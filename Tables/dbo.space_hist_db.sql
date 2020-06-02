CREATE TABLE [dbo].[space_hist_db]
(
[StatDate] [smalldatetime] NULL,
[DBName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AllocatedMB] [int] NULL,
[ReservedMB] [int] NULL,
[UsedMB] [int] NULL,
[DataMB] [int] NULL,
[IndexMB] [int] NULL,
[UnusedMB] [int] NULL,
[UnreservedMB] [int] NULL
) ON [PRIMARY]
GO
