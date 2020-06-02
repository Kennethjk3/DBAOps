SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetTempCubeName](@TempCubeName sysname = NULL)
AS
BEGIN

	DECLARE	@cEModule						sysname					= 'dbasp_SetTempCubeName'
			,@cECategory					sysname
			,@cEEvent						sysname
			,@cEGUID						UniqueIdentifier		= NEWID()
			,@cEMessage						nvarchar(max)
			,@cERE_ForceScreen				BIT
			,@cERE_Severity					INT
			,@cERE_State					INT
			,@cERE_With						VarChar(2048)
			,@cEStat_Rows					BigInt
			,@cEStat_Duration				FLOAT
			,@cEMethod_Screen				Bit						= 0
			,@cEMethod_TableLocal			Bit						= 1
			,@cEMethod_TableCentral			BIT
			,@cEMethod_RaiseError			BIT
			,@cEMethod_Twitter				BIT


	IF NULLIF(@TempCubeName,'') IS NULL		-- Clear Properties because Deployment is Completed 
	BEGIN

		SELECT		 @cECategory	= 'Clear Extended Property'
					,@cEEvent		= 'TempCubeName'
					,@cEMessage		= [dbo].[dbaudf_GetTempCubeName]()

		EXEC [dbo].[dbasp_LogEvent]	 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen=@cEMethod_Screen
									,@cEMethod_TableLocal=@cEMethod_TableLocal


		IF EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'TempCubeName', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_dropextendedproperty @name=N'TempCubeName'


		RAISERROR('Removed TempCubeName Extended Properties',-1,-1) WITH NOWAIT

	END
	ELSE
	BEGIN

		IF NOT EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'TempCubeName', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_addextendedproperty		@name=N'TempCubeName'	,@value=@TempCubeName
		ELSE
			EXEC dbo.sp_updateextendedproperty	@name=N'TempCubeName'	,@value=@TempCubeName
		
		RAISERROR('SET TempCubeName Extended Property to "%s"',-1,-1,@TempCubeName) WITH NOWAIT

		SELECT		 @cECategory	= 'SET Extended Property'
					,@cEEvent		= 'TempCubeName'
					,@cEMessage		= @TempCubeName

		EXEC [dbo].[dbasp_LogEvent]	 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen=@cEMethod_Screen
									,@cEMethod_TableLocal=@cEMethod_TableLocal
	END
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_SetTempCubeName] TO [public]
GO
