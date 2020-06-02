SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetPaths]
(
	@DataPath					VarChar(8000)	= NULL	OUT
	,@LogPath					VarChar(8000)	= NULL	OUT
	,@BackupPathL				VarChar(8000)	= NULL	OUT		-- Local
	,@BackupPathN				VarChar(8000)	= NULL	OUT		-- Primary Network
	,@BackupPathN2				VarChar(8000)	= NULL	OUT		-- Failover Network
	,@BackupPathA				VarChar(8000)	= NULL	OUT		-- Network Archive
	,@RootSDTBackups			VarChar(8000)	= NULL	OUT		-- SDT DEVELOPER SHARE FOR CLEAN BACKUPS
	,@DBASQLPath				VarChar(8000)	= NULL	OUT
	,@SQLAgentLogPath			VarChar(8000)	= NULL	OUT
	,@DBAArchivePath			VarChar(8000)	= NULL	OUT
	,@EnvBackupPath				VarChar(8000)	= NULL	OUT
	,@SQLEnv					VarChar(10)		= NULL	OUT
	,@RootNetworkBackups		VarChar(8000)	= NULL	OUT
	,@RootNetworkFailover		VARCHAR(8000)	= NULL	OUT
	,@RootNetworkArchive		VARCHAR(8000)	= NULL	OUT
	,@RootNetworkClean			VARCHAR(8000)	= NULL	OUT
	,@CentralServer				VARCHAR(8000)	= NULL	OUT
	,@CentralServerShare		VARCHAR(8000)	= NULL	OUT
	,@Verbose					INT				= 0
	,@FP						BIT				= 0				-- ONLY USE FOR TESTING
)
AS
BEGIN

	-- EXEC DBAOps.[dbo].[dbasp_GetPaths] @Verbose =1

	SELECT		@RootNetworkBackups		= COALESCE(@RootNetworkBackups	,'\\SDCPROFS.${{secrets.DOMAIN_NAME}}\DatabaseBackups\')		
				,@RootNetworkFailover	= COALESCE(@RootNetworkFailover	,'\\sdcpronas02.${{secrets.DOMAIN_NAME}}\SQLBackup-Failover\')		
				,@RootNetworkArchive	= COALESCE(@RootNetworkArchive	,'\\SDCPROFS.${{secrets.DOMAIN_NAME}}\databasearchive\')	
				,@RootNetworkClean		= COALESCE(@RootNetworkClean	,'\\SDCPROFS.${{secrets.DOMAIN_NAME}}\CleanBackups\')
				,@RootSDTBackups		= COALESCE(@RootSDTBackups		,'\\SDTPRONAS01.${{secrets.DOMAIN_NAME}}\Backup\CleanBackups\')
				,@CentralServer			= COALESCE(@CentralServer		,'SDCSQLTOOLS.DB.${{secrets.DOMAIN_NAME}}')
				,@CentralServerShare	= COALESCE(@CentralServerShare	,'\\'+@CentralServer+'\dba_reports\')

	DECLARE		@PathAndFile			VarChar(8000)  

SELECT		@SQLEnv						= CASE
											WHEN @@ServerName Like 'SDT%'	THEN 'DESK'
											WHEN @@ServerName Like 'SEA%'	THEN 'DESK'
											WHEN @@ServerName Like '%PRO%'	THEN 'PRO'
											WHEN @@ServerName Like '%STG%'	THEN 'STG'
											WHEN @@ServerName Like '%CPI%'	THEN 'CPI'
											WHEN @@ServerName Like '%QA1%'	THEN 'QA1'
											WHEN @@ServerName Like '%QA2%'	THEN 'QA2'
											WHEN @@ServerName Like '%QA%'	THEN 'QA'
											WHEN @@ServerName Like '%DEV1%' THEN 'DEV1'
											WHEN @@ServerName Like '%DEV2%' THEN 'DEV2'
											WHEN @@ServerName Like '%DEV%'	THEN 'DEV'
											WHEN @@ServerName Like '%RELEASE%'	THEN 'REL'
											WHEN @@ServerName Like '%TST%'	THEN 'TST'
											WHEN @@ServerName Like '%BACKLOG%'	THEN 'BLOG'
											WHEN @@ServerName Like '%PREVIEW%'	THEN 'PRV'
											WHEN @@Servername IN ('SDCSQLBACKUPMGR','SDCSQLTOOLS','','','','','') THEN 'PRO'
											ELSE 'OTHER' END

IF @FP = 1 SET @SQLEnv = 'PRO'

IF @Verbose > 0 RAISERROR('-- @SQLEnv				[%s].',-1,-1,@SQLEnv) WITH NOWAIT

-- GET PATHS
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData',		@DataPath		output, 'no_output' 
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog',		@LogPath		output, 'no_output' 
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory',	@BackupPathL	output, 'no_output' 

IF (@DataPath is null) 
BEGIN 
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @DataPath output, 'no_output' 
	SELECT @DataPath = @DataPath + N'\Data' 
END

IF (@LogPath is null) 
BEGIN 
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @LogPath output, 'no_output' 
	SELECT @LogPath = @LogPath + N'\Data' 
END


-- FORCE TRAILING "\"
IF RIGHT(@BackupPathL,1) != '\' SET @BackupPathL = @BackupPathL + '\'

IF @SQLEnv IN ('PRO','STG')
	SELECT		@BackupPathN			= COALESCE(@RootNetworkBackups	+ UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN()) +'\',@BackupPathL) -- DEFAULT TO LOCAL PATH IF FQDN IS NULL
				,@BackupPathN2			= COALESCE(@RootNetworkFailover	+ UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN()) +'\',@BackupPathL) -- DEFAULT TO LOCAL PATH IF FQDN IS NULL
				,@BackupPathA			= @RootNetworkArchive			+ UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN()) +'\' 
ELSE
	SELECT		@BackupPathN			= CASE @SQLEnv
											WHEN  'DESK' 
											THEN @RootSDTBackups + UPPER(COALESCE(DBAOps.dbo.dbaudf_GetLocalFQDN(),@@SERVERNAME+'.${{secrets.DOMAIN_NAME}}'))+'\'
											ELSE COALESCE(@RootNetworkClean + UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN()) +'\',@BackupPathL) -- DEFAULT TO LOCAL PATH IF FQDN IS NULL
											END
				,@BackupPathN2			= NULL
				,@BackupPathA			= NULL
				,@RootNetworkBackups	= @RootNetworkClean --+ UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN()) +'\'
				,@RootNetworkFailover	= NULL
				,@RootNetworkArchive	= NULL




SELECT		@DBASQLPath			= @BackupPathL + 'dbasql\'
			,@SQLAgentLogPath	= @BackupPathL + 'SQLAgentLogs\'
			,@DBAArchivePath	= @BackupPathL + 'dba_archive\'


-- GET ENVIRO OVERRIDE
SELECT		@EnvBackupPath		= env_detail
FROM		DBAOps.dbo.local_serverenviro
WHERE		env_type			= 'backup_path'

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--									VALIDATE EACH PATH
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
--		@DataPath
--------------------------------------------------------------------------------------------
IF @BackupPathL IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @DataPath + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@DataPath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@DataPath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@DataPath) WITH NOWAIT
		SET @DataPath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @DataPath			[%s].',-1,-1,@BackupPathL) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@LogPath
--------------------------------------------------------------------------------------------
IF @LogPath IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @LogPath + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@LogPath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@LogPath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@LogPath) WITH NOWAIT
		SET @LogPath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @LogPath				[%s].',-1,-1,@LogPath) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@BackupPathL
--------------------------------------------------------------------------------------------
IF @BackupPathL IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @BackupPathL + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@BackupPathL) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@BackupPathL,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@BackupPathL) WITH NOWAIT
		SET @BackupPathL = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @BackupPathL			[%s].',-1,-1,@BackupPathL) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@BackupPathN
