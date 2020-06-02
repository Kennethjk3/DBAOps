SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Retention]
								(
								@BkUpPath			VarChar(1024)	= NULL
								,@ArchivePath		VarChar(1024)	= NULL
								,@SingleDBName		SYSNAME			= NULL

								,@WeeklyDay			INT				= 7		--  1 = Sunday .... 6 = Friday
								,@MonthlyDay		INT				= -1	-- -1 = Last Day Of Month			OR 1 - 31
								,@QuarterlyDay		INT				= -1	-- -1 = Last Day of the Quarter		OR 1 - 99
								,@YearlyDay			INT				= -1	-- -1 = Last Day of the Year		OR 1 - 365

								,@KeepDays			INT				= 2
								,@KeepWeeks			INT				= 0
								,@KeepMonths		INT				= 0
								,@KeepQuarters		INT				= 0
								,@KeepYears			INT				= 0

								,@ArchiveDays		INT				= 7
								,@ArchiveWeeks		INT				= 4
								,@ArchiveMonths		INT				= 12
								,@ArchiveQuarters	INT				= 4
								,@ArchiveYears		INT				= 2

								,@ForceLocal		BIT				= 0
								,@database_list		VarChar(max)	= NULL
								,@name_pattern		VarChar(max)	= NULL
								,@FP				BIT				= 0
								,@Noexec			Bit				= 0
								)
 /***************************************************************
 **  Stored Procedure dbasp_Backup_Retention
 **  Written by Steve Ledridge, Virtuoso
 **  August 08, 2017
 **
 **
 **
 **
 **
 **
 **
 **
 ***************************************************************/
AS
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	08/08/2017	Steve Ledridge			New process .
--	======================================================================================


Declare		@save_servername			sysname
			,@save_servername2			sysname
			,@save_servername3			sysname
			,@parm01					varchar(100)
			,@charpos					int
			,@save_delete_mask_tlog		sysname
			,@Data						XML

DECLARE		@CMD						VarChar(8000)
			,@Today						DateTime		=  CAST(CONVERT(VarChar(12),GetDate(),101)AS DateTime)

DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@BackupPathA				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					VarChar(10)	
			,@RootNetworkBackups		VarChar(8000)	
			,@RootNetworkFailover		VARCHAR(8000)	
			,@RootNetworkArchive		VARCHAR(8000)	
			,@RootNetworkClean			VARCHAR(8000)

DROP TABLE IF EXISTS #PeriodsToKeep_tmp
CREATE TABLE	#PeriodsToKeep_tmp (Period INT,DateTimeValue DateTime,Type VarChar(50))


DROP TABLE IF EXISTS #PeriodsToKeep
CREATE TABLE	#PeriodsToKeep (Period INT,DateTimeValue DateTime,Type VarChar(50))


DROP TABLE IF EXISTS #PeriodsToArchive_tmp
CREATE TABLE	#PeriodsToArchive_tmp (Period INT,DateTimeValue DateTime,Type VarChar(50))


DROP TABLE IF EXISTS #PeriodsToArchive
CREATE TABLE	#PeriodsToArchive (Period INT,DateTimeValue DateTime,Type VarChar(50))


DROP TABLE IF EXISTS #FilesToKeep
CREATE TABLE	#FilesToKeep (Period INT, Mask VarChar(4000),DBName SYSNAME, BackupTimeStamp DateTime, BackupType VarChar(50))


DROP TABLE IF EXISTS #FilesToClean
CREATE TABLE	#FilesToClean (FullPathName VarChar(4000),BackupType VarChar(50))


DROP TABLE IF EXISTS #FilesToDelete
CREATE TABLE	#FilesToDelete (FullPathName VarChar(4000))


DROP TABLE IF EXISTS #FilesToArchive
CREATE TABLE	#FilesToArchive (FullPathName VarChar(4000),NewPathName VarChar(4000))


----------------  initial values  -------------------

		---------------------  Get Paths  -----------------------
		----   GET PATHS FROM [dbo].[dbasp_GetPaths]
		EXEC dbo.dbasp_GetPaths
			 @DataPath				= @DataPath				OUT
			,@LogPath				= @LogPath				OUT
			,@BackupPathL			= @BackupPathL			OUT
			,@BackupPathN			= @BackupPathN			OUT
			,@BackupPathN2			= @BackupPathN2			OUT
			,@BackupPathA			= @BackupPathA			OUT
			,@DBASQLPath			= @DBASQLPath			OUT
			,@SQLAgentLogPath		= @SQLAgentLogPath		OUT
			,@DBAArchivePath		= @DBAArchivePath		OUT
			,@EnvBackupPath			= @EnvBackupPath		OUT
			,@SQLEnv				= @SQLEnv				OUT
			,@RootNetworkBackups	= @RootNetworkBackups	OUT	
			,@RootNetworkFailover	= @RootNetworkFailover	OUT	
			,@RootNetworkArchive	= @RootNetworkArchive	OUT
			,@RootNetworkClean		= @RootNetworkClean		OUT
			,@FP					= @FP
				


