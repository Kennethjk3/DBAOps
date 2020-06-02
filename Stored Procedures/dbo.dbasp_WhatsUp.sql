SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE     PROCEDURE [dbo].[dbasp_WhatsUp]
AS

EXEC msdb.dbo.sysmail_start_sp

SET NOCOUNT ON
DROP TABLE IF EXISTS #T
DROP TABLE IF EXISTS #Results
DROP TABLE IF EXISTS #Results2

DECLARE		@Date			DateTime
DECLARE		@FullFileName	nvarchar(max)
DECLARE		@bytes			int				= 48
DECLARE		@FileText		nvarchar(max)
DECLARE		@Message		VarChar(8000)	= 'Check Spids: ' + @@ServerName 
DECLARE		@To				VarChar(8000)	= 'steve.ledridge@gmail.com'
DECLARE		@from_address	VarChar(8000)	= @@ServerName + '<'+@@ServerName+'@VIRTUOSO.COM>'
DECLARE		@HTMLTable		VarChar(max)
DECLARE		@Body			VarChar(max)

CREATE TABLE #Results2
(
	[dd hh:mm:ss.mss]	  Varchar(8000)	 NULL
   ,[session_id]		  Smallint		 NOT NULL
   ,[sql_text]			  Xml			 NULL
   ,[login_name]		  NVarchar(128)	 NOT NULL
   ,[wait_info]			  NVarchar(4000) NULL
   ,[CPU]				  Varchar(30)	 NULL
   ,[tempdb_allocations]  Varchar(30)	 NULL
   ,[tempdb_current]	  Varchar(30)	 NULL
   ,[blocking_session_id] Smallint		 NULL
   ,[reads]				  Varchar(30)	 NULL
   ,[writes]			  Varchar(30)	 NULL
   ,[physical_reads]	  Varchar(30)	 NULL
   ,[used_memory]		  Varchar(30)	 NULL
   ,[status]			  Varchar(30)	 NOT NULL
   ,[open_tran_count]	  Varchar(30)	 NULL
   ,[percent_complete]	  Varchar(30)	 NULL
   ,[host_name]			  NVarchar(128)	 NULL
   ,[database_name]		  NVarchar(128)	 NULL
   ,[program_name]		  NVarchar(128)	 NULL
   ,[start_time]		  DateTime		 NOT NULL
   ,[login_time]		  DateTime		 NULL
   ,[request_id]		  Int			 NULL
   ,[collection_time]	  DateTime		 NOT NULL
);

SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH
,( SELECT REPLACE	(
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
				REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
					N'--' + NCHAR(13) + NCHAR(10) + T.Text + NCHAR(13) + NCHAR(10) + N'--' COLLATE Latin1_General_Bin2,
					NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
					NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
					NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
				NCHAR(0),
				N'') AS [processing-instruction(query)]
							FOR XML
								PATH(''),
								TYPE)  AS [SQL_TEXT]
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T

;WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH, SQL_TEXT)
AS
(
SELECT SPID,
BLOCKED,
CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
BATCH ,SQL_TEXT FROM #T R
WHERE (BLOCKED = 0 OR BLOCKED = SPID)
AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
UNION ALL
SELECT R.SPID,
R.BLOCKED,
CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
R.BATCH, R.SQL_TEXT FROM #T AS R
INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID
)
SELECT		LEFT(N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
			CASE	WHEN (LEN(LEVEL)/4 - 1) = 0 
					THEN 'HEAD -  '
					ELSE '|------  ' 
					END
			+ CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH,200) AS BLOCKING_TREE
			,SQL_TEXT
INTO #Results
FROM BLOCKERS ORDER BY LEVEL ASC



SELECT @HTMLTable = [dbo].[dbaudf_FormatTableToHTML]	(
																'#Results'
																,'Results'
																,'BLOCKING SPID TREE'
																,''
																,1
																,1
																)


SET @Body = @Message + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + @HTMLTable

EXEC sp_whoisactive @destination_table = '#Results2'

ALTER TABLE [#Results2] DROP COLUMN [wait_info]
ALTER TABLE [#Results2] DROP COLUMN [start_time]		
ALTER TABLE [#Results2] DROP COLUMN [login_time]		
ALTER TABLE [#Results2] DROP COLUMN [request_id]		
ALTER TABLE [#Results2] DROP COLUMN [collection_time]	

SELECT @HTMLTable = [dbo].[dbaudf_FormatTableToHTML]	(
																'#Results2'
																,'Results'
																,'WHO IS ACTIVE'
																,''
																,1
																,1
																)

SET @Body = @Body + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + @HTMLTable

EXEC msdb.dbo.sp_send_dbmail
		@profile_name 	= 'SQLServiceAccountMail'
		--,@from_address 	= @from_address 
		,@recipients	= @TO
		,@subject		= @Message
		,@Body			= @Body
		,@Body_format	= 'HTML'
GO
GRANT EXECUTE ON  [dbo].[dbasp_WhatsUp] TO [public]
GO
