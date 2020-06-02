SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_IntegerToIPAddress] (@IP AS bigint)
RETURNS varchar(15)
AS
BEGIN
 DECLARE @Octet1 bigint
 DECLARE @Octet2 tinyint
 DECLARE @Octet3 tinyint
 DECLARE @Octet4 tinyint
 DECLARE @RestOfIP bigint

 SET @Octet1 = @IP / 16777216
 SET @RestOfIP = @IP - (@Octet1 * 16777216)
 SET @Octet2 = @RestOfIP / 65536
 SET @RestOfIP = @RestOfIP - (@Octet2 * 65536)
 SET @Octet3 = @RestOfIP / 256
 SET @Octet4 = @RestOfIP - (@Octet3 * 256)

 RETURN(CONVERT(varchar, @Octet1) + '.' +
        CONVERT(varchar, @Octet2) + '.' +
        CONVERT(varchar, @Octet3) + '.' +
        CONVERT(varchar, @Octet4))
END
GO
