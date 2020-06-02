SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Verify]


/*********************************************************
 **  Stored Procedure dbasp_Backup_Verify
 **  Written by Steve Ledridge, Virtuoso
 **  August 13, 2012
 **
 **  This dbasp is set up to verify recent sql backups.
 **
 ***************************************************************/
 as
SET	TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- Do not lock anything, and do not get held up by any locks.
SET	NOCOUNT ON
SET	ANSI_WARNINGS OFF
--	================================================================================================================
--	Revision History
--	Date			Author     			Desc
--	==========	====================	========================================================================
--	08/13/2012	Steve Ledridge			New process.
--	09/12/2012	Steve Ledridge			Modified process to run Verifyies in a parallel thread and monitoring
--										it for progress. If no progress is made after 10 minutes, checking of
--										that file is aborted. If a file is Locked and older than 4 hours, it is
--										forcably unlocked so that it can be checked. all progress is logged in
--										[DBAOps].[dbo].[EventLog] WHERE [cEModule] = 'dbasp_Backup_Verify'
--	10/05/2012	Steve Ledridge			Modified call to dbasp_SpawnAsyncTSQLThread to use new @GroupName parameter
--										Moved cleanup of output file from dbasp_SpawnAsyncTSQLThread to this process
--										Added checked Condition that output file was not created.
--										Removed RAISEERROR from this process so that it does not error out and continue
--										running other DB checks. checking of results will be added to
--										health report and/or final step in agent job so that all checks are
--										performed and logged.
--	04/23/2013	Steve Ledridge			Removed code related to dbasp_SpawnAsyncTSQLThread and the forcably unlock.
--	04/29/2013	Steve Ledridge			Will now not check files until 7 min after backup complete.
--	09/17/2013	Steve Ledridge			Added cleanup for table dbo.backup_log.
--	11/11/2016	Steve Ledridge			Modified Select to exclude backups to NUL or NUL:
--	11/21/2017	Steve Ledridge			Modified to use Better Logic for excluding missing files and examining files
--	================================================================================================================


-----------------  declares  ------------------
DECLARE		 @miscprint				nvarchar(255)
			,@cmd					varchar(8000)
			,@cmd2					varchar(8000)
			--,@G_O					nvarchar(2)
			--,@charpos				int
			--,@outpath3 				nvarchar(500)
			--,@outpath_archive		nvarchar(500)
			--,@file_exists_flag		char(1)
			--,@path_exists_flag		char(1)
			--,@file_inuse_flag		char(1)
			,@processed_flag		char(1)
			,@HoldBackupName		nvarchar(260)
			--,@BkUpMethod			nvarchar(10)
			,@save_backup_set_id	int
			,@save_type				char(1)
			,@save_filegroup_name	sysname
			,@save_DBname			sysname
			,@parms					sysname
			,@cEModule				sysname
			,@cECategory			sysname
			,@cEEvent				nVarChar(max)
			,@cEGUID				uniqueidentifier
			,@cEMessage				nvarchar(max)
			,@cEStat_Duration		FLOAT
			,@StartDate				DATETIME
			,@StopDate				DATETIME
			,@TXT					VarChar(8000)
			,@NestLevel				INT
			,@ErrorsFound			INT
			,@SetSize				INT

DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					SYSNAME


	EXEC DBAOps.dbo.dbasp_GetPaths 
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


Select		@cEModule			= 'dbasp_Backup_Verify'
			,@cEGUID			= NEWID()
			,@NestLevel			= 0
			,@ErrorsFound		= 0
			,@processed_flag	= 'n'

create table #resultstring (message varchar (2500) null)


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------
EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1
SET	@TXT = REPLICATE('-',80)
EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
EXEC	DBAOps.dbo.dbasp_Print 'Backup Verify Process',@NestLevel,1,1
EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1
SET	@TXT = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1
SET	@TXT = REPLICATE('-',80)
EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1


SET	@NestLevel = @NestLevel + 1


DECLARE BackupVerifyCursor CURSOR
KEYSET
FOR
SELECT		DISTINCT
			bs.backup_set_id
			, bs.database_name
			, bs.type
			, bf.filegroup_name
			, bmf.physical_device_name
FROM		msdb.dbo.backupset bs with (NOLOCK)
JOIN		msdb.dbo.backupfile bf with (NOLOCK)
		ON	bs.backup_set_id = bf.backup_set_id
JOIN		msdb.dbo.backupmediafamily bmf with (NOLOCK)
		ON	bs.media_set_id = bmf.media_set_id
