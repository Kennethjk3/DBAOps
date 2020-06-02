CREATE TABLE [dbo].[DBA_BackupInfo]
(
[ServerName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RunDate] [datetime] NULL,
[Period] [int] NULL,
[Period_DateTime] [datetime] NULL,
[Period_Type] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBName] [sys].[sysname] NOT NULL,
[PrimaryFile_Path] [varchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PrimaryFile_Mask] [varchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PrimaryFile_BackupType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PrimaryFile_BackupTimeStamp] [datetime] NULL,
[SupportFile_Path] [varchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SupportFile_Mask] [varchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SupportFile_BackupTimeStamp] [datetime] NULL,
[SupportFile_BackupType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
