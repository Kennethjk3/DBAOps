SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_StringToTable] (@Input [nvarchar] (max), @separator [nvarchar] (max))
RETURNS TABLE (
[OccurenceId] [int] NULL,
[SplitValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_StringToTable]
GO
