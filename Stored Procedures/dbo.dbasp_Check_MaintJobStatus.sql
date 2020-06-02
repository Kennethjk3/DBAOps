SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_MaintJobStatus]


/*********************************************************
 **  Stored Procedure dbasp_Check_MaintJobStatus
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 8, 2012
 **
 **  This procedure checks the status of other MAINT jobs
 **  to determine if the MAINT job trying to start is clear
 **  to do so.
 **
 **  - If a backup is trying to start and the reindex job
 **    is found to be running, this sproc will try to shut
 **    down the reindex process.
 **
 **  - If a backup is trying to start and another backup
 **    job is found to be running, this sproc will fail.
 **
 **  - If a reindex is trying to start and another backup
 **    job is found to be running, this sproc will fail.
 **
 ***************************************************************/
  as
	SET NOCOUNT ON;
	-- Do not lock anything, and do not get held up by any locks.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	-- Do Not let this process be the winner in a deadlock
	SET DEADLOCK_PRIORITY LOW;


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	08/08/2012	Steve Ledridge		New process
--	10/29/2012	Steve Ledridge		New code to kill GIMPI if running.
--	07/24/2014	Steve Ledridge		Remove code for GIMPI.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(255)
	,@cmd				nvarchar(500)
	,@saveJobName			sysname
	,@status1 			varchar(10)
	,@status2 			varchar(10)
	,@save_spid			int
	,@retry_count			int


----------------  initial values  -------------------


Select @saveJobName = (SELECT DBAOps.[dbo].[dbaudf_APP_NAME] ('JobName'))
--Select @saveJobName = 'MAINT - Daily Index Maintenance'


Print '--  Starting Check Maint Jobs Process for job - ' + @saveJobName
raiserror('', -1,-1) with nowait


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Section for Current Job 'MAINT - Daily Index Maintenance'
--  Note:  In this section we check to see if the daily or weekly
--         backup processes are running.  If so, we alert and fail.


If @saveJobName = 'MAINT - Daily Index Maintenance'
   begin
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Backup and DBCC', @status1 output
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Weekly Backup and DBCC', @status2 output


	If @status1 <> 'idle' or @status2 <> 'idle'
	   begin
		Select @miscprint = 'DBA ERROR: SQL job ' + @saveJobName + ' failed due to other active MAINT (backup) jobs.'
		raiserror(@miscprint,16,-1) with log
		goto label99
	   end
	Else
	   begin
		Print '--  No other Maint jobs active at this time.  Continue process for job - ' + @saveJobName
		raiserror('', -1,-1) with nowait
		If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_indexmaint')
		   begin
			update dbo.Local_ServerEnviro set env_detail = 'running' where env_type = 'check_indexmaint'
		   end
		Else
		   begin
			Insert into dbo.Local_ServerEnviro values ('check_indexmaint', 'running')
		   end


		--  Reset vw_AllDB_stats and vw_AllDB_objects
		exec dbo.dbasp_CreateAllDBViews


		goto label99
	   end
   end


--  Section for Current Job 'MAINT - Daily Backup and DBCC'
--  Note:  In this section we check to see if the weekly backup
--         processes is running and also check to see if the index
--         maintenance process is running.  If backups are running,
--         we alert and fail.  If index maintenance is running, we
--         try to stop it so we can contine with this backup process.


If @saveJobName = 'MAINT - Daily Backup and DBCC'
   begin
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Weekly Backup and DBCC', @status1 output
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status2 output


	If @status1 <> 'idle'
	   begin
		Select @miscprint = 'DBA ERROR: SQL job ' + @saveJobName + ' failed due to other active MAINT (backup) jobs.'
		raiserror(@miscprint,16,-1) with log
		goto label99
	   end
	Else If @status2 <> 'idle'
	   begin
		Select @miscprint = 'DBA Warning: SQL job ' + @saveJobName + ' on-hold due to other active MAINT (index) jobs.'
		raiserror(@miscprint,-1,-1) with log
		goto index_section
	   end
	Else
	   begin
		Print '--  No other Maint jobs active at this time.  Continue process for job - ' + @saveJobName
		goto label99
	   end
   end


--  Section for Current Job 'MAINT - Weekly Backup and DBCC'
--  Note:  In this section we check to see if the daily backup
--         processes is running and also check to see if the index
--         maintenance process is running.  If backups are running,
--         we alert and fail.  If index maintenance is running, we
--         try to stop it so we can contine with this backup process.


If @saveJobName = 'MAINT - Weekly Backup and DBCC'
   begin
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Backup and DBCC', @status1 output
	exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status2 output


	If @status1 <> 'idle'
	   begin
		Select @miscprint = 'DBA ERROR: SQL job ' + @saveJobName + ' failed due to other active MAINT (backup) jobs.'
		raiserror(@miscprint,16,-1) with log
		goto label99
	   end
	Else If @status2 <> 'idle'
	   begin
		Select @miscprint = 'DBA Warning: SQL job ' + @saveJobName + ' on-hold due to other active MAINT (index) jobs.'
		raiserror(@miscprint,-1,-1) with log
		goto index_section
	   end
	Else
	   begin
		Print '--  No other Maint jobs active at this time.  Continue process for job - ' + @saveJobName
		goto label99
	   end
   end


