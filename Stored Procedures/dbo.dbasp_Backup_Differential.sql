SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Differential] (@PlanName varchar(500) = null
					,@DBName sysname = null
					,@backup_name sysname = null
					,@BkUpPath varchar(255) = null
					,@BkUpExt varchar(10) = null
					,@DeletePrevious varchar(10) = 'after'
					,@DeleteDfntl char(1) = 'y'
					,@RedGate_Bypass char(1) = 'n'
					,@threads smallint = 3
					,@compressionlevel smallint = 1
					,@maxtransfersize bigint = 1048576
					,@compress_Bypass char(1) = 'n'
					,@Checksum char(1) = 'y'
					,@process_mode sysname = 'normal'
					,@skip_vss char(1) = 'y')

/***************************************************************
 **  Stored Procedure dbasp_Backup_Differential
 **  Written by Steve Ledridge, Virtuoso
 **  June 11, 2004
 **
 **  This proc accepts the following input parms (none are required):
 **  @PlanName         - name of the maintenance plan that will specify
 **                      the list of databases to process.
 **
 **  @DBName           - name of the single database that will be processed.
 **
 **  @backup_name      - Force this name for the backup file. (optional)
 **
 **  @BkUpPath         - Full path where the backup files should be
 **                      written to.
 **
 **  @BkUpExt          - Extension for the backup file (e.g. 'DIF').
 **
 **  @DeletePrevious   - ('before', 'after' or 'none') indicates when you
 **                      want to delete the previous backup file(s).
 **
 **  @DeleteDfntl      - (y or n) Delete all previous differentials.
 **
 **  @RedGate_Bypass   - (y or n) indicates if you want to bypass
 **                      RedGate processing.
 **
 **  @compress_Bypass  - (y or n) indicates if you want to bypass compression.
 **
 **  @Checksum         - (y or n) set the checksum option for the backup process.
 **
 **  @process_mode     - (normal, pre_release, pre_calc, mid_calc)
 **                      is for special processing where the backup file is
 **                      written to a sub folder of the backup share and
 **                      the backup info is logged in the backup_log table.
 **
 **  @skip_vss        - (y or n) skip the VSS stop and start process.
 **
 **  If no input parameters are given, all user DB's will be processed.
 **  The resulting differential backup files will be written to the
 **  standard backup share location.
 **
 **  Will delete \pre_release backups if > three days old.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/11/2004	Steve Ledridge		New process
--	07/07/2004	Steve Ledridge		Modify delete old backup process
--	08/18/2005	Steve Ledridge		Added processing for LiteSpeed.  Also added option
--						delete for previous differentials.
--	08/19/2005	Steve Ledridge		Added code for LiteSpeed bypass.
--	10/27/2005	Steve Ledridge		Added input parm @DeletePrevious.
--	12/07/2005	Steve Ledridge		Changed Litespeed logging to '0'.
--	02/16/2006	Steve Ledridge		Modified for sql 2005
--	03/27/2006	Steve Ledridge		Added LiteSpeed input parms.
--	07/27/2006	Steve Ledridge		Chaged conversion of @maxtransfersize to varchar(10)
--	11/28/2006	Steve Ledridge		Added input parm @backup_name.
--	05/03/2007	Steve Ledridge		Fixed for paths with imbedded spaces.
--	07/24/2007	Steve Ledridge		Added RedGate processing.
--	10/16/2008	Steve Ledridge		Added pre_release input parm.
--	10/21/2008	Steve Ledridge		Added @process_mode input parm.
--	03/06/2009	Anne Moss		Added section to delete pre_release files
--	03/12/2009	Steve Ledridge		Fixed bug in pre_release delete (path)
--	04/14/2009	Steve Ledridge		Update error check process for RG.
--	06/05/2009	Steve Ledridge		Added display of result temp table for redgate errors.
--	12/01/2009	Steve Ledridge		Updated error handeling.
--	04/05/2011	Steve Ledridge		Added compression for sql2008 R2.
--	11/16/2011	Steve Ledridge		Updated check for SQL compression.
--	04/27/2012	Steve Ledridge		Lookup backup path from local_serverenviro.
--	08/09/2012	Steve Ledridge		Added Checksum.
--	08/27/2012	Steve Ledridge		Stop and start VSS if InMage and Redgate are active.
--	10/12/2012	Steve Ledridge		New wait for inmage sync process.
--	12/28/2012	Steve Ledridge		Added check for full backup.  Removed Lightspeed.
--	======================================================================================


/***
Declare @PlanName varchar(500)
Declare @DBName sysname
Declare @backup_name sysname
Declare @BkUpPath varchar(1000)
Declare @BkUpExt varchar(10)
Declare @DeletePrevious varchar(10)
Declare @DeleteDfntl char(1)
Declare @RedGate_Bypass char(1)
Declare @threads smallint
Declare @compressionlevel smallint
Declare @maxtransfersize int
Declare @compress_Bypass char(1)
Declare @Checksum char(1)
Declare @process_mode sysname
Declare @skip_vss char(1)


Select @PlanName = 'Mplan_user_full'
--Select @DBName = 'Runbook'
--Select @backup_name = 'DBAOps_dfntl_test01'
--Select @BkUpPath = '\\SEAFRERYLGINS02\SEAFRERYLGINS02_backup\SEAFRERYLSQL02'
Select @BkUpExt = null
Select @DeletePrevious = 'before'
Select @DeleteDfntl = 'y'
Select @RedGate_Bypass = 'n'
Select @threads = 3
Select @compressionlevel = 1
Select @maxtransfersize = 1048576
Select @compress_Bypass = 'n'
Select @Checksum = 'y'
Select @process_mode = 'normal'
Select @skip_vss = 'n'
--***/


