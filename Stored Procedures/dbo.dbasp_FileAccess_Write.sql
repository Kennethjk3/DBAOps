SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_FileAccess_Write] (@InputText [nvarchar] (max), @path [nvarchar] (max), @append [bit], @ForceCrLf [bit])
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_FileAccess_Write]
GO
