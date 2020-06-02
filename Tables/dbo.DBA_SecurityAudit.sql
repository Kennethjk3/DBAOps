CREATE TABLE [dbo].[DBA_SecurityAudit]
(
[ServerName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModDate] [datetime] NULL,
[GroupName] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FirstName] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DomainAccount] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ServerPermissions] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBPermissions] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TempPermissionsGranted] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SecurityLevel] [int] NOT NULL
) ON [PRIMARY]
GO
