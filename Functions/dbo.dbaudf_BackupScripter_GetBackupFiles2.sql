SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_BackupScripter_GetBackupFiles2]
				(
				@DBName				SYSNAME			--= 'MDI'
				,@FilePath			VARCHAR(max)	--= '\\SDCPROFS.${{secrets.DOMAIN_NAME}}\CleanBackups\SDCPROSSSQL01.DB.${{secrets.DOMAIN_NAME}}\'
				,@IncludeSubDir		bit				= 0
				,@ForceFileName		VarChar(max)	= null
				)
RETURNS TABLE
AS
--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/05/2015	Steve Ledridge		Modified process to exclude similarly named databases
--	03/09/2015	Steve Ledridge		Fixed problem where last fix was excluding forced name lookups.

RETURN
(
	SELECT		DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'_SET_[0-9][0-9]_OF_[0-9][0-9]','_SET_[0-9][0-9]_OF_[0-9][0-9]') [Mask]
			,T1.Name
			--,@DBName
			,REPLACE
				(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
					DBAOps.dbo.dbaudf_RegexReplace
						(
						DBAOps.dbo.dbaudf_RegexReplace
							(
							DBAOps.dbo.dbaudf_RegexReplace
								(
								T1.Name
								,'_SET_[0-9][0-9]_OF_[0-9][0-9]'
								,''
								)
							,'_20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9][0-5][0-9][._]'
							,'.'
							)
						,'_FG[$][\w]+'
						,''
						)
					,'_DFNTL.'
					,'.'
					)
					,'_DB_CLN_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].'
					,'.'
					)
					,'_DB.'
					,'.'
					)
					,'_TLOG.'
					,'.'
					)

				,T1.Extension
				,''
				)							[DBName]
			,	CAST(STUFF(STUFF(STUFF(STUFF(STUFF((
				SELECT	TOP 1 SUBSTRING(Text,2,14)
				FROM	DBAOps.dbo.dbaudf_RegexMatches(T1.Name,'_20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9][0-5][0-9][._]')
				),13,0,':'),11,0,':'),9,0,' '),7,0,'-'),5,0,'-') AS DATETIME) [BackupTimeStamp]
			,CASE	WHEN CHARINDEX('_CLN_DB_',T1.Name,1) > 1 THEN 'PI' 
												WHEN CHARINDEX('_DFNTL_',T1.Name,1) > 1 THEN 'DF'
												WHEN CHARINDEX('_FG',T1.Name,1) > 1 THEN 'FG'
												WHEN CHARINDEX('_TLOG_',T1.Name,1) > 1 THEN 'TL'
												WHEN CHARINDEX('_BASE_',T1.Name,1) > 1 THEN 'DB'
												WHEN T1.Extension = '.trn' THEN 'TL'
												WHEN T1.Extension = '.ctrn' THEN 'TL'
												WHEN CHARINDEX('_DB_',T1.Name,1) > 1 THEN 'DB'
												ELSE '??' END BackupType
			,CASE T1.Extension
				WHEN '.sqb' THEN 'RedGate'
				WHEN '.sqd' THEN 'RedGate'
				WHEN '.sqt' THEN 'RedGate'
				ELSE 'Microsoft' END [BackupEngine]
			,	ISNULL((
				SELECT	TOP 1 CAST(DBAOps.dbo.dbaudf_ReturnPart(REPLACE(Text,'_','|'),2) AS INT)
				FROM	DBAOps.dbo.dbaudf_RegexMatches(T1.Name,'SET_[0-9][0-9]_OF_[0-9][0-9]')
				),1) [BackupSetNumber]
			,	ISNULL((
				SELECT	TOP 1 CAST(DBAOps.dbo.dbaudf_ReturnPart(REPLACE(Text,'_','|'),4) AS INT)
				FROM	DBAOps.dbo.dbaudf_RegexMatches(T1.Name,'SET_[0-9][0-9]_OF_[0-9][0-9]')
				),1) [BackupSetSize]
			,	ISNULL((
				SELECT	TOP 1 CAST(DBAOps.dbo.dbaudf_ReturnPart(REPLACE(Text,'_','|'),3) AS INT)
				FROM	DBAOps.dbo.dbaudf_RegexMatches(T1.Name,'DB_CLN_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
				),0) [BatchHistoryLogID]

			,CASE WHEN T1.Name LIKE @DBName+'_DB_FG_%'
				THEN	(
					SELECT	REPLACE(REPLACE([DBAOps].[dbo].[dbaudf_Concatenate]([SplitValue]),',','_'),'FG$','')
					FROM	(
						SELECT	*
						FROM	[DBAOps].[dbo].[dbaudf_StringToTable](REPLACE(REPLACE(REPLACE(REPLACE(T1.Name,'_DB_FG_','_FG$'),'_','|'),'.','|'),REPLACE(@DBName,'_','|'),@DBName),'|')
						) D
					WHERE	OccurenceID > 1
						AND	OccurenceID < (SELECT max(OccurenceID) FROM [DBAOps].[dbo].[dbaudf_StringToTable](REPLACE(REPLACE(REPLACE(REPLACE(DBAOps.dbo.dbaudf_RegexReplace(T1.Name,'_SET_[0-9][0-9]_OF_[0-9][0-9]',''),'_DB_FG_','_FG$'),'_','|'),'.','|'),REPLACE(@DBName,'_','|'),@DBName),'|')) - 1
					)
				END [FileGroup]
			,T1.FullPathName
			,T1.Directory
			,T1.Extension
			,T1.DateCreated
			,T1.DateAccessed
			,T1.DateModified
			,T1.Attributes
			,T1.Size
	FROM		DBAOps.dbo.dbaudf_DirectoryList2(@FilePath,COALESCE(nullif(@ForceFileName,''),@DBName)+'*',@IncludeSubDir) T1
	--JOIN		(
	--		SELECT	@DBName+'_DB_%' [Name],'DB' [BackupType]
	--		UNION ALL
	--		SELECT	@DBName+'_CLN_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_%' [Name],'PI'
	--		UNION ALL
	--		SELECT	@DBName+'_FG$%','FG'
	--		UNION ALL
	--		SELECT	@DBName+'_DFNTL_%','DF'
	--		UNION ALL
	--		SELECT	@DBName+'_TLOG_%','TL'
	--		UNION ALL
	--		SELECT	@DBName+'%.trn','TL'
	--		UNION ALL
	--		SELECT	@DBName+'_BASE_%','DB'
	--		UNION ALL
	--		SELECT	@ForceFileName +'%','??'
	--		) T2
	--	ON	REPLACE(REPLACE(T1.[Name],'_DB_FG_','_FG$'),'_DB_CLN_','_CLN_') LIKE T2.Name
	WHERE		REPLACE
				(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
				DBAOps.dbo.dbaudf_RegexReplace
					(
					DBAOps.dbo.dbaudf_RegexReplace
						(
						DBAOps.dbo.dbaudf_RegexReplace
							(
							DBAOps.dbo.dbaudf_RegexReplace
								(
								T1.Name
								,'_SET_[0-9][0-9]_OF_[0-9][0-9]'
								,''
								)
							,'_20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9][0-5][0-9][0-5][0-9][._]'
							,'.'
							)
						,'_FG[$][\w]+'
						,''
						)
					,'_DFNTL.'
					,'.'
					)
					,'_DB_CLN_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].'
					,'.'
					)
					,'_DB.'
					,'.'
					)
					,'_TLOG.'
					,'.'
					)

				,T1.Extension
				,''
				) = @DBName
		OR	T1.Name Like @ForceFileName +'%'
)
GO
