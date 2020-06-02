SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE AGGREGATE [dbo].[dbaudf_RSquared] (@value [nvarchar] (max))
RETURNS [float]
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.dbaudf_RSquared]
GO
