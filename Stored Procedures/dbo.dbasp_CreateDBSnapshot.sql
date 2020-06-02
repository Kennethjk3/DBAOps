SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CreateDBSnapshot]
	(
	@DBName				SYSNAME
	,@SnapName			SYSNAME
	,@SnapShotPath			VARCHAR(60)	= NULL	-- IF NULL, USE ORIGIONAL DB PATH
	,@ReplaceExisting		BIT		= 0	-- 1 IS NEEDED TO REPLACE EXISTING SNAPSHOT
	)
WITH EXECUTE AS SELF
AS
/*


	EXEC DBAOps.dbo.dbasp_CreateDBSnapshot 'MirrorTest','MirrorTest_Snapshot',NULL,1


*/
BEGIN


	DECLARE		@TSQL			VARCHAR(8000)
			,@OldSnapName		VARCHAR(50)
			,@drop			VARCHAR(200)
			,@create		VARCHAR(500)
			,@path			VARCHAR(400)
			,@path2			VARCHAR(60)

	IF @ReplaceExisting =0 AND DB_ID(@SnapName) IS NOT NULL
	BEGIN
		RAISERROR ('Database %s already exists, Use @ReplaceExisting=1 to Replace Database with New Snapshot' ,16,1,@SnapName)
		RETURN -1
	END

	IF @ReplaceExisting =1 AND DB_ID(@SnapName) IS NOT NULL
	BEGIN
		EXEC DBAOps.dbo.dbasp_KillAllOnDB @SnapName
		SET @TSQL = 'DROP DATABASE [' + @SnapName + ']'

		RAISERROR('    -- %s',-1,-1,@tsql) WITH NOWAIT
		EXEC (@TSQL)

		IF DB_ID(@SnapName) IS NULL
			RAISERROR('      -- Success.',-1,-1) WITH NOWAIT
		ELSE
			RAISERROR('      -- Failure.',-1,-1) WITH NOWAIT
	END


	SET		@TSQL	= 'CREATE DATABASE ' + QUOTENAME(@SnapName) + CHAR(13) + CHAR(10)
				+ 'ON' + CHAR(13) + CHAR(10)


 	;WITH		DBFiles
 			AS
 			(
 			--DECLARE @DBName SYSNAME,@SnapName VarChar(8000),@SnapShotPath VarChar(8000);SELECT @DBName = '${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM',@SnapName='${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM_Daily',@SnapShotPath='C:\';
			 SELECT		name
					,DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','DirectoryName')+'\' OldPath
					,COALESCE(@SnapShotPath, DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','DirectoryName')+'\') NewPath
					,DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Name') OldFile
					,@SnapName+'_'+REPLACE(REPLACE(DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Name'),'.mdf','.ss'),'.ndf','.ss') NewFile
			 FROM		sys.master_files
			 WHERE		data_space_id <> 0
				AND	is_sparse = 0
				AND	database_id = DB_ID(@DBName)
				AND	DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'File','Exists') = 'True'
			)


	SELECT		@TSQL = @TSQL + '    ,( NAME=[' + name + '],FILENAME=''' + NewPath + NewFile + ''')'+ CHAR(13) + CHAR(10)
	FROM		DBFiles


	SET		@TSQL	= REPLACE(@TSQL,'ON'+CHAR(13)+CHAR(10)+'    ,( NAME','ON'+CHAR(13)+CHAR(10)+'    ( NAME')
				+ 'AS SNAPSHOT OF ' + QUOTENAME(@DBName)

	RAISERROR('    -- Creating Mirror %s From Database %s',-1,-1,@SnapName,@DBName) WITH NOWAIT
	--Print '   -- ' + REPLACE(@TSQL,CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)+'   -- ')
	EXEC (@TSQL)


	IF DB_ID(@SnapName) IS NOT NULL
		RAISERROR('      -- Success.',-1,-1) WITH NOWAIT
	ELSE
		RAISERROR('      -- Failure.',-1,-1) WITH NOWAIT

 END
GO
GRANT EXECUTE ON  [dbo].[dbasp_CreateDBSnapshot] TO [public]
GO
