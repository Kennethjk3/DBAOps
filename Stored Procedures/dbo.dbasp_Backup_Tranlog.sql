SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Tranlog] (@PlanName varchar(500) = null
					,@DBName sysname = null
					,@BkUpPath varchar(255) = null
					,@BkUpExt varchar(10) = null
					,@RedGate_Bypass char(1) = 'n'
					,@threads smallint = 3
					,@compressionlevel smallint = 1
					,@maxtransfersize bigint = 1048576
					,@compress_Bypass char(1) = 'n'
					)

/***************************************************************
 **  Stored Procedure dbasp_Backup_Tranlog
 **  Written by Steve Ledridge, Virtuoso
 **  March 22, 2002
 **
 **  This proc accepts the following input parms (none are required):
 **  @PlanName      - name of the maintenance plan that will specify
 **                   the list of databases to process.
 **  @DBName        - name of the single database that will be processed.
 **  @BkUpPath      - Full path where the backup files should be
 **                   written to.
 **  @BkUpExt       - Extension for the backup file (e.g. 'TRN').
 **  @RedGate_Bypass - (y or n) indicates if you want to bypass
 **                    RedGate processing.
 **  @compress_Bypass - (y or n) indicates if you want to bypass compression.
 **
 **  If no input parameters are given, all user DB's with the Recovery
 **  model set to 'full' will be processed.  The resulting transaction
 **  log backup file will be written to the standard backup share location.
 **
 **  This procedure will run post tranlog process (via data in the local_control table).
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	07/29/2002	Steve Ledridge		Added code to delete older backup files.
--	02/04/2004	Steve Ledridge		New process for a single DB or all DB's.
--	08/12/2004	Steve Ledridge		Added verification of backup file.
--	08/18/2005	Steve Ledridge		Added code for LiteSpeed backup processing.
--	08/19/2005	Steve Ledridge		Added code for LiteSpeed bypass.
--	09/19/2005	Steve Ledridge		Fixed trailing single quote for normal sql backup processing.
--	12/07/2005	Steve Ledridge		Changed Litespeed logging to '0'.
--	02/16/2006	Steve Ledridge		Modified for sql 2005
--	03/27/2006	Steve Ledridge		Added LiteSpeed input parms.
--	07/27/2006	Steve Ledridge		Chaged conversion of @maxtransfersize to varchar(10)
--	05/03/2007	Steve Ledridge		Fixed for paths with imbedded spaces.
--	07/24/2007	Steve Ledridge		Added RedGate processing.
--	09/21/2007	Steve Ledridge		Added Restore script process.
--	02/06/2008	Steve Ledridge		Added error checking (@retcode).
--	02/13/2008	Steve Ledridge		Fixed error checking for litespeed.
--	04/17/2008	Steve Ledridge		Fixed error in single DB redgate syntax.
--	03/06/2009	Anne Moss		Added section to delete pre_release files
--	03/12/2009	Steve Ledridge		Fixed bug in pre_release delete (path)
--	04/14/2009	Steve Ledridge		Update error check process for RG.
--	12/01/2009	Steve Ledridge		Updated error handeling.
--	04/07/2010	Steve Ledridge		Added post tranlog backup process from local_control table.
--	12/07/2010	Steve Ledridge		Fixed delete old file process.
--	04/05/2011	Steve Ledridge		Added compression for sql2008 R2.
--	11/16/2011	Steve Ledridge		Updated check for SQL compression.
--	04/27/2012	Steve Ledridge		Lookup backup path from local_serverenviro.
--	07/05/2012	Steve Ledridge		Modified RG Backup to look for CopyTo Property on Each database
--						Then Use that Property to support Delivery of the Log for a LogShiped DB
--	09/14/2012	Steve Ledridge		Added wait for InMage code.
--	11/20/2012	Steve Ledridge		Remove Tranlog backup cleanup process. Removed Litespeed.
--	12/26/2012	Steve Ledridge		Added check to skip backup if DB is a Logshipping Primary DB.
--	02/12/2013	Steve Ledridge		Added the logship check to other section of this sproc.
--	======================================================================================


/***
Declare @PlanName varchar(500)
Declare @DBName sysname
Declare @BkUpPath varchar(255)
Declare @BkUpExt varchar(10)
Declare @BkUpSaveDays int
Declare @RedGate_Bypass char(1)
Declare @threads smallint
Declare @compressionlevel smallint
Declare @maxtransfersize bigint
Declare @compress_Bypass char(1)


Select @PlanName = 'mplan_user_tranlog'
--Select @DBName = 'ProductCatalog'
Select @BkUpPath = null
Select @BkUpExt = null
Select @BkUpSaveDays = 1
Select @RedGate_Bypass = 'n'
Select @threads = 3
Select @compressionlevel = 1
Select @maxtransfersize = 1048576
Select @compress_Bypass = 'n'
--***/


