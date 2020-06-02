SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Restore] 
					(
					@dbname							SYSNAME			= NULL
					,@NewDBName						SYSNAME			= NULL
					,@FromServer					SYSNAME			= NULL -- SHOULD BE FQDN AND IS USED TO FORCE PATH TO EXAMPLE BELOW
					,@FilePath						VarChar(MAX)	= NULL --'\\SDCSQLBACKUPFS.virtuoso.com\DatabaseBackups\{Server_FQDN}\'
					,@FileGroups					VarChar(MAX)	= NULL
					,@ForceFileName					VarChar(MAX)	= NULL
					,@RestoreToDateTime				DateTime		= NULL
					,@LeaveNORecovery				BIT				= 0
					,@IgnoreSpaceLimits				Bit				= 0
					,@NoFullRestores				BIT				= 0
					,@NoDifRestores					BIT				= 0
					,@NoLogRestores					BIT				= 1
					,@OverrideXML					XML				= NULL	
					,@BufferCount					INT				= 100
					,@MaxTransferSize				INT				= 4194304
					,@Verbose						INT				= 0
					,@FullReset						BIT				= 1
					,@WorkDir						Varchar(MAX)	= NULL
					,@DeleteWorkFiles				Bit				= 1
					,@post_shrink					BIT				= 0
					,@post_shrink_OnlyLog			Bit				= 1
					,@post_set_recovery				VarChar(50)		= 'SIMPLE'
					,@Debug							BIT				= 0
					,@NoExec						BIT				= 0
					,@NoSnap						BIT				= 0
					,@NoRevert						BIT				= 0
					,@ForceRevert					BIT				= 0
					,@IgnoreAGRestrict				BIT				= 0
					,@ForceBHLID					INT				= NULL
					,@DropAllCustomStats			BIT				= 1
					,@PreShrinkAllLogs				Bit				= 0
					,@FP							BIT				= 0
					)


/*********************************************************
 **  Stored Procedure dbasp_Restore                  
 **  Written by Steve Ledridge, VIRTUOSO                
 **  December 29, 2008                                      
 **  
 **  This procedure is used for automated database
 **  restore processing for the pre-restore method.
 **  The pre-restore method is where we restore the
 **  DB along side of the DB of the same name using "_new"
 **  added to the DBname.  The mdf and ldf file names are 
 **  changed as well.  When the restore is completed, the old
 **  DB is droped and the "_new" DB is renamed, completing the
 **  restore.  This gives the end user greater DB availability.
 **
 **  This proc accepts the following input parms:
 **  - @dbname is the name of the database being restored.
 **  - @FilePath is the path where the backup file(s) can be found
 **    example - "\\seapsqlrpt01\seapsqlrpt01_restore"
 **  - @FileGroups is the name of individual file groups to be restored (comma seperated if more than one)
 **  - @LeaveNORECOVERY when set will Leave Database in Recovery Mode When Done
 **  - @NoFullRestores when set will Not Create Restore Script For Full Backups
 **  - @NoDifRestores when set will Not Create Restore Script For Diff Backups
 **  - @OverrideXML enables process to Force Files to be restored to specific locations
 **  - @post_shrink is for a post restore file shrink 
 **
 **	WARNING: BufferCount and MaxTransferSize values can cause Memory Errors
 **	   The total space used by the buffers is determined by: buffercount * maxtransfersize * DB_Data_Devices
 **	   blogs.msdn.com/b/sqlserverfaq/archive/2010/05/06/incorrect-buffercount-data-transfer-option-can-lead-to-oom-condition.aspx
 **
 **	@BufferCount		If Specified, Forces Value to be used				  X	  X
 **	@MaxTransferSize	If Specified, Forces Value to be used				  X	  X
 **
 ***************************************************************/
  
 

/*
EXEC dbo.[dbasp_Restore] 
		@DBName			= 'DBAPerf'
		,@FromServer	= 'SDCPROSQL01.db.virtuoso.com'
		,@post_shrink	= 1
		,@NoRevert		= 1
		,@noSnap		= 1


EXEC dbo.[dbasp_Restore] 
		@DBName			= 'DBAPerf'
		--,@NewDBName		= 'GD'
		,@FromServer	= 'SDCPROSQL01.db.virtuoso.com'
		,@Debug			= 1
		,@NoExec		= 1
		,@noSnap		= 1
		,@OverrideXML	= '
<RestoreFileLocations>
  <Override LogicalName="dbaperf" PhysicalName="E:\sqldata\dbaperf.mdf" New_PhysicalName="E:\SQLData\dbaperf.mdf" />
  <Override LogicalName="dbaperf_log" PhysicalName="L:\sqllog\dbaperf_log.ldf" New_PhysicalName="L:\SQLLog\dbaperf_log.ldf" />
</RestoreFileLocations>'
*/




AS
SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date			Author     				Desc
--	==========		====================	=============================================
--	12/29/2008		Steve Ledridge			New process based on dbasp_autorestore.
--	12/08/2010		Steve Ledridge			Added code for filegroup processing.
--	04/22/2011		Steve Ledridge			New code for 2008 processing.
--	10/24/2011		Steve Ledridge			Remove systema dn hidden attributes from the restore paths.
--	11/23/2011		Steve Ledridge			Added code for path override via local_control table.
--	11/12/2013		Steve Ledridge			Converted to use the new sproc dbasp_format_BackupRestore.
--	01/29/2014		Steve Ledridge			Changed tssqldba to tsdba.
--	02/03/2014		Steve Ledridge			Added new parm for dbaudf_BackupScripter_GetBackupFiles.
--	10/28/2014		Steve Ledridge			Added Parameters for @MaxTransferSize and @BufferCount to be used for both Backup and Restore Database scripts.
--	03/18/2015		Steve Ledridge			Fixed problem where Sproc loops if no files can be restored
--	03/18/2015		Steve Ledridge			Added new parm for @BaselineUpdates.
--	05/07/2015		Steve Ledridge			Set @fullreset to 0 for diff restores.
--  11/02/2018		Steve Ledridge			Added logic to not try to drop & restore if a backup file is not available. (will still try to revert)
--	======================================================================================

			

