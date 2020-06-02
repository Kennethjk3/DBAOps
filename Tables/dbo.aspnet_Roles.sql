CREATE TABLE [dbo].[aspnet_Roles]
(
[ApplicationId] [uniqueidentifier] NOT NULL,
[RoleId] [uniqueidentifier] NOT NULL,
[RoleName] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LoweredRoleName] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