SET @BkUpPath = COALESCE	(
							CASE WHEN @ForceLocal = 1 THEN @BackupPathL END
							,@EnvBackupPath
							,@BackupPathN
							,@BackupPathN2
							,@BackupPathL
							)


--  Make sure the @BkUpPath ends with '\'
IF RIGHT(@BkUpPath,1) != '\'
	SET @BkUpPath = @BkUpPath + '\'

IF @ArchivePath IS NOT NULL
BEGIN
	Select @cmd = 'mkdir "' + @ArchivePath + '"'
	EXEC master.sys.xp_cmdshell @cmd, no_output
END

SET @ArchivePath = COALESCE(@ArchivePath,@BackupPathA) -- USE PASSED IN VALUE IF SPECIFIED

IF @ArchivePath is null or [dbo].[dbaudf_GetFileProperty] (@ArchivePath,'folder','Exists') != 'True'
BEGIN
	RAISERROR('-- Archive Path [%s] is NOT valid, Exiting.',-1,-1,@ArchivePath) WITH NOWAIT
	GOTO ExitProcess
END


RAISERROR ('--  START Backup File Cleanup Process',-1,-1) WITH NOWAIT
RAISERROR ('',-1,-1) WITH NOWAIT


RAISERROR ('Backup path is %s',-1,-1,@BkUpPath) WITH NOWAIT
RAISERROR ('',-1,-1) WITH NOWAIT


--  Process to delete old backup files  -------------------


--  Set up for delete processing
Select @save_delete_mask_tlog = '*_tlog_*.*'


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--								BUILD DATE DIMMENSION
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------


DROP TABLE IF EXISTS #DateDimmension


SELECT		*
INTO		#DateDimmension
FROM		[dbo].[dbaudf_TimeDimension]	(
											DATEADD(year,(@KeepYears*-1)-1,DATEADD(day,((datepart(dy,getdate())-1)*-1),CAST(CONVERT(VarChar(12),GetDate(),101)AS DateTime)))
											--,DATEADD(year,1,DATEADD(day,((datepart(dy,getdate())-1)*-1),CAST(CONVERT(VarChar(12),GetDate(),101)AS DateTime)))
											,DATEADD(year,1,DATEADD(day,((datepart(dy,getdate())-1)*-1),CAST(CONVERT(VarChar(12),GetDate(),101)AS DateTime)))
											,'day'
											,1
											)


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--								BUILD PERIODS TO KEEP
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
BEGIN	-- BUILD PERIODS TO KEEP


	INSERT INTO #PeriodsToKeep_tmp


	-- DAILY DAYS TO KEEP
	SELECT		Period,DateTimeValue,'Daily'
	FROM		(
				SELECT		TOP(@KeepDays)
							*
				FROM		#DateDimmension
				WHERE		DateTimeValue <= Getdate()
				ORDER BY	Period DESC
				) Data


	UNION
	-- WEEKLY DAYS TO KEEP
	SELECT		Period,DateTimeValue,'Weekly'
	FROM		(
				SELECT		TOP(@KeepWeeks)
							*
				FROM		#DateDimmension
				WHERE		DatePart_weekday = @WeeklyDay
					AND		DateTimeValue <= Getdate()
				ORDER BY	Period DESC
				) Data
	UNION
	-- MONTHLY DAYS TO ARCHIVE -- DECLARE @MonthlyDay INT = -1, @ArchiveMonths INT = 12
	SELECT		Period,DateTimeValue,'Monthly'
	FROM		(
				SELECT		TOP(@KeepMonths)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Month ORDER BY DatePart_day DESC) [RowNum]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@MonthlyDay = -1 AND  DATEPART(month,DateTimeValue) !=  DATEPART(month,dateadd(day,1,DateTimeValue))) --    [RowNum] = 1)
					OR		DatePart_day = @MonthlyDay
				ORDER BY	Period DESC
				) Data
	UNION
	-- QUARTERLY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Quarterly'
	FROM		(
				SELECT		TOP(@KeepQuarters)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Quarter ORDER BY DatePart_dayofyear DESC) [RowNum]
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Quarter ORDER BY DatePart_dayofyear DESC) [RowNum2]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@QuarterlyDay = -1 AND DATEPART(quarter,DateTimeValue) !=  DATEPART(quarter,dateadd(day,1,DateTimeValue))) --[RowNum] = 1)
					OR		RowNum2 = @QuarterlyDay
				ORDER BY	Period DESC
				) Data
	UNION
	-- YEARLY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Yearly'
	FROM		(
				SELECT		TOP(@KeepYears)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year ORDER BY DatePart_dayofyear DESC) [RowNum]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@YearlyDay = -1 AND DATEPART(year,DateTimeValue) !=  DATEPART(year,dateadd(day,1,DateTimeValue))) --[RowNum] = 1)
					OR		DatePart_dayofyear = @YearlyDay
				ORDER BY	Period DESC
				) Data


	INSERT INTO #PeriodsToKeep
	SELECT		Period
				,DateTimeValue
				,dbo.dbaudf_ConcatenateUnique(Type) [Type]
	FROM		#PeriodsToKeep_tmp
	GROUP BY	Period
				,DateTimeValue


	--SELECT * FROM #PeriodsToKeep
	--SELECT * FROM #PeriodsToKeep_tmp
