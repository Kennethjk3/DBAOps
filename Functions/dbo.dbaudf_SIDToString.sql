SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_SIDToString]
(
  @BinSID AS VARBINARY(8000)
)
RETURNS VARCHAR(8000)
AS BEGIN

  IF LEN(@BinSID) % 4 <> 0 RETURN(NULL)

  DECLARE @StringSID VARCHAR(100)
  DECLARE @i AS INT
  DECLARE @j AS INT

  SELECT @StringSID = 'S-'
     + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@BinSID, 1, 1))))
  SELECT @StringSID = @StringSID + '-'
     + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@BinSID, 3, 6))))

  SET @j = 9
  SET @i = LEN(@BinSID)

  WHILE @j < @i
  BEGIN
    DECLARE @val BINARY(4)
    SELECT @val = SUBSTRING(@BinSID, @j, 4)
    SELECT @StringSID = @StringSID + '-'
      + CONVERT(VARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(CONVERT(VARBINARY, @val)))))
    SET @j = @j + 4
  END
  RETURN ( @StringSID )
END
GO
