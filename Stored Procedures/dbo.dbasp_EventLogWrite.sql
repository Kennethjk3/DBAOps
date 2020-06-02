SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE PROCEDURE [dbo].[dbasp_EventLogWrite] (@EvtSource [nvarchar] (max), @EvtMessage [nvarchar] (max), @EvtType [nvarchar] (max), @EvtID [int], @EvtCat [smallint])
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.StoredProcedures].[dbasp_EventLogWrite]
GO
