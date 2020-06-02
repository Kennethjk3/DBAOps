CREATE TABLE [dbo].[db_stats_log]
(
[ServerName] [sys].[sysname] NOT NULL,
[DatabaseName] [sys].[sysname] NOT NULL,
[rundate] [datetime] NOT NULL,
[database_size_MB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[unallocated space_MB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[reserved_space_KB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[data_space_used_KB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[index_size_used_KB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[unused_space_KB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[log_size_MB] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[log_space_used_pct] [varchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
