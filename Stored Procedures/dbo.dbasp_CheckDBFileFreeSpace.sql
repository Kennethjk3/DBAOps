SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CheckDBFileFreeSpace]
AS
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
-- Do not lock anything, and do not get held up by any locks.
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
IF OBJECT_ID('tempdb..#RptData') IS NOT NULL DROP TABLE #RptData
IF OBJECT_ID('tempdb..#Results') IS NOT NULL DROP TABLE #Results
IF OBJECT_ID('tempdb..#ListDrives') IS NOT NULL DROP TABLE #ListDrives
DECLARE @Results TABLE
                 (
                    Value   NVARCHAR (100),
                    Data    NVARCHAR (100)
                 )


-- THIS MAKES SURE THAT THE Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor BRANCH EXISTS
EXEC[sys].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor','XX','reg_sz','0'
EXEC[sys].[xp_instance_regdeletevalue] N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor','XX'


-- GET DISK ALERT OVERRIDES AT Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor
INSERT INTO @Results
EXEC [sys].[xp_instance_regenumvalues] N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor'


CREATE TABLE #Results ([DBName] SYSNAME,[Type] sysname, [FileName] SYSNAME, [CurrentSizeMB] Float, [FreeSpaceMB] Float, [GrowthMB] Float, [MaxSizeMB] Float)
DECLARE @RptLine	VarChar(2047)
DECLARE @Level		VarChar(50)
DECLARE @Severity	INT
DECLARE @State		INT


/*


SELECT	DB_NAME()	AS DbName
		,CASE [type] WHEN 0 THEN 'ROWS' ELSE 'LOG' END AS [Type]
		,physical_name	AS FileName
		,size/128.0	AS CurrentSizeMB
		,size/128.0 -CAST(FILEPROPERTY(name,'SpaceUsed')AS INT)/128.0 AS FreeSpaceMB
		,CASE is_percent_growth
			WHEN 1 THEN	CONVERT(numeric(18,2), (((convert(numeric, size)*growth)/100)*8)/1024)
			ELSE			CONVERT(numeric(18,2), (convert(numeric, growth)*8)/1024)
			END AS [Growth]
		,CASE max_size WHEN -1 THEN -1 ELSE max_size/128.0 END	AS MaxSizeMB
FROM sys.database_files;


*/


exec DBAOps.dbo.dbasp_foreachdb @is_ag_secondary = 0, @Command = 'USE ?;
INSERT INTO #Results
SELECT	DB_NAME()	AS DbName
		,CASE [type] WHEN 0 THEN ''ROWS'' ELSE ''LOG'' END AS [Type]
		,physical_name	AS FileName
		,size/128.0	AS CurrentSizeMB
		,size/128.0 -CAST(FILEPROPERTY(name,''SpaceUsed'')AS INT)/128.0 AS FreeSpaceMB
		,CASE is_percent_growth
			WHEN 1 THEN	CONVERT(numeric(18,2), (((convert(numeric, size)*growth)/100)*8)/1024)
			ELSE			CONVERT(numeric(18,2), (convert(numeric, growth)*8)/1024)
			END AS [Growth]
		,CASE max_size WHEN -1 THEN -1 ELSE max_size/128.0 END	AS MaxSizeMB
FROM sys.database_files;'


SELECT		*
			,CASE	WHEN T2.Data = 0 THEN 0
				WHEN PercentUsed >= COALESCE (T2.Data, 90) THEN 1
				ELSE 0
				END [Alert]
			,REPLACE(REPLACE(UseChart,NCHAR(9633),NCHAR(9617)),NCHAR(9632),NCHAR(9608))	[CurrentUseChart]
			,T2.Data PercentFullOverride