--------------------------------------------------------------------------------------------
IF @BackupPathN IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @BackupPathN + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@BackupPathN) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@BackupPathN,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@BackupPathN) WITH NOWAIT
		SET @BackupPathN = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @BackupPathN			[%s].',-1,-1,@BackupPathN) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@BackupPathN2
--------------------------------------------------------------------------------------------
IF @BackupPathN2 IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @BackupPathN2 + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@BackupPathN2) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@BackupPathN2,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@BackupPathN2) WITH NOWAIT
		SET @BackupPathN2 = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @BackupPathN2		[%s].',-1,-1,@BackupPathN2) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@BackupPathA
--------------------------------------------------------------------------------------------
IF @BackupPathA IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @BackupPathA + 'tests.txt'
	BEGIN TRY
		exec [dbaops].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC [dbaops].[dbo].[dbasp_GetErrorInfo]
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@BackupPathA) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@BackupPathA,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@BackupPathA) WITH NOWAIT
		SET @BackupPathA = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @BackupPathA			[%s].',-1,-1,@BackupPathA) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@EnvBackupPath
--------------------------------------------------------------------------------------------
IF @EnvBackupPath IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @EnvBackupPath + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@EnvBackupPath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@EnvBackupPath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@EnvBackupPath) WITH NOWAIT
		SET @EnvBackupPath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @EnvBackupPath		[%s].',-1,-1,@EnvBackupPath) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@DBASQLPath
--------------------------------------------------------------------------------------------
IF @DBASQLPath IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @DBASQLPath + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@DBASQLPath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@DBASQLPath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@DBASQLPath) WITH NOWAIT
		SET @DBASQLPath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @DBASQLPath			[%s].',-1,-1,@DBASQLPath) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@SQLAgentLogPath
