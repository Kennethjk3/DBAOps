SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_StringToTable_Pairs]	(
													@TargetString varchar(max),    -- Full String of Values to be split up
													@RecDelimiter varchar(10),        -- Delimiter for each record
													@ColDelimiter varchar(10)        -- Delimiter for Each Field in a record
													)
    RETURNS @Results    TABLE	(
								PairNumber    Int not null,
								Label        VarChar(1000) not null,
								Value        varchar(7000) null
								)
AS
BEGIN
    /***
Function to extract items into a set of values
Example....
SELECT * FROM StringToTable_Pairs( 'T:0,D:1,E:0,DW:0', ',', ':' )
Returns: PairNumber Label Value
-------------- -------------- ------------------------------------
1 T 0
2 D 1
3 E 0
4 DW 0
****/
    DECLARE        @PairNumber		Int				-- Current Pair in String To Process
    DECLARE        @Label			VarChar(max)	-- The First Half of a Pair
    DECLARE        @Value			VarChar(max)	-- The Seccond Half of a Pair

    SET        @TargetString    = COALESCE(@TargetString,'')    -- Resolves Errors with NULL Strings
    SET        @PairNumber		= 1								-- Start at the First Pair

        WHILE 1=1    -- A Trick to Keep Looping till a BREAK
        BEGIN

        Select    @Label = DBAOps.dbo.dbaudf_ReturnPart(RTRIM(LTRIM(REPLACE(DBAOps.dbo.dbaudf_ReturnPart(RTRIM(LTRIM(REPLACE(@TargetString,@RecDelimiter,'|'))),@PairNumber),@ColDelimiter,'|'))),1)
        Select    @Value = DBAOps.dbo.dbaudf_ReturnPart(RTRIM(LTRIM(REPLACE(DBAOps.dbo.dbaudf_ReturnPart(RTRIM(LTRIM(REPLACE(@TargetString,@RecDelimiter,'|'))),@PairNumber),@ColDelimiter,'|'))),2)

        IF (COALESCE(@Label,'') = '') AND (COALESCE(@Value,'') = '') BREAK    -- At The End

        INSERT INTO	@Results            -- Add the Record to the Results
        SELECT		@PairNumber
					,@Label
					,@Value

        SET @PairNumber = @PairNumber + 1        -- Set up for the Next Set

        END
    RETURN
END
GO
