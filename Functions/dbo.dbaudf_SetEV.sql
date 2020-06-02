SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_SetEV] (@EVname [nvarchar] (max), @EVvalue [nvarchar] (max))
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_SetEV]
GO
