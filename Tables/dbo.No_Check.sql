CREATE TABLE [dbo].[No_Check]
(
[nocheckID] [int] NOT NULL IDENTITY(1, 1),
[NoCheck_type] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail01] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail02] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail03] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[detail04] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[addedby] [sys].[sysname] NOT NULL CONSTRAINT [DF__No_Check__addedb__38996AB5] DEFAULT (suser_sname()),
[createdate] [datetime] NULL CONSTRAINT [DF__No_Check__create__398D8EEE] DEFAULT (getdate()),
[moddate] [datetime] NULL CONSTRAINT [DF__No_Check__moddat__3A81B327] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[No_Check] ADD CONSTRAINT [PK_DBA_NoCheck] PRIMARY KEY CLUSTERED  ([nocheckID]) ON [PRIMARY]
GO
