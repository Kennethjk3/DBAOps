SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO
CREATE FUNCTION [dbo].[dbaudf_RestoreFileList] (@full_backup_path [nvarchar] (max))
RETURNS TABLE (
[LogicalName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PhysicalName] [nvarchar] (260) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FileGroupName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SIZE] [numeric] (20, 0) NULL,
[MaxSize] [numeric] (20, 0) NULL,
[FileId] [bigint] NULL,
[CreateLSN] [numeric] (25, 0) NULL,
[DropLSN] [numeric] (25, 0) NULL,
[UniqueId] [uniqueidentifier] NULL,
[ReadOnlyLSN] [numeric] (25, 0) NULL,
[ReadWriteLSN] [numeric] (25, 0) NULL,
[BackupSizeInBytes] [bigint] NULL,
[SourceBlockSize] [int] NULL,
[FileGroupId] [int] NULL,
[LogGroupGUID] [uniqueidentifier] NULL,
[DifferentialBaseLSN] [numeric] (25, 0) NULL,
[DifferentialBaseGUID] [uniqueidentifier] NULL,
[IsReadOnly] [bit] NULL,
[IsPresent] [bit] NULL,
[TDEThumbprint] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [Virtuoso.Operations.CLRTools].[Virtuoso.Operations.UserDefinedFunctions].[filelists]
GO
