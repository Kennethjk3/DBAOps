CREATE TABLE [dbo].[DBA_LinkedServerInfo]
(
[LK_ID] [int] NOT NULL IDENTITY(1, 1),
[SQLName] [sys].[sysname] NOT NULL,
[LKname] [sys].[sysname] NOT NULL,
[LKserver_id] [int] NOT NULL,
[LKsrvproduct] [sys].[sysname] NULL,
[LKprovidername] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LKdatasource] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LKlocation] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LKproviderstring] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LKcatalog] [sys].[sysname] NULL,
[LKconnecttimeout] [int] NULL,
[LKquerytimeout] [int] NULL,
[LKrpc] [bit] NULL,
[LKpub] [bit] NULL,
[LKsub] [bit] NULL,
[LKdist] [bit] NULL,
[LKrpcout] [bit] NULL,
[LKdataaccess] [bit] NULL,
[LKcollationcompatible] [bit] NULL,
[LKuseremotecollation] [bit] NULL,
[LKlazyschemavalidation] [bit] NULL,
[LKcollation] [sys].[sysname] NULL,
[LKcreatedate] [datetime] NULL CONSTRAINT [DF__DBA_Linke__LKcre__534D60F1] DEFAULT (getdate()),
[LKmoddate] [datetime] NULL CONSTRAINT [DF__DBA_Linke__LKmod__5441852A] DEFAULT (getdate())
) ON [PRIMARY]
GO
