SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[clr_http_request] (@requestMethod [nvarchar] (max), @url [nvarchar] (max), @parameters [nvarchar] (max), @headers [nvarchar] (max), @timeout [int], @autoDecompress [bit], @convertResponseToBas64 [bit])
RETURNS [xml]
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[UserDefinedFunctions].[clr_http_request]
GO
