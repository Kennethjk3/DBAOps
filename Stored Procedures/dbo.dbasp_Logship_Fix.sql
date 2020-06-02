SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Logship_Fix]
	(
	@DBName		SYSNAME
	,@FullReset	BIT		= 0
	,@CleanOnly	BIT		= 0
	)
AS


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.


	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF


	DECLARE		@MostRecent_Full	DATETIME
			,@MostRecent_Diff	DATETIME
			,@MostRecent_Log	DATETIME
			,@CMD			VARCHAR(8000)
			,@BackupPath		VARCHAR(8000)
			,@RestorePath		VARCHAR(8000)
			,@FileName		VARCHAR(MAX)
			,@agentJob		SYSNAME
			,@ReadyToRun		BIT


	DECLARE		@DBSources		TABLE
			(
			DBName			SYSNAME
			,BackupPath		VARCHAR(8000)
			)


	INSERT INTO	@DBSources
	SELECT		'Product'		,'\\G1sqlB\G1SQLB$B_backup\' UNION ALL
	SELECT		'RightsPrice'		,'\\G1sqlB\G1SQLB$B_backup\' UNION ALL
	SELECT		'WCDS'			,'\\G1sqlA\G1SQLA$A_backup\' UNION ALL
	SELECT		'AssetUsage_Archive'	,'\\G1sqlB\G1SQLB$B_backup\'

	SELECT		@DBName		= DBName
			,@BackupPath	= BackupPath
			,@RestorePath	= 'G:\Backup_2005\LogShip\'
			,@ReadyToRun	= 1
			,@AgentJob	= 'MAINT - Logship Restore ' + DBName
	FROM		@DBSources
	WHERE		DBName		= @DBName


	IF @DBName IS NULL
	BEGIN
		RAISERROR ('Process Not Configured for that Database, Sproc must be edited.',-1,-1) WITH NOWAIT
		RETURN 99
	END


	IF @CleanOnly = 0
	BEGIN
		IF DBAOps.dbo.[dbaudf_GetJobStatus](@AgentJob) = 4
		BEGIN
			PRINT	'Agent Job: '+@AgentJob+' is running, Stopping it now.'
			EXEC	msdb.dbo.sp_stop_job @Job_Name = @AgentJob
		END


		PRINT	'Agent Job: '+@AgentJob+' is being disabled.'
		EXEC	msdb.dbo.sp_update_job @job_Name=@AgentJob, @enabled=0
	END


	IF @FullReset = 1 AND DB_ID(@DBNAME) IS NOT NULL AND @CleanOnly = 0
	BEGIN
		Print '**** FULL RESET REQUESTED, '+UPPER(@DBNAME)+' DATABASE WILL BE DROPED AND RECREATED. ***'
		SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE ['+@DBName+']'
		EXEC (@CMD)
	END


	SELECT		@MostRecent_Full	= MAX(CASE [type] WHEN 'D' THEN [backup_start_date] END)
			,@MostRecent_Diff	= MAX(CASE [type] WHEN 'I' THEN [backup_start_date] END)
			,@MostRecent_Log	= MAX(CASE [type] WHEN 'L' THEN [backup_start_date] END)

	FROM		[msdb].[dbo].[backupset] bs
	JOIN		[msdb].[dbo].[backupmediafamily] bmf
		ON	bmf.[media_set_id] = bs.[media_set_id]
	WHERE		bs.database_name = @DBName
		AND	name IS NOT NULL
	ORDER BY	1  DESC


	START_CHECK:


	SET @ReadyToRun = 1


	;WITH		SourceFiles
			AS
			(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_DirectoryList(@BackupPath,NULL)
			WHERE		LEFT(name,len(@DBName)+1) = @DBName + '_'
				AND	IsFolder = 0
			)
			,MostRecent
			AS
			(
			SELECT		MAX(CASE RIGHT(name,3) WHEN 'SQB' THEN [DateModified] END)	MostRecent_Full
					,MAX(CASE RIGHT(name,3) WHEN 'SQD' THEN [DateModified] END)	MostRecent_Diff
					,MAX(CASE RIGHT(name,3) WHEN 'SQT' THEN [DateModified] END)	MostRecent_Log
			FROM		SourceFiles
			)
			,NeededFiles
			AS
			(
			SELECT		*
			FROM		SourceFiles S

			WHERE		RIGHT(S.Name,3) = 'SQB' AND S.[DateModified] = (SELECT top 1 MostRecent_Full FROM MostRecent)
				OR	(
					RIGHT(S.Name,3) = 'SQD'
					AND S.[DateModified] = (SELECT top 1 MostRecent_Diff FROM MostRecent)
					AND S.[DateModified] > (SELECT top 1 MostRecent_Full FROM MostRecent)
					)
				OR	(
					RIGHT(S.Name,3) = 'SQT' AND S.[DateModified] > (SELECT CASE WHEN MostRecent_Full > MostRecent_Diff THEN MostRecent_Full ELSE MostRecent_Diff END FROM MostRecent)
					)
			)
			,QueuedFiles
			AS
			(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_DirectoryList(@RestorePath+@DBName+'\',NULL)
			WHERE		LEFT(name,len(@DBName)+1) = @DBName + '_'
			)
			,ProcessedFiles
			AS
			(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_DirectoryList(@RestorePath+@DBName+'\Processed\',NULL)
			WHERE		LEFT(name,len(@DBName)+1) = @DBName + '_'
			)
			,
			AppliedFiles
			AS
			(
			SELECT		DISTINCT
					REPLACE([physical_device_name],@RestorePath+@DBName+'\','') AS [name]
					,[physical_device_name] AS [Path]
			FROM		[msdb].[dbo].[backupset] bs
			JOIN		[msdb].[dbo].[backupmediafamily] bmf
				ON	bmf.[media_set_id] = bs.[media_set_id]
			WHERE		bs.database_name = DB_NAME(DB_ID(@DBName))
			)
			,Results
			AS
			(
			SELECT		@MostRecent_Full	LastAppliedFul
					,@MostRecent_Diff	LastAppliedDif
					,@MostRecent_Log	LastAppliedLog
					,N.name
					,CASE	WHEN Q.name IS NULL AND P.Name Is Not NULL	THEN P.[FullPathName]
						WHEN A.name IS NOT NULL				THEN A.[Path]
						WHEN Q.name IS NULL AND P.Name IS NULL		THEN N.[FullPathName]
						WHEN Q.name IS NOT NULL AND P.Name IS NULL	THEN Q.[FullPathName]
						END AS [Path]
					,N.IsFolder
					,N.Extension
					,N.DateCreated
					,N.DateAccessed
					,N.DateModified
					,N.Attributes
					,N.Size
					,CASE	WHEN Q.name IS NULL AND P.Name Is Not NULL	THEN 'Processed'
						WHEN A.name IS NOT NULL				THEN 'Applied'
						WHEN Q.name IS NULL AND P.Name Is NULL		THEN 'Not Coppied'
						WHEN Q.name IS NOT NULL AND P.Name IS NULL	THEN 'Not Processed'
						END AS [Status]
			FROM		NeededFiles N
			LEFT JOIN	QueuedFiles Q
				ON	Q.name = N.Name
			LEFT JOIN	ProcessedFiles P
				ON	P.name = N.Name
			LEFT JOIN	AppliedFiles A
				ON	A.name = N.Name


			UNION ALL


			SELECT		@MostRecent_Full	LastAppliedFul
					,@MostRecent_Diff	LastAppliedDif
					,@MostRecent_Log	LastAppliedLog
					,Q.*
					,'No Longer Needed'
			FROM		QueuedFiles Q
			WHERE		Q.Name NOT IN (SELECT Name FROM NeededFiles)


			UNION ALL


			SELECT		@MostRecent_Full	LastAppliedFul
					,@MostRecent_Diff	LastAppliedDif
					,@MostRecent_Log	LastAppliedLog
					,P.*
					,'No Longer Needed'
			FROM		ProcessedFiles P
			WHERE		P.Name NOT IN (SELECT Name FROM NeededFiles)
			)
	SELECT		*
	INTO		#Results
	FROM		Results

	-- RESET ANY PROCESSED FILES IF RESTARTING DATABASE
	IF @FullReset = 1  OR DB_ID(@DBName) IS NULL
	BEGIN
		DECLARE ProcessedFiles CURSOR
		FOR
		SELECT		[name]
		FROM		#Results
		WHERE		[Status] IN ('Applied','Processed')


		OPEN ProcessedFiles
		FETCH NEXT FROM ProcessedFiles INTO @FileName
		WHILE (@@FETCH_STATUS <> -1)
		BEGIN
			IF (@@FETCH_STATUS <> -2)
			BEGIN
				SET @ReadyToRun = 0
				PRINT 'Moving File ' + @FileName + ' to ' + @RestorePath +@DBName+'\'
				SET @CMD = 'MOVE /Y ' + @RestorePath + @DBName + '\Processed\' + @FileName + ' ' + @RestorePath+@DBName+'\'
				EXEC xp_CmdShell @CMD--, no_output
			END
			FETCH NEXT FROM ProcessedFiles INTO @FileName
		END
		CLOSE ProcessedFiles
		DEALLOCATE ProcessedFiles
	END
	ELSE
	BEGIN
		DECLARE AppliedFiles CURSOR
		FOR
		SELECT		[name]
		FROM		#Results
		WHERE		[Status] = 'Applied'


		OPEN AppliedFiles
		FETCH NEXT FROM AppliedFiles INTO @FileName
		WHILE (@@FETCH_STATUS <> -1)
		BEGIN
			IF (@@FETCH_STATUS <> -2)
			BEGIN
				SET @ReadyToRun = 0
				PRINT 'Moving File ' + @FileName + ' to ' + @RestorePath +@DBName+'\Processed\'
				SET @CMD = 'MOVE /Y ' + @RestorePath + @DBName + '\' + @FileName + ' ' + @RestorePath+@DBName+'\Processed\'
				EXEC xp_CmdShell @CMD--, no_output
			END
			FETCH NEXT FROM AppliedFiles INTO @FileName
		END
		CLOSE AppliedFiles
		DEALLOCATE AppliedFiles
	END


	--COPY ANY MISSING FILES
	DECLARE MissingFiles CURSOR
	FOR
	SELECT		[name]
	FROM		#Results
	WHERE		[Status] = 'Not Coppied'
	OPEN MissingFiles
	FETCH NEXT FROM MissingFiles INTO @FileName
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
		BEGIN
			SET @ReadyToRun = 0
			PRINT 'Copying File ' + @FileName + ' to ' + @RestorePath +@DBName
				+ CASE	WHEN @FileName Like '%.SQT' THEN '\'
					WHEN DB_ID(@DBName) IS NULL THEN '\'
					ELSE '\Processed\' END

			IF @FileName Like '%.SQT' OR DB_ID(@DBName) IS NULL
				SET @CMD = 'ROBOCOPY ' + @BackupPath + ' ' + @RestorePath+@DBName+'\ ' + @FileName
			ELSE
				SET @CMD = 'ROBOCOPY ' + @BackupPath + ' ' + @RestorePath+@DBName+'\Processed\ ' + @FileName

			EXEC xp_CmdShell @CMD--, no_output
		END
		FETCH NEXT FROM MissingFiles INTO @FileName
	END
	CLOSE MissingFiles
	DEALLOCATE MissingFiles


	--PURGE ANY UNNEEDED FILES
	DECLARE PurgeOldFiles CURSOR
	FOR
	SELECT		[Path]
	FROM		#Results
	WHERE		[Status] = 'No Longer Needed'


	OPEN PurgeOldFiles
	FETCH NEXT FROM PurgeOldFiles INTO @FileName
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
		BEGIN
			SET @ReadyToRun = 0
			PRINT 'Removing File ' + @FileName
			SET @CMD = 'DEL ' + @FileName
			EXEC xp_CmdShell @CMD--, no_output

		END
		FETCH NEXT FROM PurgeOldFiles INTO @FileName
	END
	CLOSE PurgeOldFiles
	DEALLOCATE PurgeOldFiles


	DROP TABLE #Results


	--IF @ReadyToRun = 0 AND @CleanOnly = 0
	--BEGIN
	--	PRINT 'Changes were made, re-checking status.'
	--	--GOTO START_CHECK
	--END


	PRINT 'All Files are ready to be processed.'


	IF @CleanOnly = 0
	BEGIN
		PRINT	'Agent Job: '+@AgentJob+' is being re-enabled.'
		EXEC		msdb.dbo.sp_update_job @job_Name=@AgentJob, @enabled=1
		--EXEC		msdb.dbo.sp_start_job @Job_Name = @AgentJob
	END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Logship_Fix] TO [public]
GO
