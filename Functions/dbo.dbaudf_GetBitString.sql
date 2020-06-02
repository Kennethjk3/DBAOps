SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetBitString]
(
	  @IntValue Int
	, @BitSize tinyInt --1 to 32
)
RETURNS varchar(32)
AS
BEGIN
	DECLARE @BitNum tinyint, @BitString varchar(32)

	IF @BitSize>32 SET @BitSize=32

	SELECT @BitNum=1, @BitString=''

	WHILE @BitNum<=@BitSize
	Begin
		SELECT @BitString=
			Cast( (convert(bigint,(@IntValue/power(cast(2 as bigint),@BitNum-1))) % 2)  as char(1))
			-- Cast(  dbo.fn_GetBit(@IntValue ,@BitNum)  as char(1))
			+@BitString
		SELECT @BitNum=@BitNum+1
	End

	RETURN @BitString

END
GO
