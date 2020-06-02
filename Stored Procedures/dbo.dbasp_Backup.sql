SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup] 
				(
				@DBname				sysname			= null
				,@PlanName			sysname			= null
				,@Mode				CHAR(2)			= null
				,@BkUpPath			varchar(4000)	= null
				,@backup_name		sysname			= null
				,@DeletePrevious	varchar(10)		= 'none' --'before', 'after' or 'none'
				,@FileGroups		VarChar(MAX)	= null
				,@ForceEngine		SYSNAME			= NULL
				,@ForceCompression	bit				= null
				,@ForceChecksum		BIT				= null
				,@ForceLocal		BIT				= 0
				,@CopyOnly			BIT				= 0
				,@process_mode		sysname			= 'normal'
				,@auto_diff			char(1)			= 'n'
				,@ForceSetSize		INT				= null
				,@BufferCount		INT				= NULL
				,@MaxTransferSize	INT				= NULL
				,@ForceB2Null		BIT				= NULL
				,@IgnoreMaintOvrd	BIT				= 0
				,@IgnoreB2NullOvrd	BIT				= 0
				,@DaysToKeep		INT				= 14
				,@verbose			INT				= 1
				,@FP				BIT				= 0
				)
 

/***************************************************************
 **  Stored Procedure dbasp_Backup                  
 **  Written by Steve Ledridge, Virtuoso                
 **  September 05, 2013                                      
 **
 **  This procedure is used for various 
 **  database backup processing.
 **
 **  This proc accepts several input parms: 
 **
 **  Either @dbname or @planname is required.
 **
 **  - @dbname is the name of the database to be backed up.
 **
 **  - @PlanName is the maintenance plane name if one is being used.
 **
 **  - @Mode is the backup mode (BF = full, BD = differential, BL = t-log)
 **
 **  - @BkUpPath is the target output path (optional)
 **
 **  - @backup_name can be used to override the backup file name
 **    when backing up a single database. (optional)
 ** 
 **  - @DeletePrevious ('before', 'after' or 'none') indicates if
 **    and when you want to delete the previous backup file(s).
 **
 **  - @FileGroups is used for FG processing ('All', 'None', 'FGname' or null).
 ** 
 **  - @ForceEngine can force the backup engine that is used ('MSSQL' or 'REDGATE').
 **
 **  - @ForceCompression (0=off, 1=on) indicates if you want to force compression processing.
 ** 
 **  - @ForceChecksum (0=off, 1=on) will force the checksum option for the backup process.
 ** 
 **  - @ForceLocal (0=off, 1=on) will force the backup process to the local backup share.
 ** 
 **  - @CopyOnly will set the CopyOnly option for the backup process (0=off, 1=on).
 ** 
 **  - @process_mode (normal, pre_release, post_release)
 **    is for special processing where the backup file is written to a 
 **    sub folder of the backup share. forced to be a full backup and copy only
 ** 
 **  - @auto_diff (y or n) creates a differential backup for all
 **    non-system processed databases.
 **
 **  - @ForceSetSize sets the number of files used for multi-file backup processing (64 max).
 **
 **	WARNING: BufferCount and MaxTransferSize values can cause Memory Errors
 **	   The total space used by the buffers is determined by: buffercount * maxtransfersize * DB_Data_Devices
 **	   blogs.msdn.com/b/sqlserverfaq/archive/2010/05/06/incorrect-buffercount-data-transfer-option-can-lead-to-oom-condition.aspx
 **
 **	@BufferCount		If Specified, Forces Value to be used				  X	  X
 **	@MaxTransferSize	If Specified, Forces Value to be used (specifiy in bytes e.g. 524288 = 512kb)
 **	
 ***************************************************************/
  as
SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	==============================================
--	09/05/2013	Steve Ledridge				New all in one backup process based on dbasp_backupDBs 
--	11/20/2013	Steve Ledridge				New delete old file processing. 
--	12/02/2013	Steve Ledridge				Revised backup cleanup for File Groups. 
--	12/26/2013	Steve Ledridge				Set size for companion diff to 1. 
--	01/06/2014	Steve Ledridge				Fixed missing #filelist table. 
--	03/07/2014	Steve Ledridge				Delete previous before is now the default. 
--	03/10/2014	Steve Ledridge				New check for full backup before diff or tran. 
--	08/19/2014	Steve Ledridge				Added code to check for AvailGrp. 
--	10/28/2014	Steve Ledridge				Added Parameters for @MaxTransferSize and @BufferCount to be used for both Backup and Restore Database scripts.
--	11/24/2014	Steve Ledridge				Added Code to check if database is preferred backup replica
--	02/19/2015	Steve Ledridge				Added Code to check if database is Primary Replica.
--	03/02/2015	Steve Ledridge				Test for availability groups being enabled.
--	03/18/2015	Steve Ledridge				Prevent Full Backups for Calc Databases in Calc Window
--	04/08/2015	Steve Ledridge				Made sure that Master Database is excluded from Calcs Window forced Differential Backups.
--	05/28/2015	Steve Ledridge				Added input parm @ForceLocal.
--	02/01/2016	Steve Ledridge				Fixed Test for DB in an availability group.
--	01/20/2017	Steve Ledridge				Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	04/03/2017	Steve Ledridge				Changed Standard Paths to Virtuoso Standards
--											Modified PlanName to refer to Recovery Model
--	08/08/2017	Steve Ledridge				Delete None is now the default and cleanup will be another sproc
--	11/06/2019	Steve Ledridge				Modified Process to save Backups in Directory named by Listener if in an AG.
--   BLA BLA BLA
--	======================================================================================


