SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupDBs] (@DBname sysname = null
				,@PlanName sysname = null
				,@backup_type sysname = 'db'
				,@backup_name sysname = null
				,@BkUpPath varchar(255) = null
				,@BkUpExt varchar(10) = null
				,@target_path varchar(500) = null
				,@DeletePrevious varchar(10) = 'after'
				,@VerifyBackup char(1) = 'n'
				,@Checksum char(1) = 'y'
				,@DeleteDfntl char(1) = 'n'
				,@DeleteTran char(1) = 'n'
				,@LiteSpeed_Bypass char(1) = 'n'
				,@RedGate_Bypass char(1) = 'n'
				,@threads smallint = 3
				,@compressionlevel smallint = 1
				,@maxtransfersize bigint = 1048576
				,@Compress_Bypass char(1) = 'n'
				,@Filegroup_Bypass char(1) = 'n'
				,@process_mode sysname = 'normal'
				,@auto_diff char(1) = 'y'
				,@skip_InMage_check char(1) = 'y')

/***************************************************************
 **  Stored Procedure dbasp_BackupDBs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 07, 2003
 **
 **  This procedure is used for various
 **  database backup processing.
 **
 **  This proc accepts several input parms:
 **
 **  Either @dbname or @planname is required.
 **
 **  - @dbname is the name of the database to be backed up.
 **    use 'ALL_USER_DBs' to backup all user databases
 **    use 'ALL_SYS_DBs' to backup all system databases
 **    use 'ALL_DBs' to backup all databases
 **
 **  - @PlanName is the maintenance plane name if one is being used.
 **
 **  - @backup_type is the middle node of the backup name.
 **    e.g. 'db', 'predeployment', 'archive' (optional)
 **
 **  - @backup_name can be used to override the backup file name
 **    when backing up a single database. (optional)
 **
 **  - @BkUpPath is the target output path (optional)
 **
 **  - @BkUpExt is the output file extension (optional)
 **
 **  - @target_path is the target output path (optional)
 **
 **  - @DeletePrevious ('before', 'after' or 'none') indicates if
 **    and when you want to delete the previous backup file(s).
 **
 **  - @VerifyBackup (y or n) allows the verify backup process to
 **    be disabled.
 **
 **  - @Checksum (y or n) set the checksum option for the backup process.
 **
 **  - @DeleteDfntl (y or n) indicates if you want to delete the
 **    previous differential file(s).
 **
 **  - @DeleteTran (y or n) indicates if you want to delete the
 **    previous transaction log backup file(s).
 **
 **  - @LiteSpeed_Bypass (y or n) indicates if you want to bypass
 **    LiteSpeed processing.
 **
 **  - @RedGate_Bypass (y or n) indicates if you want to bypass
 **    RedGate processing.
 **
 **  - @compress_Bypass (y or n) indicates if you want non-compressed backups.
 **
 **  - @Filegroup_Bypass (y or n) indicates if you want to skip backup by Filegroup processing.
 **
 **  - @process_mode (normal, pre_release, pre_calc, mid_calc)
 **    is for special processing where the backup file is written to a
 **    sub folder of the backup share and the backup info is logged
 **    in the backup_log table.
 **
 **  - @auto_diff (y or n) creates a differential backup for all
 **    non-system processed databases.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/07/2003	from systeminfo		New backup process
--	10/14/2003	JWilson			New optional input parm to set backup name and
--						new parm to set target path.
--	10/20/2003	JWilson			Removed reference to systeminfo sproc.
--	08/02/2004	JWilson			Added maintenance plan and delete previous backup input.
--	08/03/2004	JWilson			Added restore verify only to process.
--	08/11/2004	Steve Ledridge		Minor fix to maintenance plan processing
--						uses Handle.exe to list file contension issues.
--	08/27/2004	Steve Ledridge		Added brackets around DBname in backup command
--	09/06/2004	Steve Ledridge		Added test for version prior to sp_MSget_file_existence check.
--	10/20/2004	Steve Ledridge		Added delete of previous tran and dfntl files.
--	11/09/2004	Steve Ledridge		Commented out section for @deleteprevious parm check.
--	08/18/2005	Steve Ledridge		Added code for LiteSpeed backup processing.
--	08/19/2005	Steve Ledridge		Added code for LiteSpeed bypass.
--	12/07/2005	Steve Ledridge		Changed Litespeed logging to '0'.
--	12/13/2005	Steve Ledridge		Force a backup filename extention for input backup names
--						that do not list an extention.
--	02/15/2006	Steve Ledridge		Modified for sql2005
--	03/27/2006	Steve Ledridge		Added LiteSpeed input parms.
--	07/27/2006	Steve Ledridge		Chaged conversion of @maxtransfersize to varchar(10)
--	12/05/2006	Steve Ledridge		Added input parms @BkUpPath and @BkUpExt.
--	03/22/2007	Steve Ledridge		Fixed date parse for after deletes.
--	05/03/2007	Steve Ledridge		Fixed for paths with imbedded spaces.
--	05/24/2007	Steve Ledridge		Added century for charpos on _db_ charpos (now _db_2).
--	07/24/2007	Steve Ledridge		Added RedGate processing.
--	03/13/2008	Steve Ledridge		Added error checking.
--	03/13/2008	Steve Ledridge		Removed @maxtransfersize for Litespeed backups.
--	04/29/2008	Steve Ledridge		Post backup delete of old files if deleteprevious is before or after.
--	09/25/2008	Steve Ledridge		New code to skip backup for DB's that have been dropped during this process.
--	10/21/2008	Steve Ledridge		Added @process_mode input parm.
--	02/20/2009	Steve Ledridge		Added funtionality to force System databases to use MS backup only.
--	04/14/2009	Steve Ledridge		Update error check process for RG.
--	06/15/2009	Steve Ledridge		Added delete from standard backup share when @process_mode <> 'normal'
--	08/10/2009	Steve Ledridge		Create a differential for every DB in recovery full mode.
--	12/01/2009	Steve Ledridge		Updated error handeling.
--	02/11/2010	Steve Ledridge		Modified the calls to Handle.exe to use the /accepteula switch
--	11/18/2010	Steve Ledridge		Added support for backup by filegroup.
--	12/07/2010	Steve Ledridge		Fixed delete old file process.
--	04/05/2011	Steve Ledridge		Added compression for sql2008 R2.
--	05/20/2011	Steve Ledridge		New code for setting prerelease DB's to full recivery mode.
--	11/16/2011	Steve Ledridge		Modified check for SQL 2008 compression.
--	04/27/2012	Steve Ledridge		Lookup backup path from local_serverenviro.
--	07/05/2012	Steve Ledridge		Modified RG Backup to look for CopyTo Property on Each database
--						Then Use that Property to support Delivery of the Log for a LogShiped DB
--	08/27/2012	Steve Ledridge		Stop and start VSS if InMage and Redgate are active.
--	10/18/2012	Steve Ledridge		Added InMage wait.
--	02/11/2013	Steve Ledridge		Commentede out all Handle executions.
--	02/13/2013	Steve Ledridge		Removed litespeed parm from backup_diff call.
--	04/18/2013	Steve Ledridge		Removed Copyto options
--	======================================================================================


/***
Declare @DBname sysname
Declare @PlanName sysname
Declare @backup_type sysname
Declare @backup_name sysname
Declare @BkUpPath varchar(255)
Declare @BkUpExt varchar(10)
Declare @target_path varchar(500)
Declare @DeletePrevious varchar(10)
Declare @VerifyBackup char(1)
Declare @Checksum char(1)
Declare @DeleteDfntl char(1)
Declare @DeleteTran char(1)
Declare @LiteSpeed_Bypass char(1)
Declare @RedGate_Bypass char(1)
Declare @threads smallint
Declare @compressionlevel smallint
Declare @maxtransfersize int
Declare @compress_Bypass char(1)
Declare @Filegroup_Bypass char(1)
Declare @process_mode sysname
Declare @auto_diff char(1)
Declare @skip_InMage_check char(1)


Select @DBname = 'aaa_test'
--Select @DBname = 'ALL_USER_DBs'
--Select @DBname = 'ALL_SYS_DBs'
--Select @DBname = 'ALL_DBs'
--Select @PlanName = 'mplan_user_full'
Select @backup_type = 'db'
--Select @backup_name = 'DBAOps_db_20050818'
Select @BkUpPath = null
Select @BkUpExt = null
--Select @target_path = '\\SEAFRERYLGINSDB\SEAFRERYLGINSDB_backup'
Select @DeletePrevious = 'after'
Select @VerifyBackup = 'y'
Select @Checksum = 'y'
Select @DeleteDfntl = 'n'
Select @DeleteTran = 'n'
Select @LiteSpeed_Bypass = 'n'
Select @RedGate_Bypass = 'n'
Select @threads = 3
Select @compressionlevel = 1
Select @maxtransfersize = 1048576
Select @compress_Bypass = 'n'
Select @Filegroup_Bypass = 'n'
Select @process_mode = 'normal'
Select @auto_diff = 'y'
Select @skip_InMage_check = 'y'
--***/


