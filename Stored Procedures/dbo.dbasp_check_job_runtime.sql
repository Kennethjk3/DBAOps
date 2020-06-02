SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_check_job_runtime]	(
													@job_name				char(50)
													,@minutes_allowed		int				= 60 
													,@person_to_notify		varchar(50)		='dbanotify@virtuoso.com'
													)
AS 

DECLARE		@minutes_running		Int
			,@message_text			varchar(255)

SELECT		@minutes_running = isnull(DATEDIFF(mi, p.last_batch, getdate()), 0)
FROM		master..sysprocesses p
JOIN		msdb..sysjobs j						ON DBAOps.dbo.dbaudf_sysjobs_getprocessid(j.job_id) = substring(p.program_name,32,8)
WHERE		j.name = @job_name

IF @minutes_running > @minutes_allowed 
    BEGIN
      SELECT @message_text = ('Job ' + UPPER(SUBSTRING(@job_name,1,LEN(@job_name))) + ' has been running for ' + SUBSTRING(CAST(@minutes_running AS char(5)),1,LEN(CAST(@minutes_running AS char(5)))) + ' minutes, which is over the allowed run time of ' + SUBSTRING(CAST(@minutes_allowed AS char(5)),1,LEN(CAST(@minutes_allowed AS char(5)))) + ' minutes.') 

      EXEC msdb.dbo.sp_send_dbmail
        @recipients = @person_to_notify,
        @body		= @message_text,
        @subject	= 'DBAERROR: Long-Running Job to Check' 

	RAISERROR(@message_text,15,1) WITH LOG,NOWAIT
    END
GO
GRANT EXECUTE ON  [dbo].[dbasp_check_job_runtime] TO [public]
GO
