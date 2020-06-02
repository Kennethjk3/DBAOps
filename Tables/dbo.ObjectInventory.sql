CREATE TABLE [dbo].[ObjectInventory]
(
[OIname] [sys].[sysname] NOT NULL,
[OItype] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OItype_desc] [sys].[sysname] NULL,
[OInotes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
