SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_check_defrag] (@check_period smallint = 7)


/**************************************************************
 **  Stored Procedure dbasp_check_defrag
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 13, 2008
 **
 **  This dbasp is set up to check local defrag processing.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/13/2008	Steve Ledridge		New process for SQL 2005.
--	10/20/2009	Steve Ledridge		Added no_check table lookup
--	03/23/2010	Steve Ledridge		Added input parm @check_period.
--	06/21/2010	Steve Ledridge		Modified for New Maintenance Process which writes to
--						dbo.IndexMaintenanceLastRunDetails instead of
--						dbo.fragmentation_LOG.
--	======================================================================================


/***
Declare @check_period smallint


Select @check_period = 7
--***/


-----------------  declares  ------------------
DECLARE
	 @cmd	 		nvarchar(4000)
	,@alert 		sysname


print convert(nvarchar(20), getdate(), 121)


--  If not production, skip this check
If (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname') <> 'production'
   begin
	goto label99
   end


--  If no full DB's and no defrag DB's, skip this check
If (select count(*) From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
		    Where d.plan_id = s.plan_id
		     and s.plan_name like '%user_defrag%') = 0
   and (select count(*) From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
		    Where d.plan_id = s.plan_id
		     and s.plan_name like '%user_full%') = 0
   begin
	goto label99
   end


--  If the check_maint 'skip' row exists in the Local_ServerEnviro table, skip this check
If exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_maint' and env_detail = 'skip')
   begin
	goto label99
   end


--  If the 'maint' row exists in the no_check table, skip this check
If exists (select 1 from DBAOps.dbo.no_check where NoCheck_type = 'maint' and detail01 = 'skip_check')
   begin
	goto label99
   end


If (select count(*) from DBAOps.dbo.IndexMaintenanceLastRunDetails) < 1
   begin
	Select @alert = 'No index maintenace has ever been run on this server (' + @@servername + ')!'
	Print @alert
	RAISERROR (67015, -1, -1, @alert) with log
   end
Else If (select max (createdate) from DBAOps.dbo.IndexMaintenanceLastRunDetails) < getdate()-@check_period
   begin
	Select @alert = 'No index maintenace has been run in the last '+CAST(@check_period AS VarChar(50))+' days for server (' + @@servername + ')!'
	Print @alert
	RAISERROR (67015, -1, -1, @alert) with log
   end


----------------  End  -------------------


label99:


Print ''
Print 'Defrag Check Complete.'
GO
GRANT EXECUTE ON  [dbo].[dbasp_check_defrag] TO [public]
GO
