SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_GetEV] (@EVname [nvarchar] (max))
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_GetEV]
GO