-----------------  declares  ------------------
DECLARE	@miscprint						nvarchar(4000)
		,@error_count					int
		,@cmd 							nvarchar(4000)
		,@Restore_cmd					nvarchar(max)
		,@save_BackupSetSize			smallint
		,@save_subject					sysname
		,@save_message					nvarchar(500)
		,@save_diff_filename			sysname
		,@save_Diff_FullPath			varchar(2000)
		,@save_DB_checkpoint_lsn		numeric(25,0)
		,@save_DB_DatabaseBackup_lsn	numeric(25,0)
		,@save_Diff_DatabaseBackupLSN	numeric(25,0)
		,@loop_count					smallint
		,@Restore_DB_flag				char(1)			
		,@IsSnapshot					bit
		,@IsSnapCurrent					bit
		,@SnapDBName					SYSNAME

		-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
		,@DataPath						VarChar(8000)
		,@LogPath						VarChar(8000)
		,@BackupPathL					VarChar(8000)
		,@BackupPathN					VarChar(8000)
		,@BackupPathN2					VarChar(8000)
		,@BackupPathA					VarChar(8000)
		,@DBASQLPath					VarChar(8000)
		,@SQLAgentLogPath				VarChar(8000)
		,@DBAArchivePath				VarChar(8000)
		,@EnvBackupPath					VarChar(8000)
		,@CleanBackupPath				VARCHAR(8000)
		,@SQLEnv						VarChar(10)	
		,@RootNetworkBackups			VarChar(8000)
		,@RootNetworkFailover			VarChar(8000)
		,@RootNetworkArchive			VarChar(8000)
		,@RootNetworkClean				VARCHAR(8000)

		,@CustomProperty				SYSNAME
		,@CurrentModValue				DateTime
		,@BackupModDate					DateTime
		,@TSQL							VarChar(8000)
		,@DropDBName					SYSNAME
		,@LastAction					SYSNAME				= ''
		,@AllAction						SYSNAME				= ''

DECLARE @OVERRIDEVALUE					VARCHAR(8000)

DECLARE	@cEModule						sysname
		,@cECategory					sysname
		,@cEEvent						sysname
		,@cEGUID						uniqueidentifier
		,@cEMessage						nvarchar(max)
		,@cERE_ForceScreen				BIT
		,@cERE_Severity					INT
		,@cERE_State					INT
		,@cERE_With						VarChar(2048)
		,@cEStat_Rows					BigInt
		,@cEStat_Duration				FLOAT
		,@cEMethod_Screen				Bit			= 0
		,@cEMethod_TableLocal			Bit			= 1
		,@cEMethod_TableCentral			BIT
		,@cEMethod_RaiseError			BIT
		,@cEMethod_Twitter				BIT

DECLARE @IsInAG							BIT			= 0
		,@IsPrimary						BIT			= 0
		,@AG							SYSNAME
		,@ErrorOutput					INT			= 0

	--------------------------------------------------
	--           SET GLOBAL cE VARIABLES            --
	--------------------------------------------------
SELECT	@cEModule						= 'dbasp_Restore'	-- SHOULD BE SET ONCE AT BEGINNING OF PROCCESS
		,@cEGUID						= NEWID()			-- SHOULD BE SET ONCE AT BEGINNING OF PROCCESS

IF @Verbose > 0 
	SET @cEMethod_Screen = 1

SELECT	@cECategory = 'PROCEDURE',@cEEvent = 'START',@cEMessage = 'DBA INFO: Starting Execution of Procedure'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

-- RESET @FP VALUE TO OVERIDE IF IT EXISTS FOR SPECIFIED DATABASE
SELECT		@OVERRIDEVALUE = Detail03
FROM		DBAOps.dbo.Local_Control
WHERE		Subject		= 'dbasp_restore_param_override'
	AND		Detail01	= @DBName
	AND		Detail02	= '@FP'

IF @OVERRIDEVALUE IS NOT NULL
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'INPUT PARAMETER OVERRIDE',@cEMessage = 'DBA INFO: The @FP parameter for dbasp_Restore has been overridden to a ['+@OVERRIDEVALUE+'] by DBA Control.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;    

	SELECT		@FP = Detail03
	FROM		DBAOps.dbo.Local_Control
	WHERE		Subject		= 'dbasp_restore_param_override'
		AND		Detail01	= @DBName
		AND		Detail02	= '@FP'
END					

----------------  Initial Values  -------------------
Select	@error_count = 0
Select	@loop_count = 0
Select	@Restore_DB_flag = 'n'
SELECT	@NewDBName = COALESCE(@NewDBName,@DBName)


			-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
			EXEC DBAOps.dbo.dbasp_GetPaths 
				 @DataPath				= @DataPath				OUT
				,@LogPath				= @LogPath				OUT
				,@BackupPathL			= @BackupPathL			OUT
				,@BackupPathN			= @BackupPathN			OUT
				,@BackupPathN2			= @BackupPathN2			OUT
				,@BackupPathA			= @BackupPathA			OUT
				,@DBASQLPath			= @DBASQLPath			OUT
				,@SQLAgentLogPath		= @SQLAgentLogPath		OUT
				,@DBAArchivePath		= @DBAArchivePath		OUT
				,@EnvBackupPath			= @EnvBackupPath		OUT
				,@SQLEnv				= @SQLEnv				OUT
				,@RootNetworkBackups	= @RootNetworkBackups	OUT	
				,@RootNetworkFailover	= @RootNetworkFailover	OUT	
				,@RootNetworkArchive	= @RootNetworkArchive	OUT
				,@RootNetworkClean		= @RootNetworkClean		OUT
				,@Verbose				= @Verbose				
				,@FP					= @FP

--  Check input parms
IF NULLIF(@FilePath,'') IS NULL AND NULLIF(@FromServer,'') IS NULL
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'INPUT PARAMETER',@cEMessage = 'DBA WARNING: Invalid parameters to dbasp_Restore - @FilePath or @FromServer must be specified.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	SELECT	@error_count = @error_count + 1
	GOTO	label99
END

IF NULLIF(@dbname,'') IS NULL
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'INPUT PARAMETER',@cEMessage = 'DBA WARNING: Invalid parameters to dbasp_Restore - @bname must be specified.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	SELECT	@error_count = @error_count + 1
	GOTO	label99
