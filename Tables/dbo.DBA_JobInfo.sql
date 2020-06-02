CREATE TABLE [dbo].[DBA_JobInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[JobName] [sys].[sysname] NOT NULL,
[Enabled] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Owner] [sys].[sysname] NULL,
[Description] [nvarchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[JobSteps] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[JobSchedules] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartStep] [int] NULL,
[AvgDurationMin] [int] NULL,
[PassCheck] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Created] [datetime] NULL,
[Modified] [datetime] NULL,
[LastExecuted] [datetime] NULL,
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_JobIn__modda__5812160E] DEFAULT (getdate()),
[PassCheckDesc] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
