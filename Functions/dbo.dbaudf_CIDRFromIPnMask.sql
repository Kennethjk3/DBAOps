SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_CIDRFromIPnMask] (@IP varchar(15),@Mask varchar(15))
RETURNS VARCHAR(20)
AS
BEGIN
	DECLARE @IPCalc	BIGINT
     DECLARE @maskCalc	BIGINT

     SELECT	@IPCalc		= dbo.dbaudf_IPAddressToInteger(@Mask) & dbo.dbaudf_IPAddressToInteger(@IP)
			,@maskCalc	= dbo.dbaudf_IPAddressToInteger('255.255.255.255') - dbo.dbaudf_IPAddressToInteger(@mask) + 1

     DECLARE @logCalc int
     SELECT @logCalc = (32 - (LOG(@maskCalc)/LOG(2)))

     RETURN  [dbo].[dbaudf_IntegerToIPAddress](@IPCalc) +  '/' + CAST(@logCalc AS VARCHAR(5))

END
GO
