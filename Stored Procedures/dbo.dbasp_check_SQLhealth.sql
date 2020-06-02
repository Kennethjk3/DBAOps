SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_check_SQLhealth] (@rpt_recipient sysname = 'DBANotify@${{secrets.DOMAIN_NAME}}'
						,@checkin_grace_hours SMALLINT = 32
						,@recycle_grace_days SMALLINT = 120
						,@reboot_grace_days SMALLINT = 120
						,@Verbose INT = 1	-- -1=SILENT,0=ONLY FAILURE SUMMARY,1=STEP DETAILS,2=DEBUG INFO
						,@NestLevel	INT = 0
						,@PrintOnly INT = 0
						)


	/*************************************************************************************************
	 **  Stored Procedure dbasp_check_SQLhealth
	 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
	 **  August 31, 2010
	 **
	 **  This dbasp is set up to do a complete health check for
	 **  the local SQL instance.
	 *************************************************************************************************/


	--------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------
	--											EXAMPLE EXECUTION
	--------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------
	--
	--			EXEC DBAOps.[dbo].[dbasp_check_SQLhealth] @Verbose = 0
	--
	--------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------
AS
	-- Do not lock anything, and do not get held up by any locks.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET CONCAT_NULL_YIELDS_NULL ON

--	==================================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/31/2010	Steve Ledridge		New process.
--	01/07/2011	Steve Ledridge		Added output files
--	01/12/2011	Steve Ledridge		Fixed inserts into temp tables (no output)
--	01/13/2011	Steve Ledridge		Converted @cmd = 'type c:\...) to use dbaudf_FileAccess_Read
--	01/19/2011	Steve Ledridge		Fixed problem with cores vs core(s)
--	02/10/2011	Steve Ledridge		Fixed output line for auditlevel and backup check to include type = 'F'
--	02/17/2011	Steve Ledridge		Added check for 3gb='-' (for OSver 2008).
--	02/25/2011	Steve Ledridge		Added top 1 for secedit_id queries.
--	03/04/2011	Steve Ledridge		Added code for AHP procesing.
--	03/18/2011	Steve Ledridge		Added ' 2048' for sc qc command (set buffer size)
--	04/22/2011	Steve Ledridge		Modified backup_type check for 2008
--	06/02/2011	Steve Ledridge		Added skip for *_new databases (reporting in restoring mode)
--	06/06/2011	Steve Ledridge		Added check for DBowner override (nocheck)
--								New code for memory check (convert GB and KB to MB)
--	06/14/2011	Steve Ledridge		New check for share security by creating and deleting a new folder.
--								Reversed convert of @cmd = 'type c:\...) to use dbaudf_FileAccess_Read
--	06/22/2011	Steve Ledridge		Added instance name to folder security check.
--	06/30/2011	Steve Ledridge		Fixed an issue with memory listed with a decimal.
--	07/05/2011	Steve Ledridge		Fix DB owner if it's the sql srvc acct.
--	07/22/2011	Steve Ledridge		Added time stamp the the report header.
--	07/25/2011	Steve Ledridge		Added no_check lookup for SQLjobs.
--	08/10/2011	Steve Ledridge		Updated DEPL related job check and added check for Failed jobs.
--	08/19/2011	Steve Ledridge		Added orphan login and user check and cleanup.
--	09/13/2011	Steve Ledridge		Updated central servername and central share name.
--	11/09/2011	Steve Ledridge		Fixed code for orphaned user per DB alert.
--	11/15/2011	Steve Ledridge		Commented out tempdb file size check.
--	01/03/2012	Steve Ledridge		Modified code for droping orphaned users schema to check if it exists and
--								has no objects using the schema before trying to drop it.
--	01/12/2012	Steve Ledridge		Chg file_size variable to bigint and added check for DB autogrowth.
--	02/22/2012	Steve Ledridge		New code to bypass mirroring DB's.
--	02/29/2012	Steve Ledridge		Added localservice for SQLBrowser svcacct check.
--	04/02/2012	Steve Ledridge		new check for Redgate entries to local_serverenviro when RG is not installed.
--	04/27/2012	Steve Ledridge		Added SQL mail check.
--	05/01/2012	Steve Ledridge		New section to check cluster resources, and new memory check for under use.
--	05/07/2012	Steve Ledridge		Added no_check for OSmemory limit and MAXdop self healing.
--	06/01/2012	Steve Ledridge		Changed Disk Space Forecasting Section to run from the dbo.DMV_DiskSpaceForecast Table (line 4598)
--	06/04/2012	Steve Ledridge		Modified SQLMaxMemory Calculation to round down to 1GB increments to filter false positives (line 1048)
--	06/04/2012	Steve Ledridge		Modified TempDB_filecount to use a No_Check Overide. (line 1710)
--	06/04/2012	Steve Ledridge		Modified all Calls to GetDate() to use @CheckDate Variable that is set at the beginning so
--						that all reports, comments, and table entries use the exact same datetime for better grouping
--						of multiple records.
--	06/05/2012	Steve Ledridge		New code to skip snapshot DB's (source_database_id is null)
--	06/05/2012	Steve Ledridge		Modified Cluster Status Checking to be more reliable. (line 508)
--	06/05/2012	Steve Ledridge		Modified all output to use standard calls so that it can be groomed.
--	06/18/2012	Steve Ledridge		Modified Job Checking processes
--	06/18/2012	Steve Ledridge		Modified all Output and file writing processes to use newer methods.
--	07/16/2012	Steve Ledridge		New code for Read_Only databases.
--	07/25/2012	Steve Ledridge		Added code to make sure tlb DMV_DiskSpaceForecast exists.
--	08/10/2012	Steve Ledridge		New code to restart the index maint process if it was stopped.
--	08/20/2012	Steve Ledridge		Fixed IF stmt followed by label issue.
--	10/31/2012	Steve Ledridge		Commented out code for Job step output not in history.
--	11/21/2012	Steve Ledridge		Change hour lookback values from 24 to 25 and 168 to 169.
--	12/28/2012	Steve Ledridge		Added diag for cluster info errors.
--	01/08/2013	Steve Ledridge		Added SET CONCAT_NULL_YIELDS_NULL ON
--	02/13/2013	Steve Ledridge		Fully qualified code for dba_dbinfo update.
--	02/25/2013	Steve Ledridge		Rewrote calls to CLR sprocs which replaces OLE Sprocs.
--	02/27/2013	Steve Ledridge		Added AllDBs to DBowner no_check add JobDBpointer no_check.
--	03/13/2013	Steve Ledridge		Removed reference to DB systeminfo.
--	04/01/2013	Steve Ledridge		Modified sql max memoery calcs.
--	04/29/2013	Steve Ledridge		Changed DEPLinfo to DBAOps.
--	05/23/2013	Steve Ledridge		Removed set for OLE config.
--	06/11/2013	Steve Ledridge		Removed 276610_276610.exe from system32 check process.
--	07/18/2013	Steve Ledridge		Changed references to DEPL jobs to DBAOps jobs.
--	08/05/2013	Steve Ledridge		Changed check info for 'Base - local' and 'DBAOps monitor' jobs.
--	09/06/2013	Steve Ledridge		Change hour lookback values from 25 to 30 for production.
--	09/12/2013	Steve Ledridge		Add code to ignore z_snap DB's.
--	09/18/2013	Steve Ledridge		Special code for login DBAasapir
--	10/10/2013	Steve Ledridge		For DB's online only - code for login DBAasapir
--	11/06/2013	Steve Ledridge		Adjusted skip for DB's that are restoring.
--	12/10/2013	Steve Ledridge		Added job status check prior to restart for index maint.
--	01/08/2014	Steve Ledridge		Changed check for 4GB memory to 4090.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	04/09/2014	Steve Ledridge		Added Verify DBAOps section, with fix for is_cursor_default_local.
--	04/15/2014	Steve Ledridge		Modified calls to sc.exe to use double quotes arround service names to prevent errors with spaces.
--	04/16/2014	Steve Ledridge		Changed seapsqldba01 to seapdbasql01.
--	06/24/2014	Steve Ledridge		Updates for SQL services.
--	08/18/2014	Steve Ledridge		Modified "CHECK DISK FORECAST" to use current forecasting tables.
--	08/19/2014	Steve Ledridge		New code to ignore secondary AvailGrp DB's.
--	09/26/2014	Steve Ledridge		Modified CPU Core Check to default to 1 Core if recorded as "Unknown"
--	09/30/2014	Steve Ledridge		Changed iscluster to Cluster.
--	10/01/2014	Steve Ledridge		Modified Addrolemember section to exclude read_only databases.
--	10/29/2014	Steve Ledridge		Removed references to MOM.
--	05/20/2015	Steve Ledridge		Changed cluster to ClusterName.
--	08/27/2015	Steve Ledridge		Added exclusion for agent job log file checks if job not owned by sa.
--	======================================================================================


/*
declare @rpt_recipient sysname
declare @checkin_grace_hours smallint
declare @recycle_grace_days smallint
declare @reboot_grace_days smallint
declare @Verbose INT
declare @NestLevel INT
declare @PrintOnly INT


select @rpt_recipient = 'DBANotify@${{secrets.DOMAIN_NAME}}'
Select @checkin_grace_hours = 32
select @recycle_grace_days = 120
select @reboot_grace_days = 120
select @Verbose = 2	-- -1=SILENT,0=ONLY FAILURE SUMMARY,1=STEP DETAILS,2=DEBUG INFO
select @NestLevel = 0
select @PrintOnly = 0
--*/


BEGIN	---------------------------------------  DECLARES  -------------------------------------------
	DECLARE		@central_server					SYSNAME
				,@charpos				INT
				,@CheckDate				DATETIME
				,@cmd					NVARCHAR(4000)
				,@ColumnWrapCnt				INT
				,@CritFail				VarChar(20)
				,@CRLF					CHAR(2)
				,@date_control				DATETIME
				,@day_count				INT
				,@DBASQL_Share_Name			SYSNAME
				,@DebugPrint				INT
				,@doesexist				INT
				,@EnableCodeComments			SQL_VARIANT
				,@fail_flag				CHAR(1)
				,@file_size 				BIGINT
				,@FilterOutlierPercent			INT
				,@first_flag				CHAR(1)
				,@FloatRange				INT
				,@hold_backup_start_date		DATETIME
				,@hold_source_path			sysname
				,@hold_value01				NVARCHAR(500)
				,@isNMinstance				CHAR(1)
				,@jobhistory_max_rows			INT
				,@jobhistory_max_rows_per_job		INT
				,@JobLog_Share_Name			VARCHAR(255)
				,@JobLog_Share_Path			VARCHAR(100)
				,@message				NVARCHAR(4000)
				,@miscprint				NVARCHAR(255)
				,@MSG					VARCHAR(MAX)
				,@nocheck_backup_flag			CHAR(1)
				,@nocheck_maint_flag			CHAR(1)
				,@OutputComment				VARCHAR(MAX)
				,@OutputPrint				INT
				,@p2 					NVARCHAR(4000)
				,@p4 					INT
				,@p5 					INT
				,@parm01				sysname
				,@PrintWidth				INT
				,@ReportFileName			VARCHAR(100)
				,@reportfile_path			nVarChar(500)
				,@ReportPath				VARCHAR(8000)
				,@ReportText				VARCHAR(MAX)
				,@Result				INT
				,@rpt_flag				CHAR(1)
				,@saverun_date				INT
				,@saverun_time				INT
				,@save_auditlevel			sysname
				,@save_awe				NCHAR(1)
				,@save_backuptype			sysname
				,@save_backup_start_date		sysname
				,@save_boot_3gb				NCHAR(1)
				,@save_boot_pae				NCHAR(1)
				,@save_boot_userva			NCHAR(1)
				,@save_check	    			sysname
				,@save_check_type			sysname
				,@save_cluster_ActvActv_flag		CHAR(1)
				,@save_multi_instance_flag		CHAR(1)
				,@save_CPUcore 				sysname
				,@save_DBAOps_Version			sysname
				,@save_dba_mail_path			sysname
				,@save_DBid				INT
				,@save_DBname				sysname
				,@save_DBstatus				sysname
				,@save_DB_owner				sysname
				,@save_display_name			sysname
				,@save_domain				sysname
				,@save_DomainName			sysname
				,@save_DriveFullWks			INT
				,@save_driveletter			NVARCHAR(10)
				,@save_EnableCodeComments		SQL_VARIANT
				,@save_envname				sysname
				,@save_grade01				sysname
				,@save_GrowthPerWeekMB			INT
				,@save_Cluster				sysname
				,@save_joblog_outpath			NVARCHAR(2000)
				,@save_jobname				sysname
				,@save_jobstep				INT
				,@save_job_id				UNIQUEIDENTIFIER
				,@save_lastrun				INT
				,@save_litespeed			sysname
				,@save_loginmode			sysname
				,@save_login_name			sysname
				,@save_master_filepath			NVARCHAR(2000)
				,@save_maxdop 				sysname
				,@save_maxdop_int 			INT
				,@save_Memory				INT
				,@save_memory_float			FLOAT
				,@save_memory_varchar			sysname
				,@save_moddate				DATETIME
				,@save_Name2				sysname
				,@save_next_run_date			DATETIME
				,@save_notes01				NVARCHAR(500)
				,@save_ObjectName			sysname
				,@save_ObjectType			sysname
				,@save_old_check			sysname
				,@save_OSmemory				INT
				,@save_OSmemory_vch			sysname
				,@save_OSuptime				sysname
				,@save_outfilename			sysname
				,@save_reboot_days			NVARCHAR(10)
				,@save_RecoveryModel			sysname
				,@save_RedGate				sysname
				,@save_Redgate_flag			CHAR(1)
				,@save_rg_version			sysname
				,@save_rg_versiontype			sysname
				,@save_r_id				INT
				,@save_sc_data				sysname
				,@save_sc_data_part			sysname
				,@save_sched_maint_parm01		tinyint
				,@save_sched_tlog_parm02		tinyint
				,@save_sched_archive_parm03		int
				,@save_sched_maint_parm04		int
				,@save_secedit_data			VARCHAR(MAX)
				,@save_secedit_hold			VARCHAR(MAX)
				,@save_secedit_id			INT
				,@save_servername			sysname
				,@save_servername2			sysname
				,@save_SERVICE_START_NAME		sysname
				,@save_sharename			sysname
				,@save_size_of_userDBs_MB		INT
				,@save_sqlinstance			sysname
				,@save_SQLmax_memory			NVARCHAR(20)
				,@save_SQLmax_memory_all		BIGINT
				,@save_SQLmax_memory_int		INT
				,@save_SQLrecycle_date			DATETIME
				,@save_sqlservername			sysname
				,@save_sqlservername2			sysname
				,@save_SQLSvcAcct			sysname
				,@save_start_type			sysname
				,@save_status				sysname
				,@save_status2				sysname
				,@save_subject01			NVARCHAR(500)
				,@save_svcsid				sysname
				,@save_svc_state			sysname
				,@save_tempdb_corecount			NVARCHAR(10)
				,@save_tempdb_filecount			NVARCHAR(10)
				,@save_tempdb_filedrive			sysname
				,@save_tempdb_filesize			INT
				,@save_text				NVARCHAR(500)
				,@save_user_name			sysname
				,@save_user_sid				VARCHAR(255)
				,@save_value01				NVARCHAR(500)
				,@save_winzip_build			sysname
				,@share_outpath				NVARCHAR(2000)
				,@SQL					NVARCHAR(4000)
				,@StatusPrint				INT
				,@status1				sysname
				,@subject				NVARCHAR(255)
				,@Today					DATETIME
				,@TotalWidth				INT
				,@trys					INT
				,@updatefile_name			sysname
				,@updatefile_path			NVARCHAR(500)
				,@version_control			sysname


	DECLARE		@OutputComments					TABLE	(
														OutputComment VARCHAR(MAX)
														)
	DECLARE		@emailmessage					TABLE	(
														emailtext VARCHAR(MAX)
														)
	DECLARE		@Report							TABLE	(
														[subject] VARCHAR(MAX)
														,[value] VARCHAR(MAX)
														,[grade] sysname
														,[notes] VARCHAR(MAX)
														,[OutputComment] VARCHAR(MAX)
														)
	DECLARE		@JobStatusResults				TABLE	(
														[JobName]						[sysname]	NOT NULL
														,[OwnerName]					[sysname]	NULL
														,[Enabled]						[INT]		NULL
														,[Schedules]					[INT]		NULL
														,[EnabledSchedules]				[INT]		NULL
														,[WeightedAverageRunDuration]	[INT]		NULL
														,[AverageRunDuration]			[INT]		NULL
														,[AVGDevs]						[FLOAT]		NULL
														,[ExecutionsToday]				[INT]		NULL
														,[OutliersToday]				[INT]		NULL
														,[Executions]					[INT]		NULL
														,[lastrun]						[DATETIME]	NULL
														,[Failures]						[INT]		NULL
														,[FailuresToday]				[INT]		NULL
														,[LastStatus]					[INT]		NULL
														,[LastStatusMsg]				[SYSNAME]	NULL
														,[CurrentCount]					[INT]		NULL
														,[AvgDailyExecutionsCount]		[FLOAT]		NULL
														,[MaxDailyExecutionsCount]		[FLOAT]		NULL
														,[AvgDailyFailCount]			[FLOAT]		NULL
														,[MaxDailyFailCount]			[FLOAT]		NULL
														,[AvgDailyFailPercent]			[FLOAT]		NULL
														,[MaxDailyFailPercent]			[FLOAT]		NULL
														,[next_scheduled_run_date]		[DATETIME]	NULL
														)
	DECLARE		@tblv_DBA_Serverinfo			TABLE	(
														SQLServerName sysname
														,SQLServerENV sysname
														,Active CHAR(1)
														,modDate DATETIME
														,SQL_Version NVARCHAR (500) NULL
														,DBAOps_Version sysname NULL
														,backup_type sysname NULL
														,LiteSpeed sysname NULL
														,RedGate sysname NULL
														,DomainName sysname NULL
														,SQLrecycle_date sysname NULL
														,awe_enabled CHAR(1) NULL
														,MAXdop_value NVARCHAR(5) NULL
														,SQLmax_memory NVARCHAR(20) NULL
														,tempdb_filecount NVARCHAR(10) NULL
														,Cluster sysname NULL
														,Port NVARCHAR(10) NULL
														,IPnum sysname NULL
														,CPUcore sysname NULL
														,CPUtype sysname NULL
														,Memory sysname NULL
														,OSname sysname NULL
														,OSver sysname NULL
														,OSuptime sysname NULL
														,boot_3gb CHAR(1) NULL
														,boot_pae CHAR(1) NULL
														,boot_userva CHAR(1) NULL
														,Pagefile_inuse sysname NULL
														,SystemModel sysname NULL
														)
	DECLARE 	@tblv_moddate					TABLE	(
														SQLServerName sysname
														,modDate DATETIME
														)
	DECLARE 	@tblv_recycle					TABLE	(
														SQLServerName sysname
														,SQLrecycle_date sysname NULL
														)
	DECLARE 	@tblv_reboot					TABLE	(
														SQLServerName sysname
														,OSuptime sysname NULL
														)
	DECLARE 	@tblv_version					TABLE	(
														SQLServerName sysname
														,DBAOps_Version sysname NULL
														)
	DECLARE 	@tblv_backup_usage 				TABLE	(
														SQLServerName sysname
														,size_of_userDBs_MB INT NULL
														)
	DECLARE 	@tblv_std_backup_check 			TABLE	(
														SQLServerName sysname
														,LiteSpeed CHAR(1) NULL
														,RedGate CHAR(1) NULL
														)
	DECLARE 	@tblv_cmp_backup_check			TABLE	(
														SQLServerName sysname
														,backup_type sysname NULL
														,LiteSpeed CHAR(1) NULL
														,RedGate CHAR(1) NULL
														)
	DECLARE 	@tblv_memory					TABLE	(
														SQLServerName sysname
														,awe_enabled CHAR(1) NULL
														,SQLmax_memory NVARCHAR(20) NULL
														,Memory sysname NULL
														,boot_3gb CHAR(1) NULL
														,boot_pae CHAR(1) NULL
														,boot_userva CHAR(1) NULL
														)
	DECLARE 	@tblv_cluster					TABLE	(
														SQLServerName sysname
														,Name2 sysname NULL
														)
	DECLARE 	@xp_results						TABLE	(
														job_id                UNIQUEIDENTIFIER NOT NULL,
        												last_run_date         INT              NOT NULL,
        												last_run_time         INT              NOT NULL,
        												next_run_date         INT              NOT NULL,
        												next_run_time         INT              NOT NULL,
        												next_run_schedule_id  INT				NOT NULL,
        												requested_to_run      INT              NOT NULL, -- BOOL
        												request_source        INT              NOT NULL,
        												request_source_id     sysname          COLLATE database_default NULL,
        												running               INT              NOT NULL, -- BOOL
        												current_step          INT              NOT NULL,
        												current_retry_attempt INT              NOT NULL,
        												job_state             INT              NOT NULL
        												)
	DECLARE 	@DBStatusChanges				TABLE	(
														DBName					SYSNAME
														,StatusChanges			VARCHAR(MAX)
														)


	CREATE TABLE	#temp_results		(
										r_id [INT]	IDENTITY(1,1)	NOT NULL
										,subject01	VARCHAR(MAX)	NOT NULL
										,value01	VARCHAR(MAX)	NULL
										,grade01	VARCHAR(10)		NULL
										,notes01	VARCHAR(MAX)	NULL
										);
	CREATE TABLE	#temp_tbl1			(
										tb11_id [INT] IDENTITY(1,1) NOT NULL
										,text01	NVARCHAR(400) NULL
										)
	CREATE TABLE 	#miscTempTable		(
										cmdoutput NVARCHAR(400) NULL
										)
	CREATE TABLE 	#seceditTempTable	(
										secedit_id [INT] IDENTITY(1,1) NOT NULL
			 	 						,secedit_data VARCHAR(MAX) NULL
			 	 						)
	CREATE TABLE 	#showgrps			(
										cmdoutput NVARCHAR(255) NULL
										)
	CREATE TABLE 	#ShareTempTable		(
										PATH NVARCHAR(500) NULL
										)
	CREATE TABLE 	#scTempTable		(
										sctbl_id [INT] IDENTITY(1,1) NOT NULL
			 							,sc_data        NVARCHAR(400) NULL
			 							)
	CREATE TABLE 	#scTempTable2		(
										sctbl_id [INT] IDENTITY(1,1) NOT NULL
										,sc_data        NVARCHAR(400) NULL
										)
	CREATE TABLE 	#loginconfig		(
										name sysname NULL
			 							,configvalue sysname NULL
			 							)
	CREATE TABLE 	#dir_results		(
										dir_row VARCHAR(255) NULL
										)
	CREATE TABLE 	#orphans			(
										orph_sid VARBINARY(85) NOT NULL
										, orph_name sysname NULL
										)
	CREATE TABLE 	#Objects			(
										DatabaseName sysname,
										UserName sysname,
										ObjectName sysname,
										ObjectType NVARCHAR(60)
										);
	CREATE TABLE	#SchemaObjCounts	(
										SchemaName sysname
										,objCount BIGINT
										);


	CREATE TABLE	#SQLInstances        (
										InstanceID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
										,InstName NVARCHAR(180)
										,Folder NVARCHAR(50)
										,StaticPort INT NULL
										,DynamicPort INT NULL
										,Platform INT NULL
										);
