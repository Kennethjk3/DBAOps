SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Jobs] (@purge_days int = 30)


/***************************************************************
 **  Stored Procedure dbasp_Check_Jobs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 11, 2000
 **
 **  This dbasp is set up to;
 **
 **  Check job status and raise errors to the SQL error log
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	06/12/2003	Steve Ledridge		Add filter for jobs already reported via the
--						periodic check process.
--	04/01/2004	Steve Ledridge		Change so we don't report on job
--						'UTIL - SQL Activity Log Process'.
--	05/30/2006	Steve Ledridge		Updated for SQL 2005.
--	09/22/2006	Steve Ledridge		Check for (and replace) '%' in message parm.
--	04/18/2008	Steve Ledridge		Now look for job steps with status 0 (failed) or 3 (cancelled)
--						This will aviod alerting for retrys.
--	04/18/2011	Steve Ledridge		Added purge process for MSDB history.
--	======================================================================================


/***
Declare @purge_days int


Select @purge_days = 30
--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(4000)
	,@cursor11_text			nvarchar(1024)
	,@cursor12_text			nvarchar(1024)
	,@saverun_date			int
	,@saverun_time			int
	,@status1 			varchar(10)
	,@status2 			varchar(10)
	,@purge_date			varchar(25)


DECLARE
	 @cu11name			sysname
	,@cu11step_name			sysname
	,@cu11sql_message_id		int
	,@cu11sql_severity		int
	,@cu11message			nvarchar(1024)
	,@cu11run_status		int
	,@cu11run_date			int
	,@cu11run_time			int


DECLARE
	 @cu12Jname			sysname
	,@cu12Sname			sysname
	,@cu12next_run_date		int


/*********************************************************************
 *                Initialization
 ********************************************************************/


--------------------  Set last-run date and time parameters  -------------------
select @saverun_date = (Select max(h.run_date)
			from msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j
			where h.job_id = j.job_id
			  and j.name = 'UTIL - DBA Check Misc process'
			  and h.run_status = 1
			  and h.step_id = 0)


If @saverun_date is not null
   begin
	select @saverun_time = (Select max(h.run_time) from msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j
				where h.job_id = j.job_id
				  and h.run_date = @saverun_date
				  and j.name = 'UTIL - DBA Check Misc process')
   end
Else
   begin
	select @saverun_date = convert(int,(convert(varchar(20),getdate(), 112)))
	select @saverun_time = 0
   end


/****************************************************************
 *                MainLine
 ***************************************************************/
--------------------  Cursor for Failed Job Steps  -------------------
Select @cursor11_text = 'DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT j.name, h.step_name, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
   From msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j ' +
  'Where h.job_id = j.job_id
     and h.instance_ID not in (select instance_ID from DBAOps.dbo.FailedJobs)
     and h.run_status in (0, 3)
     and h.run_date >= ' + convert(varchar(10),@saverun_date) + '
   Order by h.job_id, h.instance_id, h.step_id For Read Only'


EXECUTE (@cursor11_text)


OPEN cu11_cursor


WHILE (11=11)
 Begin
	FETCH Next From cu11_cursor Into @cu11name, @cu11step_name, @cu11sql_message_id, @cu11sql_severity, @cu11message, @cu11run_status, @cu11run_date, @cu11run_time
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_cursor
	      BREAK
           end


	If @cu11run_date <> @saverun_date or
	   (@cu11run_date = @saverun_date and @cu11run_time >= @saverun_time)
	   begin
		If rtrim(@cu11name) <> 'UTIL - SQL Activity Log Process'
		   begin
			Select @cu11message = replace(@cu11message, '%', 'pct')
			Select @cu11step_name = replace(@cu11step_name, '%', 'pct')
			Select @miscprint = 'DBA WARNING: Job Step Failed - Job: ''' + @cu11name + ''' Step: ''' + @cu11step_name + ''' Message: ''' + @cu11message + ''' Date: ' + convert(varchar(10),@cu11run_date) + ' Time: ' + convert(varchar(10),@cu11run_time)
			raiserror(@miscprint,-1,-1) with log
		   end
	   end


 End  -- loop 11


DEALLOCATE cu11_cursor


--------------------  Cursor for Next Run Date check  -------------------


--  Note:  The next run date must be at least 24 hours in the past for that job to be picked
--         up by this process.  That fixes the problem of listing jobs that are currently running.


Select @cursor12_text = 'DECLARE cu12_cursor Insensitive Cursor For ' +
  'SELECT j.name, s.name, sj.next_run_date
   From msdb.dbo.sysjobs j, msdb.dbo.sysschedules s, msdb.dbo.sysjobschedules sj ' +
  'Where j.job_id = sj.job_id
	 and sj.schedule_id = s.schedule_id
     and j.enabled = 1
     and s.enabled = 1
     and sj.next_run_date is not null
     and sj.next_run_date <> 0
     and sj.next_run_date < ' + convert(char(8), getdate()-1, 112) + '
   Order by j.name For Read Only'


EXECUTE (@cursor12_text)


OPEN cu12_cursor


WHILE (12=12)
 Begin
	FETCH Next From cu12_cursor Into @cu12Jname, @cu12Sname, @cu12next_run_date
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_cursor
	      BREAK
           end


	-- Check to see if the job is currently idle (not running).  If so, raise an error.
	exec DBAOps.dbo.dbasp_Check_Jobstate @cu12Jname, @status1 output


	IF @status1 = 'idle'
	   begin
		Select @miscprint = 'DBA WARNING: Next Scheduled Run Date for Job: ''' + @cu12Jname + ''' & Schedule: ''' + @cu12Sname + ''' has past (i.e. ' + convert(char(8), @cu12next_run_date) + ').  Please stop and restart SQL Agent on this server to reset job schedules'
		raiserror(@miscprint,-1,-1) with log
	   end


 End  -- loop 12


DEALLOCATE cu12_cursor


--  MSDB Purge Process  --------------------------------------------------------------
Print 'Start MSDB purge process'
Print ''


select @purge_date = convert(varchar(25), getdate()-@purge_days, 120)


exec msdb.dbo.sp_delete_backuphistory @purge_date


exec msdb.dbo.sp_purge_jobhistory @oldest_date=@purge_date


exec msdb.dbo.sp_maintplan_delete_log null,null,@purge_date


---------------------------  Finalization  -----------------------


return 0
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Jobs] TO [public]
GO
