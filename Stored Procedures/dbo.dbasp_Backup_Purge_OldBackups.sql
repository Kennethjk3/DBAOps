SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Purge_OldBackups]
								(
								@BkUpPath			VarChar(1024)	= NULL
								,@IncludeSubDir		BIT				= 1
								,@NoDelete			BIT				= 1
								,@ShowSets			BIT				= 1
								)
AS
SET NOCOUNT ON
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	08/08/2017	Steve Ledridge			New process .
--	======================================================================================

DROP TABLE IF EXISTS #AllFiles
DROP TABLE IF EXISTS #FilesToDelete

DECLARE		@Data						XML
			,@Files						INT
			,@Space						BIGINT
			,@SpaceTxt					VARCHAR(50)
			,@FreeSpaceBefore			BIGINT
			,@FreeSpaceAfter			BIGINT
			,@SpaceCleared				BIGINT


DECLARE		 @RootNetworkBackups		VARCHAR(8000)	
			,@RootNetworkFailover		VARCHAR(8000)	
			,@RootNetworkArchive		VARCHAR(8000)	
			,@RootNetworkClean			VARCHAR(8000)

		----   GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
		EXEC DBAOps.dbo.dbasp_GetPaths
			@RootNetworkBackups		= @RootNetworkBackups	OUT	
			,@RootNetworkFailover	= @RootNetworkFailover	OUT	
			,@RootNetworkArchive	= @RootNetworkArchive	OUT
			,@RootNetworkClean		= @RootNetworkClean		OUT
			,@FP					= 1

SET		@BkUpPath = COALESCE(@BkUpPath,@RootNetworkClean)

