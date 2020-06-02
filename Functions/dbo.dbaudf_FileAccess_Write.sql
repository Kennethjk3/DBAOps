SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_FileAccess_Write] (@InputText [nvarchar] (max), @path [nvarchar] (max), @append [bit], @ForceCrLf [bit])
RETURNS [bit]
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_FileAccess_Write]
GO
