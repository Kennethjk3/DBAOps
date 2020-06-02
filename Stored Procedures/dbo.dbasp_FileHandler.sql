SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_FileHandler] (@data [xml])
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_FileHandler]
GO
