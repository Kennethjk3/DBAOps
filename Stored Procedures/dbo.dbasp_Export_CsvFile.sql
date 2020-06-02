SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_Export_CsvFile] (@sqlcmd [nvarchar] (max), @filename [nvarchar] (max), @includeheaders [bit], @quoteall [bit], @provideoutput [bit])
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_Export_CsvFile]
GO
