SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Mirror_DB]
				(
				@DBName					SYSNAME
				,@FromServerName		SYSNAME
				,@WitnessName			SYSNAME = NULL
				,@FilePath				VarChar(2000) = NULL		
				,@Wait4All				BIT = 0
				,@UseExistingBackups	bit = 0
				,@DelExistingBackups	bit = 0
				,@NoRestore				bit = 0	
				)
AS
SET NOCOUNT ON
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
DECLARE	@Command				nVarChar(max)
		,@DestServer			SYSNAME
		,@InAG					BIT					= 0
		,@DBJoined				BIT
		,@CreateJob_cmd			VarChar(8000)
		,@AgentJob				SYSNAME				= 'MAINT - TranLog Backup'
		,@Backup_cmd			varchar(max)
		,@DeleteFileData		XML
		,@CheckAGName			SYSNAME
		--,@DataPath				nVarChar(512)
		--,@LogPath				nVarChar(512)
		--,@BackupPath			nVarChar(512)
		,@Local_FQDN			SYSNAME
		,@Remote_FQDN			SYSNAME
		,@Witness_FQDN			SYSNAME
		,@jobId					BINARY(16)
		,@Params				nvarchar(4000)
		,@RemoteEndpointName	SYSNAME
		,@RemoteEndpointID		INT
		,@RemoteEndpointPort	INT
		,@LocalEndpointName		SYSNAME
		,@LocalEndpointID		INT
		,@LocalEndpointPort		INT
		,@WitnessEndpointName	SYSNAME
		,@WitnessEndpointID		INT
		,@WitnessEndpointPort	INT
		,@CreateEndpoint		VarChar(MAX)

					-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@BackupPathA				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@CleanBackupPath			VARCHAR(8000)
			,@SQLEnv					VarChar(10)	
			,@RootNetworkBackups		VarChar(8000)
			,@RootNetworkFailover		VarChar(8000)
			,@RootNetworkArchive		VarChar(8000)
			,@RootNetworkClean			VARCHAR(8000)

DECLARE	@NodeDBStatus		Table		(DestServer SYSNAME, DBJoined bit)

--exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DataPath output
--exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @LogPath output
--exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupPath output


			-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
			EXEC DBAOps.dbo.dbasp_GetPaths --@verbose = 1
				 @DataPath				= @DataPath				OUT
				,@LogPath				= @LogPath				OUT
				,@BackupPathL			= @BackupPathL			OUT
				,@BackupPathN			= @BackupPathN			OUT
				,@BackupPathN2			= @BackupPathN2			OUT
				,@BackupPathA			= @BackupPathA			OUT
				,@DBASQLPath			= @DBASQLPath			OUT
				,@SQLAgentLogPath		= @SQLAgentLogPath		OUT
				,@DBAArchivePath		= @DBAArchivePath		OUT
				,@EnvBackupPath			= @EnvBackupPath		OUT
				,@SQLEnv				= @SQLEnv				OUT
				,@RootNetworkBackups	= @RootNetworkBackups	OUT	
				,@RootNetworkFailover	= @RootNetworkFailover	OUT	
				,@RootNetworkArchive	= @RootNetworkArchive	OUT
				,@RootNetworkClean		= @RootNetworkClean		OUT



SET	@CreateEndpoint = 'CREATE ENDPOINT [Mirroring] 
	AUTHORIZATION [sa]
	STATE=STARTED
	AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
	FOR DATA_MIRRORING (ROLE = PARTNER, AUTHENTICATION = WINDOWS NEGOTIATE
, ENCRYPTION = REQUIRED ALGORITHM RC4)'

-- GET LOCAL MIRRORING ENPOINT INFO
SELECT		@LocalEndpointID	= endpoint_id
			,@LocalEndpointPort	= port
FROM		master.sys.tcp_endpoints 
WHERE		TYPE=4

IF @LocalEndpointID IS NOT NULL
	SELECT		@LocalEndpointName = NAME
	FROM		master.sys.endpoints 
	WHERE		endpoint_id = @LocalEndpointID
ELSE
BEGIN
	EXEC (@CreateEndpoint)

	SELECT		@LocalEndpointID	= endpoint_id
				,@LocalEndpointPort	= port
				,@LocalEndpointName	= 'Mirroring'-- select *
	FROM		master.sys.tcp_endpoints 
	WHERE		TYPE=4
END

