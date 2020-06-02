SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_TimeDimension]
    (
    @StartDateTime	DateTime
    ,@EndDateTime	DateTime
    ,@Interval		sysname
    ,@IntervalCount	Int
    )
RETURNS TABLE
AS RETURN
(
	SELECT		ROW_NUMBER() OVER(ORDER BY [DateTimeValue])		AS [Period]
				,CONVERT(bigint,REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VarChar(50),[DateTimeValue],121),' ',''),':',''),'-',''),'.',''))	AS TimeKey
				,[DateTimeValue]
				,DATEPART(year,[DateTimeValue])					AS DatePart_year
				,DATEPART(quarter,[DateTimeValue])				AS DatePart_quarter
				,DATEPART(month,[DateTimeValue])				AS DatePart_month
				,DATEPART(dayofyear,[DateTimeValue])			AS DatePart_dayofyear
				,DATEPART(day,[DateTimeValue])					AS DatePart_day
				,DATEPART(week,[DateTimeValue])					AS DatePart_week
				,DATEPART(weekday,[DateTimeValue])				AS DatePart_weekday
				,DATEPART(hour,[DateTimeValue])					AS DatePart_hour
				,DATEPART(minute,[DateTimeValue])				AS DatePart_minute
				,DATEPART(second,[DateTimeValue])				AS DatePart_second
				,DATEPART(millisecond,[DateTimeValue])			AS DatePart_millisecond
				--,DATEPART(microsecond,[DateTimeValue])			AS DatePart_microsecond
				--,DATEPART(nanosecond,[DateTimeValue])			AS DatePart_nanosecond
				--,DATEPART(ISO_WEEK,[DateTimeValue])				AS DatePart_ISO_WEEK
				,DATENAME(year,[DateTimeValue])					AS DateName_year
				,DATENAME(quarter,[DateTimeValue])				AS DateName_quarter
				,DATENAME(month,[DateTimeValue])				AS DateName_month
				,DATENAME(dayofyear,[DateTimeValue])			AS DateName_dayofyear
				,DATENAME(day,[DateTimeValue])					AS DateName_day
				,DATENAME(week,[DateTimeValue])					AS DateName_week
				,DATENAME(weekday,[DateTimeValue])				AS DateName_weekday
				,DATENAME(hour,[DateTimeValue])					AS DateName_hour
				,DATENAME(minute,[DateTimeValue])				AS DateName_minute
				,DATENAME(second,[DateTimeValue])				AS DateName_second
				,DATENAME(millisecond,[DateTimeValue])			AS DateName_millisecond
				--,DATENAME(microsecond,[DateTimeValue])			AS DateName_microsecond
				--,DATENAME(nanosecond,[DateTimeValue])			AS DateName_nanosecond
	FROM		DBAOps.dbo.dbaudf_TimeTable(@StartDateTime,@EndDateTime,@Interval,@IntervalCount)
)
GO
