SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_internalGetEnviroByDB]
				 (@db sysname)
/**************************************************************
 **  Stored Procedure dbasp_internalGetEnviroByDB
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 25, 2008
 **
 **  Returns the SQL Instance, database name and
 **  Environment by database.
 **
 ***************************************************************/
  as
BEGIN


	SET NOCOUNT ON;

	  SELECT
		SQLNAME,
		Envnum,
        'BaseLineFolder'=
		CASE BaseLineFolder
			WHEN '  ' THEN 'No BaseLineFolder'
			ELSE BaseLineFolder
        END,
		BaselineServerName
	FROM dbo.DBA_DBInfo
	WHERE DBNAme = @db
	ORDER BY Envnum

END
GO
GRANT EXECUTE ON  [dbo].[dbasp_internalGetEnviroByDB] TO [public]
GO
