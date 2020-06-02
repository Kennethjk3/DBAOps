SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_File]
	(
	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null
	,@cEFile_Name		VarChar(2048)		=null
	,@cEFile_Path		VarChar(2048)		=null
	,@cEFile_OverWrite	BIT			=null

	)
AS
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.


BEGIN
	DECLARE @append bit

	SELECT	@cEFile_Path = @cEFile_Path + @cEFile_Name
		,@append = case @cEFile_OverWrite  WHEN 1 then 0 else 1 end


	EXEC [dbo].[dbasp_FileAccess_Write] @cEMessage,@cEFile_Path,@append,1


	RETURN 0
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_File] TO [public]
GO
