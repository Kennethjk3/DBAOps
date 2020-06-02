SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_REPORT_SQLhealth] (@rpt_recipient sysname = 'DBANotify@${{secrets.DOMAIN_NAME}}'
						,@checkin_grace_hours smallint = 32
						,@recycle_grace_days smallint = 120
						,@reboot_grace_days smallint = 120
						,@userDB_size_cutoff_MB int = 25000
						,@save_SQLEnv sysname = '')


/*********************************************************
 **  Stored Procedure dbasp_REPORT_SQLhealth
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 14, 2007
 **
 **  This dbasp is set up to monitor SQL health by reviewing the
 **  central util_server table.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/14/2007	Steve Ledridge		New report
--	08/22/2008	Steve Ledridge		Convertion to new dba_*info tables
--	08/27/2008	Steve Ledridge		New input parm @save_sqlenv
--	12/17/2008	Steve Ledridge		Added 'default' as valid backup type
--	03/25/2009	Steve Ledridge		New section to check for compression backup software trial versions.
--	03/26/2009	Steve Ledridge		Fixed bug with printing wrong memory setting for x64 servers.
--	05/13/2009	Steve Ledridge		Added clusterinfo check processing.
--	07/10/2009	Steve Ledridge		Added mom verify check.
--	03/12/2010	Steve Ledridge		Added support for active = 'm'.
--	03/17/2010	Steve Ledridge		Changed pagefile_size to pagefile_inuse.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	09/30/2014	Steve Ledridge		Changed iscluster to Cluster.
--	10/29/2014	Steve Ledridge		Removed mom verify check.
--	05/20/2015	Steve Ledridge		Changed Cluster to ClusterName.
--	======================================================================================


/*
declare @rpt_recipient sysname
declare @checkin_grace_hours smallint
declare @recycle_grace_days smallint
declare @reboot_grace_days smallint
declare @userDB_size_cutoff_MB int
declare @save_SQLEnv sysname


select @rpt_recipient = 'DBANotify@${{secrets.DOMAIN_NAME}}'
Select @checkin_grace_hours = 32
select @recycle_grace_days = 120
select @reboot_grace_days = 120
select @userDB_size_cutoff_MB = 25000
Select @save_SQLEnv = 'production'
--*/


-----------------  declares  ------------------
Declare
	 @miscprint			nvarchar(255)
	,@cmd				nvarchar(4000)
	,@charpos			int
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_sqlservername		sysname
	,@save_sqlservername2		sysname
	,@save_SQLmax_memory_all	bigint
	,@save_moddate			datetime
	,@date_control			datetime
	,@save_SQLrecycle_date		datetime
	,@save_OSuptime			sysname
	,@save_reboot_days		nvarchar(10)
	,@save_DBAOps_Version		sysname
	,@save_size_of_userDBs_MB	int
	,@save_litespeed		sysname
	,@save_RedGate			sysname
	,@save_backuptype		sysname
	,@save_SQLmax_memory		nvarchar(20)
	,@save_Memory			sysname
	,@save_awe			nchar(1)
	,@save_boot_pae			nchar(1)
	,@save_boot_3gb			nchar(1)
	,@save_boot_userva		nchar(1)
	,@version_control		sysname
	,@rpt_flag			char(1)
	,@first_flag			char(1)
	,@subject			nvarchar(255)
	,@message			nvarchar(4000)
	,@out_filename			sysname
	,@save_domain			sysname
	,@save_Name2			sysname


----------------  initial values  -------------------
Select @subject = 'SQL Health Check from [' + upper(@@servername) + '] on ' + convert(nvarchar(19), getdate(), 121)
Select @message = ''
Select @rpt_flag = 'n'


