SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_Filter_Alpha] (@filenameToCheck [nvarchar] (max), @ReplacementCharacter [nchar] (1))
RETURNS [nvarchar] (max)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_Filter_Alpha]
GO
