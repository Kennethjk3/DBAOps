SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_DbaDB_General]


/*********************************************************
 **  Stored Procedure dbasp_HC_DbaDB_General
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 18, 2014
 **  This procedure runs the DBA DB portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as


set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/18/2014	Steve Ledridge		New process.
--	02/03/2015	Steve Ledridge		Added Status, Updateability and UserAccess.
--	03/07/2016	Steve Ledridge		Auto fix DB owner if owned by a DBA.
--	01/18/2017	Steve Ledridge		Pass files set for no growth.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  For DB's: DBAOps, dbaperf, DBAOps
--  dba DB status
--  dba DB Updateability
--  dba DB UserAccess
--  dba DB owner
--  dba DB recov model
--  dba DB page verify
--  dba DB Backups
--  dba DB DBCC (within the last 4 weeks)
--  dba DB sizing and growth settings
--  dba DB local cursor setting
--  add DBAaspir to db_datareader if needed


/***


--***/


DECLARE		@miscprint						nvarchar(2000)
			,@cmd							nvarchar(2000)
			,@sqlcmd						nvarchar(2000)
			,@charpos						int
			,@save_test						nvarchar(4000)
			,@save_DB_owner					sysname
			,@save_RecoveryModel			sysname
			,@save_PageVerify				sysname
			,@save_fileid					smallint
			,@save_growthsize				int
			,@save_filesize					int
			,@save_DbaDB_Status				sysname
			,@save_old_DbaDB_Status			sysname
			,@save_DbaDB_Updateability		sysname
			,@save_old_DbaDB_Updateability	sysname
			,@save_DbaDB_UserAccess			sysname
			,@save_old_DbaDB_UserAccess		sysname
			,@save_DBname					sysname
			,@save_DBCC_date				datetime


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

	EXEC DBAOps.dbo.dbasp_GetPaths 
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

----------------  initial values  -------------------


CREATE TABLE #miscTempTable (cmdoutput NVARCHAR(400) NULL)


CREATE TABLE #db_files(fileid SMALLINT
			,groupid SMALLINT
			,groupname sysname null
			,size INT
			,growth INT
			,status INT
			,name sysname)


CREATE TABLE #DBCCs (ID INT IDENTITY(1, 1) PRIMARY KEY
			, ParentObject VARCHAR(255)
			, Object VARCHAR(255)
			, Field VARCHAR(255)
			, Value VARCHAR(255)
			, DbName NVARCHAR(128) NULL
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - DBA DB General'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Get the DB names to be processed
DELETE FROM #miscTempTable
INSERT INTO #miscTempTable
SELECT		name
FROM		master.sys.databases
WHERE		name in ('DBAOps', 'dbaperf')
--select * from #miscTempTable


