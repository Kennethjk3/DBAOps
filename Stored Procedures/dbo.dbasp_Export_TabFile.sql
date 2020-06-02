SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_Export_TabFile] (@sqlcmd [nvarchar] (max), @filename [nvarchar] (max), @includeheaders [bit], @quoteall [bit], @provideoutput [bit])
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.StoredProcedures].[dbasp_Export_TabFile]
GO
