SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_JobController] (@JobNameMask sysname = 'BASE'
					 ,@ControlName sysname = 'job_control'
					 ,@restore_StartTime int = 600
					 ,@auto_reset char(1) = 'n'
					 )

/*********************************************************
 **  Stored Procedure dbasp_JobController
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 11, 2008
 **
 **  This dbasp is set up to run a series of jobs (job stream), each
 **  job one after the other.
 **
 **  Input Parms:
 **  @JobNameMask - The first Part of the job name (all jobs must start with the same name mask)
 **
 **  @ControlName - This will be the subject value in the control table.
 **
 **  @restore_StartTime - For restore jobs, the time they can start (605 would be 6:05AM)
 **
 **  @auto_reset - When 'y', this will reset the process to the current running job.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/11/2008	Steve Ledridge		New process
--	04/13/2015	Steve Ledridge		Added check for running job.
--	======================================================================================


/**
declare @JobNameMask sysname
declare @ControlName sysname
declare @restore_StartTime int
declare @auto_reset char(1)


select @JobNameMask = 'BASE'
Select @ControlName = 'job_control'
select @restore_StartTime = 600
select @auto_reset = 'n'
--**/


DECLARE
	 @miscprint			nvarchar(500)
	,@is_sysadmin			int
	,@job_owner			sysname
	,@message			nvarchar(500)
	,@save_current_jobname		sysname
	,@save_next_jobname		sysname
	,@save_current_jobid		UNIQUEIDENTIFIER
	,@save_next_jobid		UNIQUEIDENTIFIER
	,@save_instance_id		int
	,@hhmm				nvarchar(5)
	,@hhmm_int			int


/*********************************************************************
 *                Initialization
 ********************************************************************/


CREATE TABLE #xp_results (job_id                UNIQUEIDENTIFIER NOT NULL,
                          last_run_date         INT              NOT NULL,
                          last_run_time         INT              NOT NULL,
                          next_run_date         INT              NOT NULL,
                          next_run_time         INT              NOT NULL,
                          next_run_schedule_id  INT              NOT NULL,
                          requested_to_run      INT              NOT NULL, -- BOOL
                          request_source        INT              NOT NULL,
                          request_source_id     sysname          NULL,
                          running               INT              NOT NULL, -- BOOL
                          current_step          INT              NOT NULL,
                          current_retry_attempt INT              NOT NULL,
                          job_state             INT              NOT NULL)


SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
SELECT @job_owner = SUSER_SNAME()

INSERT INTO #xp_results
   EXECUTE master.sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner


select * from #xp_results


--  Remove rows that dont match the job mask
delete from #xp_results where job_id not in (select job_id from msdb.dbo.sysjobs where name like @JobNameMask + '%')
--select * from #xp_results


/****************************************************************
 *  Main Process
 ***************************************************************/