--------------------------------------------------------------------------------------------
IF @SQLAgentLogPath IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @SQLAgentLogPath + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@SQLAgentLogPath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@SQLAgentLogPath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@SQLAgentLogPath) WITH NOWAIT
		SET @SQLAgentLogPath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @SQLAgentLogPath		[%s].',-1,-1,@SQLAgentLogPath) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@DBAArchivePath
--------------------------------------------------------------------------------------------
IF @DBAArchivePath IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @DBAArchivePath + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@DBAArchivePath) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@DBAArchivePath,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@DBAArchivePath) WITH NOWAIT
		SET @DBAArchivePath = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @DBAArchivePath		[%s].',-1,-1,@DBAArchivePath) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@RootNetworkBackups
--------------------------------------------------------------------------------------------
IF @RootNetworkBackups IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @RootNetworkBackups + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@RootNetworkBackups) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@RootNetworkBackups,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@RootNetworkBackups) WITH NOWAIT
		SET @RootNetworkBackups = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @RootNetworkBackups	[%s].',-1,-1,@RootNetworkBackups) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@RootNetworkFailover
--------------------------------------------------------------------------------------------
IF @RootNetworkFailover IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @RootNetworkFailover + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@RootNetworkFailover) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@RootNetworkFailover,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@RootNetworkFailover) WITH NOWAIT
		SET @RootNetworkFailover = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @RootNetworkFailover	[%s].',-1,-1,@RootNetworkFailover) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@RootNetworkArchive
--------------------------------------------------------------------------------------------
IF @RootNetworkArchive IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @RootNetworkArchive + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@RootNetworkArchive) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@RootNetworkArchive,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@RootNetworkArchive) WITH NOWAIT
		SET @RootNetworkArchive = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @RootNetworkArchive	[%s].',-1,-1,@RootNetworkArchive) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@RootNetworkClean
--------------------------------------------------------------------------------------------
IF @RootNetworkClean IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @RootNetworkClean + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@RootNetworkClean) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@RootNetworkClean,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@RootNetworkClean) WITH NOWAIT
		SET @RootNetworkClean = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @RootNetworkClean	[%s].',-1,-1,@RootNetworkClean) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@RootSDTBackups
--------------------------------------------------------------------------------------------
IF @RootSDTBackups IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @RootSDTBackups + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@RootSDTBackups) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@RootSDTBackups,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@RootSDTBackups) WITH NOWAIT
		SET @RootSDTBackups = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @RootSDTBackups		[%s].',-1,-1,@RootSDTBackups) WITH NOWAIT
--------------------------------------------------------------------------------------------
--		@CentralServerShare
--------------------------------------------------------------------------------------------
IF @CentralServerShare IS NOT NULL
BEGIN
	SELECT	@PathAndFile = @CentralServerShare + 'tests.txt'
	BEGIN TRY
		exec DBAOps.[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS
		SET @PathAndFile = NULL;
	END TRY
	BEGIN CATCH
		--EXEC DBAOps.dbo.dbasp_GetErrorInfo
		IF @Verbose > 0 RAISERROR('-- Unable to perform Test Write to Location [%s].',-1,-1,@CentralServerShare) WITH NOWAIT
	END CATCH

	IF [dbaops].[dbo].[dbaudf_GetFileProperty] (@CentralServerShare,'folder','Exists') != 'True'
	BEGIN
		IF @Verbose > 0 RAISERROR('-- Location [%s] is NOT valid and will be ignored',-1,-1,@CentralServerShare) WITH NOWAIT
		SET @CentralServerShare = null;
	END
END
IF @Verbose > 0 RAISERROR('-- @CentralServerShare	[%s].',-1,-1,@CentralServerShare) WITH NOWAIT
IF @Verbose > 0 RAISERROR('-- @CentralServer		[%s].',-1,-1,@CentralServer) WITH NOWAIT

IF @Verbose > 1
SELECT	 @DataPath					[DataPath]				
		,@LogPath					[LogPath]				
		,@BackupPathL				[BackupPathL]			
		,@BackupPathN				[BackupPathN]			
		,@BackupPathN2				[BackupPathN2]			
		,@BackupPathA				[BackupPathA]			
		,@DBASQLPath				[DBASQLPath]			
		,@SQLAgentLogPath			[SQLAgentLogPath]		
		,@DBAArchivePath			[DBAArchivePath]		
		,@EnvBackupPath				[EnvBackupPath]			
		,@SQLEnv					[SQLEnv]				
		,@RootNetworkBackups		[RootNetworkBackups]	
		,@RootNetworkFailover		[RootNetworkFailover]	
		,@RootNetworkArchive		[RootNetworkArchive]	
		,@RootNetworkClean			[RootNetworkClean]		
		,@CentralServer				[CentralServer]
		,@CentralServerShare		[CentralServerShare]
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetPaths] TO [public]
GO