INTO		#ListDrives
FROM		DBAOps.dbo.dbaudf_ListDrives() T1
LEFT JOIN	@Results T2
	ON		CASE	WHEN LEN(T2.Value) = 1 THEN T2.Value+':\'
					WHEN LEN(T2.Value) = 2 THEN T2.Value+'\'
					ELSE T2.Value END = T1.RootFolder
    AND		isnumeric(T2.Data) = 1	-- Try to exclude other registry entries that are not simply the override value
order by	RootFolder


-- SELECT * FROM #ListDrives


;WITH	DBFiles
		AS
		(
		SELECT	DBNAME [Database Name]
				,(SELECT TOP 1 RootFolder FROM #ListDrives WHERE T1.FileName LIKE RootFolder+ '%' ORDER BY RootFolder DESC) [RootFolder]
				,[Type] [type_desc]
				,[CurrentSizeMB] - [FreeSpaceMB] AS [USEDSPACE_MB]
				,[FreeSpaceMB] AS [FREESPACE_MB]
				,[GrowthMB] [Growth in MB]
				,[CurrentSizeMB] AS [Total Size in MB]
				,[MaxSizeMB]
				,CASE WHEN [MaxSizeMB] > 0 THEN DBAOps.dbo.dbaudf_FormatBytes([MaxSizeMB]-[CurrentSizeMB],'MB') END AS [Limited Growth Left]
		FROM	#Results T1
		)


SELECT	*
		,CASE
			WHEN [Database Name] != 'tempdb' AND [Growth in MB] > 0 AND [GrowthsAvailable] < [GrowthsOnDrive] AND [MaxSizeMB] < 2097152 --max log size
			  THEN 'ERROR|16|1|'+[Database Name] + ' ' + [type_desc] + ' FILES ON '+[RootFolder]+' ARE CAPPED AND CANNOT MAKE USE OF ALL SPACE AVAILABLE.'
			WHEN [AvailablePctUsed] > 90
			  THEN 'ERROR|16|1|'+[Database Name] + ' ' + [type_desc] + ' FILES ON '+[RootFolder]+' HAVE LESS THAN 90% FREESPACE AVAILABLE INCLUDING UNUSED DRIVE SPACE.'
			WHEN [AvailablePctUsed] > 80
			  THEN 'WARNING|15|1|'+[Database Name] + ' ' + [type_desc] + ' FILES ON '+[RootFolder]+' HAVE LESS THAN 80% FREESPACE AVAILABLE INCLUDING UNUSED DRIVE SPACE.'
			WHEN [Database Name] != 'tempdb' AND [PercentFullOverride] = 0 AND [Growth in MB] > 0
			  THEN 'INFO|14|1|'+[Database Name] + ' ' + [type_desc] + ' FILES ON '+[RootFolder]+' ARE SET TO GROW BUT THE DRIVE IS SET TO IGNORE. THIS SHOULD ONLY BET SET ON DRIVES WITH NO GROWABLE DEVICES.'
			WHEN [Database Name] != 'tempdb' AND [GrowthsAvailable] < 10 AND [Growth in MB] > 0
			  THEN 'INFO|14|1|'+[Database Name] + ' ' + [type_desc] + ' FILES ON '+[RootFolder]+' ONLY HAVE ENOUGH SPACE TO GROW '+CAST([GrowthsAvailable] AS VarChar(2))+' MORE TIMES.'

			ELSE 'Good'
			END AS [Condition]


INTO	#RptData
FROM	(
		SELECT	*
				,[FREESPACE_MB] + [RoomToGrow] AS [Available_FreeSpace_MB]
				,CAST(CASE [Growth in MB] WHEN 0 THEN 0 ELSE [RoomToGrow]/[Growth in MB] END AS INT) AS [GrowthsAvailable]
				,CAST(CASE [Growth in MB] WHEN 0 THEN 0 ELSE [Drive_FreeSpace_MB]/[Growth in MB] END AS INT) AS [GrowthsOnDrive]
				,([USEDSPACE_MB]*100)/([Total Size in MB] + [RoomToGrow]) AS [AvailablePctUsed]
				,LEFT(REPLICATE(NCHAR(9608),((([USEDSPACE_MB]*100)/([Total Size in MB] + [RoomToGrow]))/10))+REPLICATE(NCHAR(9617),10),10) AS [AvailablePctUsed_Chart]
		FROM	(
				SELECT	*
						,CASE	WHEN [MaxSizeMB] < 0
								THEN [Drive_FreeSpace_MB]
								WHEN [Total Size in MB] + [Drive_FreeSpace_MB] > [MaxSizeMB]
								THEN [MaxSizeMB]-[Total Size in MB]
								ELSE [Drive_FreeSpace_MB] END AS [RoomToGrow]
						,([USEDSPACE_MB]*100)/[Total Size in MB] [AlocatedPctUsed]
						,LEFT(REPLICATE(NCHAR(9608),((([USEDSPACE_MB]*100)/([Total Size in MB]))/10))+REPLICATE(NCHAR(9617),10),10) [AlocatedPctUsed_Chart]
				FROM	(
						SELECT		T1.[Database Name]
									,T1.RootFolder
									,REPLACE(T1.type_desc,'ROWS','DATA') [type_desc]
									,T2.FreeSpace / POWER(1024.0,2) [Drive_FreeSpace_MB]
									,T2.PercentFullOverride
									,T2.CurrentUseChart
									,SUM(T1.[Growth in MB])			[Growth in MB]
									,SUM(T1.[USEDSPACE_MB])			[USEDSPACE_MB]
									,SUM(T1.[FREESPACE_MB])			[FREESPACE_MB]
									,SUM(T1.[Total Size in MB])		[Total Size in MB]
									,SUM(CASE T1.[MaxSizeMB]
											WHEN -1 THEN T1.[Total Size in MB] + (T2.FreeSpace / POWER(1024.0,2))
											ELSE T1.[MaxSizeMB]
											END)					[MaxSizeMB]
						FROM		DBFiles T1
						LEFT JOIN	#ListDrives T2
								ON	T1.RootFolder = T2.RootFolder
						GROUP BY	T1.[Database Name]
									,T1.RootFolder
									,T1.type_desc
									,T2.FreeSpace / POWER(1024.0,2)
									,T2.PercentFullOverride
									,T2.CurrentUseChart
						) Data
				) Data
		)Data
ORDER BY	[Database Name],[RootFolder]


-- SELECT * FROM #RptData


DECLARE ErrorCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT	(SELECT SplitValue FROM DBAOps.dbo.dbaudf_split([Condition],'|') WHERE OccurenceId = 1)
		,(SELECT SplitValue FROM DBAOps.dbo.dbaudf_split([Condition],'|') WHERE OccurenceId = 2)
		,(SELECT SplitValue FROM DBAOps.dbo.dbaudf_split([Condition],'|') WHERE OccurenceId = 3)
		,(SELECT SplitValue FROM DBAOps.dbo.dbaudf_split([Condition],'|') WHERE OccurenceId = 4)
FROM	#RptData
WHERE	[Condition] != 'Good'
OPEN ErrorCursor;
FETCH ErrorCursor INTO @Level,@Severity,@State,@RptLine;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		----------------------------
		---------------------------- CURSOR LOOP TOP
		--SELECT @RptLine
		BEGIN TRY
			RAISERROR ('DBA %s: %s',@Severity,@State,@Level,@RptLine) WITH NOWAIT,LOG
		END TRY
		BEGIN CATCH
			RAISERROR ('DBA %s: %s',-1,-1,@Level,@RptLine) WITH NOWAIT
		END CATCH
		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM ErrorCursor INTO @Level,@Severity,@State,@RptLine;
END
CLOSE ErrorCursor;
DEALLOCATE ErrorCursor;
GO
GRANT EXECUTE ON  [dbo].[dbasp_CheckDBFileFreeSpace] TO [public]
GO