DECLARE		@miscprint					nvarchar(4000)
			,@cmd						nvarchar(4000)
			,@syntax_out				varchar(max)
			,@retcode					int
			,@std_backup_path			nvarchar(255)
			,@outpath 					nvarchar(500)
			,@outpath2					nvarchar(500)
			,@outpath_archive			nvarchar(500)
			,@fileexist_path			nvarchar(500)
			,@error_count				int
			,@Attempt_Count				int
			,@parm01					nvarchar(100)
			,@charpos					int
			,@exists 					bit
			,@backup_type				sysname
			,@save_delete_mask_db		sysname
			,@save_delete_mask_diff		sysname
			,@save_FileGroups			VarChar(MAX) 
			,@hold_FileGroups			VarChar(MAX)
			,@delete_Data_db			XML 
			,@delete_Data_diff			XML 
			,@hold_single_FG			sysname
			,@hold_dd_id				int
			,@a							int
			,@b							int
			,@save_productversion		sysname
			,@CalcWindow				nVarChar(50)
			,@save_DBname				sysname

DECLARE		@PathTree					VarChar(Max)
			,@Size						BIGINT
			,@FreeSpace					BIGINT
			,@diffPrediction			INT
			,@tmpvar1					VarChar(max)
			,@tmpvar2					VarChar(max)
			,@tmpvar3					VarChar(max)

			-- GET PATHS FROM [dbo].[dbasp_GetPaths]
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

--  Create Temp Tables
declare @DBnames table	(name sysname)

declare @filegroupnames table (
			 name sysname
			,data_space_id int)

create table #DirectoryTempTable(cmdoutput nvarchar(255) null)

create table #DBdelete(dd_id [int] IDENTITY(1,1) NOT NULL
			,delete_Data_db XML null)

create table #fileexists ( 
	doesexist smallint,
	fileindir smallint,
	direxist smallint)

--DROP TABLE IF EXISTS #FGs2
CREATE TABLE	#FGs2
		(
		id					INT
		,name				SYSNAME
		,size				DECIMAL(15, 2)
		) 


			----------------  initial values  -------------------
			SELECT		@error_count				= 0
						,@exists					= 0
						,@Attempt_Count				= 1



--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--								CHECK INPUT PARAMETERS
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

If @Mode is null or @Mode not in ('BF', 'BD', 'BL')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @Mode parm must be ''BF'', ''BD'' or ''BL''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If (@DBname is null or @DBname = '') and (@backup_name is not null)
   begin
	Print 'DBA Warning:  Invalid input parameters.  @backup_name can only be set for single DB backups.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @DeletePrevious not in ('before', 'after', 'none')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DeletePrevious parm must be ''before'', ''after'' or ''none''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @process_mode not in ('normal', 'pre_release', 'post_release')
   begin
	Print 'DBA Warning: Invalid input parameter.  @process_mode parm must be ''normal'', ''pre_release'', ''post_release''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If nullif(@PlanName,'') IS NOT NULL
BEGIN 
	IF @PlanName NOT IN ('SIMPLE','FULL','BULK_LOGGED','ALL','SYSTEMDBS','USERDBS')
   BEGIN
		Print 'DBA WARNING: Invaild parameter passed to dbasp_backup - @PlanName parm is invalid (SIMPLE,FULL,BULK_LOGGED,ALL,SYSTEMDBS,USERDBS'
		Select @error_count = @error_count + 1
		Goto label99
	END

	RAISERROR('Process mode: Maintenance plan = %s',-1,-1,@PlanName) WITH NOWAIT
END
ELSE IF NULLIF(@DBname,'') IS NOT NULL
BEGIN
	If not exists(select 1 from master.sys.databases where name = @DBname AND source_database_id	IS NULL)
	   begin
		Print 'DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
		Select @error_count = @error_count + 1
		Goto label99
	END

	RAISERROR('Process mode: Single DB = %s',-1,-1,@DBname) WITH NOWAIT
END
ELSE
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DBname or @PlanName must be specified'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @ForceSetSize is not null and @ForceSetSize > 64
   begin
	Print 'DBA WARNING: Invaild parameter passed to dbasp_backup - @ForceSetSize max is 64.'
	Select @error_count = @error_count + 1
	Goto label99
   end



