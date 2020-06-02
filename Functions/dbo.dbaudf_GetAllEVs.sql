SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_GetAllEVs] ()
RETURNS TABLE (
[Name] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_GetAllEVs]
GO
