SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE   FUNCTION [dbo].[dbaudf_TimeTable]
    (
    @StartDateTime	DateTime
    ,@EndDateTime	DateTime
    ,@Interval		sysname
    ,@IntervalCount	Int
    )
RETURNS @TimeTable TABLE(DateTimeValue DATETIME NOT NULL)
AS
BEGIN
    DECLARE @DateTime	DateTime
    SELECT	@DateTime	= @StartDateTime
    WHILE	@DateTime  <= @EndDateTime
    BEGIN
        INSERT INTO @TimeTable (DateTimeValue)
        SELECT		@DateTime

        SET @DateTime = CASE @Interval
							WHEN 'year'			THEN Dateadd(year			,@IntervalCount, @DateTime)
							WHEN 'quarter'		THEN Dateadd(quarter		,@IntervalCount, @DateTime)
							WHEN 'month'		THEN Dateadd(month			,@IntervalCount, @DateTime)
							WHEN 'dayofyear'	THEN Dateadd(dayofyear		,@IntervalCount, @DateTime)
							WHEN 'day'			THEN Dateadd(day			,@IntervalCount, @DateTime)
							WHEN 'week'			THEN Dateadd(week			,@IntervalCount, @DateTime)
							WHEN 'weekday'		THEN Dateadd(weekday		,@IntervalCount, @DateTime)
							WHEN 'hour'			THEN Dateadd(hour			,@IntervalCount, @DateTime)
							WHEN 'minute'		THEN Dateadd(minute			,@IntervalCount, @DateTime)
							WHEN 'second'		THEN Dateadd(second			,@IntervalCount, @DateTime)
							WHEN 'millisecond'	THEN Dateadd(millisecond	,@IntervalCount, @DateTime)
							--WHEN 'microsecond'	THEN Dateadd(microsecond	,@IntervalCount, @DateTime)
							--WHEN 'nanosecond'	THEN Dateadd(nanosecond		,@IntervalCount, @DateTime)
							ELSE @DateTime + @IntervalCount
							END
    END
    RETURN
END
GO
