SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CheckServiceBrokerQueues]
AS
BEGIN
	SET NOCOUNT ON
	/*
	-- Done:	ADD CONTROL TABLE ENTRIES FOR EXPECTED SERVICE BROKER QUEUES
	-- ToDo:	ADD CONTROL TABLE ENTRIES TO IGNORE SPECIFIC SERVICE BROKER QUEUES


	-- */
	DECLARE @SpecificSBQs	TABLE	(
								DBName			SYSNAME
								,Name			SYSNAME
								,IgnoreExistance	BIT
								,IgnoreReceive		BIT
								,IgnoreActivation	BIT
								)


	INSERT INTO	@SpecificSBQs
		 SELECT	DBName, QName, IgnoreExistance, IgnoreReceive, IgnoreActivation from dbo.SrvBrkrQueues


	IF (OBJECT_ID('tempdb..#ServiceQueues'))		IS NOT NULL	DROP TABLE #ServiceQueues
	CREATE TABLE #ServiceQueues
				(
				[DBName]								SYSNAME
				,[name]								SYSNAME
				,[object_id]							INT
				,[principal_id]						INT		NULL
				,[schema_id]							INT
				,[parent_object_id]						INT
				,[type]								SYSNAME
				,[type_desc]							SYSNAME
				,[create_date]							DATETIME
				,[modify_date]							DATETIME
				,[is_ms_shipped]						BIT
				,[is_published]						BIT
				,[is_schema_published]					BIT
				,[max_readers]							INT
				,[activation_procedure]					VARCHAR(max)
				,[execute_as_principal_id]				INT NULL
				,[is_activation_enabled]					BIT
				,[is_receive_enabled]					BIT
				,[is_enqueue_enabled]					BIT
				,[is_retention_enabled]					BIT
				,[is_poison_message_handling_enabled]		BIT
				)


	DECLARE		@DBName								SYSNAME
				,@name								SYSNAME
				,@object_id							INT
				,@principal_id							INT
				,@schema_id							INT
				,@parent_object_id						INT
				,@type								SYSNAME
				,@type_desc							SYSNAME
				,@create_date							DATETIME
				,@modify_date							DATETIME
				,@is_ms_shipped						BIT
				,@is_published							BIT
				,@is_schema_published					BIT
				,@max_readers							INT
				,@activation_procedure					VARCHAR(MAX)
				,@execute_as_principal_id				INT
				,@is_activation_enabled					BIT
				,@is_receive_enabled					BIT
				,@is_enqueue_enabled					BIT
				,@is_retention_enabled					BIT
				,@is_poison_message_handling_enabled		BIT
				,@IgnoreExistance						BIT
				,@IgnoreReceive						BIT
				,@IgnoreActivation						BIT
				,@MSG								VARCHAR(2048)
				,@Error_Missing						bit = 0
				,@Error_Status							bit = 0
				,@CMD								VARCHAR(MAX)	=
	'
	INSERT INTO #ServiceQueues
	SELECT	''?'' [DBName],[name],[object_id],[principal_id],[schema_id],[parent_object_id],[type],[type_desc],[create_date],[modify_date],[is_ms_shipped],[is_published],[is_schema_published],[max_readers],[activation_procedure],[execute_as_principal_id],[is_activation_enabled],[is_receive_enabled],[is_enqueue_enabled],[is_retention_enabled],[is_poison_message_handling_enabled]
	FROM		[?].sys.service_queues
	WHERE	[is_ms_shipped] = 0
	'
	-- Gather service_queues from each database that is not an AG Secondary.
	exec DBAOps.dbo.dbasp_ForEachDB
			@command = @CMD
			,@suppress_quotename = 1
			,@is_ag_secondary = 0


	-- SELECT * FROM #ServiceQueues
	-----------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------
	--		TEST EXISTENCE OF SPECIFIC SERVICE BROKER QUEUES (LATER TO BE DRIVEN BY CONTROL TABLE)
	-----------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------
	DECLARE SpecificQueueCursor CURSOR
	FOR
	-- SELECT QUERY FOR CURSOR
	SELECT	*
	FROM		@SpecificSBQs
	WHERE	IgnoreExistance = 0
		AND	isnull(DBAOps.dbo.dbaudf_AG_Get_Primary(NULLIF(DBAOps.dbo.dbaudf_GetDbAg(DB_Name(DB_ID(DBName))),'ERROR: Database '+DB_Name(DB_ID(DBName))+' is NOT in an Availability Group.')),@@SERVERNAME) = @@Servername
		AND	DB_Name(DB_ID(DBName)) IS NOT NULL


	OPEN SpecificQueueCursor;
	FETCH SpecificQueueCursor INTO @DBName
							,@name
							,@IgnoreExistance
							,@IgnoreReceive
							,@IgnoreActivation;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			----------------------------
			---------------------------- CURSOR LOOP TOP
			IF NOT EXISTS		(
							SELECT	1
							FROM		#ServiceQueues
							WHERE	DBName	= @DBName
								AND	name		= @name
							)
				BEGIN
					SET @Error_Missing = 1
					SET @MSG = 'DBA ERROR: ServiceBroker: Service Broker Queue ['+@DBName+']..['+@name+'] DOES NOT EXIST.'
					RAISERROR (@MSG,-1,-1) WITH NOWAIT
					exec xp_logevent 50001,@MSG,'ERROR'
				END
			ELSE
				RAISERROR ('OK: Service Broker Queue [%s]..[%s] DOES EXIST.',-1,-1,@DBName,@name) WITH NOWAIT
			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 	FETCH NEXT FROM SpecificQueueCursor INTO @DBName
									,@name
									,@IgnoreExistance
									,@IgnoreReceive
									,@IgnoreActivation;
		END
	CLOSE SpecificQueueCursor;
	DEALLOCATE SpecificQueueCursor;


	-----------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------
	--		TEST STATUS OF ALL EXISTING NON-MS SERVICE BROKER QUEUES
	-----------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------
	DECLARE ServiceQueueCursor CURSOR
	FOR
	-- SELECT QUERY FOR CURSOR
	SELECT	*
	FROM		#ServiceQueues


	OPEN ServiceQueueCursor;
	FETCH ServiceQueueCursor INTO @DBName
							,@name
							,@object_id
							,@principal_id
							,@schema_id
							,@parent_object_id
							,@type
							,@type_desc
							,@create_date
							,@modify_date
							,@is_ms_shipped
							,@is_published
							,@is_schema_published
							,@max_readers
							,@activation_procedure
							,@execute_as_principal_id
							,@is_activation_enabled
							,@is_receive_enabled
							,@is_enqueue_enabled
							,@is_retention_enabled
							,@is_poison_message_handling_enabled;


	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			----------------------------
			---------------------------- CURSOR LOOP TOP
			IF NOT EXISTS (SELECT 1 FROM @SpecificSBQs WHERE DBName = @DBName AND Name = @Name AND IgnoreExistance = 1)
			BEGIN -- ONLY CHECK QUEUES THAT ARE NOT SET TO IGNORE EXISTENCE


				IF EXISTS (SELECT 1 FROM sys.databases WHERE is_broker_enabled = 0 AND name = @DBName)
				BEGIN
					SET @Error_Status = 1
					SET @MSG = 'DBA ERROR: ServiceBroker: '+@DBName+' Has Service Broker Queues but "is_broker_enabled" = 0 (DISABLED).'
					RAISERROR (@MSG,-1,-1) WITH NOWAIT
					exec xp_logevent 50001,@MSG,'ERROR'
				END


				IF @is_receive_enabled = 0
				IF NOT EXISTS (SELECT 1 FROM @SpecificSBQs WHERE DBName = @DBName AND Name = @Name AND IgnoreReceive = 1)
				BEGIN

					SET @Error_Status = 1
					SET @MSG = 'DBA ERROR: ServiceBroker: '+@DBName+' Has a Service Broker Queue ('+ @name +') but it''s Receive is DISABLED).'
					RAISERROR (@MSG,-1,-1) WITH NOWAIT
					exec xp_logevent 50001,@MSG,'ERROR'
				END


				IF @activation_procedure IS NOT NULL
				IF @is_activation_enabled = 0
				IF NOT EXISTS (SELECT 1 FROM @SpecificSBQs WHERE DBName = @DBName AND Name = @Name AND IgnoreActivation = 1)
				BEGIN
					SET @Error_Status = 1
					SET @MSG = 'DBA ERROR: ServiceBroker: '+@DBName+' Has a Service Broker Queue ('+ @name +') which contains an Activation Procedure ('+@activation_procedure+') But Activation is DISABLED).'
					RAISERROR (@MSG,-1,-1) WITH NOWAIT
					exec xp_logevent 50001,@MSG,'ERROR'
				END
			END
			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM ServiceQueueCursor INTO @DBName
							,@name
							,@object_id
							,@principal_id
							,@schema_id
							,@parent_object_id
							,@type
							,@type_desc
							,@create_date
							,@modify_date
							,@is_ms_shipped
							,@is_published
							,@is_schema_published
							,@max_readers
							,@activation_procedure
							,@execute_as_principal_id
							,@is_activation_enabled
							,@is_receive_enabled
							,@is_enqueue_enabled
							,@is_retention_enabled
							,@is_poison_message_handling_enabled;
	END
	CLOSE ServiceQueueCursor;
	DEALLOCATE ServiceQueueCursor;


	IF @Error_Missing = 0
		RAISERROR ('OK: All Expected Queues Were Found.',-1,-1) WITH NOWAIT

	IF @Error_Status = 0
		RAISERROR ('OK: All Non-MS Queue Statuses Were OK.',-1,-1) WITH NOWAIT


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_CheckServiceBrokerQueues] TO [public]
GO
