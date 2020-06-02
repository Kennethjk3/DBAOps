SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_IPAddress2BigInt]
(
    @Ipaddress NVARCHAR(15) -- should be in the form '123.123.123.123'
)
RETURNS BIGINT
AS
BEGIN
 DECLARE @part1 AS NVARCHAR(3)
 DECLARE @part2 AS NVARCHAR(3)
 DECLARE @part3 AS NVARCHAR(3)
 DECLARE @part4 AS NVARCHAR(3)

 SELECT	@part1	= PARSENAME(@Ipaddress,4)
		,@part2	= PARSENAME(@Ipaddress,3)
		,@part3	= PARSENAME(@Ipaddress,2)
		,@part4	= PARSENAME(@Ipaddress,1)

 DECLARE @ipAsBigInt AS BIGINT
 SELECT @ipAsBigInt =
    (16777216 * (CAST(@part1 AS BIGINT)))
    + (65536 * (CAST(@part2 AS BIGINT)))
    + (256 * (CAST(@part3 AS BIGINT)))
    + (CAST(@part4 AS BIGINT))

 RETURN @ipAsBigInt

END
GO
