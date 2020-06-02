SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE AGGREGATE [dbo].[dbaudf_ConcatenateUnique] (@Value [nvarchar] (max))
RETURNS [nvarchar] (max)
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.dbaudf_ConcatenateUnique]
GO
