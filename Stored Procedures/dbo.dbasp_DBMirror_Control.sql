SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_DBMirror_Control]
	(
	@Function	VarChar(50)	= 'help'
	,@DBName	SYSNAME		= NULL
	,@ServerName	SYSNAME		= NULL
	,@BackupPath	VARCHAR(MAX)	= NULL
	,@RestorePath	VARCHAR(MAX)	= NULL
	,@TestCopyOnly	BIT		= 1
	)
AS


	SET NOCOUNT ON
	SET ANSI_NULLS ON
	SET ANSI_WARNINGS ON


	--------------------------------------------------
	-- DECLARE ALL cE VARIABLES AT HEAD OF PROCCESS --
	--------------------------------------------------
	DECLARE	@CMD			VARCHAR(8000)
		,@CMD2			VARCHAR(8000)
		,@DBN			sysname
		,@cEModule		sysname
		,@cECategory		sysname
		,@cEEvent		nVarChar(max)
		,@cEGUID		uniqueidentifier
		,@cEMessage		nvarchar(max)
		,@cERE_ForceScreen	BIT
		,@cERE_Severity		INT
		,@cERE_State		INT
		,@cERE_With		VarChar(2048)
		,@cEStat_Rows		BigInt
		,@cEStat_Duration	FLOAT
		,@cEMethod_Screen	BIT
		,@cEMethod_TableLocal	BIT
		,@cEMethod_TableCentral	BIT
		,@cEMethod_RaiseError	BIT
		,@cEMethod_Twitter	BIT
	--------------------------------------------------
	--           SET GLOBAL cE VARIABLES            --
	--------------------------------------------------
	SELECT	@cEModule		= 'dbasp_DBMirror_Control'
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
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''SUSPEND''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--PAUSING MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''SUSPEND''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--RESUME MIRRORING ON ALL MIRRORED DATABASES--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''RESUME''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--REMOVE MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''OFF''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--FAILOVER MIRRORING ON A SINGLE MIRRORED DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''FAILOVER''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''MirroredDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--START MIRRORING A SINGLE DATABASE--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''START''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@DBName = ''PrimaryDatabaseName''',4,0,1
		exec DBAOps.dbo.dbasp_print ',@ServerName = ''PrimaryServerName''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1
		exec DBAOps.dbo.dbasp_print '--SHOW MIRRORING STATUS ON ALL MIRRORED DATABASES--',1,0,1
		exec DBAOps.dbo.dbasp_print 'EXEC [DBAOps].[dbo].[dbasp_DBMirror_Control]',2,0,1
		exec DBAOps.dbo.dbasp_print '@Function = ''STATUS''',4,0,1
		exec DBAOps.dbo.dbasp_print '',1,0,1


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


		RETURN 0
	END


	-- CHECK IF RECENT OVERRIDE RECORD HAS BEN INSERTED
	IF NOT EXISTS(select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'mirror_failover_override' and datediff(mi, convert(datetime,env_detail), getdate()) < 45)
	BEGIN
		SELECT @CMD = 'DBA Error:  Override required.  Use: insert into DBAOps.dbo.Local_ServerEnviro values(''mirror_failover_override'', getdate())'
		RAISERROR(@CMD,16,-1) WITH LOG

		RETURN -1
	END


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
			AND	DB_NAME(database_id) = COALESCE(@DBName,DB_NAME(database_id)) -- IF @DBName IS NOT NULL JUST DO THE ONE DB SPECIFIED


		OPEN MirrorDBCursor
		FETCH NEXT FROM MirrorDBCursor INTO @DBN
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN

				SELECT	@CMD		= 'ALTER DATABASE ['+@DBN+'] SET PARTNER ' + @Function
					,@cECategory	= 'STEP'
					,@cEEvent	= @Function + ' MIRRORING ON ' + UPPER(@DBN)
					,@cEMessage	= @CMD


				EXEC [dbo].[dbasp_LogEvent]
							 @cEModule
							,@cECategory
							,@cEEvent
							,@cEGUID
							,@cEMessage
							,@cEMethod_Screen = 1
							,@cEMethod_TableLocal = 1

				PRINT	(@CMD)
				EXEC	(@CMD)
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

		EXEC [DBAOps].[dbo].[dbasp_Mirror_Database] @ServerName,@DBName,DEFAULT,DEFAULT,1,0


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
		SET @CMD2 = 'ALTER DATABASE [?] SET PARTNER SAFETY FULL'

		StartDBLoop:
		-- =============================================
		DECLARE MirrorDBCursor CURSOR
		FOR
		select		DB_NAME(database_id)
		FROM		master.sys.database_mirroring
		WHERE		mirroring_guid IS NOT NULL
			AND	DB_NAME(database_id) = COALESCE(@DBName,DB_NAME(database_id)) -- IF @DBName IS NOT NULL JUST DO THE ONE DB SPECIFIED


		OPEN MirrorDBCursor
		FETCH NEXT FROM MirrorDBCursor INTO @DBN
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN

				SELECT	@CMD		= REPLACE(@CMD2,'?',@DBN)
					,@cECategory	= 'STEP'
					,@cEEvent	= @Function + ' MIRRORING ON ' + UPPER(@DBN)
					,@cEMessage	= @CMD


				EXEC [dbo].[dbasp_LogEvent]
							 @cEModule
							,@cECategory
							,@cEEvent
							,@cEGUID
							,@cEMessage
							,@cEMethod_Screen = 1
							,@cEMethod_TableLocal = 1

				PRINT	(@CMD)
				EXEC	(@CMD)
			END
			FETCH NEXT FROM MirrorDBCursor INTO @DBN
		END
		CLOSE MirrorDBCursor
		DEALLOCATE MirrorDBCursor
		-- =============================================


		-- DO FAILOVER
		IF @CMD2 = 'ALTER DATABASE [?] SET PARTNER SAFETY FULL'
		BEGIN
			WAITFOR DELAY '00:00:10'
			SET @CMD2 = 'ALTER DATABASE [?] SET PARTNER FAILOVER'
			GOTO StartDBLoop
		END


		-- RUN TARGET CLEANUP

		-- ENABLE TARGET JOBS

		-- RESET LOCAL MAINTENANCE PLANS
		exec DBAOps.dbo.dbasp_set_maintplans

		-- RESET TARGET MAINTENANCE PLANS
		exec DYN_DBA_RMT.DBAOps.dbo.dbasp_set_maintplans

		-- RUN TARGET BACKUPS

		RETURN 0
	END
GO
GRANT EXECUTE ON  [dbo].[dbasp_DBMirror_Control] TO [public]
GO
