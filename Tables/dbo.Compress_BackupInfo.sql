CREATE TABLE [dbo].[Compress_BackupInfo]
(
[servername] [sys].[sysname] NOT NULL,
[SQLname] [sys].[sysname] NOT NULL,
[CompType] [sys].[sysname] NOT NULL,
[Version] [sys].[sysname] NULL,
[VersionType] [sys].[sysname] NULL,
[License] [sys].[sysname] NULL,
[InstallDate] [datetime] NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [Compress_BackupInfo_ix1] ON [dbo].[Compress_BackupInfo] ([servername]) ON [PRIMARY]
GO
