CREATE TABLE [dbo].[FailedJobs]
(
[instance_ID] [int] NOT NULL,
[Job_ID] [uniqueidentifier] NOT NULL,
[run_status] [int] NOT NULL,
[run_date] [int] NOT NULL
) ON [PRIMARY]
GO
