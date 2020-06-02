SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[usp_CheckHourlySnapshotJob]
as
Declare @MName Varchar(100)
Declare @Server Varchar(100)
Declare @Msg Varchar(125)
Declare @Subj varchar(125)


Declare HSCur Cursor
For
  SELECT distinct SJ.Name, JH.server
  FROM sysjobs SJ
  JOIN sysjobhistory JH ON JH.job_id = SJ.job_id
  JOIN sysjobservers SJS ON SJS.job_id = JH.job_id
  where
  SJS.last_run_outcome = 0 and
  SJ.name = 'MIRRORED DATABASES - CREATE HOURLY SNAPSHOTS' and
  SJ.enabled = 1


Open HSCur
Fetch Next from HSCur Into @MName, @Server


While @@Fetch_Status = 0
Begin


  Set @Msg = @MName +  ' Job has failed on ' + @Server + '. The job will be restarted.'
  Set @Subj = 'Job Error - ' + @MName + ' job will be restarted on ' + @Server + '. '
  EXEC msdb.dbo.sp_send_dbmail @recipients = 'marlena.mattingly@23touchpoints', @Subject = @Subj, @Body = @Msg
  EXEC msdb.dbo.sp_start_job @job_name = @MName


If @@error <> 0
Begin
  Set @Msg = @MName +  ' The job could not be restarted. Error number = ' + Cast (@@error as varchar)
  Set @Subj = 'Job Error in ' + @MName +' job on ' + @Server + '. The job could not be restarted.'
  EXEC msdb.dbo.sp_send_dbmail @recipients = 'marlena.mattingly@23touchpoints.com', @Subject = @Subj, @Body = @Msg
End


  Fetch Next from HSCur Into @MName, @Server
End


Close HSCur
Deallocate HSCur
GO
GRANT EXECUTE ON  [dbo].[usp_CheckHourlySnapshotJob] TO [public]
GO