--  Start the DBAr DB Check process
IF (SELECT COUNT(*) FROM #miscTempTable) > 0
   BEGIN
	start_databases:
	SELECT @save_DBname = (SELECT TOP 1 cmdoutput FROM #miscTempTable ORDER BY cmdoutput)
	SELECT @save_DBname = RTRIM(@save_DBname)


	--  Start Check for the next DB
	Print 'Start Check for the ' + @save_DBname + ' DB'
	Print ''


	SELECT @save_DbaDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'Status')))


	Select @save_old_DbaDB_Status = @save_DbaDB_Status
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'Status' and DBname = @save_DBname)
	   begin
		Select @save_old_DbaDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'Status' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Status''))'
	If @save_old_DbaDB_Status <> @save_DbaDB_Status
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Status_change', 'Warning', 'High', @save_test, @save_DBname, @save_DbaDB_Status, @save_old_DbaDB_Status, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Status''))'
	IF @save_DbaDB_Status = 'OFFLINE'
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Status', 'Fail', 'High', @save_test, @save_DBname, @save_DbaDB_Status, 'OFFLINE at this time', getdate())
	   end
	ELSE IF @save_DbaDB_Status <> 'ONLINE'
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Status', 'Fail', 'High', @save_test, @save_DBname, @save_DbaDB_Status, null, getdate())
	   end
	ELSE
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Status', 'Pass', 'High', @save_test, @save_DBname, @save_DbaDB_Status, null, getdate())
	   end


	SELECT @save_DbaDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'Updateability')))


	Select @save_old_DbaDB_Updateability = @save_DbaDB_Updateability
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'Updateability' and DBname = @save_DBname)
	   begin
		Select @save_old_DbaDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'Updateability' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Updateability''))'
	If @save_old_DbaDB_Updateability <> @save_DbaDB_Updateability
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Updateability_change', 'Warning', 'High', @save_test, @save_DBname, @save_DbaDB_Updateability, @save_old_DbaDB_Updateability, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''updateability''))'
	IF @save_DbaDB_Updateability = 'READ_ONLY'
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Updateability', 'Fail', 'High', @save_test, @save_DBname, @save_DbaDB_Updateability, 'READ_ONLY mode at this time', getdate())
	   end
	ELSE
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Updateability', 'Pass', 'High', @save_test, @save_DBname, @save_DbaDB_Updateability, null, getdate())
	   end


	SELECT @save_DbaDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'UserAccess')))


	Select @save_old_DbaDB_UserAccess = @save_DbaDB_UserAccess
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'UserAccess' and DBname = @save_DBname)
	   begin
		Select @save_old_DbaDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'DbaDB' and HCtype = 'UserAccess' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''UserAccess''))'
	If @save_old_DbaDB_UserAccess <> @save_DbaDB_UserAccess
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'UserAccess_change', 'Warning', 'High', @save_test, @save_DBname, @save_DbaDB_UserAccess, @save_old_DbaDB_UserAccess, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''UserAccess''))'
	IF @save_DbaDB_UserAccess = 'MULTI_USER'
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'UserAccess', 'Pass', 'High', @save_test, @save_DBname, @save_DbaDB_UserAccess, null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'UserAccess', 'Fail', 'High', @save_test, @save_DBname, @save_DbaDB_UserAccess, null, getdate())
	   end


	Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = ''' + @save_DBname + ''''


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
	If @save_DB_owner like 'DBA%' or @save_DB_owner like '%jwilson%' or @save_DB_owner like '%jbrown%' or @save_DB_owner like '%sledridge%'
	   begin
		Select @sqlcmd = 'ALTER AUTHORIZATION ON DATABASE::[' + @save_DBname + '] TO sa;'
		exec (@sqlcmd)
		SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
	   end


	IF @save_DB_owner = 'sa'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DB Owner', 'Pass', 'Medium', @save_test, @save_DBname, @save_DB_owner, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DB Owner', 'Fail', 'Medium', @save_test, @save_DBname, @save_DB_owner, @save_DBname + ' owner should be "sa"', getdate())
	   END


	Select @save_test = 'SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = ''' + @save_DBname + ''''


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'RecoveryModel', 'Pass', 'Medium', @save_test, @save_DBname, @save_RecoveryModel, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'RecoveryModel', 'Fail', 'Medium', @save_test, @save_DBname, @save_RecoveryModel, @save_DBname + ' recovery model should be SIMPLE', getdate())
	   END


	Select @save_test = 'SELECT CASE WHEN page_verify_option = 0 THEN ''NONE'' WHEN page_verify_option = 1 THEN ''TORN_PAGE_DETECTION'' WHEN page_verify_option = 2 THEN ''CHECKSUM'' end FROM master.sys.databases WITH (NOLOCK) WHERE name = ''' + @save_DBname + ''''


	SELECT @save_PageVerify = (SELECT CASE WHEN page_verify_option = 0 THEN 'NONE' WHEN page_verify_option = 1 THEN 'TORN_PAGE_DETECTION' WHEN page_verify_option = 2 THEN 'CHECKSUM' end FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
	IF @save_PageVerify = 'CHECKSUM'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Page Verify Option', 'Pass', 'Medium', @save_test, @save_DBname, @save_PageVerify, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Page Verify Option', 'Fail', 'Medium', @save_test, @save_DBname, @save_PageVerify, @save_DBname + ' page verify should be CHECKSUM', getdate())
	   END


	Select @save_test = 'select * from master.sys.databases where name = ''' + @save_DBname + ''' and is_local_cursor_default = 1'
	IF exists(select 1 from master.sys.databases where name = @save_DBname and is_local_cursor_default = 1)
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'local_cursor_default', 'Fail', 'Medium', @save_test, @save_DBname, 'Setting for is_local_cursor_default was LOCAL.  S/B set to GLOBAL.', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'local_cursor_default', 'Pass', 'Medium', @save_test, @save_DBname, 'Setting for is_local_cursor_default is GLOBAL.', null, getdate())
	   END


	--  check DbaDB Backups
	Print 'Start DbaDB Backup check'
	Print ''


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) <> 'production'
	   BEGIN
		Print 'Skip Backup check for DB ' + @save_DBname + '.  This check only done for production.'
		Print ''
	   END
	Else
	   BEGIN
		exec dbasp_HC_DB_Backups @dbname = @save_DBname, @HCcat = 'DbaDB'
	   END


	--  check for last DBCC (within the last 4 weeks)
	Print 'Start DbaDB DBCC check'
	Print ''


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) <> 'production'
	   BEGIN
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  This check only done for production.'
		Print ''
		goto skip_DBCC_check
	   END


	If (select sum((CAST(size AS bigint)*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @save_DBname and type <> 1) > 999998
	   begin
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  Size limit for this DB.'
		Print ''
		goto skip_DBCC_check
	   END


	delete from #DBCCs
	INSERT #DBCCs
		(ParentObject,
		Object,
		Field,
		Value)
	EXEC ('DBCC DBInfo(' + @save_DBname + ') With TableResults, NO_INFOMSGS')
	delete from #DBCCs where field <> 'dbi_dbccLastKnownGood'
	--select * from #DBCCs


	Select @save_test = 'EXEC (''DBCC DBInfo(' + @save_DBname + ') With TableResults, NO_INFOMSGS'')'


	If (select count(*) from #DBCCs) > 0
	   begin
		Select @save_DBCC_date = (select top 1 convert(datetime, Value) from #DBCCs where field = 'dbi_dbccLastKnownGood')
		If (datediff(day, @save_DBCC_date, getdate())) < 28
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DBCC Check', 'Pass', 'High', @save_test, @save_DBname, convert(sysname, @save_DBCC_date), null, getdate())
		   END
		Else
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DBCC Check', 'Fail', 'High', @save_test, @save_DBname, convert(sysname, @save_DBCC_date), 'Last DBCC CheckDB was more than 28 days ago.', getdate())
		   END


	   end
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DBCC Check', 'Fail', 'High', @save_test, @save_DBname, 'dbi_dbccLastKnownGood not found for this DB.', 'DBCC status unknown', getdate())
	   END


	skip_DBCC_check:


	--  check for file sizes and growth sizes.
	SELECT @cmd = 'select s.fileid, s.groupid, null, s.size, s.growth, s.status, s.name from ' + @save_DBname + '.sys.sysfiles s, ' + @save_DBname + '.sys.database_files f where s.fileid = f.file_id'
	Select @save_test = @cmd


	delete from #db_files
	INSERT INTO #db_files EXEC (@cmd)
	--select * from #db_files


	Start_file_size:


	Select @save_fileid = (select top 1 fileid from #db_files)


	If (select groupid from #db_files where fileid = @save_fileid) = 0
	   begin
		Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
		If @save_filesize >= 65536
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Size', 'Pass', 'Medium', @save_test,@save_DBname, convert(varchar(20), @save_filesize) + 'KB', null, getdate())
		   END
		ELSE
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Size', 'Fail', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 512MB', getdate())
		   END

		Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
		If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Growth', 'Fail', 'Medium', @save_test, @save_DBname, 'Growth by percentage is set', 'File growth size should be 256MB', getdate())
		   END
		Else If @save_growthsize >= 32768
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Growth', 'Pass', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
		   END
		Else If @save_growthsize = 0
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Growth', 'Pass', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', 'File set to not grow', getdate())
		   END
		Else
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Log File Growth', 'Fail', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 256MB', getdate())
		   END
	   end
	Else
	   begin
		Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
		If @save_filesize >= 131072
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Size', 'Pass', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_filesize) + 'KB', null, getdate())
		   END
		ELSE
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Size', 'Fail', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 1GB (1024MB)', getdate())
		   END

		Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
		If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Growth', 'Fail', 'Medium', @save_test, @save_DBname, 'Growth by percentage is set', 'File growth size should be 512MB', getdate())
		   END
		Else If @save_growthsize >= 65536
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Growth', 'Pass', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
		   END
		Else If @save_growthsize = 0
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Growth', 'Pass', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', 'File set to not grow', getdate())
		   END
		Else
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'Data File Growth', 'Fail', 'Medium', @save_test, @save_DBname, convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 512MB', getdate())
		   END
	   end


	delete from #db_files where fileid = @save_fileid
	If (select count(*) from #db_files) > 0
	   begin
		goto Start_file_size
	   end


	--  Special Check for DBAcentral data
	If @save_DBname = 'DBAcentral'
	   begin
		Select @save_test = 'Select * from DBAcentral.dbo.DBA_ServerInfo where active = ''y'' and moddate < getdate()-5'


		If exists (Select 1 from DBAcentral.dbo.DBA_ServerInfo where active = 'y' and moddate < getdate()-5)
		   begin
			insert into [dbo].[HealthCheckLog] values ('DbaDB', 'DBA_ServerInfo', 'Warning', 'High', @save_test, @save_DBname, 'Active servers with moddate older than 5 days', null, getdate())
		   end
	   end


	-- check for more rows to process
	delete from #miscTempTable where cmdoutput = @save_DBname
	IF (SELECT COUNT(*) FROM #miscTempTable) > 0
	   BEGIN
		goto start_databases
	  END


   END


Print '--select * from [dbo].[HealthCheckLog] where HCcat like ''DbaDB%'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #miscTempTable
drop TABLE #db_files
drop TABLE #DBCCs
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_DbaDB_General] TO [public]
GO
