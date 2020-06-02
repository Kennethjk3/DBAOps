SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[CreateSnapshot]
	(
	 @DBName			VarChar(1000)
	,@SnapshotPrefix	VarChar(100)	= 'Snap_'
	)
AS
BEGIN


	DECLARE		@NewDBName			VarChar(1000)
				,@LogicalName		VarChar(1000)
				,@LogLogicalName	VarChar(1000)
				,@DataFileName		VarChar(4000)
				,@LogFileName		VarChar(4000)
				,@SnapFileName		VarChar(4000)
				,@TSQL				VarChar(MAX)


	select	@LogicalName = [name]
			,@DataFileName = REPLACE(physical_name,@DBName,@SnapshotPrefix + @DBName)
			,@SnapFileName = REPLACE(physical_name,'.mdf','_' + LEFT(@SnapshotPrefix,(LEN(@SnapshotPrefix)-1)) + '.ss')
			,@NewDBName = @SnapshotPrefix + @DBName
	from	sys.master_files
	where	database_id = DB_ID(@DBName)
		AND	[type] = 0


	select	@LogLogicalName = [name]
			,@LogFileName = REPLACE(physical_name,@DBName,@SnapshotPrefix + @DBName)
	from	sys.master_files
	where	database_id = DB_ID(@DBName)
		AND	[type] = 1


	IF EXISTS (SELECT * FROM sys.databases where name =	 @NewDBName)
	BEGIN
		SET @TSQL = 'DROP DATABASE [' + @NewDBName + ']'
		EXEC(@TSQL)
	END


	SET @TSQL = 'CREATE DATABASE [' + @NewDBName + '] ON ( NAME = ''' + @LogicalName + ''', FILENAME = '''
		+ @SnapFileName + ''') AS SNAPSHOT OF [' + @DBName + ']'
	EXEC (@TSQL)
Done:


END
GO
GRANT EXECUTE ON  [dbo].[CreateSnapshot] TO [public]
GO
