SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_internalGetEnviroInfoByApp]
				 (@appl sysname)
/**************************************************************
 **  Stored Procedure dbasp_internalGetEnviroInfoByApp
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 25, 2008
 **
 **  Returns the baseline folder, SQL Instance,
 **  database name and environment by Application.
 **
 ***************************************************************/
  as
BEGIN


	SET NOCOUNT ON;
	SELECT
		DISTINCT
		 'BaseLineFolder'=
		CASE BaseLineFolder
			WHEN '  ' THEN 'No BaseLineFolder'
			ELSE BaseLineFolder
        END,
		BaseLineServerName,
		SQLName,
	    ENVnum
	FROM dbo.DBA_DBInfo
	WHERE Appl_desc = @appl
      AND BaseLineFolder <> ' '
	ORDER BY ENVnum
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_internalGetEnviroInfoByApp] TO [public]
GO
