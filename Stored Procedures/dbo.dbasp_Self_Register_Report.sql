SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Self_Register_Report]
--
--/*********************************************************
-- **  Stored Procedure dbasp_Self_Register_Report
-- **  Written by Steve Ledridge        , Virtuoso
-- **  March 22, 2007
-- **
-- **  This procedure registers the local SQL server instance
-- **  to the designated central SQL server.
-- ***************************************************************/
as
set nocount on
SET ANSI_WARNINGS off


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	03/22/2007	Steve Ledridge        		New Process
--	04/16/2007	Steve Ledridge        		Added sql install date, number and size of user DB's
--	06/19/2007	Steve Ledridge        		New register process for DEPL related servers.
--	06/21/2007	Steve Ledridge        		Modify the new register process for all servers now.
--	08/24/2007	Steve Ledridge        		Added backup processing info.
--	09/18/2007	Steve Ledridge        		Allow null in new temp table.
--	09/21/2007	Steve Ledridge        		Update for SQL2005.
--	11/05/2007	Steve Ledridge        		Added sql and server config info.
--	11/06/2007	Steve Ledridge        		Get Domain name from srvinfo.
--	11/07/2007	Steve Ledridge        		Removed psinfo and added msinfo.
--	02/07/2008	Steve Ledridge        		Added skip for database that are not online.
--	02/12/2008	Steve Ledridge        		New code for DEPL table update.
--	03/06/2008	Steve Ledridge        		Added dynamic code for DEPL table update.
--	06/23/2008	Steve Ledridge        		New code for Compression backup info check in.
--	06/27/2008	Steve Ledridge        		Fixed bug in getting cluster node names.
--	08/20/2008	Steve Ledridge        		Major re-write.
--	08/22/2008	Steve Ledridge        		Skip appl desc for DBAOps and systeminfo.
--	08/26/2008	Steve Ledridge        		force reg2.exe for x64.
--	09/16/2008	Steve Ledridge        		seafresqldba02 to seafresqldba01.
--	09/25/2008	Steve Ledridge        		New code to check for clr enabled setting.
--	10/07/2008	Steve Ledridge        		Added FAStT and Multi-Path for SAN flag.
--	10/13/2008	Steve Ledridge        		Added section for general environment verification (file shares).
--	10/14/2008	Steve Ledridge        		Skip DB's like "_new" and"_nxt".
--	10/20/2008	Steve Ledridge        		Fixed code for fulltext DB's.
--	11/10/2008	Steve Ledridge        		Code to force upper case on server name and sql name.
--	11/14/2008	Steve Ledridge        		New code to add backup_type to Local_ServerEnviro table.
--	11/21/2008	Steve Ledridge        		Added auto set for the local policy rights.
--	12/01/2008	Steve Ledridge        		Fix to grant policy for non-standard cluster group names.
--  12/02/2008	Steve Ledridge				Added code to update the local DBAOps DBA_*info tables.
--	12/08/2008	Steve Ledridge				Added code to capture database compatibility level
--	12/12/2008	Steve Ledridge        		Revised code to check for baseline date
--	12/29/2008	Steve Ledridge        		Fully qualified all references to DBAOps objects.
--	03/11/2009	Steve Ledridge        		Added DEPLstatus verification to the no_check table.
--	03/18/2009	Steve Ledridge        		Added section for DiskPerfinfo. Also changed
--											pagefile from available to max size.
--	03/20/2009	Steve Ledridge        		Only delete DBinfo rowsolder than 60 days (last moddate)
--	03/25/2009	Steve Ledridge        		Updated code for DiskPerfinfo
--	03/27/2009	Steve Ledridge        		Set robocopy to work for folders with spaces.  Changed
--												most echo commands to sqlcmd.
--	03/30/2009	Steve Ledridge        		Changed output to print only.
--	05/13/2009	Steve Ledridge        		Fixed substrings for cluster info.
--	05/18/2009	Steve Ledridge					Keep Baselined databases from checking in.
--	05/20/2009	Steve Ledridge        		Added status and createdate to dba_dbinfo update.
--	06/25/2009	Steve Ledridge        		Added MOMdate update for dba_serverinfo (regread).
--	07/07/2009	Steve Ledridge        		Added rmtshare cmd if showacls result is blank.
--	07/21/2009	Steve Ledridge        		Added update top (1) to dba_serverinfo update.
--	08/13/2009	Steve Ledridge        		Added -4 to ping command.
--	08/17/2009	Steve Ledridge        		Added nslookup to IP capture process and new diskinfo section.
--	10/09/2009	Steve Ledridge        		Replaced code for DB systeminfo with DEPLinfo.
--	10/19/2009	Steve Ledridge        		Added raiserror with nowait after go's.
--	10/20/2009	Steve Ledridge        		Set Redgate log file retention if installed.
--	10/23/2009	Steve Ledridge        		Add insert to temp table for sqbutility exec's to suppress "return".
--	10/26/2009	Steve Ledridge        		Add conditional for CLR check - make sure the DB is not in no_check.
--	11/09/2009	Steve Ledridge        		Added code for cluster node check (2 instances on one node)
--	03/12/2010	Steve Ledridge        		New code for active = 'm'.
--	03/15/2010	Steve Ledridge        		Output code will now be non-DBname specific.
--	03/17/2010	Steve Ledridge        		Added dbaperf and DEPLinfo version columns and more pagefile info.
--	03/26/2010	Steve Ledridge        		Added chkcpu32 processing for cpu info capture.
--	05/05/2010	Steve Ledridge        		Revised OSuptime code.
--	05/24/2010	Steve Ledridge        		Commented out some diag print stmts.
--	05/25/2010	Steve Ledridge        		Added new columns for Indx snapshot and CLR state.
--	10/12/2010	Steve Ledridge        		Added print statements to output script.
--	02/17/2011	Steve Ledridge        		New code for OS2008 BCD (Boot.ini) check.
--	03/04/2011	Steve Ledridge        		Added code for AHP processing.
--	06/08/2011	Steve Ledridge        		Added chech for 'cannot find file' on boot.ini.
--												New code for installed physical memory.
--	06/23/2011	Steve Ledridge        		Added PowerShell flag.
--	09/21/2011	Steve Ledridge        		Added code for new columns related to disk growth info.
--	02/24/2012	Steve Ledridge        		New code for SQL install date.
--	03/14/2012	Steve Ledridge        		Fixed cluster IP capture by adding nslookup.
--  04/17/2012	Steve Ledridge					Fixed Calculation of mirroring Column
--	04/17/2012	Steve Ledridge				Modified process to include system Databases Other Than TempDB
--	04/17/2012	Steve Ledridge				Modified process to Assign Operations, OpsCentral and System Aplication Names.
--	04/17/2012	Steve Ledridge				Moved as many DB Tests to before the OFFLINE skip as posible.
--	04/18/2012	Steve Ledridge				Modified Mirroring Column to Contain SQLName:DBName of MirroringPartner
--	03/14/2012	Steve Ledridge        		Reformatted SQL version info.
--	05/10/2012	Steve Ledridge				Repaired Antivirus Check to look at different registry branch and now include versions in the value.
--	06/15/2012	Steve Ledridge        		Skip redgate and litespeed version check for sql2008r2 and above.
--	07/02/2012	Steve Ledridge				Modified DBA_DBinfo population to ignore databases set with a status of "REMOVED"
--	08/16/2012	Steve Ledridge        		Added or modified mirroring, logshipping, filestream and PageVerify info.
--	09/26/2012	Steve Ledridge        		Increased size of @save_AntiVirus_type.
--	11/19/2012	Steve Ledridge        		Updated check for cluster node name (@mask01).
--	12/26/2012	Steve Ledridge        		Updated CPU info capture.
--	01/25/2013	Steve Ledridge				Made sure all OA Objects are destroyed at end of sproc.
--	02/07/2013	Steve Ledridge        		Added top (1) to update for dba_dbinfo.
--	02/11/2013	Steve Ledridge        		Removed UnlockAndDelete process.
--	02/26/2013	Steve Ledridge				Modified Calls to functions supporting the replacement of OLE with CLR.
--	03/06/2013	Steve Ledridge        		Added skip for DB'sModified Calls to functions supporting the replacement of OLE with CLR.
--	03/13/2013	Steve Ledridge        		Changed DBname systeminfo to DBAOps.
--	04/01/2013	Steve Ledridge        		Replaced code for DB DEPLinfo with DBAOps (except column name for the insert).
--	04/10/2013	Steve Ledridge        		Replaced code for DB DEPLinfo with DBAOps (column name for the insert).
--	04/29/2013	Steve Ledridge        		Removed code for DB DEPLinfo.
--	06/10/2013	Steve Ledridge        		Added code for sql 2012 DB availability group check.
--	08/08/2013	Steve Ledridge        		Removed variable @save_driveSize_char.
--	09/06/2013	Steve Ledridge        		Revised check for sql version 2008R2 or above.
--	10/08/2013	Steve Ledridge        		Added code for DBextra info (Adi request).
--	10/25/2013	Steve Ledridge        		Added sections for NoCheck and Linked Servers.
--	02/24/2014	Steve Ledridge        		Added VLFcount for dba_DBinfo table and new code for DBA_diskinfo Ovrrd_Freespace_pct.
--	03/19/2014	Steve Ledridge        		Added DBfileInfo table.
--	03/24/2014	Steve Ledridge        		Added try catch for DBfileInfo section.
--	04/09/2014	Steve Ledridge        		Added DBA_JobInfo section.
--	05/06/2014	Steve Ledridge        		Added DBA_ControlInfo section (replaces NoCheckInfo).
--	06/10/2014	Steve Ledridge				Replace all CPU Identification code with calls to Newer CPUInfo CLR Function.
--	07/24/2014	Steve Ledridge        		Changed GIMPI reference to D.I.A.P.E.R.
--	07/25/2014	Steve Ledridge        		Added code for system type.
--	09/25/2014	Steve Ledridge        		New code for ClusterInfo capture.
--	10/15/2014	Steve Ledridge				Wrapped Cluster Check with try catch for some servers that return an error.
--	10/27/2014	Steve Ledridge        		New section for ConnectionInfo capture.
--	10/29/2014	Steve Ledridge        		New code for OffSite Backup info.
--	12/01/2014	Steve Ledridge				Modified DBA_diskinfo Ovrrd_Freespace_pct to no longer mask nulls.
--	12/12/2014	Steve Ledridge        		New data capture for PowerPath version, Services, and AvailGrp info.
--	01/06/2015	Steve Ledridge        		Updated Tivoli log parse for Failed.
--	01/20/2015	Steve Ledridge				Modified #Disk population to include DISTINCT to prevent duplicate records.
--	01/22/2015	Steve Ledridge        		Added RebootPending info.
--	01/30/2015	Steve Ledridge        		Call dbasp_DiskSpaceCheck_CaptureAndExport via sqlcmd.
--	02/06/2015	Steve Ledridge        		Added DB Settings.
--	02/25/2015	Steve Ledridge        		Now create a unique msinfo file each time.
--												Added section for DBA_AGInfo.
--	03/03/2015	Steve Ledridge        		Added Delete from dbo.DBA_ClusterInfo.
--	05/19/2015	Steve Ledridge        		New code for SAN flag - Virtual disk.
--	05/20/2015	Steve Ledridge        		Removed section for dbo.ControlTable.
--											Modified AGinfo section (new columns for listener port and ip)
--											Changed column names cluster to clustername and availgrp to AGName.
--	06/26/2015	Steve Ledridge				Added a new IP Lookup process that looks for active connections to the SQL Port with netstat.
--	08/27/2015	Steve Ledridge				Added exclusion for agent job log file checks if job not owned by sa.
--	01/26/2016	Steve Ledridge        		Updated dba_diskinfo section using new disk forecasting tables.
--	02/05/2016	Steve Ledridge        		Change dbasp_DiskSpaceCheck_CaptureAndExport to dbasp_DiskSpaceCheck_CaptureAndExport.
--	03/04/2016	Steve Ledridge        		Fixed formatting for SQL version.
--	03/28/2016	Steve Ledridge        		Fixed query for DBAOps version.
--	09/01/2016	Steve Ledridge        		Changed SQLStartupParms variable to nvarchar(500).
--	10/28/2016	Steve Ledridge				Added Conection Property Method to get IP Address and SQL Port
--	11/10/2016	Steve Ledridge        		Added columns to dba_clusterinfo and fixed code for dba_AGinfo.
--	12/02/2016	Steve Ledridge        		New loop for AG listeners.
--	12/02/2016	Steve Ledridge        		Added IPconfig Section.
--	01/24/2017	Steve Ledridge        		Modified Report Header.

--	======================================================================================


	DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd				nvarchar(4000)
	,@cmd2				nvarchar(4000)
	,@central_server 		sysname
	,@save_cmptlvl 			nvarchar(10)
	,@save_DBAOps_build		sysname
	,@save_dbaperf_build		sysname
	,@save_SQLDeploy_build		sysname
	,@save_version			nvarchar(500)
	,@save_version01		nvarchar(500)
	,@save_version02		nvarchar(500)
	,@save_SQL_install_date		datetime
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_ServerType		sysname
	,@save_sqlinstance		sysname
	,@save_SQLSvcAcct		sysname
	,@save_SQLAgentAcct		sysname
	,@save_SQLStartupParms		nvarchar(500)
	,@hold_SQLStartupParms		nvarchar(500)
	,@save_install_folder		sysname
	,@save_SQLScanforStartupSprocs	char(1)
	,@save_baseline_srvname		sysname
	,@save_backup_type	    	sysname
	,@save_rg_version	    	sysname
	,@save_domain_name		sysname
	,@save_port			nvarchar(10)
	,@save_SQLrecycle_date		sysname
	,@save_awe_enabled		char(1)
	,@save_clr_enabled		char(1)
	,@save_MAXdop_value		nvarchar(5)
	,@save_SQLmax_memory		nvarchar(20)
	,@save_tempdb_filecount		nvarchar(5)
	,@save_iscluster		char(1)
	,@save_is64bit			char(1)
	,@save_compbackup_rg_flag	char(1)
	,@save_rg_versiontype		sysname
	,@save_rg_license		sysname
	,@save_rg_installdate		datetime
	,@save_FullTextCat		char(1)
	,@save_Assemblies		char(1)
	,@save_Mirroring		char(1)
	,@save_Repl_Flag		char(1)
	,@save_LogShipping		char(1)
	,@save_LinkedServers		char(1)
	,@save_ReportingSvcs		char(1)
	,@save_LocalPasswords		char(1)
	,@save_PowerShell_flag		char(1)
	,@save_SAN_flag			char(1)
	,@save_depl_flag		char(1)
	,@save_availGrp_flag		char(1)
	,@save_ip			sysname
	,@save_id			int
	,@save_CPUtype			sysname
	,@save_Memory			sysname
	,@save_OSname			sysname
	,@save_OSver			sysname
	,@save_OSuptime			sysname
	,@save_boot_3gb			char(1)
	,@save_boot_pae			char(1)
	,@save_boot_userva		char(1)
	,@save_Pagefile_maxsize		sysname
	,@save_Pagefile_avail		sysname
	,@save_Pagefile_inuse		sysname
	,@save_TimeZone			sysname
	,@save_SystemModel		sysname
	,@save_system_man		sysname
	,@save_system_mod		sysname
	,@save_system_type		sysname
	,@charpos			int
	,@charpos2			int
	,@save_charpos			int
	,@Filesize_logonly		dec(15,2)
	,@Filesize_dataonly		dec(15,2)
	,@Datasize			dec(15,2)
	,@Logsize			dec(15,2)
	,@bytesperpage			dec(15,2)
	,@pagesperMB			dec(15,2)
	,@DBAOps_flag			char(1)
	,@depl_flag			char(1)
	,@save_RSTRfolder		sysname
	,@save_companionDB_name		sysname
	,@isNMinstance			char(1)
	,@error_count			int
	,@outfile_name			sysname
	,@outfile_path			nvarchar(250)
	,@hold_source_path		sysname
	,@save_sqlnetname		sysname
	,@save_server_active		char(1)
	,@save_IndxSnapshot_process	char(1)
	,@save_IndxSnapshot_inverval	sysname
	,@save_CLR_state		sysname
	,@save_FrameWork_ver		sysname
	,@save_FrameWork_dir		varchar(250)
	,@save_clr_enabled_flag		char(1)
	,@save_filestream_access_level	char(1)
	,@save_availGrp_details		sysname
	,@save_text01			nvarchar(400)
	,@save_msinfo_filepath		sysname
	,@save_msinfo_filename		sysname
	,@mask01			sysname
	,@Domain			sysname
	,@save_FQDN			sysname
	,@a				sysname
	,@filetext			varchar(8000)
	,@save_LastWriteTime		sysname
	,@save_OffSiteBkUp_Status	sysname
	,@save_PowerPath_version	sysname
	,@save_services			nvarchar(500)
	,@RebootPending			CHAR(1)
	,@save_propertyname		sysname


DECLARE
	 @save_DBstatus			sysname
	,@save_ENVname	 		sysname
	,@save_ENVnum			sysname
	,@save_DBCreateDate		datetime
	,@save_count			int
	,@save_count2			int
	,@save_seq_id			int
	,@save_Appl_desc		sysname
	,@save_BaselineDate		sysname
	,@save_build			sysname
	,@save_RecovModel		sysname
	,@save_PageVerify		sysname
	,@save_db_FullTextCat		char(1)
	,@save_db_Trustworthy		char(1)
	,@save_db_Assemblies		char(1)
	,@save_db_Filestream		nvarchar(10)
	,@save_db_Mirroring		sysname
	,@save_db_Repl_Flag		char(1)
	,@save_db_LogShipping		sysname
	,@hold_db_LogShipping		sysname
	,@save_db_ReportingSvcs		char(1)
	,@save_db_StartupSprocs		char(1)
	,@save_row_count		bigint
	,@hold_DB_name			sysname
	,@hold_Appl_desc		sysname
	,@hold_dbid			int
	,@save_database_id		int
	,@save_TotalSizeMB		bigint
	,@save_Size_PR_From_Total	int
	,@save_NumberOfFiles		int
	,@save_Collation		sysname
	,@save_Last_Access		datetime
	,@save_Last_Access_in_days	int
	,@save_DBsettings		nvarchar(4000)


DECLARE
	 @save_filepath			nvarchar(500)
	,@save_sharename		sysname
	,@save_bytes_sec		sysname
	,@save_master_path		nvarchar(500)
	,@save_tempdb_path		nvarchar(500)
	,@save_mdf_path			nvarchar(500)
	,@save_ldf_path			nvarchar(500)
	,@save_master_push		bigint
	,@save_master_pull		bigint
	,@save_tempdb_push		bigint
	,@save_tempdb_pull		bigint
	,@save_mdf_push			bigint
	,@save_mdf_pull			bigint
	,@save_ldf_push			bigint
	,@save_ldf_pull			bigint
	,@outpath			varchar(255)


DECLARE
	 @save_OracleClient		sysname
	,@save_TNSnamesPath		sysname
	,@save_CPUphysical		sysname
	,@save_CPUphysical_num		smallint
	,@save_CPUcore			sysname
	,@save_CPUcore_num		smallint
	,@save_CPUlogical		sysname
	,@save_OSinstallDate		sysname
	,@save_Pagefile_path		sysname
	,@save_Pagefile_path2		sysname
	,@save_IEver			sysname
	,@save_MDACver			sysname
	,@save_AntiVirus_type		nvarchar(4000)
	,@save_AntiVirus_Excludes	sysname


DECLARE
	 @save_nodename			sysname
	,@save_cluster_name		sysname
	,@save_tb11_id			int
	,@save_ResourceType		sysname
	,@save_ResourceName		sysname
	,@save_ResourceDetail		sysname
	,@save_GroupName		sysname
	,@save_CurrentOwner		sysname
	,@save_PreferredOwner		sysname
	,@save_Dependencies		nvarchar(500)
	,@save_RestartAction		sysname
	,@save_AutoFailback		sysname
	,@save_State			sysname

DECLARE
	 @fileexist_path		sysname
	,@save_Administrators		sysname
	,@save_checkname		sysname
	,@save_OSuptime_date 		sysname
	,@save_OSuptime_day 		nvarchar(10)
	,@save_OSuptime_month 		nvarchar(5)
	,@save_OSuptime_year 		nvarchar(5)
	,@save_OSuptime_time 		sysname
	,@save_OSuptime_time_hour 	sysname
	,@save_OSuptime_time_minute 	sysname
	,@save_OSuptime_time_second 	sysname
	,@save_OSuptime_meridiem 	sysname
	,@save_OSuptime_seeddate 	datetime


DECLARE
	 @save_nocheckid		int
	,@save_Control_Subject		sysname
	,@save_detail01			sysname
	,@hold_detail01			sysname
	,@save_detail02			sysname
	,@save_detail03			nvarchar(max)
	,@save_detail04			sysname
	,@save_moddate			datetime


DECLARE
	 @save_LKname			sysname
	,@save_LKserver_id		int
	,@save_LKsrvproduct		sysname
	,@save_LKprovidername		nvarchar(128)
	,@save_LKdatasource		nvarchar(4000)
	,@save_LKlocation		nvarchar(4000)
	,@save_LKproviderstring		nvarchar(4000)
	,@save_LKcatalog		sysname
	,@save_LKconnecttimeout		int
	,@save_LKquerytimeout		int
	,@save_LKrpc			bit
	,@save_LKpub			bit
	,@save_LKsub			bit
	,@save_LKdist			bit
	,@save_LKrpcout			bit
	,@save_LKdataaccess		bit
	,@save_LKcollationcompatible	bit
	,@save_LKuseremotecollation	bit
	,@save_LKlazyschemavalidation	bit
	,@save_LKcollation		sysname


DECLARE
	 @in_key			sysname
	,@in_path			sysname
	,@in_value			sysname
	,@result_value			nvarchar(500)


DECLARE
	 @save_AGname				sysname
	,@save_AGgroup_id			UniqueIdentifier
	,@save_AGreplica_id			UniqueIdentifier
	,@save_Listener				nvarchar(500)
	,@save_Listener_port			sysname
	,@save_Listener_ip			sysname
	,@save_BackupPreference			sysname
	,@save_AGrole				sysname
	,@save_AGmode				sysname
	,@save_FailoverMode			sysname
	,@save_SynchronizationHealth		sysname
	,@save_PrimaryAllowConnections		sysname
	,@save_SecondaryAllowConnections	sysname
	,@save_AGdns_name			sysname


DECLARE
	 @cu11DBName			sysname
	,@cu11DBId			smallint


DECLARE
	 @cu12FILEsize			dec(15,0)
	,@cu12FILEgroupid		smallint


DECLARE
	 @hr				int
	,@fso				int
	,@save_drivename		SYSNAME
	,@odrive			int
	,@save_driveSize		bigint
	,@save_drivefree		bigint
	,@save_drivefree_pct		int
	,@save_drive_GrowthPerWeekMB	int
	,@save_DriveFullWks		int
	,@save_Ovrrd_Freespace_pct	smallint
	,@MB				bigint
	,@p2 				nvarchar(4000)
	,@p4 				int
	,@p5 				int


DECLARE
	 @versionString			VARCHAR(20)
	,@serverVersion			DECIMAL(10,5)
	,@sqlServer2012Version		DECIMAL(10,5)
	,@save_VLFcount			int


DECLARE
	 @vars					sysname
	,@save_dbf_id				int
	,@save_file_id				int
	,@save_DBfile_DBname			sysname
	,@save_DBfile_LogicalName		sysname
	,@save_DBfile_FileType			sysname
	,@save_usage				sysname
	,@save_DBfile_FGname			sysname
	,@save_DBfile_PhysicalPath		nvarchar(2000)
	,@save_DBfile_PhysicalName		sysname
	,@save_DBfile_state			sysname
	,@save_DBfile_sizewk			bigint
	,@save_FreeSpacewk			bigint
	,@save_DBfile_size			int
	,@save_FreeSpace			int
	,@save_DBfile_MaxSize			bigint
	,@save_DBfile_Growth			sysname
	,@save_DBfile_is_media_RO		bit
	,@save_DBfile_is_RO			bit
	,@save_DBfile_is_sparse			bit
	,@save_DBfile_DBunavailable_flag	char(1)


DECLARE
	 @save_sj_id				int
	,@save_job_id				UniqueIdentifier
	,@save_jobname				sysname
	,@save_enabled				tinyint
	,@save_jobowner				sysname
	,@save_description			nvarchar(512)
	,@save_StartStep			int
	,@save_job_created			datetime
	,@save_job_modified			datetime
	,@save_job_last_execution		datetime
	,@save_AvgDurationMin			int
	,@save_JobSteps				nvarchar(max)
	,@save_job_schedulename			sysname
	,@save_job_schedule_enabled		int
	,@save_job_schedule_frequency		sysname
	,@save_job_schedule_subfrequency	sysname
	,@save_job_schedule_starttime		sysname
	,@save_job_schedule_endtime		sysname
	,@save_job_schedule_runtime		nvarchar(500)
	,@save_job_schedule_output		nvarchar(max)
	,@save_job_schedule_nextrundate		sysname
	,@save_job_schedule_nextrundate_date	datetime
	,@save_job_PassCheck					char(1)
	,@JobLog_Share_Path						sysname
	,@Job_PassCheckDesc						VarChar(max)


DECLARE
	 @save_DBc_id				int
	,@save_DBName				sysname
	,@save_LoginName			sysname
	,@save_HostName				sysname
	,@save_text				nvarchar(4000)
	,@save_Physical_Address			nvarchar(400)


