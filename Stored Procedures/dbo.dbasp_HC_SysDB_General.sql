SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_SysDB_General]


/*********************************************************
 **  Stored Procedure dbasp_HC_SysDB_General
 **  Written by Steve Ledridge, Virtuoso
 **  November 04, 2014
 **  This procedure runs the Sys DB portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/01/2014	Steve Ledridge		New process.
--	01/02/2015	Steve Ledridge		Added growable check for tempdb log files.
--	02/03/2015	Steve Ledridge		Added Status, Updateability and UserAccess.
--	02/10/2015	Steve Ledridge		Added backup check.
--	02/20/2015	Steve Ledridge		Added Auto fix for tempdb size and growth.
--	03/04/2015	Steve Ledridge		Removed page verify for tempdb.
--	05/14/2015	Steve Ledridge		Allow for ReportServerTempDbon the tempdb drive.
--	09/10/2015	Steve Ledridge		OK for tempdb to be on same drive with master.
--	03/22/2016	Steve Ledridge		New code for DB SemanticsDB.
--	03/25/2016	Steve Ledridge		Fixed code for DB SemanticsDB backups.
--	01/24/2017	Steve Ledridge		Make sure model is FULL recovery mode in prod.
--	01/25/2017	Steve Ledridge		Added msdb Service Broker Queue check.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  dba DB status
--  dba DB Updateability
--  dba DB UserAccess
--  sys DB owner
--  sys DB recov model
--  sys DB page verify
--  sys DB sizing and growth settings (model and tempdb)
--  sys DB file location (for tempdb)
--  tempDB number of files


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@save_DB_owner				sysname
	,@save_RecoveryModel			sysname
	,@save_PageVerify			sysname
	,@save_name				sysname
	,@save_groupid				smallint
	,@save_fileid				smallint
	,@save_growthsize			int
	,@save_filesize				int
	,@save_filename				sysname
	,@save_master_filepath			NVARCHAR(2000)
	,@save_tempdb_corecount			NVARCHAR(10)
	,@save_tempdb_filecount			NVARCHAR(10)
	,@save_tempdb_corecount_int		int
	,@save_tempdb_filecount_int		int
	,@save_tempdb_filedrive			sysname
	,@save_SysDB_Status			sysname
	,@save_old_SysDB_Status			sysname
	,@save_SysDB_Updateability		sysname
	,@save_old_SysDB_Updateability		sysname
	,@save_SysDB_UserAccess			sysname
	,@save_old_SysDB_UserAccess		sysname
	,@hold_backup_start_date		DATETIME
	,@save_backup_start_date		sysname


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


CREATE TABLE #db_files(fileid SMALLINT
			,groupid SMALLINT
			,groupname sysname null
			,size INT
			,growth INT
			,status INT
			,name sysname)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Sys DB General'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Start Check for the master DB
Print 'Start Check for the master DB'
Print ''


SELECT @save_SysDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('master', 'Status')))


Select @save_old_SysDB_Status = @save_SysDB_Status
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'Status' and DBname = 'master')
   begin
	Select @save_old_SysDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'Status' and DBname = 'master' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''Status''))'
If @save_old_SysDB_Status <> @save_SysDB_Status
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Status_change', 'Warning', 'High', @save_test, 'master', @save_SysDB_Status, @save_old_SysDB_Status, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''Status''))'
IF @save_SysDB_Status = 'OFFLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Status', 'fail', 'High', @save_test, 'master', @save_SysDB_Status, 'OFFLINE at this time', getdate())
   end
ELSE IF @save_SysDB_Status <> 'ONLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Status', 'fail', 'High', @save_test, 'master', @save_SysDB_Status, null, getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Status', 'pass', 'High', @save_test, 'master', @save_SysDB_Status, null, getdate())
   end


SELECT @save_SysDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('master', 'Updateability')))


Select @save_old_SysDB_Updateability = @save_SysDB_Updateability
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'Updateability' and DBname = 'master')
   begin
	Select @save_old_SysDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'Updateability' and DBname = 'master' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''Updateability''))'
If @save_old_SysDB_Updateability <> @save_SysDB_Updateability
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Updateability_change', 'Warning', 'High', @save_test, 'master', @save_SysDB_Updateability, @save_old_SysDB_Updateability, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''updateability''))'
IF @save_SysDB_Updateability = 'READ_ONLY'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Updateability', 'fail', 'High', @save_test, 'master', @save_SysDB_Updateability, 'READ_ONLY mode at this time', getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Updateability', 'pass', 'High', @save_test, 'master', @save_SysDB_Updateability, null, getdate())
   end


SELECT @save_SysDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('master', 'UserAccess')))


Select @save_old_SysDB_UserAccess = @save_SysDB_UserAccess
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'UserAccess' and DBname = 'master')
   begin
	Select @save_old_SysDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_master' and HCtype = 'UserAccess' and DBname = 'master' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''UserAccess''))'
If @save_old_SysDB_UserAccess <> @save_SysDB_UserAccess
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'UserAccess_change', 'Warning', 'High', @save_test, 'master', @save_SysDB_UserAccess, @save_old_SysDB_UserAccess, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''master'', ''UserAccess''))'
IF @save_SysDB_UserAccess = 'MULTI_USER'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'UserAccess', 'pass', 'High', @save_test, 'master', @save_SysDB_UserAccess, null, getdate())
   end
Else
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'UserAccess', 'fail', 'High', @save_test, 'master', @save_SysDB_UserAccess, null, getdate())
   end


Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = ''master'''


SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'master')
IF @save_DB_owner = 'sa'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'DB Owner', 'Pass', 'Medium', @save_test, 'master', @save_DB_owner, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'DB Owner', 'Fail', 'Medium', @save_test, 'master', @save_DB_owner, 'master owner should be "sa"', getdate())
   END


Select @save_test = 'SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = ''master'''


SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'master')
IF @save_RecoveryModel = 'SIMPLE'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'RecoveryModel', 'Pass', 'Medium', @save_test, 'master', @save_RecoveryModel, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'RecoveryModel', 'Fail', 'Medium', @save_test, 'master', @save_RecoveryModel, 'master recovery model should be SIMPLE', getdate())
   END


Select @save_test = 'SELECT CASE WHEN page_verify_option = 0 THEN ''NONE'' WHEN page_verify_option = 1 THEN ''TORN_PAGE_DETECTION'' WHEN page_verify_option = 2 THEN ''CHECKSUM'' end FROM master.sys.databases WITH (NOLOCK) WHERE name = ''master'''


SELECT @save_PageVerify = (SELECT CASE WHEN page_verify_option = 0 THEN 'NONE' WHEN page_verify_option = 1 THEN 'TORN_PAGE_DETECTION' WHEN page_verify_option = 2 THEN 'CHECKSUM' end FROM master.sys.databases WITH (NOLOCK) WHERE name = 'master')
IF @save_PageVerify = 'CHECKSUM'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Page Verify Option', 'Pass', 'Medium', @save_test, 'master', @save_PageVerify, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Page Verify Option', 'Fail', 'Medium', @save_test, 'master', @save_PageVerify, 'master page verify should be CHECKSUM', getdate())
   END


--  Get the backup time for the last full database backup
If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
   BEGIN
	SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
						WHERE database_name = 'master'
						AND backup_finish_date IS NOT NULL
						AND type IN ('D', 'F')
						ORDER BY backup_start_date DESC)

	SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)

	Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''master'' AND backup_finish_date IS NOT NULL AND type IN (''D'', ''F'') ORDER BY backup_start_date DESC'
	IF @hold_backup_start_date IS NULL
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Backup Full', 'Fail', 'Critical', @save_test, 'master', 'No DBbackup found', null, getdate())
	   END
	ELSE IF @hold_backup_start_date < getdate()-2
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Backup Full', 'Fail', 'Critical', @save_test, 'master', 'No recent DBbackup found', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_master', 'Backup Full', 'Pass', 'Critical', @save_test, 'master', @save_backup_start_date, null, getdate())
	   END
   END


--  Start Check for the SemanticsDB DB
Print 'Start Check for the SemanticsDB DB'
Print ''


If not exists (SELECT 1 FROM master.sys.databases WITH (NOLOCK) WHERE name = 'SemanticsDB')
   begin
	goto skip_SemanticsDB
   end


SELECT @save_SysDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('SemanticsDB', 'Status')))


Select @save_old_SysDB_Status = @save_SysDB_Status
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'Status' and DBname = 'SemanticsDB')
   begin
	Select @save_old_SysDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'Status' and DBname = 'SemanticsDB' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''Status''))'
If @save_old_SysDB_Status <> @save_SysDB_Status
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Status_change', 'Warning', 'High', @save_test, 'SemanticsDB', @save_SysDB_Status, @save_old_SysDB_Status, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''Status''))'
IF @save_SysDB_Status = 'OFFLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Status', 'fail', 'High', @save_test, 'SemanticsDB', @save_SysDB_Status, 'OFFLINE at this time', getdate())
   end
ELSE IF @save_SysDB_Status <> 'ONLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Status', 'fail', 'High', @save_test, 'SemanticsDB', @save_SysDB_Status, null, getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Status', 'pass', 'High', @save_test, 'SemanticsDB', @save_SysDB_Status, null, getdate())
   end


SELECT @save_SysDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('SemanticsDB', 'Updateability')))


Select @save_old_SysDB_Updateability = @save_SysDB_Updateability
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'Updateability' and DBname = 'SemanticsDB')
   begin
	Select @save_old_SysDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'Updateability' and DBname = 'SemanticsDB' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''Updateability''))'
If @save_old_SysDB_Updateability <> @save_SysDB_Updateability
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Updateability_change', 'Warning', 'High', @save_test, 'SemanticsDB', @save_SysDB_Updateability, @save_old_SysDB_Updateability, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''updateability''))'
IF @save_SysDB_Updateability = 'READ_ONLY'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Updateability', 'fail', 'High', @save_test, 'SemanticsDB', @save_SysDB_Updateability, 'READ_ONLY mode at this time', getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Updateability', 'pass', 'High', @save_test, 'SemanticsDB', @save_SysDB_Updateability, null, getdate())
   end


SELECT @save_SysDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('SemanticsDB', 'UserAccess')))


Select @save_old_SysDB_UserAccess = @save_SysDB_UserAccess
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'UserAccess' and DBname = 'SemanticsDB')
   begin
	Select @save_old_SysDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_SemanticsDB' and HCtype = 'UserAccess' and DBname = 'SemanticsDB' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''UserAccess''))'
If @save_old_SysDB_UserAccess <> @save_SysDB_UserAccess
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'UserAccess_change', 'Warning', 'High', @save_test, 'SemanticsDB', @save_SysDB_UserAccess, @save_old_SysDB_UserAccess, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''SemanticsDB'', ''UserAccess''))'
IF @save_SysDB_UserAccess = 'MULTI_USER'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'UserAccess', 'pass', 'High', @save_test, 'SemanticsDB', @save_SysDB_UserAccess, null, getdate())
   end
Else
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'UserAccess', 'fail', 'High', @save_test, 'SemanticsDB', @save_SysDB_UserAccess, null, getdate())
   end


Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = ''SemanticsDB'''


SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'SemanticsDB')
IF @save_DB_owner = 'sa'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'DB Owner', 'Pass', 'Medium', @save_test, 'SemanticsDB', @save_DB_owner, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'DB Owner', 'Fail', 'Medium', @save_test, 'SemanticsDB', @save_DB_owner, 'SemanticsDB owner should be "sa"', getdate())
   END


Select @save_test = 'SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = ''SemanticsDB'''


SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'SemanticsDB')
IF @save_RecoveryModel = 'SIMPLE'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'RecoveryModel', 'Pass', 'Medium', @save_test, 'SemanticsDB', @save_RecoveryModel, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'RecoveryModel', 'Fail', 'Medium', @save_test, 'SemanticsDB', @save_RecoveryModel, 'SemanticsDB recovery model should be SIMPLE', getdate())
   END


Select @save_test = 'SELECT CASE WHEN page_verify_option = 0 THEN ''NONE'' WHEN page_verify_option = 1 THEN ''TORN_PAGE_DETECTION'' WHEN page_verify_option = 2 THEN ''CHECKSUM'' end FROM master.sys.databases WITH (NOLOCK) WHERE name = ''SemanticsDB'''


SELECT @save_PageVerify = (SELECT CASE WHEN page_verify_option = 0 THEN 'NONE' WHEN page_verify_option = 1 THEN 'TORN_PAGE_DETECTION' WHEN page_verify_option = 2 THEN 'CHECKSUM' end FROM master.sys.databases WITH (NOLOCK) WHERE name = 'SemanticsDB')
IF @save_PageVerify = 'CHECKSUM'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Page Verify Option', 'Pass', 'Medium', @save_test, 'SemanticsDB', @save_PageVerify, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_SemanticsDB', 'Page Verify Option', 'Fail', 'Medium', @save_test, 'SemanticsDB', @save_PageVerify, 'SemanticsDB page verify should be CHECKSUM', getdate())
   END


--  Check DB backups
If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
   BEGIN
	exec dbo.dbasp_HC_DB_Backups @dbname = 'SemanticsDB', @HCcat = 'SysDB'
   END


skip_SemanticsDB:


--  Start Check for the msdb DB
Print 'Start Check for the msdb DB'
Print ''


SELECT @save_SysDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('msdb', 'Status')))


Select @save_old_SysDB_Status = @save_SysDB_Status
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'Status' and DBname = 'msdb')
   begin
	Select @save_old_SysDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'Status' and DBname = 'msdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''Status''))'
If @save_old_SysDB_Status <> @save_SysDB_Status
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Status_change', 'Warning', 'High', @save_test, 'msdb', @save_SysDB_Status, @save_old_SysDB_Status, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''Status''))'
IF @save_SysDB_Status = 'OFFLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Status', 'fail', 'High', @save_test, 'msdb', @save_SysDB_Status, 'OFFLINE at this time', getdate())
   end
ELSE IF @save_SysDB_Status <> 'ONLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Status', 'fail', 'High', @save_test, 'msdb', @save_SysDB_Status, null, getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Status', 'pass', 'High', @save_test, 'msdb', @save_SysDB_Status, null, getdate())
   end


SELECT @save_SysDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('msdb', 'Updateability')))


Select @save_old_SysDB_Updateability = @save_SysDB_Updateability
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'Updateability' and DBname = 'msdb')
   begin
	Select @save_old_SysDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'Updateability' and DBname = 'msdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''Updateability''))'
If @save_old_SysDB_Updateability <> @save_SysDB_Updateability
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Updateability_change', 'Warning', 'High', @save_test, 'msdb', @save_SysDB_Updateability, @save_old_SysDB_Updateability, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''updateability''))'
IF @save_SysDB_Updateability = 'READ_ONLY'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Updateability', 'fail', 'High', @save_test, 'msdb', @save_SysDB_Updateability, 'READ_ONLY mode at this time', getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Updateability', 'pass', 'High', @save_test, 'msdb', @save_SysDB_Updateability, null, getdate())
   end


SELECT @save_SysDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('msdb', 'UserAccess')))


Select @save_old_SysDB_UserAccess = @save_SysDB_UserAccess
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'UserAccess' and DBname = 'msdb')
   begin
	Select @save_old_SysDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_msdb' and HCtype = 'UserAccess' and DBname = 'msdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''UserAccess''))'
If @save_old_SysDB_UserAccess <> @save_SysDB_UserAccess
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'UserAccess_change', 'Warning', 'High', @save_test, 'msdb', @save_SysDB_UserAccess, @save_old_SysDB_UserAccess, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''msdb'', ''UserAccess''))'
IF @save_SysDB_UserAccess = 'MULTI_USER'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'UserAccess', 'pass', 'High', @save_test, 'msdb', @save_SysDB_UserAccess, null, getdate())
   end
Else
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'UserAccess', 'fail', 'High', @save_test, 'msdb', @save_SysDB_UserAccess, null, getdate())
   end



Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM msdb.sys.databases WITH (NOLOCK) WHERE name = ''msdb'''


SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM msdb.sys.databases WITH (NOLOCK) WHERE name = 'msdb')
IF @save_DB_owner = 'sa'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'DB Owner', 'Pass', 'Medium', @save_test, 'msdb', @save_DB_owner, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'DB Owner', 'Fail', 'Medium', @save_test, 'msdb', @save_DB_owner, 'msdb owner should be "sa"', getdate())
   END


Select @save_test = 'SELECT recovery_model_desc FROM msdb.sys.databases WITH (NOLOCK) WHERE name = ''msdb'''


SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM msdb.sys.databases WITH (NOLOCK) WHERE name = 'msdb')
IF @save_RecoveryModel = 'SIMPLE'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'RecoveryModel', 'Pass', 'Medium', @save_test, 'msdb', @save_RecoveryModel, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'RecoveryModel', 'Fail', 'Medium', @save_test, 'msdb', @save_RecoveryModel, 'msdb recovery model should be SIMPLE', getdate())
   END


Select @save_test = 'SELECT CASE WHEN page_verify_option = 0 THEN ''NONE'' WHEN page_verify_option = 1 THEN ''TORN_PAGE_DETECTION'' WHEN page_verify_option = 2 THEN ''CHECKSUM'' end FROM msdb.sys.databases WITH (NOLOCK) WHERE name = ''msdb'''


SELECT @save_PageVerify = (SELECT CASE WHEN page_verify_option = 0 THEN 'NONE' WHEN page_verify_option = 1 THEN 'TORN_PAGE_DETECTION' WHEN page_verify_option = 2 THEN 'CHECKSUM' end FROM msdb.sys.databases WITH (NOLOCK) WHERE name = 'msdb')
IF @save_PageVerify = 'CHECKSUM'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Page Verify Option', 'Pass', 'Medium', @save_test, 'msdb', @save_PageVerify, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Page Verify Option', 'Fail', 'Medium', @save_test, 'msdb', @save_PageVerify, 'msdb page verify should be CHECKSUM', getdate())
   END


--  Get the backup time for the last full database backup
If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
   BEGIN
	SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
						WHERE database_name = 'msdb'
						AND backup_finish_date IS NOT NULL
						AND type IN ('D', 'F')
						ORDER BY backup_start_date DESC)

	SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)

	Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''msdb'' AND backup_finish_date IS NOT NULL AND type IN (''D'', ''F'') ORDER BY backup_start_date DESC'
	IF @hold_backup_start_date IS NULL
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Backup Full', 'Fail', 'Critical', @save_test, 'msdb', 'No DBbackup found', null, getdate())
	   END
	ELSE IF @hold_backup_start_date < getdate()-2
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Backup Full', 'Fail', 'Critical', @save_test, 'msdb', 'No recent DBbackup found', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'Backup Full', 'Pass', 'Critical', @save_test, 'msdb', @save_backup_start_date, null, getdate())
	   END
   END


--  Check Service Broker Queues
Print 'Start SysDB msdb Service Broker Queue check'
Print ''


If not exists (SELECT name FROM msdb.sys.service_queues WHERE [is_ms_shipped] = 0)
   begin
	Print 'Skip SysDB Service Broker Queue check for DB msdb.  The DB does not contain Service Broker Queues.'
	Print ''
	goto skip_ServiceBrokerQueue_msdb
   end


Select @save_test = 'SELECT name FROM msdb.sys.service_queues WHERE [is_ms_shipped] = 0'


Select @save_name = ''
Start_ServiceBrokerQueue_msdb:
Select @save_name = (select top 1 name from msdb.sys.service_queues WHERE [is_ms_shipped] = 0 and name > @save_name order by name)
If exists (select 1 from dbo.SrvBrkrQueues where DBName = 'msdb' and QName = @save_name)
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'SBQueue Check', 'Pass', 'High', @save_test, 'msdb', @save_name, null, getdate())
   END
Else
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_msdb', 'SBQueue Check', 'Fail', 'High', @save_test, 'msdb', @save_name, 'Unknown Service Broker Queue', getdate())
   END


If exists (select top 1 name from msdb.sys.service_queues WHERE [is_ms_shipped] = 0 and name > @save_name)
   begin
	goto Start_ServiceBrokerQueue_msdb
   end


skip_ServiceBrokerQueue_msdb:


--  Start Check for the model DB
Print 'Start Check for the model DB'
Print ''


SELECT @save_SysDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('model', 'Status')))


Select @save_old_SysDB_Status = @save_SysDB_Status
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'Status' and DBname = 'model')
   begin
	Select @save_old_SysDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'Status' and DBname = 'model' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''Status''))'
If @save_old_SysDB_Status <> @save_SysDB_Status
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Status_change', 'Warning', 'High', @save_test, 'model', @save_SysDB_Status, @save_old_SysDB_Status, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''Status''))'
IF @save_SysDB_Status = 'OFFLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Status', 'fail', 'High', @save_test, 'model', @save_SysDB_Status, 'OFFLINE at this time', getdate())
   end
ELSE IF @save_SysDB_Status <> 'ONLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Status', 'fail', 'High', @save_test, 'model', @save_SysDB_Status, null, getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Status', 'pass', 'High', @save_test, 'model', @save_SysDB_Status, null, getdate())
   end


SELECT @save_SysDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('model', 'Updateability')))


Select @save_old_SysDB_Updateability = @save_SysDB_Updateability
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'Updateability' and DBname = 'model')
   begin
	Select @save_old_SysDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'Updateability' and DBname = 'model' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''Updateability''))'
If @save_old_SysDB_Updateability <> @save_SysDB_Updateability
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Updateability_change', 'Warning', 'High', @save_test, 'model', @save_SysDB_Updateability, @save_old_SysDB_Updateability, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''updateability''))'
IF @save_SysDB_Updateability = 'READ_ONLY'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Updateability', 'fail', 'High', @save_test, 'model', @save_SysDB_Updateability, 'READ_ONLY mode at this time', getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Updateability', 'pass', 'High', @save_test, 'model', @save_SysDB_Updateability, null, getdate())
   end


SELECT @save_SysDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('model', 'UserAccess')))


Select @save_old_SysDB_UserAccess = @save_SysDB_UserAccess
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'UserAccess' and DBname = 'model')
   begin
	Select @save_old_SysDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_model' and HCtype = 'UserAccess' and DBname = 'model' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''UserAccess''))'
If @save_old_SysDB_UserAccess <> @save_SysDB_UserAccess
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'UserAccess_change', 'Warning', 'High', @save_test, 'model', @save_SysDB_UserAccess, @save_old_SysDB_UserAccess, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''model'', ''UserAccess''))'
IF @save_SysDB_UserAccess = 'MULTI_USER'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'UserAccess', 'pass', 'High', @save_test, 'model', @save_SysDB_UserAccess, null, getdate())
   end
Else
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'UserAccess', 'fail', 'High', @save_test, 'model', @save_SysDB_UserAccess, null, getdate())
   end



Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM model.sys.databases WITH (NOLOCK) WHERE name = ''model'''


SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM model.sys.databases WITH (NOLOCK) WHERE name = 'model')
IF @save_DB_owner = 'sa'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'DB Owner', 'Pass', 'Medium', @save_test, 'model', @save_DB_owner, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'DB Owner', 'Fail', 'Medium', @save_test, 'model', @save_DB_owner, 'model owner should be "sa"', getdate())
   END


Select @save_test = 'SELECT recovery_model_desc FROM model.sys.databases WITH (NOLOCK) WHERE name = ''model'''


If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production' and not exists (select 1 from dbo.no_check where NoCheck_type = 'recovery_model' and detail01 = 'model' and detail02 = 'simple')
   BEGIN
	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM model.sys.databases WITH (NOLOCK) WHERE name = 'model')
	IF @save_RecoveryModel = 'FULL'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'RecoveryModel', 'Pass', 'Medium', @save_test, 'model', @save_RecoveryModel, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'RecoveryModel', 'Fail', 'Medium', @save_test, 'model', @save_RecoveryModel, 'model recovery model should be FULL', getdate())
	   END
   END
ELSE
   BEGIN
	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM model.sys.databases WITH (NOLOCK) WHERE name = 'model')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'RecoveryModel', 'Pass', 'Medium', @save_test, 'model', @save_RecoveryModel, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'RecoveryModel', 'Fail', 'Medium', @save_test, 'model', @save_RecoveryModel, 'model recovery model should be SIMPLE', getdate())
	   END
   END


Select @save_test = 'SELECT CASE WHEN page_verify_option = 0 THEN ''NONE'' WHEN page_verify_option = 1 THEN ''TORN_PAGE_DETECTION'' WHEN page_verify_option = 2 THEN ''CHECKSUM'' end FROM model.sys.databases WITH (NOLOCK) WHERE name = ''model'''


SELECT @save_PageVerify = (SELECT CASE WHEN page_verify_option = 0 THEN 'NONE' WHEN page_verify_option = 1 THEN 'TORN_PAGE_DETECTION' WHEN page_verify_option = 2 THEN 'CHECKSUM' end FROM model.sys.databases WITH (NOLOCK) WHERE name = 'model')
IF @save_PageVerify = 'CHECKSUM'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Page Verify Option', 'Pass', 'Medium', @save_test, 'model', @save_PageVerify, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Page Verify Option', 'Fail', 'Medium', @save_test, 'model', @save_PageVerify, 'model page verify should be CHECKSUM', getdate())
   END


--  Get the backup time for the last full database backup
If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
   BEGIN
	SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
						WHERE database_name = 'model'
						AND backup_finish_date IS NOT NULL
						AND type IN ('D', 'F')
						ORDER BY backup_start_date DESC)

	SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)

	Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''model'' AND backup_finish_date IS NOT NULL AND type IN (''D'', ''F'') ORDER BY backup_start_date DESC'
	IF @hold_backup_start_date IS NULL
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Backup Full', 'Fail', 'Critical', @save_test, 'model', 'No DBbackup found', null, getdate())
	   END
	ELSE IF @hold_backup_start_date < getdate()-2
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Backup Full', 'Fail', 'Critical', @save_test, 'model', 'No recent DBbackup found', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Backup Full', 'Pass', 'Critical', @save_test, 'model', @save_backup_start_date, null, getdate())
	   END
   END


--  check file size and growth settings
SELECT @cmd = 'select s.fileid, s.groupid, g.name, s.size, s.growth, s.status, s.name from model.sys.sysfiles s, model.sys.database_files f, model.sys.filegroups g where s.fileid = f.file_id and f.data_space_id = g.data_space_id'
Select @save_test = @cmd


delete from #db_files
INSERT INTO #db_files EXEC (@cmd)
--select * from #db_files


--  check for growable file in each filegroup
Start_model_grow_check:


Select @save_groupid = (select top 1 groupid from #db_files)


If exists (select 1 from #db_files where groupid = @save_groupid and growth <> 0)
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Growable', 'Pass', 'Medium', @save_test, 'model', null, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Growable', 'Fail', 'Medium', @save_test, 'model', 'For groupid ' + convert(sysname, @save_groupid), 'No growable files found for this file group', getdate())
   END

Delete from #db_files where groupid = @save_groupid
If (select count(*) from #db_files) > 0
   begin
	goto Start_model_grow_check
   end


--  check for file sizes and growth sizes.
SELECT @cmd = 'select s.fileid, s.groupid, null, s.size, s.growth, s.status, s.name from model.sys.sysfiles s, model.sys.database_files f where s.fileid = f.file_id'
Select @save_test = @cmd


delete from #db_files
INSERT INTO #db_files EXEC (@cmd)
--select * from #db_files


Start_model_file_size:


Select @save_fileid = (select top 1 fileid from #db_files)


If (select groupid from #db_files where fileid = @save_fileid) = 0
   begin
	Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
	If @save_filesize >= 65536
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Log File Size', 'Pass', 'Medium', @save_test, 'model', convert(varchar(20), @save_filesize) + 'KB', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Log File Size', 'Fail', 'Medium', @save_test, 'model', convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 512MB', getdate())
	   END

	Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
	If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Log File Growth', 'Fail', 'Medium', @save_test, 'model', 'Growth by percentage is set', 'File growth size should be 256MB', getdate())
	   END
	Else If @save_growthsize >= 32768
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Log File Growth', 'Pass', 'Medium', @save_test, 'model', convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Log File Growth', 'Fail', 'Medium', @save_test, 'model', convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 256MB', getdate())
	   END
   end
Else
   begin
	Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
	If @save_filesize >= 131072
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Size', 'Pass', 'Medium', @save_test, 'model', convert(varchar(20), @save_filesize) + 'KB', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Size', 'Fail', 'Medium', @save_test, 'model', convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 1GB (1024MB)', getdate())
	   END

	Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
	If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Growth', 'Fail', 'Medium', @save_test, 'model', 'Growth by percentage is set', 'File growth size should be 512MB', getdate())
	   END
	Else If @save_growthsize >= 65536
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Growth', 'Pass', 'Medium', @save_test, 'model', convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_model', 'Data File Growth', 'Fail', 'Medium', @save_test, 'model', convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 512MB', getdate())
	   END
   end


delete from #db_files where fileid = @save_fileid
If (select count(*) from #db_files) > 0
   begin
	goto Start_model_file_size
   end


--  Start Check for TempDB
Print 'Start Check for TempDB'
Print ''


SELECT @save_SysDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('tempdb', 'Status')))


Select @save_old_SysDB_Status = @save_SysDB_Status
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'Status' and DBname = 'tempdb')
   begin
	Select @save_old_SysDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'Status' and DBname = 'tempdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''Status''))'
If @save_old_SysDB_Status <> @save_SysDB_Status
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Status_change', 'Warning', 'High', @save_test, 'tempdb', @save_SysDB_Status, @save_old_SysDB_Status, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''Status''))'
IF @save_SysDB_Status = 'OFFLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Status', 'fail', 'High', @save_test, 'tempdb', @save_SysDB_Status, 'OFFLINE at this time', getdate())
   end
ELSE IF @save_SysDB_Status <> 'ONLINE'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Status', 'fail', 'High', @save_test, 'tempdb', @save_SysDB_Status, null, getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Status', 'pass', 'High', @save_test, 'tempdb', @save_SysDB_Status, null, getdate())
   end


SELECT @save_SysDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('tempdb', 'Updateability')))


Select @save_old_SysDB_Updateability = @save_SysDB_Updateability
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'Updateability' and DBname = 'tempdb')
   begin
	Select @save_old_SysDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'Updateability' and DBname = 'tempdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''Updateability''))'
If @save_old_SysDB_Updateability <> @save_SysDB_Updateability
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Updateability_change', 'Warning', 'High', @save_test, 'tempdb', @save_SysDB_Updateability, @save_old_SysDB_Updateability, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''updateability''))'
IF @save_SysDB_Updateability = 'READ_ONLY'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Updateability', 'fail', 'High', @save_test, 'tempdb', @save_SysDB_Updateability, 'READ_ONLY mode at this time', getdate())
   end
ELSE
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Updateability', 'pass', 'High', @save_test, 'tempdb', @save_SysDB_Updateability, null, getdate())
   end


SELECT @save_SysDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX('tempdb', 'UserAccess')))


Select @save_old_SysDB_UserAccess = @save_SysDB_UserAccess
If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'UserAccess' and DBname = 'tempdb')
   begin
	Select @save_old_SysDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'SysDB_tempdb' and HCtype = 'UserAccess' and DBname = 'tempdb' order by hc_id desc)
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''UserAccess''))'
If @save_old_SysDB_UserAccess <> @save_SysDB_UserAccess
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'UserAccess_change', 'Warning', 'High', @save_test, 'tempdb', @save_SysDB_UserAccess, @save_old_SysDB_UserAccess, getdate())
   end


Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''tempdb'', ''UserAccess''))'
IF @save_SysDB_UserAccess = 'MULTI_USER'
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'UserAccess', 'pass', 'High', @save_test, 'tempdb', @save_SysDB_UserAccess, null, getdate())
   end
Else
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'UserAccess', 'fail', 'High', @save_test, 'tempdb', @save_SysDB_UserAccess, null, getdate())
   end


Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM tempdb.sys.databases WITH (NOLOCK) WHERE name = ''tempdb'''


SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM tempdb.sys.databases WITH (NOLOCK) WHERE name = 'tempdb')
IF @save_DB_owner = 'sa'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'DB Owner', 'Pass', 'Medium', @save_test, 'tempdb', @save_DB_owner, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'DB Owner', 'Fail', 'Medium', @save_test, 'tempdb', @save_DB_owner, 'tempdb owner should be "sa"', getdate())
   END


Select @save_test = 'SELECT recovery_model_desc FROM tempdb.sys.databases WITH (NOLOCK) WHERE name = ''tempdb'''


SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM tempdb.sys.databases WITH (NOLOCK) WHERE name = 'tempdb')
IF @save_RecoveryModel = 'SIMPLE'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Recoverytempdb', 'Pass', 'Medium', @save_test, 'tempdb', @save_RecoveryModel, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Recoverytempdb', 'Fail', 'Medium', @save_test, 'tempdb', @save_RecoveryModel, 'tempdb recovery tempdb should be SIMPLE', getdate())
   END


--  Check for tempdb guest
Select @save_test = 'SELECT 1 FROM tempdb.sys.sysusers WITH (NOLOCK) WHERE name = ''guest'' AND status = 0 AND hasdbaccess = 1'


IF EXISTS(SELECT 1 FROM tempdb.sys.sysusers WITH (NOLOCK) WHERE name = 'guest' AND status = 0 AND hasdbaccess = 1)
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_guest', 'Pass', 'Medium', @save_test, 'tempdb', null, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_guest', 'Fail', 'Medium', @save_test, 'tempdb', null, 'Guest needs to have access to Tempdb', getdate())
   END


--  check for file sizes and growth sizes.
SELECT @cmd = 'select s.fileid, s.groupid, null, s.size, s.growth, s.status, s.name from tempdb.sys.sysfiles s, tempdb.sys.database_files f where s.fileid = f.file_id'
Select @save_test = @cmd


delete from #db_files
INSERT INTO #db_files EXEC (@cmd)
--select * from #db_files


--  Make sure at least one log file is growable.
If exists (select 1 from #db_files where groupid = 0 and growth <> 0)
   begin
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growable', 'Pass', 'Medium', @save_test, 'tempdb', 'At least one log file for TempDB is growable', null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growable', 'Fail', 'Medium', @save_test, 'tempdb', 'No growable log files found for TempDB', null, getdate())
   END


Start_tempdb_file_size:


Select @save_fileid = (select top 1 fileid from #db_files)
Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
Select @save_filename = (select name from #db_files where fileid = @save_fileid)


If (select groupid from #db_files where fileid = @save_fileid) = 0
   begin
	If @save_filesize < 65536
	   begin
		Select @cmd = 'ALTER DATABASE tempdb MODIFY FILE (NAME = ''' + @save_filename + ''', SIZE = 512MB)'
		EXEC (@cmd)
	   end


	If @save_filesize >= 65536
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Size', 'Pass', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_filesize) + 'KB', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Size', 'Fail', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 512MB', getdate())
	   END

	Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
	If (select growth from master.sys.master_files where name = @save_filename) < 32768
	   begin
		Select @cmd = 'ALTER DATABASE tempdb MODIFY FILE (NAME = ''' + @save_filename + ''', FILEGROWTH = 256MB)'
		EXEC (@cmd)
	   end


	If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growth', 'Fail', 'Medium', @save_test, 'tempdb', 'Growth by percentage is set for file ' + @save_filename, 'File growth size should be 256MB', getdate())
	   END
	Else If @save_growthsize >= 32768
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growth', 'Pass', 'Medium', @save_test, 'tempdb', @save_filename + ' file growth is ' + convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
	   END
	Else If @save_growthsize = 0
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growth', 'Pass', 'Medium', @save_test, 'tempdb', @save_filename + ' file growth Set to zero', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Log File Growth', 'Fail', 'Medium', @save_test, 'tempdb', @save_filename + ' file growth is ' + convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 256MB', getdate())
	   END
   end
Else
   begin
	Select @save_filesize = (select size from #db_files where fileid = @save_fileid)
	If @save_filesize < 131072
	   begin
		Select @cmd = 'ALTER DATABASE tempdb MODIFY FILE (NAME = ''' + @save_filename + ''', SIZE = 1024MB)'
		EXEC (@cmd)
	   end


	If @save_filesize >= 131072
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Data File Size', 'Pass', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_filesize) + 'KB', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Data File Size', 'Fail', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_filesize) + 'KB', 'File size should be minimum 1GB (1024MB)', getdate())
	   END

	Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)
	If (select growth from master.sys.master_files where name = @save_filename) < 65536
	   begin
		Select @cmd = 'ALTER DATABASE tempdb MODIFY FILE (NAME = ''' + @save_filename + ''', FILEGROWTH = 512MB)'
		EXEC (@cmd)
	   end


	If (select (case when (status & 0x100000 = 0x100000) then 1 else 0 end) from #db_files where fileid = @save_fileid) = 1
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Data File Growth', 'Fail', 'Medium', @save_test, 'tempdb', 'Growth by percentage is set', 'File growth size should be 512MB', getdate())
	   END
	Else If @save_growthsize >= 65536
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Data File Growth', 'Pass', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_growthsize) + 'KB', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Data File Growth', 'Fail', 'Medium', @save_test, 'tempdb', convert(varchar(20), @save_growthsize) + 'KB', 'File growth size should be minimum 512MB', getdate())
	   END
   end


delete from #db_files where fileid = @save_fileid
If (select count(*) from #db_files) > 0
   begin
	goto Start_tempdb_file_size
   end


--  Check for tempdb file location


--  Get the system DB path
SELECT @save_master_filepath = (SELECT filename FROM master.sys.sysfiles WITH (NOLOCK) WHERE fileid = 1)
SELECT @save_master_filepath = REVERSE(@save_master_filepath)
SELECT @charpos = CHARINDEX('\', @save_master_filepath)
IF @charpos <> 0
   BEGIN
	SELECT @save_master_filepath = SUBSTRING(@save_master_filepath, @charpos+1, LEN(@save_master_filepath))
   END
SELECT @save_master_filepath = REVERSE(@save_master_filepath)


SELECT @save_tempdb_filedrive = (SELECT physical_name FROM tempdb.sys.database_files WITH (NOLOCK) WHERE FILE_ID = 1)
SELECT @charpos = CHARINDEX('\', @save_tempdb_filedrive)
IF @charpos <> 0
   BEGIN
	SELECT @save_tempdb_filedrive = LEFT(@save_tempdb_filedrive, @charpos) + '%'
   END


Select @save_test = 'SELECT 1 FROM tempdb.sys.sysfiles WITH (NOLOCK) WHERE groupid <> 0 AND filename LIKE ''' + @save_master_filepath + '%'''
IF EXISTS(SELECT 1 FROM tempdb.sys.sysfiles WITH (NOLOCK) WHERE groupid <> 0 AND filename LIKE @save_master_filepath + '%')
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_filepath', 'Pass', 'Low', @save_test, 'tempdb', @save_tempdb_filedrive, 'tempdb has not been moved from the original install path', getdate())
	goto skip_tempdb_check
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_filepath', 'Pass', 'Low', @save_test, 'tempdb', @save_tempdb_filedrive, 'tempdb has been moved', getdate())
   END


--  Check for tempdb files alone (tempdb has been moved - no other DB files should share that drive)
Select @save_test = 'SELECT COUNT(*) FROM master.sys.master_files WHERE name NOT IN (SELECT name FROM tempdb.sys.database_files) AND Physical_name LIKE ''' + @save_tempdb_filedrive + ''''
IF (SELECT COUNT(*) FROM master.sys.master_files
	WHERE name = 'master'
	AND Physical_name LIKE @save_tempdb_filedrive) > 0
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_alone', 'Pass', 'Low', @save_test, 'tempdb', @save_tempdb_filedrive, null, getdate())
 END
Else IF (SELECT COUNT(*) FROM master.sys.master_files
	WHERE name NOT IN (SELECT name FROM tempdb.sys.database_files)
	AND name not like '%temp%'
	AND Physical_name LIKE @save_tempdb_filedrive) = 0
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_alone', 'Pass', 'Low', @save_test, 'tempdb', @save_tempdb_filedrive, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_alone', 'Fail', 'Low', @save_test, 'tempdb', @save_tempdb_filedrive, 'Other DB files were found on the tempdb drive', getdate())
   END


--  Check for number of tempdb files
SELECT @save_tempdb_filecount = (SELECT count(*) FROM tempdb.sys.sysfiles WITH (NOLOCK) WHERE groupid <> 0)
SELECT @save_tempdb_corecount = (SELECT ISNULL(NULLIF(CPUcore,'Unknown'),1) FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
SELECT @save_tempdb_corecount = REPLACE(@save_tempdb_corecount, 'core(s)', '')
SELECT @save_tempdb_corecount = REPLACE(@save_tempdb_corecount, 'cores', '')
SELECT @save_tempdb_corecount = REPLACE(@save_tempdb_corecount, 'core', '')
SELECT @save_tempdb_corecount = RTRIM(LTRIM(@save_tempdb_corecount))

If convert(int, @save_tempdb_corecount) > 8
   begin
	 SELECT @save_tempdb_corecount = 8
   end


IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'SQLHealth' AND detail01 = 'TempDB_FileCount')
   BEGIN
	SELECT @save_tempdb_corecount = (SELECT CONVERT(INT, detail03) FROM dbo.no_check WHERE NoCheck_type = 'SQLHealth' AND detail01 = 'TempDB_FileCount')
   END


select @save_tempdb_filecount_int = convert(int,@save_tempdb_filecount)
select @save_tempdb_corecount_int = convert(int,@save_tempdb_corecount)


Select @save_test = 'SELECT COUNT(*) FROM master.sys.master_files WHERE name NOT IN (SELECT name FROM tempdb.sys.database_files) AND Physical_name LIKE ''' + @save_tempdb_filedrive + ''''
IF @save_tempdb_filecount_int < @save_tempdb_corecount_int
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_filecount', 'Fail', 'Medium', @save_test, 'tempdb', convert(varchar(5), @save_tempdb_filecount), 'File count does not match core count: ' + convert(varchar(5), @save_tempdb_corecount), getdate())
   END
ELSE IF @save_tempdb_filecount_int > @save_tempdb_corecount_int
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_filecount', 'Pass', 'Medium', @save_test, 'tempdb', convert(varchar(5), @save_tempdb_filecount), 'Recomend ' + convert(varchar(5), @save_tempdb_corecount), getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('SysDB_tempdb', 'Tempdb_filecount', 'Pass', 'Medium', @save_test, 'tempdb', convert(varchar(5), @save_tempdb_filecount), null, getdate())
   END


skip_tempdb_check:


Print '--select * from [dbo].[HealthCheckLog] where HCcat like ''SysDB%'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #db_files
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_SysDB_General] TO [public]
GO
