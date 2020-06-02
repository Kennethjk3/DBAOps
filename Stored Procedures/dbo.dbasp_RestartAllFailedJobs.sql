SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_RestartAllFailedJobs]
		(
		@ExcludeFilter	SYSNAME = NULL
		)
AS
DECLARE		@JobName	SYSNAME
		,@StepName	SYSNAME


DECLARE RestartFailedJobCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		[JobName]
		,[StepName]
FROM		(
		SELECT        O.name [JobName]
			      ,(SELECT step_name FROM MSDB.DBO.SYSJOBSTEPS WHERE job_id = O.job_id and step_id = COALESCE(OA0.last_executed_step_id,1)) [StepName]
			      ,OA0.last_executed_step_id Current_LastStep
			      ,OA.last_executed_step_id Last_LastStep
			      ,CASE
				   WHEN OA0.run_requested_date IS NULL THEN 'Idle'
				   WHEN JH0.RUN_STATUS = 0 THEN 'Failed'
				   WHEN JH0.RUN_STATUS = 1 THEN 'Succeeded'
				   WHEN JH0.RUN_STATUS = 2 THEN 'Retry'
				   WHEN JH0.RUN_STATUS = 3 THEN 'Canceled'
				   WHEN JH0.RUN_STATUS = 4 THEN 'Running'
				   WHEN JH0.RUN_STATUS IS NULL AND OA0.start_execution_date IS NOT NULL AND OA0.stop_execution_date IS NULL THEN 'Running'
				   ELSE 'Unknown'
				   END Current_Run_Status
			      ,CASE
				   WHEN OA.run_requested_date IS NULL THEN 'Idle'
				   WHEN JH.RUN_STATUS = 0 THEN 'Failed'
				   WHEN JH.RUN_STATUS = 1 THEN 'Succeeded'
				   WHEN JH.RUN_STATUS = 2 THEN 'Retry'
				   WHEN JH.RUN_STATUS = 3 THEN 'Canceled'
				   WHEN JH.RUN_STATUS = 4 THEN 'Running'
				   WHEN JH.RUN_STATUS IS NULL AND OA.start_execution_date IS NOT NULL AND OA.stop_execution_date IS NULL THEN 'Running'
				   ELSE 'Unknown'
				   END Last_RunStatus
			      ,(SELECT MAX(Step_id) FROM MSDB.DBO.SYSJOBSTEPS WHERE job_id = O.job_id) [MaxStep]
		FROM          MSDB.DBO.SYSJOBS O
		LEFT JOIN     (
			      SELECT        *
			      FROM          MSDB.DBO.SYSJOBACTIVITY
			      WHERE         Session_ID = (SELECT MAX(SESSION_ID)-1 FROM MSDB.DBO.SYSSESSIONS)
			      ) OA
		       ON     O.job_id = OA.job_id
		LEFT JOIN     (
			      SELECT        *
			      FROM          MSDB.DBO.SYSJOBACTIVITY
			      WHERE         Session_ID = (SELECT MAX(SESSION_ID) FROM MSDB.DBO.SYSSESSIONS)
			      ) OA0
		       ON     O.job_id = OA0.job_id


		LEFT JOIN     MSDB.DBO.SYSJOBHISTORY JH
		       ON     OA.job_history_id = JH.instance_id


		LEFT JOIN     MSDB.DBO.SYSJOBHISTORY JH0
		       ON     OA0.job_history_id = JH0.instance_id
		) Data
WHERE		Current_Run_Status = 'Failed'		-- LAST RUN WAS NOT SUCESSFULL
	AND	[JobName] NOT LIKE ISNULL(NULLIF(@ExcludeFilter,''),'XXXXXXXXXXXXXXXX')

OPEN RestartFailedJobCursor;
FETCH RestartFailedJobCursor INTO @JobName,@StepName;
WHILE (@@fetch_status <> -1)
BEGIN
       IF (@@fetch_status <> -2)
       BEGIN
              ----------------------------
              ---------------------------- CURSOR LOOP TOP
       	BEGIN TRY
		RAISERROR ('Re-Starting Job "%s" at Step "%s".',-1,-1,@JobName,@StepName) WITH NOWAIT
		exec msdb.dbo.sp_start_job @Job_name = @JobName, @step_name = @StepName
	END TRY
	BEGIN CATCH
		SELECT @@ERROR
		RAISERROR ('Unable to Re-StartiJob "%s" at Step "%s".',-1,-1,@JobName,@StepName) WITH NOWAIT
	END CATCH


              ---------------------------- CURSOR LOOP BOTTOM
              ----------------------------
       END
      FETCH NEXT FROM RestartFailedJobCursor INTO @JobName,@StepName;
END
CLOSE RestartFailedJobCursor;
DEALLOCATE RestartFailedJobCursor;
GO
GRANT EXECUTE ON  [dbo].[dbasp_RestartAllFailedJobs] TO [public]
GO
