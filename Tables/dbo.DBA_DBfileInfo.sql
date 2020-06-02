CREATE TABLE [dbo].[DBA_DBfileInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[DBName] [sys].[sysname] NOT NULL,
[LogicalName] [sys].[sysname] NOT NULL,
[File_ID] [int] NULL,
[FileType] [sys].[sysname] NULL,
[Usage] [sys].[sysname] NULL,
[FileGroup] [sys].[sysname] NULL,
[FilePath] [varchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Filename] [sys].[sysname] NULL,
[State] [sys].[sysname] NULL,
[Size_MB] [int] NULL,
[FreeSpace_MB] [int] NULL,
[MaxSize_MB] [int] NULL,
[Growth] [sys].[sysname] NULL,
[is_media_read_only] [bit] NULL,
[is_read_only] [bit] NULL,
[is_sparse] [bit] NULL,
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_DBfil__modda__5629CD9C] DEFAULT (getdate())
) ON [PRIMARY]
GO
