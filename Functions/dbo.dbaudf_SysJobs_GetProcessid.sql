SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_SysJobs_GetProcessid](@job_id uniqueidentifier)
RETURNS VARCHAR(8)
AS
BEGIN
RETURN (substring(left(@job_id,8),7,2) +
                        substring(left(@job_id,8),5,2) +
                        substring(left(@job_id,8),3,2) +
                        substring(left(@job_id,8),1,2))
END
GO
