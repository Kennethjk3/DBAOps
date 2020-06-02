CREATE TABLE [dbo].[UserDB_Access_Ctrl]
(
[CreateDate] [datetime] NOT NULL CONSTRAINT [DF__UserDB_Ac__Creat__6CAE0B98] DEFAULT (getdate()),
[RequestID] [int] NOT NULL,
[LoginCreated] [bit] NOT NULL CONSTRAINT [DF__UserDB_Ac__Login__6DA22FD1] DEFAULT ((0)),
[DBname] [sys].[sysname] NOT NULL,
[UserCreated] [bit] NOT NULL CONSTRAINT [DF__UserDB_Ac__UserC__6E96540A] DEFAULT ((0)),
[Loginname] [sys].[sysname] NOT NULL,
[DBrole] [sys].[sysname] NOT NULL,
[DeleteDate] [datetime] NOT NULL,
[DateDeleted] [datetime] NULL
) ON [PRIMARY]
GO
