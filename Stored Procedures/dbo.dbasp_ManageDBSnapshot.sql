SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ManageDBSnapshot]
	(
	@DBName				SYSNAME
	,@SnapName			SYSNAME
	,@SnapShotPath			VARCHAR(2000)	= NULL	-- IF NULL, USE ORIGINAL DB PATH
	,@CreateNew			BIT		= 0	-- 1 IS NEEDED TO CREATE SNAPSHOT
	,@DropExisting			BIT		= 0	-- 1 IS NEEDED TO DROP EXISTING SNAPSHOT IF IT EXISTS
	)
WITH EXECUTE AS SELF
AS
SET NOCOUNT ON
--	======================================================================================
--	Stored Procedure dbasp_ManageDBSnapshot
--	Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
--	June 17, 2014
--
--	This procedure was created to allow the DW team to create and drop
--	DB Snapshots at will and timed within thier ETL Processes.
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	06/17/2014	Steve Ledridge		New process (Branched from dbasp_CreateDBSnapshot).
--						Process was improved while adding "Drop Only" functionality
--						and "Sparse File" cleanup. Parameter change was significant
--						enough to cause a new sproc rather than modif
--	======================================================================================
--	RETURN CODES
--	======================================================================================
--		 0		SUCCESS
--		-1		BAD DATABASE NAME
--		-2		SNAPSHOT EXISTS AND @DropExisting WAS NOT SPECIFIED
--		-3		FAILURE TO DROP SNAPSHOT
--		-4		FAILURE TO DELETE ORPHANED SPARSE FILES
--		-5		FAILURE TO CREATE SNAPSHOT
--	======================================================================================
--	======================================================================================
--	EXAMPLES
--	======================================================================================
/*
	-- CREATE IF ONE DOES NOT ALREADY EXIST
		EXEC DBAOps.dbo.dbasp_ManageDBSnapshot 'MirrorTest','MirrorTest_Snapshot',NULL,1,0


	-- CREATE AND REPLACE IF EXISTING
		EXEC DBAOps.dbo.dbasp_ManageDBSnapshot 'MirrorTest','MirrorTest_Snapshot',NULL,1,1


	-- ONLY DROP IF EXISTING
		EXEC DBAOps.dbo.dbasp_ManageDBSnapshot 'MirrorTest','MirrorTest_Snapshot',NULL,0,1


	-- ONLY REPORT FILES
		EXEC DBAOps.dbo.dbasp_ManageDBSnapshot 'MirrorTest','MirrorTest_Snapshot',NULL,0,0
		or
		EXEC DBAOps.dbo.dbasp_ManageDBSnapshot 'MirrorTest','MirrorTest_Snapshot'
*/
--	======================================================================================
BEGIN


	DECLARE		@TSQL			VARCHAR(8000)
			,@OldSnapName		VARCHAR(50)
			,@drop			VARCHAR(200)
			,@create		VARCHAR(500)
			,@path			VARCHAR(400)
			,@path2			VARCHAR(60)
			,@Data			XML

	DECLARE		@DBFiles		TABLE
			(
			name		SYSNAME	 PRIMARY KEY
			,OldPath	VarChar(MAX)
			,NewPath	VarChar(MAX)
			,OldFile	VarChar(MAX)
			,NewFile	VarChar(MAX)
			,NewExists	VarChar(MAX)
			)


	IF DB_ID(@DBName) IS NULL
	BEGIN
		RAISERROR ('    -- Database %s does NOT exists, No Snapshot can be Managed.' ,16,1,@DBName)
		RETURN -1
	END


	INSERT INTO	@DBFiles
	SELECT		name
			,DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','DirectoryName')+'\' OldPath
			,COALESCE(@SnapShotPath, DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','DirectoryName')+'\') NewPath
			,DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Name') OldFile
			,@SnapName+'_'+REPLACE(REPLACE(DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Name'),'.mdf','.ss'),'.ndf','.ss') NewFile
			,DBAOps.dbo.dbaudf_GetFileProperty(COALESCE(@SnapShotPath, DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','DirectoryName')+'\')+@SnapName+'_'+REPLACE(REPLACE(DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Name'),'.mdf','.ss'),'.ndf','.ss'),'File','Exists') NewExists
	FROM		sys.master_files
	WHERE		data_space_id <> 0
		AND	is_sparse = 0
		AND	database_id = DB_ID(@DBName)
		AND	DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Exists') = 'True'


	IF @CreateNew = 0 AND @DropExisting = 0
	BEGIN
		SELECT * FROM @DBFiles
		RETURN 0
	END


	IF @CreateNew = 1 AND @DropExisting = 0 AND DB_ID(@SnapName) IS NOT NULL
	BEGIN
		RAISERROR ('    -- Database %s already exists, Use @DropExisting = 1 to Replace Database with New Snapshot' ,16,1,@SnapName)
		RETURN -2
	END


	-----------------------------------------------------------
	-----------------------------------------------------------
	--		DROP EXISTING SNAPSHOT
	-----------------------------------------------------------
	-----------------------------------------------------------


	IF @DropExisting = 1
	BEGIN
		IF DB_ID(@SnapName) IS NULL
			RAISERROR ('    -- Database %s does NOT exists, Skipping Drop Steps' ,-1,-1,@SnapName)
		ELSE
		BEGIN
			EXEC DBAOps.dbo.dbasp_KillAllOnDB @SnapName
			SET @TSQL = 'DROP DATABASE [' + @SnapName + ']'

			RAISERROR('    -- %s',-1,-1,@tsql) WITH NOWAIT
			--Print '   -- ' + REPLACE(@TSQL,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
			EXEC (@TSQL)

			IF DB_ID(@SnapName) IS NULL
				RAISERROR('      -- Success Dropping Snapshot.',-1,-1) WITH NOWAIT
			ELSE
			BEGIN
				RAISERROR('      -- Failure Dropping Snapshot.',16,1) WITH NOWAIT
				RETURN -3
			END
		END
	END


	-- UPDATE EXISTING FILES AFTER DROP
	UPDATE		@DBFiles
		SET	NewExists = DBAOps.dbo.dbaudf_GetFileProperty(NewPath+NewFile,'File','Exists')


	-----------------------------------------------------------
	-----------------------------------------------------------
	--		CLEANUP EXISTING SPARCE FILES
	-----------------------------------------------------------
	-----------------------------------------------------------


	IF EXISTS (SELECT * FROM @DBFiles WHERE NewExists = 'True')
	BEGIN
		RAISERROR('    -- Orphaned Sparse Files still exist for %s.',-1,-1,@SnapName) WITH NOWAIT


		;WITH		Settings
				AS
				(
				SELECT		32		AS [QueueMax]		-- Max Number of files coppied at once.
						,'false'	AS [ForceOverwrite]	-- true,false
						,1		AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
						,300		AS [UpdateInterval]	-- rate of progress updates in Seconds
				)
				,DeleteFile
				AS
				(
				SELECT		NewPath+NewFile [Source]
				FROM		@DBFiles
				WHERE		NewExists = 'True'
				)
		SELECT		@Data =	(
					SELECT		*
							,(SELECT * FROM DeleteFile FOR XML RAW ('DeleteFile'), TYPE)
					FROM		Settings
					FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
					)


		RAISERROR('    -- Deleting Orphaned Sparse Files for %s.',-1,-1,@SnapName) WITH NOWAIT
		--SELECT @Data
		exec dbasp_FileHandler @Data


		-- UPDATE EXISTING FILES AFTER DELETE
		UPDATE		@DBFiles
			SET	NewExists = DBAOps.dbo.dbaudf_GetFileProperty(NewPath+NewFile,'File','Exists')


		IF NOT EXISTS (SELECT * FROM @DBFiles WHERE NewExists = 'True')
			RAISERROR('      -- Success Deleting Sparse Files.',-1,-1) WITH NOWAIT
		ELSE
		BEGIN
			RAISERROR('      -- Failure Deleting Sparse Files.',16,1) WITH NOWAIT
			RETURN -4
		END
	 END
	 ELSE
		RAISERROR('    -- No Orphaned Sparse Files exist for %s.',-1,-1,@SnapName) WITH NOWAIT


	-----------------------------------------------------------
	-----------------------------------------------------------
	--		CREATE SNAPSHOT SCRIPT
	-----------------------------------------------------------
	-----------------------------------------------------------


	IF @CreateNew = 1
	BEGIN


		SET		@TSQL	= 'CREATE DATABASE ' + @SnapName + CHAR(13) + CHAR(10)
					+ 'ON' + CHAR(13) + CHAR(10)


		SELECT		@TSQL = @TSQL + '    ,( NAME=[' + name + '],FILENAME=''' + NewPath + NewFile + ''')'+ CHAR(13) + CHAR(10)
		FROM		@DBFiles


		SET		@TSQL	= REPLACE(@TSQL,'ON'+CHAR(13)+CHAR(10)+'    ,( NAME','ON'+CHAR(13)+CHAR(10)+'    ( NAME')
					+ 'AS SNAPSHOT OF ' + @DBName

		RAISERROR('    -- Creating Mirror %s From Database %s',-1,-1,@SnapName,@DBName) WITH NOWAIT
		--Print '   -- ' + REPLACE(@TSQL,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
		EXEC (@TSQL)


		IF DB_ID(@SnapName) IS NOT NULL
			RAISERROR('      -- Success Creating Snapshot.',-1,-1) WITH NOWAIT
		ELSE
		BEGIN
			RAISERROR('      -- Failure Creating Snapshot.',16,1) WITH NOWAIT
			RETURN -5
		END
	 END
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_ManageDBSnapshot] TO [public]
GO
