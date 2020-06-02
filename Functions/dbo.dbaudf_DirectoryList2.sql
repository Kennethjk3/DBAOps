SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_DirectoryList2] (@rootDir [nvarchar] (max), @wildCard [nvarchar] (max), @subDirectories [bit])
RETURNS TABLE (
[Name] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FullPathName] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Directory] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Extension] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NULL,
[DateAccessed] [datetime] NULL,
[DateModified] [datetime] NULL,
[Attributes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Size] [bigint] NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[dbaudf_DirectoryList2]
GO