Declare
	 @miscprint		varchar(500)
	,@BkUpFile 		varchar(500)
	,@BkUpDateStmp 		char(14)
	,@Hold_hhmmss		varchar(8)
	,@Hold_filename		varchar(500)
	,@Hold_filedate		sysname
	,@cursor_text		varchar(500)
	,@cmd			nvarchar(2000)
	,@cmd2			nvarchar(2000)
	,@tempcount		int
	,@parm01		varchar(100)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_BkUpExt		varchar(10)
	,@charpos		int
	,@error_count		int
	,@plan_flag		char(1)
	,@db_flag		char(1)
	,@backup_log_flag	nchar(1)
	,@BkUpMethod		nvarchar(5)
	,@BkUpPath2		varchar(255)
	,@fileexist_path	nvarchar(255)
	,@BkUpFilename		sysname
	,@delete_flag		char (1)
	,@Pre_Release_Save_Days int
	,@Retention_filedate	varchar(14)
	,@VSS_flag		nchar(1)
	,@InMage_try		smallint
	,@a			datetime
	,@b			datetime


DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu12DBName		sysname


----------------  initial values  -------------------
Set @error_count = 0
Select @plan_flag = 'n'
Select @db_flag = 'n'
Select @backup_log_flag = 'n'
Select @VSS_flag = 'n'


If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'RedGate')
   and @RedGate_Bypass = 'n'
   and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'RG'
	Set @save_BkUpExt = 'SQD'
   end
Else If (select @@version) not like '%Server 2005%'
  and ((select SERVERPROPERTY ('productversion')) > '10.50.0000' or (select @@version) like '%Enterprise Edition%')
  and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'MSc'
	Set @save_BkUpExt = 'cDIF'
   end
Else
   begin
	Set @BkUpMethod = 'MS'
	Set @save_BkUpExt = 'DIF'
   end


If @BkUpExt is null or @BkUpExt = ''
   begin
	Set @BkUpExt = @save_BkUpExt
   end