--  Set servername variables
Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain = (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain')


--  Create the output file
Select @out_filename = '\\' + @save_servername + '\DBASQL\dba_reports\SQLhealth_report_' + @save_servername2 + '.txt'
Print  ' '
Select @cmd = 'copy nul ' + @out_filename
EXEC master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'echo ' + @subject + '>>' + @out_filename
EXEC master.sys.xp_cmdshell @cmd, no_output


Select @message = '.'
Select @cmd = 'echo' + @message + '>>' + @out_filename
EXEC master.sys.xp_cmdshell @cmd, no_output


--  create the temp table
declare @tblv_DBA_Serverinfo table (SQLServerName sysname
			    ,SQLServerENV sysname
			    ,Active char(1)
			    ,modDate datetime
			    ,SQL_Version nvarchar (500) null
			    ,DBAOps_Version sysname null
			    ,backup_type sysname null
			    ,LiteSpeed sysname null
			    ,RedGate sysname NULL
			    ,DomainName sysname NULL
			    ,SQLrecycle_date sysname NULL
			    ,awe_enabled char(1) NULL
			    ,MAXdop_value nvarchar(5) NULL
			    ,SQLmax_memory nvarchar(20) NULL
			    ,tempdb_filecount nvarchar(10) NULL
			    ,Cluster sysname NULL
			    ,Port nvarchar(10) NULL
			    ,IPnum sysname NULL
			    ,CPUcore sysname NULL
			    ,CPUtype sysname NULL
			    ,Memory sysname NULL
			    ,OSname sysname NULL
			    ,OSver sysname NULL
			    ,OSuptime sysname NULL
			    ,boot_3gb char(1) NULL
			    ,boot_pae char(1) NULL
			    ,boot_userva char(1) NULL
			    ,Pagefile_inuse sysname NULL
			    ,SystemModel sysname NULL
			    )


declare @tblv_moddate table (SQLServerName sysname
			    ,modDate datetime
			    )


declare @tblv_recycle table (SQLServerName sysname
			    ,SQLrecycle_date sysname NULL
			    )


declare @tblv_reboot table (SQLServerName sysname
			    ,OSuptime sysname NULL
			    )


declare @tblv_version table (SQLServerName sysname
			    ,DBAOps_Version sysname null
			    )


declare @tblv_backup_usage table (SQLServerName sysname
			    ,size_of_userDBs_MB int null
			    )


declare @tblv_std_backup_check table (SQLServerName sysname
			    ,LiteSpeed char(1) null
			    ,RedGate char(1) NULL
			    )


declare @tblv_cmp_backup_check table (SQLServerName sysname
			    ,backup_type sysname null
			    ,LiteSpeed char(1) null
			    ,RedGate char(1) NULL
			    )


declare @tblv_memory table (SQLServerName sysname
			    ,awe_enabled char(1) NULL
			    ,SQLmax_memory nvarchar(20) NULL
			    ,Memory sysname NULL
			    ,boot_3gb char(1) NULL
			    ,boot_pae char(1) NULL
			    ,boot_userva char(1) NULL
			    )


declare @tblv_cluster table (SQLServerName sysname
			    ,Name2 sysname NULL
			    )


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Load data into temp table
delete from @tblv_DBA_Serverinfo
insert into @tblv_DBA_Serverinfo (SQLServerName
			    ,SQLServerENV
			    ,Active
			    ,modDate
			    ,SQL_Version
			    ,DBAOps_Version
			    ,backup_type
			    ,LiteSpeed
			    ,RedGate
			    ,DomainName
			    ,SQLrecycle_date
			    ,awe_enabled
			    ,MAXdop_value
			    ,SQLmax_memory
			    ,tempdb_filecount
			    ,Cluster
			    ,Port
			    ,IPnum
			    ,CPUcore
			    ,CPUtype
			    ,Memory
			    ,OSname
			    ,OSver
			    ,OSuptime
			    ,boot_3gb
			    ,boot_pae
			    ,boot_userva
			    ,Pagefile_inuse
			    ,SystemModel)
select SQLName
	,SQLEnv
	,Active
	,modDate
	,SQLver
	,DBAOps_Version
	,backup_type
	,LiteSpeed
	,RedGate
	,DomainName
	,SQLrecycleDate
	,awe_enabled
	,MAXdop_value
	,SQLmax_memory
	,tempdb_filecount
	,ClusterName
	,Port
	,IPnum
	,CPUcore
	,CPUtype
	,Memory
	,OSname
	,OSver
	,OSuptime
	,boot_3gb
	,boot_pae
	,boot_userva
	,Pagefile_inuse
	,SystemModel
From dbo.DBA_Serverinfo
Where DomainName = @save_domain
 and  SQLEnv like '%' + @save_SQLEnv + '%'


delete from @tblv_DBA_Serverinfo where SQL_Version like '%7.00%'
delete from @tblv_DBA_Serverinfo where active = 'n'


--Select * from @tblv_DBA_Serverinfo


--  MAINT MODE Check mod date (looking for servers that have stopped checking in)
Select @date_control = dateadd(hour, -336, getdate())


delete from @tblv_moddate
insert into @tblv_moddate (SQLServerName, modDate)
select SQLServerName, modDate
From @tblv_DBA_Serverinfo
where modDate < @date_control
and active = 'm'


If (select count(*) from @tblv_moddate) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) in Maintenance Mode have not checked into [' + @@servername + '] within the past ' + convert(nvarchar(5), @checkin_grace_hours) + ' hours.'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_moddate:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_moddate order by SQLServerName)
	select @save_moddate = (select moddate from @tblv_moddate where sqlservername = @save_sqlservername)


	Select @message = convert(char(30), @save_sqlservername) + convert(nvarchar(30), @save_moddate, 121)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_moddate where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_moddate) > 0
	   begin
		goto start_moddate
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check mod date (looking for servers that have stopped checking in)
Select @date_control = dateadd(hour, -@checkin_grace_hours, getdate())


