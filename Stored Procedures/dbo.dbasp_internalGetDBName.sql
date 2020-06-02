SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_internalGetDBName]

/**************************************************************
 **  Stored Procedure dbasp_internalGetDBName
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 25, 2008
 **
 **  Returns the database names from dbo.DBA_DBInfo
 **  table.
 **
 ***************************************************************/
  as
BEGIN


	SET NOCOUNT ON;
	SELECT
		DBName
	FROM dbo.DBA_DBInfo
	GROUP BY DBName
	ORDER BY DBName
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_internalGetDBName] TO [public]
GO
