SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*
EXEC	[dbo].[dbasp_HealthCheck_MirrorAndAG]
		@Recipients		= 'dbasupport@virtuoso.com;sql@virtuoso.pagerduty.com'
		,@RequiredMirroredDBs	= 'AppLogArchive|EnterpriseServices|TravelMart_DNN|VCOM|ComposerSL|GEOdata|TRANSIENT|DBAOps'


*/


CREATE   PROCEDURE [dbo].[dbasp_HealthCheck_MirrorAndAG]
		(
		@Recipients				VarChar(8000)	= 'sledridge@virtuoso.com'
		,@RequiredMirroredDBs	VarChar(8000)	= NULL
		)
AS
BEGIN
	SET NOCOUNT ON


	exec msdb.sys.sp_dbmmonitorupdate


	DECLARE @DbName							SYSNAME
		,@synchronization_state_desc		SYSNAME
		,@synchronization_health_desc		SYSNAME
		,@database_state_desc				SYSNAME
		,@is_suspended						BIT
		,@suspend_reason_desc				SYSNAME
		,@last_sent_time					DateTime
		,@last_received_time				DateTime
		,@operational_state_desc			SYSNAME
		,@recovery_health_desc				SYSNAME
		,@role_desc							SYSNAME
		,@last_connect_error_description	SYSNAME
		,@last_connect_error_number			INT
		,@last_connect_error_timestamp		DateTime
		,@mirroring_role_desc				SYSNAME
		,@mirroring_state_desc				SYSNAME


		,@IsMirrored						BIT
		,@IsMirrorHealthy					BIT
		,@IsInAG							BIT
		,@IsAGHealthy						BIT
		,@IsAGError							BIT


		,@Subject							VarChar(1000)
		,@MSG								VarChar(8000)
		,@instlevel							Int


	-- GET COMPATIBILITY LEVEL FOR THE MASTER DATABASE
	SELECT		@instlevel = cmptlevel
	FROM		master.dbo.sysdatabases
	WHERE		name = 'master'


	-- get status for mirrored databases
	IF @instlevel >= 110
	BEGIN
		DECLARE AGorMirrorDB CURSOR
		FOR
		-- SELECT QUERY FOR CURSOR
		SELECT		T1.Name DBName
					,T2.synchronization_state_desc
					,T2.synchronization_health_desc
					,T2.database_state_desc
					,T2.is_suspended
					,T2.suspend_reason_desc
					,T2.last_sent_time
					,T2.last_received_time
					,T3.operational_state_desc
					,T3.recovery_health_desc
					,T3.role_desc
					,T3.last_connect_error_description
					,T3.last_connect_error_number
					,T3.last_connect_error_timestamp
					,T4.mirroring_role_desc
					,T4.mirroring_state_desc
		FROM		sys.databases T1
		LEFT JOIN	sys.dm_hadr_database_replica_states T2
			ON		T1.database_id = T2.database_id
			AND		T2.is_local = 1
		LEFT JOIN	sys.dm_hadr_availability_replica_states T3
			ON		T2.replica_id = T3.replica_id
			AND		T2.group_id = T3.group_id
		LEFT JOIN	sys.database_mirroring T4
			ON		T1.database_id = T4.database_id
		WHERE		T2.database_id IS NOT NULL
			OR		T4.mirroring_guid IS NOT NULL
			OR		T1.name IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@RequiredMirroredDBs,'|'))
	END
	ELSE
	BEGIN
		DECLARE AGorMirrorDB CURSOR
		FOR
		-- SELECT QUERY FOR CURSOR
		SELECT		T1.Name DBName
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,T4.mirroring_role_desc
				,T4.mirroring_state_desc
		FROM		sys.databases T1
		LEFT JOIN	sys.database_mirroring T4
			ON	T1.database_id = T4.database_id
		WHERE		T4.mirroring_guid IS NOT NULL
			OR		T1.name IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@RequiredMirroredDBs,'|'))
	END


	OPEN AGorMirrorDB;
	FETCH AGorMirrorDB INTO @DbName,@synchronization_state_desc,@synchronization_health_desc,@database_state_desc,@is_suspended
				,@suspend_reason_desc,@last_sent_time,@last_received_time,@operational_state_desc,@recovery_health_desc
				,@role_desc,@last_connect_error_description,@last_connect_error_number,@last_connect_error_timestamp
				,@mirroring_role_desc,@mirroring_state_desc;


	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			----------------------------
			---------------------------- CURSOR LOOP TOP
			SET @IsMirrorHealthy = NULL
			SET @IsAGHealthy = NULL


			-- CHECK MIRRORED DATABASE
			IF @mirroring_role_desc IS NOT NULL
			BEGIN
				--RAISERROR('1 %s',-1,-1,@DbName) WITH NOWAIT
				SET @IsMirrored = 1
				IF @mirroring_state_desc IN ('SYNCHRONIZED','SYNCHRONIZING')
				BEGIN
					--RAISERROR('2 %s',-1,-1,@DbName) WITH NOWAIT
					SET @IsMirrorHealthy = 1
				END
				ELSE
				BEGIN -- MIRROR IS NOT HEALTHY
					--RAISERROR('3 %s',-1,-1,@DbName) WITH NOWAIT
					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
					SET @IsMirrorHealthy	= 0
					SET @Subject			= @@servername+'.'+ @DbName + ' - DB Mirroring is '+@mirroring_state_desc +' - Notify DBA'
					SET @MSG				= 'SERVER         : ' + @@ServerName + CHAR(13) + CHAR(10)
											+ 'DATABASE       : ' + @DBName + CHAR(13) + CHAR(10)
											+ 'DATE/TIME      : ' + CAST(Getdate() AS VarChar(50))
											+ 'MIRRORING ROLE : ' + @mirroring_role_desc + CHAR(13) + CHAR(10)
											+ 'MIRRORING STATE: ' + @mirroring_state_desc + CHAR(13) + CHAR(10)


					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
				END
			END
			ELSE IF @DbName IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@RequiredMirroredDBs,'|'))
			BEGIN
				--RAISERROR('4 %s',-1,-1,@DbName) WITH NOWAIT
				SET @IsMirrored = 0
				SET @IsMirrorHealthy = 0
				SET @Subject			= @@servername+'.'+ @DbName + ' - DB Mirroring is not enabled and is included in the Required List - Notify DBA'
				SET @MSG				= 'SERVER         : ' + @@ServerName + CHAR(13) + CHAR(10)
										+ 'DATABASE       : ' + @DBName + CHAR(13) + CHAR(10)
										+ 'DATE/TIME      : ' + CAST(Getdate() AS VarChar(50))
			END
			ELSE
			BEGIN
				--RAISERROR('5 %s',-1,-1,@DbName) WITH NOWAIT
				SET @IsMirrored = 0
			END


			-- CHECK AG DATABASE
			IF @synchronization_state_desc IS NOT NULL
			BEGIN
				--RAISERROR('6 %s',-1,-1,@DbName) WITH NOWAIT
				SET @IsInAG = 1
				IF @synchronization_health_desc IN ('HEALTHY')
				BEGIN
					--RAISERROR('7 %s',-1,-1,@DbName) WITH NOWAIT
					SET @IsAGHealthy = 1
				END
				ELSE
				BEGIN
					--RAISERROR('8 %s',-1,-1,@DbName) WITH NOWAIT
					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
					SET @IsAGHealthy	= 0
					SET @Subject		= @@servername+'.'+ @DbName + ' - Availability Group Replica is '+@synchronization_state_desc +' - Notify DBA'
					SET @MSG		= 'SERVER                  : ' + @@ServerName + CHAR(13) + CHAR(10)
								+ 'DATABASE                : ' + @DBName + CHAR(13) + CHAR(10)
								+ 'DATE/TIME               : ' + CAST(Getdate() AS VarChar(50))
								+ 'SYNCHRONIZATION HEALTH  : ' + @synchronization_health_desc + CHAR(13) + CHAR(10)
								+ 'SYNCHRONIZATION STATE   : ' + @synchronization_state_desc + CHAR(13) + CHAR(10)


								+ 'DATABASE STATE          : ' + @database_state_desc + CHAR(13) + CHAR(10)
								+ 'OPERATIONAL STATE       : ' + @operational_state_desc + CHAR(13) + CHAR(10)
								+ CASE @is_suspended
									WHEN 1
									THEN 'DATABASE SUSPENDED FOR  : ' + @suspend_reason_desc + CHAR(13) + CHAR(10)
									ELSE '' END
								+ 'ROLE                    : ' + @role_desc + CHAR(13) + CHAR(10)
								+ 'LAST SENT TIME          : ' + @last_sent_time + CHAR(13) + CHAR(10)
								+ 'LAST RECEIVED TIME      : ' + @last_received_time + CHAR(13) + CHAR(10)
								+ CASE
									WHEN @last_connect_error_number IS NOT NULL
									THEN 'LAST CONNECT ERROR      : ' + @last_connect_error_description + CHAR(13) + CHAR(10) +
									     'LAST CONNECT ERROR #    : ' + @last_connect_error_description + CHAR(13) + CHAR(10) +
									     'LAST CONNECT ERROR DATE : ' + @last_connect_error_description + CHAR(13) + CHAR(10)
									ELSE '' END


					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------


				END
			END
			ELSE
			BEGIN
				--RAISERROR('9 %s',-1,-1,@DbName) WITH NOWAIT
				SET @IsInAG = 0
			END


			IF @IsMirrorHealthy = 0 OR @IsAGHealthy = 0
			BEGIN
				--RAISERROR('10 %s',-1,-1,@DbName) WITH NOWAIT
				-- SEND MESSAGE
				EXEC msdb.dbo.sp_send_dbmail
					@recipients	= @Recipients
					,@subject	= @Subject
					,@body		= @MSG


				-- RAISE ALLERT
				RAISERROR(@Subject,-1,-1) WITH LOG,NOWAIT


			END


			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM AGorMirrorDB INTO @DbName,@synchronization_state_desc,@synchronization_health_desc,@database_state_desc,@is_suspended
						,@suspend_reason_desc,@last_sent_time,@last_received_time,@operational_state_desc,@recovery_health_desc
						,@role_desc,@last_connect_error_description,@last_connect_error_number,@last_connect_error_timestamp
						,@mirroring_role_desc,@mirroring_state_desc;
	END
	CLOSE AGorMirrorDB;
	DEALLOCATE AGorMirrorDB;
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_HealthCheck_MirrorAndAG] TO [public]
GO