END


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--								BUILD PERIODS TO ARCHIVE
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
BEGIN	-- BUILD PERIODS TO ARCHIVE


	INSERT INTO #PeriodsToArchive_tmp


	-- DAILY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Daily'
	FROM		(
				SELECT		TOP(@ArchiveDays)
							*
				FROM		#DateDimmension
				WHERE		DateTimeValue <= Getdate()
				ORDER BY	Period DESC
				) Data


	UNION
	-- WEEKLY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Weekly'
	FROM		(
				SELECT		TOP(@ArchiveWeeks)
							*
				FROM		#DateDimmension
				WHERE		DatePart_weekday = @WeeklyDay
					AND		DateTimeValue <= Getdate()
				ORDER BY	Period DESC
				) Data
	UNION
	-- MONTHLY DAYS TO ARCHIVE -- DECLARE @MonthlyDay INT = -1, @ArchiveMonths INT = 12
	SELECT		Period,DateTimeValue,'Monthly'
	FROM		(
				SELECT		TOP(@ArchiveMonths)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Month ORDER BY DatePart_day DESC) [RowNum]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@MonthlyDay = -1 AND DATEPART(month,DateTimeValue) !=  DATEPART(month,dateadd(day,1,DateTimeValue))) --[RowNum] = 1)
					OR		DatePart_day = @MonthlyDay
				ORDER BY	Period DESC
				) Data
	UNION
	-- QUARTERLY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Quarterly'
	FROM		(
				SELECT		TOP(@ArchiveQuarters)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Quarter ORDER BY DatePart_dayofyear DESC) [RowNum]
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year,DatePart_Quarter ORDER BY DatePart_dayofyear DESC) [RowNum2]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@QuarterlyDay = -1 AND DATEPART(quarter,DateTimeValue) !=  DATEPART(quarter,dateadd(day,1,DateTimeValue))) --[RowNum] = 1)
					OR		RowNum2 = @QuarterlyDay
				ORDER BY	Period DESC
				) Data
	UNION
	-- YEARLY DAYS TO ARCHIVE
	SELECT		Period,DateTimeValue,'Yearly'
	FROM		(
				SELECT		TOP(@ArchiveYears)
							*
				FROM		(
							SELECT		*
										,ROW_NUMBER() OVER(PARTITION BY DatePart_Year ORDER BY DatePart_dayofyear DESC) [RowNum]
							FROM		#DateDimmension
							WHERE		DateTimeValue <= Getdate()
							) Data
				WHERE		(@YearlyDay = -1 AND DATEPART(year,DateTimeValue) !=  DATEPART(year,dateadd(day,1,DateTimeValue))) --[RowNum] = 1)
					OR		DatePart_dayofyear = @YearlyDay
				ORDER BY	Period DESC
				) Data


	INSERT INTO #PeriodsToArchive
	SELECT		Period
				,DateTimeValue
				,dbo.dbaudf_ConcatenateUnique(Type) [Type]
	FROM		#PeriodsToArchive_tmp
	GROUP BY	Period
				,DateTimeValue


	--SELECT * FROM #PeriodsToArchive
END

		--SELECT	@BackupPathN			= REPLACE(@BackupPathN			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))
		--		,@BackupPathN2			= REPLACE(@BackupPathN2			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))
		--		,@BackupPathA			= REPLACE(@BackupPathA			,dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](@save_DBname))

RAISERROR ('Generate File List Of Files To Keep',-1,-1) WITH NOWAIT
SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToKeep
SELECT		Period
			,Mask
			,DBName
			,BackupTimeStamp
			,BackupType
