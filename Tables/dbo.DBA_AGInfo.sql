CREATE TABLE [dbo].[DBA_AGInfo]
(
[ServerName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[moddate] [datetime] NOT NULL,
[group_id] [uniqueidentifier] NOT NULL,
[name] [sys].[sysname] NULL,
[resource_id] [nvarchar] (40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[resource_group_id] [nvarchar] (40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[failure_condition_level] [int] NULL,
[health_check_timeout] [int] NULL,
[automated_backup_preference] [tinyint] NULL,
[automated_backup_preference_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[version] [smallint] NULL,
[basic_features] [bit] NULL,
[dtc_support] [bit] NULL,
[db_failover] [bit] NULL,
[is_distributed] [bit] NULL,
[replica_id] [uniqueidentifier] NULL,
[replica_metadata_id] [int] NULL,
[replica_server_name] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[owner_sid] [varbinary] (85) NULL,
[endpoint_url] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[availability_mode] [tinyint] NULL,
[availability_mode_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[failover_mode] [tinyint] NULL,
[failover_mode_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[session_timeout] [int] NULL,
[primary_role_allow_connections] [tinyint] NULL,
[primary_role_allow_connections_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[secondary_role_allow_connections] [tinyint] NULL,
[secondary_role_allow_connections_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[create_date] [datetime] NULL,
[modify_date] [datetime] NULL,
[backup_priority] [int] NULL,
[read_only_routing_url] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[seeding_mode] [tinyint] NULL,
[seeding_mode_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[listener_id] [nvarchar] (36) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dns_name] [nvarchar] (63) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[port] [int] NULL,
[is_conformant] [bit] NOT NULL,
[ip_configuration_string_from_cluster] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[is_local] [bit] NOT NULL,
[role] [tinyint] NULL,
[role_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[operational_state] [tinyint] NULL,
[operational_state_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[connected_state] [tinyint] NULL,
[connected_state_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[recovery_health] [tinyint] NULL,
[recovery_health_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[synchronization_health] [tinyint] NULL,
[synchronization_health_desc] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[last_connect_error_number] [int] NULL,
[last_connect_error_description] [nvarchar] (1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[last_connect_error_timestamp] [datetime] NULL
) ON [PRIMARY]
GO