IF @WitnessName IS NOT NULL
BEGIN
	-- ADD DYNAMIC LINKED SERVER
	IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
		EXEC ('master.dbo.sp_dropserver @server=N''DYN_DBA_RMT'', @droplogins=''droplogins''')
  
	EXEC ('sp_addlinkedserver @server=''DYN_DBA_RMT'',@srvproduct='''',@provider=''SQLNCLI'',@datasrc=''tcp:'+@WitnessName+'''')
	EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc'', @optvalue=N''true''')
	EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc out'', @optvalue=N''true''')
	EXEC ('master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''DYN_DBA_RMT'',@useself=N''False'',@locallogin=null,@rmtuser=N''LinkedServer_User'',@rmtpassword=''4vnetonly''')



	-- GET WITNESS MIRRORING ENPOINT INFO
	SELECT		@WitnessEndpointID		= endpoint_id
				,@WitnessEndpointPort	= port
	FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints 
	WHERE		TYPE=4

	IF @WitnessEndpointID IS NOT NULL
		SELECT		@WitnessEndpointName = NAME
		FROM		[DYN_DBA_RMT].master.sys.endpoints 
		WHERE		endpoint_id = @WitnessEndpointID
	ELSE
	BEGIN
		EXEC (@CreateEndpoint) AT [DYN_DBA_RMT]

		SELECT		@WitnessEndpointID	= endpoint_id
					,@WitnessEndpointPort	= port
					,@WitnessEndpointName	= 'Mirroring'
		FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints 
		WHERE		TYPE=4
	END


	-- GET WITNESS FQDN
	IF @WitnessName = COALESCE(PARSENAME(@WitnessName,5),PARSENAME(@WitnessName,4),PARSENAME(@WitnessName,3),PARSENAME(@WitnessName,2),PARSENAME(@WitnessName,1))
	BEGIN
		EXEC [DYN_DBA_RMT].master..xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @Witness_FQDN OUTPUT
		SELECT @Witness_FQDN = @WitnessName + '.' + @Witness_FQDN
	END
	ELSE
		SET @Witness_FQDN = @WitnessName
END

-- ADD DYNAMIC LINKED SERVER
IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
	EXEC ('master.dbo.sp_dropserver @server=N''DYN_DBA_RMT'', @droplogins=''droplogins''')
  
EXEC ('sp_addlinkedserver @server=''DYN_DBA_RMT'',@srvproduct='''',@provider=''SQLNCLI'',@datasrc=''tcp:'+@FromServerName+'''')
EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc'', @optvalue=N''true''')
EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc out'', @optvalue=N''true''')
EXEC ('master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''DYN_DBA_RMT'',@useself=N''False'',@locallogin=null,@rmtuser=N''LinkedServer_User'',@rmtpassword=''4vnetonly''')

-- GET REMOTE MIRRORING ENPOINT INFO
SELECT		@RemoteEndpointID		= endpoint_id
			,@RemoteEndpointPort	= port
FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints 
WHERE		TYPE=4

IF @RemoteEndpointID IS NOT NULL
	SELECT		@RemoteEndpointName = NAME
	FROM		[DYN_DBA_RMT].master.sys.endpoints 
	WHERE		endpoint_id = @RemoteEndpointID
ELSE
BEGIN
	EXEC (@CreateEndpoint) AT [DYN_DBA_RMT]

	SELECT		@RemoteEndpointID	= endpoint_id
				,@RemoteEndpointPort	= port
				,@RemoteEndpointName	= 'Mirroring'
	FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints 
	WHERE		TYPE=4
END


-- GET LOCAL FQDN
EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @Local_FQDN OUTPUT
SELECT @Local_FQDN = Cast(SERVERPROPERTY('MachineName') as nvarchar) + '.' + @Local_FQDN

-- GET REMOTE FQDN
IF @FromServerName = COALESCE(PARSENAME(@FromServerName,5),PARSENAME(@FromServerName,4),PARSENAME(@FromServerName,3),PARSENAME(@FromServerName,2),PARSENAME(@FromServerName,1))
BEGIN
	EXEC [DYN_DBA_RMT].master..xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @Remote_FQDN OUTPUT
	SELECT @Remote_FQDN = @FromServerName + '.' + @Remote_FQDN
END
ELSE
	SET @Remote_FQDN = @FromServerName

