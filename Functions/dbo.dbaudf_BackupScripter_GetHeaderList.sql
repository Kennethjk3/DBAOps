SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_BackupScripter_GetHeaderList]
		(
		@SetSize		INT
		,@FileName		VarChar(MAX)
		,@FullPathName		VarChar(MAX)
		)

RETURNS TABLE AS RETURN
(

	SELECT		*
			,@FileName [BackupFileName]
	FROM		[DBAOps].[dbo].[dbaudf_RestoreHeader](@FullPathName)

)
GO
