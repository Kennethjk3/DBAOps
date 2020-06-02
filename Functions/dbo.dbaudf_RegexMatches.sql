SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_RegexMatches] (@input [nvarchar] (max), @pattern [nvarchar] (max))
RETURNS TABLE (
[Index] [int] NULL,
[Text] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_RegexMatches]
GO