LEFT JOIN	(
			SELECT	DISTINCT
					[cEEvent]
			FROM	[DBAOps].[dbo].[EventLog] WITH(NOLOCK)
			WHERE	[cEModule] = 'dbasp_Backup_Verify'
				AND	[cEMessage] IN ('Valid','Invalid','File Not Found','Path not found')
			) el
		ON el.[cEEvent] = bmf.physical_device_name


WHERE		bs.backup_start_date > getdate()-30
		AND	bs.backup_finish_date < getdate()-.005
		AND	bf.is_present = 1
		AND	bmf.physical_device_name NOT LIKE '{%'
		AND	bf.filegroup_name is not null
		AND	bs.type in ('D','F','I')
		AND	bs.server_name = @@servername
		AND el.[cEEvent] IS NULL
		--AND	bmf.physical_device_name NOT IN	(
		--									SELECT	DISTINCT
		--											[cEEvent]
		--									FROM	[DBAOps].[dbo].[EventLog] WITH(NOLOCK)
		--									WHERE	[cEModule] = 'dbasp_Backup_Verify'
		--									  AND	[cEMessage] IN ('Valid','Invalid','File Not Found')
		--									)
		AND	bmf.physical_device_name NOT IN ('NUL','NUL:')
ORDER BY	1 desc


OPEN BackupVerifyCursor
FETCH NEXT FROM BackupVerifyCursor INTO @save_backup_set_id
										,@save_DBname
										,@save_type
										,@save_filegroup_name
										,@HoldBackupName


