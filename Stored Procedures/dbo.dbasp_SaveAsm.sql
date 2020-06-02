SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_SaveAsm] (@asmname [nvarchar] (max), @filename [nvarchar] (max), @savefile [nvarchar] (max))
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_SaveAsm]
GO
