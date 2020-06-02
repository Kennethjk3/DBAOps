SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   VIEW [dbo].[DBA_RestoreInfo]
AS
WITH   RestoreHistory
		AS
		(
		SELECT		DISTINCT
					[rs].[destination_database_name] [DBName]
					,[rs].[restore_date] 
					,[bs].[backup_start_date] 
					,[bs].[backup_finish_date] 
					,[bs].[database_name] as [source_database_name]
					,CASE WHEN [bmf].[physical_device_name] LIKE '%DB_CLN%' THEN 'YES' ELSE 'NO' END [Cleaned]
					,CAST(STUFF(STUFF(STUFF(STUFF(STUFF((
						SELECT	TOP 1 SUBSTRING(Text,2,14)
						FROM	DBAOps.dbo.dbaudf_RegexMatches([bmf].[physical_device_name],'_20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9][0-5][0-9][._]')
						),13,0,':'),11,0,':'),9,0,' '),7,0,'-'),5,0,'-') AS DATETIME) [BackupTimeStamp] 
					--,[bmf].[physical_device_name] as [backup_file_used_for_restore]
					,DBAOps.dbo.dbaudf_RegexReplace([bmf].[physical_device_name],'_SET_[0-9][0-9]_OF_[0-9][0-9]','_SET_[0-9][0-9]_OF_[0-9][0-9]') [Mask]
					,RANK() OVER(PARTITION BY [rs].[destination_database_name] ORDER BY [rs].[restore_date] DESC) [SortOrder2]
					,CASE	WHEN [sd].[state] != 0
							THEN NULL
							WHEN OBJECT_ID('['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata]') IS NOT NULL
							THEN CAST(DBAOps.dbo.dbaudf_execute_tsql('SELECT [Value] FROM ['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata] WHERE [Parameter] = ''BatchHistoryLogId''') AS XML).value('(/Results/@Value)[1]', 'INT')
							END [BatchHistoryLogId]
					,CASE	WHEN [sd].[state] != 0
							THEN NULL
							WHEN OBJECT_ID('['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata]') IS NOT NULL
							THEN CAST(DBAOps.dbo.dbaudf_execute_tsql('SELECT [Value] FROM ['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata] WHERE [Parameter] = ''ProcessID''') AS XML).value('(/Results/@Value)[1]', 'UNIQUEIDENTIFIER')
							END [ProcessID]
					,CASE	WHEN [sd].[state] != 0
							THEN NULL
							WHEN OBJECT_ID('['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata]') IS NOT NULL
							THEN CAST(DBAOps.dbo.dbaudf_execute_tsql('SELECT [Value] FROM ['+[rs].[destination_database_name]+'].[dbo].[Operations_Metadata] WHERE [Parameter] = ''ProductionBackupFileName''') AS XML).value('(/Results/@Value)[1]', 'VarChar(8000)')
							END [ProductionBackupFileName]

				--			SELECT *
		FROM		sys.databases sd		
		LEFT JOIN	msdb..restorehistory rs			ON [sd].[name]			= [rs].[destination_database_name]
		LEFT JOIN	msdb..backupset bs 				ON [rs].[backup_set_id] = [bs].[backup_set_id]
		LEFT JOIN	msdb..backupmediafamily bmf 	ON [bs].[media_set_id]	= [bmf].[media_set_id] 	
		WHERE		[rs].[destination_database_name] IS NOT NULL					
		)
		,LoggedDatabases
        AS
        (
        SELECT      name				DBName
                    ,create_date		CreateDate
					,state_desc
                    ,GETDATE()			modDate 
        FROM       sys.databases
        WHERE        name  NOT IN ('master','model','msdb','TempDB','DBAOps','DBAPerf','ReportServer','ReportServerTempDB','SQLsafeRepository','mdw','tpcc','','')
				AND	source_database_id IS null
        )
SELECT      DISTINCT
			TOP 100 PERCENT
			CASE WHEN [SortOrder2] IS NULL THEN 1 WHEN [SortOrder2] = 1 THEN 1 ELSE 2 END [SortOrder1]
			,T1.DBName [DatabaseName]
			,T1.state_desc
            ,T1.CreateDate
            ,T2.*
FROM        [LoggedDatabases] T1
LEFT JOIN   RestoreHistory T2        ON    T2.DBName = T1.DBName

ORDER BY    CASE WHEN [SortOrder2] IS NULL THEN 1 WHEN [SortOrder2] = 1 THEN 1 ELSE 2 END,T1.DBName,T2.restore_date desc
GO
GRANT SELECT ON  [dbo].[DBA_RestoreInfo] TO [public]
GO
