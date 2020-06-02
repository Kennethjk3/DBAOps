SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_format_BackupRestore]
						(
						@DBName					SYSNAME			= NULL
						,@NewDBName				SYSNAME			= NULL
						,@Mode					CHAR(2)			= NULL

						,@ForceEngine			SYSNAME			= NULL
						,@ForceSetSize			INT				= NULL
						,@ForceCompression		BIT				= NULL
						,@ForceChecksum			BIT				= NULL
						,@ForceB2Null			BIT				= NULL


						,@FilePath				VarChar(MAX)	= NULL
						,@ForceFileName			VarChar(MAX)	= NULL
						,@FileGroups			VarChar(MAX)	= NULL
						,@FromServer			SYSNAME			= NULL
						,@WorkDir				VarChar(MAX)	= NULL
						,@DeleteWorkFiles		BIT				= 1
						,@SetName				VarChar(MAX)	= NULL
						,@SetDesc				VarChar(MAX)	= NULL

						,@CopyOnly				BIT				= 0
						,@RestoreToDateTime		DateTime		= NULL
						,@LeaveNORECOVERY		BIT				= 0
						,@NoFullRestores		BIT				= 0
						,@NoLogRestores			BIT				= 0
						,@NoDifRestores			BIT				= 0
						,@FullReset				BIT				= 0
						,@IgnoreSpaceLimits		BIT				= 0


						,@IgnoreMaintOvrd		BIT				= 0
						,@IgnoreB2NullOvrd		BIT				= 0


						,@IsBaseline			BIT				= 0
						,@OverrideXML			XML				= NULL OUTPUT


						,@Verbose				INT				= 1
						,@syntax_out			VarChar(max)	OUTPUT
						,@IncludeSubDir			BIT				= 0
						,@StandBy				VarChar(max)	= NULL
						,@BufferCount			INT				= NULL
						,@MaxTransferSize		INT				= NULL
						,@UseTryCatch			BIT				= 0
						,@UseGO					BIT				= 0
						,@ForceBHLID			INT				= NULL
						--,@status_out			XML				= NULL OUTPUT
						,@FP					BIT				= 0
						)


/*********************************************************
 **  Stored Procedure dbasp_Format_BackupRestore
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 08, 2013
 **
 **
 **  Description: Creates proper syntax for backup and restore processing.
 **
 **
 **  This proc accepts the following input parameters:
 **	PARAMETER				DESCRIPTION											USED IN	  BACKUP	  RESTORE
 **	-----------------------	--------------------------------------------------     		  ------	  -------
 **	@DBName: (REQ)		Database name														X			X
 **	@NewDBName			Restore TO DBName																X
 **
 **	@Mode: (REQ)		'BF' Backup FULL													X
 **						'BD' Backup DIFFERENTIAL											X
 **						'BL' Backup LOG														X
 **						'RD' Restore DATABASE															X
 **						'HO' Restore (Header Only)														X
 **						'FO' Restore (Filelist Only)													X
 **						'LO' Restore (Label Only)														X
 **						'VO' Restore (Verify Only)														X
 **
 **	@ForceEngine:		'MSSQL' or 'REDGATE' Forces specific Engine to be Used				X			X
 **	@ForceSetSize: 		Force Backup to create specific Number of Files						X
 ** @ForceCompression:	0 = no compression  1 = compression NULL = Let it decide			X
 ** @ForceChecksum:		0 = no Checksum  1 = with Checksum NULL = Let it decide				X			X
 **
 **	@FilePath: 			UNC/Drive Path to Backup Files To or Restore Backup Files From		X			X
 **
 **	@ForceFileName: 	Override output file name											X			X
 **	@FileGroups: 		Filegroup names to include in BKUP/RSTR	Proccess					X			X
 **	@FromServer			Server to get the Backup Files From (_Backup Share)					X
 **	@WorkDir			Copy Files to this Directory Before Restoring									X
 **
 **	@SetName: 			Backup Set Name														X
 **	@SetDesc: 			Backup Set Description												X
 **
 **	WARNING:			BufferCount and MaxTransferSize values can cause Memory Errors
 **						The total space used by the buffers is determined by:
 **							buffercount * maxtransfersize * DB_Data_Devices
 **						blogs.msdn.com/b/sqlserverfaq/archive/2010/05/06/incorrect-buffercount-data-transfer-option-can-lead-to-oom-condition.aspx
 **
 **	@BufferCount		If Specified, Forces Value to be used								X			X
 **	@MaxTransferSize	If Specified, Forces Value to be used								X			X
 **
 **
 ** @CopyOnly:			0 = no CopyOnly  1 = with CopyOnly									X
 **	@RestoreToDateTime	Restore to a specific point in time												X
 **	@LeaveNORECOVERY	Leave Database in Recovery Mode When Done										X
 **	@NoLogRestores		Do Not Create Restore Script For Log Backups									X
 **	@NoDifRestores		Do Not Create Restore Script For Diff Backups									X
 **	@FullReset			Wipe Out existing database and start from scratch								X
 **	@IgnoreSpaceLimits	Generate Restore Script even if there is not enough room to run					X
 **	@OverrideXML		Force Files to be restored to specific locations								X
 **
 **	'<RestoreFileLocations>
 **	  <Override LogicalName="StackFactors" PhysicalName="I:\Data\StackFactors.mdf" New_PhysicalName="X:\MSSQL\Data\XXX_StackFactors_data.mdf" />
 **	  <Override LogicalName="StackFactors_log" PhysicalName="J:\Log\StackFactors_log.ldf" New_PhysicalName="X:\MSSQL\Log\XXX_StackFactors_log.ldf" />
 **	</RestoreFileLocations>'
 **
 **	@Verbose			-1=NO NOUTPUT		0=ONLY ERRORS									X			X
 **						1=INFO MESSAGES		2=INFO AND OUTPUT								X			X
 **
 **	@syntax_out		OUTPUT PARAMETER CONTAINING FINAL SCRIPT								X			X
 ***************************************************************/
AS
	SET NOCOUNT ON
	SET ANSI_NULLS ON
	SET ANSI_WARNINGS ON
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	2013-08-08	SteveL					Created
--	2014-03-25	Steve Ledridge			Modified Line 919 no set the Backup Timestamp to be the minimum of all files in a single mask
--	2014-08-01	Steve Ledridge			Modified Maximum Limit to Backup Files to be 32 since we have experienced problems at 64.
--	2014-09-30	Steve Ledridge			Modified Usage for Log shipping. Dont delete needed logs from list if nofull and/or nodiff and not full reset
--	2014-10-28	Steve Ledridge			Added Parameters for @MaxTransferSize and @BufferCount to be used for both Backup and Restore Database scripts.
--	2015-01-28	Steve Ledridge			1) Added the @UseTryCatch Parameter which causes all generated backup and restore commands to be wraped in individual
--											- Try Catch blocks. This prevents a single failure to prevent the rest from being attempted.
--										2) Added Try/Catch Blocks to calls to check backup files so that locked or damaged files do not stop the entire process.
--										3) Fixed problem where exclusion of already applied logs was not working.
--	2015-03-23	Steve Ledridge			Modified code to Drop Database and Restore History for FullReset
--	2015-05-25	Steve Ledridge			Code for new function dbaudf_GetSharePath2.
--	2016-02-16	Steve Ledridge			Fixed error in getting NDF Path.
--	2016-05-03	Steve Ledridge			Commented out section to DELETE ALL PREVIOUSLY APPLIED LOG FILES UNLESS A FULL RESET
--											- This section was passing up log files when backups were taken in diferent time zones.
--	2016-10-19	Steve Ledridge			Added @DeleteWorkFiles parameter to prevent the deletion if needed.
--	2017-06-06	Steve Ledridge			Modified Sproc so that it would work with Idera SQLSafe Backups.
--	======================================================================================


	BEGIN	-- VARIABLE AND TEMP TABLE DECLARATIONS


		DECLARE	@BackupEngine			VarChar(50)
				,@BackupTimeStamp		DATETIME
				,@BackupType			VarChar(10)
				,@CMD					VARCHAR(MAX)
				,@CMD2					VARCHAR(MAX)
				,@CMD3					NVARCHAR(4000)
				,@CMD4					NVARCHAR(4000)
				,@ColID					INT
				,@ColName1				SYSNAME
				,@ColName2				SYSNAME
				,@ColName3				SYSNAME
				,@ColName4				SYSNAME
				,@ColName5				SYSNAME
				,@ColName6				SYSNAME
				,@ColName7				SYSNAME
				,@ColName8				SYSNAME
				,@ColName9				SYSNAME
				,@ColumnName			SYSNAME
				,@ColumnSize			INT
				,@Compression			tinyint
				,@CRLF					CHAR(2)
				--,@DataPath				nVarChar(512)
				,@diffPrediction		int
				,@DriveFreeSpace		BIGINT
				,@DriveLetter			SYSNAME
				,@ExistingSize			BIGINT
				,@Extension				VarChar(50)
				,@FGID					INT
				,@FileGroup				SYSNAME
				,@FileName				VarChar(MAX)
				,@FileNameSet			VarChar(MAX)
				,@FilesRestored			INT
				,@FMT1					VarChar(max)
				,@FMT2					VarChar(max)
				,@FullPathName			VarChar(max)
				,@HeaderLine			VarChar(max)
				,@Init					BIT
				,@LogicalName			SYSNAME
				--,@LogPath				nVarChar(512)
				,@BackupPath			nVarChar(512)
				,@MachineName			SYSNAME
				,@NDFPath				VarChar(500)
				,@NewPhysicalName		VarChar(8000)
				,@NOW					VarChar(20)
				,@partial_flag			BIT
				,@RedGate				BIT
				,@RedGateInstalled		BIT
				,@Idera					BIT
				,@IderaInstalled		BIT
				,@RestoreOrder			INT
				,@ServerName			SYSNAME
				,@SetNumber				INT
				,@SetSize				INT
				,@Size					BIGINT
				,@SkipFlag				bit
				,@srvprop				Char(5)
				,@Stats					INT
				,@TBL					VarChar(max)
				,@VersionBuild			INT
				,@VersionMajor			INT
				,@VersionMinor			INT
				,@XML					XML
				,@xtype					INT
				,@RevOrder				INT
				,@Replace1				VarChar(max)
				,@Replace2				VarChar(max)
				,@FN					VarChar(max)
				,@B2N					VarChar(50)  = ''
				--,@SQLEnv				SYSNAME
				,@NotFirstInChain		bit = 0

