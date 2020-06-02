SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE   FUNCTION [dbo].[dbaudf_ReturnPart]
    (@String VarChar(MAX),
     @WordNumber int)
RETURNS VarChar(MAX)
AS
BEGIN
If    @WordNumber < 1
    Return ''
IF CHARINDEX('|', @String, 1) = 0
    BEGIN
        IF @WordNumber = 1
            RETURN @String
        ELSE
            Return ''
    END
SET    @String = LTRIM(RTRIM(@String))
IF      @String = ''
        RETURN ''
IF @WordNumber = 1
        RETURN SUBSTRING(@String, 1, CHARINDEX('|', @String, 1) - 1)
WHILE @WordNumber > 1
    BEGIN
        IF CHARINDEX('|', @String, 1) = 0
            Return ''
          SET @String = SUBSTRING(@String,  CHARINDEX('|', @String, 1) + 1, LEN(@String) - CHARINDEX('|', @String, 1))
        SET @WordNumber = @WordNumber - 1
    END
IF CHARINDEX('|', @String, 1) = 0
    RETURN @String
RETURN SUBSTRING(@String, 1, CHARINDEX('|', @String, 1) - 1)
END
GO
