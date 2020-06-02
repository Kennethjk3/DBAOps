SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetDBMaint]
(
    @DBName SYSNAME
)
RETURNS BIT
AS
BEGIN
	DECLARE	@Value	BIT
	DECLARE	@Maint	DateTime
	DECLARE	@MaintTxt	VarChar(50)
	DECLARE	@CMD		VarChar(8000)

	SET @CMD = 'SELECT CAST([value] AS DateTime) [Maint] FROM ['+@DBName+'].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE [objtype] IS NULL AND [objname] IS NULL AND [name] = ''Maint'''

	select @MaintTxt = DBAOps.dbo.dbaudf_execute_tsql(@CMD) OPTION (RECOMPILE);

	IF @MaintTxt IS NOT NULL
	BEGIN
		SET @Value = 1
	END
	ELSE
	BEGIN
		SET @Value = 0
	END

    RETURN @Value
END
GO
