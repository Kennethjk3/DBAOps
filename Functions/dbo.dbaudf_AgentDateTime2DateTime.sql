SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_AgentDateTime2DateTime](@date int, @time int)
  RETURNS datetime
AS
/*****************************************************************************
** File:  dbaudf_AgentDateTime2DateTime.sql
** Name:  dbaudf_AgentDateTime2DateTime
** Desc:  function to convert SQL Agent based date/times (ex:stored in sysjobhistory table) to datetime data type
**        The format for @date is like 20030122, and for @time is like 93358.
**        These values would produce "2003-01-22 09:33:58"
**        Note: if date format is not like yyyymmdd, the function will error out with convertion error
**
** Dependancies:
**
** Processing Steps:
**
** Restart:
**
** Author:  Steve Ledridge
** Date:    05/20/2010
******************************************************************************
**       CHANGE HISTORY
******************************************************************************
** Date       Author        Description
** --------   -----------   ---------------------------------------------------
**
******************************************************************************/
BEGIN
  DECLARE @DateTime datetime

  IF @date<0 or @time<0 RETURN NULL
  IF @date = 0
    SET @DateTime = 0 -- 1900-00-00
  ELSE
    SET @DateTime = convert(datetime,convert(char(8),@date))

  --add seconds
  SET @DateTime = dateadd(ss,@time%100,@DateTime)

  --divide by 100 to get rid of seconds, then add minutes
  SET @time = @time/100
  SET @DateTime = dateadd(mi,@time%100,@DateTime)

  --divide by 100 yet again to get rid of minutes, then add hours
  SET @time = @time/100
  SET @DateTime = dateadd(hh,@time%100,@DateTime)

  RETURN @DateTime
END
GO
