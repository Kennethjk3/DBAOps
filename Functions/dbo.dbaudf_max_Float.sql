SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_max_Float] (@Value1 Float(53), @Value2 Float(53))
 Returns FLOAT
As
BEGIN
	DECLARE @ret Float(53)

   If isnull(@Value1,0)>=isnull(@Value2,0)
	Set @ret=@Value1
   Else
    Set @ret=@Value2

   Return @ret
END
GO
