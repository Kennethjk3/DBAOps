SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_TableLocal]
	(
	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null
	,@cEStat_Rows		BigInt			=null
	,@cEStat_Duration	FLOAT			=null
	)
AS
BEGIN
	INSERT INTO	[dbo].[EventLog] (cEModule,cECategory,cEEvent,cEGUID,cEMessage,cEStat_Rows,cEStat_Duration)
	SELECT		@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEStat_Rows
			,@cEStat_Duration
	If @@ROWCOUNT = 1
		RETURN 0
	ELSE
		RETURN -1
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_TableLocal] TO [public]
GO