DECLARE			@DataPath					VarChar(8000)
				,@LogPath					VarChar(8000)
				,@BackupPathL				VarChar(8000)
				,@BackupPathN				VarChar(8000)
				,@BackupPathN2				VarChar(8000)
				,@BackupPathA				VarChar(8000)
				,@DBASQLPath				VarChar(8000)
				,@SQLAgentLogPath			VarChar(8000)
				,@DBAArchivePath			VarChar(8000)
				,@EnvBackupPath				VarChar(8000)
				,@SQLEnv					VarChar(10)	
				,@RootNetworkBackups		VarChar(8000)	
				,@RootNetworkFailover		VARCHAR(8000)	
				,@RootNetworkArchive		VARCHAR(8000)	
				,@RootNetworkClean			VARCHAR(8000)


			-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
			EXEC DBAOps.dbo.dbasp_GetPaths
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
				,@Verbose				= @Verbose
				,@FP					= @FP				

	IF @Verbose > 1
		SELECT	 @DataPath				[@DataPath]		
				,@LogPath				[@LogPath]			
				,@BackupPathL			[@BackupPathL]		
				,@BackupPathN			[@BackupPathN]		
				,@BackupPathN2			[@BackupPathN2]
				,@BackupPathA			[@BackupPathA]		
				,@DBASQLPath			[@DBASQLPath]		
				,@SQLAgentLogPath		[@SQLAgentLogPath]	
				,@DBAArchivePath		[@DBAArchivePath]	
				,@EnvBackupPath			[@EnvBackupPath]	
				,@SQLEnv				[@SQLEnv]
				,@RootNetworkBackups	[@RootNetworkBackups]	
				,@RootNetworkFailover	[@RootNetworkFailover]	
				,@RootNetworkArchive	[@RootNetworkArchive]	
				,@RootNetworkClean		[@RootNetworkClean]		
	


		DECLARE	@VDR		TABLE	-- ValidDateRanges
				(
				FileGroupName			SYSNAME NULL,
				BackupDateRange_Start	DATETIME,
				BackupDateRange_End		DATETIME
				)

		DECLARE	@SF		TABLE	-- SourceFiles
				(
				[Mask]					[nvarchar](4000) NULL,
				[Name]					[nvarchar](4000) NULL,
				[DBName]				SYSNAME NULL,
				[BackupTimeStamp]		DATETIME NULL,
				[BackupType]			[nvarchar](10) NULL,
				[BackupEngine]			VarChar(50) NULL,
				[BackupSetNumber]		INT NULL,
				[BackupSetSize]			INT NULL,
				[BatchHistoryLogID]		INT NULL,
				[FileGroup]				SYSNAME NULL,
				[FullPathName]			[nvarchar](4000) NULL,
				[Directory]				[nvarchar](4000) NULL,
				[Extension]				[nvarchar](4000) NULL,
				[DateCreated]			[datetime] NULL,
				[DateAccessed]			[datetime] NULL,
				[DateModified]			[datetime] NULL,
				[Attributes]			[nvarchar](4000) NULL,
				[Size]					[bigint] NULL
				)

		DECLARE	@RC		TABLE
				(
				BackupType				smallint
				,FirstLSN				numeric(25,0)
				,LastLSN				numeric(25,0)
				,DatabaseBackupLSN		numeric(25,0)
				,BackupFileName			[nvarchar](4000)
				,FileGroupName			NVARCHAR(128) NULL
				,[ReverseOrder]			INT
				)

		DECLARE	@HL		TABLE	-- HeaderList
				(
				BackupName				nvarchar(128),
				BackupDescription		nvarchar(255) ,
				BackupType				smallint ,
				ExpirationDate			datetime ,
				Compressed				bit ,
				Position				smallint ,
				DeviceType				tinyint ,
				UserName				nvarchar(128) ,
				ServerName				nvarchar(128) ,
				DatabaseName			nvarchar(128) ,
				DatabaseVersion			int ,
				DatabaseCreationDate	datetime ,
				BackupSize				numeric(20,0) ,
				FirstLSN				numeric(25,0) ,
				LastLSN					numeric(25,0) ,
				CheckpointLSN			numeric(25,0) ,
				DatabaseBackupLSN		numeric(25,0) ,
				BackupStartDate			datetime ,
				BackupFinishDate		datetime ,
				SortOrder				smallint ,
				CodePage				smallint ,
				UnicodeLocaleId			int ,
				UnicodeComparisonStyle	int ,
				CompatibilityLevel		tinyint ,
				SoftwareVendorId		int ,
				SoftwareVersionMajor	int ,
				SoftwareVersionMinor	int ,
				SoftwareVersionBuild	int ,
				MachineName				nvarchar(128) ,
				Flags					int ,
				BindingID				uniqueidentifier ,
				RecoveryForkID			uniqueidentifier ,
				Collation				nvarchar(128) ,
				FamilyGUID				uniqueidentifier ,
				HasBulkLoggedData		bit ,
				IsSnapshot				bit ,
				IsReadOnly				bit ,
				IsSingleUser			bit ,
				HasBackupChecksums		bit ,
				IsDamaged				bit ,
				BeginsLogChain			bit ,
				HasIncompleteMetaData	bit ,
				IsForceOffline			bit ,
				IsCopyOnly				bit ,
				FirstRecoveryForkID		uniqueidentifier ,
				ForkPointLSN			numeric(25,0) NULL,
				RecoveryModel			nvarchar(60) ,
				DifferentialBaseLSN		numeric(25,0) NULL,
				DifferentialBaseGUID	uniqueidentifier ,
				BackupTypeDescription	nvarchar(60) ,
				BackupSetGUID			uniqueidentifier NULL ,
				CompressedBackupSize	bigint NULL,
				containment				bit,
				BackupFileName			[nvarchar](4000) NULL,
				[BackupDateRange_Start]	datetime NULL,
				[BackupDateRange_End]	datetime NULL,
				[BackupChainStartDate]	datetime NULL,
				[BackupLinkStartDate]	datetime NULL
				)

		DECLARE	@FL		TABLE	-- FileList
				(
				LogicalName				NVARCHAR(128) NULL,
				PhysicalName			NVARCHAR(260) NULL,
				type					CHAR(1),
				FileGroupName			NVARCHAR(128) NULL,
				SIZE					NUMERIC(20,0),
				MaxSize					NUMERIC(20,0),
				FileId					BIGINT,
				CreateLSN				NUMERIC(25,0),
				DropLSN					NUMERIC(25,0),
				UniqueId				VARCHAR(50),
				ReadOnlyLSN				NUMERIC(25,0),
				ReadWriteLSN			NUMERIC(25,0),
				BackupSizeInBytes		BIGINT,
				SourceBlockSize			INT,
				FileGroupId				INT,
				LogGroupGUID			VARCHAR(50) NULL,
				DifferentialBaseLSN		NUMERIC(25,0),
				DifferentialBaseGUID	VARCHAR(50),
				IsReadOnly				BIT,
				IsPresent				BIT,
				TDEThumbprint			NVARCHAR(128) NULL,
				New_PhysicalName		NVARCHAR(1000) NULL,
				BackupFileName			NVARCHAR(4000) NULL
				)


		--If Table already exists, USE IT
		IF OBJECT_ID('tempdb..#AGInfo') IS NULL
		BEGIN
			CREATE TABLE #AGInfo ([DBName] sysname,[AGName] SYSNAME, [primary_replica] sysname)


			IF @@microsoftversion / 0x01000000 >= 11
			IF SERVERPROPERTY('IsHadrEnabled') = 1
			BEGIN
				INSERT INTO #AGInfo
				SELECT		DISTINCT
							dbcs.database_name [DBName],AG.Name [AGName],primary_replica
				FROM		master.sys.availability_groups AS AG
				LEFT JOIN	master.sys.availability_replicas AS AR
					ON		AG.group_id = AR.group_id
				LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					ON		AR.replica_id = dbcs.replica_id
				LEFT JOIN	sys.dm_hadr_availability_group_states ags
					ON		ags.group_id = ag.group_id
				WHERE		db_id(dbcs.database_name) IS NOT NULL
					AND		AG.Name IS NOT NULL
			END
		END

		DROP TABLE IF EXISTS #FLX
		DROP TABLE IF EXISTS #Fgrps
		DROP TABLE IF EXISTS #FGs
		DROP TABLE IF EXISTS #TMP1
		DROP TABLE IF EXISTS #TMP2
		DROP TABLE IF EXISTS #TMP3
		DROP TABLE IF EXISTS #TMP4
		DROP TABLE IF EXISTS #TMP5
		DROP TABLE IF EXISTS #DBFileSpaceCheck
		DROP TABLE IF EXISTS #FLst
		DROP TABLE IF EXISTS #FLst_Last


		CREATE TABLE	#FGs
				(
				id					INT
				,name				SYSNAME
				,size				DECIMAL(15, 2)
				)


		CREATE TABLE	#FLst
				(
				LogicalName				NVARCHAR(128) NULL,
				PhysicalName			NVARCHAR(260) NULL,
				type					CHAR(1),
				FileGroupName			NVARCHAR(128) NULL,
				SIZE					NUMERIC(20,0),
				MaxSize					NUMERIC(20,0),
				FileId					BIGINT,
				CreateLSN				NUMERIC(25,0),
				DropLSN					NUMERIC(25,0),
				UniqueId				VARCHAR(50),
				ReadOnlyLSN				NUMERIC(25,0),
				ReadWriteLSN			NUMERIC(25,0),
				BackupSizeInBytes		BIGINT,
				SourceBlockSize			INT,
				FileGroupId				INT,
				LogGroupGUID			VARCHAR(50) NULL,
				DifferentialBaseLSN		NUMERIC(25,0),
				DifferentialBaseGUID	VARCHAR(50),
				IsReadOnly				BIT,
				IsPresent				BIT,
				TDEThumbprint			NVARCHAR(128) NULL,
				New_PhysicalName		NVARCHAR(1000) NULL,
				BackupFileName			nvarchar(4000) NULL
				)


	END	-- VARIABLE AND TEMP TABLE DECLARATIONS


	BEGIN	-- VARIABLE INITIALIZATIONS AND PARAMETER CHECKING

		IF nullif(@syntax_out,'') IS NOT NULL
			SET @NotFirstInChain = 1

		If @Mode not in ('BF', 'BD', 'BL', 'RD', 'HO', 'FO', 'LO', 'VO')
		BEGIN
			SELECT	@CMD	= 'DBA WARNING: Invalid @Mode input parm.  Must be in:'
					+@CRLF	+'	''BF'' = Backup Full'
					+@CRLF	+'	''BD'' = Backup Differential'
					+@CRLF	+'	''BL'' = Backup Log'
					+@CRLF	+'	''RD'' = Restore Database'
					+@CRLF	+'	''HO'' = Restore Header Only'
					+@CRLF	+'	''FO'' = Restore File List Only'
					+@CRLF	+'	''LO'' = Restore Label Only'
					+@CRLF	+'	''VO'' = Restore Verify Only'

			PRINT ''
			RAISERROR(@CMD,-1,-1) WITH NOWAIT
			GOTO label99
		END


		IF @Mode in ('BF', 'BD', 'BL') AND DB_ID(@DBName) IS NULL
		   BEGIN
			PRINT ''
			RAISERROR('DBA WARNING: Invalid @DBName input parm: DBName must Exist to Create Backup Script.',-1,-1) WITH NOWAIT
			GOTO label99
		   END


		IF @Mode NOT in ('BF', 'BD', 'BL') AND NULLIF(@DBName,'') IS NULL
		   BEGIN
			PRINT ''
			RAISERROR('DBA WARNING: Invalid @DBName input parm: DBName must Exist to Create Backup Script.',-1,-1) WITH NOWAIT
			GOTO label99
		   END


		IF	@Mode = 'BF' AND EXISTS (SELECT 1 FROM dbo.Local_Control WHERE subject = 'backup_by_filegroup' AND Detail01 = rtrim(@DBname))
		BEGIN
			IF @FileGroups = 'NONE'
			BEGIN
				RAISERROR('  -- "backup_by_filegroup" ignored because @FileGroups = "NONE"',-1,-1) WITH NOWAIT
				SET @FileGroups = NULL
			END
			ELSE IF @FileGroups IS NULL
			BEGIN
				RAISERROR('  -- "backup_by_filegroup" is set for this database',-1,-1) WITH NOWAIT
				SET @FileGroups = 'ALL'
			END
			ELSE
				RAISERROR('  -- "backup_by_filegroup" ignored because @FileGroups was used',-1,-1) WITH NOWAIT
		END

