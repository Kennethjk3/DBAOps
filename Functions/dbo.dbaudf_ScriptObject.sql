SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_ScriptObject] (@ObjectName [nvarchar] (max), @drop [bit], @create [bit], @alter [bit], @data [bit], @OutputFilename [nvarchar] (max), @append [bit], @ForceCrLf [bit], @HeaderScript [nvarchar] (max), @FooterScript [nvarchar] (max), @dropIfDiff [bit])
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_ScriptObject]
GO
