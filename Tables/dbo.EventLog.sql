CREATE TABLE [dbo].[EventLog]
(
[EventLogID] [bigint] NOT NULL IDENTITY(1, 1),
[EventDate] [datetime] NULL CONSTRAINT [DF__EventLog__EventD__02FC7413] DEFAULT (getutcdate()),
[cEModule] [sys].[sysname] NOT NULL,
[cECategory] [sys].[sysname] NOT NULL,
[cEEvent] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[cEGUID] [uniqueidentifier] NULL,
[cEMessage] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[cEStat_Rows] [bigint] NULL,
[cEStat_Duration] [float] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EventLog] ADD CONSTRAINT [PK__EventLog__2A546C4795AE3B94] PRIMARY KEY CLUSTERED  ([EventLogID]) ON [PRIMARY]
GO
