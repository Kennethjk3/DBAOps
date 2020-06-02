CREATE TABLE [dbo].[Build]
(
[iBuildid] [int] NOT NULL IDENTITY(1, 1),
[vchName] [varchar] (40) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[vchLabel] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[dtBuildDate] [datetime] NOT NULL CONSTRAINT [DF__Build__dtBuildDa__403A8C7D] DEFAULT (getdate()),
[vchNotes] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Build] ADD CONSTRAINT [PKCL_Build] PRIMARY KEY CLUSTERED  ([iBuildid]) ON [PRIMARY]
GO
