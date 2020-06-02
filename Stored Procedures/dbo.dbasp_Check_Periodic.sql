SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Periodic]
					(
					@check_repl_errors char(1) = 'y'
					,@check_jobstep_errors char(1) = 'y'
					,@Check_maintstep_errors char(1) = 'y'
					,@check_jobname_like sysname = 'APPL'
					)


/***************************************************************
 **  Stored Procedure dbasp_Check_Periodic
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 19, 2002
 **
 **  This dbasp is set up to;
 **
 **  Check for SQL job step failures
 **  Check for replication related errors
 **
 **  When problems are found, specific errors are raised to the
 **  SQL error log.
 ***************************************************************/
 AS


	SET NOCOUNT ON;
	-- Do not lock anything, and do not get held up by any locks.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	-- Do Not let this process be the winner in a deadlock
	SET DEADLOCK_PRIORITY LOW;

	SET ANSI_WARNINGS OFF


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/19/2002	Steve Ledridge		New process
--	06/11/2003	Steve Ledridge		Modify to check previous 48 hours for job step failures
--	10/17/2003	Steve Ledridge		Change conversion for @save_rundate
--	07/26/2003	Steve Ledridge		Add check for DBA, BASE and RSTR jobs
--	03/28/2005	Steve Ledridge		Major revision.  Now using table variables (mostly) with no cursors.
--	08/22/2006	Steve Ledridge		Udated for SQL 2005
--	02/09/2007	Steve Ledridge		Added check for DEPL job steps.
--	06/05/2007	Steve Ledridge		Added reporting for retying job steps.
--	12/19/2007	Steve Ledridge		Added spcl gmail alerting for BASE jobs.
--	12/21/2007	Steve Ledridge		Added exceptions to on-call lookup process.
--	02/06/2008	Steve Ledridge		Added skip raiserror for retries.
--	02/11/2008	Steve Ledridge		Added skip in depl and base section for retries.
--	09/24/2008	Steve Ledridge		Remove old status = 2 rows from the check process.
--	09/29/2008	Steve Ledridge		Added code for STRT jobs.
--	08/28/2009	Steve Ledridge		New code for APPL jobs - dev support emails.
--	09/16/2009	Steve Ledridge		Disabled new code for APPL jobs - dev support emails.
--	10/26/2009	Steve Ledridge		Increased all message variables to nvarchar(4000).
--	02/01/2010	Steve Ledridge		Re-enabled code for APPL jobs - dev support emails.
--	03/19/2010	Steve Ledridge		Updated APPL jobs - dev support emails to go to SQLDevAdmin.
--	08/04/2010	Steve Ledridge		Updated gmail address.
--	12/01/2011	Steve Ledridge		Skip APPL job email to dev if already reported same day.
--	01/18/2012	Steve Ledridge		Check check for run_status to "in (0,3)"
--	04/06/2012	Steve Ledridge		New section for the Archive/Health Check process.
--	04/17/2012	Steve Ledridge		Added delete for Mirror Failover Override row in local_serverenviro.
--	04/25/2012	Steve Ledridge		Changed 67022 to be only for MAINT jobs.
--	06/19/2012	Steve Ledridge		Added a Check and Prune for Agent Job History.
--	07/17/2012	Steve Ledridge		Modified Job Pruining to not output undo scripts or change summary output because of excessive size.
--	07/17/2012	Steve Ledridge		Added the DEADLOCK_PRIORITY Setting to prevent Winning Deadlocks
--	09/17/2012	Steve Ledridge		Modified all Message Variables from nvarchar(4000) to varchar(8000) to prevent errors for larger messages.
--	09/17/2012	Steve Ledridge		Added "SET ANSI_WARNINGS OFF" to prevent Null aggregaion warning.
--	11/05/2012	Steve Ledridge		Added fix to repair invalid agent run durations caused by daylight saving back an hour
--	12/07/2012	Steve Ledridge		Addd skip check for job 'MAINT - Backup Verify'.
--	01/31/2013	Steve Ledridge		Addd no_check for sqljobhistory.
--	03/11/2013	Steve Ledridge		Fixed bug with once a day email for job failures.  Now every 4 hours.
--	03/18/2013	Steve Ledridge		Added skip for cancelled index maint ptocess.
--	04/29/2013	Steve Ledridge		Changed DEPLinfo to DBAOps.
--	06/03/2013	Steve Ledridge		Added description to APPL job alert.
--	09/24/2013	Steve Ledridge		Code to skip alert for job 'UTIL - PERF Stat Capture Process'.
--	10/18/2013	Steve Ledridge		Added no_check for SQLjob.
--	10/25/2013	Steve Ledridge		Skip Archive check if Maint jobs are running.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	05/05/2014	Steve Ledridge		Added cleanup for expired noCheck rows.
--	05/19/2014	Steve Ledridge		Added code for alert 67028 (CLR Issue).
--	10/20/2015	Steve Ledridge		Added code for Mirroring and AGgroup alerting.
--	11/17/2015	Steve Ledridge		Removed code that called the old BOA server.
--	12/14/2015	Steve Ledridge		Added code for alert 67026 (BASE Issue).
--	02/22/2016	Steve Ledridge		Added code for alert 67027 (Backup Issue).
--	04/18/2016	Steve Ledridge		Chaned Error alerts to 16, -1.
--	06/30/2016	Steve Ledridge		Changed Job names to ignore for alerts.
--	07/14/2016	Steve Ledridge		New check for tranlog backup check (5 hours)
--	08/09/2016	Steve Ledridge		Updated tranlog no_check
--	10/24/2016	Steve Ledridge		New section for CRL-.NET check and fix
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	01/25/2017	Steve Ledridge		Added dbasp_CheckServiceBrokerQueues
--	======================================================================================