END

------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
--									CHECK AG PARTICIPATION
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------

SELECT @AG =[DBAOps].[dbo].[dbaudf_GetDbAg](@NewDBName)

IF @AG Like 'ERROR:%'
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'AG Validation',@cEMessage = 'DBA INFO: Database is not in an Availability Group'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	SET		@AG = NULL
END
ELSE
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'AG Validation',@cEMessage = 'DBA INFO: Database is in Availability Group ' + @AG; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	SET @IsInAG = 1
	IF [DBAOps].[dbo].[dbaudf_AG_Get_Primary]([DBAOps].[dbo].[dbaudf_GetDbAg](@NewDBName)) = @@SERVERNAME
	BEGIN
		SELECT	@cECategory = 'VALIDATION',@cEEvent = 'AG Validation',@cEMessage = 'DBA INFO: This Server is Primary for Availability Group ' + @AG; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		SET @IsPrimary = 1
	END
END


IF @IsInAG = 1 AND @IsPrimary = 0 AND @NoExec = 0 AND @IgnoreAGRestrict = 0
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'AG Validation',@cEMessage = 'DBA WARNING: AG Restore can only be done from Primary Node.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	SELECT	@error_count = @error_count + 1
	GOTO	label99
END

IF @IsInAG = 1 AND @NoExec = 0 AND @IgnoreAGRestrict = 0
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'AG Validation',@cEMessage = 'DBA INFO: Removing DB From Availability Group.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	EXEC DBAOps.dbo.dbasp_AG_DB_Remove @NewDBName, @AG

	SELECT		@LastAction		= 'AG_Drop'
				,@AllAction		= @AllAction + '|' + @LastAction
END


