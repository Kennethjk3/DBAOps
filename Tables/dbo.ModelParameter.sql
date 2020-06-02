CREATE TABLE [dbo].[ModelParameter]
(
[ModelParameterID] [int] NOT NULL IDENTITY(1, 1),
[ProvisionModelID] [int] NOT NULL,
[ParameterScope] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ParameterName] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsPerDatabase] [bit] NOT NULL CONSTRAINT [DF__ModelPara__IsPer__F818CB4] DEFAULT ((0)),
[PreferredSetting] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsAlertOnNonCompliance] [bit] NOT NULL CONSTRAINT [DF__ModelPara__IsAle__46364D24] DEFAULT ((0)),
[CorrectiveAction] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ModelParameter] ADD CONSTRAINT [PK_ModelParameter] PRIMARY KEY CLUSTERED  ([ModelParameterID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IDX_ParameterCheck_ModelParameterID] ON [dbo].[ModelParameter] ([ModelParameterID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IDX_ModelParameter_ProvisionModelID] ON [dbo].[ModelParameter] ([ProvisionModelID]) ON [PRIMARY]
GO
