CREATE TABLE [dbo].[DBA_DeplInfo]
(
[DeplInfoId] [bigint] NOT NULL IDENTITY(1, 1),
[Domain] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Enviro_Type] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ServerName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SQLName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Build_Number] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Build_Date] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Baseline_Date] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Record_Date] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DBA_DeplInfo] ADD CONSTRAINT [PK_DBA_DeplInfo] PRIMARY KEY CLUSTERED  ([DeplInfoId]) ON [PRIMARY]
GO
