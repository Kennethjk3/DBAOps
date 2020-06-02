SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   VIEW [dbo].[dbavw_AgentJobFailReport]
AS
SELECT		DISTINCT
			T1.server															AS [Server Name],
			SUBSTRING(T2.name,1,140)											AS [SQL Job Name],
			CASE dbaops.dbo.dbaudf_GetJobStatus(T2.name)
				WHEN -2 THEN 'Job was not Found'
				WHEN -1 THEN 'Job is Disabled'
				WHEN  0 THEN 'Failed'
				WHEN  1 THEN 'Succeeded'
				WHEN  2 THEN 'Retry'
				WHEN  3 THEN 'Canceled'
				WHEN  4 THEN 'In progress'
				WHEN  5 THEN 'Disabled'
				WHEN  6 THEN 'Idle'
				ELSE 'Unknown' END												AS [Current Job Status],
			T1.step_id															AS [Step_id],
			T1.step_name														AS [Step Name],
			CAST(CONVERT(DATETIME,CAST(run_date AS CHAR(8)),101) AS CHAR(11))	AS [Failure Date],
			msdb.dbo.agent_datetime(T1.run_date, T1.run_time)					AS 'RunDateTime',
			T1.run_duration														AS StepDuration,
			CASE T1.run_status
				WHEN 0 THEN 'Failed'
				WHEN 1 THEN 'Succeeded'
				WHEN 2 THEN 'Retry'
				WHEN 3 THEN 'Cancelled'
				WHEN 4 THEN 'In Progress'
				END																AS ExecutionStatus,
			T1.message															AS [Error Message]
FROM		msdb..sysjobhistory T1
JOIN		msdb..sysjobs T2				ON T1.job_id = T2.job_id
WHERE		T1.run_status	NOT IN (1, 4)
	AND		T1.step_id		!= 0
	AND		(
			msdb.dbo.agent_datetime(T1.run_date, T1.run_time)		>= DATEADD (DAY,(-1), GETDATE())
		OR		(
					SUBSTRING(T2.name,1,140) Like '%weekly%'
				AND	msdb.dbo.agent_datetime(T1.run_date, T1.run_time)		>= DATEADD (WEEK,(-1), GETDATE())
				)
			)
	AND		T2.name			Not Like 'collection_set%'
	AND		dbaops.dbo.dbaudf_GetJobStatus(T2.name) NOT IN(-1,-2,5) -- NOT DISABLED
GO
GRANT SELECT ON  [dbo].[dbavw_AgentJobFailReport] TO [public]
GO
