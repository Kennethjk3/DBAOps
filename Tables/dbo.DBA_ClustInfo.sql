CREATE TABLE [dbo].[DBA_ClustInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[ClusterName] [sys].[sysname] NULL,
[ClusterIP] [sys].[sysname] NULL,
[ClusterVer] [sys].[sysname] NULL,
[ResourceType] [sys].[sysname] NULL,
[ResourceName] [sys].[sysname] NULL,
[ResourceDetail] [sys].[sysname] NULL,
[GroupName] [sys].[sysname] NULL,
[CurrentOwner] [sys].[sysname] NULL,
[PreferredOwner] [sys].[sysname] NULL,
[Dependencies] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RestartAction] [sys].[sysname] NULL,
[AutoFailback] [sys].[sysname] NULL,
[Status] [sys].[sysname] NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_clust_DBA_ClustInfo] ON [dbo].[DBA_ClustInfo] ([SQLName]) ON [PRIMARY]
GO
