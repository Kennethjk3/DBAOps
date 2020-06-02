SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_getShareUNC](@ShareName VarChar(255))
returns VarChar(2000)
as
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/26/2013	Steve Ledridge		Found on DBA01.
--	04/29/2015	Steve Ledridge		Changed Results to All Uppercase
--	11/20/2017	Steve Ledridge		Modified for ${{secrets.COMPANY_NAME}}

BEGIN
	DECLARE @PathName VarChar(2000)

	SELECT TOP 1 @PathName = '\\'+UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN())+'\'+[ShareName]
	FROM [dbo].[dbaudf_ListShares]()
	where ShareName Like '%'+@ShareName+'%'
	RETURN @PathName
END
GO
