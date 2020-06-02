SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
--IF OBJECT_ID('dbasp_Export_Checkin_Data') IS NOT NULL
--	DROP PROCEDURE [dbo].[dbasp_Export_Checkin_Data]
--GO
CREATE   PROCEDURE [dbo].[dbasp_Export_Checkin_Data]	(
                                                        @SpecificTables		VarChar(max)	= NULL -- USE PIPE DELIMITED STRING OF TABLES
                                                        ,@ListTables		BIT		        = 0
                                                        )
AS

DECLARE		@RunDate					DATETIME		--= GETDATE()
			,@Output_Path				VARCHAR(8000)
			,@FileName					VARCHAR(8000)
			,@TableName					VARCHAR(8000)
			,@Script					VARCHAR(8000)
			
DECLARE		@Verbose					INT				--= 0
			,@CentralServer				VARCHAR(8000)
			,@CentralServerShare		VARCHAR(8000)
			,@DateColumn				SYSNAME
			,@GetAll					BIT
			,@CreateExportDate			BIT
			,@CreateKeyColumn			BIT
			,@KeyColumn					SYSNAME
			,@Now						VARCHAR(12)				--= CONVERT(VARCHAR(12),GETDATE(),101)
			,@TMP						VARCHAR(8000)					

SELECT		@RunDate					= GETDATE()
			,@Verbose					= 0
			,@Now						= CONVERT(VARCHAR(12),GETDATE(),101)

			-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
EXEC DBAOps.dbo.dbasp_GetPaths
			@CentralServer				= @CentralServer		OUT
			,@CentralServerShare		= @CentralServerShare	OUT
			,@Verbose					= @Verbose				

