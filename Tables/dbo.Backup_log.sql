CREATE TABLE [dbo].[Backup_log]
(
[BLid] [int] NOT NULL IDENTITY(1, 1),
[BackupDate] [datetime] NOT NULL,
[DBname] [sys].[sysname] NOT NULL,
[Backup_filename] [sys].[sysname] NOT NULL,
[Backup_path] [sys].[sysname] NOT NULL,
[Backup_notes] [sys].[sysname] NULL
) ON [PRIMARY]
GO
