SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FormatString] (@format [nvarchar] (max), @var01 [nvarchar] (max), @var02 [nvarchar] (max), @var03 [nvarchar] (max), @var04 [nvarchar] (max), @var05 [nvarchar] (max), @var06 [nvarchar] (max), @var07 [nvarchar] (max), @var08 [nvarchar] (max), @var09 [nvarchar] (max), @var10 [nvarchar] (max))
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_FormatString]
GO
