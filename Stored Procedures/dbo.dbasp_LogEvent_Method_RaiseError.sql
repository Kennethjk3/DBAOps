SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_RaiseError]
	(
	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null
	,@cERE_Severity		INT			=null
	,@cERE_State		INT			=null
	,@cERE_With		VarChar(2048)		=null
	)
AS
BEGIN
	DECLARE @TSQL VarChar(8000)

	SET @TSQL = 'RAISERROR (' + QUOTENAME(@cEMessage,'''') +', ' + CAST(@cERE_Severity AS VarChar(20)) + ', ' + CAST(@cERE_State AS VarChar(20)) + ') ' + COALESCE(@cERE_With,'')
	EXEC (@TSQL)


	RETURN 0
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_RaiseError] TO [public]
GO
