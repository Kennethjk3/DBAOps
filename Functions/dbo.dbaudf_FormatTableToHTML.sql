SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FormatTableToHTML] (@TableName [nvarchar] (max), @HTMLTableName [nvarchar] (max), @Title [nvarchar] (max), @Summary [nvarchar] (max), @HTMLStyle [int], @IncludeHeaders [bit])
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_FormatTableToHTML]
GO
