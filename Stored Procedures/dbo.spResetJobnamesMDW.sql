SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[spResetJobnamesMDW]
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
   name                     = SUBSTRING(j.name, 1, 15) + c.name + SUBSTRING(j.name, 17, LEN(j.name))
  ,owner_sid                = 0x01
  ,notify_level_eventlog    = 3
  ,notify_level_email       = 2
  ,notify_email_operator_id = @OperatorId
  FROM msdb.dbo.sysjobs j
  INNER JOIN msdb.dbo.syscollector_collection_sets c
  ON c.collection_job_id    = j.Job_id
  WHERE j.notify_level_eventlog <> 3


  UPDATE msdb.dbo.sysjobs SET
   name                     = SUBSTRING(j.name, 1, 15) + c.name + SUBSTRING(j.name, 17, LEN(j.name))
  ,owner_sid                = 0x01
  ,notify_level_eventlog    = 3
  ,notify_level_email       = 2
  ,notify_email_operator_id = @OperatorId
  FROM msdb.dbo.sysjobs j
  INNER JOIN msdb.dbo.syscollector_collection_sets c
  ON c.upload_job_id        = j.Job_id
  WHERE j.notify_level_eventlog <> 3


  UPDATE msdb.dbo.sysjobs SET
   owner_sid                = 0x01
  ,notify_level_eventlog    = 3
  ,notify_level_email       = 2
  ,notify_email_operator_id = @OperatorId
  WHERE name                LIKE 'mdw_purge_data_%'
  AND notify_level_eventlog <> 3


END
GO
GRANT EXECUTE ON  [dbo].[spResetJobnamesMDW] TO [public]
GO
