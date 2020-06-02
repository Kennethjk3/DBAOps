CREATE TABLE [dbo].[DBA_DBInfo]
(
[SQLName] [sys].[sysname] NOT NULL,
[DBName] [sys].[sysname] NOT NULL,
[database_id] [int] NULL,
[status] [sys].[sysname] NULL,
[CreateDate] [datetime] NULL,
[ENVname] [sys].[sysname] NULL,
[ENVnum] [sys].[sysname] NULL,
[Appl_desc] [sys].[sysname] NULL,
[BaselineFolder] [sys].[sysname] NULL,
[BaselineServername] [sys].[sysname] NULL,
[BaselineDate] [sys].[sysname] NULL,
[build] [sys].[sysname] NULL,
[TotalSizeMB] [bigint] NULL,
[Size_PR_From_Total] [int] NULL,
[NumberOfFiles] [int] NULL,
[data_size_MB] [nvarchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[log_size_MB] [nvarchar] (18) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[row_count] [bigint] NULL,
[RecovModel] [sys].[sysname] NULL,
[PageVerify] [sys].[sysname] NULL,
[Collation] [sys].[sysname] NULL,
[FullTextCat] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Trustworthy] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Assemblies] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Filestream] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AGName] [sys].[sysname] NULL,
[Mirroring] [sys].[sysname] NULL,
[Repl_Flag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LogShipping] [sys].[sysname] NULL,
[ReportingSvcs] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartupSprocs] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Last_Access] [datetime] NULL,
[Last_Access_in_days] [int] NULL,
[modDate] [datetime] NULL,
[DBCompat] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DEPLstatus] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[VLFcount] [int] NULL,
[DB_Settings] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NotFound] [datetime] NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[dbatr_DBinfo_Updated]
   ON  [dbo].[DBA_DBInfo]
   AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

        INSERT dbo.DBA_AuditChanges (Tablename, ColumnName, Event, DataKey, OldValue, NewValue)


          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN database_id FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','database_id', 'Update', d.DBname, cast(d.database_id as sql_variant), cast(i.database_id as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.database_id <> i.database_id
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN status FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','status', 'Update', d.DBname, cast(d.status as sql_variant), cast(i.status as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.status <> i.status
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CreateDate FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','CreateDate', 'Update', d.DBname, cast(d.CreateDate as sql_variant), cast(i.CreateDate as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.CreateDate <> i.CreateDate
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN ENVname FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','ENVname', 'Update', d.DBname, cast(d.ENVname as sql_variant), cast(i.ENVname as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.ENVname <> i.ENVname
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN ENVnum FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','ENVnum', 'Update', d.DBname, cast(d.ENVnum as sql_variant), cast(i.ENVnum as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.ENVnum <> i.ENVnum
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Appl_desc FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Appl_desc', 'Update', d.DBname, cast(d.Appl_desc as sql_variant), cast(i.Appl_desc as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Appl_desc <> i.Appl_desc
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN BaselineFolder FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','BaselineFolder', 'Update', d.DBname, cast(d.BaselineFolder as sql_variant), cast(i.BaselineFolder as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.BaselineFolder <> i.BaselineFolder
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN BaselineServername FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','BaselineServername', 'Update', d.DBname, cast(d.BaselineServername as sql_variant), cast(i.BaselineServername as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.BaselineServername <> i.BaselineServername
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN RecovModel FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','RecovModel', 'Update', d.DBname, cast(d.RecovModel as sql_variant), cast(i.RecovModel as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.RecovModel <> i.RecovModel
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN PageVerify FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','PageVerify', 'Update', d.DBname, cast(d.PageVerify as sql_variant), cast(i.PageVerify as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.PageVerify <> i.PageVerify
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Collation FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Collation', 'Update', d.DBname, cast(d.Collation as sql_variant), cast(i.Collation as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Collation <> i.Collation
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN FullTextCat FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','FullTextCat', 'Update', d.DBname, cast(d.FullTextCat as sql_variant), cast(i.FullTextCat as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.FullTextCat <> i.FullTextCat
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Trustworthy  FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Trustworthy ', 'Update', d.DBname, cast(d.Trustworthy as sql_variant), cast(i.Trustworthy as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Trustworthy <> i.Trustworthy
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Assemblies FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Assemblies', 'Update', d.DBname, cast(d.Assemblies as sql_variant), cast(i.Assemblies as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Assemblies <> i.Assemblies
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Filestream FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Filestream', 'Update', d.DBname, cast(d.Filestream as sql_variant), cast(i.Filestream as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Filestream <> i.Filestream
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN AGName FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','AGName', 'Update', d.DBname, cast(d.AGName as sql_variant), cast(i.AGName as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.AGName <> i.AGName
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Mirroring FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Mirroring', 'Update', d.DBname, cast(d.Mirroring as sql_variant), cast(i.Mirroring as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Mirroring <> i.Mirroring
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Repl_Flag FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','Repl_Flag', 'Update', d.DBname, cast(d.Repl_Flag as sql_variant), cast(i.Repl_Flag as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.Repl_Flag <> i.Repl_Flag
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN LogShipping FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','LogShipping', 'Update', d.DBname, cast(d.LogShipping as sql_variant), cast(i.LogShipping as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.LogShipping <> i.LogShipping
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN ReportingSvcs FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','ReportingSvcs', 'Update', d.DBname, cast(d.ReportingSvcs as sql_variant), cast(i.ReportingSvcs as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.ReportingSvcs <> i.ReportingSvcs
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN StartupSprocs FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','StartupSprocs', 'Update', d.DBname, cast(d.StartupSprocs as sql_variant), cast(i.StartupSprocs as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.StartupSprocs <> i.StartupSprocs
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DBCompat FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','DBCompat', 'Update', d.DBname, cast(d.DBCompat as sql_variant), cast(i.DBCompat as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.DBCompat <> i.DBCompat
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DEPLstatus FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','DEPLstatus', 'Update', d.DBname, cast(d.DEPLstatus as sql_variant), cast(i.DEPLstatus as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.DEPLstatus <> i.DEPLstatus
      UNION ALL
          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DB_Settings FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_DBInfo','DB_Settings', 'Update', d.DBname, cast(d.DB_Settings as sql_variant), cast(i.DB_Settings as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.DBname = d.DBname
            WHERE d.DB_Settings <> i.DB_Settings


END
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_clust_DBA_DBInfo] ON [dbo].[DBA_DBInfo] ([SQLName], [DBName]) ON [PRIMARY]
GO
