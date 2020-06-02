CREATE TABLE [dbo].[filescan_temp]
(
[fulltext] [nchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_filescan_temp] ON [dbo].[filescan_temp] ([fulltext]) ON [PRIMARY]
GO