--SELECT @FilePath, DBAOps.dbo.dbaudf_GetFileProperty(@ForceFileName,'file','valid')

		IF @FromServer	IS NOT NULL
			SET @FilePath = REPLACE(@BackupPathN,DBAOps.dbo.dbaudf_GetLocalFQDN()+'\','') + @FromServer + '\'

--SELECT @FilePath,DBAOps.dbo.dbaudf_GetFileProperty(@ForceFileName,'file','DirectoryName')

		SELECT	 @NOW			= REPLACE(REPLACE(REPLACE(CONVERT(VarChar(50),getdate(),120),'-',''),':',''),' ','')
				,@NdfPath		= @DataPath
				,@FilePath		= COALESCE	(
											NULLIF(@FilePath,'')
											,NULLIF(REPLACE(@ForceFileName,[DBAOps].[dbo].[dbaudf_GetFileFromPath](@ForceFileName),''),'')
											,@BackupPathN
											,@BackupPathN2
											,@BackupPathL
											)

				-- CLEAN UP PATH NAMES AND MAKE SURE THEY ALL END WITH "\"
				,@DataPath		= @DataPath	+ CASE WHEN RIGHT(@DataPath,1)	= '\' THEN '' ELSE '\' END
				,@NdfPath		= @NdfPath	+ CASE WHEN RIGHT(@NdfPath,1)	= '\' THEN '' ELSE '\' END
				,@LogPath		= @LogPath	+ CASE WHEN RIGHT(@LogPath,1)	= '\' THEN '' ELSE '\' END
				,@FilePath		= @FilePath	+ CASE WHEN RIGHT(@FilePath,1)	= '\' THEN '' ELSE '\' END


				,@FilesRestored	= 0
				,@NewDBName		= COALESCE(@NewDBName,@DBName)
				,@Init			= 1
				,@Stats			= 1
				,@CRLF			= CHAR(13)+CHAR(10)

				,@MachineName		= CAST(SERVERPROPERTY ('MachineName') AS SYSNAME)
				,@ServerName		= CAST(SERVERPROPERTY ('ComputerNamePhysicalNetBIOS') AS SYSNAME)

				,@VersionMajor		= CAST(REVERSE(PARSENAME(REVERSE(CAST(SERVERPROPERTY ('productversion') AS SYSNAME)),1))AS Int)
				,@VersionMinor		= CAST(REVERSE(PARSENAME(REVERSE(CAST(SERVERPROPERTY ('productversion') AS SYSNAME)),2))AS Int)
				,@VersionBuild		= CAST(REVERSE(PARSENAME(REVERSE(CAST(SERVERPROPERTY ('productversion') AS SYSNAME)),3))AS Int)

				,@SetName		= COALESCE(@SetName,@ForceFileName,'')
				,@SetDesc		= COALESCE(@SetDesc,@ForceFileName,'')


--SELECT @FilePath

		IF @Verbose >= 1
			RAISERROR('    -- Using File Path: %s',-1,-1,@FilePath) WITH NOWAIT


		IF @DataPath IS NULL AND @Mode NOT IN ('BF', 'BD', 'BL')
		BEGIN
			PRINT ''
			RAISERROR('    -- DBA ERROR: THE DBA "_MDF" SHARE DOES NOT EXIST OR IS INVALID.',-1,-1) WITH NOWAIT
			GOTO label99
		END


		IF @LogPath IS NULL AND @Mode NOT IN ('BF', 'BD', 'BL')
		BEGIN
			PRINT ''
			RAISERROR('    -- DBA ERROR: THE DBA "_LDF" SHARE DOES NOT EXIST OR IS INVALID.',-1,-1) WITH NOWAIT
			GOTO label99
		END


		-- IS REDGATE INSTALLED
		IF OBJECT_ID('master.dbo.sqlbackup') IS NULL
			SELECT	@RedGateInstalled	= 0
		ELSE
			SELECT	@RedGateInstalled	= 1


		-- IS IDERA SQLSAFE INSTALLED
		IF OBJECT_ID('master.dbo.xp_ss_backup') IS NULL
			SELECT	@IderaInstalled	= 0
		ELSE
			SELECT	@IderaInstalled	= 1


		IF @ForceEngine = 'IDERA' AND @IderaInstalled = 0
		BEGIN
			PRINT ''
			RAISERROR('    -- DBA ERROR: @ForceEngine PARAMETER SPECIFIED "IDERA" BUT IDERA SQLSAFE IS NOT INSTALLED.',-1,-1) WITH NOWAIT
			GOTO label99
		END


		IF @ForceEngine = 'REDGATE' AND @RedGateInstalled = 0
		BEGIN
			PRINT ''
			RAISERROR('    -- DBA ERROR: @ForceEngine PARAMETER SPECIFIED "REDGATE" BUT REDGATE IS NOT INSTALLED.',-1,-1) WITH NOWAIT
			GOTO label99
		END


		-- CAN SERVER USE MICROSOFT COMPRESSION
		IF (@VersionMajor = 10 AND CAST(SERVERPROPERTY ('Edition') AS SYSNAME) LIKE 'Enterprise%')	-- SQL2008 Enterprise Edition
		 OR (@VersionMajor = 10 AND @VersionMinor >= 50)											-- SQL2008 R2 +
		 OR (@VersionMajor > 10)																	-- SQL2012 +
			SET @Compression = 1
		ELSE
			SET @Compression = 0


		If @Compression = 1
		BEGIN
			IF @DBName IN ('master','model','msdb','temp')
				SET @Compression = 0


			-- OVERRIDE WITH THE FORCED VALUE IF NOT NULL
			SET	@Compression = COALESCE(@ForceCompression,@Compression)
		END
		ELSE IF @ForceCompression = 1
		BEGIN
			PRINT ''
			RAISERROR('    -- DBA ERROR: @ForceCompression PARAMETER SPECIFIED "1" BUT MSSQL COMPRESSION IS NOT AVAILABLE ON THIS SQL VERSION.',-1,-1) WITH NOWAIT
			GOTO label99
		END


		SELECT	DriveLetter
				,CAST(CAST(TotalSize AS NUMERIC(38,10))/POWER(1024.0,3) AS NUMERIC(38,2)) SizeGB
				,CAST(CAST(AvailableSpace AS NUMERIC(38,10))/POWER(1024.0,3) AS NUMERIC(38,2)) AvailableGB
				,CAST(CAST(FreeSpace AS NUMERIC(38,10))/POWER(1024.0,3) AS NUMERIC(38,2)) FreeGB
				,DriveType
				,FileSystem
				,IsReady
				,VolumeName
				,RootFolder
		INTO		#TMP1
		FROM		[dbo].[dbaudf_ListDrives]()


	END	-- VARIABLE INITIALIZATIONS AND PARAMETER CHECKING


	IF	-- SCRIPT DATABASE BACKUPS
	@Mode IN ('BF','BD','BL')
	BEGIN	-- SCRIPT BACKUPS
		IF [dbo].[dbaudf_GetDBMaint](@DBName) = 1 AND @IgnoreMaintOvrd = 0
		BEGIN
			RAISERROR('    -- %s is in Maintenance Mode, No Backups can be performed unless...',-1,-1,@DBName) WITH NOWAIT
			RAISERROR('      -- Rerun dbasp_format_BackupRestore with @IgnoreMaintOvrd=1 ',-1,-1) WITH NOWAIT
			RAISERROR('      -- or turn off Maintenance Mode with...',-1,-1) WITH NOWAIT
			RAISERROR('      --   EXEC [dbo].[dbasp_SetDBMaint] ''%s'',0',-1,-1,@DBName) WITH NOWAIT


			Goto SkipScriptBackup
		END


		IF @ForceB2Null IS NULL -- CHECK CONTROL TABLE OVERRIDES
		BEGIN
			IF @IgnoreB2NullOvrd = 0
			BEGIN
				IF @Mode IN ('BF','BD')
					SELECT	@B2N = [Detail03]
					FROM	[dbo].[Local_Control]
					WHERE	[Subject] = 'B2Null'
						AND	[Detail01] = @DBName
						AND	[Detail02] IN ('DATA','ALL')
				ELSE IF @Mode IN ('BL')
					SELECT	@B2N = [Detail03]
					FROM	[dbo].[Local_Control]
					WHERE	[Subject] = 'B2Null'
						AND	[Detail01] = @DBName
						AND	[Detail02] IN ('LOG','ALL')
			END


			IF @SQLEnv = 'PRO' -- PRODUCTION NEEDS OVERRIDE = 'Y' FOR BACKUP TO NUL
			BEGIN
				IF @B2N = 'Y'
					SET	@ForceB2Null = 1
				ELSE
					SET	@ForceB2Null = 0


				IF @Verbose >= 1
				BEGIN
					PRINT ''
					IF @ForceB2Null = 1
						RAISERROR('    -- %s backup will not be written to files because the ''B2Null'' Entry in [dbo].[Local_Control]',-1,-1,@DBName) WITH NOWAIT
				END
			END
			ELSE -- NON-PROD NEEDS OVERRIDE = 'N' FOR LOGS NOT BACKUP TO NUL
			BEGIN
				IF @B2N = 'N'
					SET	@ForceB2Null = 0
				ELSE
					SET	@ForceB2Null = 1


				IF @Verbose >= 1
				BEGIN
					PRINT ''
					IF @ForceB2Null = 0
						RAISERROR('    -- %s backup will be written to files because the ''B2Null'' Entry in [dbo].[Local_Control]',-1,-1,@DBName) WITH NOWAIT
				END
			END
		END
		ELSE
		BEGIN
			IF @Verbose >= 1
			BEGIN
				PRINT ''
				IF @ForceB2Null = 1
					RAISERROR('    -- %s backup will not be written to files because the @ForceB2Null=1 parameter',-1,-1,@DBName) WITH NOWAIT
				ELSE IF @ForceB2Null = 0
					RAISERROR('    -- %s backup will be written to files because the @ForceB2Null=0 parameter',-1,-1,@DBName) WITH NOWAIT
			END
		END


		IF @Verbose >= 1
		BEGIN
			DECLARE CreateHeadersCursor CURSOR
			FOR
			SELECT		name
						,xtype
						,colid
			FROM		TempDB..syscolumns
			WHERE		id = OBJECT_ID('tempdb..#TMP1')
			ORDER BY	colid


			SELECT	@FMT1		= ''
					,@FMT2		= ''
					,@HeaderLine	= ''


			OPEN CreateHeadersCursor
			FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
					SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP1'
					SET @CMD4 = '@ColumnSize INT OUTPUT'
					EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT

					IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
						SET @ColumnSize = LEN(@ColumnName)


					SELECT		@FMT1		= @FMT1 + '{'+CAST(@ColID-1 AS VarChar(5))+',-'+CAST(@ColumnSize AS VarChar(5))+'} '
							,@FMT2		= @FMT2 + '{'+CAST(@ColID-1 AS VarChar(5))+','+ CASE @xtype WHEN 108 then '' else '-' END + CAST(@ColumnSize AS VarChar(5))+'} '
							,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
							,@ColName1	= CASE @ColID WHEN 1 THEN @ColumnName ELSE @ColName1 END
							,@ColName2	= CASE @ColID WHEN 2 THEN @ColumnName ELSE @ColName2 END
							,@ColName3	= CASE @ColID WHEN 3 THEN @ColumnName ELSE @ColName3 END
							,@ColName4	= CASE @ColID WHEN 4 THEN @ColumnName ELSE @ColName4 END
							,@ColName5	= CASE @ColID WHEN 5 THEN @ColumnName ELSE @ColName5 END
							,@ColName6	= CASE @ColID WHEN 6 THEN @ColumnName ELSE @ColName6 END
							,@ColName7	= CASE @ColID WHEN 7 THEN @ColumnName ELSE @ColName7 END
							,@ColName8	= CASE @ColID WHEN 8 THEN @ColumnName ELSE @ColName8 END
							,@ColName9	= CASE @ColID WHEN 9 THEN @ColumnName ELSE @ColName9 END
				END
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
			END
			CLOSE CreateHeadersCursor
			DEALLOCATE CreateHeadersCursor


			SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
					+ @HeaderLine +@CRLF
			SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,DriveLetter,SizeGB,AvailableGB,FreeGB,DriveType,FileSystem,IsReady,VolumeName,RootFolder,'') +@CRLF
			FROM		#TMP1


			RAISERROR('/* =================================================== CURRENT DRIVE PROPERTIES =================================================== --',-1,-1) WITH NOWAIT
			RAISERROR('',-1,-1) WITH NOWAIT
			PRINT @TBL
			RAISERROR('',-1,-1) WITH NOWAIT
			RAISERROR('-- ================================================================================================================================ */',-1,-1) WITH NOWAIT
			RAISERROR('',-1,-1) WITH NOWAIT
		END


		-- SET ENGINE TO USE
		SELECT	@BackupEngine = CASE	WHEN @ForceEngine IS NOT NULL							THEN @ForceEngine
					WHEN @DBName IN ('master','model','msdb','temp','DBAOps','dbaperf','DBAOps')	THEN 'MSSQL'
					WHEN @Compression = 1									THEN 'MSSQL'
					WHEN @RedGateInstalled = 1								THEN 'REDGATE'
					WHEN @IderaInstalled = 1								THEN 'IDERA'
					ELSE 'MSSQL' END

		--  SET EXTENSION
		IF @BackupEngine = 'REDGATE'
			SELECT	@Extension = CASE @Mode
						WHEN 'BF' THEN 'SQB'
						WHEN 'BD' THEN 'SQD'
						WHEN 'BL' THEN 'SQT'
						END
		ELSE IF @BackupEngine = 'IDERA'
			SELECT	@Extension = CASE @Mode
						WHEN 'BF' THEN 'safe'
						WHEN 'BD' THEN 'safe'
						WHEN 'BL' THEN 'safe'
						END
		ELSE IF @Compression = 1
			SELECT	@Extension = CASE @Mode
						WHEN 'BF' THEN 'cBAK'
						WHEN 'BD' THEN 'cDIF'
						WHEN 'BL' THEN 'cTRN'
						END
		ELSE
			SELECT	@Extension = CASE @Mode
						WHEN 'BF' THEN 'BAK'
						WHEN 'BD' THEN 'DIF'
						WHEN 'BL' THEN 'TRN'
						END


		--SELECT @BackupEngine,@ForceEngine,@DBName,@Compression,@RedGateInstalled,@Extension


		-- BUILD LIST OF CURRENT FILE GROUPS IN DATABASE
		Select @CMD		= REPLACE('USE [{DBNAME}];
						SET NOCOUNT ON;
						SET ANSI_WARNINGS OFF;
						INSERT INTO	#FGs
						SELECT		fg.data_space_id
								,fg.name
								,COALESCE((cast((sum(a.used_pages) * 8192/1048576.) as decimal(15, 2))*25)/100,0)
						FROM		sys.filegroups fg
						LEFT JOIN	sys.allocation_units a
							ON	fg.data_space_id = a.data_space_id


						LEFT JOIN	sys.partitions p
							ON	p.partition_id = a.container_id
						LEFT JOIN	sys.internal_tables it
							ON	p.object_id = it.object_id
						GROUP BY	fg.data_space_id
								,fg.name;','{DBNAME}',@DBNAME)
		EXEC (@CMD)
		SET @CMD = NULL


		DECLARE LoopBackupFileGroups CURSOR
		FOR


		SELECT	id
				,name
		FROM		#FGs
		WHERE	name in  (SELECT SplitValue FROM [dbo].[dbaudf_StringToTable](@filegroups,','))
			OR	@filegroups = 'ALL'
		UNION ALL
		SELECT		1
				,NULL
		WHERE		@filegroups IS NULL
		ORDER BY	1


		OPEN LoopBackupFileGroups;
		FETCH LoopBackupFileGroups INTO @FGID, @FileGroup;
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				---------------------------- EXECUTE LOOP ONCE PER FILE GROUP SPECIFIED
				---------------------------- CURSOR LOOP TOP


				-- SET MULTIFILE SET SIZE
				IF @ForceSetSize is null
				BEGIN
					IF @Mode = 'BF'
					BEGIN
						-- GET THE SIZE OF THE FILEGROUP OR ALL FILEGROUPS IF @FileGroup IS NULL
						SELECT @Size = SUM(size) FROM #FGs WHERE name = COALESCE(@FileGroup,name)
					END
					Else If @Mode = 'BD'
					BEGIN

						exec dbo.dbasp_Estimate_Diff_Size @DBName = @DBname, @diffPrediction = @diffPrediction output
						Select @size = convert(float, @diffPrediction)
					END


					SELECT @SetSize = COALESCE(@Size,(1024*2))/(1024*2)
				END
				ELSE
					SET @SetSize = @ForceSetSize


				-- LIMIT SETSIZE BASED ON BACKUP ENGINE
				IF @SetSize < 1
					SET @SetSize = 1


				-- THE MAXIMUM SQL CAN DO IS 64
				-- WE HAVE FOUND 64 TO CAUSE IO PROBLEMS IN OUR ENVIRONMENT SO WE
				-- ARE LIMITING THE MAXIMUM TO 32
				IF @SetSize > 32
					SET @SetSize = 32


				IF @BackupEngine = 'REDGATE' and @SetSize > 32
					SET @SetSize = 32


				--SELECT @DBName,@FileGroup,@ForceSetSize,@SetSize,@Mode,@Size,@diffPrediction


				-- START BUILDING COMMAND


				SELECT	@CMD		= CASE @Mode
								WHEN 'BL' THEN 'BACKUP LOG ['+@DBName+']' + @CRLF
								ELSE 'BACKUP DATABASE ['+@DBName+']' + @CRLF
								END
					,@SetNumber	= 0
					,@FileName	= COALESCE	(
									REPLACE(REPLACE(@ForceFileName,'$FG$',COALESCE(@FileGroup,'')),'$TS$',@Now)
									,@DBName
										+ CASE
											WHEN @IsBaseLine = 1		THEN '_BASE_'
											WHEN @FileGroup IS NOT NULL	THEN '_FG$'+@FileGroup+'_'
											WHEN @Mode = 'BF'		THEN '_DB_'
											WHEN @Mode = 'BD'		THEN '_DFNTL_'
											WHEN @Mode = 'BL'		THEN '_TLOG_'
											END
										+@NOW
									)


				If @FileGroup IS NOT NULL
					SELECT	@CMD = @CMD + ' FILEGROUP = '''+@FileGroup+''''+@CRLF


				SELECT	@CMD = @CMD + ' TO ' + @CRLF


				IF @ForceB2Null = 1
				BEGIN
					SET    @CMD   = @CMD + ' DISK = ''NUL:'''+ @CRLF


				END
				ELSE
				BEGIN
					IF @SetSize > 1
					BEGIN
						WHILE         @SetNumber < @SetSize
						BEGIN
							--SELECT @FilePath,@FileName,@SetNumber,@SetSize,@Extension


							SET    @SetNumber = @SetNumber + 1
							SET    @CMD2 = ' DISK = '''+@FilePath+@FileName+'_SET_'+RIGHT('0'+CAST(@SetNumber AS VARCHAR(2)),2)+'_OF_'+RIGHT('0'+CAST(@SetSize AS VARCHAR(2)),2)+'.'+@Extension+''''


							--PRINT @CMD2


							SET    @CMD   = @CMD + CASE @SetNumber  WHEN 1 THEN '' ELSE ',' END + @CMD2 + @CRLF
						END
						-- SET FILENAME TO A DOS COMPATIBLE MASK WHICH IDENTIFYS ALL FILES IN THE SET
						SET @FileName = @FileName + '_SET_??_OF_' + RIGHT('0'+CAST(@SetSize AS VARCHAR(2)),2)
					END
					ELSE
						SET    @CMD   = @CMD + ' DISK = '''+@FilePath+@FileName+'.'+@Extension+''''+ @CRLF


					-- ADD EXTENSION TO FILENAME FOR REMAINING USAGE
					SET @FileName = @FileName + '.' + @Extension


					--PRINT @CMD


					IF @Verbose >= 1
					BEGIN
						DECLARE @S1	VarChar(50)
						DECLARE @S2	VarChar(50)

						SELECT	@S1	= DBAOps.[dbo].[dbaudf_FormatNumber](@Size,0,0)
								,@S2	= DBAOps.[dbo].[dbaudf_FormatNumber](CAST(@Size AS DECIMAL(15,2))/@SetSize,0,2)


						PRINT ''
						RAISERROR('    -- %s Estimated Total Backup Size is %s MB',-1,-1,@FileName,@S1) WITH NOWAIT
						IF @SetSize > 1
							RAISERROR('    --   Backup will Be Writen into %d Files in order to Keep each File at about %s MB.',-1,-1,@SetSize,@S2) WITH NOWAIT


					END
				END


				-- ADD ALL "WITH" PARAMETERS
				SELECT        @CMD	= @CMD
							+ ' WITH '
							+ dbo.dbaudf_ConcatenateUnique (WithOptions)
				FROM		(
						SELECT CASE @CopyOnly WHEN 1 THEN 'COPY_ONLY' END					UNION ALL
						SELECT CASE @Mode WHEN 'BD' THEN 'DIFFERENTIAL' END					UNION ALL
						SELECT CASE @ForceChecksum WHEN 1 THEN 'CHECKSUM' WHEN 0 THEN 'NO_CHECKSUM' END		UNION ALL
						SELECT CASE WHEN @BackupEngine='MSSQL' AND @Compression=1 THEN 'COMPRESSION' END	UNION ALL
						SELECT CASE @BackupEngine WHEN 'REDGATE' THEN 'COMPRESSION = 1' END			UNION ALL
						SELECT CASE @BackupEngine WHEN 'MSSQL' THEN 'STATS = ' + CAST(@Stats AS VarChar) END	UNION ALL
						SELECT CASE @BackupEngine WHEN 'REDGATE' THEN 'SINGLERESULTSET' END			UNION ALL
						--SELECT CASE @BackupEngine WHEN 'REDGATE' THEN 'THREADCOUNT = 3' END			UNION ALL
						SELECT CASE WHEN @MaxTransferSize IS NOT NULL
								THEN 'MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS VarChar(10)) END	UNION ALL
						SELECT CASE WHEN @BufferCount IS NOT NULL
								THEN 'BUFFERCOUNT = ' + CAST(@BufferCount AS VarChar(10)) END		UNION ALL
						SELECT 'NAME = ''' + @SetName + ''''							UNION ALL
						SELECT 'DESCRIPTION = ''' + @SetDesc + ''''
						) Data([WithOptions])
				WHERE		[WithOptions] IS NOT NULL

				--PRINT @CMD


				--  SPECIAL FORMATING FOR REDGATE
				If @BackupEngine = 'REDGATE'
					SET	@CMD	= 'EXEC Master.dbo.SQLBackup ''-SQL "'
							+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@CMD,CHAR(9),' '),@CRLF,' '),'''',''''''),'  ',' '),'  ',' ')
							+ '"'''


				IF @UseTryCatch = 1
					SET @CMD	= 'BEGIN TRY' + @CRLF
							+ @CMD + @CRLF
							+ 'END TRY' + @CRLF
							+ 'BEGIN CATCH' + @CRLF
							+ 'RAISERROR (''UNABLE TO BACKUP DATABASE'',-1,-1) WITH NOWAIT' + @CRLF
							+ 'END CATCH' + @CRLF
							+ @CRLF


				-- ADD LOGGING CALL
				IF @ForceB2Null = 0
				SET	@CMD		= @CMD + ';' + @CRLF + @CRLF
							+ 'INSERT INTO dbo.backup_log values(getdate(), '''
							+ COALESCE(@DBName,'')		+ ''', '''
							+ COALESCE(@FileName,'')	+ ''', '''
							+ COALESCE(@FilePath,'')	+ ''', '''
							+ COALESCE(@mode,'')		+ ''')'
							+ @CRLF
				ELSE
				SET	@CMD		= @CMD + ';' + @CRLF + @CRLF
							+ 'INSERT INTO dbo.backup_log values(getdate(), '''
							+ COALESCE(@DBName,'')		+ ''', '''
							+ 'NUL:'	+ ''', '''
							+ 'NUL:'	+ ''', '''
							+ COALESCE(@mode,'')		+ ''')'
							+ @CRLF


				SET	@syntax_out	= COALESCE(@syntax_out,'')
							+ @CRLF
							+ COALESCE(@CMD,'') -- USE COALESCE TO MAKE SURE THAT ONE BAD ENTRY DOES NOT NULL THE STRING


				---------------------------- CURSOR LOOP BOTTOM
				----------------------------
			END
 			FETCH NEXT FROM LoopBackupFileGroups INTO @FGID, @FileGroup;
		END
		CLOSE LoopBackupFileGroups;
		DEALLOCATE LoopBackupFileGroups;

	SkipScriptBackup:

	END	-- SCRIPT DATABASE BACKUPS


	IF	-- SCRIPT DATABASE RESTORE
	@Mode IN ('RD')
	BEGIN	-- SCRIPT DATABASE RESTORE


		BEGIN	-- GATHER LIST OF BACKUP FILES


			DELETE		@SF

			BEGIN TRY
				IF @Verbose >= 1
					RAISERROR ('  -- Getting List of Backup Files',-1,-1) WITH NOWAIT
				INSERT INTO	@SF
				SELECT		*
				FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(@DBName,@FilePath,@IncludeSubDir,@ForceFileName)
				WHERE		BatchHistoryLogID = COALESCE(@ForceBHLID,BatchHistoryLogID)  -- FORCE A SPECIFIC BLHID if Parameter specified.
			END TRY
			BEGIN CATCH
				IF @Verbose >= 0
					RAISERROR ('    -- *** FAILED TO GET LIST OF BACKUP FILES ***',-1,-1) WITH NOWAIT
				DECLARE @TempInt INT
				SET @TempInt = CAST(@IncludeSubDir AS INT)
				RAISERROR ('USING : SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''%s'',''%s'',''%d'',''%s'')',-1,-1,@DBName,@FilePath,@TempInt,@ForceFileName) WITH NOWAIT
				EXEC dbo.dbasp_GetErrorInfo
			END CATCH


--SELECT @DBName,@FilePath,@IncludeSubDir,@ForceFileName,@RestoreToDateTime
--SELECT * FROM @SF ORDER BY [BackupTimeStamp] DESC


			IF @RestoreToDateTime IS NOT NULL
			BEGIN
				set @CMD = CAST(@RestoreToDateTime AS VarChar(50))
				RAISERROR('    --  RestoreToDatTime was specified. Ignoring Files newer than %s.',-1,-1,@CMD) WITH NOWAIT

				DELETE
				FROM		@SF
				WHERE		[BackupTimeStamp] > DATEADD(minute,15,@RestoreToDateTime)
			END


			---- DELETE ALL PREVIOUSLY APPLIED LOG FILES UNLESS A FULL RESET
			--IF @FullReset = 0
			--BEGIN


			--	DELETE		@SF
			--	WHERE		BackupType = 'TL'
			--		AND	[BackupTimeStamp] <
			--				(
			--				SELECT		MAX(backup_start_date)
			--				FROM		msdb.dbo.restorehistory rh
			--				JOIN		[msdb].[dbo].[backupset] bs
			--					ON	rh.backup_set_id = bs.backup_set_id
			--				JOIN		[msdb].[dbo].[backupmediafamily] bmf
			--					ON	bmf.[media_set_id] = bs.[media_set_id]
			--				WHERE		restore_type = 'L'
			--					AND	rh.destination_database_name = @NewDBName
			--				)
			--END


			IF @NoDifRestores = 0
			BEGIN -- DELETE ALL LOGS AND DIFFS OLDER THAN THE MOST RECENT DIFF
				DELETE
				FROM		@SF
				WHERE		BackupType IN ('TL','DF')
					AND	[BackupTimeStamp] < (SELECT MAX([BackupTimeStamp]) FROM @SF WHERE BackupType = 'DF')
			END


			-- DELETE ALL FULLS OTHER THAN THE MOST RECENT FULLS BY FILEGROUP (IS SPECIFIED)
			DELETE		T1
			FROM		@SF T1
			LEFT JOIN	(
					SELECT		[FileGroup]
								,[BackupType]
								,MAX([BackupTimeStamp]) [BackupTimeStamp]
					FROM		@SF
					WHERE		BackupType IN('DB','FG','PI')
					GROUP BY	[FileGroup]
								,[BackupType]
					) T2
				ON	ISNULL(T1.[FileGroup],'ALL') = ISNULL(T2.[FileGroup],'ALL')
				AND	T1.[BackupType] = T2.[BackupType]
				AND	T1.[BackupTimeStamp] = T2.[BackupTimeStamp]
			WHERE	T1.BackupType IN('DB','FG','PI')
				AND	T2.[BackupTimeStamp] IS NULL


			IF @NoLogRestores = 1
				DELETE
				FROM		@SF
				WHERE		BackupType = 'TL'


			IF @NoDifRestores = 1
				DELETE
				FROM		@SF
				WHERE		BackupType = 'DF'


			IF @NoFullRestores = 1
				DELETE
				FROM		@SF
				WHERE		BackupType IN ('DB','FG','PI')


			IF @RedGateInstalled = 0
			BEGIN
				DELETE
				FROM		@SF
				WHERE		BackupEngine = 'RedGate'


				IF @@ROWCOUNT > 0
					RAISERROR('    -- REDGATE BACKUP FILES WERE NOT USABLE BECAUSE REDGATE IS NOT INSTALLED',-1,-1) WITH NOWAIT


			END


			IF @IderaInstalled = 0
			BEGIN
				DELETE
				FROM		@SF
				WHERE		BackupEngine = 'Idera'


				IF @@ROWCOUNT > 0
					RAISERROR('    -- IDERA BACKUP FILES WERE NOT USABLE BECAUSE IDERA SQLSafe IS NOT INSTALLED',-1,-1) WITH NOWAIT


			END


			IF NOT EXISTS(SELECT * FROM @SF)
			BEGIN
				PRINT ''
				RAISERROR('    -- NO SUITABLE BACKUP FILES EXIST',-1,-1) WITH NOWAIT
				GOTO SkipRestore
			END
		END	-- GATHER LIST OF BACKUP FILES


		-- FIX BACKUP TYPE AND DATE
		UPDATE		T1
			SET		BackupTimeStamp = (SELECT MIN([dbo].[dbaudf_GetFileProperty]([FullPathName],'file','CreationTime')) FROM @SF WHERE Mask = T1.Mask)
					,BackupType = 'DB'
		FROM		@SF T1
		WHERE		BackupType = '??'
			AND	BackupTimeStamp IS NULL

		UPDATE		T1
			SET		BackupType = 'DB'
		FROM		@SF T1
		WHERE		BackupType = 'PI'
			

--SELECT * FROM @SF ORDER BY [BackupTimeStamp] DESC


		BEGIN	-- CHECK BACKUP FILES


			IF @Verbose >= 1
				RAISERROR('  -- Checking Backup Files',-1,-1) WITH NOWAIT

			DECLARE BackupFileCheckCursor CURSOR
			FOR
			SELECT		DISTINCT
						T1.[BackupTimeStamp]
						,T1.[BackupSetSize]
						,T1.[Mask]
						,T1.[FullPathName]
			FROM		@SF T1
			WHERE		T1.[BackupSetNumber] = 1
			--AND		Name Not In	(
			--				SELECT		DISTINCT
			--						[dbo].[dbaudf_GetFileFromPath]([physical_device_name]) [Name]
			--				FROM		msdb.dbo.restorehistory rh
			--				JOIN		[msdb].[dbo].[backupset] bs
			--					ON	rh.backup_set_id = bs.backup_set_id
			--				JOIN		[msdb].[dbo].[backupmediafamily] bmf
			--					ON	bmf.[media_set_id] = bs.[media_set_id]
			--				WHERE		rh.destination_database_name = @NewDBName
			--				)
			ORDER BY	T1.BackupTimeStamp


			OPEN BackupFileCheckCursor
			FETCH NEXT FROM BackupFileCheckCursor INTO @BackupTimeStamp,@SetSize,@FileName,@FullPathName
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN


					IF @Verbose >= 1
						RAISERROR('  -- Checking ''%s''',-1,-1,@FullPathName) WITH NOWAIT


					IF @Verbose >= 1
						RAISERROR('    -- Calling dbo.dbaudf_BackupScripter_GetFileList (''%s'',''%s'',%d,''%s'',''%s'',@OverrideXML,''%s'',''%s'',''%s'',''%s'')',-1,-1,@DBName,@NewDBName,@SetSize,@FileName,@FullPathName,@NOW,@DataPath,@NdfPath,@LogPath) WITH NOWAIT


					BEGIN TRY
						INSERT INTO	@FL
						SELECT		*
						FROM		dbo.dbaudf_BackupScripter_GetFileList (@DBName,@NewDBName,@SetSize,@FileName,@FullPathName,@OverrideXML,@NOW,@DataPath,@NdfPath,@LogPath)
					END TRY
					BEGIN CATCH
						RAISERROR('    -- Calling dbo.dbaudf_BackupScripter_GetFileList (''%s'',''%s'',%d,''%s'',''%s'',@OverrideXML,''%s'',''%s'',''%s'',''%s'')',-1,-1,@DBName,@NewDBName,@SetSize,@FileName,@FullPathName,@NOW,@DataPath,@NdfPath,@LogPath) WITH NOWAIT
						RAISERROR ('      ** UNABLE TO GET FILELIST FROM %s',-1,-1,@FileName) WITH NOWAIT


					END CATCH

					IF @Verbose >= 1
						RAISERROR('    -- Calling dbo.dbaudf_BackupScripter_GetHeaderList (%d,''%s'',''%s'')',-1,-1,@SetSize,@FileName,@FullPathName) WITH NOWAIT

					BEGIN TRY
						INSERT INTO	@HL
						SELECT		*,null,null,null,null
						FROM		dbo.dbaudf_BackupScripter_GetHeaderList (@SetSize,@FileName,@FullPathName)
					END TRY
					BEGIN CATCH
						RAISERROR('    -- Calling dbo.dbaudf_BackupScripter_GetHeaderList (%d,''%s'',''%s'')',-1,-1,@SetSize,@FileName,@FullPathName) WITH NOWAIT
						RAISERROR ('      ** UNABLE TO GET HEADERLIST FROM %s',-1,-1,@FileName) WITH NOWAIT


					END CATCH


					IF @Verbose >= 1
						RAISERROR('   -- Done Checking ''%s''',-1,-1,@FullPathName) WITH NOWAIT


				END
				FETCH NEXT FROM BackupFileCheckCursor INTO @BackupTimeStamp,@SetSize,@FileName,@FullPathName
			END
			CLOSE BackupFileCheckCursor
			DEALLOCATE BackupFileCheckCursor


			IF @Verbose >= 1
				RAISERROR('    -- Done Checking Backup Files',-1,-1) WITH NOWAIT


		UPDATE @FL SET FileGroupId = 1, IsPresent = 1 WHERE (TYPE = 'D' AND FileGroupId IS NULL AND IsPresent IS NULL) OR (TYPE = 'L' AND IsPresent IS NULL)