IF @FilePath IS NULL
	SELECT	@FilePath = REPLACE(@RootNetworkBackups,dbaops.dbo.dbaudf_GetLocalFQDN()+'\','') + UPPER(@Remote_FQDN) + '\'


	--SELECT @DBName,@Remote_FQDN,@RemoteEndpointPort,@Local_FQDN,@LocalEndpointPort,@FilePath


-- SET REMOTE DATABASE IN MAINTENANCE MODE SO THAT TRANLOG BACKUPS ARE NOT BEING RUN
EXEC (
'print ''Testing Remote Agent Job...''
WHILE DBAOps.dbo.[dbaudf_GetJobStatus]('''+@AgentJob+''') IN(-5,4)
BEGIN
	RAISERROR (''	Remote Agent Job:'+@AgentJob+' is running, Waiting for it to finish.'',-1,-1) WITH NOWAIT
	WAITFOR DELAY ''00:00:10''
END
RAISERROR (''	Remote Agent Job: '+@AgentJob+' is not running.'',-1,-1) WITH NOWAIT

RAISERROR (''Remote DB ['+@DBName+'] is being placed into Maintenance Mode.'',-1,-1) WITH NOWAIT 
EXEC	DBAOps.[dbo].[dbasp_SetDBMaint] '''+@DBName+''',1'
) AT [DYN_DBA_RMT]


if @UseExistingBackups = 0 AND @DelExistingBackups = 1
BEGIN	-- DELETE ALL EXISTING BACKUPS IN LOCAL BACKUP SHARE FOR THE AG DATABASES SINCE IT SLOWS DOWN THE RESTORE PROCESS 
	;WITH	Settings
			AS
			(
			SELECT	32			AS [QueueMax]		-- Max Number of files coppied at once.
					,'false'	AS [ForceOverwrite]	-- true,false
					,-1			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
					,300		AS [UpdateInterval]	-- rate of progress updates in Seconds
			)
			,DeleteFile
			AS
			(
			SELECT	FullPathName [Source]
			FROM		DBAOps.dbo.dbaudf_BackupScripter_GetBackupFiles(@DBName,@FilePath,0,NULL)
			)
	SELECT	@DeleteFileData =	(
							SELECT	*
									,(SELECT * FROM DeleteFile FOR XML RAW ('DeleteFile'), TYPE)
							FROM		Settings
							FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
							)
	-- DEBUG CODE
	--SELECT @DeleteFileData
	RAISERROR ('Deleting all Local Backup Files for Database: %s.',-1,-1,@DBName) WITH NOWAIT

	exec DBAOps.dbo.dbasp_FileHandler @DeleteFileData
END

if @UseExistingBackups = 0
BEGIN	-- BACKUP DATABASE

		SET	@jobid	= NULL

		-- DELETE JOB IF IT ALREADY EXISTS
		RAISERROR ('Deleting Backup Job for %s Database if it already exists.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'DECLARE @jobId BINARY(16)
			SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_' + @Local_FQDN + ''' 
			IF (@jobId IS NOT NULL)
			EXEC msdb.dbo.sp_delete_job @jobId'
		EXEC (@Command) AT [DYN_DBA_RMT]

		-- CREATE BACKUP JOB
		RAISERROR ('Creating Backup Job for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET @Command = 'EXEC msdb.dbo.sp_add_job @job_name=N''XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_' + @Local_FQDN + ''', 
				@enabled=1, @notify_level_eventlog=0, @notify_level_email=0, 
				@notify_level_netsend=0, @notify_level_page=0, @delete_level=1, 
				@description=N''Restore Database From Existing Server'', 
				@category_name=N''[Uncategorized (Local)]'', 
				@owner_login_name=N''sa'''
		EXEC (@Command) AT [DYN_DBA_RMT]

		RAISERROR('Getting JobID for new Job.',-1,-1) WITH NOWAIT
		SELECT @jobId = job_id 
		FROM [DYN_DBA_RMT].msdb.dbo.sysjobs
		where name = 'XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_' + @Local_FQDN 
		--SELECT @jobId

		-- ADD JOB STEP TO FULL BACKUP DATABASE
		RAISERROR ('  - Adding FULL Backup Step for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id='''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobID) AS Varchar(50))+''', @step_name=N''Backup Database - FULL'', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=3, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N''TSQL'', 
				@command=N''DECLARE @Backup_cmd varchar(max)
					EXEC DBAOps.[dbo].[dbasp_format_BackupRestore] 
						@DBName			= '''''+@DBName+'''''
						,@Mode			= ''''BF''''
						,@FilePath		= '+ CASE WHEN @FilePath IS NULL THEN 'NULL'
												ELSE '''''' +  @FilePath + ''''''
												END +'
						,@Verbose			= 1
						,@ForceB2Null		= 0
						,@IgnoreMaintOvrd	= 1
						,@syntax_out		= @Backup_cmd OUTPUT
					SET  @Backup_cmd = REPLACE(@Backup_cmd,''''INSERT INTO'''',''''--INSERT INTO'''')
					EXEC (@Backup_cmd)
					WAITFOR DELAY ''''00:0:05'''''', 
				@database_name=N''master'', 
				@output_file_name=N''' +  @FilePath + 'XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_'+ @Local_FQDN +'.txt'',
				@flags=6'
		EXEC (@Command) AT [DYN_DBA_RMT]
		--exec DBAOps.dbo.dbasp_PrintLarge @Command

		-- ADD JOB STEP TO LOG BACKUP DATABASE
		RAISERROR ('  - Adding LOG Backup Step for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id='''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobID) AS Varchar(50))+''', @step_name=N''Backup Database - LOG'', 
				@step_id=2, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0,
				@os_run_priority=0, @subsystem=N''TSQL'', 
				@command=N''DECLARE @Backup_cmd varchar(max)
					EXEC DBAOps.[dbo].[dbasp_format_BackupRestore] 
						@DBName			= '''''+@DBName+'''''
						,@Mode			= ''''BL''''
						,@FilePath		= '+ CASE WHEN @FilePath IS NULL THEN 'NULL'
												ELSE '''''' +  @FilePath + ''''''
												END +'
						,@Verbose			= 1
						,@ForceB2Null		= 0
						,@IgnoreMaintOvrd	= 1
						,@syntax_out		= @Backup_cmd OUTPUT
					SET  @Backup_cmd = REPLACE(@Backup_cmd,''''INSERT INTO'''',''''--INSERT INTO'''')
					EXEC (@Backup_cmd)
					WAITFOR DELAY ''''00:0:05'''''', 
				@database_name=N''master'', 
				@output_file_name=N''' +  @FilePath + 'XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_'+ @Local_FQDN +'.txt'',
				@flags=6'
		EXEC (@Command) AT [DYN_DBA_RMT]


		-- SET START STEP
		RAISERROR ('   - Setting Start Step for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_update_job @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobID) AS Varchar(50))+''', @start_step_id = 1'
		EXEC (@Command) AT [DYN_DBA_RMT]
				
		-- SET JOB SERVER
		RAISERROR ('   - Setting Job Server for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobserver @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobID) AS Varchar(50))+''', @server_name = N''(local)'''
		EXEC (@Command) AT [DYN_DBA_RMT]
				
		-- START JOB
		RAISERROR ('    - Starting Backup Job for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'exec msdb.dbo.sp_start_job @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobID) AS Varchar(50))+''''
		EXEC (@Command) AT [DYN_DBA_RMT]

	END


	BEGIN -- RESTORE DATABASE
		SET	@jobid	= NULL
		SET	@Params	= N'@jobid BINARY(16) OUT'

		-- DELETE JOB IF IT ALREADY EXISTS
		RAISERROR ('Deleting Restore Job for %s Database if it already exists.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'DECLARE @jobId BINARY(16)
			SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''XXX_DBA_RESTORE_DB_' + @DBName + '_FROM_' + @FromServerName + ''' 
			IF (@jobId IS NOT NULL)
			EXEC msdb.dbo.sp_delete_job @jobId'
		EXEC (@Command)

		-- CREATE JOB
		RAISERROR ('Creating Restore Job for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET @Command = 'EXEC msdb.dbo.sp_add_job @job_name=N''XXX_DBA_RESTORE_DB_' + @DBName + '_FROM_' + @FromServerName + ''', 
				@enabled=1, @notify_level_eventlog=0, @notify_level_email=0, 
				@notify_level_netsend=0, @notify_level_page=0, @delete_level=1, 
				@description=N''Restore Database From Existing Server'', 
				@category_name=N''[Uncategorized (Local)]'', 
				@owner_login_name=N''sa'', @job_id = @jobId OUTPUT'
		EXEC sp_executesql @Command,@Params,@jobid OUT

		-- ADD JOB STEP RESTORE DATABASE
		RAISERROR ('  - Adding Restore Step for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET	@Params = N'@jobid BINARY(16)'
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Restore Database'', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=3, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N''TSQL'', 
				@command=N''USE DBAOps;
					DECLARE @Restore_cmd nvarchar(max)
					WHILE EXISTS (SELECT * FROM [DYN_DBA_RMT].msdb.dbo.sysjobs WHERE name = ''''XXX_DBA_BACKUP_DB_' + @DBName + '_FOR_' + @Local_FQDN +''''')
						BEGIN
							RAISERROR (''''Waiting For Backup to complete...'''',-1,-1) WITH NOWAIT
							WAITFOR DELAY ''''00:01:00''''
						END
					WAITFOR DELAY ''''00:0:10''''

					EXEC(''''IF EXISTS (select 1 From sys.database_mirroring where mirroring_partner_name IS NOT NULL AND DB_NAME(database_id) = ''''''''' + @DBName + ''''''''')
						ALTER DATABASE ['+@DBName+'] SET PARTNER OFF'''') AT [DYN_DBA_RMT];

					EXEC DBAOps.[dbo].[dbasp_format_BackupRestore] 
						@DBName			= '''''+@DBName+'''''
						,@Mode			= ''''RD''''
						,@FilePath		= '+ CASE WHEN @FilePath IS NULL THEN 'NULL'
												ELSE '''''' +  @FilePath + ''''''
												END +' 
						,@FromServer		= '+ CASE WHEN @FilePath IS NULL THEN ''''''+@FromServerName+''''''
												ELSE 'NULL'
												END +'
						,@FullReset			= 1 
						,@Verbose			= 0
						,@LeaveNORECOVERY	= 1
						,@syntax_out		= @Restore_cmd OUTPUT
					EXEC (@Restore_cmd) AS LOGIN = ''''sa'''''', 
				@database_name=N''master'', 
				@output_file_name=N''' +  @FilePath + 'XXX_DBA_RESTORE_DB_' + @DBName + '_FROM_'+ @Remote_FQDN +'.txt'',
				@flags=6'
		EXEC sp_executesql @Command,@Params,@jobid

		-- ADD JOB STEP ALTER DATABASE
		RAISERROR ('  - Adding Alter DB Step for %s Database.',-1,-1,@DBName) WITH NOWAIT
		
		SET	@Params = N'@jobid BINARY(16)'
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''Alter Database'', 
				@step_id=2, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N''TSQL'', 
				@command=N''USE DBAOps;
					
					EXEC(''''IF EXISTS (select 1 From sys.database_mirroring where mirroring_partner_name IS NOT NULL AND DB_NAME(database_id) = ''''''''' + @DBName + ''''''''')
						ALTER DATABASE ['+@DBName+'] SET PARTNER OFF'''') AT [DYN_DBA_RMT];

					ALTER DATABASE ['+@DBName+'] SET PARTNER = ''''TCP://'+@Remote_FQDN+':'+CAST(@RemoteEndpointPort AS VarChar(10))+''''';

					EXEC(''''ALTER DATABASE ['+@DBName+'] SET PARTNER = ''''''''TCP://'+@Local_FQDN+':'+CAST(@LocalEndpointPort AS VarChar(10))+''''''''''''') AT [DYN_DBA_RMT];

					' + CASE WHEN @Witness_FQDN IS NOT NULL 
								THEN 'EXEC(''''ALTER DATABASE ['+@DBName+'] SET WITNESS = ''''''''TCP://'+@Witness_FQDN+':'+CAST(@WitnessEndpointPort AS VarChar(10))+''''''''''''') AT [DYN_DBA_RMT];'
								ELSE '' END +
					'
					EXEC(''''EXEC DBAOps.[dbo].[dbasp_SetDBMaint] '''''''''+@DBName+''''''''',0'''') AT [DYN_DBA_RMT];'', 
				@database_name=N''master'', 
				@output_file_name=N''' +  @FilePath + '\XXX_DBA_RESTORE_DB_' + @DBName + '_FROM_'+ @Remote_FQDN +'.txt'',
				@flags=6'
		EXEC sp_executesql @Command,@Params,@jobid
		--EXEC DBAOps.dbo.dbasp_PrintLarge @command
		
		-- SET START STEP
		RAISERROR ('   - Setting Start Step for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1'
		EXEC sp_executesql @Command,@Params,@jobid
				
		-- SET JOB SERVER
		RAISERROR ('   - Setting Job Server for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)'''
		EXEC sp_executesql @Command,@Params,@jobid
				
		-- START JOB
		RAISERROR ('    - Starting Restore Job for %s Database.',-1,-1,@DBName) WITH NOWAIT
		SET	@Command = 'exec msdb.dbo.sp_start_job @job_id = @jobId'
		EXEC sp_executesql @Command,@Params,@jobid
	END

	IF @Wait4All = 1
		WHILE EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'XXX_DBA_RESTORE_DB_' + @DBName + '_FROM_' + @Remote_FQDN )
		BEGIN
			RAISERROR ('Waiting For Mirroring to complete...',-1,-1) WITH NOWAIT
			WAITFOR DELAY '00:01:00'
		END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Mirror_DB] TO [public]
GO
