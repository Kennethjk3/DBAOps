CREATE TABLE [dbo].[HealthCheckLog]
(
[HC_ID] [bigint] NOT NULL IDENTITY(1, 1),
[HCcat] [sys].[sysname] NOT NULL,
[HCtype] [sys].[sysname] NOT NULL,
[HCstatus] [sys].[sysname] NOT NULL,
[HCPriority] [sys].[sysname] NULL,
[HCtest] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBname] [sys].[sysname] NULL,
[Check_detail01] [sys].[sysname] NULL,
[Check_detail02] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Check_date] [datetime] NULL CONSTRAINT [DF__HealthChe__Check__7F2BE32F] DEFAULT (getdate())
) ON [PRIMARY]
GO