FROM		(
			SELECT		*
						,ROW_NUMBER() OVER(PARTITION BY CAST(CONVERT(VarChar(12),T1.BackupTimeStamp,101)AS DateTime) ORDER BY BackupTimeStamp DESC) [SeqNo]
			FROM		(
						SELECT		Mask
									,DBName
									,BackupTimeStamp
									,BackupType
						FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
						WHERE		BackupType NOT IN (''TL'')
						UNION
						SELECT		Mask
									,DBName
									,BackupTimeStamp
									,BackupType
						FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
						WHERE		BackupType NOT IN (''TL'')
						) T1
			JOIN		#PeriodsToKeep T2
				ON		T2.DateTimeValue = CAST(CONVERT(VarChar(12),T1.BackupTimeStamp,101)AS DateTime)
			) Data
WHERE		[SeqNo] = 1

-- MAKE SURE YOU KEEP MOST RECENT NO MATER WHAT DATE
INSERT INTO #FilesToKeep
SELECT		0 Period
			,Mask
			,DBName
			,MAX(BackupTimeStamp) BackupTimeStamp
			,BackupType		
FROM		(
			SELECT		Mask
						,DBName
						,BackupTimeStamp
						,BackupType
			FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			WHERE		BackupType NOT IN (''TL'')
			UNION
			SELECT		Mask
						,DBName
						,BackupTimeStamp
						,BackupType
			FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			WHERE		BackupType NOT IN (''TL'')
			) T1
GROUP BY	Mask
			,DBName
			,BackupType'

EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToKeep


-- GET SUPPORTING FULL BACKUPS FOR INCLUDED DIFFS
RAISERROR ('Ad Needed Full Backups to List Of Files To Keep',-1,-1) WITH NOWAIT
SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToKeep
SELECT		DISTINCT
			T1.Period,T2.*
