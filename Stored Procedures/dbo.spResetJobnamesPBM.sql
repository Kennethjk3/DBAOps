SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[spResetJobnamesPBM]
--  Copyright c 2010 Edward Vassie.  Distributed under Ms-Pl License
--
--  Author: Ed Vassie
--
AS BEGIN
  SET NOCOUNT ON


  DECLARE
   @OperatorId      int
  ,@rc              int


  SELECT
   @OperatorId      = 0
  ,@rc              = 0


  SELECT @OperatorId        = id
  FROM msdb.dbo.sysoperators
  WHERE name                = N'SQL Alerts'


  UPDATE msdb.dbo.sysjobs SET
   owner_sid=0x01
  ,notify_level_eventlog    = 3
  ,notify_level_email       = 2
  ,notify_email_operator_id = @OperatorId
  WHERE name                = 'syspolicy_purge_history'
  AND notify_level_eventlog <> 3


  UPDATE msdb.dbo.sysjobs SET
   name                     = SUBSTRING(j.name, 1, 25) + s.name
  ,owner_sid                = 0x01
  ,notify_level_eventlog    = 3
  ,notify_level_email       = 2
  ,notify_email_operator_id = @OperatorId
  FROM msdb.dbo.sysjobs j
  INNER JOIN msdb.dbo.sysjobschedules js
  ON js.job_id              = j.job_id
  INNER JOIN msdb.dbo.sysschedules s
  ON js.schedule_id         = s.schedule_id
  WHERE j.name              LIKE 'syspolicy_check_schedule_%'
  AND j.notify_level_eventlog <> 3


END
GO
GRANT EXECUTE ON  [dbo].[spResetJobnamesPBM] TO [public]
GO
