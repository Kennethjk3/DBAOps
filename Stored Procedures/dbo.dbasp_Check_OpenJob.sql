SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_OpenJob] (@job_run_hours int = 4)

/*********************************************************
 **  Stored Procedure dbasp_Check_OpenJob
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 23, 2002
 **
 **  This dbasp is set up to check for long running jobs.
 **  The default time period is four hours.  If needed, the default
 **  can be modified by using an input parameter.
 **
 **  Example syntax to run this proc is:
 **  exec DBAOps..dbasp_CheckOpenJob @job_run_hours = 6
 **
 ***************************************************************/
  as
set nocount on


/**
declare @job_run_hours int


select @job_run_hours = 4
--**/


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/23/2002	Steve Ledridge		Check for long running jobs created
--	09/26/2002	Steve Ledridge		Shortened long lines to 255
--	06/20/2006	Steve Ledridge		Converted to SQL 2005.  Now capture top 1 from sysjobactivity
--						for most recent session_id.
--	04/18/2008	Steve Ledridge		Added skip for known long running jobs.
--	07/27/2009	Steve Ledridge		Added No_check table reference.
--	======================================================================================


DECLARE
	 @miscprint		varchar(500)
	,@is_sysadmin		int
	,@job_owner		sysname
	,@save_job_start	varchar(30)
	,@save_job_date		datetime
	,@run_length		int


DECLARE
	 @cu11job_id			UNIQUEIDENTIFIER
	,@cu11name			sysname
	,@cu11start_execution_date	datetime


-- Step 1: Create intermediate work tables
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


-- Step 2: Capture job execution information (for local jobs only since that's all SQLServerAgent caches)
SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
SELECT @job_owner = SUSER_SNAME()

INSERT INTO #xp_results
   EXECUTE master.sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner


--  Remove row for jobs that are not running
delete from #xp_results where running <> 1
--select * from #xp_results


--------------------  Cursor for job info  -------------------


EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT x.job_id, j.name
   From #xp_results  x, msdb.dbo.sysjobs  j ' +
  'Where x.job_id = j.job_id
   Order By j.name For Read Only')


OPEN cu11_cursor


WHILE (11=11)
 Begin
	FETCH Next From cu11_cursor Into @cu11job_id, @cu11name
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_cursor
	      BREAK
           end


	--  Capture the start date for the current execution
	Select @cu11start_execution_date = (select top 1 start_execution_date from msdb.dbo.sysjobactivity
											where job_id = @cu11job_id
											order by session_id desc
										)


	If exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type like 'check_job_nocheck%' and env_detail = @cu11name)
	   begin
		goto skip_job
	   end


	If exists (select 1 from DBAOps.dbo.no_check where NoCheck_type like 'sql_job_nocheck%' and detail01 = @cu11name)
	   begin
		goto skip_job
	   end


	--  Now check to see if this job has run long
	Select @run_length = datediff (hh, @cu11start_execution_date, getdate())


	If @run_length > @job_run_hours
	   begin
		select @miscprint = 'DBA WARNING: Job ''' + @cu11name + ''' has been running for ' + convert(varchar(10), @run_length) + ' hours.'
		raiserror(@miscprint,-1,-1) with log
		Print @miscprint
	   end


	skip_job:


 End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cu11_cursor


DROP TABLE #xp_results
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_OpenJob] TO [public]
GO
