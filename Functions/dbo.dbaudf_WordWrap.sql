SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_WordWrap]	(
										@WordWrap			Varchar(MAX)
										,@MaxLen			int
										,@Separators		varchar(255)	= ' '
										,@LineTerminator	varchar(255)	= NULL
										)

RETURNS varchar(MAX) -- The result string wrapped.
/*
* This function word wraps a nvarchar string at a given
* length. There can be several word separating characters.
* Space is always added as a separator.
*
*
* Common Usage:
	select dbo.dbaudf_WordWrap (REPLICATE ('12345 ', 200)
				  , 58, N' ', NULL) as [Wrapped Text]
	select dbo.dbaudf_WordWrap ('123457890', 4, N' ', NULL)


****************************************************************/
AS BEGIN
	DECLARE @Pointer			INT
	DECLARE @Output			VarChar(max) = ''
	DECLARE @Line				VarChar(max)

	SET @LineTerminator = ISNULL(@LineTerminator,CHAR(13)+CHAR(10))

	DECLARE WordWrapCursor CURSOR
	FOR
	-- SELECT QUERY FOR CURSOR
	SELECT	SplitValue
	FROM		dbo.dbaudf_SplitByLines	(@WordWrap)
	ORDER BY	OccurenceId

	OPEN WordWrapCursor;
	FETCH WordWrapCursor INTO @Line;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			----------------------------
			---------------------------- CURSOR LOOP TOP

			WHILE LEN(@Line) > @MaxLen
			BEGIN -- SPLIT THE LINE

				SET @Pointer = LEN(@Line)-CHARINDEX(@Separators,REVERSE(@Line),LEN(@Line)-@MaxLen)
				IF @Pointer >0 AND @Pointer <= @MaxLen
				BEGIN
					--SELECT @Pointer
					SET @Output = @Output + LEFT(@Line,@Pointer) +@LineTerminator
					SET @Line = STUFF(@Line,1,(@Pointer)+1,'')
				END
				ELSE
				BEGIN
					SET @Pointer = CHARINDEX(@Separators,@Line+@Separators)
					SET @Output = @Output + LEFT(@Line,@Pointer-1) +@LineTerminator
					SET @Line = STUFF(@Line+@Separators,1,@Pointer,'')
					--SELECT @Pointer
				END

				--SELECT @Line
			END
			SET @Output = @Output + @Line+@LineTerminator

			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM WordWrapCursor INTO @Line;
	END
	CLOSE WordWrapCursor;
	DEALLOCATE WordWrapCursor;

	--exec DBAOps.dbo.dbasp_printLarge @Output
	RETURN @Output
End -- Function
GO
