SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_NumberTable]
    (
    @StartNumber Int,
    @EndNumber Int,
    @Interval Int
    )
RETURNS @dbaudf_NumberTable TABLE (Number int)
AS
BEGIN
    DECLARE @Number TinyInt
    Set    @Number = @StartNumber
    WHILE @Number <= @EndNumber
    BEGIN
        INSERT INTO @dbaudf_NumberTable SELECT @Number
        SET @Number = @Number + @Interval
    END
    RETURN
END
GO
