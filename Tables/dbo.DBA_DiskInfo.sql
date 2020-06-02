CREATE TABLE [dbo].[DBA_DiskInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[Active] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DriveName] [sys].[sysname] NOT NULL,
[DriveSize] [int] NULL,
[DriveFree] [int] NULL,
[DriveFree_pct] [int] NULL,
[GrowthPerWeekMB] [int] NULL,
[DriveFullWks] [int] NULL,
[Ovrrd_Freespace_pct] [smallint] NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