DECLARE
	 @cmd				nvarchar(4000)
	,@cmd2				nvarchar(4000)
	,@retcode			int
	,@date 				nchar(14)
	,@Hold_hhmmss			nvarchar(8)
	,@std_backup_path		nvarchar(255)
	,@std_backup_path2		nvarchar(255)
	,@check_backup_path		nvarchar(255)
	,@outpath 			nvarchar(255)
	,@outpath2 			nvarchar(255)
	,@fileexist_path		nvarchar(255)
	,@BkUpFile 			varchar(500)
	,@error_count			int
	,@parm01			nvarchar(100)
	,@save_backupname		sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@charpos			int
	,@exists 			bit
	,@plan_flag			nchar(1)
	,@oneDB_flag			nchar(1)
	,@userDB_flag			nchar(1)
	,@sysDB_flag			nchar(1)
	,@allDB_flag			nchar(1)
	,@backup_log_flag		nchar(1)
	,@backup_by_filegroup_flag	nchar(1)
	,@tempcount			int
	,@Hold_filename			sysname
	,@Hold_filedate			sysname
	,@BkUpSufx			nvarchar(10)
	,@BkUpSufx_tlog			nvarchar(10)
	,@BkUpSufx_dfntl		nvarchar(10)
	,@BkUpMethod			nvarchar(5)
	,@BkUpFilename			sysname
	,@save_filegroupname		sysname
	,@save_date			nvarchar(30)
	,@VSS_flag			nchar(1)
	,@InMage_try			smallint
	,@a				datetime
	,@b				datetime


DECLARE
	 @cu10DBName		sysname


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId		smallint
	,@cu11DBStatus		int


DECLARE
	 @cu12DBName		sysname
	,@cu12DBId		smallint
	,@cu12DBStatus		int


DECLARE
	 @cu13DBName		sysname
	,@cu13DBId		smallint
	,@cu13DBStatus		int


DECLARE	@LogShipPaths	TABLE(CopyToPath VarChar(2048))
DECLARE @TSQL			VarChar(8000)


----------------  initial values  -------------------
Select @error_count = 0
Select @exists = 0
Select @plan_flag = 'n'
Select @oneDB_flag = 'n'
Select @userDB_flag = 'n'
Select @sysDB_flag = 'n'
Select @allDB_flag = 'n'
Select @backup_log_flag = 'n'
Select @VSS_flag = 'n'


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'LiteSpeed')
   and @LiteSpeed_Bypass = 'n'
   and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'LS'
	Set @BkUpSufx = 'BKP'
	Set @BkUpSufx_tlog = 'TNL'
	Set @BkUpSufx_dfntl = 'DFL'
   end
Else If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'RedGate')
   and @RedGate_Bypass = 'n'
   and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'RG'
	Set @BkUpSufx = 'SQB'
	Set @BkUpSufx_tlog = 'SQT'
	Set @BkUpSufx_dfntl = 'SQD'
   end
Else If (select @@version) not like '%Server 2005%'
  and ((select SERVERPROPERTY ('productversion')) > '10.50.0000' or (select @@version) like '%Enterprise Edition%')
  and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'MSc'
	Set @BkUpSufx = 'cBAK'
	Set @BkUpSufx_tlog = 'cTRN'
	Set @BkUpSufx_dfntl = 'cDIF'
   end
Else
 begin
	Set @BkUpMethod = 'MS'
	Set @BkUpSufx = 'BAK'
	Set @BkUpSufx_tlog = 'TRN'
	Set @BkUpSufx_dfntl = 'DIF'
   end


If @BkUpExt is not null
   begin
	Select @BkUpSufx = @BkUpExt
   end


--  Set the backup name extension if not specified with the input backup name.
If @backup_name is not null
   begin
	Select @charpos = charindex('.', @backup_name)
	IF @charpos = 0
	   begin
		Select @backup_name = @backup_name + '.' + rtrim(@BkUpSufx)
	   end
   end


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


create table #resultstring (message varchar (2500) null)


CREATE TABLE #temp_tbl2	(tbl2_id [int] IDENTITY(1,1) NOT NULL
			,text01	nvarchar(400)
			)


create Table #ReadSqlLog (LogDate smalldatetime
			,ProcessInfo varchar(30)
			,Text varchar(400)
			)


create Table #ReadSqlLog2 (LogDate smalldatetime
			,ProcessInfo varchar(30)
			,Text varchar(400)
			)


declare @DBnames table	(name sysname)


declare @DBnames2 table	(name sysname
			,dbid smallint
			,status int
			)

declare @filegroupnames table (
			 name sysname
			,data_space_id int)


--  Check input parameters and determine backup process
If @DeletePrevious not in ('before', 'after', 'none')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DeletePrevious parm must be ''before'', ''after'' or ''none''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @process_mode not in ('normal', 'pre_release', 'pre_calc', 'mid_calc')
   begin
	Print 'DBA Warning: Invalid input parameter.  @process_mode parm must be ''normal'', ''pre_release'', ''pre_calc'' or ''mid_calc''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @PlanName is not null and @PlanName <> ''
   begin
	If not exists (select * from msdb.dbo.sysdbmaintplans Where plan_name = @PlanName)
	   begin
		Print 'DBA WARNING: Invaild parameter passed to dbasp_backupDBs - @PlanName parm is invalid'
		Select @error_count = @error_count + 1
		Goto label99
	   end
	Else
	   begin
		If exists (select 1
			From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
			Where d.plan_id = s.plan_id
			and s.plan_name = @PlanName
			and d.database_name = 'All User Databases')
		   begin
			Print '-- Process mode is for all User DBs using Maintenance plan [' + @PlanName + ']'
			Select @userDB_flag = 'y'
			goto label05
		   end


		If exists (select 1
			From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
			Where d.plan_id = s.plan_id
			and s.plan_name = @PlanName
			and d.database_name = 'All System Databases')
		   begin
			Print '-- Process mode is for all System DBs using Maintenance plan [' + @PlanName + ']'
			Select @sysDB_flag = 'y'
			goto label05
		   end


		Print 'Process mode is from Maintenance plan ' + @PlanName
		Select @plan_flag = 'y'
		goto label05
	   end
   end


If @DBname is not null
   begin
	If @DBname = 'ALL_USER_DBs'
	   begin
		Print 'Process mode is for all User DBs.'
		Select @userDB_flag = 'y'
		goto label05
	   end
	Else If @DBname = 'ALL_SYS_DBs'
	   begin
		Print 'Process mode is for all System DBs.'
		Select @sysDB_flag = 'y'
		goto label05
	   end
	Else If @DBname = 'ALL_DBs'
	   begin
		Print 'Process mode is for all DBs.'
		Select @allDB_flag = 'y'
		goto label05
	   end
	Else
	   begin
		If not exists(select 1 from master.sys.sysdatabases where name = @DBname)
		   begin
			Print 'DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
			Select @error_count = @error_count + 1
			Goto label99
		   end
		Else
		   begin
			Print 'Process mode is for a single DB - ' + @DBname
			Select @oneDB_flag = 'y'
			goto label05
		   end
	   end
   end


If @DBname is null and @PlanName is null
   begin
	Print 'DBA Warning:  Invalid input parameter.  @DBname or @PlanName must be specified'
	Select @error_count = @error_count + 1
	Goto label99
   end


--  Backup process has been determined at this point
label05:


If @oneDB_flag = 'n' and @backup_name is not null
   begin
	Print 'DBA Warning:  Invalid input parameters.  A specific backup name can only be set for a single DB backup.'
	Select @error_count = @error_count + 1
	Goto label99
   end