If @backup_name is not null
   begin
	Select @auto_diff = 'n'
   end

-- TRANLOG BACKUPS WILL ALWAYS BE NORMAL
 IF @Mode = 'BL'
	SET @process_mode = 'normal'

-- PRE AND POST RELEASE BACKUPS ARE ALWAYS FULL AND COPY_ONLY
IF @process_mode IN('pre_release','post_release')
BEGIN
	SET @CopyOnly = 1
	SET @Mode = 'BF'
END




/****************************************************************
 *                MainLine
 ***************************************************************/
--  Populate temp table with DB's to process
delete from @DBnames

If @PlanName is not null
   begin
	IF @PlanName IN ('SIMPLE','FULL','BULK_LOGGED')
		INSERT INTO	@DBnames
		SELECT		name
		FROM		sys.databases 
		WHERE		state_desc			= 'ONLINE'
			AND		database_id			> 4			-- EXCLUDE SYSTEM DB'S
			AND		recovery_model_desc = @PlanName 
			AND		source_database_id	IS NULL		-- NOT A SNAPSHOT
	
	IF @PlanName = 'ALL'
		INSERT INTO	@DBnames
		SELECT		name 
		FROM		sys.databases 
		WHERE		state_desc = 'ONLINE'
			AND		database_id > 4					-- EXCLUDE SYSTEM DB'S 
			AND		source_database_id	IS NULL		-- NOT A SNAPSHOT
		
	IF @PlanName = 'USERDBS'
		INSERT INTO	@DBnames
		SELECT		name 
		FROM		sys.databases 
		WHERE		state_desc = 'ONLINE'
			AND		database_id > 4 
			AND		source_database_id	IS NULL		-- NOT A SNAPSHOT

	IF @PlanName = 'SYSTEMDBS'
	BEGIN
		INSERT INTO	@DBnames
		SELECT		name 
		FROM		sys.databases 
		WHERE		state_desc = 'ONLINE'
			AND		database_id <= 4 
			AND		source_database_id	IS NULL		-- NOT A SNAPSHOT

		SET			@Mode = 'BF'					-- ONLY FULL BACKUPS OF SYSTEM DATABASES
	END

	-------------------------------------------------------------
	-------------------------------------------------------------
	--	SKIP DATABASE IF OVERRIDE EXISTS
	-------------------------------------------------------------
	-------------------------------------------------------------
	DELETE @DBnames WHERE name IN (select Detail01 from dbo.Local_Control where subject = 'backup_Skip_by_Plan')

	-- EXAMPLE TO ADD ENTRY
	-- INSERT INTO dbo.Local_Control VALUES ('backup_skip_by_plan','{DBName}',null,null)

   END
ELSE
   BEGIN
	insert into @DBnames (name) values(@DBname)
   END

DELETE @DBnames WHERE name = 'TempDB'
        
--select * from @DBnames
If (select count(*) from @DBnames) = 0
BEGIN
	Print 'DBA Error:  No databases selected for backup.'
	select * from @DBnames
	Select @error_count = @error_count + 1
	Goto label99
END

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
--					START OF DB LOOP
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
start_dbnames:

Select	@save_DBname	= (select top 1 name from @DBnames order by name)
		,@Attempt_Count	= 0

