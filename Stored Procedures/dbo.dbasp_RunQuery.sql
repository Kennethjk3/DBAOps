SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_RunQuery] (@Name [nvarchar] (max), @Query [nvarchar] (max), @ServerName [nvarchar] (max), @DBName [nvarchar] (max), @Login [nvarchar] (max), @Password [nvarchar] (max), @outputfile [nvarchar] (max), @OutputText [nvarchar] (max))
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.StoredProcedures].[dbasp_RunQuery]
GO
