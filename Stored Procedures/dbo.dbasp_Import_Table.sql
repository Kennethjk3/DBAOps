SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Import_Table]
					(
					@ImportPath		VARCHAR(8000)
					,@TableName		SYSNAME			= NULL
					,@SchemaName	SYSNAME			= 'dbo'
					,@DatabaseName	SYSNAME			= NULL
					,@NoDeleteData	BIT				= 0
					,@NoDeleteTable	BIT				= 0
					)
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE		@BCP_CMD				VarChar(max)
				,@DeleteRecords_CMD		VarChar(max)
				,@DeleteFiles_CMD		VarChar(max)
				,@ServerName			SYSNAME
				,@KeyColumn				SYSNAME
				,@DateColumn			SYSNAME
				,@DateValue				VarChar(12)
				,@GetAll				Bit
                
	CREATE TABLE #Results (Line Varchar(MAX) NULL)

	DECLARE ImportCursor CURSOR
	FOR
	SELECT		[ServerName]
				,[TableName]
				,CASE [TableName] 
					WHEN 'DMV_DATABASE_FORECAST2_SUMMARY' THEN 'ServerName'
					WHEN 'DMV_DATABASE_FORECAST2_DETAIL' THEN 'ServerName'
					WHEN 'DMV_DRIVE_FORECAST2_SUMMARY' THEN 'ServerName'
					WHEN 'DMV_DRIVE_FORECAST2_DETAIL' THEN 'ServerName'
					ELSE [KeyColumn]
					END [KeyColumn]
				,CASE [TableName] 
					WHEN 'DMV_DATABASE_FORECAST2_SUMMARY' THEN 'RunDate'
					WHEN 'DMV_DATABASE_FORECAST2_DETAIL' THEN 'RunDate'
					WHEN 'DMV_DRIVE_FORECAST2_SUMMARY' THEN 'RunDate'
					WHEN 'DMV_DRIVE_FORECAST2_DETAIL' THEN 'RunDate'
					ELSE [DateColumn]
					END [DateColumn]
				,COALESCE([DateValue],CONVERT(VARCHAR(12),DateCreated,101)) [DateValue]
				,[GetAll]
				,'EXEC xp_cmdshell ''bcp '+COALESCE(@DatabaseName+'.','') + @SchemaName +'.'+ [TableName] + ' in "' + [FullPathName] + '" -T -N -q'''			[BCP_CMD]
				,'DELETE '+COALESCE(@DatabaseName+'.','') + @SchemaName +'.' + [TableName] 
						+ ' WHERE ['+CASE [TableName] 
										WHEN 'DMV_DATABASE_FORECAST2_SUMMARY' THEN 'ServerName'
										WHEN 'DMV_DATABASE_FORECAST2_DETAIL' THEN 'ServerName'
										WHEN 'DMV_DRIVE_FORECAST2_SUMMARY' THEN 'ServerName'
										WHEN 'DMV_DRIVE_FORECAST2_DETAIL' THEN 'ServerName'
										ELSE [KeyColumn]
										END
						+'] = '''+[ServerName]+''''
						+ CASE [GetAll] WHEN '1' THEN '' ELSE ' AND ['+CASE [TableName] 
																		WHEN 'DMV_DATABASE_FORECAST2_SUMMARY' THEN 'RunDate'
																		WHEN 'DMV_DATABASE_FORECAST2_DETAIL' THEN 'RunDate'
																		WHEN 'DMV_DRIVE_FORECAST2_SUMMARY' THEN 'RunDate'
																		WHEN 'DMV_DRIVE_FORECAST2_DETAIL' THEN 'RunDate'
																		ELSE [DateColumn]
																		END
						+'] = '''+COALESCE([DateValue],CONVERT(VARCHAR(12),DateCreated,101))+'''' END														[DeleteRecords_CMD]
				,'EXEC xp_cmdshell ''DEL "'+ [FullPathName] +'"'''																							[DeleteFiles_CMD]
	FROM		(
				SELECT		Name
							,FullPathName
							,DateCreated
							,REPLACE([DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),1),'$','\')	[ServerName]
							,[DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),2)					[TableName]
							,[DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),3)					[KeyColumn]
							,[DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),4)					[DateColumn]
							,[DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),5)					[DateValue]
							,[DBAOps].[dbo].[dbaudf_ReturnPart]([DBAOps].[dbo].[dbaudf_base64_decode](LEFT(REPLACE([Name],'$','='),LEN([Name])-4)),6)					[GetAll]
				FROM		DBAOps.dbo.dbaudf_FileAccess_Dir2
							(@ImportPath,null,0)
				WHERE		Extension = '.dat'
						AND	DateModified >= GetDate()-30
				) DataFiles
	WHERE		[TableName] = COALESCE(@TableName,[TableName])
	ORDER BY	[DateCreated]
 




	OPEN ImportCursor;
	FETCH ImportCursor INTO @ServerName,@TableName,@KeyColumn,@DateColumn,@DateValue,@GetAll,@BCP_CMD,@DeleteRecords_CMD,@DeleteFiles_CMD;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			---------------------------- 
			---------------------------- CURSOR LOOP TOP
			--SELECT @ServerName,@TableName,@KeyColumn,@DateColumn,@DateValue,@GetAll,@BCP_CMD,@DeleteRecords_CMD,@DeleteFiles_CMD;

			RAISERROR ('Importing %s from [%s]',-1,-1,@TableName,@ServerName)WITH NOWAIT

			IF OBJECT_ID(COALESCE(@DatabaseName+'.','') + @SchemaName +'.'+@TableName) IS NOT NULL
			BEGIN
				BEGIN TRY
			
					IF @NoDeleteData = 0
						EXEC (@DeleteRecords_CMD)

					TRUNCATE TABLE #Results

					INSERT INTO #Results
					EXEC (@BCP_CMD)

					IF EXISTS (SELECT * FROM #Results WHERE Line LIKE 'Error%')
					BEGIN
						RAISERROR('	-- ERROR IMPORTING DATA : %s',-1,-1,@BCP_CMD) WITH NOWAIT

						SET @DeleteFiles_CMD = REPLACE(REPLACE(@DeleteFiles_CMD,'EXEC xp_cmdshell ''DEL "',''),'"''','')

						SET @DeleteFiles_CMD = 'EXEC xp_cmdshell ''MOVE "' + @DeleteFiles_CMD + '" "' + REPLACE(@DeleteFiles_CMD,DBAOps.dbo.dbaudf_GetFileFromPath(@DeleteFiles_CMD),'BAD\') + '"'''
					END

					IF @NoDeleteTable = 0
						EXEC (@DeleteFiles_CMD)

					RAISERROR('	-- Delete Data Command	: %s',-1,-1,@DeleteRecords_CMD) WITH NOWAIT
					RAISERROR('	-- BCP Command			: %s',-1,-1,@BCP_CMD) WITH NOWAIT
					RAISERROR('	-- Delete Table Command	: %s',-1,-1,@DeleteFiles_CMD) WITH NOWAIT


				END TRY
				BEGIN CATCH

					EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
					RAISERROR('	-- Unable to Import Table [%s] for Server [%s].',-1,-1,@TableName,@ServerName) WITH NOWAIT
					
					IF @NoDeleteData = 0
						RAISERROR('	-- Delete Data Command	: %s',-1,-1,@DeleteRecords_CMD) WITH NOWAIT
					
					RAISERROR('	-- BCP Command			: %s',-1,-1,@BCP_CMD) WITH NOWAIT
					
					IF @NoDeleteTable = 0
						RAISERROR('	-- Delete Table Command	: %s',-1,-1,@DeleteFiles_CMD) WITH NOWAIT

				END CATCH
			END
			ELSE
				RAISERROR('-- TABLE [%s] DOES NOT EXIST IN DATABASE [%s].',-1,-1,@TableName,@DatabaseName) WITH NOWAIT
			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM ImportCursor INTO @ServerName,@TableName,@KeyColumn,@DateColumn,@DateValue,@GetAll,@BCP_CMD,@DeleteRecords_CMD,@DeleteFiles_CMD;
	END
	CLOSE ImportCursor;
	DEALLOCATE ImportCursor;
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Import_Table] TO [public]
GO