/***
Declare @check_repl_errors char(1)
Declare @check_jobstep_errors char(1)
Declare @Check_maintstep_errors char(1)
Declare @check_jobname_like sysname


Select @check_repl_errors = 'y'
Select @check_jobstep_errors = 'y'
Select @Check_maintstep_errors = 'y'
Select @check_jobname_like = 'APPL'
--Select @check_jobname_like = '*all*'
--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(8000)
	,@cmd				nvarchar(4000)
	,@query				varchar(8000)
	,@saverun_date			int
	,@saverun_time			int
	,@holdrun_date			int
	,@holdrun_time			int
	,@message			varchar(8000)
	,@message2			varchar(8000)
	,@message3			varchar(8000)
	,@jobtype			sysname
	,@charpos			int
	,@startpos			int
	,@cnvt_old_runtime 		sysname
	,@old_runtime 			sysname
	,@new_runtime 			sysname
	,@Hold_hhmmss 			varchar(8)
	,@reset_int			int
	,@reset_char			varchar(8)
	,@reset_date			datetime
	,@servername			sysname
	,@db_query1			varchar(8000)
	,@db_query2			sysname
	,@pong_count			smallint
	,@status1 			varchar(10)
	,@status2 			varchar(10)
	,@save_dbcount			int
	,@save_TlogDBname		sysname
	,@Recipients			VarChar(2000)
	,@Subject			VarChar(1000)
	,@MSG				VarChar(8000)
	,@a				int
	,@save_productversion		sysname


DECLARE
	 @save_name			sysname
	,@save_instance_ID		int
	,@save_Job_ID			varchar(50)
	,@save_step_name		sysname
	,@save_sql_message_id		int
	,@save_sql_severity		int
	,@save_message			varchar(8000)
	,@save_description		nvarchar(512)
	,@save_run_status		int
	,@save_run_date			int
	,@save_run_time			int
	,@save_msdistributiondbs	sysname
	,@save_rq_stamp			sysname
	,@save_more_info		sysname
	,@appl_name			sysname
	,@save_env_name			sysname
	,@save_sendmail_recipients	nvarchar(500)
	,@save_run_date_char		nvarchar(10)
	,@save_run_time_char		nvarchar(10)
	,@lastrundate			datetime


DECLARE
	 @save_time			datetime
	,@save_source_name		sysname
	,@save_error_code		sysname
	,@save_error_text		varchar(8000)


DECLARE
		 @central_server		SYSNAME


		,@ENVname			SYSNAME


		,@Path				VarChar(max)


		,@FileName			VarChar(max)


		,@sqlcmd			VarChar(8000)


/*********************************************************************
 *                Initialization
 ********************************************************************/
Select @message = ''
Select @message2 = ''
Select @message3 = ''
Select @servername = @@servername
Select @Recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}'


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @new_runtime = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


--  Create table variables
declare @jobinfo table	(jobname	sysname
			,instance_ID	int
			,Job_ID		varchar(50)
			,step_name	sysname
			,step_id	int
			,sql_message_id	int
			,sql_severity	int
			,message	varchar(8000)
			,run_status	int
			,run_date	int
			,run_time	int
			,primary key 	(instance_ID)
			)


declare @msdistributiondbs table (DBname sysname)


--  Create temp tables
create table #replerrors (time		datetime
			  ,source_name	sysname
			  ,error_code	sysname
			  ,error_text	varchar(8000)
			  )


CREATE TABLE	#CMDOutput	(
				cmdoutput nvarchar(max) null
				)


--  Set last-run date and time parameters  -------------------


Select @old_runtime = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_periodic_time')


If @old_runtime is null
   begin
	Select @old_runtime = @new_runtime
   end


select @cnvt_old_runtime = substring(@old_runtime, 1,4) + '-' + substring(@old_runtime, 5,2) + '-' + substring(@old_runtime, 7,2) + ' ' + substring(@old_runtime, 9,2) + ':' + substring(@old_runtime, 11,2) + ':' + substring(@old_runtime, 13,2) + '.000'


Select @saverun_date = convert(int,(substring(@old_runtime, 1, 8)))
Select @saverun_time = convert(int,(substring(@old_runtime, 9, 6)))
Select @holdrun_date = @saverun_date
Select @holdrun_time = @saverun_time


--Print convert(varchar(20), @saverun_date)
--Print convert(varchar(20), @saverun_time)
--print @cnvt_old_runtime


--  The following code was put in so that we check for job step failures in the
--  past 48 hours, and compare those against previously reported failures.
Select @reset_char = convert(varchar(8), @saverun_date)


Select @reset_date = convert(datetime, @reset_char)


Select @reset_date = DATEADD(day, -2, @reset_date)


Select @reset_char = convert(varchar(8), @reset_date, 112)


Select @saverun_date = convert(int, @reset_char)


--Print convert(varchar(20), @saverun_date)
--Print convert(varchar(20), @saverun_time)


/****************************************************************
 *  Clear out expired control records.
 ***************************************************************/


Delete from dbo.No_Check where NoCheck_type = 'BASEgmail' and datediff(hh, createdate, getdate()) < 4