--  Auto reset process
If @auto_reset = 'y'
   begin
	If not exists (select 1 from #xp_results where job_state = 1)
	   begin
		Print 'Job Controller Auto Reset failed. No matching jobs are running at this time.'
		raiserror(67016, 16, -1, @message)
		goto label99
	   end


	If (select count(*) from #xp_results where job_state = 1) > 1
	   begin
		Print 'Job Controller Auto Reset failed.  More than one job is running at this time.'
		raiserror(67016, 16, -1, @message)
		goto label99
	   end


	Select @save_current_jobid = (select top 1 job_id from #xp_results where job_state = 1)
	Select @save_current_jobname = (select top 1 name from msdb.dbo.sysjobs where job_id = @save_current_jobid)
	Delete from dbo.Local_Control where subject = @ControlName
	Insert into dbo.Local_Control values(@ControlName, @save_current_jobname, '', '')
	goto label99
   end


-- If no rows are found in the dbo.Local_Control table, error out
If (select count(*) from dbo.Local_Control where subject = @ControlName) = 0
   begin
	Select @message = 'No job_control record exists in the DBAOps Local_Control table'
	Print @message
	raiserror(67016, 16, -1, @message)
	goto label99
   end


-- If more than one row is found in the dbo.Local_Control table, error out
If (select count(*) from dbo.Local_Control where subject = @ControlName) > 1
   begin
	Select @message = 'More than one job_control record exists in the DBAOps Local_Control table'
	Print @message
	raiserror(67016, 16, -1, @message)
	goto label99
   end


--  Check to see what job has been started
Set @save_current_jobname = null
Select @save_current_jobname = (select detail01 from dbo.Local_Control where subject = @ControlName)


--  Get the job_id for this job
Print 'Checking job: ' + @save_current_jobname
Set @save_current_jobid = null
Select @save_current_jobid = (select job_id from msdb.dbo.sysjobs where name = @save_current_jobname and originating_server_id = 0)


-- If no rows were found in the dbo.Local_Control table, error out
If @save_current_jobid is null
   begin
	Select @message = 'Unable to find job_id for job ''' + @save_current_jobname + '''. '
	Print @message
	raiserror(67016, 16, -1, @message)
	goto label99
   end


--  Check the status of the current job
Print 'Current Job State is:'
select job_state from #xp_results where job_id = @save_current_jobid


--  If the current job is running, end this process
If (select job_state from #xp_results where job_id = @save_current_jobid) in (1, 2, 3, 7)
   begin
	Print 'Current job ''' + @save_current_jobname + ''' is running. ' + convert(varchar(30),getdate(),120)
	goto label99
   end


If (select running from #xp_results where job_id = @save_current_jobid) = 1
   begin
	Print 'Current job ''' + @save_current_jobname + ''' is running but the job state is not in (1, 2, 3, 7). ' + convert(varchar(30),getdate(),120)
	goto label99
   end


--  If the current job is not idle, error out
 If (select job_state from #xp_results where job_id = @save_current_jobid) <> 4
   begin
	Print 'Current job ''' + @save_current_jobname + ''' is in a bad state. ' + convert(varchar(30),getdate(),120)
	raiserror(67016, 16, -1, @message)
	goto label99
   end


--  If the current job is idle (at this point it must be), get the history info
Select @save_instance_id = (Select top 1 instance_id from msdb.dbo.sysjobhistory where job_id = @save_current_jobid order by instance_id desc)


-- check to see if the job is still running
If (select run_status from msdb.dbo.sysjobhistory where instance_id = @save_instance_id) = 4 -- in-process
   begin
	Print 'Current job ''' + @save_current_jobname + ''' is running. ' + convert(varchar(30),getdate(),120)
	goto label99
   end


-- check to see if the job is in retry mode
If (select run_status from msdb.dbo.sysjobhistory where instance_id = @save_instance_id) = 2 -- retry
   begin
	Print 'Current job ''' + @save_current_jobname + ''' is retrying. ' + convert(varchar(30),getdate(),120)
	goto label99
   end


-- check to see if the job has failed
If (select run_status from msdb.dbo.sysjobhistory where instance_id = @save_instance_id) = 0 -- failed
   begin
	Print 'Current job ''' + @save_current_jobname + ''' has failed. ' + convert(varchar(30),getdate(),120)
	raiserror(67016, 16, -1, @message)
	goto label99
   end


-- check to see if the job has been cancelled
If (select run_status from msdb.dbo.sysjobhistory where instance_id = @save_instance_id) = 3 -- cancelled
   begin
	Print 'Current job ''' + @save_current_jobname + ''' has been cancelled. ' + convert(varchar(30),getdate(),120)
	raiserror(67016, 16, -1, @message)
	goto label99
   end


-- check to make sure the job succeeded
If (select run_status from msdb.dbo.sysjobhistory where instance_id = @save_instance_id) <> 1 -- success
   begin
	Print 'Current job ''' + @save_current_jobname + ''' has unknown history run status. ' + convert(varchar(30),getdate(),120)
	raiserror(67016, 16, -1, @message)
	goto label99
   end


--  At this point we know the job succeeded.  Check to see if there is another job to start.
If exists (select 1 from msdb.dbo.sysjobs where name like @JobNameMask + '%' and name > @save_current_jobname)
   begin
	Select @save_next_jobname = (select top 1 name from msdb.dbo.sysjobs where name like @JobNameMask + '%' and name > @save_current_jobname order by name)


	--  Get the Next job job_id.
	Set @save_next_jobid = null
	Select @save_next_jobid = (select job_id from msdb.dbo.sysjobs where name = @save_next_jobname and originating_server_id = 0)


	-- If no rows were found in the dbo.Local_Control table, error out
	If @save_next_jobid is null
	   begin
		Select @message = 'Unable to find job_id for next job ''' + @save_next_jobname + '''. '
		Print @message
		raiserror(67016, 16, -1, @message)
		goto label99
	   end


	--  If the next job is running, error out
	If (select job_state from #xp_results where job_id = @save_next_jobid) in (1, 2, 3, 7)
	   begin
		Select @message = 'Next job ''' + @save_next_jobname + ''' is running. ' + convert(varchar(30),getdate(),120)
		Print @message
		raiserror(67016, 16, -1, @message)
		goto label99
	   end


	--  Check to see if the next job is a restore.
	If @save_next_jobname like '%Restore%'
	   begin
		--  check current time against input parm.  If it's not time yet, end the process.
		select @hhmm = convert(nvarchar(5), getdate(), 8)
		select @hhmm = replace(@hhmm, ':', '')
		select @hhmm_int = convert(int, @hhmm)


		If @hhmm_int < @restore_StartTime
		   begin
			Select @message = 'Not time to start restore jobs yet.  Job ''' + @save_next_jobname + '''. ' + convert(varchar(30),getdate(),120)
			Print @message
			goto label99
		   end
	   end


	--  Start the next job and reset the control table
	Select @message = 'Starting job ''' + @save_next_jobname + '''. ' + convert(varchar(30),getdate(),120)
	Print @message


	exec msdb.dbo.sp_start_job @job_name = @save_next_jobname


	Update dbo.Local_Control set detail01 = @save_next_jobname where subject = @ControlName


   end
Else
   begin
	Print 'Current job ''' + @save_current_jobname + ''' has completed and no further jobs were found. ' + convert(varchar(30),getdate(),120)
	raiserror(67016, 16, -1, @message)
	goto label99
   end


---------------------------  Finalization  -----------------------


label99:


DROP TABLE #xp_results
GO
GRANT EXECUTE ON  [dbo].[dbasp_JobController] TO [public]
GO
