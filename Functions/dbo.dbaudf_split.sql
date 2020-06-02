SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_split] ( @String VARCHAR(200), @Delimiter VARCHAR(5))
returns @SplittedValues TABLE
(
    OccurenceId SMALLINT IDENTITY(1,1),
    SplitValue VARCHAR(200)
)
/**************************************************************
 **  User Defined Function dbaudf_split
 **  Written by Steve Ledridge, Virtuoso
 **  May 12, 2009
 **
 **  This dbaudf is set up parse a delimited string return values
 **  in tabular format.
 **
 ***************************************************************/
as

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	05/13/2009	Steve Ledridge		New process
--
--	======================================================================================

/***
declare @String VARCHAR(200)
declare @Delimiter VARCHAR(5)

set @String = 'abc def ghi'
set @Delimiter = ' '

--***/

BEGIN

    DECLARE @SplitLength INT

    WHILE LEN(@String) > 0

	BEGIN

	    SELECT @SplitLength = (CASE CHARINDEX(@Delimiter,@String) WHEN 0 THEN
			           LEN(@String) ELSE CHARINDEX(@Delimiter,@String) -1 END)

	    INSERT INTO @SplittedValues
	    SELECT SUBSTRING(@String,1,@SplitLength)

	    SELECT @String = (CASE (LEN(@String) - @SplitLength) WHEN 0 THEN ''
			      ELSE RIGHT(@String, LEN(@String) - @SplitLength - 1) END)
	END

    RETURN

END
GO
