SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AG_DB_Remove]
				(
				@DBName		SYSNAME
				,@AGroup		SYSNAME		OUT
				)
AS
SET NOCOUNT ON
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
DECLARE	@Command			nVarChar(max)
		,@DestServer		SYSNAME
		,@InAG			BIT
		,@DBJoined		BIT
		,@CreateJob_cmd	VarChar(8000)
		,@LoopCount		INT = 0
		,@LoopLimit		INT = 60
DECLARE	@NodeDBStatus		Table		(DestServer SYSNAME, DBJoined bit)


SET		@AGroup			= NULL


IF DB_ID(@DBName) IS NOT NULL
IF @@microsoftversion / 0x01000000 >= 11
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
	SELECT	DISTINCT
			@AGroup = AG.Name
	FROM		master.sys.availability_groups AS AG
	LEFT JOIN	master.sys.availability_replicas AS AR
		ON	AG.group_id = AR.group_id
		--AND	AG.Name = @AGroup
	LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
		ON	AR.replica_id = dbcs.replica_id
	WHERE	dbcs.database_name = @DBName
		and	db_id(dbcs.database_name) IS NOT NULL
		AND	AG.Name IS NOT NULL


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


	IF @AGroup IS NULL
	BEGIN
		RAISERROR ('Databases %s is NOT in an Availability Group. Nothing to do....',-1,-1,@DBName) WITH NOWAIT
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
		RAISERROR ('Removing Databases %s From AG %s.',-1,-1,@DBName,@AGroup) WITH NOWAIT


		IF EXISTS (SELECT * FROM @NodeDBStatus WHERE DBJoined = 1)
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


					IF @DBJoined = 0
					BEGIN
						RAISERROR ('Database %s has already been removed from Availability Group %s on node %s.',-1,-1,@DBName,@AGroup,@DestServer) WITH NOWAIT
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
										+ 'SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''XXX_DBA_DROP_DB_FROM_AG_'+ @AGroup+'_'+@DBName+''''+CHAR(13)+CHAR(10)
										+ 'IF (@jobId IS NOT NULL)'+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_delete_job @jobId'
						EXEC (@CreateJob_cmd) AT [DYN_DBA_RMT]


						SET @CreateJob_cmd	= 'USE [msdb]'+CHAR(13)+CHAR(10)
										+ 'DECLARE @jobId BINARY(16)'+CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_job @job_name=N''XXX_DBA_DROP_DB_FROM_AG_'+ @AGroup+'_'+@DBName+''','+CHAR(13)+CHAR(10)
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
										+ 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Remove Database From AG'','+CHAR(13)+CHAR(10)
										+ '	@step_id=1,'+CHAR(13)+CHAR(10)
										+ '	@cmdexec_success_code=0,'+CHAR(13)+CHAR(10)
										+ '	@on_success_action=3,'+CHAR(13)+CHAR(10)
										+ '	@on_success_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_action=2,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_attempts=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_interval=0,'+CHAR(13)+CHAR(10)
										+ '	@os_run_priority=0, @subsystem=N''TSQL'','+CHAR(13)+CHAR(10)
										+ '	@command=N''USE master;ALTER DATABASE ['+@DBName+'] SET HADR OFF;'','+CHAR(13)+CHAR(10)
										+ '	@database_name=N''master'','+CHAR(13)+CHAR(10)
										+ '	@output_file_name=N''D:\XXX_DBA_DROP_DB_FROM_AG_'+ @AGroup+'_'+@DBName+'.txt'','+CHAR(13)+CHAR(10)
										+ '	@flags=6'+CHAR(13)+CHAR(10)
										+ CHAR(13)+CHAR(10)
										+ 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Drop Database'','+CHAR(13)+CHAR(10)
										+ '	@step_id=2,'+CHAR(13)+CHAR(10)
										+ '	@cmdexec_success_code=0,'+CHAR(13)+CHAR(10)
										+ '	@on_success_action=1,'+CHAR(13)+CHAR(10)
										+ '	@on_success_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_action=2,'+CHAR(13)+CHAR(10)
										+ '	@on_fail_step_id=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_attempts=0,'+CHAR(13)+CHAR(10)
										+ '	@retry_interval=0,'+CHAR(13)+CHAR(10)
										+ '	@os_run_priority=0, @subsystem=N''TSQL'','+CHAR(13)+CHAR(10)
										+ '	@command=N''USE Master;'+CHAR(13)+CHAR(10)
										+ '				IF (SELECT state_desc FROM SYS.Databases where name = '''''+@DBName+''''') = ''''RESTORING'''''+CHAR(13)+CHAR(10)
										+ '					DROP DATABASE ['+@DBName+']'+CHAR(13)+CHAR(10)
										+ '				ELSE'+CHAR(13)+CHAR(10)
										+ '				BEGIN'+CHAR(13)+CHAR(10)
										+ '					ALTER DATABASE ['+@DBName+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;'+CHAR(13)+CHAR(10)
										+ '					DROP DATABASE ['+@DBName+'];'+CHAR(13)+CHAR(10)
										+ '				END'','+CHAR(13)+CHAR(10)
										+ '	@database_name=N''master'','+CHAR(13)+CHAR(10)
										+ '	@output_file_name=N''D:\XXX_DBA_DROP_DB_FROM_AG_'+ @AGroup+'_'+@DBName+'.txt'','+CHAR(13)+CHAR(10)
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


			WHILE EXISTS (SELECT * FROM @NodeDBStatus WHERE DBJoined = 1) AND @LoopCount < @LoopLimit
			BEGIN
				RAISERROR ('Waiting for DB %s to be Removed from all Replica Nodes.',-1,-1,@DBName) WITH NOWAIT

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

				SET @LoopCount = @LoopCount + 1
				WAITFOR DELAY '00:00:10'
			END

			IF @LoopCount >= @LoopLimit
				RAISERROR ('Done Waiting for DB %s to be Removed from all Replica Nodes. Force Removing it From AG',-1,-1,@DBName) WITH NOWAIT

			--SET @Command = 'USE master;ALTER AVAILABILITY GROUP ['+@AGroup+'] REMOVE DATABASE ['+@DBName+'];'
			--EXEC (@Command)

		END
		
		SET @Command = 'USE master;ALTER AVAILABILITY GROUP ['+@AGroup+'] REMOVE DATABASE ['+@DBName+'];'
		EXEC (@Command)
	END
END
ELSE
	RAISERROR ('Server Configuration does not Support Availability Groups.',-1,-1) WITH NOWAIT
ELSE
	RAISERROR ('Server Version does not Support Availability Groups.',-1,-1) WITH NOWAIT
ELSE
	RAISERROR ('Database %s does NOT Exist.',-1,-1,@DBName) WITH NOWAIT
GO
GRANT EXECUTE ON  [dbo].[dbasp_AG_DB_Remove] TO [public]
GO
