SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FixJobLogOutputFiles] 
						(
						@NestLevel					INT		= 0
						,@Verbose					INT		= 0
						,@PrintOnly					BIT		= 1
						,@ForcePath					BIT		= 0
						,@OldPath					VarChar(max) = NULL
						,@NoCheckExisting			BIT		= 0
						)

/**************************************************************
 **  Stored Procedure dbasp_FixJobLogOutputFiles                  
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}                
 **  July 17, 2012                                      
 **  
 **  This dbasp is set up to fix the name and/or path of the job step
 **  output file for all existing Job Steps.
 **
 **		INPUT PARAMETERS:
 **
 **		@NestLevel	USED TO DEFINE PADDING TO THE LEFT OF ALL TEXT OUTPUT.
 **
 **		@Verbose	LEVELS OF TEXT OUTPUT
 **						-1	= NO OUTPUT AT ALL
 **						 0	= OUTPUT ERRORS ONLY
 **						 1	= OUTPUT ALL INCLUDING ANY DEBUG OR STATUS MESSAGES
 **
 **		@PrintOnly		1	= ONLY SHOW WHAT WOULD BE DONE, MAKES NO CHANGES
 **
 **		@ForcePath		1	= CHANGE PATH TO CURRENT DEFAULT LOG OUTPUT PATH
 **
 **		@OldPath		FOR USE WITH @ForcePath=1 ONLY CHANGE WHERE CURRENT PATH MATCHES THIS PARAMETER
 **
 ** --	EXEC [dbo].[dbasp_FixJobLogOutputFiles] @PrintOnly = 0, @NoCheckExisting = 1,  @ForcePath = 1 
 ** --	EXEC [dbo].[dbasp_FixJobLogOutputFiles] @PrintOnly = 0, @ForcePath = 1 
 ***************************************************************/
  as
  SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	04/24/2012	Steve Ledridge		New process (cloned from dbasp_dba_sqlsetup).
--	07/17/2012	Steve Ledridge		Modified _SQLjob_logs folder & share to be on the same drive as the _backup Share
--									-- _backup Share Must Exist before running this.
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	03/26/2013	Steve Ledridge		Resolved issue with Null output_file_name for job steps.
--	08/26/2015	Steve Ledridge		Added exclusions for all Jobs not owned by sa
--	09/09/2015	Steve Ledridge		Modified sa check to force conversion of sid to varchar.
--	04/03/2018	Steve Ledridge		Modified to make usable in ${{secrets.COMPANY_NAME}} Environment.
--	======================================================================================

