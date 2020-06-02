SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   PROCEDURE	[dbo].[dbasp_SelfRegister_DBA_AGInfo] 
					(
					@ForceUpgrade BIT = 0
					)
AS
BEGIN
		IF OBJECT_ID('DBA_AGInfo') IS NOT NULL AND @ForceUpgrade = 1
		BEGIN
			RAISERROR ('"@ForceUpgrade = 1" so existing Table is being Dropped',-1,-1) WITH NOWAIT
			DROP TABLE [dbo].[DBA_AGInfo]
		END

		IF OBJECT_ID('DBA_AGInfo') IS NULL
		BEGIN
			RAISERROR ('Creating New DBA_AGInfo Table',-1,-1) WITH NOWAIT

			SELECT		@@SERVERNAME	[ServerName]
						,GETDATE()		[moddate]
						,ag.group_id	
						,ag.name	
						,ag.resource_id	
						,ag.resource_group_id	
						,ag.failure_condition_level	
						,ag.health_check_timeout	
						,ag.automated_backup_preference	
						,ag.automated_backup_preference_desc	
						,ag.version	
						,ag.basic_features	
						,ag.dtc_support	
						,ag.db_failover	
						,ag.is_distributed
						,ar.replica_id	
						,ar.replica_metadata_id	
						,ar.replica_server_name	
						,ar.owner_sid	
						,ar.endpoint_url	
						,ar.availability_mode	
						,ar.availability_mode_desc	
						,ar.failover_mode	
						,ar.failover_mode_desc	
						,ar.session_timeout	
						,ar.primary_role_allow_connections	
						,ar.primary_role_allow_connections_desc	
						,ar.secondary_role_allow_connections	
						,ar.secondary_role_allow_connections_desc	
						,ar.create_date	
						,ar.modify_date	
						,ar.backup_priority	
						,ar.read_only_routing_url	
						,ar.seeding_mode	
						,ar.seeding_mode_desc
						,agl.listener_id	
						,agl.dns_name	
						,agl.port	
						,agl.is_conformant	
						,agl.ip_configuration_string_from_cluster
						,ars.is_local	
						,ars.role	
						,ars.role_desc	
						,ars.operational_state	
						,ars.operational_state_desc	
						,ars.connected_state	
						,ars.connected_state_desc	
						,ars.recovery_health	
						,ars.recovery_health_desc	
						,ars.synchronization_health	
						,ars.synchronization_health_desc	
						,ars.last_connect_error_number	
						,ars.last_connect_error_description	
						,ars.last_connect_error_timestamp
			INTO		DBA_AGInfo
			FROM		master.sys.availability_groups ag
			JOIN		master.sys.availability_replicas ar										ON	ar.group_id					= ag.group_id
																								AND	ar.replica_server_name		= @@Servername
			JOIN		master.sys.availability_group_listeners agl								ON	agl.group_id				= ag.group_id
			JOIN		master.sys.dm_hadr_availability_replica_states ars						ON ars.group_id					= ag.group_id
																								AND	ars.replica_id				= ar.replica_id
		END
		ELSE
		BEGIN
			RAISERROR ('Re-Populating DBA_AGInfo Table',-1,-1) WITH NOWAIT

			DELETE		[dbo].[DBA_AGInfo]

			INSERT INTO	[dbo].[DBA_AGInfo]
			SELECT		@@SERVERNAME	[ServerName]
						,GETDATE()		[moddate]
						,ag.group_id	
						,ag.name	
						,ag.resource_id	
						,ag.resource_group_id	
						,ag.failure_condition_level	
						,ag.health_check_timeout	
						,ag.automated_backup_preference	
						,ag.automated_backup_preference_desc	
						,ag.version	
						,ag.basic_features	
						,ag.dtc_support	
						,ag.db_failover	
						,ag.is_distributed
						,ar.replica_id	
						,ar.replica_metadata_id	
						,ar.replica_server_name	
						,ar.owner_sid	
						,ar.endpoint_url	
						,ar.availability_mode	
						,ar.availability_mode_desc	
						,ar.failover_mode	
						,ar.failover_mode_desc	
						,ar.session_timeout	
						,ar.primary_role_allow_connections	
						,ar.primary_role_allow_connections_desc	
						,ar.secondary_role_allow_connections	
						,ar.secondary_role_allow_connections_desc	
						,ar.create_date	
						,ar.modify_date	
						,ar.backup_priority	
						,ar.read_only_routing_url	
						,ar.seeding_mode	
						,ar.seeding_mode_desc
						,agl.listener_id	
						,agl.dns_name	
						,agl.port	
						,agl.is_conformant	
						,agl.ip_configuration_string_from_cluster
						,ars.is_local	
						,ars.role	
						,ars.role_desc	
						,ars.operational_state	
						,ars.operational_state_desc	
						,ars.connected_state	
						,ars.connected_state_desc	
						,ars.recovery_health	
						,ars.recovery_health_desc	
						,ars.synchronization_health	
						,ars.synchronization_health_desc	
						,ars.last_connect_error_number	
						,ars.last_connect_error_description	
						,ars.last_connect_error_timestamp
			FROM		master.sys.availability_groups ag
			JOIN		master.sys.availability_replicas ar										ON	ar.group_id					= ag.group_id
																								AND	ar.replica_server_name		= @@Servername
			JOIN		master.sys.availability_group_listeners agl								ON	agl.group_id				= ag.group_id
			JOIN		master.sys.dm_hadr_availability_replica_states ars						ON ars.group_id					= ag.group_id
																								AND	ars.replica_id				= ar.replica_id
		END
END
GO
