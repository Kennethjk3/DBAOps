CREATE TABLE [dbo].[IndexMaintenanceLastRunDetails]
(
[DatabaseName] [sys].[sysname] NOT NULL,
[TableName] [sys].[sysname] NOT NULL,
[IndexName] [sys].[sysname] NOT NULL,
[Process] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Reason] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[createdate] [datetime] NULL CONSTRAINT [DF__IndexMain__creat__75A278F5] DEFAULT (getdate())
) ON [PRIMARY]
GO
