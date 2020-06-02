SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_StartJob]
	(
	@job_name		VarChar(500)
	,@WaitToFinish		bit		= 0
	,@WaitMaxMinutes	INT		= 30
	,@CheckDelay		VarChar(10)	= '00:01:00'
	)
/*********************************************************
 **  Stored Procedure dbasp_StartJob
 **  Written by Steve Ledridge, Virtuoso
 **  April 14, 2014
 **  This procedure starts an Agent Job if it is not already
 **  running, and optionally waits for it to complete.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/14/2014	Steve Ledridge		New process
--	======================================================================================
--
--	RETURN CODES
--		0	NO ERRORS
--		-1	BAD JOB NAME
--		-2	EXCEDED WAIT MAXIMUM TIME


Declare @job_status sysname
Declare @Minutes int


if not exists(SELECT * From msdb.dbo.sysjobs where name = @job_name)
	BEGIN
		raiserror('"%s" is not a valid job name.',-1,-1,@job_name) WITH NOWAIT
		RETURN -1
	END


EXEC [DBAOps].[dbo].[dbasp_Check_Jobstate] @job_name = @job_name,@job_status = @job_status OUTPUT;


raiserror('Job status for SQL job "%s" = %s',-1,-1,@job_name,@job_status) WITH NOWAIT


If @job_status = 'idle'
   begin
	raiserror('Starting SQL job "%s"',-1,-1,@job_name) WITH NOWAIT
	EXEC msdb.dbo.sp_start_job @job_name = @job_name
	WAITFOR DELAY '00:00:05'
   end
else
   begin
	Select @Minutes = (SELECT DATEDIFF(Minute,aj.start_execution_date,GetDate()) --AS Minutes
				FROM msdb..sysjobactivity aj
				JOIN msdb..sysjobs sj on sj.job_id = aj.job_id
				WHERE aj.stop_execution_date IS NULL -- job hasn't stopped running
				AND aj.start_execution_date IS NOT NULL -- job is currently running
				AND sj.name = @job_name
				and not exists( -- make sure this is the most recent run
				    select 1
				    from msdb..sysjobactivity new
				    where new.job_id = aj.job_id
				    and new.start_execution_date > aj.start_execution_date))


	raiserror('Job "%s" has already been running for %d minutes. Skipping Job Start',-1,-1,@job_name,@Minutes) WITH NOWAIT
   end


EXEC [DBAOps].[dbo].[dbasp_Check_Jobstate] @job_name = @job_name,@job_status = @job_status OUTPUT;


if @WaitToFinish = 1
BEGIN
	WHILE @job_status = 'active'
	BEGIN
		Select @Minutes = (SELECT DATEDIFF(Minute,aj.start_execution_date,GetDate()) --AS Minutes
				FROM msdb..sysjobactivity aj
				JOIN msdb..sysjobs sj on sj.job_id = aj.job_id
				WHERE aj.stop_execution_date IS NULL -- job hasn't stopped running
				AND aj.start_execution_date IS NOT NULL -- job is currently running
				AND sj.name = @job_name
				and not exists( -- make sure this is the most recent run
				    select 1
				    from msdb..sysjobactivity new
				    where new.job_id = aj.job_id
				    and new.start_execution_date > aj.start_execution_date))


		RAISERROR('  -- Job "%s" has been running for %d minutes. Waiting for Completion.',-1,-1,@job_name,@Minutes) WITH NOWAIT;


		if @Minutes > @WaitMaxMinutes
		BEGIN
			raiserror('Job "%s" has exceded wait limit of %d minutes. No Longer waiting, Job is Still Running.',-1,-1,@job_name,@WaitMaxMinutes) WITH NOWAIT
			RETURN -2
		END


		WAITFOR DELAY @CheckDelay;
		EXEC [DBAOps].[dbo].[dbasp_Check_Jobstate] @job_name = @job_name,@job_status = @job_status OUTPUT;
	END;


	RAISERROR('    -- Job "%s" Has Completed.',-1,-1,@job_name) WITH NOWAIT;
END


RETURN 0
GO
GRANT EXECUTE ON  [dbo].[dbasp_StartJob] TO [public]
GO
