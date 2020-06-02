SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Retention_Report]
--DECLARE
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
								)
 /***************************************************************
 **  Stored Procedure dbasp_Backup_Retention
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
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


DROP TABLE IF EXISTS #CurrentFiles
CREATE TABLE	#CurrentFiles	(
								[Period]						INT
								,[Period_DateTime]				DateTime
								,[Period_Type]					VarChar(50)
								,[PrimaryFile_Mask]				VarChar(2000)
								,[PrimaryFile_DBName]			SYSNAME
								,[PrimaryFile_BackupTimeStamp]	datetime
								,[PrimaryFile_BackupType]		VarChar(50)
								,[PrimaryFile_Path]				VarChar(2000)
								,[SupportFile_Mask]				VarChar(2000) NULL
								,[SupportFile_DBName]			SYSNAME NULL
								,[SupportFile_BackupTimeStamp]	datetime NULL
								,[SupportFile_BackupType]		VarChar(50) NULL
								,[SupportFile_Path]				VarChar(2000) NULL
								)


IF OBJECT_ID('DBAOps.dbo.DBA_BackupInfo') IS NULL
BEGIN
	CREATE TABLE [dbo].[DBA_BackupInfo](
		[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[RunDate] [datetime] NULL,
		[Period] [int] NULL,
		[Period_DateTime] [datetime] NULL,
		[Period_Type] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[DBName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		[PrimaryFile_Path] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[PrimaryFile_Mask] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[PrimaryFile_BackupType] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[PrimaryFile_BackupTimeStamp] [datetime] NULL,
		[SupportFile_Path] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[SupportFile_Mask] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[SupportFile_BackupTimeStamp] [datetime] NULL,
		[SupportFile_BackupType] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	) ON [PRIMARY]
END


----------------  initial values  -------------------

		---------------------  Get Paths  -----------------------
		----   GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
		EXEC DBAOps.dbo.dbasp_GetPaths
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

IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@ArchivePath,'folder','Exists') != 'True'
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


END


	INSERT INTO #PeriodsToArchive
	SELECT		Period
				,DateTimeValue
				,dbo.dbaudf_ConcatenateUnique(Type) [Type]
	FROM		(
				SELECT * FROM #PeriodsToArchive_tmp	-- COMBINE PERIODS TO KEEP AND PERIODS TO ARCHIVE
				UNION
				SELECT * FROM #PeriodsToKeep_tmp
				) Data
	GROUP BY	Period
				,DateTimeValue


	--SELECT * FROM #PeriodsToArchive

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--					READ EXISTING BACKUP FILES
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------


RAISERROR ('Generate File List For Retention Report',-1,-1) WITH NOWAIT


SET @CMD = 'RAISERROR (''  Processing Database ?'',-1,-1) WITH NOWAIT
INSERT INTO #CurrentFiles
SELECT		T2.Period
			,T2.DateTimeValue
			,T2.Type
			,T1.[PrimaryFile_Mask]
			,T1.[PrimaryFile_DBName]
			,T1.[PrimaryFile_BackupTimeStamp]
			,T1.[PrimaryFile_BackupType]
			,T1.[PrimaryFile_Path]
			,T1.[SupportFile_Mask]
			,T1.[SupportFile_DBName]
			,T1.[SupportFile_BackupTimeStamp]
			,T1.[SupportFile_BackupType]
			,T1.[SupportFile_Path]
FROM		(
			SELECT		*
			FROM		(
						SELECT		*
						FROM		(
									SELECT		DISTINCT
												Mask				[PrimaryFile_Mask]
												,DBName				[PrimaryFile_DBName]
												,BackupTimeStamp	[PrimaryFile_BackupTimeStamp]
												,BackupType			[PrimaryFile_BackupType]
												,Path				[PrimaryFile_Path]
												,ROW_NUMBER() OVER(PARTITION BY CAST(CONVERT(VarChar(12),BackupTimeStamp,101)AS DateTime) ORDER BY BackupTimeStamp DESC) [SeqNo]
									FROM		(
												SELECT		*
												,'''+@BkUpPath+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BkUpPath+''',0,null)
									UNION
									SELECT		*
												,'''+@ArchivePath+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@ArchivePath+''',0,null)
									UNION
									SELECT		*
												,'''+@BackupPathN2+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BackupPathN2+''',0,null)
												) T1A


									WHERE		BackupType NOT IN (''TL'')
									) T1B
						WHERE		[SeqNo] = 1
						) T1
			CROSS APPLY
						(
						SELECT		TOP 1
									CASE WHEN Mask != T1.[PrimaryFile_Mask] THEN Mask END				[SupportFile_Mask]
									,CASE WHEN Mask != T1.[PrimaryFile_Mask] THEN DBName END			[SupportFile_DBName]
									,CASE WHEN Mask != T1.[PrimaryFile_Mask] THEN BackupTimeStamp END	[SupportFile_BackupTimeStamp]
									,CASE WHEN Mask != T1.[PrimaryFile_Mask] THEN BackupType END		[SupportFile_BackupType]
									,CASE WHEN Mask != T1.[PrimaryFile_Mask] THEN Path END				[SupportFile_Path]
									FROM		(
									SELECT		*
												,'''+@BkUpPath+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BkUpPath+''',0,null)
									UNION
									SELECT		*
												,'''+@ArchivePath+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@ArchivePath+''',0,null)
									UNION
									SELECT		*
												,'''+@BackupPathN2+''' [Path]
									FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BackupPathN2+''',0,null)
									) T1A
						WHERE		BackupType IN (''DB'')
							AND		BackupTimeStamp <= T1.PrimaryFile_BackupTimeStamp
						ORDER BY	BackupTimeStamp DESC
						) T2
			) T1


JOIN		#PeriodsToArchive T2
	ON		T2.DateTimeValue = CAST(CONVERT(VarChar(12),T1.PrimaryFile_BackupTimeStamp,101)AS DateTime)'


EXEC dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD, @database_list = @database_list, @name_pattern = @name_pattern


DELETE		DBAOps.dbo.DBA_BackupInfo
--WHERE		[RunDate] = @Today
WHERE		[DBName] IN (SELECT [PrimaryFile_DBName] FROM #CurrentFiles)


INSERT INTO DBAOps.dbo.DBA_BackupInfo
SELECT		@@ServerName [ServerName]
			,@Today [RunDate]
			,[Period]
			,[Period_DateTime]
			,[Period_Type]
			,[PrimaryFile_DBName] [DBName]
			,[PrimaryFile_Path]
			,[PrimaryFile_Mask]
			,[PrimaryFile_BackupType]
			,[PrimaryFile_BackupTimeStamp]
			,[SupportFile_Path]
			,[SupportFile_Mask]
			,[SupportFile_BackupTimeStamp]
			,[SupportFile_BackupType]

FROM		#CurrentFiles
ORDER BY	PrimaryFile_DBName,Period

ExitProcess:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Retention_Report] TO [public]
GO
