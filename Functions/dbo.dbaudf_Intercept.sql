SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE AGGREGATE [dbo].[dbaudf_Intercept] (@value [nvarchar] (max))
RETURNS [float]
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.dbaudf_Intercept]
GO
