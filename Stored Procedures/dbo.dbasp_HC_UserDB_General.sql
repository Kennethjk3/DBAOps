SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_UserDB_General]


/*********************************************************
 **  Stored Procedure dbasp_HC_UserDB_General
 **  Written by Steve Ledridge, Virtuoso
 **  February 03, 2015
 **  This procedure runs the User DB portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/03/2015	Steve Ledridge		New process.
--	04/24/2015	Steve Ledridge		Do not fix DB files set for no autogrow.
--	12/21/2015	Steve Ledridge		Skip DBCC check for new DB's.
--	03/07/2016	Steve Ledridge		Auto fix DB owner if owner by a DBA.
--	03/10/2016	Steve Ledridge		New code for avail grps.
--	03/22/2016	Steve Ledridge		New code for DB SemanticsDB.
--	08/08/2016	Steve Ledridge		Modified code for avail grp DB resolving.
--	01/25/2017	Steve Ledridge		Added Check for Service Broker Queues
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  check for recent status change
--  check DB status, Updateability and UserAccess
--  check DB Settings (collation, comparison Style, IsAnsiNullDefault, IsAnsiNullsEnabled, IsAnsiPaddingEnabled, IsAnsiWarningsEnabled,
--			IsArithmeticAbortEnabled, IsAutoClose, IsAutoCreateStatistics, IsAutoShrink, IsAutoUpdateStatistics, IsCloseCursorsOnCommitEnabled
--			IsInStandBy, IsLocalCursorsDefault, IsMergePublished, IsNullConcat, IsNumericRoundAbortEnabled, IsParameterizationForced, IsPublished
--			IsRecursiveTriggersEnabled, IsSubscribed, IsSyncWithBackup, IsTornPageDetectionEnabled, LCID, SQLSortOrder)
--  check for auto close, auto shrink, auto create stats, qauto update stats
--  check DB security (DB owner)
--  Check Recovery Model
--  check UserDB page verify
--  Check Backups
--  check orphaned users (Drop users orphaned for more than 7 days)
--  check Build Table
--  check for last DBCC (within the last 5 weeks)
--  check for High VLF Count
--  check DB and file growth settings
--  check for activity in past 30 days
--  add DBAaspir to db_datareader if needed
--  Check certificates
--  check LDF Growth Duration
--  check Serfvice Broker Queues


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(4000)
	,@sqlcmd				nvarchar(4000)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@save_detail01				nvarchar(4000)
	,@save_detail02				nvarchar(4000)
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@save_DBname				sysname
	,@hold_DBname				sysname
	,@nocheck_backup_flag			CHAR(1)
	,@nocheck_maint_flag			CHAR(1)
	,@save_UserDB_Status			sysname
	,@save_UserDB_Updateability		sysname
	,@save_UserDB_UserAccess		sysname
	,@save_old_UserDB_Status		sysname
	,@save_old_UserDB_Updateability		sysname
	,@save_old_UserDB_UserAccess		sysname
	,@save_name				sysname
	,@save_DBid				INT
	,@save_oldvalue				nvarchar(4000)
	,@save_newvalue				nvarchar(4000)
	,@save_ACid				int
	,@save_tbl_id				int
	,@save_text01				sysname
	,@save_text02				nvarchar(4000)
	,@save_text03				nvarchar(4000)
	,@save_SQLSvcAcct			sysname
	,@save_DB_owner				sysname
	,@save_check	    			sysname
	,@save_AvailGrp				char(1)
	,@a					int
	,@save_DBCC_date			datetime
	,@save_VLFcount				int
	,@save_fileid				smallint
	,@save_filename				sysname
	,@save_growthsize			bigint
	,@save_CertName				sysname
	,@save_pvt_key_last_backup_date		varchar(100)
	,@path					NVARCHAR(256)


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


CREATE TABLE 	#miscTempTable (cmdoutput NVARCHAR(400) NULL
			,AvailGrp char(1) null
			)


CREATE TABLE #temp_tbl	(tbl_id [int] IDENTITY(1,1) NOT NULL
			,text01	sysname null
			,text02 nvarchar(4000) null
			,text03 nvarchar(4000) null
			)


CREATE TABLE #DBCCs (ID INT IDENTITY(1, 1) PRIMARY KEY
			, ParentObject VARCHAR(255)
			, Object VARCHAR(255)
			, Field VARCHAR(255)
			, Value VARCHAR(255)
			, DbName NVARCHAR(128) NULL
			)


CREATE TABLE #db_files (fileid SMALLINT
			,groupid SMALLINT
			,groupname sysname null
			,size bigINT
			,growth INT
			,status INT
			,name sysname)


CREATE TABLE #db_cert (CertName sysname
			,pvt_key_last_backup_date VARCHAR(100) null)


CREATE TABLE #SpecificSBQs (Name SYSNAME)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - USER DB General'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Get the DB names to be processed
DELETE FROM #miscTempTable
INSERT INTO #miscTempTable
SELECT		name, 'n'
FROM		master.sys.databases
WHERE		database_id > 4
		AND source_database_id IS NULL
		AND name not in ('SemanticsDB', 'DBAOps', 'dbaperf', 'DBAOps', 'DBAcentral', 'DBAperf_reports', 'DEPLOYcentral')
--select * from #miscTempTable


--  Mark any AvailGrp DB's
IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
   begin
	Update #miscTempTable set AvailGrp = 'y' where cmdoutput in (Select dbcs.database_name
					FROM master.sys.availability_groups AS AG
					LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
					   ON AG.group_id = agstates.group_id
					INNER JOIN master.sys.availability_replicas AS AR
					   ON AG.group_id = AR.group_id
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					   ON arstates.replica_id = dbcs.replica_id
					LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
					   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id)
   end


--  Start the User DB Check process
IF (SELECT COUNT(*) FROM #miscTempTable) > 0
   BEGIN
	start_databases:
	SELECT @save_DBname = (SELECT TOP 1 cmdoutput FROM #miscTempTable ORDER BY cmdoutput)
	SELECT @hold_DBname = @save_DBname
	SELECT @save_AvailGrp = (SELECT AvailGrp FROM #miscTempTable where cmdoutput = @save_DBname)
	SELECT @save_DBname = RTRIM(@save_DBname)

	Print ''
	Print 'Start UserDB Processing for DBname ' + @save_DBname
	Print ''


	SELECT @save_DBid = (SELECT database_id FROM sys.databases WHERE name = @save_DBname)


	--  Take a look at the nocheck table
	SELECT @nocheck_backup_flag = 'n'
	IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'backup' AND detail01 = @save_DBname)
	   BEGIN
		SELECT @nocheck_backup_flag = 'y'
	   END


	SELECT @nocheck_maint_flag = 'n'
	IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'maint' AND detail01 = @save_DBname)
	   BEGIN
		SELECT @nocheck_maint_flag = 'y'
	   END


	--  check UserDB Status
	Print 'Start UserDB status check'
	Print ''


	SELECT @save_UserDB_Status = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'Status')))


	Select @save_old_UserDB_Status = @save_UserDB_Status
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'Status' and DBname = @save_DBname)
	   begin
		Select @save_old_UserDB_Status = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'Status' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Status''))'
	If @save_old_UserDB_Status <> @save_UserDB_Status
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status_change', 'Warning', 'High', @save_test, @save_DBname, @save_UserDB_Status, @save_old_UserDB_Status, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Status''))'
	IF @save_UserDB_Status = 'RESTORING' AND EXISTS (SELECT 1 FROM master.sys.database_mirroring WHERE database_id = @save_DBid AND mirroring_guid IS NOT NULL)
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Pass', 'Medium', @save_test, @save_DBname, @save_UserDB_Status, 'Mirrored copy of the database pending failover', getdate())
	   end
	Else IF @save_UserDB_Status = 'RESTORING'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Pass', 'Medium', @save_test, @save_DBname, @save_UserDB_Status, 'pending restore completion', getdate())
	   end
	ELSE IF @save_UserDB_Status = 'OFFLINE'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Fail', 'High', @save_test, @save_DBname, @save_UserDB_Status, 'OFFLINE at this time', getdate())
	   end
	ELSE IF @save_UserDB_Status <> 'ONLINE'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Fail', 'High', @save_test, @save_DBname, @save_UserDB_Status, null, getdate())
	   end
	ELSE
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Pass', 'High', @save_test, @save_DBname, @save_UserDB_Status, null, getdate())
	   end


	Select @save_test = 'select top 1 cast(OldValue as varchar(4000)), cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where Tablename = ''DBA_DBInfo'' and ColumnName = ''status'' and DataKey = ''' + @save_DBname + ''' and moddate > getdate()-.5 order by DBA_ACid desc'
	If exists (select 1 from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'status' and DataKey = @save_DBname and moddate > getdate()-.5)
	   begin
		Select @save_ACid = (Select top 1 DBA_ACid from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'status' and DataKey = @save_DBname and moddate > getdate()-.5 order by DBA_ACid desc)
		Select @save_oldvalue = (select cast(OldValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)
		Select @save_newvalue = (select cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)


		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Status', 'Warning', 'High', @save_test, @save_DBname, 'DB Status Change', 'From ' + @save_oldvalue + ' to ' + @save_newvalue, getdate())
	   end


	--  check UserDB updateability
	Print 'Start UserDB Updateability check'
	Print ''


	SELECT @save_UserDB_Updateability = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'Updateability')))


	Select @save_old_UserDB_Updateability = @save_UserDB_Updateability
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'Updateability' and DBname = @save_DBname)
	   begin
		Select @save_old_UserDB_Updateability = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'Updateability' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Updateability''))'
	If @save_old_UserDB_Updateability <> @save_UserDB_Updateability
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability_change', 'Warning', 'High', @save_test, @save_DBname, @save_UserDB_Updateability, @save_old_UserDB_Updateability, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''updateability''))'
	IF @save_UserDB_Updateability = 'READ_ONLY'
	   begin
		If @save_AvailGrp = 'y'
		   begin
			If (Select arstates.role_desc
					FROM master.sys.availability_replicas AS AR
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					   ON arstates.replica_id = dbcs.replica_id
					where AR.replica_server_name = @@servername
					and dbcs.database_name = @save_DBname) = 'SECONDARY'
			   begin
				insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability', 'Pass', 'Medium', @save_test, @save_DBname, @save_UserDB_Updateability, 'Secondary AvailGrp database', getdate())
			   end
			Else
			   begin
				insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability', 'Fail', 'Medium', @save_test, @save_DBname, @save_UserDB_Updateability, 'Primary AvailGrp database', getdate())
			   end
		   end
		Else IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'logship' AND detail01 = @save_DBname)
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability', 'Pass', 'Medium', @save_test, @save_DBname, @save_UserDB_Updateability, 'Logshipping database', getdate())
		   end
		Else
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability', 'Warning', 'Medium', @save_test, @save_DBname, @save_UserDB_Updateability, 'READ_ONLY mode at this time', getdate())
		   end
	   end
	ELSE
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Updateability', 'Pass', 'High', @save_test, @save_DBname, @save_UserDB_Updateability, null, getdate())
	   end


	--  check UserDB UserAccess
	Print 'Start UserDB UserAccess check'
	Print ''


	SELECT @save_UserDB_UserAccess = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'UserAccess')))


	Select @save_old_UserDB_UserAccess = @save_UserDB_UserAccess
	If exists (select 1 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'UserAccess' and DBname = @save_DBname)
	   begin
		Select @save_old_UserDB_UserAccess = (select top 1 Check_detail01 from [dbo].[HealthCheckLog] where HCcat = 'UserDB' and HCtype = 'UserAccess' and DBname = @save_DBname order by hc_id desc)
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''UserAccess''))'
	If @save_old_UserDB_UserAccess <> @save_UserDB_UserAccess
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'UserAccess_change', 'Warning', 'High', @save_test, @save_DBname, @save_UserDB_UserAccess, @save_old_UserDB_UserAccess, getdate())
	   end


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''UserAccess''))'
	IF @save_UserDB_UserAccess = 'MULTI_USER'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'UserAccess', 'Pass', 'High', @save_test, @save_DBname, @save_UserDB_UserAccess, null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'UserAccess', 'Warning', 'High', @save_test, @save_DBname, @save_UserDB_UserAccess, null, getdate())
	   end


	--  check UserDB Settings
	Print 'Start UserDB Settings check'
	Print ''


	Select @save_test = 'select top 1 cast(OldValue as varchar(4000)), cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where Tablename = ''DBA_DBInfo'' and ColumnName = ''DB_Settings'' and DataKey = @save_DBname and moddate > getdate()-.5 order by DBA_ACid desc'


	If exists (select 1 from [dbo].[DBA_AuditChanges]
				where Tablename = 'DBA_DBInfo'
				and ColumnName = 'DB_Settings'
				and DataKey = @save_DBname
				and OldValue <> NewValue
				and moddate > getdate()-.5)
	   begin
		delete from #temp_tbl
		Insert into #temp_tbl values('DBowner', null, null)
		Insert into #temp_tbl values('is_read_only', null, null)
		Insert into #temp_tbl values('is_auto_close_on', null, null)
		Insert into #temp_tbl values('is_auto_shrink_on', null, null)
		Insert into #temp_tbl values('is_in_standby', null, null)
		Insert into #temp_tbl values('is_cleanly_shutdown', null, null)
		Insert into #temp_tbl values('is_supplemental_logging_enabled', null, null)
		Insert into #temp_tbl values('snapshot_isolation_state', null, null)
		Insert into #temp_tbl values('is_read_committed_snapshot_on', null, null)
		Insert into #temp_tbl values('is_auto_create_stats_on', null, null)
		Insert into #temp_tbl values('is_auto_update_stats_on', null, null)
		Insert into #temp_tbl values('is_auto_update_stats_async_on', null, null)
		Insert into #temp_tbl values('is_ansi_null_default_on', null, null)
		Insert into #temp_tbl values('is_ansi_nulls_on', null, null)
		Insert into #temp_tbl values('is_ansi_padding_on', null, null)
		Insert into #temp_tbl values('is_ansi_warnings_on', null, null)
		Insert into #temp_tbl values('is_arithabort_on', null, null)
		Insert into #temp_tbl values('is_concat_null_yields_null_on', null, null)
		Insert into #temp_tbl values('is_numeric_roundabort_on', null, null)
		Insert into #temp_tbl values('is_quoted_identifier_on', null, null)
		Insert into #temp_tbl values('is_recursive_triggers_on', null, null)
		Insert into #temp_tbl values('is_cursor_close_on_commit_on', null, null)
		Insert into #temp_tbl values('is_local_cursor_default', null, null)
		Insert into #temp_tbl values('is_db_chaining_on', null, null)
		Insert into #temp_tbl values('is_parameterization_forced', null, null)
		Insert into #temp_tbl values('is_master_key_encrypted_by_server', null, null)
		Insert into #temp_tbl values('is_published', null, null)
		Insert into #temp_tbl values('is_subscribed', null, null)
		Insert into #temp_tbl values('is_merge_published', null, null)
		Insert into #temp_tbl values('is_distributor', null, null)
		Insert into #temp_tbl values('is_sync_with_backup', null, null)
		Insert into #temp_tbl values('is_broker_enabled', null, null)
		Insert into #temp_tbl values('is_date_correlation_on', null, null)
		--Insert into #temp_tbl values('is_cdc_enabled', null, null)
		--Insert into #temp_tbl values('is_encrypted', null, null)
		--Insert into #temp_tbl values('is_honor_broker_priority_on', null, null)


		Select @save_test = 'select top 1 cast(OldValue as varchar(4000)), cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where Tablename = ''DBA_DBInfo'' and ColumnName = ''DB_Settings'' and DataKey = ''' + @save_DBname + ''' and moddate > getdate()-.5 order by DBA_ACid desc'


		If exists (select 1 from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'DB_Settings' and DataKey = @save_DBname and moddate > getdate()-.5)
		   begin
			Select @save_ACid = (Select top 1 DBA_ACid from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'DB_Settings' and DataKey = @save_DBname and moddate > getdate()-.5 order by DBA_ACid desc)
			Select @save_oldvalue = (select cast(OldValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)
			Select @save_newvalue = (select cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)


			Update #temp_tbl set text02 = SplitValue FROM [DBAOps].[dbo].[dbaudf_StringToTable](@save_oldvalue,',') where OccurenceId = tbl_id
			Update #temp_tbl set text03 = SplitValue FROM [DBAOps].[dbo].[dbaudf_StringToTable](@save_newvalue,',') where OccurenceId = tbl_id


			delete from #temp_tbl where text02 = text03
			delete from #temp_tbl where text02 is null and text03 is null
			update #temp_tbl set text02 = '' where text02 is null
			update #temp_tbl set text03 = '' where text03 is null

			If (select count(*) from #temp_tbl) > 0
			   begin
				start_DBA_ACid02:
				Select @save_tbl_id = (select top 1 tbl_id from #temp_tbl)
				Select @save_text01 = text01 from #temp_tbl where tbl_id = @save_tbl_id
				Select @save_text02 = (select text02 from #temp_tbl where tbl_id = @save_tbl_id)
				Select @save_text03 = (select text03 from #temp_tbl where tbl_id = @save_tbl_id)


				insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Settings', 'Fail', 'Medium', @save_test, @save_DBname, 'DB Settings have changed for ' + @save_text01 , 'From ' + @save_text02 + ' to ' + @save_text03, getdate())


				delete from #temp_tbl where tbl_id = @save_tbl_id
				If (select count(*) from #temp_tbl) > 0
				   begin
					goto start_DBA_ACid02
				   end
			   end
		   end
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Settings', 'Pass', 'Medium', @save_test, @save_DBname, 'DB Settings have not changed', null, getdate())
	   end


	--  check UserDB Auto Close
	Print 'Start UserDB Auto Close check'
	Print ''


	Select @save_test = 'select is_auto_close_on from master.sys.databases where name = @save_DBname'


	If (select is_auto_close_on from master.sys.databases where name = @save_DBname) = 1
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Close', 'Fail', 'High', @save_test, @save_DBname, 'Auto Close should not be set for this DB.', null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Close', 'Pass', 'High', @save_test, @save_DBname, null, null, getdate())
	   end


	--  check UserDB Auto Shrink
	Print 'Start UserDB Auto Shrink check'
	Print ''


	Select @save_test = 'select is_auto_shrink_on from master.sys.databases where name = @save_DBname'


	If (select is_auto_shrink_on from master.sys.databases where name = @save_DBname) = 1
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Shrink', 'Fail', 'High', @save_test, @save_DBname, 'Auto Shrink should not be set for this DB.', null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Shrink', 'Pass', 'High', @save_test, @save_DBname, null, null, getdate())
	   end


	--  If the database is not online, skip the Remaining checks
	If @save_UserDB_Status <> 'ONLINE'
	 or (SELECT is_read_only FROM sys.databases WHERE name = @save_DBname) = 1
	   begin
		goto skip_11
	   end


	--  check UserDB Auto Create Stats
	Print 'Start UserDB Auto Create Stats check'
	Print ''


	Select @save_test = 'select is_auto_create_stats_on from master.sys.databases where name = @save_DBname'


	If (select is_auto_create_stats_on from master.sys.databases where name = @save_DBname) = 0
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Create Stats', 'Fail', 'High', @save_test, @save_DBname, 'Auto Create Stats should be set for this DB.', null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Create Stats', 'Pass', 'High', @save_test, @save_DBname, null, null, getdate())
	   end


	--  check UserDB Auto Update Stats
	Print 'Start UserDB Auto Update Stats check'
	Print ''


	Select @save_test = 'select is_auto_update_stats_on from master.sys.databases where name = @save_DBname'


	If (select is_auto_update_stats_on from master.sys.databases where name = @save_DBname) = 0
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Update Stats', 'Fail', 'High', @save_test, @save_DBname, 'Auto Update Stats should be set for this DB.', null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Auto Update Stats', 'Pass', 'High', @save_test, @save_DBname, null, null, getdate())
	   end


	--  check UserDB Owner
	Print 'Start UserDB Owner check'
	Print ''


	Select @save_SQLSvcAcct = (Select SQLSvcAcct from dbo.DBA_ServerInfo where SQLName = @@servername)


	Select @save_test = 'SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = ''' + @save_DBname + ''''


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
	If @save_DB_owner like 'DBA%' or @save_DB_owner like '%jwilson%' or @save_DB_owner like '%jbrown%' or @save_DB_owner like '%sledridge%'
	   begin
		If @save_AvailGrp = 'y'
		   begin
			If (Select arstates.role_desc
					FROM master.sys.availability_replicas AS AR
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					   ON arstates.replica_id = dbcs.replica_id
					where AR.replica_server_name = @@servername
					and dbcs.database_name = @save_DBname) <> 'SECONDARY'
			   begin
				Select @sqlcmd = 'ALTER AUTHORIZATION ON DATABASE::[' + @save_DBname + '] TO sa;'
				exec (@sqlcmd)
				SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
			   end
		   end
		Else
		   begin
			Select @sqlcmd = 'ALTER AUTHORIZATION ON DATABASE::[' + @save_DBname + '] TO sa;'
			exec (@sqlcmd)
			SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)
		   end
	   end


	IF EXISTS (SELECT 1 FROM dbo.no_check
				WHERE NoCheck_type = 'DBowner'
				AND (detail01 = @save_DBname or detail01 = 'AllDBs')
				AND detail02 = @save_DB_owner)
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Pass', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'Approved by nocheck.', getdate())
	   end
	Else If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) = 'SECONDARY'
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Pass', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'AG Secondary DB.', getdate())
		   end
	   end
	Else IF EXISTS (SELECT 1 FROM dbo.No_Check WHERE NoCheck_type = 'DBowner' AND Detail02 = @save_DB_owner and (Detail01 = @save_DBname or Detail01 = 'AllDBs'))
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Pass', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'DB Owner override in dbo.No_Check', getdate())
	   end
	Else If @save_DB_owner = 'sa'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Pass', 'Medium', @save_test, @save_DBname, @save_DB_owner, null, getdate())
	   end
	Else If @save_DB_owner LIKE '%' + @save_SQLSvcAcct + '%'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Fail', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'Owner is set to the SQL service account.  Updated to "sa"', getdate())
		SELECT @cmd = 'ALTER AUTHORIZATION ON DATABASE::' + @save_DBname + ' TO sa;'
		--Print '		'+@cmd
		EXEC master.sys.sp_executeSQL @cmd
	   end
	Else If @save_DB_owner is null
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Fail', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'Owner is null - should be "sa"', getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DB Owner', 'Fail', 'Medium', @save_test, @save_DBname, @save_DB_owner, 'Owner should be "sa"', getdate())
	   end


	--  check UserDB Recovery Model
	Print 'Start UserDB Recovery Model check'
	Print ''


	Select @save_test = 'SELECT CONVERT(sysname, DATABASEPROPERTYEX(''' + @save_DBname + ''', ''Recovery''))'
	SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, 'Recovery')))


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'RecovModel', 'Pass', 'Medium', @save_test, @save_DBname, @save_check, null, getdate())
	   end
	Else If @save_check = 'FULL' and @save_AvailGrp = 'y'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'RecovModel', 'Pass', 'Medium', @save_test, @save_DBname, @save_check, 'AvailGrp DB', getdate())
	   end
	Else If @save_check = 'FULL'
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'RecovModel', 'Fail', 'Medium', @save_test, @save_DBname, @save_check, 'Recovery model should be SIMPLE', getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'RecovModel', 'Pass', 'Medium', @save_test, @save_DBname, @save_check, null, getdate())
	   end


	Select @save_test = 'select top 1 cast(OldValue as varchar(4000)), cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where Tablename = ''DBA_DBInfo'' and ColumnName = ''RecovModel'' and DataKey = ''' + @save_DBname + ''' and moddate > getdate()-.5 order by DBA_ACid desc'
	If exists (select 1 from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'RecovModel' and DataKey = @save_DBname and moddate > getdate()-.5)
	   begin
		Select @save_ACid = (Select top 1 DBA_ACid from [dbo].[DBA_AuditChanges] where Tablename = 'DBA_DBInfo' and ColumnName = 'RecovModel' and DataKey = @save_DBname and moddate > getdate()-.5 order by DBA_ACid desc)
		Select @save_oldvalue = (select cast(OldValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)
		Select @save_newvalue = (select cast(NewValue as varchar(4000)) from [dbo].[DBA_AuditChanges] where DBA_ACid = @save_ACid)


		insert into [dbo].[HealthCheckLog] values ('UserDB', 'RecovModel', 'Warning', 'High', @save_test, @save_DBname, 'RecovModel Change', 'From ' + @save_oldvalue + ' to ' + @save_newvalue, getdate())
	   end


	--  check UserDB page verify
	Print 'Start UserDB Page Verify check'
	Print ''


	Select @save_test = 'SELECT page_verify_option_desc from master.sys.databases where name = ''' + @save_DBname + ''''


	If (select page_verify_option from master.sys.databases where name = @save_DBname) = 2
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Page Verify', 'Pass', 'Medium', @save_test, @save_DBname, 'CHECKSUM', null, getdate())
	   end
	Else
	   begin
		BEGIN TRY
			select @cmd = 'ALTER DATABASE ' + quotename(@save_DBname) + ' SET PAGE_VERIFY CHECKSUM WITH ROLLBACK IMMEDIATE'
			exec (@cmd)
		END TRY
		BEGIN CATCH
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Page Verify', 'Warning', 'Medium', @save_test, @save_DBname, 'Unable to Change to CHECKSUM', null, getdate())
			goto end_page_verify
		END CATCH


		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Page Verify', 'Warning', 'Medium', @save_test, @save_DBname, 'Changed to CHECKSUM', null, getdate())
	   end


	end_page_verify:


	--  check UserDB Backups
	Print 'Start UserDB Backup check'
	Print ''


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) <> 'production'
	   BEGIN
		Print 'Skip Backup check for DB ' + @save_DBname + '.  This check only done for production.'
		Print ''
	   END
	Else IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'backup' AND detail01 = @save_DBname)
	   BEGIN
		Print 'Skip Backup check for DB ' + @save_DBname + '.  No_check record found for this DB.'
		Print ''
	   END
	Else If @save_AvailGrp = 'y'
	   begin
		If (select sys.fn_hadr_backup_is_preferred_replica(@save_DBname)) = 0
		   BEGIN
			Print 'Skip Backup check for DB ' + @save_DBname + '.  Not the preferred backup location for this DB.'
			Print ''
		   END
		Else
		   BEGIN
			exec dbo.dbasp_HC_DB_Backups @dbname = @save_DBname, @HCcat = 'UserDB'
		   END
	   END
	Else
	   BEGIN
		exec dbo.dbasp_HC_DB_Backups @dbname = @save_DBname, @HCcat = 'UserDB'
	   END


	--  check UserDB Orphaned Users
	Print 'Start UserDB Orphaned Users check'
	Print ''


	If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) in ('SECONDARY', 'RESOLVING')
		   begin
			Print 'Skip Orphaned Users check for DB ' + @save_DBname + '.  The DB is an AvailGrp and is not available for this check.'
			Print ''
		   end
		Else
		   begin
			exec dbo.dbasp_HC_DB_OrphanedUsers @dbname = @save_DBname, @HCcat = 'UserDB'
		   end
	   end
	Else
	   begin
		exec dbo.dbasp_HC_DB_OrphanedUsers @dbname = @save_DBname, @HCcat = 'UserDB'
	   end


	--  check Build Table
	Print 'Start UserDB Build Table check'
	Print ''


	If @save_DBname not in (select db_name from dbo.db_sequence)
	   begin
		Print 'Skip Build Table check for DB ' + @save_DBname + '.  The DB is not part of the Virtuoso deployment process.'
		Print ''
		goto skip_buildtable
	   end


	If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) = 'SECONDARY'
		   begin
			Print 'Skip Build Table check for DB ' + @save_DBname + '.  The DB is SECONDARY in an AvailGrp.'
			Print ''
			goto skip_buildtable
		   end
	   end


	Select @save_test = 'select * from ' + @save_DBname + '.sys.sysobjects where name = ''build'''


	SELECT @cmd = 'SELECT @a = 1 FROM ' + @save_DBname + '.sys.sysobjects WHERE name = ''build'''
	EXEC sp_executesql @cmd, N'@a int output', @a output


	IF @a = 0
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Build Table', 'Fail', 'Medium', @save_test, @save_DBname, 'Build table is required for this DB.', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'Build Table', 'Pass', 'Medium', @save_test, @save_DBname, null, null, getdate())
	   END


	Select @save_test = 'select * from ' + @save_DBname + '.sys.sysobjects where name = ''builddetail'''


	SELECT @cmd = 'SELECT @a = 1 FROM ' + @save_DBname + '.sys.sysobjects WHERE name = ''builddetail'''
	EXEC sp_executesql @cmd, N'@a int output', @a output


	IF @a = 0
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'BuildDetail Table', 'Fail', 'Medium', @save_test, @save_DBname, 'BuildDetail table is required for this DB.', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'BuildDetail Table', 'Pass', 'Medium', @save_test, @save_DBname, null, null, getdate())
	   END


	   skip_buildtable:


	--  check for last DBCC (within the last 5 weeks)
	Print 'Start UserDB DBCC check'
	Print ''


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) <> 'production'
	   BEGIN
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  This check only done for production.'
		Print ''
		goto skip_DBCC_check
	   END


	If (SELECT user_access FROM sys.databases WHERE name = @save_DBname) = 1
	   begin
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  The DB is in single_user mode.'
		Print ''
		goto skip_DBCC_check
	   END


	If (SELECT create_date FROM sys.databases WHERE name = @save_DBname) > getdate()-8
	   begin
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  The DB is new.'
		Print ''
		goto skip_DBCC_check
	   END


	If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) = 'SECONDARY'
		   begin
			Print 'Skip Build Table check for DB ' + @save_DBname + '.  The DB is SECONDARY in an AvailGrp.'
			Print ''
			goto skip_DBCC_check
		   end
	   end


	If exists (select 1 from dbo.no_check where NoCheck_type = 'DBCC_weekly' and detail01 = @save_DBname)
	   begin
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  NoCheck type ''DBCC_weekly'' found for this DB.'
		Print ''
		goto skip_DBCC_check
	   END


	If exists (select 1 from dbo.no_check where NoCheck_type = 'backup' and detail01 = @save_DBname)
	   begin
		Print 'Skip DBCC check for DB ' + @save_DBname + '.  NoCheck type ''backup'' found for this DB.'
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
	EXEC ('DBCC DBInfo([' + @save_DBname + ']) With TableResults, NO_INFOMSGS')
	delete from #DBCCs where field <> 'dbi_dbccLastKnownGood'
	--select * from #DBCCs


	Select @save_test = 'EXEC (''DBCC DBInfo([' + @save_DBname + ']) With TableResults, NO_INFOMSGS'')'


	If (select count(*) from #DBCCs) > 0
	   begin
		Select @save_DBCC_date = (select top 1 convert(datetime, Value) from #DBCCs where field = 'dbi_dbccLastKnownGood')
		If (datediff(day, @save_DBCC_date, getdate())) < 28
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'DBCC Check', 'Pass', 'High', @save_test, @save_DBname, convert(sysname, @save_DBCC_date), null, getdate())
		   END
		Else
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'DBCC Check', 'Fail', 'High', @save_test, @save_DBname, convert(sysname, @save_DBCC_date), 'Last DBCC CheckDB was more than 28 days ago.', getdate())
		   END


	   end
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'DBCC Check', 'Fail', 'High', @save_test, @save_DBname, 'dbi_dbccLastKnownGood not found for this DB.', 'DBCC status unknown', getdate())
	   END


	skip_DBCC_check:


	--  check for High VLF Count
	Print 'Start UserDB High VLF Count check'
	Print ''


	Select @save_test = 'Select VLFcount from DBAOps.dbo.DBA_DBinfo where DBname = ''' + @save_DBname + ''''


	Select @save_VLFcount = (select VLFcount from dbo.DBA_DBinfo where DBname = @save_DBname and SQLname = @@servername)


	If @save_VLFcount > 999
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'VLF Count', 'Fail', 'Medium', @save_test, @save_DBname, convert(sysname, @save_VLFcount), 'VLF count should be under 999.', getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'VLF Count', 'Pass', 'Medium', @save_test, @save_DBname, convert(sysname, @save_VLFcount), null, getdate())
	   END


	--  check DB and file growth settings
	Print 'Start UserDB File Growth check'
	Print ''


	If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) in ('SECONDARY', 'RESOLVING')
		   begin
			Print 'Skip File Growth check for DB ' + @save_DBname + '.  The DB is an AvailGrp and is not available for this check.'
			Print ''
			goto skip_filegrowth
		   end
	   end


	SELECT @cmd = 'select s.fileid, s.groupid, null, s.size, s.growth, s.status, s.name from [' + @save_DBname + '].sys.sysfiles s, [' + @save_DBname + '].sys.database_files f where s.fileid = f.file_id'
	Select @save_test = @cmd


	delete from #db_files
	INSERT INTO #db_files EXEC (@cmd)
	--select * from #db_files


	If (select count(*) from #db_files) > 0
	   begin
		start_file_growth:


		Select @save_fileid = (select top 1 fileid from #db_files)
		Select @save_filename = (select name from #db_files where fileid = @save_fileid)
    		Select @save_growthsize = (select growth from #db_files where fileid = @save_fileid)


		If @save_growthsize > 0 and @save_growthsize < 32768
		   begin
			BEGIN TRY
				Select @cmd = 'ALTER DATABASE [' + @save_DBname + '] MODIFY FILE (NAME = ''' + @save_filename + ''', FILEGROWTH = 256MB)'
				EXEC (@cmd)
			END TRY
			BEGIN CATCH
				insert into [dbo].[HealthCheckLog] values ('UserDB', 'File Growth', 'Warning', 'Medium', @save_test, @save_DBname, @save_filename, 'Unable to Change growth', getdate())
				goto end_file_growth01
			END CATCH


			insert into [dbo].[HealthCheckLog] values ('UserDB', 'File Growth', 'Warning', 'Medium', @save_test, @save_DBname, @save_filename, 'Changed to 256MB', getdate())
		   end
		Else
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'File Growth', 'Pass', 'Medium', @save_test, @save_DBname, @save_filename, convert(sysname, @save_growthsize), getdate())
		   end


		end_file_growth01:


		Delete from #db_files where fileid = @save_fileid
		If (select count(*) from #db_files) > 0
		   begin
			goto start_file_growth
		   end
	   end


	skip_filegrowth:


	--  check for activity in past 30\90 days
	Print 'Start UserDB Activity check'
	Print ''


	Select @save_SQLSvcAcct = (select top 1 SQLSvcAcct from dbo.dba_serverinfo where sqlname = @@servername)


	If (select SQLEnv from dbo.dba_serverinfo where sqlname = @@servername) = 'production'
	   begin
		Select @save_test = 'select * from [dbo].[DBA_ConnectionInfo] where moddate > getdate()-31 and DBname = ''' + @save_DBname + ''''

		If exists (select 1 from [dbo].[DBA_ConnectionInfo]
				where moddate > getdate()-31
				and DBname = @save_DBname
				and loginname <> 'sa'
				and loginname not like '%' + @save_SQLSvcAcct + '%'
				and hostname not in ('seapdbasql01', 'seapdbasql02', 'seasdbasql01'))
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Activity', 'Pass', 'Low', @save_test, @save_DBname, null, null, getdate())
		   end
		Else
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Activity', 'Warning', 'Low', @save_test, @save_DBname, 'No connections found for the past 30 days.', null, getdate())
		   end
	   end
	Else
	   begin
		Select @save_test = 'select * from [dbo].[DBA_ConnectionInfo] where moddate > getdate()-91 and DBname = ''' + @save_DBname + ''''

		If exists (select 1 from [dbo].[DBA_ConnectionInfo]
				where moddate > getdate()-91
				and DBname = @save_DBname
				and loginname <> 'sa'
				and loginname not like '%' + @save_SQLSvcAcct + '%'
				and hostname not in ('seapdbasql01', 'seapdbasql02', 'seasdbasql01'))
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Activity', 'Pass', 'Low', @save_test, @save_DBname, null, null, getdate())
		   end
		Else
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Activity', 'Warning', 'Low', @save_test, @save_DBname, 'No connections found for the past 90 days.', null, getdate())
		   end
	   end


	--  Check certificates - current, backed up, assosciated DB
	Print 'Start UserDB Certificate check'
	Print ''


	IF @@VERSION LIKE '%Microsoft SQL Server 2005%'
	   begin
		Print 'Skip UserDB Certificate check (SQL2005)'
		Print ''
		goto skip_Certificate
	   end


	If @save_AvailGrp = 'y'
	   begin
		If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @save_DBname) in ('SECONDARY', 'RESOLVING')
		   begin
			Print 'Skip Certificate check for DB ' + @save_DBname + '.  The DB is an AvailGrp and is not available for this check.'
			Print ''
			goto skip_Certificate
		   end
	   end


	SELECT @cmd = 'select c.name, COALESCE(CAST(c.pvt_key_last_backup_date AS VARCHAR(100)), ''Never'') from [' + @save_DBname + '].sys.certificates c INNER JOIN [' + @save_DBname + '].sys.dm_database_encryption_keys dek ON c.thumbprint = dek.encryptor_thumbprint'
	Select @save_test = @cmd


	delete from #db_cert
	INSERT INTO #db_cert EXEC (@cmd)
	--select * from #db_cert


	If (select count(*) from #db_cert) > 0
	   begin
		start_Certificate:

		Select @save_CertName = (select top 1 CertName from #db_cert)


		If (select pvt_key_last_backup_date from #db_cert where certName = @save_CertName) is null
		   begin
			insert into [dbo].[HealthCheckLog] values ('UserDB', 'Certificate', 'Warning', 'Medium', @save_test, @save_DBname, 'Certificate has never been backed up.', @save_CertName, getdate())
		   end
		Else
		   begin
			Select @save_pvt_key_last_backup_date = (select pvt_key_last_backup_date from #db_cert where certName = @save_CertName)

			If convert(datetime, @save_pvt_key_last_backup_date) <= DATEADD(dd, -30, GETDATE())
			   begin
				insert into [dbo].[HealthCheckLog] values ('UserDB', 'Certificate', 'Warning', 'Medium', @save_test, @save_DBname, 'Certificate has not been recently backed up (30 days).', @save_CertName + ' ' + @save_pvt_key_last_backup_date, getdate())
			   end
			Else
			   begin
				insert into [dbo].[HealthCheckLog] values ('UserDB', 'Certificate', 'Pass', 'Medium', @save_test, @save_DBname, 'Cert: ' + @save_CertName, 'Backed up: ' + @save_pvt_key_last_backup_date, getdate())
			   end
		   end


		--  check for more rows
		delete from #db_cert where CertName = @save_CertName
		If (select count(*) from #db_cert) > 0
		   begin
			goto start_Certificate
		   end
	   end


	skip_Certificate:


	--  check LDF Growth Duration
	Print 'Start UserDB LDF Growth Duration check'
	Print ''


	Select @save_test = 'Select * FROM sys.fn_trace_gettable(@path, DEFAULT) t WHERE t.EventClass = 93 AND t.StartTime > DATEADD(dd, -30, GETDATE()) AND t.Duration > 15000000 AND t.DatabaseName = ''' + @save_DBname + ''''


        SELECT @path=CAST(value as NVARCHAR(256)) FROM sys.fn_trace_getinfo(1) WHERE traceid=1 AND property=2;


	If @path is null or @path = ''
	   begin
		Print 'Skip LDF Growth Duration check for DB ' + @save_DBname + '.  @path was not found for the default trace.'
		Print ''
		goto skip_LDFGrowthDuration
	   end


	If exists (Select 1 FROM sys.fn_trace_gettable(@path, DEFAULT) t
				WHERE t.EventClass = 93
				AND t.StartTime > DATEADD(dd, -30, GETDATE())
				AND t.Duration > 15000000
				AND t.DatabaseName = @save_DBname)
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'LDF Growth Duration', 'Warning', 'Medium', @save_test, @save_DBname, 'Some LDF growth exceeded 15 seconds.', null, getdate())
	   end
	Else
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'LDF Growth Duration', 'Pass', 'Medium', @save_test, @save_DBname, 'All LDF growth under 15 seconds.', null, getdate())
	   end


	skip_LDFGrowthDuration:


	--  check DBA Read Access
	Print 'Start UserDB DBA Read Access check'
	Print ''


	If @save_DBname not in (select db_name from dbo.db_sequence)
	   begin
		Print 'Skip DBA Read Access check for DB ' + @save_DBname + '.  The DB is not part of the Virtuoso deployment process.'
		Print ''
		goto skip_DBAReadAccess
	   end


	Select @save_test = 'select * from ' + + @save_DBname + '.sys.database_principals where name = ''DBAasapir'''


	If (SELECT DATABASEPROPERTYEX(@save_DBname, 'Status')) = 'ONLINE'
	  and (SELECT DATABASEPROPERTYEX(@save_DBname, 'Updateability')) = 'READ_WRITE'
	   begin
		Select @cmd = 'use ' + @save_DBname + ' If not exists (select 1 from sys.database_principals where name = ''DBAasapir'') CREATE USER [DBAasapir];'
		--print @cmd
		exec(@cmd)


		Select @cmd = 'use ' + @save_DBname + ' exec sp_addrolemember ''db_datareader'', ''DBAasapir'';'
		--print @cmd
		exec(@cmd)
	   end


	skip_DBAReadAccess:


	--  Check Service Broker Queues
	Print 'Start UserDB Service Broker Queue check'
	Print ''


	SELECT @cmd = 'SELECT name FROM [' + @save_DBname + '].sys.service_queues WHERE [is_ms_shipped] = 0'
	Select @save_test = @cmd


	delete from #SpecificSBQs
	INSERT INTO #SpecificSBQs EXEC (@cmd)
	--select * from #SpecificSBQs


	If not exists (SELECT name FROM #SpecificSBQs)
	   begin
		Print 'Skip UserDB Service Broker Queue check for DB ' + @save_DBname + '.  The DB does not contain Service Broker Queues.'
		Print ''
		goto skip_ServiceBrokerQueue
	   end


	Start_ServiceBrokerQueue:
	Select @save_name = (select top 1 name from #SpecificSBQs order by name)
	If exists (select 1 from dbo.SrvBrkrQueues where DBName = @save_DBname and QName = @save_name)
	   begin
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'SBQueue Check', 'Pass', 'High', @save_test, @save_DBname, @save_name, null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('UserDB', 'SBQueue Check', 'Fail', 'High', @save_test, @save_DBname, @save_name, 'Unknown Service Broker Queue', getdate())
	   END


	Delete from #SpecificSBQs where name = @save_name
	If exists (select 1 from #SpecificSBQs)
	   begin
		goto Start_ServiceBrokerQueue
	   end


	skip_ServiceBrokerQueue:


	skip_11:


	-- check for more rows to process
	delete from #miscTempTable where cmdoutput = @hold_DBname
	IF (SELECT COUNT(*) FROM #miscTempTable) > 0
	   BEGIN
		goto start_databases
	   END


   END


Print '--select * from [dbo].[HealthCheckLog] where HCcat like ''UserDB%'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #miscTempTable
drop TABLE #temp_tbl
drop TABLE #DBCCs
drop TABLE #db_files
drop TABLE #db_cert
drop TABLE #SpecificSBQs
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_UserDB_General] TO [public]
GO
