CREATE TABLE [dbo].[DBA_DiskPerfinfo]
(
[SQLname] [sys].[sysname] NOT NULL,
[MasterPath] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Master_Push_BytesSec] [bigint] NULL,
[Master_Pull_BytesSec] [bigint] NULL,
[MDFPath] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MDF_Push_BytesSec] [bigint] NULL,
[MDF_Pull_BytesSec] [bigint] NULL,
[LDFPath] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LDF_Push_BytesSec] [bigint] NULL,
[LDF_Pull_BytesSec] [bigint] NULL,
[TempdbPath] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Tempdb_Push_BytesSec] [bigint] NULL,
[Tempdb_Pull_BytesSec] [bigint] NULL,
[CreateDate] [datetime] NOT NULL
) ON [PRIMARY]
GO
