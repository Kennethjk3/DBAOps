SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Print]
	(
	@Text			VarChar(max)
	,@NestLevel		INT				= 0 -- ADDS ADITIONAL "  " (TWO SPACES) MULTIPLIED BY THIS VALUE TO BEGINING OF EACH LINE
	,@ScriptSafe	BIT				= 1 -- ADDS a "-- " AT THE BEGINNING OF SONGLE LINES OR WRAPS WITH "/* " & " */" IF MULTIPLE LINES
	,@Force			BIT				= 0 -- PRINTS EVEN IF EnableCodeComments IS CURRENTLY OFF
	)
AS
BEGIN
	DECLARE @ECC BIT, @ExtProp_chk sql_variant, @ExtProp sysname, @ExtProp_val sql_variant,@CRLF CHAR(2), @NestString VarChar(100)
	SELECT	@CRLF = CHAR(13) + CHAR(10)
			,@NestString = COALESCE(REPLICATE('  ',@NestLevel),'')
	-- GET EnableCodeComments FROM DATABASE
	SELECT	@ExtProp_chk = NULL, @ExtProp = 'EnableCodeComments', @ExtProp_val = '0' --USE AS DEFAULT VALUE IF CREATING PARAMETER
	SELECT	@ExtProp_chk = Value FROM sys.fn_listextendedproperty(@ExtProp, default, default, default, default, default, default)
	IF @@ROWCOUNT = 0 EXEC sys.sp_addextendedproperty @name=@ExtProp, @value=@ExtProp_val
	SELECT	@ECC = COALESCE(CAST(@ExtProp_chk AS bit),0)


	SET @Text = CASE @ScriptSafe WHEN 1 THEN @NestString + '-- ' ELSE @NestString END + REPLACE(@Text,@CRLF,CASE @ScriptSafe WHEN 1 THEN @CRLF + @NestString + '-- ' ELSE @CRLF + @NestString END)

	IF @ECC = 1 OR @Force = 1 --ONLY PRINT IF COMMENTS ARE ON OR FORCED TO
		RAISERROR (@Text,-1,-1) WITH NOWAIT
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_Print] TO [public]
GO