--  If InMage and Redgate, disable and stop VSS
If @BkUpMethod = 'RG' and @skip_InMage_check = 'n'
   begin
	--  check the last time the InMage sync was done.  If within the last 12 minutes, start the backups.
	Print 'Check InMage Sync processing'
	raiserror('', -1,-1) with nowait


	Select @InMage_try = 0
	InMage_start01:
	delete from #ReadSqlLog
	select @a = getdate()-.00001 --1 minute
	select @b = getdate()-.0082 --12 minutes
	insert into #ReadSqlLog EXEC xp_readerrorlog 0, 1, 'I/O was resumed', '', @b, @a;
	--select * from #ReadSqlLog


	delete from #ReadSqlLog2
	select @a = getdate()-.00001 --1 minute
	select @b = getdate()-.021 --30 minutes
	insert into #ReadSqlLog2 EXEC xp_readerrorlog 0, 1, 'I/O was resumed', '', @b, @a;
	--select * from #ReadSqlLog2


	If (select count(*) from #ReadSqlLog) = 0
	   begin
		--  if no InMage sync in the last 12 minutes, check to see if VSS is running.
		Print 'Check VSS Running status'
		raiserror('', -1,-1) with nowait


		delete from #temp_tbl2
		select @cmd = 'sc query vss'
		insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
		Delete from #temp_tbl2 where text01 is null or text01 = ''
		--select * from #temp_tbl2


		--  If VSS is running, wait 3 minutes
		If (select count(*) from #ReadSqlLog2) <> 0
 		   and exists (select 1 from #temp_tbl2 where text01 like '%running%') and @InMage_try < 3
		   begin
			--  run the InMage process
			delete from #temp_tbl2
			select @cmd = '"C:\Program Files (x86)\InMage Systems\vacp.exe"  -a SQL2005'
			insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
			Delete from #temp_tbl2 where text01 is null or text01 = ''
			--select * from #temp_tbl2


			Print 'Wait 3 minutes'
			raiserror('', -1,-1) with nowait
			Select @InMage_try = @InMage_try + 1
			Waitfor delay '00:02:58'
			goto InMage_start01
		   end
	   end


	--  disable InMage
	delete from #temp_tbl2
	select @cmd = 'sc query'
	--print @cmd
	insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
	Delete from #temp_tbl2 where text01 is null or text01 = ''
	Delete from #temp_tbl2 where text01 not like '%svagents%'
	--select * from #temp_tbl2


	If exists (select 1 from #temp_tbl2 where text01 like '%svagents%')
	   begin
		Select @VSS_flag = 'y'
		print 'Stopping VSS'
		select @cmd = 'sc config "VSS" start= disabled'
		Print @cmd
		exec master.sys.xp_cmdshell @cmd
		select @cmd = 'net stop VSS'
		Print @cmd
		exec master.sys.xp_cmdshell @cmd
	   end
   end


--  Set backup path
Select @parm01 = @save_servername2 + '_backup'
If exists (select 1 from dbo.local_serverenviro where env_type = 'backup_path')
   begin
	Select @std_backup_path = (select top 1 env_detail from dbo.local_serverenviro where env_type = 'backup_path')
   end
Else
   begin
	--exec DBAOps.dbo.dbasp_get_share_path @parm01, @std_backup_path output
	SET @std_backup_path = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)
   end


If @BkUpPath is not null
   begin
	Select @outpath = @BkUpPath
   end
Else If @target_path is not null
   begin
	Select @outpath = @target_path
   end
Else
   begin
	Select @outpath = @std_backup_path
   end


If @process_mode = 'pre_release' and @outpath = @std_backup_path
   begin
	--  check to see if the @pre_release folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\pre_release'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\pre_release"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	 end


	--  set @outpath
	Select @outpath = @std_backup_path + '\pre_release'
	select @backup_log_flag = 'y'
   end
Else If @process_mode = 'pre_calc' and @outpath = @std_backup_path
   begin
	--  check to see if the @pre_calc folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\pre_calc'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\pre_calc"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	--  set @outpath
	Select @outpath = @std_backup_path + '\pre_calc'
	select @backup_log_flag = 'y'
   end
Else If @process_mode = 'mid_calc' and @outpath = @std_backup_path
   begin
	--  check to see if the @mid_calc folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @std_backup_path + '\mid_calc'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @std_backup_path + '\mid_calc"'
		Print 'Creating pre_release folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	--  set @outpath
	Select @outpath = @std_backup_path + '\mid_calc'
	select @backup_log_flag = 'y'
   end


Print 'Backup output path is ' + @outpath


Select @charpos = charindex(' ', @outpath)
IF @charpos <> 0
   begin
	Select @outpath2 = '"' + @outpath + '"'
   end
Else
   begin
	Select @outpath2 = @outpath
   end


Select @charpos = charindex(' ', @std_backup_path)
IF @charpos <> 0
   begin
	Select @std_backup_path2 = '"' + @std_backup_path + '"'
   end
Else
   begin
	Select @std_backup_path2 = @std_backup_path
   end


Print ' '


/****************************************************************
 *                MainLine
 ***************************************************************/
--  Maintenance plan used for DB list
If @plan_flag = 'y'
   begin


	Select @cmd = 'SELECT d.database_name
	   From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s ' +
	  'Where d.plan_id = s.plan_id
	     and s.plan_name = ''' + @PlanName + ''''


	delete from @DBnames


	insert into @DBnames (name) exec (@cmd)


	delete from @DBnames where name is null or name = ''
        --select * from @DBnames


	If (select count(*) from @DBnames) > 0
	   begin
		start_dbnames:


		Select @cu10DBName = (select top 1 name from @DBnames order by name)

		---- GET COPYTO INFO
		--DELETE	@LogShipPaths
		--SET		@TSQL			= 'USE ['+@cu10DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		----PRINT @TSQL
		--INSERT INTO	@LogShipPaths
		--EXEC		(@TSQL)
		--SELECT		@TSQL = ''
		--SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		--FROM		@LogShipPaths
		--WHERE		nullif(CopyToPath,'') IS NOT NULL


		If not exists (select 1 from master.sys.databases where name = @cu10DBName)
		   begin
			Print 'DBA Warning:  Skip backup for missing DB: ' + @cu10DBName
			goto Maint_plan_loop_end
		   end


		--  PreRelease Processing
		If @process_mode = 'pre_release' and DATABASEPROPERTYEX(@cu10DBName, 'Recovery') = 'simple'
		   begin
			select @save_date = convert(nvarchar(30), getdate(), 121)
			insert into dbo.local_control values ('Deploy_Recovery_Model', @cu10DBName, 'simple', @save_date)


			Print 'Setting this DB to FULL recovery mode.'
			select @cmd = 'ALTER DATABASE [' + @cu10DBName + '] SET RECOVERY FULL WITH NO_WAIT'
			Print @cmd
			raiserror('', -1,-1) with nowait


			Exec (@cmd)
		   end


		If @DeletePrevious = 'before'
		   begin
			Select @cmd = 'del ' + @outpath2 + '\' + @cu10DBName + '_' + @backup_type + '_*.*'
			Print ' '
			Print 'The following delete command will be used.'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd


			--  Check to make sure files were deleted
			--  Skip if this is being run on a sql 7.0 server
			If ( 0 = ( SELECT PATINDEX( '%[7].[00]%', @@version ) ) )
			   begin
				Select @check_backup_path = @outpath + '\' + @cu10DBName + '_' + @backup_type + '_*.*'
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				 begin
					Print 'DBA Warning:  File delete error prior to backup processing'
					--Select @cmd = 'handle /accepteula -u ' + @outpath
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				    end
			   end


			If @process_mode <> 'normal'
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @cu10DBName + '_' + @backup_type + '_*.*'
				Print ' '
				Print 'The following delete command will be used to delete from the standard backup path.'
				Print @cmd
				EXEC master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				--  Skip if this is being run on a sql 7.0 server
				If ( 0 = ( SELECT PATINDEX( '%[7].[00]%', @@version ) ) )
				   begin
					Select @check_backup_path = @std_backup_path + '\' + @cu10DBName + '_' + @backup_type + '_*.' + rtrim(@BkUpSufx)
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output

					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error prior to backup processing'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					    end
				   end
			   end
		   end


		Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
		Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


		Select @backup_by_filegroup_flag = 'n'
		If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@cu10DBName))
		  and @Filegroup_Bypass = 'n'
		   begin
			Select @backup_by_filegroup_flag = 'y'

			Select @cmd = 'SELECT name, data_space_id From ' + @cu10DBName + '.sys.filegroups'
			--print @cmd
			delete from @filegroupnames
			insert into @filegroupnames exec (@cmd)
			delete from @filegroupnames where name is null or name = ''
			--select * from @filegroupnames
		   end


		backup_by_filegroup10:

		If @backup_by_filegroup_flag = 'y'
		   begin
			Select @save_filegroupname = (select top 1 name from @filegroupnames order by data_space_id)
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_FG_' + rtrim(@save_filegroupname) + '_' + rtrim(@date) + '.' + rtrim(@BkUpSufx) + ''
		   end
		Else
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx
		   end


		Print 'Output file will be: ' + @BkUpFile


		If rtrim(@cu10DBName) in ('master', 'model','msdb')
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'
			Print 'Output file will be: ' + @BkUpFile


			Select @cmd = 'Backup database [' + rtrim(@cu10DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end
		Else If @BkUpMethod = 'LS'
		   begin
			Select @cmd = 'master.dbo.xp_backup_database'
					+ ' @database = ''' + rtrim(@cu10DBName)
					+ ''', @filename = ''' + rtrim(@BkUpFile)
					+ ''', @threads = ' + convert(varchar(10), @threads)
					+ ', @compressionlevel = ' + convert(varchar(5), @compressionlevel)
					+ ', @logging = 0'
			Print @cmd
			Print ' '
			Exec @retcode = master.dbo.xp_backup_database
					 @database = @cu10DBName
					,@filename = @BkUpFile
					,@threads = @threads
					,@compressionlevel = @compressionlevel
					,@logging = 0
		   end
		Else If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'

			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu10DBName) + ']'
						+ ' FILEGROUP = ''' + rtrim(@save_filegroupname)
						+ ''' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'') -- ADD COPYTO IF EXISTS
			   end
			Else
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu10DBName) + ']'
						+ ' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'') -- ADD COPYTO IF EXISTS
			   end

			If @VerifyBackup = 'y'
			   begin
			    Select @cmd2 = @cmd2 + ', VERIFY'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu10DBName and page_verify_option = 2)
			   begin
			    Select @cmd2 = @cmd2 + ', CHECKSUM'
			   end
			Select @cmd2 = @cmd2 + '"'


			Print @cmd
			Print @cmd2
			Print ' '
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			--select * from #resultstring
		   end
		Else
		   begin
			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu10DBName) + '] FILEGROUP = ''' + rtrim(@save_filegroupname) + ''' to disk = ''' + @BkUpFile + ''' with init'
			   end
			Else
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu10DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu10DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ', COMPRESSION'
			   end
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Error:  DB Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode was not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  DB Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename = rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx


			Insert into dbo.backup_log values(getdate(), @cu10DBName, @BkUpFilename, @outpath, @process_mode)
		   end


		--  Loop for filegroup backups
		If @backup_by_filegroup_flag = 'y'
		   begin
			Delete from @filegroupnames where name = @save_filegroupname
			If exists (select 1 from @filegroupnames)
			   begin
				goto backup_by_filegroup10
			   end
			Select @backup_by_filegroup_flag = 'n'
		   end


		If @DeletePrevious in ('before', 'after')
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu10DBName + '_' + @backup_type + '_*.* /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			--select * from #DirectoryTempTable


			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					--  Skip if this is being run on a sql 7.0 server
					If ( 0 = ( SELECT PATINDEX( '%[7].[00]%', @@version ) ) )
					   begin
						Select @check_backup_path = @outpath + '\' + @Hold_filename
						exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


						If @exists = 1
						   begin
							Print 'DBA Warning:  File delete error after backup processing complete'
							--Select @cmd = 'handle /accepteula -u ' + @outpath
							--Print @cmd
							--exec master.sys.xp_cmdshell @cmd
						    end
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end


			If @process_mode <> 'normal'
			   begin
				Delete from #DirectoryTempTable
				select @cmd = 'dir ' + @std_backup_path2 + '\' + @cu10DBName + '_' + @backup_type + '_*.* /B'
				insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
				Delete from #DirectoryTempTable where cmdoutput is null
				Select @tempcount = (select count(*) from #DirectoryTempTable)
				--select * from #DirectoryTempTable


				While (@tempcount > 0)
				   begin
					Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


					--  Parse the backup file name to get the date info
					Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = reverse(@Hold_filename)
						Select @charpos = charindex('_', @Hold_filedate)
						IF @charpos <> 0
						   begin
							Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
						   end
						Select @Hold_filedate = reverse(@Hold_filedate)
					   end


					Select @Hold_filedate = left(@Hold_filedate, 12)


					If left(@date, 12) > @Hold_filedate
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
						select @cmd = 'del ' + @std_backup_path2 + '\' + @Hold_filename
						print @cmd
						exec master.sys.xp_cmdshell @cmd


						--  Check to make sure files were deleted
						--  Skip if this is being run on a sql 7.0 server
						If ( 0 = ( SELECT PATINDEX( '%[7].[00]%', @@version ) ) )
						   begin
							Select @check_backup_path = @std_backup_path + '\' + @Hold_filename
							exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


							If @exists = 1
							   begin
								Print 'DBA Warning:  File delete error after backup processing complete'
								--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
								--Print @cmd
								--exec master.sys.xp_cmdshell @cmd
							    end
						   end
					   end
					Else
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					   end

					Select @tempcount = (select count(*) from #DirectoryTempTable)


				   end


			   end
		   end


		If @DeleteTran = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu10DBName + '_tlog_*.' + rtrim(@BkUpSufx_tlog) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
					Select @charpos = charindex('_tlog_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					--  Skip if this is being run on a sql 7.0 server
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end


		If @DeleteDfntl = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu10DBName + '_dfntl_*.' + rtrim(@BkUpSufx_dfntl) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_dfntl_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		 end


		--  Create a differential
		If @auto_diff = 'y'
		   begin
			exec DBAOps.dbo.dbasp_Backup_Differential @DBName = @cu10DBName
								,@BkUpPath = @BkUpPath
								,@RedGate_Bypass = @RedGate_Bypass
								,@Compress_Bypass = @Compress_Bypass
								,@process_mode = @process_mode
								,@skip_vss = 'y'
		   end


		Maint_plan_loop_end:


		--  check for more rows to process
		Delete from @DBnames where name = @cu10DBName
		If (select count(*) from @DBnames) > 0
		   begin
			goto start_dbnames
		   end


	   end


   end
--  Back up a single DB
Else If @oneDB_flag = 'y'
   begin


	--  PreRelease Processing
	If @process_mode = 'pre_release' and DATABASEPROPERTYEX(@DBName, 'Recovery') = 'simple'
	   begin
		select @save_date = convert(nvarchar(30), getdate(), 121)
		insert into dbo.local_control values ('Deploy_Recovery_Model', @DBName, 'simple', @save_date)


		Print 'Setting this DB to FULL recovery mode.'
		select @cmd = 'ALTER DATABASE [' + @DBName + '] SET RECOVERY FULL WITH NO_WAIT'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)
	   end


	--	-- GET COPYTO INFO
	--DELETE	@LogShipPaths
	--SET		@TSQL			= 'USE ['+@DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
	----PRINT @TSQL
	--INSERT INTO	@LogShipPaths
	--EXEC		(@TSQL)
	--SELECT		@TSQL = ''
	--SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
	--FROM		@LogShipPaths
	--WHERE		nullif(CopyToPath,'') IS NOT NULL


	Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
	Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


	If @backup_name is null
	   begin
		Select @save_backupname = rtrim(@DBname) + '_' + rtrim(@backup_type) + '_' + rtrim(@date) + '.' + rtrim(@BkUpSufx) + ''
	   end
	Else
	   begin
		Select @save_backupname = @backup_name
	   end


	If @backup_name is null
	   begin
		Select @cmd = 'del ' + @outpath2 + '\' + @DBname + '_' + @backup_type + '_*.*'
		Select @check_backup_path = @outpath + '\' + @DBname + '_' + @backup_type + '_*.*'
	   end
	Else
	   begin
		Select @cmd = 'del ' + @outpath2 + '\' + @backup_name
		Select @check_backup_path = @outpath + '\' + @backup_name
	   end


	If @DeletePrevious = 'before'
	   begin
		Print ' '
		Print 'The following delete command will be used.'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd


		--  Check to make sure files were deleted
		exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output

		If @exists = 1
		   begin
			Print 'DBA Warning:  File delete error prior to backup processing'
			--Select @cmd = 'handle /accepteula -u ' + @outpath
			--Print @cmd
			--exec master.sys.xp_cmdshell @cmd
		   end


		If @process_mode <> 'normal'
		   begin
			If @backup_name is null
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @DBname + '_' + @backup_type + '_*.*'
				Select @check_backup_path = @std_backup_path + '\' + @DBname + '_' + @backup_type + '_*.*'
			   end
			Else
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @backup_name
				Select @check_backup_path = @std_backup_path + '\' + @backup_name
			   end


			Print ' '
			Print 'The following delete command will be used.'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd


			--  Check to make sure files were deleted
			exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output

			If @exists = 1
			   begin
				Print 'DBA Warning:  File delete error prior to backup processing'
				--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
				--Print @cmd
				--exec master.sys.xp_cmdshell @cmd
			   end
		   end
	   end


	Select @backup_by_filegroup_flag = 'n'
	If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@DBname))
	   begin
		Select @backup_by_filegroup_flag = 'y'

		Select @cmd = 'SELECT name, data_space_id From ' + @DBname + '.sys.filegroups'
		--print @cmd
		delete from @filegroupnames
		insert into @filegroupnames exec (@cmd)
		delete from @filegroupnames where name is null or name = ''
		--select * from @filegroupnames
	   end


	backup_by_filegroup2:

	If @backup_by_filegroup_flag = 'y'
	   begin
		Select @save_filegroupname = (select top 1 name from @filegroupnames order by data_space_id)
		Select @save_backupname = rtrim(@DBname) + '_' + rtrim(@backup_type) + '_FG_' + rtrim(@save_filegroupname) + '_' + rtrim(@date) + '.' + rtrim(@BkUpSufx) + ''
	   end


	Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@save_backupname)
	Print 'Output file will be: ' + @BkUpFile


	If rtrim(@cu10DBName) in ('master', 'model','msdb')
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'
			Print 'Output file will be: ' + @BkUpFile


			Select @cmd = 'Backup database [' + rtrim(@cu10DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end
	Else If @BkUpMethod = 'LS'
	   begin
		Select @cmd = 'master.dbo.xp_backup_database'
				+ ' @database = ''' + rtrim(@DBname)
				+ ''', @filename = ''' + rtrim(@BkUpFile)
				+ ''', @threads = ' + convert(varchar(10), @threads)
				+ ', @compressionlevel = ' + convert(varchar(5), @compressionlevel)
				+ ', @logging = 0'
		Print @cmd
		Print ' '
		Exec @retcode = master.dbo.xp_backup_database
				 @database = @DBname
				,@filename = @BkUpFile
				,@threads = @threads
				,@compressionlevel = @compressionlevel
				,@logging = 0
	   end
	Else If @BkUpMethod = 'RG'
	   begin
		Select @cmd = 'master.dbo.sqlbackup'


		If @backup_by_filegroup_flag = 'y'
		   begin
			Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@DBName) + ']'
					+ ' FILEGROUP = ''' + rtrim(@save_filegroupname)
					+ ''' TO DISK = ''' + rtrim(@BkUpFile)
					+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
					+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
					+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
					+ ', SINGLERESULTSET'
					--+ isnull(@TSQL,'')
		   end
		Else
		   begin
			Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@DBName) + ']'
					+ ' TO DISK = ''' + rtrim(@BkUpFile)
					+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
					+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
					+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
					+ ', SINGLERESULTSET'
					--+ isnull(@TSQL,'')
		   end

		If @VerifyBackup = 'y'
		   begin
		    Select @cmd2 = @cmd2 + ', VERIFY'
		   end
		If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @DBName and page_verify_option = 2)
		   begin
		    Select @cmd2 = @cmd2 + ', CHECKSUM'
		   end
		Select @cmd2 = @cmd2 + '"'
		Print @cmd
		Print @cmd2
		Print ' '
		delete from #resultstring
		Insert into #resultstring exec @cmd @cmd2
		select * from #resultstring
	   end
	Else
	   begin
		If @backup_by_filegroup_flag = 'y'
		   begin
			Select @cmd = 'Backup database [' + rtrim(@DBName) + '] FILEGROUP = ''' + rtrim(@save_filegroupname) + ''' to disk = ''' + @BkUpFile + ''' with init'
		   end
		Else
		   begin
			Select @cmd = 'Backup database [' + rtrim(@DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
		   end
		If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @DBName and page_verify_option = 2)
		   begin
			Select @cmd = @cmd + ', CHECKSUM'
		   end
		If @BkUpMethod = 'MSc'
		   begin
			Select @cmd = @cmd + ', COMPRESSION'
		   end
		Print @cmd
		Print ' '
		Exec (@cmd)
	   end


	If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
	   begin
		Print 'DBA Error:  DB Backup Failure for command ' + @cmd
		Print '--***********************************************************'
		Print '@@error or @retcode is not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end
	Else If exists (select 1 from #resultstring where message like '%error%')
	   begin
		Print 'DBA Error:  DB Backup (RG) Failure for command ' + @cmd + @cmd2
		Print '--***********************************************************'
		Select * from #resultstring
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  Log the backup info
	If @backup_log_flag = 'y'
	   begin
		Insert into dbo.backup_log values(getdate(), @DBName, @save_backupname, @outpath, @process_mode)
	   end


	--  Loop for filegroup backups
	If @backup_by_filegroup_flag = 'y'
	   begin
		Delete from @filegroupnames where name = @save_filegroupname
		If exists (select 1 from @filegroupnames)
		   begin
			goto backup_by_filegroup2
		   end
		Select @backup_by_filegroup_flag = 'n'
	   end


	If @DeletePrevious in ('before', 'after')
	   begin
		Delete from #DirectoryTempTable
		select @cmd = 'dir ' + @outpath2 + '\' + @DBname + '_' + @backup_type + '_*.* /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null
		Select @tempcount = (select count(*) from #DirectoryTempTable)
		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


			--  Parse the backup file name to get the date info
			Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = reverse(@Hold_filename)
				Select @charpos = charindex('_', @Hold_filedate)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
				   end
				Select @Hold_filedate = reverse(@Hold_filedate)
			   end


			Select @Hold_filedate = left(@Hold_filedate, 12)


			If left(@date, 12) > @Hold_filedate
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
				print @cmd
				exec master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @outpath + '\' + @Hold_filename
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error after backup processing completed'
					--Select @cmd = 'handle /accepteula -u ' + @outpath
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
			Else
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
			   end

			Select @tempcount = (select count(*) from #DirectoryTempTable)


		   end


		If @process_mode <> 'normal'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @std_backup_path2 + '\' + @DBname + '_' + @backup_type + '_*.* /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @std_backup_path2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @std_backup_path + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing completed'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end
	   end


	If @DeleteTran = 'y'
	   begin
		Delete from #DirectoryTempTable
		select @cmd = 'dir ' + @outpath2 + '\' + @DBName + '_tlog_*.' + rtrim(@BkUpSufx_tlog) + ' /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null
		Select @tempcount = (select count(*) from #DirectoryTempTable)
		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


			--  Parse the backup file name to get the date info
			Select @charpos = charindex('_tlog_', @Hold_filename)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = reverse(@Hold_filename)
				Select @charpos = charindex('_', @Hold_filedate)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
				   end
				Select @Hold_filedate = reverse(@Hold_filedate)
			   end


			Select @Hold_filedate = left(@Hold_filedate, 12)


			If left(@date, 12) > @Hold_filedate
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
				print @cmd
				exec master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @outpath + '\' + @Hold_filename
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error after backup processing complete'
					--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
			Else
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
			   end

			Select @tempcount = (select count(*) from #DirectoryTempTable)


		   end
	   end


	If @DeleteDfntl = 'y'
	   begin
		Delete from #DirectoryTempTable
		select @cmd = 'dir ' + @outpath2 + '\' + @DBname + '_dfntl_*.' + rtrim(@BkUpSufx_dfntl) + ' /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null
		Select @tempcount = (select count(*) from #DirectoryTempTable)
		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


			--  Parse the backup file name to get the date info
			Select @charpos = charindex('_dfntl_', @Hold_filename)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = reverse(@Hold_filename)
				Select @charpos = charindex('_', @Hold_filedate)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
				   end
				Select @Hold_filedate = reverse(@Hold_filedate)
			   end


			Select @Hold_filedate = left(@Hold_filedate, 12)


			If left(@date, 12) > @Hold_filedate
			  begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
				print @cmd
				exec master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @outpath + '\' + @Hold_filename
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error after backup processing complete'
					--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
			Else
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
			   end

			Select @tempcount = (select count(*) from #DirectoryTempTable)


		   end
	   end


	--  Create a differential
	If @auto_diff = 'y'
	   begin
		exec DBAOps.dbo.dbasp_Backup_Differential @DBName = @DBName
							,@BkUpPath = @BkUpPath
							,@RedGate_Bypass = @RedGate_Bypass
							,@Compress_Bypass = @Compress_Bypass
							,@process_mode = @process_mode
							,@skip_vss = 'y'
	   end
   end
--  Back up all user DBs
Else If @userDB_flag = 'y'
   begin


	Select @cmd = 'SELECT d.name, d.dbid, d.status
	   From master.sys.sysdatabases   d ' +
	  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


	delete from @DBnames2


	insert into @DBnames2 (name, dbid, status) exec (@cmd)


	delete from @DBnames2 where name is null or name = ''
	--select * from @DBnames2


	If (select count(*) from @DBnames2) > 0
	   begin
		start_dbnames2:


		Select @cu11DBId = (select top 1 dbid from @DBnames2 order by dbid)
		Select @cu11DBName = (select name from @DBnames2 where dbid = @cu11DBId)
		Select @cu11DBStatus = (select status from @DBnames2 where dbid = @cu11DBId)


		If not exists (select 1 from master.sys.databases where name = @cu10DBName)
		   begin
			Print 'DBA Warning:  Skip backup for missing DB: ' + @cu10DBName
			goto allDBs_loop_end
		   end


		---- GET COPYTO INFO
		--DELETE	@LogShipPaths
		--SET		@TSQL			= 'USE ['+@cu11DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		----PRINT @TSQL
		--INSERT INTO	@LogShipPaths
		--EXEC		(@TSQL)
		--SELECT		@TSQL = ''
		--SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		--FROM		@LogShipPaths
		--WHERE		nullif(CopyToPath,'') IS NOT NULL


		--  PreRelease Processing
		If @process_mode = 'pre_release' and DATABASEPROPERTYEX(@cu11DBName, 'Recovery') = 'simple'
		   begin
			select @save_date = convert(nvarchar(30), getdate(), 121)
			insert into dbo.local_control values ('Deploy_Recovery_Model', @cu11DBName, 'simple', @save_date)


			Print 'Setting this DB to FULL recovery mode.'
			select @cmd = 'ALTER DATABASE [' + @cu11DBName + '] SET RECOVERY FULL WITH NO_WAIT'
			Print @cmd
			raiserror('', -1,-1) with nowait


			Exec (@cmd)
		   end


		If @DeletePrevious = 'before'
		   begin
			Select @cmd = 'del ' + @outpath2 + '\' + @cu11DBName + '_' + @backup_type + '_*.*'
			Print ' '
			Print 'The following delete command will be used.'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd


			--  Check to make sure files were deleted
			Select @check_backup_path = @outpath + '\' + @cu11DBName + '_' + @backup_type + '_*.*'
			exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


			If @exists = 1
			   begin
				Print 'DBA Warning:  File delete error prior to backup processing'
				--Select @cmd = 'handle /accepteula -u ' + @outpath
				--Print @cmd
				--exec master.sys.xp_cmdshell @cmd
			   end


			If @process_mode <> 'normal'
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @cu11DBName + '_' + @backup_type + '_*.*'
				Print ' '
				Print 'The following delete command will be used.'
				Print @cmd
				EXEC master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @std_backup_path + '\' + @cu11DBName + '_' + @backup_type + '_*.*'
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error prior to backup processing'
					--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
		   end


		Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
		Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


		Select @backup_by_filegroup_flag = 'n'
		If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@cu11DBName))
		   begin
			Select @backup_by_filegroup_flag = 'y'

			Select @cmd = 'SELECT name, data_space_id From ' + @cu11DBName + '.sys.filegroups'
			--print @cmd
			delete from @filegroupnames
			insert into @filegroupnames exec (@cmd)
			delete from @filegroupnames where name is null or name = ''
			--select * from @filegroupnames
		   end


		backup_by_filegroup11:

		If @backup_by_filegroup_flag = 'y'
		   begin
			Select @save_filegroupname = (select top 1 name from @filegroupnames order by data_space_id)
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu11DBName) + '_' + rtrim(@backup_type) + '_FG_' + rtrim(@save_filegroupname) + '_' + rtrim(@date) + '.' + rtrim(@BkUpSufx) + ''
		   end
		Else
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu11DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx
		   end


		Print 'Output file will be: ' + @BkUpFile


		If rtrim(@cu10DBName) in ('master', 'model','msdb')


		   begin


			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu10DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'
			Print 'Output file will be: ' + @BkUpFile


			Select @cmd = 'Backup database [' + rtrim(@cu10DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		Else If @BkUpMethod = 'LS'
		   begin
			Select @cmd = 'master.dbo.xp_backup_database'
					+ ' @database = ''' + rtrim(@cu11DBName)
					+ ''', @filename = ''' + rtrim(@BkUpFile)
					+ ''', @threads = ' + convert(varchar(10), @threads)
					+ ', @compressionlevel = ' + convert(varchar(5), @compressionlevel)
					+ ', @logging = 0'
			Print @cmd
			Print ' '
			Exec @retcode = master.dbo.xp_backup_database
					 @database = @cu11DBName
					,@filename = @BkUpFile
					,@threads = @threads
					,@compressionlevel = @compressionlevel
					,@logging = 0
		   end
		Else If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'

			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu11DBName) + ']'
						+ ' FILEGROUP = ''' + rtrim(@save_filegroupname)
						+ ''' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'')
			   end
			Else
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu11DBName) + ']'
						+ ' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'')
			   end


			If @VerifyBackup = 'y'
			   begin
			    Select @cmd2 = @cmd2 + ', VERIFY'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 2)
			   begin
			    Select @cmd2 = @cmd2 + ', CHECKSUM'
			   end
			Select @cmd2 = @cmd2 + '"'


			Print @cmd
			Print @cmd2
			Print ' '
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			select * from #resultstring
		   end
		Else
		   begin
			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu11DBName) + '] FILEGROUP = ''' + rtrim(@save_filegroupname) + ''' to disk = ''' + @BkUpFile + ''' with init'
			   end
			Else
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu11DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ', COMPRESSION'
			   end
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Error:  DB Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode is not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  DB Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename = rtrim(@cu11DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx


			Insert into dbo.backup_log values(getdate(), @cu11DBName, @BkUpFilename, @outpath, @process_mode)
		   end


		--  Loop for filegroup backups
		If @backup_by_filegroup_flag = 'y'
		   begin
			Delete from @filegroupnames where name = @save_filegroupname
			If exists (select 1 from @filegroupnames)
			   begin
				goto backup_by_filegroup11
			   end
			Select @backup_by_filegroup_flag = 'n'
		   end


		If @DeletePrevious in ('before', 'after')
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu11DBName + '_' + @backup_type + '_*.* /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing completed'
						--Select @cmd = 'handle /accepteula -u ' + @outpath
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end


				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end


			If @process_mode <> 'normal'
			   begin
				Delete from #DirectoryTempTable
				select @cmd = 'dir ' + @std_backup_path2 + '\' + @cu11DBName + '_' + @backup_type + '_*.* /B'
				insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
				Delete from #DirectoryTempTable where cmdoutput is null
				Select @tempcount = (select count(*) from #DirectoryTempTable)
				While (@tempcount > 0)
				   begin
					Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


					--  Parse the backup file name to get the date info
					Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = reverse(@Hold_filename)
						Select @charpos = charindex('_', @Hold_filedate)
						IF @charpos <> 0
						   begin
							Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
						   end
						Select @Hold_filedate = reverse(@Hold_filedate)
					   end


					Select @Hold_filedate = left(@Hold_filedate, 12)


					If left(@date, 12) > @Hold_filedate
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
						select @cmd = 'del ' + @std_backup_path2 + '\' + @Hold_filename
						print @cmd
						exec master.sys.xp_cmdshell @cmd


						--  Check to make sure files were deleted
						Select @check_backup_path = @std_backup_path + '\' + @Hold_filename
						exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


						If @exists = 1
						   begin
							Print 'DBA Warning:  File delete error after backup processing completed'
							--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
							--Print @cmd
							--exec master.sys.xp_cmdshell @cmd
						   end
					   end
					Else
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					   end

					Select @tempcount = (select count(*) from #DirectoryTempTable)


				   end
			   end
		   end


		If @DeleteTran = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu11DBName + '_tlog_*.' + rtrim(@BkUpSufx_tlog) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_tlog_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning: File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end


		If @DeleteDfntl = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu11DBName + '_dfntl_*.' + rtrim(@BkUpSufx_dfntl) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_dfntl_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end


		--  Create a differential
		If @auto_diff = 'y'
		   begin
			exec DBAOps.dbo.dbasp_Backup_Differential @DBName = @cu11DBName
								,@BkUpPath = @BkUpPath
								,@RedGate_Bypass = @RedGate_Bypass
								,@Compress_Bypass = @Compress_Bypass
								,@process_mode = @process_mode
								,@skip_vss = 'y'
		   end


		allDBs_loop_end:


		--  check for more rows to process
		delete from @DBnames2 where dbid = @cu11DBId
		If (select count(*) from @DBnames2) > 0
		   begin
			goto start_dbnames2
		   end


	   end


   end
--  Back up all system DBs
Else If @sysDB_flag = 'y'
   begin


	Select @cmd = 'SELECT d.name, d.dbid, d.status
	   From master.sys.sysdatabases   d ' +
	  'Where d.name in (''master'', ''model'', ''msdb'')'


	delete from @DBnames2


	insert into @DBnames2 (name, dbid, status) exec (@cmd)


	delete from @DBnames2 where name is null or name = ''
	--select * from @DBnames2


	If (select count(*) from @DBnames2) > 0
	   begin
		start_dbnames2b:


		Select @cu12DBId = (select top 1 dbid from @DBnames2 order by dbid)
		Select @cu12DBName = (select name from @DBnames2 where dbid = @cu12DBId)
		Select @cu12DBStatus = (select status from @DBnames2 where dbid = @cu12DBId)


		---- GET COPYTO INFO
		--DELETE	@LogShipPaths
		--SET		@TSQL			= 'USE ['+@cu12DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		----PRINT @TSQL
		--INSERT INTO	@LogShipPaths
		--EXEC		(@TSQL)
		--SELECT		@TSQL = ''
		--SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		--FROM		@LogShipPaths
		--WHERE		nullif(CopyToPath,'') IS NOT NULL

		If @DeletePrevious = 'before'
		   begin
			Select @cmd = 'del ' + @outpath2 + '\' + @cu12DBName + '_' + @backup_type + '_*.bak'
			Print ' '
			Print 'The following delete command will be used.'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd


			--  Check to make sure files were deleted
			Select @check_backup_path = @outpath + '\' + @cu12DBName + '_' + @backup_type + '_*.bak'
			exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


			If @exists = 1
			   begin
				Print 'DBA Warning:  File delete error prior to backup processing'
				--Select @cmd = 'handle /accepteula -u ' + @outpath
				--Print @cmd
				--exec master.sys.xp_cmdshell @cmd
			   end


			If @process_mode <> 'normal'
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @cu12DBName + '_' + @backup_type + '_*.bak'
				Print ' '
				Print 'The following delete command will be used.'
				Print @cmd
				EXEC master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @std_backup_path + '\' + @cu12DBName + '_' + @backup_type + '_*.bak'
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error prior to backup processing'
					--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
		   end


		Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
		Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


		Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu12DBName) + '_' + rtrim(@backup_type) + '_' + rtrim(@date) + '.bak'
		Print 'Output file will be: ' + @BkUpFile

		If rtrim(@cu12DBName) in ('master', 'model','msdb')
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu12DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'
			Print 'Output file will be: ' + @BkUpFile


			Select @cmd = 'Backup database [' + rtrim(@cu12DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu12DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If (@@error <> 0 or @retcode <> 0)
		   begin
			Print 'DBA Error:  DB Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode is not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename = rtrim(@cu12DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'


			Insert into dbo.backup_log values(getdate(), @cu12DBName, @BkUpFilename, @outpath, @process_mode)
		   end


		If @DeletePrevious in ('before', 'after')
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu12DBName + '_' + @backup_type + '_*.bak /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing completed'
						--Select @cmd = 'handle /accepteula -u ' + @outpath
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end


			If @process_mode <> 'normal'
			   begin
				Delete from #DirectoryTempTable
				select @cmd = 'dir ' + @std_backup_path2 + '\' + @cu12DBName + '_' + @backup_type + '_*.bak /B'
				insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
				Delete from #DirectoryTempTable where cmdoutput is null
				Select @tempcount = (select count(*) from #DirectoryTempTable)
				While (@tempcount > 0)
				   begin
					Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


					--  Parse the backup file name to get the date info
					Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = reverse(@Hold_filename)
						Select @charpos = charindex('_', @Hold_filedate)
						IF @charpos <> 0
						   begin
							Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
						   end
						Select @Hold_filedate = reverse(@Hold_filedate)
					   end


					Select @Hold_filedate = left(@Hold_filedate, 12)


					If left(@date, 12) > @Hold_filedate
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
						select @cmd = 'del ' + @std_backup_path2 + '\' + @Hold_filename
						print @cmd
						exec master.sys.xp_cmdshell @cmd


						--  Check to make sure files were deleted
						Select @check_backup_path = @std_backup_path + '\' + @Hold_filename
						exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


						If @exists = 1
						   begin
							Print 'DBA Warning:  File delete error after backup processing completed'
							--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
							--Print @cmd
							--exec master.sys.xp_cmdshell @cmd
						   end
					   end
					Else
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					   end

					Select @tempcount = (select count(*) from #DirectoryTempTable)
				   end
			   end
		   end


		--  check for more rows to process
		delete from @DBnames2 where dbid = @cu12DBId
		If (select count(*) from @DBnames2) > 0
		   begin
			goto start_dbnames2b
		   end


	   end


   end
--  Back up all DBs
Else If @allDB_flag = 'y'
   begin


	Select @cmd = 'SELECT d.name, d.dbid, d.status
	   From master.sys.sysdatabases   d ' +
	  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


	delete from @DBnames2


	insert into @DBnames2 (name, dbid, status) exec (@cmd)


	delete from @DBnames2 where name is null or name = ''
	--select * from @DBnames2


	If (select count(*) from @DBnames2) > 0
	   begin
		start_dbnames2c:


		Select @cu13DBId = (select top 1 dbid from @DBnames2 order by dbid)
		Select @cu13DBName = (select name from @DBnames2 where dbid = @cu13DBId)
		Select @cu13DBStatus = (select status from @DBnames2 where dbid = @cu13DBId)


		---- GET COPYTO INFO
		--DELETE	@LogShipPaths
		--SET		@TSQL			= 'USE ['+@cu13DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		----PRINT @TSQL
		--INSERT INTO	@LogShipPaths
		--EXEC		(@TSQL)
		--SELECT		@TSQL = ''
		--SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		--FROM		@LogShipPaths
		--WHERE		nullif(CopyToPath,'') IS NOT NULL


		--  PreRelease Processing
		If @process_mode = 'pre_release' and DATABASEPROPERTYEX(@cu13DBName, 'Recovery') = 'simple'
		   begin
			select @save_date = convert(nvarchar(30), getdate(), 121)
			insert into dbo.local_control values ('Deploy_Recovery_Model', @cu13DBName, 'simple', @save_date)


			Print 'Setting this DB to FULL recovery mode.'
			select @cmd = 'ALTER DATABASE [' + @cu13DBName + '] SET RECOVERY FULL WITH NO_WAIT'
			Print @cmd
			raiserror('', -1,-1) with nowait


			Exec (@cmd)
		   end


		If @DeletePrevious = 'before'
		   begin
			Select @cmd = 'del ' + @outpath2 + '\' + @cu13DBName + '_' + @backup_type + '_*.*'
			Print ' '
			Print 'The following delete command will be used.'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd


			--  Check to make sure files were deleted
			Select @check_backup_path = @outpath + '\' + @cu13DBName + '_' + @backup_type + '_*.*'
			exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


			If @exists = 1
			   begin
				Print 'DBA Warning:  File delete error prior to backup processing'
				--Select @cmd = 'handle /accepteula -u ' + @outpath
				--Print @cmd
				--exec master.sys.xp_cmdshell @cmd
			   end


			If @process_mode <> 'normal'
			   begin
				Select @cmd = 'del ' + @std_backup_path2 + '\' + @cu13DBName + '_' + @backup_type + '_*.*'
				Print ' '
				Print 'The following delete command will be used.'
				Print @cmd
				EXEC master.sys.xp_cmdshell @cmd


				--  Check to make sure files were deleted
				Select @check_backup_path = @std_backup_path + '\' + @cu13DBName + '_' + @backup_type + '_*.*'
				exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output

				If @exists = 1
				   begin
					Print 'DBA Warning:  File delete error prior to backup processing'
					--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
					--Print @cmd
					--exec master.sys.xp_cmdshell @cmd
				   end
			   end
		   end


		Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
		Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


		Select @backup_by_filegroup_flag = 'n'
		If exists (select 1 from dbo.Local_Control where subject = 'backup_by_filegroup' and Detail01 = rtrim(@cu13DBName))
		   begin
			Select @backup_by_filegroup_flag = 'y'

			Select @cmd = 'SELECT name, data_space_id From ' + @cu13DBName + '.sys.filegroups'
			--print @cmd
			delete from @filegroupnames
			insert into @filegroupnames exec (@cmd)
			delete from @filegroupnames where name is null or name = ''
			--select * from @filegroupnames
		   end


		backup_by_filegroup13:

		If @backup_by_filegroup_flag = 'y'
		   begin
			Select @save_filegroupname = (select top 1 name from @filegroupnames order by data_space_id)
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu13DBName) + '_' + rtrim(@backup_type) + '_FG_' + rtrim(@save_filegroupname) + '_' + rtrim(@date) + '.' + rtrim(@BkUpSufx) + ''
		   end
		Else
		   begin
			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu13DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx
		   end


		Print 'Output file will be: ' + @BkUpFile

		If rtrim(@cu13DBName) in ('master', 'model','msdb')


		   begin


			Select @BkUpFile = rtrim(@outpath) + '\' + rtrim(@cu13DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.bak'
			Print 'Output file will be: ' + @BkUpFile


			Select @cmd = 'Backup database [' + rtrim(@cu13DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		Else If @BkUpMethod = 'LS'
		   begin
			Select @cmd = 'master.dbo.xp_backup_database'
					+ ' @database = ''' + rtrim(@cu13DBName)
					+ ''', @filename = ''' + rtrim(@BkUpFile)
					+ ''', @threads = ' + convert(varchar(10), @threads)
					+ ', @compressionlevel = ' + convert(varchar(5), @compressionlevel)
					+ ', @logging = 0'
			Print @cmd
			Print ' '
			Exec @retcode = master.dbo.xp_backup_database
					 @database = @cu13DBName
					,@filename = @BkUpFile
					,@threads = @threads
					,@compressionlevel = @compressionlevel
					,@logging = 0
		   end
		Else If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'

			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu13DBName) + ']'
						+ ' FILEGROUP = ''' + rtrim(@save_filegroupname)
						+ ''' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'')
			   end
			Else
			   begin
				Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu13DBName) + ']'
						+ ' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						--+ isnull(@TSQL,'')
			   end


			If @VerifyBackup = 'y'
			   begin
			    Select @cmd2 = @cmd2 + ', VERIFY'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu13DBName and page_verify_option = 2)
			   begin
			    Select @cmd2 = @cmd2 + ', CHECKSUM'
			   end
			Select @cmd2 = @cmd2 + '"'


			Print @cmd
			Print @cmd2
			Print ' '
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			select * from #resultstring
		   end
		Else
		   begin
			If @backup_by_filegroup_flag = 'y'
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu13DBName) + '] FILEGROUP = ''' + rtrim(@save_filegroupname) + ''' to disk = ''' + @BkUpFile + ''' with init'
			   end
			Else
			   begin
				Select @cmd = 'Backup database [' + rtrim(@cu13DBName) + '] to disk = ''' + @BkUpFile + ''' with init'
			   end
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu13DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ', COMPRESSION'
			   end
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Error:  DB Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode is not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  DB Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename = rtrim(@cu13DBName) + '_' + rtrim(@backup_type) + '_' + @date + '.' + @BkUpSufx


			Insert into dbo.backup_log values(getdate(), @cu13DBName, @BkUpFilename, @outpath, @process_mode)
		   end


		--  Loop for filegroup backups
		If @backup_by_filegroup_flag = 'y'
		   begin
			Delete from @filegroupnames where name = @save_filegroupname
			If exists (select 1 from @filegroupnames)
			   begin
				goto backup_by_filegroup13
			   end
			Select @backup_by_filegroup_flag = 'n'
		   end


		If @DeletePrevious in ('before', 'after')
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu13DBName + '_' + @backup_type + '_*.* /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing completed'
						--Select @cmd = 'handle /accepteula -u ' + @outpath
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end


			If @process_mode <> 'normal'
			   begin
				Delete from #DirectoryTempTable
				select @cmd = 'dir ' + @std_backup_path2 + '\' + @cu13DBName + '_' + @backup_type + '_*.* /B'
				insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
				Delete from #DirectoryTempTable where cmdoutput is null
				Select @tempcount = (select count(*) from #DirectoryTempTable)
				While (@tempcount > 0)
				   begin
					Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


					--  Parse the backup file name to get the date info
					Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = reverse(@Hold_filename)
						Select @charpos = charindex('_', @Hold_filedate)
						IF @charpos <> 0
						   begin
							Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
						   end
						Select @Hold_filedate = reverse(@Hold_filedate)
					   end


					Select @Hold_filedate = left(@Hold_filedate, 12)


					If left(@date, 12) > @Hold_filedate
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
						select @cmd = 'del ' + @std_backup_path2 + '\' + @Hold_filename
						print @cmd
						exec master.sys.xp_cmdshell @cmd


						--  Check to make sure files were deleted
						Select @check_backup_path = @std_backup_path + '\' + @Hold_filename
						exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


						If @exists = 1
						   begin
							Print 'DBA Warning:  File delete error after backup processing completed'
							--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
							--Print @cmd
							--exec master.sys.xp_cmdshell @cmd
						   end
					   end
					Else
					   begin
						delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					   end

					Select @tempcount = (select count(*) from #DirectoryTempTable)


				   end
			   end


		   end


		If @DeleteTran = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu13DBName + '_tlog_*.' + rtrim(@BkUpSufx_tlog) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_tlog_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end


		If @DeleteDfntl = 'y'
		   begin
			Delete from #DirectoryTempTable
			select @cmd = 'dir ' + @outpath2 + '\' + @cu13DBName + '_dfntl_*.' + rtrim(@BkUpSufx_dfntl) + ' /B'
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null
			Select @tempcount = (select count(*) from #DirectoryTempTable)
			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


				--  Parse the backup file name to get the date info
				Select @charpos = charindex('_dfntl_', @Hold_filename)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = reverse(@Hold_filename)
					Select @charpos = charindex('_', @Hold_filedate)
					IF @charpos <> 0
					   begin
						Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
					   end
					Select @Hold_filedate = reverse(@Hold_filedate)
				   end


				Select @Hold_filedate = left(@Hold_filedate, 12)


				If left(@date, 12) > @Hold_filedate
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
					print @cmd
					exec master.sys.xp_cmdshell @cmd


					--  Check to make sure files were deleted
					Select @check_backup_path = @outpath + '\' + @Hold_filename
					exec DBAOps.dbo.dbasp_get_file_existence @check_backup_path, @exists output


					If @exists = 1
					   begin
						Print 'DBA Warning:  File delete error after backup processing complete'
						--Select @cmd = 'handle /accepteula -u ' + @std_backup_path
						--Print @cmd
						--exec master.sys.xp_cmdshell @cmd
					   end
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end

				Select @tempcount = (select count(*) from #DirectoryTempTable)


			   end
		   end


		--  Create a differential
		If @auto_diff = 'y'
		   begin
			exec DBAOps.dbo.dbasp_Backup_Differential @DBName = @cu13DBName
								,@BkUpPath = @BkUpPath
								,@RedGate_Bypass = @RedGate_Bypass
								,@Compress_Bypass = @Compress_Bypass
								,@process_mode = @process_mode
								,@skip_vss = 'y'
		   end


		--  check for more rows to process
		delete from @DBnames2 where dbid = @cu13DBId
		If (select count(*) from @DBnames2) > 0
		   begin
			goto start_dbnames2c
		   end


	   end


	--  delete before system DB backups
	If @DeletePrevious = 'before'
	   begin
		Select @cmd = 'del ' + @outpath2 + '\master_' + @backup_type + '_*.bak'
		Print ' '
		Print 'The following delete command will be used.'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd


		Select @cmd = 'del ' + @outpath2 + '\model_' + @backup_type + '_*.bak'
		Print ' '
		Print 'The following delete command will be used.'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd


		Select @cmd = 'del ' + @outpath2 + '\msdb_' + @backup_type + '_*.bak'
		Print ' '
		Print 'The following delete command will be used.'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd
	   end


	Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
	Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


	Select @BkUpFile = rtrim(@outpath) + '\master_' + rtrim(@backup_type) + '_' + rtrim(@date) + '.bak'
	Print 'Output file will be: ' + @BkUpFile

	Select @cmd = 'Backup database [master] to disk = ''' + @BkUpFile + ''' with init'
	If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = 'master' and page_verify_option = 2)
	   begin
		Select @cmd = @cmd + ', CHECKSUM'
	   end
	Print @cmd
	Print ' '
	Exec (@cmd)


	If (@@error <> 0 or @retcode <> 0)
	   begin
		Print 'DBA Error:  DB Backup Failure for command ' + @cmd
		Print '--***********************************************************'
		Print '@@error or @retcode is not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  Log the backup info
	If @backup_log_flag = 'y'
	   begin
		Select @BkUpFilename = 'master_' + rtrim(@backup_type) + '_' + @date + '.bak'


		Insert into dbo.backup_log values(getdate(), 'master', @BkUpFilename, @outpath, @process_mode)
	   end


	Select @BkUpFile = rtrim(@outpath) + '\model_' + rtrim(@backup_type) + '_' + rtrim(@date) + '.bak'
	Print 'Output file will be: ' + @BkUpFile

	Select @cmd = 'Backup database [model] to disk = ''' + @BkUpFile + ''' with init'
	If @Checksum = 'y' and exists (select 1 from model.sys.databases where name = 'model' and page_verify_option = 2)
	   begin
		Select @cmd = @cmd + ', CHECKSUM'
	   end
	Print @cmd
	Print ' '
	Exec (@cmd)


	If (@@error <> 0 or @retcode <> 0)
	   begin
		Print 'DBA Error:  DB Backup Failure for command ' + @cmd
		Print '--***********************************************************'
		Print '@@error or @retcode is not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  Log the backup info
	If @backup_log_flag = 'y'
	   begin
		Select @BkUpFilename = 'model_' + rtrim(@backup_type) + '_' + @date + '.bak'


		Insert into dbo.backup_log values(getdate(), 'model', @BkUpFilename, @outpath, @process_mode)
	   end


	Select @BkUpFile = rtrim(@outpath) + '\msdb_' + rtrim(@backup_type) + '_' + rtrim(@date) + '.bak'
	Print 'Output file will be: ' + @BkUpFile

	Select @cmd = 'Backup database [msdb] to disk = ''' + @BkUpFile + ''' with init'
	If @Checksum = 'y' and exists (select 1 from msdb.sys.databases where name = 'msdb' and page_verify_option = 2)
	   begin
		Select @cmd = @cmd + ', CHECKSUM'
	   end
	Print @cmd
	Print ' '
	Exec (@cmd)


	If (@@error <> 0 or @retcode <> 0)
	   begin
		Print 'DBA Error:  DB Backup Failure for command ' + @cmd
		Print '--***********************************************************'
		Print '@@error or @retcode is not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  Log the backup info
	If @backup_log_flag = 'y'
	   begin
		Select @BkUpFilename = 'msdb_' + rtrim(@backup_type) + '_' + @date + '.bak'


		Insert into dbo.backup_log values(getdate(), 'msdb', @BkUpFilename, @outpath, @process_mode)
	   end


	If @DeletePrevious in ('before', 'after')
	   begin
		Delete from #DirectoryTempTable
		select @cmd = 'dir ' + @outpath2 + '\master_' + @backup_type + '_*.bak /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		select @cmd = 'dir ' + @outpath2 + '\model_' + @backup_type + '_*.bak /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		select @cmd = 'dir ' + @outpath2 + '\msdb_' + @backup_type + '_*.bak /B'
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null


		Select @tempcount = (select count(*) from #DirectoryTempTable)
		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


			--  Parse the backup file name to get the date info
			Select @charpos = charindex('_' + @backup_type + '_', @Hold_filename)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = reverse(@Hold_filename)
				Select @charpos = charindex('_', @Hold_filedate)
				IF @charpos <> 0
				   begin
					Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
				   end
				Select @Hold_filedate = reverse(@Hold_filedate)
			   end


			Select @Hold_filedate = left(@Hold_filedate, 12)


			If left(@date, 12) > @Hold_filedate
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @outpath2 + '\' + @Hold_filename
				print @cmd
				exec master.sys.xp_cmdshell @cmd
			   end
			Else
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
			   end

			Select @tempcount = (select count(*) from #DirectoryTempTable)


		   end
	   end


   end


--  End Processing  ---------------------------------------------------------------------------------------------

Label99:


--  If InMage and Redgate, disable and stop VSS
If @VSS_flag = 'y'
   begin
	print 'Starting VSS'
	select @cmd = 'sc config "VSS" start= demand'
	Print @cmd
	exec master.sys.xp_cmdshell @cmd
	select @cmd = 'net start VSS'
	Print @cmd
	exec master.sys.xp_cmdshell @cmd
   end


drop table #DirectoryTempTable
drop table #fileexists
drop table #resultstring
drop table #temp_tbl2
drop table #ReadSqlLog
drop table #ReadSqlLog2


If @error_count > 0
   begin
	raiserror('dbasp_BackupDBs Failure',16,-1) with log
	return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupDBs] TO [public]
GO
