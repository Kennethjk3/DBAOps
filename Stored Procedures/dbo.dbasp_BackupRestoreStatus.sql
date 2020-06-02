SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupRestoreStatus]
					(
					@RawData	bit = 0
					)
AS
	--DECLARE @RawData	bit
	--SET		@RawData	= 0


	SET NOCOUNT ON
	DECLARE @msg				varchar(max)
			,@DBName			sysname
			,@ProcessedBytes	bigint
			,@DBSize			bigint

	CREATE TABLE #BackupStats
					(
					[DBName]			sysname
					,[LoginName]		sysname
					,[ProcessedBytes]	bigint
					,[CompressedBytes]	bigint
					,[Process]			CHAR(1)
					,[TYPE]				CHAR(1)
					,[Compression]		INT
					,[Encryption]		INT
					,[Start_Date]		DateTime
					)

	IF OBJECT_ID('master.dbo.sqbstatus') IS NOT NULL
	INSERT INTO		#BackupStats
			exec	master.dbo.sqbstatus 1


	----INSERT TEST RECORD
	--INSERT INTO #BackupStats
	--SELECT		'ProductCatalog','',111111112345,111111112345
	--UNION
	--SELECT		'DynamicSortOrder','',111111112345,111111112345
	--UNION
	--SELECT		'MessageQueue','',1111112345,1111112345

	IF @RawData = 0
	BEGIN
		SELECT		@Msg = COALESCE(@Msg,'')
							+ COALESCE
							( '	       CURRENTLY ' + REPLACE(REPLACE(r.command,'BACKUP','BACKING UP'),'RESTORE','RESTORING') + ' ' + UPPER(DB_NAME([database_id])) + CHAR(13) + CHAR(10)
							+ '	           Percent Done		= '
										+ CAST([percent_complete] as VarChar(max)) +'%'
										+ CHAR(13) + CHAR(10)
							+ '	           Running Time		= '
										+ CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ' hour(s), '
										+ CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + ' min(s), '
										+ CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ' sec(s)'
										+ CHAR(13) + CHAR(10)
							+ '	           Remaining Time	= '
										+ CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
										+ CAST((estimated_completion_time %3600000)/60000 as varchar) + ' min(s), '
										+ CAST((estimated_completion_time %60000)/1000 as varchar) + ' sec(s)'
										+ CHAR(13) + CHAR(10)
							+ '	           Completion Time	= '
										+ CAST(dateadd(second,estimated_completion_time/1000, getdate()) as VarChar(max))
										+ CHAR(13) + CHAR(10)
							+ CHAR(13) + CHAR(10)
							, ''
							)
		FROM		sys.dm_exec_requests r
		WHERE		r.command IN ('RESTORE DATABASE', 'BACKUP DATABASE', 'RESTORE LOG', 'BACKUP LOG')


		;WITH		DBSizes
					AS
					(
					Select		DB_NAME(database_id) [DBName]
								,SUM(cast(size AS bigint) * 8 * 1024) [DBSize]
					From		sys.master_files
					GROUP BY	DB_NAME(database_id)
					)
		SELECT		@Msg = COALESCE(@Msg,'')
							+ COALESCE
							( '	       CURRENTLY ' + REPLACE(REPLACE(
										CASE [Process] WHEN 'B' THEN 'BACKUP ' ELSE 'RESTORE ' END
										+ CASE [TYPE] WHEN 'D' THEN 'DATABASE' ELSE 'LOG' END
										,'BACKUP','BACKING UP'),'RESTORE','RESTORING') + ' ' + UPPER(bs.[DBName])
										+ CHAR(13) + CHAR(10)
							+ '	           Percent Done		= '
										+ CAST((bs.[ProcessedBytes] * 100)/dbs.[DBSize] as VarChar(max)) +'%'
										+ CHAR(13) + CHAR(10)
							+ '	           Running Time		= '
										+ CAST(((DATEDIFF(s,bs.[start_date],GetDate()))/3600) as varchar) + ' hour(s), '
										+ CAST((DATEDIFF(s,bs.[start_date],GetDate())%3600)/60 as varchar) + ' min(s), '
										+ CAST((DATEDIFF(s,bs.[start_date],GetDate())%60) as varchar) + ' sec(s)'
										+ CHAR(13) + CHAR(10)
							+ CHAR(13) + CHAR(10)
							, ''
							)
		FROM		#BackupStats bs
		LEFT JOIN	DBSizes dbs
				ON	bs.[DBName] = dbs.[DBName]


		PRINT @Msg
	END
	ELSE
	BEGIN


		;WITH		DBSizes
					AS
					(
					Select		DB_NAME(database_id) [DBName]
								,SUM(cast(size AS bigint) * 8 * 1024) [DBSize]
					From		sys.master_files
					GROUP BY	DB_NAME(database_id)
					)
		SELECT		r.command																			[Command]
					,UPPER(DB_NAME([database_id]))														[DBName]
					,[percent_complete]
					, CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ' hour(s), '
						+ CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + ' min(s), '
						+ CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ' sec(s)'			[Running Time]
					,CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
						+ CAST((estimated_completion_time %3600000)/60000 as varchar) + ' min(s), '
						+ CAST((estimated_completion_time %60000)/1000 as varchar) + ' sec(s)'			[Remaining Time]
					,CAST(dateadd(second,estimated_completion_time/1000, getdate()) as VarChar(max))	[Completion Time]
		FROM		sys.dm_exec_requests r
		WHERE		r.command IN ('RESTORE DATABASE', 'BACKUP DATABASE', 'RESTORE LOG', 'BACKUP LOG')

		UNION


		SELECT		CASE [Process] WHEN 'B' THEN 'BACKUP ' ELSE 'RESTORE ' END
						+ CASE [TYPE] WHEN 'D' THEN 'DATABASE' ELSE 'LOG' END							[Command]
					,bs.[DBName]																		[DBName]
					,(bs.[ProcessedBytes] * 100)/dbs.[DBSize]											[percent_complete]
					, CAST(((DATEDIFF(s,bs.[start_date],GetDate()))/3600) as varchar) + ' hour(s), '
						+ CAST((DATEDIFF(s,bs.[start_date],GetDate())%3600)/60 as varchar) + ' min(s), '
						+ CAST((DATEDIFF(s,bs.[start_date],GetDate())%60) as varchar) + ' sec(s)'		[Running Time]
					,NULL																				[Remaining Time]
					,NULL																				[Completion Time]
		FROM		#BackupStats bs
		LEFT JOIN	DBSizes dbs
				ON	bs.[DBName] = dbs.[DBName]

	END


	DROP TABLE #BackupStats
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupRestoreStatus] TO [public]
GO
