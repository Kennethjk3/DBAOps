CREATE TABLE [dbo].[filescan_exclude]
(
[scantext] [nchar] (125) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[useflag] [nchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_filescan_exclude] ON [dbo].[filescan_exclude] ([scantext]) ON [PRIMARY]
GO