/***

--***/
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET	NOCOUNT ON
	SET ANSI_WARNINGS ON
	
											
		
	DECLARE		@CheckDate					DateTime
	DECLARE		@EnableCodeComments			INT
	DECLARE		@save_EnableCodeComments	INT
	DECLARE		@PrintWidth					INT
	DECLARE		@MSG						VARCHAR(MAX)
	DECLARE		@StatusPrint				INT
	DECLARE		@DebugPrint					INT
	DECLARE		@OutputPrint				INT

	DECLARE		@DataPath					VarChar(8000)
				,@LogPath					VarChar(8000)
				,@BackupPathL				VarChar(8000)
				,@BackupPathN				VarChar(8000)
				,@BackupPathN2				VarChar(8000)
				,@DBASQLPath				VarChar(8000)
				,@SQLAgentLogPath			VarChar(8000)
				,@DBAArchivePath			VarChar(8000)
				,@EnvBackupPath				VarChar(8000)
				,@SQLEnv					VarChar(10)


	DECLARE		@CMDTable			Table	(
											[CMD]			VarChar(MAX),
											[RevertCMD]		VarChar(MAX)
											)
									
	DECLARE		@CMD					varchar	(8000)
	DECLARE		@RevertCMD				varchar	(8000)

	DECLARE		@JobLogFileList				TABLE	(
													[job_id]					[uniqueidentifier]	NOT NULL,
													[step_id]					[int]				NOT NULL,
													[step_name]					[sysname]			NOT NULL,
													[subsystem]					[nvarchar](40)		NOT NULL,
													[command]					[nvarchar](MAX)		NULL,
													[flags]						[int]				NOT NULL,
													[additional_parameters]		[ntext]				NULL,
													[cmdexec_success_code]		[int]				NOT NULL,
													[on_success_action]			[tinyint]			NOT NULL,
													[on_success_step_id]		[int]				NOT NULL,
													[on_fail_action]			[tinyint]			NOT NULL,
													[on_fail_step_id]			[int]				NOT NULL,
													[server]					[sysname]			NULL,
													[database_name]				[sysname]			NULL,
													[database_user_name]		[sysname]			NULL,
													[retry_attempts]			[int]				NOT NULL,
													[retry_interval]			[int]				NOT NULL,
													[os_run_priority]			[int]				NOT NULL,
													[output_file_name]			[nvarchar](200)		NULL,
													[last_run_outcome]			[int]				NOT NULL,
													[last_run_duration]			[int]				NOT NULL,
													[last_run_retries]			[int]				NOT NULL,
													[last_run_date]				[int]				NOT NULL,
													[last_run_time]				[int]				NOT NULL,
													[proxy_id]					[int]				NULL,
													[step_uid]					[uniqueidentifier]	NULL,
													[JobName]					[sysname]			NULL,
													[FileStatus]				[varchar](500)		NULL,
													[FileName]					[nvarchar](200)		NULL,
													[Folder]					[nvarchar](4000)	NULL
													)


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


	--exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupPathL output
				
	-- SET VALUE IF IT DOES NOT EXIST
	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty('EnableCodeComments', default, default, default, default, default, default))
		EXEC sys.sp_addextendedproperty		@Name = 'EnableCodeComments', @value = 0

	-- SET STARTING VALUES
	SELECT		@PrintWidth					= 80
				,@OutputPrint				= CASE WHEN @Verbose >= 0 THEN 1 ELSE 0 END
				,@StatusPrint				= CASE WHEN @Verbose >  0 THEN 1 ELSE 0 END
				,@DebugPrint				= CASE WHEN @Verbose >  1 THEN 1 ELSE 0 END
				,@CheckDate					= GetDate()
				,@EnableCodeComments		= CASE @DebugPrint WHEN 1 THEN 1 ELSE 0 END
				,@save_EnableCodeComments	= COALESCE(CAST([value] AS INT),0)
	FROM	fn_listextendedproperty('EnableCodeComments', default, default, default, default, default, default)
											
		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='STARTING '+COALESCE(CAST(Objectpropertyex(@@Procid,'BaseType')AS SYSNAME),'')+COALESCE(', ['+CAST(Object_Name(@@Procid)AS SYSNAME)+']',''),@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------

	-- CHANGE VALUE IF SPECIFIED WITH @Verbose VALUE
	EXEC	sys.sp_updateextendedproperty	@Name	= 'EnableCodeComments',@value	= @EnableCodeComments

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG='PREVIOUS "EnableCodeComments" VALUE WAS '+CASE @save_EnableCodeComments WHEN 1 THEN 'ON' ELSE 'OFF' END ,@MSG='DEBUG: '+REPLICATE(' ',(@PrintWidth-7-LEN(@MSG)))+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		SELECT @MSG='DATABASE EXTENDED PROPERTY "EnableCodeComments" IS ENABLED',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel
		-------------------------------------------------------------------------------------------------------

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='GETTING PATH FOR SQLJOB_LOG SHARE',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------

	-- GET SQLJOB_LOG SHARE PATH
	--exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupPathL output
	--SET @LogPath = @BackupPathL + '\SQLAgentLogs'


		-------------------------------------------------------------------------------------------------------
		SELECT @MSG='@SQLAgentLogPath = '+QUOTENAME(CAST(@SQLAgentLogPath AS VarChar(max)),'"'),@MSG='DEBUG: '+REPLICATE(' ',(@PrintWidth-7-LEN(@MSG)))+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		-------------------------------------------------------------------------------------------------------

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='GETTING JOB STEP DATA',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	--	POPULATE @JobLogFileList with the contents of msdb..sysjobsteps along with the Job Name, 
	--	File status, and parsed file and path of the log file specified in the step.
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------

	INSERT INTO	@JobLogFileList
	SELECT		*,
				(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)									AS [JobName]
				,CASE @NoCheckExisting WHEN 0 THEN	CASE DBAOps.dbo.dbaudf_GetFileProperty(output_file_name,'file','InUse')
														WHEN '0'			THEN 'File is Good'
														WHEN '1'			THEN 'Permission Denied (in use)'
														WHEN '2'			THEN 'Bad Path or FileName'
														ELSE 'Unknown'
														END ELSE 'NOCHECK' END
																											AS [FileStatus]
				,DBAOps.dbo.dbaudf_GetFileFromPath(output_file_name)										AS [FileName]
				,REPLACE(output_file_name,DBAOps.dbo.dbaudf_GetFileFromPath(output_file_name),'')			AS [Folder] -- select *
	FROM		msdb..sysjobsteps T1
	WHERE		NULLIF(output_file_name,'') IS NOT NULL
		-- DO NOT RESET JOBS OWNED BY NON-SA
		--AND	(SELECT convert(varchar(50),owner_sid,1) FROM msdb.dbo.sysjobs where job_id = T1.job_id) = '0x01'
	UNION ALL
	SELECT		*
			,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)	AS [JobName]
			,'na'								AS [FileStatus]
			,'na'								AS [FileName]
			,'na'								AS [Folder]
	FROM		msdb..sysjobsteps T1
	WHERE		subsystem in ('LogReader', 'Snapshot')
		-- DO NOT RESET JOBS OWNED BY NON-SA
		--AND	(SELECT convert(varchar(50),owner_sid,1) FROM msdb.dbo.sysjobs where job_id = T1.job_id) = '0x01'
	UNION ALL
	SELECT		*
			,(SELECT name FROM msdb..sysjobs WHERE job_id = T1.job_id)	AS [JobName]
			,'Null'								AS [FileStatus]
			,NULL								AS [FileName]
			,NULL								AS [Folder]
	FROM		msdb..sysjobsteps T1
	WHERE		NULLIF(output_file_name,'') IS NULL
		AND	subsystem not in ('LogReader', 'Snapshot')
		-- DO NOT RESET JOBS OWNED BY NON-SA
		--AND	(SELECT convert(varchar(50),owner_sid,1) FROM msdb.dbo.sysjobs where job_id = T1.job_id) = '0x01'

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='GENERATING OUTPUT COMMANDS',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------

	-- DEBUG STEP --
	IF @DebugPrint = 1
		SELECT * FROM @JobLogFileList

	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	--	POPULATE @CMDTable with a record for each job log step that requires a change to the job log file
	--
	--	USING CTE's (Common Table Expression)
	--		BadOutputFiles:	The entries in @JobLogFileList that need changed and Identifying their "BAD REASON"
	--			BAD REASON:
	--				'Other Server'	Path is a UNC pointing to another server name
	--				'Using Share'	Path is a UNC pointing to this server name
	--				'Change Path'	@ForcePath = 1, existing value points to @OldPath, & @OldPath IS NOT the current path to the SQLJOB_LOG Share
	--				'Wrong Path'	@ForcePath = 1 & the existing values path IS NOT the current path to the SQLJOB_LOG Share
	--				'No File'		No log file specified
	--				'Bad Path'		The path for the specified file is not valid
	--				'Bad FileName'	The file name specified can not be used because of invalid characters
	--				'Permissions'	The path specified will not allow a file to be written.
	--
	--		ValidCounts:	A distinct count of "GOOD" log names by other steps in the same job
	--		AutoFixes:		Identification of steps that have no log and other steps refer to a single file name.
	--
	--	Each Section following the "INSERT INTO @CMDTable" line is a seperate query identifying a specific
	--		Issue with a set of "BAD" entries and generating the statement used to "Fix" it allong with
	--		a rollback statement that can be used if needed.
	--
	--	@CMDTable SECTIONS:
	--		PATH_CHANGE:	IF BADREASON IS 'Wrong Path','Change Path','Other Server','Using Share' (Changes Path, Not FileName)
	--		AUTOFIX:		IF BADREASON IS 'No File' AND JOB IS IN "AutoFixes" CTE (Uses same file as other steps)
	--		NOFILE:			IF BADREASON IS 'No File' AND JOB IS NOT IN "AutoFixes" CTE (creates file name from job name)
	--		BADCHAR:		IF BADREASON IS 'Bad FileName' (Filters Bad Characters out of FileName)
	--		MISSINGSUBDIR:	IF BADREASON IS 'Bad Path' AND Path is Subdir under the SQLJOB_LOG Share (Create Missing Sub Directory, no change to file or path)
	--
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	;WITH		BadOutputFiles
				AS
				(
				SELECT		job_id
							,JobName
							,step_id
							,step_uid
							,CASE
								WHEN FileStatus = 'NOCHECK'															THEN 'No File'
								WHEN LEFT([Folder],2) = '\\'
									AND	[Folder] NOT LIKE '\\'+REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'%'
																													THEN 'Other Server'
								WHEN LEFT([Folder],2) = '\\'														THEN 'Using Share'																			
								WHEN @ForcePath = 1 
									AND [Folder] = @OldPath
									AND [Folder] != @SQLAgentLogPath												THEN 'Change Path'
								WHEN @ForcePath = 1
									AND @OldPath IS NULL
									AND [Folder] != @SQLAgentLogPath												THEN 'Wrong Path'
								WHEN nullif([output_file_name],'') IS NULL
								 AND FileStatus <> 'na'																THEN 'No File'
								WHEN [FileStatus] = 'Path not found'
								 AND DBAOps.dbo.dbaudf_GetFileProperty([Folder],'Folder','Name') IS NULL			THEN 'Bad Path'
								WHEN [FileStatus] = 'Path not found'												THEN 'Bad FileName'
								WHEN [FileStatus] = 'Logon failure: unknown user name or bad password'				THEN 'Permissions'
								ELSE [FileStatus]
								END AS [BadReason]
							,[FileName]
							,[Folder]
							,[output_file_name]
							,[subsystem]
							,[database_name]
				FROM		@JobLogFileList
				)
				,ValidCounts
				AS
				(
				SELECT		T2.[job_id]
							,T2.[output_file_name]
							,COUNT(*) OVER(PARTITION BY T2.[job_id]) [ValidCount]
				FROM		BadOutputFiles		T1
				JOIN		msdb..sysjobsteps	T2
						ON	T1.job_id = T2.job_id
						AND	T2.step_uid NOT IN (SELECT step_uid FROM BadOutputFiles)
				GROUP BY	T2.[job_id]
							,T2.[output_file_name]
				)
				,AutoFixes
				AS
				(
				SELECT	*
				FROM	ValidCounts									
				WHERE	[ValidCount] = 1					
				)
	INSERT INTO @CMDTable			
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	--		BEGINNING OF @CMDTable SECTIONS
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- PATH_CHANGE:	PATH CHANGE OR FIX IS BEING FORCED
	SELECT		'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+@SQLAgentLogPath+B.[FileName]+''''+ CASE WHEN b.subsystem NOT IN ('SSIS','ANALYSISCOMMAND','CmdExec','PowerShell') THEN ', @flags=6' ELSE '' END + CASE WHEN DB_ID(b.database_name) IS NULL THEN ', @database_name = ''master''' ELSE '' END
				,'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+B.output_file_name+''''	
	FROM		BadOutputFiles B
	WHERE		[BadReason] IN ('Wrong Path','Change Path','Other Server','Using Share')
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- AUTOFIX:	CURRENT OUTPUT_FILE_NAME IS BAD OR MISSING AND OTHER STEPS IN JOB ONLY REFER TO ONE OTHER GOOD OUTPUT_FILE_NAME
	UNION
	SELECT		'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+F.output_file_name+''''+ CASE WHEN b.subsystem NOT IN ('SSIS','ANALYSISCOMMAND','CmdExec','PowerShell') THEN ', @flags=6' ELSE '' END + CASE WHEN DB_ID(b.database_name) IS NULL THEN ', @database_name = ''master''' ELSE '' END 
				,'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+B.output_file_name+''''	
	FROM		BadOutputFiles B
	JOIN		AutoFixes F
			ON	F.job_id = B.job_id
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- NOFILE:	NO OUTPUT_FILE_NAME SPECIFIED
	UNION 
	SELECT		'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+@SQLAgentLogPath+
					DBAOps.dbo.dbaudf_FilterCharacters(
					STUFF(JobName,1,1,isnull(nullif(LEFT(JobName,1),'x'),''))
					,' -/:*?"<>|','I','_',1)
					+'.txt'+''''+ CASE WHEN b.subsystem NOT IN ('SSIS','ANALYSISCOMMAND','CmdExec','PowerShell') THEN ', @flags=6' ELSE '' END + CASE WHEN DB_ID(b.database_name) IS NULL THEN ', @database_name = ''master''' ELSE '' END
				,'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''''	
	FROM		BadOutputFiles B
	WHERE		B.BadReason = 'No File'
			AND	job_id NOT IN (Select job_id FROM AutoFixes)
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- BADCHAR:	BAD CHARACTER IN FILE NAME
	UNION
	SELECT		'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST([job_id] AS VarChar(50))
					+ ''' ,@step_id='+CAST([step_id] AS VarChar(10))
					+ ' ,@output_file_name='''+[Folder]+'\'
					+ DBAOps.dbo.dbaudf_FilterCharacters([FileName],' -/:*?"<>|','I','_',1)+''''+ CASE WHEN b.subsystem NOT IN ('SSIS','ANALYSISCOMMAND','CmdExec','PowerShell') THEN ', @flags=6' ELSE '' END + CASE WHEN DB_ID(b.database_name) IS NULL THEN ', @database_name = ''master''' ELSE '' END
				,'exec msdb.dbo.sp_update_jobstep @job_id='''+CAST(B.job_id AS VarChar(50))
					+''' ,@step_id='+CAST(B.step_id AS VarChar(10))
					+' ,@output_file_name='''+B.output_file_name+''''	
	FROM		BadOutputFiles B
	WHERE		BadReason='Bad FileName'
			AND [FileName] != DBAOps.dbo.dbaudf_FilterCharacters([FileName],' -/:*?"<>|','I','',1)
			AND	job_id NOT IN (Select job_id FROM AutoFixes)
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	-- MISSINGSUBDIR:	MISSING SUBDIRECTORY UNDER LOG SHARE
	UNION 
	SELECT		'exec xp_CMDShell ''mkdir ' + [Folder] + ''''
				,''
	FROM		BadOutputFiles B
	WHERE		BadReason='Bad Path'
			AND	[Folder] LIKE @SQLAgentLogPath+'%'
			AND	job_id NOT IN (Select job_id FROM AutoFixes)
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	--		END OF @CMDTable SECTIONS
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------

	IF @@ROWCOUNT = 0 GOTO NoFixesNeeded

	-- DEBUG STEP --
	IF @DebugPrint = 1
		SELECT * FROM @CMDTable

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='START GENERATING OUTPUT',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,0,@StatusPrint
		-------------------------------------------------------------------------------------------------------

		-------------------------------------------------------------------------------------------------------
		-- START GENERATING OUTPUT STATEMENTS
		-------------------------------------------------------------------------------------------------------
		EXEC DBAOps.dbo.dbasp_Print	'GO'																	,@NestLevel,0,@OutputPrint
		EXEC DBAOps.dbo.dbasp_Print	'DECLARE	@RevertCMD		Bit'										,@NestLevel,0,@OutputPrint
		EXEC DBAOps.dbo.dbasp_Print	'SET		@RevertCMD		= 0'										,@NestLevel,0,@OutputPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		SELECT @MSG='CHANGE @RevertCMD VALUE TO 1 AND RERUN TO REVERT CHANGES',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		-------------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	--
	--	CURSOR THROUGH ENTRIES IN @CMDTable AND...
	--		PROCESS:		IF @PrintOnly = 0
	--		PRINT CHANGE:	TSQL STATEMENT TO FIX ISSUE
	--		PRINT ROLLBACK:	TSQL STATEMENT TO UNDO FIX
	--
	-------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------
	DECLARE FixStepOutputFile CURSOR
	FOR SELECT '	'+CMD,'	'+RevertCMD FROM @CMDTable
	OPEN FixStepOutputFile
	FETCH NEXT FROM FixStepOutputFile INTO @CMD, @RevertCMD
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			EXEC DBAOps.dbo.dbasp_Print	''																,@NestLevel,0,@OutputPrint
			EXEC DBAOps.dbo.dbasp_Print	'IF @RevertCMD = 0 '											,@NestLevel,0,@OutputPrint
			EXEC DBAOps.dbo.dbasp_Print	@CMD															,@NestLevel,0,@OutputPrint

			IF @PrintOnly = 0
			BEGIN
				SET @NestLevel = @NestLevel + 1
					-------------------------------------------------------------------------------------------------------
					SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
					SELECT @MSG='STATEMENT WAS EXECUTED.',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
					SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
					-------------------------------------------------------------------------------------------------------
				EXEC (@CMD)
				SET @NestLevel = @NestLevel - 1
			END	

			EXEC DBAOps.dbo.dbasp_Print	'IF @RevertCMD = 1'												,@NestLevel,0,@OutputPrint
			EXEC DBAOps.dbo.dbasp_Print	@RevertCMD														,@NestLevel,0,@OutputPrint		
		END
		FETCH NEXT FROM FixStepOutputFile INTO @CMD, @RevertCMD
	END
	CLOSE FixStepOutputFile
	DEALLOCATE FixStepOutputFile

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,0,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='DONE GENERATING OUTPUT',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------

	-- SET BACK VALUE IF CHANGED AT THE BEGINNING
	EXEC	sys.sp_updateextendedproperty	@Name	= 'EnableCodeComments', @value	= @EnableCodeComments

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG='EXITING '+COALESCE(CAST(Objectpropertyex(@@Procid,'BaseType')AS SYSNAME),'')+COALESCE(', ['+CAST(Object_Name(@@Procid)AS SYSNAME)+']',''),@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@StatusPrint
		-------------------------------------------------------------------------------------------------------
											
		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		SELECT @MSG='DATABASE EXTENDED PROPERTY "EnableCodeComments" IS STILL ENABLED',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@DebugPrint
		-------------------------------------------------------------------------------------------------------

	GOTO ExitProcess
	NoFixesNeeded:

		-------------------------------------------------------------------------------------------------------
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		SELECT @MSG='***  NO FIXES WERE NEEDED  ***',@MSG=REPLICATE(' ',(@PrintWidth-LEN(@MSG))/2)+@MSG;EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		SELECT @MSG=REPLICATE('-',@PrintWidth);EXEC DBAOps.dbo.dbasp_Print @MSG,@NestLevel,1,@OutputPrint
		-------------------------------------------------------------------------------------------------------

	ExitProcess:	
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_FixJobLogOutputFiles] TO [public]
GO
