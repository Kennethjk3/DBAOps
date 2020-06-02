SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_Query] (@Query [nvarchar] (max))
RETURNS TABLE (
[RowNumber] [int] NULL,
[col_01] [sql_variant] NULL,
[col_02] [sql_variant] NULL,
[col_03] [sql_variant] NULL,
[col_04] [sql_variant] NULL,
[col_05] [sql_variant] NULL,
[col_06] [sql_variant] NULL,
[col_07] [sql_variant] NULL,
[col_08] [sql_variant] NULL,
[col_09] [sql_variant] NULL,
[col_10] [sql_variant] NULL,
[col_11] [sql_variant] NULL,
[col_12] [sql_variant] NULL,
[col_13] [sql_variant] NULL,
[col_14] [sql_variant] NULL,
[col_15] [sql_variant] NULL,
[col_16] [sql_variant] NULL,
[col_17] [sql_variant] NULL,
[col_18] [sql_variant] NULL,
[col_19] [sql_variant] NULL,
[col_20] [sql_variant] NULL,
[col_21] [sql_variant] NULL,
[col_22] [sql_variant] NULL,
[col_23] [sql_variant] NULL,
[col_24] [sql_variant] NULL,
[col_25] [sql_variant] NULL,
[col_26] [sql_variant] NULL,
[col_27] [sql_variant] NULL,
[col_28] [sql_variant] NULL,
[col_29] [sql_variant] NULL,
[col_30] [sql_variant] NULL,
[col_31] [sql_variant] NULL,
[col_32] [sql_variant] NULL,
[col_33] [sql_variant] NULL,
[col_34] [sql_variant] NULL,
[col_35] [sql_variant] NULL,
[col_36] [sql_variant] NULL,
[col_37] [sql_variant] NULL,
[col_38] [sql_variant] NULL,
[col_39] [sql_variant] NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_Query]
GO
