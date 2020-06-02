CREATE TABLE [dbo].[DBA_AuditChanges]
(
[DBA_ACid] [int] NOT NULL IDENTITY(1, 1),
[Tablename] [sys].[sysname] NULL,
[ColumnName] [sys].[sysname] NULL,
[Event] [sys].[sysname] NULL,
[DataKey] [sql_variant] NULL,
[OldValue] [sql_variant] NULL,
[NewValue] [sql_variant] NULL,
[moddate] [datetime] NULL CONSTRAINT [DF__DBA_Audit__modda__06CD04F7] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DBA_AuditChanges] ADD CONSTRAINT [PK_DBA_AuditChanges] PRIMARY KEY CLUSTERED  ([DBA_ACid]) ON [PRIMARY]
GO
