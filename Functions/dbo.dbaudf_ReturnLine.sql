SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_ReturnLine]
    (@String VarChar(MAX),
     @LineNumber int)
RETURNS VarChar(8000)
AS
BEGIN
If    @LineNumber < 1
    Return ''
IF CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1) = 0
    BEGIN
        IF @LineNumber = 1
            RETURN @String
        ELSE
            Return ''
    END
SET    @String = LTRIM(RTRIM(@String))
IF      @String = ''
        RETURN ''
IF @LineNumber = 1
        RETURN SUBSTRING(@String, 1, CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1) - 1)
WHILE @LineNumber > 1
    BEGIN
        IF CHARINDEX(CHAR(13)+CHAR(10), @String, 1) = 0
            Return ''
          SET @String = SUBSTRING(@String,  CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1) + 2, LEN(@String) - CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1))
        SET @LineNumber = @LineNumber - 1
    END
IF CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1) = 0
    RETURN @String
RETURN SUBSTRING(@String, 1, CHARINDEX(CHAR(13)+CHAR(10), @String+CHAR(13)+CHAR(10), 1) - 1)
END
GO
