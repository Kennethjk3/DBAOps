CREATE TABLE [dbo].[DBA_CommentInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[CommentNum] [int] NOT NULL IDENTITY(1, 1),
[CommentTitle] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CommentText] [ntext] COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_DBA_CommentInfo] ON [dbo].[DBA_CommentInfo] ([SQLName], [CommentNum]) ON [PRIMARY]
GO
