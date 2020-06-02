SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[RunAsyncAgentJob]
					(
					@TSQL1			VARCHAR(MAX),
					@TSQL2			VARCHAR(MAX)	= NULL,
					@JobName		SYSNAME			= NULL,
					@RunAt			SYSNAME			= NULL,
					@LogFilePath	VarChar(MAX)	= NULL,
					@JobId			UNIQUEIDENTIFIER = NULL OUTPUT
					)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE		@Command			VarChar(MAX)

DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@PathAndFile				VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					SYSNAME
			,@central_server			SYSNAME

	EXEC DBAOps.dbo.dbasp_GetPaths  -- @verbose = 1
		 @DataPath			= @DataPath			 OUT
		,@LogPath			= @LogPath			 OUT
		,@BackupPathL		= @BackupPathL		 OUT
		,@BackupPathN		= @BackupPathN		 OUT
		,@BackupPathN2		= @BackupPathN2		 OUT
		,@DBASQLPath		= @DBASQLPath		 OUT
		,@SQLAgentLogPath	= @SQLAgentLogPath	 OUT
		,@DBAArchivePath	= @DBAArchivePath	 OUT
		,@EnvBackupPath		= @EnvBackupPath	 OUT
		,@SQLEnv			= @SQLEnv			 OUT
		,@CentralServerShare= @central_server	 OUT


	If NULLIF(@JobName,'') IS NULL
		SET @JobName = 'DynamicJob_' + CAST(NewID() AS VarChar(50));

	SET @LogFilePath = COALESCE(@LogFilePath,@SQLAgentLogPath)

	IF NULLIF(@LogFilePath,'') IS NULL
		SET @LogFilePath = @SQLAgentLogPath

	IF RIGHT(@LogFilePath,1) !='\'
		SET @LogFilePath = @LogFilePath + '\'


	IF NULLIF(@RunAt,'') IS NULL
		SET @RunAt = @@SERVERNAME;


	IF LEFT(@JobName,8) != 'XXX_DBA_'
		SET @JobName = 'XXX_DBA_' + @JobName;


	SET @JobName = @JobName +'_FROM_' + @@SERVERNAME


	-- ADD DYNAMIC LINKED SERVER
	IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
		EXEC ('master.dbo.sp_dropserver @server=N''DYN_DBA_RMT'', @droplogins=''droplogins''')

	EXEC ('sp_addlinkedserver @server=''DYN_DBA_RMT'',@srvproduct='''',@provider=''SQLNCLI'',@datasrc=''tcp:'+@RunAt+'''')
	EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc'', @optvalue=N''true''')
	EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc out'', @optvalue=N''true''')
	EXEC ('master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''DYN_DBA_RMT'',@useself=N''False'',@locallogin=null,@rmtuser=N''LinkedServer_User'',@rmtpassword=''4vnetonly''')


	BEGIN	-- CREATE JOB


		SET	@JobId = NULL


		-- DELETE JOB IF IT ALREADY EXISTS
		RAISERROR ('Deleting Dynamic Job "%s", if it already exists.',-1,-1,@JobName) WITH NOWAIT
		SET	@Command = 'DECLARE @JobId BINARY(16)
			SELECT @JobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''' + @JobName + '''
			IF (@JobId IS NOT NULL)
			EXEC msdb.dbo.sp_delete_job @JobId'
		EXEC (@Command) AT [DYN_DBA_RMT]


		-- CREATE JOB
		RAISERROR ('Creating Dynamic Job "%s".',-1,-1,@JobName) WITH NOWAIT
		SET @Command = 'EXEC msdb.dbo.sp_add_job @job_name=N''' + @JobName + ''',
				@enabled=1, @notify_level_eventlog=0, @notify_level_email=0,
				@notify_level_netsend=0, @notify_level_page=0, @delete_level=1,
				@description=N''Restore Database From Existing Server'',
				@category_name=N''[Uncategorized (Local)]'',
				@owner_login_name=N''sa'''
		EXEC (@Command) AT [DYN_DBA_RMT]


		RAISERROR('Getting JobID for new Job.',-1,-1) WITH NOWAIT
		SELECT @JobId = job_id
		FROM [DYN_DBA_RMT].msdb.dbo.sysjobs
		where name = @JobName
		--SELECT @JobId


		RAISERROR(' - Job Logging to %s%s.txt',-1,-1,@LogFilePath,@JobName) WITH NOWAIT


		-- ADD JOB STEP TO DYNAMIC JOB
		RAISERROR ('  - Adding Job Step 1 to Dynamic Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id='''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobId) AS Varchar(50))+''', @step_name=N''Dynamic Job Step 1'',
				@step_id=1,
				@cmdexec_success_code=0,
				@on_success_action=3,
				@on_success_step_id=0,
				@on_fail_action=2,
				@on_fail_step_id=0,
				@retry_attempts=0,
				@retry_interval=0,
				@os_run_priority=0, @subsystem=N''TSQL'',
				@command= '''+ REPLACE(@TSQL1,'''','''''')+''',
				@database_name=N''master'',
				@output_file_name=N''' +  COALESCE(@LogFilePath + @JobName,'xxx') +'.txt'',
				@flags=6'
		EXEC (@Command) AT [DYN_DBA_RMT]
		--exec dbo.dbasp_PrintLarge @Command


		IF NULLIF(@TSQL2,'') IS NULL
			SET @TSQL2 = 'SELECT @@SERVERNAME'


		-- ADD JOB STEP TO LOG BACKUP DATABASE
		RAISERROR ('  - Adding Job Step 2 to Dynamic Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id='''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobId) AS Varchar(50))+''', @step_name=N''Dynamic Job Step 2'',
				@step_id=2,
				@cmdexec_success_code=0,
				@on_success_action=1,
				@on_success_step_id=0,
				@on_fail_action=2,
				@on_fail_step_id=0,
				@retry_attempts=0,
				@retry_interval=0,
				@os_run_priority=0, @subsystem=N''TSQL'',
				@command= '''+ REPLACE(@TSQL2,'''','''''')+''',
				@database_name=N''master'',
				@output_file_name=N''' +  COALESCE(@LogFilePath + @JobName,'xxx') +'.txt'',
				@flags=6'
		EXEC (@Command) AT [DYN_DBA_RMT]
		--exec dbo.dbasp_PrintLarge @Command


		-- SET START STEP
		RAISERROR ('   - Setting Start Step for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_update_job @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobId) AS Varchar(50))+''', @start_step_id = 1'
		EXEC (@Command) AT [DYN_DBA_RMT]

		-- SET JOB SERVER
		RAISERROR ('   - Setting Job Server for Job.',-1,-1) WITH NOWAIT
		SET	@Command = 'EXEC msdb.dbo.sp_add_jobserver @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobId) AS Varchar(50))+''', @server_name = N''(local)'''
		EXEC (@Command) AT [DYN_DBA_RMT]

		-- START JOB
		RAISERROR ('    - Starting Dynamic Job "%s" On %s.',-1,-1,@JobName,@RunAt) WITH NOWAIT
		SET	@Command = 'exec msdb.dbo.sp_start_job @job_id = '''+CAST(CONVERT(UNIQUEIDENTIFIER,@JobId) AS Varchar(50))+''''
		EXEC (@Command) AT [DYN_DBA_RMT]


	END
END
GO
GRANT EXECUTE ON  [dbo].[RunAsyncAgentJob] TO [public]
GO
