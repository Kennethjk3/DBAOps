CREATE TABLE [dbo].[DBA_NoCheckInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[NoCheck_type] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail01] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail02] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail03] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail04] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[addedby] [sys].[sysname] NOT NULL CONSTRAINT [DF__DBA_NoChe__added__4F7CD00D] DEFAULT (suser_sname()),
[createdate] [datetime] NULL CONSTRAINT [DF__DBA_NoChe__creat__5070F446] DEFAULT (getdate()),
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_NoChe__modda__5165187F] DEFAULT (getdate())
) ON [PRIMARY]
GO
