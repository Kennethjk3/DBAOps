SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetJobStatus] (
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
-- -1 = Job is Disabled
--  0 = Failed
--  1 = Succeeded
--  2 = Retry
--  3 = Canceled
--  4 = In progress
--  5 = Disabled
--  6 = Idle
-- =============================================

BEGIN
    DECLARE @status int

    SELECT
        @status = CASE
            WHEN O.enabled = 0 THEN -1
            WHEN OA.run_requested_date IS NULL THEN 6
            ELSE ISNULL(JH.RUN_STATUS, 4)
        END
    FROM MSDB.DBO.SYSJOBS O
    INNER JOIN MSDB.DBO.SYSJOBACTIVITY OA ON (O.job_id = OA.job_id)
    INNER JOIN (SELECT MAX(SESSION_ID) AS SESSION_ID FROM MSDB.DBO.SYSSESSIONS ) AS S ON (OA.session_ID = S.SESSION_ID)
    LEFT JOIN MSDB.DBO.SYSJOBHISTORY JH ON (OA.job_history_id = JH.instance_id)
    WHERE O.name = @pJobName

    RETURN ISNULL(@status, -2)
END
GO
