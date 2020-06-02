SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CheckRequiredShares]
	@StopOnFail	BIT = 0
AS
	-- RETURNS NUMBER OF MISSING SHARES
SET NOCOUNT ON
BEGIN	-- CHECK AND FIX LOCAL ADMIN SHARES
	DECLARE	@Results int = 0
	DECLARE	@ShareTest Table	([ShareName] SYSNAME, [Required] bit, [Found] bit)


	;WITH	SharesToCheck ([ShareName],[Required])
			AS
			(
			SELECT 'BulkDataLoad',1			UNION ALL
			SELECT 'SQLBackups',1			UNION ALL
			SELECT 'CRM-Composer Sync2',0	UNION ALL
			SELECT 'FileDrop',0				UNION ALL
			SELECT 'Imageupload',0			UNION ALL
			SELECT 'Intellidon',0			UNION ALL
			SELECT 'SQLServerAgent',0		UNION ALL
			SELECT 'AirCommission',0		UNION ALL
			SELECT 'ExcelImport',0			UNION ALL
			SELECT 'Globalmatrix',0			UNION ALL
			SELECT 'GRASP',0				UNION ALL
			SELECT 'OLAP',0					UNION ALL
			SELECT 'Sync',0					UNION ALL
			SELECT 'JRB_tst',0				UNION ALL
			SELECT 'SSIS',0					UNION ALL
			SELECT 'OLAPBackup',0


			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_backup',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_base',0		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_builds',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dbasql',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dba_archive',1	UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dba_mail',0	UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_filescan',0	UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_ldf',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_log',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_mdf',1		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_nxt',0		UNION ALL
			--SELECT REPLACE(@@SERVERNAME,'\','$')+'_SQLjob_logs',1
			)
	INSERT	@ShareTest
	select	T1.[ShareName],T1.[Required],CASE T1.ShareName WHEN T2.ShareName Then 1 ELSE 0 END [Found]
	FROM		SharesToCheck T1
	LEFT JOIN	DBAOps.[dbo].[dbaudf_ListShares]() T2
		ON	T1.ShareName = T2.ShareName


	SELECT @Results = count(*) FROM @ShareTest WHERE [Required] = 1 and [Found] = 0


	IF @Results > 0
	BEGIN
		--SET @Results = 0
		----REBUILD SHARES
		--EXEC		dbo.dbasp_dba_sqlsetup


		---- RECHECK COUNT
		--DELETE FROM @ShareTest;


		--;WITH	SharesToCheck ([ShareName],[Required])
		--		AS
		--		(
		--		SELECT 'BulkDataLoad',1			UNION ALL
		--		SELECT 'SQLBackups',1			UNION ALL
		--		SELECT 'CRM-Composer Sync2',0	UNION ALL
		--		SELECT 'FileDrop',0				UNION ALL
		--		SELECT 'Imageupload',0			UNION ALL
		--		SELECT 'Intellidon',0			UNION ALL
		--		SELECT 'SQLServerAgent',0		UNION ALL
		--		SELECT 'AirCommission',0		UNION ALL
		--		SELECT 'ExcelImport',0			UNION ALL
		--		SELECT 'Globalmatrix',0			UNION ALL
		--		SELECT 'GRASP',0				UNION ALL
		--		SELECT 'OLAP',0					UNION ALL
		--		SELECT 'Sync',0					UNION ALL
		--		SELECT 'JRB_tst',0				UNION ALL
		--		SELECT 'SSIS',0					UNION ALL
		--		SELECT 'OLAPBackup',0


		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_backup',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_base',0		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_builds',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dbasql',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dba_archive',1	UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_dba_mail',0	UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_filescan',0	UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_ldf',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_log',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_mdf',1		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_nxt',0		UNION ALL
		--		--SELECT REPLACE(@@SERVERNAME,'\','$')+'_SQLjob_logs',1
		--		)
		--INSERT	@ShareTest
		--select	T1.[ShareName],T1.[Required],CASE T1.ShareName WHEN T2.ShareName Then 1 ELSE 0 END [Found]
		--FROM		SharesToCheck T1
		--LEFT JOIN	DBAOps.[dbo].[dbaudf_ListShares]() T2
		--	ON	T1.ShareName = T2.ShareName


		--SELECT @Results = count(*) FROM @ShareTest WHERE [Required] = 1 and [Found] = 0


		IF @Results > 0
		BEGIN
			IF @StopOnFail = 1
				RAISERROR(' -- REQUIRED DEFAULT OPPERATIONS SHARES MUST EXIST BEFORE THIS SCRIPT CAN RUN.',20,-1) WITH LOG
			ELSE
				RAISERROR(' -- REQUIRED DEFAULT OPPERATIONS SHARES DO NOT EXIST.',-1,-1) WITH LOG
			RETURN @Results
		END
	END

	RAISERROR(' -- REQUIRED DEFAULT OPPERATIONS SHARES EXIST.',-1,-1) WITH NOWAIT
	RETURN @Results


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_CheckRequiredShares] TO [public]
GO
