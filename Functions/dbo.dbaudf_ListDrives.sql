SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_ListDrives] ()
RETURNS TABLE (
[DriveLetter] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TotalSize] [float] NULL,
[AvailableSpace] [float] NULL,
[FreeSpace] [float] NULL,
[DriveType] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FileSystem] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsReady] [bit] NULL,
[VolumeName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RootFolder] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PercentUsed] [float] NULL,
[UseChart] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [${{secrets.COMPANY_NAME}}.Operations.CLRTools].[${{secrets.COMPANY_NAME}}.Operations.UserDefinedFunctions].[dbaudf_ListDrives]
GO
