SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetDeplInstID](@DeplBuildID SYSNAME = NULL, @DeplInstID sysname = NULL)
AS
BEGIN

	DECLARE	@cEModule						sysname					= 'dbasp_SetDeplInstID'
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


	IF @DeplBuildID IS NULL		-- Clear Properties because Deployment is Completed 
	BEGIN

		SELECT		 @cECategory	= 'Clear Extended Property'
					,@cEEvent		= 'DeplInstID'
					,@cEMessage		= [dbo].[dbaudf_GetDeplInstID]()

		EXEC [dbo].[dbasp_LogEvent]	 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen=@cEMethod_Screen
									,@cEMethod_TableLocal=@cEMethod_TableLocal

		SELECT		 @cECategory	= 'Clear Extended Property'
					,@cEEvent		= 'DeplBuildID'
					,@cEMessage		= [dbo].[dbaudf_GetDeplBuildID]()

		EXEC [dbo].[dbasp_LogEvent]	 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen=@cEMethod_Screen
									,@cEMethod_TableLocal=@cEMethod_TableLocal

		IF EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'DeplInstID', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_dropextendedproperty @name=N'DeplInstID'

		IF EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'DeplBuildID', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_dropextendedproperty @name=N'DeplBuildID'

		RAISERROR('Removed DeplInstID & DeplBuildID Extended Properties',-1,-1) WITH NOWAIT

	END
	ELSE
	BEGIN
		SET @DeplInstID = COALESCE(@DeplInstID,NEWID()) -- USE NEW VALUE IF ONE ISNT SPECIFIED 

		IF NOT EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'DeplInstID', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_addextendedproperty		@name=N'DeplInstID'	,@value=@DeplInstID
		ELSE
			EXEC dbo.sp_updateextendedproperty	@name=N'DeplInstID'	,@value=@DeplInstID
		
		RAISERROR('SET DeplInstID Extended Property to "%s"',-1,-1,@DeplInstID) WITH NOWAIT

		SELECT		 @cECategory	= 'SET Extended Property'
					,@cEEvent		= 'DeplInstID'
					,@cEMessage		= @DeplInstID

		EXEC [dbo].[dbasp_LogEvent]	 @cEModule
									,@cECategory
									,@cEEvent
									,@cEGUID
									,@cEMessage
									,@cEMethod_Screen=@cEMethod_Screen
									,@cEMethod_TableLocal=@cEMethod_TableLocal

		IF NOT EXISTS (SELECT Value FROM ::fn_listextendedproperty(N'DeplBuildID', NULL, NULL, NULL, NULL, NULL, NULL))
			EXEC dbo.sp_addextendedproperty		@name=N'DeplBuildID'	,@value=@DeplBuildID
		ELSE
			EXEC dbo.sp_updateextendedproperty	@name=N'DeplBuildID'	,@value=@DeplBuildID

		RAISERROR('SET DeplBuildID Extended Property to "%s"',-1,-1,@DeplBuildID) WITH NOWAIT

		SELECT		 @cECategory	= 'SET Extended Property'
					,@cEEvent		= 'DeplBuildID'
					,@cEMessage		= @DeplBuildID

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
GRANT EXECUTE ON  [dbo].[dbasp_SetDeplInstID] TO [public]
GO
