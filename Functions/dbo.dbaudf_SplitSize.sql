SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_SplitSize] (@String varchar(max),@Size INT = 8000)

RETURNS @Array TABLE	(
			PartNumber	INT		IDENTITY(1,1)
			,Part		varchar(8000)
			)
AS
BEGIN

    DECLARE	@Index     INT

	IF @Size < 1 SET @Size = 1
	IF @Size > 8000 SET @Size = 8000

    --loop through source string and add elements to destination table array
    WHILE LEN(@String) > 0
    BEGIN
	IF LEN(@String) > @Size
		SET @Index = @Size
	ELSE
		SET @Index = LEN(@String)

	INSERT	@Array
	SELECT	SUBSTRING(@String, 1, @Index)

	SET @String = STUFF(@String,1,@Index,'')
    END

    RETURN
END
GO