IF @ListTables = 1
	RAISERROR('-- @ListTables = 1: Not performing any action other than listing tables configured for export. these values can be passed in to @SpecificTables as a Pipe Delimited string to only export specified tables.',-1,-1) WITH NOWAIT

	DECLARE ExportCursor CURSOR
	FOR
	SELECT		T1.*
	FROM		(
							SELECT 'DBAOps.dbo.DBA_AGInfo'					[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ClusterInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ConnectionInfo'			[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ControlInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_DBfileInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_DBInfo'					[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_DiskInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_DiskPerfinfo'			[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'CreateDate'	[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_IPconfigInfo'			[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_JobInfo'					[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_LinkedServerInfo'		[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'LKModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ServerInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]	-- Data Generated From dbasp_Self_Register

				UNION ALL	SELECT 'DBAOps.dbo.DBA_AuditChanges'			[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],1 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_BackupInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'RunDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ClustInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_CommentInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'RunDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_NoCheckInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_DeplInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_UserLoginInfo'			[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'SQLName'		[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_RestoreInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],1 [CreateExportDate],1 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_AgentJobFailInfo'		[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'ModDate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.DBA_ShareInfo'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'rundate'		[DateColumn],1 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAOps.dbo.HealthCheckLog'				[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'Check_date'	[DateColumn],1 [GetAll],0 [CreateExportDate],1 [CreateKeyColumn], 'ServerName'	[KeyColumn]
				UNION ALL	SELECT 'DBAPerf.dbo.DMV_Cache_Query_Analysis'	[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'CheckDate'		[DateColumn],0 [GetAll],0 [CreateExportDate],0 [CreateKeyColumn], 'ServerName'	[KeyColumn]

				UNION ALL	SELECT 'DBAOps.dbo.EventLog'					[TableName]	, @CentralServerShare +'Checkins' [OutputPath], 'EventDate'		[DateColumn],0 [GetAll],0 [CreateExportDate],1 [CreateKeyColumn], 'ServerName'	[KeyColumn]

				) T1
	LEFT JOIN	DBAOps.dbo.dbaudf_StringToTable(@SpecificTables,'|') T2		ON T1.TableName = T2.SplitValue
	WHERE		@SpecificTables IS NULL OR T2.OccurenceId IS NOT NULL

	OPEN ExportCursor;
	FETCH ExportCursor INTO @TableName,@Output_Path,@DateColumn,@GetAll,@CreateExportDate,@CreateKeyColumn,@KeyColumn;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			---------------------------- 
			---------------------------- CURSOR LOOP TOP
			SET @Output_Path = @CentralServerShare +'Checkins'
			
			IF @ListTables = 1
			BEGIN
				RAISERROR('-- %s',-1,-1,@TableName) WITH NOWAIT
				Goto DoNothing
			END

			-- FILE NAME FORMAT = {ServerName}|{TableName}|{KeyColumn}|{DateColumn}|{DateValue}|{GetAll}.dat
			SELECT	@FileName	= REPLACE([DBAOps].[dbo].[dbaudf_base64_encode]		(
                                                                                    @@SERVERNAME+'|'
                                                                                    +PARSENAME(@TableName,1)+'|'
                                                                                    +@KeyColumn+'|' 
                                                                                    +@DateColumn+'|' 
                                                                                    +@Now+'|'
                                                                                    +CASE @GetAll WHEN 1 THEN '1' ELSE '0' END +'|'
                                                                                    )+'.dat','=','$')

                    ,@SCRIPT	= 'bcp "SELECT *'
                                + CASE @CreateExportDate WHEN 0 THEN '' ELSE ', CAST('''+@Now+''' AS DateTime) ['+@DateColumn+']' END
                                + CASE @CreateKeyColumn WHEN 0 THEN '' ELSE ', '''+@@ServerName+''' ['+@KeyColumn+']' END
                                + ' FROM '
                                + @TableName
                                + CASE WHEN @GetAll = 1 THEN '' ELSE ' WHERE Convert(VarChar(12),['+@DateColumn+'],101) = '''+@Now+'''' END
                                +'" queryout "'+@Output_Path +'\'+@FileName+'" -S '+@@Servername+' -T -N -q'
 
			RAISERROR('Exporting Data from %s to file %s\%s.',-1,-1,@TableName,@Output_Path,@FileName) WITH NOWAIT
			
			--PRINT @SCRIPT
			EXEC	xp_cmdshell		@SCRIPT, no_output
 
			DoNothing:
			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM ExportCursor INTO @TableName,@Output_Path,@DateColumn,@GetAll,@CreateExportDate,@CreateKeyColumn,@KeyColumn;
	END
	CLOSE ExportCursor;
	DEALLOCATE ExportCursor;

	-- EXPORT ALL CONFIGURED TABLES TO CHECKIN DIRECTORY ON CENTRAL SERVER
	-- EXEC DBAOps.[dbo].[dbasp_Export_Checkin_Data]

	-- ONLY SHOW LIST OF TABLES THAT ARE CURENTLY CONFIGURED FOR EXPORT
	-- EXEC DBAOps.[dbo].[dbasp_Export_Checkin_Data] NULL,1

	-- EXPORT SPECIFIC TABLES (This Example is everything Updated from dbasp_Self_Register)
	-- EXEC DBAOps.[dbo].[dbasp_Export_Checkin_Data] 'DBAOps.dbo.DBA_AGInfo|DBAOps.dbo.DBA_ClusterInfo|DBAOps.dbo.DBA_ConnectionInfo|DBAOps.dbo.DBA_ControlInfo|DBAOps.dbo.DBA_DBfileInfo|DBAOps.dbo.DBA_DBInfo|DBAOps.dbo.DBA_DiskInfo|DBAOps.dbo.DBA_DiskPerfinfo|DBAOps.dbo.DBA_IPconfigInfo|DBAOps.dbo.DBA_JobInfo|DBAOps.dbo.DBA_LinkedServerInfo|DBAOps.dbo.DBA_ServerInfo'
GO
GRANT EXECUTE ON  [dbo].[dbasp_Export_Checkin_Data] TO [public]
GO