FROM		(SELECT * FROM #FilesToKeep WHERE BackupType = ''DF'') T1
CROSS APPLY
			(
			SELECT		TOP 1
						Mask
						,DBName
						,BackupTimeStamp
						,BackupType
			FROM		(
						SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
						UNION
						SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
						) Data
			WHERE		BackupType IN (''DB'') AND BackupTimeStamp <= T1.BackupTimeStamp
			ORDER BY	BackupTimeStamp DESC
			) T2'


EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToKeep


-- DELETE ALL LOCAL TRANLOGS OLDER THAN MOST RECENT BACKUP


RAISERROR ('Generate File List to Delete Old Tranloags',-1,-1) WITH NOWAIT


SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToDelete
SELECT		FullPathName
FROM		(
			SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			UNION
			SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			) Data
WHERE		BackupType IN (''TL'')
	AND		DateModified < (
							SELECT		MAX(BackupTimeStamp)
							FROM		(
										SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
										UNION
										SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
										) Data2
							WHERE		BackupType IN (''DB'',''DF'')
							)'
--PRINT @CMD
EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToDelete


RAISERROR ('Create XML for Delete Old Tranloags',-1,-1) WITH NOWAIT
IF EXISTS (SELECT * FROM #FilesToDelete)
	SELECT @Data =	(
					SELECT		FullPathName [Source]
					FROM		#FilesToDelete
					FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
					)
select  @Data [Delete Old Tranlogs]


RAISERROR ('Delete Old Tranloags',-1,-1) WITH NOWAIT


If @Data is not NULL AND @Noexec = 0
	exec dbasp_FileHandler @Data


-- Get all Files to Migrate


RAISERROR ('Generate File List Of Files To Migrate',-1,-1) WITH NOWAIT


SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToArchive
SELECT		T1.FullPathName,REPLACE('''+@BackupPathA+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?''))+T1.Name
FROM		(
			SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BkUpPath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			UNION
			SELECT * FROM dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@BackupPathN2+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			) T1
LEFT JOIN	#FilesToKeep T2
	ON		T1.MASK = T2.Mask
WHERE		T1.BackupType NOT IN (''TL'')
	AND		T2.Mask IS NULL
	AND		T1.BackupTimeStamp < GetDate()-'+CAST(@KeepDays AS Varchar(2))
PRINT @CMD


EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToArchive


RAISERROR ('Create XML for Migrate Files to Archive',-1,-1) WITH NOWAIT
;WITH		Settings
			AS
			(
			SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
						,'false'	AS [ForceOverwrite]	-- true,false
						,1			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
						,30			AS [UpdateInterval]	-- rate of progress updates in Seconds
			)
			,MoveFile -- CopyFile, MoveFile, DeleteFile
			AS
			(
			SELECT		FullPathName [Source]
						,NewPathName [Destination]
			FROM		#FilesToArchive
			)

SELECT		@Data =	(
			SELECT		*
					,(SELECT * FROM MoveFile FOR XML RAW ('MoveFile'), TYPE)
			FROM		Settings
			FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
			)


SELECT @Data [Migrate Files to Archive]


RAISERROR ('Migrate Files to Archive',-1,-1) WITH NOWAIT
If @Data is not null AND @Noexec = 0
	exec dbasp_FileHandler @Data

DELETE FROM #FilesToKeep


RAISERROR ('Generate File List Of Files To Keep In Archive',-1,-1) WITH NOWAIT
SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToKeep
SELECT		Period
			,Mask
			,DBName
			,BackupTimeStamp
			,BackupType
FROM		(
			SELECT		*
						,ROW_NUMBER() OVER(PARTITION BY CAST(CONVERT(VarChar(12),T1.BackupTimeStamp,101)AS DateTime) ORDER BY BackupTimeStamp DESC) [SeqNo]
			FROM		(
						SELECT		DISTINCT
									Mask
									,DBName
									,BackupTimeStamp
									,BackupType
						FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@ArchivePath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
						WHERE		BackupType NOT IN (''TL'')
						) T1
			JOIN		#PeriodsToArchive T2
				ON		T2.DateTimeValue = CAST(CONVERT(VarChar(12),T1.BackupTimeStamp,101)AS DateTime)
			) Data
WHERE		[SeqNo] = 1'
EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToKeep


-- GET SUPPORTING FULL BACKUPS FOR INCLUDED DIFFS
RAISERROR ('Ad Needed Full Backups to List Of Files To Keep',-1,-1) WITH NOWAIT
SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToKeep
SELECT		DISTINCT
			T1.Period,T2.*
FROM		(SELECT * FROM #FilesToKeep WHERE BackupType = ''DF'') T1
CROSS APPLY
			(
			SELECT		TOP 1
						Mask
						,DBName
						,BackupTimeStamp
						,BackupType
			FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@ArchivePath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null)
			WHERE		BackupType IN (''DB'') AND BackupTimeStamp <= T1.BackupTimeStamp
			ORDER BY	BackupTimeStamp DESC
			) T2'


EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToKeep


-- Get all Files to Remove From Archive
DELETE FROM #FilesToDelete


RAISERROR ('Generate File List Of Files To Remove From Archive',-1,-1) WITH NOWAIT


SET @CMD = 'RAISERROR (''	Checking [?]...'',-1,-1) WITH NOWAIT
INSERT INTO #FilesToDelete
SELECT		T1.FullPathName
FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'',REPLACE('''+@ArchivePath+''',dbo.dbaudf_GetLocalFQDN(),[dbo].[dbaudf_GetDbServerName](''?'')),0,null) T1
LEFT JOIN	#FilesToKeep T2
	ON		T1.MASK = T2.Mask
WHERE		T2.Mask IS NULL'
--PRINT @CMD


EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern
--SELECT * FROM #FilesToDelete


RAISERROR ('Create XML for Delete Files From Archive',-1,-1) WITH NOWAIT
;WITH		Settings
			AS
			(
			SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
						,'false'	AS [ForceOverwrite]	-- true,false
						,1			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
						,30			AS [UpdateInterval]	-- rate of progress updates in Seconds
			)
			,DeleteFile -- CopyFile, MoveFile, DeleteFile
			AS
			(
			SELECT		FullPathName [Source]
			FROM		#FilesToDelete
			)
SELECT		@Data =	(
			SELECT		*
					,(SELECT * FROM DeleteFile FOR XML RAW ('DeleteFile'), TYPE)
			FROM		Settings
			FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
			)
SELECT @Data [Removing Unneeded Files From Archive]


RAISERROR ('Removing Unneeded Files From Archive',-1,-1) WITH NOWAIT
If @Data is not null AND @Noexec = 0
	exec dbasp_FileHandler @Data

IF @Noexec = 0
exec [dbo].[dbasp_Backup_Retention_Report]
								@BkUpPath
								,@ArchivePath
								,@SingleDBName
								,@WeeklyDay
								,@MonthlyDay
								,@QuarterlyDay
								,@YearlyDay
								,@KeepDays
								,@KeepWeeks
								,@KeepMonths
								,@KeepQuarters
								,@KeepYears
								,@ArchiveDays
								,@ArchiveWeeks
								,@ArchiveMonths
								,@ArchiveQuarters
								,@ArchiveYears
								,@ForceLocal
								,@database_list
								,@name_pattern
ExitProcess:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Retention] TO [public]
GO
