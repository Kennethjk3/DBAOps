SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_MirrorAGHealthCheck]
		(
		@Recipients				VarChar(2000) = 'DBANotify@${{secrets.DOMAIN_NAME}}'
		)


/*********************************************************
 **  Stored Procedure dbasp_MirrorAGHealthCheck
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 11, 2015
 **
 **  This dbasp is set up to check Mirroring and AvailGrp
 **  health and alert if problems are found.
 **
 ***************************************************************/
AS
SET ANSI_WARNINGS OFF
SET NOCOUNT ON


/*
declare @Recipients VarChar(2000)


select @Recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}'
--*/


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	12/11/2015	Steve Ledridge		New process
--	06/23/2016	Steve Ledridge		Added 2nd AvailGrp Check
--	07/01/2016	Steve Ledridge		Added 4 min wait for 2nd AvailGrp Check alert
--	08/08/2016	Steve Ledridge		Fixed cast for date and time values.
--	11/22/2016	Steve Ledridge		Added AG DB update to the Local_Control table.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================


BEGIN


		exec msdb.sys.sp_dbmmonitorupdate


	DECLARE
		 @miscprint							varchar(255)
		,@DbName							SYSNAME
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
		,@save_productversion				sysname
		,@health_count						smallint


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   Check Mirror and AG Status '
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


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
			ON	T1.database_id = T2.database_id
			AND	T2.is_local = 1
		LEFT JOIN	sys.dm_hadr_availability_replica_states T3
			ON	T2.replica_id = T3.replica_id
			AND	T2.group_id = T3.group_id
		LEFT JOIN	sys.database_mirroring T4
			ON	T1.database_id = T4.database_id
		WHERE		T2.database_id IS NOT NULL
			OR	T4.mirroring_guid IS NOT NULL
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
				SET @IsMirrored = 1
				IF @mirroring_state_desc IN ('SYNCHRONIZED','SYNCHRONIZING')
					SET @IsMirrorHealthy = 1
				Else
				BEGIN -- MIRROR IS NOT HEALTHY
					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
					SET @IsMirrorHealthy	= 0
					SET @Subject		= @@servername+'.'+ @DbName + ' - DB Mirroring is '+@mirroring_state_desc +' - Notify DBA (next morning)'
					SET @MSG		= 'SERVER         : ' + @@ServerName + CHAR(13) + CHAR(10)
								+ 'DATABASE       : ' + @DBName + CHAR(13) + CHAR(10)
								+ 'DATE/TIME      : ' + CAST(Getdate() AS VarChar(50))
								+ 'MIRRORING ROLE : ' + @mirroring_role_desc + CHAR(13) + CHAR(10)
								+ 'MIRRORING STATE: ' + @mirroring_state_desc + CHAR(13) + CHAR(10)


					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
				END
			END
			Else
				SET @IsMirrored = 0


			-- CHECK AG DATABASE
			IF @synchronization_state_desc IS NOT NULL
			BEGIN
				If exists(select 1 from dbo.Local_Control where Subject = 'AG_DB' and Detail01 = @DbName)
				   begin
						update dbo.Local_Control set Detail02 = @role_desc where Subject = 'AG_DB' and Detail01 = @DbName
				   end
				Else
				   begin
						Insert into dbo.Local_Control values('AG_DB', @DbName, @role_desc, '')
				   end


				SET @IsInAG = 1
				IF @synchronization_health_desc IN ('HEALTHY')
					SET @IsAGHealthy = 1
				ELSE
				BEGIN


					--------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------
					SET @IsAGHealthy	= 0
					SET @Subject		= @@servername+'.'+ @DbName + ' - Availability Group Replica is '+@synchronization_state_desc +' - Notify DBA'
					SET @MSG		= 'SERVER                  : ' + @@ServerName + CHAR(13) + CHAR(10)
								+ 'DATABASE                : ' + @DBName + CHAR(13) + CHAR(10)
								+ 'DATE/TIME               : ' + CAST(Getdate() AS VarChar(50)) + CHAR(13) + CHAR(10)
								+ 'SYNCHRONIZATION HEALTH  : ' + @synchronization_health_desc + CHAR(13) + CHAR(10)
								+ 'SYNCHRONIZATION STATE   : ' + @synchronization_state_desc + CHAR(13) + CHAR(10)


								+ 'DATABASE STATE          : ' + @database_state_desc + CHAR(13) + CHAR(10)
								+ 'OPERATIONAL STATE       : ' + @operational_state_desc + CHAR(13) + CHAR(10)
								+ CASE @is_suspended
									WHEN 1
									THEN 'DATABASE SUSPENDED FOR  : ' + @suspend_reason_desc + CHAR(13) + CHAR(10)
									ELSE '' END
								+ 'ROLE                    : ' + @role_desc + CHAR(13) + CHAR(10)
								+ 'LAST SENT TIME          : ' + CAST(@last_sent_time AS VarChar(50)) + CHAR(13) + CHAR(10)
								+ 'LAST RECEIVED TIME      : ' + CAST(@last_received_time AS VarChar(50)) + CHAR(13) + CHAR(10)
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
				SET @IsInAG = 0


			IF @IsMirrorHealthy = 0 OR @IsAGHealthy = 0
			   BEGIN
			--  If this has been reported in the past 1 hours, skip this section
				If exists (select 1 from dbo.No_Check where NoCheck_type = 'IsMirrorAGHealthy' and detail01 = @@servername and datediff(hh, createdate, getdate()) < 1)
				   begin
					Print 'Skip IsMirrorAGHealthy alert'
					Print @Subject
					goto skip_mirror_alert
				   end
				Else
				   begin
					Delete from dbo.No_Check where NoCheck_type = 'IsMirrorAGHealthy' and detail01 = @@servername
					insert into dbo.No_Check values ('IsMirrorAGHealthy', @@servername, '', '', '', 'periodic_check', getdate(), getdate())
				   end


				-- SEND MESSAGE
				EXEC DBAOps.dbo.dbasp_sendmail
					@recipients	= @Recipients
					,@subject	= @Subject
					,@message	= @MSG


				-- RAISE ALLERT
				RAISERROR(67016, 16, -1, @Subject) WITH LOG,NOWAIT
			   END


			skip_mirror_alert:
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


	--  @2nd availgrp check
	IF @@microsoftversion / 0x01000000 >= 11
	  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
	   BEGIN
		If exists (select 1 from sys.availability_groups_cluster)
		   begin
			Select @health_count = 0
			start_availtwo:


			If exists (select top 1 ar.replica_server_name
					from sys.dm_hadr_availability_replica_states ars
					inner join sys.availability_replicas ar on ars.replica_id = ar.replica_id
					where ars.synchronization_health_desc <> 'HEALTHY'
					and exists (select 1 from sys.dm_hadr_database_replica_states drs where drs.replica_id = ars.replica_id))
			   begin
				--  Info sent to the job log output for diag
				select * from sys.dm_hadr_database_replica_states


				select * from sys.dm_hadr_database_replica_cluster_states


				Select @synchronization_health_desc = (select top 1 ars.synchronization_health_desc
									from sys.dm_hadr_availability_replica_states ars
									inner join sys.availability_replicas ar on ars.replica_id = ar.replica_id
									where ars.synchronization_health_desc <> 'HEALTHY'
									and exists (select 1 from sys.dm_hadr_database_replica_states drs where drs.replica_id = ars.replica_id))
				SET @Subject		= @@servername+' - Availability Group Replica is not healthy - Notify DBA'
				SET @MSG		= 'SERVER                  : ' + @@ServerName + CHAR(13) + CHAR(10)
							+ 'DATE/TIME               : ' + CAST(Getdate() AS VarChar(50))
							+ 'SYNCHRONIZATION HEALTH  : ' + @synchronization_health_desc + CHAR(13) + CHAR(10)


				If @health_count < 2
				   begin
					Select @health_count = @health_count +1
					Print 'Initial 2nd_availgrp_check alert detected.  Waiting 2 min.'
					WAITFOR DELAY '00:01:59'
					goto start_availtwo
				   end


				--  If this has been reported in the past 1 hours, skip this section
				If exists (select 1 from dbo.No_Check where NoCheck_type = '2nd_availgrp_check' and detail01 = @@servername and datediff(hh, createdate, getdate()) < 1)
				   begin
					Print 'Skip 2nd_availgrp_check alert'
					Print @Subject
					goto skip_2nd_availgrp_check
				   end
				Else
				   begin
					Delete from dbo.No_Check where NoCheck_type = '2nd_availgrp_check' and detail01 = @@servername
					insert into dbo.No_Check values ('2nd_availgrp_check', @@servername, '', '', '', 'periodic_check', getdate(), getdate())
				   end


				-- SEND MESSAGE
				EXEC DBAOps.dbo.dbasp_sendmail
					@recipients	= @Recipients
					,@subject	= @Subject
					,@message	= @MSG


				-- RAISE ALLERT
				RAISERROR(67016, 16, -1, @Subject) WITH LOG,NOWAIT
			   end


			skip_2nd_availgrp_check:


		   end
	   END


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_MirrorAGHealthCheck] TO [public]
GO