--SELECT * FROM @FL
--SELECT * FROM @HL


		END	-- CHECK BACKUP FILES


		BEGIN	-- GENERATE FILEGROUP LIST


			IF @Verbose >= 1
				RAISERROR('  -- Generating FileGroup List',-1,-1) WITH NOWAIT


			SELECT		FileGroupName
						,FileGroupId
						,CASE MIN(CAST(IsPresent AS INT)) WHEN 0 THEN 1 ELSE 0 END [HasFGExcluded]
						,MAX(CAST(IsPresent AS INT)) [HasFGIncluded]
			INTO		#Fgrps
			FROM		@FL
			WHERE		FileGroupId > 0
			GROUP BY	FileGroupName
					,FileGroupId


--SELECT 12345,* FROM #Fgrps


			IF @filegroups IS NOT NULL
			BEGIN
				SELECT		T1.*
							,CASE WHEN T2.SplitValue IS NOT NULL THEN 1 ELSE 0 END [BeingRestored]
				INTO		#TMP5
				FROM		#Fgrps T1
				LEFT JOIN	[dbo].[dbaudf_StringToTable](@filegroups,',') T2
					ON		T1.FileGroupName = T2.SplitValue


				IF @Verbose >= 1
				BEGIN
					DECLARE CreateHeadersCursor CURSOR
					FOR
					SELECT		name
								,xtype
								,colid
					FROM		TempDB..syscolumns
					WHERE		id = OBJECT_ID('tempdb..#TMP5')
					ORDER BY	colid


					SELECT		@FMT1			= ''
								,@FMT2			= ''
								,@HeaderLine	= ''


					OPEN CreateHeadersCursor
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
					WHILE (@@fetch_status <> -1)
					BEGIN
						IF (@@fetch_status <> -2)
						BEGIN
							SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP5'
							SET @CMD4 = '@ColumnSize INT OUTPUT'
							EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT


							IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
								SET @ColumnSize = LEN(@ColumnName)


							SELECT		@FMT1		= @FMT1 + '{'+CAST(@ColID-1 AS VarChar(5))+',-'+CAST(@ColumnSize AS VarChar(5))+'} '
									,@FMT2		= @FMT2 + '{'+CAST(@ColID-1 AS VarChar(5))+','+ CASE @xtype WHEN 108 then '' else '-' END + CAST(@ColumnSize AS VarChar(5))+'} '
									,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
									,@ColName1	= CASE @ColID WHEN 1 THEN @ColumnName ELSE COALESCE(@ColName1,'') END
									,@ColName2	= CASE @ColID WHEN 2 THEN @ColumnName ELSE COALESCE(@ColName2,'') END
									,@ColName3	= CASE @ColID WHEN 3 THEN @ColumnName ELSE COALESCE(@ColName3,'') END
									,@ColName4	= CASE @ColID WHEN 4 THEN @ColumnName ELSE COALESCE(@ColName4,'') END
									,@ColName5	= CASE @ColID WHEN 5 THEN @ColumnName ELSE COALESCE(@ColName5,'') END
									,@ColName6	= CASE @ColID WHEN 6 THEN @ColumnName ELSE COALESCE(@ColName6,'') END
									,@ColName7	= CASE @ColID WHEN 7 THEN @ColumnName ELSE COALESCE(@ColName7,'') END
									,@ColName8	= CASE @ColID WHEN 8 THEN @ColumnName ELSE COALESCE(@ColName8,'') END
									,@ColName9	= CASE @ColID WHEN 9 THEN @ColumnName ELSE COALESCE(@ColName9,'') END


						END
						FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
					END
					CLOSE CreateHeadersCursor
					DEALLOCATE CreateHeadersCursor


					SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
							+ @HeaderLine +@CRLF
					SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,FileGroupName,FileGroupID,HasFGExcluded,HasFGIncluded,BeingRestored,'','','','','') +@CRLF
					FROM		#TMP5


					RAISERROR('/* =============================================== DATABASE FILE GROUP PROPERTIES =============================================== --',-1,-1) WITH NOWAIT
					RAISERROR('',-1,-1) WITH NOWAIT
					PRINT @TBL
					RAISERROR('-- ============================================================================================================================== */',-1,-1) WITH NOWAIT
					RAISERROR('',-1,-1) WITH NOWAIT
				END


			END


			IF @Verbose >= 1
				RAISERROR('    -- Done Generating FileGroup List',-1,-1) WITH NOWAIT


		END					-- GENERATE FILEGROUP LIST


		BEGIN	-- CLEANUP BACKUP FILES
			--------------------------------------------------------------------------------------
			--------------------------------------------------------------------------------------
			--	Backup type:
			--		1 = Database
			--		2 = Transaction log
			--		4 = File
			--		5 = Differential database
			--		6 = Differential file
			--		7 = Partial
			--		8 = Differential partial
			--------------------------------------------------------------------------------------
			--------------------------------------------------------------------------------------
			UPDATE @HL SET BackupFinishDate = DATEADD(MINUTE,5,BackupStartDate) WHERE BackupFinishDate IS NULL AND BackupStartDate IS NOT NULL


			IF @Verbose >= 1
				RAISERROR('  -- Cleaning Backup Files',-1,-1) WITH NOWAIT


			BEGIN	-- SET CALCULATED DATE RANGE FIELDS IN @HL
				UPDATE		T1
					SET	[BackupDateRange_Start]	=	COALESCE(
											CASE BackupType
											WHEN 2 THEN --LOGS
											COALESCE(
												(
												SELECT		MAX(BackupFinishDate)
												FROM		@HL
												WHERE		LastLSN = T1.FirstLSN
													AND	BackupType = 2 -- LOG
												)
												,(
												SELECT		MIN(BackupFinishDate)
												FROM		@HL
												WHERE		FirstLSN < T1.LastLSN
													AND	BackupType IN (1,4) -- FULL OR FILE/FILEGROUP
												)
												,[BackupFinishDate]
												)
											ELSE [BackupFinishDate] -- ALL BUT LOGS
											END
											,(
											SELECT		MAX(BackupFinishDate)
											FROM		@HL
											WHERE		FirstLSN < T1.LastLSN
												AND	LastLSN > T1.LastLSN
												AND	BackupType IN(1,4,5) -- FULL OR FILE/FILEGROUP OR DIFF
											)
											)


						,[BackupDateRange_End]	=	[BackupFinishDate] --DATEADD(SECOND,-1,[BackupFinishDate])
						,[BackupChainStartDate]	=	CASE BackupType
										WHEN 1 THEN [BackupFinishDate]
										WHEN 4 THEN [BackupFinishDate]
										ELSE
										(
										SELECT		MIN(BackupFinishDate)
										FROM		@HL
										WHERE		BackupStartDate < T1.BackupStartDate
											AND	BackupType IN (1,4) -- FULL OR FILE/FILEGROUP
										)
										END


						,[BackupLinkStartDate]	=	CASE BackupType WHEN 2
										THEN
										(
										SELECT		MAX(BackupFinishDate)
										FROM		@HL
										WHERE		BackupStartDate < T1.BackupStartDate
											AND	BackupType IN(1,4,5) -- FULL OR FILE/FILEGROUP OR DIFF
										)
										ELSE [BackupFinishDate]
										END
				FROM		@HL T1
			END	-- SET CALCULATED DATE RANGE FIELDS IN @HL


