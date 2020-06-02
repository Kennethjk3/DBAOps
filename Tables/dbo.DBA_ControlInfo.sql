CREATE TABLE [dbo].[DBA_ControlInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[ControlTbl] [sys].[sysname] NOT NULL,
[Subject] [sys].[sysname] NULL,
[detail01] [sys].[sysname] NULL,
[detail02] [sys].[sysname] NULL,
[detail03] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail04] [sys].[sysname] NULL,
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_Contr__modda__59FA5E80] DEFAULT (getdate())
) ON [PRIMARY]
GO