delete from @tblv_moddate
insert into @tblv_moddate (SQLServerName, modDate)
select SQLServerName, modDate
From @tblv_DBA_Serverinfo
where modDate < @date_control
and active = 'y'


If (select count(*) from @tblv_moddate) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) have not checked into [' + @@servername + '] within the past ' + convert(nvarchar(5), @checkin_grace_hours) + ' hours.'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_moddate2:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_moddate order by SQLServerName)
	select @save_moddate = (select moddate from @tblv_moddate where sqlservername = @save_sqlservername)


	Select @message = convert(char(30), @save_sqlservername) + convert(nvarchar(30), @save_moddate, 121)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_moddate where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_moddate) > 0
	   begin
		goto start_moddate2
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check last sql recycle date
Select @date_control = dateadd(day, -@recycle_grace_days, getdate())


delete from @tblv_recycle
insert into @tblv_recycle (SQLServerName, SQLrecycle_date)
select SQLServerName, SQLrecycle_date
From @tblv_DBA_Serverinfo
where SQLrecycle_date < @date_control
  and Active = 'y'


If (select count(*) from @tblv_recycle) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) have not been recycled in the past ' + convert(nvarchar(10), @recycle_grace_days) + ' day(s).'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_recycle:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_recycle order by SQLServerName)
	select @save_SQLrecycle_date = (select SQLrecycle_date from @tblv_recycle where sqlservername = @save_sqlservername)


	Select @message = convert(char(30), @save_sqlservername) + convert(nvarchar(30), @save_SQLrecycle_date, 121)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_recycle where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_recycle) > 0
	   begin
		goto start_recycle
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check last OS Reboot date
delete from @tblv_reboot
insert into @tblv_reboot (SQLServerName, OSuptime)
select SQLServerName, OSuptime
From @tblv_DBA_Serverinfo
where OSuptime is not null
  and Active = 'y'


If (select count(*) from @tblv_reboot) > 0
   begin
	Select @save_sqlservername = ''
	start_reboot01:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_reboot where sqlservername > @save_sqlservername order by SQLServerName)
	select @save_OSuptime = (select OSuptime from @tblv_reboot where sqlservername = @save_sqlservername)


	Select @charpos = charindex(' Day', @save_OSuptime)
	IF @charpos <> 0
	   begin
		select @save_reboot_days = left(@save_OSuptime, @charpos-1)
		If convert(int, @save_reboot_days) < @reboot_grace_days
		   begin
			delete from @tblv_reboot where sqlservername = @save_sqlservername
		   end
	   end


	If (select count(*) from @tblv_reboot where sqlservername > @save_sqlservername) > 0
	   begin
		goto start_reboot01
	   end
   end


If (select count(*) from @tblv_reboot) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) have not been rebooted in the past ' + convert(nvarchar(10), @reboot_grace_days) + ' day(s).'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_reboot02:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_reboot order by SQLServerName)
	select @save_OSuptime = (select OSuptime from @tblv_reboot where sqlservername = @save_sqlservername)


	Select @message = convert(char(30), @save_sqlservername) + convert(nvarchar(30), @save_OSuptime)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_reboot where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_reboot) > 0
	   begin
		goto start_reboot02
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for old DBAOps version
Select @version_control = (select top 1 vchLabel from DBAOps.dbo.build where vchname = 'DBAOps' order by iBuildID desc)


delete from @tblv_version
insert into @tblv_version (SQLServerName, DBAOps_Version)
select SQLServerName, DBAOps_Version
From @tblv_DBA_Serverinfo
where DBAOps_Version <> rtrim(@version_control)
  and Active = 'y'


Delete from @tblv_DBA_Serverinfo where DBAOps_Version is null


