SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FileAccess_Write] (@InputText [nvarchar] (max), @path [nvarchar] (max), @append [bit], @ForceCrLf [bit])
RETURNS [bit]
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_FileAccess_Write]
GO
