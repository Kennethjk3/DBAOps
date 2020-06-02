SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_ListShares] ()
RETURNS TABLE (
[ShareName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SharePath] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_ListShares]
GO
