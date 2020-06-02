CREATE TABLE [dbo].[DBA_IPconfigInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[CONFIGname] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CONFIGdetail] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