Declare
	 @miscprint		varchar(500)
	,@BkUpFile 		varchar(500)
	,@BkUpDateStmp 		char(14)
	,@Hold_hhmmss		varchar(8)
	,@Hold_filename		varchar(500)
	,@Hold_filedate		sysname
	,@Retention_filedate	varchar(14)
	,@cursor_text		varchar(500)
	,@cmd 			nvarchar(512)
	,@cmd2			nvarchar(4000)
	,@retcode		int
	,@result		int
	,@tempcount		int
	,@error_count		int
	,@parm01		varchar(100)
	,@save_BkUpExt		varchar(10)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_servername3	sysname
	,@charpos		int
	,@plan_flag		char(1)
	,@db_flag		char(1)
	,@all_flag		char(1)
	,@BkUpMethod		nvarchar(5)
	,@BkUpPath2		varchar(255)
	,@outpath		nvarchar(500)
	,@sqlcmd		nvarchar(500)
	,@max_ls		int
	,@delete_flag		char (1)
	,@InMage_try		smallint
	,@Pre_Release_Save_Days int
	,@a			datetime
	,@b			datetime


DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu12DBName		sysname


DECLARE	@LogShipPaths	TABLE(CopyToPath VarChar(2048))
DECLARE @TSQL			VarChar(8000)
----------------  initial values  -------------------
Set @error_count = 0
Select @plan_flag = 'n'
Select @db_flag = 'n'
Select @all_flag = 'n'
Select @max_ls = @maxtransfersize


If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'RedGate')
   and @RedGate_Bypass = 'n'
   and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'RG'
	Set @save_BkUpExt = 'SQT'
   end
Else If (select @@version) not like '%Server 2005%'
  and ((select SERVERPROPERTY ('productversion')) > '10.50.0000' or (select @@version) like '%Enterprise Edition%')
  and @Compress_Bypass = 'n'
   begin
	Set @BkUpMethod = 'MSc'
	Set @save_BkUpExt = 'cTRN'
   end
Else
   begin
	Set @BkUpMethod = 'MS'
	Set @save_BkUpExt = 'TRN'
   end


If @BkUpExt is null or @BkUpExt = ''
   begin
	Set @BkUpExt = @save_BkUpExt
   end


Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @save_servername3	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


Select @outpath = '\\' + @save_servername + '\DBAArchive\' + @save_servername3 + '_RestoreFull_'


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


declare @post_tranlog table (detail01 sysname)


--  Check input parameters
If @PlanName is not null and @PlanName <> ''
   begin
	Select @plan_flag = 'y'
	Select @db_flag = 'n'
	Select @all_flag = 'n'
	If not exists (select * from msdb.dbo.sysdbmaintplans Where plan_name = @PlanName)
	   begin
		Select @miscprint = 'DBA WARNING: Invaild parameter passed to dbasp_backup_tranlog - @PlanName parm is invalid'
		Print @miscprint
		raiserror(@miscprint,-1,-1)
		Select @error_count = @error_count + 1
		goto label99
	   end
	Else
	 begin
		If exists (select * From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
			Where d.plan_id = s.plan_id
			and s.plan_name = @PlanName
			and d.database_name = 'All User Databases')
		   begin
			Select @plan_flag = 'n'
			Select @all_flag = 'y'
		   end
	   end
   end


If @DBName is not null and @DBName <> ''
   begin
	Select @db_flag = 'y'
	Select @plan_flag = 'n'
	Select @all_flag = 'n'
	If not exists (select * from master.sys.sysdatabases Where name = @DBName)
	   begin
		Select @miscprint = 'DBA WARNING: Invaild parameter passed to dbasp_backup_tranlog - @DBName parm is invalid'
		Print @miscprint
		raiserror(@miscprint,-1,-1)
		Select @error_count = @error_count + 1
		goto label99
	   end


	-------------------------------------------------------------
	-------------------------------------------------------------
	--
	--	IF DATABASE IS LOGSHIPPING PRIMARY DO NOT BACKUP
	--
	-------------------------------------------------------------
	-------------------------------------------------------------


	IF @DBname in (SELECT primary_database from msdb.dbo.log_shipping_primary_databases)
	   begin
		Select @miscprint = 'DBA INFO: Database is a Logshipping Primary, dbasp_backup_tranlog cannot be used to do log backup'
		Print @miscprint
		raiserror(@miscprint,-1,-1)
		goto label99
	   end
   end