DECLARE @TSQL					VarChar(8000)
Declare @DBName					sysname
DECLARE	@LogShipPaths				TABLE(CopyToPath VarChar(2048))
DECLARE @CheckDate				DateTime;


/*********************************************************************
 *                Initialization
 ********************************************************************/
Select @save_moddate = getdate()


SET    @CheckDate = CAST(CONVERT(VarChar(12),@save_moddate,101)AS DATETIME)


Select @save_is64bit = 'n'
Select @save_compbackup_rg_flag = 'n'
Select @save_FullTextCat = 'n'
Select @save_Assemblies = 'n'
Select @save_Mirroring = 'n'
Select @save_Repl_Flag = 'n'
Select @save_LogShipping = 'n'
Select @save_ReportingSvcs = 'n'
Select @save_SAN_flag = 'n'
Select @save_depl_flag = 'n'
Select @save_availGrp_flag = 'n'
Select @save_domain_name = ' '
Select @save_SQLScanforStartupSprocs = 'n'
Select @isNMinstance = 'n'
Select @error_count = 0
Select @save_ServerType = 'SQL Server'
SET @MB = 1048576


select @bytesperpage = low
	from master.dbo.spt_values
	where number = 1
		and type = 'E'
select @pagesperMB = 1048576 / @bytesperpage


Select @save_sqlinstance = 'mssqlserver'
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
	Select @isNMinstance = 'y'
   end


EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\CurrentControlSet\services\Tcpip\Parameters', N'Domain',@Domain OUTPUT
Select @save_FQDN = (SELECT Cast(SERVERPROPERTY('MachineName') as nvarchar) + '.' + @Domain)


Select @DBAOps_flag = 'n'
If (SELECT DATABASEPROPERTYEX ('DBAOps','status')) = 'ONLINE'
   begin
	Select @DBAOps_flag = 'y'
   end


--  Create temp table


create table #groups (groupname	sysname)


create table #clust_tb11 ([tb11_id] [int] IDENTITY(1,1) NOT NULL,
			[ClusterName] [sysname] NULL,
			[ResourceType] [sysname] NULL,
			[ResourceName] [sysname] NULL,
			[ResourceDetail] [sysname] NULL,
			[GroupName] [sysname] NULL,
			[CurrentOwner] [sysname] NULL,
			[PreferredOwner] [sysname] NULL,
			[Dependencies] [nvarchar](500) NULL,
			[RestartAction] [sysname] NULL,
			[AutoFailback] [sysname] NULL,
			[State] [sysname] NULL
			)


create table #config 	(
			 name01 sysname
			,min02 sysname null
			,max03 sysname null
			,config04 sysname null
			,run05 sysname null
			)


CREATE TABLE #temp_tbl1	(tb11_id [int] IDENTITY(1,1) NOT NULL
			,text01	nvarchar(400)
			)


CREATE TABLE #temp_tbl2	(tbl2_id [int] IDENTITY(1,1) NOT NULL
			,text01	nvarchar(400)
			)


Create table #regresults (results nvarchar(1500) null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


create table #copystats (copydata nvarchar(500))


create table #drives (	[drive]			SYSNAME PRIMARY KEY,
			[FreeSpace]		NUMERIC(10,2)	NULL,
			[TotalSize]		NUMERIC(10,2)	NULL,
			[PctFree]		NUMERIC(10,2)	NULL,
			[GrowthPerWeekMB]	NUMERIC(10,2)	NULL,
			[DriveFullWeeks]	NUMERIC(10,2)	NULL,
			[OverrideFreeSpace]	INT
			)


CREATE TABLE #SqbOutput	(text01	nvarchar(400))


CREATE TABLE #RegValues	(Name sysname,Data nvarchar(4000))


create table #DBextra 	(
			 database_id int
			,DBname sysname not null
			,RecoveryModel nvarchar(60) null
			,Status nvarchar(60) not null
			,Collation sysname null
			,NumberOfFiles int null
			,TotalSizeMB bigint null
			,Size_PR_From_Total int null
			,create_date datetime
			,last_access datetime
			,last_access_in_days int null
			)


create table #LKservers 	(
			 LKname sysname NOT NULL
			,LKserver_id int NOT NULL
			,LKsrvproduct sysname NULL
			,LKprovidername nvarchar(128) NULL
			,LKdatasource nvarchar(4000) NULL
			,LKlocation nvarchar(4000) NULL
			,LKproviderstring nvarchar(4000) NULL
			,LKcatalog sysname NULL
			,LKconnecttimeout int NULL
			,LKquerytimeout int NULL
			,LKrpc bit NULL
			,LKpub bit NULL
			,LKsub bit NULL
			,LKdist bit NULL
			,LKrpcout bit NULL
			,LKdataaccess bit NULL
			,LKcollationcompatible bit NULL
			,LKuseremotecollation bit NULL
			,LKlazyschemavalidation bit NULL
			,LKcollation sysname NULL
			)


CREATE TABLE  #VLFInfo
                     (
                     RecoveryUnitID       int NULL
                     ,FileID              int NULL
                     ,FileSize     bigint NULL
                     ,StartOffset  bigint NULL
                     ,FSeqNo              int NULL
                     ,[Status]     int NULL
                     ,Parity              tinyint NULL
                     ,CreateLSN    numeric(25,0) NULL
                     )


CREATE TABLE #Keys
		(
                    KeyName   NVARCHAR (100)
                 )


DECLARE @Results TABLE (Value NVARCHAR(100), Data NVARCHAR(100))


DECLARE @Results02	TABLE
			(
			KeyValue	NVARCHAR(100),
			Value		NVARCHAR(100),
			Data		NVARCHAR(100)
			)


DECLARE @DBfiles TABLE (dbf_id [int] IDENTITY(1,1) NOT NULL
			, database_id int not null
			, file_id int not null)


DECLARE @SQLjobs TABLE (sj_id [int] IDENTITY(1,1) NOT NULL
			, job_id UniqueIdentifier not null
			, jobname sysname not null
			, enabled tinyint null
			, description nvarchar(512) null
			, start_step_id int null
			, jobowner sysname null
			, date_created datetime null
			, date_modified datetime null)


Declare @weekDay Table (mask int
			, maskValue  varchar(32)
			)


DECLARE @jobschedules TABLE (schedulename sysname not null
			, job_id UniqueIdentifier not null
			, enabled tinyint null
			, frequency sysname null
			, subfrequency sysname null
			, start_time sysname null
			, end_time sysname null
			, nextruntime sysname null
			, nextrundate sysname null)


DECLARE @LocalControl TABLE (LC_id [int] IDENTITY(1,1) NOT NULL
			, subject sysname not null
			, detail01 sysname null
			, detail02 sysname null
			, detail03 nvarchar(4000) null)


DECLARE @DBconnections TABLE (DBc_id [int] IDENTITY(1,1) NOT NULL
			, DBname sysname not null
			, LoginName sysname null
			, HostName sysname null
			, moddate datetime null)

IF NOT EXISTS (SELECT 1 from dbo.Local_ServerEnviro where env_type = 'CentralServer')
BEGIN
	INSERT INTO dbo.Local_ServerEnviro (env_detail,env_type)
	VALUES ('SDCSQLTOOLS.DB.VIRTUOSO.COM','CentralServer')
END

Select @central_server = env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer'
If @central_server is null
   begin
	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The nightly self check-in failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end

IF NOT EXISTS (SELECT 1 from dbo.Local_ServerEnviro where env_type = 'ENVname')
BEGIN
	IF LEFT(@@ServerName,3) = 'SDC'
		SET @save_ENVname = RIGHT(LEFT(@@ServerName,6),3)
	ELSE
		SET @save_ENVname = 'DEV'

	INSERT INTO dbo.Local_ServerEnviro (env_detail,env_type)
	VALUES (@save_ENVname,'ENVname')
END

IF LEFT(@@ServerName,3) = 'SDC'
	UPDATE	dbo.Local_ServerEnviro
		SET env_detail = RIGHT(LEFT(@@ServerName,6),3)
	where env_type = 'ENVname'
ELSE
	UPDATE	dbo.Local_ServerEnviro
		SET env_detail = 'DEV'
	where env_type = 'ENVname'


Select @save_ENVname = env_detail from dbo.Local_ServerEnviro where env_type = 'ENVname'
If @save_ENVname is null
   begin
	Select @miscprint = 'DBA WARNING: The envirnment name is not defined for ' + @@servername + '.  The nightly self check-in failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end


--  Create headers


Select @miscprint = '--  DBA Central Table Update Script from server: ''' + @@servername + ''''
Print  @miscprint


Select @miscprint = '--  Created: '  + convert(varchar(30),getdate(),9)
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


Select @save_propertyname = (SELECT convert(sysname, serverproperty('ComputerNamePhysicalNetBIOS')))
Select @miscprint = '-- [ComputerNamePhysicalNetBIOS] = ' + @save_propertyname
Print  @miscprint


Select @save_propertyname = (SELECT convert(sysname, serverproperty('MachineName')))
Select @miscprint = '-- [MachineName] = ' + @save_propertyname
Print  @miscprint


Select @save_propertyname = (select @@SERVERNAME)
Select @miscprint = '-- [@@SERVERNAME] = ' + @save_propertyname
Print  @miscprint


Select @save_propertyname = (select @@SERVICENAME)
Select @miscprint = '-- [@@SERVICENAME] = ' + @save_propertyname
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------------------------------------------------------------------------------
-- General Environment verification
----------------------------------------------------------------------------------------------


--  check file shares


	----  Check to see if the 'dba_archive' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\dba_archive'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'dbasql' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_dbasql'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'backup' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_backup'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'dba_mail' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername + '_dba_mail'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'builds' folder exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername + '_builds'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'mdf' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_mdf'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'ldf' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_ldf'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'SQLjob_logs' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


	----  Check to see if the 'log' share exists
	--Delete from #fileexists
	--Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_log'
	--Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	----select * from #fileexists


	--If (select fileindir from #fileexists) = 1
	--   begin
	--	Select @cmd = 'showacls ' + @fileexist_path


	--	delete from #regresults
	--	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--	delete from #regresults where results is null
	--	--select * from #regresults


	--	If (select count(*) from #regresults) = 0
	--	   begin
	--		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


	--		delete from #regresults
	--		insert into #regresults exec master.sys.xp_cmdshell @cmd
	--		delete from #regresults where results is null
	--		--select * from #regresults
	--	   end


	--	If exists (select 1 from #regresults where results like '%Administrators%')
	--	   begin
	--		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
	--		If @save_Administrators not like '%Full Control%'
	--		   begin
	--			Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
	--			Print @miscprint
	--			raiserror(@miscprint,-1,-1) with log
	--		   end
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = '--DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
	--		Print @miscprint
	--		raiserror(@miscprint,-1,-1) with log
	--	   end
	--   end
	--Else
	--   begin
	--	Select @miscprint = '--DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	--	Print @miscprint
	--	raiserror(@miscprint,-1,-1) with log
	--   end


--  Check for clustering
delete from #clust_tb11
BEGIN TRY
	insert into #clust_tb11
	select * From dbo.dbaudf_ListClusterNode()
END TRY
BEGIN CATCH
END CATCH
--select * from #clust_tb11


If (select count(*) from #clust_tb11) > 0
   begin
	Select @save_iscluster = 'y'


	SELECT @save_cluster_name = (select top 1 ClusterName FROM #clust_tb11)
   end
Else
   begin
	Select @save_iscluster = 'n'
	SELECT @save_cluster_name = ''
   end


--  Check to see if dbasp_dba_setpolicygrants has run for this server
If @save_iscluster = 'n'
   begin
	Select @save_checkname = 'check_localpolicy_' + @save_servername
	If not exists (select 1 from dbo.Local_ServerEnviro where env_type = @save_checkname)
	   begin
		exec dbo.dbasp_dba_setpolicygrants
		insert into dbo.Local_ServerEnviro values (@save_checkname, @save_servername)
	   end
   end
Else
   begin
	Select @save_nodename = convert(sysname, (Select SERVERPROPERTY('ComputerNamePhysicalNetBIOS')))
	Select @save_checkname = 'check_localpolicy_' + @save_nodename
	If not exists (select 1 from dbo.Local_ServerEnviro where env_type = @save_checkname)
	   begin
		exec dbo.dbasp_dba_setpolicygrants
		insert into dbo.Local_ServerEnviro values (@save_checkname, @save_servername)
	   end
   end


skip_policy:


----------------------------------------------------------------------------------------------
--  Start the Capture Process
----------------------------------------------------------------------------------------------


--  Make sure the old msinfo file is deleted
Select @save_msinfo_filepath = 'c:\msinfo_' + @save_servername2 + '*.txt'
SELECT @cmd = 'DEL ' + @save_msinfo_filepath + ' /Q'
PRINT '--' + @cmd
Exec master.sys.xp_cmdshell @cmd, no_output


--  Create the MSINFO output file
Select @save_msinfo_filename = 'msinfo_' + @save_servername2 + '_' + REPLACE(REPLACE(REPLACE(CONVERT(VarChar(50),getdate(),120),'-',''),':',''),' ','') + '.txt'
select @cmd = 'msinfo32 /categories +IEsummary /report c:\' + @save_msinfo_filename
exec master.sys.xp_cmdshell @cmd, no_output


--  Capture the SQL version
Select @save_version = @@version


If @save_version like '%x64%'
   begin
	Select @save_is64bit = 'y'
   end


--  Reformat the SQL version info
Start_ver01:
Select @charpos = charindex(char(10), @save_version)
IF @charpos <> 0
   begin
	select @save_version = stuff(@save_version, @charpos, 1, ' ')
	goto Start_ver01
   end


Start_ver02:
Select @charpos = charindex(char(9), @save_version)
IF @charpos <> 0
   begin
	select @save_version = stuff(@save_version, @charpos, 1, ' ')
	goto Start_ver02
   end


Select @save_version = replace(@save_version, '  ', ' ')
Select @save_version = replace(@save_version, '  ', ' ')


Select @charpos = charindex(' - ', @save_version)
IF @charpos <> 0
   begin
	select @save_version01 = substring(@save_version, @charpos+3, len(@save_version)-@charpos-3)
 	select @save_version01 = ltrim(@save_version01)


	select @save_version02 = substring(@save_version, 1, @charpos-1)
 	select @save_version02 = ltrim(rtrim(@save_version02))
  end
Select @charpos = charindex(')', @save_version01)
IF @charpos <> 0
   begin
	select @save_version01 = substring(@save_version01, 1, @charpos+1)
 	select @save_version01 = ltrim(rtrim(@save_version01))
  end
If @save_version like '%Standard Edition%'
   begin
 	select @save_version01 = @save_version01 + ' Standard Edition'
   end
Else If @save_version like '%Enterprise Edition%'
   begin
 	select @save_version01 = @save_version01 + ' Enterprise Edition'
   end
Else
   begin
 	select @save_version01 = @save_version01 + ' Unknown Edition'
   end


If @save_version01 is not null and @save_version02 is not null
   begin
	Select @save_version = @save_version01 + ' ' + @save_version02
   end


--  Capture the SQL install date
Select @save_SQL_install_date = (select createdate from master.sys.syslogins where name = 'BUILTIN\Administrators')


If @save_SQL_install_date is null
   begin
	Select @save_SQL_install_date = (select createdate from master.sys.syslogins where name = 'NT AUTHORITY\SYSTEM')
   end


--  Capture Last SQL recycle date
Select @save_SQLrecycle_date = (select convert(sysname, create_date, 120) from master.sys.databases where name = 'tempdb')


--  Capture the service accounts (Note:  We have to strip off the last byte from config_value because it's not printable)
If @isNMinstance = 'n'
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\MSSQLServer'
	select @in_value = 'ObjectName'
	exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end
Else
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\MSSQL$' + @save_sqlinstance
	select @in_value = 'ObjectName'
	exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


Select @save_SQLSvcAcct = @result_value


Select @charpos = charindex('\', @save_SQLSvcAcct)
IF @charpos <> 0
   begin
	Select @save_SQLSvcAcct = rtrim(substring(@save_SQLSvcAcct, @charpos+1, 100))
	goto get_SQLSvcAcct_end
   end


Select @charpos = charindex('@', @save_SQLSvcAcct)
IF @charpos <> 0
   begin
	Select @save_SQLSvcAcct = rtrim(substring(@save_SQLSvcAcct, 1, @charpos-1))
	goto get_SQLSvcAcct_end
   end


get_SQLSvcAcct_end:


If @save_SQLSvcAcct is null or @save_SQLSvcAcct = ''
   begin
	Select @save_SQLSvcAcct = 'unknown'
   end


If @isNMinstance = 'n'
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\SQLServerAgent'
	select @in_value = 'ObjectName'
	exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end
Else
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\SQLAgent$' + @save_sqlinstance
	select @in_value = 'ObjectName'
	exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


Select @save_SQLAgentAcct = @result_value


Select @charpos = charindex('\', @save_SQLAgentAcct)
IF @charpos <> 0
   begin
	Select @save_SQLAgentAcct = rtrim(substring(@save_SQLAgentAcct, @charpos+1, 100))
	goto get_SQLAgentAcct_end
   end


Select @charpos = charindex('@', @save_SQLAgentAcct)
IF @charpos <> 0
   begin
	Select @save_SQLAgentAcct = rtrim(substring(@save_SQLAgentAcct, 1, @charpos-1))
	goto get_SQLAgentAcct_end
   end


get_SQLAgentAcct_end:


If @save_SQLAgentAcct is null or @save_SQLAgentAcct = ''
   begin
	Select @save_SQLAgentAcct = 'unknown'
   end


--  Capture the SQL Startup Parameters
Select @save_SQLStartupParms = ''


--  Get the instalation directory folder name
select @in_key = 'HKEY_LOCAL_MACHINE'
select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
select @in_value = @save_sqlinstance
exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output


If @result_value is null or @result_value = ''
   begin
	goto startup_parm_end
   end


--  Now get the startup parms
select @save_install_folder = @result_value
select @in_key = 'HKEY_LOCAL_MACHINE'
select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @save_install_folder + '\MSSQLServer\Parameters'


If @@version like '%x64%'
   begin
	Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
   end
Else
   begin
	Select @cmd = 'reg query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
   end
--print @cmd


insert into #regresults exec master.sys.xp_cmdshell @cmd
delete from #regresults where results is null
--select * from #regresults


If exists (select 1 from #regresults where results like '%but is for a machine type%')
   begin
	Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
	--print @cmd


	insert into #regresults exec master.sys.xp_cmdshell @cmd
	--select * from #regresults
	delete from #regresults where results is null
	delete from #regresults where results like '%but is for a machine type%'
   end


delete from #regresults where results not like '%REG_SZ%'
delete from #regresults where results like '%ERROR:%'


startup_parm_start:
If (select count(*) from #regresults) > 1
   begin
	select @hold_SQLStartupParms = (select top 1 results from #regresults)
	Select @charpos = charindex('REG_SZ', @hold_SQLStartupParms)
	IF @charpos <> 0
	   begin
		Select @hold_SQLStartupParms = rtrim(substring(@hold_SQLStartupParms, @charpos+6, 100))
	   end


	Delete from #regresults where results like '%' + @hold_SQLStartupParms + '%'
	Select @save_SQLStartupParms = @save_SQLStartupParms + ltrim(@hold_SQLStartupParms) + ';'
	goto startup_parm_start
   end
Else If (select count(*) from #regresults) > 0
   begin
	select @hold_SQLStartupParms = (select top 1 results from #regresults)
	Select @charpos = charindex('REG_SZ', @hold_SQLStartupParms)
	IF @charpos <> 0
	   begin
		Select @hold_SQLStartupParms = rtrim(substring(@hold_SQLStartupParms, @charpos+7, 100))
	   end


	Delete from #regresults where results like '%' + @hold_SQLStartupParms + '%'
	Select @save_SQLStartupParms = @save_SQLStartupParms + ltrim(@hold_SQLStartupParms)
   end


startup_parm_end:


--  Check to see if SQL is set up to scan for startup sprocs
If (select convert(int, value_in_use) from master.sys.configurations where name like '%scan for startup procs%') = 1
   begin
	Select @save_SQLScanforStartupSprocs = 'y'
   end


--  Get domain name
Select @save_domain_name = (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'domain')
If @save_domain_name is null
   begin
	Select @save_domain_name = 'Unknown'
   end


--  Capture the DBAOps version
Select @save_DBAOps_build = (select top 1 vchLabel from dbo.build where vchName = 'DBAOps' and vchNotes like 'DBAOps_release%' order by iBuildID desc)


If @save_DBAOps_build is null or @save_DBAOps_build = ''
   begin
	Select @save_DBAOps_build = 'none'
   end


--  Capture the dbaperf version
If exists (select 1 from master.sys.databases where name = 'dbaperf')
   begin
	Select @save_dbaperf_build = (select top 1 vchLabel from dbaperf.dbo.build where vchName = 'dbaperf' order by iBuildID desc)


	If @save_dbaperf_build is null or @save_dbaperf_build = ''
	   begin
		Select @save_dbaperf_build = 'none'
	   end
   end
Else
   begin
	Select @save_dbaperf_build = 'n/a'
   end


--  Capture the DBAOps version
If exists (select 1 from master.sys.databases where name = 'DBAOps')
   begin
	Select @save_DBAOps_build = (select top 1 vchLabel from dbo.build where vchName = 'DBAOps' order by iBuildID desc)


	If @save_DBAOps_build is null or @save_DBAOps_build = ''
	   begin
		Select @save_DBAOps_build = 'none'
	   end
   end
Else
   begin
	Select @save_DBAOps_build = 'n/a'
   end


--  Capture Backup Type
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and Env_detail = 'RedGate')
   begin
	Select @save_backup_type = 'RedGate'
   end
Else If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and Env_detail = 'Standard')
   begin
	Select @save_backup_type = 'Standard'
   end
Else
   begin
	Select @save_backup_type = 'Default'
   end


--  For 2008 R2 and above, skip the check for Redgate
If (select @@version) not like '%Server 2005%'
  and (SERVERPROPERTY ('productversion') > '10.50.0000' or (select @@version) like '%Enterprise Edition%')
   begin
	goto skip_backuptype
   end


--  Capture RedGate Version (if installed)
Select @save_rg_version = 'na'
If exists (select 1 from master.sys.objects where name = 'sqlbackup' and type = 'x')
   begin
	Select @save_rg_version = (select env_detail from dbo.Local_ServerEnviro where env_type = 'backup_rg_version')
	Select @save_rg_versiontype = (select env_detail from dbo.Local_ServerEnviro where env_type = 'backup_rg_versiontype')
	Select @save_rg_license = (select env_detail from dbo.Local_ServerEnviro where env_type = 'backup_rg_license')


	Select @save_rg_installdate = (select create_date from master.sys.objects where name = 'sqlbackup' and type = 'x')


	Select @save_compbackup_rg_flag = 'y'


	--  set retention for Redgate log files
	insert into #SqbOutput exec master.dbo.sqbutility @Parameter1=1008,@Parameter2=@p2 output
	--select @p2


	If @p2 like '%LogDelete=0%'
	   begin
		insert into #SqbOutput exec master.dbo.sqbutility @Parameter1=1041,@Parameter2=N'LogDelete',@Parameter3=1,@Parameter4=@p4 output
		insert into #SqbOutput exec master.dbo.sqbutility @Parameter1=1041,@Parameter2=N'LogDeleteHours',@Parameter3=168,@Parameter4=@p5 output
	   end
   end


skip_backuptype:


--  Capture SQL AWE setting
--  Capture SQL Max DOP setting
--  Capture SQL memory Limit
--  CLR Enabled
--  Filestream Access Level
delete from #config
insert into #config exec master.sys.sp_configure


If (select run05 from #config where name01 = 'awe enabled') = 1
   begin
	Select @save_awe_enabled = 'y'
   end
Else
   begin
	Select @save_awe_enabled = 'n'
   end


Select @save_MAXdop_value = (select run05 from #config where name01 = 'max degree of parallelism')
If @save_MAXdop_value is null
   begin
	Select @save_MAXdop_value = 'Unknown'
   end


Select @save_SQLmax_memory = (select run05 from #config where name01 like '%max server memory%')
If @save_SQLmax_memory is null
   begin
	Select @save_SQLmax_memory = 'Unknown'
   end


If (select run05 from #config where name01 = 'clr enabled') = 1
   begin
	Select @save_clr_enabled = 'y'
   end
Else
   begin
	Select @save_clr_enabled = 'n'
   end


Select @save_filestream_access_level = (select convert(char(1), run05) from #config where name01 = 'filestream access level')
If @save_filestream_access_level is null
   begin
	Select @save_filestream_access_level = 'n'
   end


--  Capture TempDB files (number of)
Select @save_tempdb_filecount = (select convert(nvarchar(5), count(*)) from tempdb.sys.sysfiles where groupid <> 0)


--  check for linked servers
Select @save_LinkedServers = 'n'
If exists (select 1 from master.sys.servers where name <> @@servername)
   begin
	Select @save_LinkedServers = 'y'
   end


--  check for local passwords
Select @save_LocalPasswords = 'n'
If exists (select 1 from dbo.local_control where subject like 'pw_%')
   begin
	Select @save_LocalPasswords = 'n'
   end


--  check for IndxSnapshot processing
Select @save_IndxSnapshot_process = 'n'
Select @save_IndxSnapshot_inverval = 'na'
If exists (select 1 from msdb.dbo.sysjobs where name like 'UTIL - %' and name like '%D.I.A.P.E.R.%')
   begin
	Select @save_IndxSnapshot_process = 'y'


	if (select enabled from msdb.dbo.sysjobs where name like 'UTIL - %' and name like '%D.I.A.P.E.R.%') <> 1
	   begin
		Select @save_IndxSnapshot_inverval = 'disabled'
	   end
	Else
	   begin
		Select @save_IndxSnapshot_inverval = (select top 1 coalesce(lv.name, 'disabled') from msdb.dbo.sysjobs j, msdb.dbo.sysjobschedules s, msdb.dbo.sysschedules_localserver_view lv
								where j.job_id = s.job_id
								and j.name like 'UTIL - %' and j.name like '%D.I.A.P.E.R.%'
								and s.schedule_id = lv.schedule_id
								and lv.enabled = 1)
	   end
   end


--  Check for CLR / Framework config
Select @save_CLR_state = (select coalesce(value, '') from master.sys.dm_clr_properties where name = 'state')
Select @save_FrameWork_ver = (select coalesce(value, '') from master.sys.dm_clr_properties where name = 'version')
Select @save_FrameWork_dir = (select coalesce(value, '') from master.sys.dm_clr_properties where name = 'directory')


If right(@save_FrameWork_ver, 1) = char(0) and len(@save_FrameWork_ver) > 0
   begin
	Select @save_FrameWork_ver = left(@save_FrameWork_ver, len(@save_FrameWork_ver)-1)
   end


If right(@save_FrameWork_dir, 1) = char(0) and len(@save_FrameWork_dir) > 0
   begin
	Select @save_FrameWork_dir = left(@save_FrameWork_dir, len(@save_FrameWork_dir)-1)
   end


Select @save_CLR_state = replace(@save_CLR_state, char(0), '')
Select @save_FrameWork_ver = replace(@save_FrameWork_ver, char(0), '')
Select @save_FrameWork_dir = replace(@save_FrameWork_dir, char(0), '')


select @save_clr_enabled_flag = (select convert(char(1), value_in_use) from master.sys.configurations where name = 'clr enabled')
If @save_clr_enabled_flag is not null
   begin
	Select @save_CLR_state = 'clr enabled = ' + @save_clr_enabled_flag + ', ' + @save_CLR_state
   end


--
--  START DB CAPTURE PROCESS
--


--  Capture ENV related info
--  Set ENVnum value
If @save_envname in ('production', 'stage', 'staging', 'alpha', 'beta', 'prodsupport')
   begin
	Select @save_envnum = rtrim(@save_envname)
	goto envnum_end
   end


--  First check the instance name
Select @charpos = charindex('01', @save_sqlinstance)
IF @charpos <> 0
begin
	Select @save_envnum = rtrim(@save_envname) + '01'
	goto envnum_end
   end


Select @charpos = charindex('02', @save_sqlinstance)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '02'
	goto envnum_end
   end

Select @charpos = charindex('03', @save_sqlinstance)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '03'
	goto envnum_end
   end

Select @charpos = charindex('04', @save_sqlinstance)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '04'
	goto envnum_end
   end


--  Now check the server name
Select @charpos = charindex('01', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '01'
	goto envnum_end
   end

Select @charpos = charindex('02', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '02'
	goto envnum_end
   end

Select @charpos = charindex('03', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '03'
	goto envnum_end
   end

Select @charpos = charindex('04', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '04'
	goto envnum_end
   end

Select @charpos = charindex('1', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '01'
	goto envnum_end
   end

Select @charpos = charindex('2', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '02'
	goto envnum_end
   end

Select @charpos = charindex('3', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '03'
	goto envnum_end
   end

Select @charpos = charindex('4', @save_servername)
IF @charpos <> 0
   begin
	Select @save_envnum = rtrim(@save_envname) + '04'
	goto envnum_end
   end


--  Default to '01' if the naming convention is not found in the instance or the servername
Select @save_envnum = rtrim(@save_envname) + '01'


envnum_end:


-- Create script to delete all rows on the central server dbo.DBA_DBInfo related to this SQL server
Select @miscprint = ' '
Print  @miscprint


Select @miscprint = '--  Start DBA_DBInfo Updates'
Print  @miscprint
Select @miscprint = 'Print ''Start DBA_DBInfo Updates'''
Print  @miscprint