/****************************************************************
 *  CHECK AND PRUNE JOB HISTORY
 ***************************************************************/


	-- RESET HISTORY MAXIMUMS FOR AUTO PRUNING AS SAFETY NET
	If not exists(select 1 from DBAOps.dbo.no_check where nocheck_type = 'SQLJobHistory')
	   begin
		EXEC msdb.dbo.sp_set_sqlagent_properties
				@jobhistory_max_rows		= 50000
				,@jobhistory_max_rows_per_job	= 1500
	   end


	-- SAVE BEFORE COUNTS
	SELECT		[job_id]
				,(SELECT name from [msdb].[dbo].sysjobs where job_id = T1.job_id ) [job_name]
				,COUNT(*) [rows]
				,COUNT(case when step_id = 0 then 1 end) [executions]
	INTO		#JobHistoryCounts
	  FROM [msdb].[dbo].[sysjobhistory] T1
	  GROUP BY [job_id]
	  WITH ROLLUP
	  ORDER BY 2


	-- FIX ANY INVALID DURATION ENTRIES (SEEN CASUED BY JOB RUNNING AS DAYLIGHT SAVING SET BACK AN HOUR)
	UPDATE [msdb].[dbo].[sysjobhistory]
	SET run_duration = 1
	WHERE run_duration < 0


	-- DELETE HISTORY RECORDS WHILE GENERATING SCRIPTS TO REPLACE THEM IF NEEDED
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
		---- CREATES TOO MUCH OUTPUT --- ONLY UNCOMMENT IF TROUBLESHOOTING ----
		-----------------------------------------------------------------------
		--OUTPUT	'SET IDENTITY_INSERT msdb.dbo.sysjobhistory ON;INSERT INTO [msdb].[dbo].[sysjobhistory]([instance_id],[job_id],[step_id],[step_name],[sql_message_id],[sql_severity],[message],[run_status],[run_date],[run_time],[run_duration],[operator_id_emailed],[operator_id_netsent],[operator_id_paged],[retries_attempted],[server]) VALUES('
		--		+CAST(COALESCE(DELETED.instance_id,'') AS VarChar(max))+','
		--		+QUOTENAME(CAST(COALESCE(DELETED.job_id,'') AS VarChar(max)),'''')+','
		--		+CAST(COALESCE(DELETED.step_id,'') AS VarChar(max))+','
		--		+QUOTENAME(CAST(COALESCE(DELETED.step_name,'') AS VarChar(max)),'''')+','
		--		+CAST(COALESCE(DELETED.sql_message_id,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.sql_severity,'') AS VarChar(max))+','
		--		+COALESCE(QUOTENAME(CAST(COALESCE(DELETED.message,'') AS VarChar(max)),''''),'''''')+','
		--		+CAST(COALESCE(DELETED.run_status,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.run_date,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.run_time,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.run_duration,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.operator_id_emailed,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.operator_id_netsent,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.operator_id_paged,'') AS VarChar(max))+','
		--		+CAST(COALESCE(DELETED.retries_attempted,'') AS VarChar(max))+','
		--		+QUOTENAME(CAST(COALESCE(DELETED.server,'') AS VarChar(max)),'''')+');SET IDENTITY_INSERT msdb.dbo.sysjobhistory OFF;' AS [-- Execute This Command To Replace Removed Records]
	--SELECT		H.*
	FROM		RankedHistory H
	JOIN		JobStepCount S
			ON	S.job_id = H.job_id
	WHERE		--DATEDIFF(HOUR,msdb.dbo.agent_datetime(H.run_date,H.run_time),GETDATE())> 24 -- USE TO BASE ON START TIME INSTEAD OF END TIME
				DATEDIFF(HOUR,DATEADD(s,DATEDIFF(s,msdb.dbo.agent_datetime(run_date,0),msdb.dbo.agent_datetime(run_date,run_duration%240000)+(run_duration/240000)),msdb.dbo.agent_datetime(run_date,run_time)),GETDATE())> 24
			AND H.InstanceRank > (S.job_steps+1)*100


	-- CREATES TOO MUCH OUTPUT --- ONLY UNCOMMENT IF TROUBLESHOOTING
	-- CALCULATE AND REPORT WHAT JOBS GOT HISTORY PRUNED
	--SELECT		T1.job_name
	--			,t1.rows						AS rows_before
	--			,t2.rows						AS rows_after
	--			,t1.rows - t2.rows				AS rows_diff
	--			,t1.executions					AS execs_before
	--			,t2.executions					AS execs_after
	--			,t1.executions - t2.executions	AS execs_diff
	--FROM		#JobHistoryCounts T1
	--LEFT JOIN	(
	--			SELECT		[job_id]
	--						,(SELECT name from [msdb].[dbo].sysjobs where job_id = T1.job_id ) [job_name]
	--						,COUNT(*) [rows]
	--						,COUNT(case when step_id = 0 then 1 end) [executions]
	--			  FROM [msdb].[dbo].[sysjobhistory] T1
	--			  GROUP BY [job_id]
	--			  WITH ROLLUP
	--			) T2
	--		ON	T2.job_id = T1.job_id
	--WHERE		t1.rows != t2.rows
	--		OR	t1.executions != t2.executions
	--ORDER BY	1


	DROP TABLE #JobHistoryCounts


/****************************************************************
 *  Check for Tranlog Backups not running (for 5 hours)
 ***************************************************************/


Select @save_dbcount = (select count(*) from sys.databases
					where database_id > 4
					and state = 0
					and recovery_model = 1
					and is_read_only = 0
					and name not in (select detail01 from no_check where NoCheck_type in ('backup', 'baseline')))


If @save_dbcount > (select count(distinct database_name) from msdb.dbo.backupset
    where database_name in (select name from sys.databases
					where database_id > 4
					and state = 0
					and recovery_model = 1
					and is_read_only = 0
					and left(name,2) != 'z_'
					and name not in (select detail01 from no_check where NoCheck_type in ('backup', 'baseline')))
    and backup_finish_date > getdate()-.21
    and type = 'L')
   begin
	Select @save_TlogDBname = (select top 1 name from sys.databases
					where database_id > 4
					and recovery_model = 1
					and state = 0
					and left(name,2) != 'z_'
					and name not in (select distinct database_name from msdb.dbo.backupset
					    where database_name in (select name from sys.databases
										where database_id > 4
										and state = 0
										and recovery_model = 1
										and is_read_only = 0
										and name not in (select detail01 from no_check where NoCheck_type in ('backup', 'baseline')))
					    and backup_finish_date > getdate()-.21
					    and type = 'L'))


	IF @@microsoftversion / 0x01000000 >= 11
	  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
	   begin


		SET @a = 0
		-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
		SELECT @cmd = 'SELECT @a = 1 FROM master.sys.dm_hadr_database_replica_states WHERE database_id = db_id(''' + @save_TlogDBname  + ''')'
		--Print @cmd
		--Print ''
		EXEC sp_executesql @cmd, N'@a int output', @a output


		IF @a = 1
		   BEGIN
			SET @a = 0
			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS
			SELECT @cmd = 'SELECT @a = sys.fn_hadr_backup_is_preferred_replica (''' + @save_TlogDBname  + ''')'
			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@a int output', @a output


			IF @a = 0
			   BEGIN
				RAISERROR('DBA Note: Skipping DB %s.  This DB is not the prefered replica in an Always On Availability Group.', -1,-1,@save_TlogDBname) with nowait
				GOTO loop_end
			   END
		   END
	   end


	SET @Subject		= @@servername+' - Tranlog backups not current for DB ' + @save_TlogDBname + '.  Notify DBA'
	SET @MSG		= 'SERVER                  : ' + @@ServerName + CHAR(13) + CHAR(10)
				+ 'DATE/TIME               : ' + CAST(Getdate() AS VarChar(50))


Print @Subject
	-- SEND MESSAGE
	EXEC DBAOps.dbo.dbasp_sendmail
		@recipients	= @Recipients
		,@subject	= @Subject
		,@message	= @MSG


	-- RAISE ALLERT
	--RAISERROR(67016, 16, -1, @Subject) WITH LOG,NOWAIT


	loop_end:


   end


/****************************************************************
 *  Check for failed job steps
 ***************************************************************/
If @check_jobstep_errors = 'y'
   begin
	--------------------  Cursor for Failed Job Steps  -------------------
	If @check_jobname_like = '*ALL*'
	   begin
		Insert into @jobinfo (jobname, instance_ID, Job_ID, step_name, step_id, sql_message_id, sql_severity, message, run_status, run_date, run_time)
		SELECT j.name, h.instance_ID, convert(varchar(50),h.Job_ID), h.step_name, h.step_id, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
		From msdb.dbo.sysjobhistory  h with (NOLOCK),  msdb.dbo.sysjobs j with (NOLOCK)
		Where h.job_id = j.job_id
		   and h.instance_ID not in (select instance_ID from DBAOps.dbo.FailedJobs with (NOLOCK))
		   and j.name not like 'MAINT%' and j.name not like 'DBA%' and j.name not like 'STRT%' and j.name not like 'DBAOps%' and j.name not like 'BASE%' and j.name not like 'RSTR%' and j.name not like 'UTIL - SQL Activity Log Process%'
		   and h.run_status in (0,3)
		   and h.step_id <> 0
		   and h.run_date >= convert(varchar(8),@saverun_date)
	   end
	Else
	   begin
		Select @jobtype = @check_jobname_like + '%'


		Insert into @jobinfo (jobname, instance_ID, Job_ID, step_name, step_id, sql_message_id, sql_severity, message, run_status, run_date, run_time)
		SELECT j.name, h.instance_ID, convert(varchar(50),h.Job_ID), h.step_name, h.step_id, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
		From msdb.dbo.sysjobhistory  h with (NOLOCK),  msdb.dbo.sysjobs  j with (NOLOCK)
		Where h.job_id = j.job_id
		  and h.instance_ID not in (select instance_ID from DBAOps.dbo.FailedJobs with (NOLOCK))
		  and j.name like @jobtype
		  and h.run_status in (0,3)
		  and h.step_id <> 0
		  and h.run_date >= convert(varchar(8),@saverun_date)
	   end
   end


delete from @jobinfo where run_status = 2 and (run_date < @holdrun_date or run_time < @holdrun_time)
delete from @jobinfo where jobname = 'MAINT - Backup Verify'


--select * from @jobinfo
--select * from DBAOps.dbo.FailedJobs


--  Process the results one record at a time by instance_id
If (select count(*) from @jobinfo) > 0
   begin
	start_jobinfo:

	Select @save_instance_ID = (select top 1 instance_ID from @jobinfo)
	Select @save_Job_ID = Job_ID from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_status = run_status from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_date = run_date from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_time = run_time from @jobinfo where instance_ID = @save_instance_ID
	Select @save_name = jobname from @jobinfo where instance_ID = @save_instance_ID
	Select @save_step_name = step_name from @jobinfo where instance_ID = @save_instance_ID
	Select @save_message = message from @jobinfo where instance_ID = @save_instance_ID


	If exists (select 1 from dbo.no_check where NoCheck_type = 'SQLjob' and Detail01 = @save_name)
	   begin
		goto skip_this_job_step
	   end


	--  Fix single quote problem in @save_name
	Select @startpos = 1
	label01:
	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_name = stuff(@save_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end

	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label01
 	   end


	--  Fix single quote problem in @save_step_name
	Select @startpos = 1
	label02:
	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_step_name = stuff(@save_step_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label02
 	   end


	--  Fix single quote problem in @save_message
	Select @startpos = 1
	label03:
	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		select @save_message = stuff(@save_message, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		goto label03
 	   end


	If @save_name not in ('UTIL - PERF Stat Capture Process')
	   begin
		Select @message  = 'Job: ' + @save_name + '  Step: ' + @save_step_name + '  Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time)
		If @save_run_status = 2
		   begin
			Select @message  = 'Retrying Job Step now.  ' + @message
			Select @message2 = '  Message: ' + @save_message
			Select @message3 = @message + ' ' + @message2
			--print @message
			--print @message2
			print @message3


			goto skip_this_job_step
		   end
		Else
		   begin
			Select @message2 = '  Message: ' + @save_message
			Select @message3 = @message + ' ' + @message2
			--print @message
			--print @message2
			--print @message3
		   end


		If exists (select 1 from msdb.dbo.sysjobs where name = @save_name and description <> 'No description available.')
		   begin
			Select @save_description = (select top 1 description from msdb.dbo.sysjobs where name = @save_name)
			Select @message2 = @message2 + '  ' + @save_description
		   end


		--  raise error for this job step
		raiserror(67023, -1, -1, @message, @message2)


		--  send email to dev if this job is related to any of our dev supported applications
		If @save_name like 'APPL%' and (select count(*) from master.sys.databases where name = 'DBAOps') > 0
		   begin
			--  If this job has been reported in the past 4 hours, skip this section
			If exists (select 1 from dbo.No_Check where NoCheck_type = 'APPLjob' and detail01 = @save_name and datediff(hh, createdate, getdate()) < 4)
			   begin
				goto end_appl_job_check
			   end
			Else
			   begin
				Delete from dbo.No_Check where NoCheck_type = 'APPLjob' and detail01 = @save_name
				insert into dbo.No_Check values ('APPLjob', @save_name, '', '', '', 'periodic_check', getdate(), getdate())
			   end


			Select @save_description = (select top 1 description from msdb.dbo.sysjobs where job_id = @save_Job_ID)


			Select @appl_name = ''
			start_appl_job_check:
			If exists(select 1 from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name)
			   begin
				Select @appl_name = (select top 1 RSTRfolder from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name order by RSTRfolder)
				--Print @appl_name


				If @save_description like @appl_name + '%'
				  begin
					Select @save_env_name = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname')
					Select @save_sendmail_recipients = 'SQLDevAdmin@${{secrets.DOMAIN_NAME}}; SQLDBAreports@${{secrets.DOMAIN_NAME}}'


					--Select @save_sendmail_recipients = (select top 1 recipients from DBAOps.dbo.sendmail_dist_list where ProjectID = @appl_name and success_flag = 'n' and env_name = @save_env_name)


					--If @save_sendmail_recipients is null or @save_sendmail_recipients = ''
					--   begin
					--	Select @save_sendmail_recipients = (select top 1 recipients from DBAOps.dbo.sendmail_dist_list where ProjectID = 'other' and success_flag = 'n' and env_name = 'ALL')
					--   end


					--If @save_sendmail_recipients is null or @save_sendmail_recipients = ''
					--   begin
					--	Select @save_sendmail_recipients = 'SQLDBAreports@${{secrets.DOMAIN_NAME}}'
					--   end
					--Else
					--   begin
					--	Select @save_sendmail_recipients = @save_sendmail_recipients + '; SQLDBAreports@${{secrets.DOMAIN_NAME}}'
					--   end

					Select @message  = 'APPL Job Step Failure - Server: ' + @servername + '  Job: ' + @save_name + '  Step: ' + @save_step_name + '  Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time)

					Select @message2 = 'APPL Job Step Failure - Server: ' + @servername + char(13)+char(10)
					Select @message2 = @message2 + 'Job: ' + @save_name + char(13)+char(10)
					Select @message2 = @message2 + 'Step: ' + @save_step_name + char(13)+char(10)
					Select @message2 = @message2 + 'Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time) + char(13)+char(10)
					Select @message2 = @message2 + char(13)+char(10)
					Select @message2 = @message2 + @save_message


					--print @message
					--print @message2

					--  Email TS SQL DBA with this information
					EXEC DBAOps.dbo.dbasp_sendmail
					@recipients = @save_sendmail_recipients,
					@subject = @message,
					@message = @message2


					goto end_appl_job_check
				   end


				If exists(select 1 from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name)
				   begin
					goto start_appl_job_check
				   end
			   end


			end_appl_job_check:
		   end


		insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
		--select * from DBAOps.dbo.FailedJobs


		insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67023, rtrim(@message3))
		--select * from DBAOps.dbo.Periodic_Errors order by error_id


	   end


	skip_this_job_step:


	Delete from @jobinfo where instance_ID = @save_instance_ID
	If (select count(*) from @jobinfo) > 0
	   begin
		goto start_jobinfo
	   end


   end


/****************************************************************
 *  Check for failed MAINT job steps
 ***************************************************************/
Select @message  = ' '
Select @message2  = ' '
Select @message3  = ' '
delete from @jobinfo


If @Check_maintstep_errors = 'y'
   begin
	--------------------  Cursor for Failed Job Steps  -------------------
	Insert into @jobinfo (jobname, instance_ID, Job_ID, step_name, step_id, sql_message_id, sql_severity, message, run_status, run_date, run_time)
	SELECT j.name, h.instance_ID, convert(varchar(50),h.Job_ID), h.step_name, h.step_id, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
	From msdb.dbo.sysjobhistory  h with (NOLOCK),  msdb.dbo.sysjobs j with (NOLOCK)
	Where h.job_id = j.job_id
	   and h.instance_ID not in (select instance_ID from DBAOps.dbo.FailedJobs with (NOLOCK))
	   and (j.name like 'MAINT%' or j.name like 'DBA%' or j.name like 'STRT%' or j.name like 'RSTR%' or j.name like 'UTIL%')
	   and h.run_status in (0,3)
	   and h.step_id <> 0
	   and h.run_date >= convert(varchar(8),@saverun_date)
   end


delete from @jobinfo where run_status = 2 and (run_date < @holdrun_date or run_time < @holdrun_time)


--select * from @jobinfo
--select * from DBAOps.dbo.FailedJobs


--  Process the results one record at a time by instance_id
If (select count(*) from @jobinfo) > 0
   begin
	start_maintstep:

	Select @save_instance_ID = (select top 1 instance_ID from @jobinfo)
	Select @save_Job_ID = Job_ID from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_status = run_status from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_date = run_date from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_time = run_time from @jobinfo where instance_ID = @save_instance_ID
	Select @save_name = jobname from @jobinfo where instance_ID = @save_instance_ID
	Select @save_step_name = step_name from @jobinfo where instance_ID = @save_instance_ID
	Select @save_message = message from @jobinfo where instance_ID = @save_instance_ID


	If exists (select 1 from dbo.no_check where NoCheck_type = 'SQLjob' and Detail01 = @save_name)
	   begin
		goto skip_maint_job_step
	   end


	--  Fix single quote problem in @save_name
	Select @startpos = 1
	label11:
	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_name = stuff(@save_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end

	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label11
 	   end


	--  Fix single quote problem in @save_step_name
	Select @startpos = 1
	label12:
	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_step_name = stuff(@save_step_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label12
 	   end


	--  Fix single quote problem in @save_message
	Select @startpos = 1
	label13:
	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		select @save_message = stuff(@save_message, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		goto label13
 	   end


	If @save_name not in ('UTIL - PERF Daily 5min Processing', 'UTIL - DBA Daily 5min Processing')
	   begin
		Select @message  = 'Job: ' + @save_name + '  Step: ' + @save_step_name + '  Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time)
		If @save_run_status = 2
		   begin
			Select @message  = 'Retrying Job Step now.  ' + @message
			Select @message2 = '  Message: ' + @save_message
			Select @message3 = @message + ' ' + @message2
			--print @message
			--print @message2
			print @message3


			goto skip_maint_job_step
		   end
		Else
		   begin
			Select @message2 = '  Message: ' + @save_message
			Select @message3 = @message + ' ' + @message2
			--print @message
			--print @message2
			--print @message3
		   end


		If @message3 like '%Assembly in host store has a different signature than assembly in GAC%'
		   begin
			raiserror(67028, -1, -1, @message, @message2)
			insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
			--select * from DBAOps.dbo.FailedJobs


			insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67028, rtrim(@message3))
			--select * from DBAOps.dbo.Periodic_Errors order by error_id
		   end
		Else If @save_name like 'MAINT%'and @save_name like '%Backup%'
		   begin
			raiserror(67027, 16, -1, @message, @message2) WITH LOG
			insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
			--select * from DBAOps.dbo.FailedJobs

			insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67027, rtrim(@message3))
			--select * from DBAOps.dbo.Periodic_Errors order by error_id
		   end
		Else If @save_name like 'MAINT%'
		   begin
			If @save_name like '%Index Maint%' and (@message like '%cancelled%' or @message2 like '%cancelled%')
			   begin
				goto skip_maint_job_step
			   end
			Else
			   begin
				raiserror(67022, -1, -1, @message, @message2)
				insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
				--select * from DBAOps.dbo.FailedJobs

				insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67022, rtrim(@message3))
				--select * from DBAOps.dbo.Periodic_Errors order by error_id
			   end
		   end
		Else
		   begin
			raiserror(67023, -1, -1, @message, @message2)
			insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
			--select * from DBAOps.dbo.FailedJobs


			insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67023, rtrim(@message3))
			--select * from DBAOps.dbo.Periodic_Errors order by error_id
		   end


	   end


	skip_maint_job_step:


	Delete from @jobinfo where instance_ID = @save_instance_ID
	If (select count(*) from @jobinfo) > 0
	   begin
		goto start_maintstep
	   end


   end


/****************************************************************
 *  Check for failed DBAOps and BASE job steps
 ***************************************************************/
Select @message  = ' '
Select @message2  = ' '
Select @message3  = ' '
delete from @jobinfo


If exists (select 1 from msdb.dbo.sysjobs where name like 'DBAOps%' or name like 'BASE%')
   begin
	--------------------  Cursor for Failed Job Steps  -------------------
	Insert into @jobinfo (jobname, instance_ID, Job_ID, step_name, step_id, sql_message_id, sql_severity, message, run_status, run_date, run_time)
	SELECT j.name, h.instance_ID, convert(varchar(50),h.Job_ID), h.step_name, h.step_id, h.sql_message_id, h.sql_severity, h.message, h.run_status, h.run_date, h.run_time
	From msdb.dbo.sysjobhistory  h with (NOLOCK),  msdb.dbo.sysjobs j with (NOLOCK)
	Where h.job_id = j.job_id
	   and h.instance_ID not in (select instance_ID from DBAOps.dbo.FailedJobs with (NOLOCK))
	   and (j.name like 'DBAOps%' or j.name like 'BASE%')
	   and h.run_status in (0,3)
	   and h.step_id <> 0
	   and h.run_date >= convert(varchar(8),@saverun_date)
   end


delete from @jobinfo where run_status = 2 and (run_date < @holdrun_date or run_time < @holdrun_time)


--select * from @jobinfo
--select * from DBAOps.dbo.FailedJobs


--  Process the results one record at a time by instance_id
If (select count(*) from @jobinfo) > 0
   begin
	start_deplstep:

	Select @save_instance_ID = (select top 1 instance_ID from @jobinfo)
	Select @save_Job_ID = Job_ID from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_status = run_status from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_date = run_date from @jobinfo where instance_ID = @save_instance_ID
	Select @save_run_time = run_time from @jobinfo where instance_ID = @save_instance_ID
	Select @save_name = jobname from @jobinfo where instance_ID = @save_instance_ID
	Select @save_step_name = step_name from @jobinfo where instance_ID = @save_instance_ID
	Select @save_message = message from @jobinfo where instance_ID = @save_instance_ID


	If exists (select 1 from dbo.no_check where NoCheck_type = 'SQLjob' and Detail01 = @save_name)
	   begin
		goto skip_base
	   end


	--  Fix single quote problem in @save_name
	Select @startpos = 1
	label21:
	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_name = stuff(@save_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end

	select @charpos = charindex('''', @save_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label21
 	   end


	--  Fix single quote problem in @save_step_name
	Select @startpos = 1
	label22:
	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		select @save_step_name = stuff(@save_step_name, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_step_name, @startpos)
	IF @charpos <> 0
	   begin
		goto label22
 	   end


	--  Fix single quote problem in @save_message
	Select @startpos = 1
	label23:
	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		select @save_message = stuff(@save_message, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @save_message, @startpos)
	IF @charpos <> 0
	   begin
		goto label23
 	   end


	If @save_run_status = 2
	   begin
		Select @message  = 'DBAOps Job Step Failure (Retrying Job Step now) - Server: ' + @servername + '  Job: ' + @save_name + '  Step: ' + @save_step_name + '  Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time)
		goto skip_base
	   end
	Else
	   begin
		Select @message  = 'DBAOps Job Step Failure - Server: ' + @servername + '  Job: ' + @save_name + '  Step: ' + @save_step_name + '  Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time)
	   end


	Select @message2 = 'DBAOps Job Step Failure - Server: ' + @servername + char(13)+char(10)
	Select @message2 = @message2 + 'Job: ' + @save_name + char(13)+char(10)
	Select @message2 = @message2 + 'Step: ' + @save_step_name + char(13)+char(10)
	Select @message2 = @message2 + 'Date/Time: ' + convert(varchar(10),@save_run_date) + ' ' + convert(varchar(10),@save_run_time) + char(13)+char(10)
	Select @message2 = @message2 + char(13)+char(10)
	Select @message2 = @message2 + @save_message


	--print @message
	--print @message2


	--  Email TS SQL DBA with this information
	--  If this job has been reported in the past 4 hours, skip this section
	If exists (select 1 from dbo.No_Check where NoCheck_type = 'BASEjob' and detail01 = @save_name and datediff(hh, createdate, getdate()) < 4)
	   begin
		goto end_Base_job_check
	   end
	Else
	   begin
		Delete from dbo.No_Check where NoCheck_type = 'BASEjob' and detail01 = @save_name
		insert into dbo.No_Check values ('BASEjob', @save_name, '', '', '', 'periodic_check', getdate(), getdate())
	   end


	EXEC DBAOps.dbo.dbasp_sendmail
		--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@subject = @message,
		@message = @message2


	end_Base_job_check:


	raiserror(67026, 16, -1, @message, @message2) WITH LOG
	insert into DBAOps.dbo.FailedJobs(instance_ID, Job_ID, run_status, run_date) values( @save_instance_ID, @save_Job_ID, @save_run_status, @save_run_date )
	--select * from DBAOps.dbo.FailedJobs


	Select @message3 = @message + ' ' + @message2
	insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67026, rtrim(@message3))
	--select * from DBAOps.dbo.Periodic_Errors order by error_id


	skip_base:


	Delete from @jobinfo where instance_ID = @save_instance_ID
	If (select count(*) from @jobinfo) > 0
	   begin
		goto start_deplstep
	   end


   end


/****************************************************************
 *  Check To see if the Archive and Health Check process has run
 ***************************************************************/


--  For production only
If (select env_detail from dbo.Local_ServerEnviro where env_type = 'ENVname') <> 'production'
   begin
	Print 'Note:  The check Archive/Health Check process is intended only for production instances.  Skipping this process.'
	Print ' '
	Print ' '
	goto skip_Archive_check
   end
--  Check once after 5AM
Else If datediff(hh, convert(nvarchar(8), getdate(), 112), getdate()) < 5
   begin
	goto skip_Archive_check
   end
--  See if this is the check record for today
Else If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_archive_job' and env_detail = convert(nvarchar(8), getdate(), 112))
   begin
	goto skip_Archive_check
   end


--  If the daily or weekly backup job is running, skip this.
exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Backup and DBCC', @status1 output
exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Weekly Backup and DBCC', @status2 output
If @status1 = 'active' or @status2 = 'active'
   begin
	goto skip_Archive_check
   end


--  Update or insert control row
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_archive_job')
   begin
	update dbo.Local_ServerEnviro set env_detail = convert(nvarchar(8), getdate(), 112) where env_type = 'check_archive_job'
   end
Else
   begin
	insert into dbo.Local_ServerEnviro values ('check_archive_job', convert(nvarchar(8), getdate(), 112))
   end


select @save_instance_id = (Select max(h.instance_id)
			from msdb.dbo.sysjobhistory  h,  msdb.dbo.sysjobs  j
			where h.job_id = j.job_id
			  and j.name = 'UTIL - DBA Archive process'
			  and h.run_status = 1
			  and h.step_id = 0)


select @save_run_date_char = (Select h.run_date
				from msdb.dbo.sysjobhistory  h
				where h.instance_id = @save_instance_id)


select @save_run_time_char = (Select h.run_time
				from msdb.dbo.sysjobhistory  h
				where h.instance_id = @save_instance_id)


If len(@save_run_time_char) = 5
   begin
	Select @save_run_time_char = '0' + @save_run_time_char
   end
Else If len(@save_run_time_char) = 4
   begin
	Select @save_run_time_char = '00' + @save_run_time_char
   end
Else If len(@save_run_time_char) = 3
   begin
	Select @save_run_time_char = '000' + @save_run_time_char
   end
Else If len(@save_run_time_char) = 2
   begin
	Select @save_run_time_char = '0000' + @save_run_time_char
   end
Else If len(@save_run_time_char) = 1
   begin
	Select @save_run_time_char = '00000' + @save_run_time_char
   end


Select @save_run_date_char = substring(@save_run_date_char, 1, 4) + '-' + substring(@save_run_date_char, 5, 2) + '-' + substring(@save_run_date_char, 7, 2)


Select @save_run_time_char = substring(@save_run_time_char, 1, 2) + ':' + substring(@save_run_time_char, 3, 2) + ':' + substring(@save_run_time_char, 5, 2)


If @save_run_date_char is null or @save_run_time_char is null
   begin
	Print 'Note:  Unable to determine the last time the archive process ran.  Run it now'
	Print ' '
	Print ' '

	exec msdb.dbo.sp_start_job @job_name = 'UTIL - DBA Archive process'

	goto skip_Archive_check
   end


Select @lastrundate = convert(datetime, @save_run_date_char + ' ' + @save_run_time_char)


If Datediff(hh, @lastrundate, getdate()) > 22
   begin
	Print 'Note:  The Archive process has not run in the past 22 hours and Maint jobs are not running.  Run it now.'
	Print ' '
	Print ' '

	exec msdb.dbo.sp_start_job @job_name = 'UTIL - DBA Archive process'
   end


skip_Archive_check:


/****************************************************************
 *  Check for Replication errors
 ***************************************************************/
If exists (select * from msdb.sys.sysobjects where name = 'msdistributiondbs' and xtype = 'U')
   begin
	Insert into @msdistributiondbs (DBname)
	SELECT name from msdb.dbo.msdistributiondbs


	--select * from @msdistributiondbs


	If (select count(*) from @msdistributiondbs) > 0
	   begin
		start_msdistributiondbs:


		Select @save_msdistributiondbs = (select top 1 DBname from @msdistributiondbs)


		Select @message = ' '
		Select @message2 = ' '
		Select @message3 = ' '


		Select @query = 'Insert into #replerrors (time, source_name, error_code, error_text)
		SELECT e.time, e.source_name, e.error_code, convert(varchar(4000), e.error_text)
		From ' + rtrim(@save_msdistributiondbs) + '.dbo.MSrepl_errors  e ' +
		  'Where convert(varchar(23), e.time, 121) > ''' +  @cnvt_old_runtime + '''
		     and e.source_name is not null'


		Exec (@query)


		--Select * from #replerrors


		If (select count(*) from #replerrors) > 0
		   begin
			start_replerrors:


			Select @save_time = (select top 1 time from #replerrors)
			Select @message = rtrim(source_name) from #replerrors where time = @save_time
			Select @message2 = rtrim(error_code) from #replerrors where time = @save_time
			Select @message3 = rtrim(left(error_text, 50)) from #replerrors where time = @save_time


			raiserror(67021, -1, -1, @message, @message2, @message3)


			insert into DBAOps.dbo.Periodic_Errors (alert_num, Message_text) values(67021, rtrim(@message) + rtrim(@message2) + rtrim(@message3))


			Delete from #replerrors where time = @save_time
			If (select count(*) from #replerrors) > 0
			   begin
				goto start_replerrors
			   end
		   end


		Delete from @msdistributiondbs where DBname = @save_msdistributiondbs
		If (select count(*) from @msdistributiondbs) > 0
		   begin
			goto start_msdistributiondbs
		   end
	   end


   end


/****************************************************************
 *  Check for Mirroring or AGgroup errors
 ***************************************************************/
exec dbo.dbasp_MirrorAGHealthCheck


/****************************************************************
 *  Check Service Broker Queues
 ***************************************************************/
exec dbo.dbasp_CheckServiceBrokerQueues


/****************************************************************
 *  Check for CLR - .NET errors
 ***************************************************************/


EXEC DBAOps.dbo.dbasp_AutoFixCLR


/****************************************************************
 *  Delete expired records from Local_ServerEnviro
 ***************************************************************/
--  delete a Mirror Failover Override row older than 45 minutes
If exists(select 1 from dbo.Local_ServerEnviro where env_type = 'mirror_failover_override' and datediff(mi, convert(datetime,env_detail), getdate()) > 45)
   begin
	delete from dbo.Local_ServerEnviro where env_type = 'mirror_failover_override'
   end


---------------------------  Finalization  -----------------------


delete from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_periodic_time'
insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('check_periodic_time', @new_runtime)


Select @reset_date = DATEADD(day, -3, @reset_date)
Select @reset_char = convert(varchar(8), @reset_date, 112)
Select @reset_int = convert(int, rtrim(@reset_char))
delete from DBAOps.dbo.FailedJobs where run_date < @reset_int


drop table IF EXISTS #replerrors
drop table IF EXISTS #CMDOutput
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Periodic] TO [public]
GO
