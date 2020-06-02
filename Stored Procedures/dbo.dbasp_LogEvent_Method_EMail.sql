SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_EMail]
	(
	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null
	,@cEMail_Subject	VarChar(2048)		=null
	,@cEMail_To		VarChar(2048)		=null
	,@cEMail_CC		VarChar(2048)		=null
	,@cEMail_BCC		VarChar(2048)		=null
	,@cEMail_Urgent		BIT			=null

	)
AS
BEGIN


	SET	@cEMessage	= 'Module:   ' + @cEModule +CHAR(13)+CHAR(10)
				+ 'Category: ' + @cECategory +CHAR(13)+CHAR(10)
				+ 'Event:    ' + @cEEvent +CHAR(13)+CHAR(10)
				+ 'GUID:     ' + CAST(@cEGUID AS VarChar(50)) +CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
				+ @cEMessage


	EXEC [dbo].[dbasp_sendmail]
	   @recipients			= @cEMail_To
	  ,@copy_recipients		= @cEMail_CC
	  ,@blind_copy_recipients	= @cEMail_BCC
	  ,@subject			= @cEMail_Subject
	  ,@message			= @cEMessage


	RETURN 0
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_EMail] TO [public]
GO
