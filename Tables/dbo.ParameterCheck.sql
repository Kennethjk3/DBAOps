CREATE TABLE [dbo].[ParameterCheck]
(
[ParameterCheckID] [int] NOT NULL IDENTITY(1, 1),
[ProvisionModelID] [int] NOT NULL,
[ModelParameterID] [int] NOT NULL,
[PreferredSetting] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ActualSetting] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DatabaseName] [sys].[sysname] NULL,
[IsSettingCompliant] [bit] NOT NULL,
[InsertDateTime] [datetime] NOT NULL CONSTRAINT [DF__Parameter__Inser__28438E97] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ParameterCheck] ADD CONSTRAINT [PK_ParameterCheck] PRIMARY KEY CLUSTERED  ([ParameterCheckID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IDX_ParameterCheck_ProvisionModelID] ON [dbo].[ParameterCheck] ([ProvisionModelID]) ON [PRIMARY]
GO
