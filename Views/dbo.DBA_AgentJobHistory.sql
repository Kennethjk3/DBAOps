SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   VIEW [dbo].[DBA_AgentJobHistory]
AS
WITH JobRuns
AS (SELECT			j.name
				   ,jh.step_id
				   ,jh.step_name
				   ,jh.run_date
				   ,jh.run_time
				   ,DATEADD(
							   SECOND
							  ,CONVERT(Int, RIGHT('0000000' + CONVERT(Varchar(6), jh.run_time), 2))
							  ,DATEADD(
										  MINUTE
										 ,CONVERT(Int, SUBSTRING(RIGHT('000000' + CONVERT(Varchar(6), jh.run_time), 6), 3, 2))
										 ,DATEADD(
													 HOUR
													,CONVERT(
																Int
															   ,LEFT(RIGHT('000000' + CONVERT(Varchar(6), jh.run_time), 6), 2)
															)
													,CONVERT(DateTime, CONVERT(Char(8), jh.run_date))
												 )
									  )
						   ) AS RunStartDateTime
				   ,jh.run_duration
				   ,DATEADD(
							   SECOND
							  ,CONVERT(Int, RIGHT('000000' + CONVERT(Varchar(20), jh.run_duration), 2))
							  ,DATEADD(
										  MINUTE
										 ,CONVERT(
													 Int
													,SUBSTRING(RIGHT('000000' + CONVERT(Varchar(20), jh.run_duration), 6), 3, 2)
												 )
										 ,DATEADD(
													 HOUR
													,CONVERT(
																Int
															   ,LEFT(RIGHT('000000' + CONVERT(Varchar(20), jh.run_duration), 6), 2)
															)
													,DATEADD(
																DAY
															   ,jh.run_duration / 1000000
																-- the rest is the start date/time, above
															   ,DATEADD(
																		   SECOND
																		  ,CONVERT(
																					  Int
																					 ,RIGHT('0'
																							+ CONVERT(Varchar(6), jh.run_time), 2)
																				  )
																		  ,DATEADD(
																					  MINUTE
																					 ,CONVERT(
																								 Int
																								,SUBSTRING(
																											  RIGHT('000000'
																													+ CONVERT(
																																 Varchar(6)
																																,jh.run_time
																															 ), 6)
																											 ,3
																											 ,2
																										  )
																							 )
																					 ,DATEADD(
																								 HOUR
																								,CONVERT(
																											Int
																										   ,LEFT(RIGHT('000000'
																													   + CONVERT(
																																	Varchar(6)
																																   ,jh.run_time
																																), 6), 2)
																										)
																								,CONVERT(
																											DateTime
																										   ,CONVERT(
																													   Char(8)
																													  ,jh.run_date
																												   )
																										)
																							 )
																				  )
																	   )
															)
												 )
									  )
						   ) AS RunFinishDateTime
				   ,jh.sql_message_id
				   ,jh.sql_severity
				   ,jh.message
				   ,jh.run_status
	FROM			msdb.dbo.sysjobhistory jh
		LEFT JOIN	msdb.dbo.sysjobs	   j
			ON j.job_id = jh.job_id)
SELECT	JobRuns.name														[JobName]
	   ,CAST(JobRuns.RunStartDateTime AS Date)								[StartDate]
	   ,CAST(JobRuns.RunStartDateTime AS Time)								[StartTime]
	   ,CAST(JobRuns.RunFinishDateTime AS Date)								[EndDate]
	   ,CAST(JobRuns.RunFinishDateTime AS Time)								[EndTime]
	   ,DATEDIFF(MINUTE,JobRuns.RunStartDateTime,JobRuns.RunFinishDateTime)	[Duration]
FROM	JobRuns
WHERE	JobRuns.name NOT IN ('MAINT - Rapid Stats Updates','UTIL - DBA Daily 5min Processing','MAINT - TranLog Backup','UTIL - PERF Daily 5min Processing'
									,'','','','','','','','','','','','','','','')
		AND JobRuns.step_id = 0;
GO
