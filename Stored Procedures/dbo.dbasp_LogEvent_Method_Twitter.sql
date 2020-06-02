SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_Twitter]
	(
	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null
	)
AS
BEGIN
	-- MAKE SURE THERE IS A TIMESTAMP IN THE MESSAGE SO IT DOESNT THINK THEY ARE DUPES.
	--TWITTER WILL DENY DUPES
	SET @cEMessage = LEFT(@cEModule+CHAR(10)
			+ CONVERT(nvarchar(50),GETUTCDATE(),120)+CHAR(10)
			+ @cECategory+CHAR(10)
			+ @cEEvent+CHAR(10)
			+ COALESCE(@cEMessage,''),140)


	EXECUTE [dbo].[dbasp_SendTweet]
		   @TwitterUser = 'TSSQLDBA'
		  ,@TwitterPass = 'L84Lunch'
		  ,@message = @cEMessage


	RETURN 0
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_Twitter] TO [public]
GO
