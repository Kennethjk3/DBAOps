SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_ListClusterNetwork] ()
RETURNS TABLE (
[ClusterName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResourceType] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResourceName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResourceDetail] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GroupName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CurrentOwner] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PreferredOwner] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Dependencies] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RestartAction] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AutoFailback] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[State] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_ListClusterNetwork]
GO
