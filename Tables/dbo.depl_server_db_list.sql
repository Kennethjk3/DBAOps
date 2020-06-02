CREATE TABLE [dbo].[depl_server_db_list]
(
[TBL_ID] [int] NOT NULL IDENTITY(1, 1),
[Parent_name] [sys].[sysname] NOT NULL,
[App_name] [sys].[sysname] NOT NULL,
[depl_servername] [sys].[sysname] NOT NULL,
[depl_ENVname] [sys].[sysname] NOT NULL,
[depl_ENVnum] [sys].[sysname] NOT NULL,
[depl_restore_folder] [sys].[sysname] NOT NULL,
[depl_DBname] [sys].[sysname] NOT NULL,
[Active] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[push_to_nxt] [nchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[depl_Baseline_servername] [sys].[sysname] NOT NULL,
[modDate] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[depl_server_db_list] ADD CONSTRAINT [PKCL_depl_servername] PRIMARY KEY CLUSTERED  ([depl_servername], [TBL_ID]) ON [PRIMARY]
GO
