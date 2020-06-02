CREATE TABLE [dbo].[fragmentation_LOG]
(
[frag_DBname] [sys].[sysname] NOT NULL,
[frag_TBLname] [sys].[sysname] NOT NULL,
[frag_IDXname] [sys].[sysname] NOT NULL,
[frag_IDX_ID] [int] NULL,
[frag_pages] [int] NULL,
[frag_frag_pct] [decimal] (18, 0) NULL,
[frag_sdensity_pct] [decimal] (18, 0) NULL,
[frag_recdate] [datetime] NOT NULL
) ON [PRIMARY]
GO