Select @miscprint = 'delete from dbo.DBA_DBInfo where SQLName = ''' + @@servername + ''' and moddate < getdate()-60 AND Status !=''REMOVED'''
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


--  Load the DBextra table ------------
;WITH A AS
(
       SELECT [database_id], DB_NAME(database_id) AS DatabaseName,
       Name AS Logical_Name,
       Physical_Name, (size*8)/1024 SizeMB
       FROM sys.master_files
),
B AS
(
       SELECT [database_id], A.DatabaseName, COUNT(1) AS NumberOfFiles, SUM(SizeMB) AS TotalSizeMB FROM A GROUP BY [database_id], [DatabaseName]
),
C AS
(
       SELECT SUM(B.TotalSizeMB) AS AllDatabasesSize FROM B
),
D AS
(
       SELECT
                     sd.database_id,
                     sd.name,
                     sd.create_date
       FROM sys.databases sd
       --WHERE name = DB_NAME()
),
E AS --> New addition, getting the "last access", defaults to database creation date if none.
(
SELECT [database_id], MAX(maxdate) AS last_access FROM
       (
                     SELECT [database_id],MAX(last_user_seek) AS maxdate FROM sys.dm_db_index_usage_stats WHERE object_id>100 GROUP BY [database_id]
              UNION
                     SELECT [database_id],MAX(last_user_scan) AS maxdate FROM sys.dm_db_index_usage_stats WHERE object_id>100 GROUP BY [database_id]
              UNION
                     SELECT [database_id],MAX(last_user_lookup) AS maxdate FROM sys.dm_db_index_usage_stats WHERE object_id>100 GROUP BY [database_id]
UNION
           SELECT [database_id],MAX(last_user_update) AS maxdate FROM sys.dm_db_index_usage_stats WHERE object_id>100 GROUP BY [database_id]
              UNION
                     SELECT [database_id],MAX(create_date) AS maxdate FROM sys.databases GROUP BY [database_id]
       ) m GROUP BY [database_id]
)
insert into #DBextra
SELECT
       D.database_id,
       d.name AS DBname,
       cast(DATABASEPROPERTYEX(B.DatabaseName,'Recovery') as nvarchar(60)) AS RecoveryModel,
       cast(DATABASEPROPERTYEX(B.DatabaseName,'Status') as nvarchar(60)) AS Status,
       cast(DATABASEPROPERTYEX(B.DatabaseName,'Collation') as sysname) AS Collation,
       B.NumberOfFiles,
       B.TotalSizeMB,
       CASE WHEN C.AllDatabasesSize>0 THEN  B.TotalSizeMB * 100 / C.AllDatabasesSize ELSE 0 END AS Size_PR_From_Total, --> div/0 protection
       D.create_date,
       E.last_access,
       DATEDIFF(day,E.last_access,GETDATE()) AS last_access_in_days
       FROM D
       LEFT JOIN B ON B.database_id=D.database_id
       JOIN E ON d.database_id=E.database_id
       CROSS JOIN C
       --WHERE d.name NOT IN ('master','model','tempdb','msdb','ReportServer','ReportServerTempDB','distribution','DBAOps','dbaperf','DBAOps') --> Exclude "system", as well as Virtuoso's generic DB's


