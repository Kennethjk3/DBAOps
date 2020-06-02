CREATE TABLE [dbo].[Periodic_Errors]
(
[error_id] [int] NOT NULL IDENTITY(1, 1),
[alert_num] [int] NOT NULL,
[Message_text] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
