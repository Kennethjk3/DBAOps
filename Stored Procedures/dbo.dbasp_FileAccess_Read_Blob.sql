SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_FileAccess_Read_Blob] (@FullFileName [nvarchar] (max), @FileText [nvarchar] (max) OUTPUT)
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_FileAccess_Read_Blob]
GO
