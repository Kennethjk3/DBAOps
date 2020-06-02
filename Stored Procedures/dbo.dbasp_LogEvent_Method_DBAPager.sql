SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_DBAPager]
	(
	 @cEModule			sysname				=null
	,@cECategory		sysname				=null
	,@cEEvent			NVarchar(max)		=null
	,@cEGUID			UniqueIdentifier	=null
	,@cEMessage			NVarchar(max)		=null
	,@cEPage_Subject	VarChar(2048)		=null
	,@cEPage_To			Varchar(2048)		=null
	)
AS
BEGIN
	/*
	When using the email endpoint, the resulting behavior of the VictorOps platform will depend on the use of predefined keywords in the subject line of the email as follows: 

	CRITICAL		- This keyword will open a new incident, thus triggering whatever escalation policy has been configured for the team receiving the incident. The patterns recognized are "critical" and "problem".
	WARNING			- This keyword will add an entry to the timeline, and can either create a new incident or simply show visually based on your configuration at Settings >> Alert Behavior >> Configure Incidents. The patterns recognized are "warn" and "warning".
	INFO			- This keyword will post an informational event in the timeline, without creating an incident. (Nobody gets paged). The patterns recognized are "info", "informational" and "information".
	ACKNOWLEDGEMENT - This keyword, though rarely used, will acknowledge an incident. The platform will stop paging users. The patterns recognized are "acked", "acknowledge", "acknowledgement" and "acknowledged".
	RECOVERY		- Either of these keywords will resolve an open incident. The platform will stop paging users.  (It is not necessary for an incident to be acknowledged before it can be resolved). The patterns recognized are "resolved", "recovered", "recovery", "ok", and "closed".

	Use one of the Values at the End of the subject line with square brackets around it or you won't get the results you expect.   ex. [CRITICAL]
	*/

	SET	@cEPage_To	= 'd92eba86-b96f-4385-afec-bf612877688a+'+COALESCE(@cEPage_To,'db')+'@alert.victorops.com' -- USE VictorOps RoutingKey. NULL Defaults to "db"

	SET	@cEMessage	= 'Module:   ' + @cEModule +CHAR(13)+CHAR(10)
					+ 'Category: ' + @cECategory +CHAR(13)+CHAR(10)
					+ 'Event:    ' + @cEEvent +CHAR(13)+CHAR(10)
					+ 'GUID:     ' + CAST(@cEGUID AS VarChar(50)) +CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
					+ @cEMessage


	EXEC [dbo].[dbasp_sendmail]
	   @recipients			= @cEPage_To
	  ,@subject				= @cEPage_Subject
	  ,@message				= @cEMessage


	RETURN 0
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_DBAPager] TO [public]
GO