RAISERROR( ' Starting with %s DB Loop',-1,-1,@save_DBname)WITH NOWAIT

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
--					START OF ATTEMPT LOOP
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
start_attempts:

		--------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------
		--								SET BACKUP PATHS
		--
		--		@std_backup_path		= Calculated Path
		--		@BkUpPath				= Forced Parameter Path
		--		@outpath				= Actual Destination for Backup File
		---------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------


			-- GET PATHS FROM [dbo].[dbasp_GetPaths]
			EXEC dbo.dbasp_GetPaths
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

		SELECT	@BackupPathN			= REPLACE(@BackupPathN			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))
				,@BackupPathN2			= REPLACE(@BackupPathN2			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))
				,@BackupPathA			= REPLACE(@BackupPathA			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))

		--------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------
		--									RESET FOR PROCESSING MODE
		--------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------
		--		@BkUpPath
		--------------------------------------------------------------------------------------------
		IF @BkUpPath IS NOT NULL
		BEGIN
			IF @process_mode = 'pre_release'
				SET @BkUpPath = @BkUpPath + 'pre_release\'
			ELSE IF @process_mode = 'post_release'
				SET @BkUpPath = @BkUpPath + 'post_release\'
		END
		--------------------------------------------------------------------------------------------
		--		@BackupPathN
		--------------------------------------------------------------------------------------------
		IF @process_mode = 'pre_release'
			SET @BackupPathN = @BackupPathN + 'pre_release\'
		ELSE IF @process_mode = 'post_release'
			SET @BackupPathN = @BackupPathN + 'post_release\'
		--------------------------------------------------------------------------------------------
		--		@BackupPathN2
		--------------------------------------------------------------------------------------------
		IF @process_mode = 'pre_release'
			SET @BackupPathN2 = @BackupPathN2 + 'pre_release\'
		ELSE IF @process_mode = 'post_release'
			SET @BackupPathN2 = @BackupPathN2 + 'post_release\'
		--------------------------------------------------------------------------------------------
		--		@BackupPathL
		--------------------------------------------------------------------------------------------
		IF @process_mode = 'pre_release'
			SET @BackupPathL = @BackupPathL + 'pre_release\'
		ELSE IF @process_mode = 'post_release'
			SET @BackupPathL = @BackupPathL + 'post_release\'
		--------------------------------------------------------------------------------------------
		--		@EnvBackupPath
		--------------------------------------------------------------------------------------------
		IF @EnvBackupPath IS NOT NULL
		BEGIN
			IF @process_mode = 'pre_release'
				SET @EnvBackupPath = @EnvBackupPath + 'pre_release\'
			ELSE IF @process_mode = 'post_release'
				SET @EnvBackupPath = @EnvBackupPath + 'post_release\'
		END

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

		SET		@PathTree =		CASE  
									WHEN @ForceLocal = 1 THEN ISNULL(@BackupPathL		+'|','')
									WHEN @BkUpPath IS NOT NULL THEN ISNULL(@BkUpPath		+'|','') + ISNULL(@BackupPathL		+'|','')
									ELSE	ISNULL(@EnvBackupPath	+'|','')
										+	ISNULL(@BackupPathN		+'|','')
										+	ISNULL(@BackupPathN2	+'|','')
										+	ISNULL(@BackupPathL		+'|','')
									END

		IF @Verbose > 0 
			RAISERROR('-- Using Backup Locations [%s].',-1,-1,@PathTree) WITH NOWAIT

		SELECT		@Attempt_Count	= @Attempt_Count + 1
					,@outpath		= nullif(dbo.dbaudf_ReturnPart(@PathTree,@Attempt_Count),'')
					,@outpath2		= @outpath

		BEGIN	-- GET ESTIMATED BACKUP SIZE
			DELETE #FGs2

			-- BUILD LIST OF CURRENT FILE GROUPS IN DATABASE		
			Select @CMD		= REPLACE('USE [{DBNAME}];
							SET NOCOUNT ON;
							SET ANSI_WARNINGS OFF; 
							INSERT INTO	#FGs2
							SELECT		fg.data_space_id
									,fg.name
									,COALESCE((cast((sum(a.used_pages) * 8192) as decimal(15, 2))*40)/100,0) 
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

			IF @Mode = 'BF'
			BEGIN
				-- GET THE SIZE OF THE SELECTED FILEGROUP(s) OR ALL FILEGROUPS IF @FileGroup IS NULL OR 'ALL'
				IF NULLIF(@filegroups,'ALL') IS NOT NULL
				BEGIN
					SELECT @Size = SUM(size) FROM #FGs2 WHERE name in  (SELECT SplitValue FROM dbo.[dbaudf_StringToTable](@filegroups,','))
				END
				ELSE
					SELECT @Size = SUM(size) FROM #FGs2
			END
			Else If @Mode = 'BD'
			BEGIN
      
				exec dbo.dbasp_Estimate_Diff_Size @DBName = @DBname, @diffPrediction = @diffPrediction output
				Select @size = convert(float, @diffPrediction)
			END
		END

		IF @Verbose > 0 RAISERROR('  Attempt Number %d.',-1,-1,@Attempt_Count) WITH NOWAIT
		IF @Verbose > 0 RAISERROR('  @outpath [%s].',-1,-1,@outpath) WITH NOWAIT
		--IF @Verbose > 0 RAISERROR('  @outpath2 [%s].',-1,-1,@outpath2) WITH NOWAIT

		BEGIN -- Check Path for FreeSpace
			select @Freespace = TRY_CAST(dbo.dbaudf_GetFileProperty(@outpath,'folder','AvailableFreeSpace') AS BigInt)

			SELECT	@tmpvar1	= dbo.dbaudf_formatBytes(@size,'bytes')
					,@tmpvar2	= dbo.dbaudf_formatBytes(@Freespace,'bytes')
	
			IF @Verbose > 0 RAISERROR('   Backup Estimated Size [%s].',-1,-1,@tmpvar1) WITH NOWAIT
			IF @Verbose > 0 RAISERROR('   Path Free Space [%s].',-1,-1,@tmpvar2) WITH NOWAIT

			IF @Freespace < @size
			BEGIN
				RAISERROR('DBA Warning: [%s] requires %s freespace and "%s" only has %s Free.',-1,-1,@save_DBname,@tmpvar1,@outpath,@tmpvar2) WITH NOWAIT
				RAISERROR('		Skipping this path.',-1,-1) WITH NOWAIT
				IF @Attempt_Count >5
					GOTO loop_end
				ELSE
					GOTO start_attempts
			END
		END

		IF @outpath IS NULL
		BEGIN
			RAISERROR('DBA ERROR: No More Path Options Aborting Backup.',-1,-1) WITH NOWAIT
			SET @error_count = @error_count + 1
			goto label99
		END
		---------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------
		--			DATABASE AVAILABILITY GROUP CHECKS
		---------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------
		IF @@microsoftversion / 0x01000000 >= 11
		  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
		BEGIN
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			--			CHECK IF DATABASE IS IN AVAILABILITY GROUP
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------

			SET @a = 0
			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
			SELECT @cmd = 'SELECT @a = 1 FROM master.sys.dm_hadr_database_replica_states WHERE database_id = db_id(''' + @save_DBname  + ''')'
			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@a int output', @a output

			IF @a = 0
			   BEGIN
				RAISERROR('DBA Note: DB %s is not in an Always On Availability Group.  Backups are unchanged from normal.', -1,-1,@save_DBname) with nowait
				GOTO AGCheck_end
			   END

			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			--			CHECK IF DATABASE IS PREFERRED REPLICA
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------

			SET @a = 0
			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
			SELECT @cmd = 'SELECT @a = sys.fn_hadr_backup_is_preferred_replica (''' + @save_DBname  + ''')'
			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@a int output', @a output

			IF @a = 0
			   BEGIN
				RAISERROR('DBA Note: Skipping DB %s.  This DB is not the prefered replica in an Always On Availability Group.', -1,-1,@save_DBname) with nowait
				GOTO loop_end
			   END
			ELSE
				RAISERROR('DBA Note: DB %s is the prefered replica in an Always On Availability Group.', -1,-1,@save_DBname) with nowait


			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			--			CHECK IF DATABASE IS PRIMARY REPLICA
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			SET @a = 0
			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
	
			-- ONLY VALID IN SQL 2014
			--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @save_DBname  + ''')'

			Select @cmd = 'SELECT	@a = ars.role
									,@b = ar.secondary_role_allow_connections		
					FROM		sys.dm_hadr_availability_replica_states ars
					JOIN	sys.databases dbs
						ON	ars.replica_id = dbs.replica_id
					JOIN	sys.availability_replicas ar
						ON	ar.replica_id = ars.replica_id
					WHERE		dbs.name = ''' + @save_DBname  + ''';
					SET	@a	= COALESCE(@a,1)'

			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@a int output, @b int output', @a output, @b output

			IF @a != 1
			   BEGIN
				--print @save_DBname
				IF @b = 0
					   BEGIN
						RAISERROR('DBA Note: Skipping DB %s.  This DB is not a readable replica in an Always On Availability Group.', -1,-1,@save_DBname) with nowait
						GOTO loop_end
					   END 

				raiserror('DBA Note: DB %s is NOT the Primary Replica. No Differential Backups can be done and Full Backups must be COPY_ONLY.', -1,-1,@save_DBname) with nowait

				-- Force Full Backups IF not Primary and trying to do a Differential.
				IF @Mode = 'BD'
					SET @Mode = 'BF'

				-- Force Copy Only for Full Backups.
				IF @Mode = 'BF'
					SET @CopyOnly = 1
			   END
			ELSE
				raiserror('DBA Note: DB %s is the Primary Replica. Backups are unchanged from normal.', -1,-1,@save_DBname) with nowait

		   AGCheck_end:
		END

		Print ' '
		Print '=========================================================================== '
		Print '** Start Backup Processing for DB: ' + @save_DBname
		Print '=========================================================================== '
		Print ' '

		-------------------------------------------------------------
		-------------------------------------------------------------
		--	RESET PER-DATABASE BACKUP PATH IF OVERRIDE EXISTS
		-------------------------------------------------------------
		-------------------------------------------------------------
		-- USE EXAMPLE:
		--	INSERT INTO dbo.Local_Control(Subject,Detail01,Detail02) VALUES ('backup_location_override','{DBNAME}','{PATH}')
		--
		-------------------------------------------------------------
		-------------------------------------------------------------
		SELECT		@OutPath2 = CASE RIGHT(Detail02,1) WHEN '\' THEN Detail02 ELSE Detail02+'\' END
		from		dbo.Local_Control 
		WHERE		subject = 'backup_location_override'
			AND	Detail01 = @save_DBname

		If not exists (select 1 from master.sys.databases where name = @save_DBname)
		   begin
			Print 'DBA Warning:  Skip backup for missing DB: ' + @save_DBname
			goto loop_end
		   end

		-------------------------------------------------------------
		-------------------------------------------------------------
		--
		--	IF DATABASE IS LOGSHIPPING PRIMARY DO NOT BACKUP TRANLOG
		--
		-------------------------------------------------------------
		-------------------------------------------------------------
		IF @Mode = 'BL' and @save_DBname in (SELECT primary_database from msdb.dbo.log_shipping_primary_databases)
		   begin
			Select @miscprint = 'DBA INFO: Database (' + @save_DBname + ') is a Logshipping Primary DB, dbasp_backup cannot be used to do t-log backup'
			raiserror(@miscprint,-1,-1)
			goto loop_end
		   end

		IF @Mode = 'BL' and databaseproperty(@save_DBname, 'IsTrunclog') <> 0
		   begin
			Select @miscprint = 'DBA INFO: Database (' + @save_DBname + ') is not in full recovery mode.  Transaction log backup request is being skipped.'
			raiserror(@miscprint,-1,-1)
			goto loop_end
		   end


		-------------------------------------------------------------
		-------------------------------------------------------------
		--	RESET TO FORCE FULL IF OVERRIDE EXISTS
		-------------------------------------------------------------
		-------------------------------------------------------------
		-- USE EXAMPLE:
		--	INSERT INTO dbo.Local_Control(Subject,Detail01,Detail02) VALUES ('backup_force_always_full','{DBNAME}','{MODE}')
		--
		-------------------------------------------------------------
		-------------------------------------------------------------
		IF EXISTS (SELECT * FROM dbo.Local_Control WHERE subject = 'backup_force_always_full' AND Detail01 = @save_DBname AND Detail02 = @Mode)
			SET @Mode = 'BF'


		--  Check for filegroup backup
		Select @save_FileGroups = null

		If @mode = 'BF'
		BEGIN
			If @FileGroups is not null
			   begin
				Select @save_FileGroups = @FileGroups
			   end
			Else If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@save_DBname))
			   begin
				Select @save_FileGroups = 'all'
			   end
		END

   
		--  Set up for delete processing
		Select @backup_type = CASE @Mode WHEN 'BF' THEN '_db_'
										 WHEN 'BD' THEN '_dfntl_'
										 WHEN 'BL' THEN '_tlog_'
										 END



