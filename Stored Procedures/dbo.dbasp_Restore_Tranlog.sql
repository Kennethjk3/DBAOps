SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Restore_Tranlog]
					(
					@DBName		SYSNAME
					,@DBPath	VarChar(max) = null
					,@LogPath	VarChar(max) = null
					)
AS


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	04/02/2013	Steve Ledridge		Modified calls and logic and made more portable to other servers,


BEGIN


	DECLARE @errorcode		INT
	DECLARE @sqlerrorcode		INT
	DECLARE	@Path			VarChar(MAX)
	DECLARE	@CMD			VarChar(MAX)
	DECLARE @CMD2			VarChar(8000)
	DECLARE	@FileName		VarChar(MAX)
	DECLARE @spid			INT
	DECLARE	@tsql			NVARCHAR(4000)
		,@CnD_CMD		VARCHAR(8000)
		,@COPY_CMD		VARCHAR(max)
		,@CopyStartTime		DateTime
		,@filegroups		VARCHAR(MAX)
		,@files			VARCHAR(MAX)

	DECLARE	@MostRecent_Full	DATETIME
		,@MostRecent_Diff	DATETIME
		,@MostRecent_Log	DATETIME
		,@BackupPath		VARCHAR(MAX)
		,@RestorePath		VARCHAR(MAX)


	DECLARE		@SourceFiles		TABLE
			(
			[Mask]			[nvarchar](4000) NULL,
			[Name]			[nvarchar](4000) NULL,
			[FullPathName]		[nvarchar](4000) NULL,
			[Directory]		[nvarchar](4000) NULL,
			[Extension]		[nvarchar](4000) NULL,
			[DateCreated]		[datetime] NULL,
			[DateAccessed]		[datetime] NULL,
			[DateModified]		[datetime] NULL,
			[Attributes]		[nvarchar](4000) NULL,
			[Size]			[bigint] NULL
			)


	DECLARE		@nameMatches		TABLE (NAME VARCHAR(MAX))
	DECLARE		@CopyAndDeletes		TABLE (CnD_CMD VarChar(max))

	DECLARE		@DBSources		TABLE
			(
			DBName			SYSNAME
			,BackupPath		VARCHAR(8000)
			,AgentJob		VarChar(8000)
			)


	INSERT INTO	@DBSources
	SELECT		'EditorialSiteDB'	,'\\SEAPEDSQL0A\SEAPEDSQL0A_backup\'		,'LSRestore_SEAPEDSQL0A_EditorialSiteDB' UNION ALL
	SELECT		'EventServiceDB'	,'\\SEAPEDSQL0A\SEAPEDSQL0A_backup\'		,'LSRestore_SEAPEDSQL0A_EventServiceDB' UNION ALL
	SELECT		'Virtuoso_Master'		,'\\FREPSQLRYLA01\FREPSQLRYLA01_backup\'	,'LSRestore_FREPSQLRYLA01_Virtuoso_Master' UNION ALL
	SELECT		'GINS_Master'		,'\\FREPSQLRYLB01\FREPSQLRYLB01_backup\'	,'LSRestore_FREPSQLRYLB01_GINS_Master' UNION ALL
	SELECT		'Gins_Integration'	,'\\FREPSQLRYLB01\FREPSQLRYLB01_backup\'	,'LSRestore_FREPSQLRYLB01_Gins_Integration' UNION ALL
	SELECT		'RM_Integration'	,'\\FREPSQLRYLA01\FREPSQLRYLA01_backup\'	,'LSRestore_FREPSQLRYLB01_RM_Integration'


	SELECT		@DBName		= DBName
			,@BackupPath	= BackupPath
			,@RestorePath	= '\\'+ LEFT(@@ServerName,CHARINDEX('\',@@ServerName+'\')-1)+'\'+REPLACE(@@ServerName,'\','$')+'_backup\LogShip\'+@DBName
			,@COPY_CMD	= 'ROBOCOPY '+@BackupPath+'\ '+@RestorePath +'\'
	FROM		@DBSources
	WHERE		DBName		= @DBName


	SELECT	@Path		= '\\'+ LEFT(@@ServerName,CHARINDEX('\',@@ServerName+'\')-1)+'\'+REPLACE(@@ServerName,'\','$')+'_backup\LogShip\'+@DBName
		,@DBPath	= COALESCE(@DBPath,DBAOps.dbo.dbaudf_GetSharePath(REPLACE(@@ServerName,'\','$')+'_mdf'))
		,@LogPath	= COALESCE(@LogPath,DBAOps.dbo.dbaudf_GetSharePath(REPLACE(@@ServerName,'\','$')+'_ldf'))
		,@CMD		= '-SQL "RESTORE LOG [' + @DBName + '] FROM DISK = '''
						+ @Path + '\' + @DBName + '_tlog_*.SQT'' WITH STANDBY = '''
						+ @DBPath + '\UNDO_' + @DBName + '.dat'', MOVETO = '''
						+ @Path + '\Processed''"'


	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	--		KILL OPEN CONNECTIONS ON DB BEFORE RESTORING
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	EXEC DBAOps.dbo.dbasp_KillAllOnDB @DBName
	RAISERROR ('All Connections to %s Have Been Killed',-1,-1,@DBName) WITH NOWAIT


	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	--		START PROCESSING
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	IF DB_ID(@DBName) IS NULL	-- DATABASE NEEDS TO START FROM A FULL BACKUP
	BEGIN
		RAISERROR ('dbasp_Restore_Tranlog cannot be run on %s because the database does not yet exist.', 16, 1, @DBName)
		RETURN -1
	END
	-------------------------------------------------------------------------------------
	-- RESTORE ALL TRAN LOG FILES AND MOVE TO PROCESSED FOLDER
	-------------------------------------------------------------------------------------
	EXECUTE master..sqlbackup @CMD, @errorcode OUT, @sqlerrorcode OUT;
	IF (@errorcode >= 500) OR (@sqlerrorcode <> 0)
	BEGIN
		RAISERROR ('LogShip Restore on %s failed with exit code: %d  SQL error code: %d', 16, 1, @DBName, @errorcode, @sqlerrorcode)
		RETURN @errorcode
	END


		StartFileCopySection:
	SET @CopyStartTime = GETDATE();


	--SET @CMD	= 'SELECT '''+@DBName +'_db_FG_''+ name+''_%'' FROM [DYN_DBA_RMT].['+@DBName+'].sys.filegroups'
	--		+ CASE WHEN NULLIF(@filegroups,'') IS NOT NULL THEN ' where name = '''+@filegroups+'''' ELSE '' END
	--INSERT INTO @nameMatches
	--EXEC(@CMD)


	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_db_%')

	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_dfntl_%')


	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_tlog_%')


	---- ONLY COPY SPECIFIED FILEGROUPS IF THEY WERE SPECIFIED
	--IF NULLIF(@FileGroups,'') IS NOT NULL
	--DELETE	@nameMatches
	--WHERE	Name LIKE '%_db_FG_%'
	--  AND	Name NOT IN (SELECT @DBName +'_db_FG_'+SplitValue+'%' FROM dbo.dbaudf_StringToTable(@FileGroups,','))


	--SELECT * FROM @nameMatches


	DELETE		@SourceFiles

	INSERT INTO	@SourceFiles
	SELECT		DISTINCT
			T2.Name
			,T1.*
	FROM		DBAOps.dbo.dbaudf_DirectoryList2(@BackupPath,NULL,0) T1
	JOIN		@nameMatches T2
		ON	T1.NAME LIKE T2.NAME


	--SELECT @BackupPath
	--SELECT * FROM @SourceFiles


	-- REMOVE DB RECORDS THAT WERE IDENTIFIED AS DB AND FILEGROUP
	DELETE
	FROM	@SourceFiles
	WHERE	Mask NOT IN (SELECT name FROM @nameMatches WHERE name LIKE  '%_db_FG_%')
	  AND	Name LIKE '%_db_FG_%'


	DELETE		T1
	FROM		@SourceFiles T1
	LEFT JOIN	(
			SELECT	MASK,EXTENSION,MAX(DateModified)DateModified
			FROM	@SourceFiles
			GROUP BY MASK,EXTENSION
			) T2
		ON	T1.Mask = T2.Mask
		AND	T1.Extension = T2.Extension
		AND	T1.DateModified = T2.DateModified
	WHERE		T1.Extension NOT IN ('.cTRN','.TRN','.sqt')
		AND	T2.Mask IS NULL


	DELETE		T1
	FROM		@SourceFiles T1
	WHERE		Extension IN ('.cTRN','.TRN','.sqt')
		AND	DateModified <= (
						SELECT	MAX(DateModified)DateModified
						FROM	@SourceFiles
						WHERE	Extension NOT IN ('.cTRN','.TRN','.sqt')
						)


	DELETE		@SourceFiles
	WHERE		REPLACE(NAME,extension,'') IN	(
							SELECT		REPLACE(NAME,extension,'')
							FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,NULL,0)
							WHERE		Extension = '.partial'
							)


	;WITH		SourceFiles
			AS
			(
			SELECT		*
			FROM		@SourceFiles
			)
			,QueuedFiles
			AS
			(
			SELECT		DISTINCT T1.*
			FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,null,0) T1
			JOIN		@nameMatches T2
				ON	T1.NAME LIKE T2.NAME
			WHERE		T1.Extension != '.partial'
			)
			,ProcessedFiles
			AS
			(
			SELECT		DISTINCT T1.*
			FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath+'\Processed',null,0) T1
			JOIN		@nameMatches T2
				ON	T1.NAME LIKE T2.NAME
			)
			,AppliedFiles
			AS
			(
			SELECT		DISTINCT
					REPLACE([physical_device_name],@RestorePath+'\','') AS [name]
					,[physical_device_name] AS [Path]
			FROM		[msdb].[dbo].[backupset] bs
			JOIN		[msdb].[dbo].[backupmediafamily] bmf
				ON	bmf.[media_set_id] = bs.[media_set_id]
			WHERE		bs.database_name = @DBName
			)
			,Files
			AS
			(
			SELECT		S.Name
					,S.FullPathName
					,S.DateModified
					,CASE	WHEN COALESCE(Q.Name,P.Name,A.Name) IS NULL THEN 'S'
						WHEN Q.NAME IS NOT NULL AND COALESCE(P.Name,A.Name) IS NULL THEN 'Q'
						WHEN Q.NAME IS NOT NULL AND P.NAME IS NOT NULL THEN 'QP'
						WHEN Q.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'QA'
						WHEN Q.NAME IS NOT NULL AND P.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'QPA'
						WHEN P.NAME IS NOT NULL AND COALESCE(Q.Name,A.Name) IS NULL THEN 'P'
						WHEN A.NAME IS NOT NULL AND COALESCE(Q.Name,P.Name) IS NULL THEN 'A'
						WHEN P.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'PA'
						ELSE '?'
						END AS [Status]


			FROM		SourceFiles S
			LEFT JOIN	QueuedFiles Q
				ON	Q.name = S.Name
			LEFT JOIN	ProcessedFiles P
				ON	P.name = S.Name
			LEFT JOIN	AppliedFiles A
				ON	A.name = S.Name

			UNION ALL
			SELECT		Name
					,FullPathName
					,DateModified
					,'X'
			FROM		QueuedFiles
			WHERE		Name NOT IN (SELECT Name FROM SourceFiles)
			UNION ALL
			SELECT		Name
					,FullPathName
					,DateModified
					,'X'
			FROM		ProcessedFiles
			WHERE		Name NOT IN (SELECT Name FROM SourceFiles)
			)

	INSERT INTO	@CopyAndDeletes
	SELECT		CASE [Status]
				WHEN 'S'	THEN @COPY_CMD + ' '+ name
				WHEN 'QP'	THEN 'DEL ' + @RestorePath + '\Processed\' + name
				WHEN 'QA'	THEN 'MOVE ' + @RestorePath + '\' + name + ' ' + @RestorePath + '\Processed\'
				WHEN 'QPA'	THEN 'DEL ' + @RestorePath + '\' + name
				WHEN 'P'	THEN 'MOVE ' + @RestorePath + '\Processed\' + name + ' ' + @RestorePath + '\'
				WHEN 'A'	THEN @COPY_CMD + 'Processed\ '+ name
				WHEN 'X'	THEN 'DEL ' + fullpathname
				ELSE '|' + fullpathname + ' is Good.'
				END
	FROM		Files F
	ORDER BY	[Status],[DateModified]


	RAISERROR('  -- Starting Copy''s and Delete''s',-1,-1) WITH NOWAIT


	DECLARE CopyAndDeleteCursor CURSOR
	FOR
	SELECT CnD_CMD FROM @CopyAndDeletes


	OPEN CopyAndDeleteCursor
	FETCH NEXT FROM CopyAndDeleteCursor INTO @CnD_CMD
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SET @CMD = REPLACE (@CnD_CMD,'|','  ')
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT


			IF  LEFT(@CnD_CMD,1) != '|'
				exec xp_CmdShell @CnD_CMD,no_output
		END
		FETCH NEXT FROM CopyAndDeleteCursor INTO @CnD_CMD
	END


	CLOSE CopyAndDeleteCursor
	DEALLOCATE CopyAndDeleteCursor

	RAISERROR('  -- Done with Copy''s and Delete''s',-1,-1) WITH NOWAIT


	IF DATEDIFF(minute,@CopyStartTime,GETDATE()) > 15
		GOTO StartFileCopySection


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Restore_Tranlog] TO [public]
GO
