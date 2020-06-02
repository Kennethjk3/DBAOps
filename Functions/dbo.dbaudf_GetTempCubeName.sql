SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetTempCubeName]()
		RETURNS sysname
		AS
		BEGIN
			DECLARE @TempCubeName sysname

			SELECT		@TempCubeName = TRY_CAST(Value AS sysname)
			FROM		sys.fn_listextendedproperty('TempCubeName', default, default, default, default, default, default) 

			RETURN COALESCE(@TempCubeName,N'Undefined') -- this is a generic value so that it doesnt return a NULL
		END
GO
