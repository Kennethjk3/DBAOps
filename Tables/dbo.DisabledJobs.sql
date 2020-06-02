CREATE TABLE [dbo].[DisabledJobs]
(
[Job_ID] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[JobName] [sys].[sysname] NOT NULL,
[Disable_date] [datetime] NOT NULL CONSTRAINT [DF__DisabledJ__Disab__3C69FB99] DEFAULT (getdate())
) ON [PRIMARY]
GO
