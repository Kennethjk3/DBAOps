CREATE TABLE [dbo].[SrvBrkrQueues]
(
[DBName] [sys].[sysname] NOT NULL,
[QName] [sys].[sysname] NOT NULL,
[IgnoreExistance] [bit] NULL,
[IgnoreReceive] [bit] NULL,
[IgnoreActivation] [bit] NULL
) ON [PRIMARY]
GO
