SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_DropAllCustomStatsOnDB]
		(
		@DBName		SYSNAME 
		,@TableName	SYSNAME	= NULL
		,@Noexec	BIT		= 0
		)
AS
BEGIN
	DROP TABLE IF EXISTS #DropScripts

	CREATE TABLE	#DropScripts (Script VARCHAR(800))
	DECLARE			@Script VARCHAR(8000)
	DECLARE			@TSQL VARCHAR(MAX)

	SET @TSQL = 
	'USE ' + QUOTENAME(@DBName) +';
	INSERT INTO	#DropScripts
	SELECT		''USE ' + QUOTENAME(@DBName) +';DROP STATISTICS '' + QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + ''.'' + QUOTENAME(OBJECT_NAME(object_id)) + ''.'' + QUOTENAME(name) + '';'' 
	FROM		sys.stats AS ColumnStats 
	WHERE		user_created = 1'
	+COALESCE('	AND		OBJECT_NAME(object_id) = '''+@TableName+'''','')+'
		AND		(name LIKE ''CustomStat%'' or name LIKE ''%dta%'' )'

	EXEC (@TSQL)

	SET @TSQL = 
	'USE ' + QUOTENAME(@DBName) +';
	INSERT INTO	#DropScripts
	SELECT		''USE ' + QUOTENAME(@DBName) +';DROP INDEX '' + QUOTENAME([i].[name]) + '' ON '' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) +''.''+ QUOTENAME(OBJECT_NAME(i.[object_id])) + '';'' 
	FROM sys.[indexes] AS [i]
	JOIN sys.[objects] AS [o]
	ON i.[object_id] = o.[object_id]
	WHERE 1=1'
	+COALESCE('AND OBJECT_NAME(i.object_id) = '''+@TableName+'''','')+' 
	AND INDEXPROPERTY(i.[object_id], i.[name], ''IsHypothetical'') = 1
	AND OBJECTPROPERTY([o].[object_id], ''IsUserTable'') = 1'

	EXEC (@TSQL)


	-- SELECT QUERY FOR CURSOR
	DECLARE DropStats CURSOR
	FOR
	SELECT * FROM #DropScripts
	OPEN DropStats;
	FETCH DropStats INTO @Script;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			PRINT @Script
			IF @Noexec = 0
				EXEC(@Script)
		END
		 FETCH NEXT FROM DropStats INTO @Script;
	END
	CLOSE DropStats;
	DEALLOCATE DropStats;
END
-- EXAMPLE CLEAN ALL DATABASES
-- EXEC sp_msForEachDB 'exec DBAOps.dbo.dbasp_DropAllCustomStatsOnDB ''?'''
GO
GRANT EXECUTE ON  [dbo].[dbasp_DropAllCustomStatsOnDB] TO [public]
GO
