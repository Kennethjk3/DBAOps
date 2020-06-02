SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetDBMaint]
		(
		@DBName	SYSNAME
		,@Value	BIT
		)
AS
BEGIN
	DECLARE	@Maint	DateTime
	DECLARE	@MaintTxt	VarChar(50)
	DECLARE	@CMD		VarChar(8000)
	DECLARE	@Results	Table	(
							[objtype]		varchar(128)	NULL
							,[objname]	sysname		NULL
							,[name]		sysname
							,[value]		sql_variant	NULL
							)
	SET NOCOUNT ON
	SET @CMD = 'SELECT * FROM ['+@DBName+'].sys.fn_listextendedproperty(default, default, default, default, default, default, default)'


	INSERT INTO @Results
	EXEC (@CMD)


	SELECT	@Maint		= CAST([value] AS DateTime)
			,@MaintTxt	= Convert(VarChar(50),[value],108)
	FROM		@Results
	WHERE	[objtype] IS NULL
		AND	[objname] IS NULL
		AND	[name] = 'Maint'


	IF @Maint IS NOT NULL
		RAISERROR('Database %s was in maintenance since %s',-1,-1,@DBName,@MaintTxt) WITH NOWAIT


	IF @Value = 1
	BEGIN


		IF @Maint IS NULL
			SET @CMD = 'DECLARE @NOW DATETIME = GETDATE();EXEC ['+@DBName+'].sys.sp_addextendedproperty @name=N''Maint'', @value=@Now'
		ELSE
			SET @CMD = 'DECLARE @NOW DATETIME = GETDATE();EXEC ['+@DBName+'].sys.sp_updateextendedproperty @name=N''Maint'', @value=@Now'

		EXEC(@CMD)
		RAISERROR('Database %s is now in maintenance',-1,-1,@DBName) WITH NOWAIT
	END
	ELSE
	BEGIN


		IF @Maint IS NULL
			SET @CMD = NULL
		ELSE
			SET @CMD = 'EXEC ['+@DBName+'].sys.sp_dropextendedproperty @name=N''Maint'''

		EXEC(@CMD)
		RAISERROR('Database %s is now not in maintenance',-1,-1,@DBName) WITH NOWAIT
	END
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_SetDBMaint] TO [public]
GO