--SELECT * FROM @HL ORDER BY BackupStartDate DESC


			IF @NoFullRestores = 0
			BEGIN	-- REMOVE OLD LOGS HAVING NO FULL TO START
				DELETE		T1
				FROM		@HL T1
				JOIN		(
						SELECT		BackupChainStartDate
								,BackupLinkStartDate
								,MIN(BackupDateRange_End) BackupDateRange_End
						FROM		@HL
						WHERE		BackupDateRange_Start IS NULL
							AND	BackupType = 2 -- LOG
						GROUP BY	BackupChainStartDate
								,BackupLinkStartDate
						)T2
					ON	T1.BackupChainStartDate = T2.BackupChainStartDate
					AND	T1.BackupLinkStartDate = T2.BackupLinkStartDate
					AND	T1.BackupDateRange_End >= T2.BackupDateRange_End
				WHERE		T1.BackupType = 2 -- LOG
			END	-- REMOVE OLD LOGS HAVING NO FULL TO START


--SELECT * FROM @HL ORDER BY BackupStartDate DESC


			BEGIN	-- BUILD @VDR (VALID DATE RANGES)
				SET ANSI_WARNINGS OFF
				;WITH		RawRanges
						AS
						(
						SELECT		T2.FileGroupName
									,BackupDateRange_Start
									,BackupDateRange_End
						FROM		@HL T1
						CROSS JOIN	#Fgrps T2
						WHERE		BackupType IN(1,5) -- FULL OR DIFF
						UNION ALL
						SELECT		(SELECT TOP 1 FileGroupName FROM @FL WHERE IsPresent = 1 AND FileGroupName IS NOT NULL AND T1.BackupFileName = BackupFileName) [FileGroupName]
									,BackupDateRange_Start
									,BackupDateRange_End
						FROM		@HL T1
						WHERE		BackupType IN(4,6,7,8) -- FILE\FILEGROUP
						UNION ALL
						SELECT		T2.FileGroupName
									,MIN(BackupLinkStartDate)
									,MAX(BackupDateRange_End)
						FROM		@HL T1
						CROSS JOIN	#Fgrps T2
						WHERE		BackupType = 2 -- LOG
						GROUP BY	T2.FileGroupName
						)
						,SummaryRanges
						AS
						(
						SELECT		[FileGroupName]
									,BackupDateRange_Start
									,BackupDateRange_End
									,0 lvl
						FROM		RawRanges
						WHERE		BackupDateRange_Start = BackupDateRange_End
						UNION ALL
						SELECT		T2.[FileGroupName]
									,T2.BackupDateRange_Start
									,T1.BackupDateRange_End
									,T2.lvl + 1 lvl
						FROM		RawRanges T1
						JOIN		SummaryRanges T2
							ON		T1.FileGroupName = T2.FileGroupName
							AND		T1.BackupDateRange_Start = T2.BackupDateRange_End
							AND		T1.BackupDateRange_Start != T1.BackupDateRange_End
						)
						,RankedRanges
						AS
						(
						SELECT		*
									,DENSE_RANK() OVER(PARTITION BY [BackupDateRange_Start] ORDER BY [lvl] desc) AS rank
						FROM		SummaryRanges
						)
				INSERT		@VDR
				SELECT		[FileGroupName]
							,BackupDateRange_Start
							,BackupDateRange_End
				FROM		RankedRanges
				WHERE		[rank] = 1
				ORDER BY	BackupDateRange_Start
				SET ANSI_WARNINGS ON
			END	-- BUILD @VDR (VALID DATE RANGES)


--SELECT 121212,* FROM @VDR


			IF	-- ERROR IF NO VALID DATE IS SPECIFIED
			@RestoreToDateTime IS NOT NULL AND NOT EXISTS (SELECT * FROM @VDR WHERE BackupDateRange_Start <= @RestoreToDateTime AND BackupDateRange_End >= @RestoreToDateTime)
			BEGIN	-- ERROR IF NO VALID DATE IS SPECIFIED
				IF @Verbose >= 0
				BEGIN
					RAISERROR('  -- *** NO VALID BACKUPS TO RESTORE TO THAT POINT IN TIME ***',-1,-1) WITH NOWAIT
					RAISERROR('  -- *** SELECT A DATETIME VALUE FROM ONE OF THE FOLLOWING RANGES ***',-1,-1) WITH NOWAIT


					SELECT		*
					FROM		@VDR


				END


				GOTO SkipRestore
			END     -- ERROR IF NO VALID DATE IS SPECIFIED


			IF (@NoDifRestores = 0 AND @NoFullRestores = 0)
			BEGIN	-- REMOVE LOGS FROM BROKEN LINKS

				IF @Verbose >= 1
					RAISERROR('    -- Removing Logs From Broken Links',-1,-1) WITH NOWAIT

				DELETE		@SF
				WHERE		Mask IN	(
							SELECT		[BackupFileName]
							FROM		@HL
							WHERE		[BackupType] = 2
								AND	[BackupLinkStartDate] IS NULL
							)


				DELETE		@HL
				WHERE		[BackupType] = 2
					AND	[BackupLinkStartDate] IS NULL


				IF @Verbose >= 1
					RAISERROR('      -- Done Removing Logs From Broken Links',-1,-1) WITH NOWAIT


			END	-- REMOVE LOGS FROM BROKEN LINKS


--SELECT * FROM @HL ORDER BY BackupStartDate DESC


			IF (@NoDifRestores = 0 AND @NoFullRestores = 0)
			BEGIN	-- REMOVE LOGS AND DIFFS FROM OTHER LINKS


				IF @Verbose >= 1
					RAISERROR('    -- Removing Logs AND Diffs From Other Links',-1,-1) WITH NOWAIT


				DELETE		@SF
				WHERE		Mask IN	(
								SELECT		[BackupFileName]
								FROM		@HL
								WHERE		[BackupType] NOT IN (1,4)
									AND	COALESCE([BackupLinkStartDate],'1980-01-01') != (
														SELECT		MAX([BackupLinkStartDate])[BackupLinkStartDate]
														FROM		@HL T1
														WHERE		[BackupDateRange_Start] <= COALESCE(@RestoreToDateTime, (SELECT MAX([BackupDateRange_End]) FROM @HL))
															AND	[BackupDateRange_End] >= COALESCE(@RestoreToDateTime, (SELECT MAX([BackupDateRange_End]) FROM @HL))
														)
								)


				DELETE		@HL
				WHERE		[BackupType] NOT IN (1,4)
					AND	COALESCE([BackupLinkStartDate],'1980-01-01') !=	(
										SELECT		MAX([BackupLinkStartDate])[BackupLinkStartDate]
										FROM		@HL T1
										WHERE		[BackupDateRange_Start] <= COALESCE(@RestoreToDateTime, (SELECT MAX([BackupDateRange_End]) FROM @HL))
											AND	[BackupDateRange_End] >= COALESCE(@RestoreToDateTime, (SELECT MAX([BackupDateRange_End]) FROM @HL))
										)


				IF @Verbose >= 1
					RAISERROR('      -- Done Removing Logs AND Diffs From Other Links',-1,-1) WITH NOWAIT


			END	-- REMOVE LOGS AND DIFFS FROM OTHER LINKS


--SELECT * FROM @SF
--SELECT 9999,* FROM @HL ORDER BY BackupStartDate DESC


			IF	-- REMOVE FG BACKUPS FOR FG'S NOT BEING RESTORED
			@filegroups IS NOT NULL
			BEGIN	-- REMOVE FG BACKUPS FOR FG'S NOT BEING RESTORED


				IF @Verbose >= 1
					RAISERROR('    -- Removing FG Backups from FG''s Not Being Restored',-1,-1) WITH NOWAIT


				DELETE		@SF
				WHERE		Mask NOT IN	(
									SELECT		DISTINCT
											T1.BackupFileName
									FROM		@FL T1
									JOIN		[dbo].[dbaudf_StringToTable](@filegroups,',') T2
											ON	T1.FileGroupName = T2.SplitValue
											AND	T1.IsPresent = 1
									)


				DELETE		@HL
				WHERE		BackupFileName NOT IN	(
									SELECT		DISTINCT
											T1.BackupFileName
									FROM		@FL T1
									JOIN		[dbo].[dbaudf_StringToTable](@filegroups,',') T2
											ON	T1.FileGroupName = T2.SplitValue
											AND	T1.IsPresent = 1
									)


				IF @Verbose >= 1
					RAISERROR('      -- Done Removing FG Backups from FG''s Not Being Restored',-1,-1) WITH NOWAIT


			END	-- REMOVE FG BACKUPS FOR FG'S NOT BEING RESTORED


--SELECT 8888,* FROM @SF
--SELECT 7777,* FROM @HL ORDER BY BackupStartDate DESC


--SELECT * FROM		@HL T3
--SELECT * FROM		@FL T4


--SELECT		T4.FileGroupName
--			,MAX([BackupDateRange_End]) [BackupDateRange_End]
--FROM		@HL T3
--JOIN		@FL T4
--	ON		T3.BackupFileName = T4.BackupFileName
--	AND		T4.FileGroupName IS NOT NULL
--WHERE		T4.IsPresent = 1
--GROUP BY	T4.FileGroupName


			BEGIN	-- BUILD @RC (RESTORE CHAIN)
				---------------------------------------------------------------------------------
				---------------------------------------------------------------------------------
				--	POPULATE @RC (RESTORE CHAIN) WITH THE ENDING POINTS
				---------------------------------------------------------------------------------
				---------------------------------------------------------------------------------
				;WITH		MaxDates
						AS
						(
						SELECT		T4.FileGroupName
									,MAX([BackupDateRange_End]) [BackupDateRange_End]
						FROM		@HL T3
						JOIN		@FL T4
							ON		T3.BackupFileName = T4.BackupFileName
							AND		T4.FileGroupName IS NOT NULL
						WHERE		T4.IsPresent = 1
						GROUP BY	T4.FileGroupName
						)
				INSERT INTO	@RC
				SELECT		DISTINCT
							T1.BackupType
							,T1.FirstLSN
							,T1.LastLSN
							,T1.DatabaseBackupLSN
							,T1.BackupFileName
							,T2.FileGroupName
							,1 as[ReverseOrder]
				FROM		@HL T1
				JOIN		@FL T2
					ON		T1.BackupFileName = T2.BackupFileName
				WHERE		T2.IsPresent = 1
					AND	T2.FileGroupName IS NOT NULL
					AND	T1.[BackupDateRange_Start]	<= COALESCE(@RestoreToDateTime, (SELECT [BackupDateRange_End] FROM MaxDates WHERE FileGroupName = T2.FileGroupName))
					AND	T1.[BackupDateRange_End]	>= COALESCE(@RestoreToDateTime, (SELECT [BackupDateRange_End] FROM MaxDates WHERE FileGroupName = T2.FileGroupName))


--SELECT 6666,* FROM @RC ORDER BY FirstLSN DESC
				---------------------------------------------------------------------------------
				---------------------------------------------------------------------------------
				--	POPULATE @RC (RESTORE CHAIN) BY WALKING BACKWARDS FROM EXISTING ENTRIES
				---------------------------------------------------------------------------------
				---------------------------------------------------------------------------------


				WHILE @@ROWCOUNT > 0
				BEGIN
					INSERT INTO	@RC
					SELECT		DISTINCT
								T1.BackupType
								,T1.FirstLSN
								,T1.LastLSN
								,T1.DatabaseBackupLSN
								,T1.BackupFileName
								,T1.FileGroupName
								,T2.[ReverseOrder]+1 [ReverseOrder]
					FROM		(
							SELECT		DISTINCT
										T1.BackupType
										,T1.FirstLSN
										,T1.LastLSN
										,T1.CheckpointLSN
										,T1.DatabaseBackupLSN
										,T1.BackupFileName
										,T2.FileGroupName
										,1 as[ReverseOrder]
							FROM		@HL T1
							JOIN		@FL T2
								ON		T1.BackupFileName = T2.BackupFileName
							WHERE		T2.IsPresent = 1
								AND		T2.FileGroupName IS NOT NULL
							) T1
					JOIN		@RC T2
						ON	(	-- ADD LOGS
								T1.BackupType = 2
							AND	T2.BackupType = 2
							AND	T2.FirstLSN = T1.LastLSN
							)
						OR	(	-- ADD DIFF
								T1.BackupType = 5
							AND	T2.BackupType = 2
							AND	T2.LastLSN >= T1.LastLSN
							AND	T2.FirstLSN <= T1.LastLSN
							)
						OR	(	-- ADD FULL
								T1.BackupType = 1
							AND	T2.BackupType IN (2,5)
							AND	(
								T1.FirstLSN = T2.DatabaseBackupLSN
								OR
								T1.DatabaseBackupLSN = T2.DatabaseBackupLSN
								OR
								T1.CheckPointLSN = T2.DatabaseBackupLSN
								)
							)
						OR	(	-- ADD FULL
								T1.BackupType = 4
							AND	T2.BackupType IN (2,5)
							AND	(
								T1.DatabaseBackupLSN = T2.DatabaseBackupLSN
								OR
								T1.CheckPointLSN = T2.DatabaseBackupLSN
								)
							)
					WHERE		T1.BackupFileName NOT IN (SELECT BackupFileName FROM @RC)
				END
			END	-- BUILD @RC (RESTORE CHAIN)


