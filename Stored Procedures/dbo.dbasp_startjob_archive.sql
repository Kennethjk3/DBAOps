SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_startjob_archive]  @miniute_limit int = 20


/*********************************************************
 **  Stored Procedure dbasp_startjob_archive
 **  Written by Steve Ledridge, Virtuoso
 **  March 13, 2014
 **  This procedure starts the DBA Archive process if it is
 **  not already running.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/13/2014	Steve Ledridge		New process
--	======================================================================================


/***
declare @miniute_limit int


select @miniute_limit = 20
--***/


Declare @saveJobName sysname
Declare @status1 sysname
Declare @save_minutes int
Declare @save_subject sysname
Declare @miscprint varchar(500)


Select @saveJobName = 'UTIL - DBA Archive process'


exec DBAOps.dbo.dbasp_Check_Jobstate @saveJobName, @status1 output


print 'Job status for SQL job ''UTIL - DBA Archive process'' = ' + @status1
Print ''


If @status1 = 'idle'
   begin
	Print 'Starting SQL job ''UTIL - DBA Archive process'''
	EXEC msdb.dbo.sp_start_job @job_name = 'UTIL - DBA Archive process'
   end
else
   begin
	Select @save_minutes = (SELECT DATEDIFF(Minute,aj.start_execution_date,GetDate()) --AS Minutes
				FROM msdb..sysjobactivity aj
				JOIN msdb..sysjobs sj on sj.job_id = aj.job_id
				WHERE aj.stop_execution_date IS NULL -- job hasn't stopped running
				AND aj.start_execution_date IS NOT NULL -- job is currently running
				AND sj.name = 'UTIL - DBA Archive process'
				and not exists( -- make sure this is the most recent run
				    select 1
				    from msdb..sysjobactivity new
				    where new.job_id = aj.job_id
				    and new.start_execution_date > aj.start_execution_date))


	If @save_minutes < @miniute_limit
	   begin
		print 'Skipping job start process'
	   end
	Else
	   begin
		Select @save_subject = 'DBA Job Start Error on ' + @@servername
		Select @miscprint = 'DBA Warning:  SQL job ''UTIL - DBA Archive process'' has been found running long on server ' + @@servername + '.  Unable to start the job at this time.'
		Print @miscprint


		EXEC DBAOps.dbo.dbasp_sendmail
			@recipients = 'DBANotify@virtuoso.com',
			@subject = @save_subject,
			@message = @miscprint
	   end
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_startjob_archive] TO [public]
GO
