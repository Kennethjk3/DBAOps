SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_autorestore] ( @full_path NVARCHAR(500) = NULL,
					@dbname SYSNAME = NULL,
					@ALTdbname SYSNAME = NULL,
					@backupname SYSNAME = NULL,
					@backmidmask SYSNAME = '_db_2',
					@diffmidmask SYSNAME = '_dfntl_2',
					@datapath NVARCHAR(100) = NULL,
					@data2path NVARCHAR(100) = NULL,
					@logpath NVARCHAR(100) = NULL,
					@sourcepath CHAR(1) = 'n',
					@force_newldf CHAR(1) = 'n',
					@drop_dbFlag CHAR(1) = 'n',
					@differential_flag CHAR(1) = 'n',
					@db_norecovOnly_flag CHAR(1) = 'n',
					@db_diffOnly_flag CHAR(1) = 'n',
					@post_shrink CHAR(1) = 'n',
					@complete_on_diffOnly_fail CHAR(1) = 'n',
					@script_out CHAR(1) = 'y',
					@DTstmp_in_DBfilenames CHAR(1) = 'n',
					@partial_flag CHAR(1) = 'n',
		 			@filegroup_name SYSNAME = '',
		 			@file_name NVARCHAR(500) = '')


/*********************************************************
 **  Stored Procedure dbasp_autorestore
 **  Written by Steve Ledridge, Virtuoso
 **  September 21, 2001
 **
 **  This procedure is used for automated database
 **  restore processing.
 **
 **  This proc accepts the following input parms:
 **  - @full_path is the path where the backup file can be found
 **    example - "\\seafresqlwcds\seafresqlwcds_dbasql"
 **  - @dbname is the name of the database being restored.
 **  - @ALTdbname is the "new" name of the database being restored (if you need a different DB name).
 **  - @backupname is the name pattern of the backup file to be restored.
 **  - @backmidmask is the mask for the midpart of the backup file name (i.e. '_db_2')
 **  - @diffmidmask is the mask for the midpart of the differential file name (i.e. '_dfntl_2')
 **  - @datapath is the target path for the data files (optional)
 **  - @logpath is the target path for the log files (optional)
 **  - @sourcepath is a flag to force the usage of the file paths
 **    designated in the source backup.  Specify "y" to set on.
 **  - @force_newldf is a flag to force the creation of a new ldf file
 **  - @drop_dbFlag is a flag to force a drop of the DB prior to restore.
 **  - @differential_flag is a flag to indicate a recovery for a
 **    DB backup followed by a differential backup.
 **  - @db_norecovOnly_flag indicates a DB recovery with the norecovery parm,
 **    which should be followed later by a differential only restore.
 **  - @db_diffOnly_flag indicates a differential only restore.
 **  - @post_shrink is for a post restore file shrink (y or n)
 **  - @complete_on_diffOnly_fail will finish the restore of a DB after a failed
 **    differential restore'
 **  - @script_out will either script out the restore commands or run the restore
 **    within the context of the sproc.
 **  - @DTstmp_in_DBfilenames will add a time stamp to the DB physical file names (y or n).
 **  - @partial_flag = 'y' if you want to restore just a single file group.
 **  - @filegroup_name if a file group restore is requested.
 **  - @file_name if a file name restore is requested.
 ***************************************************************/
  AS
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	06/10/2002	Steve Ledridge		Changed isql to osql
--	07/29/2002	Steve Ledridge		Set default path by looking at the path for the
--						master DB files.
--	09/24/2002	Steve Ledridge		Modified output share example
--	12/23/2002	Steve Ledridge		Added backup name parm
--	01/08/2003	Steve Ledridge		Added flag for forcing a new ldf file
--	04/14/2003	Steve Ledridge		Fixed shrink ldf file process (detach and reatach)
--	10/13/2003	Steve Ledridge		The process will now still work if multiple backup
--						files are found.  Newest file is used.  The default
--						backup name was chaged so that dbname_DB anywhere in
--						the backup file name will work.
--						Added drop DB flag.
--	06/14/2004	Steve Ledridge		Added differential restore process
--	07/20/2004	Steve Ledridge		New split processing (DB restore with norecovery or
--						differential only)
--	08/10/2004	Steve Ledridge		New set standard mdf file name process
--	08/16/2004	Steve Ledridge		Fixed time stamp for just after midnight(12am to 00am)
--	08/18/2005	Steve Ledridge		Added code for LiteSpeed processing.
--	08/19/2005	Steve Ledridge		Added retry for the 'dir' command.
--	12/13/2005	Steve Ledridge		Removed order by for differential files in the cursor.
--	06/22/2006	Steve Ledridge		Updated for SQL 2005.
--	07/28/2006	Steve Ledridge		Change filelist table for Litespeed backup header.
--	12/06/2006	Steve Ledridge		Added 2 masks for non-standard backup and differentail file names.
--	03/23/2007	Steve Ledridge		Leading underscore for input parm @diffmidmask was missing.
--	07/25/2007	Steve Ledridge		Added code for RedGate processing.
--	11/12/2007	Steve Ledridge		Added support for type 'F' files.
--	05/27/2008	Steve Ledridge		New shrink DB process using @force_newldf = 'x'
--	05/27/2008	Steve Ledridge		Added data2path and post_restore shrink.
--	07/23/2008	Steve Ledridge		Major revisions; added input parms @complete_on_diffOnly_fail and
--						@script_out.  Now retores can be done within the context of this sproc.
--	07/28/2008	Steve Ledridge		Added if scriptout='n' at end.
--	08/05/2008	Steve Ledridge		Modified error checking for Redgate restores.
--	08/06/2008	Steve Ledridge		Post file shrink is now just for LDF files.  Also
--						added time stamp to data file names, new ability to
--						restore to alternate DBname, and alter DB options after restore.
--	03/30/2009	Steve Ledridge		Change path to \\localhost for local restores to unc.
--	04/16/2009	Steve Ledridge		Removed \\localhostcode and added code to get the driveletter path.
--	05/19/2009	Steve Ledridge		Added @partial_flag and @filegroup_name input parms.
--	05/28/2009	Steve Ledridge		Added @file_name input parms.
--	06/16/2009	Steve Ledridge		Fixed bug with standard restore for RESTORE DATABASE line.
--	07/07/2009	Steve Ledridge		Removed filegroup parm from redgate diff restore syntax.
--	04/20/2011	Steve Ledridge		Added TDEThumbprint column to filelist temp table.  Now works for 2005 and 2008.
--	11/23/2011	Steve Ledridge		Added override for file path using local_control table.
--	10/29/2012	Steve Ledridge		Modified process to better work with @differential_flag AND @db_norecovOnly_flag
--						On RedGate restores so that it would restore the dierential and still leave it as
--						Restoring so that logs can be applied.
--	11/26/2012	Steve Ledridge		Modified process to better work with @differential_flag AND @db_norecovOnly_flag
--						On MS restores so that it would restore the dierential and still leave it as
--						Restoring so that logs can be applied.
--	03/07/2013	Steve Ledridge		Comment line for Diff's was not comented out when scripting = 'y'
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	======================================================================================