--SELECT 5555,* FROM @RC ORDER BY FirstLSN DESC


			BEGIN	-- DELETE @SF(SORCE FILES) NOT IN @RC (RESTORE CHAIN)
				DELETE
				FROM		@SF
				WHERE		Mask NOT IN	(
								SELECT		BackupFileName
								FROM		@RC T1
								WHERE		[ReverseOrder] =	(
													SELECT	MAX([ReverseOrder])
													FROM	@RC
													WHERE	BackupFileName = T1.BackupFileName
													)
								)
			END     -- DELETE @SF(SORCE FILES) NOT IN @RC (RESTORE CHAIN)


			IF @Verbose >= 1
				RAISERROR('    -- Done Cleaning Backup Files',-1,-1) WITH NOWAIT

		END						-- CLEANUP BACKUP FILES


--SELECT 4444,* FROM @SF


		BEGIN	-- REPORT BACKUP FILE AND HEADER INFO


			SELECT	T1.Mask																				[Name]
					,T2.ServerName																		[FromServer]
					,T1.BackupType																		[Type]
					,T1.BackupEngine																	[Engine]
					,T1.BackupSetSize																	[SetSize]
					,COUNT(*)																			[Files]
					,SUM(CAST(T1.Size AS NUMERIC(38,2))/POWER(1024.,3))									[Size_GB]
					,MAX(CAST(CAST(T2.BackupSize AS NUMERIC(38,10))/POWER(1024.0,2) AS NUMERIC(38,2)))	[Size]
			INTO		#TMP2
			FROM		@SF T1
			LEFT JOIN	@HL T2
				ON	T1.Mask = T2.BackupFileName
			GROUP BY	T1.Mask
					,T2.ServerName
					,T1.BackupType
					,T1.BackupEngine
					,T1.BackupSetSize


			IF @Verbose >= 1
			BEGIN
				DECLARE CreateHeadersCursor CURSOR
				FOR
				SELECT		name
							,xtype
							,colid
				FROM		TempDB..syscolumns
				WHERE		id = OBJECT_ID('tempdb..#TMP2')
				ORDER BY	colid


				SELECT		@FMT1			= ''
							,@FMT2			= ''
							,@HeaderLine	= ''


				OPEN CreateHeadersCursor
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP2'
						SET @CMD4 = '@ColumnSize INT OUTPUT'
						EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT


						IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
							SET @ColumnSize = LEN(@ColumnName)


						SELECT		@FMT1		= @FMT1 + '{'+CAST(@ColID-1 AS VARCHAR(5))+',-'+CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@FMT2		= @FMT2 + '{'+CAST(@ColID-1 AS VARCHAR(5))+','+ CASE @xtype WHEN 108 THEN '' ELSE '-' END + CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
								,@ColName1	= CASE @ColID WHEN 1 THEN @ColumnName ELSE COALESCE(@ColName1,'') END
								,@ColName2	= CASE @ColID WHEN 2 THEN @ColumnName ELSE COALESCE(@ColName2,'') END
								,@ColName3	= CASE @ColID WHEN 3 THEN @ColumnName ELSE COALESCE(@ColName3,'') END
								,@ColName4	= CASE @ColID WHEN 4 THEN @ColumnName ELSE COALESCE(@ColName4,'') END
								,@ColName5	= CASE @ColID WHEN 5 THEN @ColumnName ELSE COALESCE(@ColName5,'') END
								,@ColName6	= CASE @ColID WHEN 6 THEN @ColumnName ELSE COALESCE(@ColName6,'') END
								,@ColName7	= CASE @ColID WHEN 7 THEN @ColumnName ELSE COALESCE(@ColName7,'') END
								,@ColName8	= CASE @ColID WHEN 8 THEN @ColumnName ELSE COALESCE(@ColName8,'') END
								,@ColName9	= CASE @ColID WHEN 9 THEN @ColumnName ELSE COALESCE(@ColName9,'') END


					END
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				END
				CLOSE CreateHeadersCursor
				DEALLOCATE CreateHeadersCursor


				SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
						+ @HeaderLine +@CRLF
				SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,Name,FromServer,Type,Engine,SetSize,Files,Size_GB,Size,'','') +@CRLF
				FROM		#TMP2


				RAISERROR('/* =================================================== BACKUP FILE PROPERTIES =================================================== --',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				PRINT @TBL
				RAISERROR('',-1,-1) WITH NOWAIT
			END


			SELECT		DISTINCT
					T2.BackupFileName [Name]
					,T2.FirstLSN
					,T2.LastLSN
					,T2.DatabaseBackupLSN
			INTO		#TMP3
			FROM		@HL T2


			IF @Verbose >= 1
			BEGIN
				DECLARE CreateHeadersCursor CURSOR
				FOR
				SELECT		name
						,xtype
						,colid
				FROM		TempDB..syscolumns
				WHERE		id = OBJECT_ID('tempdb..#TMP3')
				ORDER BY	colid


				SELECT		@FMT1		= ''
						,@FMT2		= ''
						,@HeaderLine	= ''


				OPEN CreateHeadersCursor
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP3'
						SET @CMD4 = '@ColumnSize INT OUTPUT'
						EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT

						IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
							SET @ColumnSize = LEN(@ColumnName)


						SELECT		@FMT1		= @FMT1 + '{'+CAST(@ColID-1 AS VARCHAR(5))+',-'+CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@FMT2		= @FMT2 + '{'+CAST(@ColID-1 AS VARCHAR(5))+','+ CASE @xtype WHEN 108 THEN '' ELSE '-' END + CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
								,@ColName1	= CASE @ColID WHEN 1 THEN @ColumnName ELSE @ColName1 END
								,@ColName2	= CASE @ColID WHEN 2 THEN @ColumnName ELSE @ColName2 END
								,@ColName3	= CASE @ColID WHEN 3 THEN @ColumnName ELSE @ColName3 END
								,@ColName4	= CASE @ColID WHEN 4 THEN @ColumnName ELSE @ColName4 END
								,@ColName5	= CASE @ColID WHEN 5 THEN @ColumnName ELSE @ColName5 END
								,@ColName6	= CASE @ColID WHEN 6 THEN @ColumnName ELSE @ColName6 END
								,@ColName7	= CASE @ColID WHEN 7 THEN @ColumnName ELSE @ColName7 END
								,@ColName8	= CASE @ColID WHEN 8 THEN @ColumnName ELSE @ColName8 END
								,@ColName9	= CASE @ColID WHEN 9 THEN @ColumnName ELSE @ColName9 END
					END
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				END
				CLOSE CreateHeadersCursor
				DEALLOCATE CreateHeadersCursor


				SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
						+ @HeaderLine +@CRLF
				SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,Name,FirstLSN,LastLSN,DatabaseBackupLSN,'','','','','','') +@CRLF
				FROM		#TMP3


				RAISERROR('/* ==================================================== BACKUP FILE LSN RANGES ==================================================== --',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				PRINT @TBL
				RAISERROR('',-1,-1) WITH NOWAIT
			END


			SELECT		DISTINCT
						T1.Mask [Name]
						,CONVERT(VarChar(50),T1.BackupTimeStamp,1)			BackupTimeStamp
						,CONVERT(VarChar(50),T2.BackupStartDate,1)			BackupStartDate
						,CONVERT(VarChar(50),T2.BackupFinishDate,1)			BackupFinishDate
						,CONVERT(VarChar(50),T2.BackupDateRange_Start,1)	BackupDateRange_Start
						,CONVERT(VarChar(50),T2.BackupDateRange_End,1)		BackupDateRange_End
						,CONVERT(VarChar(50),T2.BackupChainStartDate,1)		BackupChainStartDate
						,CONVERT(VarChar(50),T2.BackupLinkStartDate,1)		BackupLinkStartDate

			INTO		#TMP4
			FROM		@SF T1
			LEFT JOIN	@HL T2 	ON	T1.Mask = T2.BackupFileName


			IF @Verbose >= 1
			BEGIN
				DECLARE CreateHeadersCursor CURSOR
				FOR
				SELECT		name
							,xtype
							,colid
				FROM		TempDB..syscolumns
				WHERE		id = OBJECT_ID('tempdb..#TMP4')
				ORDER BY	colid


				SELECT		@FMT1			= ''
							,@FMT2			= ''
							,@HeaderLine	= ''


				OPEN CreateHeadersCursor
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP4'
						SET @CMD4 = '@ColumnSize INT OUTPUT'
						EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT

						IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
							SET @ColumnSize = LEN(@ColumnName)


						SELECT		@FMT1		= @FMT1 + '{'+CAST(@ColID-1 AS VARCHAR(5))+',-'+CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@FMT2		= @FMT2 + '{'+CAST(@ColID-1 AS VARCHAR(5))+','+ CASE @xtype WHEN 108 THEN '' ELSE '-' END + CAST(@ColumnSize AS VARCHAR(5))+'} '
								,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
								,@ColName1	= CASE @ColID WHEN 1 THEN @ColumnName ELSE @ColName1 END
								,@ColName2	= CASE @ColID WHEN 2 THEN @ColumnName ELSE @ColName2 END
								,@ColName3	= CASE @ColID WHEN 3 THEN @ColumnName ELSE @ColName3 END
								,@ColName4	= CASE @ColID WHEN 4 THEN @ColumnName ELSE @ColName4 END
								,@ColName5	= CASE @ColID WHEN 5 THEN @ColumnName ELSE @ColName5 END
								,@ColName6	= CASE @ColID WHEN 6 THEN @ColumnName ELSE @ColName6 END
								,@ColName7	= CASE @ColID WHEN 7 THEN @ColumnName ELSE @ColName7 END
								,@ColName8	= CASE @ColID WHEN 8 THEN @ColumnName ELSE @ColName8 END
								,@ColName9	= CASE @ColID WHEN 9 THEN @ColumnName ELSE @ColName9 END
					END
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				END
				CLOSE CreateHeadersCursor
				DEALLOCATE CreateHeadersCursor


				SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
						+ @HeaderLine +@CRLF
				SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,Name,BackupTimeStamp,BackupStartDate,BackupFinishDate,BackupDateRange_Start,BackupDateRange_End,BackupChainStartDate,BackupLinkStartDate,'','') +@CRLF
				FROM		#TMP4


				RAISERROR('/* =================================================== BACKUP FILE  DATE RANGES =================================================== --',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				PRINT @TBL
				RAISERROR('',-1,-1) WITH NOWAIT
				RAISERROR('-- ================================================================================================================================ */',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
			END


--RAISERROR('A1',-1,-1) WITH NOWAIT
SELECT * INTO #FLX FROM @FL
--RAISERROR('A2',-1,-1) WITH NOWAIT


			SELECT		LogicalName
						--,PhysicalName
						,Drives.RootFolder [DriveLetter]
						,NEW_PhysicalName
						,MAX(CASE [dbo].[dbaudf_GetFileProperty](NEW_PhysicalName,'FILE','Exists') WHEN 'True' THEN 1 ELSE 0 END) [FileExists]
						,MAX(CASE [dbo].[dbaudf_GetFileProperty](NEW_PhysicalName,'FILE','Exists') WHEN 'True' THEN CAST(CAST([dbo].[dbaudf_GetFileProperty](NEW_PhysicalName,'FILE','Length') AS NUMERIC(38,10))/CAST(POWER(1024.0,3) AS NUMERIC(38,10)) AS NUMERIC(38,10)) ELSE 0 END) [ExistingSizeGB]
						,MAX(CAST(CAST(Drives.FreeSpace AS NUMERIC(38,10))/CAST(POWER(1024.0,3) AS NUMERIC(38,10)) AS NUMERIC(38,10))) [DriveFreeGB]
						,MAX(CAST(CAST(Size AS NUMERIC(38,10))/CAST(POWER(1024.0,3) AS NUMERIC(38,10)) AS NUMERIC(38,10))) [SizeGB]
						,MAX(CAST(CAST(MaxSize AS NUMERIC(38,10))/CAST(POWER(1024.0,3) AS NUMERIC(38,10)) AS NUMERIC(38,10))) [MaxSizeGB]
			INTO		#DBFileSpaceCheck
			FROM		#FLX
			LEFT JOIN	dbo.dbaudf_ListDrives() Drives		ON	Drives.RootFolder = [dbo].[dbaudf_GetFileProperty](NEW_PhysicalName,'file','RootFolder')
			WHERE		IsPresent = 1
				AND		(type = 'L' OR @filegroups IS NULL OR FileGroupName IN (Select SplitValue FROM [dbo].[dbaudf_StringToTable](@filegroups,',')))
			GROUP BY	LogicalName
						--,PhysicalName
						,Drives.RootFolder
						--,LEFT(NEW_PhysicalName,1)
						,NEW_PhysicalName


--SELECT 3333,* FROM @FL
--SELECT 2222,* FROM #DBFileSpaceCheck


			IF @Verbose >= 1
			BEGIN
				DECLARE CreateHeadersCursor CURSOR
				FOR
				SELECT		name
							,xtype
							,colid
				FROM		TempDB..syscolumns
				WHERE		id = OBJECT_ID('tempdb..#DBFileSpaceCheck')
				ORDER BY	colid


				SELECT		@FMT1			= ''
							,@FMT2			= ''
							,@HeaderLine	= ''


				OPEN CreateHeadersCursor
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #DBFileSpaceCheck'
						SET @CMD4 = '@ColumnSize INT OUTPUT'
						EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT

						IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
							SET @ColumnSize = LEN(@ColumnName)


						SELECT		@FMT1			= @FMT1 + '{'+CAST(@ColID-1 AS VARCHAR(5))+',-'+CAST(@ColumnSize AS VARCHAR(5))+'} '
									,@FMT2			= @FMT2 + '{'+CAST(@ColID-1 AS VARCHAR(5))+','+ CASE @xtype WHEN 108 THEN '' ELSE '-' END + CAST(@ColumnSize AS VARCHAR(5))+'} '
									,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
									,@ColName1		= CASE @ColID WHEN 1 THEN @ColumnName ELSE @ColName1 END
									,@ColName2		= CASE @ColID WHEN 2 THEN @ColumnName ELSE @ColName2 END
									,@ColName3		= CASE @ColID WHEN 3 THEN @ColumnName ELSE @ColName3 END
									,@ColName4		= CASE @ColID WHEN 4 THEN @ColumnName ELSE @ColName4 END
									,@ColName5		= CASE @ColID WHEN 5 THEN @ColumnName ELSE @ColName5 END
									,@ColName6		= CASE @ColID WHEN 6 THEN @ColumnName ELSE @ColName6 END
									,@ColName7		= CASE @ColID WHEN 7 THEN @ColumnName ELSE @ColName7 END
									,@ColName8		= CASE @ColID WHEN 8 THEN @ColumnName ELSE @ColName8 END
									,@ColName9		= CASE @ColID WHEN 9 THEN @ColumnName ELSE @ColName9 END
					END
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				END
				CLOSE CreateHeadersCursor
				DEALLOCATE CreateHeadersCursor


				SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
						+ @HeaderLine +@CRLF
				SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,LogicalName,DriveLetter,New_PhysicalName,FileExists,ExistingSizeGB,DriveFreeGB,SizeGB,MaxSizeGB,'','') +@CRLF
				FROM		#DBFileSpaceCheck


				RAISERROR('/* ================================================= NEW FILE AND SIZE PROPERTIES ================================================= --',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				PRINT @TBL
				RAISERROR('',-1,-1) WITH NOWAIT
				RAISERROR('-- ================================================================================================================================ */',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
			END


			IF @Verbose >= 1
			BEGIN
				DECLARE CreateHeadersCursor CURSOR
				FOR
				SELECT		name
							,xtype
							,colid
				FROM		TempDB..syscolumns
				WHERE		id = OBJECT_ID('tempdb..#TMP1')
				ORDER BY	colid


				SELECT		@FMT1			= ''
							,@FMT2			= ''
							,@HeaderLine	= ''


				OPEN CreateHeadersCursor
				FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SET @CMD3 = 'SET ANSI_WARNINGS OFF;SELECT @ColumnSize = MAX(LEN(['+@ColumnName+'])) FROM #TMP1'
						SET @CMD4 = '@ColumnSize INT OUTPUT'
						EXEC sp_executesql @CMD3,@CMD4,@ColumnSize=@ColumnSize OUTPUT

						IF LEN(@ColumnName) > COALESCE(@ColumnSize,0)
							SET @ColumnSize = LEN(@ColumnName)


						SELECT		@FMT1			= @FMT1 + '{'+CAST(@ColID-1 AS VARCHAR(5))+',-'+CAST(@ColumnSize AS VARCHAR(5))+'} '
									,@FMT2			= @FMT2 + '{'+CAST(@ColID-1 AS VARCHAR(5))+','+ CASE @xtype WHEN 108 THEN '' ELSE '-' END + CAST(@ColumnSize AS VARCHAR(5))+'} '
									,@HeaderLine	= @HeaderLine + REPLICATE('_',@ColumnSize) + ' '
									,@ColName1		= CASE @ColID WHEN 1 THEN @ColumnName ELSE @ColName1 END
									,@ColName2		= CASE @ColID WHEN 2 THEN @ColumnName ELSE @ColName2 END
									,@ColName3		= CASE @ColID WHEN 3 THEN @ColumnName ELSE @ColName3 END
									,@ColName4		= CASE @ColID WHEN 4 THEN @ColumnName ELSE @ColName4 END
									,@ColName5		= CASE @ColID WHEN 5 THEN @ColumnName ELSE @ColName5 END
									,@ColName6		= CASE @ColID WHEN 6 THEN @ColumnName ELSE @ColName6 END
									,@ColName7		= CASE @ColID WHEN 7 THEN @ColumnName ELSE @ColName7 END
									,@ColName8		= CASE @ColID WHEN 8 THEN @ColumnName ELSE @ColName8 END
									,@ColName9		= CASE @ColID WHEN 9 THEN @ColumnName ELSE @ColName9 END
					END
					FETCH NEXT FROM CreateHeadersCursor INTO @ColumnName,@xtype,@ColID
				END
				CLOSE CreateHeadersCursor
				DEALLOCATE CreateHeadersCursor


				SET		@TBL = [dbo].[dbaudf_FormatString](@FMT1,@ColName1,@ColName2,@ColName3,@ColName4,@ColName5,@ColName6,@ColName7,@ColName8,@ColName9,'') +@CRLF
						+ @HeaderLine +@CRLF
				SELECT		@TBL = @TBL + [dbo].[dbaudf_FormatString](@FMT2,DriveLetter,SizeGB,AvailableGB,FreeGB,DriveType,FileSystem,IsReady,VolumeName,RootFolder,'') +@CRLF
				FROM		#TMP1


				RAISERROR('/* =================================================== CURRENT DRIVE PROPERTIES =================================================== --',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				PRINT @TBL
				RAISERROR('',-1,-1) WITH NOWAIT
				RAISERROR('-- ================================================================================================================================ */',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
			END


		END		-- REPORT BACKUP FILE AND HEADER INFO


		BEGIN	-- CHECK FOR EXISTING FILES


			DECLARE DBFileExistsCursor CURSOR
			FOR
			SELECT		[LogicalName]
						,[NEW_PhysicalName]
			FROM		#DBFileSpaceCheck
			WHERE		FileExists = 1


			IF @Verbose >= 1
				RAISERROR('  -- Checking for Existing Files',-1,-1) WITH NOWAIT


			OPEN DBFileExistsCursor
			FETCH NEXT FROM DBFileExistsCursor INTO @LogicalName,@NewPhysicalName
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2) AND @Verbose >= 0
				BEGIN
					RAISERROR('      -- WARNING: File "%s" at "%s" Already Exists.',-1,-1,@LogicalName,@NewPhysicalName) WITH NOWAIT
				END
				FETCH NEXT FROM DBFileExistsCursor INTO @LogicalName,@NewPhysicalName
			END
			CLOSE DBFileExistsCursor
			DEALLOCATE DBFileExistsCursor

			IF @Verbose >= 1
				RAISERROR('',-1,-1) WITH NOWAIT


		END					-- CHECK FOR EXISTING FILES


		IF	-- CHECK FOR SPACE
		@IgnoreSpaceLimits = 0
		BEGIN	-- CHECK FOR SPACE


			DECLARE DBFileSpaceCursor CURSOR
			FOR
			SELECT		DriveLetter
						,MAX(DriveFreeGB) [DriveFreeSpace]
						,SUM(ExistingSizeGB) [ExistingSize]
						,SUM(SizeGB) [Size]
			FROM		#DBFileSpaceCheck
			GROUP BY	DriveLetter
			HAVING		MAX(DriveFreeGB) < (SUM(SizeGB)-SUM(ExistingSizeGB))


			SET	@SkipFlag = 0 --RESET TO 0 BEFORE CURSOR


			IF @Verbose >= 1
				RAISERROR('  -- Checking for Drive Space',-1,-1) WITH NOWAIT


			OPEN DBFileSpaceCursor
			FETCH NEXT FROM DBFileSpaceCursor INTO @DriveLetter,@DriveFreeSpace,@ExistingSize,@Size
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2) AND @Verbose >= 0
				BEGIN
					RAISERROR('      -- ERROR: THERE IS NOT ENOUGH SPACE ON DRIVE %s:',-1,-1,@DriveLetter) WITH NOWAIT
					RAISERROR('      --------- YOU MUST FREE UP SPACE OR RELOCATE',-1,-1) WITH NOWAIT
					RAISERROR('      --------- FILES TO ANOTHER DRIVE BEFORE RESTORING',-1,-1) WITH NOWAIT
					RAISERROR('',-1,-1) WITH NOWAIT
					SET @SkipFlag = 1
				END
				FETCH NEXT FROM DBFileSpaceCursor INTO @DriveLetter,@DriveFreeSpace,@ExistingSize,@Size
			END
			CLOSE DBFileSpaceCursor
			DEALLOCATE DBFileSpaceCursor

			IF @Verbose >= 1
				RAISERROR('',-1,-1) WITH NOWAIT


			IF @SkipFlag = 1
				GOTO SkipRestore


		END	-- CHECK FOR SPACE


		BEGIN	-- BUILD RESTORE SCRIPT


			IF @Verbose >= 1
			BEGIN
				RAISERROR('  -- Starting DB Restore''s',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
			END


--SELECT 1111,* FROM @FL

			IF @WorkDir IS NOT NULL
			BEGIN		-- COPY FILES TO LOCAL WORK DIRECTORY AND RESTORE FROM THERE


				;WITH		Settings
						AS
						(
						SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
									,'false'	AS [ForceOverwrite]	-- true,false
									,1			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
									,300		AS [UpdateInterval]	-- rate of progress updates in Seconds
						)
						,CopyFile -- MoveFile, DeleteFile
						AS
						(
						SELECT		T1.FullPathName		AS [Source]
									,@WorkDir + T1.Name	AS [Destination]
						FROM		@SF T1
						LEFT JOIN	(
							SELECT		DISTINCT
										[dbo].[dbaudf_GetFileFromPath]([physical_device_name]) [Name]
										,[physical_device_name] AS [Path]
										,rh.destination_database_name DBName
							FROM		msdb.dbo.restorehistory rh
							JOIN		[msdb].[dbo].[backupset] bs
								ON		rh.backup_set_id = bs.backup_set_id
							JOIN		[msdb].[dbo].[backupmediafamily] bmf
								ON		bmf.[media_set_id] = bs.[media_set_id]
							WHERE		rh.destination_database_name = @NewDBName


							) T2
						ON	T2.[name] LIKE T1.[Name]

						WHERE		-- NEW DATABASE DOES NOT EXIST
								DB_ID(@NewDBName) IS NULL
							OR	(@FullReset = 1
								-- DATABASE IS CURRENTLY RESTORING
							OR	(DATABASEPROPERTYEX(@NewDBName,'Status') = 'RESTORING' AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
								-- DATABASE IS CURRENTLY A LOGSHIPED STANDBY
							OR	(DATABASEPROPERTYEX(@NewDBName,'IsInStandBy') = 1 AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
								)
						)
				SELECT		@CMD =	[dbo].[dbaudf_FormatXML2String]((
								SELECT		*
											,(SELECT * FROM CopyFile FOR XML RAW ('CopyFile'), TYPE)
								FROM		Settings
								FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
								))


				SELECT		@syntax_out	= COALESCE(@syntax_out,'')
								+ @CRLF
								+ 'DECLARE	@Data XML'
								+ @CRLF
								+ 'SET	@Data		='
								+ @CRLF
								+ ''''+ @CMD + ''''
								+ @CRLF
								+ 'exec [dbo].[dbasp_FileHandler] @Data'
								+ @CRLF


			END


			----------------------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------------------------
			--	CLEAR BACKUP AND RESTORE HISTORY FOR THE DATABASE IF IT IS A FULL RESET
			----------------------------------------------------------------------------------------------------
			----------------------------------------------------------------------------------------------------


			DECLARE @DontDrop BIT = 0
			IF NOT EXISTS (SELECT * FROM @SF WHERE BackupType = 'DB')
				SET @DontDrop = 1


			IF @FullReset = 1 AND @DontDrop = 0-- DROP EXISTING DATABASE AND DELETE BACKUP HISTORY
			BEGIN
				SET @syntax_out	= COALESCE(@syntax_out,'')
								+ @CRLF
								+ 'IF DB_ID('''+@NewDBName+''') IS NOT NULL' + @CRLF
								+ '	EXEC DBAOps.dbo.dbasp_DropDatabase '''+@NewDBName+''''+ @CRLF
								+ @CRLF
			END


			IF @NotFirstInChain = 0 OR @UseGO = 1
			SET @syntax_out	= COALESCE(@syntax_out,'')
							+ @CRLF
							+ 'DECLARE @FilesRestored INT' + @CRLF
							+ @CRLF


			SET @syntax_out	= COALESCE(@syntax_out,'')
							+ @CRLF
							+ 'SET @FilesRestored = 0' + @CRLF
							+ @CRLF

			DECLARE RestoreDBCursor CURSOR
			FOR
			SELECT		*
						, ROW_NUMBER() OVER(ORDER BY [RestoreOrder] desc,[FGID] desc,[BackupTimeStamp] desc,[BackupType] desc) RevOrder
			FROM		(
					SELECT		DISTINCT
								CASE T1.BackupType WHEN 'TL' THEN 3 WHEN 'DF' THEN 2 ELSE 1 END [RestoreOrder]
								,T1.BackupTimeStamp
								,T1.[BackupType]
								,T1.[FileGroup]
								,T1.[BackupEngine]
								,T1.[BackupSetSize]
								,T1.Mask [Name]
								,(
									SELECT		MIN(FileGroupId)
									FROM		@FL
									WHERE		BackupFileName = T1.[Mask]
										AND	isPresent = 1
										AND	FileGroupId > 0


								) FGID
					FROM		@SF T1
					LEFT JOIN	(
							SELECT		DISTINCT
										[dbo].[dbaudf_GetFileFromPath]([physical_device_name]) [Name]
										,[physical_device_name] AS [Path]
										,rh.destination_database_name DBName
							FROM		msdb.dbo.restorehistory rh
							JOIN		[msdb].[dbo].[backupset] bs
								ON		rh.backup_set_id = bs.backup_set_id
							JOIN		[msdb].[dbo].[backupmediafamily] bmf
								ON		bmf.[media_set_id] = bs.[media_set_id]
							WHERE		rh.destination_database_name = @NewDBName
								AND		@FullReset = 0 --DONT RETURN ANY IF FULL RESET
							) T2
						ON	T2.[name] LIKE T1.[Name]

					WHERE		-- NEW DATABASE DOES NOT EXIST
							DB_ID(@NewDBName) IS NULL
						OR	(@FullReset = 1
							-- DATABASE IS CURRENTLY RESTORING
						OR	(DATABASEPROPERTYEX(@NewDBName,'Status') = 'RESTORING' AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
							-- DATABASE IS CURRENTLY A LOGSHIPED STANDBY
						OR	(DATABASEPROPERTYEX(@NewDBName,'IsInStandBy') = 1 AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
							)
					) Data
			ORDER BY	1,8,2,3


			DELETE #FLst


			OPEN RestoreDBCursor
			FETCH NEXT FROM RestoreDBCursor INTO @RestoreOrder,@BackupTimeStamp,@BackupType,@FileGroup,@BackupEngine,@SetSize,@FileName,@FGID,@RevOrder
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
					--SELECT @RestoreOrder,@BackupTimeStamp,@BackupType,@FileGroup,@BackupEngine,@SetSize,@FileName,@FGID,@RevOrder,@FilePath
					SET @FN = @FileName


					SET @FilesRestored = @FilesRestored + 1


					IF OBJECT_ID('tempdb..#FLst_Last') IS NULL
						SELECT	*
						INTO	#FLst_Last
						FROM	#FLst
					ELSE
						INSERT INTO	#FLst_Last
						SELECT		*
						FROM		#FLst


					DELETE		#FLst


--SELECT		BackupFileName , @FilePath+@FileName
--FROM		@FL


					INSERT INTO	#FLst
					SELECT		*
					FROM		@FL
					WHERE		BackupFileName = @FilePath+@FileName
						OR	BackupFileName = @FileName


					IF @BackupType NOT IN ('DB','FG','PI') AND DB_ID(@NewDBName) IS NOT NULL
						INSERT INTO	#FLst_Last
						SELECT		*
						FROM		#FLst
						WHERE		LogicalName IN (SELECT name FROM sys.master_files WHERE database_id = DB_ID(@NewDBName))


					SET		@FileNameSET = NULL


					SELECT		@Replace1	= REPLACE(REPLACE(REPLACE(@FileName,'$','\$'),'_SET_[0-9][0-9]','_SET_(?<set>[0-9][0-9])'),'_OF_[0-9][0-9]','_OF_(?<size>[0-9][0-9])')
								,@Replace2	= REPLACE(REPLACE(REPLACE(@FileName,'_SET_[0-9][0-9]','_SET_${set}'),'_OF_[0-9][0-9]','_OF_${size}'),'\$','$')

--SELECT @FileName,@FilePath

					IF @SetSize < 10
					BEGIN
						IF @WorkDir IS NOT NULL
							SELECT		@FileNameSET = REPLACE(dbo.dbaudf_ConcatenateUnique('DISK = '''+@WorkDir + T1.Name+''''+ @CRLF),',','       ,')
							FROM		dbo.dbaudf_DirectoryList2(@FilePath,NULL,@IncludeSubDir) T1
							WHERE		T1.Name LIKE @FileName
						ELSE
							SELECT		@FileNameSET = REPLACE(dbo.dbaudf_ConcatenateUnique('DISK = '''+T1.FullPathName+''''+ @CRLF),',','       ,')
							FROM		dbo.dbaudf_DirectoryList2(@FilePath,NULL,@IncludeSubDir) T1
							WHERE		T1.Name LIKE @FileName
					END
					ELSE
					BEGIN
					IF @WorkDir IS NOT NULL
						SELECT		@FileNameSET =	REPLACE (
										REPLACE	(
											DBAOps.[dbo].[dbaudf_RegexReplace]	(
																dbo.dbaudf_ConcatenateUnique	(
																					'DISK = '''
																					+ DBAOps.[dbo].[dbaudf_RegexReplace]	(
																										'$WD$'+ T1.Name
																										,@Replace1
																										,'${set}x${size}'
																										)
																					+ ''''+ @CRLF
																					)
																,'(?<set>[0-9][0-9])x(?<size>[0-9][0-9])'
																,@Replace2
																)
											,'$WD$'
											,@WorkDir
											)
											,',','       ,')


						FROM		dbo.dbaudf_DirectoryList2(@FilePath,NULL,@IncludeSubDir) T1
						WHERE		T1.Name LIKE @FileName
					ELSE
						SELECT		@FileNameSET =
										REPLACE	(
										REPLACE	(
											DBAOps.[dbo].[dbaudf_RegexReplace]	(
																dbo.dbaudf_ConcatenateUnique	(
																					'DISK = '''
																					+ DBAOps.[dbo].[dbaudf_RegexReplace]	(
																										REPLACE(T1.FullPathName,@FilePath,'$FP$')
																										,@Replace1
																										,'${set}x${size}'
																										)
																					+ ''''+ @CRLF
																					)
																,'(?<set>[0-9][0-9])x(?<size>[0-9][0-9])'
																,@Replace2
																)
											,'$FP$'
											,@FilePath
											)
											,',','       ,')


						FROM		dbo.dbaudf_DirectoryList2(@FilePath,NULL,@IncludeSubDir) T1
						WHERE		T1.Name LIKE @FileName
					END
					--PRINT		@FileNameSET
					SET		@FileName = @FileNameSET


--SELECT * FROM #FLst

					IF EXISTS (SELECT * FROM #FLst WHERE isPresent = 0)
						AND EXISTS (SELECT * FROM #FLst WHERE isPresent = 1 AND FileGroupId = 1)
						SET @Partial_flag = 1
					ELSE
						SET @Partial_flag = 0

					IF	-- FULL OR DIFF BACKUP FILE
					@BackupType IN ('DB','FG','DF','PI')
					BEGIN
						IF @BackupEngine = 'Idera'
							SET @CMD = 'EXEC [master].[dbo].[xp_ss_restore]	@database ='''+ @NewDBName + ''' '
						ELSE
							SET @CMD = 'RESTORE DATABASE ['+ @NewDBName + '] '
				--PRINT @CMD
						IF @FileGroup IS NOT NULL
							SELECT	@CMD = @CMD + dbo.dbaudf_ConcatenateUnique('FILEGROUP = '''+FileGroupName+'''')
							FROM	#FLst
							WHERE	isPresent = 1

				--PRINT @CMD
						IF @BackupEngine = 'Idera'
							SET @CMD = @CMD + @CRLF +'	,' + REPLACE(@FileName,'DISK =','@filename =') +  @CRLF
						ELSE
							SET @CMD = @CMD + @CRLF +'FROM    '+@FileName+ @CRLF
				--PRINT @CMD
						--SET @CMD	= @CMD
						--		+ 'WITH    '
						--		+ CASE @partial_flag
						--			WHEN 1 THEN 'PARTIAL, '
						--			ELSE '' END
						--		+ 'NORECOVERY, REPLACE' + @CRLF


				-- ADD ALL "WITH" PARAMETERS
				IF @BackupEngine != 'Idera'
					SELECT        @CMD	= @CMD
								+ '  WITH  '
								+ REPLACE(dbo.dbaudf_ConcatenateUnique (WithOptions),',',@CRLF+'        ,')
								--+ @CRLF
					FROM		(
							SELECT CASE @partial_flag WHEN 1 THEN 'PARTIAL' END					UNION ALL
							SELECT 'NORECOVERY'									UNION ALL
							SELECT 'REPLACE'									UNION ALL
							SELECT CASE WHEN @MaxTransferSize IS NOT NULL
									THEN 'MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS VarChar(10)) END	UNION ALL
							SELECT CASE WHEN @BufferCount IS NOT NULL
									THEN 'BUFFERCOUNT = ' + CAST(@BufferCount AS VarChar(10)) END
							) Data([WithOptions])
					WHERE		[WithOptions] IS NOT NULL
				ELSE
					SET		@CMD = @CMD +'	,@replace = 1, @recoverymode = ''norecovery''' + @CRLF
				--PRINT @CMD
				--PRINT '-----------------------------------'
						IF @BackupType IN ('DB','FG','PI')
						-- DB BACKUPS SHOULD ONLY USE MOVE PARAMETERS FOR DEVICES THAT ARE IN THAT BACKUP FILE
						-- FILEGROUP BACKUPS MAY CONTAIN SOME OR ALL OF THE FILES.
						BEGIN
							SELECT		@CMD	= @CMD + CASE @BackupEngine
															WHEN 'Idera'
															THEN REPLACE(ISNULL(@CRLF+'        ,'+NULLIF(REPLACE(dbo.dbaudf_Concatenate ('@withmove = ''' + LogicalName + ' "' + REPLACE(NEW_PhysicalName,',','~') + '"'''),',',@CRLF+'        ,'),''),''),'~',',')
															ELSE REPLACE(ISNULL(@CRLF+'        ,'+NULLIF(REPLACE(dbo.dbaudf_Concatenate ('MOVE ''' + LogicalName + ''' TO ''' + REPLACE(NEW_PhysicalName,',','~') + ''''),',',@CRLF+'        ,'),''),''),'~',',')
															END
							FROM		#FLst
							WHERE		isPresent = 1
								AND	(type = 'L' OR @filegroups IS NULL OR FileGroupName IN (Select SplitValue FROM [dbo].[dbaudf_StringToTable](@filegroups,',')))
						END
						ELSE
						-- DIFFERENTIAL BACKUPS SHOULD ONLY USE MOVE PARAMETERS FOR DEVICES THAT ARE NEW IN THAT BACKUP FILE
						BEGIN
							SELECT		@CMD	= @CMD + CASE @BackupEngine
															WHEN 'Idera'
															THEN REPLACE(ISNULL(@CRLF+'        ,'+NULLIF(REPLACE(dbo.dbaudf_Concatenate ('@withmove = ''' + LogicalName + ' ' + REPLACE(NEW_PhysicalName,',','~') + ''''),',',@CRLF+'        ,'),''),''),'~',',')
															ELSE REPLACE(ISNULL(@CRLF+'        ,'+NULLIF(REPLACE(dbo.dbaudf_Concatenate ('MOVE ''' + LogicalName + ''' TO ''' + REPLACE(NEW_PhysicalName,',','~') + ''''),',',@CRLF+'        ,'),''),''),'~',',')
															END
							FROM		#FLst T1
							WHERE		isPresent = 1
								AND	(type = 'L' OR @filegroups IS NULL OR FileGroupName IN (Select SplitValue FROM [dbo].[dbaudf_StringToTable](@filegroups,',')))
								AND	NOT EXISTS(SELECT * FROM #FLst_Last WHERE isPresent = 1 AND LogicalName = T1.LogicalName)
						END
					END


				--PRINT @CMD
				--PRINT '-----------------------------------'


					IF	-- TRANSACTION LOG BACKUP FILE
					@BackupType = 'TL'
					BEGIN
						SET @CMD	= 'RESTORE LOG ['+@NewDBName+'] FROM '+@FileName
								+ CASE WHEN @StandBy IS NOT NULL AND @RevOrder = 1 THEN ' WITH STANDBY = '''+@StandBy+'''' ELSE ' WITH NORECOVERY' END
								+ CASE	WHEN @RestoreToDateTime IS NOT NULL
									THEN ', STOPAT = N'''+CAST(@RestoreToDateTime AS VarChar(50))+''''
									ELSE '' END


						SELECT		@CMD = @CMD
								+ '        ,MOVE ''' + LogicalName + ''' TO ''' + NEW_PhysicalName + '''' + @CRLF
						FROM		#FLst T1
						WHERE		isPresent = 1
							AND	FileGroupName IN (Select SplitValue FROM [dbo].[dbaudf_StringToTable](@filegroups,','))
							AND	NOT EXISTS(SELECT * FROM #FLst_Last WHERE isPresent = 1 AND LogicalName = T1.LogicalName)
						ORDER BY	T1.FileID
					END

					IF	-- REDGATE SYNTAX
					@BackupEngine = 'RedGate'
					BEGIN
						SET @CMD = 'Exec master.dbo.sqlbackup ''-SQL "' + REPLACE(
													REPLACE(
													REPLACE(
													REPLACE(
													REPLACE(@CMD,CHAR(9),' ')
														,@CRLF,' ')
														,'''','''''')
														,'  ',' ')
														,'  ',' ')
														+'"'''
					END
					ELSE IF @BackupEngine = 'Idera'
						SET @CMD = @CMD + @CRLF
					ELSE	-- MICROSOFT SYNTAX
					BEGIN
						SET @CMD = @CMD + @CRLF + '        ,STATS=1' + @CRLF
					END
			--PRINT @CMD
					SET @CMD	= 'RAISERROR (''Restoring File "'+COALESCE(@FN,'???')+'"'',-1,-1) WITH NOWAIT'+ @CRLF
							+ @CMD + @CRLF
							+ 'SET @FilesRestored = @FilesRestored + 1'+ @CRLF


			--PRINT @CMD
					IF @UseTryCatch = 1
						SET @CMD	= 'BEGIN TRY' + @CRLF
								+ CHAR(9) + REPLACE(@CMD,@CRLF,@CRLF+CHAR(9)) + @CRLF
								+ 'END TRY' + @CRLF

								+ 'BEGIN CATCH' + @CRLF
								+ '	EXEC dbo.dbasp_GetErrorInfo' + @CRLF
								+ 'END CATCH' + @CRLF
								+ @CRLF


			--PRINT @CMD
					IF @Verbose >= 2
					BEGIN
						PRINT '   -- ' + REPLACE(@CMD,@CRLF,@CRLF+'   -- ')
						RAISERROR('',-1,-1) WITH NOWAIT
					END


					SET	@syntax_out	= COALESCE(@syntax_out,'')
								+ @CRLF
								+ COALESCE(@CMD,'') -- USE COALESCE TO MAKE SURE THAT ONE BAD ENTRY DOES NOT NULL THE STRING


			--PRINT @syntax_out


					-- ADD EXISTING FILELIST TO THE SUMMARY SO THAT YOU CAN TELL IF A DEVICE IS NEW
					-- TO THE DATABASE WITHIN THE CURRENT BACKUP FILE
					INSERT INTO	#FLst_Last
					SELECT		*
					FROM		#FLst

				END
				FETCH NEXT FROM RestoreDBCursor INTO @RestoreOrder,@BackupTimeStamp,@BackupType,@FileGroup,@BackupEngine,@SetSize,@FileName,@FGID,@RevOrder
			END


			CLOSE RestoreDBCursor
			DEALLOCATE RestoreDBCursor


			IF @LeaveNORECOVERY = 0 AND @FilesRestored > 0
			BEGIN
				SET @CMD = 'RESTORE DATABASE ['+@NewDBName+'] WITH RECOVERY'


				IF @Verbose >= 2
				BEGIN
					PRINT '   -- ' + REPLACE(@CMD,@CRLF,@CRLF+'   -- ')
					RAISERROR('',-1,-1) WITH NOWAIT
				END


				SET	@syntax_out	= COALESCE(@syntax_out,'')
							+ @CRLF
							+ COALESCE(@CMD,'') -- USE COALESCE TO MAKE SURE THAT ONE BAD ENTRY DOES NOT NULL THE STRING
			END


			SET @syntax_out	= COALESCE(@syntax_out,'')
					+ @CRLF
					+ 'SELECT @FilesRestored' + @CRLF
					+ 'IF @FilesRestored > 0' + @CRLF
					+ '	RAISERROR(''DATABASE WAS UPDATED'',-1,-1) WITH NOWAIT' + @CRLF
					+ 'ELSE' + @CRLF
					+ '	RAISERROR(''DATABASE WAS NOT UPDATED'',16,1) WITH NOWAIT' + @CRLF
					+ CASE @UseGO WHEN 1 THEN 'GO'  ELSE '' END + @CRLF
					+ @CRLF


			IF @WorkDir IS NOT NULL AND  @DeleteWorkFiles = 1
			BEGIN		-- DELETE FILES FROM LOCAL WORK DIRECTORY


				;WITH		Settings
						AS
						(
						SELECT		32		AS [QueueMax]		-- Max Number of files coppied at once.
								,'false'	AS [ForceOverwrite]	-- true,false
								,1		AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
								,300		AS [UpdateInterval]	-- rate of progress updates in Seconds
						)
						,DeleteFile
						AS
						(
						SELECT		@WorkDir + T1.Name	AS [Source]
						FROM		@SF T1
						LEFT JOIN	(
							SELECT		DISTINCT
									[dbo].[dbaudf_GetFileFromPath]([physical_device_name]) [Name]
									,[physical_device_name] AS [Path]
									,rh.destination_database_name DBName
							FROM		msdb.dbo.restorehistory rh
							JOIN		[msdb].[dbo].[backupset] bs
								ON	rh.backup_set_id = bs.backup_set_id
							JOIN		[msdb].[dbo].[backupmediafamily] bmf
								ON	bmf.[media_set_id] = bs.[media_set_id]
							WHERE		rh.destination_database_name = @NewDBName


							) T2
						ON	T2.[name] LIKE T1.[Name]

						WHERE		-- NEW DATABASE DOES NOT EXIST
								DB_ID(@NewDBName) IS NULL
							OR	(@FullReset = 1
								-- DATABASE IS CURRENTLY RESTORING
							OR	(DATABASEPROPERTYEX(@NewDBName,'Status') = 'RESTORING' AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
								-- DATABASE IS CURRENTLY A LOGSHIPED STANDBY
							OR	(DATABASEPROPERTYEX(@NewDBName,'IsInStandBy') = 1 AND  (@FullReset = 1 OR (T2.[Name] IS NULL AND BackupType != 'db')))
								)
						)
				SELECT		@CMD =	[dbo].[dbaudf_FormatXML2String]((
								SELECT		*
										,(SELECT * FROM DeleteFile FOR XML RAW ('DeleteFile'), TYPE)
								FROM		Settings
								FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
								))


				SELECT		@syntax_out	= COALESCE(@syntax_out,'')
								+ @CRLF
								+ 'SET	@Data		='
								+ @CRLF
								+ ''''+ @CMD + ''''
								+ @CRLF
								+ 'exec [dbo].[dbasp_FileHandler] @Data'
								+ @CRLF


			END


			IF @Verbose >= 1
			BEGIN
				RAISERROR('  -- Done with DB Restore''s',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
				RAISERROR('',-1,-1) WITH NOWAIT
			END


		END	-- BUILD RESTORE SCRIPT


		SkipRestore:


	END	-- SCRIPT DATABASE RESTORE


	IF @Verbose >= 1
		RAISERROR('-- Done --',-1,-1) WITH NOWAIT


	--  Finalization  -------------------------------------------------------------------
	label99:


	BEGIN	-- SET ANY OUTPUT PARAMETERS NOT ALREADY SET


		SELECT		@OverrideXML	=	(
							SELECT		DISTINCT
									LogicalName
									,PhysicalName
									,New_PhysicalName
							FROM		@FL
							FOR XML RAW ('Override'),TYPE, ROOT('RestoreFileLocations')
							)
				,@ForceEngine	= @BackupEngine
				,@ForceSetSize	= @SetSize
				,@ForceFileName	= @FileName


	END	-- SET ANY OUTPUT PARAMETERS NOT ALREADY SET

	IF @Verbose >= 1
	BEGIN
		RAISERROR('',-1,-1) WITH NOWAIT
		RAISERROR('',-1,-1) WITH NOWAIT
	END
GO
GRANT EXECUTE ON  [dbo].[dbasp_format_BackupRestore] TO [public]
GO
