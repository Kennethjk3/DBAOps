SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Mirror_Database]
	(
	@ServerName		SYSNAME		= ''
	,@DBName		SYSNAME		= ''
	,@BackupPath		VARCHAR(MAX)	= NULL
	,@RestorePath		VARCHAR(MAX)	= NULL
	,@FullReset		BIT		= 1
	,@TestCopyOnly		BIT		= 1
	,@NoRestore		BIT		= 0
	,@filegroups		VARCHAR(MAX)	= NULL
	,@files			VARCHAR(MAX)	= NULL
	)
AS


--DECLARE	@ServerName		SYSNAME		= 'SEAPCRMSQL1A'
--	,@DBName		SYSNAME		= '${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM'
--	,@BackupPath		VARCHAR(MAX)	= NULL
--	,@RestorePath		VARCHAR(MAX)	= NULL
--	,@FullReset		BIT		= 1
--	,@TestCopyOnly		BIT		= 0
--	,@filegroups		VARCHAR(MAX)	= 'Primary'
--	,@files			VARCHAR(MAX)	= NULL


	SET NOCOUNT ON
	SET ANSI_NULLS ON
	SET ANSI_WARNINGS ON


	DECLARE		@MostRecent_Full	DATETIME
			,@MostRecent_Diff	DATETIME
			,@MostRecent_Log	DATETIME
			,@CMD			VARCHAR(MAX)
			,@CMD2			VARCHAR(MAX)
			,@COPY_CMD		VARCHAR(MAX)
			,@CnD_CMD		VARCHAR(8000)
			,@FileName		VARCHAR(MAX)
			,@AgentJob		SYSNAME
			,@MachineName		SYSNAME
			,@RemoteEndpointName	SYSNAME
			,@RemoteEndpointID	INT
			,@RemoteEndpointPort	INT
			,@LocalEndpointName	SYSNAME
			,@LocalEndpointID	INT
			,@LocalEndpointPort	INT
			,@CreateEndpoint	VarChar(MAX)
			,@Local_FQDN		SYSNAME
			,@Remote_FQDN		SYSNAME
			,@ShareName		VarChar(500)
			,@LogPath		VarChar(100)
			,@DataPath		VarChar(100)
			,@CMD_TYPE		CHAR(3)
			,@errorcode		INT
			,@sqlerrorcode		INT
			,@RestoreOrder		INT
			,@DateModified		DATETIME
			,@Extension		VARCHAR(MAX)
			,@CopyStartTime		DateTime
			,@partial_flag		BIT
			,@FileNameSet		VarChar(MAX)
			,@RtnCode		INT
			,@CopyThreads		INT


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


	IF OBJECT_ID('tempdb..#filelist')	IS NOT NULL	DROP TABLE #filelist
	CREATE TABLE #filelist		(
					LogicalName NVARCHAR(128) NULL,
					PhysicalName NVARCHAR(260) NULL,
					type CHAR(1),
					FileGroupName NVARCHAR(128) NULL,
					SIZE NUMERIC(20,0),
					MaxSize NUMERIC(20,0),
					FileId BIGINT,
					CreateLSN NUMERIC(25,0),
					DropLSN NUMERIC(25,0),
					UniqueId VARCHAR(50),
					ReadOnlyLSN NUMERIC(25,0),
					ReadWriteLSN NUMERIC(25,0),
					BackupSizeInBytes BIGINT,
					SourceBlockSize INT,
					FileGroupId INT,
					LogGroupGUID VARCHAR(50) NULL,
					DifferentialBaseLSN NUMERIC(25,0),
					DifferentialBaseGUID VARCHAR(50),
					IsReadOnly BIT,
					IsPresent BIT,
					TDEThumbprint VARBINARY(32) NULL,
					New_PhysicalName  NVARCHAR(1000) NULL
					)

	SELECT		@partial_flag	= 0
			,@CopyThreads	= 48
			,@MachineName	= LEFT(@ServerName,CHARINDEX('\',@ServerName+'\')-1)
			,@BackupPath	= COALESCE(@BackupPath,'\\'+@MachineName+'\'+REPLACE(@ServerName,'\','$')+'_backup')
			,@RestorePath	= COALESCE(@RestorePath,'\\'+ LEFT(@@ServerName,CHARINDEX('\',@@ServerName+'\')-1)+'\'+REPLACE(@@ServerName,'\','$')+'_backup')
			--,@COPY_CMD	= 'ROBOCOPY '+@BackupPath+' '+@RestorePath+' '
			,@COPY_CMD	= 'RichCopy64.exe '+@BackupPath+' '+@RestorePath
/* Files and Dirs to Include\Exclude */	+ ' /FIF "{FileName}" /FED "*"'
/* Copy Options */			+ ' /CDSD /FSD /FAD /TSD /TSU /CT /NC +T -T'
/* Threads Prio */			+ ' /TS 99 /TD {CopyThreads} /TP 1 /PP 3 /R 100'
/* Logging Info */			+ ' /QA /QP "'+@RestorePath+'\'+@DBName+'_RichCopy.log" /UE /US /UD /UC /UPF /UPC /UPS /UFC /UCS /USC /USS /USD /UPR /UET'

			,@CreateEndpoint = 'CREATE ENDPOINT [Mirroring]
	AUTHORIZATION [sa]
	STATE=STARTED
	AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
	FOR DATA_MIRRORING (ROLE = PARTNER, AUTHENTICATION = WINDOWS NEGOTIATE
, ENCRYPTION = REQUIRED ALGORITHM RC4)'


	-- ADD DYNAMIC LINKED SERVER
	IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
		EXEC master.dbo.sp_dropserver @server=N'DYN_DBA_RMT', @droplogins='droplogins'

	EXEC sp_addlinkedserver @server='DYN_DBA_RMT',@srvproduct='',@provider='SQLNCLI',@datasrc=@ServerName
	EXEC master.dbo.sp_serveroption @server=N'DYN_DBA_RMT', @optname=N'rpc', @optvalue=N'true'
	EXEC master.dbo.sp_serveroption @server=N'DYN_DBA_RMT', @optname=N'rpc out', @optvalue=N'true'
	EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'DYN_DBA_RMT', @locallogin = N'AMER\s-sledridge', @useself = N'False', @rmtuser = N'LinkedServer_User', @rmtpassword = N'${{secrets.LINKEDSERVER_USER_PW}}'


	IF @TestCopyOnly = 0
	BEGIN
		RAISERROR('Disabeling Transaction Log Backup Job on On Primary Server',-1,-1) WITH NOWAIT
		-- DISABLE LOG BACKUPS ON PRIMARY TILL MIRRORING IS DONE
		SET @CMD = 'EXEC msdb.dbo.sp_update_job @job_name=N''MAINT - TranLog Backup'', @enabled=0'
		RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
		EXEC (@CMD)  AT [DYN_DBA_RMT]


		-- GET LOCAL MIRRORING ENPOINT INFO
		SELECT		@LocalEndpointID	= endpoint_id
				,@LocalEndpointPort	= port
		FROM		master.sys.tcp_endpoints
		WHERE		TYPE=4


		IF @LocalEndpointID IS NOT NULL
			SELECT		@LocalEndpointName = NAME
			FROM		master.sys.endpoints
			WHERE		endpoint_id = @LocalEndpointID
		ELSE
		BEGIN
			EXEC (@CreateEndpoint)


			SELECT		@LocalEndpointID	= endpoint_id
					,@LocalEndpointPort	= port
					,@LocalEndpointName	= 'Mirroring'-- select *
			FROM		master.sys.tcp_endpoints
			WHERE		TYPE=4
		END


		-- GET REMOTE MIRRORING ENPOINT INFO
		SELECT		@RemoteEndpointID	= endpoint_id
				,@RemoteEndpointPort	= port
		FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints
		WHERE		TYPE=4


		IF @RemoteEndpointID IS NOT NULL
			SELECT		@RemoteEndpointName = NAME
			FROM		[DYN_DBA_RMT].master.sys.endpoints
			WHERE		endpoint_id = @RemoteEndpointID
		ELSE
		BEGIN
			EXEC (@CreateEndpoint) AT [DYN_DBA_RMT]


			SELECT		@LocalEndpointID	= endpoint_id
					,@LocalEndpointPort	= port
					,@LocalEndpointName	= 'Mirroring'
			FROM		[DYN_DBA_RMT].master.sys.tcp_endpoints
			WHERE		TYPE=4
		END
	END

	-- GET LOCAL FQDN
	EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @Local_FQDN OUTPUT
	SELECT @Local_FQDN = Cast(SERVERPROPERTY('MachineName') as nvarchar) + '.' + @Local_FQDN


	-- GET REMOTE FQDN
	EXEC [DYN_DBA_RMT].master..xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @Remote_FQDN OUTPUT
	SELECT @Remote_FQDN = @MachineName + '.' + @Remote_FQDN


	IF @FullReset = 1 AND DB_ID(@DBNAME) IS NOT NULL
	BEGIN
		Print '**** FULL RESET REQUESTED, '+UPPER(@DBNAME)+' DATABASE WILL BE DROPED AND RECREATED. ***'


		-- DROP ANY DATABASE SNAPSHOTS
		CheckForSnapshots:
		IF EXISTS(SELECT 1 FROM sys.databases WHERE source_database_id = DB_ID(@DBNAME))
		BEGIN
			SELECT TOP 1 @CMD = name, @CMD2 = 'DROP DATABASE ['+name+'];'
			FROM sys.databases
			WHERE source_database_id = DB_ID(@DBNAME)

			RAISERROR('  -- %s is a Snapshot of %s and must be droped first.',-1,-1,@CMD2,@DBNAME) WITH NOWAIT
			RAISERROR('    -- %s',-1,-1,@CMD2) WITH NOWAIT
				EXEC DBAOps.dbo.dbasp_KillAllOnDB @CMD
				EXEC (@CMD2)
				EXEC msdb.dbo.sp_delete_database_backuphistory @CMD

			IF DB_ID(@CMD2) IS NULL
				RAISERROR('      -- Success.',-1,-1) WITH NOWAIT
			ELSE
				RAISERROR('      -- Failure.',-1,-1) WITH NOWAIT
		END

		IF EXISTS(SELECT 1 FROM sys.databases WHERE source_database_id = DB_ID(@DBNAME))
			GOTO CheckForSnapshots

		-- SET DATABASE TO RESTRICTED USER TO KICK EVERYONE OUT
		IF (select state_desc From master.sys.databases WHERE database_id = DB_ID(@DBName)) = 'ONLINE'
		BEGIN
			RAISERROR('  -- Restricting %s so that drop can be done.',-1,-1,@DBNAME) WITH NOWAIT
			SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD)
		END


		-- DISABLE MIRRORING PARTNERSHIP
		IF EXISTS(select * From master.sys.database_mirroring WHERE database_id = DB_ID(@DBName) AND mirroring_partner_name IS NOT NULL)
		BEGIN
			RAISERROR('  -- %s is currently a Mirroring Partner and must be Turned Off first.',-1,-1,@DBNAME) WITH NOWAIT
			SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER OFF;'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD)
		END


		-- TRY SIMPLE DROP
		BEGIN TRY
			RAISERROR('  -- Dropping %s...',-1,-1,@DBNAME) WITH NOWAIT
			SET @CMD = 'DROP DATABASE ['+@DBName+']'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD)
		END TRY
		BEGIN CATCH
			RAISERROR('      -- Failed, Attempting to Prepare DB For Dropping.',-1,-1,@DBNAME) WITH NOWAIT
		END CATCH

		-- RECOVER RESTORING DATABASE
		IF EXISTS(select * From master.sys.databases WHERE database_id = DB_ID(@DBName) AND state_desc = 'RESTORING')
		BEGIN
			RAISERROR('  -- %s is currently Restoring and must be Recovered first.',-1,-1,@DBNAME) WITH NOWAIT
			SET @CMD = 'RESTORE DATABASE ['+@DBName+'] WITH RECOVERY;'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD)
		END

		-- TRY SIMPLE DROP AGIAN
		IF DB_ID(@DBNAME) IS NOT NULL
		BEGIN
			RAISERROR('  -- Dropping %s...',-1,-1,@DBNAME) WITH NOWAIT
			SET @CMD = 'DROP DATABASE ['+@DBName+']'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD)
		END


		IF DB_ID(@DBName) IS NULL
			RAISERROR('      -- Success.',-1,-1) WITH NOWAIT
		ELSE
			RAISERROR('      -- Failure.',-1,-1) WITH NOWAIT
	END


	IF DB_ID(@DBNAME) IS NULL
		EXEC msdb.dbo.sp_delete_database_backuphistory @DBName


	StartFileCopySection:
	SET @CopyStartTime = GETDATE();


	SET @CMD	= 'SELECT '''+@DBName +'_db_FG_''+ name+''_%'' FROM [DYN_DBA_RMT].['+@DBName+'].sys.filegroups'
			+ CASE WHEN NULLIF(@filegroups,'') IS NOT NULL THEN ' where name = '''+@filegroups+'''' ELSE '' END
	INSERT INTO @nameMatches
	EXEC(@CMD)


	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_db_%')

	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_dfntl_%')


	INSERT INTO @nameMatches(NAME)
	VALUES  (@DBName+'_tlog_%')


	-- ONLY COPY SPECIFIED FILEGROUPS IF THEY WERE SPECIFIED
	IF NULLIF(@FileGroups,'') IS NOT NULL
	DELETE	@nameMatches
	WHERE	Name LIKE '%_db_FG_%'
	  AND	Name NOT IN (SELECT @DBName +'_db_FG_'+SplitValue+'%' FROM dbo.dbaudf_StringToTable(@FileGroups,','))


	--SELECT * FROM @nameMatches


	DELETE		@SourceFiles

	INSERT INTO	@SourceFiles
	SELECT		T1.Mask
			,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
			,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
			,T1.Directory
			,T1.Extension
			,MAX(T1.DateCreated)
			,MAX(T1.DateAccessed)
			,MAX(T1.DateModified)
			,MAX(T1.Attributes)
			,SUM(T1.Size)
	FROM		(
			SELECT		T2.Name Mask
					,T1.*
			FROM		DBAOps.dbo.dbaudf_DirectoryList2(@BackupPath,NULL,0) T1
			JOIN		@nameMatches T2
				ON	T1.NAME LIKE T2.NAME
			) T1
	GROUP BY	T1.Mask
			,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
			,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
			,T1.Directory
			,T1.Extension


	--SELECT @BackupPath
	--SELECT * FROM @SourceFiles


	-- REMOVE DB RECORDS THAT WERE IDENTIFIED AS DB AND FILEGROUP
	DELETE
	FROM	@SourceFiles
	WHERE	Mask NOT IN (SELECT name FROM @nameMatches WHERE name LIKE  '%_db_FG_%')
	  AND	Name LIKE '%_db_FG_%'


	--DELETE ALL BUT THE MOST RECENT FULL AND DIFFERENTIAL
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


	-- DELETE ANY DIFF's OLDER THAN THE MOST RECENT FULL
	DELETE		T1
	FROM		@SourceFiles T1
	WHERE		Extension IN('.DIF','.cDIF','.SQD')
		AND	DateModified <= (
						SELECT	MAX(DateModified)DateModified
						FROM	@SourceFiles
						WHERE	Extension IN ('.cBAK','.BAK','.sqb')
						)


	--SELECT * FROM @SourceFiles


	-- DELETE ANY LOGS OLDER THAN THE MOST RECENT DIFF OR FULL
	DELETE		T1
	FROM		@SourceFiles T1
	WHERE		Extension IN ('.cTRN','.TRN','.sqt')
		AND	DateModified <= (
						SELECT	MAX(DateModified)DateModified
						FROM	@SourceFiles
						WHERE	Extension NOT IN ('.cTRN','.TRN','.sqt')
						)


	--SELECT * FROM @SourceFiles

	--DELETE		@SourceFiles
	--WHERE		REPLACE(NAME,extension,'') IN	(
	--						SELECT		REPLACE(NAME,extension,'')
	--						FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,NULL,0)
	--						WHERE		Extension = '.sqb'
	--						)


	--SELECT  * FROM @SourceFiles

	;WITH		SourceFiles
			AS
			(
			SELECT		*
			FROM		@SourceFiles
			)
			,QueuedFiles
			AS
			(
			SELECT		REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*') Name
					,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*') FullPathName
					,T1.Directory
					,T1.Extension
					,MAX(T1.DateCreated) DateCreated
					,MAX(T1.DateAccessed) DateAccessed
					,MAX(T1.DateModified) DateModified
					,MAX(T1.Attributes) Attributes
					,SUM(T1.Size) Size
			FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,NULL,0) T1
			JOIN		@nameMatches T2
				ON	T1.NAME LIKE T2.NAME
			WHERE		T1.Extension != '.partial'
				AND	T1.DateModified > '1/2/1980'
			GROUP BY	REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
					,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
					,T1.Directory
					,T1.Extension
			)
			--,ProcessedFiles
			--AS
			--(
			--SELECT		DISTINCT T1.*
			--FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath+'\Processed',null,0) T1
			--JOIN		@nameMatches T2
			--	ON	T1.NAME LIKE T2.NAME
			--)
			--,AppliedFiles
			--AS
			--(
			--SELECT		DISTINCT
			--		REPLACE(REPLACE(DBAOps.dbo.dbaudf_RegexReplace([physical_device_name],'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*'),@RestorePath+'\','') AS [name]
			--		,REPLACE(DBAOps.dbo.dbaudf_RegexReplace([physical_device_name],'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*') AS [Path]
			--FROM		[msdb].[dbo].[backupset] bs
			--JOIN		[msdb].[dbo].[backupmediafamily] bmf
			--	ON	bmf.[media_set_id] = bs.[media_set_id]
			--WHERE		bs.database_name = @DBName
			--)
			,Files
			AS
			(
			SELECT		S.Name
					,S.FullPathName
					,S.DateModified
					,'S' AS [Status]
					--,CASE	WHEN COALESCE(Q.Name,P.Name,A.Name) IS NULL THEN 'S'
					--	WHEN Q.NAME IS NOT NULL AND COALESCE(P.Name,A.Name) IS NULL THEN 'Q'
					--	WHEN Q.NAME IS NOT NULL AND P.NAME IS NOT NULL THEN 'QP'
					--	WHEN Q.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'QA'
					--	WHEN Q.NAME IS NOT NULL AND P.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'QPA'
					--	WHEN P.NAME IS NOT NULL AND COALESCE(Q.Name,A.Name) IS NULL THEN 'P'
					--	WHEN A.NAME IS NOT NULL AND COALESCE(Q.Name,P.Name) IS NULL THEN 'A'
					--	WHEN P.NAME IS NOT NULL AND A.NAME IS NOT NULL THEN 'PA'
					--	ELSE '?'
					--	END AS [Status]


			FROM		SourceFiles S
			--LEFT JOIN	QueuedFiles Q
			--	ON	Q.name = S.Name
			--LEFT JOIN	AppliedFiles A
			--	ON	A.name = S.Name

			UNION ALL
			SELECT		Name
					,FullPathName
					,DateModified
					,'X'
			FROM		QueuedFiles
			WHERE		Name NOT IN (SELECT Name FROM SourceFiles)
			--UNION ALL
			--SELECT		Name
			--		,FullPathName
			--		,DateModified
			--		,'X'
			--FROM		ProcessedFiles
			--WHERE		Name NOT IN (SELECT Name FROM SourceFiles)
			)

	INSERT INTO	@CopyAndDeletes
	SELECT		CASE [Status]
				WHEN 'S'	THEN REPLACE(@COPY_CMD,'{FileName}',name)
				--WHEN 'QP'	THEN 'DEL ' + @RestorePath + '\Processed\' + name
				--WHEN 'QA'	THEN 'MOVE ' + @RestorePath + '\' + name + ' ' + @RestorePath + '\Processed\'
				--WHEN 'QPA'	THEN 'DEL ' + @RestorePath + '\' + name
				--WHEN 'P'	THEN 'MOVE ' + @RestorePath + '\Processed\' + name + ' ' + @RestorePath + '\'
				--WHEN 'A'	THEN @COPY_CMD + 'Processed\ '+ name
				WHEN 'X'	THEN 'DEL ' + fullpathname
				ELSE '|' + fullpathname + ' is Good.'
				END
	FROM		Files F
	ORDER BY	[Status],[DateModified]


	RAISERROR('  -- Starting Copy''s and Delete''s',-1,-1) WITH NOWAIT


	DECLARE CopyAndDeleteCursor SCROLL CURSOR
	FOR
	SELECT CnD_CMD FROM @CopyAndDeletes


	OPEN CopyAndDeleteCursor
	FETCH NEXT FROM CopyAndDeleteCursor INTO @CnD_CMD
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			RetryCnD:

			SET @CnD_CMD = REPLACE(@CnD_CMD,'{CopyThreads}',CAST(@CopyThreads AS VARCHAR(10)))

			SET @CMD = REPLACE (@CnD_CMD,'|','  ')
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT


			IF  LEFT(@CnD_CMD,1) NOT IN ('|','')
				exec @RtnCode = xp_CmdShell @CnD_CMD ,no_output
			If @RtnCode > 0
			BEGIN
				-- COPY ERROR
				RAISERROR('      -- Copy or Delete Return Code: %d',-1,-1,@RtnCode) WITH NOWAIT

				IF @CopyThreads > 2
				BEGIN
					SET @CopyThreads = @CopyThreads/2
					RAISERROR('      -- Copy Threads Changed to %d',-1,-1,@CopyThreads) WITH NOWAIT
				END
				ELSE
				BEGIN
					RAISERROR('      -- !! Copy Threads Already Lowerd to 1. Aborting !!',-1,-1) WITH NOWAIT
					GOTO EndCnDLoop
				END

				FETCH RELATIVE 0 FROM CopyAndDeleteCursor INTO @CnD_CMD

				GOTO RetryCnD
			END

			SET 	@CnD_CMD = NULL
			SET 	@CMD = NULL


		END
		FETCH NEXT FROM CopyAndDeleteCursor INTO @CnD_CMD
	END


	EndCnDLoop:

	CLOSE CopyAndDeleteCursor
	DEALLOCATE CopyAndDeleteCursor

	RAISERROR('  -- Done with Copy''s and Delete''s',-1,-1) WITH NOWAIT


	--IF DATEDIFF(minute,@CopyStartTime,GETDATE()) > 15
	--	GOTO StartFileCopySection


	-- GET LOG PATH
	SET		@ShareName	= REPLACE(@@ServerName,'\','$')+'_ldf'
	exec DBAOps.dbo.dbasp_get_share_path @ShareName,@LogPath OUT


	-- GET DATA PATH
	SET		@ShareName	= REPLACE(@@ServerName,'\','$')+'_mdf'
	exec DBAOps.dbo.dbasp_get_share_path @ShareName,@DataPath OUT


	IF @NoRestore = 1 GOTO NoRestore


	RAISERROR('  -- Starting DB Restore''s',-1,-1) WITH NOWAIT
	DECLARE RestoreDBCursor CURSOR
	FOR
	SELECT		MAX(CASE WHEN T1.Extension IN('.cTRN','.TRN','.sqt') THEN 3
				WHEN T1.Extension IN('.cDIF','.SQD') THEN 2 ELSE 1 END) [RestoreOrder]
			,MAX(T1.[DateModified]) [DateModified]
			,REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*') FullPathName
			,T1.[Extension]
	FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,NULL,0) T1
	JOIN		@nameMatches T2
		ON	T1.NAME LIKE T2.NAME
	LEFT JOIN	(
			SELECT		DISTINCT
					REPLACE([physical_device_name],@RestorePath+'\','') AS [name]
					,[physical_device_name] AS [Path]
			FROM		[msdb].[dbo].[backupset] bs
			JOIN		[msdb].[dbo].[backupmediafamily] bmf
				ON	bmf.[media_set_id] = bs.[media_set_id]
			JOIN		msdb.dbo.restorehistory rh
				ON	rh.backup_set_id = bs.backup_set_id
				AND	rh.destination_database_name = bs.database_name
			WHERE		bs.database_name = @DBName
			) T3
		ON	T3.[name] = T1.Name

	WHERE		T3.[Name] IS NULL
		AND	(
			Extension IN('.cTRN','.TRN','.sqt')
		OR	((@FullReset = 1  OR DB_ID(@DBName) IS NULL) AND Extension IN('.cDIF','.SQD','.cBAK','.sqb'))
			)
	GROUP BY	REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.FullPathName,'set_[0-9][0-9]_of_[0-9][0-9]','set_**'),'**','*')
			,T1.[Extension]
	ORDER BY	1,2


	OPEN RestoreDBCursor
	FETCH NEXT FROM RestoreDBCursor INTO @RestoreOrder,@DateModified,@FileName, @Extension
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			IF @FileName Like '%_set_*%'
			BEGIN
				SET		@FileNameSET = NULL

				SELECT		@FileNameSET = COALESCE(@FileNameSET + CHAR(13)+CHAR(10)+', DISK = '''+T1.FullPathName+'''','DISK = '''+T1.FullPathName+'''')
				FROM		DBAOps.dbo.dbaudf_DirectoryList2(@RestorePath,@FileName,0) T1

				SET		@FileName = @FileNameSET
			END
			ELSE
				SET		@FileName = 'DISK = '''+@FileName+''''


			-- GET FILE HEADER INFO FROM THE BACKUP FILE
			DELETE FROM #filelist

			IF	-- REDGATE FILE
			@Extension IN ('.sqb','.sqd','.sqt')
			BEGIN
				SELECT @CMD2 = 'Exec master.dbo.sqlbackup ''-SQL "RESTORE FILELISTONLY FROM ' + REPLACE(@FileName,'''','''''') + '"'''
				PRINT '   -- ' + @CMD2
				INSERT INTO #filelist (LogicalName,PhysicalName,type, FileGroupName, SIZE,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
				EXEC (@CMD2)
			END
			ELSE
			BEGIN
				SELECT @CMD2 = 'RESTORE FILELISTONLY FROM ' + @FileName
				PRINT '   -- ' + @CMD2
				IF (SELECT @@version) NOT LIKE '%Server 2005%' AND (SELECT SERVERPROPERTY ('productversion')) > '10.00.0000' --sql2008 or higher
					INSERT INTO #filelist (LogicalName,PhysicalName,type,FileGroupName,SIZE,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
					EXEC (@CMD2)
				ELSE
					INSERT INTO #filelist (LogicalName,PhysicalName,type,FileGroupName,SIZE,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent)
					EXEC (@CMD2)
			END


			IF (SELECT COUNT(*) FROM #filelist) = 0
				RAISERROR('DBA Error: Unable to process FILELISTONLY for file %s.',16,1,@FileName)

			UPDATE		T1
				SET	NEW_PhysicalName = COALESCE(T2.detail03,CASE T1.TYPE WHEN 'D' THEN @DataPath ELSE @LogPath END)
								+ '\' + DBAOps.dbo.dbaudf_GetFileFromPath(PhysicalName)
			FROM		#filelist T1
			LEFT JOIN	dbo.local_control T2
				ON	T2.subject = 'restore_override'
				AND	T2.detail01 = @DBName
				AND	T2.detail02 = T1.LogicalName

			SELECT 	* FROM #filelist

			IF EXISTS (SELECT * FROM #filelist WHERE isPresent = 0) AND EXISTS (SELECT * FROM #filelist WHERE isPresent = 1 AND FileGroupId = 1)
				SET @Partial_flag = 1
			ELSE
				SET @Partial_flag = 0

			IF	-- FULL OR DIFF BACKUP FILE
			@Extension IN ('.cBAK','.cDIF','.sqd','.sqb')
			BEGIN
				SET @CMD = 'RESTORE DATABASE ['+ @DBName + '] '

				IF @Partial_flag = 1
					SELECT	@CMD = @CMD + DBAOps.dbo.dbaudf_ConcatenateUnique('FILEGROUP = '''+FileGroupName+'''')
					FROM	#filelist
					WHERE	isPresent = 1


				SET @CMD = @CMD + CHAR(13)+ CHAR(10)+'FROM    '+@FileName+ CHAR(13)+CHAR(10)

				SET @CMD	= @CMD
						+ 'WITH    ' + CASE @partial_flag WHEN 1 THEN 'PARTIAL, ' ELSE '' END
						+ 'NORECOVERY, REPLACE' + CHAR(13)+CHAR(10)


				SELECT		@CMD = @CMD
						+ '        ,MOVE ''' + LogicalName + ''' TO ''' + NEW_PhysicalName + '''' + CHAR(13) + CHAR(10)
				FROM		#filelist
				ORDER BY	FileID


				IF	-- REDGATE SYNTAX
				@Extension IN ('.sqd','.sqb')
				BEGIN
					SET @CMD = 'Exec master.dbo.sqlbackup ''-SQL "' + REPLACE(
											  REPLACE(
											  REPLACE(
											  REPLACE(
											  REPLACE(@CMD,CHAR(9),' ')
												      ,CHAR(13)+CHAR(10),' ')
												      ,'''','''''')
												      ,'  ',' ')
												      ,'  ',' ')
												     +'"'''


					PRINT '   -- ' + REPLACE(@CMD,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
					RAISERROR('',-1,-1) WITH NOWAIT
					EXEC (@CMD)
				END
				ELSE	-- MICROSOFT SYNTAX
				BEGIN
					SET @CMD = @CMD + '        ,STATS' + CHAR(13) + CHAR(10)


					PRINT '   -- ' + REPLACE(@CMD,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
					RAISERROR('',-1,-1) WITH NOWAIT
					EXEC(@CMD)
				END

			END


			IF	-- TRANSACTION LOG BACKUP FILE
			@Extension IN('.cTRN','.TRN','.sqt')
			BEGIN
				SET @CMD = 'RESTORE LOG '+@DBName+' FROM '+@FileName+' WITH NORECOVERY'


				IF	-- REDGATE SYNTAX
				@Extension = '.sqt'
				BEGIN
					SET @CMD = '-SQL "'+@CMD+'"'
					PRINT '   -- ' + REPLACE(@CMD,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
					RAISERROR('',-1,-1) WITH NOWAIT
					EXECUTE master..sqlbackup @CMD, @errorcode OUT, @sqlerrorcode OUT;
					IF (@errorcode >= 500) OR (@sqlerrorcode <> 0)
						RAISERROR ('Redgate Restore on %s failed with exit code: %d  SQL error code: %d', 16, 1, @DBName, @errorcode, @sqlerrorcode)
				END
				ELSE	-- MICROSOFT SYNTAX
				BEGIN
					PRINT '   -- ' + REPLACE(@CMD,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
					RAISERROR('',-1,-1) WITH NOWAIT
					EXEC(@CMD)
				END
			END
			RAISERROR('',-1,-1) WITH NOWAIT

		END
		FETCH NEXT FROM RestoreDBCursor INTO @RestoreOrder,@DateModified,@FileName, @Extension
	END


	CLOSE RestoreDBCursor
	DEALLOCATE RestoreDBCursor


	RAISERROR('  -- Done with DB Restore''s',-1,-1) WITH NOWAIT

	NoRestore:


	IF @TestCopyOnly = 0
	BEGIN
		RAISERROR('  -- Start Mirroring Configuration',-1,-1) WITH NOWAIT


		-- STOP MIRRORING PARTNER AT PRIMARY
		IF EXISTS(select * From [DYN_DBA_RMT].master.sys.database_mirroring T1 JOIN [DYN_DBA_RMT].master.sys.databases T2 ON T1.database_id = T2.database_id WHERE T2.name = @DBName AND T1.mirroring_partner_name IS NOT NULL)
		BEGIN
			SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER OFF'
			RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
			EXEC (@CMD) AT [DYN_DBA_RMT]
		END

		-- SET MIRRORING PARTNER AT MIRROR
		SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER = ''TCP://'+@Remote_FQDN+':'+CAST(@RemoteEndpointPort AS VarChar(10))+''''
		RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
		EXEC (@CMD)

		-- SET MIRRORING PARTNER AT PRIMARY
		SET @CMD = 'ALTER DATABASE ['+@DBName+'] SET PARTNER = ''TCP://'+@Local_FQDN+':'+CAST(@LocalEndpointPort AS VarChar(10))+''''
		RAISERROR('    -- %s',-1,-1,@CMD) WITH NOWAIT
		EXEC (@CMD) AT [DYN_DBA_RMT]


		RAISERROR('  -- Done with Mirroring Configuration',-1,-1) WITH NOWAIT


	-- ENABLE LOG BACKUPS ON PRIMARY NOW THAT MIRRORING IS DONE
	SET @CMD = 'EXEC msdb.dbo.sp_update_job @job_name=N''MAINT - TranLog Backup'', @enabled=1'
	EXEC (@CMD)  AT [DYN_DBA_RMT]


	END
	ELSE RAISERROR('  -- Mirroring Configuration Skipped',-1,-1) WITH NOWAIT


	---- REMOVE DYNAMIC LINKED SERVER
	--IF  EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'DYN_DBA_RMT')
	--	EXEC master.dbo.sp_dropserver @server=N'DYN_DBA_RMT', @droplogins='droplogins'
GO
GRANT EXECUTE ON  [dbo].[dbasp_Mirror_Database] TO [public]
GO
