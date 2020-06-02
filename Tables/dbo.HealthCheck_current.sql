CREATE TABLE [dbo].[HealthCheck_current]
(
[DBname] [sys].[sysname] NOT NULL,
[Check_type] [sys].[sysname] NOT NULL,
[Check_detail] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Check_date] [datetime] NULL CONSTRAINT [DF__HealthChe__Check__7B5B524B] DEFAULT (getdate())
) ON [PRIMARY]
GO
