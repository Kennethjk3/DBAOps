SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSinmage_DRscript]


/*********************************************************
 **  Stored Procedure dbasp_SYSinmage_DRscript
 **  Written by Steve Ledridge, Virtuoso
 **  June 21, 2012
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Perform post failover step related to inmage replicated DR sites.
 **
 **  Output member is SYSinmage_DRscript.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/21/2012	Steve Ledridge		New process
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@cmd			nvarchar(4000)
	,@save_SQLname		sysname


----------------  initial values  -------------------


----------------------  Main header  ----------------------


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSinmage_DRscript'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/


--  SQLname change section
Select @miscprint = '--  Change SQLname'
Print  @miscprint


Select @save_SQLname = (select detail03 from dbo.Local_Control where subject = 'DR_ArchiveCopy')


Print 'Use master'
Print 'go'
Print ' '
Print 'exec sp_dropserver ''' + @@servername + ''''
Print 'go'
Print ' '
Print 'exec sp_addserver ''' + @save_SQLname + ''', local'
Print 'go'
Print ' '


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'ATTENTION:  Recycle SQL before you continue with this script.'
Print  @miscprint
Print  @miscprint
Print  @miscprint
Print  '************************************************************************/'
Print  ' '
Print  ' '


--  Disable MAINT jobs
Select @miscprint = '--  Disable MAINT Jobs'
Print  @miscprint


Print 'Use msdb'
Print 'go'
Print ' '
Print 'exec msdb.dbo.sp_update_job @job_name = ''MAINT - Daily Backup and DBCC'', @enabled = 0'
Print 'go'
Print 'exec msdb.dbo.sp_update_job @job_name = ''MAINT - TranLog Backup'', @enabled = 0'
Print 'go'
Print 'exec msdb.dbo.sp_update_job @job_name = ''MAINT - Weekly Backup and DBCC'', @enabled = 0'
Print 'go'
Print ' '
Print ' '


--  Set DB's to Simple
Select @miscprint = '--  Set Databases to Simple'
Print  @miscprint


Print 'Use master'
Print 'go'
Print ' '


Select @cmd = 'declare @save_DBname sysname
declare @cmd nvarchar(500)


select @save_DBname = '' ''


If exists(select 1 from master.sys.databases where database_id > 4 and recovery_model <> 3)
   begin
	start01:
	Select @save_DBname = (select top 1 name from master.sys.databases where database_id > 4 and recovery_model <> 3 and name > @save_DBname order by name)
	Select @cmd = ''ALTER DATABASE ['' + @save_DBname + ''] SET RECOVERY SIMPLE WITH NO_WAIT''
	Print @cmd
	exec (@cmd)

	If exists (select 1 from master.sys.databases where database_id > 4 and recovery_model <> 3 and name > @save_DBname)
	   begin
		goto start01
	   end
   end

go'

Print @cmd


Print ' '
Print 'exec DBAOps.dbo.dbasp_set_maintplans'
Print 'go'
Print ' '
Print ' '


--  Disable All Enabled Jobs
Select @miscprint = '--  Disable SQL Jobs'
Print  @miscprint


Print 'Use DBAOps'
Print 'go'
Print ' '


Print 'exec DBAOps.dbo.dbasp_Update_SQLjobs @runtype = ''disable'''
Print 'go'
Print ' '
Print ' '


--  Add/Update Shares
Select @miscprint = '--  Add/Update Shares'
Print  @miscprint


exec DBAOps.dbo.dbasp_syscreateshares
Print ' '
Print ' '


--  Add/Update SQL Jobs
Select @miscprint = '--  Add/Update SQL Jobs'
Print  @miscprint


exec DBAOps.dbo.dbasp_SYSaddjobs  @jobname = 'XXX'
Print ' '
Print ' '


--  Enable All Previously Disabled Jobs
Select @miscprint = '--  Enable All Previously Disabled Jobs'
Print  @miscprint


Print 'Use DBAOps'
Print 'go'
Print ' '


Print 'exec DBAOps.dbo.dbasp_Update_SQLjobs @runtype = ''enable'''
Print 'go'
Print ' '
Print ' '


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSinmage_DRscript] TO [public]
GO