WHILE (@@fetch_status <> -1)
BEGIN
	Select @processed_flag = 'y'


	IF (@@fetch_status <> -2)
	BEGIN
		-------------------------------------------------------
		--	CREATE HEADER FOR EACH FILE TO BE CHECKED
		-------------------------------------------------------
		--EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1
		SET	@TXT = REPLICATE('-',80)
		EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
		SET	@NestLevel = @NestLevel + 1
		EXEC	DBAOps.dbo.dbasp_Print @save_DBname,@NestLevel,1,1
		EXEC	DBAOps.dbo.dbasp_Print @HoldBackupName,@NestLevel,1,1
		SET	@NestLevel = @NestLevel - 1
		EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
		--EXEC	DBAOps.dbo.dbasp_Print ' ',@NestLevel,1,1
		SET	@NestLevel = @NestLevel + 1

		-------------------------------------------------------
		--	CHECK FOR MISSING OR INUSE FILE
		-------------------------------------------------------


		RAISERROR('-- Checking %s',-1,-1,@HoldBackupName) WITH NOWAIT

		If DBAOps.dbo.dbaudf_GetFileProperty(REPLACE(@HoldBackupName,DBAOps.dbo.dbaudf_GetFileFromPath(@HoldBackupName),''),'folder','exists') = 'True'  --  The Path is Valid
		BEGIN

			If DBAOps.dbo.dbaudf_GetFileProperty(@HoldBackupName,'file','exists') = 'True'  --  The file Is Valid
			BEGIN

				If DBAOps.dbo.dbaudf_GetFileProperty(@HoldBackupName,'file','inuse') = '0'  --  The file is not inuse
				BEGIN

					Select @cEMessage = 'File is Good'
				END
				ELSE
					Select @cEMessage = 'File In Use'
			END
			ELSE
				Select @cEMessage = 'File Not Found'
		END
		ELSE
			Select @cEMessage = 'Path not found'


		SELECT	@cECategory	= @save_DBname
				,@cEEvent	= @HoldBackupName


		exec [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1
					,@NestLevel = @NestLevel


		-----------------------------------------------------------------------
		--	IF FILE IS INVALID THEN SKIP IT
		-----------------------------------------------------------------------
		IF	@cEMessage != 'File is Good'
		   begin
			GOTO EndOfFileLoop
		   end


		-----------------------------------------------------------------------
		--		GENERATE AN RUN VALIDATE COMMAND BASED ON FILE TYPE
		-----------------------------------------------------------------------
		SELECT	@StartDate		= GetDate()
		Delete from #resultstring


		If @HoldBackupName like '%.sqb' OR @HoldBackupName like '%.sqd' OR @HoldBackupName like '%.mdf'
		BEGIN
			SELECT @cEEvent	= 'RedGate Command'

			---------------------------------------------------
			--	LOG PRE
			---------------------------------------------------
			EXEC [dbo].[dbasp_LogEvent]
						 @cEModule
						,@cECategory
						,@cEEvent
						,@cEGUID
						,@cEMessage = @cmd
						,@cEMethod_Screen = 1
						,@cEMethod_TableLocal = 1
						,@NestLevel = @NestLevel


			--  Redgate verify syntax
	   		SELECT @parms = ' WITH SINGLERESULTSET'


			Select @cmd = 'master.dbo.sqlbackup'
			Select @cmd2 = '-SQL "RESTORE VERIFYONLY'
					+ ' FROM DISK = [' + rtrim(@HoldBackupName)
					+ ']' + @parms
			Select @cmd2 = @cmd2 + '"'

			--Print @cmd
			--Print @cmd2
			--Print ' '
			Insert into #resultstring exec @cmd @cmd2
			--select * from #resultstring
			---------------------------------------------------
			--	PARSE VERIFY RESULTS
			---------------------------------------------------
			SET @StopDate = GetDate()


			If not exists (select 1 from #resultstring where message like '%is valid%')
			   begin
				Select @cEMessage = 'Invalid'
			   end
			Else
			   begin
				Select @cEMessage = 'Valid'
			   end


		END
		ELSE
		BEGIN
			SELECT @cEEvent	= 'Native Command'


			---------------------------------------------------
			--	LOG PRE
			---------------------------------------------------
			EXEC [dbo].[dbasp_LogEvent]
						 @cEModule
						,@cECategory
						,@cEEvent
						,@cEGUID
						,@cEMessage = @cmd
						,@cEMethod_Screen = 1
						,@cEMethod_TableLocal = 1
						,@NestLevel = @NestLevel


			--  Standard verify syntax
			Select @parms = ''


			SELECT @SetSize = ISNULL((
									SELECT	TOP 1 CAST(DBAOps.dbo.dbaudf_ReturnPart(REPLACE(Text,'_','|'),4) AS INT)
									FROM	DBAOps.dbo.dbaudf_RegexMatches(@HoldBackupName,'SET_[0-9][0-9]_OF_[0-9][0-9]')
									),1)
			BEGIN TRY
				IF EXISTS(SELECT * From DBAOps.dbo.dbaudf_BackupScripter_GetHeaderList(@SetSize,DBAOps.dbo.dbaudf_GetFileFromPath(@HoldBackupName),@HoldBackupName))
					Select @cEMessage = 'Valid'
			END TRY
			BEGIN CATCH
					EXEC DBAOps.dbo.dbasp_GetErrorInfo
					Select @cEMessage = 'Invalid'
			END CATCH


		END

       	---------------------------------------------------
		--	LOG RESULTS
		---------------------------------------------------
		SELECT	@cEEvent			= @HoldBackupName
				,@cEStat_Duration	= DATEDIFF(second,@StartDate,@StopDate) -- GRANULARITY IN SECONDS RESULT IN MINUTES


		EXEC [dbo].[dbasp_LogEvent]
					 @cEModule
					,@cECategory
					,@cEEvent
					,@cEGUID
					,@cEMessage
					,@cEStat_Duration	= @cEStat_Duration
					,@cEMethod_Screen = 1
					,@cEMethod_TableLocal = 1
					,@NestLevel = @NestLevel


		If @cEMessage = 'Invalid'
		BEGIN
			SET @ErrorsFound = @ErrorsFound + 1
			Select @miscprint = 'DBA ERROR: Backup verification failed for DB ' + @save_DBname + ' and backup file ' + @HoldBackupName
			RAISERROR (@miscprint,-1,-1) WITH NOWAIT


		END

		EndOfFileLoop:
		SET @NestLevel = @NestLevel - 1


	END
	FETCH NEXT FROM BackupVerifyCursor INTO @save_backup_set_id
						,@save_DBname
						,@save_type
						,@save_filegroup_name
						,@HoldBackupName
END


CLOSE BackupVerifyCursor
DEALLOCATE BackupVerifyCursor


--  Cleanup for table dbo.backup_log (keep 90 days history)
RAISERROR ('',-1,-1) WITH NOWAIT
Select	@miscprint = 'Cleanup for table ''dbo.backup_log''.'
RAISERROR (@miscprint,-1,-1) WITH NOWAIT


Delete from dbo.backup_log where BackupDate < getdate()-90


lable99:


If @processed_flag = 'n'
   begin
	RAISERROR ('',-1,-1) WITH NOWAIT
	Select @miscprint = 'Note:  No rows processed'
	RAISERROR (@miscprint,-1,-1) WITH NOWAIT
   end


IF @ErrorsFound > 0
BEGIN
	Select @miscprint = 'DBA ERROR: Backup verification failed for ' + CAST(@ErrorsFound AS VarChar(10)) + ' backup file(s).'
	raiserror(67015, -1, -1, @miscprint)
END


drop table #resultstring
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Verify] TO [public]
GO