END


BEGIN	-----------------------------------  INITIAL VALUES  -----------------------------------------
	SELECT	@CheckDate					= GETDATE()
			,@Today					= CAST(CONVERT(VARCHAR(12),@CheckDate,101)AS DATETIME)
			,@subject				= 'SQL Health Check from [' + UPPER(@@SERVERNAME) + '] on ' + CONVERT(NVARCHAR(19), @CheckDate, 121)
			,@message				= ''
			,@rpt_flag				= 'n'
			,@fail_flag				= 'n'
			,@save_Redgate_flag			= 'n'
			,@save_multi_instance_flag 		= 'n'
			,@isNMinstance				= 'n'
			,@CRLF					= CHAR(13)+CHAR(10)
			,@PrintWidth				= 250
			,@OutputPrint				= CASE WHEN @Verbose >= 0 THEN 1 ELSE 0 END
			,@StatusPrint				= CASE WHEN @Verbose >  0 THEN 1 ELSE 0 END
			,@DebugPrint				= CASE WHEN @Verbose >  1 THEN 1 ELSE 0 END


		-- SET JOB TIME AVERAGE CALCULATION VARIABLES
			,@FilterOutlierPercent		= 10
			,@FloatRange				= 100


		-- SET SERVERNAME VARIABLES
			,@save_sqlinstance			= @@SERVICENAME
			,@save_servername			= CAST(SERVERPROPERTY('Machinename') AS SYSNAME)
			,@save_servername2			= REPLACE(@@SERVERNAME,'\','$')
			,@isNMinstance				= CASE @@SERVICENAME WHEN 'MSSQLSERVER' THEN 'n' ELSE 'y' END
			,@save_domain				= (SELECT env_detail FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'domain')
			,@save_Cluster				= (SELECT TOP 1 ClusterName FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
			,@save_envname				= (SELECT env_detail FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'ENVname')
			,@CritFail				= CASE @save_envname WHEN 'Production' THEN 'CritFail' ELSE 'Fail' END

		-- SET SHARE, PATH, AND FILE NAMES
			,@JobLog_Share_Name			= @save_servername2 + '_SQLjob_logs'
			,@DBASQL_Share_Name			= @save_servername2 + '_dbasql'
			,@ReportPath				= '\\'+@save_servername+'\'+@save_servername2+'_dbasql\dba_reports\'
			,@ReportFileName			= 'SQLHealthReport_'+@save_servername2+'.txt'
			,@updatefile_name			= 'SQLHealthUpdate_'+@save_servername2+'.gsql'
			,@updatefile_path			= @ReportPath+@updatefile_name
			,@reportfile_path			= @ReportPath+@ReportFileName

		-- GET EXTENDED PROPERTY
			,@EnableCodeComments		= CASE @DebugPrint WHEN 1 THEN 1 ELSE 0 END
			,@save_EnableCodeComments	= COALESCE([value],0)
	FROM	fn_listextendedproperty('EnableCodeComments', DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)


	-- GET SHARE PATHS FROM SHARE NAMES
	EXEC	DBAOps.dbo.dbasp_get_share_path @share_name = @JobLog_Share_Name, @phy_path = @JobLog_Share_Path OUT


	--------------------  Set last-run date and time parameters  -------------------
	SELECT @saverun_date = (SELECT MAX(h.run_date)
				FROM msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j
				WHERE h.job_id = j.job_id
				  AND j.name = 'UTIL - DBA Archive process'
				  AND h.run_status = 1
				  AND h.step_id = 0)


	IF @saverun_date IS NOT NULL
	   BEGIN
		SELECT @saverun_time = (SELECT MAX(h.run_time) FROM msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j
					WHERE h.job_id = j.job_id
					  AND h.run_date = @saverun_date
					  AND j.name = 'UTIL - DBA Archive process')
	   END
	ELSE
	   BEGIN
		SELECT @saverun_date = CONVERT(INT,(CONVERT(VARCHAR(20),@CheckDate, 112)))
		SELECT @saverun_time = 0
	   END


	SELECT		@OutputComment = ''
	DELETE		@OutputComments
END

BEGIN	--------------------------------  STARTING PROCESSING  ---------------------------------------
	-----------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)
	SELECT @MSG='STARTING PROCESSING',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)


	-- SET "EnableCodeComments" VALUE FOR THIS EXECUTION
	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty('EnableCodeComments', DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT))
		EXEC sys.sp_addextendedproperty		@Name = 'EnableCodeComments', @value = @EnableCodeComments
	ELSE
		EXEC sys.sp_updateextendedproperty	@Name = 'EnableCodeComments', @value = @EnableCodeComments


	/****************************************************************
	 *                MainLine
	 ***************************************************************/


	--  reset the HealthCheck_current table
	DELETE FROM dbo.HealthCheck_current


	--  Make sure we have data in the Local_ServerEnviro table
	IF NOT EXISTS (SELECT 1 FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'instance' AND env_detail = @@SERVERNAME)
	   BEGIN
		EXEC DBAOps.dbo.dbasp_capture_local_serverenviro
	   END


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
	--Print '		'+@cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT @OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10) FROM @OutputComments
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;
	SELECT @MSG=REPLICATE(' ',(@PrintWidth-LEN(@OutputComment))/2)+@OutputComment;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	-----------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	--									STARTING PROCESSING
	-----------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)
	SELECT @MSG='STARTING PROCESSING',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint;INSERT INTO @OutputComments VALUES(@MSG)


END


--  Check for multi-instance
Delete from #SQLInstances
INSERT INTO #SQLInstances (InstName, Folder)
EXEC xp_regenumvalues N'HKEY_LOCAL_MACHINE',N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Delete from #SQLInstances where InstName is null


