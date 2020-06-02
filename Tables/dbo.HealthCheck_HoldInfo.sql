CREATE TABLE [dbo].[HealthCheck_HoldInfo]
(
[HCcat] [sys].[sysname] NOT NULL,
[HCtype] [sys].[sysname] NOT NULL,
[DBname] [sys].[sysname] NULL,
[detail01] [sys].[sysname] NULL,
[detail02] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