If (select count(*) from @tblv_version) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) do not have the latest version of DBAOps; [' + @version_control + '].'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_version:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_version order by SQLServerName)
	select @save_DBAOps_Version = (select DBAOps_Version from @tblv_version where sqlservername = @save_sqlservername)


	Select @message = convert(char(30), @save_sqlservername) + @save_DBAOps_Version
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_version where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_version) > 0
	   begin
		goto start_version
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for Litspeed or Redgate usage
delete from @tblv_backup_usage
insert into @tblv_backup_usage (SQLServerName)
select SQLServerName
From @tblv_DBA_Serverinfo
where SQLServerENV = @save_SQLEnv
  and backup_type in ('standard', 'default')
  and Active = 'y'


set @first_flag = 'y'


If (select count(*) from @tblv_backup_usage) > 0
   begin
	start_comp_backup01:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_backup_usage)
	Select @save_size_of_userDBs_MB = (select sum(convert(float, data_size_MB) + convert(float, log_size_MB)) from dbo.dba_dbinfo where SQLname = @save_sqlservername)

	If @save_size_of_userDBs_MB > @userDB_size_cutoff_MB
	   begin
		Select @rpt_flag = 'y'


		If @first_flag = 'y'
		   begin
			Select @first_flag = 'n'
			Select @message = 'The following SQL server(s) should be using Litespeed or RedGate for backup processing (DB size issues).'
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end


		Select @message = convert(char(30), @save_sqlservername) + convert(nvarchar(30), @save_size_of_userDBs_MB)
		Select @cmd = 'echo ' + @message + '>>' + @out_filename
		EXEC master.sys.xp_cmdshell @cmd, no_output


	   end


	Delete from @tblv_backup_usage where SQLServerName = @save_sqlservername
	If (select count(*) from @tblv_backup_usage) > 0
	   begin
		goto start_comp_backup01
	   end


	If @first_flag = 'n'
	   begin
		Select @message = '.'
		Select @cmd = 'echo' + @message + '>>' + @out_filename
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @message = '.'
		Select @cmd = 'echo' + @message + '>>' + @out_filename
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end
   end


--  Check for unused compression backup types
delete from @tblv_std_backup_check
insert into @tblv_std_backup_check (SQLServerName, litespeed, RedGate)
select SQLServerName, litespeed, RedGate
From @tblv_DBA_Serverinfo
where backup_type in ('standard', 'default')
  and SQLServerENV = @save_SQLEnv
  and (LiteSpeed = 'y' or RedGate = 'y')
  and Active = 'y'


If (select count(*) from @tblv_std_backup_check) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) should be using Litespeed or RedGate for backup processing (software is installed).'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_std_backup_check:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_std_backup_check order by SQLServerName)
	select @save_litespeed = (select LiteSpeed from @tblv_std_backup_check where sqlservername = @save_sqlservername)
	select @save_litespeed = 'LiteSpeed: ' + @save_litespeed
	select @save_RedGate = (select RedGate from @tblv_std_backup_check where sqlservername = @save_sqlservername)
	select @save_RedGate = 'RedGate: ' + @save_RedGate


	Select @message = convert(nchar(30), @save_sqlservername) + convert(nchar(25), @save_RedGate) + convert(nvarchar(25), @save_litespeed)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_std_backup_check where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_std_backup_check) > 0
	   begin
		goto start_std_backup_check
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for compression backup types with software not installed
delete from @tblv_cmp_backup_check
insert into @tblv_cmp_backup_check (SQLServerName, backup_type, LiteSpeed, RedGate)
select SQLServerName, backup_type, LiteSpeed, RedGate
From @tblv_DBA_Serverinfo
where backup_type not in ('standard', 'default')
  and SQLServerENV = @save_SQLEnv
  and Active = 'y'


