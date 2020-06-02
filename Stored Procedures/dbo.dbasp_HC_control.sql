SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_control] @outpath varchar (255) = null


/*********************************************************
 **  Stored Procedure dbasp_HC_control
 **  Written by Steve Ledridge, Virtuoso
 **  June 19, 2014
 **  This procedure runs the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/19/2014	Steve Ledridge		New process.
--	09/30/2014	Steve Ledridge		Changed iscluster to Cluster.
--	01/07/2015	Steve Ledridge		Opened the share standards section.
--	05/20/2015	Steve Ledridge		Changed Cluster to ClusterName.
--	04/21/2016	Steve Ledridge		Added section for AvailGrps.
--	======================================================================================


/***
declare @outpath varchar (255)


select @outpath = null
--***/


DECLARE		 @miscprint					nvarchar(2000)
			,@cmd						nvarchar(500)
			,@central_flag				char(1)
			,@charpos					int
			,@CheckDate					DATETIME
			,@save_multi_instance_flag	CHAR(1)
			,@save_Cluster				sysname
			,@save_ENVname				sysname


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
Select @central_flag = 'y'
Select @CheckDate = CONVERT(date,GETDATE())


DELETE [dbo].[HealthCheckLog] WHERE CONVERT(date,Check_Date) = Convert(date,getdate())


If @outpath is null
   begin
	Select @outpath = @DBASQLPath + '\dba_reports'
   end


--  Create Temp Tables
CREATE TABLE	#SQLInstances (
				InstanceID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
				,InstName NVARCHAR(180)
				,Folder NVARCHAR(50)
				,StaticPort INT NULL
				,DynamicPort INT NULL
				,Platform INT NULL
				);


--  Verify output path existance
If [dbo].[dbaudf_GetFileProperty] (@outpath,'FOLDER','Exists') <> 'True'
   begin
	Select @miscprint = 'DBA ERROR: Output Path does not exist.' + @outpath
	raiserror(@miscprint,-1,-1) with NOWAIT
	goto label99
   end


--  Make sure we have data in the Local_ServerEnviro table
IF NOT EXISTS (SELECT 1 FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'instance' AND env_detail = @@SERVERNAME)
   BEGIN
	EXEC DBAOps.dbo.dbasp_capture_local_serverenviro
   END


IF LEFT(@@SERVERNAME,6) = 'SDCPRO'
	UPDATE DBAOps.dbo.Local_ServerEnviro
	SET env_detail = 'production'
	where env_type = 'ENVname'


IF LEFT(@@SERVERNAME,6) = 'SDCPRO'
	UPDATE DBAOps.dbo.dba_serverinfo
	SET SQLEnv = 'production'
	where sqlname = @@servername


Select @save_ENVname = env_detail FROM DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname'
If @save_ENVname is null
   begin
	Select @miscprint = 'DBA WARNING: The envirnment name is not defined for ' + @@servername + '.  The nightly self check-in failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN DBA SQL Health Check '
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'


--  Make sure we have a current row in the DBA_Serverinfo table for this SQL instance
IF NOT EXISTS (SELECT 1 FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME AND moddate > @CheckDate-2)
   BEGIN
	EXEC DBAOps.dbo.dbasp_Self_Register
   END


--  Make sure sp_configure 'show advanced option' is set
IF NOT EXISTS (SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE '%show advanced options%' AND value = 1)
   BEGIN
	SELECT @cmd = 'sp_configure ''show advanced option'', ''1'''
	EXEC master.sys.sp_executeSQL @cmd


	SELECT @cmd = 'RECONFIGURE WITH OVERRIDE;'
	EXEC master.sys.sp_executeSQL @cmd
   END


--  Create secedit output file
SELECT @cmd = 'secedit /export /cfg c:\sql_healthcheck_secedit.INF /areas user_rights'
EXEC master.sys.xp_cmdshell @cmd, no_output


--  Check for multi-instance
Delete from #SQLInstances
INSERT INTO #SQLInstances (InstName, Folder)
EXEC xp_regenumvalues N'HKEY_LOCAL_MACHINE',N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Delete from #SQLInstances where InstName is null