--  Set the backup name extension if not specified with the input backup name.
If @backup_name is not null
   begin
	Select @charpos = charindex('.', @backup_name)
	IF @charpos = 0
	   begin
		Select @backup_name = @backup_name + '.' + rtrim(@BkUpExt)
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


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Check input parameters
If @PlanName is not null and @PlanName <> ''
   begin
	Select @plan_flag = 'y'
	If not exists (select * from msdb.dbo.sysdbmaintplans Where plan_name = @PlanName)
	   begin
		raiserror('DBA WARNING: Invaild parameter passed to dbasp_backup_differential - @PlanName parm is invalid',-1,-1)
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @process_mode not in ('normal', 'pre_release', 'pre_calc', 'mid_calc')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @process_mode parm must be ''normal'', ''pre_release'', ''pre_calc'' or ''mid_calc''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @DBName is not null and @DBName <> ''
   begin
	Select @db_flag = 'y'
	If not exists (select * from master.sys.sysdatabases Where name = @DBName)
	   begin
		raiserror('DBA WARNING: Invaild parameter passed to dbasp_backup_differential - @DBName parm is invalid',-1,-1)
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @plan_flag = 'y' and @db_flag = 'n' and @backup_name is not null
   begin
	raiserror('DBA Warning:  Invalid input parameters.  A specific backup name can only be set for a single DB backup.',-1,-1)
	Select @error_count = @error_count + 1
	Goto label99
   end


--  If InMage and Redgate, disable and stop VSS
If @BkUpMethod = 'RG' and @skip_vss = 'n'
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
		raiserror('', -1,-1) with nowait
		exec master.sys.xp_cmdshell @cmd
	   end
   end


