SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_pong] (@rq_servername sysname = null
				,@rq_stamp sysname = null
				,@rq_type sysname = null
				,@rq_detail01 nvarchar(4000) = null
				,@rq_detail02 sysname = null)


/***************************************************************
 **  Stored Procedure dbasp_pong
 **  Written by Steve Ledridge, Virtuoso
 **  May 30, 2007
 **
 **  This sproc is set up to;
 **
 **  Accepts a request from a central server and returns data to
 **  the pong_return table.
 **
 **  This proc accepts several input parms:
 **
 **  - @rq_servername is the name of the requesting sql server instance.
 **
 **  - @rq_stamp is the timestamp for this request. Use: convert(sysname, getdate(), 121) + convert(nvarchar(40), newid())
 **
 **  - @rq_type is the request type.  ('job', 'db_status', 'db_query')
 **
 **  - @rq_detail01 is information related to the request type.
 **    For job - job name (or at least the first part of the job name)
 **    For db_status - DB name
 **
 **  - @rq_detail02 is for future use.
 **
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	05/30/2007	Steve Ledridge		New process.
--	05/31/2007	Steve Ledridge		Updated for sql 2005.
--	12/19/2007	Steve Ledridge		Added code for generic DB queries that return a single value.
--	10/01/2008	Steve Ledridge		Updated example with newid() in the req_stamp.
--	04/20/2012	Steve Ledridge		Updated message to nvarchar(4000).
--	======================================================================================


/***
Declare @rq_servername sysname
Declare @rq_stamp sysname
Declare @rq_type sysname
Declare @rq_detail01 nvarchar(4000)
Declare @rq_detail02 sysname


Select @rq_servername = 'DBAOpser02'
Select @rq_stamp = '2007-12-21 12:10:03.077'
Select @rq_type = 'db_query'
Select @rq_detail01 = 'select top 1 name from master.sys.databases'
Select @rq_detail02 = ''
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd	 		nvarchar(4000)
	,@error_count		int
	,@hold_detail01		nvarchar(4000)
	,@save_detail01		nvarchar(4000)
	,@save_detail02		sysname
	,@save_jobname		sysname
	,@save_current_step	int
	,@save_run_date		nvarchar(10)
	,@save_run_time		nvarchar(10)
	,@query			nvarchar(4000)
	,@query_out		sysname


DECLARE
	 @is_sysadmin		INT
	,@job_owner		sysname


----------------  initial values  -------------------
Select @error_count = 0


--  Check input parameters
If @rq_servername is null or @rq_servername = ''
   begin
	Print 'DBA Warning:  Invalid input parameter.  @rq_servername parm must be a valid SQL instance name.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @rq_stamp is null or @rq_stamp = ''
   begin
	Print 'DBA Warning:  Invalid input parameter.  @rq_stamp parm must be a valid time stamp from the requesting server.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @rq_type is null or @rq_type not in ('job', 'db_status', 'db_query')
   begin
	Print 'DBA Warning:  Invalid input parameter.  @rq_type parm must be ''job'' or ''db_query''.'
	Select @error_count = @error_count + 1
	Goto label99
   end


If @rq_detail01 is null
   begin
	Print 'DBA Warning:  Invalid input parameter.  @rq_detail01 parm cannot be null.'
	Select @error_count = @error_count + 1
	Goto label99
   end


-- Create intermediate work tables for job info
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


CREATE TABLE #db_query (detail01    sysname)


--  Create table variables
declare @jobinfo table	(jobname		sysname
			,instance_ID		int
			,Job_ID			varchar(50)
			,step_name		sysname
			,step_id		int
			,sql_message_id		int
			,sql_severity		int
			,message		nvarchar(4000)
			,run_status		int
			,run_date		int
			,run_time		int
			,primary key 	(instance_ID)
			)


declare @jobstatus table (jobname		sysname
			,last_run_date		INT
			,last_run_time		INT
			,running		INT
			,current_step		INT
			,current_retry_attempt	INT
			,job_state		INT
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


If @rq_type = 'job'
   begin
	Select @hold_detail01 = @rq_detail01 + '%'
	Select @save_detail01 = ''
	Select @save_detail02 = ''


	-- Capture job execution information (for local jobs only since that's all SQLServerAgent caches)
	SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
	SELECT @job_owner = SUSER_SNAME()

	INSERT INTO #xp_results exec master.sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner


	--select * from #xp_results


	-- Refine job execution information and include job names
	Insert into @jobstatus (jobname, last_run_date, last_run_time, running, current_step, current_retry_attempt, job_state)
	SELECT j.name, x.last_run_date, x.last_run_time, x.running, x.current_step, x.current_retry_attempt, x.job_state
	From #xp_results x,  msdb.dbo.sysjobs j with (NOLOCK)
	Where x.job_id = j.job_id
	  and j.name like @hold_detail01


	--select * from @jobstatus


	--  Capture job history info
	Insert into @jobinfo (jobname, instance_ID, Job_ID, step_name, step_id, sql_message_id, sql_severity, message, run_status, run_date, run_time)
	SELECT j.name, h.instance_ID, convert(varchar(50),h.Job_ID), h.step_name, h.step_id, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
	From msdb.dbo.sysjobhistory  h with (NOLOCK),  msdb.dbo.sysjobs j with (NOLOCK)
	Where h.job_id = j.job_id
	  and j.name like @hold_detail01


	--select * from @jobinfo


	--  Do the job(s) esist?  If no jobs are found, report that and we are done
	If (select count(*) from @jobstatus) = 0
	   begin
		Select @save_detail01 = 'No jobs found on ' + @@servername + ' like ''''' + @rq_detail01 + ''''''
		goto return_data
	   end


	--  Is the job running now?  If the job is currently running, report the job name and step name.
	If (select count(*) from @jobstatus where running > 0) > 0
	   begin
		Select @save_jobname = (select top 1 jobname from @jobstatus where running > 0 order by jobname)
		Select @save_current_step = (select current_step from @jobstatus where jobname = @save_jobname)
		Select @save_detail01 = 'JOB Running on ' + @@servername + ': ' + @save_jobname + '  STEP#: ' + convert(varchar(5), @save_current_step)
		goto return_data
	   end


	--  Have the job(s) ever run?  If no previous execution is found, report that and we are done
	If (select count(*) from @jobstatus where last_run_date > 0) = 0
	   begin
		Select @save_detail01 = 'Requested job(s) on ' + @@servername + ' have never run (i.e. ''''' + @rq_detail01 + ''''')'
		goto return_data
	   end


	--  Do we have a job failure?  If we see a job failure, report that and we are done
	If (select top 1 run_status from @jobinfo where step_name <> '(Job outcome)' order by instance_ID desc) = 0  -- 0 is for failed job step
	   begin
		Select @save_jobname = (select top 1 jobname from @jobinfo where run_status = 0 and step_name <> '(Job outcome)' order by instance_ID desc)
		Select @save_current_step = (select top 1 step_id from @jobinfo where jobname = @save_jobname and run_status = 0 and step_name <> '(Job outcome)' order by instance_ID desc)
		Select @save_detail01 = 'JOB Failed on ' + @@servername + ': ' + @save_jobname + '  STEP#: ' + convert(varchar(5), @save_current_step)
		goto return_data
	   end


	--  Just report the last job and step that ran
	Select @save_jobname = (select top 1 jobname from @jobinfo where step_name <> '(Job outcome)' order by instance_ID desc)
	Select @save_current_step = (select top 1 step_id from @jobinfo where jobname = @save_jobname and step_name <> '(Job outcome)' order by instance_ID desc)
	Select @save_run_date = (select top 1 run_date from @jobinfo where jobname = @save_jobname and step_name <> '(Job outcome)' order by instance_ID desc)
	Select @save_run_time = (select top 1 run_time from @jobinfo where jobname = @save_jobname and step_name <> '(Job outcome)' order by instance_ID desc)
	If len(@save_run_time) = 5
	   begin
		Select @save_run_time = '0' + @save_run_time
	   end
	Else If len(@save_run_time) = 4
	   begin
		Select @save_run_time = '00' + @save_run_time
	   end
	Else If len(@save_run_time) = 3
	   begin
		Select @save_run_time = '000' + @save_run_time
	   end
	Else If len(@save_run_time) = 2
	   begin
		Select @save_run_time = '0000' + @save_run_time
	   end
	Else If len(@save_run_time) = 1
	   begin
		Select @save_run_time = '00000' + @save_run_time
	   end


	Select @save_detail01 = 'Last Job Completed on ' + @@servername + ': ' + @save_jobname + '  STEP#: ' + convert(varchar(5), @save_current_step) + '  RAN: ' + @save_run_date + '_' + @save_run_time


	return_data:


	--  Return data to the requesting sql instance
	select @query = 'Insert DBAOps.dbo.pong_return values (''' + @rq_stamp + ''', ''' + @@servername + ''', ''' + @save_detail01 + ''', ''' + @save_detail02 + ''')'
	--Print @query
	Select @cmd = 'sqlcmd -S' + @rq_servername + ' -dDBAOps -E -Q"' + @query + '"'
	print @cmd
	EXEC master.sys.xp_cmdshell @cmd--, no_output


	goto label99
   end


If @rq_type = 'db_query'
   begin
	insert into #db_query exec (@rq_detail01)


	If (select count(*) from #db_query) > 0
	   begin
		--  Return data to the requesting sql instance
	    	Select @save_detail01 = (select top 1 detail01 from #db_query)
		Select @save_detail02 = ''
		select @query = 'Insert DBAOps.dbo.pong_return values (''' + @rq_stamp + ''', ''' + @@servername + ''', ''' + @save_detail01 + ''', ''' + @save_detail02 + ''')'
		--Print @query
		Select @cmd = 'sqlcmd -S' + @rq_servername + ' -dDBAOps -E -Q"' + @query + '"'
		print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output
	   end


	goto label99
   end


If @rq_type = 'db_status'
   begin


	--  To be developed...


	goto label99
   end


--  Finalization  ----------------------------------------------------------------------
label99:


drop table #xp_results
drop table #db_query


/***
how to execute a type 'db_query'


Select @save_rq_stamp = convert(sysname, getdate(), 121) + convert(nvarchar(40), newid())
Select @db_query1 = 'select top 1 name from master.sys.databases'
Select @db_query2 = ''
select @query = 'exec DBAOps.dbo.dbasp_pong @rq_servername = ''' + @@servername
	    + ''', @rq_stamp = ''' + @save_rq_stamp
	    + ''', @rq_type = ''db_query'', @rq_detail01 = ''' + @db_query1 + ''', @rq_detail02 = ''' + @db_query2 + ''''
Select @miscprint = 'Requesting info from serverxyz.'
Print @miscprint
Select @cmd = 'sqlcmd -Sserverxyz -E -Q"' + @query + '"'
print @cmd
EXEC master.sys.xp_cmdshell @cmd, no_output


--  capture pong results
select @pong_count = 0
start_pong_result:
Waitfor delay '00:00:05'
If exists (select 1 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
   begin
	Select @save_more_info = (select pong_detail01 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
   end
Else If @pong_count < 5
   begin
	Select @pong_count = @pong_count + 1
	goto start_pong_result
   end
***/
GO
GRANT EXECUTE ON  [dbo].[dbasp_pong] TO [public]
GO