If @plan_flag = 'n' and @db_flag = 'n'
   begin
	Select @all_flag = 'y'
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


--  Check for InMage processing
delete from #temp_tbl2
select @cmd = 'sc query'
--print @cmd
insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl2 where text01 is null or text01 = ''
Delete from #temp_tbl2 where text01 not like '%svagents%'
--select * from #temp_tbl2


--  if InMage is active on this sql instance...
If exists (select 1 from #temp_tbl2 where text01 like '%svagents%')
   begin
	--  check the last time the InMage sync was done.  If within the last 12 minutes, start the tranlog backups.
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


		--  If VSS is running, wait 5 minutes
		If (select count(*) from #ReadSqlLog2) <> 0
 		   and exists (select 1 from #temp_tbl2 where text01 like '%running%') and @InMage_try < 3
		   begin
			Print 'Wait 5 minutes for InMage Sync'
			raiserror('', -1,-1) with nowait
			Select @InMage_try = @InMage_try + 1
			Waitfor delay '00:04:58'
			goto InMage_start01
		   end
	   end
   end


/****************************************************************
 *                MainLine
 ***************************************************************/
If @db_flag = 'y'
   begin
	--  Process for a single DB
	If databaseproperty(@DBName, 'IsTrunclog') = 0
	   begin
		Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
		Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2)
					+ substring(@Hold_hhmmss, 7, 2)
		Select @BkUpFile = @BkUpPath + '\' + rtrim(@DBName) + '_tlog_' + @BkUpDateStmp + '.' + @BkUpExt
		Print 'Output file will be: ' + @BkUpFile


		-- GET COPYTO INFO
		DELETE	@LogShipPaths
		SET		@TSQL			= 'USE ['+@DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		--PRINT @TSQL
		INSERT INTO	@LogShipPaths
		EXEC		(@TSQL)
		SELECT		@TSQL = ''
		SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		FROM		@LogShipPaths
		WHERE		nullif(CopyToPath,'') IS NOT NULL


		If @BkUpMethod = 'RG'
		   begin
			Select @cmd = 'master.dbo.sqlbackup'


			Select @cmd2 = '-SQL "BACKUP LOG [' + rtrim(@DBName) + ']'
					+ ' TO DISK = ''' + rtrim(@BkUpFile)
					+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
					+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
					+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
					+ ', SINGLERESULTSET'
					+ isnull(@TSQL,'')
					+ ', VERIFY"'
			Print @cmd
			Print @cmd2
			Print ' '
			delete from #resultstring
			Insert into #resultstring exec @cmd @cmd2
			--select * from #resultstring
		   end
		Else
		   begin
			Select @cmd = 'Backup LOG [' + rtrim(@DBName) + '] to disk = ''' + @BkUpFile + ''''
			If @BkUpMethod = 'MSc'
			   begin
				Select @cmd = @cmd + ' with COMPRESSION'
			   end
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
		   begin
			Print 'DBA Error:  TranLog Backup Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode was not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end
		Else If exists (select 1 from #resultstring where message like '%error%')
		   begin
			Print 'DBA Error:  TranLog Backup (RG) Failure for command ' + @cmd + @cmd2
			Print '--***********************************************************'
			Select * from #resultstring
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Verify TranLog Backup
		If @BkUpMethod <> 'RG'
		   begin
			select @cmd = 'RESTORE VERIFYONLY FROM disk = ''' + @BkUpFile + ''''
			Print @cmd
			Print ' '
			Exec (@cmd)
		   end


		If @@error <> 0 or @retcode <> 0
		   begin
			Print 'DBA Error:  Backup Verification Failure for command ' + @cmd
			Print '--***********************************************************'
			Print '@@error or @retcode was not zero'
			Print '--***********************************************************'
			Select @error_count = @error_count + 1
			goto label99
		   end


		--  Create Restore script
		SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdbRestore_singleDB @dbname = ''' + rtrim(@DBName) + '''" -E -o' + @outpath + rtrim(@DBName) + '.gsql'
		Print @sqlcmd
		EXEC @result = master.sys.xp_cmdshell @sqlcmd


	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: Unable to backup the transaction log for database ''' + @DBName
					+ '''.  Check the Recovery Model setting for this database.'
		Print  @miscprint
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


		-------------------------------------------------------------
		-------------------------------------------------------------
		--
		--	IF DATABASE IS LOGSHIPPING PRIMARY DO NOT BACKUP
		--
		-------------------------------------------------------------
		-------------------------------------------------------------
		IF @cu11DBName in (SELECT primary_database from msdb.dbo.log_shipping_primary_databases)
		   begin
			Select @miscprint = 'DBA INFO: Database is a Logshipping Primary, dbasp_backup_tranlog cannot be used to do log backup'
			Print @miscprint
			raiserror(@miscprint,-1,-1)
			goto skip11
		   end


		-- GET COPYTO INFO
		DELETE	@LogShipPaths
		SET		@TSQL			= 'USE ['+@cu11DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
		--PRINT @TSQL
		INSERT INTO	@LogShipPaths
		EXEC		(@TSQL)
		SELECT		@TSQL = ''
		SELECT		@TSQL = @TSQL + ', COPYTO='''+CopyToPath+''''
		FROM		@LogShipPaths
		WHERE		nullif(CopyToPath,'') IS NOT NULL


		If databaseproperty(@cu11DBName, 'IsTrunclog') = 0
		   begin
			Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
			Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)
			Select @BkUpFile = @BkUpPath + '\' + @cu11DBName + '_tlog_' + @BkUpDateStmp + '.' + @BkUpExt
			Print 'Output file will be: ' + @BkUpFile


			If @BkUpMethod = 'RG'
			   begin
				Select @cmd = 'master.dbo.sqlbackup'


				Select @cmd2 = '-SQL "BACKUP LOG [' + rtrim(@cu11DBName) + ']'
						+ ' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						+ isnull(@TSQL,'')
						+ ', VERIFY"'
				Print @cmd
				Print @cmd2
				Print ' '
				delete from #resultstring
				Insert into #resultstring exec @cmd @cmd2
				--select * from #resultstring
			   end
			Else
			   begin
				Select @cmd = 'Backup LOG [' + rtrim(@cu11DBName) + '] to disk = ''' + @BkUpFile + ''''
				If @BkUpMethod = 'MSc'
				   begin
					Select @cmd = @cmd + ' with COMPRESSION'
				   end
				Print @cmd
				Print ' '
				Exec (@cmd)
			   end


			If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
			   begin
				Print 'DBA Errorr:  TranLog Backup Failure for command ' + @cmd
				Print '--***********************************************************'
				Print '@@error or @retcode was not zero'
				Print '--***********************************************************'
				Select @error_count = @error_count + 1
				goto label99
			   end
			Else If exists (select 1 from #resultstring where message like '%error%')
			   begin
				Print 'DBA Error:  TranLog Backup (RG) Failure for command ' + @cmd + @cmd2
				Print '--***********************************************************'
				Select * from #resultstring
				Print '--***********************************************************'
				Select @error_count = @error_count + 1
				goto label99
			   end


			--  Verify TranLog Backup
			If @BkUpMethod <> 'RG'
			   begin
				select @cmd = 'RESTORE VERIFYONLY FROM disk = ''' + @BkUpFile + ''''
				Print @cmd
				Print ' '
				Exec (@cmd)
			   end


			If @@error <> 0 or @retcode <> 0
			   begin
				Print 'DBA Error:  Backup Verification Failure for command ' + @cmd
				Print '--***********************************************************'
				Print '@@error or @retcode was not zero'
				Print '--***********************************************************'
				Select @error_count = @error_count + 1
				goto label99
			   end


			--  Create Restore script
			SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdbRestore_singleDB @dbname = ''' + rtrim(@cu11DBName) + '''" -E -o' + @outpath + rtrim(@cu11DBName) + '.gsql'
			Print @sqlcmd
			EXEC @result = master.sys.xp_cmdshell @sqlcmd


		   end


		skip11:


		--  check for more rows to process
		Delete from @DBnames where name = @cu11DBName
		If (select count(*) from @DBnames) > 0
		   begin
			goto start_dbnames
		   end


	   end


   end
Else If @all_flag = 'y'
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


		-------------------------------------------------------------
		-------------------------------------------------------------
		--
		--	IF DATABASE IS LOGSHIPPING PRIMARY DO NOT BACKUP
		--
		-------------------------------------------------------------
		-------------------------------------------------------------
		IF @cu12DBName in (SELECT primary_database from msdb.dbo.log_shipping_primary_databases)
		   begin
			Select @miscprint = 'DBA INFO: Database is a Logshipping Primary, dbasp_backup_tranlog cannot be used to do log backup'
			Print @miscprint
			raiserror(@miscprint,-1,-1)
			goto skip12
		   end


		If databaseproperty(@cu12DBName, 'IsTrunclog') = 0
		   begin
			Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
			Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)
			Select @BkUpFile = @BkUpPath + '\' + @cu12DBName + '_tlog_' + @BkUpDateStmp + '.' + @BkUpExt
			Print 'Output file will be: ' + @BkUpFile


			If @BkUpMethod = 'RG'
			   begin
				Select @cmd = 'master.dbo.sqlbackup'


				Select @cmd2 = '-SQL "BACKUP LOG [' + rtrim(@cu12DBName) + ']'
						+ ' TO DISK = ''' + rtrim(@BkUpFile)
						+ ''' WITH THREADCOUNT = ' + convert(varchar(10), @threads)
						+ ', COMPRESSION = ' + convert(varchar(5), @compressionlevel)
						+ ', MAXTRANSFERSIZE = ' + convert(varchar(10), @maxtransfersize)
						+ ', SINGLERESULTSET'
						+ ', VERIFY"'
				Print @cmd
				Print @cmd2
				Print ' '
				delete from #resultstring
				Insert into #resultstring exec @cmd @cmd2
				--select * from #resultstring
			   end
			Else
			   begin
				Select @cmd = 'Backup LOG [' + rtrim(@cu12DBName) + '] to disk = ''' + @BkUpFile + ''''
				If @BkUpMethod = 'MSc'
				   begin
					Select @cmd = @cmd + ' with COMPRESSION'
				   end
				Print @cmd
				Print ' '
				Exec (@cmd)
			   end


			If (@@error <> 0 or @retcode <> 0) and @BkUpMethod <> 'RG'
			   begin
				Print 'DBA Error:  TranLog Backup Failure for command ' + @cmd
				Print '--***********************************************************'
				Print '@@error or @retcode was not zero'
				Print '--***********************************************************'
				Select @error_count = @error_count + 1
				goto label99
			   end
			Else If exists (select 1 from #resultstring where message like '%error%')
			   begin
				Print 'DBA Error:  TranLog Backup (RG) Failure for command ' + @cmd + @cmd2
				Print '--***********************************************************'
				Select * from #resultstring
				Print '--***********************************************************'


				Select @error_count = @error_count + 1
				goto label99
			   end


			--  Verify TranLog Backup
			If @BkUpMethod <> 'RG'
			   begin
				select @cmd = 'RESTORE VERIFYONLY FROM disk = ''' + @BkUpFile + ''''
				Print @cmd
				Print ' '
				Exec (@cmd)
			   end


			If @@error <> 0 or @retcode <> 0
			   begin
				Print 'DBA Error:  Backup Verification Failure for command ' + @cmd
				Print '--***********************************************************'
				Print '@@error or @retcode was not zero'
				Print '--***********************************************************'
				Select @error_count = @error_count + 1
				goto label99
			   end


			--  Create Restore script
			SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdbRestore_singleDB @dbname = ''' + rtrim(@cu12DBName) + '''" -E -o' + @outpath + rtrim(@cu11DBName) + '.gsql'
			Print @sqlcmd
			EXEC @result = master.sys.xp_cmdshell @sqlcmd


		   end


		skip12:


		--  check for more rows to process
		Delete from @DBnames where name = @cu12DBName
		If (select count(*) from @DBnames) > 0
		   begin
			goto start_dbnames12
		   end


	   end


   end


--  Process any post tranlog backup requests from the local_control table  -------------------
Print ''
Print 'Start Post Tranlog Processing (from local_control)'


If exists (select 1 from dbo.local_control where subject = 'tranlog_backup_post')
   begin
	insert into @post_tranlog SELECT detail01 from dbo.local_control where subject = 'tranlog_backup_post'


	If (select count(*) from @post_tranlog) > 0
	   begin
		start_post01:
		Select @cmd = (select top 1 detail01 from @post_tranlog order by detail01)
		Print @cmd
		exec (@cmd)


		delete from @post_tranlog where detail01 = @cmd
		If (select count(*) from @post_tranlog) > 0
		   begin
			goto start_post01
		   end
	   end
   end


--  End Processing  ---------------------------------------------------------------------------------------------

Label99:


drop table #resultstring
drop table #temp_tbl2
drop table #ReadSqlLog
drop table #ReadSqlLog2


If @error_count > 0
   begin
	RAISERROR( 'DBA Error:  Tranlog Backup failure', 16, -1 )
	return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Tranlog] TO [public]
GO
