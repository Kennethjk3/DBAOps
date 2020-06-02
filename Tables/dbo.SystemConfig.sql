CREATE TABLE [dbo].[SystemConfig]
(
[ConfigGroup] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ConfigName] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ConfigValue] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SystemConfig] ADD CONSTRAINT [PK_SYSTEMCONFIG] PRIMARY KEY CLUSTERED  ([ConfigGroup], [ConfigName]) ON [PRIMARY]
GO
