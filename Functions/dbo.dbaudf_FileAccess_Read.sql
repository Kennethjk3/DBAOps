SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FileAccess_Read] (@filePath [nvarchar] (max))
RETURNS TABLE (
[Line] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NumCharacters] [int] NULL,
[NumWords] [int] NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_FileAccess_Read]
GO
