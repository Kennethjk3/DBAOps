CREATE TABLE [dbo].[db_ApplCrossRef]
(
[seq_id] [int] NOT NULL IDENTITY(1, 1),
[db_name] [sys].[sysname] NOT NULL,
[companionDB_name] [sys].[sysname] NULL,
[RSTRfolder] [sys].[sysname] NULL,
[Appl_desc] [sys].[sysname] NULL,
[baseline_srvname] [sys].[sysname] NULL
) ON [PRIMARY]
GO
