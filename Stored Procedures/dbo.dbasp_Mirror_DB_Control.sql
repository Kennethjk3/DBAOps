SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Mirror_DB_Control]
	(
	@Function				VarChar(50)		= 'help'
	,@DBName				SYSNAME			= NULL
	,@FromServerName		SYSNAME			= NULL
	,@WitnessName			SYSNAME			= NULL
	,@FilePath				VarChar(2000)	= NULL
	,@Wait4All				BIT				= 0
	,@UseExistingBackups	bit				= 0
	,@DelExistingBackups	bit				= 0
	,@NoRestore				bit				= 0
	,@StatusDetails			bit				= 0
	,@OFFWithRecovery		bit				= 0
	)
AS


	SET NOCOUNT ON
	SET ANSI_NULLS ON
	SET ANSI_WARNINGS ON


	--------------------------------------------------
	-- DECLARE ALL cE VARIABLES AT HEAD OF PROCCESS --
	--------------------------------------------------
	DECLARE	@CMD				VARCHAR(8000)
		,@CMD2					VARCHAR(8000)
		,@DBN					sysname
		,@cEModule				sysname
		,@cECategory			sysname
		,@cEEvent				nVarChar(max)
		,@cEGUID				uniqueidentifier
		,@cEMessage				nvarchar(max)
		,@cERE_ForceScreen		BIT
		,@cERE_Severity			INT
		,@cERE_State			INT
		,@cERE_With				VarChar(2048)
		,@cEStat_Rows			BigInt
		,@cEStat_Duration		FLOAT
		,@cEMethod_Screen		BIT
		,@cEMethod_TableLocal	BIT
		,@cEMethod_TableCentral	BIT
		,@cEMethod_RaiseError	BIT
		,@cEMethod_Twitter		BIT
	--------------------------------------------------
	--           SET GLOBAL cE VARIABLES            --
	--------------------------------------------------
	SELECT	@cEModule		= 'dbasp_Mirror_DB_Control'
			,@cEGUID		= NEWID()


	SELECT	@cECategory		= 'STEP'
			,@cEEvent		= 'PARAMETER CHECKING'
			,@cEMessage		= 'STARTING'


	exec [dbo].[dbasp_LogEvent]
				 @cEModule
				,@cECategory
				,@cEEvent
				,@cEGUID
				,@cEMessage
				,@cEMethod_Screen = 1
				,@cEMethod_TableLocal = 1


	-- CHECK @FUNCTION PARAMETER
	IF @Function = 'help'
	BEGIN
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '---------- EXAMPLE SCRIPTS -----------',1,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--PAUSING MIRRORING ON ALL MIRRORED DATABASES--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''SUSPEND''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--PAUSING MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''SUSPEND''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--RESUME MIRRORING ON ALL MIRRORED DATABASES--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''RESUME''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--REMOVE MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''OFF''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--FAILOVER MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''FAILOVER''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--START MIRRORING A SINGLE DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''START''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''PrimaryDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@FromServerName = ''PrimaryServerName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--SHOW MIRRORING STATUS ON ALL MIRRORED DATABASES--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''STATUS''',4,0,1
		exec DBAOps.dbo.dbasp_print  '',1,0,1


		RETURN 0
	END

	IF @Function NOT IN ('SUSPEND','RESUME','OFF','START','STATUS','FAILOVER')
	BEGIN
		SELECT	@cECategory		= 'ERROR'
				,@cEEvent		= 'PARAMETER FAILED'
				,@cEMessage		= '@Function is not Valid'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		RETURN -1
	END


	IF @Function = 'Start' AND @FromServerName IS NULL
	BEGIN
		SELECT	@cECategory		= 'ERROR'
				,@cEEvent		= 'PARAMETER FAILED'
				,@cEMessage		= '@FromServerName MUST be specified if Function is "START"'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		RETURN -1
	END


	IF @Function = 'Start' AND COALESCE(PARSENAME(@FromServerName,5),PARSENAME(@FromServerName,4),PARSENAME(@FromServerName,3),PARSENAME(@FromServerName,2),PARSENAME(@FromServerName,1)) = @@SERVERNAME
	BEGIN
		SELECT	@cECategory		= 'ERROR'
				,@cEEvent		= 'PARAMETER FAILED'
				,@cEMessage		= 'This Script MUST NOT be run on the same server specified in the @FromServerName Property'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		RETURN -1
	END


	----------------------------------------------
	----------------------------------------------
	--		TODO:  ERROR CHECKS
	--
	--		CHECK IF @FromServerName IS VALID
	--		CHECK IF @DBName is Valid on remote server if START
	----------------------------------------------
	----------------------------------------------


	IF @DBName IS NOT NULL
	  AND @DBName NOT IN (select DB_NAME(database_id) FROM master.sys.database_mirroring WHERE mirroring_guid IS NOT NULL)
	  AND @Function != 'Start'
	BEGIN
		SELECT	@cECategory		= 'ERROR'
				,@cEEvent		= 'PARAMETER FAILED'
				,@cEMessage		= '@DBName is not a Mirrored Database'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		RETURN -1
	END


	SELECT	@cECategory		= 'STEP'
			,@cEEvent		= 'PARAMETER CHECKING'
			,@cEMessage		= 'DONE'


	exec [dbo].[dbasp_LogEvent]
				 @cEModule
				,@cECategory
				,@cEEvent
				,@cEGUID
				,@cEMessage
				,@cEMethod_Screen = 1
				,@cEMethod_TableLocal = 1


	IF @Function IN ('STATUS')
	BEGIN

		SELECT	@cECategory		= 'STEP'
				,@cEEvent		= 'FUNCTION ' + @Function
				,@cEMessage		= 'STARTING'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		-- RETURN THE STATUS OF EACH MIRRORED DATABASE HERE
		EXEC [DBAOps].[dbo].[dbasp_Mirror_DB_Status] @StatusDetails


		RETURN 0
	END


	---- CHECK IF RECENT OVERRIDE RECORD HAS BEN INSERTED
	--IF NOT EXISTS(select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'mirror_failover_override' and datediff(mi, convert(datetime,env_detail), getdate()) < 45)
	--BEGIN
	--	SELECT @CMD = 'DBA Error:  Override required.  Use: insert into DBAOps.dbo.Local_ServerEnviro values(''mirror_failover_override'', getdate())'
	--	RAISERROR(@CMD,16,-1) WITH LOG

	--	RETURN -1
	--END


	IF @Function IN ('SUSPEND','RESUME','OFF')
	BEGIN
		SELECT	@cECategory		= 'STEP'
				,@cEEvent		= 'FUNCTION ' + @Function
				,@cEMessage		= 'STARTING'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1

		-- =============================================
		DECLARE MirrorDBCursor CURSOR
		FOR
		select		DB_NAME(database_id)
		FROM		master.sys.database_mirroring
		WHERE		mirroring_guid IS NOT NULL
			AND		DB_NAME(database_id) = COALESCE(@DBName,DB_NAME(database_id)) -- IF @DBName IS NOT NULL JUST DO THE ONE DB SPECIFIED


		OPEN MirrorDBCursor
		FETCH NEXT FROM MirrorDBCursor INTO @DBN
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN

				SELECT	@CMD			= 'ALTER DATABASE ['+@DBN+'] SET PARTNER ' + @Function
						,@cECategory	= 'STEP'
						,@cEEvent		= @Function + ' MIRRORING ON ' + UPPER(@DBN)
						,@cEMessage		= @CMD


				EXEC [dbo].[dbasp_LogEvent]
							 @cEModule
							,@cECategory
							,@cEEvent
							,@cEGUID
							,@cEMessage
							,@cEMethod_Screen = 1
							,@cEMethod_TableLocal = 1

				exec DBAOps.dbo.dbasp_print	@CMD,1,0,1
				EXEC (@CMD)


				IF @OFFWithRecovery = 1 AND @Function = 'OFF'
				BEGIN
					IF (SELECT state_desc FROM sys.databases WHERE name = @DBN) = 'RESTORING'
					BEGIN
						SELECT	@CMD			= 'RESTORE DATABASE ['+@DBN+'] WITH RECOVERY'
								,@cECategory	= 'STEP'
								,@cEEvent		= 'RECOVER DATABASE ' + UPPER(@DBN)
								,@cEMessage		= @CMD


						EXEC [dbo].[dbasp_LogEvent]
									 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen = 1
									,@cEMethod_TableLocal = 1

						exec DBAOps.dbo.dbasp_print	@CMD,1,0,1
						EXEC (@CMD)
					END
				END
			END
			FETCH NEXT FROM MirrorDBCursor INTO @DBN
		END
		CLOSE MirrorDBCursor
		DEALLOCATE MirrorDBCursor
		-- =============================================

		RETURN 0
	END


	IF @Function IN ('START')
	BEGIN
		SELECT	@cECategory		= 'STEP'
				,@cEEvent		= 'FUNCTION ' + @Function
				,@cEMessage		= 'STARTING'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1


		-- ADD DYNAMIC LINKED SERVER SO PROCEDURE DOES NOT FAIL
		IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
			EXEC master.dbo.sp_dropserver @server=N'DYN_DBA_RMT', @droplogins='droplogins'

		EXEC sp_addlinkedserver @server='DYN_DBA_RMT',@srvproduct='',@provider='SQLNCLI',@datasrc=@@ServerName


		EXEC [DBAOps].[dbo].[dbasp_Mirror_DB]
				@DBName
				,@FromServerName
				,@WitnessName
				,@FilePath
				,@Wait4All
				,@UseExistingBackups
				,@DelExistingBackups
				,@NoRestore

		RETURN 0
	END


	IF @Function IN ('FAILOVER')
	BEGIN
		SELECT	@cECategory		= 'STEP'
				,@cEEvent		= 'FUNCTION ' + @Function
				,@cEMessage		= 'STARTING'


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1


		-- DISABLE LOCAL JOBS


		-- SET SAFETY FULL
		SET @CMD2 = 'USE MASTER; ALTER DATABASE [?] SET PARTNER SAFETY FULL'

		StartDBLoop:
		-- =============================================
		DECLARE MirrorDBCursor CURSOR
		FOR
		select		DB_NAME(database_id)
		FROM		master.sys.database_mirroring
		WHERE		mirroring_guid IS NOT NULL
			AND		DB_NAME(database_id) = COALESCE(@DBName,DB_NAME(database_id)) -- IF @DBName IS NOT NULL JUST DO THE ONE DB SPECIFIED


		OPEN MirrorDBCursor
		FETCH NEXT FROM MirrorDBCursor INTO @DBN
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				-- DETECT IF ON PRIMARY


				DECLARE @Role		SYSNAME
						,@Partner	SYSNAME


				SELECT	@Role		= mirroring_role_desc
						,@Partner	= DBAOps.dbo.dbaudf_ReturnPart(REPLACE(REPLACE(mirroring_partner_name,'TCP://',''),':','|'),1)
				FROM	sys.database_mirroring
				WHERE	DB_Name(database_id) = @DBN


				-- SET DYNAMIC LINKED SERVER IF NOT THE PRIMARY
				IF @Role = 'MIRROR'
				BEGIN
					IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
						EXEC ('master.dbo.sp_dropserver @server=N''DYN_DBA_RMT'', @droplogins=''droplogins''')

					EXEC ('sp_addlinkedserver @server=''DYN_DBA_RMT'',@srvproduct='''',@provider=''SQLNCLI'',@datasrc=''tcp:'+@Partner+'''')
					EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc'', @optvalue=N''true''')
					EXEC ('master.dbo.sp_serveroption @server=N''DYN_DBA_RMT'', @optname=N''rpc out'', @optvalue=N''true''')
					EXEC ('master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N''DYN_DBA_RMT'',@useself=N''False'',@locallogin=null,@rmtuser=N''LinkedServer_User'',@rmtpassword=''${{secrets.LINKEDSERVER_USER_PW}}''')
				END


				SELECT	@CMD			= REPLACE(@CMD2,'?',@DBN)
						,@cECategory	= 'STEP'
						,@cEEvent		= @Function + ' MIRRORING ON ' + UPPER(@DBN)
						,@cEMessage		= @CMD


				EXEC [dbo].[dbasp_LogEvent]
							 @cEModule
							,@cECategory
							,@cEEvent
							,@cEGUID
							,@cEMessage
							,@cEMethod_Screen = 1
							,@cEMethod_TableLocal = 1

				exec DBAOps.dbo.dbasp_print	@CMD,1,0,1
				IF @Role = 'MIRROR'
					EXEC (@CMD) AT DYN_DBA_RMT
				ELSE
					EXEC (@CMD)
			END
			FETCH NEXT FROM MirrorDBCursor INTO @DBN
		END
		CLOSE MirrorDBCursor
		DEALLOCATE MirrorDBCursor
		-- =============================================


		-- DO FAILOVER
		IF @CMD2 = 'USE MASTER; ALTER DATABASE [?] SET PARTNER SAFETY FULL'
		BEGIN
			WAITFOR DELAY '00:00:10'
			SET @CMD2 = 'USE MASTER; ALTER DATABASE [?] SET PARTNER FAILOVER'
			GOTO StartDBLoop
		END


		-- RUN TARGET CLEANUP

		-- ENABLE TARGET JOBS

		-- RESET LOCAL MAINTENANCE PLANS
		--exec DBAOps.dbo.dbasp_set_maintplans

		-- RESET TARGET MAINTENANCE PLANS
		--exec DYN_DBA_RMT.DBAOps.dbo.dbasp_set_maintplans

		-- RUN TARGET BACKUPS

		RETURN 0
	END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Mirror_DB_Control] TO [public]
GO