--  Index Maint Shutdown section
index_section:


--  At this point, we know the index maint job is running and we want to stop it.
--  We will modify a row in the dbo.Local_ServerEnviro table to start with
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_indexmaint')
   begin
	update dbo.Local_ServerEnviro set env_detail = 'stop' where env_type = 'check_indexmaint'
   end
Else
   begin
	Insert into dbo.Local_ServerEnviro values ('check_indexmaint', 'stop')
   end


--  Stop index maint try 1
Select @retry_count = 0
stop_index01:


If @retry_count > 10
   begin
	Select @miscprint = 'DBA Warning: Unable to stop SQL job ''MAINT - Daily Index Maintenance''.  Starting the second stop job process.'
	raiserror(@miscprint,-1,-1) with log
	Select @retry_count = 0
	goto stop_index02
   end


-- Check to see if the job is currently idle (not running).
exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status1 output


If @status1 <> 'idle'
   begin
	Select @miscprint = 'DBA WARNING: SQL job ' + @saveJobName + ' on-hold, waiting for ''MAINT - Daily Index Maintenance'' to stop.'
	raiserror(@miscprint,-1,-1) with log
	Select @retry_count = @retry_count + 1
	Waitfor delay '00:02:00'
	goto stop_index01
   end
Else
   begin
	Select @miscprint = 'DBA Note: SQL job ' + @saveJobName + ' can now continue.'
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


--  Stop index maint try 2
stop_index02:


If @retry_count > 10
   begin
	Select @miscprint = 'DBA Warning: Unable to stop the SQL job ''MAINT - Daily Index Maintenance''.  Starting the kill job process.'
	raiserror(@miscprint,-1,-1) with log
	Select @retry_count = 0
	goto stop_index03
   end


-- Check to see if the job is currently idle (not running).
exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status1 output


If @status1 <> 'idle'
   begin
	EXEC msdb.dbo.sp_stop_job N'MAINT - Daily Index Maintenance'
	Select @miscprint = 'DBA WARNING: SQL job ' + @saveJobName + ' on-hold, waiting for ''MAINT - Daily Index Maintenance'' to stop.'
	raiserror(@miscprint,-1,-1) with log
	Select @retry_count = @retry_count + 1
	Waitfor delay '00:02:00'
	goto stop_index02
   end
Else
   begin
	Select @miscprint = 'DBA Note: SQL job ' + @saveJobName + ' can now continue.'
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


--  Kill index maint
stop_index03:


--  Capture the spid related to the index maintenance job
;with spiddata as (
SELECT  x.session_id as [Sid],
            CASE LEFT(x.program_name,15)
            WHEN 'SQLAgent - TSQL' THEN
            (     select top 1 'SQL Job = '+j.name from msdb.dbo.sysjobs (nolock) j
                  inner join msdb.dbo.sysjobsteps (nolock) s on j.job_id=s.job_id
                  where right(cast(s.job_id as nvarchar(50)),10) = RIGHT(substring(x.program_name,30,34),10) )
            ELSE x.program_name
            END as Program_name
       FROM
      (
            SELECT
                  r.session_id,
                  s.program_name
            FROM sys.dm_exec_requests r
            JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
            WHERE r.status IN ('running', 'runnable', 'suspended')
            GROUP BY
                  r.session_id,
                  s.program_name
      ) x
      where x.session_id <> @@spid
      )
      select top 1 @save_spid=Sid from spiddata where program_name like '%MAINT - Daily Index Maintenance%'


Select @cmd = 'KILL ' + convert(varchar(12), @save_spid )
Print @cmd
exec(@cmd)
Waitfor delay '00:02:00'


stop_index03b:

If @retry_count > 10
   begin
	Select @miscprint = 'DBA ERROR: Unable to kill the SQL job ''MAINT - Daily Index Maintenance''.'
	raiserror(@miscprint,16,-1) with log
	goto label99
   end


-- Check to see if the job is currently idle (not running).
exec DBAOps.dbo.dbasp_Check_Jobstate 'MAINT - Daily Index Maintenance', @status1 output


If @status1 <> 'idle'
   begin
   	Select @cmd = 'KILL ' + convert(varchar(12), @save_spid )
	Print @cmd
	exec(@cmd)


	Select @miscprint = 'DBA WARNING: SQL job ' + @saveJobName + ' on-hold, waiting for ''MAINT - Daily Index Maintenance'' to die.'
	raiserror(@miscprint,-1,-1) with log
	Select @retry_count = @retry_count + 1
	Waitfor delay '00:02:00'
	goto stop_index03b
   end
Else
   begin
	Select @miscprint = 'DBA Note: SQL job ' + @saveJobName + ' can now continue.'
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


---------------------------  Finalization  -----------------------
label99:


Print ''
Print '--  End Check Maint Jobs Process for job - ' + @saveJobName
Print ''
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_MaintJobStatus] TO [public]
GO