If @save_FileGroups is null or @save_FileGroups = 'none'
   begin
	Print 'Backup Type for File cleanup is ' + @backup_type + '.'

	Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

	SELECT @delete_Data_db = 
	( 
	SELECT FullPathName [Source] 
	FROM dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
	FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
	) 
	Insert into #DBdelete values(@delete_Data_db)
	--SELECT * from #DBdelete 
   end
Else
   begin
	Select @charpos = charindex(',', @save_FileGroups)

	If @save_FileGroups = 'all'
	   begin
		Select @backup_type = ''
		Select @backup_type = '_FG'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 
	   end
	Else IF @charpos = 0
	   begin
		Select @backup_type = ''
		Select @backup_type = '_FG$' + @save_FileGroups + '_'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 
	   end
	Else
	   begin
		Select @hold_FileGroups = rtrim(@save_FileGroups)
		Select @hold_FileGroups = reverse(@hold_FileGroups)
		If left(@hold_FileGroups, 1) <> ','
		   begin
			Select @hold_FileGroups = ',' +  @hold_FileGroups
			Select @hold_FileGroups = reverse(@hold_FileGroups)
		   end

		start_FGnames_parse:

		Select @hold_single_FG = left(@hold_FileGroups, @charpos-1)

		Select @backup_type = ''
		Select @backup_type = '_FG$' + @hold_single_FG + '_'

		Print 'Backup Type for File cleanup is ' + @backup_type + '.'

		Select @save_delete_mask_db = @save_DBname + @backup_type + '*.*'

		SELECT @delete_Data_db = 
		( 
		SELECT FullPathName [Source] 
		FROM dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_db, 0) 
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
		) 
		Insert into #DBdelete values(@delete_Data_db)
		--SELECT * from #DBdelete 

		Select @hold_FileGroups = substring(@hold_FileGroups, @charpos+1, len(@hold_FileGroups)-@charpos)
		Select @hold_FileGroups = ltrim(rtrim(@hold_FileGroups))

		Select @charpos = charindex(',', @hold_FileGroups)
		If @charpos > 0
		   begin
			goto start_FGnames_parse
		   end
	   end
   end
