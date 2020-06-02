CREATE TABLE [dbo].[linear_regression]
(
[X] [float] NOT NULL,
[Y] [float] NOT NULL,
[XY] [float] NULL,
[X2] [float] NULL,
[Y2] [float] NULL,
[dataflag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
