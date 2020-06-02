SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetJobStatus2]
	(
	@pJobName varchar(100)
	)
RETURNS int
AS
-- =============================================
-- Author:      Steve Ledridge
-- Create date: 10/29/2012
-- Description: Gets state of particular Job
--
-- -2 = Job was not Found
--  0 = Failed
--  1 = Succeeded
--  2 = Retry
--  3 = Canceled
--  4 = In progress
--  5 = Idle
--	+10 Job is Disabled
-- =============================================

BEGIN
    DECLARE @status int

    SELECT
        @status = CASE
					WHEN OA.start_execution_date IS NOT NULL AND OA.stop_execution_date IS NULL THEN 4
					WHEN OA.run_requested_date IS NULL THEN 5
					ELSE JH.RUN_STATUS
					END + CASE WHEN O.enabled = 0 THEN 10 ELSE 0 END
    FROM		MSDB.DBO.SYSJOBS O
    JOIN		MSDB.DBO.SYSJOBACTIVITY OA
		ON	O.job_id = OA.job_id
    JOIN		(
			SELECT	MAX(SESSION_ID) AS SESSION_ID
			FROM		MSDB.DBO.SYSSESSIONS
			) S
		ON	OA.session_ID = S.SESSION_ID
    LEFT JOIN	MSDB.DBO.SYSJOBHISTORY JH
		ON	OA.job_history_id = JH.instance_id
    WHERE		O.name = @pJobName

    RETURN ISNULL(@status, -2)
END
GO
