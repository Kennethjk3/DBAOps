SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Logship_MS_Fix]
	(
	@DBName		SYSNAME
	,@FullReset	BIT		= 0
	,@ResetFromJob	BIT		= 0
	,@Verbose	INT		= 0
	,@OverrideXML	XML		= NULL OUTPUT
	)
AS


	/*


		-- ============================================================================================================
		--	Revision History
		--	Date		Author     				                     Desc
		--	==========	====================	=======================================================================
		--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
		--	04/02/2013	Steve Ledridge		Improved Calls AND logic AND made more portable FOR other servers.
		--	01/14/2014	Steve Ledridge		Modified to Support Multi-File Restores with new restore sproc
		--	01/24/2014	Joseph Brown		Modified @DBSources data for new server locations.
		--	03/26/2014	Steve Ledridge		Added entry for WCDSwork Database
		--	04/25/2014	Steve Ledridge		Added entry for ContributorSystemsContract Database
		--	09/05/2014	Steve Ledridge		Added all ASHBURN CRM Databases.
		-- ============================================================================================================
		-- ============================================================================================================


	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'EventServiceDB'
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'RightsPrice'
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'WCDS'
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'AssetUsage_Archive'
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ContributorSystemsContract'


	--EXAMPLES FOR EACH ASHBURN CRM DATABASES


	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix '${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix '${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix '${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM_Clone',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix '${{secrets.COMPANY_NAME}}_Images_US_Inc_Custom',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'MSCRM_CONFIG',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ReportServer',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ReportServer2',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ReportServerTempDB',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ReportServer2TempDB',1,0,1
	EXEC DBAOps.dbo.dbasp_Logship_MS_Fix 'ImportManager',1,0,1


	--DECLARE	@DBName		SYSNAME
	--	,@FullReset	BIT
	--	,@ResetFromJob	BIT
	--	,@CleanOnly	BIT


	--SELECT	@DBName		= 'EditorialSiteDB'
	--	,@FullReset	= 1
	--	,@ResetFromJob	= 0
	--	,@CleanOnly	= 0


	*/


	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF


	DECLARE		@MostRecent_Full	DATETIME
			,@MostRecent_Diff	DATETIME
			,@MostRecent_Log	DATETIME
			,@CMD			VARCHAR(8000)
			,@CMD2			VARCHAR(8000)
			,@CnD_CMD		VARCHAR(8000)
			,@COPY_CMD		VARCHAR(max)
			,@BackupPath		VARCHAR(max)
			,@RestorePath		VARCHAR(max)
			,@FileName		VARCHAR(MAX)
			,@AgentJob		SYSNAME
			,@ShareName		VarChar(500)
			,@LogPath		VarChar(100)
			,@DataPath		VarChar(100)
			,@CMD_TYPE		CHAR(3)
			,@errorcode		INT
			,@sqlerrorcode		INT
			,@DateModified		DATETIME
			,@Extension		VARCHAR(MAX)
			,@CopyStartTime		DateTime
			,@partial_flag		BIT
			,@RestoreOrder		INT
			,@syntax_out		VarChar(max)
			,@StandBy		VarChar(max)

	DECLARE		@SourceFiles		TABLE
			(
			[Mask]			[nvarchar](4000) NULL,
			[Name]			[nvarchar](4000) NULL,
			[FullPathName]		[nvarchar](4000) NULL,
			[Directory]		[nvarchar](4000) NULL,
			[Extension]		[nvarchar](4000) NULL,
			[DateCreated]		[datetime] NULL,
			[DateAccessed]		[datetime] NULL,
			[DateModified]		[datetime] NULL,
			[Attributes]		[nvarchar](4000) NULL,
			[Size]			[bigint] NULL
			)

	DECLARE		@nameMatches		TABLE (NAME VARCHAR(MAX))
	DECLARE		@CopyAndDeletes		TABLE (CnD_CMD VarChar(max))

	DECLARE		@DBSources		TABLE
			(
			DBName			SYSNAME
			,BackupPath		VARCHAR(8000)
			,AgentJob		VarChar(8000)
			)


	IF OBJECT_ID('tempdb..#filelist')	IS NOT NULL	DROP TABLE #filelist
	CREATE TABLE #filelist		(
					LogicalName NVARCHAR(128) NULL,
					PhysicalName NVARCHAR(260) NULL,
					type CHAR(1),
					FileGroupName NVARCHAR(128) NULL,
					SIZE NUMERIC(20,0),
					MaxSize NUMERIC(20,0),
					FileId BIGINT,
					CreateLSN NUMERIC(25,0),
					DropLSN NUMERIC(25,0),
					UniqueId VARCHAR(50),
					ReadOnlyLSN NUMERIC(25,0),
					ReadWriteLSN NUMERIC(25,0),
					BackupSizeInBytes BIGINT,
					SourceBlockSize INT,
					FileGroupId INT,
					LogGroupGUID VARCHAR(50) NULL,
					DifferentialBaseLSN NUMERIC(25,0),
					DifferentialBaseGUID VARCHAR(50),
					IsReadOnly BIT,
					IsPresent BIT,
					TDEThumbprint VARBINARY(32) NULL,
					New_PhysicalName  NVARCHAR(1000) NULL
					)


	INSERT INTO	@DBSources


	SELECT		'EditorialSiteDB'			,'\\EDSQLG0A\EDSQLG0A_backup\'			,'LSRestore_EDSQLG0A_EditorialSiteDB'				UNION ALL
	SELECT		'EventServiceDB'			,'\\EDSQLG0A\EDSQLG0A_backup\'			,'LSRestore_EDSQLG0A_EventServiceDB'				UNION ALL
	SELECT		'${{secrets.COMPANY_NAME}}_Master'				,'\\FREPSQLRYLA01\FREPSQLRYLA01_backup\'	,'LSRestore_FREPSQLRYLA01_${{secrets.COMPANY_NAME}}_Master'				UNION ALL
	SELECT		'GINS_Master'				,'\\FREPSQLRYLB01\FREPSQLRYLB01_backup\'	,'LSRestore_FREPSQLRYLB01_GINS_Master'				UNION ALL
	SELECT		'Gins_Integration'			,'\\FREPSQLRYLB01\FREPSQLRYLB01_backup\'	,'LSRestore_FREPSQLRYLB01_Gins_Integration'			UNION ALL
	SELECT		'RM_Integration'			,'\\FREPSQLRYLA01\FREPSQLRYLA01_backup\'	,'LSRestore_FREPSQLRYLB01_RM_Integration'			UNION ALL


	SELECT		'Product'				,'\\G1sqlB\G1SQLB$B_backup\'			,'LSRestore_G1SQLB\B_Product'					UNION ALL
	SELECT		'RightsPrice'				,'\\G1sqlB\G1SQLB$B_backup\'			,'LSRestore_G1SQLB\B_RightsPrice'				UNION ALL
	SELECT		'WCDS'					,'\\G1sqlA\G1SQLA$A_backup\'			,'LSRestore_G1SQLA\A_WCDS2'					UNION ALL
	SELECT		'WCDSwork'				,'\\G1sqlA\G1SQLA$A_backup\'			,'LSRestore_tcp:G1SQLA\A,1252_WCDSwork2'			UNION ALL
	SELECT		'AssetUsage_Archive'			,'\\G1sqlB\G1SQLB$B_backup\'			,'LSRestore_G1SQLB\B_AssetUsage_Archive'			UNION ALL
	SELECT		'ContributorSystemsContract'		,'\\SEAPCTBSQLA\SEAPCTBSQLA_backup\'		,'LSRestore_SEAPCTBSQLA_ContributorSystemsContract'		UNION ALL

	SELECT		'${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS'		,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS'		UNION ALL
	SELECT		'${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM'		,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM'		UNION ALL
	SELECT		'${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM_Clone'	,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM_Clone'	UNION ALL
	SELECT		'${{secrets.COMPANY_NAME}}_Images_US_Inc_Custom'		,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_${{secrets.COMPANY_NAME}}_Images_US_Inc_Custom'		UNION ALL
	SELECT		'MSCRM_CONFIG'				,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_MSCRM_CONFIG'				UNION ALL
	SELECT		'ReportServer'				,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_ReportServer'				UNION ALL
	SELECT		'ReportServer2'				,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_ReportServer2'				UNION ALL
	SELECT		'ReportServerTempDB'			,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_ReportServerTempDB'			UNION ALL
	SELECT		'ReportServer2TempDB'			,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_ReportServer2TempDB'			UNION ALL
	SELECT		'ImportManager'				,'\\SEAPCRMSQL1A\SEAPCRMSQL1A_backup\'		,'LSRestore_SEAPCRMSQL1A_ImportManager'


	SELECT		@DBName		= DBName
			,@BackupPath	= BackupPath
			,@RestorePath	= '\\'+ LEFT(@@ServerName,CHARINDEX('\',@@ServerName+'\')-1)+'\'+REPLACE(@@ServerName,'\','$')+'_backup\LogShip\'+@DBName
			,@AgentJob	= AgentJob
			,@COPY_CMD	= 'ROBOCOPY '+@BackupPath+'\ '+@RestorePath +'\'
			,@DataPath	= nullif(DBAOps.[dbo].[dbaudf_GetSharePath](DBAOps.[dbo].[dbaudf_getShareUNC]('mdf')),'Not Found')
			,@StandBy	= @DataPath + '\UNDO_' + @DBName + '.dat'
	FROM		@DBSources
	WHERE		DBName		= @DBName


	--SET @CMD = 'MD ' + @RestorePath + '\Processed\'
	--EXEC xp_CmdShell @CMD


	IF @DBName IS NULL
	BEGIN
		RAISERROR ('Process Not Configured for that Database, Sproc must be edited.',-1,-1) WITH NOWAIT
		--RETURN 99
	END


	-- Job Exists and Not being Run from inside of Job
	IF @ResetFromJob = 0 AND DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) != -2
	BEGIN
		IF DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) = 4
		BEGIN
			PRINT	'Agent Job: '+@AgentJob+' is running, Stopping it now.'
			EXEC	msdb.dbo.sp_stop_job @Job_Name = @AgentJob
		END


		PRINT	'Agent Job: '+@AgentJob+' is being disabled.'
		EXEC	msdb.dbo.sp_update_job @job_Name=@AgentJob, @enabled=0
	END


	--FULL RESET AND DATABASE DOES EXIST
	IF @FullReset = 1 AND DB_ID(@DBNAME) IS NOT NULL
	BEGIN
		Print '**** FULL RESET REQUESTED, '+UPPER(@DBNAME)+' DATABASE WILL BE DROPED AND RECREATED. ***'


		IF EXISTS(select * From master.sys.database_mirroring WHERE database_id = DB_ID(@DBName) AND mirroring_partner_name IS NOT NULL)
		BEGIN
			PRINT '  -- Turning Off Mirroring'
			SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER OFF;'
			EXEC (@CMD)
		END

		IF EXISTS(select * From master.sys.databases WHERE database_id = DB_ID(@DBName) AND state_desc IN('RECOVERING'))
		BEGIN
			PRINT '  -- Turning Off Mirroring'
			SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER OFF;'
			EXEC (@CMD)
		END

		IF EXISTS(select * From master.sys.databases WHERE database_id = DB_ID(@DBName) AND state_desc IN('RESTORING'))
		BEGIN
			PRINT '  -- Finishing Restore with Recovery'
			SET @CMD = 'RESTORE DATABASE ['+@DBName+'] WITH RECOVERY;'
			EXEC (@CMD)
		END

		PRINT '  -- Dropping Existing Database'
		SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE ['+@DBName+']'
		EXEC (@CMD)
	END


	IF DB_ID(@DBNAME) IS NULL
		EXEC msdb.dbo.sp_delete_database_backuphistory @DBNAME


	RAISERROR('  -- Building DB Restore''s',-1,-1) WITH NOWAIT


	EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
			@DBName			= @DBName
			,@Mode			= 'RD'
			,@Verbose		= @Verbose
			,@FullReset             = @FullReset
			,@LeaveNORECOVERY	= 1
			,@FilePath		= @BackupPath
			--,@WorkDir		= @RestorePath
			,@StandBy		= @StandBy
			,@syntax_out		= @syntax_out		OUTPUT
			,@OverrideXML		= @OverrideXML		OUTPUT


	RAISERROR('  -- Starting DB Restore''s',-1,-1) WITH NOWAIT


	EXEC (@syntax_out)
	--EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


	RAISERROR('  -- Done with DB Restore''s',-1,-1) WITH NOWAIT


	IF @ResetFromJob = 0 AND DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) != -2
	BEGIN
		DECLARE @AgentJob2 SYSNAME
		SET	@AgentJob2 = REPLACE(@AgentJob,'LSRestore_','LSCopy_')


		PRINT	'Agent Job: '+@AgentJob2+' is being re-enabled.'
		EXEC		msdb.dbo.sp_update_job @job_Name=@AgentJob2, @enabled=1
		EXEC		msdb.dbo.sp_start_job @Job_Name = @AgentJob2


		PRINT	'Agent Job: '+@AgentJob+' is being re-enabled.'
		EXEC		msdb.dbo.sp_update_job @job_Name=@AgentJob, @enabled=1
		EXEC		msdb.dbo.sp_start_job @Job_Name = @AgentJob
	END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Logship_MS_Fix] TO [public]
GO
