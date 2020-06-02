SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_DEPLOYJobs]


/***************************************************************
 **  Stored Procedure dbasp_Check_DEPLOYJobs
 **  Written by Steve Ledridge, Virtuoso
 **  February 27, 2013
 **
 **  This dbasp is set up to;
 **
 **  Check for DEPLOY jobs in production and remove them.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/27/2012	Steve Ledridge		New process.
--	07/18/2013	Steve Ledridge		Removed DEPL job references.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	10/19/2016	Steve Ledridge		Do not delete jobs if a request is in-work or pending.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(4000)
	,@savesubject			varchar(100)
	,@delete_flag			char(1)


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @delete_flag = 'n'


Select @savesubject = 'DBA Note: Deployment Jobs Being Removed from ' +  @@servername


/****************************************************************
 *                MainLine
 ***************************************************************/


If (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname') = 'production'
   Begin
	If exists (select 1 from msdb.dbo.sysjobs where name in ( 'DBAOps - 00 Controller'
								, 'DBAOps - 01 Restore'
								, 'DBAOps - 51 Deploy'
								, 'DBAOps - 99 Post'
								, 'DBAOps - Monitor')
		)
	   begin


		If (select count(*) from DBAOps.dbo.Request_local where Status like 'in-work%' or Status = 'pending') > 0
		   begin
			Select @savesubject = 'DBA Note: Deployment Jobs NOT Being Removed from ' +  @@servername


			Exec DBAOps.dbo.dbasp_sendmail
			@recipients = 'DBANotify@virtuoso.com',
			@subject = @savesubject,
			@message = 'DBA Note: Automated SQL DEPLoyment Jobs were not removed from this production server.'


			goto label99
		   end


		Print @savesubject

		If exists (select 1 from msdb.dbo.sysjobs where name = 'DBAOps - 00 Controller')
		   begin
			exec msdb.dbo.sp_delete_job @job_name = N'DBAOps - 00 Controller'
			Select @delete_flag = 'y'
		   end


		If exists (select 1 from msdb.dbo.sysjobs where name = 'DBAOps - 01 Restore')
		   begin
			exec msdb.dbo.sp_delete_job @job_name = N'DBAOps - 01 Restore'
			Select @delete_flag = 'y'
		   end


		If exists (select 1 from msdb.dbo.sysjobs where name = 'DBAOps - 51 Deploy')
		   begin
			exec msdb.dbo.sp_delete_job @job_name = N'DBAOps - 51 Deploy'
			Select @delete_flag = 'y'
		   end


		If exists (select 1 from msdb.dbo.sysjobs where name = 'DBAOps - 99 Post')
		   begin
			exec msdb.dbo.sp_delete_job @job_name = N'DBAOps - 99 Post'
			Select @delete_flag = 'y'
		   end


		If exists (select 1 from msdb.dbo.sysjobs where name = 'DBAOps - Monitor')
		   begin
			exec msdb.dbo.sp_delete_job @job_name = N'DBAOps - Monitor'
			Select @delete_flag = 'y'
		   end


		If @delete_flag = 'y'
		   begin
			Exec DBAOps.dbo.dbasp_sendmail
			@recipients = 'DBANotify@virtuoso.com',
			@subject = @savesubject,
			@message = 'DBA Note: Automated SQL DEPLoyment Jobs have been removed from this production server.'
		   end
	   end
   End


---------------------------  Finalization  -----------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_DEPLOYJobs] TO [public]
GO
