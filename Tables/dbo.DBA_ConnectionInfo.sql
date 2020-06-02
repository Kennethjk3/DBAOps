CREATE TABLE [dbo].[DBA_ConnectionInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[DBName] [sys].[sysname] NOT NULL,
[LoginName] [sys].[sysname] NULL,
[HostName] [sys].[sysname] NULL,
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_Conne__modda__5BE2A6F2] DEFAULT (getdate())
) ON [PRIMARY]
GO
