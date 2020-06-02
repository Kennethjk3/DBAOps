SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_PrintLarge]
	(
	@LargeTextToPrint nvarchar(max)
	)
AS
BEGIN
	DECLARE @TextLine nvarchar(max)


	DECLARE PrintLargeResults CURSOR
	FOR
	-- SELECT QUERY FOR CURSOR
	SELECT SplitValue
	FROM DBAOps.dbo.dbaudf_SplitByLines(@LargeTextToPrint)
	ORDER BY OccurenceID


	OPEN PrintLargeResults;
	FETCH PrintLargeResults INTO @TextLine;
	WHILE (@@fetch_status <> -1)
	BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
	----------------------------
	---------------------------- CURSOR LOOP TOP


	PRINT @TextLine


	---------------------------- CURSOR LOOP BOTTOM
	----------------------------
	END
	FETCH NEXT FROM PrintLargeResults INTO @TextLine;
	END
	CLOSE PrintLargeResults;
	DEALLOCATE PrintLargeResults;
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_PrintLarge] TO [public]
GO
