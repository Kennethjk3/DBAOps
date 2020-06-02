SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_max_datetime] (@dt1 datetime, @dt2 datetime)
 Returns datetime
As
BEGIN
   Declare @ret datetime

   If @dt1 Is NULL Set @dt1=0
   If @dt2 Is NULL Set @dt2=0

   If @dt1>=@dt2 Set @ret=@dt1
   Else Set @ret=@dt2

   Return @ret
END
GO
