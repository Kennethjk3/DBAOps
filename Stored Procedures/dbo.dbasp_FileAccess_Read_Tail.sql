SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_FileAccess_Read_Tail] (@FullFileName [nvarchar] (max), @bytes [int], @FileText [nvarchar] (max) OUTPUT)
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.StoredProcedures].[dbasp_FileAccess_Read_Tail]
GO
