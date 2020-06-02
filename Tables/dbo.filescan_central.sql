CREATE TABLE [dbo].[filescan_central]
(
[fc_ID] [int] NOT NULL IDENTITY(1, 1),
[fulltext] [nchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[reported] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
