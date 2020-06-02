SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_FormatNumber]
	(
	@Value float
	,@RightAlignSize INT
	,@DecimalPlaces INT
	)
RETURNS varchar(50)
AS
BEGIN
	/*********************************************************
	 **  Function dbaudf_FormatNumber
	 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
	 **  June 24, 2010
	 **
	 **  This function is used to format numeric values it a text output
	 **  by adding commas and right justifying.
	 **
	 ***************************************************************/

	--	======================================================================================
	--	Revision History
	--	Date		Author     		Desc
	--	==========	====================	=============================================
	--	06/24/2010	Steve Ledridge		New process
	--	======================================================================================

	/*
	EXAMPLE USAGE:


	DECLARE	@value Float
	SET	@value = '12345.3456'

	SELECT	[dbo].[dbaudf_FormatNumber](@value,20,2)
	GO

	*/

	SET @Value = ROUND(@Value,@DecimalPlaces)

	DECLARE @FormatNumber varchar(50)
	DECLARE @Pointer INT

	SET @FormatNumber = CONVERT(varchar(50), CAST(ABS(@Value) AS money), 1)
	SET @Pointer = CHARINDEX('.',@FormatNumber)
	if @pointer = 0
	BEGIN
		SET @pointer = len(@FormatNumber) + 1
		SET @FormatNumber = @FormatNumber + '.'
	END

	SET @FormatNumber = @FormatNumber + REPLICATE('0', @DecimalPlaces )


	SET @FormatNumber = CASE
				WHEN @DecimalPlaces = 0
				THEN LEFT(@FormatNumber, @Pointer - 1 )
				ELSE LEFT(@FormatNumber, @Pointer + @DecimalPlaces )
				END

	IF SIGN(@Value) = -1
		SET @FormatNumber = '(' + @FormatNumber + ')'

	if @RightAlignSize < @Pointer + @DecimalPlaces
		SET @RightAlignSize = @Pointer + @DecimalPlaces

	RETURN RIGHT(REPLICATE(' ', @RightAlignSize)+@FormatNumber,@RightAlignSize)
END
GO