If @BkUpPath is null or @BkUpPath = ''
   begin
	Select @parm01 = @save_servername2 + '_backup'
	If exists (select 1 from dbo.local_serverenviro where env_type = 'backup_path')
	   begin
		Select @BkUpPath = (select top 1 env_detail from dbo.local_serverenviro where env_type = 'backup_path')
	   end
	Else
	   begin
		--exec DBAOps.dbo.dbasp_get_share_path @parm01, @BkUpPath output
		SET @BkUpPath = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)
	   end


	If @process_mode = 'pre_release'
	   begin
		--  check to see if the @pre_release folder exists (create it if needed)
		Delete from #fileexists
		Select @fileexist_path = @BkUpPath  + '\pre_release'
		Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
		If (select fileindir from #fileexists) <> 1
		   begin
			Select @cmd = 'mkdir "' + @BkUpPath + '\pre_release"'
			Print 'Creating pre_release folder using command '+ @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end


		--  set @BkUpPath
		Select @BkUpPath = @BkUpPath + '\pre_release'
	   end
	Else If @process_mode = 'pre_calc'
	   begin
		--  check to see if the @pre_calc folder exists (create it if needed)
		Delete from #fileexists
		Select @fileexist_path = @BkUpPath  + '\pre_calc'
		Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
		If (select fileindir from #fileexists) <> 1
		   begin
			Select @cmd = 'mkdir "' + @BkUpPath + '\pre_calc"'
			Print 'Creating pre_calc folder using command '+ @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end


		--  set @BkUpPath
		Select @BkUpPath = @BkUpPath + '\pre_calc'
	   end
	Else If @process_mode = 'mid_calc'
	   begin
		--  check to see if the @mid_calc folder exists (create it if needed)
		Delete from #fileexists
		Select @fileexist_path = @BkUpPath  + '\mid_calc'
		Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
		If (select fileindir from #fileexists) <> 1
		   begin
			Select @cmd = 'mkdir "' + @BkUpPath + '\mid_calc"'
			Print 'Creating mid_calc folder using command '+ @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end


		--  set @BkUpPath
		Select @BkUpPath = @BkUpPath + '\mid_calc'
	   end


   end


--  Set logging flag
If @process_mode in ('pre_release', 'pre_calc', 'mid_calc')
   begin
	select @backup_log_flag = 'y'
   end


--  Do not delete old differentials for mid_calc processing
If @process_mode = 'mid_calc'
   begin
	Select @DeleteDfntl = 'n'
   end


Print 'Backup output path is ' + @BkUpPath


Select @charpos = charindex(' ', @BkUpPath)
IF @charpos <> 0
   begin
	Select @BkUpPath2 = '"' + @BkUpPath + '"'
   end
Else
   begin
	Select @BkUpPath2 = @BkUpPath
   end


/****************************************************************
 *                MainLine
 ***************************************************************/
If @db_flag = 'y'
   begin
	If @backup_name is not null
	   begin
		Select @BkUpFile = @BkUpPath + '\' + rtrim(@backup_name)
		print 'Output file will be: ' + @BkUpFile
	   end
	Else
	   begin
		Select @BkUpFile = @BkUpPath + '\' + rtrim(@DBName) + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt
		print 'Output file will be: ' + @BkUpFile
	   end


	--  Check for full backup
	If not exists (SELECT 1 FROM msdb.dbo.backupset
					WHERE database_name = @DBName
					AND backup_finish_date IS NOT NULL
					AND type IN ('D', 'F'))
	   begin
		print 'No full backup exists for database ' + rtrim(@DBName)
		print 'exec DBAOps.dbo.dbasp_BackupDBs @DBname = ''' + rtrim(@DBName) + ''', @auto_diff = ''n'''
		exec DBAOps.dbo.dbasp_BackupDBs @DBname = @DBName, @auto_diff = 'n'
	   end


	--  Process to delete old dfntl backup files (before) -------------------
	If @DeleteDfntl = 'y' and @DeletePrevious <> 'after'
	   begin
		Print 'Starting Delete Processing'
		select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@DBName) + '_dfntl_*.' + @BkUpExt + ' /B'
		RAISERROR('', -1,-1) WITH NOWAIT

		Delete from #DirectoryTempTable
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null


		Select @tempcount = (select count(*) from #DirectoryTempTable)

		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


			Select @Hold_filedate = left(@Hold_filedate, 14)


			If @Hold_filedate < @BkUpDateStmp
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
				Print @cmd
				exec master.sys.xp_cmdshell @cmd
			   end
			Else
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
			   end


			Select @tempcount = (select count(*) from #DirectoryTempTable)
		   end
	   end


	--  Process the differential backup
	If @BkUpMethod = 'RG'
	   begin
		Select @cmd = 'master.dbo.sqlbackup'


		Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@DBName) + ']'
				+ ' TO DISK = ''' + rtrim(@BkUpFile)
				+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
				+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
				+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
				+ ', SINGLERESULTSET'
				+ ', DIFFERENTIAL'


		If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @DBName and page_verify_option = 2)
		   begin
		    Select @cmd2 = @cmd2 + ', CHECKSUM'
		   end
		Select @cmd2 = @cmd2 + '"'
	   end
	Else
	   begin
		Select @cmd = 'Backup database [' + rtrim(@DBName) + '] to disk = ''' + @BkUpFile + ''' with DIFFERENTIAL, init'
		If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @DBName and page_verify_option = 2)
		   begin
			Select @cmd = @cmd + ', CHECKSUM'
		   end
		If @BkUpMethod = 'MSc'
		   begin
			Select @cmd = @cmd + ', COMPRESSION'
		   end
	   end


	If @BkUpMethod <> 'RG'
	   begin
		Print @cmd
		Print ' '
		RAISERROR('', -1,-1) WITH NOWAIT
		Exec(@cmd)
	   end
	Else
	   begin
		Print @cmd
		Print @cmd2
		Print ' '
		RAISERROR('', -1,-1) WITH NOWAIT
		delete from #resultstring
		Insert into #resultstring exec @cmd @cmd2
		--select * from #resultstring
	   end


	If @@error<> 0 and @BkUpMethod <> 'RG'
	   begin
		Print 'DBA Error:  Differential Backup Failure for command ' + @cmd
		Print '--***********************************************************'
		Print '@@error or @retcode was not zero'
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end
	Else If exists (select 1 from #resultstring where message like '%error%')
	   begin
		Print 'DBA Error:  Differential Backup (RG) Failure for command ' + @cmd + @cmd2
		Print '--***********************************************************'
		Select * from #resultstring
		Print '--***********************************************************'
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  Log the backup info
	If @backup_log_flag = 'y'
	   begin
		Select @BkUpFilename =  rtrim(@DBName) + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt


		Insert into dbo.backup_log values(getdate(), @DBName, @BkUpFilename, @BkUpPath, @process_mode)
	   end


	--  Process to delete old dfntl backup files  -------------------
	If @DeleteDfntl = 'y' and @DeletePrevious = 'after'
	   begin
		Print 'Starting Delete Processing'
		select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@DBName) + '_dfntl_*.' + @BkUpExt + ' /B'

		Delete from #DirectoryTempTable
		insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
		Delete from #DirectoryTempTable where cmdoutput is null


		Select @tempcount = (select count(*) from #DirectoryTempTable)

		While (@tempcount > 0)
		   begin
			Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


			Select @Hold_filedate = left(@Hold_filedate, 14)


			If @Hold_filedate < @BkUpDateStmp
			   begin
				delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
				Print @cmd
				RAISERROR('', -1,-1) WITH NOWAIT
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
Else If @plan_flag = 'y'
   begin
	--  Process for a supplied maintenance plan
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


		Select @cu11DBName = (select top 1 name from @DBnames order by name)


		Select @BkUpFile = @BkUpPath + '\' + @cu11DBName + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt
		Print 'Output file will be: ' + @BkUpFile


		--  Check for full backup
		If not exists (SELECT 1 FROM msdb.dbo.backupset
						WHERE database_name = @cu11DBName
						AND backup_finish_date IS NOT NULL
						AND type IN ('D', 'F'))
		   begin
			print 'No full backup exists for database ' + rtrim(@cu11DBName)
			print 'exec DBAOps.dbo.dbasp_BackupDBs @DBname = ''' + rtrim(@cu11DBName) + ''', @auto_diff = ''n'''
			exec DBAOps.dbo.dbasp_BackupDBs @DBname = @cu11DBName, @auto_diff = 'n'
		   end


		--  Process to delete old dfntl backup files (before) -------------------
		If @DeleteDfntl = 'y' and @DeletePrevious <> 'after'
		   begin
			Print 'Starting Delete Processing'
			select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@cu11DBName) + '_dfntl_*.' + @BkUpExt + ' /B'
			RAISERROR('', -1,-1) WITH NOWAIT

			Delete from #DirectoryTempTable
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null


			Select @tempcount = (select count(*) from #DirectoryTempTable)

			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


				Select @Hold_filedate = left(@Hold_filedate, 14)


				If @Hold_filedate < @BkUpDateStmp
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
					Print @cmd
					exec master.sys.xp_cmdshell @cmd
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end


				Select @tempcount = (select count(*) from #DirectoryTempTable)
			   end
		   end


		--  Process the differential backup
		If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'


			Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu11DBName) + ']'
					+ ' TO DISK = ''' + rtrim(@BkUpFile)
					+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
					+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
					+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
					+ ', SINGLERESULTSET'
					+ ', DIFFERENTIAL'


			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 2)
			   begin
				Select @cmd2 = @cmd2 + ', CHECKSUM'
			   end
			Select @cmd2 = @cmd2 + '"'
		   end
		Else
		   begin
			Select @cmd = 'Backup database [' + rtrim(@cu11DBName) + '] to disk = ''' + @BkUpFile + ''' with DIFFERENTIAL, init'
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ', COMPRESSION'
			   end
		   end


		If @BkUpMethod <> 'RG'
		   begin
			Print @cmd
			Print ' '
			RAISERROR('', -1,-1) WITH NOWAIT
			Exec(@cmd)
		   end
		Else
		   begin
			Print @cmd
			Print @cmd2
			Print ' '
			RAISERROR('', -1,-1) WITH NOWAIT
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			--select * from #resultstring
		   end


		If @@error<> 0 and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Warning:  Differential Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode was not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  Differential Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename =  rtrim(@cu11DBName) + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt

			Insert into dbo.backup_log values(getdate(), @cu11DBName, @BkUpFilename, @BkUpPath, @process_mode)
		   end


		--  Process to delete old dfntl backup files  -------------------
		If @DeleteDfntl = 'y' and @DeletePrevious = 'after'
		   begin
			Print 'Starting Delete Processing'
			select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@cu11DBName) + '_dfntl_*.' + @BkUpExt + ' /B'

			Delete from #DirectoryTempTable
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null


			Select @tempcount = (select count(*) from #DirectoryTempTable)

			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


				Select @Hold_filedate = left(@Hold_filedate, 14)


				If @Hold_filedate < @BkUpDateStmp
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
					Print @cmd
					RAISERROR('', -1,-1) WITH NOWAIT
					exec master.sys.xp_cmdshell @cmd
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end


				Select @tempcount = (select count(*) from #DirectoryTempTable)
			   end
		   end


		--  check for more rows to process
		Delete from @DBnames where name = @cu11DBName
		If (select count(*) from @DBnames) > 0
		   begin
			goto start_dbnames
		   end


	   end


   end
Else
   begin
	--  Process for all user databases
	Select @cmd = 'SELECT d.name
	   From master.sys.sysdatabases   d ' +
	  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


	delete from @DBnames


	insert into @DBnames (name) exec (@cmd)


	delete from @DBnames where name is null or name = ''
	--select * from @DBnames


	If (select count(*) from @DBnames) > 0
	   begin
		start_dbnames12:


		Select @cu12DBName = (select top 1 name from @DBnames order by name)


		Select @BkUpFile = @BkUpPath + '\' + @cu12DBName + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt
		Print 'Output file will be: ' + @BkUpFile


		--  Check for full backup
		If not exists (SELECT 1 FROM msdb.dbo.backupset
						WHERE database_name = @cu12DBName
						AND backup_finish_date IS NOT NULL
						AND type IN ('D', 'F'))
		   begin
			print 'No full backup exists for database ' + rtrim(@cu12DBName)
			print 'exec DBAOps.dbo.dbasp_BackupDBs @DBname = ''' + rtrim(@cu12DBName) + ''', @auto_diff = ''n'''
			exec DBAOps.dbo.dbasp_BackupDBs @DBname = @cu12DBName, @auto_diff = 'n'
		   end


		--  Process to delete old dfntl backup files (before) -------------------
		If @DeleteDfntl = 'y' and @DeletePrevious <> 'after'
		   begin
			Print 'Starting Delete Processing'
			select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@cu12DBName) + '_dfntl_*.' + @BkUpExt + ' /B'
			RAISERROR('', -1,-1) WITH NOWAIT

			Delete from #DirectoryTempTable
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null


			Select @tempcount = (select count(*) from #DirectoryTempTable)

			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


				Select @Hold_filedate = left(@Hold_filedate, 14)


				If @Hold_filedate < @BkUpDateStmp
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
					Print @cmd
					exec master.sys.xp_cmdshell @cmd
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end


				Select @tempcount = (select count(*) from #DirectoryTempTable)
			   end
		   end


		--  Process the differential backup
		If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'


			Select @cmd2 = '-SQL "BACKUP DATABASE [' + rtrim(@cu12DBName) + ']'
					+ ' TO DISK = ''' + rtrim(@BkUpFile)
					+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
					+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
					+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
					+ ', SINGLERESULTSET'
					+ ', DIFFERENTIAL'


			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu12DBName and page_verify_option = 2)
			   begin
				Select @cmd2 = @cmd2 + ', CHECKSUM'
			   end
			Select @cmd2 = @cmd2 + '"'
		   end
		Else
		   begin
			Select @cmd = 'Backup database [' + rtrim(@cu12DBName) + '] to disk = ''' + @BkUpFile + ''' with DIFFERENTIAL, init'
			If @Checksum = 'y' and exists (select 1 from master.sys.databases where name = @cu12DBName and page_verify_option = 2)
			   begin
				Select @cmd = @cmd + ', CHECKSUM'
			   end
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ', COMPRESSION'
			   end
		   end


		If @BkUpMethod <> 'RG'
		   begin
			Print @cmd
			Print ' '
			RAISERROR('', -1,-1) WITH NOWAIT
			Exec(@cmd)
		   end
		Else
		   begin
			Print @cmd
			Print @cmd2
			Print ' '
			RAISERROR('', -1,-1) WITH NOWAIT
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			--select * from #resultstring
		   end


		If @@error<> 0 and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Error:  Differential Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode was not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  Differential Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Log the backup info
		If @backup_log_flag = 'y'
		   begin
			Select @BkUpFilename =  rtrim(@cu12DBName) + '_dfntl_' + @BkUpDateStmp + '.' + @BkUpExt

			Insert into dbo.backup_log values(getdate(), @cu12DBName, @BkUpFilename, @BkUpPath, @process_mode)
		   end


		--  Process to delete old dfntl backup files  -------------------
		If @DeleteDfntl = 'y' and @DeletePrevious = 'after'
		   begin
			Print 'Starting Delete Processing'
			select @cmd = 'dir ' + @BkUpPath2 + '\' + rtrim(@cu12DBName) + '_dfntl_*.' + @BkUpExt + ' /B'

			Delete from #DirectoryTempTable
			insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
			Delete from #DirectoryTempTable where cmdoutput is null


			Select @tempcount = (select count(*) from #DirectoryTempTable)

			While (@tempcount > 0)
			   begin
				Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)

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


				Select @Hold_filedate = left(@Hold_filedate, 14)


				If @Hold_filedate < @BkUpDateStmp
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
					select @cmd = 'del ' + @BkUpPath2 + '\' + @Hold_filename
					Print @cmd
					RAISERROR('', -1,-1) WITH NOWAIT
					exec master.sys.xp_cmdshell @cmd
				   end
				Else
				   begin
					delete from #DirectoryTempTable where cmdoutput = @Hold_filename
				   end


				Select @tempcount = (select count(*) from #DirectoryTempTable)
			   end
		   end


		--  check for more rows to process
		Delete from @DBnames where name = @cu12DBName
		If (select count(*) from @DBnames) > 0
		   begin
			goto start_dbnames12
		   end
	   end
   end


--  Process to delete old pre release related backup files  -------------------
Print 'Start Delete Old Pre Release Backups Processing'


Set @Pre_Release_Save_Days = 3


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @Retention_filedate = convert(char(8), getdate()-@Pre_Release_Save_Days, 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


select @cmd = 'dir ' + @BkUpPath + '\pre_release\*.* /B'
print @cmd
RAISERROR('', -1,-1) WITH NOWAIT


Delete from #DirectoryTempTable
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
Delete from #DirectoryTempTable where cmdoutput is null
Select @tempcount = (select count(*) from #DirectoryTempTable)


While (@tempcount > 0)
   begin
	Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)
	Select @delete_flag = 'n'


	Select @charpos = charindex('_db_', @Hold_filename)
	IF @charpos <> 0
	   begin
 		Select @delete_flag = 'y'
		Select @Hold_filedate = reverse(@Hold_filename)
		Select @charpos = charindex('_', @Hold_filedate)
		IF @charpos <> 0
		   begin
			Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
		   end
		Select @Hold_filedate = reverse(@Hold_filedate)


		Select @Hold_filedate = left(@Hold_filedate, 14)
	   end


	Select @charpos = charindex('_dfntl_', @Hold_filename)
	IF @charpos <> 0
	   begin
		Select @delete_flag = 'y'
		Select @Hold_filedate = reverse(@Hold_filename)
		Select @charpos = charindex('_', @Hold_filedate)
		IF @charpos <> 0
		   begin
			Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
		   end
		Select @Hold_filedate = reverse(@Hold_filedate)


		Select @Hold_filedate = left(@Hold_filedate, 14)
	   end


	If @Retention_filedate > @Hold_filedate and @delete_flag = 'y'
	   begin
		select @cmd = 'del ' + @BkUpPath + '\pre_release\' + @Hold_filename
		Print @cmd
		RAISERROR('', -1,-1) WITH NOWAIT
		Exec master.sys.xp_cmdshell @cmd
	   end

	delete from #DirectoryTempTable where cmdoutput = @Hold_filename
	Select @tempcount = (select count(*) from #DirectoryTempTable)


   end


--  End Processing  ---------------------------------------------------------------------------------------------

Label99:


--  If InMage and Redgate, disable and stop VSS
If @VSS_flag = 'y'
   begin
   	print 'Starting VSS'
   	RAISERROR('', -1,-1) WITH NOWAIT
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
	raiserror('dbasp_Backup_Differential Failure',16,-1) with log
	return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Differential] TO [public]
GO
