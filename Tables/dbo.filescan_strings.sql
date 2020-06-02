CREATE TABLE [dbo].[filescan_strings]
(
[fs_ID] [int] NOT NULL IDENTITY(1, 1),
[fs_type] [sys].[sysname] NOT NULL,
[fs_string] [sys].[sysname] NOT NULL
) ON [PRIMARY]
GO