/***
Declare @full_path nvarchar(100)
Declare @dbname sysname
Declare @ALTdbname sysname
Declare @backupname sysname
Declare @backmidmask sysname
Declare @diffmidmask sysname
Declare @datapath nvarchar(100)
Declare @data2path nvarchar(100)
Declare @logpath nvarchar(100)
Declare @sourcepath char(1)
Declare @force_newldf char(1)
Declare @drop_dbFlag char(1)
Declare @differential_flag char(1)
Declare @db_norecovOnly_flag char(1)
Declare @db_diffOnly_flag char(1)
Declare @post_shrink char(1)
Declare @complete_on_diffOnly_fail char(1)
Declare @script_out char(1)
Declare @DTstmp_in_DBfilenames char(1)
Declare @partial_flag char(1)
Declare @filegroup_name sysname
Declare @file_name nvarchar(500)


select @full_path = '\\DBAOpsER04\DBAOpsER04_restore\BNDL'
select @dbname = 'Bundle'
--select @ALTdbname = 'ArtistListing_new'
--Select @backupname = 'DBAOps_db'
Select @backmidmask = '_db_2'
Select @diffmidmask = '_dfntl_2'
select @datapath = 'd:\mssql.1\data'
--select @data2path = 'e:\mssql.1\data'
select @logpath = 'd:\mssql.1\data'
select @sourcepath = 'n'
select @force_newldf = 'n'
select @drop_dbFlag = 'n'
select @differential_flag = 'n'
select @db_norecovOnly_flag = 'n'
select @db_diffOnly_flag = 'n'
Select @post_shrink = 'n'
Select @complete_on_diffOnly_fail = 'n'
Select @script_out = 'y'
Select @DTstmp_in_DBfilenames = 'y'
Select @partial_flag = 'n'
Select @filegroup_name = ''
Select @file_name = ''
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			NVARCHAR(4000)
	,@error_count			INT
	,@retry_count			INT
	,@cmd 				NVARCHAR(4000)
	,@Restore_cmd			NVARCHAR(4000)
	,@retcode 			INT
	,@filecount			SMALLINT
	,@filename_wild			NVARCHAR(100)
	,@diffname_wild			NVARCHAR(100)
	,@charpos			INT
	,@query 			NVARCHAR(4000)
	,@mssql_data_path		NVARCHAR(255)
	,@savePhysicalNamePart		NVARCHAR(260)
	,@savefilepath			NVARCHAR(260)
	,@save_override_path		NVARCHAR(260)
	,@hold_filedate			NVARCHAR(12)
	,@save_filedate			NVARCHAR(12)
	,@save_fileYYYY			NVARCHAR(4)
	,@save_fileMM			NVARCHAR(2)
	,@save_fileDD			NVARCHAR(2)
	,@save_fileHH			NVARCHAR(2)
	,@save_fileMN			NVARCHAR(2)
	,@save_fileAMPM			NVARCHAR(1)
	,@save_LogicalName		SYSNAME
	,@save_cmdoutput		NVARCHAR(255)
	,@save_subject			SYSNAME
	,@save_message			NVARCHAR(500)
	,@hold_ldfpath			NVARCHAR(260)
	,@hold_backupfilename		SYSNAME
	,@hold_diff_file_name		SYSNAME
	,@fileseq			SMALLINT
	,@fileseed			SMALLINT
	,@diffname			SYSNAME
	,@BkUpMethod			NVARCHAR(5)
	,@detach_cmd			SYSNAME
	,@deleteLDF_cmd			SYSNAME
	,@attach_cmd			SYSNAME
	,@DateStmp 			NVARCHAR(15)
	,@Hold_hhmmss			NVARCHAR(8)
	,@drop_dbname			SYSNAME
	,@check_dbname 			SYSNAME
	,@save_servername		SYSNAME
	,@save_servername2		SYSNAME
	,@save_localservername_mask	SYSNAME
	,@save_alt_full_path		NVARCHAR(500)
	,@outpath			NVARCHAR(500)
	,@save_fg_name			NVARCHAR(500)
	,@save_fn_name			NVARCHAR(500)


DECLARE
	 @cu11cmdoutput			NVARCHAR(255)


DECLARE
	 @cu12fileid			SMALLINT
	,@cu12name			NVARCHAR(128)
	,@cu12filename			NVARCHAR(260)


DECLARE
	 @cu21LogicalName		NVARCHAR(128)
	,@cu21PhysicalName		NVARCHAR(260)
	,@cu21Type			CHAR(1)
	,@cu21FileGroupName		NVARCHAR(128)


DECLARE
	 @cu22LogicalName		NVARCHAR(128)
	,@cu22PhysicalName		NVARCHAR(260)
	,@cu22Type			CHAR(1)
	,@cu22FileGroupName		NVARCHAR(128)


DECLARE
	 @cu25cmdoutput			NVARCHAR(255)


----------------  initial values  -------------------
SELECT @retry_count = 0
SELECT @error_count = 0
SELECT @hold_filedate = '200001010001'
SELECT @BkUpMethod = 'MS'
SELECT @filename_wild = ''
SELECT @diffname_wild = ''
SELECT @DateStmp = ''


SELECT @save_servername	= @@SERVERNAME
SELECT @save_servername2 = @@SERVERNAME


SELECT @charpos = CHARINDEX('\', @save_servername)
IF @charpos <> 0
   BEGIN
	SELECT @save_servername = SUBSTRING(@@SERVERNAME, 1, (CHARINDEX('\', @@SERVERNAME)-1))


	SELECT @save_servername2 = STUFF(@save_servername2, @charpos, 1, '$')
   END


SELECT @save_localservername_mask = '\\' + @save_servername + '%'


IF @ALTdbname IS NOT NULL AND @ALTdbname <> ''
   BEGIN
	SELECT @check_dbname = @ALTdbname
   END
ELSE
   BEGIN
	SELECT @check_dbname = @dbname
   END


IF @DTstmp_in_DBfilenames = 'y'
   BEGIN
	SET @Hold_hhmmss = CONVERT(VARCHAR(8), GETDATE(), 8)
	SET @DateStmp = '_' + CONVERT(CHAR(8), GETDATE(), 112) + SUBSTRING(@Hold_hhmmss, 1, 2) + SUBSTRING(@Hold_hhmmss, 4, 2) + SUBSTRING(@Hold_hhmmss, 7, 2)
   END


CREATE TABLE #db_files(fileid SMALLINT
			,name NVARCHAR(128)
			,filename NVARCHAR(260))


CREATE TABLE #DirectoryTempTable(cmdoutput NVARCHAR(255) NULL)
CREATE TABLE #filelist(LogicalName NVARCHAR(128) NULL,
						PhysicalName NVARCHAR(260) NULL,
						type CHAR(1),
						FileGroupName NVARCHAR(128) NULL,
						SIZE NUMERIC(20,0),
						MaxSize NUMERIC(20,0),
						FileId BIGINT,
						CreateLSN NUMERIC(25,0),
						DropLSN NUMERIC(25,0),
						UniqueId UNIQUEIDENTIFIER,
						ReadOnlyLSN NUMERIC(25,0),
						ReadWriteLSN NUMERIC(25,0),
						BackupSizeInBytes BIGINT,
						SourceBlockSize INT,
						FileGroupId INT,
						LogGroupGUID UNIQUEIDENTIFIER NULL,
						DifferentialBaseLSN NUMERIC(25,0),
						DifferentialBaseGUID UNIQUEIDENTIFIER,
						IsReadOnly BIT,
						IsPresent BIT,
						TDEThumbprint VARBINARY(32) NULL
						)


CREATE TABLE #filelist_ls (LogicalName NVARCHAR(128) NULL,
						PhysicalName NVARCHAR(260) NULL,
						type CHAR(1),
						FileGroupName NVARCHAR(128) NULL,
						SIZE NUMERIC(20,0),
						MaxSize NUMERIC(20,0)
						)


CREATE TABLE #filelist_rg(LogicalName NVARCHAR(128) NULL,
						PhysicalName NVARCHAR(260) NULL,
						type CHAR(1),
						FileGroupName NVARCHAR(128) NULL,
						SIZE NUMERIC(20,0),
						MaxSize NUMERIC(20,0),
						FileId BIGINT,
						CreateLSN NUMERIC(25,0),
						DropLSN NUMERIC(25,0),
						UniqueId UNIQUEIDENTIFIER,
						ReadOnlyLSN NUMERIC(25,0),
						ReadWriteLSN NUMERIC(25,0),
						BackupSizeInBytes BIGINT,
						SourceBlockSize INT,
						FileGroupId INT,
						LogGroupGUID SYSNAME NULL,
						DifferentialBaseLSN NUMERIC(25,0),
						DifferentialBaseGUID UNIQUEIDENTIFIER,
						IsReadOnly BIT,
						IsPresent BIT
						)


--  Check input parms
IF @full_path IS NULL OR @full_path = ''
   BEGIN
	SELECT @miscprint = 'DBA WARNING: Invalid parameters to dbasp_autorestore - @full_path must be specified.'
	PRINT @miscprint
	SELECT @error_count = @error_count + 1
	GOTO label99
   END


IF @dbname IS NULL OR @dbname = ''
   BEGIN
	SELECT @miscprint = 'DBA WARNING: Invalid parameters to dbasp_autorestore - @dbname must be specified.'
	PRINT @miscprint
	SELECT @error_count = @error_count + 1
	GOTO label99
   END


IF @db_norecovOnly_flag = 'y' AND @db_diffOnly_flag = 'y'
   BEGIN
	SELECT @miscprint = 'DBA WARNING: Invalid parameters - @db_norecovOnly_flag and @db_diffOnly_flag cannot both be selected'
	PRINT @miscprint
	SELECT @error_count = @error_count + 1
	GOTO label99
   END


IF @db_diffOnly_flag = 'y' AND @differential_flag <> 'y'
   BEGIN
	SELECT @miscprint = 'DBA WARNING: Invalid parameters - @differential_flag must = ''y'' if @db_diffOnly_flag is selected'
	PRINT @miscprint
	SELECT @error_count = @error_count + 1
	GOTO label99
   END


IF @force_newldf = 'y' AND @db_norecovOnly_flag = 'y'
   BEGIN
	SELECT @miscprint = 'DBA WARNING: Invalid parameters - @force_newldf and @db_diffOnly_flag cannot both be selected'
	PRINT @miscprint
	SELECT @error_count = @error_count + 1
	GOTO label99
   END


IF @script_out <> 'y'
   BEGIN
	SELECT @miscprint = 'DBA Message:  This restore will be done within the context of the stored procedure execution for database [' + @check_dbname + ']'
	PRINT  @miscprint
	PRINT  ''
   END


IF @backupname IS NULL OR @backupname = ''
   BEGIN
	SELECT @filename_wild = @filename_wild + @dbname + @backmidmask + '*'
	SELECT @diffname_wild = @diffname_wild + @dbname + @diffmidmask + '*'
   END
ELSE
   BEGIN
	SELECT @diffname = REPLACE(@backupname, '_db_', '_dfntl_')
	SELECT @filename_wild = @filename_wild + @backupname
	SELECT @diffname_wild = @diffname_wild + @diffname
   END


IF @data2path IS NULL
   BEGIN
	SELECT @data2path = @datapath
   END


--  Set path for local restores
IF @full_path LIKE @save_localservername_mask AND @full_path LIKE '\\%' AND @full_path NOT LIKE '%$%'
   BEGIN
	--  Get the path to the source file share
	SELECT @save_alt_full_path = REPLACE(@full_path, '\\', '')


	SELECT @charpos = CHARINDEX('\', @save_alt_full_path)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_alt_full_path = SUBSTRING(@save_alt_full_path, @charpos+1, 255)
		SELECT @save_alt_full_path = LTRIM(RTRIM(@save_alt_full_path))
	   END


	--EXEC DBAOps.dbo.dbasp_get_share_path @save_alt_full_path, @outpath OUTPUT
	SET @outpath = DBAOps.dbo.dbaudf_GetSharePath2(@save_alt_full_path)
	IF @outpath IS NOT NULL
	   BEGIN
		SELECT @full_path = @outpath
	   END


   END


/****************************************************************
 *                MainLine
 ***************************************************************/


