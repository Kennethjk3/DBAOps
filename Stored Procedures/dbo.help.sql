SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[help] (@DBname sysname = null)


/**************************************************************
 **  Stored Procedure help
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 4, 2014
 **
 **  This sproc provides example syntax for many of the common
 **  queries a DBA might need in the ${{secrets.COMPANY_NAME}} Environment.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	03/04/2014	Steve Ledridge				New process.
--	======================================================================================


/***
Declare @DBname sysname


--Select @DBname = 'all'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)


--  Check input parameters
If @DBname is null or @DBname = ''
   begin
	Select @DBname = 'DBAOps'
   end
Else If @DBname not in ('all', 'master', 'msdb', 'DBAOps', 'dbaperf', 'dbacentral', 'DBAOps', 'DEPLOYcentral')
   begin
	Print 'DBA Warning:  Invalid input parameters for @DBname.  Valid entries are ''all'', ''master'', ''msdb'', ''DBAOps'', ''dbaperf'', ''dbacentral'', ''DBAOps'' and ''DEPLOYcentral''.'
	Goto label99
   end


If @DBname = 'master' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for master:'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- General master queries and sprocs:'
	Print  @miscprint
	Select @miscprint = 'exec xp_fixeddrives'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'exec sp_who2'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'exec sp_whoisactive'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from master.sys.databases'
	Print  @miscprint
	Print  ' '
	Print  ' '
  end


If @DBname = 'DBAOps' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for DBAOps:'
	Print  @miscprint
	Select @miscprint = '--NOTE: For other DB sytax examples, use input parm ''all''.'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- DBA_*info table queries (runbook tables):'
	Print  @miscprint
	Select @miscprint = 'select * from DBAOps.dbo.DBA_serverinfo'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAOps.dbo.DBA_DBinfo'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAOps.dbo.DBA_clusterinfo'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAOps.dbo.DBA_diskinfo'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Local_ServerEnviro:'
	Print  @miscprint
	Select @miscprint = 'select * from DBAOps.dbo.Local_ServerEnviro'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Common Sprocs:'
	Print  @miscprint
	Select @miscprint = 'exec DBAOps.dbo.dbasp_script_DBsprocs ''dbname'''
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'exec DBAOps.dbo.dbasp_SYSaddjobs ''jobname'''
	Print  @miscprint
	Print  ' '
	Print  ' '
   end


If @DBname = 'dbaperf' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for DBAperf:'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- Performance Queries:'
	Print  @miscprint
	Select @miscprint = 'select * from dbaperf.dbo.check_contention'
	Print  @miscprint
	Select @miscprint = 'where createdate > getdate()-1'
	Print  @miscprint
	Select @miscprint = '--and headblocker = ''y'''
	Print  @miscprint
	Select @miscprint = 'order by createdate --desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from dbaperf.dbo.DBAperf_log'
	Print  @miscprint
	Select @miscprint = 'where rundate > getdate()-1'
	Print  @miscprint
	Select @miscprint = 'order by rundate desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from dbaperf.dbo.DMV_QueryStats_log'
	Print  @miscprint
	Select @miscprint = 'where rundate > getdate()-1'
	Print  @miscprint
	Select @miscprint = '--and QueryText like ''%sprocname%'''
	Print  @miscprint
	Select @miscprint = 'order by rundate desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from dbaperf.dbo.tempdb_filestats_log'
	Print  @miscprint
	Select @miscprint = 'where rundate > getdate()-1'
	Print  @miscprint
	Select @miscprint = '--and file_id = 1'
	Print  @miscprint
	Select @miscprint = 'order by rundate desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from dbaperf.dbo.tempdb_sessionstats_log'
	Print  @miscprint
	Select @miscprint = 'where rundate > getdate()-1'
	Print  @miscprint
	Select @miscprint = 'order by rundate desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- DBAperf common sprocs:'
	Print  @miscprint
	Select @miscprint = 'exec dbaperf.dbo.dbasp_REPORTusage'
	Print  @miscprint
	Print  ' '
	Print  ' '
   end


If @DBname = 'dbacentral' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for DBAcentral:'
	Print  @miscprint
	Select @miscprint = '--NOTE: This DB is only on the central servers.'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- DBA_*info table queries (runbook tables):'
	Print  @miscprint
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_serverinfo'
	Print  @miscprint
	Select @miscprint = 'where active <> ''n'''
	Print  @miscprint
	Select @miscprint = 'order by moddate --DBAOps_version'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_serverinfo'
	Print  @miscprint
	Select @miscprint = 'where servername like ''%servername%'''
	Print  @miscprint
	Select @miscprint = 'order by sqlenv'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_DBinfo'
	Print  @miscprint
	Select @miscprint = 'where SQLname like ''%SQLname%'''
	Print  @miscprint
	Select @miscprint = 'order by DBname'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_DBinfo'
	Print  @miscprint
	Select @miscprint = 'where DBname like ''%dbname%'''
	Print  @miscprint
	Select @miscprint = 'order by moddate  --DBname'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_clusterinfo'
	Print  @miscprint
	Select @miscprint = 'where SQLname like ''%SQLname%'''
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select * from DBAcentral.dbo.DBA_diskinfo'
	Print  @miscprint
	Select @miscprint = 'where SQLname like ''%SQLname%'''
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Print  ' '
   end


 If @DBname = 'DBAOps' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for DBAOps:'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- Check SQL Deployment Processing:'
	Print  @miscprint
	Select @miscprint = 'exec DBAOps.dbo.dpsp_status'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select top 50 * from DBAOps.dbo.Request_local order by rl_id desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Print  ' '
   end


If @DBname = 'DEPLOYcentral' or @DBname = 'all'
   begin
	Print  '------------------------------------------------- '
	Select @miscprint = '--Example Syntax for DEPLOYcentral:'
	Print  @miscprint
	Select @miscprint = '--NOTE: This DB is only on the central servers.'
	Print  @miscprint
	Print  '------------------------------------------------- '
	Print  ' '
	Select @miscprint = '-- Check SQL Deployment Processing on Central Server:'
	Print  @miscprint
	Select @miscprint = 'exec DEPLOYcentral.dbo.dpsp_status'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'select top 50 * from DEPLOYcentral.dbo.Request_central order by rc_id desc'
	Print  @miscprint
	Select @miscprint = 'go'
	Print  @miscprint
	Print  ' '
	Print  ' '
   end


----------------  End  -------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[help] TO [public]
GO
