SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AG_DB_Join]
				(
				@DBName				SYSNAME
				,@AGroup				SYSNAME
				,@Wait4All			BIT = 0
				,@UseExistingBackups	bit = 0
				)
AS
SET NOCOUNT ON
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
DECLARE	@Command			nVarChar(max)
		,@DestServer		SYSNAME
		,@InAG				BIT				= 0
		,@DBJoined			BIT
		,@CreateJob_cmd		VarChar(8000)
		,@AgentJob			SYSNAME			= 'MAINT - TranLog Backup'
		,@Backup_cmd		varchar(max)
		,@DeleteFileData	XML
		,@DeleteFilePath	VarChar(max)
		,@CheckAGName		SYSNAME


DECLARE	@NodeDBStatus		Table		(DestServer SYSNAME, DBJoined bit)


SELECT	@DeleteFilePath	= DBAOps.dbo.dbaudf_getShareUNC('backup') -- LOCAL BACKUP SHARE


IF DB_ID(@DBName) IS NOT NULL
IF @@microsoftversion / 0x01000000 >= 11
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
	SELECT	@CheckAGName =	COALESCE((
					SELECT	AG.Name
					FROM		master.sys.availability_groups AS AG
					WHERE	AG.Name = @AGroup
					),'BAD_AG_NAME')


		;WITH	AGDB
				AS
				(
				SELECT	AG.name
						,AR.replica_server_name
						,dbcs.*
				FROM		master.sys.availability_groups AS AG
				LEFT JOIN	master.sys.availability_replicas AS AR
					ON	AG.group_id = AR.group_id
					AND	AG.Name = @AGroup
				LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					ON	AR.replica_id = dbcs.replica_id
				)
		-- LIST NODES IN AG GROUP
		INSERT INTO @NodeDBStatus
		SELECT	DISTINCT
				AR.replica_server_name
				,ISNULL	(
						(
						SELECT	MAX(1)
						FROM		AGDB
						WHERE	database_name = @DBName
							AND	replica_server_name = AR.replica_server_name
							AND	is_database_joined = 1
						)
						,0
						) [DBJoined]
		FROM		master.sys.availability_replicas AR
		JOIN		master.sys.availability_groups AS AG
			ON	AG.group_id = AR.group_id
		WHERE	AG.name = @AGroup
			AND	AR.replica_server_name != @@ServerName


	IF @AGroup IS NULL
	BEGIN
		RAISERROR ('No Availability Group was specified for Databases %s. Nothing to do....',-1,-1,@DBName) WITH NOWAIT
	END
	ELSE IF @CheckAGName = 'BAD_AG_NAME'
	BEGIN
		RAISERROR ('Availability Group %s was NOT Valid. Nothing to do....',-1,-1,@AGroup) WITH NOWAIT
	END
	ELSE IF	(
			-- THIS PART OF QUERY RETURNS THE PRIMARY REPLICA FOR THE SPECIFIED AG GROUP
			select	primary_replica
			from		sys.dm_hadr_availability_group_states ags
			join		sys.availability_groups ag
				on	ags.group_id = ag.group_id
			WHERE	ag.name = @AGroup
			)  != @@SERVERNAME
	BEGIN
		RAISERROR ('This is not the Primary Replica of the %s Availability Group. Nothing to do....',-1,-1,@AGroup) WITH NOWAIT


	END
	ELSE
	BEGIN
		IF DBAOps.dbo.dbaudf_GetDbAg(@DBName) = @AGroup
			SET	@InAG = 1
		ELSE IF DBAOps.dbo.dbaudf_GetDbAg(@DBName) Not Like 'ERROR%'
		BEGIN
			RAISERROR ('%s is already a member of another Availability Group. Nothing to do....',-1,-1,@DBName) WITH NOWAIT
			GOTO DoNothing
		END


		RAISERROR ('Adding Databases %s To AG %s.',-1,-1,@DBName,@AGroup) WITH NOWAIT


		---- TURN OFF LOG BACKUP JOB
		--IF DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) >= 0
		--BEGIN
		--	RAISERROR ('Local Agent Job: %s is being disabled.',-1,-1,@AgentJob) WITH NOWAIT
		--	EXEC  msdb.dbo.sp_update_job @job_Name=@AgentJob, @enabled=0
		--END
		--ELSE
		--	RAISERROR ('Local Agent Job: %s is already disabled.',-1,-1,@AgentJob) WITH NOWAIT

		print '	Testing Local Agent Job...'
		WHILE DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) IN(-5,4)
		BEGIN
			RAISERROR ('  Local Agent Job: %s is running, Waiting for it to finish.',-1,-1,@AgentJob) WITH NOWAIT
			WAITFOR DELAY '00:00:10'
		END
		RAISERROR ('Local Agent Job: %s is not running.',-1,-1,@AgentJob) WITH NOWAIT


		RAISERROR ('%s is being placed into Maintenance Mode.',-1,-1,@DBName) WITH NOWAIT
		EXEC	[DBAOps].[dbo].[dbasp_SetDBMaint] @DBName,1


		--if @UseExistingBackups = 0
		--BEGIN	-- DELETE ALL EXISTING BACKUPS IN LOCAL BACKUP SHARE FOR THE AG DATABASES SINCE IT SLOWS DOWN THE RESTORE PROCESS
		--	;WITH	Settings
		--			AS
		--			(
		--			SELECT	32			AS [QueueMax]		-- Max Number of files coppied at once.
		--					,'false'	AS [ForceOverwrite]	-- true,false
		--					,-1			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
		--					,300		AS [UpdateInterval]	-- rate of progress updates in Seconds
		--			)
		--			,DeleteFile
		--			AS
		--			(
		--			SELECT	FullPathName [Source]
		--			FROM		DBAOps.dbo.dbaudf_BackupScripter_GetBackupFiles(@DBName,@DeleteFilePath,0,NULL)
		--			)
		--	SELECT	@DeleteFileData =	(
		--								SELECT		*
		--											,(SELECT * FROM DeleteFile FOR XML RAW ('DeleteFile'), TYPE)
		--								FROM		Settings
		--								FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
		--								)
		--	-- DEBUG CODE
		--	-- SELECT @DeleteFileData
		--	RAISERROR ('Deleting all Local Backup Files for Database: %s.',-1,-1,@DBName) WITH NOWAIT


		--	exec DBAOps.dbo.dbasp_FileHandler @DeleteFileData
		--END


		if @UseExistingBackups = 0
		BEGIN	-- BACKUP DATABASE
			-- ENSURE DATABASE IS SET TO FULL RECOVERY BEFORE TAKING BACKUPS
			SET @Command = 'USE MASTER;'+CHAR(13)+CHAR(10)
						+ 'IF (SELECT recovery_model_desc FROM sys.databases WHERE name = '''+@DBName+''') != ''FULL'''+CHAR(13)+CHAR(10)
						+ '	ALTER DATABASE ['+@DBName+'] SET RECOVERY FULL;'+CHAR(13)+CHAR(10)
			--exec DBAOps.dbo.dbasp_PrintLarge @Command
			EXEC (@Command);


			RAISERROR ('',-1,-1) WITH NOWAIT
			PRINT '--====================================================================================================--'
			SET @Backup_cmd = NULL
			RAISERROR ('Backing Up FULL Database %s.',-1,-1,@DBName) WITH NOWAIT

			EXEC DBAOps.dbo.dbasp_Backup @DBname = @DBName,@Mode = 'BF' ,@ForceB2Null = 0,@IgnoreMaintOvrd	= 1

			--EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
			--				@DBName				= @DBName
			--				,@Mode				= 'BF'
			--				,@Verbose			= 0
			--				,@ForceB2Null		= 0
			--				,@IgnoreMaintOvrd	= 1
			--				,@syntax_out		= @Backup_cmd OUTPUT
			--SET  @Backup_cmd = REPLACE(@Backup_cmd,'INSERT INTO','--INSERT INTO')
			--PRINT (@Backup_cmd)
			--EXEC (@Backup_cmd)
			PRINT '--====================================================================================================--'
			RAISERROR ('',-1,-1) WITH NOWAIT


			WAITFOR DELAY '00:0:05'


			PRINT '--====================================================================================================--'
			SET @Backup_cmd = NULL
			RAISERROR ('Backing Up Transaction Log on Database %s.',-1,-1,@DBName) WITH NOWAIT

			EXEC DBAOps.dbo.dbasp_Backup @DBname = @DBName,@Mode = 'BL' ,@ForceB2Null = 0,@IgnoreMaintOvrd	= 1

			--EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
			--				@DBName				= @DBName
			--				,@Mode				= 'BL'
			--				,@Verbose			= 0
			--				,@ForceB2Null		= 0
			--				,@IgnoreMaintOvrd	= 1
			--				,@syntax_out		= @Backup_cmd OUTPUT
			--SET  @Backup_cmd = REPLACE(@Backup_cmd,'INSERT INTO','--INSERT INTO')
			--PRINT (@Backup_cmd)
			--EXEC (@Backup_cmd)
			PRINT '--====================================================================================================--'
			RAISERROR ('',-1,-1) WITH NOWAIT


			WAITFOR DELAY '00:0:05'
		END


		IF @InAG = 0
		BEGIN	-- MODIFY DATABASE
			SET @Command = 'USE MASTER;'+CHAR(13)+CHAR(10)
						-- SET TRUSTWORTH ON
						+ 'ALTER DATABASE ['+@DBName+'] SET TRUSTWORTHY ON'+CHAR(13)+CHAR(10)
						+ ''+CHAR(13)+CHAR(10)
						-- ENABLE BROKER IF THERE ARE ANY SERVICES
						+ 'IF EXISTS(select * from sys.databases where name = '''+@DBName+''' AND is_broker_enabled = 0)'+CHAR(13)+CHAR(10)
						+ 'BEGIN'+CHAR(13)+CHAR(10)
						+ '	IF EXISTS(select * From ['+@DBName+'].sys.services WHERE name NOT LIKE ''http://schemas.microsoft.com%'')'+CHAR(13)+CHAR(10)
						+ '	BEGIN TRY'+CHAR(13)+CHAR(10)
						+ '		ALTER DATABASE ['+@DBName+'] SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;'+CHAR(13)+CHAR(10)
						+ '	END TRY'+CHAR(13)+CHAR(10)
						+ '	BEGIN CATCH'+CHAR(13)+CHAR(10)
						+ '		IF ERROR_NUMBER() = 5069'+CHAR(13)+CHAR(10)
						+ '			ALTER DATABASE ['+@DBName+'] SET NEW_BROKER WITH ROLLBACK IMMEDIATE;'+CHAR(13)+CHAR(10)
						+ '		ELSE RAISERROR(''UNABLE TO ENABLE SERVICE BROKER'',20,-1) WITH LOG'+CHAR(13)+CHAR(10)
						+ '	END CATCH'+CHAR(13)+CHAR(10)
						+ 'END'+CHAR(13)+CHAR(10)
						-- ADD DB TO AVAILABILITY GROUP
						+ ''+CHAR(13)+CHAR(10)
						+ 'ALTER AVAILABILITY GROUP ['+@AGroup+'] ADD DATABASE ['+@DBName+'];'
			--exec DBAOps.dbo.dbasp_PrintLarge @Command
			EXEC (@Command);
		END


		IF @InAG = 0
		BEGIN	-- BACKUP DATABASE LOG


			WAITFOR DELAY '00:0:05'


			PRINT '--====================================================================================================--'
			SET @Backup_cmd = NULL
			RAISERROR ('Backing Up Transaction Log on Database %s.',-1,-1,@DBName) WITH NOWAIT

			EXEC DBAOps.dbo.dbasp_Backup @DBname = @DBName,@Mode = 'BL' ,@ForceB2Null = 0,@IgnoreMaintOvrd	= 1

			--EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
			--				@DBName				= @DBName
			--				,@Mode				= 'BL'
			--				,@Verbose			= 0
			--				,@ForceB2Null		= 0
			--				,@IgnoreMaintOvrd	= 1
			--				,@syntax_out		= @Backup_cmd OUTPUT
			--SET  @Backup_cmd = REPLACE(@Backup_cmd,'INSERT INTO','--INSERT INTO')
			--PRINT (@Backup_cmd)
			--EXEC (@Backup_cmd)
			PRINT '--====================================================================================================--'
			RAISERROR ('',-1,-1) WITH NOWAIT
		END


		IF EXISTS (SELECT * FROM @NodeDBStatus WHERE DBJoined = 0) -- ARE THERE ANY REPLICAS THAT NEED JOINING
		BEGIN


			;DECLARE AGNodeCursor CURSOR
			FOR
			SELECT * FROM @NodeDBStatus


			OPEN AGNodeCursor;
			FETCH AGNodeCursor INTO @DestServer,@DBJoined;
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
					----------------------------
					---------------------------- CURSOR LOOP TOP
					PRINT '--====================================================================================================--'
					RAISERROR ('Processing Node %s.',-1,-1,@DestServer) WITH NOWAIT


					IF @DBJoined = 1
					BEGIN
						RAISERROR ('Database %s has already been Joined to Availability Group %s on node %s.',-1,-1,@DBName,@AGroup,@DestServer) WITH NOWAIT
					END
					ELSE
					BEGIN
						-- ADD DYNAMIC LINKED SERVER
						IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
							EXEC ('master.dbo.sp_dropserver @server=N''DYN_DBA_RMT'', @droplogins=''droplogins''')

						EXEC ('sp_addlinkedserver @server=''DYN_DBA_RMT'',@srvproduct='''',@provider=''SQLNCLI'',@datasrc='''+@DestServer+'''')
						EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc'', @optvalue=N''true''')
						EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc out'', @optvalue=N''true''')
						EXEC ('master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''DYN_DBA_RMT'',@useself=N''FALSE'',@locallogin=NULL,@rmtuser=''LinkedServer_User'',@rmtpassword=''4vnetonly''')


						-- CREATE REMOTE JOB
						SET @CreateJob_cmd	= 'USE [msdb]'+CHAR(13)+CHAR(10)
										+ 'DECLARE @jobId BINARY(16)'+CHAR(13)+CHAR(10)
										+ 'SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''XXX_DBA_ADD_DB_TO_AG_'+ @AGroup+'_'+@DBName+''''+CHAR(13)+CHAR(10)
										+ 'IF (@jobId IS NOT NULL)'+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_delete_job @jobId'
						EXEC (@CreateJob_cmd) AT [DYN_DBA_RMT]


						SET @CreateJob_cmd	= 'USE [msdb]'+CHAR(13)+CHAR(10)
										+ 'DECLARE @jobId BINARY(16)'+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_job @job_name=N''XXX_DBA_ADD_DB_TO_AG_'+ @AGroup+'_'+@DBName+''','+CHAR(13)+CHAR(10)
										+ '	@enabled=1,'+CHAR(13)+CHAR(10)
										+ '	@notify_level_eventlog=0,'+CHAR(13)+CHAR(10)
										+ '	@notify_level_email=0,'+CHAR(13)+CHAR(10)
										+ '	@notify_level_netsend=0,'+CHAR(13)+CHAR(10)
										+ '	@notify_level_page=0,'+CHAR(13)+CHAR(10)
										+ '	@delete_level=1,'+CHAR(13)+CHAR(10)
										+ '	@description=N''Remove Database from AG Group'','+CHAR(13)+CHAR(10)
										+ '	@category_name=N''[Uncategorized (Local)]'','+CHAR(13)+CHAR(10)
										+ '	@owner_login_name=N''sa'', @job_id = @jobId OUTPUT'+CHAR(13)+CHAR(10)
										+ CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Restore Database From Primary'','+CHAR(13)+CHAR(10)
										+ '	@step_id=1,'+CHAR(13)+CHAR(10)
										+ '	@cmdexec_success_code=0,'+CHAR(13)+CHAR(10)
										+ '	@on_success_action=3,'+CHAR(13)+CHAR(10)
										+ '	@on_success_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_action=2,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_attempts=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_interval=0,'+CHAR(13)+CHAR(10)
										+ '	@os_run_priority=0, @subsystem=N''TSQL'','+CHAR(13)+CHAR(10)
										+ '	@command=N''	DECLARE @Restore_cmd nvarchar(max)'+CHAR(13)+CHAR(10)
										+ '	EXEC [DBAOps].[dbo].[dbasp_Restore]'+CHAR(13)+CHAR(10)
										+ '		@DBName = '''''+@DBName+''''''+CHAR(13)+CHAR(10)
										+ '		,@FromServer		= '''''+UPPER(dbo.dbaudf_GetLocalFQDN())+''''''+CHAR(13)+CHAR(10)
										+ '		,@FullReset			= 1'+CHAR(13)+CHAR(10)
										+ '		,@NoSnap			= 1'+CHAR(13)+CHAR(10)
										+ '		,@NoRevert			= 1'+CHAR(13)+CHAR(10)
										+ '		,@LeaveNORecovery	= 1'+CHAR(13)+CHAR(10)
										+ '		,@NoLogRestores		= 0'+CHAR(13)+CHAR(10)
										+ '		,@IgnoreAGRestrict	= 1'','+CHAR(13)+CHAR(10)
										+ '	@database_name=N''master'','+CHAR(13)+CHAR(10)
										+ '	@output_file_name=N''D:\XXX_DBA_ADD_DB_TO_AG_'+ @AGroup+'_'+@DBName+'.txt'','+CHAR(13)+CHAR(10)
										+ '	@flags=6'+CHAR(13)+CHAR(10)
										+ CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Join AG'','+CHAR(13)+CHAR(10)
										+ '	@step_id=2,'+CHAR(13)+CHAR(10)
										+ '	@cmdexec_success_code=0,'+CHAR(13)+CHAR(10)
										+ '	@on_success_action=1,'+CHAR(13)+CHAR(10)
										+ '	@on_success_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_action=2,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_attempts=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_interval=0,'+CHAR(13)+CHAR(10)
										+ '	@os_run_priority=0, @subsystem=N''TSQL'','+CHAR(13)+CHAR(10)
										+ '	@command=N''ALTER DATABASE ['+@DBName+'] SET HADR AVAILABILITY GROUP = ['+@AGroup+']'','+CHAR(13)+CHAR(10)
										+ '	@database_name=N''master'','+CHAR(13)+CHAR(10)
										+ '	@output_file_name=N''D:\XXX_DBA_ADD_DB_TO_AG_'+ @AGroup+'_'+@DBName+'.txt'','+CHAR(13)+CHAR(10)
										+ '	@flags=6'+CHAR(13)+CHAR(10)
										+ CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1'+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)'''+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_start_job @job_id = @jobId'
						--exec DBAOps.dbo.dbasp_PrintLarge @CreateJob_cmd
						EXEC (@CreateJob_cmd) AT [DYN_DBA_RMT]
					END

					RAISERROR ('Done with Node %s.',-1,-1,@DestServer) WITH NOWAIT
					---------------------------- CURSOR LOOP BOTTOM
					----------------------------
				END
				FETCH NEXT FROM AGNodeCursor INTO @DestServer,@DBJoined;
			END
			CLOSE AGNodeCursor;
			DEALLOCATE AGNodeCursor;
		END


		-- WAIT FOR ALL NODES TO JOIN
		WHILE EXISTS (SELECT * FROM @NodeDBStatus WHERE DBJoined = 0) AND @Wait4All = 1
		BEGIN
			RAISERROR ('Waiting for DB %s to be Joined on all Replica Nodes.',-1,-1,@DBName) WITH NOWAIT

			DELETE @NodeDBStatus;


			;WITH	AGDB
					AS
					(
					SELECT	 AG.name
							,AR.replica_server_name
							,dbcs.*
					FROM		master.sys.availability_groups AS AG
					LEFT JOIN	master.sys.availability_replicas AS AR
						ON	AG.group_id = AR.group_id
						AND	AG.Name = @AGroup
					LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
						ON	AR.replica_id = dbcs.replica_id
					)
			-- LIST NODES IN AG GROUP
			INSERT INTO @NodeDBStatus
			SELECT	DISTINCT
					AR.replica_server_name
					,ISNULL	(
							(
							SELECT	MAX(1)
							FROM		AGDB
							WHERE	database_name = @DBName
								AND	replica_server_name = AR.replica_server_name
								AND	is_database_joined = 1
							)
							,0
							) [DBJoined]
			FROM		master.sys.availability_replicas AR
			JOIN		master.sys.availability_groups AS AG
				ON	AG.group_id = AR.group_id
			WHERE	AG.name = @AGroup
				AND	AR.replica_server_name != @@ServerName


			WAITFOR DELAY '00:00:10'
		END


		DoNothing:


		-- RE_ENABLE LOG BACKUP JOB
		IF @Wait4All = 1
		BEGIN
			RAISERROR ('%s is being removed from Maintenance Mode.',-1,-1,@DBName) WITH NOWAIT
			EXEC	[DBAOps].[dbo].[dbasp_SetDBMaint] @DBName,0
		END
		ELSE
		BEGIN
			RAISERROR ('%s must be removed from Maintenance Mode on primary manually by using ...',-1,-1,@DBName) WITH NOWAIT
			RAISERROR ('EXEC [DBAOps].[dbo].[dbasp_SetDBMaint] ''%s'',0',-1,-1,@DBName) WITH NOWAIT
		END


	END
END
ELSE
	RAISERROR ('Server Configuration does not Support Availability Groups.',-1,-1) WITH NOWAIT
ELSE
	RAISERROR ('Server Version does not Support Availability Groups.',-1,-1) WITH NOWAIT
ELSE
	RAISERROR ('Database %s does NOT Exist.',-1,-1,@DBName) WITH NOWAIT
GO
GRANT EXECUTE ON  [dbo].[dbasp_AG_DB_Join] TO [public]
GO
