SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_FileCompare] (@file1 [nvarchar] (max), @file2 [nvarchar] (max))
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.StoredProcedures].[dbasp_FileCompare]
GO