IF @script_out = 'y'
   BEGIN
	SELECT @miscprint = 'Use Master'
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT  ' '
   END


--  If this is for a differential only restore, jump to that section
IF @db_diffOnly_flag = 'y'
   BEGIN
	GOTO label12
   END


SELECT	@cmd = 'dir ' + @full_path + '\' + @filename_wild


start_dir:
INSERT INTO #DirectoryTempTable EXEC master.sys.xp_cmdshell @cmd
DELETE FROM #DirectoryTempTable WHERE cmdoutput IS NULL
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%<DIR>%'
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Directory of%'
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '% File(s) %'
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '% Dir(s) %'
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Volume in drive%'
DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Volume Serial Number%'
--select * from #DirectoryTempTable


SELECT @filecount = (SELECT COUNT(*) FROM #DirectoryTempTable)


IF @filecount < 1
   BEGIN
	IF @retry_count < 5
	   BEGIN
		SELECT @retry_count = @retry_count + 1
		WAITFOR delay '00:00:10'
		DELETE FROM #DirectoryTempTable
		GOTO start_dir
	   END
	ELSE
	   BEGIN
		SELECT @miscprint = 'DBA WARNING: No files found for dbasp_autorestore at ' + @full_path + ' using mask "' + @filename_wild + '"'
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END
   END
ELSE
   BEGIN
	Start_cmdoutput01:
	SELECT @save_cmdoutput = (SELECT TOP 1 cmdoutput FROM #DirectoryTempTable ORDER BY cmdoutput)
	SELECT @cu11cmdoutput = @save_cmdoutput


	SELECT @save_fileYYYY = SUBSTRING(@cu11cmdoutput, 7, 4)
	SELECT @save_fileMM = SUBSTRING(@cu11cmdoutput, 1, 2)
	SELECT @save_fileDD = SUBSTRING(@cu11cmdoutput, 4, 2)
	SELECT @save_fileHH = SUBSTRING(@cu11cmdoutput, 13, 2)
	SELECT @save_fileAMPM = SUBSTRING(@cu11cmdoutput, 18, 1)
	IF @save_fileAMPM = 'a' AND @save_fileHH = '12'
	   BEGIN
		SELECT @save_fileHH = '00'
	   END
	ELSE IF @save_fileAMPM = 'p' AND @save_fileHH <> '12'
	   BEGIN
		SELECT @save_fileHH = @save_fileHH + 12
	   END
	SELECT @save_fileMN = SUBSTRING(@cu11cmdoutput, 16, 2)
	SELECT @save_filedate = @save_fileYYYY + @save_fileMM + @save_fileDD + @save_fileHH + @save_fileMN


	IF @hold_filedate < @save_filedate
	   BEGIN
		SELECT @hold_backupfilename = LTRIM(RTRIM(SUBSTRING(@cu11cmdoutput, 40, 200)))
	   END


	DELETE FROM #DirectoryTempTable WHERE cmdoutput = @save_cmdoutput
	IF (SELECT COUNT(*) FROM #DirectoryTempTable) > 0
	   BEGIN
		GOTO Start_cmdoutput01
	   END
   END


--  Check file name to determin if we can process the file
IF @hold_backupfilename LIKE '%.bkp'
   BEGIN
	IF EXISTS (SELECT 1 FROM master.sys.objects WHERE name = 'xp_backup_database' AND type = 'x')
	   BEGIN
		PRINT '--  Note:  LiteSpeed Syntax will be used for this request'
		PRINT ' '
		SELECT @BkUpMethod = 'LS'
	   END
	ELSE
	   BEGIN
		SELECT @miscprint = 'DBA WARNING: LiteSpeed backups cannot be processed by dbasp_autorestore on this server. ' + @full_path + '\' + @hold_backupfilename
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END
   END


IF @hold_backupfilename LIKE '%.SQB%'
   BEGIN
	IF EXISTS (SELECT 1 FROM master.sys.objects WHERE name = 'sqlbackup' AND type = 'x')
	   BEGIN
		PRINT '--  Note:  RedGate Syntax will be used for this request'
		PRINT ' '
		SELECT @BkUpMethod = 'RG'
	   END
	ELSE
	   BEGIN
		SELECT @miscprint = 'DBA WARNING: RedGate backups cannot be processed by dbasp_autorestore on this server. ' + @full_path + '\' + @hold_backupfilename
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END
   END


IF @drop_dbFlag = 'y'
   BEGIN
	IF @ALTdbname IS NOT NULL AND @ALTdbname <> ''
	   BEGIN
		SELECT @drop_dbname = @ALTdbname
	   END
	ELSE
	   BEGIN
		SELECT @drop_dbname = @ALTdbname
	   END


	IF @script_out = 'y'
	   BEGIN
		SELECT @miscprint = 'DROP DATABASE ' + @drop_dbname
		PRINT  @miscprint
		SELECT @miscprint = 'go'
		PRINT  @miscprint
		PRINT  ' '
		SELECT @miscprint = 'Waitfor delay ''00:00:10'''
		PRINT  @miscprint
		SELECT @miscprint = 'go'
		PRINT  @miscprint
		PRINT  ' '
		PRINT  ' '
	   END
	ELSE
	   BEGIN
		IF EXISTS (SELECT 1 FROM master.sys.databases WHERE name = @drop_dbname)
		   BEGIN
			SELECT @cmd = 'drop database [' + @drop_dbname + ']'
			PRINT  @cmd
			EXEC(@cmd)


			WAITFOR delay '00:00:05'
		   END


		--  Verify the DB no longer exists
		IF EXISTS (SELECT 1 FROM master.sys.databases WHERE name = @drop_dbname)
		   BEGIN
			SELECT @miscprint = 'DBA ERROR: Unable to drop database ' + @drop_dbname + '.  The autorestore process is not able to continue.'
			PRINT  @miscprint
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END
	   END
   END


IF @BkUpMethod = 'RG'
   BEGIN
	SELECT @miscprint = 'Declare @cmd nvarchar(4000)'
	PRINT  @miscprint


	SELECT @miscprint = 'Select @cmd = ''-SQL "RESTORE DATABASE [' + @check_dbname + ']'


	IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
	   BEGIN
		SELECT @charpos = CHARINDEX(',', @filegroup_name)
		IF @charpos <> 0
		   BEGIN
			start_fg_multi:
			SELECT @save_fg_name = SUBSTRING(@filegroup_name, 1, @charpos-1)
			SELECT @save_fg_name = LTRIM(RTRIM(@save_fg_name))
			SELECT @filegroup_name = SUBSTRING(@filegroup_name, @charpos+1, 500)


			SELECT @miscprint = @miscprint + ' FILEGROUP=''''' + @filegroup_name + ''''''


			SELECT @charpos = CHARINDEX(',', @filegroup_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @miscprint = @miscprint + ','
				GOTO start_fg_multi
			   END
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = @miscprint + ' FILEGROUP=''''' + @filegroup_name + ''''''
		   END
	   END


	IF @partial_flag = 'y' AND @file_name IS NOT NULL AND @file_name <> ''
	   BEGIN
		IF @miscprint LIKE '%FILEGROUP=%'
		   BEGIN
			SELECT @miscprint = @miscprint + ','
		   END


		SELECT @charpos = CHARINDEX(',', @file_name)
		IF @charpos <> 0
		   BEGIN
			start_fn_multi:
			SELECT @save_fn_name = SUBSTRING(@file_name, 1, @charpos-1)
			SELECT @save_fn_name = LTRIM(RTRIM(@save_fn_name))
			SELECT @file_name = SUBSTRING(@file_name, @charpos+1, 500)


			SELECT @miscprint = @miscprint + ' FILE=''''' + @file_name + ''''''


			SELECT @charpos = CHARINDEX(',', @file_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @miscprint = @miscprint + ','
				GOTO start_fn_multi
			   END
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = @miscprint + ' FILE=''''' + @file_name + ''''''
		   END
	   END


	PRINT  @miscprint


	SELECT @miscprint = '	 FROM DISK = ''''' + @full_path + '\' + @hold_backupfilename + ''''''
	PRINT  @miscprint


	SELECT @Restore_cmd = '-SQL "RESTORE DATABASE [' + @check_dbname + ']'


	IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
	   BEGIN
		SELECT @charpos = CHARINDEX(',', @filegroup_name)
		IF @charpos <> 0
		   BEGIN
			start_fg_multi02:
			SELECT @save_fg_name = SUBSTRING(@filegroup_name, 1, @charpos-1)
			SELECT @save_fg_name = LTRIM(RTRIM(@save_fg_name))
			SELECT @filegroup_name = SUBSTRING(@filegroup_name, @charpos+1, 500)


			SELECT @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @filegroup_name + ''''


			SELECT @charpos = CHARINDEX(',', @filegroup_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @Restore_cmd = @Restore_cmd + ','
				GOTO start_fg_multi02
			   END
		   END
		ELSE
		   BEGIN
			SELECT @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @filegroup_name + ''''
		   END
	   END


	IF @partial_flag = 'y' AND @file_name IS NOT NULL AND @file_name <> ''
	   BEGIN
		IF @miscprint LIKE '%FILEGROUP=%'
		   BEGIN
			SELECT @Restore_cmd = @Restore_cmd + ','
		   END


		SELECT @charpos = CHARINDEX(',', @file_name)
		IF @charpos <> 0
		   BEGIN
			start_fn_multi02:
			SELECT @save_fn_name = SUBSTRING(@file_name, 1, @charpos-1)
			SELECT @save_fn_name = LTRIM(RTRIM(@save_fn_name))
			SELECT @file_name = SUBSTRING(@file_name, @charpos+1, 500)


			SELECT @Restore_cmd = @Restore_cmd + ' FILE=''' + @file_name + ''''


			SELECT @charpos = CHARINDEX(',', @file_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @Restore_cmd = @Restore_cmd + ','
				GOTO start_fn_multi02
			   END
		   END
		ELSE
		   BEGIN
			SELECT @Restore_cmd = @Restore_cmd + ' FILE=''' + @file_name + ''''
		   END
	   END


	SELECT @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''


	IF @differential_flag = 'y' OR @db_norecovOnly_flag = 'y'
	   BEGIN
		IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
		   BEGIN
			SELECT @miscprint = '	 WITH PARTIAL, NORECOVERY'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, NORECOVERY'
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = '	 WITH NORECOVERY'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH NORECOVERY'
		   END
	   END
	ELSE
	   BEGIN
		IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
		   BEGIN
			SELECT @miscprint = '	 WITH PARTIAL, RECOVERY'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, RECOVERY'
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = '	 WITH RECOVERY'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH RECOVERY'
		   END
	   END


	-- Get file header info from the SQB backup file
	DELETE FROM #filelist_rg


	SELECT @query = 'Exec master.dbo.sqlbackup ''-SQL "RESTORE FILELISTONLY FROM DISK = ''''' + RTRIM(@full_path) + '\' + RTRIM(@hold_backupfilename) + '''''"'''
	INSERT INTO #filelist_rg EXEC (@query)
	IF (SELECT COUNT(*) FROM #filelist_rg) = 0
	   BEGIN
		SELECT @miscprint = 'DBA Error: Unable to process RedGate filelistonly for file ' + @full_path + '\' + @hold_backupfilename
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END


	--  set the default path just in case we need it
	SELECT @mssql_data_path = (SELECT filename FROM master.sys.sysfiles WHERE fileid = 1)
	SELECT @charpos = CHARINDEX('master', @mssql_data_path)
	SELECT @mssql_data_path = LEFT(@mssql_data_path, @charpos-1)
	SELECT @fileseq = 1


	EXECUTE('DECLARE cu21_cursor Insensitive Cursor For ' +
	  'SELECT f.LogicalName, f.PhysicalName, f.Type, f.FileGroupName
	   From #filelist_rg   f ' +
	  'for Read Only')


	OPEN cu21_cursor

	WHILE (21=21)
	 BEGIN
		FETCH NEXT FROM cu21_cursor INTO @cu21LogicalName, @cu21PhysicalName, @cu21Type, @cu21FileGroupName
		IF (@@FETCH_STATUS < 0)
	           BEGIN
	              CLOSE cu21_cursor
		      BREAK
	           END


		SELECT @savePhysicalNamePart = @cu21PhysicalName
		label02:
			SELECT @charpos = CHARINDEX('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   BEGIN
	  		    SELECT @savePhysicalNamePart = SUBSTRING(@savePhysicalNamePart, @charpos + 1, 100)
			   END

			SELECT @charpos = CHARINDEX('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   BEGIN
			    GOTO label02
	 		   END


		IF @DTstmp_in_DBfilenames = 'y'
		   BEGIN
			IF @savePhysicalNamePart LIKE '%.mdf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.mdf', @DateStmp + '.mdf')
			   END
			ELSE IF @savePhysicalNamePart LIKE '%.ndf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.ndf', @DateStmp + '.ndf')
			   END
			ELSE IF @savePhysicalNamePart LIKE '%.ldf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.ldf', @DateStmp + '.ldf')
			   END
			ELSE
			   BEGIN
				SELECT @savePhysicalNamePart = @savePhysicalNamePart + @DateStmp
			   END
		   END


		IF @sourcepath = 'y'
		   BEGIN
			SELECT @savefilepath = @cu21PhysicalName
		   END
		ELSE IF @datapath IS NOT NULL AND @cu21Type IN ('D', 'F')
		   BEGIN
			IF EXISTS (SELECT 1 FROM dbo.local_control WHERE subject = 'restore_override' AND detail01 = @check_dbname AND detail02 = @cu21LogicalName)
			   BEGIN
				SELECT @save_override_path = (SELECT TOP 1 detail03 FROM dbo.local_control WHERE subject = 'restore_override' AND detail01 = @check_dbname AND detail02 = @cu21LogicalName)
				SELECT @savefilepath = @save_override_path + '\' + @savePhysicalNamePart
			   END
			ELSE IF @savePhysicalNamePart NOT LIKE '%mdf' AND @data2path IS NOT NULL
			   BEGIN
				SELECT @savefilepath = @data2path + '\' + @savePhysicalNamePart
			   END
			ELSE
			   BEGIN
				SELECT @savefilepath = @datapath + '\' + @savePhysicalNamePart
			   END
		   END
		ELSE IF @logpath IS NOT NULL AND @cu21Type = 'L'
		   BEGIN
			SELECT @savefilepath = @logpath + '\' + @savePhysicalNamePart
		   END
		ELSE
		   BEGIN
			SELECT @savefilepath = @mssql_data_path + @savePhysicalNamePart
		   END


		SELECT @miscprint = '	,MOVE ''''' + RTRIM(@cu21LogicalName) + ''''' to ''''' + RTRIM(@savefilepath) + ''''''
		PRINT  @miscprint


		SELECT @Restore_cmd = @Restore_cmd + ', MOVE ''' + RTRIM(@cu21LogicalName) + ''' to ''' + RTRIM(@savefilepath) + ''''


		--  capture ldf info if needed
		IF @force_newldf = 'y'
		   BEGIN
			SELECT @charpos = CHARINDEX('.ldf', @savefilepath)
			IF @charpos <> 0
			   BEGIN
				SELECT @hold_ldfpath = @savefilepath
			   END
			ELSE
			   BEGIN
				INSERT #db_files VALUES (@fileseq, @cu21LogicalName, @savefilepath)
			   END
		   END


		SELECT @fileseq = @fileseq + 1


	END  -- loop 21
	DEALLOCATE cu21_cursor


	SELECT @miscprint = '	,REPLACE"'''
	PRINT  @miscprint
	SELECT @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(9),'''')'
	PRINT  @miscprint
	SELECT @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(13)+char(10),'' '')'
	PRINT  @miscprint
	SELECT @miscprint = 'Exec master.dbo.sqlbackup @cmd'
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @Restore_cmd = @Restore_cmd + ' ,REPLACE"'


	IF @script_out <> 'y'
	   BEGIN
		-- Restore the database
		SELECT @cmd = 'Exec master.dbo.sqlbackup ' + @Restore_cmd
		PRINT 'Here is the restore command being executed;'
		PRINT @cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC master.dbo.sqlbackup @Restore_cmd


		IF @db_norecovOnly_flag = 'y' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
		   BEGIN
			SELECT @miscprint = 'DBA Error:  Restore Failure (Redgate partial restore) for command ' + @cmd
			PRINT  @miscprint
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END
		ELSE IF @db_norecovOnly_flag <> 'y' AND @differential_flag = 'n' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
		   BEGIN
			SELECT @miscprint = 'DBA Error:  Restore Failure (Redgate complete restore) for command ' + @cmd
			PRINT  @miscprint
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END
	   END


	IF @db_norecovOnly_flag = 'y' AND  @differential_flag = 'n'
	   BEGIN
		PRINT ' '
		SELECT @miscprint = '--  Note:  This will leave the database in recovery pending mode.'
		PRINT  @miscprint
		GOTO label99
	   END
   END


--  If not a LiteSpeed or RedGate file ----
IF @BkUpMethod = 'MS'
   BEGIN
	SELECT @miscprint = 'RESTORE DATABASE ' + @check_dbname


	SELECT @Restore_cmd = ''
	SELECT @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname


	IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
	   BEGIN
		SELECT @charpos = CHARINDEX(',', @filegroup_name)
		IF @charpos <> 0
		   BEGIN
			start_fg_multi03:
			SELECT @save_fg_name = SUBSTRING(@filegroup_name, 1, @charpos-1)
			SELECT @save_fg_name = LTRIM(RTRIM(@save_fg_name))
			SELECT @filegroup_name = SUBSTRING(@filegroup_name, @charpos+1, 500)


			SELECT @miscprint = @miscprint + ' FILEGROUP=''' + @filegroup_name + ''''
			SELECT @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @filegroup_name + ''''


			SELECT @charpos = CHARINDEX(',', @filegroup_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @miscprint = @miscprint + ','
				SELECT @Restore_cmd = @Restore_cmd + ','
				GOTO start_fg_multi03
			   END
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = @miscprint + ' FILEGROUP=''' + @filegroup_name + ''''
			SELECT @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @filegroup_name + ''''
		   END
	   END


	IF @partial_flag = 'y' AND @file_name IS NOT NULL AND @file_name <> ''
	   BEGIN
		IF @miscprint LIKE '%FILEGROUP=%'
		   BEGIN
			SELECT @miscprint = @miscprint + ','
			SELECT @Restore_cmd = @Restore_cmd + ','
		   END


		SELECT @charpos = CHARINDEX(',', @file_name)
		IF @charpos <> 0
		   BEGIN
			start_fn_multi04:
			SELECT @save_fn_name = SUBSTRING(@file_name, 1, @charpos-1)
			SELECT @save_fn_name = LTRIM(RTRIM(@save_fn_name))
			SELECT @file_name = SUBSTRING(@file_name, @charpos+1, 500)


			SELECT @miscprint = @miscprint + ' FILE=''''' + @file_name + ''''''
			SELECT @Restore_cmd = @Restore_cmd + ' FILE=''''' + @file_name + ''''''


			SELECT @charpos = CHARINDEX(',', @file_name)
			IF @charpos <> 0
			   BEGIN
				SELECT @miscprint = @miscprint + ','
				SELECT @Restore_cmd = @Restore_cmd + ','
				GOTO start_fn_multi04
			   END
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = @miscprint + ' FILE=''''' + @file_name + ''''''
			SELECT @Restore_cmd = @Restore_cmd + ' FILE=''''' + @file_name + ''''''
		   END
	   END


	PRINT  @miscprint


	SELECT @miscprint = 'FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''
	PRINT  @miscprint


	SELECT @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''


	IF @differential_flag = 'y' OR @db_norecovOnly_flag = 'y'
	   BEGIN
		IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
		   BEGIN
			SELECT @miscprint = 'WITH PARTIAL, NORECOVERY,'
			PRINT  @miscprint
			SELECT @miscprint = 'REPLACE,'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, NORECOVERY,'
			SELECT @Restore_cmd = @Restore_cmd + ' REPLACE,'
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = 'WITH NORECOVERY,'
			PRINT  @miscprint
			SELECT @miscprint = 'REPLACE,'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH NORECOVERY,'
			SELECT @Restore_cmd = @Restore_cmd + ' REPLACE,'
		   END
	   END
	ELSE
	   BEGIN
		IF @partial_flag = 'y' AND @filegroup_name IS NOT NULL AND @filegroup_name <> ''
		   BEGIN
			SELECT @miscprint = 'WITH PARTIAL, REPLACE,'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, REPLACE,'
		   END
		ELSE
		   BEGIN
			SELECT @miscprint = 'WITH REPLACE,'
			PRINT  @miscprint


			SELECT @Restore_cmd = @Restore_cmd + ' WITH REPLACE,'
		   END
	   END


	DELETE FROM #filelist


	SELECT @query = 'RESTORE FILELISTONLY FROM Disk = ''' + @full_path + '\' + @hold_backupfilename + ''''
	IF (SELECT @@version) NOT LIKE '%Server 2005%' AND (SELECT SERVERPROPERTY ('productversion')) > '10.00.0000' --sql2008 or higher
	   BEGIN
		INSERT INTO #filelist EXEC (@query)
	   END
	ELSE
	   BEGIN
		INSERT INTO #filelist (LogicalName
			, PhysicalName
			, type
			, FileGroupName
			, SIZE
			, MaxSize
			, FileId
			, CreateLSN
			, DropLSN
			, UniqueId
			, ReadOnlyLSN
			, ReadWriteLSN
			, BackupSizeInBytes
			, SourceBlockSize
			, FileGroupId
			, LogGroupGUID
			, DifferentialBaseLSN
			, DifferentialBaseGUID
			, IsReadOnly
			, IsPresent)
		EXEC (@query)
	   END
	--select * from #filelist
	IF (SELECT COUNT(*) FROM #filelist) = 0
	   BEGIN
		SELECT @miscprint = 'DBA Error: Unable to process standard filelistonly for file ' + @full_path + '\' + @hold_backupfilename
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END


	--  set the default path just in case we need it
	SELECT @mssql_data_path = (SELECT filename FROM master.sys.sysfiles WHERE fileid = 1)
	SELECT @charpos = CHARINDEX('master', @mssql_data_path)
	SELECT @mssql_data_path = LEFT(@mssql_data_path, @charpos-1)
	SELECT @fileseq = 1


	EXECUTE('DECLARE cu22_cursor Insensitive Cursor For ' +
	  'SELECT f.LogicalName, f.PhysicalName, f.Type, f.FileGroupName
	   From #filelist   f ' +
	  'for Read Only')


	OPEN cu22_cursor

	WHILE (22=22)
	 BEGIN
		FETCH NEXT FROM cu22_cursor INTO @cu22LogicalName, @cu22PhysicalName, @cu22Type, @cu22FileGroupName
		IF (@@FETCH_STATUS < 0)
	           BEGIN
	              CLOSE cu22_cursor
		      BREAK
	           END


		SELECT @savePhysicalNamePart = @cu22PhysicalName
		label03:
			SELECT @charpos = CHARINDEX('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   BEGIN
	  		    SELECT @savePhysicalNamePart = SUBSTRING(@savePhysicalNamePart, @charpos + 1, 100)
			   END

			SELECT @charpos = CHARINDEX('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   BEGIN
			    GOTO label03
	 		   END


		IF @DTstmp_in_DBfilenames = 'y'
		   BEGIN
			IF @savePhysicalNamePart LIKE '%.mdf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.mdf', @DateStmp + '.mdf')
			   END
			ELSE IF @savePhysicalNamePart LIKE '%.ndf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.ndf', @DateStmp + '.ndf')
			   END
			ELSE IF @savePhysicalNamePart LIKE '%.ldf'
			   BEGIN
				SELECT @savePhysicalNamePart = REPLACE(@savePhysicalNamePart, '.ldf', @DateStmp + '.ldf')
			   END
			ELSE
			   BEGIN
				SELECT @savePhysicalNamePart = @savePhysicalNamePart + @DateStmp
			   END
		   END


		IF @sourcepath = 'y'
		   BEGIN
			SELECT @savefilepath = @cu22PhysicalName
		   END
		ELSE IF @datapath IS NOT NULL AND @cu22Type IN ('D', 'F')
		   BEGIN
			IF EXISTS (SELECT 1 FROM dbo.local_control WHERE subject = 'restore_override' AND detail01 = @check_dbname AND detail02 = @cu22LogicalName)
			   BEGIN
				SELECT @save_override_path = (SELECT TOP 1 detail03 FROM dbo.local_control WHERE subject = 'restore_override' AND detail01 = @check_dbname AND detail02 = @cu22LogicalName)
				SELECT @savefilepath = @save_override_path + '\' + @savePhysicalNamePart
			   END
			ELSE IF @savePhysicalNamePart NOT LIKE '%mdf' AND @data2path IS NOT NULL
			   BEGIN
				SELECT @savefilepath = @data2path + '\' + @savePhysicalNamePart
			   END
			ELSE
			   BEGIN
				SELECT @savefilepath = @datapath + '\' + @savePhysicalNamePart
			   END
		   END
		ELSE IF @logpath IS NOT NULL AND @cu22Type = 'L'
		   BEGIN
			SELECT @savefilepath = @logpath + '\' + @savePhysicalNamePart
		   END
		ELSE
		   BEGIN
			SELECT @savefilepath = @mssql_data_path + @savePhysicalNamePart
		   END


		SELECT @miscprint = 'MOVE ''' + @cu22LogicalName + ''' to ''' + @savefilepath + ''','
		PRINT  @miscprint


		SELECT @Restore_cmd = @Restore_cmd + ' MOVE ''' + @cu22LogicalName + ''' to ''' + @savefilepath + ''','


		--  capture ldf info if needed
		IF @force_newldf = 'y'
		   BEGIN
			SELECT @charpos = CHARINDEX('.ldf', @savefilepath)
			IF @charpos <> 0
			   BEGIN
				SELECT @hold_ldfpath = @savefilepath
			   END
			ELSE
			   BEGIN
				INSERT #db_files VALUES (@fileseq, @cu22LogicalName, @savefilepath)
			   END
		   END


		SELECT @fileseq = @fileseq + 1


	END  -- loop 22
	DEALLOCATE cu22_cursor


	SELECT @miscprint = 'stats'
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @Restore_cmd = @Restore_cmd + ' stats'


	IF @script_out <> 'y'
	   BEGIN
		-- Restore the database
		SELECT @cmd = @Restore_cmd
		PRINT 'Here is the restore command being executed;'
		PRINT @cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@cmd)


		IF @@ERROR<> 0
		   BEGIN
			PRINT 'DBA Error:  Restore Failure (Standard Restore) for command ' + @cmd
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END
	   END


	IF @db_norecovOnly_flag = 'y'
	   BEGIN
		PRINT ' '
		SELECT @miscprint = '--  Note:  This will leave the database in recovery pending mode.'
		PRINT  @miscprint
		--GOTO label99

	   END


   END


label12:


-- Differentail Processing
IF @differential_flag = 'y'
   BEGIN


	IF @db_diffOnly_flag = 'y' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
	   BEGIN
		SELECT @miscprint = 'DBA ERROR:  A differential only restore was requested but the database is not in ''RESTORING'' mode.'
		PRINT  @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END

	PRINT '-- Restore Differential backup to database ' + @DBName


	SELECT @cmd = 'dir ' + @full_path + '\' + @diffname_wild
	--print @cmd


	DELETE FROM #DirectoryTempTable
	INSERT INTO #DirectoryTempTable EXEC master.sys.xp_cmdshell @cmd
	DELETE FROM #DirectoryTempTable WHERE cmdoutput IS NULL
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%<DIR>%'
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Directory of%'
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '% File(s) %'
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '% Dir(s) %'
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Volume in drive%'
	DELETE FROM #DirectoryTempTable WHERE cmdoutput LIKE '%Volume Serial Number%'
	--select * from #DirectoryTempTable


	SELECT @filecount = (SELECT COUNT(*) FROM #DirectoryTempTable)


	IF @filecount < 1
	   BEGIN
		SELECT @miscprint = 'DBA WARNING: No differential files found for dbasp_autorestore at ' + @full_path
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END


	Start_cmdoutput02:
	SELECT @save_cmdoutput = (SELECT TOP 1 cmdoutput FROM #DirectoryTempTable ORDER BY cmdoutput)
	SELECT @cu25cmdoutput = @save_cmdoutput


	SELECT @save_fileYYYY = SUBSTRING(@cu25cmdoutput, 7, 4)
	SELECT @save_fileMM = SUBSTRING(@cu25cmdoutput, 1, 2)
	SELECT @save_fileDD = SUBSTRING(@cu25cmdoutput, 4, 2)
	SELECT @save_fileHH = SUBSTRING(@cu25cmdoutput, 13, 2)
	SELECT @save_fileAMPM = SUBSTRING(@cu25cmdoutput, 18, 1)
	IF @save_fileAMPM = 'a' AND @save_fileHH = '12'
	   BEGIN
		SELECT @save_fileHH = '00'
	   END
	ELSE IF @save_fileAMPM = 'p' AND @save_fileHH <> '12'
	   BEGIN
		SELECT @save_fileHH = @save_fileHH + 12
	   END
	SELECT @save_fileMN = SUBSTRING(@cu25cmdoutput, 16, 2)
	SELECT @save_filedate = @save_fileYYYY + @save_fileMM + @save_fileDD + @save_fileHH + @save_fileMN


	IF @hold_filedate < @save_filedate
	   BEGIN
		SELECT @hold_diff_file_name = LTRIM(RTRIM(SUBSTRING(@cu25cmdoutput, 40, 200)))
	   END


	DELETE FROM #DirectoryTempTable WHERE cmdoutput = @save_cmdoutput
	IF (SELECT COUNT(*) FROM #DirectoryTempTable) > 0
	   BEGIN
		GOTO Start_cmdoutput02
	   END


	IF @hold_diff_file_name IS NULL OR @hold_diff_file_name = ''
	   BEGIN
		SELECT @miscprint = 'DBA ERROR: Unable to determine differential file for dbasp_autorestore at ' + @full_path
		PRINT @miscprint
		SELECT @error_count = @error_count + 1
		GOTO label99
	   END


	IF @hold_diff_file_name LIKE '%.DFL'
	   BEGIN
		--  This code is for LiteSpeed files
		SELECT @miscprint = 'EXEC master.dbo.xp_restore_database'
		PRINT  @miscprint
		SELECT @miscprint = '  @database = ''' + @check_dbname + ''''
		PRINT  @miscprint
		SELECT @miscprint = ', @filename = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		PRINT  @miscprint
		SELECT @miscprint = ', @with = RECOVERY'
		PRINT  @miscprint
		SELECT @miscprint = ', @with = ''stats'''
		PRINT  @miscprint
		SELECT @miscprint = 'go'
		PRINT  @miscprint
		PRINT ' '


		SELECT @Restore_cmd = ''
		SELECT @Restore_cmd = @Restore_cmd + 'EXEC master.dbo.xp_restore_database'
		SELECT @Restore_cmd = @Restore_cmd + '  @database = ''' + @check_dbname + ''''
		SELECT @Restore_cmd = @Restore_cmd + ', @filename = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		SELECT @Restore_cmd = @Restore_cmd + ', @with = RECOVERY'
		SELECT @Restore_cmd = @Restore_cmd + ', @with = ''stats'''


		IF @script_out <> 'y'
		   BEGIN
			-- Restore the differential
			SELECT @cmd = @Restore_cmd
			PRINT 'Here is the restore command being executed;'
			PRINT @cmd
			RAISERROR('', -1,-1) WITH NOWAIT


			EXEC (@cmd)


			IF DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE' AND @db_norecovOnly_flag = 'N'
			   BEGIN
				IF @complete_on_diffOnly_fail = 'y'
				   BEGIN
					--  finish the restore and send the DBA's an email
					SELECT @save_subject = 'DBAOps:  AutoRestore Failure for server ' + @@SERVERNAME
					SELECT @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
					EXEC DBAOps.dbo.dbasp_sendmail
						@recipients = 'DBANotify@virtuoso.com',
						--@recipients = 'DBANotify@virtuoso.com',
						@subject = @save_subject,
						@message = @save_message


					SELECT @Restore_cmd = ''
					SELECT @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


					SELECT @cmd = @Restore_cmd
					PRINT 'The differential restore failed.  Completing restore for just the database using the following command;'
					PRINT @cmd
					RAISERROR('', -1,-1) WITH NOWAIT


					EXEC (@cmd)


					IF DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
					   BEGIN
						PRINT 'DBA Error:  Restore Failure (LiteSpeed DFL restore - Unable to finish restore without the DFL) for command ' + @cmd
						SELECT @error_count = @error_count + 1
						GOTO label99
					   END
				   END
				ELSE
				   BEGIN
					PRINT 'DBA Error:  Restore Failure (LiteSpeed DFL restore) for command ' + @cmd
					SELECT @error_count = @error_count + 1
					GOTO label99
				   END
			   END
		   END
	   END
	ELSE IF @hold_diff_file_name LIKE '%.SQD'
	   BEGIN
		--  This code is for RedGate files
		SELECT @miscprint = 'Declare @cmd nvarchar(4000)'
		PRINT  @miscprint


		SELECT @miscprint = 'Select @cmd = ''-SQL "RESTORE DATABASE [' + @check_dbname + ']'
		PRINT  @miscprint
		SELECT @miscprint = ' FROM DISK = ''''' + @full_path + '\' + @hold_diff_file_name + ''''''
		PRINT  @miscprint
		SELECT @miscprint = CASE @db_norecovOnly_flag WHEN 'y' THEN ' WITH NORECOVERY"''' ELSE ' WITH RECOVERY"''' END
		PRINT  @miscprint
		SELECT @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(9),'''')'
		PRINT  @miscprint
		SELECT @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(13)+char(10),'' '')'
		PRINT  @miscprint
		SELECT @miscprint = 'Exec master.dbo.sqlbackup @cmd'
		PRINT  @miscprint
		SELECT @miscprint = 'go'
		PRINT  @miscprint
		PRINT ' '


		SELECT @Restore_cmd = ''


		SELECT @Restore_cmd = @Restore_cmd + '-SQL "RESTORE DATABASE [' + @check_dbname + ']'
		SELECT @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		SELECT @Restore_cmd = @Restore_cmd + CASE @db_norecovOnly_flag WHEN 'y' THEN ' WITH NORECOVERY"' ELSE ' WITH RECOVERY"' END


		IF @script_out <> 'y'
		   BEGIN
			-- Restore the differential
			SELECT @cmd = 'Exec master.dbo.sqlbackup ' + @Restore_cmd
			PRINT 'Here is the restore command being executed;'
			PRINT @cmd
			RAISERROR('', -1,-1) WITH NOWAIT


			EXEC master.dbo.sqlbackup @Restore_cmd


			IF @db_norecovOnly_flag = 'n' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
			   BEGIN
				IF @complete_on_diffOnly_fail = 'y'
				   BEGIN
					--  finish the restore and send the DBA's an email
					SELECT @save_subject = 'DBAOps:  AutoRestore Failure for server ' + @@SERVERNAME
					SELECT @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
					EXEC DBAOps.dbo.dbasp_sendmail
						@recipients = 'DBANotify@virtuoso.com',
						--@recipients = 'DBANotify@virtuoso.com',
						@subject = @save_subject,
						@message = @save_message


					SELECT @Restore_cmd = ''
					SELECT @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


					SELECT @cmd = @Restore_cmd
					PRINT 'The differential restore failed.  Completing restore for just the database using the following command;'
					PRINT @cmd
					RAISERROR('', -1,-1) WITH NOWAIT


					EXEC (@cmd)


					IF DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
					   BEGIN
						PRINT 'DBA Error:  Restore Failure (Redgate SQD restore - Unable to finish restore without the SQD) for command ' + @cmd
						SELECT @error_count = @error_count + 1
						GOTO label99
					   END
				   END
				ELSE
				   BEGIN
					PRINT 'DBA Error:  Restore Failure (Redgate SQD restore) for command ' + @cmd
					SELECT @error_count = @error_count + 1
					GOTO label99
				   END
			   END
		   END
	   END
	ELSE
	   BEGIN
		--  This code is for non-LiteSpeed and non-RadGate files
		SELECT @miscprint = 'RESTORE DATABASE ' + @check_dbname
		PRINT  @miscprint
		SELECT @miscprint = 'FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		PRINT  @miscprint
		SELECT @miscprint =  CASE @db_norecovOnly_flag WHEN 'y' THEN ' WITH NORECOVERY,' ELSE ' WITH RECOVERY,' END
		PRINT  @miscprint
		SELECT @miscprint = 'stats'
		PRINT  @miscprint
		SELECT @miscprint = 'go'
		PRINT  @miscprint
		PRINT ' '


		SELECT @Restore_cmd = ''
		SELECT @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname
		SELECT @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		SELECT @Restore_cmd = @Restore_cmd + CASE @db_norecovOnly_flag WHEN 'y' THEN ' WITH NORECOVERY,' ELSE ' WITH RECOVERY,' END
		SELECT @Restore_cmd = @Restore_cmd + ' stats'


		IF @script_out <> 'y'
		   BEGIN
			-- Restore the differential
			SELECT @cmd = @Restore_cmd
			PRINT 'Here is the restore command being executed;'
			PRINT @cmd
			RAISERROR('', -1,-1) WITH NOWAIT


			EXEC (@cmd)


			IF DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE' AND @db_norecovOnly_flag = 'N'
			   BEGIN
				IF @complete_on_diffOnly_fail = 'y'
				   BEGIN
					--  finish the restore and send the DBA's an email
					SELECT @save_subject = 'DBAOps:  AutoRestore Failure for server ' + @@SERVERNAME
					SELECT @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
					EXEC DBAOps.dbo.dbasp_sendmail
						@recipients = 'DBANotify@virtuoso.com',
						--@recipients = 'DBANotify@virtuoso.com',
						@subject = @save_subject,
						@message = @save_message


					SELECT @Restore_cmd = ''
					SELECT @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


					SELECT @cmd = @Restore_cmd
					PRINT 'The differential restore failed.  Completing restore for just the database using the following command;'
					PRINT @cmd
					RAISERROR('', -1,-1) WITH NOWAIT


					EXEC (@cmd)


					IF DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
					   BEGIN
						PRINT 'DBA Error:  Restore Failure (Standard DIF restore - Unable to finish restore without the DIF) for command ' + @cmd
						SELECT @error_count = @error_count + 1
						GOTO label99
					   END
				   END
				ELSE
				   BEGIN
					PRINT 'DBA Error:  Restore Failure (Standard DIF restore) for command ' + @cmd
					SELECT @error_count = @error_count + 1
					GOTO label99
				 END
			   END
		   END
	   END
   END


--  Trun off auto shrink and auto stats for ALTdbname restores
IF @ALTdbname IS NOT NULL AND @ALTdbname <> ''
   BEGIN
	SELECT @miscprint = '--  ALTER DATABASE OPTIONS'
	PRINT @miscprint
	SELECT @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
	PRINT @miscprint
	PRINT ''
	SELECT @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
	PRINT @miscprint
	PRINT ''
	SELECT @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
	PRINT @miscprint
	PRINT ''


	IF @script_out <> 'y'
	   BEGIN
		PRINT 'Here are the Alter Database Option commands being executed;'
		SELECT @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
		PRINT @cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@cmd)


		SELECT @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
		PRINT @cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@cmd)


		SELECT @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
		PRINT @cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@cmd)
	   END
   END


-- New LDF if requested
IF @force_newldf = 'y' AND (@ALTdbname IS NULL OR @ALTdbname = '')
   BEGIN
	PRINT '--NOTE:  New Log file (LDF) was requested'
	PRINT ' '


	SELECT @miscprint = 'Waitfor delay ''00:00:05'''
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @miscprint = 'exec master.sys.sp_detach_db ''' + RTRIM(@dbname) + ''', @skipchecks = ''true'''
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @detach_cmd = 'exec master.sys.sp_detach_db ''' + RTRIM(@dbname) + ''', @skipchecks = ''true'''


	SELECT @miscprint = 'Waitfor delay ''00:00:05'''
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @miscprint = 'Declare @cmd varchar(500)'
	PRINT  @miscprint
	SELECT @miscprint = 'Select @cmd = ''Del ' + @hold_ldfpath + ''''
	PRINT  @miscprint
	SELECT @miscprint = 'EXEC master.sys.xp_cmdshell @cmd, no_output'
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @deleteLDF_cmd = 'Del ' + @hold_ldfpath


	SELECT @miscprint = 'Waitfor delay ''00:00:05'''
	PRINT  @miscprint
	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	SELECT @miscprint = 'CREATE DATABASE [' + RTRIM(@dbname) + '] ON'
	PRINT  @miscprint


	SELECT @attach_cmd = 'CREATE DATABASE [' + RTRIM(@dbname) + '] ON'


	SELECT @fileseed = 1


	--------------------  Cursor for 12DB  -----------------------
	EXECUTE('DECLARE cu12_file Insensitive Cursor For ' +
	  'SELECT f.fileid, f.name, f.filename
	   From #db_files  f ' +
	  'Order By f.fileid For Read Only')


	OPEN cu12_file


	WHILE (12=12)
	   BEGIN
		FETCH NEXT FROM cu12_file INTO @cu12fileid, @cu12name, @cu12filename
		IF (@@FETCH_STATUS < 0)
	           BEGIN
	              CLOSE cu12_file
		      BREAK
	           END


		IF @fileseed = 1
		   BEGIN
			SELECT @miscprint = '     (FILENAME = ''' + RTRIM(@cu12filename) + ''')'
			PRINT  @miscprint


			SELECT @attach_cmd = @attach_cmd + ' (FILENAME = ''' + RTRIM(@cu12filename) + ''')'


		   END
		ELSE
		   BEGIN
			SELECT @miscprint = '    ,(FILENAME = ''' + RTRIM(@cu12filename) + ''')'
			PRINT  @miscprint


			SELECT @attach_cmd = @attach_cmd + ' ,(FILENAME = ''' + RTRIM(@cu12filename) + ''')'
		   END

		SELECT @fileseed = @fileseed + 1


	   END  -- loop 12
	   DEALLOCATE cu12_file


	PRINT  'FOR ATTACH;'
	PRINT  'go'
	PRINT  ' '
	PRINT  ' '


	SELECT @attach_cmd = @attach_cmd + ' FOR ATTACH;'


	IF @script_out <> 'y' AND DATABASEPROPERTYEX (@dbname,'status') = 'ONLINE'
	   BEGIN
		-- detach the DB
		PRINT 'Here is the Detach command being executed;'
		PRINT @detach_cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@detach_cmd)


		IF @@ERROR<> 0
		   BEGIN
			SELECT @miscprint = 'DBA Error:  Detach failure for command ' + @detach_cmd
			PRINT  @miscprint
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END


		-- delete the old ldf file
		PRINT 'Here is the del LDF file command being executed;'
		PRINT @deleteLDF_cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC master.sys.xp_cmdshell @deleteLDF_cmd


		-- reattach the DB
		PRINT 'Here is the Attach command being executed;'
		PRINT @attach_cmd
		RAISERROR('', -1,-1) WITH NOWAIT


		EXEC (@attach_cmd)


		IF @@ERROR<> 0
		   BEGIN
			SELECT @miscprint = 'DBA Error:  ReAttach Failure for command ' + @attach_cmd
			PRINT  @miscprint
			SELECT @error_count = @error_count + 1
			GOTO label99
		   END
	   END
   END


-- Shrink DB LDF Files if requested
IF @post_shrink = 'y'
   BEGIN
	PRINT '--NOTE:  Post Restore LDF file shrink was requested'
	PRINT ' '


	SELECT @miscprint = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @check_dbname + ''''
	PRINT  @miscprint
	SELECT @cmd = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @check_dbname + ''''


	SELECT @miscprint = 'go'
	PRINT  @miscprint
	PRINT ' '


	IF @script_out <> 'y'
	   BEGIN
		IF DATABASEPROPERTYEX (@check_dbname,'status') = 'ONLINE'
		   BEGIN
			SELECT @miscprint = 'Shrink file using command: ' + @cmd
			PRINT  @miscprint
			EXEC(@cmd)
		   END
	   END


   END


-------------------   end   --------------------------


label99:


--  Check to make sure the DB is in 'restoring' mode if requested
IF @script_out = 'n'
   BEGIN
	IF @db_norecovOnly_flag = 'y' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
	   BEGIN
		SELECT @miscprint = 'DBA ERROR:  A norecovOnly restore was requested and the database is not in ''RESTORING'' mode.'
		PRINT  @miscprint
		SELECT @error_count = @error_count + 1
	   END


	IF @error_count = 0 AND @db_norecovOnly_flag = 'n' AND DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
	   BEGIN
		SELECT @miscprint = 'DBA ERROR:  The AutoRestore process has failed for database ' + @check_dbname + '.  That database is not ''ONLINE'' at this time.'
		PRINT  @miscprint
		SELECT @error_count = @error_count + 1
	   END
   END


DROP TABLE #DirectoryTempTable
DROP TABLE #db_files
DROP TABLE #filelist
DROP TABLE #filelist_ls
DROP TABLE #filelist_rg


IF @error_count > 0
   BEGIN
	RAISERROR(@miscprint,16,-1) WITH LOG
	RETURN (1)
   END
ELSE
   BEGIN
	RETURN (0)
   END
GO
GRANT EXECUTE ON  [dbo].[dbasp_autorestore] TO [public]
GO
