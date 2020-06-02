SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
 
-- Adds a first step to specified job, which checks whether running on Primary replica
 
CREATE   PROCEDURE [dbo].[dbasp_AddAGPrimaryCheckStepToAgentJob]
    @jobname nvarchar(128)
as
 
set nocount on;
 
---- Do nothing if No AG groups defined
--IF SERVERPROPERTY ('IsHadrEnabled') = 1
--begin
    declare @jobid uniqueidentifier = (select sj.job_id from msdb.dbo.sysjobs sj where sj.name = @jobname)
 
    if not exists(select * from msdb.dbo.sysjobsteps where job_id = @jobid and step_name = 'Check If AG Primary' )
    begin
        -- Add new first step: on success go to next step, on failure quit reporting success
        exec msdb.dbo.sp_add_jobstep 
          @job_id = @jobid
        , @step_id = 1
        , @cmdexec_success_code = 0
        , @step_name = 'Check If AG Primary'
        , @on_success_action = 3  -- On success, go to Next Step
        , @on_success_step_id = 2
        , @on_fail_action = 1     -- On failure, Quit with Success  
        , @on_fail_step_id = 0
        , @retry_attempts = 0
        , @retry_interval = 0
        , @os_run_priority = 0
        , @subsystem = N'TSQL'
        , @command=N'DECLARE		@ShouldRun		Bit
DECLARE		@ShouldRun2		Bit
SELECT		@ShouldRun =
			CASE	WHEN [DBAOps].[dbo].[dbaudf_AG_Get_Primary](STUFF(c.name,1,3,'''')) LIKE ''ERROR%''		THEN 1
					WHEN [DBAOps].[dbo].[dbaudf_AG_Get_Primary](STUFF(c.name,1,3,'''')) = @@SERVERNAME	THEN 1
					ELSE 0 END
			,@ShouldRun2 = 
			CASE	WHEN j.name LIKE ''UTIL%''															THEN 1
					WHEN j.name LIKE ''MAINT%''															THEN 1
					WHEN CHARINDEX(''<ExecuteInLowers>'',j.description) > 0								THEN 1
					ELSE 0 END
			
FROM		msdb.dbo.sysjobs j
JOIN		msdb.dbo.syscategories c				ON c.category_id = j.category_id
WHERE		j.job_id = $(ESCAPE_SQUOTE(JOBID))

IF @ShouldRun = 0
	raiserror (''Not the AG primary'', 2, 1)
	
IF DBAOps.dbo.dbaudf_GetServerEnv() != ''PRO'' AND @ShouldRun2 = 0 
	raiserror (''Not In PRO Environment'', 2, 1)'
        , @database_name=N'master'
        , @flags=0
    end
--end
GO
