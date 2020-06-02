CREATE TABLE [dbo].[Security_Orphan_Log]
(
[SOL_id] [int] NOT NULL IDENTITY(1, 1),
[SOL_name] [sys].[sysname] NOT NULL,
[SOL_type] [sys].[sysname] NOT NULL,
[SOL_DBname] [sys].[sysname] NULL,
[Initial_Date] [datetime] NULL,
[Last_Date] [datetime] NULL,
[Delete_flag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