Delete from @tblv_cmp_backup_check where backup_type is null
Delete from @tblv_cmp_backup_check where backup_type = 'LiteSpeed' and LiteSpeed = 'y'
Delete from @tblv_cmp_backup_check where backup_type = 'RedGate' and RedGate = 'y'
If (select count(*) from @tblv_cmp_backup_check) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) are set up to use backup compression software that is not installed.'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_cmp_backup_check:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cmp_backup_check order by SQLServerName)
	select @save_backuptype = (select backup_type from @tblv_cmp_backup_check where sqlservername = @save_sqlservername)
	select @save_backuptype = 'Backup Type: ' + @save_backuptype
	select @save_litespeed = (select LiteSpeed from @tblv_cmp_backup_check where sqlservername = @save_sqlservername)
	select @save_litespeed = 'LiteSpeed: ' + @save_litespeed
	select @save_RedGate = (select RedGate from @tblv_cmp_backup_check where sqlservername = @save_sqlservername)
	select @save_RedGate = 'RedGate: ' + @save_RedGate


	Select @message = convert(nchar(30), @save_sqlservername) + convert(nchar(30), @save_backuptype) + convert(nchar(25), @save_RedGate) + convert(nvarchar(25), @save_litespeed)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_cmp_backup_check where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_cmp_backup_check) > 0
	   begin
		goto start_cmp_backup_check
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for compression backup types in Trail version mode
delete from @tblv_cmp_backup_check
insert into @tblv_cmp_backup_check (SQLServerName, backup_type, LiteSpeed, RedGate)
select s.SQLName, s.backup_type, s.LiteSpeed, s.RedGate
From dbo.DBA_Serverinfo s, dbo.Compress_BackupInfo cb
where (s.redgate = 'y' or s.LiteSpeed = 'y')
  and s.SQLENV = @save_SQLEnv
  and s.Active = 'y'
  and s.SQLName = cb.SQLname
  and cb.versiontype like '%trial%'


Delete from @tblv_cmp_backup_check where backup_type is null
If (select count(*) from @tblv_cmp_backup_check) > 0
   begin
	Select @rpt_flag = 'y'


	Select @message = 'The following SQL server(s) are using a trial version of backup compression software.'
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	start_cmp_trial_check:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cmp_backup_check order by SQLServerName)


	Select @message = convert(nchar(30), @save_sqlservername)
	Select @cmd = 'echo ' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	delete from @tblv_cmp_backup_check where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_cmp_backup_check) > 0
	   begin
		goto start_cmp_trial_check
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory issues - limit settings
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where Active = 'y'


Delete from @tblv_memory where SQLmax_memory is null or SQLmax_memory = 'error'
Delete from @tblv_memory where Memory is null or Memory = 'error'


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory01:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	select @save_SQLmax_memory = (select SQLmax_memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) < convert(int, @save_SQLmax_memory)
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) memory limit setting is greater than the available memory on the server.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' Limit Set: ' + convert(nchar(25), @save_SQLmax_memory)
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory01
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory issues - limit settings for all instances greater than memory installed
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where Active = 'y'


Delete from @tblv_memory where SQLmax_memory is null or SQLmax_memory = 'error' or SQLmax_memory = 'Unknown' or SQLmax_memory = ''
Delete from @tblv_memory where Memory is null or Memory = 'error'
--select * from @tblv_DBA_Serverinfo


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory02:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_sqlservername2 = @save_sqlservername
	Select @charpos = charindex('\', @save_sqlservername2)
	IF @charpos <> 0
	   begin
		select @save_sqlservername2 = left(@save_sqlservername2, @charpos-1)
	   end


	Select @save_SQLmax_memory_all = (select sum(convert(bigint, SQLmax_memory)) from @tblv_DBA_Serverinfo where SQLServerName like @save_sqlservername2 + '%' and Active = 'y')


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) < @save_SQLmax_memory_all
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) (all instances) memory limit setting is greater than the available memory on the server.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' Total Limit(s) Set: ' + convert(nchar(25), @save_SQLmax_memory_all)
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername like @save_sqlservername2 + '%'
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory02
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory issues - limit settings plus 4GB for all instances less than memory installed
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where Active = 'y'


Delete from @tblv_memory where SQLmax_memory is null or SQLmax_memory = 'error' or SQLmax_memory = 'Unknown' or SQLmax_memory = ''
Delete from @tblv_memory where Memory is null or Memory = 'error'


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory03:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_sqlservername2 = @save_sqlservername
	Select @charpos = charindex('\', @save_sqlservername2)
	IF @charpos <> 0
	   begin
		select @save_sqlservername2 = left(@save_sqlservername2, @charpos-1)
	   end


	Select @save_SQLmax_memory_all = (select sum(convert(bigint, SQLmax_memory)) from @tblv_DBA_Serverinfo where SQLServerName like @save_sqlservername2 + '%' and Active = 'y')


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) > @save_SQLmax_memory_all + 4096
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) (all instances) memory limit settings are not high enough related to the available memory on the server.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' Total Limit(s) Set: ' + convert(nchar(25), @save_SQLmax_memory_all)
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername like @save_sqlservername2 + '%'
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory03
	 end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory settings - for 64 bit servers
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where sql_version like '%X64%'
  and Active = 'y'


