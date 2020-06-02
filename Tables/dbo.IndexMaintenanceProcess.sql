CREATE TABLE [dbo].[IndexMaintenanceProcess]
(
[IMP_ID] [bigint] NOT NULL IDENTITY(1, 1),
[DBname] [sys].[sysname] NOT NULL,
[TBLname] [sys].[sysname] NULL,
[MAINTsql] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Status] [sys].[sysname] NOT NULL,
[CreateDate] [datetime] NULL CONSTRAINT [DF__IndexMain__Creat__787EE5A0] DEFAULT (getdate()),
[ModDate] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IndexMaintenanceProcess] ADD CONSTRAINT [PK__IndexMai__11F0BD04C151DBE9] PRIMARY KEY CLUSTERED  ([IMP_ID]) ON [PRIMARY]
GO
