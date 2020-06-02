SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_PruneAgentJobHistory]
AS


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/07/2016	Steve Ledridge		Added code for msdb.dbo.sysssislog clean up
--	======================================================================================


BEGIN
	-- Do not lock anything, and do not get held up by any locks.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET NOCOUNT ON
	SET Ansi_warnings OFF


		Declare @save_productversion		sysname
			,@cmd				nvarchar(4000)


		Create table #JobHistoryCounts (
				job_id uniqueidentifier,
				job_name sysname null,
				rows int null,
				executions int null)


		Print ''
		Print '**************************************************************'
		Print 'Start the MSDB Pruning process. ' + convert(nvarchar(20), getdate(), 121)
		Print '**************************************************************'
		Print ''


		-- REMOVE OLD DATA FROM msdb.dbo.sysssislog
		SELECT @save_productversion = convert(sysname, SERVERPROPERTY ('productversion'))
		IF	@save_productversion > '10.0.0000' --sql2008 or higher
		  and	@save_productversion not like '9.00.%'
		   BEGIN


			RAISERROR('REMOVING ALL RECORDS FROM msdb.dbo.sysssislog older than 90 days',-1,-1) WITH NOWAIT


			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT HAVE TABLE msdb.dbo.sysssislog
			SELECT @cmd = 'SET NOCOUNT ON


declare @save_id int
declare @BatchSize INT
select @BatchSize = 10000


select @save_id = (select MAX(id) from msdb.dbo.sysssislog WHERE starttime < getdate()-90)


If @save_id is not null
BEGIN
	delete_start:
	delete TOP(@BatchSize)
	from msdb.dbo.sysssislog
	where id <= @save_id


	IF @@rowcount = @BatchSize
	   begin
		RAISERROR(''   -- DONE WITH BATCH OF %d.'',-1,-1,@BatchSize) WITH NOWAIT
		goto delete_start
	   end