Delete from @tblv_memory where Memory is null or Memory = 'error' or Memory = 'Unknown' or Memory = ''


select * from @tblv_memory


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory04:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_awe = (select awe_enabled from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_pae = (select boot_pae from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_3gb = (select boot_3gb from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_userva = (select boot_userva from @tblv_memory where SQLServerName = @save_sqlservername)


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	If @save_awe = 'y' or @save_boot_pae = 'y' or @save_boot_3gb = 'y' or @save_boot_userva = 'y'
	   begin
		If @first_flag = 'y'
		   begin
			Select @rpt_flag = 'y'
			Select @first_flag = 'n'


			Select @message = 'The following 64 bit SQL server(s) should have these memory related settings all set to ''n''.'
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end


		Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' AWE: ''' + @save_awe + '''   PAE: ''' + @save_boot_pae +  '''   3GB: ''' + @save_boot_3gb +  '''   UserVA: ''' + @save_boot_userva + ''''
		Select @cmd = 'echo ' + @message + '>>' + @out_filename
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory04
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory 3GB and userva settings when memory is low - for 32 bit servers
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where sql_version not like '%X64%'
  and Active = 'y'


Delete from @tblv_memory where Memory is null or Memory = 'error' or Memory = 'Unknown' or Memory = ''


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory05:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_awe = (select awe_enabled from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_pae = (select boot_pae from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_3gb = (select boot_3gb from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_userva = (select boot_userva from @tblv_memory where SQLServerName = @save_sqlservername)


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If (convert(int, @save_Memory) < 3500 and @save_boot_3gb = 'y') or
		   (convert(int, @save_Memory) < 3000 and @save_boot_userva = 'y')
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) have incorrect settings related to the boot.ini 3gb or userva parms.  They should not be set.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + '  3GB: ''' + @save_boot_3gb +  '''   UserVA: ''' + @save_boot_userva + ''''
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory05
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory 3GB and userva settings when memory is high - for 32 bit servers
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where sql_version not like '%X64%'
  and Active = 'y'


Delete from @tblv_memory where Memory is null or Memory = 'error' or Memory = 'Unknown' or Memory = ''


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory06:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_awe = (select awe_enabled from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_pae = (select boot_pae from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_3gb = (select boot_3gb from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_userva = (select boot_userva from @tblv_memory where SQLServerName = @save_sqlservername)


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) > 16000 and (@save_boot_3gb = 'y' or @save_boot_userva = 'y')
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) have incorrect settings related to the boot.ini 3gb or userva parms.  They should not be set.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' 3GB: ''' + @save_boot_3gb +  '''   UserVA: ''' + @save_boot_userva + ''''
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory06
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory AWE and PAE settings when memory is low - for 32 bit servers
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where sql_version not like '%X64%'
  and Active = 'y'


Delete from @tblv_memory where Memory is null or Memory = 'error' or Memory = 'Unknown' or Memory = ''


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory07:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_awe = (select awe_enabled from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_pae = (select boot_pae from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_3gb = (select boot_3gb from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_userva = (select boot_userva from @tblv_memory where SQLServerName = @save_sqlservername)


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) < 4100 and (@save_awe = 'y' or @save_boot_pae = 'y')
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) have incorrect settings related to the boot.ini pae or SQL awe parms.  They should both be set to ''n''.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' AWE: ''' + @save_awe +  '''   PAE: ''' + @save_boot_pae + ''''
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory07
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check for memory AWE and PAE settings when memory is high - for 32 bit servers
delete from @tblv_memory
insert into @tblv_memory (SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva)
select SQLServerName, awe_enabled, SQLmax_memory, Memory, boot_3gb, boot_pae, boot_userva
From @tblv_DBA_Serverinfo
where sql_version not like '%X64%'
  and Active = 'y'


Delete from @tblv_memory where Memory is null or Memory = 'error' or Memory = 'Unknown' or Memory = ''


If (select count(*) from @tblv_memory) > 0
   begin
	Select @first_flag = 'y'
	start_memory08:
	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_memory order by SQLServerName)
	Select @save_awe = (select awe_enabled from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_pae = (select boot_pae from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_3gb = (select boot_3gb from @tblv_memory where SQLServerName = @save_sqlservername)
	Select @save_boot_userva = (select boot_userva from @tblv_memory where SQLServerName = @save_sqlservername)


	select @save_Memory = (select Memory from @tblv_memory where sqlservername = @save_sqlservername)
	select @save_Memory = replace(@save_Memory, ',', '')
	select @save_Memory = replace(@save_Memory, 'MB', '')
	select @save_Memory = rtrim(@save_Memory)


	Select @charpos = charindex('.', @save_Memory)
	IF @charpos <> 0
	   begin
		select @save_Memory = left(@save_Memory, @charpos-1)
		If convert(int, @save_Memory) > 4096 and (@save_awe = 'n' or @save_boot_pae = 'n')
		   begin
			If @first_flag = 'y'
			   begin
				Select @rpt_flag = 'y'
				Select @first_flag = 'n'


				Select @message = 'The following SQL server(s) have incorrect settings related to the boot.ini pae or SQL awe parms.  They should both be set to ''y''.'
				Select @cmd = 'echo ' + @message + '>>' + @out_filename
				EXEC master.sys.xp_cmdshell @cmd, no_output
			   end


			Select @message = convert(nchar(30), @save_sqlservername) + ' Memory: ' + convert(nchar(15), @save_Memory) + ' AWE: ''' + @save_awe +  '''   PAE: ''' + @save_boot_pae + ''''
			Select @cmd = 'echo ' + @message + '>>' + @out_filename
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	delete from @tblv_memory where sqlservername = @save_sqlservername
	If (select count(*) from @tblv_memory) > 0
	   begin
		goto start_memory08
	   end


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output


	Select @message = '.'
	Select @cmd = 'echo' + @message + '>>' + @out_filename
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


--  Check the OffSite Backup Info for production servers.
-- code to follow...


----  Check the dba_clusterinfo table  ------------------------------------------------------------------------
----  Check Quorum Group
--delete from @tblv_cluster
--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.quorumgroup_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.quorumgroup_status <> 'online'


--If (select count(*) from @tblv_cluster) > 0
--   begin
--	Select @first_flag = 'y'
--	start_cluster01:
--	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cluster order by SQLServerName)
--	Select @save_Name2 = (select top 1 Name2 from @tblv_cluster where SQLServerName = @save_sqlservername)


--	If @first_flag = 'y'
--	   begin
--		Select @rpt_flag = 'y'
--		Select @first_flag = 'n'


--		Select @message = 'The following SQL server(s) have status issues related to the quorum group in the cluster.'
--		Select @cmd = 'echo ' + @message + '>>' + @out_filename
--		EXEC master.sys.xp_cmdshell @cmd, no_output
--	   end


--	Select @message = convert(nchar(30), @save_sqlservername) + ' Quorum Group: ' + convert(nchar(15), @save_Name2)
--	Select @cmd = 'echo ' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	delete from @tblv_cluster where sqlservername = @save_sqlservername
--	If (select count(*) from @tblv_cluster) > 0
--	   begin
--		goto start_cluster01
--	   end


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output
--   end


----  Check DTC Group
--delete from @tblv_cluster
--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.DTCgroup_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.DTCgroup_status <> 'online'


--If (select count(*) from @tblv_cluster) > 0
--   begin
--	Select @first_flag = 'y'
--	start_cluster02:
--	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cluster order by SQLServerName)
--	Select @save_Name2 = (select top 1 Name2 from @tblv_cluster where SQLServerName = @save_sqlservername)


--	If @first_flag = 'y'
--	   begin
--		Select @rpt_flag = 'y'
--		Select @first_flag = 'n'


--		Select @message = 'The following SQL server(s) have status issues related to the DTC group in the cluster.'
--		Select @cmd = 'echo ' + @message + '>>' + @out_filename
--		EXEC master.sys.xp_cmdshell @cmd, no_output
--	   end


--	Select @message = convert(nchar(30), @save_sqlservername) + ' DTC Group: ' + convert(nchar(15), @save_Name2)
--	Select @cmd = 'echo ' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	delete from @tblv_cluster where sqlservername = @save_sqlservername
--	If (select count(*) from @tblv_cluster) > 0
--	   begin
--		goto start_cluster02
--	   end


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output
--   end


----  Check Virtual Server Group(s)
--delete from @tblv_cluster
--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.VirtSrv01_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.VirtSrv01_node <> ''
--and dc.VirtSrv01_node is not null
--and dc.VirtSrv01_status <> 'online'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.VirtSrv02_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.VirtSrv02_node <> ''
--and dc.VirtSrv02_node is not null
--and dc.VirtSrv02_status <> 'online'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.VirtSrv03_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.VirtSrv03_node <> ''
--and dc.VirtSrv03_node is not null
--and dc.VirtSrv03_status <> 'online'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.VirtSrv04_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.VirtSrv04_node <> ''
--and dc.VirtSrv04_node is not null
--and dc.VirtSrv04_status <> 'online'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.VirtSrv05_node
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.VirtSrv05_node <> ''
--and dc.VirtSrv05_node is not null
--and dc.VirtSrv05_status <> 'online'


--If (select count(*) from @tblv_cluster) > 0
--   begin
--	Select @first_flag = 'y'
--	start_cluster03:
--	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cluster order by SQLServerName)
--	Select @save_Name2 = (select top 1 Name2 from @tblv_cluster where SQLServerName = @save_sqlservername)


--	If @first_flag = 'y'
--	   begin
--		Select @rpt_flag = 'y'
--		Select @first_flag = 'n'


--		Select @message = 'The following SQL server(s) have status issues related to a Virtual Server in the cluster.'
--		Select @cmd = 'echo ' + @message + '>>' + @out_filename
--		EXEC master.sys.xp_cmdshell @cmd, no_output
--	   end


--	Select @message = convert(nchar(30), @save_sqlservername) + ' Virtual Server: ' + convert(nchar(15), @save_Name2)
--	Select @cmd = 'echo ' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	delete from @tblv_cluster where sqlservername = @save_sqlservername
--	If (select count(*) from @tblv_cluster) > 0
--	   begin
--		goto start_cluster03
--	   end


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output
--   end


----  Check Physical Node(s)
--delete from @tblv_cluster
--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.clustNode01
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.clustNode01 <> ''
--and dc.clustNode01 is not null
--and dc.clustNode01_status <> 'Up'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.clustNode02
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.clustNode02 <> ''
--and dc.clustNode02 is not null
--and dc.clustNode02_status <> 'Up'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.clustNode03
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.clustNode03 <> ''
--and dc.clustNode03 is not null
--and dc.clustNode03_status <> 'Up'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.clustNode04
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.clustNode04 <> ''
--and dc.clustNode04 is not null
--and dc.clustNode04_status <> 'Up'


--insert into @tblv_cluster (SQLServerName, Name2)
--Select dc.sqlname, dc.clustNode05
--from @tblv_DBA_Serverinfo ds, dbo.DBA_Clusterinfo dc
--where ds.SQLServerName = dc.sqlname
--and ds.Active = 'y'
--and dc.clustNode05 <> ''
--and dc.clustNode05 is not null
--and dc.clustNode05_status <> 'Up'


--If (select count(*) from @tblv_cluster) > 0
--   begin
--	Select @first_flag = 'y'
--	start_cluster04:
--	Select @save_sqlservername = (select top 1 SQLServerName from @tblv_cluster order by SQLServerName)
--	Select @save_Name2 = (select top 1 Name2 from @tblv_cluster where SQLServerName = @save_sqlservername)


--	If @first_flag = 'y'
--	   begin
--		Select @rpt_flag = 'y'
--		Select @first_flag = 'n'


--		Select @message = 'The following SQL server(s) have status issues related to a Physical node in the cluster.'
--		Select @cmd = 'echo ' + @message + '>>' + @out_filename
--		EXEC master.sys.xp_cmdshell @cmd, no_output
--	   end


--	Select @message = convert(nchar(30), @save_sqlservername) + ' Physical Node: ' + convert(nchar(15), @save_Name2)
--	Select @cmd = 'echo ' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	delete from @tblv_cluster where sqlservername = @save_sqlservername
--	If (select count(*) from @tblv_cluster) > 0
--	   begin
--		goto start_cluster04
--	   end


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output


--	Select @message = '.'
--	Select @cmd = 'echo' + @message + '>>' + @out_filename
--	EXEC master.sys.xp_cmdshell @cmd, no_output
--   end


send_report:


If @rpt_flag = 'y'
   begin
	--print @subject
	--print @message


	--  Email TS SQL DBA with this information
	EXEC DBAOps.dbo.dbasp_sendmail
	    @recipients = @rpt_recipient,
	    @subject = @subject,
	    @message = @subject,
	    @attachments = @out_filename
   end


--print @subject
--print @message


---------------------------  Finalization for process  -----------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_REPORT_SQLhealth] TO [public]
GO
