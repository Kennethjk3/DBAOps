CREATE TABLE [dbo].[BuildDetail]
(
[bd_id] [int] NOT NULL IDENTITY(1, 1),
[vchLabel] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ScriptName] [sys].[sysname] NULL,
[ScriptPath] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ScriptResult] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ScriptRundate] [datetime] NOT NULL CONSTRAINT [DF__BuildDeta__Scrip__4316F928] DEFAULT (getdate()),
[ScriptRunduration_ss] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BuildDetail] ADD CONSTRAINT [PKCL_BuildDetail] PRIMARY KEY CLUSTERED  ([bd_id]) ON [PRIMARY]
GO