END'


			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd

			RAISERROR('DONE REMOVING ALL RECORDS FROM msdb.dbo.sysssislog older than 90 days',-1,-1) WITH NOWAIT
		   END
		Else
		   BEGIN
			RAISERROR('Skipping the delete from msdb.dbo.sysssislog section',-1,-1) WITH NOWAIT
		   END


		-- RESET HISTORY MAXIMUMS FOR AUTO PRUNING AS SAFETY NET
		EXEC msdb.dbo.sp_set_sqlagent_properties
				@jobhistory_max_rows = 50000
				,@jobhistory_max_rows_per_job = 1500


		--  Remove Orphaned job history
		delete from [msdb].[dbo].[sysjobhistory] where job_id not in (select job_id from [msdb].[dbo].sysjobs)


		-- SAVE BEFORE COUNTS
		Insert INTO #JobHistoryCounts
			SELECT [job_id]
			,(SELECT name from [msdb].[dbo].sysjobs where job_id = T1.job_id ) [job_name]
			,COUNT(*) [rows]
			,COUNT(case when step_id = 0 then 1 end) [executions]
		  FROM [msdb].[dbo].[sysjobhistory] T1
		  GROUP BY [job_id]
		  --WITH ROLLUP
		  ORDER BY 2
		  --select * from #JobHistoryCounts


		-- DELETE RECORDS
		;WITH		JobStepCount
					AS
					(
					SELECT		job_id
								,count(*) job_steps
					FROM		msdb.dbo.sysjobsteps
					GROUP BY	job_id
					)
					,RankedHistory
					AS
					(
					SELECT		row_number() OVER(PARTITION BY H.job_id ORDER BY H.instance_id desc)	AS InstanceRank
								,H.*
					FROM		[msdb].[dbo].[sysjobhistory] H
					)
		DELETE		H
			OUTPUT	'SET IDENTITY_INSERT msdb.dbo.sysjobhistory ON;INSERT INTO [msdb].[dbo].[sysjobhistory]([instance_id],[job_id],[step_id],[step_name],[sql_message_id],[sql_severity],[message],[run_status],[run_date],[run_time],[run_duration],[operator_id_emailed],[operator_id_netsent],[operator_id_paged],[retries_attempted],[server]) VALUES('
					+CAST(COALESCE(DELETED.instance_id,'') AS VarChar(max))+','
					+QUOTENAME(CAST(COALESCE(DELETED.job_id,'') AS VarChar(max)),'''')+','
					+CAST(COALESCE(DELETED.step_id,'') AS VarChar(max))+','
					+QUOTENAME(CAST(COALESCE(DELETED.step_name,'') AS VarChar(max)),'''')+','
					+CAST(COALESCE(DELETED.sql_message_id,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.sql_severity,'') AS VarChar(max))+','
					+COALESCE(QUOTENAME(CAST(COALESCE(DELETED.message,'') AS VarChar(max)),''''),'''''')+','
					+CAST(COALESCE(DELETED.run_status,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.run_date,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.run_time,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.run_duration,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.operator_id_emailed,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.operator_id_netsent,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.operator_id_paged,'') AS VarChar(max))+','
					+CAST(COALESCE(DELETED.retries_attempted,'') AS VarChar(max))+','
					+QUOTENAME(CAST(COALESCE(DELETED.server,'') AS VarChar(max)),'''')+');SET IDENTITY_INSERT msdb.dbo.sysjobhistory OFF;' AS [-- Execute This Command To Replace Removed Records]
		--SELECT		H.*
		FROM		RankedHistory H
		JOIN		JobStepCount S
				ON	S.job_id = H.job_id
		WHERE		--DATEDIFF(HOUR,msdb.dbo.agent_datetime(H.run_date,H.run_time),GETDATE())> 24 -- USE TO BASE ON START TIME INSTEAD OF END TIME
					DATEDIFF(HOUR,DATEADD(s,DATEDIFF(s,msdb.dbo.agent_datetime(run_date,0),msdb.dbo.agent_datetime(run_date,run_duration%240000)+(run_duration/240000)),msdb.dbo.agent_datetime(run_date,run_time)),GETDATE())> 24
				AND H.InstanceRank > (S.job_steps+1)*100


		-- CALCULATE AND REPORT WHAT JOBS GOT HISTORY PRUNED
		If (select count(*) FROM #JobHistoryCounts T1
				    LEFT JOIN (SELECT [job_id]
					,(SELECT name from [msdb].[dbo].sysjobs where job_id = T1.job_id ) [job_name]
					,COUNT(*) [rows]
					,COUNT(case when step_id = 0 then 1 end) [executions]
						  FROM [msdb].[dbo].[sysjobhistory] T1
						  GROUP BY [job_id]
						  --WITH ROLLUP
						) T2
				ON T2.job_id = T1.job_id
				WHERE t1.rows != t2.rows
				   OR t1.executions != t2.executions) > 0
		   begin
			SELECT		T1.job_name
						,t1.rows AS rows_before
						,t2.rows AS rows_after
						,t1.rows - t2.rows AS rows_diff
						,t1.executions AS execs_before
						,t2.executions AS execs_after
						,t1.executions - t2.executions AS execs_diff
			FROM		#JobHistoryCounts T1
			LEFT JOIN (SELECT [job_id]
					,(SELECT name from [msdb].[dbo].sysjobs where job_id = T1.job_id ) [job_name]
					,COUNT(*) [rows]
					,COUNT(case when step_id = 0 then 1 end) [executions]
						  FROM [msdb].[dbo].[sysjobhistory] T1
						  GROUP BY [job_id]
						  --WITH ROLLUP
						) T2
				ON T2.job_id = T1.job_id
			WHERE t1.rows != t2.rows
			   OR t1.executions != t2.executions
			ORDER BY	1
		   end
		Else
		   begin
			Print ''
			Print 'DBA Note: No msdb history rows to process at this time.'
		   end


		DROP TABLE #JobHistoryCounts
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_PruneAgentJobHistory] TO [public]
GO
