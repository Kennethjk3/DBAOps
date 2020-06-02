SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_SplitByLines] ( @String VARCHAR(max))
returns @SplittedValues TABLE
(
    OccurenceId INT IDENTITY(1,1),
    SplitValue VARCHAR(max)
)
as
BEGIN

	DECLARE	@SplitLength	INT
			,@SplitValue	Varchar(max)
			,@CRLF			Char(2)

	SELECT	@CRLF		= CHAR(13)+CHAR(10)
			,@String	= REPLACE(REPLACE(REPLACE(@String,@CRLF,CHAR(13)),CHAR(10),CHAR(13)),CHAR(13),@CRLF) + @CRLF

	WHILE LEN(@String) > 0

	BEGIN
		SELECT		@SplitLength	= COALESCE(NULLIF(CHARINDEX(@CRLF,@String),0)-1,LEN(@String))
					,@SplitValue	= LEFT(@String,@SplitLength)
					,@String	= STUFF(@String,1,@SplitLength+2,'')

		INSERT INTO	@SplittedValues([SplitValue])
		SELECT		@SplitValue
	END

	RETURN

END
GO
