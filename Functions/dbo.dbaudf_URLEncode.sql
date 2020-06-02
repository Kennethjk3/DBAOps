SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_URLEncode]
	(@decodedString VARCHAR(max))
RETURNS VARCHAR(max)
AS
BEGIN
/*******************************************************************************************************
*   dbo.dbaudf_URLEncode
*   Creator:       Steve Ledridge
*   Date:          06/20/2012
*
*   Notes:
*
*
*   Usage:
        select dbo.URLEncode('K8%/fwO3L mEQ*.}')
*   Modifications:
*   Developer Name      Date        Brief description
*   ------------------- ----------- ------------------------------------------------------------
*
********************************************************************************************************/

DECLARE @encodedString VARCHAR(max)

IF @decodedString LIKE '%[^a-zA-Z0-9*-.!_]%' ESCAPE '!'
BEGIN
    SELECT @encodedString = REPLACE(
                                    COALESCE(@encodedString, @decodedString),
                                    SUBSTRING(@decodedString,number,1),
                                    '%' + SUBSTRING(master.dbo.fn_varbintohexstr(CONVERT(VARBINARY(1),ASCII(SUBSTRING(@decodedString,number,1)))),3,3))
     FROM		DBAOps.dbo.NumberTable(1,LEN(@decodedString),1)
    WHERE		SUBSTRING(@decodedString,Number,1) like '[^a-zA-Z0-9*-.!_]' ESCAPE '!'
END
ELSE
BEGIN
	SELECT @encodedString = @decodedString
END

RETURN @encodedString

END
GO
