CREATE TABLE [dbo].[ProvisionModel]
(
[ProvisionModelID] [int] NOT NULL,
[ProvisionModelName] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProvisionModel] ADD CONSTRAINT [PK_ProvisionModel] PRIMARY KEY CLUSTERED  ([ProvisionModelID]) ON [PRIMARY]
GO
