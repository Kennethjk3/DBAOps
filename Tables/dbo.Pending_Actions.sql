CREATE TABLE [dbo].[Pending_Actions]
(
[PAid] [int] NOT NULL IDENTITY(1, 1),
[cmd_text] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CreateDate] [datetime] NOT NULL,
[RequestDate] [datetime] NOT NULL,
[CompletedDate] [datetime] NULL
) ON [PRIMARY]
GO