--------------------  Cursor 11  -----------------------
EXECUTE('DECLARE cursor_11DBNames Insensitive Cursor For ' +
  'SELECT d.name, d.database_id
   From master.sys.databases   d ' +
  'Where d.name != ''tempdb''
	AND d.name not in (SELECT DBName FROM dbo.DBA_DBInfo where Status = ''REMOVED'')
	AND source_database_id is null
   Order By d.name For Read Only')


OPEN cursor_11DBNames


WHILE (11=11)
   Begin
	FETCH Next From cursor_11DBNames Into @cu11DBName, @cu11DBId
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11DBNames
	      BREAK
           end


	--  skip DB's "_new" and "_nxt"
	If @cu11DBName like '%_new' or @cu11DBName like '%_nxt'
	   begin
		goto loop11_end
	   end


        -- skip baseline databases
	if @cu11DBName in (SELECT detail01 from dbo.no_check where NoCheck_Type = 'baseline')
           begin
                goto loop11_end
           end


	-- Get AvailGrp info
	Select @save_availGrp_details = ''


	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		If exists (SELECT 1 FROM master.sys.availability_groups AS AG
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
					   where dbcs.database_name = @cu11DBName)
		   begin
			Select @save_availGrp_flag = 'y'


			Select @save_availGrp_details = (SELECT AG.name
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
								   where dbcs.database_name = @cu11DBName)
		   end
	   end


	Select @miscprint = '--  ' + @cu11DBName
	Print  @miscprint


	Select @save_DBstatus = convert(sysname, (SELECT DATABASEPROPERTYEX (@cu11DBName,'status')))


	Select @save_DBCreateDate = (select create_date from master.sys.databases where name = @cu11DBName)


	Select @depl_flag = 'n'
	Select @save_RSTRfolder = ''
	Select @save_baseline_srvname = ''
	Select @save_Appl_desc = ''
	Select @save_db_FullTextCat = 'n'
	Select @save_db_Trustworthy = 'n'
	Select @save_db_Mirroring = 'n'
	Select @save_db_Assemblies = 'n'
	Select @save_db_Filestream = 'n'
	Select @save_db_Repl_Flag = 'n'
	Select @save_db_LogShipping = 'n'
	Select @save_db_ReportingSvcs = 'n'
	Select @save_db_StartupSprocs = 'n'
	Select @Filesize_dataonly = 0
	Select @Filesize_logonly = 0


	If @cu11DBName in ('DBAOps', 'dbaperf', 'DBAOps')
	   begin
	    Select @save_Appl_desc = 'Operations'
		goto end_ApplCrossRef
	   end


	If @cu11DBName in ('dbacentral', 'DBAperf_reports', 'DEPLcontrol','gears','RunBook','RunBook05'
						,'DeployMaster','operations','SpotlightPlaybackDatabase','SpotlightStatisticsRepository'
						,'MetricOps')
	   begin
	    Select @save_Appl_desc  = 'OpsCentral'
		goto end_ApplCrossRef
	   end


	If @cu11DBName in ('master', 'model', 'msdb')
	   begin
	    Select @save_Appl_desc  = 'System'
		goto end_ApplCrossRef
	   end

	--  Determine Appl_desc and baseline folder info
	Select @save_count = (Select count(*) from dbo.db_ApplCrossRef where db_name = @cu11DBName)


	If @save_count = 1
	   begin
		Select @save_RSTRfolder = (Select top 1 RSTRfolder from dbo.db_ApplCrossRef where db_name = @cu11DBName)
		Select @save_Appl_desc = (Select top 1 Appl_desc from dbo.db_ApplCrossRef where db_name = @cu11DBName)
		Select @save_baseline_srvname = (Select top 1 Baseline_srvname from dbo.db_ApplCrossRef where db_name = @cu11DBName)
	   end
	Else If @save_count > 1
	   begin
		Select @save_seq_id = 0


		Start_ApplCrossRef01:


		Select @save_seq_id = (Select top 1 seq_id from dbo.db_ApplCrossRef where db_name = @cu11DBName and seq_id > @save_seq_id order by seq_id)
		Select @save_companionDB_name = (Select companionDB_name from dbo.db_ApplCrossRef where seq_id = @save_seq_id)


		If exists (select 1 from master.sys.databases where name = @save_companionDB_name)
		   begin
			Select @save_RSTRfolder = (Select top 1 RSTRfolder from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
			Select @save_Appl_desc = (Select top 1 Appl_desc from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
			Select @save_baseline_srvname = (Select top 1 Baseline_srvname from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
			goto end_ApplCrossRef
		   end


		If exists (Select 1 from dbo.db_ApplCrossRef where db_name = @cu11DBName and seq_id > @save_seq_id)
		   begin
			goto Start_ApplCrossRef01
		   end
	   end
	Else If @save_count = 0
	   begin
		--  Check for partial DB_names in the db_ApplCrossRef table
		Select @save_seq_id = 0


		Start_ApplCrossRef02:


		Select @save_seq_id = (Select top 1 seq_id from dbo.db_ApplCrossRef where db_name like '%*' and seq_id > @save_seq_id order by seq_id)
		Select @hold_DB_name = (Select db_name from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
		Select @save_companionDB_name = (Select companionDB_name from dbo.db_ApplCrossRef where seq_id = @save_seq_id)

		Select @hold_DB_name = replace(@hold_DB_name, '*', '%')


		If @cu11DBName like @hold_DB_name
		   begin
			If @save_companionDB_name = ''
			   begin
				Select @save_RSTRfolder = (Select top 1 RSTRfolder from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				Select @save_Appl_desc = (Select top 1 Appl_desc from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				Select @save_baseline_srvname = (Select top 1 Baseline_srvname from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				goto end_ApplCrossRef
			   end
			Else If exists (select 1 from master.sys.databases where name = @save_companionDB_name)
			   begin
				Select @save_RSTRfolder = (Select top 1 RSTRfolder from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				Select @save_Appl_desc = (Select top 1 Appl_desc from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				Select @save_baseline_srvname = (Select top 1 Baseline_srvname from dbo.db_ApplCrossRef where seq_id = @save_seq_id)
				goto end_ApplCrossRef
			   end
		   end


		If exists (Select 1 from dbo.db_ApplCrossRef where db_name like '%*' and seq_id > @save_seq_id)
		   begin
			goto Start_ApplCrossRef02
		   end


		--  No db_name match or partial db_name match.  Check to see if this instance is used for a single Appl_desc.  If so, use that.
		Select @hold_dbid = 4
		Select @save_count2 = 0
		Select @hold_Appl_desc = ''


		Start_ApplCrossRef03:


		Select @hold_DB_name = (select top 1 name from  master.sys.databases Where database_id > @hold_dbid)


		Select @hold_dbid = (select database_id from  master.sys.databases Where name = @hold_DB_name)


		Select @save_count = (Select count(*) from dbo.db_ApplCrossRef where db_name = @hold_DB_name)

		If @save_count = 1
		   begin
			If (Select top 1 Appl_desc from dbo.db_ApplCrossRef where db_name = @hold_DB_name) <> @hold_Appl_desc
			   begin
				Select @save_count2 = @save_count2 + 1
				Select @hold_Appl_desc = (Select top 1 Appl_desc from dbo.db_ApplCrossRef where db_name = @hold_DB_name)
			   end
		   end


		If @save_count2 > 1
		   begin
			Select @hold_Appl_desc = ''
			goto end_ApplCrossRef
		   end


		If exists (select 1 from  master.sys.databases Where database_id > @hold_dbid)
		   begin
			goto Start_ApplCrossRef03
		   end


		If @save_count2 = 1
		   begin
			Select @save_Appl_desc = @hold_Appl_desc
			Select @save_baseline_srvname = (Select top 1 Baseline_srvname from dbo.db_ApplCrossRef where Appl_desc = @hold_Appl_desc)
		   end


	   end


	end_ApplCrossRef:


	If @save_baseline_srvname is null or @save_baseline_srvname = ''
	   begin
		Select @save_baseline_srvname = @central_server
	   end


	If @save_domain_name in ('production', 'stage') or @save_envname = 'Production'
	   begin
		Select @save_baseline_srvname = (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer')
	   end


	--  Check to see if this DB is part of the DEPL process
	If exists (select 1 from dbo.db_sequence where db_name = @cu11DBName)
	   and not exists(select 1 from dbo.No_Check where NoCheck_type in ('DEPL_RD_Skip', 'DEPL_ahp_Skip') and (detail01 = @cu11DBName or detail01 = 'all'))
	   begin
		Select @depl_flag = 'y'
		Select @save_depl_flag = 'y'
	   end


	-- check for active full text catalogs
    	Select @cmd = 'select @save_count = (select count(*) from master.sys.dm_fts_active_catalogs df, master.sys.databases d where df.database_id = d.database_id and d.name = ''' + @cu11DBName + ''')'
	EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


	If @save_count is not null and @save_count > 0
	   begin
		Select @save_db_FullTextCat = 'y'
		Select @save_FullTextCat = 'y'
	   end


	--  check for Trustworthy
    	Select @cmd = 'select @save_count = (select count(*) from master.sys.databases where name = ''' + @cu11DBName + ''' and (is_trustworthy_on = 1))'
	EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


	If @save_count is not null and @save_count > 0
	   begin
		Select @save_db_Trustworthy = 'y'
	   end


	-- check for mirroring
	Select @cmd = 'select @save_count = (select count(*) from master.sys.database_mirroring where database_id = DB_ID(''' + ISNULL(@cu11DBName,'') + ''') AND mirroring_state is not null)'
	EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


	If @save_count is not null and @save_count > 0
	   begin
		SELECT @save_db_Mirroring = ISNULL(mirroring_partner_instance,'n'), @save_Mirroring = 'y'
		FROM	master.sys.database_mirroring where database_id = DB_ID(@cu11DBName)


		Select @save_db_Mirroring = ISNULL(mirroring_role_desc,'n') + '\' + @save_db_Mirroring
		FROM	master.sys.database_mirroring where database_id = DB_ID(@cu11DBName)
	   end


	-- check for replication
    	Select @cmd = 'select @save_count = (select count(*) from master.sys.databases where name = ''' + @cu11DBName + ''' and (is_published = 1 or is_subscribed = 1 or is_distributor = 1))'
	EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


	If @save_count is not null and @save_count > 0
	   begin
		Select @save_db_Repl_Flag = 'y'
		Select @save_Repl_Flag = 'y'
	   end


	--  check for log shipping
    	Select @cmd = 'select @save_count = (select count(*) from msdb.dbo.log_shipping_primary_databases where primary_database = ''' + @cu11DBName + ''')'
	EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


	If @save_count is not null and @save_count > 0
	   begin
		Select @save_db_LogShipping = 'y'
		Select @save_LogShipping = 'y'
	   end


	-- Get Logshipping Info (second pass)
	DELETE @LogShipPaths
	SET @TSQL = 'USE ['+@DBName+'];SELECT Cast([Value] AS VarChar(2048)) FROM fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [name] like ''Logship___CopyTo'''
	PRINT @TSQL
	INSERT INTO @LogShipPaths EXEC (@TSQL)
	Delete from @LogShipPaths where CopyToPath is null


	If exists (select 1 from @LogShipPaths)
	   begin
		Select @save_db_LogShipping = ''


		Select @hold_db_LogShipping = (select top 1 CopyToPath from @LogShipPaths order by CopyToPath)


		If @hold_db_LogShipping like '\\' + @save_servername + '%'
		   begin
			Select @save_db_LogShipping = 'Source'
		   end
		Else
		   begin
			Select @save_db_LogShipping = 'Target'
		   end


		If @save_db_LogShipping = 'Source'
		   begin
			Select @hold_db_LogShipping = (select top 1 server_name from msdb.dbo.backupset
								where database_name = @DBName
								order by backup_set_id desc)


			Select @save_db_LogShipping = @save_db_LogShipping + '|' + @hold_db_LogShipping
		   end
		Else
		   begin
			start_logship_part2:


			Select @save_db_LogShipping = @save_db_LogShipping + '|' + @hold_db_LogShipping


			Delete from @LogShipPaths where CopyToPath = @hold_db_LogShipping
			If exists (select 1 from @LogShipPaths)
			   begin
				Select @hold_db_LogShipping = (select top 1 CopyToPath from @LogShipPaths order by CopyToPath)

				goto start_logship_part2
			   end
		   end
	   end


	--  Get the recovery model for this DB
	Select @save_RecovModel = convert(sysname, DATABASEPROPERTYEX(@cu11DBName, 'recovery'))
	If @save_RecovModel is null
	   begin
		Select @save_RecovModel = 'Unknown'
	   end


	--  Get the Page Verify description for this DB
	Select @save_PageVerify = (select page_verify_option_desc from master.sys.databases where name = @cu11DBName)
	If @save_PageVerify is null
	   begin
		Select @save_PageVerify = 'Unknown'
	   end


	-- Get database compatibility level for this DB
	Select @save_cmptlvl = convert(nvarchar(10), compatibility_level) from master.sys.databases where name = @cu11DBName
	if @save_cmptlvl is null
	    begin
		Select @save_cmptlvl = 'Unknown'
	    end


	--  Get the file sizes
	--------------------  Cursor 12  -----------------------
	select @Logsize = 0
	select @Datasize = 0

	EXECUTE('DECLARE cursor_12FILEsize Insensitive Cursor For ' +
	  'SELECT (convert(dec(15),a.size)), a.type
	   From master.sys.master_files a WHERE database_id = DB_ID(''' + @cu11DBName + ''')')

	OPEN cursor_12FILEsize

	WHILE (12=12)
	   Begin
		FETCH Next From cursor_12FILEsize Into @cu12FILEsize, @cu12FILEgroupid
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cursor_12FILEsize
		      BREAK
	           end

		If @cu12FILEgroupid = 1
		   begin
		     select @Logsize = @cu12FILEsize + @Logsize
		   end
		Else
		   begin
		     select @Datasize = @cu12FILEsize + @Datasize
		   end

	End  -- loop 12
	DEALLOCATE cursor_12FILEsize


	Select @Filesize_logonly = @Filesize_logonly + (@Logsize / @pagesperMB)
	Select @Filesize_dataonly = @Filesize_dataonly + (@Datasize / @pagesperMB)


	--  check for startup sprocs.  Startup Sprocs can only exist in the master DB
	IF @cu11DBName = 'master'
	BEGIN
    		Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.sysobjects where xtype = ''p'' and OBJECTPROPERTY(id, ''ExecIsStartup'') = 1)'
		EXEC sp_executesql @cmd, N'@save_count int output', @save_count output


		If @save_count is not null and @save_count > 0
		   begin
			Select @save_db_StartupSprocs = 'y'
		   end
	END


	--  Capture the "extra" DB info
	Select @save_database_id = (select top 1 database_id from #DBextra where DBname = @cu11DBName)
	Select @save_TotalSizeMB = (select top 1 TotalSizeMB from #DBextra where DBname = @cu11DBName)
	Select @save_Size_PR_From_Total = (select top 1 Size_PR_From_Total from #DBextra where DBname = @cu11DBName)
	Select @save_NumberOfFiles = (select top 1 NumberOfFiles from #DBextra where DBname = @cu11DBName)
	Select @save_Collation = (select top 1 Collation from #DBextra where DBname = @cu11DBName)
	Select @save_Last_Access = (select top 1 Last_Access from #DBextra where DBname = @cu11DBName and DBname <> 'model')
	Select @save_Last_Access_in_days = (select top 1 Last_Access_in_days from #DBextra where DBname = @cu11DBName and DBname <> 'model')


	--  Capture DB Settings
	Select @save_DBsettings = suser_sname(owner_sid) + ','
		    + convert(char(1),(is_read_only)) + ','
		    + convert(char(1),(is_auto_close_on)) + ','
		    + convert(char(1),(is_auto_shrink_on)) + ','
		    + convert(char(1),(is_in_standby)) + ','
		    + convert(char(1),(is_cleanly_shutdown)) + ','
		    + convert(char(1),(is_supplemental_logging_enabled)) + ','
		    + convert(char(1),(snapshot_isolation_state)) + ','
		    + convert(char(1),(is_read_committed_snapshot_on)) + ','
		    + convert(char(1),(is_auto_create_stats_on)) + ','
		    + convert(char(1),(is_auto_update_stats_on)) + ','
		    + convert(char(1),(is_auto_update_stats_async_on)) + ','
		    + convert(char(1),(is_ansi_null_default_on)) + ','
		    + convert(char(1),(is_ansi_nulls_on)) + ','
		    + convert(char(1),(is_ansi_padding_on)) + ','
		    + convert(char(1),(is_ansi_warnings_on)) + ','
		    + convert(char(1),(is_arithabort_on)) + ','
		    + convert(char(1),(is_concat_null_yields_null_on)) + ','
		    + convert(char(1),(is_numeric_roundabort_on)) + ','
		    + convert(char(1),(is_quoted_identifier_on)) + ','
		    + convert(char(1),(is_recursive_triggers_on)) + ','
		    + convert(char(1),(is_cursor_close_on_commit_on)) + ','
		    + convert(char(1),(is_local_cursor_default)) + ','
		    + convert(char(1),(is_db_chaining_on)) + ','
		  + convert(char(1),(is_parameterization_forced)) + ','
		    + convert(char(1),(is_master_key_encrypted_by_server)) + ','
		    + convert(char(1),(is_published)) + ','
		    + convert(char(1),(is_subscribed)) + ','
		    + convert(char(1),(is_merge_published)) + ','
		    + convert(char(1),(is_distributor)) + ','
		    + convert(char(1),(is_sync_with_backup)) + ','
		    + convert(char(1),(is_broker_enabled)) + ','
		    + convert(char(1),(is_date_correlation_on)) --+ ','
--		    + convert(char(1),(is_cdc_enabled)) + ','  -- invalid for sql2005
--		    + convert(char(1),(is_encrypted)) + ','  -- invalid for sql2005
--		    + convert(char(1),(is_honor_broker_priority_on))  -- invalid for sql2005
		FROM master.sys.databases WHERE name = @cu11DBName


	--  If the database is not online, skip the Remaining info capture, which requires access to the DB
	If @save_DBstatus <> 'ONLINE'
	   begin
		goto skip_11
	   end


	--  For sql 2012 and above, check availability group status
	If (SELECT cast(parsename(cast(SERVERPROPERTY ('productversion') as varchar(50)), 4) as int)) > 10
	   begin
		If exists(select 1 from sys.dm_hadr_database_replica_states where database_id = DB_ID(@cu11DBName) and is_local = 1 and synchronization_health <> 2)
		   begin
			goto skip_11
		   end
	   end


	--  Check the build table if it exists
	Select @save_build = ''
	Select @save_BaselineDate = ''


	Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.objects o, [' + @cu11DBName + '].sys.columns c where o.object_id = c.object_id and o.name = ''build'' and o.type = ''U'' and o.schema_id = 1 and c.name = ''vchName'')'


	BEGIN TRY
		EXEC sp_executesql @cmd, N'@save_count int output', @save_count output
	END TRY
	BEGIN CATCH
		Select @save_count = null
		Select @save_build = null
		Select @save_BaselineDate = null
	END CATCH


	If @save_count is not null and @save_count = 1
	   begin
		Select @cmd = 'select @save_build = (select top 1 vchLabel from [' + @cu11DBName + '].dbo.build where vchName = ''' + @cu11DBName + ''' and vchLabel not like ''%Backup, Detach%'' order by ibuildid desc)'
		EXEC sp_executesql @cmd, N'@save_build sysname output', @save_build output


		Select @cmd = 'select @save_BaselineDate = (select top 1 dtBuildDate from [' + @cu11DBName + '].dbo.build where vchLabel = ''Baseline Backup'' or vchLabel = ''Backup, Detach & Move'' order by ibuildid desc)'
		EXEC sp_executesql @cmd, N'@save_BaselineDate sysname output', @save_BaselineDate output
	   end


	If @save_build is null
	   begin
		Select @save_build = ''
	   end


	If @save_BaselineDate is null
	   begin
		Select @save_BaselineDate = ''
	   end


	-- check for assemblies
	If not exists (select 1 from dbo.no_check where NoCheck_type = 'backup' and detail01 = @cu11DBName)
	   begin
		Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.assemblies)'

		BEGIN TRY
			EXEC sp_executesql @cmd, N'@save_count int output', @save_count output
		END TRY
		BEGIN CATCH
			Select @save_count = null
		END CATCH


		If @save_count is not null and @save_count > 0
		   begin
			Select @save_db_Assemblies = 'y'
			Select @save_Assemblies = 'y'
		   end
	   end


	-- check for filestream usage
	If not exists (select 1 from dbo.no_check where NoCheck_type = 'backup' and detail01 = @cu11DBName)
	   begin
		Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.filegroups where type_desc like ''%FILESTREAM%'')'

		BEGIN TRY
			EXEC sp_executesql @cmd, N'@save_count int output', @save_count output
		END TRY
		BEGIN CATCH
			Select @save_count = null
		END CATCH


		If @save_count is not null and @save_count > 0
		   begin
			Select @save_db_Filestream = 'Enabled'
		   end


		Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.columns where is_filestream = 1)'

		BEGIN TRY
			EXEC sp_executesql @cmd, N'@save_count int output', @save_count output
		END TRY
		BEGIN CATCH
			Select @save_count = null
		END CATCH


		If @save_count is not null and @save_count > 0
		   begin
			Select @save_db_Filestream = 'Used'
		   end
	   end


	--  check for Report Services
    	Select @cmd = 'select @save_count = (select count(*) from [' + @cu11DBName + '].sys.sysusers Where issqlrole = 1 and name = ''RSExecRole'')'

	BEGIN TRY
		EXEC sp_executesql @cmd, N'@save_count int output', @save_count output
	END TRY
	BEGIN CATCH
		Select @save_count = null
	END CATCH


	If @save_count is not null and @save_count > 0
	   begin
		Select @save_db_ReportingSvcs = 'y'
		Select @save_ReportingSvcs = 'y'
	   end


	--  Get the row count for this DB
    	Select @cmd = 'select @save_row_count = (select sum(rowcnt) from [' + @cu11DBName + '].sys.sysindexes where indid in (0,1))'

	BEGIN TRY
		EXEC sp_executesql @cmd, N'@save_row_count bigint output', @save_row_count output
	END TRY
	BEGIN CATCH
		Select @save_count = null
	END CATCH


	If @save_row_count is null
	   begin
		Select @save_row_count = 0
	   end


	--  Get the VLF (virtual log file) count
	Select @versionString = CAST(SERVERPROPERTY('productversion') AS VARCHAR(20))
	Select @serverVersion = CAST(LEFT(@versionString,CHARINDEX('.', @versionString)) AS DECIMAL(10,5))
        Select @sqlServer2012Version = 11.0 -- SQL Server 2012


	delete from #VLFInfo


	Select @cmd = 'DBCC LOGINFO([' + @cu11DBName + '])  WITH NO_INFOMSGS'


	IF(@serverVersion >= @sqlServer2012Version)
	   begin
		INSERT INTO #VLFInfo (RecoveryUnitID,FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
			EXEC sp_executesql @cmd;
	   end
	Else
	   begin
		INSERT INTO #VLFInfo (FileID,FileSize,StartOffset,FSeqNo,[Status],Parity,CreateLSN)
			EXEC sp_executesql @cmd;
	   end


	Select @save_VLFcount = (Select COUNT(*) FROM #VLFInfo)


	skip_11:


	-- Create script to insert this row on the central server dbo.DBA_DBInfo related for this SQL server
	Select @miscprint = 'if not exists (select 1 from dbo.DBA_DBInfo where SQLName = ''' + upper(@@servername) + ''' and DBname = ''' + rtrim(@cu11DBName) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_DBInfo (SQLName, DBName, status, CreateDate) VALUES (''' + upper(@@servername) + ''', ''' + rtrim(@cu11DBName) + ''', ''' + @save_DBstatus + ''', ''' + convert(nvarchar(30), @save_DBCreateDate, 121) + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update top (1) dbo.DBA_DBInfo set ENVname = ''' + @save_ENVname + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,ENVnum = ''' + @save_ENVnum + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,database_id = ' + convert(nvarchar(20), @save_database_id)
	Print  @miscprint


	Select @miscprint = '                                  ,status = ''' + @save_DBstatus + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,CreateDate = ''' + convert(nvarchar(30), @save_DBCreateDate, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Appl_desc = ''' + @save_Appl_desc + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,BaselineFolder = ''' + @save_RSTRfolder + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,BaselineServername = ''' + upper(@save_baseline_srvname) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,BaselineDate = ''' + @save_BaselineDate + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,build = ''' + @save_build + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,TotalSizeMB = ' + convert(nvarchar(20), @save_TotalSizeMB)
	Print  @miscprint


	Select @miscprint = '                                  ,Size_PR_From_Total = ' + convert(nvarchar(20), @save_Size_PR_From_Total)
	Print  @miscprint


	Select @miscprint = '                                  ,NumberOfFiles = ' + convert(nvarchar(20), @save_NumberOfFiles)
	Print  @miscprint


	Select @miscprint = '                                  ,data_size_MB = ''' + convert(nvarchar(20), @Filesize_dataonly) + ''''
	Print  @miscprint


	Select @miscprint = '                      ,log_size_MB = ''' + convert(nvarchar(20), @Filesize_logonly) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,row_count = ' + convert(nvarchar(20), @save_row_count) + ''
	Print  @miscprint


	Select @miscprint = '                                  ,RecovModel = ''' + @save_RecovModel + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,PageVerify = ''' + @save_PageVerify + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Collation = ''' + @save_Collation + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,FullTextCat = ''' + @save_db_FullTextCat + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Trustworthy = ''' + @save_db_Trustworthy + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Assemblies = ''' + @save_db_Assemblies + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Filestream = ''' + @save_db_Filestream + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,AGname = ''' + @save_availGrp_details + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Mirroring = ''' + @save_db_Mirroring + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Repl_Flag = ''' + @save_db_Repl_Flag + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,LogShipping = ''' + @save_db_LogShipping + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,ReportingSvcs = ''' + @save_db_ReportingSvcs + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,StartupSprocs = ''' + @save_db_StartupSprocs + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,DBCompat = ''' + @save_cmptlvl + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,DEPLstatus = ''' + @depl_flag + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,VLFcount = ' + convert(nvarchar(20), @save_VLFcount) + ''
	Print  @miscprint


	Select @miscprint = '                                  ,DB_Settings = ''' + @save_DBsettings + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Last_Access = ''' + convert(nvarchar(30), @save_Last_Access, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Last_Access_in_days = ' + convert(nvarchar(20), @save_Last_Access_in_days)
	Print  @miscprint


	Select @miscprint = '                                  ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,NotFound = null'
	Print  @miscprint
	Select @miscprint = 'where SQLName = ''' + upper(@@servername) + ''' and DBName = ''' + rtrim(@cu11DBName) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


loop11_end:


End  -- loop 11
DEALLOCATE cursor_11DBNames


Select @miscprint = 'Update dbo.DBA_DBInfo set NotFound = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
Print  @miscprint


Select @miscprint = 'where SQLName = ''' + upper(@@servername) + ''' and modDate <> ''' + convert(nvarchar(30), @save_moddate, 121) + ''' and NotFound is null'
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


--  Verify DEPLstatus setting
If @save_depl_flag = 'y' and exists (select 1 from dbo.No_Check where NoCheck_type in ('DEPL_RD_Skip', 'DEPL_ahp_Skip') and detail01 = 'all')
   begin
	Select @save_depl_flag = 'n'
   end


--  Capture PowerShell flag
delete from #temp_tbl1
Select @cmd = 'powershell /?'
insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl1 where text01 is null or text01 = ''
--select * from #temp_tbl1


Select @save_PowerShell_flag = 'n'


If exists (select 1 from #temp_tbl1 where text01 like '%PSConsoleFile%')
   begin
	Select @save_PowerShell_flag = 'y'
   end


--  Check for the Oracle Client
delete from #temp_tbl1
Select @cmd = 'tnsping infoaccess'
insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl1 where text01 is null or text01 = ''
Delete from #temp_tbl1 where text01 not like '%:\%'
--select * from #temp_tbl1


Select @save_OracleClient = 'na'
Select @save_TNSnamesPath = 'na'

If (select count(*) from #temp_tbl1) > 0
   begin
	Select @save_TNSnamesPath = (select top 1 text01 from #temp_tbl1)
	select @charpos = 0


	startTNSnamesPath:
	select @charpos2 = charindex('\', @save_TNSnamesPath, @charpos)


	If @charpos2 > 0
	   begin
		Select @charpos = @charpos2+1
		goto startTNSnamesPath
	   end


	If @charpos > 0
	   begin
		Select @save_TNSnamesPath = substring(@save_TNSnamesPath, 1, @charpos-2)
	   end


	Select @save_OracleClient = 'unknown'


	If @save_TNSnamesPath like '%.%'
	   begin
		Select @save_OracleClient = @save_TNSnamesPath
		startOracleClient:
		select @charpos = charindex('.', @save_OracleClient)
		select @charpos2 = charindex('\', @save_OracleClient)

		If @charpos2 < @charpos
		   begin
			Select @save_OracleClient = substring(@save_OracleClient, @charpos2+1, 200)
			goto startOracleClient
		   end

		select @charpos2 = charindex('\', @save_OracleClient)

		If @charpos2 > 0
		   begin
			Select @save_OracleClient = substring(@save_OracleClient, 1, @charpos2-1)
		   end
	   end
   end


--  Capture SAN flag
delete from #temp_tbl1
Select @cmd = 'wmic diskdrive list brief'
insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl1 where text01 is null or text01 = ''
--select * from #temp_tbl1


If exists (select 1 from #temp_tbl1 where text01 like '%Powerpath%' or text01 like '%RDAC%' or text01 like '%HSV110%' or text01 like '%FAStT%' or text01 like '%Multi-Path%' or text01 like '%Virtual disk%')
   begin
	Select @save_SAN_flag = 'y'
   end


--  Capture PowerPath Version
delete from #temp_tbl1
Select @cmd = 'powermt version'
insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl1 where text01 is null or text01 = ''
--select * from #temp_tbl1


If exists (select 1 from #temp_tbl1 where text01 like '%version%')
   begin
	Select @save_PowerPath_version = (select top 1 text01 from #temp_tbl1 where text01 like '%version%')
	select @charpos = charindex('version', @save_PowerPath_version)
	Select @save_PowerPath_version = Substring(@save_PowerPath_version, @charpos, len(@save_PowerPath_version)- @charpos + 1)
   end
Else
   begin
	Select @save_PowerPath_version = ''
   end


--------------------------------------------------------------
--------------------------------------------------------------
-- CAPTURE SQL PORT
--------------------------------------------------------------
--------------------------------------------------------------
BEGIN -- USE CONNECTIONPROPERTY
	IF OBJECT_ID('tempdb..#Port') IS NOT NULL DROP TABLE #Port
	CREATE TABLE #Port (Port VarChar(15))


	IF @@VERSION NOT LIKE '%Microsoft SQL Server 2005%'
		INSERT INTO #Port
		EXEC ('SELECT CAST(CASE WHEN CAST(CONNECTIONPROPERTY(''local_tcp_port'') AS INT) < 0 THEN 65536 - CAST(CONNECTIONPROPERTY(''local_tcp_port'') AS INT) ELSE CAST(CONNECTIONPROPERTY(''local_tcp_port'') AS INT) END AS VarChar(50))')


	SELECT @save_port = Port FROM #Port
END
--------------------------------------------------------------
--------------------------------------------------------------
If ISNULL(NULLIF(@save_port,''),'Error') = 'Error'
BEGIN	-- USE Local_ServerEnviro
	Select @save_port = (select env_detail from dbo.Local_ServerEnviro where env_type = 'SQL Port')
	If @save_port is null or @save_port = ''
	   begin
		Select @save_port = 'Error'
	   end
END
--------------------------------------------------------------
--------------------------------------------------------------
-- CAPTURE IP
--------------------------------------------------------------
--------------------------------------------------------------
BEGIN -- USE CONNECTIONPROPERTY
	SET NOCOUNT ON
	IF OBJECT_ID('tempdb..#IP') IS NOT NULL DROP TABLE #IP
	CREATE TABLE #IP (IP VarChar(15))


	IF @@VERSION NOT LIKE '%Microsoft SQL Server 2005%'
		INSERT INTO #IP
		EXEC ('SELECT CAST(CONNECTIONPROPERTY(''local_net_address'') AS VarChar(15))')


	SELECT @save_ip = IP FROM #IP


END
--------------------------------------------------------------
--------------------------------------------------------------
If ISNULL(NULLIF(@save_ip,''),'Error') = 'Error'
BEGIN	-- USE NETSTAT
	delete from #temp_tbl1
	Select @cmd = 'netstat -ano'
	--PRINT @CMD
	insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd


	Delete from #temp_tbl1
	where	nullif(text01,'') is null
		OR	tb11_id < 5
		OR	text01 like '%0.0.0.0%'
		OR  text01 like '%::%'
		OR	text01 NOT like '%:'+@save_port+'%'


	UPDATE	#temp_tbl1
		SET	text01 = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(text01,CHAR(9),'|'),' ','|'),':','|'),'||TCP','TCP'),'||UDP','UDP')

	WHILE @@ROWCOUNT > 0
	BEGIN
		UPDATE	#temp_tbl1
			SET	text01 = REPLACE(text01,'||','|')
		WHERE text01 LIKE '%||%'
	END


	DELETE #temp_tbl1
	WHERE	NOT
			(dbo.dbaudf_ReturnPart(text01,3) != @save_port
		OR	dbo.dbaudf_ReturnPart(text01,5) != @save_port
			)


	SELECT	DISTINCT
			@save_ip = dbo.dbaudf_ReturnPart(text01,2)
	FROM	#temp_tbl1
	WHERE	dbo.dbaudf_ReturnPart(text01,3) = @save_port
		OR	dbo.dbaudf_ReturnPart(text01,5) = @save_port
END
--------------------------------------------------------------
--------------------------------------------------------------
If ISNULL(NULLIF(@save_ip,''),'Error') = 'Error'
BEGIN	-- USE NSLOOKUP
	delete from #temp_tbl1
	Select @cmd = 'nslookup ' + @save_servername
	insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
	Delete from #temp_tbl1 where text01 is null or text01 = ''
	--select * from #temp_tbl1

	If (select count(*) from #temp_tbl1) > 0
	   begin
		Select @save_id = (select top 1 tb11_id from #temp_tbl1 where text01 like '%Name:%')


		Select @save_ip = (select top 1 text01 from #temp_tbl1 where text01 like '%Address:%' and tb11_id > @save_id order by tb11_id)
		Select @save_ip = ltrim(substring(@save_ip, 9, 20))
		Select @save_ip = rtrim(@save_ip)


		Select @charpos = charindex(':', @save_ip)
		IF @charpos <> 0
		   begin
			select @save_ip = substring(@save_ip, 1, @charpos-1)
		   end
	end
	Else
	   begin
		Select @save_ip = 'Error'
	   end
END
--------------------------------------------------------------
--------------------------------------------------------------
-- If nslookup didn't work, try ping
If ISNULL(NULLIF(@save_ip,''),'Error') = 'Error'
BEGIN	-- USE PING
	delete from #temp_tbl1
	Select @cmd = 'ping ' + @save_servername + ' -4'
	insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
	Delete from #temp_tbl1 where text01 is null or text01 = ''
	Delete from #temp_tbl1 where text01 not like '%Reply from%'
	--select * from #temp_tbl1

	If (select count(*) from #temp_tbl1) > 0
	BEGIN
		Select @save_ip = (select top 1 text01 from #temp_tbl1 where text01 like '%Reply from%')
		Select @save_ip = ltrim(substring(@save_ip, 11, 20))
		Select @charpos = charindex(':', @save_ip)
		IF @charpos <> 0
		BEGIN
			select @save_ip = substring(@save_ip, 1, @charpos-1)
		END
	END
	ELSE
	BEGIN
		Select @save_ip = 'Error'
	END
END
--------------------------------------------------------------
--------------------------------------------------------------


--  Capture CPU info


SELECT		@save_CPUcore		= isnull(CAST(dbo.dbaudf_CPUInfo('Cores') AS VarChar(50)),'Unknown')	-- [NumberOfCPUCores]
		,@save_CPUlogical	= isnull(CAST(dbo.dbaudf_CPUInfo('Processors') AS VarChar(50)),'Unknown')	-- [NumberOfCPUProcessors]
		,@save_CPUphysical	= isnull(CAST(dbo.dbaudf_CPUInfo('Sockets') AS VarChar(50)),'Unknown')	-- [NumberOfCPUSockets]


--SELECT		isnull(dbo.dbaudf_CPUInfo('Cores'),'Unknown')		[NumberOfCPUCores]
--		,isnull(dbo.dbaudf_CPUInfo('Processors'),'Unknown')	[NumberOfCPUProcessors]
--		,isnull(dbo.dbaudf_CPUInfo('Sockets'),'Unknown')	[NumberOfCPUSockets]


--Select @save_CPUphysical = 'Unknown'
--Select @save_CPUcore = 'Unknown'
--Select @save_CPUlogical = 'Unknown'


--start_htdump:


--delete from #temp_tbl1
--Select @cmd = 'htdump.exe'
--insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
--Delete from #temp_tbl1 where text01 is null or text01 = ''
--Delete from #temp_tbl1 where text01 not like '%System has %'


--If (select count(*) from #temp_tbl1) = 0
--   begin
--	Select @save_CPUphysical = 'Unknown'
--	Select @save_CPUcore = 'Unknown'
--	Select @save_CPUlogical = 'Unknown'
--	goto start_chkcpu
--   end


----  get physical info
--Select @save_CPUlogical = (select top 1 text01 from #temp_tbl1)
--select @charpos = charindex('System has ', @save_CPUlogical)


--If @charpos > 0
--   begin
--	Select @save_CPUlogical = substring(@save_CPUlogical, @charpos+11, 200)
--	Select @save_CPUlogical = ltrim(rtrim(@save_CPUlogical))
--	Select @save_CPUphysical = @save_CPUlogical
--   end


--select @charpos = charindex('processor', @save_CPUlogical)
--If @charpos > 0
--   begin
--	Select @save_CPUlogical = substring(@save_CPUlogical, 1, @charpos-1)
--	Select @save_CPUlogical = ltrim(rtrim(@save_CPUlogical))
--   end


----  get physical info
--select @charpos = charindex('exposed by ', @save_CPUphysical)


--If @charpos > 0
--   begin
--	Select @save_CPUphysical = substring(@save_CPUphysical, @charpos+11, 200)
--	Select @save_CPUphysical = ltrim(rtrim(@save_CPUphysical))
--   end


--select @charpos = charindex('processor', @save_CPUphysical)
--If @charpos > 0
--   begin
--	Select @save_CPUphysical = substring(@save_CPUphysical, 1, @charpos-1)
--	Select @save_CPUphysical = ltrim(rtrim(@save_CPUphysical))
--   end


--start_chkcpu:
----  One last try with chkcpu32.exe
--If @save_CPUphysical is null or @save_CPUphysical = '' or @save_CPUphysical = 'Unknown'
--   or @save_CPUcore is null or @save_CPUcore = '' or @save_CPUcore = 'Unknown'
--   or @save_CPUlogical is null or @save_CPUlogical = '' or @save_CPUlogical = 'Unknown'
--   begin
--	delete from #temp_tbl1
--	Select @cmd = 'chkcpu32.exe'
--	insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
--	Delete from #temp_tbl1 where text01 is null or text01 = ''


--	If (select count(*) from #temp_tbl1 where text01 like '%System CPU count%') = 0
--	   begin
--		If @save_CPUphysical is null or @save_CPUphysical = ''
--		   begin
--			Select @save_CPUphysical = 'Unknown'
--		   end
--		If @save_CPUcore is null or @save_CPUcore = ''
--		   begin
--			Select @save_CPUcore = 'Unknown'
--		   end
--		If @save_CPUlogical is null or @save_CPUlogical = ''
--		   begin
--			Select @save_CPUlogical = 'Unknown'
--		   end
--		goto skip_cpu
--	   end

--	Select @save_CPUphysical = (select top 1 text01 from #temp_tbl1 where text01 like '%System CPU count%')
--	Select @charpos = charindex(':', @save_CPUphysical)


--	If @charpos > 0
--	   begin
--		Select @save_CPUphysical = substring(@save_CPUphysical, @charpos+1, 200)
--		Select @save_CPUphysical = ltrim(rtrim(@save_CPUphysical))

--		Select @charpos = charindex('Physical', @save_CPUphysical)


--		If @charpos > 0
--		   begin
--			Select @save_CPUphysical = left(@save_CPUphysical, @charpos-1)
--			Select @save_CPUphysical = ltrim(rtrim(@save_CPUphysical))
--			Select @save_CPUphysical_num = convert(smallint, @save_CPUphysical)
--			Select @save_CPUphysical = @save_CPUphysical + ' physical'
--		   end
--	   end


--	Select @save_CPUcore = (select top 1 text01 from #temp_tbl1 where text01 like '%System CPU count%')
--	Select @charpos = charindex(',', @save_CPUcore)


--	If @charpos > 0
--	   begin
--		Select @save_CPUcore = substring(@save_CPUcore, @charpos+1, 200)
--		Select @save_CPUcore = ltrim(rtrim(@save_CPUcore))

--		Select @charpos = charindex('Core', @save_CPUcore)


--		If @charpos > 0
--		   begin
--			Select @save_CPUcore = left(@save_CPUcore, @charpos-1)
--			Select @save_CPUcore = ltrim(rtrim(@save_CPUcore))
--			Select @save_CPUcore_num = convert(smallint, @save_CPUcore)
--			Select @save_CPUcore_num = @save_CPUphysical_num * @save_CPUcore_num
--			Select @save_CPUcore = convert(nvarchar(10), @save_CPUcore_num) + ' core(s)'
--		   end
--	   end


-- 	Select @save_CPUlogical = (select top 1 text01 from #temp_tbl1 where text01 like '%System CPU count%')
--	Select @charpos = charindex('per CPU', @save_CPUlogical)


--	If @charpos > 0
--	   begin
--		Select @save_CPUlogical = substring(@save_CPUlogical, @charpos+8, 200)
--		Select @save_CPUlogical = ltrim(rtrim(@save_CPUlogical))

--		Select @charpos = charindex('Thread', @save_CPUlogical)


--		If @charpos > 0
--		   begin
--			Select @save_CPUlogical = left(@save_CPUlogical, @charpos-1)
--			Select @save_CPUlogical = ltrim(rtrim(@save_CPUlogical))
--			Select @save_CPUlogical = @save_CPUlogical + ' logical'
--		   end
--	   end
--   end


skip_cpu:


--  Capture CPU Type
--  Capture OS Name
--  Capture OS Version
--  Capture OS Install Date
--  Capture OS Uptime
--  Capture Memory
--  Capture PageFile size
--  Capture PageFile path
--  Capture Machine Definition
delete from #temp_tbl2
select @cmd = 'systeminfo'
--print @cmd
insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl2 where text01 is null or text01 = ''
--select * from #temp_tbl2


If (select count(*) from #temp_tbl2) = 0
   begin
	Select @save_CPUtype = ''
	Select @save_OSname = ''
	Select @save_OSver = ''
	Select @save_OSinstallDate = ''
	Select @save_OSuptime = ''
	Select @save_Memory = ''
	Select @save_Pagefile_maxsize = ''
	Select @save_Pagefile_avail = ''
	Select @save_Pagefile_inuse = ''
	Select @save_Pagefile_path = ''
	Select @save_TimeZone = ''
	Select @save_SystemModel = ''
	goto skip_systeminfo
   end


Select @save_CPUtype = (select top 1 text01 from #temp_tbl2 where text01 like '%stepping%')
Select @charpos = charindex(': ', @save_CPUtype)
IF @charpos <> 0
   begin
	Select @save_CPUtype = ltrim(substring(@save_CPUtype, @charpos+1, 132))
   end


Select @save_OSname = (select top 1 text01 from #temp_tbl2 where text01 like 'OS Name:%')
Select @charpos = charindex(':', @save_OSname)
IF @charpos <> 0
   begin
	Select @save_OSname = ltrim(substring(@save_OSname, @charpos+1, 132))
	If @save_OSname like '%x64%'
	   begin
		Select @save_is64bit = 'y'
	   end
   end


Select @save_OSver = (select top 1 text01 from #temp_tbl2 where text01 like 'OS Version:%')
Select @charpos = charindex(':', @save_OSver)
IF @charpos <> 0
   begin
	Select @save_OSver = ltrim(substring(@save_OSver, @charpos+1, 132))
   end


Select @save_OSinstallDate = (select top 1 text01 from #temp_tbl2 where text01 like 'Original Install Date:%')
Select @charpos = charindex(':', @save_OSinstallDate)
IF @charpos <> 0
   begin
	Select @save_OSinstallDate = ltrim(substring(@save_OSinstallDate, @charpos+1, 132))
   end


If exists (select 1 from #temp_tbl2 where text01 like 'System Up Time:%')
   begin
	Select @save_OSuptime = (select top 1 text01 from #temp_tbl2 where text01 like 'System Up Time:%')
	Select @charpos = charindex(':', @save_OSuptime)
	IF @charpos <> 0
	   begin
		Select @save_OSuptime = ltrim(substring(@save_OSuptime, @charpos+1, 132))
	   end


	select @save_OSuptime_seeddate = getdate()


	Select @charpos = charindex('Days', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_OSuptime_day = ltrim(rtrim(left(@save_OSuptime, @charpos-1)))
		select @save_OSuptime = ltrim(right(@save_OSuptime, len(@save_OSuptime)-@charpos-4))
	   end

	Select @charpos = charindex('Hours', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_OSuptime_time_hour = ltrim(rtrim(left(@save_OSuptime, @charpos-1)))
		select @save_OSuptime = ltrim(right(@save_OSuptime, len(@save_OSuptime)-@charpos-5))
	   end

	Select @charpos = charindex('Minutes', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_OSuptime_time_minute = ltrim(rtrim(left(@save_OSuptime, @charpos-1)))
		select @save_OSuptime = ltrim(right(@save_OSuptime, len(@save_OSuptime)-@charpos-7))
	   end

	Select @charpos = charindex('Seconds', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_OSuptime_time_second = ltrim(rtrim(left(@save_OSuptime, @charpos-1)))
	   end

	Select @save_OSuptime_seeddate = dateadd (dd, - convert(int, @save_OSuptime_day), @save_OSuptime_seeddate)
	Select @save_OSuptime_seeddate = dateadd (hh, - convert(int, @save_OSuptime_time_hour), @save_OSuptime_seeddate)
	Select @save_OSuptime_seeddate = dateadd (mi, - convert(int, @save_OSuptime_time_minute), @save_OSuptime_seeddate)
	Select @save_OSuptime_seeddate = dateadd (ss, - convert(int, @save_OSuptime_time_second), @save_OSuptime_seeddate)

	Select @save_OSuptime = convert(sysname, @save_OSuptime_seeddate, 120)


   end
Else
   begin
	Select @save_OSuptime = (select top 1 text01 from #temp_tbl2 where text01 like 'System Boot Time:%')
	Select @charpos = charindex(':', @save_OSuptime)
	IF @charpos <> 0
	   begin
		Select @save_OSuptime = ltrim(substring(@save_OSuptime, @charpos+1, 132))
	   end


	Select @charpos = charindex(',', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_OSuptime_date = ltrim(left(@save_OSuptime, @charpos-1))
		select @save_OSuptime_time = ltrim(right(@save_OSuptime, len(@save_OSuptime)-@charpos))
		--print @save_OSuptime_date
		--print @save_OSuptime_time

		Select @charpos = charindex(' ', @save_OSuptime_time)
		IF @charpos <> 0
		   begin
			select @save_OSuptime_meridiem = ltrim(right(@save_OSuptime_time, len(@save_OSuptime_time)-@charpos))
			select @save_OSuptime_time = ltrim(left(@save_OSuptime_time, @charpos-1))
			--print @save_OSuptime_meridiem
			--print @save_OSuptime_time
		   end

		Select @charpos = charindex('/', @save_OSuptime_date)
		IF @charpos <> 0
		   begin
			select @save_OSuptime_month = ltrim(left(@save_OSuptime_date, @charpos-1))
			select @save_OSuptime_day = ltrim(right(@save_OSuptime_date, len(@save_OSuptime_date)-@charpos))
			Select @save_OSuptime_month = ltrim(rtrim(@save_OSuptime_month))
			If len(@save_OSuptime_month) < 2
			   begin
				Select @save_OSuptime_month = '0' + @save_OSuptime_month
			   end
		   end

		Select @charpos = charindex('/', @save_OSuptime_day)
		IF @charpos <> 0
		   begin
			select @save_OSuptime_year = ltrim(right(@save_OSuptime_day, len(@save_OSuptime_day)-@charpos))
			select @save_OSuptime_day = ltrim(left(@save_OSuptime_day, @charpos-1))
			--print @save_OSuptime_year
			--print @save_OSuptime_day
		   end

		If @save_OSuptime_meridiem = 'PM'
		   begin
			Select @charpos = charindex(':', @save_OSuptime_time)
			IF @charpos <> 0
			   begin
				select @save_OSuptime_time_hour = ltrim(left(@save_OSuptime_time, @charpos-1))
				select @save_OSuptime_time_minute = ltrim(right(@save_OSuptime_time, len(@save_OSuptime_time)-@charpos))
			   end

			Select @save_OSuptime_time_hour = @save_OSuptime_time_hour + 12
			Select @save_OSuptime_time = ltrim(rtrim(@save_OSuptime_time_hour)) + ':' + ltrim(rtrim(@save_OSuptime_time_minute))
		   end


		Select @save_OSuptime = @save_OSuptime_year + '-' + @save_OSuptime_month + '-' + @save_OSuptime_day + ' ' + @save_OSuptime_time


	   end


end


Select @save_Memory = (select top 1 text01 from #temp_tbl2 where text01 like 'Total Physical Memory:%')
Select @charpos = charindex(':', @save_Memory)
IF @charpos <> 0
   begin
	Select @save_Memory = ltrim(substring(@save_Memory, @charpos+1, 132))
   end


Select @save_Pagefile_maxsize = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File: Max Size:%')
Select @charpos = charindex('Max', @save_Pagefile_maxsize)
IF @charpos <> 0
   begin
	Select @save_Pagefile_maxsize = ltrim(substring(@save_Pagefile_maxsize, @charpos+9, 132))
   end


Select @save_Pagefile_avail = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File: Available:%')
Select @charpos = charindex('Available', @save_Pagefile_avail)
IF @charpos <> 0
   begin
	Select @save_Pagefile_avail = ltrim(substring(@save_Pagefile_avail, @charpos+10, 132))
   end


Select @save_Pagefile_inuse = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File: In Use:%')
Select @charpos = charindex('In', @save_Pagefile_inuse)
IF @charpos <> 0
   begin
	Select @save_Pagefile_inuse = ltrim(substring(@save_Pagefile_inuse, @charpos+7, 132))
   end


Select @save_Pagefile_path = ''
Select @save_Pagefile_path2 = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File Location%')
Select @save_id = (select top 1 tbl2_id from #temp_tbl2 where text01 like 'Page File Location%')
Select @charpos = charindex(':', @save_Pagefile_path2)
pagefilepath_loop:
IF @charpos <> 0
   begin
	Select @save_Pagefile_path = @save_Pagefile_path + ltrim(substring(@save_Pagefile_path2, @charpos+1, 132)) + ';'
   end

--  Check for more pagefile paths
Select @save_id = @save_id + 1
Select @save_Pagefile_path2 = (select top 1 text01 from #temp_tbl2 where tbl2_id =  @save_id)
If @save_Pagefile_path2 not like 'Domain%' and @save_Pagefile_path2 like '%:\%'
   begin
	goto pagefilepath_loop
   end


Select @save_TimeZone = (select top 1 text01 from #temp_tbl2 where text01 like 'Time Zone:%')
Select @charpos = charindex('Zone', @save_TimeZone)
IF @charpos <> 0
   begin
	Select @save_TimeZone = ltrim(substring(@save_TimeZone, @charpos+5, 132))
   end


Select @save_system_man = (select top 1 text01 from #temp_tbl2 where text01 like 'System Manufacturer%')
Select @save_system_man = replace(@save_system_man, char(9), ' ')
Select @charpos = charindex('System Manufacturer', @save_system_man)
IF @charpos <> 0
   begin
	Select @save_system_man = rtrim(ltrim(substring(@save_system_man, @charpos+20, 132)))
   end


Select @save_system_mod = (select top 1 text01 from #temp_tbl2 where text01 like 'System Model%')
Select @save_system_mod = replace(@save_system_mod, char(9), ' ')
Select @charpos = charindex('System Model', @save_system_mod)
IF @charpos <> 0
   begin
	Select @save_system_mod = ltrim(substring(@save_system_mod, @charpos+13, 132))
   end


Select @save_system_type = (select top 1 text01 from #temp_tbl2 where text01 like 'System Type%')
Select @save_system_type = replace(@save_system_type, char(9), ' ')
Select @charpos = charindex('System Type', @save_system_type)
IF @charpos <> 0
   begin
	Select @save_system_type = ltrim(substring(@save_system_type, @charpos+12, 132))
   end


If @save_system_man is not null and @save_system_mod is not null and @save_system_type is not null
   begin
    	Select @save_SystemModel = rtrim(@save_system_man) + ' ' + rtrim(@save_system_mod) + ' ' + rtrim(@save_system_type)
   end
Else
   begin
    	Select @save_SystemModel = 'Unknown'
   end


skip_systeminfo:


--  Capture CPU Type
--  Capture OS Name
--  Capture OS Version
--  Capture Memory
--  Capture PageFile size
--  Capture PageFile path
--  Capture Machine Definition
--  Capture IE version
delete from #temp_tbl2
select @cmd = 'type c:\' + @save_msinfo_filename
--print @cmd
insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl2 where text01 is null or text01 = ''
--select * from #temp_tbl2


If (select count(*) from #temp_tbl2) = 0
   begin
	Select @save_IEver = 'Error'
	goto skip_msinfo
   end


If @save_CPUtype is null or @save_CPUtype = ''
   begin
	Select @save_CPUtype = (select top 1 text01 from #temp_tbl2 where text01 like 'Processor%')
	Select @save_CPUtype = replace(@save_CPUtype, char(9), ' ')
	Select @charpos = charindex('Processor', @save_CPUtype)
	IF @charpos <> 0
	   begin
		Select @save_CPUtype = rtrim(ltrim(substring(@save_CPUtype, @charpos+10, 132)))
	   end
   end


If @save_OSname is null or @save_OSname = ''
   begin
	Select @save_OSname = (select top 1 text01 from #temp_tbl2 where text01 like 'OS Name%')
	Select @save_OSname = replace(@save_OSname, char(9), ' ')
	Select @charpos = charindex('OS Name', @save_OSname)
	IF @charpos <> 0
	   begin
		Select @save_OSname = rtrim(ltrim(substring(@save_OSname, @charpos+8, 132)))
		If @save_OSname like '%x64%'
		   begin
			Select @save_is64bit = 'y'
		   end
	   end
   end


If @save_OSver is null or @save_OSver = ''
   begin
	Select @save_OSver = (select top 1 text01 from #temp_tbl2 where text01 like 'Version%' and text01 like '%Build%')
	Select @save_OSver = replace(@save_OSver, char(9), ' ')
	Select @charpos = charindex('Version', @save_OSver)
	IF @charpos <> 0
	   begin
		Select @save_OSver = rtrim(ltrim(substring(@save_OSver, @charpos+8, 132)))
	   end
   end


--  If we have a row for installed memory, use it!
If exists (select 1 from #temp_tbl2 where text01 like 'Installed Physical Memory%')
  begin
	Select @save_Memory = (select top 1 text01 from #temp_tbl2 where text01 like 'Installed Physical Memory%')
	Select @save_Memory = replace(@save_Memory, char(9), ' ')
	Select @save_Memory = replace(@save_Memory, '(RAM)', ' ')
	Select @charpos = charindex('Installed Physical Memory', @save_Memory)
	IF @charpos <> 0
	   begin
		Select @save_Memory = rtrim(ltrim(substring(@save_Memory, @charpos+26, 132)))
	   end
   end


If @save_Memory is null or @save_Memory = ''
   begin
	Select @save_Memory = (select top 1 text01 from #temp_tbl2 where text01 like 'Total Physical Memory%')
	Select @save_Memory = replace(@save_Memory, char(9), ' ')
	Select @charpos = charindex('Total Physical Memory', @save_Memory)
	IF @charpos <> 0
	   begin
		Select @save_Memory = rtrim(ltrim(substring(@save_Memory, @charpos+22, 132)))
	   end
   end


If @save_Pagefile_inuse is null or @save_Pagefile_inuse = ''
   begin
	Select @save_Pagefile_inuse = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File Space%')
	Select @save_Pagefile_inuse = replace(@save_Pagefile_inuse, char(9), ' ')
	Select @charpos = charindex('Page File Space', @save_Pagefile_inuse)
	IF @charpos <> 0
	   begin
		Select @save_Pagefile_inuse = rtrim(ltrim(substring(@save_Pagefile_inuse, @charpos+16, 132)))
	   end
   end


If @save_Pagefile_path is null or @save_Pagefile_path = ''
   begin
	Select @save_Pagefile_path = (select top 1 text01 from #temp_tbl2 where text01 like 'Page File%' and text01 like '%:\%')
	Select @save_Pagefile_path = replace(@save_Pagefile_path, char(9), ' ')
	Select @charpos = charindex('Page File', @save_Pagefile_path)
	IF @charpos <> 0
	   begin
		Select @save_Pagefile_path = rtrim(ltrim(substring(@save_Pagefile_path, @charpos+10, 132)))
	   end
   end

If @save_TimeZone is null or @save_TimeZone = ''
   begin
	Select @save_TimeZone = (select top 1 text01 from #temp_tbl2 where text01 like 'Time Zone%')
	Select @save_TimeZone = replace(@save_TimeZone, char(9), ' ')
	Select @charpos = charindex('Time Zone', @save_TimeZone)
	IF @charpos <> 0
	   begin
		Select @save_TimeZone = rtrim(ltrim(substring(@save_TimeZone, @charpos+10, 132)))
	   end
   end


If @save_SystemModel is null or @save_SystemModel = ''
   begin
	Select @save_system_man = (select top 1 text01 from #temp_tbl2 where text01 like 'System Manufacturer%')
	Select @save_system_man = replace(@save_system_man, char(9), ' ')
	Select @charpos = charindex('System Manufacturer', @save_system_man)
	IF @charpos <> 0
	   begin
		Select @save_system_man = rtrim(ltrim(substring(@save_system_man, @charpos+20, 132)))
	   end


	Select @save_system_mod = (select top 1 text01 from #temp_tbl2 where text01 like 'System Model%')
	Select @save_system_mod = replace(@save_system_mod, char(9), ' ')
	Select @charpos = charindex('System Model', @save_system_mod)
	IF @charpos <> 0
	   begin
		Select @save_system_mod = ltrim(substring(@save_system_mod, @charpos+12, 132))
	   end


	Select @save_system_type = (select top 1 text01 from #temp_tbl2 where text01 like 'System Type%')
	Select @save_system_type = replace(@save_system_type, char(9), ' ')
	Select @charpos = charindex('System Type', @save_system_type)
	IF @charpos <> 0
	   begin
		Select @save_system_type = ltrim(substring(@save_system_type, @charpos+11, 132))
	   end


	If @save_system_man is not null and @save_system_mod is not null and @save_system_type is not null
	   begin
    		Select @save_SystemModel = rtrim(@save_system_man) + ' ' + rtrim(@save_system_mod) + ' ' + rtrim(@save_system_type)
	   end
	Else
	   begin
    		Select @save_SystemModel = 'Unknown'
	   end
   end


Select @save_IEver = (select top 1 text01 from #temp_tbl2 where text01 like 'Version%' and text01 not like '%Build%')
Select @save_IEver = replace(@save_IEver, char(9), ' ')
Select @charpos = charindex('Version', @save_IEver)
IF @charpos <> 0
   begin
	Select @save_IEver = rtrim(ltrim(substring(@save_IEver, @charpos+8, 132)))
   end


skip_msinfo:


--  Capture Boot 3gb
--  Capture Boot pae
--  Capture Boot userva
If @save_OSname like '%r 2008%'
   begin
	goto skip_to_3gb_OS2008
   end


delete from #temp_tbl2
Select @cmd = 'Type c:\boot.ini'
insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl2 where text01 is null or text01 = ''
Delete from #temp_tbl2 where text01 like '%cannot find the file%'


Select @save_boot_3gb = 'n'
Select @save_boot_pae = 'n'
Select @save_boot_userva = 'n'


If (select count(*) from #temp_tbl2) = 0
   begin
	goto skip_boot
   end


If exists(select 1 from #temp_tbl2 where text01 like '%/3gb%')
   begin
	Select @save_boot_3gb = 'y'
   end


If exists(select 1 from #temp_tbl2 where text01 like '%/pae%')
   begin
	Select @save_boot_pae = 'y'
   end


If exists(select 1 from #temp_tbl2 where text01 like '%/userva%')
   begin
	Select @save_boot_userva = 'y'
   end


goto skip_boot


--  Start 3gb check for OS 2008
skip_to_3gb_OS2008:


delete from #temp_tbl2
Select @cmd = 'bcdedit'
insert #temp_tbl2(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl2 where text01 is null or text01 = ''


Select @save_boot_3gb = '-'
Select @save_boot_pae = 'n'
Select @save_boot_userva = 'n'


If (select count(*) from #temp_tbl2) = 0
   begin
	goto skip_boot
   end


If exists(select 1 from #temp_tbl2 where text01 like '%pae%')
   begin
	Select @save_text01 = (select top 1 text01 from #temp_tbl2 where text01 like '%pae%')
	If @save_text01 not like '%Disable%'
	   begin
		Select @save_boot_pae = 'y'
	   end
   end


If exists(select 1 from #temp_tbl2 where text01 like '%userva%')
   begin
	Select @save_boot_userva = 'y'
   end

skip_boot:


--  Capture MDAC version
select @in_key = 'HKEY_LOCAL_MACHINE'
select @in_path = 'SOFTWARE\Microsoft\DataAccess'
select @in_value = 'Version'
exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output


If @result_value is not null and @result_value <> ''
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\DataAccess'
	select @in_value = 'FullInstallVer'
	exec dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


If @result_value is not null and @result_value <> ''
   begin
	Select @save_MDACver = @result_value
   end


--  Capture AntiVirus Info
select @save_install_folder = @result_value
select @in_key = 'HKEY_LOCAL_MACHINE'
select @in_path = 'SOFTWARE\McAfee\SystemCore\VSCore\On Access Scanner\McShield\Configuration\Default'


If @@version like '%x64%'
   begin
	Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
   end
Else
   begin
	Select @cmd = 'reg query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
   end


--print @cmd


insert into #regresults exec master.sys.xp_cmdshell @cmd
delete from #regresults where results is null
--select * from #regresults


If exists (select 1 from #regresults where results like '%but is for a machine type%')
   begin
	Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /s'
	--print @cmd


	insert into #regresults exec master.sys.xp_cmdshell @cmd
	delete from #regresults where results is null
	--select * from #regresults
 end


delete from #regresults where results not like '%ExcludedItem%'


Select @save_AntiVirus_type = 'na'
Select @save_AntiVirus_Excludes = ''


If (select count(*) from #regresults) > 1
   begin
	Select @save_AntiVirus_type = 'McAfee'
	Select @save_AntiVirus_Excludes = 'n'


	delete from #RegValues
	Insert Into #RegValues (Name, Data)
	Exec xp_regenumvalues N'HKEY_LOCAL_MACHINE',N'SOFTWARE\McAfee\SystemCore\VSCore\On Access Scanner\McShield';


	SELECT @save_AntiVirus_type = @save_AntiVirus_type + ' Engine(' + Data FROM #RegValues WHERE Name = 'EngineVersionMajor'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + '.' + Data FROM #RegValues WHERE Name = 'EngineVersionMinor'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + ') AVDat(' + Data FROM #RegValues WHERE Name = 'AVDatVersion'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + '.' + Data FROM #RegValues WHERE Name = 'AVDatVersionMinor'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + ') ' + Data FROM #RegValues WHERE Name = 'AVDatDateYear'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + '-' + Data FROM #RegValues WHERE Name = 'AVDatDateMonth'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + '-' + Data FROM #RegValues WHERE Name = 'AVDatDateDay'
	SELECT @save_AntiVirus_type = @save_AntiVirus_type + ' Detct=' + Data FROM #RegValues WHERE Name = 'AVDatDetections'


	If not exists (select 1 from #regresults where results like '%mssql%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%mssql.1%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%mssql.2%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%mssql.3%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%MDF%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%NDF%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%LDF%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%MDFnxt%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%NDFnxt%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%BAK%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%DIF%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%TRN%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%BKP%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%DFL%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%TNL%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%SQB%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%SQD%')
	   begin
		goto anti_virus_end
	   end
	If not exists (select 1 from #regresults where results like '%SQT%')
	   begin
		goto anti_virus_end
	   end


	Select @save_AntiVirus_Excludes = 'y'


   end


anti_virus_end:


--  Capture OffSiteBU Info
select @save_LastWriteTime = dbo.dbaudf_getfileproperty ('C:\Program Files\Tivoli\TSM\baclient\dsmsched.log', 'file', 'LastWriteTime')


If @save_LastWriteTime Like '%Not a valid File%'
   begin
	Select @save_LastWriteTime = null
	Select @save_OffSiteBkUp_Status = 'File Not Found'


	--Check for Veritas


	select @save_LastWriteTime = (select top 1 DateModified from dbo.dbaudf_directorylist2('C:\Program Files\Veritas\NetBackup\logs','*.log',0) order by DateModified desc)


	If @save_LastWriteTime is not null
	   begin
		Select @save_OffSiteBkUp_Status = 'Veritas'
	   end
   end
Else
   begin
	exec dbo.dbasp_FileAccess_Read_Tail @FullFileName = 'C:\Program Files\Tivoli\TSM\baclient\dsmsched.log', @bytes = 8000, @filetext = @filetext output
	--print @filetext


	Select @filetext = reverse(@filetext)


	Select @charpos = charindex(':ssecca tsaL', @filetext)
	--Select @charpos = charindex('Last access:', @filetext)
	IF @charpos <> 0
	   begin
		select @save_LastWriteTime = substring(@filetext, @charpos-20, 19)
		Select @save_LastWriteTime = reverse(@save_LastWriteTime)
		--Print @save_LastWriteTime
	   end


	Select @filetext = reverse(@filetext)


	If @filetext Like '%Scheduled %' and @filetext Like '%completed successfully%'
	   begin
		Select @save_OffSiteBkUp_Status = 'Success'
	   end
	Else If @filetext Like '%Scheduled %' and @filetext Like '%failed.%'
	   begin
		Select @save_OffSiteBkUp_Status = 'Failed'
	   end
	Else
	   begin
		Select @save_OffSiteBkUp_Status = 'Unknown'
	   end
   end


--  Capture RebootPending Info
INSERT INTO @Results02
EXEC [sys].[xp_instance_regRead] N'HKEY_LOCAL_MACHINE',N'SYSTEM\CurrentControlSet\Control\Session Manager',N'PendingFileRenameOperations'


IF EXISTS (SELECT * FROM @Results02 WHERE KeyValue Like 'PendingFileRenameOperations%' AND Value IS NOT NULL)
   begin
	SET @RebootPending = 'Y'
   end
ELSE
   begin
	SET @RebootPending = 'N'
   end


--  Check for CLR Enabled
If @save_Assemblies = 'y' and @save_clr_enabled = 'n'
   begin
	select @miscprint = '--DBA WARNING: ''CLR Enabled'' setting in sp_configure is not enabled.  Assemblies were found in this SQL instance.'
	raiserror(@miscprint,-1,-1) with log
   end


--  Capture Services
delete from #Keys
INSERT INTO #Keys
EXEC [sys].[xp_instance_regenumkeys] N'HKEY_LOCAL_MACHINE',N'SYSTEM\CurrentControlSet\Services'
delete from #Keys where KeyName is null
--Select * from #Keys


Select @save_services = ''
If (select count(*) from #Keys) > 0
   begin
	Select @save_services = (
						SELECT	REPLACE(DBAOps.[dbo].[dbaudf_ConcatenateUnique](KeyName),',','|') [Services]
						FROM		#Keys
						WHERE	KeyName Like 'ah3agent%'			-- 'AntHill'
							OR	KeyName Like 'McShield%'			-- 'Mcafee'
							OR	KeyName Like 'Splunk%'			-- 'Splunk'
							OR	KeyName Like 'TSM%'				-- 'Tivoli'
							OR	KeyName Like 'InMage%'			-- 'InMage'
							OR	KeyName Like 'MOMConnector%'		-- 'SCOM'
							OR	KeyName Like 'HealthService%'		-- 'SCOM'
							OR	KeyName Like 'McAfeeFramework%'	-- 'Mcafee'
							OR	KeyName Like 'SQLBackupAgent%'	-- 'Redgate'
							OR	KeyName Like 'EmcSrdfce%'		-- 'EMCsrdf'
							OR	KeyName Like 'NetBackup%'		-- 'Netbackup'
							OR	KeyName Like 'MSDTC%'			-- 'DTC'
							OR	KeyName Like 'MSSQL%'			-- 'SQL Server'
							OR	KeyName Like 'MSOLAP%'			-- 'Analysis Services'
							OR	KeyName Like 'puppet%'			-- 'Puppet'
							OR	KeyName Like 'SQLBrowser%'		-- 'SQL Browser'
							OR	KeyName Like 'SQLSERVERAGENT%'	-- 'SQL Agent'
							OR	KeyName Like 'SQLWriter%'		-- 'SQL VSS WRITER'
							OR	KeyName Like 'MSRS%'			-- 'Reporting Services'
							OR	KeyName Like 'ReportServer%'		-- 'Reporting Services'
							OR	KeyName Like 'MSDTS%'			-- 'Integration Services'
						)
   end


--  Set active status
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_sqlstatus' and env_detail like 'maint%')
   begin
	Select @save_server_active = 'm'
   end
Else
   begin
	Select @save_server_active = 'y'
   end


-- Create script to insert this row on the central server dbo.DBA_ServerInfo related for this SQL server
Select @miscprint = ' '
Print  @miscprint


Select @miscprint = '--  Start DBA_ServerInfo Updates'
Print  @miscprint
Select @miscprint = 'Print ''Start DBA_ServerInfo Updates'''
Print  @miscprint


Select @miscprint = 'if not exists (select 1 from dbo.DBA_ServerInfo where ServerName = ''' + upper(@save_servername) + ''' and SQLName = ''' + upper(@@servername) + ''')'
Print  @miscprint


Select @miscprint = '   begin'
Print  @miscprint


Select @miscprint = '      INSERT INTO dbo.DBA_ServerInfo (ServerName, SQLName, Active, Filescan, SQLmail, ClusterName, modDate) VALUES (''' + upper(@save_servername) + ''', ''' + upper(@@servername) + ''', ''' + @save_server_active + ''', ''Y'', ''Y'', '''', ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
Print  @miscprint


Select @miscprint = '   end'
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


Select @miscprint = 'Update top (1) dbo.DBA_ServerInfo set FQDN = ''' + @save_FQDN + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLEnv = ''' + @save_ENVname + ''''
Print  @miscprint


Select @miscprint = '                                      ,active = ''' + @save_server_active + ''''
Print  @miscprint


Select @miscprint = '                                      ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLver = ''' + @save_version + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLinstallDate = ''' + convert(nvarchar(30), @save_SQL_install_date, 121) + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLrecycleDate = ''' + @save_SQLrecycle_date + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLSvcAcct = ''' + @save_SQLSvcAcct + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLAgentAcct = ''' + @save_SQLAgentAcct + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLStartupParms = ''' + @save_SQLStartupParms + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLScanforStartupSprocs = ''' + @save_SQLScanforStartupSprocs + ''''
Print  @miscprint


Select @miscprint = '                                      ,DBAOps_Version = ''' + @save_DBAOps_build + ''''
Print  @miscprint


Select @miscprint = '                                      ,dbaperf_Version = ''' + @save_dbaperf_build + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLDeploy_Version = ''' + @save_DBAOps_build + ''''
Print  @miscprint


Select @miscprint = '                                      ,backup_type = ''' + @save_backup_type + ''''
Print  @miscprint


Select @miscprint = '                                      ,RedGate = ''' + @save_compbackup_rg_flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,awe_enabled = ''' + @save_awe_enabled + ''''
Print  @miscprint


Select @miscprint = '                                      ,MAXdop_value = ''' + @save_MAXdop_value + ''''
Print  @miscprint


Select @miscprint = '                                      ,Memory = ''' + @save_Memory + ''''
Print  @miscprint


Select @miscprint = '                                      ,SQLmax_memory = ''' + @save_SQLmax_memory + ''''
Print  @miscprint


Select @miscprint = '                                      ,tempdb_filecount = ''' + @save_tempdb_filecount + ''''
Print  @miscprint


Select @miscprint = '                                      ,FullTextCat = ''' + @save_FullTextCat + ''''
Print  @miscprint


Select @miscprint = '                                      ,Assemblies = ''' + @save_Assemblies + ''''
Print  @miscprint


Select @miscprint = '                                      ,Filestream_AcsLvl = ''' + @save_filestream_access_level + ''''
Print  @miscprint


Select @miscprint = '                                      ,AvailGrp = ''' + @save_availGrp_flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,Mirroring = ''' + @save_Mirroring + ''''
Print  @miscprint


Select @miscprint = '                                      ,Repl_Flag = ''' + @save_Repl_Flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,LogShipping = ''' + @save_LogShipping + ''''
Print  @miscprint


Select @miscprint = '                                      ,LinkedServers = ''' + @save_LinkedServers + ''''
Print  @miscprint


Select @miscprint = '                                      ,ReportingSvcs = ''' + @save_ReportingSvcs + ''''
Print  @miscprint


Select @miscprint = '                                ,LocalPasswords = ''' + @save_LocalPasswords + ''''
Print  @miscprint


Select @miscprint = '                                      ,DEPLstatus = ''' + @save_depl_flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,IndxSnapshot_process = ''' + @save_IndxSnapshot_process + ''''
Print  @miscprint


Select @miscprint = '                                      ,IndxSnapshot_inverval = ''' + @save_IndxSnapshot_inverval + ''''
Print  @miscprint


Select @miscprint = '                                      ,CLR_state = ''' + @save_CLR_state + ''''
Print  @miscprint


Select @miscprint = '                                      ,FrameWork_ver = ''' + rtrim(@save_FrameWork_ver) + ''''
Print  @miscprint


Select @miscprint = '                                      ,FrameWork_dir = ''' + rtrim(@save_FrameWork_dir) + ''''
Print  @miscprint


Select @miscprint = '                                      ,PowerShell = ''' + @save_PowerShell_flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,OracleClient = ''' + @save_OracleClient + ''''
Print  @miscprint


Select @miscprint = '                                      ,TNSnamesPath = ''' + @save_TNSnamesPath + ''''
Print  @miscprint


Select @miscprint = '                                      ,DomainName = ''' + @save_domain_name + ''''
Print  @miscprint


Select @miscprint = '                                      ,ClusterName = ''' + @save_cluster_name + ''''
Print  @miscprint


Select @miscprint = '                                      ,SAN = ''' + @save_SAN_flag + ''''
Print  @miscprint


Select @miscprint = '                                      ,PowerPath = ''' + @save_PowerPath_version + ''''
Print  @miscprint


Select @miscprint = '                                      ,Port = ''' + @save_port + ''''
Print  @miscprint


Select @miscprint = '                                      ,IPnum = ''' + @save_ip + ''''
Print  @miscprint


Select @miscprint = '                                      ,ServerType = ''' + @save_ServerType + ''''
Print  @miscprint


Select @miscprint = '                                      ,CPUphysical = ''' + @save_CPUphysical + ''''
Print  @miscprint


Select @miscprint = '                                      ,CPUcore = ''' + @save_CPUcore + ''''
Print  @miscprint


Select @miscprint = '                                      ,CPUlogical = ''' + @save_CPUlogical + ''''
Print  @miscprint


Select @miscprint = '                                      ,CPUtype = ''' + @save_CPUtype + ''''
Print  @miscprint


Select @miscprint = '                                      ,OSname = ''' + @save_OSname + ''''
Print  @miscprint


Select @miscprint = '                                      ,OSver = ''' + @save_OSver + ''''
Print  @miscprint


Select @miscprint = '                                      ,OSinstallDate = ''' + @save_OSinstallDate + ''''
Print  @miscprint


Select @miscprint = '                                      ,OSuptime = ''' + @save_OSuptime + ''''
Print  @miscprint


Select @miscprint = '                                      ,MDACver = ''' + @save_MDACver + ''''
Print  @miscprint


Select @miscprint = '                                      ,IEver = ''' + @save_IEver + ''''
Print  @miscprint


Select @miscprint = '                                      ,AntiVirus_type = ''' + @save_AntiVirus_type + ''''
Print  @miscprint


Select @miscprint = '                                      ,AntiVirus_Excludes = ''' + @save_AntiVirus_Excludes + ''''
Print  @miscprint


Select @miscprint = '                                      ,boot_3gb = ''' + @save_boot_3gb + ''''
Print  @miscprint


Select @miscprint = '                                      ,boot_pae = ''' + @save_boot_pae + ''''
Print  @miscprint


Select @miscprint = '                                      ,boot_userva = ''' + @save_boot_userva + ''''
Print  @miscprint


Select @miscprint = '                                      ,Pagefile_maxsize = ''' + @save_Pagefile_maxsize + ''''
Print  @miscprint


Select @miscprint = '                                      ,Pagefile_available = ''' + @save_Pagefile_avail + ''''
Print  @miscprint


Select @miscprint = '                                      ,Pagefile_inuse = ''' + @save_Pagefile_inuse + ''''
Print  @miscprint


Select @miscprint = '                                      ,Pagefile_path = ''' + @save_Pagefile_path + ''''
Print  @miscprint


Select @miscprint = '                                      ,TimeZone = ''' + @save_TimeZone + ''''
Print  @miscprint


Select @miscprint = '                                      ,SystemModel = ''' + @save_SystemModel + ''''
Print  @miscprint


Select @miscprint = '                                      ,Services = ''' + @save_services + ''''
Print  @miscprint


If @save_LastWriteTime is null
   begin
	Select @miscprint = '                                      ,OffSiteBkUp_Date = null'
	Print  @miscprint
   end
Else
   begin
	Select @miscprint = '                                      ,OffSiteBkUp_Date = ''' + @save_LastWriteTime + ''''
	Print  @miscprint
   end


Select @miscprint = '                                      ,OffSiteBkUp_Status = ''' + @save_OffSiteBkUp_Status + ''''
Print  @miscprint


Select @miscprint = '                                      ,RebootPending = ''' + @RebootPending + ''''
Print  @miscprint


Select @miscprint = 'where '
Print  @miscprint


Select @miscprint = 'ServerName = ''' + upper(@save_servername) + ''' and SQLName = ''' + upper(@@servername) + ''''
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


--  Capture Disk Info and create insert/update script
delete from #drives
delete from @Results


-- THIS MAKES SURE THAT THE Software\Virtuoso\Script\DiskMonitor BRANCH EXISTS
EXEC[sys].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor','XX','reg_sz','0'
EXEC[sys].[xp_instance_regdeletevalue] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor','XX'


-- GET DISK ALERT OVERRIDES AT Software\Virtuoso\Script\DiskMonitor
INSERT INTO @Results
EXEC [sys].[xp_instance_regenumvalues] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor'


-- IF FORECAST DATA IS MORE THAN A DAY OLD THEN REPROCESS IT
If not exists (select * from [DBAperf].[sys].[objects] where name = 'DMV_DRIVE_FORECAST2_DETAIL')
   BEGIN
	RAISERROR('--*** CALLING dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2 ***',-1,-1) WITH NOWAIT;
	--EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2
	SELECT @cmd = 'sqlcmd -S' + @@servername + ' -w265 -u -i"EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2" -E'
	EXEC master.sys.xp_cmdshell @cmd, no_output
   END
ELSE IF (SELECT DATEDIFF(DAY,MAX(RunDate),@CheckDate) FROM [DBAperf].[dbo].[DMV_DRIVE_FORECAST2_DETAIL]) > 1
   BEGIN
	RAISERROR('--*** CALLING dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2 ***',-1,-1) WITH NOWAIT;
	--EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2
	SELECT @cmd = 'sqlcmd -S' + @@servername + ' -w265 -u -i"EXEC dbaperf.dbo.dbasp_DiskSpaceCheck_CaptureAndExport2" -E'
	EXEC master.sys.xp_cmdshell @cmd, no_output
   END


--DECLARE @CheckDate	datetime	= getdate()
--	,@MB		bigint		= 1048576
--DECLARE @Results TABLE
--                 (
--                    Value   NVARCHAR (100),
--                    Data    NVARCHAR (100)
--                 )
--INSERT INTO @Results
--EXEC [sys].[xp_instance_regenumvalues] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor'


;WITH		DriveData		-- SOURCE DATA TO WORK FROM
			AS
			(
			SELECT	DISTINCT
				[ServerName]
				,[RootPath]
				,[DateTimeValue]
				,[ForecastUsed_GB]*1024 as ForecastUsed_MB
			FROM	[DBAperf].[dbo].[DMV_DRIVE_FORECAST2_DETAIL]
			WHERE	RunDate = CAST(CONVERT(VarChar(12),@CheckDate,101)AS DATETIME)
			)
			,[Now]		-- CURRENT SIZE
			AS
			(
			SELECT	*
			FROM	[DriveData]
			WHERE	[DateTimeValue] = (SELECT MIN([DateTimeValue]) FROM [DriveData])
			)
			,[Future]	-- FURTHEST FORECASTED SIZE
			AS
			(
			SELECT	*
			FROM	[DriveData]
			WHERE	[DateTimeValue] = (SELECT MAX([DateTimeValue]) FROM [DriveData])
			)
			,
			[AVG]		-- AVERAGE GROWTH PER DAY
			AS
			(
			SELECT		DISTINCT
					[Now].[ServerName]
					,[Now].[RootPath]
					,([Future].[ForecastUsed_MB] - [Now].[ForecastUsed_MB]) / DATEDIFF(day,[Now].[DateTimeValue],[Future].[DateTimeValue]) [AvgGrowthPerDay]
			FROM		[NOW]
			JOIN		[Future]
				ON	[Now].[ServerName]	= [Future].[ServerName]
				AND	[Now].[RootPath]	= [Future].[RootPath]
			)
INSERT INTO	#drives
SELECT		DISTINCT
		T1.RootFolder							[DriveName]
		,CAST(T1.FreeSpace/@MB AS NUMERIC(10,2))			[DriveFree]
		,CAST(T1.TotalSize/@MB AS NUMERIC(10,2))			[DriveSize]
		,CAST((T1.FreeSpace*100.)/T1.TotalSize AS NUMERIC(10,2))	[DriveFee_pct]
		,CAST(ISNULL(T4.[AvgGrowthPerDay] * 7,0) AS NUMERIC(10,2))	[GrowthPerWeekMB]
		,CAST(ISNULL(T3.[DaysTillFail] / 7.0,9999) AS NUMERIC(10,2))	[DriveFullWeeks]
		,100 -T2.Data							[OverrideFreeSpace]
FROM		dbo.dbaudf_ListDrives() T1
LEFT JOIN	@Results T2
       ON	CASE	WHEN LEN(T2.Value) = 1 THEN T2.Value+':\'
		WHEN LEN(T2.Value) = 2 THEN T2.Value+'\'
			ELSE T2.Value END = T1.RootFolder
       AND	isnumeric(T2.Data) = 1							-- Try to exclude other registry entries that are not simply the override value
LEFT JOIN	dbaperf.dbo.DMV_DRIVE_FORECAST2_SUMMARY T3
	ON	T1.RootFolder = T3.RootPath				-- FORECAST DATA CURRENTLY ONLY VALID FOR DRIVES NOT MOUNT POINTS
	AND	T3.rundate = CAST(CONVERT(VarChar(12),@CheckDate,101)AS DATETIME)	-- GET TODAYS FORECAST SUMMARY
LEFT JOIN	[AVG] T4
	ON	T3.[ServerName]		= T4.[ServerName]
	AND	T3.[RootPath]		= T4.[RootPath]
WHERE		ISNULL(T1.TotalSize,0) > 0
	AND	SUBSTRING(T1.RootFolder,2,1) = ':'


If (select count(*) from #drives) > 0
   begin


	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start DBA_DiskInfo Updates'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_DiskInfo Updates'''
	Print  @miscprint


	Select @miscprint = 'Update dbo.DBA_DiskInfo set active = ''n'' where SQLName = ''' + upper(@@servername) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	start_drives01:


	Select @save_drivename = (select top 1 drive from #drives order by drive)


	Select	@save_drivefree			= [FreeSpace]
		,@save_driveSize		= [TotalSize]
		,@save_drivefree_pct		= [PctFree]
		,@save_drive_GrowthPerWeekMB	= [GrowthPerWeekMB]
		,@save_DriveFullWks		= [DriveFullWeeks]
		,@save_Ovrrd_Freespace_pct	= [OverrideFreeSpace]
	from	#drives
	where	drive = @save_drivename

	Select @miscprint = 'if not exists (select 1 from dbo.DBA_DiskInfo where SQLName = ''' + upper(@@servername) + ''' and DriveName = ''' + rtrim(@save_drivename) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_DiskInfo (SQLName, Active, DriveName, modDate) VALUES (''' + upper(@@servername) + ''', ''Y'', ''' + rtrim(@save_drivename) + ''', ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update top (1) dbo.DBA_DiskInfo set active = ''y'''
	Print  @miscprint


	Select @miscprint = '                                      ,DriveSize = ' + convert(varchar(20), @save_drivesize)
	Print  @miscprint


	Select @miscprint = '                                      ,DriveFree = ' + convert(varchar(20), @save_drivefree)
	Print  @miscprint


	Select @miscprint = '                                      ,DriveFree_pct = ' + convert(varchar(20), @save_drivefree_pct)
	Print  @miscprint


	If @save_drive_GrowthPerWeekMB is not null
	   begin
		Select @miscprint = '                                      ,GrowthPerWeekMB = ' + convert(varchar(20), @save_drive_GrowthPerWeekMB)
		Print  @miscprint
	   end


	If @save_DriveFullWks is not null
	   begin
		Select @miscprint = '                                      ,DriveFullWks = ' + convert(varchar(20), @save_DriveFullWks)
		Print  @miscprint
	   end


	If @save_Ovrrd_Freespace_pct is not null
	   begin
		Select @miscprint = '                                      ,Ovrrd_Freespace_pct = ' + convert(varchar(20), @save_Ovrrd_Freespace_pct)
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = '                                      ,Ovrrd_Freespace_pct = null'
		Print  @miscprint
	   end


	Select @miscprint = '                                      ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = 'where '
	Print  @miscprint


	Select @miscprint = 'SQLName = ''' + upper(@@servername) + ''' and DriveName = ''' + rtrim(@save_drivename) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	delete from #drives where drive = @save_drivename
	If (select count(*) from #drives) > 0
	   begin
		goto start_drives01
	   end


	Select @miscprint = ' '
	Print  @miscprint


   end


---------------------------------------
--  START DBfile CAPTURE PROCESS
---------------------------------------


--  Load temp table from sys.master_files
delete from @DBfiles


insert into @DBfiles
SELECT database_id, file_id from sys.master_files
--select * from @DBfiles


If (select count(*) from @DBfiles) > 0
   begin


	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start DBA_DBfileInfo Updates'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_DBfileInfo Updates'''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	start_dbfiles:


	Select @save_dbf_id = (select top 1 dbf_id from @DBfiles order by dbf_id)
	Select @save_database_id = (select database_id from @DBfiles where dbf_id = @save_dbf_id)
	Select @save_file_id = (select file_id from @DBfiles where dbf_id = @save_dbf_id)
	Select @save_DBfile_DBname = (select name from master.sys.databases where database_id = @save_database_id)
	Select @save_DBfile_LogicalName = (select name from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)
	Select @save_DBfile_FileType = (select type_desc from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)


	Select @save_DBfile_DBunavailable_flag = 'n'


	BEGIN TRY
		set @save_usage = ''
		SET @cmd = N'select @save_usage = (case status & 0x40 when 0x40 then ''log only'' else ''data only'' end) from [' + @save_DBfile_DBname + '].sys.sysfiles WHERE fileid = ' + convert(varchar(10), @save_file_id)
		SET @vars = N'@save_usage sysname OUTPUT'
		exec sp_executeSQL @cmd, @vars, @save_usage OUTPUT
	END TRY
	BEGIN CATCH
		set @save_usage = 'unavailable'
		Select @save_DBfile_DBunavailable_flag = 'y'
 	END CATCH;


	If @save_DBfile_DBunavailable_flag = 'n'
	   begin
		set @save_DBfile_FGname = ''
		SET @cmd = N'select @save_DBfile_FGname = filegroup_name(groupid) from [' + @save_DBfile_DBname + '].sys.sysfiles WHERE fileid = ' + convert(varchar(10), @save_file_id)
		SET @vars = N'@save_DBfile_FGname sysname OUTPUT'
		exec sp_executeSQL @cmd, @vars, @save_DBfile_FGname OUTPUT
	   end
	Else
	   begin
		select @save_DBfile_FGname = 'unavailable'
	   end


	Select @save_DBfile_PhysicalPath = (select physical_name from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)
	Select @save_DBfile_PhysicalPath = reverse(@save_DBfile_PhysicalPath)
	Select @charpos = charindex('\', @save_DBfile_PhysicalPath)
	IF @charpos <> 0
	   begin
		Select @save_DBfile_PhysicalName = left(@save_DBfile_PhysicalPath, @charpos-1)
		Select @save_DBfile_PhysicalName = reverse(@save_DBfile_PhysicalName)
		Select @save_DBfile_PhysicalPath = substring(@save_DBfile_PhysicalPath, @charpos+1, len(@save_DBfile_PhysicalPath)-@charpos)
		Select @save_DBfile_PhysicalPath = reverse(@save_DBfile_PhysicalPath)
	   end


	Select @save_DBfile_state = (select state_desc from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)


	If @save_DBfile_DBunavailable_flag = 'n'
	   begin
		set @save_DBfile_sizewk = ''
		SET @cmd = N'select @save_DBfile_sizewk = size from [' + @save_DBfile_DBname + '].sys.sysfiles WHERE fileid = ' + convert(varchar(10), @save_file_id)
		SET @vars = N'@save_DBfile_sizewk bigint OUTPUT'
		exec sp_executeSQL @cmd, @vars, @save_DBfile_sizewk OUTPUT


		set @save_FreeSpacewk = ''
		SET @cmd = N'use [' + @save_DBfile_DBname + '] select @save_FreeSpacewk = FILEPROPERTY(''' + @save_DBfile_LogicalName + ''', ''SpaceUsed'')'
		SET @vars = N'@save_FreeSpacewk bigint OUTPUT'
		exec sp_executeSQL @cmd, @vars, @save_FreeSpacewk OUTPUT


		Select @save_FreeSpacewk = (@save_DBfile_sizewk - @save_FreeSpacewk)


		Select @save_DBfile_size = ((@save_DBfile_sizewk * 8) / 1024) + 1
		Select @save_FreeSpace = ((@save_FreeSpacewk * 8) / 1024) + 1
	   end


	Select @save_DBfile_MaxSize = (select max_size from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)
	If @save_DBfile_MaxSize <> -1
	   begin
		Select @save_DBfile_MaxSize = (@save_DBfile_MaxSize * 8) / 1024
	   end


	Select @save_DBfile_Growth = (select growth from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)
	If (select is_percent_growth from sys.master_files where database_id = @save_database_id and file_id = @save_file_id) = 1
	   begin
		Select @save_DBfile_Growth = @save_DBfile_Growth + ' PCT'
	   end
	Else
	   begin
		Select @save_DBfile_Growth = (@save_DBfile_Growth * 8) / 1024
		Select @save_DBfile_Growth = @save_DBfile_Growth + ' MB'
	   end


	Select @save_DBfile_is_media_RO = (select is_media_read_only from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)


	Select @save_DBfile_is_RO = (select is_read_only from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)


	Select @save_DBfile_is_sparse = (select is_sparse from sys.master_files where database_id = @save_database_id and file_id = @save_file_id)


	-- Create script to insert this row on the central server table dbo.DBA_DBfileInfo related for this SQL server
	Select @miscprint = 'if not exists (select 1 from dbo.DBA_DBfileInfo where SQLName = ''' + upper(@@servername) + ''' and DBname = ''' + rtrim(@save_DBfile_DBname) + ''' and LogicalName = ''' + rtrim(@save_DBfile_LogicalName) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_DBfileInfo (SQLName, DBName, LogicalName) VALUES (''' + upper(@@servername) + ''', ''' + rtrim(@save_DBfile_DBname) + ''', ''' + @save_DBfile_LogicalName + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update top (1) dbo.DBA_DBfileInfo set File_ID = ' + convert(varchar(5), @save_file_id)
	Print  @miscprint


	Select @miscprint = '                                  ,FileType = ''' + @save_DBfile_FileType + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Usage = ''' + @save_usage + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,FileGroup = ''' + @save_DBfile_FGname + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,FilePath = ''' + @save_DBfile_PhysicalPath + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,FileName = ''' + @save_DBfile_PhysicalName + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,State = ''' + @save_DBfile_state + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Size_MB = ' + convert(varchar(15), @save_DBfile_size)
	Print  @miscprint


	Select @miscprint = '                                  ,FreeSpace_MB = ' + convert(varchar(15),  @save_FreeSpace)
	Print  @miscprint


	Select @miscprint = '                                  ,MaxSize_MB = ' + convert(varchar(15), @save_DBfile_MaxSize)
	Print  @miscprint


	Select @miscprint = '                                  ,Growth = ''' + @save_DBfile_Growth + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,is_media_read_only = ' + convert(char(1), @save_DBfile_is_media_RO)
	Print  @miscprint


	Select @miscprint = '                                  ,is_read_only = ' + convert(char(1), @save_DBfile_is_RO)
	Print  @miscprint


	Select @miscprint = '                                  ,is_sparse = ' + convert(char(1), @save_DBfile_is_sparse)
	Print  @miscprint


	Select @miscprint = '                                  ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = 'where SQLName = ''' + upper(@@servername) + ''' and DBname = ''' + rtrim(@save_DBfile_DBname) + ''' and LogicalName = ''' + rtrim(@save_DBfile_LogicalName) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	--  check for more rows
	delete from @DBfiles where dbf_id = @save_dbf_id
	If (select count(*) from @DBfiles) > 0
	   begin
		goto start_dbfiles
	   end


   end


---------------------------------------
--  START SQL Job CAPTURE PROCESS
---------------------------------------


--  Set joblog share path
Select @JobLog_Share_Path = nullif(DBAOps.[dbo].[dbaudf_GetSharePath](DBAOps.[dbo].[dbaudf_getShareUNC]('SQLjob_logs')),'Not Found')


--  Load temp table from sys.master_files
delete from @SQLjobs


Insert into @SQLjobs
select s.job_id, s.name, s.enabled, s.description, s.start_step_id, suser_sname(s.owner_sid), s.date_created, s.date_modified
from msdb.dbo.sysjobs s, master.sys.server_principals p
where s.owner_sid = p.sid
--select * from @SQLjobs


--  Load the job schedule temp table
delete from @weekDay


Insert Into @weekDay
Select 1, 'Sunday'  Union All
Select 2, 'Monday'  Union All
Select 4, 'Tuesday'  Union All
Select 8, 'Wednesday'  Union All
Select 16, 'Thursday'  Union All
Select 32, 'Friday'  Union All
Select 64, 'Saturday';

delete from @jobschedules


Insert into @jobschedules
    Select sched.name
        , jobsched.job_id
	, sched.enabled
        , Case When sched.freq_type = 1 Then 'Once'
            When sched.freq_type = 4
                And sched.freq_interval = 1
                    Then 'Daily'
            When sched.freq_type = 4
                Then 'Every ' + Cast(sched.freq_interval As varchar(5)) + ' days'
            When sched.freq_type = 8 Then
                Replace( Replace( Replace((
                    Select maskValue
                    From @weekDay As x
                    Where sched.freq_interval & x.mask <> 0
                    Order By mask For XML Raw)
                , '"/><row maskValue="', ', '), '<row maskValue="', ''), '"/>', '')
                + Case When sched.freq_recurrence_factor <> 0
                        And sched.freq_recurrence_factor = 1
                         Then '; weekly'
                    When sched.freq_recurrence_factor <> 0 Then '; every '
                + Cast(sched.freq_recurrence_factor As varchar(10)) + ' weeks' End
            When sched.freq_type = 16 Then 'On day '
                + Cast(sched.freq_interval As varchar(10)) + ' of every '
                + Cast(sched.freq_recurrence_factor As varchar(10)) + ' months'
            When sched.freq_type = 32 Then
                Case When sched.freq_relative_interval = 1 Then 'First'
                    When sched.freq_relative_interval = 2 Then 'Second'
                    When sched.freq_relative_interval = 4 Then 'Third'
                    When sched.freq_relative_interval = 8 Then 'Fourth'
                    When sched.freq_relative_interval = 16 Then 'Last'
                End +
                Case When sched.freq_interval = 1 Then ' Sunday'
                    When sched.freq_interval = 2 Then ' Monday'
                    When sched.freq_interval = 3 Then ' Tuesday'
                    When sched.freq_interval = 4 Then ' Wednesday'
                    When sched.freq_interval = 5 Then ' Thursday'
                    When sched.freq_interval = 6 Then ' Friday'
                    When sched.freq_interval = 7 Then ' Saturday'
                    When sched.freq_interval = 8 Then ' Day'
                    When sched.freq_interval = 9 Then ' Weekday'
                    When sched.freq_interval = 10 Then ' Weekend'
                End
                + Case When sched.freq_recurrence_factor <> 0
                        And sched.freq_recurrence_factor = 1 Then '; monthly'
                    When sched.freq_recurrence_factor <> 0 Then '; every '
           + Cast(sched.freq_recurrence_factor As varchar(10)) + ' months' End
            When sched.freq_type = 64 Then 'StartUp'
            When sched.freq_type = 128 Then 'Idle'
          End As 'frequency'
        , IsNull('Every ' + Cast(sched.freq_subday_interval As varchar(10)) +
            Case When sched.freq_subday_type = 2 Then ' seconds'
                When sched.freq_subday_type = 4 Then ' minutes'
                When sched.freq_subday_type = 8 Then ' hours'
            End, 'Once') As 'subFrequency'
        , Replicate('0', 6 - Len(sched.active_start_time))
      + Cast(sched.active_start_time As varchar(6))
        , Replicate('0', 6 - Len(sched.active_end_time))
            + Cast(sched.active_end_time As varchar(6))
        , Replicate('0', 6 - Len(jobsched.next_run_time))
            + Cast(jobsched.next_run_time As varchar(6))
        , Cast(jobsched.next_run_date As char(8))
    From msdb.dbo.sysschedules As sched
    Join msdb.dbo.sysjobschedules As jobsched
        On sched.schedule_id = jobsched.schedule_id


If (select count(*) from @SQLjobs) > 0
   begin


	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start DBA_JobInfo Updates'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_JobInfo Updates'''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	start_sqljobs:


	-- Add New Column if not yet there
	IF NOT EXISTS (SELECT 1 from sys.columns where object_id = object_id('DBA_JobInfo') and name =  'PassCheckDesc')
		ALTER TABLE [dbo].[DBA_JobInfo] ADD [PassCheckDesc] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL


	Select	@save_job_PassCheck = 'y'
			,@Job_PassCheckDesc = ''


	Select @save_sj_id = (select top 1 sj_id from @SQLjobs order by jobname)
	Select @save_job_id = (select job_id from @SQLjobs where sj_id = @save_sj_id)
	Select @save_jobname = (select jobname from @SQLjobs where sj_id = @save_sj_id)
	Select @save_enabled = (select enabled from @SQLjobs where sj_id = @save_sj_id)
	Select @save_jobowner = (select jobowner from @SQLjobs where sj_id = @save_sj_id)
	Select @save_description = (select description from @SQLjobs where sj_id = @save_sj_id)
	Select @save_StartStep = (select start_step_id from @SQLjobs where sj_id = @save_sj_id)
	Select @save_job_created = (select date_created from @SQLjobs where sj_id = @save_sj_id)
	Select @save_job_modified = (select date_modified from @SQLjobs where sj_id = @save_sj_id)


	-- Fix description for output.
	Select @save_description = replace(@save_description, '''', '''''')


	--  Capture last execution date
	Select @save_job_last_execution = null
	Select @save_job_last_execution = MAX(CAST(STUFF(STUFF(CAST(jh.run_date as varchar),7,0,'-'),5,0,'-') + ' ' + STUFF(STUFF(REPLACE(STR(jh.run_time,6,0),' ','0'),5,0,':'),3,0,':') as datetime))
						FROM msdb.dbo.sysjobs j
						INNER JOIN msdb.dbo.sysjobhistory jh
						ON jh.job_id = j.job_id AND jh.step_id = 0
						WHERE j.[name] = @save_jobname
						GROUP BY j.[name]


	--  Capture Avg duration info
	Select @save_AvgDurationMin = (Avg((run_duration/10000) * 3600 + (run_duration/100%100)*60 + run_duration%100))/60
					From msdb.dbo.sysjobhistory
					Where job_id = @save_job_id
					    And step_id = 0 -- only grab our total run-time
					    And run_status = 1 -- only grab successful executions
					    And msdb.dbo.agent_datetime(run_date, run_time) >= DateAdd(day, -30, GetDate())
					Group By job_id;


	--  Capture job step info
	Select @save_JobSteps = dbo.dbaudf_ConcatenateUnique('(' + RIGHT('00'+CAST(step_id AS VarChar(2)),2) + ')' + step_name)
				from msdb.dbo.sysjobsteps
				where job_id = @save_job_id


	--  Capture job schedule info
	Select @save_job_schedule_output = ''
	If exists (select 1 from @jobschedules where job_id = @save_job_id)
	   begin
		start_job_schedule_info:
		If len(@save_job_schedule_output) > 0
		   begin
			Select @save_job_schedule_output = @save_job_schedule_output + ', '
		   end
		Select @save_job_schedulename = (select top 1 schedulename from @jobschedules where job_id = @save_job_id)
		Select @save_job_schedule_enabled = (select enabled from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
		Select @save_job_schedule_frequency = (select frequency from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
		Select @save_job_schedule_subfrequency = (select subfrequency from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)


		Select @save_job_schedule_runtime = null
		If @save_job_schedule_subfrequency like '%every%'
		   begin
			Select @save_job_schedule_starttime = (select start_time from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
			Select @save_job_schedule_endtime = (select end_time from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
			Select @save_job_schedule_runtime = 'from ' + SubString(@save_job_schedule_starttime, 1, 2) + ':'
								+ SubString(@save_job_schedule_starttime, 3, 2) + ' to '
								+ SubString(@save_job_schedule_endtime, 1, 2) + ':'
								+ SubString(@save_job_schedule_endtime, 3, 2)
		   end
		Else
		   begin
			Select @save_job_schedule_starttime = (select start_time from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
			Select @save_job_schedule_runtime = 'at ' + SubString(@save_job_schedule_starttime, 1, 2) + ':'
								+ SubString(@save_job_schedule_starttime, 3, 2)
		   end


		If @save_job_schedule_frequency like '%once%' and @save_job_schedule_subfrequency like '%once%'
		   begin
			Select @save_job_schedule_output = @save_job_schedule_output + @save_job_schedulename + '(OneTime, '
		   end
		Else
		   begin
			Select @save_job_schedule_output = @save_job_schedule_output + @save_job_schedulename + '(' + @save_job_schedule_frequency + ' ' + @save_job_schedule_subfrequency + ' ' + @save_job_schedule_runtime + ', '
		   end


		If @save_job_schedule_enabled = 1
		   begin
			Select @save_job_schedule_output = @save_job_schedule_output + 'Enabled)'
		   end
		Else
		   begin
			Select @save_job_schedule_output = @save_job_schedule_output + 'Disabled)'
		   end


		If @save_enabled = 1 and @save_job_schedule_enabled = 1 and (select nextrundate from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename) <> 0
		   begin
			Select @save_job_schedule_nextrundate = (select nextrundate from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename)
			Select @save_job_schedule_nextrundate_date = SubString(@save_job_schedule_nextrundate, 1, 4) + '/' + SubString(@save_job_schedule_nextrundate, 5, 2) + '/' + SubString(@save_job_schedule_nextrundate, 7, 2)
			--  check to see if next run date is in the past
			If datediff(dd, @save_job_schedule_nextrundate_date, getdate()) > 1
			   begin
				Select	@save_job_PassCheck = 'n'
						,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs Next Scheduled Run Date is in the past.'
			   end
		   end


		--  Check for more rows
		Delete from @jobschedules where job_id = @save_job_id and schedulename = @save_job_schedulename
		If exists (select 1 from @jobschedules where job_id = @save_job_id)
		   begin
			Select @save_job_schedulename = null
			Select @save_job_schedule_enabled = null
			Select @save_job_schedule_frequency = null
			Select @save_job_schedule_subfrequency = null


			goto start_job_schedule_info
		   end
	   end


	--  Check job health
	--If @save_job_PassCheck = 'n'
	--   begin
	--	goto skip_job_PassCheck
	--   end


	--  make sure all tssql steps point to master
	If exists (select 1 from msdb.dbo.sysjobsteps where job_id = @save_job_id and subsystem = 'TSQL' and DB_ID(database_name) IS NULL)
	   BEGIN
			-- TRY TO AUTO FIX
			UPDATE msdb.dbo.sysjobsteps SET database_name = 'master' where job_id = @save_job_id and subsystem = 'TSQL' and DB_ID(database_name) IS NULL
			
			-- SET JOB FAIL IF AUTO FIX DOES NOT WORK
			If exists (select 1 from msdb.dbo.sysjobsteps where job_id = @save_job_id and subsystem = 'TSQL' and DB_ID(database_name) IS NULL)
				SELECT		@save_job_PassCheck = 'n'
							,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs Database is not an active database.'

		--goto skip_job_PassCheck
	   end


	--  make sure job owner is SA
	If (SELECT owner_sid FROM msdb.dbo.sysjobs where job_id = @save_job_id) != 0x01
	   BEGIN
			-- TRY TO AUTO FIX
			EXEC msdb.dbo.sp_update_job @job_id = @save_job_id,@owner_login_name = 'sa'
			
			-- SET JOB FAIL IF AUTO FIX DOES NOT WORK
			If (SELECT owner_sid FROM msdb.dbo.sysjobs where job_id = @save_job_id) != 0x01
				SELECT		@save_job_PassCheck = 'n' 
							,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs owner is not SA.'

		--goto skip_job_PassCheck
	   END


	--  make sure Transact-SQL job step output file is set and pointed to the sql_joblogs folder
	If exists (select 1 from msdb.dbo.sysjobsteps T1 WHERE job_id = @save_job_id and subsystem = 'TSQL' and output_file_name NOT LIKE @JobLog_Share_Path +'%')
	   begin
		Select	@save_job_PassCheck = 'n'
				,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs does not have file ouput to correct path.'
		--goto skip_job_PassCheck
	   end


	-- select * from msdb.dbo.sysjobsteps T1 where subsystem = 'TSQL' and output_file_name IS NOT NULL AND flags & 2 = 0


	--  make sure the Transact-SQL job step output file is set to append
	If exists (select 1 from msdb.dbo.sysjobsteps T1 where job_id = @save_job_id and subsystem = 'TSQL' and output_file_name IS NOT NULL AND flags & 2 = 0)
	   begin
		Select	@save_job_PassCheck = 'n'
				,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs file output is not set to append.'
		--goto skip_job_PassCheck
	   end


	   -- select * from msdb.dbo.sysjobsteps T1 where subsystem = 'TSQL' and flags & 4 = 0 AND flags & 8 = 0	AND flags & 16 = 0


	   	--  make sure the Transact-SQL job step output to step history
	If exists (select 1 from msdb.dbo.sysjobsteps T1 where job_id = @save_job_id and subsystem = 'TSQL' and flags & 4 = 0 AND flags & 8 = 0	AND flags & 16 = 0 )
	   begin
		Select	@save_job_PassCheck = 'n'
				,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs is not set to output Transact-SQL job step to step history.'
		--goto skip_job_PassCheck
	   end


	--  check to see if the job is in a failed state
	If (SELECT top 1 h.[run_status]
		FROM [msdb].[dbo].[sysjobhistory] h
		INNER JOIN [msdb].[dbo].[sysjobs] j
		ON h.[job_id] = j.[job_id]
		where h.[job_id] = @save_job_id
		and h.step_id = 0
		order by h.instance_id desc) = 0
	   begin
		Select	@save_job_PassCheck = 'n'
				,@Job_PassCheckDesc	= @Job_PassCheckDesc + CHAR(13)+CHAR(10)+'Jobs is currently in a failed state.'
		--goto skip_job_PassCheck
	   end


	skip_job_PassCheck:


	-- Create script to insert this row on the central server table dbo.DBA_JobInfo related for this SQL server
	Select @miscprint = 'if not exists (select 1 from dbo.DBA_JobInfo where SQLName = ''' + upper(@@servername) + ''' and JobName = ''' + rtrim(@save_jobname) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_JobInfo (SQLName, JobName) VALUES (''' + upper(@@servername) + ''', ''' + rtrim(@save_jobname) + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update top (1) dbo.DBA_JobInfo set Enabled = ' + convert(varchar(5), @save_enabled)
	Print  @miscprint


	Select @miscprint = '                                  ,Owner = ''' + @save_jobowner + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Description = ''' + @save_description + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,JobSteps = ''' + @save_JobSteps + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,JobSchedules = ''' + @save_job_schedule_output + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,StartStep = ' + convert(varchar(5), @save_StartStep)
	Print  @miscprint


	Select @miscprint = '                                  ,AvgDurationMin = ' + convert(varchar(15),  @save_AvgDurationMin)
	Print  @miscprint


	Select @miscprint = '									,PassCheck = ''' + convert(char(1), @save_job_PassCheck) + ''''
	Print  @miscprint


	Select @miscprint = '									,PassCheckDesc = ''' + @Job_PassCheckDesc + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Created = ''' + convert(nvarchar(30), @save_job_created, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,Modified = ''' + convert(nvarchar(30), @save_job_modified, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,LastExecuted = ''' + convert(nvarchar(30), @save_job_last_execution, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                  ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = 'where SQLName = ''' + upper(@@servername) + ''' and JobName = ''' + rtrim(@save_jobname) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	--  check for more rows
	delete from @SQLjobs where sj_id = @save_sj_id
	If (select count(*) from @SQLjobs) > 0
	   begin
		goto start_sqljobs
	   end


   end


--  Capture Cluster info
If @save_iscluster = 'y'
   begin


	--  Get the cluster name and related info
	delete from #clust_tb11


	insert into #clust_tb11
	select * From dbo.dbaudf_ListClusterResource()
	UNION ALL
	select * From dbo.dbaudf_ListClusterNode()
	UNION ALL
	select * From dbo.dbaudf_ListClusterNetwork()
	UNION ALL
	select * From dbo.dbaudf_ListClusterNetworkInterface()
	--select * from #clust_tb11


	If (select count(*) from #clust_tb11) = 0
	   begin
		goto skip_cluster
	   end


	Select @miscprint = ' '
	Print  @miscprint
	Select @miscprint = '--  Start DBA_ClusterInfo Updates'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_ClusterInfo Updates'''
	Print  @miscprint
	Print  ''


	Select @save_tb11_id = (Select top 1 tb11_id from #clust_tb11)


	SELECT @save_cluster_name = ClusterName
		, @save_ResourceType = ResourceType
		, @save_ResourceName = ResourceName
		, @save_ResourceDetail = ResourceDetail
		, @save_GroupName = GroupName
		, @save_CurrentOwner = CurrentOwner
		, @save_PreferredOwner = PreferredOwner
		, @save_Dependencies = Dependencies
		, @save_RestartAction = RestartAction
		, @save_AutoFailback = AutoFailback
		, @save_State = State
	FROM #clust_tb11
	Where tb11_id = @save_tb11_id


	Select @miscprint = 'Delete from dbo.DBA_ClusterInfo where ClusterName = ''' + @save_cluster_name + ''' and ServerName = ''' + @save_servername + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	start_cluster01:


	-- Create script to insert this row to dbo.DBA_ClusterInfo
	Select @miscprint = 'if not exists (select 1 from dbo.DBA_ClusterInfo where ClusterName = ''' + @save_cluster_name + ''' and ServerName = ''' + @save_servername + ''' and ResourceType = ''' + @save_ResourceType + ''' and ResourceName = ''' + @save_ResourceName + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_ClusterInfo (ClusterName, ServerName, FQDN, ResourceType, ResourceName, modDate) VALUES (''' + @save_cluster_name + ''', ''' + @save_servername + ''', ''' + @save_FQDN + ''', ''' + @save_ResourceType + ''', ''' + @save_ResourceName + ''', ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update dbo.DBA_ClusterInfo set modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,ResourceDetail = ''' + @save_ResourceDetail + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,GroupName = ''' + @save_GroupName + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,CurrentOwner = ''' + @save_CurrentOwner + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,PreferredOwner = ''' + @save_PreferredOwner + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,Dependencies = ''' + @save_Dependencies + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,RestartAction = ''' + @save_RestartAction + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,AutoFailback = ''' + @save_AutoFailback + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,State = ''' + @save_State + ''''
	Print  @miscprint


	Select @miscprint = 'where ClusterName = ''' + @save_cluster_name + ''' and ServerName = ''' + @save_servername + ''' and ResourceType = ''' + @save_ResourceType + ''' and ResourceName = ''' + @save_ResourceName + ''''
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Delete from #clust_tb11 where tb11_id = @save_tb11_id
	If (select count(*) from #clust_tb11) > 0
	   begin
		Select @save_tb11_id = (Select top 1 tb11_id from #clust_tb11)


		SELECT @save_cluster_name = ClusterName
			, @save_ResourceType = ResourceType
			, @save_ResourceName = ResourceName
			, @save_ResourceDetail = ResourceDetail
			, @save_GroupName = GroupName
			, @save_CurrentOwner = CurrentOwner
			, @save_PreferredOwner = PreferredOwner
			, @save_Dependencies = Dependencies
			, @save_RestartAction = RestartAction
			, @save_AutoFailback = AutoFailback
			, @save_State = State
		FROM #clust_tb11
		Where tb11_id = @save_tb11_id


		goto start_cluster01
	   end
   end


skip_cluster:


--  Availability Group Section


If @save_availGrp_flag = 'y'
   begin
	delete from #groups
	insert into #groups select name from master.sys.availability_groups
	delete from #groups where groupname is null


	If (select count(*) from #groups) > 0
	   begin
		Select @miscprint = ' '
		Print  @miscprint


		Select @miscprint = '--  Start DBA_AGInfo Insert'
		Print  @miscprint
		Select @miscprint = 'Print ''Start DBA_AGInfo Insert'''
		Print  @miscprint


		Select @miscprint = 'Delete from dbo.DBA_AGInfo where ModDate < getdate()-60 or ModDate is null'
		Print  @miscprint


		Select @miscprint = 'go'
		Print  @miscprint


		Select @miscprint = ' '
		Print  @miscprint


		raiserror('', -1,-1) with nowait


		start_availGrp:

		Select @save_AGname = (select top 1 groupname from #groups)


		Select @save_AGgroup_id = (select group_id from master.sys.availability_groups where name = @save_AGname)


		Select @save_AGreplica_id = (select replica_id from master.sys.availability_replicas where group_id = @save_AGgroup_id and replica_server_name = @@servername)


		Select @save_AGdns_name = ''


		start_availGrplistener:


		If exists (SELECT 1 FROM master.sys.availability_group_listeners where group_id = @save_AGgroup_id and dns_name > @save_AGdns_name)
		   begin
				SELECT @save_Listener = (select top 1 dns_name FROM master.sys.availability_group_listeners where group_id = @save_AGgroup_id and dns_name > @save_AGdns_name order by dns_name)
				SELECT @save_AGdns_name = @save_Listener


				SELECT @save_Listener_port = convert(sysname, port) FROM master.sys.availability_group_listeners where group_id = @save_AGgroup_id and dns_name = @save_AGdns_name
				SELECT @save_Listener_ip = ip_configuration_string_from_cluster FROM master.sys.availability_group_listeners where group_id = @save_AGgroup_id and dns_name = @save_AGdns_name
				SELECT @save_Listener_ip = replace(@save_Listener_ip, '''', '')
		   end
		Else
		   begin
				SELECT @save_Listener = 'null'
				SELECT @save_Listener_port = 'null'
				SELECT @save_Listener_ip = 'null'
		   end


		Select @save_AGrole = (select role_desc from master.sys.dm_hadr_availability_replica_states where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_AGmode = (select Availability_mode_desc from master.sys.availability_replicas where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_SynchronizationHealth = (select synchronization_health_desc from master.sys.dm_hadr_availability_replica_states where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_FailoverMode = (select Failover_mode_desc from master.sys.availability_replicas where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_PrimaryAllowConnections = (select Primary_role_Allow_Connections_desc from master.sys.availability_replicas where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_SecondaryAllowConnections = (select secondary_role_Allow_Connections_desc from master.sys.availability_replicas where group_id = @save_AGgroup_id and replica_id = @save_AGreplica_id)


		Select @save_BackupPreference = (select automated_backup_preference_desc from master.sys.availability_groups where group_id = @save_AGgroup_id)


		-- Create script to insert this row on the central server table dbo.DBA_AGInfo related for this SQL server
		Select @miscprint = 'if not exists (select 1 from dbo.DBA_AGInfo where AGName = ''' + @save_AGname + ''' and SQLName = ''' + upper(@@servername) + ''' and Listener = ''' + @save_Listener + ''')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      INSERT INTO dbo.DBA_AGInfo (AGName, SQLName, Listener) VALUES (''' + @save_AGname + ''', ''' + upper(@@servername) + ''', ''' + @save_Listener + ''')'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Select @miscprint = 'go'
		Print  @miscprint


		Select @miscprint = ' '
		Print  @miscprint


		raiserror('', -1,-1) with nowait


		Select @miscprint = 'Update top (1) dbo.DBA_AGInfo set Listener_port = ''' + @save_Listener_port + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,Listener_ip = ''' + @save_Listener_ip + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,AGrole = ''' + @save_AGrole + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,AGmode = ''' + @save_AGmode + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,SynchronizationHealth = ''' + @save_SynchronizationHealth + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,FailoverMode = ''' + @save_FailoverMode + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,PrimaryAllowConnections = ''' + @save_PrimaryAllowConnections + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,SecondaryAllowConnections = ''' + @save_SecondaryAllowConnections + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,BackupPreference = ''' + @save_BackupPreference + ''''
		Print  @miscprint


		Select @miscprint = '                                  ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
		Print  @miscprint


		Select @miscprint = 'where AGName = ''' + rtrim(@save_AGname) + ''' and SQLName = ''' + upper(@@servername) + ''' and Listener = ''' + @save_Listener + ''''
		Print  @miscprint


		Select @miscprint = 'go'
		Print  @miscprint


		Select @miscprint = ' '
		Print  @miscprint


		raiserror('', -1,-1) with nowait


		--  Check for more listeners
		If exists (SELECT 1 FROM master.sys.availability_group_listeners where group_id = @save_AGgroup_id and dns_name > @save_AGdns_name)
		   begin
				goto start_availGrplistener
		   end


		--  check for more rows
		delete from #groups where groupname = @save_AGname
		If (select count(*) from #groups) > 0
		   begin
			goto start_availGrp
		   end
	   end
   end


skip_availgrp:


--  IPconfig Section


--  Capture IPconfig Info
delete from #temp_tbl1
Select @cmd = 'ipconfig /all'
insert #temp_tbl1(text01) exec master.sys.xp_cmdshell @cmd
Delete from #temp_tbl1 where text01 is null or text01 = ''
--Select * from #temp_tbl1
Delete from #temp_tbl1 where text01 not like '%Description%' and text01 not like '%Physical Address%'
--Select * from #temp_tbl1


If (select count(*) from #temp_tbl1) > 0
   begin
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start DBA_IPconfigInfo Insert'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_IPconfigInfo Insert'''
	Print  @miscprint


	Select @miscprint = 'Delete from dbo.DBA_IPconfigInfo where ModDate < getdate()-60 or ModDate is null'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @save_Description = 'unknown'


	start_ipconfig01:


	Select @save_id = (select top 1 tb11_id from #temp_tbl1 order by tb11_id)
	--select * from #temp_tbl1 where tb11_id = @save_id


	Select @save_text = (select text01 from #temp_tbl1 where tb11_id = @save_id)
	If @save_text like '%Description%'
	   begin
		Select @charpos = charindex(':', @save_text)
		Select @save_Description = ltrim(substring(@save_text, @charpos+1, 132))
		--Print @save_Description
	   end


	If @save_text like '%Physical Address%'
	   begin
		Select @charpos = charindex(':', @save_text)
		Select @save_Physical_Address = ltrim(substring(@save_text, @charpos+1, 132))
		--Print @save_Physical_Address


		-- Create script to insert this row on the table dbo.DBA_AGInfo related for this SQL server
		Select @miscprint = 'if not exists (select 1 from dbo.DBA_IPconfigInfo where SQLName = ''' + upper(@@servername) + ''' and CONFIGname = ''' + @save_Description + ''')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      INSERT INTO dbo.DBA_IPconfigInfo (SQLName, CONFIGname, modDate) VALUES (''' + upper(@@servername) + ''', ''' + @save_Description + ''', ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Select @miscprint = 'go'
		Print  @miscprint


		raiserror('', -1,-1) with nowait


		Select @miscprint = 'Update top (1) dbo.DBA_IPconfigInfo set CONFIGdetail = ''' + @save_Physical_Address + ''''
		Print  @miscprint


		Select @miscprint = '                                       ,modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
		Print  @miscprint


		Select @miscprint = 'where SQLName = ''' + upper(@@servername) + ''' and CONFIGname = ''' + @save_Description + ''''
		Print  @miscprint


		Select @miscprint = 'go'
		Print  @miscprint


		Select @miscprint = ' '
		Print  @miscprint


		raiserror('', -1,-1) with nowait


		Select @save_Description = 'unknown'
	   end


	Delete from #temp_tbl1 where tb11_id = @save_id
	If (select count(*) from #temp_tbl1) > 0
	   begin
		goto start_ipconfig01
	   end
   end


--  Now we insert or update the central compression_backupinfo table if needed
If @save_compbackup_rg_flag = 'y'
begin
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start Compress_BackupInfo Updates for RedGate'
	Print  @miscprint
	Select @miscprint = 'Print ''Start Compress_BackupInfo Updates for RedGate'''
	Print  @miscprint


	Select @miscprint = 'if not exists (select 1 from dbo.Compress_BackupInfo where servername = ''' + upper(@save_servername) + ''' and SQLname = ''' + upper(@@servername) + ''' and CompType = ''RedGate'')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.Compress_BackupInfo (servername, SQLname, CompType, modDate) VALUES (''' + upper(@save_servername) + ''', ''' + upper(@@servername) + ''', ''RedGate'', ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	SELECT @cmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''' + @miscprint + '''" -E >>' + @outfile_path
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = 'Update dbo.Compress_BackupInfo set modDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,Version = ''' + @save_rg_version + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,VersionType = ''' + @save_rg_versiontype + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,License = ''' + @save_rg_license + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,InstallDate = ''' + convert(nvarchar(30), @save_rg_installdate, 121) + ''''
	Print  @miscprint


	Select @miscprint = 'where servername = ''' + upper(@save_servername) + ''' and SQLname = ''' + upper(@@servername) + ''' and CompType = ''RedGate'''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait
   end


--  Disk performance capture section


Select @cmd = 'del c:\DBA_DiskCheck_DoNotDelete.txt2 /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


--  Check disk speed for master path
select @save_filepath = (select top 1 filename from master.sys.sysfiles order by fileid)
select @save_filepath = reverse(@save_filepath)
Select @charpos = charindex('\', @save_filepath)
IF @charpos <> 0
   begin
	select @save_filepath = substring(@save_filepath, @charpos, 500)
   end


If left(@save_filepath, 1) = '\'
   begin
	select @save_filepath = reverse(@save_filepath)
	Select @save_filepath = left(@save_filepath, len(@save_filepath)-1)
   end
Else
   begin
	select @save_filepath = reverse(@save_filepath)
   end


Select @save_master_path = @save_filepath


Select @cmd = 'robocopy c:\ "' + @save_filepath + '" DBA_DiskCheck_DoNotDelete.txt /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_master_push = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_master_push = 0
   end


Select @cmd = 'ren "' + @save_filepath + '\DBA_DiskCheck_DoNotDelete.txt" DBA_DiskCheck_DoNotDelete.txt2'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'robocopy "' + @save_filepath + '" c:\ DBA_DiskCheck_DoNotDelete.txt2 /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_master_pull = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_master_pull = 0
   end


Select @cmd = 'del "' + @save_filepath + '\DBA_DiskCheck_DoNotDelete.txt2" /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'del c:\DBA_DiskCheck_DoNotDelete.txt2 /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


--  Check disk speed for tempdb path
select @save_filepath = (select top 1 filename from tempdb.sys.sysfiles order by fileid)
select @save_filepath = reverse(@save_filepath)
Select @charpos = charindex('\', @save_filepath)
IF @charpos <> 0
   begin
	select @save_filepath = substring(@save_filepath, @charpos, 500)
   end


If left(@save_filepath, 1) = '\'
   begin
	select @save_filepath = reverse(@save_filepath)
	Select @save_filepath = left(@save_filepath, len(@save_filepath)-1)
   end
Else
   begin
	select @save_filepath = reverse(@save_filepath)
   end


Select @save_tempdb_path = @save_filepath


Select @cmd = 'robocopy c:\ "' + @save_filepath + '" DBA_DiskCheck_DoNotDelete.txt /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_tempdb_push = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_tempdb_push = 0
   end


Select @cmd = 'ren "' + @save_filepath + '\DBA_DiskCheck_DoNotDelete.txt" DBA_DiskCheck_DoNotDelete.txt2'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'robocopy "' + @save_filepath + '" c:\ DBA_DiskCheck_DoNotDelete.txt2 /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_tempdb_pull = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_tempdb_pull = 0
   end


Select @cmd = 'del "' + @save_filepath + '\DBA_DiskCheck_DoNotDelete.txt2" /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'del c:\DBA_DiskCheck_DoNotDelete.txt2 /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


--  Check disk speed for MDF path
Select @save_sharename = @save_servername2 + '_mdf'
exec dbo.dbasp_get_share_path @save_sharename, @outpath output


Select @save_mdf_path = @outpath


Select @cmd = 'robocopy c:\ "' + @save_mdf_path + '" DBA_DiskCheck_DoNotDelete.txt /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_mdf_push = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_mdf_push = 0
   end


Select @cmd = 'ren "' + @save_mdf_path + '\DBA_DiskCheck_DoNotDelete.txt" DBA_DiskCheck_DoNotDelete.txt2'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'robocopy "' + @save_mdf_path + '" c:\ DBA_DiskCheck_DoNotDelete.txt2 /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_mdf_pull = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_mdf_pull = 0
   end


Select @cmd = 'del "' + @save_mdf_path + '\DBA_DiskCheck_DoNotDelete.txt2" /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'del c:\DBA_DiskCheck_DoNotDelete.txt2 /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


--  Check disk speed for LDF path
Select @save_sharename = @save_servername2 + '_ldf'
exec dbo.dbasp_get_share_path @save_sharename, @outpath output


Select @save_ldf_path = @outpath


Select @cmd = 'robocopy c:\ "' + @save_ldf_path + '" DBA_DiskCheck_DoNotDelete.txt /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_ldf_push = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_ldf_push = 0
   end


Select @cmd = 'ren "' + @save_ldf_path + '\DBA_DiskCheck_DoNotDelete.txt" DBA_DiskCheck_DoNotDelete.txt2'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'robocopy "' + @save_ldf_path + '" c:\ DBA_DiskCheck_DoNotDelete.txt2 /NP /Z /R:3'
--Print @cmd


Waitfor delay '00:00:03'
delete from #copystats
Insert into #copystats exec master.sys.xp_cmdshell @cmd
delete from #copystats where copydata is null
delete from #copystats where copydata not like '%Bytes/sec%'
--select * from #copystats


If (select count(*) from #copystats) > 0
   begin
	Select @save_bytes_sec = (select top 1 copydata from #copystats)
	Select @charpos = charindex('Bytes/sec', @save_bytes_sec)
	IF @charpos <> 0
	   begin
		select @save_bytes_sec = substring(@save_bytes_sec, @charpos-21, 20)
		Select @save_bytes_sec = rtrim(ltrim(@save_bytes_sec))
		Select @save_ldf_pull = convert(bigint, @save_bytes_sec)
	   end
   end
Else
   begin
	Select @save_ldf_pull = 0
   end


Select @cmd = 'del "' + @save_ldf_path + '\DBA_DiskCheck_DoNotDelete.txt2" /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'del c:\DBA_DiskCheck_DoNotDelete.txt2 /Q'
--Print @cmd
exec master.sys.xp_cmdshell @cmd, no_output


--  Insert data
If @save_master_path is null
   begin
	Select @save_master_path = 'unknown'
   end


If @save_tempdb_path is null
   begin
	Select @save_tempdb_path = 'unknown'
   end


If @save_mdf_path is null
   begin
	Select @save_mdf_path = 'unknown'
   end


If @save_ldf_path is null
   begin
	Select @save_ldf_path = 'unknown'
   end


Select @miscprint = ' '
Print  @miscprint


Select @miscprint = '--  Start DBA_DiskPerfinfo Insert'
Print  @miscprint
Select @miscprint = 'Print ''Start DBA_DiskPerfinfo Insert'''
Print  @miscprint


Select @miscprint = 'Delete from dbo.DBA_DiskPerfinfo where CreateDate < getdate()-60'
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


Select @miscprint = 'INSERT INTO dbo.DBA_DiskPerfinfo values(''' + @@servername + ''''
Print  @miscprint


Select @miscprint = '                                                ,''' + @save_master_path + ''''
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_master_push)
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_master_pull)
Print  @miscprint


Select @miscprint = '                                                ,''' + @save_mdf_path + ''''
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_mdf_push)
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_mdf_pull)
Print  @miscprint


Select @miscprint = '                                                ,''' + @save_ldf_path + ''''
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_ldf_push)
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_ldf_pull)
Print  @miscprint


Select @miscprint = '                                                ,''' + @save_tempdb_path + ''''
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_tempdb_push)
Print  @miscprint


Select @miscprint = '                                                ,' + convert(nvarchar(30), @save_tempdb_pull)
Print  @miscprint


Select @miscprint = '                                                ,''' + convert(nvarchar(30), @save_moddate, 121) + ''''
Print  @miscprint


Select @miscprint = '                                                )'
Print  @miscprint


Select @miscprint = 'go'
Print  @miscprint


Select @miscprint = ' '
Print  @miscprint


raiserror('', -1,-1) with nowait


--  Capture Control Info and create insert/update script
Select @miscprint = ' '
Print  @miscprint


Select @miscprint = '--  Start DBA_ControlInfo Updates'
Print  @miscprint
Select @miscprint = 'Print ''Start DBA_ControlInfo Inserts'''
Print  @miscprint


raiserror('', -1,-1) with nowait


If exists (select 1 from dbo.no_check)
   begin


	Select @miscprint = ' '
	Print  @miscprint


	Select @save_nocheckid = 0


	start_NoCheck01:


	Select @save_nocheckid = (select top 1 nocheckid from dbo.no_check where nocheckid > @save_nocheckid order by nocheckid)
	Select @save_Control_Subject = (select top 1 NoCheck_type from dbo.no_check where nocheckid = @save_nocheckid)
	Select @save_detail01 = (select top 1 detail01 from dbo.no_check where nocheckid = @save_nocheckid)
	Select @save_detail02 = (select top 1 detail02 from dbo.no_check where nocheckid = @save_nocheckid)
	Select @save_detail03 = (select top 1 detail03 from dbo.no_check where nocheckid = @save_nocheckid)
	Select @save_detail04 = (select top 1 detail04 from dbo.no_check where nocheckid = @save_nocheckid)

	Select @miscprint = 'if not exists (select 1 from dbo.DBA_ControlInfo where SQLName = ''' + upper(@@servername) + ''' and ControlTbl = ''dbo.no_check'' and Subject = ''' + rtrim(@save_Control_Subject) + ''' and detail01 = ''' + isnull(@save_detail01, 'null') + ''' and detail02 = ''' + isnull(@save_detail02, 'null') + ''' and detail03 = ''' + isnull(@save_detail03, 'null') + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_ControlInfo (SQLName, ControlTbl, Subject, detail01, detail02, detail03, detail04, moddate)'
	Print  @miscprint
	Select @miscprint = '                               VALUES (''' + upper(@@servername) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''dbo.no_check'','
	Print  @miscprint
	Select @miscprint = '                                       ''' + rtrim(@save_Control_Subject) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail01, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail02, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail03, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail04, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint

	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'Else'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      Update dbo.DBA_ControlInfo set detail03 = ''' + isnull(@save_detail03, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                     detail04 = ''' + isnull(@save_detail04, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                   moddate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint
	Select @miscprint = '      Where SQLName = ''' + upper(@@servername) + ''' and ControlTbl = ''dbo.no_check'' and Subject = ''' + rtrim(@save_Control_Subject) + ''' and detail01 = ''' + isnull(@save_detail01, 'null') + ''' and detail02 = ''' + isnull(@save_detail02, 'null') + ''''
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	If exists (select 1 from dbo.no_check where nocheckid > @save_nocheckid)
	   begin
		goto start_NoCheck01
	   end
   end


raiserror('', -1,-1) with nowait


If exists (select 1 from dbo.Local_Control)
   begin


	insert into @LocalControl
	SELECT subject, detail01, detail02, detail03 from dbo.Local_Control


	Select @miscprint = ' '
	Print  @miscprint


	start_LocalControl01:


	Select @save_nocheckid = (select top 1 LC_id from @LocalControl)
	Select @save_Control_Subject = (select subject from @LocalControl where LC_id = @save_nocheckid)
	Select @save_detail01 = (select detail01 from @LocalControl where LC_id = @save_nocheckid)
	Select @save_detail02 = (select detail02 from @LocalControl where LC_id = @save_nocheckid)
	Select @save_detail03 = (select detail03 from @LocalControl where LC_id = @save_nocheckid)


	If @save_Control_Subject like 'pw%'
	   begin
		Select @hold_detail01 = 'not printed'
	   end
	Else
	   begin
		Select @hold_detail01 = @save_detail01
	   end


	Select @miscprint = 'if not exists (select 1 from dbo.DBA_ControlInfo where SQLName = ''' + upper(@@servername) + ''' and ControlTbl = ''dbo.Local_Control'' and Subject = ''' + rtrim(@save_Control_Subject) + ''' and detail01 = ''' + isnull(@save_detail01, 'null') + ''' and detail02 = ''' + isnull(@save_detail02, 'null') + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_ControlInfo (SQLName, ControlTbl, Subject, detail01, detail02, detail03, moddate)'
	Print  @miscprint
	Select @miscprint = '                              VALUES (''' + upper(@@servername) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''dbo.Local_Control'','
	Print  @miscprint
	Select @miscprint = '               ''' + rtrim(@save_Control_Subject) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@hold_detail01, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail02, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + isnull(@save_detail03, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint

	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'Else'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      Update dbo.DBA_ControlInfo set detail03 = ''' + isnull(@save_detail03, 'null') + ''','
	Print  @miscprint
	Select @miscprint = '                                     moddate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint
	Select @miscprint = '      Where SQLName = ''' + upper(@@servername) + ''' and ControlTbl = ''dbo.Local_Control'' and Subject = ''' + rtrim(@save_Control_Subject) + ''' and detail01 = ''' + isnull(@hold_detail01, 'null') + ''' and detail02 = ''' + isnull(@save_detail02, 'null') + ''''
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Delete from @LocalControl where LC_id = @save_nocheckid
	If exists (select 1 from @LocalControl)
	   begin
		goto start_LocalControl01
	   end
   end


raiserror('', -1,-1) with nowait


--  Capture Connection Info and create insert/update script
Select @miscprint = ' '
Print  @miscprint


Select @miscprint = '--  Start DBA_ConnectionInfo Updates'
Print  @miscprint
Select @miscprint = 'Print ''Start DBA_ConnectionInfo Inserts'''
Print  @miscprint


raiserror('', -1,-1) with nowait


If exists (select 1 from DBAperf.dbo.DBconnections where moddate > @save_moddate-2)
   begin


	Select @miscprint = ' '
	Print  @miscprint


	--  Load temp table
	Delete from @DBconnections

	Insert into @DBconnections
	select DBname, LoginName, HostName, max(moddate)
	from dbaperf.dbo.DBconnections with (nolock)
	where moddate > @save_moddate-2
	group by DBname, LoginName, HostName


	start_DBconnections01:


	Select @save_DBc_id = (select top 1 DBc_id from @DBconnections)


	Select @save_DBname = DBname, @save_LoginName = LoginName, @save_HostName = HostName, @save_moddate = moddate
	From @DBconnections
	where DBc_id = @save_DBc_id


	If @save_LoginName = '' or @save_LoginName is null
	   begin
		goto skip_connection01
	   end


	If @save_HostName = '' or @save_HostName is null
	   begin
		goto skip_connection01
	   end


	Select @miscprint = 'if not exists (select 1 from dbo.DBA_ConnectionInfo where SQLName = ''' + upper(@@servername) + ''' and DBName = ''' + @save_DBname + ''' and LoginName = ''' + rtrim(@save_LoginName) + ''' and HostName = ''' + rtrim(@save_HostName) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_ConnectionInfo (SQLName, DBname, LoginName, HostName, moddate)'
	Print  @miscprint
	Select @miscprint = '                               VALUES (''' + upper(@@servername) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + rtrim(@save_DBname) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + rtrim(@save_LoginName) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + rtrim(@save_HostName) + ''','
	Print  @miscprint
	Select @miscprint = '                                       ''' + convert(nvarchar(30), @save_moddate, 121) + ''')'
	Print  @miscprint

	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'Else'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      Update dbo.DBA_ConnectionInfo set moddate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint
	Select @miscprint = '      where SQLName = ''' + upper(@@servername) + ''' and DBName = ''' + @save_DBname + ''' and LoginName = ''' + rtrim(@save_LoginName) + ''' and HostName = ''' + rtrim(@save_HostName) + ''''
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	skip_connection01:


	Delete from @DBconnections where DBc_id = @save_DBc_id
	If (Select count(*) from @DBconnections) > 0
	   begin
		goto start_DBconnections01
	   end
   end


raiserror('', -1,-1) with nowait


--  Capture Linked Server Info and create insert/update script
delete from #lkservers


INSERT INTO #lkservers
SELECT s.srvname, s.srvid, s.srvproduct, s.providername, s.datasource, s.location, s.providerstring,
		s.catalog, s.connecttimeout, s.querytimeout, s.rpc, s.pub, s.sub, s.dist, s.rpcout,
		s.dataaccess, s.collationcompatible, s.useremotecollation, s.lazyschemavalidation, s.collation
   From master.sys.sysservers   s
Where s.srvid > 0
     and s.isremote = 0


If (select count(*) from #lkservers) > 0
   begin


	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '--  Start DBA_LinkedServerInfo Updates'
	Print  @miscprint
	Select @miscprint = 'Print ''Start DBA_LinkedServerInfo Updates'''
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	start_LKservers:


	Select @save_LKname = (select top 1 LKname from #LKservers order by LKname)

	Select	@save_LKserver_id = LKserver_id
		,@save_LKsrvproduct = LKsrvproduct
		,@save_LKprovidername = LKprovidername
		,@save_LKdatasource = LKdatasource
		,@save_LKlocation = LKlocation
		,@save_LKproviderstring = LKproviderstring
		,@save_LKcatalog = LKcatalog
		,@save_LKconnecttimeout = LKconnecttimeout
		,@save_LKquerytimeout = LKquerytimeout
		,@save_LKrpc = LKrpc
		,@save_LKpub = LKpub
		,@save_LKsub = LKsub
		,@save_LKdist = LKdist
		,@save_LKrpcout = LKrpcout
		,@save_LKdataaccess = LKdataaccess
		,@save_LKcollationcompatible = LKcollationcompatible
		,@save_LKuseremotecollation = LKuseremotecollation
		,@save_LKlazyschemavalidation = LKlazyschemavalidation
		,@save_LKcollation = LKcollation
	from	#LKservers
	where	LKname = @save_LKname

	Select @miscprint = 'if not exists (select 1 from dbo.DBA_LinkedServerInfo where SQLName = ''' + upper(@@servername) + ''' and LKname = ''' + rtrim(@save_LKname) + ''')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      INSERT INTO dbo.DBA_LinkedServerInfo (SQLName, LKname, LKserver_id) VALUES (''' + upper(@@servername) + ''', ''' + @save_LKname + ''', ' + convert(varchar(20), @save_LKserver_id) + ')'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	Select @miscprint = 'Update top (1) dbo.DBA_LinkedServerInfo set LKserver_id = ' + convert(varchar(10), @save_LKserver_id)
	Print  @miscprint


	Select @miscprint = '                                      ,LKsrvproduct = ''' + rtrim(@save_LKsrvproduct) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKprovidername = ''' + rtrim(@save_LKprovidername) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKdatasource = ''' + rtrim(@save_LKdatasource) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKlocation = ''' + rtrim(@save_LKlocation) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKproviderstring = ''' + rtrim(@save_LKproviderstring) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKcatalog = ''' + rtrim(@save_LKcatalog) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKconnecttimeout = ' + convert(varchar(20), @save_LKconnecttimeout)
	Print  @miscprint


	Select @miscprint = '                                      ,LKquerytimeout = ' + convert(varchar(20), @save_LKquerytimeout)
	Print  @miscprint


	Select @miscprint = '                                      ,LKrpc = ' + convert(varchar(10), @save_LKrpc)
	Print  @miscprint


	Select @miscprint = '                                      ,LKpub = ' + convert(varchar(10), @save_LKpub)
	Print  @miscprint


	Select @miscprint = '                                      ,LKsub = ' + convert(varchar(10), @save_LKsub)
	Print  @miscprint


	Select @miscprint = '                                      ,LKdist = ' + convert(varchar(10), @save_LKdist)
	Print  @miscprint


	Select @miscprint = '                                      ,LKrpcout = ' + convert(varchar(10), @save_LKrpcout)
	Print  @miscprint


	Select @miscprint = '                                      ,LKdataaccess = ' + convert(varchar(10), @save_LKdataaccess)
	Print  @miscprint


	Select @miscprint = '                                      ,LKcollationcompatible = ' + convert(varchar(10), @save_LKcollationcompatible)
	Print  @miscprint


	Select @miscprint = '                                      ,LKuseremotecollation = ' + convert(varchar(10), @save_LKuseremotecollation)
	Print  @miscprint


	Select @miscprint = '                                      ,LKlazyschemavalidation = ' + convert(varchar(10), @save_LKlazyschemavalidation)
	Print  @miscprint


	Select @miscprint = '                                      ,LKcollation = ''' + rtrim(@save_LKcollation) + ''''
	Print  @miscprint


	Select @miscprint = '                                      ,LKmodDate = ''' + convert(nvarchar(30), @save_moddate, 121) + ''''
	Print  @miscprint


	Select @miscprint = 'where '
	Print  @miscprint


	Select @miscprint = 'SQLName = ''' + upper(@@servername) + ''' and LKname = ''' + rtrim(@save_LKname) + ''''
	Print  @miscprint


	Select @miscprint = 'go'
	Print  @miscprint


	Select @miscprint = ' '
	Print  @miscprint


	raiserror('', -1,-1) with nowait


	delete from #LKservers where LKname = @save_LKname
	If (select count(*) from #LKservers) > 0
	   begin
		goto start_LKservers
	   end


	Select @miscprint = ' '
	Print  @miscprint


   end


--  End of process marker
Select @miscprint = ' '
Print  @miscprint
Select @miscprint = '-- End of dbasp_Self_Register_Report'
Print  @miscprint
Select @miscprint = ' '
Print  @miscprint


---------------------------  Finalization  -----------------------
label99:


drop table #clust_tb11
drop table #groups
drop table #config
drop TABLE #temp_tbl1
drop TABLE #temp_tbl2
drop table #regresults
drop table #fileexists
drop table #copystats
drop table #drives
drop TABLE #SqbOutput
drop TABLE #RegValues
drop Table #DBextra
drop table #LKservers
drop TABLE #VLFInfo
drop TABLE #Keys
GO
GRANT EXECUTE ON  [dbo].[dbasp_Self_Register_Report] TO [public]
GO
