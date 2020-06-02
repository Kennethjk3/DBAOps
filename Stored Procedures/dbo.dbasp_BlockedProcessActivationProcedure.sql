SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BlockedProcessActivationProcedure]
AS
SET NOCOUNT ON
--Service Broker
DECLARE @message_body xml
DECLARE @message_body_text nvarchar(max)
DECLARE @dialog uniqueidentifier
DECLARE @message_type nvarchar(256)
DECLARE @BlockedProcessReport nvarchar(max)
DECLARE @post_time varchar(32)
DECLARE @duration int
DECLARE @blocked_spid int
DECLARE @waitresource nvarchar(max)
DECLARE @waitresource_db nvarchar(128)
DECLARE @waitresource_schema nvarchar(128)
DECLARE @waitresource_name nvarchar(128)
DECLARE @blocked_hostname nvarchar(128)
DECLARE @blocked_db nvarchar(128)
DECLARE @blocked_login nvarchar(128)
DECLARE @blocked_lasttranstarted nvarchar(32)
DECLARE @blocked_inputbuf nvarchar(max)
DECLARE @blocking_spid int
DECLARE @blocking_hostname nvarchar(128)
DECLARE @blocking_db nvarchar(128)
DECLARE @blocking_login nvarchar(128)
DECLARE @blocking_lasttranstarted nvarchar(32)
DECLARE @blocking_inputbuf nvarchar(max)
DECLARE @ErrorSev INT
DECLARE @ErrorText VarChar(255)
DECLARE @BlockTimeSevere	INT = 900 -- 900 = 15 minutes. Time in Seconds Till Blocking is considered Severe and raises error as Error insted of warning
DECLARE @CRLF CHAR(2) = CHAR(13)+CHAR(10)
DECLARE @MSG1 VarChar(max)
DECLARE @MSG2 VarChar(max)


