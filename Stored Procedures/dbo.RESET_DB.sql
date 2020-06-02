SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[RESET_DB]
	(
	@DBName VarChar(50)
	,@DoBackup Bit   = 0
	,@BreakMirror Bit  = 1
	,@MakeDailySnapshot bit	 = 1
	)
AS
BEGIN
	DECLARE @RC int
	DECLARE @db_nm varchar(50)
	DECLARE @TSQL VarChar(MAX)


	SET @db_nm   =  'Daily_' + @DBName
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @db_nm)
	BEGIN
	EXECUTE @RC = [dbo].p_KillProcessesOnDB
	   @db_nm
	SET @TSQL = 'DROP DATABASE ' + @db_nm
	EXEC (@TSQL)
	END


	SET @db_nm   =  'Hourly_' + @DBName
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @db_nm)
	BEGIN
	EXECUTE @RC = [dbo].p_KillProcessesOnDB
	   @db_nm
	SET @TSQL = 'DROP DATABASE ' + @db_nm
	EXEC (@TSQL)
	END


	SET @db_nm   =  @DBName
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @db_nm)
	BEGIN
		EXECUTE @RC = [dbo].p_KillProcessesOnDB @db_nm

		IF EXISTS(SELECT * FROM sys.database_mirroring WHERE Mirroring_guid IS Not NULL AND  DB_NAME(database_id) = @db_nm)
			EXEC dbo.BreakMirroring_DB @db_nm


		SET @TSQL = 'DROP DATABASE ' + @db_nm
		EXEC (@TSQL)
	END


	EXEC dbo.StartMirroring_DB @db_nm, @DoBackup


	If @BreakMirror = 1
		EXEC dbo.BreakMirroring_DB @db_nm


	IF @MakeDailySnapshot = 1
		EXEC dbo.CreateSnapshot @db_nm, 'Daily_'
END
GO
GRANT EXECUTE ON  [dbo].[RESET_DB] TO [public]
GO
