SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_FilterCharacters]
						(
						@myString			varchar(500)
						,@Chars				varchar(100)
						,@ValidOrInvalid	CHAR(1)			= 'I'
						,@ReplaceWith		CHAR(1)			= ''
						,@Compact			bit				= 1
						)
Returns varchar(500) AS
BEGIN
	DECLARE @LoopProtecter INT
	SET		@LoopProtecter =0

	SET		@Chars = REPLACE(@Chars,'[','[[')							-- FIX ESCAPE CHARACTER

	IF @ValidOrInvalid = 'I'
	BEGIN
		SET @Chars = REPLACE(@Chars,@ReplaceWith,'')					-- MAKE SURE REPLACEMENT CHARACTER IS NOT AN INVALID CHARACTER

		IF LEN(@Chars) != LEN(REPLACE(@Chars,' ',''))					-- IF YOU ARE FILTERING SPACES
			SET	@myString = REPLACE(@myString,' ',@ReplaceWith)			-- REMOVE SPACES FROM STRING

		SET	@Chars = REPLACE(REPLACE(@Chars,' ',''),@ReplaceWith,'')	-- REMOVE SPACE AND REPLACEMENT CHARCTER FROM FILTER CHARACTERS
	END
	ELSE
	BEGIN
		IF LEN(@Chars) = LEN(REPLACE(@Chars,@ReplaceWith,''))			-- IF REPLACEMENT CHARACTER IS IN VALID CHARACTER STRING
			SET @Chars = @Chars + @ReplaceWith
	END

	SET		@Chars = '%['+ CASE @ValidOrInvalid WHEN 'V' THEN '^' ELSE '' END + @Chars + ']%'

	While	@myString like @Chars AND @LoopProtecter < 100
	BEGIN
		Select @myString = REPLACE(@myString,substring(@myString,patindex(@Chars,@myString),1),@ReplaceWith)
		WHILE @Compact = 1 AND @myString LIKE '%['+@ReplaceWith+@ReplaceWith+']%' AND @LoopProtecter < 100
		BEGIN
			SET @myString =  REPLACE(@myString,@ReplaceWith+@ReplaceWith,@ReplaceWith)
			SET @LoopProtecter = @LoopProtecter + 1
		END
		SET @LoopProtecter = @LoopProtecter + 1
	END

	IF @Compact = 1
	BEGIN
		SET @myString = STUFF(@myString,1,1,isnull(nullif(LEFT(@myString,1),@ReplaceWith),''))					-- STRIP OFF LEADING  REPLACEMENT CHARACTER
		SET @myString = STUFF(@myString,LEN(@myString),1,isnull(nullif(RIGHT(@myString,1),@ReplaceWith),''))	-- STRIP OFF TRAILING REPLACEMENT CHARACTER
	END

	RETURN @myString
END
GO