IF @@SERVERNAME LIKE 'SDT%' OR @BackupPathN IS NULL
BEGIN
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'BACKUP FILE LOCATION',@cEMessage = 'DBA INFO: -- CURRENT SERVERNAME STARTS WITH "SDT", USING SDT LOCAL SHARE.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	--RAISERROR('-- CURRENT SERVERNAME STARTS WITH "SDT", USING SDT LOCAL SHARE',-1,-1) WITH NOWAIT
	SET	@FilePath = COALESCE(@FilePath,'\\SDTPRONAS01.virtuoso.com\Backup\CleanBackups\' + @FromServer + '\')
END
ELSE
	SET	@FilePath = COALESCE(@FilePath,REPLACE(@BackupPathN,DBAOps.dbo.dbaudf_GetLocalFQDN()+'\','') + @FromServer + '\')


--RAISERROR('-- get backup mod date',-1,-1) WITH NOWAIT
SELECT	@cECategory = 'VALIDATION',@cEEvent = 'BACKUP FILE AGE',@cEMessage = 'DBA INFO: -- Getting Backup File Modification Date.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

------   GET DATE TO EVALUEATE IF REVERT SHOULD BE USED INSTEAD OF ACTUAL RESTORE   ------
SELECT		@BackupModDate  = MAX(BackupTimeStamp)
FROM		dbo.dbaudf_BackupScripter_GetBackupFiles(@DBName,@FilePath,0,@ForceFileName)
WHERE		(@NoFullRestores	= 0 OR BackupType != 'DB')
	AND		(@NoDifRestores		= 0 OR BackupType != 'DF')
	AND		(@NoLogRestores		= 0 OR BackupType != 'TL')


SELECT		@IsSnapshot			= 0
			,@IsSnapCurrent		= 0
			,@SnapDBName		= 'z_snap_' + @NewDBName
			,@CustomProperty	= 'SnapshotModDate_'+@NewDBName


	IF @PreShrinkAllLogs = 1 AND @NoExec = 0
	BEGIN TRY
		EXECUTE dbaops.[dbo].[dbasp_ShrinkAllLargeFiles] 
			@MinLogSize_MB	= 1
			,@MinLogFreePct	= 1
			,@FileTypes		= 'LOG'
			,@DBNameFilter	= NULL
			,@DoItNow		= 1
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'CATCH ERROR',@cEEvent = 'ERROR SHRINKING TRAN-LOGS',@cEMessage = 'DBA Warning:  There were issues wile shrinking Transaction Logs, This is not a critical Issue.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH

--start_full_restore:

-- CHECK TO SEE IF BACKUP FILES ARE AVAILABLE
IF @BackupModDate IS NULL
BEGIN
	IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	SELECT	@cECategory = 'VALIDATION',@cEEvent = 'NO USABLE BACKUPS ARE AVAILABLE',@cEMessage = 'DBA Warning:  There were no backup files available for a restoe.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	IF @NoRevert = 0
		SET @ForceRevert = 1
	IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
END

	--  Create DB restore command
	Select @Restore_cmd = ''

	IF @NoRevert = 0 
	BEGIN
   		SELECT	@cECategory = 'STEP',@cEEvent = 'SNAP CHECK',@cEMessage = 'Check for Current Database Snapshot.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF NOT EXISTS (SELECT value FROM fn_listextendedproperty(@CustomProperty, default, default, default, default, default, default))
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'SNAPSHOT PROPERTY CHECK',@cEMessage = 'No snapshot Property Found for DB ' + @NewDBName; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			GOTO	Start_DB_Restores
		END

		IF DB_ID(@SnapDBName) IS NULL
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'SNAPSHOT DB CHECK',@cEMessage = 'No snapshot DB Found for DB ' + @NewDBName; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			GOTO	Start_DB_Restores
		end

		--  Does the snapshot match the most recent baseline file on the central server
		SELECT	@cECategory = 'STEP',@cEEvent = 'CHECK SNAPSHOT DATE',@cEMessage = 'Test current snapshot vs most recent Backup File'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		SELECT	@IsSnapshot			= 1
				,@CurrentModValue	= CAST(value AS DateTime)
		FROM	fn_listextendedproperty(@CustomProperty, default, default, default, default, default, default)

		IF @ForceRevert = 1
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'CHECK SNAPSHOT DATE',@cEMessage = '@ForceRevert = 1, Reverting no matter the date.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			SELECT	@IsSnapCurrent = 1
		END
		ELSE IF @CurrentModValue <> COALESCE(@BackupModDate,CAST('2000-01-01' AS DateTime)) 
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'CHECK SNAPSHOT DATE',@cEMessage = 'Current Snapshot is NOT the SAME as the current backup file.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			GOTO	Start_DB_Restores
		END
		ELSE
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'CHECK SNAPSHOT DATE',@cEMessage = 'Current Snapshot IS the SAME as the current backup file.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			SELECT	@IsSnapCurrent = 1
		END

		--  Revert to snapshot
		SELECT	@cECategory = 'STEP',@cEEvent = 'PREPARE REVERT SNAPSHOT',@cEMessage = 'Prepare for Reverting Current Snapshot.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF @IsSnapshot = 1 AND @IsSnapCurrent = 1 AND @NoExec = 0
		BEGIN
			SELECT	@cECategory = 'STEP',@cEEvent = 'KILL ALL CONNECTIONS ON DB',@cEMessage = 'Killing all Connections on DB before revert.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			SELECT	@cECategory = 'SCRIPT',@cEEvent = 'LOG KILL SCRIPT',@cEMessage = 'dbo.dbasp_KillAllOnDB '''+@NewDBNAME+''''; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			EXEC	dbo.dbasp_KillAllOnDB @NewDBNAME

			SELECT		@LastAction		= 'KillActiveUsers'
						,@AllAction		= @AllAction + '|' + @LastAction
		END

		IF DB_ID(@SnapDBName) IS NOT NULL
		BEGIN
			-- Reverting DATABASE
			IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
			SELECT	@cECategory = 'STEP',@cEEvent = 'REVERT SNAPSHOT START',@cEMessage = 'Started Reverting Current Snapshot.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			SELECT	@TSQL = 'RESTORE DATABASE '+@NewDBName+' FROM DATABASE_SNAPSHOT = '''+@SnapDBName+''''
			IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

			SELECT		@LastAction		= 'RevertDB'
						,@AllAction		= @AllAction + '|' + @LastAction

			--  Drop the extra snapshots if any exist
			IF @NoExec = 0 
			BEGIN

				DECLARE DropSnapshotCursorx CURSOR
				FOR
				SELECT		name 
				FROM		sys.databases
				WHERE		source_database_id = DB_ID(@NewDBName)  
				AND			name != @SnapDBName

				OPEN DropSnapshotCursorx;
				FETCH DropSnapshotCursorx INTO @DropDBName;
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						SELECT	@cECategory = 'STEP',@cEEvent = 'DROP EXISTING SNAPSHOT DB',@cEMessage = 'Existing Extra Snapshot ['+@DropDBName+'] must be Dropped before a Revert.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
						BEGIN TRY				
							EXEC DBAOps.dbo.dbasp_DropDatabase	@dbname = @DropDBName
																,@debug = @Debug
																,@Retrys = 10
							SELECT		@LastAction		= 'DropSnapshot_' + @DropDBName
										,@AllAction		= @AllAction + '|' + @LastAction
						END TRY
						BEGIN CATCH
							EXEC DBAOps.dbo.dbasp_GetErrorInfo
						END CATCH
					END
 					FETCH NEXT FROM DropSnapshotCursorx INTO @DropDBName;
				END
				CLOSE DropSnapshotCursorx;
				DEALLOCATE DropSnapshotCursorx;
			END

			IF @Debug = 1 OR @NoExec = 1
				EXEC	dbo.dbasp_PrintLarge @TSQL

			IF @NoExec = 0
			BEGIN TRY
				SELECT	@cECategory = 'STEP',@cEEvent = 'EXECUTE COMMAND',@cEMessage = @TSQL; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
				EXEC (@TSQL) AS Login = 'sa'
				SELECT	@cECategory = 'STEP',@cEEvent = 'REVERT SNAPSHOT COMPLETE',@cEMessage = 'Completed Reverting Current Snapshot.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

				If (DATABASEPROPERTYEX(@NewDBName, N'Status') != N'ONLINE')
				BEGIN
					IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
					SELECT	@cECategory = 'STEP',@cEEvent = 'SNAPSHOT DB CHECK',@cEMessage = 'DBA Warning:  Snapshot Revert is not Usable. Trying Restore from Backup now.' + @NewDBName; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
					IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
					GOTO	Start_DB_Restores
				END
			END TRY
			BEGIN CATCH
				IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
				EXEC DBAOps.dbo.dbasp_GetErrorInfo
				SELECT	@cECategory = 'CATCH ERROR',@cEEvent = 'ERROR REVERTING SNAPSHOT',@cEMessage = 'DBA Warning:  Snapshot Revert Failed. Trying Restore from Backup now.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
				IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
				goto Start_DB_Restores
			END CATCH

		GOTO	Skip_DB_Restores	
		END
	END

Start_DB_Restores:
	--RAISERROR('-- start DB restore',-1,-1) WITH NOWAIT
	SELECT	@cECategory = 'STEP',@cEEvent = 'START',@cEMessage = 'DBA INFO: Starting Restore of ['+@dbname+'] as ['+@NewDBName+'] From '+@FilePath ; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

	--  Drop the related snapshot if it exists
	IF @NoExec = 0 
	BEGIN

		DECLARE DropSnapshotCursorx CURSOR
		FOR
		SELECT		name 
		FROM		sys.databases
		WHERE		source_database_id = DB_ID(@NewDBName)  

		OPEN DropSnapshotCursorx;
		FETCH DropSnapshotCursorx INTO @DropDBName;
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				SELECT	@cECategory = 'STEP',@cEEvent = 'DROP EXISTING SNAPSHOT DB',@cEMessage = 'Existing Snapshot ['+@DropDBName+'] must be Dropped before a Restore.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
				BEGIN TRY				
					EXEC DBAOps.dbo.dbasp_DropDatabase	@dbname = @DropDBName
														,@debug = @Debug
														,@Retrys = 10

					SELECT		@LastAction		= 'DropSnapshot_' + @DropDBName
								,@AllAction		= @AllAction + '|' + @LastAction
				END TRY
				BEGIN CATCH
					EXEC DBAOps.dbo.dbasp_GetErrorInfo
				END CATCH
			END
 			FETCH NEXT FROM DropSnapshotCursorx INTO @DropDBName;
		END
		CLOSE DropSnapshotCursorx;
		DEALLOCATE DropSnapshotCursorx;
	END

	If EXISTS (SELECT value FROM fn_listextendedproperty(@CustomProperty, default, default, default, default, default, default))
	BEGIN
		EXEC sys.sp_dropextendedproperty @Name = @CustomProperty
	END

	SELECT @IsSnapshot = 0, @IsSnapCurrent = 0

	IF @BackupModDate IS NULL
	BEGIN
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'RESTORE ERROR',@cEEvent = 'UNABLE TO LOCATE USABLE BACKUP FILES',@cEMessage = 'DBA Error:  NO USABLE BACKUP FILES EXIST.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SET @error_count = @error_count + 1
		GOTO Skip_DB_Restores
	END

	IF DB_ID(@NewDBName) IS NOT NULL AND @FullReset = 1 
	BEGIN
		SELECT	@cECategory = 'STEP',@cEEvent = 'DROP EXISTING DB',@cEMessage = 'Existing Database ['+@NewDBName+'] must be Dropped before a Restore.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		BEGIN TRY				
			EXEC DBAOps.dbo.dbasp_DropDatabase	@dbname = @NewDBName
												,@debug = @Debug
												,@Retrys = 10

			IF DB_ID(@NewDBName) IS NOT NULL
			BEGIN
				IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
				SELECT	@cECategory = 'DROP ERROR',@cEEvent = 'UNABLE TO DROP DATABASE',@cEMessage = 'DBA Error:  UNABLE TO DROP EXISTING DATABASE. CHECK FOR HUNG SPID OR LONG ROLLBACK.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
				IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
				GOTO Skip_DB_Restores
			END
			ELSE
			BEGIN
				SELECT		@LastAction		= 'DropDB'
							,@AllAction		= @AllAction + '|' + @LastAction
			END
		END TRY
		BEGIN CATCH
			IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
			SELECT	@cECategory = 'CATCH ERROR',@cEEvent = 'ERROR DROPPING DATABASE',@cEMessage = 'DBA Error:  UNABLE TO DROP EXISTING DATABASE. CHECK FOR HUNG SPID OR LONG ROLLBACK.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
			EXEC DBAOps.dbo.dbasp_GetErrorInfo
			IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
			GOTO Skip_DB_Restores
		END CATCH
	END

	-- Restore the DB
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'DB RESTORE - GENERATE SCRIPT',@cEMessage = 'User dbasp_Format_BackupRestore to Generate Script.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
  
  SET @cEMessage = 'EXEC	[dbo].[dbasp_format_BackupRestore]    
				@DBName				= '''+@DBName+'''
				,@NewDBName			= '''+@NewDBName+'''
				--,@FromServer		= '''+COALESCE(@FromServer,'')+'''
				,@Mode				= ''RD'' 
				,@FilePath			= '''+COALESCE(CAST(@FilePath			AS VarChar(max)),'')+'''
				,@FileGroups		= '''+COALESCE(CAST(@FileGroups			AS VarChar(max)),'')+'''
				,@ForceFileName		= '''+COALESCE(CAST(@ForceFileName		AS VarChar(max)),'')+'''
				,@Verbose			= '''+COALESCE(CAST(@Verbose			AS VarChar(max)),'')+'''
				,@FullReset			= '''+COALESCE(CAST(@FullReset			AS VarChar(max)),'')+'''
				,@NoFullRestores	= '''+COALESCE(CAST(@NoFullRestores		AS VarChar(max)),'')+'''
				,@NoDifRestores		= '''+COALESCE(CAST(@NoDifRestores		AS VarChar(max)),'')+'''
				,@NoLogRestores		= '''+COALESCE(CAST(@NoLogRestores		AS VarChar(max)),'')+'''
				,@IgnoreSpaceLimits = '''+COALESCE(CAST(@IgnoreSpaceLimits	AS VarChar(max)),'')+'''
				,@BufferCount		= '''+COALESCE(CAST(@BufferCount		AS VarChar(max)),'')+'''		
				,@MaxTransferSize	= '''+COALESCE(CAST(@MaxTransferSize	AS VarChar(max)),'')+'''
				,@LeaveNORECOVERY	= '''+COALESCE(CAST(@LeaveNORECOVERY	AS VarChar(max)),'')+'''
				,@ForceBHLID		= '''+COALESCE(CAST(@ForceBHLID			AS VarChar(max)),'')+'''
				,@RestoreToDateTime = '''+COALESCE(CAST(@RestoreToDateTime	AS VarChar(max)),'')+'''
				,@OverrideXML		= @OverrideXML OUTPUT
				,@syntax_out		= @Restore_cmd OUTPUT '
  
  
IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
SELECT	@cECategory = 'DEBUG',@cEEvent = 'DB RESTORE - GENERATE SCRIPT'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
  
   		EXEC	[dbo].[dbasp_format_BackupRestore]    
				@DBName				= @DBName
				,@NewDBName			= @NewDBName
				--,@FromServer		= @FromServer
				,@WorkDir			= @WorkDir
				,@DeleteWorkFiles	= @DeleteWorkFiles
				,@Mode				= 'RD' 
				,@FilePath			= @FilePath
				,@FileGroups		= @FileGroups
				,@ForceFileName		= @ForceFileName
				,@Verbose			= @Verbose
				,@FullReset			= @FullReset
				,@NoFullRestores	= @NoFullRestores
				,@NoDifRestores		= @NoDifRestores
				,@NoLogRestores		= @NoLogRestores
				,@IgnoreSpaceLimits = @IgnoreSpaceLimits
				,@BufferCount		= @BufferCount		
				,@MaxTransferSize	= @MaxTransferSize
				,@LeaveNORECOVERY	= @LeaveNORECOVERY
				,@ForceBHLID		= @ForceBHLID
				,@RestoreToDateTime = @RestoreToDateTime
				,@OverrideXML		= @OverrideXML OUTPUT
				,@syntax_out		= @Restore_cmd OUTPUT 
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
 		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		--RAISERROR (@cEMessage,-1,-1) WITH NOWAIT
		SELECT	@cECategory = 'STEP',@cEEvent = 'DB RESTORE - GENERATE SCRIPT FAILED',@cEMessage = 'DBA Error:  Restore DB Failed while executing Command.'+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+@cEMessage; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		SET @error_count = @error_count + 1
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		GOTO label99
	END CATCH

	IF @NoExec = 1 OR @Debug = 1
		SELECT @OverrideXML
	
	SELECT	@cECategory = 'STEP',@cEEvent = 'DB RESTORE - EXECUTE SCRIPT',@cEMessage = 'Execute Restore Script.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

	SELECT	@cECategory = 'SCRIPT',@cEEvent = 'LOG RESTORE SCRIPT',@cEMessage = @Restore_cmd; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

	IF @Debug = 1 OR @NoExec = 1
		EXEC	dbo.dbasp_PrintLarge @Restore_cmd
	
	IF @NoExec = 0
	BEGIN TRY
		EXEC (@Restore_cmd) AS LOGIN = 'sa'
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'DB RESTORE - EXECUTE SCRIPT FAILED',@cEMessage = 'DBA Error:  Restore DB Failed while executing Command.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		Select	@error_count = @error_count + 1
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		goto	label99
	END CATCH

	If @@error<> 0 OR (DB_ID(@NewDBName) IS NULL AND @NoExec = 0)
	BEGIN
		SELECT	@cECategory = 'STEP',@cEEvent = 'DB RESTORE - EXECUTE SCRIPT FAILED',@cEMessage = 'DBA Error:  Restore DB Failed while executing Command.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		SELECT	@error_count = @error_count + 1
		GOTO	label99
	END
	ELSE
	BEGIN
				SELECT		@LastAction		= 'RestoreDB'
							,@AllAction		= @AllAction + '|' + @LastAction

	END

	SET @TSQL = COALESCE(PARSENAME(@FromServer,6),PARSENAME(@FromServer,5),PARSENAME(@FromServer,4),PARSENAME(@FromServer,3),PARSENAME(@FromServer,2),PARSENAME(@FromServer,1))

	IF @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST RESTORE - FIX ORPHANED USERS',@cEMessage = 'Execute dbasp_FixOrphanedUsersInDB.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'DEBUG',@cEEvent = 'FIX OPRPHANS SCRIPT',@cEMessage='EXEC [dbo].[dbasp_FixOrphanedUsersInDB] '''+@NewDBName+''', '''+@TSQL+''',0'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
			--RAISERROR ('EXEC [dbo].[dbasp_FixOrphanedUsersInDB] ''%s'', ''%s'',0' ,-1,-1,@NewDBName,@TSQL) WITH NOWAIT
		IF @NoExec = 0
		BEGIN 
			EXEC [dbo].[dbasp_FixOrphanedUsersInDB] @NewDBName,@TSQL,0;

			SELECT		@LastAction		= 'FixOrphans'
						,@AllAction		= @AllAction + '|' + @LastAction

		END
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST RESTORE - FIX ORPHANED USERS',@cEMessage = 'DBA WARNING:  Execute dbasp_FixOrphanedUsersInDB Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH

	IF @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'ALTER DATABASE - SET TRUSTWORTHY',@cEMessage = 'Execute Script.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		SET @TSQL = 'ALTER DATABASE ['+@NewDBName+'] SET TRUSTWORTHY ON;'
		
		IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'DEBUG',@cEEvent = 'FIX TRUSTWORTHY SCRIPT',@cEMessage=@TSQL; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

		--IF @Debug = 1
		--	EXEC dbo.dbasp_PrintLarge @TSQL
		IF @NoExec = 0 
		BEGIN
			EXEC (@TSQL) AS LOGIN = 'sa'

			SELECT		@LastAction		= 'FixTrustworthy'
						,@AllAction		= @AllAction + '|' + @LastAction
		END
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'ALTER DATABASE - SET TRUSTWORTHY',@cEMessage = 'DBA WARNING:  Execute Script Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH

	IF @post_shrink = 1 AND @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST SHRINK - EXECUTE',@cEMessage = 'Execute dbasp_ShrinkAllLargeFiles.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'DEBUG',@cEEvent = 'FIX SHRINK FILES SCRIPT',@cEMessage='EXEC dbo.dbasp_ShrinkAllLargeFiles @DBNameFilter = '''+@NewDBName+''', @DoItNow = 1' ; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

		--IF @Debug = 1
		--	RAISERROR ('EXEC dbo.dbasp_ShrinkAllLargeFiles @DBNameFilter = ''%s'', @DoItNow = 1' ,-1,-1,@NewDBName) WITH NOWAIT
		IF @NoExec = 0
		BEGIN
			EXEC dbo.dbasp_ShrinkAllLargeFiles @DBNameFilter = @NewDBName, @DoItNow = 1

			SELECT		@LastAction		= 'ShrinkAllFiles'
						,@AllAction		= @AllAction + '|' + @LastAction
		END
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST SHRINK - EXECUTE',@cEMessage = 'DBA WARNING:  Execute dbasp_ShrinkAllLargeFiles Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH


	IF @post_shrink_OnlyLog = 1 AND @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST SHRINK LOG ONLY - EXECUTE',@cEMessage = 'Execute dbasp_ShrinkAllLargeFiles.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'DEBUG',@cEEvent = 'FIX SHRINK FILES SCRIPT',@cEMessage='EXEC dbo.dbasp_ShrinkAllLargeFiles @FileTypes = ''LOG'', @DBNameFilter = '''+@NewDBName+''', @DoItNow = 1' ; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

		--IF @Debug = 1
		--	RAISERROR ('EXEC dbo.dbasp_ShrinkAllLargeFiles @FileTypes = ''LOG'', @DBNameFilter = ''%s'', @DoItNow = 1' ,-1,-1,@NewDBName) WITH NOWAIT
		IF @NoExec = 0
		BEGIN
			EXEC dbo.dbasp_ShrinkAllLargeFiles @FileTypes = 'LOG', @DBNameFilter = @NewDBName, @DoItNow = 1

			SELECT		@LastAction		= 'ShrinkLogFile'
						,@AllAction		= @AllAction + '|' + @LastAction
		END

	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST SHRINK LOG ONLY - EXECUTE',@cEMessage = 'DBA WARNING:  Execute dbasp_ShrinkAllLargeFiles Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH



	IF @IsInAG = 1
		SET @post_set_recovery = 'FULL'

	IF @post_set_recovery IS NOT NULL AND @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'ALTER DATABASE - SET RECOVERY',@cEMessage = 'Execute Script.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		SET @TSQL = 'ALTER DATABASE ['+@NewDBName+'] SET RECOVERY '+@post_set_recovery+' WITH NO_WAIT;'
		IF @Debug = 1
			EXEC dbo.dbasp_PrintLarge @TSQL
		IF @NoExec = 0
		BEGIN
			EXEC (@TSQL) AS LOGIN = 'sa'

			SELECT		@LastAction		= 'SetRecovery_'+ @post_set_recovery
						,@AllAction		= @AllAction + '|' + @LastAction
		END

	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'ALTER DATABASE - SET RECOVERY',@cEMessage = 'DBA WARNING:  Execute Script Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH

	IF @DropAllCustomStats = 1 AND @LeaveNORecovery = 0
	BEGIN TRY
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST DROP CUSTOM STATS - EXECUTE',@cEMessage = 'Execute dbasp_DropAllCustomStatsOnDB.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

		IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		SELECT	@cECategory = 'DEBUG',@cEEvent = 'FIX DROP CUSTOM STATS SCRIPT',@cEMessage='EXEC dbo.dbasp_DropAllCustomStatsOnDB '''+@NewDBName+'''' ; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

		--IF @Debug = 1
		--	RAISERROR ('EXEC dbo.dbasp_DropAllCustomStatsOnDB ''%s''' ,-1,-1,@NewDBName) WITH NOWAIT
		IF @NoExec = 0
		BEGIN
			EXEC DBAOps.dbo.dbasp_DropAllCustomStatsOnDB @NewDBName

			SELECT		@LastAction		= 'DropCustomStats'
						,@AllAction		= @AllAction + '|' + @LastAction
		END

	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'POST DROP CUSTOM STATS - FAILED',@cEMessage = 'DBA WARNING:  Execute Script Failed.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	END CATCH

	IF @LeaveNORECOVERY = 1 OR @NoSnap = 1
		GOTO skip_db_snapshot

	SELECT	@cECategory = 'STEP',@cEEvent = 'CREATE SNAPSHOT',@cEMessage = 'GENERATE SNAPSHOT OF '+ @NewDBName+' AS '+@SnapDBName; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

	SET @TSQL = 'EXEC DBAOps.dbo.dbasp_CreateDBSnapshot '''+@NewDBName+''','''+@SnapDBName+''''

	SELECT	@cECategory = 'STEP',@cEEvent = 'CREATE SNAPSHOT - EXECUTE SCRIPT',@cEMessage = 'Execute Snapshot DB Script.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;

	IF @Debug = 1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
	SELECT	@cECategory = 'DEBUG',@cEEvent = 'CREATE SNAPSHOT SCRIPT',@cEMessage=@TSQL ; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
	IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;

	--IF @Debug = 1
	--	EXEC	dbo.dbasp_PrintLarge @TSQL

	IF @NoExec = 0
	BEGIN TRY
		EXEC (@TSQL) AS LOGIN = 'sa'

		SELECT		@LastAction		= 'CreateSnapshot'
					,@AllAction		= @AllAction + '|' + @LastAction
	END TRY
	BEGIN CATCH
		IF @Verbose > -1 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		SELECT	@cECategory = 'STEP',@cEEvent = 'CREATE SNAPSHOT - EXECUTE SCRIPT FAILED',@cEMessage = 'DBA Warning:  Create DB Snapshot Failed while executing Command.' +CHAR(13)+CHAR(10)+@TSQL; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		--Select	@error_count = @error_count + 1
		--EXEC	dbo.dbasp_PrintLarge @TSQL
		IF @Verbose > 0 SET @cEMethod_Screen = 1 ELSE SET @cEMethod_Screen = 0;
		goto	skip_db_snapshot
	END CATCH

	IF DB_ID(@SnapDBName) IS NULL AND @NoExec = 0
	BEGIN
		SELECT	@cECategory = 'STEP',@cEEvent = 'CREATE SNAPSHOT - EXECUTE SCRIPT FAILED',@cEMessage = 'DBA Warning:  Create DB Snapshot Failed while executing Command.'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
		--Select	@error_count = @error_count + 1
		EXEC	dbo.dbasp_PrintLarge @TSQL
		goto	skip_db_snapshot
	END

	IF @NoExec = 0 AND @LeaveNORecovery = 0
	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty(@CustomProperty, default, default, default, default, default, default))
	   BEGIN
		PRINT 'Adding Property'
		EXEC sys.sp_addextendedproperty @Name = @CustomProperty, @value = @BackupModDate
	   END
	ELSE
	   BEGIN
		PRINT 'Updating Property'
		EXEC sys.sp_updateextendedproperty @Name = @CustomProperty, @value = @BackupModDate
	   END

skip_db_snapshot:
Skip_DB_Restores:



IF @IsInAG = 1 AND @NoExec = 0
BEGIN
	EXEC DBAOps.dbo.dbasp_AG_DB_Join @NewDBName, @AG, 1

	SELECT		@LastAction		= 'JoinAG'
				,@AllAction		= @AllAction + '|' + @LastAction
END

-------------------   end   --------------------------

label99:

--  Check to make sure the DB is in 'restoring' mode if requested
If @LeaveNORECOVERY = 1 and DATABASEPROPERTYEX (@DBName,'status') <> 'RESTORING' 
   begin
	select @miscprint = 'DBA ERROR: POST RESTORE CHECK: A norecovOnly restore was requested and the database is not in ''RESTORING'' mode.'
	RAISERROR(@miscprint,-1,-1) WITH NOWAIT
	Select @error_count = @error_count + 1
   end

If @error_count = 0 and @LeaveNORECOVERY = 0 and DATABASEPROPERTYEX (@DBName,'status') <> 'ONLINE'
   begin
	select @miscprint = 'DBA ERROR: POST RESTORE CHECK: The Restore process has failed for database ' + @DBName + '.  That database is not ''ONLINE'' at this time.'
	RAISERROR(@miscprint,-1,-1) WITH NOWAIT
	Select @error_count = @error_count + 1
   end

SET @AllAction = 'Actions = ' + ISNULL(NULLIF(@AllAction,''),'NoActions')
RAISERROR(@AllAction,-1,-1) WITH NOWAIT

DECLARE @Return Int
SET @Return = CASE
				WHEN	@AllAction LIKE '%|DropDB%' AND DB_ID(@NewDBName) IS NULL						THEN -1		-- DATABASE WAS DROPPED AND NOT REPLACED
				WHEN	DB_ID(@NewDBName) IS NULL														THEN -2		-- DATABASE DOES NOT EXIST
				WHEN	@LeaveNORECOVERY = 1 and DATABASEPROPERTYEX (@DBName,'status') <> 'RESTORING'	THEN -3		-- @LeaveNORECOVERY = 1 AND DATABASE IS NOT IN "RESTORING" MODE
				WHEN	@LeaveNORECOVERY = 0 and DATABASEPROPERTYEX (@DBName,'status') <> 'ONLINE'		THEN -4		-- @LeaveNORECOVERY = 0 AND DATABASE IS NOT IN "ONLINE" MODE

				WHEN	@AllAction LIKE '%NoActions%'													THEN 0		-- NO ACTIONS WERE TAKEN

				WHEN	@AllAction LIKE '%|RestoreDB%'													THEN 1		-- DATABASE WAS RESTORED
				WHEN	@AllAction LIKE '%|RevertDB%'													THEN 2		-- DATABASE WAS REVERTED
				ELSE																						-99		-- UNKNOWN STATE																								
				END

If @error_count > 0 OR @Return < 1
BEGIN
	SELECT	@cECategory = 'PROCEDURE',@cEEvent = 'END',@cEMessage = 'DBA ERROR: Ending Execution of Procedure With Errors '; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal,@cERE_Severity=16,@cEMethod_RaiseError = 1,@cERE_State = -1;
END
ELSE
BEGIN
	SELECT	@cECategory = 'PROCEDURE',@cEEvent = 'END',@cEMessage = 'DBA INFO: Ending Execution of Procedure'; EXEC [dbo].[dbasp_LogEvent] @cEModule,@cECategory,@cEEvent,@cEGUID,@cEMessage,@cEMethod_Screen=@cEMethod_Screen,@cEMethod_TableLocal=@cEMethod_TableLocal;
END
   
RETURN (@Return)
GO
GRANT EXECUTE ON  [dbo].[dbasp_Restore] TO [public]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Used to automate the Restore of SQL Databases', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_Description', N'used to override MS Standard value to improve performance (WARNING: can Cause Memory problems)', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@BufferCount'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Name of Database to Restore', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@dbname'
GO
EXEC sp_addextendedproperty N'MS_Description', N'shows additional debug info in the output including an example value for the @OverrideXML parameter to use as a template', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@Debug'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Drop all custom stats after the restore', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@DropAllCustomStats'
GO
EXEC sp_addextendedproperty N'MS_Description', N'only used to restore a single file group (if the file group was backed up independently)', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@FileGroups'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Only used to force a restore from a nonstandard location', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@FilePath'
GO
EXEC sp_addextendedproperty N'MS_Description', N'only restore backup with a specific BHLID (used to ensure encryption key matches other databases)', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@ForceBHLID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Only used to force a restore from a nonstandard location or naming convention', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@ForceFileName'
GO
EXEC sp_addextendedproperty N'MS_Description', N'force a revert even if the backup file is newer', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@ForceRevert'
GO
EXEC sp_addextendedproperty N'MS_Description', N'DO NOT USE', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@FP'
GO
EXEC sp_addextendedproperty N'MS_Description', N'the Server FQDN from which the database comes (real name, not alias) ex. SDCPROSQL01.DB.VIRTUOSO.COM', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@FromServer'
GO
EXEC sp_addextendedproperty N'MS_Description', N'force restore over an existing database (will error if 0 and database exists)', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@FullReset'
GO
EXEC sp_addextendedproperty N'MS_Description', N'ignore restrictions from database being in availability group', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@IgnoreAGRestrict'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Leave the database in restoring mode so that additional diff or tranlog backups can be applied or when implementing replication/mirroring/availabilities/log shipping', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@LeaveNORecovery'
GO
EXEC sp_addextendedproperty N'MS_Description', N'used to override MS Standard value to improve performance (WARNING: can Cause Memory problems)', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@MaxTransferSize'
GO
EXEC sp_addextendedproperty N'MS_Description', N'New Name if Changing from the Origional', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NewDBName'
GO
EXEC sp_addextendedproperty N'MS_Description', N'do not apply diff if it exist, just restore full', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoDifRestores'
GO
EXEC sp_addextendedproperty N'MS_Description', N'go through the steps but do not actually do the restore', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoExec'
GO
EXEC sp_addextendedproperty N'MS_Description', N'only offer restore of diff or tranlogs, used for adding to a database in restoring mode', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoFullRestores'
GO
EXEC sp_addextendedproperty N'MS_Description', N'do not apply logs if they exist', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoLogRestores'
GO
EXEC sp_addextendedproperty N'MS_Description', N'do not revert instead of restore if date is the same', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoRevert'
GO
EXEC sp_addextendedproperty N'MS_Description', N'do not generate a snapshot after restore', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@NoSnap'
GO
EXEC sp_addextendedproperty N'MS_Description', N'used to specify new location to place restored files', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@OverrideXML'
GO
EXEC sp_addextendedproperty N'MS_Description', N'which recovery model to leave the database as', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@post_set_recovery'
GO
EXEC sp_addextendedproperty N'MS_Description', N'force a full shrink of data and log devices after restore to remove all free space', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@post_shrink'
GO
EXEC sp_addextendedproperty N'MS_Description', N'force a shrink of only the log file to its default empty size', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@post_shrink_OnlyLog'
GO
EXEC sp_addextendedproperty N'MS_Description', N'shrink all other database logs to free up space before the restore is attempted', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@PreShrinkAllLogs'
GO
EXEC sp_addextendedproperty N'MS_Description', N'values from -1 = silent to 2 = Extremely verbose add messages to output', 'SCHEMA', N'dbo', 'PROCEDURE', N'dbasp_Restore', 'PARAMETER', N'@Verbose'
GO