If (select count(*) from #SQLInstances) > 1
   begin
	Select @save_multi_instance_flag = 'y'
   end


BEGIN	-------  CLUSTER VERIFICATIONS (RESOURCES ONLINE, NODES ONLINE, INSTANCE ON NODE ALONE)  -----
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start Cluster verifications')


	IF @save_Cluster is not null
	BEGIN
		DECLARE		@Groups			TABLE(ResultLine VARCHAR(MAX))
		DECLARE		@Nodes			TABLE(ResultLine VARCHAR(MAX))
		DECLARE		@Results		TABLE(ResultLine VARCHAR(MAX))
		DECLARE		@ClusterStatus	TABLE(ClusterResource SYSNAME,ClusterGroup SYSNAME, SQLName SYSNAME NULL, ClusterNode SYSNAME, status SYSNAME)


		INSERT INTO @Nodes		EXEC xp_CMDSHELL 'cluster NODE /status'
		INSERT INTO @Groups		EXEC xp_CMDSHELL 'cluster group /status'
		INSERT INTO @Results	EXEC xp_CMDSHELL 'cluster res /status'


		;WITH		ClusterNodes
					AS
					(
					SELECT		UPPER(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1)) [NodeName]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2)	[NodeNumber]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],3)	[NodeStatus]
					FROM		(
								SELECT		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ResultLine,CHAR(13),'|'),' ','|'),'||','|'),'||','|'),'||','|'),'||','|') [ResultLine]
								FROM		@Nodes
								) Nodes
					WHERE		ISNUMERIC(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2)) = 1
					)
					,ClusterGroups
					AS
					(
					SELECT		DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1) [GroupName]
								,UPPER(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2))	[NodeName]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],3)	[GroupStatus]
					FROM		(
								SELECT		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ResultLine,N.NodeName,'|'+N.NodeName+'|'),CHAR(13),'|'),')',')|'),'  ','|'),' '+'|','|'),'|'+' ','|'),'|'+'|','|'),'|'+'|','|'),'|'+'|','|'),CHAR(9),''),'-|','-'),'|'+N.NodeName+'|'+N.NodeName+'|','|'+N.NodeName+'|') [ResultLine]
								FROM		@Groups G
								LEFT JOIN	ClusterNodes N
										ON	G.ResultLine LIKE '%'+N.NodeName+'%'
								) Groups
					WHERE		NULLIF(NULLIF(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2),''),'Node') IS NOT NULL
					)
					,ClusterResources
					AS
					(
					SELECT		LEFT(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1),CHARINDEX('(',DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1)+'(')-1)	[ResourceName]
								,UPPER(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2))	[GroupName]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],3)	[NodeName]
								,LTRIM(RTRIM(CAST(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],4)AS VARCHAR(20))))	[status]
								,CASE	WHEN [ResultLine] LIKE 'SQL%(%)%'
										THEN
										SUBSTRING	(
														[ResultLine]
														,CHARINDEX('(',[ResultLine]+'()')+ 1
														,CHARINDEX(')',[ResultLine]+'()') - CHARINDEX('(',[ResultLine]+'()')-1
														)
										END	AS SQLDetails
					FROM		(
								SELECT		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(STUFF(REPLACE('|'+REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ResultLine,CHAR(13),''),G.GroupName,'|$GN$|'),G.NodeName,'|$NN$|'),'(|','('),'|)',')'),'   ',' '),'  ',' '),'  ',' '),'| ','|'),' |','|'),'||','|'),'| ','|'),' |','|'),'||','|'),1,1,''),'$GN$',G.GroupName),'$NN$',G.NodeName),'-|','-'),'|_','_'),'|$','$'),'for|','for ') [ResultLine]
								FROM		@Results R
								LEFT JOIN	ClusterGroups G
										ON	R.ResultLine LIKE '%'+G.GroupName+'%'
								) Resources
					WHERE		DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1) IS NOT NULL
					)
					,SQLNames
					AS
					(
					SELECT		[GroupName]
								,MAX(CASE WHEN [ResourceName] = 'SQL Network Name' THEN [SQLDetails] END) [SERVERNAME]
								,MAX(CASE WHEN [ResourceName] = 'SQL Server' THEN [SQLDetails] END) [SQLInstance]
					FROM		ClusterResources
					WHERE		[GroupName] IS NOT NULL
					GROUP BY	[GroupName]
					)
		INSERT INTO	@ClusterStatus
		SELECT		T1.[ResourceName]
					,T1.[GroupName]
					,UPPER(T2.[ServerName] + COALESCE('\'+NULLIF(T2.[SQLInstance],'MSSQLSERVER'),'')) [SQLName]
					,T1.[NodeName]
					,T1.[Status]
		FROM		ClusterResources T1
		JOIN		SQLNames T2
				ON	T1.GroupName = T2.GroupName


		-- ARE ANY RESOURCES OF THIS INSTANCE OFFLINE
		---------------------------------------------
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		SELECT		'Cluster_Resource'
					,'Resource Not Online'
					,@CritFail
					,ClusterResource
		FROM		@ClusterStatus
		WHERE		[SQLName] = @@SERVERNAME
				AND [status] != 'Online'
				AND ClusterResource not in (select Detail01 from dbo.no_check where nocheck_type = 'Cluster')

		IF @@ROWCOUNT = 0
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Cluster_Resource', 'Online', 'pass', '')


		-- ARE ANY NODES OFFLINE
		---------------------------------------------
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		SELECT		'Cluster_node'
					,'Node Not Up'
					,@CritFail
					,[NodeName]
		FROM		(
					SELECT		UPPER(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],1)) [NodeName]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2)	[NodeNumber]
								,DBAOps.dbo.dbaudf_ReturnPart([ResultLine],3)	[NodeStatus]
					FROM		(
								SELECT		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ResultLine,CHAR(13),'|'),' ','|'),'||','|'),'||','|'),'||','|'),'||','|') [ResultLine]
								FROM		@Nodes
								) Nodes
					WHERE		ISNUMERIC(DBAOps.dbo.dbaudf_ReturnPart([ResultLine],2)) = 1
					) Nodes
		WHERE		NodeStatus != 'Up'


		IF @@ROWCOUNT = 0
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Cluster_node', 'Up', 'pass', '')


		-- ARE MULTIPLE SQL GROUPS ACTIVE ON CLUSTER
		----------------------------------------------
		IF	(
			SELECT		COUNT(DISTINCT ClusterGroup)
			FROM		@ClusterStatus
			WHERE		[ClusterResource]	= 'SQL Server'
					AND [status]		like '%Online%'
			) > 1
		   begin
			SET @save_cluster_ActvActv_flag = 'y'


			-- ARE MULTIPLE SQL GROUPS ACTIVE ON THIS NODE
			----------------------------------------------
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
 			SELECT		'Cluster_active_active'
 						, @@SERVERNAME + ' AND ' + [SQLName]
 						, 'fail'
 						, 'Muti SQL Instances on node ' + [ClusterNode]
			FROM		@ClusterStatus
			WHERE		[ClusterResource]	= 'SQL Server'
					AND [status]			= 'Online'
					AND [ClusterNode]		= SERVERPROPERTY('ComputerNamePhysicalNetBIOS')
					AND [SQLName]			!= @@SERVERNAME

			IF @@ROWCOUNT = 0
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('Cluster_active_active', @@SERVERNAME, 'pass', 'One SQL Instance on node ' + CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS')AS VARCHAR(255)))


		   end
		ELSE
		   begin
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('Cluster_active_active', 'Not active\active', 'pass', '')
		   end


		END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end

END


BEGIN	---------------------  VERIFY INSTALLATION AND STANDARD CONFIGURATION  -----------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	--  verify xp_cmdshell turned on (self healing)
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Verify installation and standard configuration')
	INSERT INTO @OutputComments VALUES('Start verify OLE and xp_cmdshell')


	--Insert into #temp_results values ('xp_cmdshell', 'n', 'fail', '')
	IF NOT EXISTS (SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE '%xp_cmdshell%' AND value = 1)
	   BEGIN
		SELECT @cmd = 'sp_configure ''xp_cmdshell'', ''1'''
		EXEC master.sys.sp_executeSQL @cmd


		SELECT @cmd = 'RECONFIGURE WITH OVERRIDE;'
		EXEC master.sys.sp_executeSQL @cmd
	   END


	IF EXISTS (SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE '%xp_cmdshell%' AND value = 1)
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('xp_cmdshell', 'y', 'pass', '')
	   END
	   ELSE
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('xp_cmdshell', 'n', 'fail', '')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  check system32 utilities (self heal)
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start check system32 utilities')


	Exec dbo.dbasp_sys32_copy


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  check awe and boot.ini (3gb, pae, userva) settings
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('check awe and boot.ini (3gb, pae, userva) settings')


	--  Get sql memory
	SELECT @save_memory_varchar = (SELECT TOP 1 memory FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ',', '')


	IF @save_memory_varchar LIKE '%MB%'
	   BEGIN
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'MB', '')
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
		SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
		SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
		IF @charpos <> 0
		   BEGIN
			SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
		   END
		SELECT @save_memory = CONVERT(INT, @save_memory_varchar)
	   END
	ELSE IF @save_memory_varchar LIKE '%GB%'
	   BEGIN
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'GB', '')
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
		SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
		SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
		IF @charpos <> 0
		   BEGIN
			SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
		   END
		SELECT @save_memory_float = CONVERT(FLOAT, @save_memory_varchar)
		SELECT @save_memory = @save_memory_float * 1024.0
	   END
	ELSE IF @save_memory_varchar LIKE '%KB%'
	   BEGIN
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'KB', '')
		SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
		SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
		SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
		IF @charpos <> 0
		   BEGIN
			SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
		   END
		SELECT @save_memory = CONVERT(INT, @save_memory_varchar)
		SELECT @save_memory = @save_memory / 1024.0
	   END


	SELECT @save_awe = (SELECT TOP 1 awe_enabled FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	IF @@version LIKE '%x64%'
	   BEGIN
		IF @save_awe = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'y', 'warning', 'not needed for x64')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'n', 'pass', '')
		   END
	   END
	ELSE IF @save_memory < 4100
	   BEGIN
		IF @save_awe = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'y', 'fail', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'n', 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF @save_awe = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'y', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('awe_enabled', 'n', 'fail', '')
		   END
	   END


	SELECT @save_boot_3gb = (SELECT TOP 1 boot_3gb FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	IF @@version LIKE '%x64%' OR @save_memory < 4000 OR @save_memory > 16384
	   BEGIN
		IF @save_boot_3gb = '-'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', '-', 'pass', '')
		   END
		ELSE IF @save_boot_3gb = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', 'y', 'fail', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', 'n', 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF @save_boot_3gb = '-'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', '-', 'pass', '')
		   END
		ELSE IF @save_boot_3gb = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', 'y', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_3gb', 'n', 'fail', '')
		   END
	   END


	SELECT @save_boot_userva = (SELECT TOP 1 boot_userva FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	IF @@version LIKE '%x64%' OR @save_memory < 4000 OR @save_memory > 16384
	   BEGIN
		IF @save_boot_userva = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_userva', 'y', 'fail', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_userva', 'n', 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF @save_boot_userva = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_userva', 'y', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_userva', 'n', 'pass', '')
		   END
	   END


	SELECT @save_boot_pae = (SELECT TOP 1 boot_pae FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	IF @@version LIKE '%x64%' OR @save_memory < 4100
	   BEGIN
		IF @save_boot_pae = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_pae', 'y', 'fail', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_pae', 'n', 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF @save_boot_pae = 'y'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_pae', 'y', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('boot_pae', 'n', 'fail', '')
		   END
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start check MAXdop settings
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start check MAXdop settings')


	SELECT @save_maxdop = (SELECT MAXdop_value FROM dbo.dba_serverinfo WHERE sqlname = @@SERVERNAME)
	SELECT @save_maxdop = LTRIM(@save_maxdop)
	SELECT @save_maxdop = LTRIM(@save_maxdop)
	SELECT @charpos = CHARINDEX(' ', @save_maxdop)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_maxdop = LEFT(@save_maxdop, @charpos-1)
	   END
	SELECT @save_CPUcore = (SELECT CPUcore FROM dba_serverinfo WHERE sqlname = @@SERVERNAME)
	SELECT @save_CPUcore = LTRIM(@save_CPUcore)
	SELECT @charpos = CHARINDEX(' ', @save_CPUcore)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_CPUcore = LEFT(@save_CPUcore, @charpos-1)
	   END


	IF @save_maxdop = 0 AND ISNUMERIC(@save_maxdop) = 1 AND ISNUMERIC(@save_CPUcore) = 1
	   BEGIN
		SELECT @save_maxdop_int = CONVERT(INT,@save_CPUcore)/4
		IF @save_maxdop_int = 0
		   BEGIN
			SELECT @save_maxdop_int = 1
		   END

		SELECT @cmd = 'EXEC sp_configure ''max degree of parallelism'' , ' + CONVERT(sysname, @save_maxdop_int)
		--Print '		'+@cmd
		EXEC (@cmd)


		SELECT @cmd = 'RECONFIGURE WITH OVERRIDE'
		--Print '		'+@cmd
		EXEC (@cmd)
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start check memory settings
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start check memory settings')


	--  Get sql memory
	SELECT @save_SQLmax_memory = (SELECT TOP 1 SQLmax_memory FROM DBAOps.dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, ',', '')
	SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'MB', '')
	SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'GB', '')
	SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'KB', '')
	SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, ' ', '')
	SELECT @save_SQLmax_memory = RTRIM(LTRIM(@save_SQLmax_memory))
	SELECT @save_SQLmax_memory_int = CONVERT(INT, @save_SQLmax_memory)


	IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'OSmemory')
	   BEGIN
		SELECT @save_OSmemory_vch = (SELECT TOP 1 Detail01 FROM dbo.no_check WHERE NoCheck_type = 'OSmemory')
		SELECT @save_OSmemory_vch = RTRIM(LTRIM(@save_OSmemory_vch))
		SELECT @save_OSmemory = CONVERT(INT, @save_OSmemory_vch)
	   END
	ELSE If @save_memory < 8192
	   BEGIN
		SELECT @save_OSmemory = 2048
	   END
	ELSE If @save_memory < 16384
	   BEGIN
		SELECT @save_OSmemory = 4096
	   END
	ELSE If @save_memory < 65536
	   BEGIN
		SELECT @save_OSmemory = 6144
	   END
	ELSE
	   BEGIN
		SELECT @save_OSmemory = 8192
	   END


	IF @save_cluster_ActvActv_flag = 'y' or @save_multi_instance_flag = 'y'
	   BEGIN
		IF @save_memory < 4090
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'warning', 'memory on this multi-instance server is less than 4GB')
		   END
		Else IF @save_SQLmax_memory_int > (@save_memory/2)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory is greater than half the available memory on the server')
		   END
		ELSE IF @save_SQLmax_memory_int > ((@save_memory - @save_OSmemory)/2)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory for multi-instance has not been limited by at least ' + convert(nvarchar(10), @save_OSmemory) + ' (' + CONVERT(NVARCHAR(20), @save_memory) + ' available)')
		   END
		ELSE IF @save_SQLmax_memory_int < ((@save_memory - @save_OSmemory)/2)-2048
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory for multi-instance is more than 2GB below recomended max memory setting (' + CONVERT(NVARCHAR(20), @save_memory) + ' available)')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF @save_memory < 4090
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'warning', 'memory on this server is less than 4GB')
		   END
		Else IF @save_SQLmax_memory_int > (@save_memory)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory is greater than the available memory on the server')
		   END
		ELSE IF @save_SQLmax_memory_int > (@save_memory - @save_OSmemory)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory has not been limited by at least ' + convert(nvarchar(10), @save_OSmemory) + ' (' + CONVERT(NVARCHAR(20), @save_memory) + ' available)')
		   END
		ELSE IF @save_SQLmax_memory_int < (@save_memory - @save_OSmemory - 2048)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'fail', 'max memory is more than 2GB below recomended max memory setting (' + CONVERT(NVARCHAR(20), @save_memory) + ' available)')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SQLmax_memory', @save_SQLmax_memory, 'pass', '')
		   END
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start check lock pages in memory setting
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start check lock pages in memory setting')


	SELECT @save_SQLSvcAcct = (SELECT TOP 1 SQLSvcAcct FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	SELECT @cmd = 'whoami /user'


	DELETE FROM #miscTempTable
	INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd--, no_output
	DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
	DELETE FROM #miscTempTable WHERE cmdoutput NOT LIKE '%' + @save_SQLSvcAcct + '%'
	SELECT TOP 1 @cmd=cmdoutput FROM #miscTempTable
	--Print '		'+@cmd
	--select * from #miscTempTable


	SELECT @save_svcsid = (SELECT TOP 1 cmdoutput FROM #miscTempTable)
	SELECT @save_svcsid = RTRIM(LTRIM(@save_svcsid))
	SELECT @charpos = CHARINDEX(' ', @save_svcsid)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_svcsid = SUBSTRING(@save_svcsid, @charpos+1, LEN(@save_svcsid)-@charpos)
	   END
	SELECT @save_svcsid = RTRIM(LTRIM(@save_svcsid))


	--Select @cmd = 'insert into #seceditTempTable (secedit_data) select line from dbo.dbaudf_FileAccess_Read (''c:'', ''sql_healthcheck_secedit.INF'')'
	SELECT @cmd = 'type c:\sql_healthcheck_secedit.INF'
	--Print '		'+@cmd
	DELETE FROM #seceditTempTable
	--insert into #seceditTempTable (secedit_data) select line from dbo.dbaudf_FileAccess_Read ('c:', 'sql_healthcheck_secedit.INF')
	INSERT INTO #seceditTempTable (secedit_data) EXEC master.sys.xp_cmdshell @cmd
	DELETE FROM #seceditTempTable WHERE secedit_data IS NULL
	--delete from #seceditTempTable where secedit_data not like '%LockMemoryPrivilege%'
	--select * from #seceditTempTable


	IF EXISTS (SELECT 1 FROM #seceditTempTable WHERE secedit_data LIKE '%LockMemoryPrivilege%')
	   BEGIN
		SELECT @save_secedit_id = (SELECT TOP 1 secedit_id FROM #seceditTempTable WHERE secedit_data LIKE '%LockMemoryPrivilege%')
		SELECT @save_secedit_data = (SELECT secedit_data FROM #seceditTempTable WHERE secedit_id = @save_secedit_id)


		start_LockMemoryPrivilege:

		SELECT @save_secedit_id = @save_secedit_id + 1
		SELECT @save_secedit_hold = (SELECT secedit_data FROM #seceditTempTable WHERE secedit_id = @save_secedit_id)
		IF @save_secedit_hold <> '' AND @save_secedit_hold IS NOT NULL AND @save_secedit_hold NOT LIKE 'Se%'
		   BEGIN
			SELECT @save_secedit_data = @save_secedit_data + @save_secedit_hold
			GOTO start_LockMemoryPrivilege
		   END


		IF EXISTS (SELECT 1 FROM #seceditTempTable WHERE secedit_data LIKE '%' + @save_svcsid + '%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('LockMemoryPrivilege', 'LockMemoryPrivilege granted', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('LockMemoryPrivilege', 'LockMemoryPrivilege granted', 'warning', 'LockMemoryPrivilege needs to be granted for the current SQL service account.')
		   END
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('LockMemoryPrivilege', 'LockMemoryPrivilege granted', 'fail', 'LockMemoryPrivilege not found in the secedit output file.')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start verify service account and local admin permissions
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify service account and local admin permissions')


	--Select @cmd = 'insert into #seceditTempTable (secedit_data) select line from dbo.dbaudf_FileAccess_Read (''c:'', ''sql_healthcheck_secedit.INF'')'
	SELECT @cmd = 'type c:\sql_healthcheck_secedit.INF'
	--Print '		'+@cmd
	DELETE FROM #seceditTempTable
	--insert into #seceditTempTable (secedit_data) select line from dbo.dbaudf_FileAccess_Read ('c:', 'sql_healthcheck_secedit.INF')
	INSERT INTO #seceditTempTable (secedit_data) EXEC master.sys.xp_cmdshell @cmd
	DELETE FROM #seceditTempTable WHERE secedit_data IS NULL
	--delete from #seceditTempTable where secedit_data not like '%ServiceLogonRight%'
	--select * from #seceditTempTable


	IF EXISTS (SELECT 1 FROM #seceditTempTable WHERE secedit_data LIKE '%ServiceLogonRight%')
	   BEGIN
		SELECT @save_secedit_id = (SELECT TOP 1 secedit_id FROM #seceditTempTable WHERE secedit_data LIKE '%ServiceLogonRight%')
		SELECT @save_secedit_data = (SELECT secedit_data FROM #seceditTempTable WHERE secedit_id = @save_secedit_id)


		start_ServiceLogonRight:

		SELECT @save_secedit_id = @save_secedit_id + 1
		SELECT @save_secedit_hold = (SELECT secedit_data FROM #seceditTempTable WHERE secedit_id = @save_secedit_id)
		IF @save_secedit_hold <> '' AND @save_secedit_hold IS NOT NULL AND @save_secedit_hold NOT LIKE 'Se%'
		   BEGIN
			SELECT @save_secedit_data = @save_secedit_data + @save_secedit_hold
			GOTO start_ServiceLogonRight
		   END


		IF EXISTS (SELECT 1 FROM #seceditTempTable WHERE secedit_data LIKE '%' + @save_svcsid + '%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('ServiceLogonRight', 'ServiceLogonRight granted', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('ServiceLogonRight', 'ServiceLogonRight granted', 'warning', 'ServiceLogonRight may not be granted for the current SQL service account.')
		   END
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('ServiceLogonRight', 'ServiceLogonRight granted', 'fail', 'ServiceLogonRight not found in the secedit output file.')
	   END


	SELECT @cmd = 'local administrators \\' + @save_servername
	--Print '		'+@cmd
	DELETE FROM #miscTempTable
	INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd--, no_output
	DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
	--select * from #miscTempTable


	SELECT @save_DomainName = (SELECT TOP 1 DomainName FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
	SELECT @cmd = 'showgrps ' + @save_DomainName + '\' + @save_SQLSvcAcct
	--Print '		'+@cmd
	DELETE FROM #showgrps
	INSERT INTO #showgrps EXEC master.sys.xp_cmdshell @cmd--, no_output
	DELETE FROM #showgrps WHERE cmdoutput IS NULL
	DELETE FROM #showgrps WHERE cmdoutput LIKE '%is a member of%'
	DELETE FROM #showgrps WHERE cmdoutput LIKE '%everyone%'
	UPDATE #showgrps SET cmdoutput = LTRIM(RTRIM(cmdoutput))
	--select * from #showgrps


	IF EXISTS (SELECT 1 FROM #miscTempTable WHERE cmdoutput LIKE '%' + @save_SQLSvcAcct + '%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAccount_LocalAdmin', 'verified', 'pass', '')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #miscTempTable l, #showgrps s WHERE l.cmdoutput = s.cmdoutput)
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAccount_LocalAdmin', 'verified via group', 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAccount_LocalAdmin', @save_SQLSvcAcct, 'fail', 'Service account not found in local admin group')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start verify sql services set properly
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify sql services set properly')


	SELECT @cmd = 'sc query state= all'
	--Print '		'+@cmd
	DELETE FROM #scTempTable
	INSERT INTO #scTempTable EXEC master.sys.xp_cmdshell @cmd--, no_output
	DELETE FROM #scTempTable WHERE sc_data IS NULL
	DELETE FROM #scTempTable WHERE sc_data NOT LIKE '%service[_]name%'
	DELETE FROM #scTempTable WHERE sc_data NOT LIKE '% mssql%' AND sc_data NOT LIKE '% sql%'
select * from #scTempTable


	IF (SELECT COUNT(*) FROM #scTempTable) > 0
	   BEGIN
		start_sctemp:
		SELECT @save_sc_data = (SELECT TOP 1 sc_data FROM #scTempTable ORDER BY sc_data)
		SELECT @save_sc_data_part = REPLACE(@save_sc_data, 'SERVICE_NAME:', '')
		SELECT @save_sc_data_part = RTRIM(LTRIM(@save_sc_data_part))


		SELECT @cmd = 'sc qc "' + @save_sc_data_part + '" 2048'
		--Print '		'+@cmd
		DELETE FROM #scTempTable2
		INSERT INTO #scTempTable2 EXEC master.sys.xp_cmdshell @cmd--, no_output
		DELETE FROM #scTempTable2 WHERE sc_data IS NULL
		--select * from #scTempTable2

		SELECT @save_start_type = (SELECT TOP 1 sc_data FROM #scTempTable2 WHERE sc_data LIKE '%START_TYPE%')
		SELECT @save_start_type = REPLACE(@save_start_type, 'START_TYPE', '')
		SELECT @save_start_type = REPLACE(@save_start_type, ':', '')
		SELECT @save_start_type = REPLACE(@save_start_type, ' ', '')
		SELECT @save_start_type = RTRIM(LTRIM(@save_start_type))

		SELECT @save_display_name = (SELECT TOP 1 sc_data FROM #scTempTable2 WHERE sc_data LIKE '%DISPLAY_NAME%')
		SELECT @save_display_name = REPLACE(@save_display_name, 'DISPLAY_NAME', '')
		SELECT @save_display_name = REPLACE(@save_display_name, ':', '')
		SELECT @save_display_name = RTRIM(LTRIM(@save_display_name))


		SELECT @save_SERVICE_START_NAME = (SELECT TOP 1 sc_data FROM #scTempTable2 WHERE sc_data LIKE '%SERVICE_START_NAME%')
		SELECT @save_SERVICE_START_NAME = REPLACE(@save_SERVICE_START_NAME, 'SERVICE_START_NAME', '')
		SELECT @save_SERVICE_START_NAME = REPLACE(@save_SERVICE_START_NAME, ':', '')
		SELECT @save_SERVICE_START_NAME = RTRIM(LTRIM(@save_SERVICE_START_NAME))


		SELECT @cmd = 'sc query "' + @save_sc_data_part +'"'
		--Print '		'+@cmd
		DELETE FROM #miscTempTable
		INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd--, no_output
		DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
		DELETE FROM #miscTempTable WHERE cmdoutput NOT LIKE '%state%'
		--select * from #miscTempTable

		SELECT @save_svc_state = (SELECT TOP 1 cmdoutput FROM #miscTempTable WHERE cmdoutput LIKE '%STATE%')
		SELECT @save_svc_state = REPLACE(@save_svc_state, 'STATE', '')
		SELECT @save_svc_state = REPLACE(@save_svc_state, ':', '')
		SELECT @save_svc_state = REPLACE(@save_svc_state, ' ', '')
		SELECT @save_svc_state = RTRIM(LTRIM(@save_svc_state))


		IF @save_sc_data_part LIKE '%MSSQLServerAD%'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
		   END
		ELSE IF @save_sc_data_part LIKE '%MSSQLFDLauncher%'
		   BEGIN
			--  check running
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_svc_state LIKE '%running%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_start_type LIKE '%DEMAND_START%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF (SELECT OSname FROM dbo.DBA_serverinfo WHERE sqlname = @@SERVERNAME) LIKE '%Server 2003%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'warning', 'low-privileged local user account should be used for this.')
			   END
			ELSE IF @save_SERVICE_START_NAME LIKE '%local%' or @save_SERVICE_START_NAME LIKE '%FDlauncher%' or @save_SERVICE_START_NAME LIKE '%SQLadmin%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%MSSQLServerOLAPService%'
		   BEGIN
			--  check running
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_svc_state LIKE '%running%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_start_type LIKE '%AUTO_START%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF (SELECT OSname FROM dbo.DBA_serverinfo WHERE sqlname = @@SERVERNAME) LIKE '%Server 2003%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'warning', 'low-privileged local user account should be used for this.')
			   END
			ELSE IF @save_SERVICE_START_NAME LIKE '%local%' or @save_SERVICE_START_NAME LIKE '%ServerOLAPService%' or @save_SERVICE_START_NAME LIKE '%SQLadmin%'
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%SQL Server Distributed Replay%'
		   BEGIN
			--  Show status
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')


			--  show start parm
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')


			--  Show Svc Account
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')

		   END
		ELSE IF @save_sc_data_part LIKE '%SQLEXPRESS%'
		   BEGIN
			--  Show status
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')


			--  show start parm
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')


			--  Show Svc Account
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')

		   END


		ELSE IF @save_sc_data_part LIKE '%MSSQL%'
		   OR @save_sc_data_part LIKE '%SQLSERVERAGENT%'
		   OR @save_sc_data_part LIKE '%SQLAGENT%'
		   BEGIN
			--  If this is a SQL named instance, make sure we are checking the right service
			IF @@SERVICENAME <> 'MSSQLSERVER' AND @save_sc_data_part NOT LIKE '%$' + @@SERVICENAME + '%'
			   BEGIN
				GOTO skip_svc
			   END


			--  check running
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_svc_state LIKE '%running%'
    			 BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_start_type LIKE '%AUTO_START%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF @save_SERVICE_START_NAME LIKE '%SQLadmin%' OR @save_SERVICE_START_NAME LIKE '%RoyaltyDatabase%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%SQLBrowser%'
		   BEGIN
			--  check running
			IF @save_svc_state LIKE '%running%' OR (SELECT COUNT(*) FROM dbo.Local_ServerEnviro WHERE env_type = 'SQL Port' AND env_detail = '1433') > 0
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_start_type LIKE '%AUTO_START%' OR (SELECT COUNT(*) FROM dbo.Local_ServerEnviro WHERE env_type = 'SQL Port' AND env_detail = '1433') > 0
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF @save_SERVICE_START_NAME LIKE '%SQLadmin%'
			   OR @save_SERVICE_START_NAME LIKE '%RoyaltyDatabase%'
			   OR @save_SERVICE_START_NAME LIKE '%LOCALSERVICE%'
			   OR (SELECT COUNT(*) FROM dbo.Local_ServerEnviro WHERE env_type = 'SQL Port' AND env_detail = '1433') > 0
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%SQLdm%'
		   BEGIN
			--  check running
			IF @save_svc_state LIKE '%running%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_start_type LIKE '%AUTO_START%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF @save_SERVICE_START_NAME LIKE '%SQLadmin%' OR @save_SERVICE_START_NAME LIKE '%RoyaltyDatabase%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%SQLWriter%'
		   BEGIN
			--  check running
			IF @save_svc_state LIKE '%running%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_start_type LIKE '%AUTO_START%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF @save_SERVICE_START_NAME LIKE '%Local%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE IF @save_sc_data_part LIKE '%SQLBackupAgent%'
		   BEGIN
			--  If this is a SQL named instance, make sure we are checking the right service
			IF @@SERVICENAME <> 'MSSQLSERVER' AND @save_sc_data_part <> 'SQLBackupAgent_' + @@SERVICENAME
			   BEGIN
				GOTO skip_svc
			   END


			SELECT @save_Redgate_flag = 'y'

			--  check running
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_svc_state LIKE '%running%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcState_' + @save_sc_data_part, @save_svc_state, 'fail', '')
			   END


			--  Auto Start
			IF @save_Cluster is not null
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'na', 'see cluster resource info')
			   END
			ELSE IF @save_start_type LIKE '%AUTO_START%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcStartType_' + @save_sc_data_part, @save_start_type, 'fail', '')
			   END


			--  Svc Account
			IF @save_SERVICE_START_NAME LIKE '%SQLadmin%' OR @save_SERVICE_START_NAME LIKE '%RoyaltyDatabase%'
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'pass', '')
			   END
			ELSE
    			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_' + @save_sc_data_part, @save_SERVICE_START_NAME, 'fail', '')
			   END
		   END
		ELSE
		   BEGIN
   			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('SvcAcct_error' + @save_sc_data_part, 'Unknown service found', 'fail', 'no code to process this server at this time')
		   END


		skip_svc:


		DELETE FROM #scTempTable WHERE sc_data = @save_sc_data
		IF (SELECT COUNT(*) FROM #scTempTable) > 0
		   BEGIN
			GOTO start_sctemp
		   END


	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	-----------------------------  START VERIFY MASTER DB SETTINGS  ------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify master DB settings')


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'master')
	IF @save_DB_owner = 'sa'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('master_owner', @save_DB_owner, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('master_owner', @save_DB_owner, 'fail', 'master owner should be "sa"')
	   END


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'master')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('master_RecoveryModel', @save_RecoveryModel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('master_RecoveryModel', @save_RecoveryModel, 'fail', 'master recovery model should be SIMPLE')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


	-----------------------------------------------------------------------------------------
	--  Start login and security config
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start login and security config')


	--  verify security audit level set to 'failure' (self heal)
	INSERT INTO #loginconfig EXEC master.sys.xp_loginconfig
	DELETE FROM #loginconfig WHERE name IS NULL
	--select * from #loginconfig


	SELECT @save_loginmode = (SELECT configvalue FROM #loginconfig WHERE name = 'login mode')
	IF @save_loginmode IS NULL
	   BEGIN
		SELECT @save_loginmode = 'unknown'
	   END

	IF  @save_loginmode = 'Mixed'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Security_loginmode', @save_loginmode, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Security_loginmode', @save_loginmode, 'warning', '')
	   END


	SELECT @save_auditlevel = (SELECT configvalue FROM #loginconfig WHERE name = 'audit level')
	IF @save_auditlevel IS NULL
	   BEGIN
		SELECT @save_auditlevel = 'unknown'
	   END

	IF  @save_auditlevel = 'failure'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Security_auditlevel', @save_auditlevel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Security_auditlevel', @save_auditlevel, 'warning', '')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end
END


BEGIN	------------------------------  VERIFY TEMPDB DB SETTINGS  -----------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Verify TempDB DB')


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'tempdb')
	IF @save_DB_owner = 'sa'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_owner', @save_DB_owner, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_owner', @save_DB_owner, 'fail', 'Tempdb owner should be "sa"')
	   END


	IF EXISTS(SELECT 1 FROM tempdb.sys.sysusers WITH (NOLOCK) WHERE name = 'guest' AND status = 0 AND hasdbaccess = 1)
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_guest', 'verified', 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_guest', '', 'fail', 'The guest needs to have access to Tempdb')
	   END


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'tempdb')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_RecoveryModel', @save_RecoveryModel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_RecoveryModel', @save_RecoveryModel, 'fail', 'Tempdb recovery model should be SIMPLE')
	   END


	--  Get the system DB path
	SELECT @save_master_filepath = (SELECT filename FROM master.sys.sysfiles WITH (NOLOCK) WHERE fileid = 1)
	SELECT @save_master_filepath = REVERSE(@save_master_filepath)
	SELECT @charpos = CHARINDEX('\', @save_master_filepath)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_master_filepath = SUBSTRING(@save_master_filepath, @charpos+1, LEN(@save_master_filepath))
	   END
	SELECT @save_master_filepath = REVERSE(@save_master_filepath)


	--  Get the tempdb drive letter
	SELECT @save_tempdb_filedrive = (SELECT physical_name FROM tempdb.sys.database_files WITH (NOLOCK) WHERE FILE_ID = 1)
	SELECT @charpos = CHARINDEX('\', @save_tempdb_filedrive)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_tempdb_filedrive = LEFT(@save_tempdb_filedrive, @charpos) + '%'
	   END


	IF EXISTS(SELECT 1 FROM tempdb.sys.sysfiles WITH (NOLOCK) WHERE groupid <> 0 AND filename LIKE @save_master_filepath + '%')
	   BEGIN
 		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_location', 'Tempdb has not been moved from the original install path', 'pass', '')
	   END
	ELSE IF (SELECT COUNT(*) FROM master.sys.master_files
		WHERE name NOT IN (SELECT name FROM tempdb.sys.database_files)
		AND Physical_name LIKE @save_tempdb_filedrive) = 0
	   BEGIN
		SELECT @save_tempdb_filecount = (SELECT tempdb_filecount FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
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

		IF EXISTS(SELECT 1 FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME AND CONVERT(INT, RTRIM(@save_tempdb_filecount)) < CONVERT(INT, RTRIM(@save_tempdb_corecount)))
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_filecount', @save_tempdb_filecount, 'fail', 'Tempdb file count is less than the CPU core count')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_filecount', @save_tempdb_filecount, 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
 		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Tempdb_location', 'Tempdb has not been moved from the original install path', 'pass', '')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	-------------------------------  VERIFY MSDB DB SETTINGS  ------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Verify MSDB DB')


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'msdb')
	IF @save_DB_owner = 'sa'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_owner', @save_DB_owner, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_owner', @save_DB_owner, 'fail', 'msdb owner should be "sa"')
	   END


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'msdb')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_RecoveryModel', @save_RecoveryModel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_RecoveryModel', @save_RecoveryModel, 'fail', 'msdb recovery model should be SIMPLE')
	   END
END


BEGIN	-----------------------------------  CHECK AGENT JOBS  ---------------------------------------
	----------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------
	--
	--									AGENT JOB SYSTEM CHECKS
	--
	----------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------


	-- RESET HISTORY MAXIMUMS FOR AUTO PRUNING AS SAFETY NET
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
	SELECT @MSG='AUTO FIXING AGENT HISTORY MAXIMUMS',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint


	EXEC msdb.dbo.sp_set_sqlagent_properties
			@jobhistory_max_rows		= 50000
			,@jobhistory_max_rows_per_job	= 1500


	-- ATTEMPT TO SELF HEAL ANY JOB LOG OUTPUT FILES THAT CAN AUTOMATICLY BE FIXED
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
	SELECT @MSG='AUTO FIXING JOB LOG OUTPUT',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
	SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint


	EXEC DBAOps.dbo.dbasp_FixJobLogOutputFiles
			@NestLevel		= @NestLevel
			,@Verbose		= @Verbose
			,@PrintOnly		= @PrintOnly

	BEGIN -- POPULATE @JobStatusResults WITH DATA TO LATER EVALUATE JOB STEP CONDITIONS


		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='POPULATING @JobStatusResults',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint

		-- FIX ANY INVALID DURATION ENTRIES (SEEN CASUED BY JOB RUNNING AS DAYLIGHT SAVING SET BACK AN HOUR)
		UPDATE [msdb].[dbo].[sysjobhistory]
		SET run_duration = 1
		WHERE run_duration < 0


		;WITH		JobHistoryData
					AS
					(
					SELECT		job_id
								,ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY [StartDateTime])		AS RowNumber
								,ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY [StartDateTime] DESC)	AS RowNumberInversion
								,COUNT(*) OVER (PARTITION BY job_id)									AS SetCount
								,(@FilterOutlierPercent
									* COUNT(*) OVER (PARTITION BY job_id))
									/ 100																AS OutlierRowCount
								,ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY [Duration_Seconds])	AS ValueRankAsc
								,ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY [Duration_Seconds]DESC)AS ValueRankDesc
								,StartDateTime	[START]
								,EndDateTime	[Stop]
								,Duration_Seconds [Seconds]
								,run_status
								,MESSAGE
					FROM		(
								SELECT		msdb.dbo.agent_datetime(run_date,run_time) AS StartDateTime
											,DATEADD(s,DATEDIFF(s,msdb.dbo.agent_datetime(run_date,0),msdb.dbo.agent_datetime(run_date,run_duration%240000)+(run_duration/240000)),msdb.dbo.agent_datetime(run_date,run_time)) AS EndDateTime
											,DATEDIFF(s,msdb.dbo.agent_datetime(run_date,0),msdb.dbo.agent_datetime(run_date,run_duration%240000)+(run_duration/240000)) AS Duration_Seconds
											,*
								FROM		msdb..sysjobhistory
								WHERE		step_id = 0
								) JobHistory
					)
					,F0
					AS
					(
					SELECT		job_id
								,RowNumber
					FROM		JobHistoryData
					WHERE		run_status = 0
					)
					,F1
					AS
					(
					SELECT		job_id
								,RowNumber
								,RowNumber - ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY RowNumber) AS Grp
					FROM		F0
					)
					,S0
					AS
					(
					SELECT		job_id
								,RowNumber
					FROM		JobHistoryData
					WHERE		run_status = 1
					)
					,S1
					AS
					(
					SELECT		job_id
								,RowNumber
								,RowNumber - ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY RowNumber) AS Grp
					FROM		S0
					)
					,T1
					AS
					(
					SELECT		job_id
								,RowNumber
								,ROW_NUMBER() OVER (PARTITION BY job_id,Grp ORDER BY RowNumber) AS Consecutive
					FROM		F1
					UNION ALL
					SELECT		job_id
								,RowNumber
								,ROW_NUMBER() OVER (PARTITION BY job_id,Grp ORDER BY RowNumber) AS Consecutive
					FROM		S1
					)
					,DailyFailRate
					AS
					(
					SELECT		job_id
								,AVG([DailyExecutionsCount])	[AvgDailyExecutionsCount]
								,MAX([DailyExecutionsCount])	[MaxDailyExecutionsCount]
								,AVG([DailyFailCount])			[AvgDailyFailCount]
								,MAX([DailyFailCount])			[MaxDailyFailCount]
								,AVG([DailyFailPercent])		[AvgDailyFailPercent]
								,MAX([DailyFailPercent])		[MaxDailyFailPercent]
					FROM		(
								SELECT		job_id
											,CAST(CONVERT(VARCHAR(12),[START],101)AS DATETIME)	AS [StartDay]
											,COUNT(*)+0.0										AS [DailyExecutionsCount]
											,COUNT(CASE run_status WHEN 0 THEN 1 END)+0.0		AS [DailyFailCount]
											,(100*(COUNT(CASE run_status WHEN 0 THEN 1 END)+0.0))
												/(COUNT(*)+0.0)									AS [DailyFailPercent]
								FROM		JobHistoryData
								GROUP BY	job_id
											,CAST(CONVERT(VARCHAR(12),[START],101)AS DATETIME)
								)DFR
					GROUP BY	job_id
					)
					,FloatingAverage
					AS
					(
					SELECT		[JobHistoryData].job_id
								,[JobHistoryData].RowNumber
								,AVG([JobHistoryData3].Seconds)				AS AVG_Value
								,STDEVP([JobHistoryData3].Seconds)			AS STDEVP_Value
					FROM		[JobHistoryData]
					JOIN		(
								SELECT		*
								FROM		[JobHistoryData]
								WHERE		ValueRankAsc	> OutlierRowCount
										AND	ValueRankDesc	> OutlierRowCount
								) [JobHistoryData3]
							ON	[JobHistoryData].job_id	= [JobHistoryData3].job_id
							AND ABS([JobHistoryData].RowNumber - [JobHistoryData3].RowNumber) < @FloatRange
					GROUP BY	[JobHistoryData].job_id
								,[JobHistoryData].RowNumber
					)
					,Results
					AS
					(
					SELECT		T1.job_id
								,T1.RowNumber
								,T1.RowNumberInversion
								,T1.Start
								,T1.Stop
								,T1.Seconds
								,run_status
								,CASE run_status
									WHEN 0 THEN 'Failure'
									WHEN 1 THEN 'Success'
									WHEN 2 THEN 'Retry'
									WHEN 3 THEN 'Cancelled'
									WHEN 4 THEN 'Running'
									ELSE 'Other: ' +
									CONVERT(VARCHAR,run_status)
								  END AS run_status_msg
								,MESSAGE
								,ABS(Seconds-AVG_Value)/ISNULL(NULLIF(STDEVP_Value,0),1)		AS DevsFromAvg
								,CAST(ABS(Seconds-AVG_Value)/ISNULL(NULLIF(STDEVP_Value,0),1)/2 AS INT) AS TREND
								,T2.AVG_Value
								,T2.STDEVP_Value
					FROM		[JobHistoryData] T1
					LEFT JOIN	[FloatingAverage] T2
							ON	T1.job_id = T2.job_id
							AND T1.RowNumber = T2.RowNumber
					)
					,JobActivity
					AS
					(
					SELECT		TOP 1 WITH ties
								a.job_id
								,j.name AS job_name
								,CASE WHEN stop_execution_date IS NULL	THEN start_execution_date ELSE NULL END start_execution_date
								,CASE WHEN start_execution_date IS NULL THEN 0		WHEN stop_execution_date IS NULL THEN COALESCE(last_executed_step_id+1,1)						ELSE 0		END AS step_execution
								,CASE WHEN start_execution_date IS NULL THEN NULL	WHEN stop_execution_date IS NULL THEN COALESCE(last_executed_step_date,start_execution_date)	ELSE NULL	END AS step_execution_date
								,CASE WHEN start_execution_date IS NOT NULL AND stop_execution_date IS NULL THEN a.job_history_id ELSE NULL END job_history_id
								,next_scheduled_run_date
					FROM		msdb..sysjobactivity a
					JOIN		msdb..sysjobs j
							ON	j.job_id = a.job_id
					ORDER BY RANK() OVER(ORDER BY a.session_id DESC)
					)
					,JobSchedules
					AS
					(
					SELECT		JS.job_id
								,COUNT(*) [Schedules]
								,COUNT(CASE WHEN S.enabled = 1 THEN 1 END) [EnabledSchedules]
								,MIN(CASE WHEN S.enabled = 1 THEN msdb.dbo.agent_datetime(COALESCE(NULLIF(JS.next_run_date,0),20000101),JS.next_run_time) END) NextRunDateTime
					FROM		msdb.dbo.sysjobschedules JS
					JOIN		msdb.dbo.sysschedules S
							ON	S.schedule_id = JS.schedule_id
					GROUP BY	JS.job_id
					)
		INSERT INTO	@JobStatusResults
		SELECT		j.name JobName
					,(SELECT name FROM sys.syslogins WHERE sid = MAX(J.owner_sid))	AS [Owner name]
					,MAX(COALESCE(j.enabled,0))					AS [Enabled]
					,MAX(COALESCE(JS.[Schedules],0))				AS [Schedules]
					,MAX(COALESCE(JS.[EnabledSchedules],0))				AS [EnabledSchedules]
					,AVG(AVG_Value)							AS [Weighted Average Run Duration]
					,AVG(Seconds)							AS [Average Run Duration]
					,AVG(DevsFromAvg)						AS [AVGDevs]
					,COUNT(CASE WHEN [START] >= @Today
								THEN 1 END) 				AS [ExecutionsToday]
					,COUNT(CASE WHEN [START] >= @Today AND [Trend] >= 20
								THEN 1 END)				AS [OutliersToday]
					,COUNT(*)							AS [Executions]
					,MAX([START])							AS [lastrun]

					,COUNT(CASE run_status WHEN 0 THEN 1 END)			AS [Failures]
					,COUNT(CASE
							WHEN [START] >=
							CAST(CONVERT(VARCHAR(12),GETDATE(),101)AS DATETIME)
							AND [run_status]= 0 THEN 1 END)							AS [FailuresToday]
					,MAX(CASE RowNumberInversion WHEN 1 THEN [run_status] END)		AS [LastStatus]
					,MAX(CASE RowNumberInversion WHEN 1 THEN [run_status_msg] END)	AS [LastStatusMsg]
					,MAX(CASE RowNumberInversion WHEN 1 THEN T1.Consecutive END)	AS [CurrentCount]
					,MAX(DFR.[AvgDailyExecutionsCount])								AS [AvgDailyExecutionsCount]
					,MAX(DFR.[MaxDailyExecutionsCount])								AS [MaxDailyExecutionsCount]
					,MAX(DFR.[AvgDailyFailCount])									AS [AvgDailyFailCount]
					,MAX(DFR.[MaxDailyFailCount])									AS [MaxDailyFailCount]
					,MAX(DFR.[AvgDailyFailPercent])									AS [AvgDailyFailPercent]
					,MAX(DFR.[MaxDailyFailPercent])									AS [MaxDailyFailPercent]
					,MIN(JS.[NextRunDateTime])										AS [next_scheduled_run_date]
		FROM		msdb..sysjobs J
		LEFT JOIN	Results JH
				ON	J.job_id = JH.job_id
		LEFT JOIN	T1
				ON	T1.job_id = jh.job_id
				AND	T1.RowNumber = jh.RowNumber
		LEFT JOIN	DailyFailRate DFR
				ON	DFR.job_id = J.job_id
		LEFT JOIN	JobSchedules JS
				ON	JS.job_id = J.job_id
		GROUP BY	J.Name


	END


	---sqlagent history max set above 1000, 100 (self heal)
	EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
										   N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
										   N'JobHistoryMaxRows',
										   @jobhistory_max_rows OUTPUT,
										   N'no_output'
	EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
										   N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
										   N'JobHistoryMaxRowsPerJob',
										   @jobhistory_max_rows_per_job OUTPUT,
										   N'no_output'


	IF @jobhistory_max_rows < 50000
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_jobhistory_maxrows', CONVERT(NVARCHAR(10), @jobhistory_max_rows), 'fail', 'jobhistory maxrows must be at least 50,000')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_jobhistory_maxrows', CONVERT(NVARCHAR(10), @jobhistory_max_rows), 'pass', '')
	   END


	IF @jobhistory_max_rows_per_job < 1500
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_jobhistory_maxrowsperjob', CONVERT(NVARCHAR(10), @jobhistory_max_rows_per_job), 'fail', 'jobhistory maxrows/job must be at least 1,500')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('msdb_jobhistory_maxrowsperjob', CONVERT(NVARCHAR(10), @jobhistory_max_rows_per_job), 'pass', '')
	   END


	IF	@save_envname != 'production'
		AND	EXISTS (SELECT 1 FROM dbo.dba_dbinfo WHERE SQLname = @@SERVERNAME AND DEPLstatus = 'y')
		AND	NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WITH (NOLOCK) WHERE name = 'DBAOps - Monitor')
		BEGIN
			EXEC DBAOps.dbo.dpsp_addjob_streamline
			WAITFOR delay '00:00:05'
		END

	BEGIN	------------------------------ EVALUEATE STANDARD JOBS  ----------------------------------


	--  Set variables for maint jobs (different for prod and non-prod)
	Select @save_sched_maint_parm01 = 1
	Select @save_sched_tlog_parm02 = 1
	Select @save_sched_archive_parm03 = 169
	Select @save_sched_maint_parm04 = 25


	If @save_envname = 'Production'
	   begin
		Select @save_sched_maint_parm01 = 0
		Select @save_sched_archive_parm03 = 30


		If (select count(*) from master.sys.databases where recovery_model_desc = 'FULL' and database_id > 4 and state = 0 and is_read_only = 0) > 0
		   begin
			Select @save_sched_tlog_parm02 = 0
		   end
	   end


	--  If this is Friday or Saturday, the daily maint job may not run for 48 hours
	If DATEPART ( dw , getdate()) > 5 -- Friday or Saturday
	   begin
		Select @save_sched_maint_parm04 = 48
	   end


	;WITH		StandardJobs
				AS
				(
				SELECT	'MAINT - Daily Backup and DBCC' [JobName]			-- DO I REALLY NEED TO EXPLAIN THIS?
						,@save_sched_maint_parm04					[HrsBetweenRuns]	-- IF NOT RUN FOR X HOURS JOB IS IN ERROR. -- 24=DAY 168=WEEK 744=MONTH
						,@save_sched_maint_parm01					[Can_NotScheduled]	-- JOB DOES NOT NEED TO BE SCHEDULED OR ENABLED.
						,0								[Must_NotScheduled]	-- JOB SHOULD NOT BE SCHEDULED OR ENABLED.
						,0								[DeplJobs]		-- JOBS ONLY INCLUDED IF DEPL SERVER
				UNION ALL
				SELECT	'MAINT - Daily Index Maintenance'			, 25,@save_sched_maint_parm01,0,0	UNION ALL
				SELECT	'MAINT - TranLog Backup'				, 25,@save_sched_tlog_parm02,0,0	UNION ALL
				SELECT	'MAINT - Weekly Backup and DBCC'			,169,@save_sched_maint_parm01,0,0	UNION ALL
				SELECT	'MON - SQL Performance Reporting'			,169,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Archive process'				, @save_sched_archive_parm03,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Check Misc process'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Check Periodic'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Errorlog Check'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Log Parser'					, 25,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Nightly Processing'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - DBA Update Files'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - SQLTrace Process'				, 25,1,0,0	UNION ALL
				SELECT	'UTIL - PERF Check Non-Use'				, 25,0,0,0	UNION ALL
				SELECT	'UTIL - PERF Stat Capture Process'			, 25,0,0,0	UNION ALL
				SELECT	'UTIL - PERF Weekly Processing'				,169,0,0,0	UNION ALL
				SELECT	'DBAOps - 00 Controller'				,  0,0,1,1	UNION ALL
				SELECT	'DBAOps - 01 Restore'				,  0,0,1,1	UNION ALL
				SELECT	'DBAOps - 51 Deploy'					,  0,0,1,1	UNION ALL
				SELECT	'DBAOps - 99 Post'					,  0,0,1,1	UNION ALL
				SELECT	'DBAOps - Monitor'					,  0,0,0,1	UNION ALL
				SELECT	'BASE - Local Process'					,169,0,0,1	UNION ALL
				SELECT	'UTIL - SQLTrace (Critical Response)'			,  0,0,1,0
				)
				,NoCheckJobs
				AS
				(
				 SELECT		[detail02]		AS JobName
							,[detail03]*24	AS [HrsBetweenRuns]
				 FROM		DBAOps.dbo.no_check
				 WHERE		NoCheck_type	= 'SQLHealth'
				 AND		detail01		= 'SQLjob'
				)
	INSERT INTO #temp_results
		OUTPUT	'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO	@OutputComments

	SELECT		CAST([subject01] AS VARCHAR(MAX))
				,CAST([value01] AS VARCHAR(MAX))
				,CAST(CASE WHEN [notes01] IS NULL THEN 'pass' ELSE 'fail' END  AS VARCHAR(MAX))
				,CAST(COALESCE([notes01],'')  AS VARCHAR(MAX))
	FROM		(
				SELECT		'SQLAgent Standard Job' [subject01]
							,T1.JobName [value01]
							,CASE	WHEN	T2.JobName IS NULL							THEN 'Standard Job ['+ T1.JobName + '] Does Not Exist.'
								WHEN	T2.Enabled = 0
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Is Disabled.'
								WHEN	T2.Schedules = 0
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Is Not Scheduled.'
								WHEN	T2.Enabled = 1
										AND T1.[Must_NotScheduled] = 1				THEN 'Standard Job ['+ T1.JobName + '] Is Enabled and Should Not Be.'
								--WHEN	T2.Schedules > 0
								--		AND T1.[Must_NotScheduled] = 1				THEN 'Standard Job ['+ T1.JobName + '] Is Scheduled and Should Not Be.'
								WHEN	T2.EnabledSchedules = 0
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Has It''s Schedule Disabled.'
								WHEN	T2.LastRun IS NULL
										AND T2.next_scheduled_run_date < GETDATE()
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Has Not Run.  Next Run Date Is In The Past.'
								WHEN	T2.LastRun IS NULL
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Has Never Run.'
								WHEN	DATEDIFF(HOUR,T2.LastRun,GETDATE())
										> COALESCE(NCJ.[HrsBetweenRuns],T1.[HrsBetweenRuns])
										AND T1.[Can_NotScheduled] = 0
										AND T1.[Must_NotScheduled] = 0				THEN 'Standard Job ['+ T1.JobName + '] Has Not Run In Over ' + CAST(DATEDIFF(HOUR,T2.LastRun,GETDATE()) AS VARCHAR(10)) + ' Hours'
								END AS  [notes01]
				FROM		StandardJobs T1
				LEFT JOIN	@JobStatusResults T2
						ON	T1.JobName = T2.JobName
				LEFT JOIN	NoCheckJobs NCJ
						ON	NCJ.JobName = T1.JobName
				WHERE		T1.DeplJobs = 0				--  skip the sql job stream check unless not production and at least one deployable DB.
						OR	CASE WHEN @save_envname = 'production' OR (SELECT COUNT(*) FROM dbo.dba_dbinfo WHERE SQLname = @@SERVERNAME AND DEPLstatus = 'y') = 0 THEN 0 ELSE 1 END = 1
				) JobStatusResults


	UNION ALL


	SELECT		'SQLAgent Generic Job'			AS [subject01]
				,JobName						AS [value01]
				,[LEVEL]						AS [grade01]
				,CAST([Alert] AS VARCHAR(MAX))	AS [notes01]
	FROM		(
				SELECT		'warning' AS [LEVEL]
							,JobName
							,'The Job "'
							+JobName
							+'" has run longer or shorter than expected '+CAST(OutliersToday AS VARCHAR(10))+' times Today.'  AS [Alert]
				FROM		@JobStatusResults
				WHERE		Enabled = 1
				AND COALESCE(OutliersToday,0) > 0
				AND LastStatus = 1
				AND [AverageRunDuration] > 90
				AND JobName not like 'UTIL - Central%'
				UNION ALL


				SELECT		CASE WHEN [FailuresToday] > [CurrentCount] THEN 'fail' ELSE
							'warning' END AS [LEVEL]
							,JobName
							,'The Job "'
							+JobName
							+'" has Failed '+CAST(FailuresToday AS VARCHAR(10))+' times Today.'  AS [Alert]
				FROM		@JobStatusResults
				WHERE		Enabled = 1 AND COALESCE(FailuresToday,0) > 0 AND LastStatus = 1
				UNION ALL


				SELECT		'fail' AS [LEVEL]
							,JobName
							,'The Job "'
							+JobName
							+'" last execution on "'+CAST(lastrun AS VARCHAR(50))+'" Failed'
							+ CASE WHEN CurrentCount > 1 THEN ', and has Failed ' +CAST(CurrentCount AS VARCHAR(5))+ ' times in a row.' ELSE '.' END AS [Alert]
				FROM		@JobStatusResults
				WHERE		Enabled = 1 AND LastStatus = 0
				UNION ALL

				SELECT		'warning' AS [LEVEL]
							,JobName
							,'The Job "'
							+JobName
							+'" is owned by "'+OwnerName+'" rather than "SA".' AS [Alert]
				FROM		@JobStatusResults
				WHERE		Enabled = 1 AND OwnerName != 'sa' AND OwnerName not in (select detail01 from dbo.no_check where NoCheck_type = 'JobOwner')
				UNION ALL


				SELECT		'warning' AS [LEVEL]
							,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							,'The Job "'
							+(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							+'" (step '+ CAST(step_id AS VARCHAR(5)) +') "'
							+step_name
							+'" Points to Database "'+database_name+'" rather than Master or msdb.' AS [Alert]
				FROM		msdb..sysjobsteps T1
				JOIN		msdb..sysjobs T2
						ON	T1.job_id = T2.job_id
				WHERE		Enabled = 1 AND database_name not in ('master', 'msdb')	and not exists(select 1 from dbo.no_check where NoCheck_type = 'JobDBpointer')


				UNION ALL
				SELECT		'fail' AS [LEVEL]
							,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							,'The Job "'
							+(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							+'" (step '+ CAST(step_id AS VARCHAR(5)) +') "'
							+step_name
							+'" Does not have an output log.' AS [Alert]
				FROM		msdb..sysjobsteps T1
				JOIN		msdb..sysjobs T2
						ON	T1.job_id = T2.job_id
				WHERE		Enabled = 1 AND NULLIF(output_file_name,'') IS NULL AND T1.subsystem not in ('LogReader', 'Snapshot')
					AND	T2.owner_sid = '0x01'

				UNION ALL
				SELECT		'warning' AS [LEVEL]
							,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							,'The Job "'
							+(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							+'" (step '+ CAST(step_id AS VARCHAR(5)) +') "'
							+step_name
							+'" Output Log File points to "'+output_file_name+'", not to the "SQLjob_logs" share.' AS [Alert]
				FROM		msdb..sysjobsteps T1
				JOIN		msdb..sysjobs T2
						ON	T1.job_id = T2.job_id
				WHERE		Enabled = 1 AND output_file_name NOT LIKE @JobLog_Share_Path +'%'
						AND	output_file_name NOT LIKE '\\'+CAST(SERVERPROPERTY('machinename')AS VARCHAR(50))+'\'+@JobLog_Share_Name +'\%'
						AND	T2.owner_sid = '0x01'

				UNION ALL
				SELECT		'warning' AS [LEVEL]
							,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							,'The Job "'
							+(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
							+'" (step '+ CAST(step_id AS VARCHAR(5)) +') "'
							+step_name
							+'" Output Log File is set to Overwrite instead of Append.' AS [Alert]
				FROM		msdb..sysjobsteps T1
				JOIN		msdb..sysjobs T2
						ON	T1.job_id = T2.job_id
				WHERE		T2.Enabled = 1 AND flags & 2 != 2


				--UNION ALL
				--SELECT		'warning' AS [LEVEL]
				--			,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
				--			,'The Job "'
				--			+(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)
				--			+'" (step '+ CAST(step_id AS VARCHAR(5)) +') "'
				--			+step_name
				--			+'" Step Output Not Included in History.' AS [Alert]
				--FROM		msdb..sysjobsteps T1
				--JOIN		msdb..sysjobs T2
				--		ON	T1.job_id = T2.job_id
				--WHERE		T2.Enabled = 1 AND flags & 4 != 4
				) Alerts
	END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	----------------------------------  VERIFY DBAOps DB  ---------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Verify DBAOps DB')


	IF (SELECT PATINDEX( '%[8].[00]%', @@version ) ) <> 0
	   BEGIN
		GOTO Skip_DBAOps
	   END

	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'DBAOps')
	IF @save_DB_owner = 'sa'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('DBAOps_owner', @save_DB_owner, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('DBAOps_owner', @save_DB_owner, 'fail', 'DBAOps owner should be "sa"')
	   END


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'DBAOps')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('DBAOps_RecoveryModel', @save_RecoveryModel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('DBAOps_RecoveryModel', @save_RecoveryModel, 'fail', 'DBAOps recovery model should be SIMPLE')
	   END


	If exists (select 1 from master.sys.databases where name = 'DBAOps' and is_local_cursor_default = 1)
	   BEGIN
		ALTER DATABASE DBAOps SET CURSOR_DEFAULT GLOBAL;
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('DBAOps_is_local_cursor_default', '', 'warning', 'Setting for is_local_cursor_default was LOCAL.  Now set to GLOBAL.')
	   END


	Skip_DBAOps:


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	----------------------------------  VERIFY DBAPERF DB  ---------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Verify DBAPerf DB')


	IF (SELECT PATINDEX( '%[8].[00]%', @@version ) ) <> 0
	   BEGIN
		GOTO Skip_dbaperf
	   END

	IF NOT EXISTS (SELECT 1 FROM master.sys.databases WITH (NOLOCK) WHERE name = 'dbaperf')
	 BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf', '', 'fail', 'The dbaperf DB does not exist')
	   END
	ELSE
	   BEGIN
   		SELECT @save_status = (SELECT state_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'dbaperf')


		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf', @save_status, 'pass', '')
	   END


	SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = 'dbaperf')
	IF @save_DB_owner = 'sa'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf_owner', @save_DB_owner, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf_owner', @save_DB_owner, 'fail', 'dbaperf owner should be "sa"')
	   END


	SELECT @save_RecoveryModel = (SELECT recovery_model_desc FROM master.sys.databases WITH (NOLOCK) WHERE name = 'dbaperf')
	IF @save_RecoveryModel = 'SIMPLE'
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf_RecoveryModel', @save_RecoveryModel, 'pass', '')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('dbaperf_RecoveryModel', @save_RecoveryModel, 'fail', 'dbaperf recovery model should be SIMPLE')
	   END


	Skip_dbaperf:


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	------------------------------  START VERIFY STANDARD SHARES  --------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify standard shares')


	-- backup
	SELECT @save_sharename = @save_servername2 + '_backup'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_backup', '', 'fail', 'The standard backup share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_backup', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_backup_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_backup_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_backup_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	--dba_archive
	SELECT @save_sharename = 'DBA_Archive'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_archive', '', 'fail', 'The standard dba_archive share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_archive', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_archive_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_archive_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_archive_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	-- dbasql
	SELECT @save_sharename = @save_servername2 + '_dbasql'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dbasql', '', 'fail', 'The standard dbasql share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dbasql', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dbasql_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dbasql_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dbasql_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	-- ldf
	SELECT @save_sharename = @save_servername2 + '_ldf'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_ldf', '', 'fail', 'The standard ldf share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_ldf', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_ldf_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_ldf_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_ldf_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	--  mdf
	SELECT @save_sharename = @save_servername2 + '_mdf'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_mdf', '', 'fail', 'The standard mdf share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_mdf', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_mdf_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_mdf_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_mdf_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	--  log
	SELECT @save_sharename = @save_servername2 + '_log'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_log', '', 'fail', 'The standard log share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_log', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_log_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_log_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_log_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	--  SQLjob_logs
	SELECT @save_sharename = @save_servername2 + '_SQLjob_logs'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_SQLjob_logs', '', 'fail', 'The standard SQLjob_logs share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_SQLjob_logs', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_SQLjob_logs_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_SQLjob_logs_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_SQLjob_logs_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	--  Look for large files in SQLjob_logs
	SELECT @cmd = 'DIR "\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs" /-c /O-S'


	DELETE FROM #dir_results
	INSERT #dir_results
	EXEC ('master.sys.xp_cmdshell ''' + @cmd + '''')
	DELETE FROM #dir_results WHERE dir_row IS NULL
	DELETE FROM #dir_results WHERE dir_row LIKE '%Volume in drive%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%Volume Serial Number%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%Directory of%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%<DIR>%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%File(s)%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%Dir(s)%'
	--select * from #dir_results


	If (select count(*) from #dir_results) > 0
	   begin
		SELECT @save_text = (SELECT TOP 1 dir_row FROM #dir_results)
		SELECT @save_text = SUBSTRING(@save_text, 21, 19)
		SELECT @file_size = LTRIM(RTRIM(@save_text))


		IF @file_size > 900000000 --900mb
		   BEGIN
			INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		('share_SQLjob_logs-FileSize', '', 'fail', 'A large file exists in this share.')
		   END
	   end


	-- builds
	SELECT @save_sharename = @save_servername + '_builds'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_builds', '', 'fail', 'The standard builds share does not exist')
	   END
	ELSE
	 BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_builds', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_builds_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_builds_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_builds_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	-- dba_mail
	SELECT @save_sharename = @save_servername + '_dba_mail'
	EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
	IF @share_outpath IS NULL
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_mail', '', 'fail', 'The standard dba_mail share does not exist')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_mail', @share_outpath, 'pass', '')
	   END


	SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	EXEC master.sys.xp_cmdshell @cmd, no_output
	SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
	DELETE FROM #ShareTempTable
	INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


	IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_mail_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
	   END
	ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_mail_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_dba_mail_security', '', 'pass', '')
		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END


	IF EXISTS (SELECT 1 FROM master.sys.databases WITH (NOLOCK) WHERE name IN (SELECT DB_NAME FROM db_sequence))
	   AND @save_envname <> 'production'
	   BEGIN
		-- base
		SELECT @save_sharename = @save_servername + '_base'
		EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
		IF @share_outpath IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_base', '', 'fail', 'The standard BASE share does not exist.  Creating share now.')
			EXEC dbo.dbasp_create_NXTshare
			GOTO skip_share_base
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_base', @share_outpath, 'pass', '')
		   END


		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
		SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		DELETE FROM #ShareTempTable
		INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


		IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_base_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
		   END
		ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_base_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_base_security', '', 'pass', '')
			SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   END


		skip_share_base:


		-- nxt
		SELECT @save_sharename = @save_servername2 + '_nxt'
		EXEC dbo.dbasp_get_share_path @save_sharename, @share_outpath OUTPUT
		IF @share_outpath IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_nxt', '', 'fail', 'The standard NXT share does not exist.  Creating share now.')
			EXEC dbo.dbasp_create_NXTshare
			GOTO skip_share_nxt
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_nxt', @share_outpath, 'pass', '')
		   END


		SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		EXEC master.sys.xp_cmdshell @cmd, no_output
		SELECT @cmd = 'mkdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
		DELETE FROM #ShareTempTable
		INSERT INTO #ShareTempTable EXEC master.sys.xp_cmdshell @cmd


		IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%denied%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_nxt_security', '', 'fail', 'xp_cmdshell unable to run mkdir')
		   END
		ELSE IF EXISTS (SELECT 1 FROM #ShareTempTable WHERE PATH LIKE '%already exists%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_nxt_security', '', 'warning', 'test folder SQLHealthCheck54321 should be deleted.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('share_nxt_security', '', 'pass', '')
			SELECT @cmd = 'rmdir \\' + @save_servername + '\' + @save_sharename + '\SQLHealthCheck54321' + @save_sqlinstance
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   END


		skip_share_nxt:
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	----------------------------------  START VERIFY UTILITIES  ----------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify Utilities')


	--rmtshare
	SELECT @cmd = 'rmtshare /?'


	DELETE FROM #miscTempTable
	INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd
	DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
	--select * from #regresults


	IF EXISTS (SELECT 1 FROM #miscTempTable WHERE cmdoutput LIKE '%is not recognized%')
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		CAST('	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01) AS VARCHAR(100)) AS [CHECK drive USAGE (history, growth rate, projected growth)]
		VALUES ('utility_rmtshare', 'rmtshare is not recognized', 'fail', 'The rmtshare utility was not found in the default path')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_rmtshare', 'rmtshare utility found', 'pass', '')
	   END


	--winzip
--	SELECT @cmd = 'wzzip -a c:\test.zip c:\*.txxt'
--
--	DELETE FROM #miscTempTable
--	INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd
--	DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
--	--select * from #miscTempTable
--
--	IF EXISTS (SELECT 1 FROM #miscTempTable WHERE cmdoutput LIKE '%is not recognized%')
--	   BEGIN
--		INSERT INTO #temp_results
--			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
--			INTO		@OutputComments
--			VALUES		('utility_winzip', 'winzip is not recognized', 'fail', 'The winzip utility was not found in the default path')
--	   END
--	ELSE
--	   BEGIN
--		SELECT @save_winzip_build = (SELECT TOP 1 cmdoutput FROM #miscTempTable WHERE cmdoutput LIKE '%build%')
--		INSERT INTO #temp_results
--			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
--			INTO		@OutputComments
--			VALUES		('utility_winzip', @save_winzip_build, 'pass', '')
--	   END


	--redgate
	IF @save_Redgate_flag = 'y'
	   BEGIN
		IF NOT EXISTS (SELECT 1 FROM master.sys.objects WITH (NOLOCK) WHERE name = 'sqlbackup' AND type = 'x')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_Redgate_version', 'Redgate is not installed', 'fail', 'The Redgate service was found but the extended sprocs in master were not found')
			GOTO Redgate_end
		   END
		ELSE
		   BEGIN
			SELECT @save_rg_version = (SELECT env_detail FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_rg_version')
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_Redgate_version', @save_rg_version, 'pass', '')
		   END


		SELECT @save_rg_versiontype = (SELECT env_detail FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_rg_versiontype')
		IF @save_rg_versiontype LIKE '%trial%'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_Redgate_versiontype', @save_rg_versiontype, 'fail', 'Redgate Trial version found')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_Redgate_versiontype', @save_rg_versiontype, 'pass', '')
		   END


		--  Further redgate settings to check
		DELETE FROM #miscTempTable
		INSERT INTO #miscTempTable EXEC master.dbo.sqbutility @Parameter1=1008,@Parameter2=@p2 OUTPUT
		--select * from #miscTempTable
		--select @p2


		IF @p2 LIKE '%LogDelete=0%'
		   BEGIN
			INSERT INTO #miscTempTable EXEC master.dbo.sqbutility @Parameter1=1041,@Parameter2=N'LogDelete',@Parameter3=1,@Parameter4=@p4 OUTPUT
			INSERT INTO #miscTempTable EXEC master.dbo.sqbutility @Parameter1=1041,@Parameter2=N'LogDeleteHours',@Parameter3=168,@Parameter4=@p5 OUTPUT
		   END

		--  No tests set up for further redgate settings at this time (they would go here)


	   END
	ELSE
	   BEGIN
		IF EXISTS (SELECT 1 FROM dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type LIKE 'backup_rg%')
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('utility_Redgate_Local_ServerEnviro', 'Redgate is not installed', 'fail', 'Entries for Redgate were found in the Local_ServerEnviro table')
			GOTO Redgate_end
		   END
	   END


	Redgate_end:


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	-----------------------------  START VERIFY BACKUP SETTINGS  ---------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify Backup Settings')


	IF (SELECT @@version) NOT LIKE '%Server 2005%' AND (SELECT SERVERPROPERTY ('productversion')) > '10.50.0000'
	   BEGIN
		IF EXISTS (SELECT 1 FROM DBAOps.dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_type')
		   BEGIN
			DELETE FROM DBAOps.dbo.Local_ServerEnviro WHERE env_type = 'backup_type'
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', 'Standard', 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', 'Standard', 'pass', '')
		   END
	   END
	ELSE IF @save_Redgate_flag = 'y'
	   BEGIN
		IF NOT EXISTS (SELECT 1 FROM DBAOps.dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_type' AND Env_detail = 'RedGate')
		   BEGIN
			SELECT @save_backuptype = (SELECT Env_detail FROM DBAOps.dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_type')
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', @save_backuptype, 'fail', 'Redgate is installed but not being used as the default')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', 'Redgate', 'pass', '')
		   END
	   END
	ELSE
	   BEGIN
		IF EXISTS (SELECT 1 FROM DBAOps.dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_type')
		   BEGIN
			SELECT @save_backuptype = (SELECT Env_detail FROM DBAOps.dbo.Local_ServerEnviro WITH (NOLOCK) WHERE env_type = 'backup_type')
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', @save_backuptype, 'fail', 'There should be no backup_type in the Local_ServerEnviro table for this instance')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('default_backup_type', 'Standard', 'pass', '')
		   END
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	--------------------------------  START VERIFY DATABASES  ------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify Databases')


	IF DB_ID('DBAOps') IS NOT NULL
	BEGIN	-- DATABASE CHANGE CHECKS
		;WITH		DBStatusComparison
					AS
					(
					SELECT		COALESCE(T1.DBName,T2.Name) AS DBName
								,CASE
									WHEN T1.Status Like 'Remove%'												THEN 'Ignored'
									WHEN T2.Name IS NULL														THEN 'Removed'
									WHEN T1.DBName IS NULL														THEN 'Added'
									WHEN T1.Status != T2.state_desc COLLATE SQL_Latin1_General_CP1_CI_AS		THEN 'StatusChange_'+T2.state_desc COLLATE SQL_Latin1_General_CP1_CI_AS
									ELSE ''
									END	AS [status]
								,CASE
									WHEN T1.CreateDate < T2.Create_Date											THEN 'Drop&Create_'+CAST( T2.Create_Date AS VARCHAR(MAX))
									ELSE ''
									END	AS [CreateDate]
								,CASE
									WHEN T1.RecovModel
											!= T2.recovery_model_desc COLLATE SQL_Latin1_General_CP1_CI_AS		THEN 'RecoveryModelChange_'+T2.recovery_model_desc COLLATE SQL_Latin1_General_CP1_CI_AS
									ELSE ''
									END	AS [RecovModel]
								,CASE
									WHEN T1.Trustworthy !=
											CASE T2.is_trustworthy_on WHEN 1 THEN 'y' ELSE 'n' END				THEN 'TrustworthyChange_'+CASE T2.is_trustworthy_on WHEN 1 THEN 'Y' ELSE 'N' END
									ELSE ''
									END	AS [TRUSTWORTHY]
								,'' AS [Mirroring]
								--,CASE
								--	WHEN T1.Mirroring !=
								--			CASE WHEN T3.mirroring_guid IS NULL THEN 'n' ELSE 'y' END			THEN 'MirroringChange_'+CASE WHEN T3.mirroring_guid IS NULL THEN 'N' ELSE 'Y' END
								--	ELSE ''
								--	END	AS [Mirroring]
								,CASE
									WHEN T1.FullTextCat !=
											CASE WHEN T4.database_id IS NULL THEN 'n' ELSE 'y' END				THEN 'FullTextChange_'+CASE WHEN T4.database_id IS NULL THEN 'N' ELSE 'Y' END
									ELSE ''
									END	AS [FullTextCat]
								,CASE
									WHEN T1.Repl_Flag !=
											CASE	T2.is_published
													| T2.is_subscribed
													| T2.is_merge_published
													| T2.is_subscribed
													WHEN 1 THEN 'y' ELSE 'n' END								THEN 'ReplChange_'+CASE	T2.is_published
																																		| T2.is_subscribed
																																		| T2.is_merge_published
																																		| T2.is_subscribed
																																		WHEN 1 THEN 'Y' ELSE 'N' END
									ELSE ''
									END	AS [Repl_Flag]
								,CASE
									WHEN T1.DBCompat != T2.compatibility_level									THEN 'CompatChange_'+CAST(T2.compatibility_level AS VARCHAR(MAX))
									ELSE	''
									END AS [DBCompat]
					FROM		DBAOps.dbo.DBA_DBInfo T1
					FULL JOIN	sys.databases T2
							ON	T1.DBName = T2.Name COLLATE SQL_Latin1_General_CP1_CI_AS
					--LEFT JOIN	sys.Database_Mirroring T3
					--		ON	T2.database_id = T3.database_id
					LEFT JOIN	(SELECT DISTINCT database_id FROM sys.dm_fts_active_catalogs) T4
							ON	T2.database_id = T4.database_id
					WHERE		COALESCE(T1.SQLName,@@SERVERNAME) = @@SERVERNAME
					)
		INSERT INTO @DBStatusChanges
		SELECT		DBName
					,REPLACE(REPLACE(ISNULL(NULLIF(STUFF(REPLACE(REPLACE(REPLACE(
						','+[status]+','+[CreateDate]+','+[RecovModel]+','+[TRUSTWORTHY]+
						','+[Mirroring]+','+[FullTextCat]+','+[Repl_Flag]+','+[DBCompat]
						,',,',','),',,',','),',,',','),1,1,''),''),'NoChanges')+'|',',|',''),'|','')
		FROM		DBStatusComparison
		WHERE		DBName NOT IN ('TempDB')
				AND DBName NOT LIKE 'z_snap%'
				AND DBName NOT IN (select detail01 from dbo.no_check where NoCheck_type in ('backup', 'prerestore'))
				AND status != 'Ignored'
		ORDER BY	1

		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments

		SELECT		DBName+'_'+StatusChanges
					,'DB_'+StatusChanges
					,@CritFail
					,DBName + ' has recently been ' + StatusChanges + '. If ok, run "update DBAOps.dbo.dba_dbinfo set status = ''removed'' where dbname = ''' + DBName + '''"'
		FROM		@DBStatusChanges
		WHERE		StatusChanges IN ('Removed')
		UNION
		SELECT		DBName+'_'+StatusChanges
					,'DB_'+StatusChanges
					,'Warning'
					,DBName + ' has experienced the following changes, (' + StatusChanges + ').'
		FROM		@DBStatusChanges
		WHERE		StatusChanges NOT IN ('Removed', 'NoChanges')


	END

	DELETE FROM #miscTempTable
	INSERT INTO #miscTempTable
	SELECT		name
	FROM		master.sys.databases
	WHERE		database_id > 4
			AND source_database_id IS NULL
			AND name not in (SELECT DBName From DBAOps.dbo.DBA_DBInfo WHERE SQLName = @@SERVERNAME AND status Like 'Remove%')
	--select * from #miscTempTable

	--  Ignore any secondary AvailGrp DB's
	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		Delete from #miscTempTable where cmdoutput in (Select dbcs.database_name
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
						   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
						where agstates.primary_replica <> @@servername)
	   end


	IF (SELECT COUNT(*) FROM #miscTempTable) > 0
	   BEGIN
		start_databases:
		SELECT @save_DBname = (SELECT TOP 1 cmdoutput FROM #miscTempTable ORDER BY cmdoutput)
		SELECT @save_DBname = RTRIM(@save_DBname)

		INSERT INTO @OutputComments VALUES('	Start process for database ' + @save_DBname)


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


		----------------------------------------------------------------------------------------------
		--  Special code for login DBAasapir  --------------------------------------------------------
		----------------------------------------------------------------------------------------------
		If exists (select 1 from [dbo].[Local_ServerEnviro] where env_type = 'ENVname' and env_detail in ('production', 'stage', 'staging'))
		  and (@save_DBname in (select db_name from [dbo].[db_sequence]) or @save_DBname in ('DBAOps', 'dbaperf'))
		  and (SELECT DATABASEPROPERTYEX(@save_DBname, 'Status')) = 'ONLINE'
		  and (SELECT DATABASEPROPERTYEX(@save_DBname, 'Updateability')) = 'READ_WRITE'
		   begin
			Select @cmd = 'use ' + @save_DBname + ' If not exists (select 1 from sys.database_principals where name = ''DBAasapir'') CREATE USER [DBAasapir];'
			print @cmd
			exec(@cmd)


			Select @cmd = 'use ' + @save_DBname + ' exec sp_addrolemember ''db_datareader'', ''DBAasapir'';'
			print @cmd
			exec(@cmd)
		   end


		--  DB Settings
		--  check status
		SELECT @save_check_type = 'Status'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))
		SELECT @save_DBid = (SELECT database_id FROM sys.databases WHERE name = @save_DBname)


		IF @save_check = 'RESTORING' AND EXISTS (SELECT 1 FROM master.sys.database_mirroring WHERE database_id = @save_DBid AND mirroring_guid IS NOT NULL)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, 'pass', @save_DBname+' is a mirrored copy of the database pending failover')
			GOTO skip_DB
		   END
		Else IF @save_check = 'RESTORING'
		   BEGIN

			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, 'pass', @save_DBname+' is pending restore completion')
			GOTO skip_DB
		   END
		ELSE IF @save_check = 'OFFLINE'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, @CritFail, @save_DBname+' is OFFLINE at this time')
			GOTO skip_DB
		   END
		ELSE IF @save_check <> 'ONLINE'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, @CritFail, @save_DBname+' is not ONLINE at this time')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, 'pass', '')
		   END


		--  check updateability
		SELECT @save_check_type = 'Updateability'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF @save_check = 'READ_ONLY'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_status', @save_check, 'pass', @save_DBname+' is in READ_ONLY mode at this time')


			IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'logship' AND detail01 = @save_DBname)
			   BEGIN
				INSERT INTO #temp_results
				OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
				INTO		@OutputComments
				VALUES		(@save_DBname+'_status', @save_check, 'pass', @save_DBname+' is a logshipping database')
			   END


			GOTO skip_DB
		   END


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check Collation
		SELECT @save_check_type = 'Collation'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check ComparisonStyle
		SELECT @save_check_type = 'ComparisonStyle'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAnsiNullDefault
		SELECT @save_check_type = 'IsAnsiNullDefault'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAnsiNullsEnabled
		SELECT @save_check_type = 'IsAnsiNullsEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAnsiPaddingEnabled
		SELECT @save_check_type = 'IsAnsiPaddingEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAnsiWarningsEnabled
		SELECT @save_check_type = 'IsAnsiWarningsEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		 END


		--  check IsArithmeticAbortEnabled
		SELECT @save_check_type = 'IsArithmeticAbortEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAutoClose
		SELECT @save_check_type = 'IsAutoClose'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAutoCreateStatistics
		SELECT @save_check_type = 'IsAutoCreateStatistics'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAutoShrink
		SELECT @save_check_type = 'IsAutoShrink'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsAutoUpdateStatistics
		SELECT @save_check_type = 'IsAutoUpdateStatistics'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsCloseCursorsOnCommitEnabled
		SELECT @save_check_type = 'IsCloseCursorsOnCommitEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsInStandBy
		SELECT @save_check_type = 'IsInStandBy'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsLocalCursorsDefault
		SELECT @save_check_type = 'IsLocalCursorsDefault'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsMergePublished
		SELECT @save_check_type = 'IsMergePublished'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsNullConcat
		SELECT @save_check_type = 'IsNullConcat'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsNumericRoundAbortEnabled
		SELECT @save_check_type = 'IsNumericRoundAbortEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsParameterizationForced
		SELECT @save_check_type = 'IsParameterizationForced'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsPublished
		SELECT @save_check_type = 'IsPublished'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsRecursiveTriggersEnabled
		SELECT @save_check_type = 'IsRecursiveTriggersEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsSubscribed
		SELECT @save_check_type = 'IsSubscribed'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsSyncWithBackup
		SELECT @save_check_type = 'IsSyncWithBackup'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check IsTornPageDetectionEnabled
		SELECT @save_check_type = 'IsTornPageDetectionEnabled'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check LCID
		SELECT @save_check_type = 'LCID'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  check SQLSortOrder
		SELECT @save_check_type = 'SQLSortOrder'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_check <> @save_old_check
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' ' + @save_check_type + ' setting has changed from '+@save_old_check)


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  Security Settings
		SELECT @save_DB_owner = (SELECT SUSER_SNAME(owner_sid) FROM master.sys.databases WITH (NOLOCK) WHERE name = @save_DBname)


		IF @save_DB_owner LIKE '%' + @save_SQLSvcAcct + '%'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', 'null', 'warning', @save_DBname+' owner is set to the SQL service account.  Updated to "sa"')


			SELECT @cmd = 'ALTER AUTHORIZATION ON DATABASE::' + @save_DBname + ' TO sa;'
			--Print '		'+@cmd
			EXEC master.sys.sp_executeSQL @cmd
		   END
		IF @save_DB_owner IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', 'null', 'fail', @save_DBname+' owner is null - should be "sa"')
		   END
		ELSE IF @save_DB_owner = 'sa'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', @save_DB_owner, 'pass', '')
		   END
		ELSE IF EXISTS (SELECT 1 FROM dbo.No_Check WHERE NoCheck_type = 'DBowner' AND Detail01 = @save_DBname AND Detail02 = @save_DB_owner)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', @save_DB_owner, 'pass', '')
		   END
		ELSE IF EXISTS (SELECT 1 FROM dbo.No_Check WHERE NoCheck_type = 'DBowner' AND Detail01 = 'AllDBs' AND Detail02 = @save_DB_owner)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', @save_DB_owner, 'pass', '')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_owner', @save_DB_owner, 'fail', @save_DBname+' owner should be "sa"')
		   END


		--  check UserAccess
		SELECT @save_check_type = 'UserAccess'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))

		IF @save_check <> 'MULTI_USER'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, @CritFail, @save_DBname+' is not set for MULTI_USER')


			UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  Recovery Model
		SELECT @save_check_type = 'Recovery'
		SELECT @save_check = (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@save_DBname, @save_check_type)))


		IF NOT EXISTS(SELECT 1 FROM dbo.HealthCheck_current WHERE DBname = @save_DBname AND Check_type = @save_check_type)
		   BEGIN
			INSERT INTO dbo.HealthCheck_current VALUES (@save_DBname, @save_check_type, @save_check, @CheckDate)
		   END


		SELECT @save_old_check = (SELECT TOP 1 Check_detail FROM dbo.HealthCheck_current WITH (NOLOCK) WHERE DBname = @save_DBname AND Check_type = @save_check_type)

		IF @save_envname = 'production'
		   BEGIN
			IF @save_check <> @save_old_check
			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'warning', @save_DBname+' recovery model has changed from '+@save_old_check)


				UPDATE dbo.HealthCheck_current SET Check_detail = @save_check, check_date = @CheckDate WHERE DBname = @save_DBname AND Check_type = @save_check_type
			   END
			ELSE
			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
			   END
		   END
		ELSE IF @save_check = 'FULL'
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'fail', @save_DBname+' recovery model should be SIMPLE')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_'+@save_check_type, @save_check, 'pass', '')
		   END


		--  Current backups
		IF @save_envname = 'production' AND @nocheck_backup_flag = 'n'
		   BEGIN
			--  Get the backup time for the last full database backup
			SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
								WHERE database_name = @save_DBname
								AND backup_finish_date IS NOT NULL
								AND type IN ('D', 'F')
								ORDER BY backup_start_date DESC)

			SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)

			IF @hold_backup_start_date IS NULL
			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DBbackup', 'null', @CritFail, @save_DBname+': No DBbackup found')
			   END
			ELSE IF @hold_backup_start_date < @CheckDate-8
			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DBbackup', @save_backup_start_date, @CritFail, @save_DBname+': No recent DBbackup found')
			   END
			ELSE
			   BEGIN
				INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DBbackup', @save_backup_start_date, 'pass', '')
			   END


			--  If the last DB backup time was older than the @backup_diff_dd_period limit, check for differentials
			IF @hold_backup_start_date < @CheckDate-2 AND DATABASEPROPERTY(RTRIM(@save_DBname), 'IsTrunclog') = 0
			   BEGIN
				SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
									WHERE database_name = @save_DBname
									AND backup_finish_date IS NOT NULL
									AND type = 'I'
									ORDER BY backup_start_date DESC)

				SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)


				IF @hold_backup_start_date IS NULL
				   BEGIN
					INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DIFFbackup', 'null', 'fail', @save_DBname+': No Differential backup found')
				   END
				ELSE IF @hold_backup_start_date < @CheckDate-8
				   BEGIN
					INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DIFFbackup', @save_backup_start_date, 'fail', @save_DBname+': No recent Differential backup found')
				   END
				ELSE
				   BEGIN
					INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DIFFbackup', @save_backup_start_date, 'pass', '')
				   END
			   END


			--  check for tranlog backups
			IF DATABASEPROPERTY(RTRIM(@save_DBname), 'IsTrunclog') = 0
			   BEGIN
				SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
									WHERE database_name = @save_DBname
									AND backup_finish_date IS NOT NULL
									AND type = 'L'
									ORDER BY backup_start_date DESC)

				SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)


				IF @hold_backup_start_date IS NULL
				   BEGIN
					INSERT INTO #temp_results
					OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
					INTO		@OutputComments
					VALUES		(@save_DBname+'_Tranlogbackup', 'null', 'fail', @save_DBname+': No Tranlog backup found')
				   END
				ELSE IF @hold_backup_start_date < @CheckDate-1
				   BEGIN
					INSERT INTO #temp_results
					OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
					INTO		@OutputComments
					VALUES		(@save_DBname+'_Tranlogbackup', @save_backup_start_date, 'fail', @save_DBname+': No recent Tranlog backup found')
				   END
				ELSE
				   BEGIN
					INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_Tranlogbackup', @save_backup_start_date, 'pass', '')
				   END
			   END
		   END

		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Process Orphaned Users
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('Process Orphaned Users')


		--  Double Check users marked as orphaned.  If any were marked in error, set delete flag to 'x'
		INSERT INTO #orphans 	EXECUTE('select sid, name from [' + @save_DBname + '].sys.sysusers
					where sid not in (select sid from master.sys.syslogins where name is not null and sid is not null)
					and name not in (''guest'')
					and sid is not null
					and issqlrole = 0
					')


		UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'x'
					WHERE Delete_flag = 'n'
					AND SOL_type = 'user'
					AND SOL_DBname = @save_DBname
					AND SOL_name NOT IN (SELECT orph_name FROM #orphans)


		--  Drop users orphaned for more than 7 days
		DELETE FROM #temp_tbl1
		INSERT #temp_tbl1(text01) SELECT SOL_name
		   FROM dbo.Security_Orphan_Log
		   WHERE Delete_flag = 'n'
		   AND SOL_type = 'user'
		   AND SOL_DBname = @save_DBname
		   AND Initial_Date < @CheckDate-7
		DELETE FROM #temp_tbl1 WHERE text01 IS NULL


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		start_delete_DBusers:
		IF (SELECT COUNT(*) FROM #temp_tbl1) > 0
		   BEGIN


			-----------------------------------------------------------------------------------------
			--  Start verify (and cleanup) for Users
			-----------------------------------------------------------------------------------------
			SELECT		@OutputComment = ''
			DELETE		@OutputComments
			INSERT INTO @OutputComments VALUES('Start verify (and cleanup) for Users')


			SELECT @save_user_name = (SELECT TOP 1 text01 FROM #temp_tbl1)
			INSERT INTO @OutputComments VALUES('	Processing User: ' + @save_user_name)


			SELECT @cmd = N'select top 1 @save_user_sid = sid from [' + @save_DBname +'].[sys].[database_principals] where name = ''' + @save_user_name + ''''
			EXEC sp_executesql @cmd, N'@save_user_sid varchar(255) output', @save_user_sid = @save_user_sid OUTPUT


			DELETE FROM #Objects


			-- Checking for cases in sys.objects where ALTER AUTHORIZATION has been used
			SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
					  SELECT ''' + @save_DBname + ''', dp.name, so.name, so.type_desc
					  FROM [' + @save_DBname + '].sys.database_principals dp
						JOIN [' + @save_DBname + '].sys.objects so
						  ON dp.principal_id = so.principal_id
					  WHERE dp.sid = ''' + @save_user_sid + ''';';
			EXEC(@SQL);


			   -- Checking for cases where the login owns one or more schema
			   SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
				 SELECT ''' + @save_DBname + ''', dp.name, sch.name, ''SCHEMA''
				 FROM [' + @save_DBname + '].sys.database_principals dp
				   JOIN [' + @save_DBname + '].sys.schemas sch
					 ON dp.principal_id = sch.principal_id
				 WHERE dp.sid = ''' + @save_user_sid + ''';';
			   EXEC(@SQL);


			   -- Checking for cases where the login owns assemblies
			   SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
				 SELECT ''' + @save_DBname + ''', dp.name, assemb.name, ''Assembly''
				 FROM [' + @save_DBname + '].sys.database_principals dp
				   JOIN [' + @save_DBname + '].sys.assemblies assemb
					 ON dp.principal_id = assemb.principal_id
				 WHERE dp.sid = ''' + @save_user_sid + ''';';
			   EXEC(@SQL);

			   -- Checking for cases where the login owns asymmetric keys
			   SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
				 SELECT ''' + @save_DBname + ''', dp.name, asym.name, ''Asymm. Key''
				 FROM [' + @save_DBname + '].sys.database_principals dp
				   JOIN [' + @save_DBname + '].sys.asymmetric_keys asym
					 ON dp.principal_id = asym.principal_id
				 WHERE dp.sid = ''' + @save_user_sid + ''';';
			   EXEC(@SQL);

			   -- Checking for cases where the login owns symmetric keys
			   SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
				 SELECT ''' + @save_DBname + ''', dp.name, sym.name, ''Symm. Key''
				 FROM [' + @save_DBname + '].sys.database_principals dp
				   JOIN [' + @save_DBname + '].sys.symmetric_keys sym
					 ON dp.principal_id = sym.principal_id
				 WHERE dp.sid = ''' + @save_user_sid + ''';';
			   EXEC(@SQL);

			   -- Checking for cases where the login owns certificates
			   SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
				 SELECT ''' + @save_DBname + ''', dp.name, cert.name, ''Certificate''
				 FROM [' + @save_DBname + '].sys.database_principals dp
				   JOIN [' + @save_DBname + '].sys.certificates cert
					 ON dp.principal_id = cert.principal_id
				 WHERE dp.sid = ''' + @save_user_sid + ''';';
			EXEC(@SQL);


			DELETE FROM #Objects WHERE ObjectName IS NULL


			IF (SELECT COUNT(*) FROM #Objects) > 0
			   BEGIN


				Start_dbuser_alterauth:
				SELECT @save_ObjectName = (SELECT TOP 1 ObjectName FROM #Objects)
				SELECT @save_ObjectType = (SELECT TOP 1 ObjectType FROM #Objects WHERE ObjectName = @save_ObjectName)


				IF @save_ObjectType = 'SCHEMA'
				   BEGIN
					SELECT @cmd = 'use [' + @save_DBname + '] ALTER AUTHORIZATION ON SCHEMA::[' + @save_ObjectName + '] TO dbo;'
					--Print '		'+@cmd
					EXEC (@cmd)
				   END
				ELSE IF @save_ObjectType = 'Assembly'
				   BEGIN
					SELECT @cmd = 'use [' + @save_DBname + '] ALTER AUTHORIZATION ON Assembly::[' + @save_ObjectName + '] TO dbo;'
					--Print '		'+@cmd
					EXEC (@cmd)
				   END
				ELSE IF @save_ObjectType = 'Symm. Key'
				   BEGIN
					SELECT @cmd = 'use [' + @save_DBname + '] ALTER AUTHORIZATION ON SYMMETRIC KEY::[' + @save_ObjectName + '] TO dbo;'
					--Print '		'+@cmd
					EXEC (@cmd)
				   END
				ELSE IF @save_ObjectType = 'Certificate'
				   BEGIN
					SELECT @cmd = 'use [' + @save_DBname + '] ALTER AUTHORIZATION ON Certificate::[' + @save_ObjectName + '] TO dbo;'
					--Print '		'+@cmd
					EXEC (@cmd)
				   END
				ELSE
				   BEGIN
					SELECT @cmd = 'use [' + @save_DBname + '] ALTER AUTHORIZATION ON OBJECT::[' + @save_ObjectName + '] TO dbo;'
					--Print '		'+@cmd
					EXEC (@cmd)
				   END
			   END


			DELETE FROM #Objects WHERE ObjectName = @save_ObjectName AND ObjectType = @save_ObjectType
			IF (SELECT COUNT(*) FROM #Objects) > 0
			   BEGIN
				GOTO Start_dbuser_alterauth
			   END

			--  GET OBJECT COUNTS FOR ALL SCHEMAS
			SELECT @cmd = 'Use [' + @save_DBname + '];
			TRUNCATE TABLE #SchemaObjCounts;
			INSERT INTO	#SchemaObjCounts
			select		ss.name
						,COUNT(so.object_id) as objCount
			From		sys.schemas ss WITH(NOLOCK)
			LEFT JOIN	sys.objects so WITH(NOLOCK)
					ON	so.schema_id = ss.schema_id
			GROUP BY	ss.name'
				--Print '		'+@cmd
				EXEC (@cmd)


			--  LIST ALL CURRENT SCHEMAS AND OBJECT COUNTS UNDER THEM
			--SELECT * FROM #SchemaObjCounts


			--  DROP SCHEMA IF IT EXISTS AND NO OBJECTS ARE USING IT.
			SELECT @cmd = 'Use [' + @save_DBname + ']; IF EXISTS(SELECT 1 FROM #SchemaObjCounts where SchemaName ='''+@save_user_name+''' and objCount = 0) DROP SCHEMA [' + @save_user_name + '];'
				--Print '		'+@cmd
				EXEC (@cmd)

			--  DROP USER IF IT STILL EXISTS
			SELECT @cmd = 'Use [' + @save_DBname + ']; IF User_ID('''+@save_user_name+''') IS NOT NULL DROP User [' + @save_user_name + '];'
				--Print '		'+@cmd
				EXEC (@cmd)


			UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'y'
					WHERE Delete_flag = 'n'
					AND SOL_name = @save_user_name
					AND SOL_DBname = @save_DBname


			--  Loop to process more logins
			DELETE FROM #temp_tbl1 WHERE text01 = @save_user_name
			GOTO start_delete_DBusers
		   END


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Check for orphaned Users
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('Check for orphaned Users')


		IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE Delete_flag = 'n' AND SOL_DBname = @save_DBname AND Initial_Date < @CheckDate-7)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Orphaned_status', '', 'fail', 'Orphaned User found (not auto-cleaned).  Run: select * from DBAOps.dbo.Security_Orphan_Log where Delete_flag = ''n''')
		   END
		ELSE IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE Delete_flag = 'n' AND SOL_DBname = @save_DBname)
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		('Orphaned_status', '', 'pass', 'Warning: Orphaned Users exist and have not yet been auto-cleaned.')
		   END


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Check for Build Tables
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('Check for Build Tables')


		IF NOT EXISTS(SELECT 1 FROM dbo.db_sequence WHERE DB_NAME = @save_DBname)
		   BEGIN
			GOTO skip_build_table_check
		   END


		SELECT @cmd = 'USE [' + @save_DBname + ']  SELECT @doesexist = OBJECT_ID(''Build'')'
		--Print '		'+@cmd


		EXEC sp_executesql @cmd, N'@doesexist int output', @doesexist OUTPUT


		IF @doesexist IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_Build_table_check', '', 'fail', @save_DBname+' has No Build Table.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_Build_table_check', '', 'pass', '')
		   END


		SELECT @cmd = 'USE [' + @save_DBname + ']  SELECT @doesexist = OBJECT_ID(''BuildDetail'')'
		--Print '		'+@cmd


		EXEC sp_executesql @cmd, N'@doesexist int output', @doesexist OUTPUT


		IF @doesexist IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_BuildDetail_table_check', '', 'fail', @save_DBname+' has No BuildDetail Table.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_BuildDetail_table_check', '', 'pass', '')
		   END


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end

		skip_build_table_check:


		-----------------------------------------------------------------------------------------
		--  Check for Autogrowth
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('Check for Autogrowth')


		IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'SQLHealth' AND detail01 = 'DBautogrowth' AND detail02 = @save_DBname)
		   BEGIN
			GOTO skip_DBautogrowth_skip
		   END

		SELECT @cmd = 'USE [' + @save_DBname + ']  SELECT @doesexist = (select distinct 1 from sys.database_files where type = 0 and growth > 0)'
		--Print '		'+@cmd
		EXEC sp_executesql @cmd, N'@doesexist int output', @doesexist OUTPUT

		IF @doesexist IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DataFileGrowth_check', '', @CritFail, @save_DBname+' has No data file enabled for growth.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_DataFileGrowth_check', '', 'pass', '')
		   END


		SELECT @cmd = 'USE [' + @save_DBname + ']  SELECT @doesexist = (select distinct 1 from sys.database_files where type = 1 and growth > 0)'
		--Print '		'+@cmd
		EXEC sp_executesql @cmd, N'@doesexist int output', @doesexist OUTPUT

		IF @doesexist IS NULL
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_LogFileGrowth_check', '', @CritFail, @save_DBname+' has No log file enabled for growth.')
		   END
		ELSE
		   BEGIN
			INSERT INTO #temp_results
			OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
			INTO		@OutputComments
			VALUES		(@save_DBname+'_LogFileGrowth_check', '', 'pass', '')
		   END

		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end

		skip_DBautogrowth_skip:

		-----------------------------------------------------------------------------------------
		--  Last DBCC
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('check Last DBCC')


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Active in past 30 days
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('check Active in past 30 days')


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Check DB file size limits
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('check DB file size limits')


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Check Growth Rate changes
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('check Growth Rate changes')

		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		-----------------------------------------------------------------------------------------
		--  Check for ability to grow
		-----------------------------------------------------------------------------------------
		SELECT		@OutputComment = ''
		DELETE		@OutputComments
		INSERT INTO @OutputComments VALUES('check for ability to grow')

		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


		skip_DB:


		--  check for more rows to process
		DELETE FROM #miscTempTable WHERE cmdoutput = @save_DBname
		IF (SELECT COUNT(*) FROM #miscTempTable) > 0
		   BEGIN
			GOTO start_databases
		   END


	   END


		------------------------------------
		--	PRINT OUTPUT
		------------------------------------
		SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
		FROM		@OutputComments
		IF @Verbose > 0
		   begin
			PRINT @OutputComment
		   end


END


BEGIN	-----------------------------------  VERIFY LOGINS  ------------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Start verify (and cleanup) for Logins')


	--  Double Check logins marked as orphaned.  If any were marked in error, set delete flag to 'x'
	INSERT INTO #orphans EXEC master.sys.sp_validatelogins


	UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'x'
				WHERE Delete_flag = 'n'
				AND SOL_type = 'login'
				AND SOL_name NOT IN (SELECT orph_name FROM #orphans)


	--  Drop logins orphaned for more than 7 days
	DELETE FROM #temp_tbl1
	INSERT #temp_tbl1(text01) SELECT SOL_name
	   FROM dbo.Security_Orphan_Log
	   WHERE Delete_flag = 'n'
	   AND SOL_type = 'login'
	   AND Initial_Date < @CheckDate-7
	DELETE FROM #temp_tbl1 WHERE text01 IS NULL


	start_delete_logins:
	IF (SELECT COUNT(*) FROM #temp_tbl1) > 0
	   BEGIN
		SELECT @save_login_name = (SELECT TOP 1 text01 FROM #temp_tbl1)

		SELECT @cmd = 'DROP Login [' + @save_login_name + '];'
			INSERT INTO @OutputComments VALUES('		--'+@cmd)
			EXEC (@cmd)


		IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @save_login_name)
		   BEGIN
			UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'y'
					WHERE Delete_flag = 'n'
					AND SOL_name = @save_login_name
		   END


		--  Loop to process more logins
		DELETE FROM #temp_tbl1 WHERE text01 = @save_login_name
		GOTO start_delete_logins
	   END


	--  Check for orphaned logins
	IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE SOL_type = 'login' AND Delete_flag = 'n' AND Initial_Date < @CheckDate-7)
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES ('Orphaned_status', '', 'fail', 'Orphaned Login found (not auto-cleaned).  Run: select * from DBAOps.dbo.Security_Orphan_Log where Delete_flag = ''n''')
	   END
	ELSE IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE Delete_flag = 'n')
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('Orphaned_status', '', 'pass', 'Warning: Orphaned Logins exist and have not yet been auto-cleaned.')
	   END
	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	--------------------------------  CHECK DISK FORECAST  ---------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('check drive forecast status')


	-- IF FORECAST DATA IS MORE THAN A DAY OLD THEN REPROCESS IT
	If not exists (select * from [DBAperf].[sys].[objects] where name = 'DMV_DRIVE_FORECAST_DETAIL')
	   BEGIN
		RAISERROR('*** CALLING dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport ***',-1,-1) WITH NOWAIT;
		INSERT INTO @OutputComments VALUES('	-- Drive forecast never done, Calculating...')
		EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport
	   END
	ELSE IF (SELECT DATEDIFF(DAY,MAX(RunDate),getdate()) FROM [DBAperf].[dbo].[DMV_DRIVE_FORECAST_DETAIL]) > 1
	   BEGIN
		RAISERROR('*** CALLING dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport ***',-1,-1) WITH NOWAIT;
		INSERT INTO @OutputComments VALUES('	-- Drive forecast too old, Recalculating...')
		EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport
	   END


	-- GENERATE RESULTS
	--DECLARE @CheckDate DateTime;	SET @CheckDate = CAST(CONVERT(VarChar(12),getdate(),101)AS DATETIME)
	--DECLARE @CritFail VarChar(20);	SET @CritFail ='CritFail'
	;WITH		DriveData
				AS
				(
				SELECT	[ServerName]
					,[DriveLetter]
					,[DateTimeValue]
					,[ForecastUsed_MB]
				FROM	[DBAperf].[dbo].[DMV_DRIVE_FORECAST_DETAIL]
				WHERE	RunDate = CAST(CONVERT(VarChar(12),@CheckDate,101)AS DATETIME)
				)
				,[Now]
				AS
				(
				SELECT	*
				FROM	[DriveData]
				WHERE	[DateTimeValue] = (SELECT MIN([DateTimeValue]) FROM [DriveData])
				)
				,[Future]
				AS
				(
				SELECT	*
				FROM	[DriveData]
				WHERE	[DateTimeValue] = (SELECT MAX([DateTimeValue]) FROM [DriveData])
				)
				,
				[AVG]
				AS
				(
				SELECT		[Now].[ServerName]
						,[Now].[DriveLetter]
						,([Future].[ForecastUsed_MB] - [Now].[ForecastUsed_MB]) / DATEDIFF(day,[Now].[DateTimeValue],[Future].[DateTimeValue]) [AvgGrowthPerDay]
				FROM		[NOW]
				JOIN		[Future]
					ON	[Now].[ServerName]	= [Future].[ServerName]
					AND	[Now].[DriveLetter]	= [Future].[DriveLetter]
				)

	INSERT INTO	#temp_results
	OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
	INTO		@OutputComments
	select		'Drive_growth_rateMB_'+T1.DriveLetter
			,CONVERT(NVARCHAR(10),CAST((T2.[AvgGrowthPerDay] * 7) AS NUMERIC(10,2)))+'MB'
			,CASE WHEN T1.[DaysTillFail] < 14 THEN @CritFail WHEN T1.[DaysTillFail] < 90 THEN 'Fail' ELSE 'Pass' END
			,CASE WHEN T1.[DaysTillFail] < 90 THEN 'Drive '+T1.DriveLetter+': will be out of space in ' + CONVERT(NVARCHAR(10),T1.[DaysTillFail]) + ' days at the current growth rate.' ELSE '' END
	FROM		dbaperf.dbo.DMV_DRIVE_FORECAST_SUMMARY T1
	JOIN		[AVG] T2
		ON	T1.[ServerName]		= T2.[ServerName]
		AND	T1.[DriveLetter]	= T2.[DriveLetter]
	WHERE		T1.rundate = CAST(CONVERT(VarChar(12),@CheckDate,101)AS DATETIME)


	SELECT		@OutputComment = ''
	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	-----------------------------------  CHECK SQLmail  ------------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Check for unprocessed *.sml files')


	SELECT @save_dba_mail_path = (SELECT env_detail FROM local_serverenviro WHERE env_type = 'dba_mail_path')
	SELECT @cmd = 'forfiles /P '+@save_dba_mail_path+' /M *.sml -d -1'
	--Print '		'+@cmd


	DELETE FROM #dir_results
	INSERT INTO #dir_results(dir_row) EXEC master.sys.xp_cmdshell @cmd
	DELETE FROM #dir_results WHERE dir_row IS NULL
	DELETE FROM #dir_results WHERE dir_row LIKE '%No files found%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%,TRUE%'
	DELETE FROM #dir_results WHERE dir_row LIKE '%DS_Store%'
	--select * from #dir_results


	IF (SELECT COUNT(*) FROM #dir_results) > 0
	   BEGIN
		--select * from #dir_results
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('SQL Mail files (sml)', '', 'fail', 'Unprocessed SQL mail files (*.sml) found.')
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('SQL Mail files (sml)', '', 'pass', '')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	-----------------------------------  CHECK INDEXmaint  ----------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = ''
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('Check for unprocessed INDEXmaint commands')


	IF exists (select 1 from [dbo].[IndexMaintenanceProcess] where status not in ('completed', 'cancelled'))
	   BEGIN
		--select * from #dir_results
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('INDEXmaint process', '', 'warning', 'Unprocessed INDEXmaint commands.  MAINT job being restarted.')


		exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status1 output
		If @status1 = 'idle'
		   begin
			EXEC msdb.dbo.sp_start_job @job_name = 'MAINT - Daily Index Maintenance', @step_name = 'Run Index Maint'
		   end
	   END
	ELSE
	   BEGIN
		INSERT INTO #temp_results
		OUTPUT		'	-- '+CAST(INSERTED.Subject01 AS CHAR(80))+'	-- '+UPPER(INSERTED.grade01)
		INTO		@OutputComments
		VALUES		('INDEXmaint process', '', 'pass', '')
	   END


	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > 0
	   begin
		PRINT @OutputComment
	   end


END


BEGIN	---------------------------------  OUTPUT ALL FAILURES  --------------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	DELETE		@OutputComments
	INSERT INTO @OutputComments VALUES('List of All Failed Tests:')
	INSERT INTO @OutputComments VALUES('')


	INSERT INTO @OutputComments
	SELECT		'	FAIL:	'
				+LEFT(CAST(Subject01 AS CHAR(100)),(SELECT MAX(LEN(Subject01))+2 FROM #temp_results WHERE grade01 LIKE '%fail%'))
				+' ('
				+LEFT(CAST(value01+')' AS CHAR(100)),(SELECT MAX(LEN(Value01))+3 FROM #temp_results WHERE grade01 LIKE '%fail%'))
				+' ' + notes01
	FROM		#temp_results
	WHERE		grade01 LIKE '%fail%'


	INSERT INTO @OutputComments VALUES('')
	INSERT INTO @OutputComments VALUES('')
	------------------------------------
	--	PRINT OUTPUT
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose >= 0
	   begin
		PRINT @OutputComment
	   end
END


BEGIN	--------------------------  GENERATE REPORT AND UPDATE FILE  ---------------------------------
	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT		@OutputComment = CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
	DELETE		@OutputComments


	IF (SELECT COUNT(*) FROM #temp_results) > 0
		BEGIN


			SELECT		@ColumnWrapCnt =((	SELECT	MAX(LEN(subject01))+2
													+MAX(LEN(value01))+2
													+MAX(LEN(notes01))
											FROM	#temp_results)
											/
											(@PrintWidth-(SELECT MAX(LEN(grade01))+2 FROM #temp_results))
											) + 1


			INSERT INTO	@Report
			---------------------------
			-- COLUMN TITLES
			---------------------------
			SELECT		'' AS [subject]
						,'' AS [value]
						,'' AS [grade]
						,'' AS [notes]
						,CAST(LEFT(CAST(REPLICATE(' ',(MaxLen_Subject-7)/2)+'SUBJECT' AS CHAR(200)),MaxLen_Subject)	+'  '
						+LEFT(CAST(REPLICATE(' ',(MaxLen_Value-5)/2)+'VALUE'	 AS CHAR(200)),MaxLen_Value)	+'  '
						+LEFT(CAST(REPLICATE(' ',(MaxLen_Grade-5)/2)+'GRADE'	 AS CHAR(200)),MaxLen_Grade)	+'  '
						+LEFT(CAST(REPLICATE(' ',(MaxLen_Notes-5)/2)+'NOTES'	 AS CHAR(200)),MaxLen_Notes) AS VARCHAR(MAX)) AS [OutputComment]
			FROM		(
						SELECT		 MAX(LEN(subject01)) /@ColumnWrapCnt MaxLen_Subject
									,MAX(LEN(value01))   /@ColumnWrapCnt MaxLen_Value
									,MAX(LEN(grade01))   MaxLen_Grade
									,MAX(LEN(notes01))   /@ColumnWrapCnt MaxLen_Notes
						FROM		#temp_results
						) T2
			UNION ALL
			---------------------------
			-- COLUMN TITLE UNDER LINES
			---------------------------
			SELECT		'' AS [subject]
						,'' AS [value]
						,'' AS [grade]
						,'' AS [notes]
						,REPLICATE('=',MaxLen_Subject)	+'  '
						+REPLICATE('=',MaxLen_Value)	+'  '
						+REPLICATE('=',MaxLen_Grade)	+'  '
						+REPLICATE('=',MaxLen_Notes)
			FROM		(
						SELECT		 MAX(LEN(subject01)) /@ColumnWrapCnt MaxLen_Subject
									,MAX(LEN(value01))   /@ColumnWrapCnt MaxLen_Value
									,MAX(LEN(grade01))   MaxLen_Grade
									,MAX(LEN(notes01))   /@ColumnWrapCnt MaxLen_Notes
						FROM		#temp_results
						) T2
			UNION ALL
			---------------------------
			-- COLUMN DATA
			---------------------------
			SELECT		subject01 AS [subject]
						,value01 AS [value]
						,grade01 AS [grade]
						,notes01 AS [notes]
						,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
						LEFT(CAST(DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(subject01,MaxLen_Subject,'_',DEFAULT),1)+'   ' AS CHAR(8000)),MaxLen_Subject+2)
						+LEFT(CAST(DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(value01,MaxLen_Value,'_',DEFAULT),1)   +'   ' AS CHAR(8000)),MaxLen_Value+2)
						+LEFT(CAST(DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(grade01,MaxLen_Grade,'_',DEFAULT),1)   +'   ' AS CHAR(8000)),MaxLen_Grade+2)
						+LEFT(CAST(DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(notes01,MaxLen_Notes,'_',DEFAULT),1)   +'   ' AS CHAR(8000)),MaxLen_Notes+2)
						+ISNULL(@CRLF+NULLIF(CAST(
						 LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(subject01,MaxLen_Subject,'_',DEFAULT),2)+' ' AS CHAR(8000)),MaxLen_Subject+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(value01,MaxLen_Value,'_',DEFAULT),2)+' '	 AS CHAR(8000)),MaxLen_Value+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(grade01,MaxLen_Grade,'_',DEFAULT),2)+' '	 AS CHAR(8000)),MaxLen_Grade+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(notes01,MaxLen_Notes,'_',DEFAULT),2)+' '	 AS CHAR(8000)),MaxLen_Notes+2) AS VARCHAR(MAX)),''),'')
						+ISNULL(@CRLF+NULLIF(CAST(
						 LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(subject01,MaxLen_Subject,'_',DEFAULT),3)+' ' AS CHAR(8000)),MaxLen_Subject+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(value01,MaxLen_Value,'_',DEFAULT),3)+' '	 AS CHAR(8000)),MaxLen_Value+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(grade01,MaxLen_Grade,'_',DEFAULT),3)+' '	 AS CHAR(8000)),MaxLen_Grade+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(notes01,MaxLen_Notes,'_',DEFAULT),3)+' '	 AS CHAR(8000)),MaxLen_Notes+2) AS VARCHAR(MAX)),''),'')
						+ISNULL(@CRLF+NULLIF(CAST(
						 LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(subject01,MaxLen_Subject,'_',DEFAULT),4)+' ' AS CHAR(8000)),MaxLen_Subject+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(value01,MaxLen_Value,'_',DEFAULT),4)+' '	 AS CHAR(8000)),MaxLen_Value+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(grade01,MaxLen_Grade,'_',DEFAULT),4)+' '	 AS CHAR(8000)),MaxLen_Grade+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(notes01,MaxLen_Notes,'_',DEFAULT),4)+' '	 AS CHAR(8000)),MaxLen_Notes+2) AS VARCHAR(MAX)),''),'')
						+ISNULL(@CRLF+NULLIF(CAST(
						 LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(subject01,MaxLen_Subject,'_',DEFAULT),5)+' ' AS CHAR(8000)),MaxLen_Subject+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(value01,MaxLen_Value,'_',DEFAULT),5)+' '	 AS CHAR(8000)),MaxLen_Value+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(grade01,MaxLen_Grade,'_',DEFAULT),5)+' '	 AS CHAR(8000)),MaxLen_Grade+2)
						+LEFT(CAST('  '+DBAOps.dbo.dbaudf_ReturnLine(DBAOps.dbo.dbaudf_WordWrap(notes01,MaxLen_Notes,'_',DEFAULT),5)+' '	 AS CHAR(8000)),MaxLen_Notes+2) AS VARCHAR(MAX)),''),'')
						,@CRLF+@CRLF,@CRLF),@CRLF+' '+@CRLF,@CRLF),@CRLF+'  '+@CRLF,@CRLF),@CRLF+'   '+@CRLF,@CRLF),@CRLF+'    '+@CRLF,@CRLF)
			FROM		#temp_results
			CROSS JOIN	(
						SELECT		 MAX(LEN(subject01)) /@ColumnWrapCnt MaxLen_Subject
									,MAX(LEN(value01))   /@ColumnWrapCnt MaxLen_Value
									,MAX(LEN(grade01))   MaxLen_Grade
									,MAX(LEN(notes01))   /@ColumnWrapCnt MaxLen_Notes
						FROM		#temp_results
						) Lengths


			SELECT		@PrintWidth
						=(MAX(LEN(subject01)) /@ColumnWrapCnt)
						+(MAX(LEN(value01))   /@ColumnWrapCnt)
						+(MAX(LEN(grade01)))
						+(MAX(LEN(notes01))   /@ColumnWrapCnt)
						+ 6
			FROM		#temp_results


			-- WRITE HEADDER LINE TO REPORT WITH OVERWRITE TO EMPTY EXISTING REPORT
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG='CREATING REPORT FILE AT '+@ReportFile_path,@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint


			SELECT		@ReportText=REPLICATE(' ',(@PrintWidth-LEN(@Subject))/2)+@Subject+@CRLF+@CRLF+@CRLF
				EXEC	DBAOps.dbo.dbasp_FileAccess_Write @ReportText,@reportfile_path,0,1


			-- WRITE HEADDER LINE TO UPDATE FILE WITH OVERWRITE TO EMPTY EXISTING REPORT
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG='CREATING UPDATE FILE AT '+@updatefile_path,@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint


			SELECT		@ReportText='-- SQLHealthReport Updated Generated on ' + CAST(@CheckDate AS VARCHAR(MAX))+@CRLF+@CRLF+@CRLF
				EXEC	DBAOps.dbo.dbasp_FileAccess_Write @ReportText,@updatefile_path,0,1


			-- WRITE HEADDER LINE TO REPORT WITH OVERWRITE TO EMPTY EXISTING REPORT
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG='WRITING TO REPORT FILE AT '+@ReportPath+@ReportFileName,@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
			SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint


			SELECT		@ReportText='Report Generated: ' + CONVERT(VARCHAR(30),@CheckDate,9),@ReportText=REPLICATE(' ',(@PrintWidth-LEN(@ReportText))/2)+@ReportText+@CRLF
				EXEC	DBAOps.dbo.dbasp_FileAccess_Write @ReportText,@reportfile_path,1,1


			SET @ReportText = @CRLF+@CRLF+REPLICATE('=',@PrintWidth)+@CRLF+@CRLF
			DECLARE ResultsCursor CURSOR
			FOR
			SELECT [subject],[value],[grade],[notes],REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(RTRIM(CAST(OutputComment AS VARCHAR(MAX)))+'|',@CRLF+'|','')+'|',@CRLF+'|','')+'|','||',''),'|',''),'CRITFAIL','FAIL')
			FROM @Report


			OPEN ResultsCursor
			FETCH NEXT FROM ResultsCursor INTO @save_subject01,@save_value01,@save_grade01,@save_notes01,@OutputComment
			WHILE (@@FETCH_STATUS <> -1)
			BEGIN
				IF (@@FETCH_STATUS <> -2) AND @OutputComment IS NOT NULL
				BEGIN


					EXEC DBAOps.dbo.dbasp_Print @OutputComment,@NestLevel,0,@StatusPrint


					SET		@ReportText = @ReportText + @OutputComment + @CRLF

					--  write to the update file if this check failed
					IF @save_grade01 LIKE '%fail%'
					   BEGIN
						SELECT @fail_flag = 'y'
						SELECT @message = 'insert into DBAcentral.dbo.SQLHealth_Central values(''' + @@SERVERNAME + ''', '''
										+ COALESCE(@save_domain,'<DOMAIN_NAME>') + ''', ''' + COALESCE(@save_envname,'<ENV_NAME>') + ''', '''
										+ COALESCE(@save_subject01,'<SUBJECT>') + ''', '''
										+ COALESCE(@save_value01,'<VALUE>')
										+ ''', ''FAIL'', '''
										+ COALESCE(@save_notes01,'<NOTES>') + ''', '''
										+ CONVERT(NVARCHAR(30), @CheckDate, 121) + ''')'

						-- WRITE UPDATE LINE TO UPDATE FILE
						SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
						SELECT @MSG='WRITING UPDATE :'+@message;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
						SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint

						-- RAISE ERROR IF CRITICAL FAILURE
						IF @save_grade01 LIKE '%CritFail%'
							RAISERROR(N'DBA ERROR: SQLHealthCheck %s',-1,-1,@save_notes01) WITH LOG,NOWAIT

						SELECT @message = @message + @CRLF +'GO' + @CRLF
						EXEC	DBAOps.dbo.dbasp_FileAccess_Write @message,@updatefile_path,1,1
					   END


				END
				FETCH NEXT FROM ResultsCursor INTO @save_subject01,@save_value01,@save_grade01,@save_notes01,@OutputComment
			END
			CLOSE ResultsCursor
			DEALLOCATE ResultsCursor


			EXEC	DBAOps.dbo.dbasp_FileAccess_Write @ReportText,@reportfile_path,1,1


	 END


	DELETE	@OutputComments
	SET		@OutputComment = ''


	IF @fail_flag = 'n'
	   BEGIN
		INSERT INTO	@OutputComments
		VALUES		(CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+'----------- STATUS PASS -----------')

		SELECT @message = 'insert into DBAcentral.dbo.SQLHealth_Central values(''' + @@SERVERNAME + ''', '''
						+ @save_domain + ''', ''' + @save_envname + ''', ''All Health Checks Pass'', '' '', '' '', '' '', ''' + CONVERT(NVARCHAR(30), @CheckDate, 121) + ''')'
		--Print  @message
		SELECT @cmd = 'echo ' + @message + '>>' + @updatefile_path
		EXEC master.sys.xp_cmdshell @cmd, no_output

		SELECT @message = 'go'
		SELECT @cmd = 'echo ' + @message + '>>' + @updatefile_path
		EXEC master.sys.xp_cmdshell @cmd, no_output


		SELECT @message = '.'
		SELECT @cmd = 'echo' + @message + '>>' + @updatefile_path
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END
	ELSE
	   BEGIN
		INSERT INTO	@OutputComments
		VALUES		(CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+'----------- STATUS FAIL -----------')
	   END

	--select * from dbo.HealthCheck_current
	INSERT INTO dbo.HealthCheck_log SELECT * FROM dbo.HealthCheck_current
	DELETE FROM dbo.HealthCheck_log WHERE check_date < @CheckDate-8
	--select * from dbo.HealthCheck_log


	--  Copy the file to the central server
	SELECT @cmd = 'xcopy /Y /R "' + RTRIM(@updatefile_path) + '" "\\' + RTRIM(@central_server) + '\DBA_SQL_Register"'
	--Print '		'+@cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	IF (SELECT TOP 1 env_detail FROM dbo.Local_ServerEnviro WHERE env_type = 'domain') NOT IN ('production', 'stage')
	   BEGIN
		SELECT @cmd = 'xcopy /Y /R "' + RTRIM(@updatefile_path) + '" "\\seapdbasql01\DBA_SQL_Register"'
		--Print '		'+@cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   END
	ELSE --If (select datepart(dw, @CheckDate)) in (5)  --Thursday
	   BEGIN
		SELECT @hold_source_path = '\\' + UPPER(@save_servername) + '\' + UPPER(@save_servername2) + '_dbasql\dba_reports'

		--SELECT CAST(Value AS INT) FROM fn_listextendedproperty('EnableCodeComments', default, default, default, default, default, default)

		SET		@SQL	= 'exec DBAOps.dbo.dbasp_File_Transit'+CHAR(13)+CHAR(10)
						+ '	@source_name = '''+@updatefile_name+''''+CHAR(13)+CHAR(10)
						+ '	,@source_path = '''+@hold_source_path+''''+CHAR(13)+CHAR(10)
						+ '	,@target_env = ''AMER'''+CHAR(13)+CHAR(10)
						+ '	,@target_server = ''seapdbasql01'''+CHAR(13)+CHAR(10)
						+ '	,@target_share = ''DBA_SQL_Register'''+CHAR(13)+CHAR(10)


		EXEC	-- RUN: SCRIPT FILE
			@Result =	[dbo].[dbasp_RunTSQL]	-- RUN SQL FILE
							@Name				= NULL
							,@DBName			= 'DBAOps'
							,@Server			= @@SERVERNAME
							,@OutputPath		= NULL
							,@StartNestLevel	= 2
							,@OutputText		= @OutputComment OUT
							,@OutputMatrix		= 4
							,@TSQL				= @SQL

			IF (@Result > 0 OR @Verbose > 1) AND @Verbose > -1
				PRINT REPLICATE('-',80)+CHAR(13)+CHAR(10)+@OutputComment+CHAR(13)+CHAR(10)+REPLICATE('-',80)
	   END


	IF @fail_flag = 'y'
	   BEGIN
		Print 'Select from the @ClusterStatus table for research'
		Select * from @ClusterStatus


		Select @ReportPath = @ReportPath + @ReportFileName
		SELECT @subject = 'SQL Health Report for server ' + @@SERVERNAME
		SELECT @message = @ReportPath + CHAR(13)+CHAR(10) + CHAR(13)+CHAR(10)
		Insert into @emailmessage (emailtext) select top 10 notes01
						from #temp_results
						WHERE grade01 LIKE '%fail%'
						or grade01 LIKE '%warning%'
						order by grade01


		SELECT @message = @message + emailtext + CHAR(13)+CHAR(10)
				from @emailmessage


		If @save_envname = 'Production'
		   begin
			EXEC DBAOps.dbo.dbasp_sendmail
				@recipients = @rpt_recipient,
				@subject = @subject ,
				@message = @message
		   end
		Else
		   begin
			EXEC DBAOps.dbo.dbasp_sendmail
				@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
				@subject = @subject ,
				@message = @message
		   end


	   END


	------------------------------------
	--	PRINT OUTPUT ** FINAL OUTPUT IGNORES VERBOSE FLAG **
	------------------------------------
	SELECT		@OutputComment = @OutputComment + OutputComment +CHAR(13)+CHAR(10)
	FROM		@OutputComments
	IF @Verbose > -1
	   begin
		PRINT @OutputComment
	   end


END


GOTO label99


BEGIN	------------------------------  FINALIZATION FOR PROCESS  ------------------------------------
	label99:


	EXEC sys.sp_updateextendedproperty @Name = 'EnableCodeComments', @value = @save_EnableCodeComments


	DROP TABLE #temp_tbl1
	DROP TABLE #temp_results
	DROP TABLE #miscTempTable
	DROP TABLE #seceditTempTable
	DROP TABLE #showgrps
	DROP TABLE #ShareTempTable
	DROP TABLE #scTempTable
	DROP TABLE #scTempTable2
	DROP TABLE #loginconfig
	DROP TABLE #dir_results
	DROP TABLE #orphans
	DROP TABLE #Objects
	DROP TABLE #SchemaObjCounts
	DROP TABLE #SQLInstances


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_check_SQLhealth] TO [public]
GO
