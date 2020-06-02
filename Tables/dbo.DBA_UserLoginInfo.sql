CREATE TABLE [dbo].[DBA_UserLoginInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[Active] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ULname] [sys].[sysname] NULL,
[ULtype] [sys].[sysname] NULL,
[ULsubname] [sys].[sysname] NULL,
[DBname] [sys].[sysname] NULL,
[SYSadmin] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBOflag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DirectGrants] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SQL_createDate] [datetime] NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
