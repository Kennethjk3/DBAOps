SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_CPUInfo] (@Attribute [nvarchar] (max))
RETURNS [int]
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_CPUInfo]
GO
