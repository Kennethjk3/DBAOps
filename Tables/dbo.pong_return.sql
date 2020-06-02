CREATE TABLE [dbo].[pong_return]
(
[pong_ID] [int] NOT NULL IDENTITY(1, 1),
[pong_stamp] [sys].[sysname] NOT NULL,
[pong_servername] [sys].[sysname] NOT NULL,
[pong_detail01] [sys].[sysname] NOT NULL,
[pong_detail02] [sys].[sysname] NULL
) ON [PRIMARY]
GO
