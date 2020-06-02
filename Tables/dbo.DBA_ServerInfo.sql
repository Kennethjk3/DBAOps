CREATE TABLE [dbo].[DBA_ServerInfo]
(
[SQLServerID] [int] NOT NULL IDENTITY(1, 1),
[ServerName] [sys].[sysname] NOT NULL,
[FQDN] [sys].[sysname] NULL,
[ServerType] [sys].[sysname] NULL,
[SQLName] [sys].[sysname] NOT NULL,
[SQLEnv] [sys].[sysname] NULL,
[Active] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Filescan] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SQLmail] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[modDate] [datetime] NULL,
[SQLver] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SQLinstallDate] [datetime] NULL,
[SQLinstallBy] [sys].[sysname] NULL,
[SQLrecycleDate] [sys].[sysname] NULL,
[SQLSvcAcct] [sys].[sysname] NULL,
[SQLAgentAcct] [sys].[sysname] NULL,
[SQLStartupParms] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SQLScanforStartupSprocs] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DBAOps_Version] [sys].[sysname] NULL,
[dbaperf_Version] [sys].[sysname] NULL,
[SQLDeploy_Version] [sys].[sysname] NULL,
[backup_type] [sys].[sysname] NULL,
[LiteSpeed] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RedGate] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[awe_enabled] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MAXdop_value] [nvarchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Memory] [sys].[sysname] NULL,
[SQLmax_memory] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[tempdb_filecount] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FullTextCat] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Assemblies] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Filestream_AcsLvl] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AvailGrp] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Mirroring] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Repl_Flag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LogShipping] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LinkedServers] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportingSvcs] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LocalPasswords] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DEPLstatus] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IndxSnapshot_process] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IndxSnapshot_inverval] [sys].[sysname] NULL,
[CLR_state] [sys].[sysname] NULL,
[FrameWork_ver] [sys].[sysname] NULL,
[FrameWork_dir] [sys].[sysname] NULL,
[PowerShell] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OracleClient] [sys].[sysname] NULL,
[TNSnamesPath] [sys].[sysname] NULL,
[DomainName] [sys].[sysname] NULL,
[ClusterName] [sys].[sysname] NULL,
[SAN] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PowerPath] [sys].[sysname] NULL,
[Port] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Location] [sys].[sysname] NULL,
[IPnum] [sys].[sysname] NULL,
[CPUphysical] [sys].[sysname] NULL,
[CPUcore] [sys].[sysname] NULL,
[CPUlogical] [sys].[sysname] NULL,
[CPUtype] [sys].[sysname] NULL,
[OSname] [sys].[sysname] NULL,
[OSver] [sys].[sysname] NULL,
[OSinstallDate] [sys].[sysname] NULL,
[OSuptime] [sys].[sysname] NULL,
[MDACver] [sys].[sysname] NULL,
[IEver] [sys].[sysname] NULL,
[AntiVirus_type] [sys].[sysname] NULL,
[AntiVirus_Excludes] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[boot_3gb] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[boot_pae] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[boot_userva] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Pagefile_maxsize] [sys].[sysname] NULL,
[Pagefile_available] [sys].[sysname] NULL,
[Pagefile_inuse] [sys].[sysname] NULL,
[Pagefile_path] [sys].[sysname] NULL,
[TimeZone] [sys].[sysname] NULL,
[SystemModel] [sys].[sysname] NULL,
[Services] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OffSiteBkUp_Date] [datetime] NULL,
[OffSiteBkUp_Status] [sys].[sysname] NULL,
[RebootPending] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[dbatr_serverinfo_Updated]
   ON  [dbo].[DBA_ServerInfo]
   AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

        INSERT dbo.DBA_AuditChanges (Tablename, ColumnName, Event,  DataKey, OldValue, NewValue)


          ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN FQDN FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','FQDN', 'Update', d.sqlname, cast(d.FQDN as sql_variant), cast(i.FQDN as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.FQDN <> i.FQDN
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLEnv FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLEnv',  'Update', d.sqlname, cast(d.SQLEnv as sql_variant), cast(i.SQLEnv as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLEnv <> i.SQLEnv
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Active FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Active',  'Update', d.sqlname, cast(d.Active as sql_variant), cast(i.Active as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Active <> i.Active
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Filescan FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Filescan',  'Update', d.sqlname, cast(d.Filescan as sql_variant), cast(i.Filescan as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Filescan <> i.Filescan
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLmail FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLmail',  'Update', d.sqlname, cast(d.SQLmail as sql_variant), cast(i.SQLmail as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLmail <> i.SQLmail
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLver FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLver',  'Update', d.sqlname, cast(d.SQLver as sql_variant), cast(i.SQLver as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLver <> i.SQLver
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLrecycleDate FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLrecycleDate',  'Update', d.sqlname, cast(d.SQLrecycleDate as sql_variant), cast(i.SQLrecycleDate as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLrecycleDate <> i.SQLrecycleDate
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLSvcAcct FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLSvcAcct',  'Update', d.sqlname, cast(d.SQLSvcAcct as sql_variant), cast(i.SQLSvcAcct as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLSvcAcct <> i.SQLSvcAcct
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLAgentAcct FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLAgentAcct',  'Update', d.sqlname, cast(d.SQLAgentAcct as sql_variant), cast(i.SQLAgentAcct as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLAgentAcct <> i.SQLAgentAcct
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLStartupParms FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLStartupParms',  'Update', d.sqlname, cast(d.SQLStartupParms as sql_variant), cast(i.SQLStartupParms as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLStartupParms <> i.SQLStartupParms
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLScanforStartupSprocs FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLScanforStartupSprocs',  'Update', d.sqlname, cast(d.SQLScanforStartupSprocs as sql_variant), cast(i.SQLScanforStartupSprocs as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLScanforStartupSprocs <> i.SQLScanforStartupSprocs
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DBAOps_Version FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','DBAOps_Version',  'Update', d.sqlname, cast(d.DBAOps_Version as sql_variant), cast(i.DBAOps_Version as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.DBAOps_Version <> i.DBAOps_Version
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN dbaperf_Version FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','dbaperf_Version',  'Update', d.sqlname, cast(d.dbaperf_Version as sql_variant), cast(i.dbaperf_Version as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.dbaperf_Version <> i.dbaperf_Version
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DBAOps_Version FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','DBAOps_Version',  'Update', d.sqlname, cast(d.DBAOps_Version as sql_variant), cast(i.DBAOps_Version as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.DBAOps_Version <> i.DBAOps_Version
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN backup_type FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','backup_type',  'Update', d.sqlname, cast(d.backup_type as sql_variant), cast(i.backup_type as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.backup_type <> i.backup_type
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN awe_enabled FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','awe_enabled',  'Update', d.sqlname, cast(d.awe_enabled as sql_variant), cast(i.awe_enabled as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.awe_enabled <> i.awe_enabled
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN MAXdop_value FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','MAXdop_value',  'Update', d.sqlname, cast(d.MAXdop_value as sql_variant), cast(i.MAXdop_value as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.MAXdop_value <> i.MAXdop_value
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Memory FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Memory',  'Update', d.sqlname, cast(d.Memory as sql_variant), cast(i.Memory as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Memory <> i.Memory
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SQLmax_memory FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SQLmax_memory',  'Update', d.sqlname, cast(d.SQLmax_memory as sql_variant), cast(i.SQLmax_memory as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SQLmax_memory <> i.SQLmax_memory
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN tempdb_filecount FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','tempdb_filecount',  'Update', d.sqlname, cast(d.tempdb_filecount as sql_variant), cast(i.tempdb_filecount as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.tempdb_filecount <> i.tempdb_filecount
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN FullTextCat FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','FullTextCat',  'Update', d.sqlname, cast(d.FullTextCat as sql_variant), cast(i.FullTextCat as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.FullTextCat <> i.FullTextCat
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Assemblies FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Assemblies',  'Update', d.sqlname, cast(d.Assemblies as sql_variant), cast(i.Assemblies as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Assemblies <> i.Assemblies
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Filestream_AcsLvl FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Filestream_AcsLvl',  'Update', d.sqlname, cast(d.Filestream_AcsLvl as sql_variant), cast(i.Filestream_AcsLvl as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Filestream_AcsLvl <> i.Filestream_AcsLvl
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN AvailGrp FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','AvailGrp',  'Update', d.sqlname, cast(d.AvailGrp as sql_variant), cast(i.AvailGrp as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.AvailGrp <> i.AvailGrp
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Mirroring FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Mirroring',  'Update', d.sqlname, cast(d.Mirroring as sql_variant), cast(i.Mirroring as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Mirroring <> i.Mirroring
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Repl_Flag FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Repl_Flag',  'Update', d.sqlname, cast(d.Repl_Flag as sql_variant), cast(i.Repl_Flag as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Repl_Flag <> i.Repl_Flag
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN LogShipping FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','LogShipping',  'Update', d.sqlname, cast(d.LogShipping as sql_variant), cast(i.LogShipping as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.LogShipping <> i.LogShipping
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN LinkedServers FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','LinkedServers',  'Update', d.sqlname, cast(d.LinkedServers as sql_variant), cast(i.LinkedServers as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.LinkedServers <> i.LinkedServers
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN ReportingSvcs FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','ReportingSvcs',  'Update', d.sqlname, cast(d.ReportingSvcs as sql_variant), cast(i.ReportingSvcs as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.ReportingSvcs <> i.ReportingSvcs
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN LocalPasswords FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','LocalPasswords',  'Update', d.sqlname, cast(d.LocalPasswords as sql_variant), cast(i.LocalPasswords as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.LocalPasswords <> i.LocalPasswords
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DEPLstatus FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','DEPLstatus',  'Update', d.sqlname, cast(d.DEPLstatus as sql_variant), cast(i.DEPLstatus as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.DEPLstatus <> i.DEPLstatus
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN IndxSnapshot_process FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','IndxSnapshot_process',  'Update', d.sqlname, cast(d.IndxSnapshot_process as sql_variant), cast(i.IndxSnapshot_process as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.IndxSnapshot_process <> i.IndxSnapshot_process
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN IndxSnapshot_inverval FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','IndxSnapshot_inverval',  'Update', d.sqlname, cast(d.IndxSnapshot_inverval as sql_variant), cast(i.IndxSnapshot_inverval as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.IndxSnapshot_inverval <> i.IndxSnapshot_inverval
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CLR_state FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','CLR_state',  'Update', d.sqlname, cast(d.CLR_state as sql_variant), cast(i.CLR_state as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.CLR_state <> i.CLR_state
      UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN FrameWork_ver FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','FrameWork_ver',  'Update', d.sqlname, cast(d.FrameWork_ver as sql_variant), cast(i.FrameWork_ver as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.FrameWork_ver <> i.FrameWork_ver
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN FrameWork_dir FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','FrameWork_dir',  'Update', d.sqlname, cast(d.FrameWork_dir as sql_variant), cast(i.FrameWork_dir as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.FrameWork_dir <> i.FrameWork_dir
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN PowerShell FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','PowerShell',  'Update', d.sqlname, cast(d.PowerShell as sql_variant), cast(i.PowerShell as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.PowerShell <> i.PowerShell
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN OracleClient FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','OracleClient',  'Update', d.sqlname, cast(d.OracleClient as sql_variant), cast(i.OracleClient as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.OracleClient <> i.OracleClient
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN TNSnamesPath FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','TNSnamesPath',  'Update', d.sqlname, cast(d.TNSnamesPath as sql_variant), cast(i.TNSnamesPath as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.TNSnamesPath <> i.TNSnamesPath
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN DomainName FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','DomainName',  'Update', d.sqlname, cast(d.DomainName as sql_variant), cast(i.DomainName as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.DomainName <> i.DomainName
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN ClusterName FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','ClusterName',  'Update', d.sqlname, cast(d.ClusterName as sql_variant), cast(i.ClusterName as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.ClusterName <> i.ClusterName
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SAN FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SAN',  'Update', d.sqlname, cast(d.SAN as sql_variant), cast(i.SAN as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SAN <> i.SAN
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN PowerPath FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','PowerPath',  'Update', d.sqlname, cast(d.PowerPath as sql_variant), cast(i.PowerPath as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.PowerPath <> i.PowerPath
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Port FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Port',  'Update', d.sqlname, cast(d.Port as sql_variant), cast(i.Port as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Port <> i.Port
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN IPnum FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','IPnum',  'Update', d.sqlname, cast(d.IPnum as sql_variant), cast(i.IPnum as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.IPnum <> i.IPnum
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CPUphysical FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','CPUphysical',  'Update', d.sqlname, cast(d.CPUphysical as sql_variant), cast(i.CPUphysical as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.CPUphysical <> i.CPUphysical
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CPUcore FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','CPUcore',  'Update', d.sqlname, cast(d.CPUcore as sql_variant), cast(i.CPUcore as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.CPUcore <> i.CPUcore
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CPUlogical FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','CPUlogical',  'Update', d.sqlname, cast(d.CPUlogical as sql_variant), cast(i.CPUlogical as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.CPUlogical <> i.CPUlogical
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN CPUtype FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','CPUtype',  'Update', d.sqlname, cast(d.CPUtype as sql_variant), cast(i.CPUtype as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.CPUtype <> i.CPUtype
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN OSname FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','OSname',  'Update', d.sqlname, cast(d.OSname as sql_variant), cast(i.OSname as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.OSname <> i.OSname
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN OSver FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','OSver',  'Update', d.sqlname, cast(d.OSver as sql_variant), cast(i.OSver as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.OSver <> i.OSver
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN MDACver FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','MDACver',  'Update', d.sqlname, cast(d.MDACver as sql_variant), cast(i.MDACver as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.MDACver <> i.MDACver
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN IEver FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','IEver',  'Update', d.sqlname, cast(d.IEver as sql_variant), cast(i.IEver as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.IEver <> i.IEver
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN AntiVirus_type FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','AntiVirus_type',  'Update', d.sqlname, cast(d.AntiVirus_type as sql_variant), cast(i.AntiVirus_type as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.AntiVirus_type <> i.AntiVirus_type
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN AntiVirus_Excludes FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','AntiVirus_Excludes',  'Update', d.sqlname, cast(d.AntiVirus_Excludes as sql_variant), cast(i.AntiVirus_Excludes as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.AntiVirus_Excludes <> i.AntiVirus_Excludes
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Pagefile_maxsize FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Pagefile_maxsize',  'Update', d.sqlname, cast(d.Pagefile_maxsize as sql_variant), cast(i.Pagefile_maxsize as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Pagefile_maxsize <> i.Pagefile_maxsize
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Pagefile_path FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Pagefile_path',  'Update', d.sqlname, cast(d.Pagefile_path as sql_variant), cast(i.Pagefile_path as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Pagefile_path <> i.Pagefile_path
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN TimeZone FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','TimeZone',  'Update', d.sqlname, cast(d.TimeZone as sql_variant), cast(i.TimeZone as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.TimeZone <> i.TimeZone
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN SystemModel FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','SystemModel',  'Update', d.sqlname, cast(d.SystemModel as sql_variant), cast(i.SystemModel as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.SystemModel <> i.SystemModel
     UNION ALL
           ------------------------------------------------
          ------------------------------------------------
          --  CHECK COLUMN Services FOR CHANGES
          ------------------------------------------------
          ------------------------------------------------
            SELECT 'DBA_ServerInfo','Services',  'Update', d.sqlname, cast(d.Services as sql_variant), cast(i.Services as sql_variant)
            FROM inserted i
            INNER JOIN deleted d
                ON i.sqlname = d.sqlname
            WHERE d.Services <> i.Services


END
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_clust_DBA_ServerInfo] ON [dbo].[DBA_ServerInfo] ([SQLName]) ON [PRIMARY]
GO