--SELECT * from #DBdelete 


Select @save_delete_mask_diff = @save_DBname + '_dfntl_*.*'

SELECT @delete_Data_diff = 
( 
SELECT FullPathName [Source] 
FROM dbo.dbaudf_DirectoryList2(@outpath2, @save_delete_mask_diff, 0) 
FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
) 
--SELECT @delete_Data_diff 


--  Delete older files (if requested)
If @DeletePrevious = 'before' and @mode = 'BF' and @CopyOnly = 0
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older backup files'
	Print '=========================================================================== '
	Print ' '
	Start_DBdelete_before:
	If (Select count(*) from #DBdelete) > 0
	   begin
		Select @hold_dd_id = (select top 1 dd_id from #DBdelete)
		Select @delete_Data_db = (select delete_Data_db from #DBdelete where dd_id = @hold_dd_id) 

		If @delete_Data_db is not null
		   begin
			exec dbo.dbasp_FileHandler @delete_Data_db
		   end

		Delete from #DBdelete where dd_id = @hold_dd_id

		goto Start_DBdelete_before
	   end

	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbo.dbasp_FileHandler @delete_Data_diff
	   end
   end
Else If @mode = 'BD' and @DeletePrevious = 'before'
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Pre delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbo.dbasp_FileHandler @delete_Data_diff
	   end
   end

IF @Mode = 'BL'
	SET @save_FileGroups = NULL


--  Check for existance of a full backup
If @mode <> 'BF' and not exists (SELECT 1 FROM msdb.dbo.backupset 
				WHERE database_name = @save_DBname
				AND backup_finish_date IS NOT NULL
				AND type IN ('D', 'F'))
BEGIN
	print '-- No full backup exists for database ' + rtrim(@save_DBname)
	print '-- Changing Mode to "Backup Full" for @DBname = ' + rtrim(@save_DBname)

	SET @Mode = 'BF'
END


SET @syntax_out = null

BEGIN TRY
	IF @Verbose > 0 RAISERROR('Generating Backup Script.',-1,-1) WITH NOWAIT

	EXEC dbo.dbasp_format_BackupRestore 
				@DBName				= @save_DBname
				, @Mode				= @Mode
				, @FilePath			= @outpath2
				, @FileGroups		= @save_FileGroups
				, @ForceFileName	= @backup_name
				, @ForceSetSize		= @ForceSetSize
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @CopyOnly			= @CopyOnly
				, @SetName			= 'dbasp_Backup'
				, @SetDesc			= @PlanName
				, @Verbose			= @verbose
				, @BufferCount		= @BufferCount		
				, @MaxTransferSize	= @MaxTransferSize
				, @ForceB2Null		= @ForceB2Null		
				, @IgnoreMaintOvrd	= @IgnoreMaintOvrd
				, @IgnoreB2NullOvrd	= @IgnoreB2NullOvrd
				, @syntax_out		= @syntax_out output
END TRY
BEGIN CATCH
 	EXEC dbo.dbasp_GetErrorInfo
	RAISERROR('DBA Error: Unable to Generate Backup Script for [%s].',-1,-1,@save_DBname) WITH NOWAIT
	SET @error_count = @error_count + 1
	IF @Attempt_Count >5
		GOTO loop_end
	ELSE
		GOTO start_attempts
END CATCH

--  Create Differential companion to full backup
If @mode = 'BF' 
  and @auto_diff = 'y' 
  and DB_ID(@save_DBname) > 4 
  and @CopyOnly = 0
BEGIN TRY
	IF @Verbose > 0 RAISERROR('Generating Backup Script.',-1,-1) WITH NOWAIT

	EXEC dbo.dbasp_format_BackupRestore 
				@DBName				= @save_DBname
				, @Mode				= 'BD'
				, @FilePath			= @outpath2
				, @FileGroups		= @save_FileGroups
				, @ForceFileName	= @backup_name
				, @ForceSetSize		= @ForceSetSize
				, @ForceEngine		= @ForceEngine
				, @ForceCompression	= @ForceCompression
				, @ForceChecksum	= @ForceChecksum
				, @CopyOnly			= @CopyOnly
				, @SetName			= 'dbasp_Backup'
				, @SetDesc			= @PlanName
				, @Verbose			= @verbose
				, @BufferCount		= @BufferCount		
				, @MaxTransferSize	= @MaxTransferSize
				, @ForceB2Null		= @ForceB2Null		
				, @IgnoreMaintOvrd	= @IgnoreMaintOvrd
				, @IgnoreB2NullOvrd	= @IgnoreB2NullOvrd
				, @syntax_out		= @syntax_out output
END TRY
BEGIN CATCH
 	EXEC dbo.dbasp_GetErrorInfo
	RAISERROR('DBA Error: Unable to Generate Backup Script for [%s].',-1,-1,@save_DBname) WITH NOWAIT
	SET @error_count = @error_count + 1
	IF @Attempt_Count >5
		GOTO loop_end
	ELSE
		GOTO start_attempts
END CATCH

Print ''
IF @Verbose > 0 exec dbo.dbasp_PrintLarge @syntax_out 


SET @retcode = 0
--  Execute the backup
	BEGIN TRY
		IF @verbose > 0 RAISERROR('Executing Backup Script.',-1,-1) WITH NOWAIT

		Exec (@syntax_out)

		If (@@error <> 0 or @retcode <> 0)
		begin
			EXEC dbo.dbasp_GetErrorInfo
			RAISERROR('DBA Error: Unable to perform Backup of [%s] to [%s].',-1,-1,@save_DBname,@outpath2) WITH NOWAIT
			SET @error_count = @error_count + 1
			IF @Attempt_Count >5
				GOTO loop_end
			ELSE
				GOTO start_attempts
		end
	END TRY
	BEGIN CATCH
		EXEC dbo.dbasp_GetErrorInfo
		RAISERROR('DBA Error: Unable to perform Backup of [%s] to [%s].',-1,-1,@save_DBname,@outpath2) WITH NOWAIT
		SET @error_count = @error_count + 1
		IF @Attempt_Count >5
			GOTO loop_end
		ELSE
			GOTO start_attempts
	END CATCH


--   Post Backup Delete Process
If @DeletePrevious = 'after' and @mode = 'BF' and @CopyOnly = 0
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older backup files'
	Print '=========================================================================== '
	Print ' '
	Start_DBdelete_after:
	If (Select count(*) from #DBdelete) > 0
	   begin
		Select @hold_dd_id = (select top 1 dd_id from #DBdelete)
		Select @delete_Data_db = (select delete_Data_db from #DBdelete where dd_id = @hold_dd_id) 

		If @delete_Data_db is not null
		   begin
			exec dbo.dbasp_FileHandler @delete_Data_db
		   end

		Delete from #DBdelete where dd_id = @hold_dd_id

		goto Start_DBdelete_after 
	   end

	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbo.dbasp_FileHandler @delete_Data_diff
	   end
   end
Else If @mode = 'BD' and @DeletePrevious = 'after'
   begin
	Print ' '
	Print '=========================================================================== '
	Print 'Post delete of older Differential files using mask ' + @save_delete_mask_diff
	Print '=========================================================================== '
	Print ' '
	If @delete_Data_diff is not null
	   begin
		exec dbo.dbasp_FileHandler @delete_Data_diff
	   end
   end


loop_end:

Delete from @DBnames where name = @save_DBname
If  (select count(*) from @DBnames) > 0
   begin
	goto start_dbnames
   end

RAISERROR( ' done with DB Loop',-1,-1)WITH NOWAIT


--  End Processing  ---------------------------------------------------------------------------------------------
	
Label99:


Print ' '
Print '=========================================================================== '
Print '** End of Backup Processing'
Print '=========================================================================== '
Print ' '


drop table IF EXISTS #DirectoryTempTable
drop table IF EXISTS #DBdelete
drop table IF EXISTS #fileexists


If @error_count > 0
   begin
	Print  ' '
	Select @miscprint = '--Example Syntax for dbasp_backup:'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Full Backup for a specific database:'
	Print  @miscprint
	Select @miscprint = 'exec dbo.dbasp_backup @DBname = ''dbname'', @Mode = ''BF'' -- BF=full, BD=diff, BL=t-log'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Differential Backup for a group of database:'
	Print  @miscprint
	Select @miscprint = 'exec dbo.dbasp_backup @PlanName = ''mplan_user_simple'', @Mode = ''BD'' -- BF=full, BD=diff, BL=t-log'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--All Available Input Parms for dbasp_backup:'
	Print  @miscprint
	Select @miscprint = 'exec dbo.dbasp_backup @DBname = ''dbname'''
	Print  @miscprint
	Select @miscprint = '                               @PlanName = ''mplan_user_simple''       -- Cannot be used if @DBname is supplied'
	Print  @miscprint
	Select @miscprint = '                              ,@Mode = ''BF''                          -- BF=full, BD=differential, BL=transaction log'
	Print  @miscprint
	Select @miscprint = '                            --,@BkUpPath = ''g:\backup''               -- Override the standard backup path'
	Print  @miscprint
	Select @miscprint = '                            --,@backup_name = ''DBAOps_db_test''     -- Override the standard backup name.  Only used with @DBname parm.'
	Print  @miscprint
	Select @miscprint = '                              ,@DeletePrevious = ''before''            -- ''before'', ''after'' or ''none'''
	Print  @miscprint
	Select @miscprint = '                              ,@FileGroups = null                    -- ''All'', ''None'', ''FGname'' or null.'
	Print  @miscprint
	Select @miscprint = '                              ,@ForceEngine = ''MSSQL''                -- ''MSSQL'' or ''REDGATE''.'
	Print  @miscprint
	Select @miscprint = '                            --,@ForceCompression = 1                 -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@ForceChecksum = 1                    -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@ForceLocal = 0                       -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '            ,@CopyOnly = 0                         -- 0=off, 1=on'
	Print  @miscprint
	Select @miscprint = '                              ,@process_mode = ''normal''              -- ''normal'', ''pre_release'', ''pre_calc'', ''mid_calc'''
	Print  @miscprint
	Select @miscprint = '                              ,@auto_diff = ''y''                      -- Automatic differential for every full backup (non-system DB).'
	Print  @miscprint
	Select @miscprint = '                            --,@ForceSetSize = 64                    -- Number of multi-file backup files (64 max, 32 Rdgate max)'
	Print  @miscprint
	Print  ' '
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup] TO [public]
GO
