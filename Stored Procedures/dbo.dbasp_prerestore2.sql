SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_prerestore2] (
					 @dbname sysname
					,@NewDBName sysname
					,@FilePath VarChar(MAX)	= NULL
					,@FileGroups VarChar(MAX) = NULL
					,@ForceFileName VarChar(MAX) = NULL
					,@LeaveNORECOVERY BIT = 0
					,@NoFullRestores BIT = 0
					,@NoDifRestores BIT = 0
					,@OverrideXML XML = NULL
					,@post_shrink char(1) = 'n'
					,@complete_on_diffOnly_fail char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_prerestore2
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
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
 **  - @NewDBName is the "new" name of the database being restored (e.g. z_DBname_new).
 **  - @FilePath is the path where the backup file(s) can be found
 **    example - "\\seapsqlrpt01\seapsqlrpt01_restore"
 **  - @FileGroups is the name of individual file groups to be restored (comma seperated if more than one)
 **  - @LeaveNORECOVERY when set will Leave Database in Recovery Mode When Done
 **  - @NoFullRestores when set will Not Create Restore Script For Full Backups
 **  - @NoDifRestores when set will Not Create Restore Script For Diff Backups
 **  - @OverrideXML enables process to Force Files to be restored to specific locations
 **  - @post_shrink is for a post restore file shrink (y or n)
 **  - @complete_on_diffOnly_fail will finish the restore of a DB after a failed
 **    differential restore'
 ***************************************************************/
  as


SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/29/2008	Steve Ledridge		New process based on dbasp_autorestore.
--	12/08/2010	Steve Ledridge		Added code for filegroup processing.
--	04/22/2011	Steve Ledridge		New code for 2008 processing.
--	10/24/2011	Steve Ledridge		Remove systema dn hidden attributes from the restore paths.
--	11/23/2011	Steve Ledridge		Added code for path override via local_control table.
--	11/12/2013	Steve Ledridge		Converted to use the new sproc dbasp_format_BackupRestore.
--	12/10/2013	Steve Ledridge		Added @IgnoreSpaceLimits for DIFF restores.
--	12/11/2013	Steve Ledridge		Fix for missing trailing '\' on @FilePath.
--	01/06/2013	Steve Ledridge		Modified the verification of the pre-restored DB.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	02/03/2014	Steve Ledridge		Added code for @ForceFileName.
--	03/23/2015	Steve Ledridge		Rewrote for Newest version of BackupRestore Scripter.
--	======================================================================================


/***
Declare @dbname sysname
Declare @NewDBName sysname
Declare @FilePath VarChar(MAX)
Declare @FileGroups VarChar(MAX)
Declare @ForceFileName VarChar(MAX)
Declare @LeaveNORECOVERY BIT
Declare @NoFullRestores BIT
Declare @NoDifRestores BIT
Declare @OverrideXML XML
Declare @post_shrink char(1)
Declare @complete_on_diffOnly_fail char(1)


select @dbname = '${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS'
select @NewDBName = 'z_${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_new'
select @FilePath = '\\seapcrmsql1a\seapcrmsql1a_backup\'
--select @FileGroups = 'primary'
select @ForceFileName = null
select @LeaveNORECOVERY = 0
select @NoFullRestores = 1
select @NoDifRestores = 0
select @OverrideXML = '
		<RestoreFileLocations>
		<Override LogicalName="${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS" PhysicalName="E:\data\${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS.mdf" New_PhysicalName="I:\MSSQL\Data\$DT$_${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS.mdf" />
		<Override LogicalName="${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_log" PhysicalName="F:\log\${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_log.LDF" New_PhysicalName="I:\MSSQL\Data\$DT$_${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_log.LDF" />
		<Override LogicalName="${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_2" PhysicalName="E:\data\${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_2.ndf" New_PhysicalName="I:\MSSQL\Data\$DT$_${{secrets.COMPANY_NAME}}_Images_CRM_GENESYS_2.ndf" />
		</RestoreFileLocations>'
Select @post_shrink = 'n'
Select @complete_on_diffOnly_fail = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
	,@cmd 				nvarchar(4000)
	,@Restore_cmd			nvarchar(max)
	,@save_BackupSetSize		smallint
	,@save_subject			sysname
	,@save_message			nvarchar(500)
	,@save_bak_filename		sysname
	,@save_diff_filename		sysname
	,@save_bak_FullPath		varchar(2000)
	,@save_Diff_FullPath		varchar(2000)
	,@save_bak_CheckpointLSN	numeric(25,0)
	,@save_DB_checkpoint_lsn	numeric(25,0)
	,@save_Diff_DatabaseBackupLSN	numeric(25,0)
	,@hold_FGmask			sysname
	,@loop_count			smallint
	,@DB_LeaveNORECOVERY		BIT
	,@restore_db_flag		char(1)
	,@FullReset			BIT
	,@save_SQLcollation		sysname


----------------  initial values  -------------------
Select @error_count = 0
Select @loop_count = 0
Select @restore_db_flag = 'n'
SELECT @FullReset = 0


--  Check input parms
If @FilePath is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore2 - @FilePath must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END
Else
   BEGIN
	Select @FilePath = reverse(@FilePath)
	If left(@FilePath, 1) <> '\'
	   begin
		Select @FilePath = '\' + @FilePath
	   end
	Select @FilePath = reverse(@FilePath)
   END


if @dbname is null or @dbname = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore2 - @dbname must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @NewDBName is null or @NewDBName = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore2 - @NewDBName must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


/****************************************************************
 *                MainLine
 ***************************************************************/


 ----------------------  Print the headers  ----------------------
Print  ' '
Print  '/*********************************************************'
Select @miscprint = 'Prerestore Database for server: ' + @@servername
Print  @miscprint
Print  '*********************************************************/'
RAISERROR('', -1,-1) WITH NOWAIT


CreateRestoreScript:


IF DB_ID(@NewDBName) IS NULL
BEGIN
	RAISERROR('DATABASE DOES NOT EXIST RESETTING @FULLRESET AND @NOFULLRESTORES', -1,-1) WITH NOWAIT
	SELECT		@FullReset		= 1
			,@NoFullRestores	= 0
END
ELSE IF DATABASEPROPERTYEX (@NewDBName,'status') <> 'RESTORING'
BEGIN
	RAISERROR('DATABASE EXIST BUT NOT RESTORING RESETTING @FULLRESET AND @NOFULLRESTORES', -1,-1) WITH NOWAIT
	SELECT		@FullReset		= 1
			,@NoFullRestores	= 0
END


If @LeaveNORECOVERY = 0 and @NoDifRestores = 1
	SET @LeaveNORECOVERY = 1


--  Create DB restore command
Select @Restore_cmd = ''


   	EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
		 @DBName		= @DBName
		,@NewDBName		= @NewDBName
		,@Mode			= 'RD'
		,@FilePath		= @FilePath
		,@FileGroups		= @FileGroups
		,@ForceFileName		= @ForceFileName
		,@Verbose		= 0
		,@IgnoreSpaceLimits	= 1
		,@FullReset		= @FullReset
		,@NoFullRestores	= @NoFullRestores
		,@NoDifRestores		= @NoDifRestores
		,@NoLogRestores		= 1
		,@LeaveNORECOVERY	= @LeaveNORECOVERY
		,@UseTryCatch		= 1
		,@OverrideXML		= @OverrideXML
		,@syntax_out		= @Restore_cmd OUTPUT


IF  @Restore_cmd LIKE '%-- NO SUITABLE BACKUP FILES EXIST%'
BEGIN
	IF @FullReset = 0
	BEGIN
		SET @FullReset = 1
		SET @NoFullRestores = 0
		raiserror('-- *** WARNING: RETRYING RESTORE AS FULL RESET ***', -1,-1) with nowait
		GOTO CreateRestoreScript
	END
	raiserror('-- *** ERROR: NO SUITABLE BACKUP FILES WERE FOUND ***', -1,-1) with nowait
	Select @error_count = @error_count + 1
	GOTO label99
END


-- Restore the DB
Select @restore_db_flag = 'y'
raiserror('-- Here is the DB restore command being executed', -1,-1) with nowait
exec dbo.dbasp_PrintLarge @Restore_cmd


BEGIN TRY
	Exec (@Restore_cmd)
END TRY
BEGIN CATCH
	IF @FullReset = 0
	BEGIN
		SET @FullReset = 1
		SET @NoFullRestores = 0
		raiserror('-- *** WARNING: RETRYING RESTORE AS FULL RESET ***', -1,-1) with nowait
		GOTO CreateRestoreScript
	END
	raiserror('-- *** ERROR: PROBLEM DURRING RESTORE ***', -1,-1) with nowait
	Select @error_count = @error_count + 1
	GOTO label99
END CATCH


IF DB_ID(@NewDBName)IS NULL
BEGIN
	IF @FullReset = 0
	BEGIN
		SET @FullReset = 1
		SET @NoFullRestores = 0
		raiserror('-- *** WARNING: RETRYING RESTORE AS FULL RESET ***', -1,-1) with nowait
		GOTO CreateRestoreScript
	END
	raiserror('-- *** ERROR: DATABASE DOES NOT EXIST AFTER RESTORE ***', -1,-1) with nowait
	Select @error_count = @error_count + 1
	GOTO label99
END


IF @LeaveNORECOVERY = 0
BEGIN
	IF DATABASEPROPERTYEX (@NewDBName,'status') <> 'ONLINE'
	   begin
		If @complete_on_diffOnly_fail = 'y'
		   begin
			--  finish the restore and send the DBA's an email
			Select @save_subject = 'DBAOps:  prerestore Failure for server ' + @@servername
			Select @save_message = 'Unable to restore the differential file for database ''' + @NewDBName + ''', the restore will be completed without the differential.'
			EXEC DBAOps.dbo.dbasp_sendmail
				@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
				--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
				@subject = @save_subject,
				@message = @save_message


			select @Restore_cmd = ''
			select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @NewDBName + ' WITH RECOVERY'


			Print 'The differential restore failed.  Completing restore for just the database using the following command;'
			Print @Restore_cmd
			raiserror('', -1,-1) with nowait


			Exec (@Restore_cmd)


			If DATABASEPROPERTYEX (@NewDBName,'status') <> 'ONLINE'
			   begin
				Print 'DBA Error:  Restore Failure (Standard DIF restore - Unable to finish restore without the DIF) for command ' + @Restore_cmd
				Select @error_count = @error_count + 1
				goto label99
			   end
		   end
		Else
		   begin
			Print 'DBA Error:  Restore Failure (Standard DIF restore) for command ' + @Restore_cmd
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end


	--  Turn off auto shrink and auto stats for @NewDBName restores
	If @NewDBName is not null and @NewDBName <> '' and DATABASEPROPERTYEX (@NewDBName,'status') = 'ONLINE'
	   begin
		select @miscprint = '--  ALTER DATABASE OPTIONS'
		Print @miscprint
		Print ''


		Print 'Here are the Alter Database Option commands being executed;'
		select @cmd = 'ALTER DATABASE [' + @NewDBName + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)


		select @cmd = 'ALTER DATABASE [' + @NewDBName + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)


		select @cmd = 'ALTER DATABASE [' + @NewDBName + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)


		Select @save_SQLcollation = CONVERT (varchar, SERVERPROPERTY('collation'));
		If (SELECT collation_name FROM master.sys.databases WHERE name = @NewDBName) <> @save_SQLcollation
		   begin
			Select @cmd = 'ALTER DATABASE [' + @NewDBName + '] COLLATE ' + @save_SQLcollation
			Print @cmd


			Begin Try
				Exec(@cmd)
			End Try
			Begin Catch
				Print ''
				select @miscprint = '--  Unable to Alter Collation for DB ' + @NewDBName
				Print @miscprint
				Print ''
			End Catch
		   end
	   end


	-- Shrink DB LDF Files if requested
	If @post_shrink = 'y' and DATABASEPROPERTYEX (@NewDBName,'status') = 'ONLINE'
	   begin
		Print '--NOTE:  Post Restore LDF file shrink was requested'
		Print ' '


		Select @miscprint = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @NewDBName + ''''
		print  @miscprint
		Select @cmd = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @NewDBName + ''''


		select @miscprint = 'go'
		print  @miscprint
		Print ' '


		exec(@cmd)
	   end
END


-------------------   end   --------------------------


label99:


If @error_count > 0
   begin
	raiserror('DBAERROR: CRITICAL ERROR OCCURED',16,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_prerestore2] TO [public]
GO
