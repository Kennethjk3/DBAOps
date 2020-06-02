SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Tranlog_Cleanup] (@BkUpPath varchar(255) = null
					,@BkUpSaveDays int = 2
					,@ForceLocal BIT = 0
					)

/***************************************************************
 **  Stored Procedure dbasp_Tranlog_Cleanup
 **  Written by Steve Ledridge, Virtuoso
 **  November 20, 2012
 **
 **  This proc accepts the following input parms (none are required):
 **  @BkUpPath      - Full path where the backup files live.
 **  @BkUpSaveDays  - Number of days to save the backup files (defaul is 2).
 **  @ForceLocal    - (0=off, 1=on) will force the backup process to the local backup share.
 **
 **
 **  This procedure deletes older transaction log backup files.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	11/20/2012	Steve Ledridge			New process removed from tranlog backup sproc.
--	11/20/2013	Steve Ledridge			Converted to XML delete process.
--	05/28/2015	Steve Ledridge			Added input parm @ForceLocal.
--	======================================================================================


/***
Declare @BkUpPath varchar(255)
Declare @BkUpSaveDays smallint


Select @BkUpPath = null
Select @BkUpSaveDays = 2
--***/


Declare		@save_servername			sysname
			,@save_servername2			sysname
			,@save_servername3			sysname
			,@parm01					varchar(100)
			,@charpos					int
			,@save_delete_mask_tlog		sysname
			,@delete_Data_tlog			XML


DECLARE		@CMD						VarChar(8000)
CREATE TABLE	#FilesToDelete (FullPathName VarChar(4000))


DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@PathAndFile				VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					SYSNAME
			,@central_server			SYSNAME

	EXEC DBAOps.dbo.dbasp_GetPaths -- @verbose = 1
		 @DataPath			= @DataPath			 OUT
		,@LogPath			= @LogPath			 OUT
		,@BackupPathL		= @BackupPathL		 OUT
		,@BackupPathN		= @BackupPathN		 OUT
		,@BackupPathN2		= @BackupPathN2		 OUT
		,@DBASQLPath		= @DBASQLPath		 OUT
		,@SQLAgentLogPath	= @SQLAgentLogPath	 OUT
		,@DBAArchivePath	= @DBAArchivePath	 OUT
		,@EnvBackupPath		= @EnvBackupPath	 OUT
		,@SQLEnv			= @SQLEnv			 OUT
		,@CentralServerShare= @central_server	 OUT
----------------  initial values  -------------------


SET @BkUpPath = COALESCE(NULLIF(@BkUpPath,''),@EnvBackupPath,CASE WHEN @ForceLocal = 1 THEN @BackupPathL END,@BackupPathN,@BackupPathL)


--Select @save_servername		= @@servername
--Select @save_servername2	= @@servername
--Select @save_servername3	= @@servername


--Select @charpos = charindex('\', @save_servername)
--IF @charpos <> 0
--   begin
--	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


--	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


--	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
--	select @save_servername3 = @save_servername3 + ')'
--   end


----  Check input parameters
--If NULLIF(@BkUpPath,'') is null
--BEGIN
--	-- GET ENVIRO OVERRIDE
--	SELECT		@BkUpPath		= env_detail
--	FROM		dbo.local_serverenviro
--	WHERE		env_type		= 'backup_path'


--	If NULLIF(@BkUpPath,'') is null
--	BEGIN
--		IF @ForceLocal = 1
--			exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BkUpPath output
--		ELSE
--			SELECT @BkUpPath = '\\SDCSQLBACKUPFS.virtuoso.com\DatabaseBackups\' + UPPER(DBAOps.dbo.dbaudf_GetLocalFQDN())
--	END
--END


--  Make sure the @BkUpPath ends with '\'


IF RIGHT(@BkUpPath,1) != '\'
	SET @BkUpPath = @BkUpPath + '\'


/****************************************************************
 *                MainLine
 ***************************************************************/
RAISERROR ('--  START Tranlog Backup File Cleanup Process',-1,-1) WITH NOWAIT
RAISERROR ('',-1,-1) WITH NOWAIT


RAISERROR ('Backup path is %s',-1,-1,@BkUpPath) WITH NOWAIT
RAISERROR ('',-1,-1) WITH NOWAIT


--  Process to delete old tlog backup files  -------------------
RAISERROR ('Create XML for Tlog delete',-1,-1) WITH NOWAIT
RAISERROR ('',-1,-1) WITH NOWAIT


--  Set up for delete processing
Select @save_delete_mask_tlog = '*_tlog_*.*'


--DECLARE		@DBName					SYSNAME
--DECLARE		@MostRecentFullorDiff	DATETIME


--SET @DBName = 'ComposerSL'
--SELECT		@MostRecentFullorDiff = MAX(BackupTimeStamp)
--FROM		DBAOps.dbo.dbaudf_BackupScripter_GetBackupFiles(@DBName,@BkUpPath,0,null)
--WHERE		BackupType IN ('DB','DF')


SET @CMD = '
INSERT INTO #FilesToDelete
SELECT		FullPathName
FROM		DBAOps.dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BkUpPath+''',0,null)
WHERE		BackupType IN (''TL'')
	AND		DateModified < (
							SELECT		MAX(BackupTimeStamp)
							FROM		DBAOps.dbo.dbaudf_BackupScripter_GetBackupFiles(''?'','''+@BkUpPath+''',0,null)
							WHERE		BackupType IN (''DB'',''DF'')
							)'


EXEC DBAOps.dbo.dbasp_foreachdb @suppress_quotename = 1, @command = @CMD


SELECT * FROM #FilesToDelete


IF EXISTS (SELECT * FROM #FilesToDelete)
	SELECT @delete_Data_tlog =	(
								SELECT		FullPathName [Source]
								FROM		#FilesToDelete
								FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
								)


SELECT @delete_Data_tlog


Print '=========================================================================== '
Print 'Pre delete of older Tlog files using mask ' + @save_delete_mask_tlog
Print '=========================================================================== '
Print ' '


If @delete_Data_tlog is not null
	exec dbasp_FileHandler @delete_Data_tlog


--  End Processing  ---------------------------------------------------------------------------------------------

Label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Tranlog_Cleanup] TO [public]
GO
