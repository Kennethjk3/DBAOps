SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FormatXML2String] (@Input [xml])
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_FormatXML2String]
GO