SELECT	@FreeSpaceBefore = DBAOps.[dbo].[dbaudf_GetFileProperty](@BkUpPath,'folder','AvailableFreeSpace')

			SELECT		*
						,REVERSE(DBAOps.dbo.dbaudf_ReturnPart(REVERSE(REPLACE(Directory,'\','|')),1)) [ServerName]
			INTO		#AllFiles
			FROM		dbo.dbaudf_BackupScripter_GetBackupFiles2('',@BkUpPath,@IncludeSubDir,'')
			WHERE		Extension IN ('.bak','.cbak','.trn','.ctrn','.dif','.cdif')

			SELECT		*
			INTO		#FilesToDelete			
			FROM		(
						SELECT		T1.*
									,T2.[SeqNo]
						FROM		#AllFiles T1
						JOIN		(
									SELECT		*
												,ROW_NUMBER() OVER(PARTITION BY ServerName,DBName,BatchHistoryLogID ORDER BY BackupTimeStamp DESC) [SeqNo]
									FROM		(
												SELECT		DISTINCT
															ServerName
															,DBName
															,BatchHistoryLogID
															,Mask
															,BackupTimeStamp
												FROM		#AllFiles
												) Data
									) T2											ON T1.Mask = T2.Mask
						) Data
			ORDER BY	 ServerName
						,DBName
						,BatchHistoryLogID
						,[SeqNo]



IF @ShowSets = 1
BEGIN

	SELECT		'ALL' [Status]
				,ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
				,COUNT(*)	[Files]
				,SUM(Size)	[Size]
	FROM		#FilesToDelete
	GROUP BY	ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
	ORDER BY	1,2,3,4,5


	SELECT		'KEEP' [Status]
				,ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
				,COUNT(*)	[Files]
				,SUM(Size)	[Size]
	FROM		#FilesToDelete
	WHERE		[seqNo] IN(1,2)
	GROUP BY	ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
	ORDER BY	ServerName
				,DBName
				,ISNULL(BatchHistoryLogID,999999)
				,ISNULL(BackupTimeStamp,'3000-01-01')
				,ISNULL(Mask,'zzzzzzzzzzzzzzzzz')

	SELECT		'DELETE' [Status]
				,ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
				,COUNT(*)	[Files]
				,SUM(Size)	[Size]
	FROM		#FilesToDelete
	WHERE		[seqNo] > 2
	GROUP BY	ServerName
				,DBName
				,[seqNo]
				,BatchHistoryLogID
				,BackupTimeStamp
				,Mask
				
	ORDER BY	1,2,3,4,5
END			

SELECT		@Files		= COUNT(*)
			,@Space		= SUM(Size)
FROM		#FilesToDelete

SET		@SpaceTxt = DBAOps.dbo.dbaudf_FormatBytes(@Space,'bytes')

RAISERROR ('Removing %d Files totaling %s.',-1,-1,@Files,@SpaceTxt) WITH NOWAIT


RAISERROR ('Create XML for Delete Old Tranloags',-1,-1) WITH NOWAIT
IF EXISTS (SELECT * FROM #FilesToDelete)
	SELECT @Data =	(
					SELECT		FullPathName [Source]
					FROM		#FilesToDelete
					WHERE		[seqNo] > 2
					FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
					)

select  @Data [Files Removed]


RAISERROR ('Delete Old Tranloags',-1,-1) WITH NOWAIT


If @Data is not NULL AND @NoDelete = 0
	exec DBAOps.dbo.dbasp_FileHandler @Data

SELECT	@FreeSpaceAfter = DBAOps.[dbo].[dbaudf_GetFileProperty](@BkUpPath,'folder','AvailableFreeSpace')

SET		@SpaceTxt = DBAOps.dbo.dbaudf_FormatBytes(@FreeSpaceBefore,'bytes')
RAISERROR ('Free Space Before		: %s.',-1,-1,@SpaceTxt) WITH NOWAIT

SET		@SpaceTxt = DBAOps.dbo.dbaudf_FormatBytes(@FreeSpaceAfter,'bytes')
RAISERROR ('Free Space After		: %s.',-1,-1,@SpaceTxt) WITH NOWAIT

SET		@SpaceTxt = DBAOps.dbo.dbaudf_FormatBytes(@FreeSpaceAfter - @FreeSpaceBefore,'bytes')
RAISERROR ('Actual Space Cleared	: %s.',-1,-1,@SpaceTxt) WITH NOWAIT


SELECT	 @RootNetworkBackups	[RootNetworkBackups Path]
		,@RootNetworkFailover	[RootNetworkFailover Path]
		,@RootNetworkArchive	[RootNetworkArchive Path]
		,@RootNetworkClean		[RootNetworkClean Path]

SELECT	 CASE WHEN @RootNetworkBackups IS NULL	THEN '??' ELSE	DBAOps.[dbo].[dbaudf_FormatBytes](DBAOps.[dbo].[dbaudf_GetFileProperty](@RootNetworkBackups	,'folder','AvailableFreeSpace'),'bytes') END	[RootNetworkBackups Free Space]
		,CASE WHEN @RootNetworkFailover IS NULL THEN '??' ELSE	DBAOps.[dbo].[dbaudf_FormatBytes](DBAOps.[dbo].[dbaudf_GetFileProperty](@RootNetworkFailover,'folder','AvailableFreeSpace'),'bytes') END	[RootNetworkFailover Free Space]
		,CASE WHEN @RootNetworkArchive IS NULL	THEN '??' ELSE	DBAOps.[dbo].[dbaudf_FormatBytes](DBAOps.[dbo].[dbaudf_GetFileProperty](@RootNetworkArchive	,'folder','AvailableFreeSpace'),'bytes') END	[RootNetworkArchive Free Space]
		,CASE WHEN @RootNetworkClean IS NULL	THEN '??' ELSE	DBAOps.[dbo].[dbaudf_FormatBytes](DBAOps.[dbo].[dbaudf_GetFileProperty](@RootNetworkClean	,'folder','AvailableFreeSpace'),'bytes') END	[RootNetworkClean Free Space]
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Purge_OldBackups] TO [public]
GO
