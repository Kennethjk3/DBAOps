SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_RegexGroups] (@input [nvarchar] (max), @pattern [nvarchar] (max))
RETURNS TABLE (
[Index] [int] NULL,
[Group] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Text] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_RegexGroups]
GO
