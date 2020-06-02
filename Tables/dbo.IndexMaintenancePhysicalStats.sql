CREATE TABLE [dbo].[IndexMaintenancePhysicalStats]
(
[imPhysicalStatsId] [bigint] NOT NULL IDENTITY(1, 1),
[insert_date] [datetime] NULL,
[scan_started] [datetime] NULL,
[database_id] [int] NULL,
[object_id] [int] NULL,
[tablename] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[index_id] [int] NULL,
[partition_number] [int] NULL,
[index_depth] [tinyint] NULL,
[index_level] [tinyint] NULL,
[avg_fragmentation_in_percent] [float] NULL,
[page_count] [bigint] NULL,
[avg_page_space_used_in_percent] [float] NULL,
[record_count] [bigint] NULL,
[min_record_size_in_bytes] [int] NULL,
[max_record_size_in_bytes] [int] NULL,
[avg_record_size_in_bytes] [float] NULL,
[user_seeks] [bigint] NULL,
[user_scans] [bigint] NULL,
[user_lookups] [bigint] NULL,
[user_updates] [bigint] NULL,
[system_seeks] [bigint] NULL,
[system_scans] [bigint] NULL,
[system_lookups] [bigint] NULL,
[system_updates] [bigint] NULL,
[ActionTaken] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActionStarted] [datetime] NULL,
[ActionCompleted] [datetime] NULL,
[Splits] [int] NULL
) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'description', N'Level of fragmentation', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'avg_fragmentation_in_percent'
GO
EXEC sp_addextendedproperty N'description', N'Avg page fill-- null if Limited scan was run', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'avg_page_space_used_in_percent'
GO
EXEC sp_addextendedproperty N'description', N'avg record size for this level of this index-- null if Limited scan was run', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'avg_record_size_in_bytes'
GO
EXEC sp_addextendedproperty N'description', N'System Database_Id in which the physical stats are located.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'database_id'
GO
EXEC sp_addextendedproperty N'description', N'Sequential number to identify the row.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'imPhysicalStatsId'
GO
EXEC sp_addextendedproperty N'description', N'Number of levels in the given index.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'index_depth'
GO
EXEC sp_addextendedproperty N'description', N'System id for the index on the table. 1= clustered index.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'index_id'
GO
EXEC sp_addextendedproperty N'description', N'Number of level for this row of data. 0= leaf level.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'index_level'
GO
EXEC sp_addextendedproperty N'description', N'Datetime at which the object scan started', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'insert_date'
GO
EXEC sp_addextendedproperty N'description', N'max record size for this level of this index-- null if Limited scan was run', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'max_record_size_in_bytes'
GO
EXEC sp_addextendedproperty N'description', N'lowest record size for this level of this index-- null if Limited scan was run', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'min_record_size_in_bytes'
GO
EXEC sp_addextendedproperty N'description', N'System object_id', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'object_id'
GO
EXEC sp_addextendedproperty N'description', N'Number of pages at this level of this index.', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'page_count'
GO
EXEC sp_addextendedproperty N'description', N'1-based partition number within the owning object; a table, view, or index. .', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'partition_number'
GO
EXEC sp_addextendedproperty N'description', N'Records in this level of this index -- null if Limited scan was run', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'record_count'
GO
EXEC sp_addextendedproperty N'description', N'Datetime at which the job run pulling the data started', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'scan_started'
GO
EXEC sp_addextendedproperty N'description', N'Schema + . + tablename on which the index lives', 'SCHEMA', N'dbo', 'TABLE', N'IndexMaintenancePhysicalStats', 'COLUMN', N'tablename'
GO
