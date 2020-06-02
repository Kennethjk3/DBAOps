CREATE TABLE [dbo].[LicenseInfo]
(
[LI_ID] [int] NOT NULL IDENTITY(1, 1),
[VendorName] [sys].[sysname] NULL,
[Product] [sys].[sysname] NULL,
[Version] [sys].[sysname] NULL,
[Type] [sys].[sysname] NULL,
[LicenseKey] [sys].[sysname] NULL,
[LicenseNum] [int] NULL,
[Support_ExpDate] [datetime] NULL,
[active] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