If (select count(*) from #SQLInstances) > 1
   begin
	Select @save_multi_instance_flag = 'y'
   end


-------------------------------------------------------------------------------------------
--  Start Individual Health Checks
-------------------------------------------------------------------------------------------


--  Insert Starting row into [dbo].[HealthCheckLog]
insert into [dbo].[HealthCheckLog] values ('SQL_Health_Check', 'Start', 'Success', null, 'insert into [dbo].[HealthCheckLog]', null, null, null, getdate())


--  01: VERIFY INSTALLATION AND STANDARD CONFIGURATION  --------------------------------------------------------------------
Print 'Starting Standard Installation and Configuration Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--xp_cmdshell (self healing)
--verify login mode
--verify audit level
exec dbo.dbasp_HC_Install_Config


--check minimum memory settings
--check max memory settings
--check awe and boot.ini
--check MAXdop settings
--check lock pages in memory setting
exec dbo.dbasp_HC_Install_Memory


--verify service account and local admin permissions
--verify sql services set properly
exec dbo.dbasp_HC_Install_Services


--  02: CLUSTER VERIFICATIONS (RESOURCES ONLINE, NODES ONLINE, INSTANCE ON NODE ALONE)  --------------------------------------------------------------------
Print 'Starting Cluster Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


Select @save_Cluster = (SELECT TOP 1 ClusterName FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)


IF @save_Cluster = ''
   BEGIN
	Print 'Skipping Cluster Health Checks (not a cluster)'
	RAISERROR('', -1,-1) WITH NOWAIT
	goto skip_Cluster_Health_Checks
   END


--CLUSTER VERIFICATIONS - NODES ONLINE
--CLUSTER VERIFICATIONS - INSTANCE ON NODE ALONE
--CLUSTER VERIFICATIONS - RESOURCES ONLINE
exec dbo.dbasp_HC_Cluster_Status


skip_Cluster_Health_Checks:


--  03: VERIFY SYSTEM DB SETTINGS  --------------------------------------------------------------------
Print 'Starting SYSTEM DB SETTINGS Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  sys DB owner
--  sys DB recov model
--  sys DB sizing and growth settings
--  sys DB security
--  sys DB file location (for tempdb)
--  temp DB number of files
--  Check Backups
exec dbo.dbasp_HC_SysDB_General


--  04: VERIFY DBA DB SETTINGS  --------------------------------------------------------------------
Print 'Starting DBA DB SETTINGS Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  dba DB owner
--  dba DB recov model
--  dba DB sizing and growth settings
--  dba DB security
--  dba DB local cursor setting
--  add DBAaspir to db_datareader if needed
--  Check Backups
exec dbo.dbasp_HC_DbaDB_General
exec dbo.dbasp_HC_DbaDB_UpdateNoCheck


--  05: VERIFY STANDARD SHARES  --------------------------------------------------------------------
Print 'Starting STANDARD SHARES Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  exist and security test for all standard shares
--  look for large files in the SQLjob_logs share
--  look for large files in the log share
--  look for old files in the dba_mail share
--  look for old files in the backup share (prod only)
exec dbo.dbasp_HC_Shares_Standard


--  06: VERIFY Utilities  --------------------------------------------------------------------
Print 'Starting STANDARD Utilities Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  verify DBA Util path and system path
--  verify Selected utilities function
--  check system32 utilities
exec dbo.dbasp_HC_Utilities


--  07: VERIFY User Databases  --------------------------------------------------------------------
Print 'Starting User Databases Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  add DBAaspir to db_datareader if needed
--  check for recent status change
--  check DB status
--  check DB Settings (updateability, collation, comparison Style, IsAnsiNullDefault, IsAnsiNullsEnabled, IsAnsiPaddingEnabled, IsAnsiWarningsEnabled,
--			IsArithmeticAbortEnabled, IsAutoClose, IsAutoCreateStatistics, IsAutoShrink, IsAutoUpdateStatistics, IsCloseCursorsOnCommitEnabled
--			IsInStandBy, IsLocalCursorsDefault, IsMergePublished, IsNullConcat, IsNumericRoundAbortEnabled, IsParameterizationForced, IsPublished
--			IsRecursiveTriggersEnabled, IsSubscribed, IsSyncWithBackup, IsTornPageDetectionEnabled, LCID, SQLSortOrder)
--  check DB security (DB owner, user access)
--  Check Recovery Model
--  Check Backups
--  check orphaned users (Drop users orphaned for more than 7 days)
--  check Build Table
--  check for last DBCC
--  check for activity in past 30 days
--  check DB and file growth settings
exec dbo.dbasp_HC_UserDB_General


--  08: VERIFY Logins  --------------------------------------------------------------------
Print 'Starting Login Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  Verify Logins (check for DB access or system role membership)
--  check for orphaned logins


--  09: VERIFY AGENT JOBS  --------------------------------------------------------------------
Print 'Starting AGENT JOBS Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  check agent properties (max rows)
--  check job output file paths
--  add DBAOps jobs if needed
--  EVALUEATE STANDARD JOBS (Util)
--  EVALUEATE STANDARD JOBS (Maint)
--  verify backup jobs (enabled, last run)


--  10: VERIFY Disk Usage  --------------------------------------------------------------------
Print 'Starting Disk Usage Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  check for out-of-space alerts (will be out of space in...)


--  11: VERIFY DBA processes  --------------------------------------------------------------------
Print 'Starting DBA processes Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  Verify Index Maint (look for non-completed rows in dbo.IndexMaintenanceProcess)
--  verify dba mail


--  12: VERIFY Availability Group processes  --------------------------------------------------------------------
Print 'Starting Availability Group processes Health Checks'
RAISERROR('', -1,-1) WITH NOWAIT


--  Verify Availability Group Config and Settings
exec dbo.dbasp_HC_AvailGrps_General


--Print 'Run dbo.dbasp_HC_123'
--RAISERROR('', -1,-1) WITH NOWAIT


--exec DBAOps.dbo.dbasp_HC_123


--TABLE [dbo].[HealthCheckLog] (
--	[HC_ID] [bigint] IDENTITY(1,1) NOT NULL,
--	[HCcat] [sysname] NOT NULL,
--	[HCtype] [sysname] NOT NULL,
--	[HCstatus] [sysname] NOT NULL,
--	[HCtest] [nvarchar](4000) NULL,
--	[DBname] [sysname] NULL,
--	[Check_detail01] [sysname] NULL,
--	[Check_detail02] [nvarchar](4000) NULL,
--	[Check_date] [datetime] NULL DEFAULT (getdate())


--  99: Report To Central  --------------------------------------------------------------------
Print 'Starting Report To Central Process'
RAISERROR('', -1,-1) WITH NOWAIT


exec DBAOps.dbo.dbasp_HC_ReportToCentral @PrintLocal = 0


--  Insert Ending row into [dbo].[HealthCheckLog]
insert into [dbo].[HealthCheckLog] values ('SQL_Health_Check', 'End', 'Success', null, 'insert into [dbo].[HealthCheckLog]', null, null, null, getdate())


--  Finalization  ------------------------------------------------------------------------------


label99:


DROP TABLE #SQLInstances
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_control] TO [public]
GO