--ALTER QUEUE msdb..BlockedProcessQueue WITH STATUS = ON;
WHILE 1 = 1
BEGIN --Process the queue
    BEGIN TRANSACTION;


    RECEIVE	TOP (1)
			@message_body	= CAST(message_body AS XML),
			@dialog		= conversation_handle,
			@message_type	= message_type_name
    FROM		msdb.dbo.BlockedProcessQueue


    --SELECT @message_body


    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Nothing more to process', 0, 1)
        ROLLBACK TRANSACTION
        RETURN
    END


    --DECLARE @MSG VarChar(max)
    --SET @MSG = DBAOps.dbo.dbaudf_FormatXML2String(@message_body)
    --RAISERROR (@MSG,-1,-1) WITH LOG


    IF @message_type = 'http://schemas.microsoft.com/SQL/Notifications/EventNotification'
    BEGIN
		SET @post_time					= CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/PostTime)[1]', 'datetime'), 109)
		SET @duration					= CAST(@message_body.value(N'(//EVENT_INSTANCE/Duration)[1]', 'bigint') / 1000000 AS int)
		SET @blocked_spid				= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@spid)[1]', 'int')
		SET @waitresource				= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@waitresource)[1]', 'nvarchar(max)')
		SET @blocked_hostname			= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@hostname)[1]', 'nvarchar(128)')
		SET @blocked_db				= DB_NAME(@message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@currentdb)[1]', 'int'))
		SET @blocked_login				= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@loginname)[1]', 'nvarchar(128)')
		SET @blocked_lasttranstarted		= CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/@lasttranstarted)[1]', 'datetime'), 109)
		SET @blocked_inputbuf			= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocked-process/process/inputbuf)[1]', 'nvarchar(max)')
		SET @blocking_spid				= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@spid)[1]', 'int')
		SET @blocking_hostname			= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@hostname)[1]', 'nvarchar(128)')
		SET @blocking_db				= DB_NAME(@message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@currentdb)[1]', 'int'))
		SET @blocking_login				= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@loginname)[1]', 'nvarchar(128)')
		SET @blocking_lasttranstarted		= CONVERT(varchar(32), @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/@lasttranstarted)[1]', 'datetime'), 109)
		SET @blocking_inputbuf			= @message_body.value(N'(//EVENT_INSTANCE/TextData/blocked-process-report/blocking-process/process/inputbuf)[1]', 'nvarchar(max)')


		SELECT	@waitresource_name		= wait_resource_object_name
				,@waitresource_schema	= wait_resource_schema_name
				,@waitresource_db		= wait_resource_database_name
		FROM		DBAOps.dbo.dbaudf_wait_resource_name(@waitresource)


		-- SET RAISERROR SEVERITY BASED ON DURATION
		IF @duration >= @BlockTimeSevere
		BEGIN
			SET @ErrorSev = 16
			SET @ErrorText = 'DBA ERROR: %s'
		END
		ELSE
		BEGIN
			SET @ErrorSev = 15
			SET @ErrorText = 'DBA WARNING: %s'
		END


		SET		@MSG1	= @CRLF
						+ REPLICATE('=',14) +' BLOCKED PROCESS REPORT ' + REPLICATE('=',13) +@CRLF
						+ 'Blocking Duration:        {0,80}'+@CRLF+@CRLF
						+ REPLICATE('=',17) +' BLOCKED PROCESS ' + REPLICATE('=',17) +@CRLF
						+ 'SPID:                     {1,80}'+@CRLF
						+ 'Wait Resource:            {2,80}'+@CRLF
						+ 'Hostname:                 {3,80}'+@CRLF
						+ 'Current Database:         {4,80}'+@CRLF
						+ 'Login Name:               {5,80}'+@CRLF
						+ 'Last Transaction Started: {6,80}'+@CRLF
						+ REPLICATE('=',18) +' BLOCKED QUERY ' + REPLICATE('=',18) +@CRLF
						+ '{7}'+@CRLF


		SET		@MSG2	= REPLICATE('=',17) +' BLOCKING PROCESS ' + REPLICATE('=',16) +@CRLF
						+ 'SPID:                     {0,80}'+@CRLF
						+ 'Hostname:                 {1,80}'+@CRLF
						+ 'Current Database:         {2,80}'+@CRLF
						+ 'Login Name:               {3,80}'+@CRLF
						+ 'Last Transaction Started: {4,80}'+@CRLF
						+ REPLICATE('=',18) +' BLOCKING QUERY ' + REPLICATE('=',17) +@CRLF
						+ '{5}'+@CRLF


		SELECT	@BlockedProcessReport	= DBAOps.dbo.dbaudf_FormatString(@MSG1
								,ISNULL( CONVERT(VarChar(10),DATEADD(second,@duration,0),108), '')
								,@blocked_spid
								,ISNULL(ISNULL(QUOTENAME(@waitresource_db) + '.' + QUOTENAME(@waitresource_schema) + '.' + QUOTENAME(@waitresource_name), @waitresource), '')
								,@blocked_hostname
								,@blocked_db
								,@blocked_login
								,@blocked_lasttranstarted
								,DBAOps.dbo.dbaudf_WordWrap(@blocked_inputbuf,100,default,default)
								,default
								,default
								)
							+@CRLF
							+ DBAOps.dbo.dbaudf_FormatString(@MSG2
								,@blocking_spid
								,@waitresource_db
								,@blocking_db
								,@blocking_login
								,@blocked_lasttranstarted
								,DBAOps.dbo.dbaudf_WordWrap(@blocking_inputbuf,100,default,default)
								,default
								,default
								,default
								,default
								)

		IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T
		DECLARE @BlockingTreeReport VarChar(MAX) = @CRLF
			+ REPLICATE('=',13) +' BLOCKING TREE REPORT ' + REPLICATE('=',13) +@CRLF+@CRLF
			+ 'Blocking Duration: '+ISNULL( CONVERT(VarChar(10),DATEADD(second,@duration,0),108), '')+@CRLF+@CRLF
		CREATE TABLE #T (SPID INT,BLOCKED INT,BATCH XML, SQL_TEXT XML)


		exec sp_whoisactive
			@get_full_inner_text	= 1
			,@get_outer_command		= 1
			,@output_column_list	= '[session_id][blocking_session_id][sql_text][sql_command]'
			,@destination_table		= '#T'


		UPDATE #T SET BLOCKED = 0 WHERE BLOCKED IS NULL;


		--SELECT * FROM #T
		;WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH, SQL_TEXT)
		AS
		(
		SELECT	SPID,
				BLOCKED,
				CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
				BATCH,
				SQL_TEXT
		FROM #T R
		WHERE (ISNULL(BLOCKED,0) = 0 OR BLOCKED = SPID)
		AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
		UNION ALL
		SELECT	R.SPID,
				R.BLOCKED,
				CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
				R.BATCH,
				R.SQL_TEXT
		FROM #T AS R
		JOIN		BLOCKERS
			ON	R.BLOCKED = BLOCKERS.SPID
		WHERE	R.BLOCKED > 0
			AND	R.BLOCKED <> R.SPID
		)
		SELECT		@BlockingTreeReport +=
					LEFT(
					N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1)
					+ CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
							THEN 'HEAD -  '
							ELSE '|------  '
							END
					+ CAST (SPID AS NVARCHAR (10))
					+ N' ' + REPLACE (REPLACE (CAST(BATCH AS VarChar(max)), CHAR(10), ' '), CHAR (13), ' ' )
					,200)
					+ @CRLF
		FROM BLOCKERS


		RAISERROR('xxx', -1, -1) WITH NOWAIT


		--select @BlockingTreeReport
		--exec DBAOps.dbo.dbasp_printLarge @BlockingTreeReport


		RAISERROR (@ErrorText,@ErrorSev,1,@BlockedProcessReport) WITH NOWAIT,LOG


		IF @BlockingTreeReport != @CRLF+'-------- BLOCKING TREE REPORT --------' +@CRLF+@CRLF
			RAISERROR(@ErrorText,@ErrorSev,1,@BlockingTreeReport) WITH NOWAIT,LOG
    END
    ELSE IF @message_type IN ('http://schemas.microsoft.com/SQL/ServiceBroker/Error', 'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
    BEGIN
        END CONVERSATION @dialog
    END


    COMMIT TRANSACTION
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_BlockedProcessActivationProcedure] TO [public]
GO
