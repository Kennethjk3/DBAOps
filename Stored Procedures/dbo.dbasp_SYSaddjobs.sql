SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- EXEC dbaops.dbo.dbasp_startjob_archive
-- [dbo].[dbasp_SYSaddjobs]						-- JUST MAINT AND UTIL
-- [dbo].[dbasp_SYSaddjobs] @jobname = ''		-- EVERY JOB
-- [dbo].[dbasp_SYSaddjobs] @jobname = 'XXX'	-- ALL BUT MAINT AND UTIL
-- [dbo].[dbasp_SYSaddjobs] 'MAINT_-_Daily_Index_Maintenance'

CREATE   PROCEDURE [dbo].[dbasp_SYSaddjobs]
	(
	  @jobname			sysname			= null     /** job name input parm **/
	, @leave_enabled	char(1)			= 'y'
	, @appl_name		Varchar(50)		= NULL
    , @Folder			Varchar(MAX)	= NULL
	, @SeperateFiles	bit				= 1
	, @WriteToCentral	Bit				= 1
	)
/*********************************************************
 **  Stored Procedure dbasp_SYSaddjobs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 5, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add sql jobs
 **
 **  Output member is SYSaddjobs.gsql
 ***************************************************************
 **  Execution Instructions:
 **  This sproc can be used to script all SQL jobs on the server,
 **  or select jobs based on the input parameter provided.  If the
 **  input parameter is left blank, all jobs will be scripted.
 **
 **  If script(s) for a specific job or set of jobs are desired,
 **  code the job name (or the first few characters of the job name)
 **  in the input parameter.  For example;
 **
 **  exec dbasp_sysaddjobs  @jobname = 'APPL'
 **
 **  This will script out all jobs that start with 'APPL'
 **
 **  If script(s) for a specific set of jobs by application are desired,
 **  first look in the job description, note the first 2-4 characters.
 **  Then, supply those characters as the input parameter.  For example;
 **
 **  exec dbasp_sysaddjobs  @appl_name = 'gmsa'
 **
 **  This will script out all jobs that are with 'GMSA'
 ***************************************************************/
AS
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	06/10/2002	Steve Ledridge		 @@servername changes to support multiple instances
--	07/03/2002	Steve Ledridge		Added code to delete the job if it exists prior
--									to re-adding it.
--	07/05/2002	Steve Ledridge		Fixed null 'muser' problem (job owner not in sysxlogins).
--	08/21/2002	Steve Ledridge		Mass re-write fixed multi schedule problem, added input
--									parm for job name and fixed the multiple 'go' issue.
--	09/20/2002	Steve Ledridge		Fixed code in the delete job section
--	09/24/2002	Steve Ledridge		Modified fix servername code for shares
--	09/27/2002	Steve Ledridge		Fixed long lines (over 255)
--	10/03/2002	Steve Ledridge		Fixed problem with dynamic servername change
--	10/10/2002	Steve Ledridge		Change query so only local jobs are scripted and
--									fixed the orphaned line feed an CR problem
--	02/10/2003	Steve Ledridge		Added dynamic code for output file path resolution
--	03/31/2003	Steve Ledridge		Jobs will now be scripted out disabled by default. A
--									new input parm has been added to allow for scripting leaving
--									enabled intact.
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	05/29/2003	Steve Ledridge		Added dynamic code for  @@servername in cmd field
--	04/21/2004	Steve Ledridge		Convert servername with instance and no leading back slash
--	09/01/2004	Steve Ledridge		Fixed problem with  @server in job step when specified.
--	05/09/2005	Steve Ledridge		Added code for production job status systeminfo table update.
--	02/22/2006	Steve Ledridge		Modified for sql 2005
--	08/04/2006	Steve Ledridge		Updated the fix servername process throughout.
--	11/30/2006	Steve Ledridge		Changes nvarchar(4000) to nvarchar(max).
--	05/22/2008	Steve Ledridge		Change output to chunks (up to 9) of just over 3000 bytes.
--	07/30/2008	Steve Ledridge		Split step code into 3000 byte chunks in the output script
--									because of some truncation selecting large amounts of text in
--									an nvarchar(max) variable.  It seems to work if you do it in chunks.
--	12/05/2008	Steve Ledridge		Added parameter to allow for application jobs can be scripted out.
--	02/02/2009	Steve Ledridge		Added code for production job status DEPLinfo table update.
--	10/09/2009	Steve Ledridge		Removed code for DB systeminfo.
--	05/31/2012	Steve Ledridge		New code for DBAOps.
--	04/29/2013	Steve Ledridge		Removed code for DB DEPLinfo.
--	04/19/2016	Steve Ledridge		New code for AG related category.
--	10/09/2017	Steve Ledridge		Modified to Run in ${{secrets.COMPANY_NAME}} Environment
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	  @miscprint						nvarchar(max)
	, @cmd								nvarchar(max)
	, @outprint01						nvarchar(max)
	, @G_O             					nvarchar(2)
	, @charpos							int
	, @startpos							int
	, @charpos02						int
	, @charpos_diff						int
	, @cmd_planname						sysname
	, @saveplanname						sysname
	, @saveserver_name					sysname
	, @saveplanid						uniqueidentifier
	, @hold_jobid						varchar(200)
	, @save_mname						sysname
	, @save_cat_class					sysname
	, @save_cat_type					sysname
	, @command_num						int
	, @command_name						sysname
	, @output_flag						char(1)
	, @cursor_text						nvarchar(max)
	, @parm01							varchar(100)
	, @logpath							varchar(255)
	, @logpath_len						int


DECLARE
	  @job_id							UNIQUEIDENTIFIER
	, @jname							SYSNAME
	, @jenabled							TINYINT
	, @jdescription						NVARCHAR(512)
	, @jstart_step_id					INT
	, @jcategory_id						INT
	, @jnotify_level_eventlog			INT
	, @jnotify_level_email				INT
	, @jnotify_level_netsend			INT
	, @jnotify_level_page				INT
	, @jnotify_email_operator_id		INT
	, @jnotify_netsend_operator_id		INT
	, @jnotify_page_operator_id			INT
	, @jdelete_level					INT
	, @jowner_sid						VARBINARY(85)
	, @vserver_id						INT
	, @cname							SYSNAME
	, @category_class					INT
	, @category_type					TINYINT


Declare
	  @len								int
	, @pos								int
	, @ascii							nvarchar(max)


DECLARE
	  @step_id							int
	, @step_name						sysname
	, @subsystem						nvarchar(40)
	, @command							nvarchar(max)
	, @flags							int
	, @cmdexec_success_code				int
	, @on_success_action				tinyint
	, @on_success_step_id				int
	, @on_fail_action					tinyint
	, @on_fail_step_id					int
	, @server							sysname
	, @database_name					sysname
	, @database_user_name				sysname
	, @retry_attempts					int
	, @retry_interval					int
	, @os_run_priority					int
	, @output_file_name					nvarchar(200)


DECLARE
	  @schedule_id						int
	, @sname							sysname
	, @senabled							int
	, @sfreq_type						int
	, @sfreq_interval					int
	, @sfreq_subday_type				int
	, @sfreq_subday_interval			int
	, @sfreq_relative_interval			int
	, @sfreq_recurrence_factor			int
	, @sactive_start_date				int
	, @sactive_end_date					int
	, @sactive_start_time				int
	, @sactive_end_time					int
	, @snext_run_date					int
	, @snext_run_time					int
	, @sdate_created					datetime
	, @BackupPathL						VarChar(8000)
	, @PathAndFile						VarChar(8000)
	, @DontExtractReplica				INT = 0

DECLARE		@DataPath					VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@ScriptFilePath			Varchar(8000)

-- GET PATHS
exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DataPath output
exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @LogPath output
exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupPathL output
SELECT		@BackupPathN		= '\\SDCSQLBACKUPFS.${{secrets.DOMAIN_NAME}}\DatabaseBackups\' + UPPER(dbo.dbaudf_GetLocalFQDN())
SELECT		@DBASQLPath			= @BackupPathL + '\dbasql'
SELECT		@SQLAgentLogPath	= @BackupPathL + '\SQLAgentLogs'
SELECT		@DBAArchivePath		= @BackupPathL + '\dba_archive'


-- GET ENVIRO OVERRIDE
SELECT		@EnvBackupPath		= env_detail
FROM		dbo.local_serverenviro
WHERE		env_type			= 'backup_path'
----------------  initial values  -------------------


SELECT	 @PathAndFile =  COALESCE(@Folder,@DBAArchivePath) + '\tests.txt';
EXEC	[DBAOps].[dbo].[dbasp_FileAccess_Write] '',  @PathAndFile,0,1 -- MAKE SURE PATH EXISTS
SELECT	 @PathAndFile =  COALESCE(@Folder,@DBAArchivePath);

----------------------  Main header  ----------------------
SET @miscprint  = convert(varchar(30),getdate(),9)


--RAISERROR( '',-1,-1) WITH NOWAIT
--RAISERROR( '/**************************************************************',-1,-1) WITH NOWAIT
--RAISERROR( 'Generated SQL - SYSaddjobs'  ,-1,-1) WITH NOWAIT
--RAISERROR( 'For Server: %s on %s',-1,-1,@@servername ,@miscprint)
--RAISERROR( '',-1,-1) WITH NOWAIT


--IF  @leave_enabled = 'y'
--BEGIN
--	RAISERROR( 'NOTE:  The following SQL jobs were scripted using the input parm',-1,-1) WITH NOWAIT
--	RAISERROR( '        @leave_enabled = ''y''.',-1,-1) WITH NOWAIT
--END
--ELSE
--BEGIN
--	RAISERROR( 'NOTE:  By default, jobs are scripted as disabled by',-1,-1) WITH NOWAIT
--	RAISERROR( '       this process.  To script jobs reflecting the current',-1,-1) WITH NOWAIT
--	RAISERROR( '       run status of enabled or disabled, use the input parm',-1,-1) WITH NOWAIT
--	RAISERROR( '        @leave_enabled = ''y'', and re-script the jobs.',-1,-1) WITH NOWAIT
--END


--RAISERROR( '**************************************************************/',-1,-1) WITH NOWAIT
--RAISERROR( 'use [msdb]',-1,-1) WITH NOWAIT
--RAISERROR( 'go',-1,-1) WITH NOWAIT
--RAISERROR( '',-1,-1) WITH NOWAIT


/****************************************************************
 *                MainLine
 ***************************************************************/


DECLARE JobCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
Select		j.job_id
			,j.name
			,j.enabled
			,j.description
			,j.start_step_id
			,j.category_id
			,j.notify_level_eventlog
			,j.notify_level_email
			,j.notify_level_netsend
			,j.notify_level_page
			,j.notify_email_operator_id
			,j.notify_netsend_operator_id
			,j.notify_page_operator_id
			,j.delete_level
			,j.owner_sid
			,v.server_id
			,c.name
			,c.category_class
			,c.category_type
From		msdb.dbo.sysjobs  j
JOIN		msdb.dbo.sysjobservers  v			ON	j.job_id				= v.job_id
JOIN		msdb.dbo.syscategories  c			ON	j.category_id			= c.category_id
JOIN		master.sys.sysservers  m			ON	j.originating_server_id = m.srvid
												AND	m.srvname				=  @@servername

WHERE		(@jobname IS NULL AND (j.name Like 'MAINT%' OR j.name LIKE 'UTIL%'))
	 OR		(NULLIF(@jobname,'XXX') IS NOT NULL AND j.name LIKE @jobname +'%')
	 OR		(@jobname = 'XXX' AND NOT(j.name Like 'MAINT%' OR j.name LIKE 'UTIL%'))

ORDER BY	j.name


OPEN JobCursor;
FETCH JobCursor INTO  @job_id, @jname, @jenabled, @jdescription, @jstart_step_id, @jcategory_id, @jnotify_level_eventlog, @jnotify_level_email, @jnotify_level_netsend, @jnotify_level_page, @jnotify_email_operator_id, @jnotify_netsend_operator_id, @jnotify_page_operator_id, @jdelete_level, @jowner_sid, @vserver_id, @cname, @category_class, @category_type;
WHILE ( @@fetch_status <> -1)
BEGIN
	IF ( @@fetch_status <> -2)
	BEGIN
		RAISERROR('-- Processing Job: %s',-1,-1,@jname) WITH NOWAIT

		SET @DontExtractReplica = 0
		IF @cname LIKE 'AG%' AND [dbo].[dbaudf_AG_Get_Primary](STUFF(@cname,1,3,'')) NOT LIKE 'ERROR%'
		BEGIN		-- ONLY EXTRACT AG JOBS FROM THE PRIMARY TO SAVE ON CENTRAL

			IF [dbo].[dbaudf_AG_Get_Primary](STUFF(@cname,1,3,'')) != @@SERVERNAME 
			BEGIN
				RAISERROR ('-- Not Scripting Job From Replica.',-1,-1) WITH NOWAIT
				SET @DontExtractReplica = 1
				SET @CMD = NULL
				GOTO SkipScripting
			END
		END

		--RAISERROR ('-- DER= %d  Category= %s',-1,-1,@DontExtractReplica,@cname) WITH NOWAIT

		SET @jdescription = REPLACE(COALESCE(@jdescription,'No description available.'),'''','''''')
		----------------------------
		---------------------------- CURSOR LOOP TOP JOBS
			SET @CMD = '/**************************************************************'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'Generated By SQL - SYSaddjobs' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'For Server: ' + @@SERVERNAME +' on ' + @miscprint
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''


			IF  @leave_enabled = 'y'
			BEGIN
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'NOTE:  The following SQL jobs were scripted using the input parm'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        @leave_enabled = ''y''.'
			END
			ELSE
			BEGIN
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'NOTE:  By default, jobs are scripted as disabled by'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '       this process.  To script jobs reflecting the current'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '       run status of enabled or disabled, use the input parm'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        @leave_enabled = ''y'', and re-script the jobs.'
			END


			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '**************************************************************/'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'use [msdb]'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'go'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

			--RAISERROR( '/*************************************************************************************************',-1,-1) WITH NOWAIT
			--RAISERROR( 'Create new job: %s',-1,-1,@jname) WITH NOWAIT
			--RAISERROR( '**************************************************************************************************/',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '/*************************************************************************************************'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'Create new job: ' + @jname
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '**************************************************************************************************/'

			IF  @cname LIKE 'AG%'
			BEGIN
				--RAISERROR( 'If not exists (select 1 from msdb.[dbo].[syscategories] where name = ''%s'')',-1,-1,@cname) WITH NOWAIT
				--RAISERROR( '	EXEC msdb.dbo.sp_add_category  @class=N''JOB'',  @type=N''LOCAL'',  @name=N''%s''',-1,-1,@cname) WITH NOWAIT
				--RAISERROR( '',-1,-1) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'If not exists (select 1 from msdb.[dbo].[syscategories] where name = '''+@cname+''')'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	EXEC msdb.dbo.sp_add_category  @class=N''JOB'',  @type=N''LOCAL'',  @name=N'''+@cname+''''
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
			END


			/***  Print declares and begin tran ***/
			--RAISERROR( 'BEGIN TRANSACTION' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @JobID BINARY(16)' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @ReturnCode INT' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @charpos INT' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @miscprint nvarchar(500)' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @save_output_filename sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @save_jname sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @save_sname sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @parm01 sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @logpath sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @BackupPathL sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  DECLARE  @PathAndFile sysname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  SELECT   @ReturnCode = 0' ,-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'BEGIN TRANSACTION' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @JobID BINARY(16)' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @ReturnCode INT' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @charpos INT' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @miscprint nvarchar(500)' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @save_output_filename sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @save_jname sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @save_sname sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @parm01 sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @logpath sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @BackupPathL sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  DECLARE  @PathAndFile sysname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  SELECT   @ReturnCode = 0' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''


			/*** GET THE LOCAL PATH FOR AGENT JOB LOG FILES ***/
			--RAISERROR( '	-- GET SQLJOB_LOG SHARE PATH',-1,-1) WITH NOWAIT
			--RAISERROR( '	exec master.dbo.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''Software\Microsoft\MSSQLServer\MSSQLServer'', N''BackupDirectory'', @BackupPathL output',-1,-1) WITH NOWAIT
			--RAISERROR( '	SET @LogPath = @BackupPathL + ''\SQLAgentLogs'';',-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT
			--RAISERROR( '	SELECT	@PathAndFile = @LogPath + ''\tests.txt'';',-1,-1) WITH NOWAIT
			--RAISERROR( '	EXEC [DBAOps].[dbo].[dbasp_FileAccess_Write] '''', @PathAndFile,0,1 -- MAKE SURE PATH EXISTS',-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	-- GET SQLJOB_LOG SHARE PATH'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	exec master.dbo.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''Software\Microsoft\MSSQLServer\MSSQLServer'', N''BackupDirectory'', @BackupPathL output'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	SET @LogPath = @BackupPathL + ''\SQLAgentLogs'';'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	SELECT	@PathAndFile = @LogPath + ''\tests.txt'';'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	EXEC [DBAOps].[dbo].[dbasp_FileAccess_Write] '''', @PathAndFile,0,1 -- MAKE SURE PATH EXISTS'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

			/***  Print add catagory name command ***/
			Select  @save_cat_class = CASE
										WHEN  @category_class = 1 THEN 'Job'
										WHEN  @category_class = 2 THEN 'Alert'
										WHEN  @category_class = 3 THEN 'Operator'
										ELSE 'Job'
										END


			Select  @save_cat_type = CASE
										WHEN  @category_type = 1 THEN 'Local'
										WHEN  @category_type = 2 THEN 'Multiserver'
										WHEN  @category_type = 3 THEN 'None'
										ELSE 'Local'
										END

			--RAISERROR( '  -- Verify the proper category exists' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N''%s'' AND category_class=''%d'')',-1,-1,@cname,@category_class) WITH NOWAIT
			--RAISERROR( '     begin' ,-1,-1) WITH NOWAIT
			--RAISERROR( '        EXEC  @ReturnCode = msdb.dbo.sp_add_category  @class=N''%s'',  @type=N''%s'',  @name=N''%s''',-1,-1,@save_cat_class,@save_cat_type,@cname) WITH NOWAIT
			--RAISERROR( '        IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
			--RAISERROR( '     end' ,-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Verify the proper category exists' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'''+@cname+''' AND category_class='''+CAST(@category_class AS Varchar(50))+''')'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     begin' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        EXEC  @ReturnCode = msdb.dbo.sp_add_category  @class=N'''+@save_cat_class+''',  @type=N'''+@save_cat_type+''',  @name=N'''+@cname+''''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     end' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''


			/***  Print check and delete old job ***/
			--RAISERROR( '  -- Delete the job with the same name (if it exists)' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  Select  @JobID = job_id' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  from   msdb.dbo.sysjobs',-1,-1) WITH NOWAIT
			--RAISERROR( '  where (name = N''%s'')',-1,-1,@jname) WITH NOWAIT
			--RAISERROR( '  If ( @JobID is not null)',-1,-1) WITH NOWAIT
			--RAISERROR( '     begin',-1,-1) WITH NOWAIT
			--RAISERROR( '        -- Check if the job is a multi-server job',-1,-1) WITH NOWAIT
			--RAISERROR( '        IF (exists (Select * From msdb.dbo.sysjobservers',-1,-1) WITH NOWAIT
			--RAISERROR( '                    Where (job_id =  @JobID) and (server_id <> 0)))',-1,-1) WITH NOWAIT
			--RAISERROR( '           begin',-1,-1) WITH NOWAIT
			--RAISERROR( '              -- This is a mult server job, so abort the script',-1,-1) WITH NOWAIT
			--RAISERROR( '              RAISERROR( ''Unable to delete job ''''%s'''' since there is already a multi-server job with this name.'',16,1) WITH NOWAIT',-1,-1,@jname) WITH NOWAIT
			--RAISERROR( '              GOTO QuitWithRollback',-1,-1) WITH NOWAIT
			--RAISERROR( '           end',-1,-1) WITH NOWAIT
			--RAISERROR( '        Else',-1,-1) WITH NOWAIT
			--RAISERROR( '           begin',-1,-1) WITH NOWAIT
			--RAISERROR( '              -- Delete the [local] job',-1,-1) WITH NOWAIT
			--RAISERROR( '              EXEC msdb.dbo.sp_delete_job  @job_name = ''%s''',-1,-1,@jname) WITH NOWAIT
			--RAISERROR( '              Select  @JobID = null',-1,-1) WITH NOWAIT
			--RAISERROR( '           end',-1,-1) WITH NOWAIT
			--RAISERROR( '     end',-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Delete the job with the same name (if it exists)' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Select  @JobID = job_id' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  from   msdb.dbo.sysjobs'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  where (name = N'''+@jname+''')'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  If ( @JobID is not null)'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     begin'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        -- Check if the job is a multi-server job'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        IF (exists (Select * From msdb.dbo.sysjobservers'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                    Where (job_id =  @JobID) and (server_id <> 0)))'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '           begin'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              -- This is a mult server job, so abort the script'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              RAISERROR( ''Unable to delete job '''''+@jname+''''' since there is already a multi-server job with this name.'',16,1) WITH NOWAIT'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              GOTO QuitWithRollback'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '           end'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        Else'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '           begin'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              -- Delete the [local] job'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              EXEC msdb.dbo.sp_delete_job  @job_name = '''+@jname+''''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '              Select  @JobID = null'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '           end'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     end'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

			SELECT	@save_mname = name
			From	sys.server_principals
			WHERE	sid = @jowner_sid


			/***  Print add job command ***/
			--RAISERROR( '  -- Add the job' ,-1,-1) WITH NOWAIT
			--RAISERROR( '  Select  @save_jname = N''%s''',-1,-1,@jname) WITH NOWAIT
			--RAISERROR( '  EXEC  @ReturnCode = msdb.dbo.sp_add_job  @job_id =  @JobID OUTPUT' ,-1,-1) WITH NOWAIT
			--RAISERROR( '                                           , @job_name =  @save_jname' ,-1,-1) WITH NOWAIT
			--RAISERROR( '                                           , @owner_login_name = N''%s''',-1,-1,@save_mname) WITH NOWAIT
			--RAISERROR( '                                           , @description = ''%s''',-1,-1,@jdescription) WITH NOWAIT
			--RAISERROR( '                                           , @category_name = N''%s''',-1,-1,@cname) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Add the job' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Select  @save_jname = N'''+@jname+''''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXEC  @ReturnCode = msdb.dbo.sp_add_job  @job_id =  @JobID OUTPUT' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @job_name =  @save_jname' 
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @owner_login_name = N'''+@save_mname+''''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @description = '''+@jdescription+''''
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @category_name = N'''+@cname+''''


			IF  @leave_enabled = 'n'
			BEGIN
				--RAISERROR( '                                           , @enabled = 0' ,-1,-1) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @enabled = 0'
			END
			ELSE
			BEGIN
				--RAISERROR( '                                           , @enabled = %d',-1,-1,@jenabled) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @enabled = '+CAST(@jenabled AS Varchar(50))
			END


			--RAISERROR( '                                           , @notify_level_email = %d',-1,-1,@jnotify_level_email) WITH NOWAIT
			--RAISERROR( '                                           , @notify_level_page = %d',-1,-1,@jnotify_level_page) WITH NOWAIT
			--RAISERROR( '                                           , @notify_level_netsend = %d',-1,-1,@jnotify_level_netsend) WITH NOWAIT
			--RAISERROR( '                                           , @notify_level_eventlog = %d',-1,-1,@jnotify_level_eventlog) WITH NOWAIT
			--RAISERROR( '                                           , @delete_level= %d',-1,-1,@jdelete_level) WITH NOWAIT
			--RAISERROR( '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
			--RAISERROR( '',-1,-1) WITH NOWAIT

			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @notify_level_email = ' + CAST(@jnotify_level_email AS Varchar(50))
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @notify_level_page = '+CAST(@jnotify_level_page AS Varchar(50))
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @notify_level_netsend = ' + CAST(@jnotify_level_netsend AS Varchar(50))
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @notify_level_eventlog = ' + CAST(@jnotify_level_eventlog AS Varchar(50))
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                           , @delete_level= ' + CAST(@jdelete_level AS Varchar(50))
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback'
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

		SET @command_num = 0
-- PRINT 1
-- PRINT @CMD

		DECLARE JobStepCursor CURSOR
		FOR
		Select		t.step_id
					,t.step_name
					,t.subsystem
					,t.command
					,t.flags
					,t.cmdexec_success_code
					,t.on_success_action
					,t.on_success_step_id
					,t.on_fail_action
					,t.on_fail_step_id
					,t.server
					,t.database_name
					,t.database_user_name
					,t.retry_attempts
					,t.retry_interval
					,t.os_run_priority
					,t.output_file_name
		From		msdb.dbo.sysjobsteps t
		Where		t.job_id =  @job_id


		OPEN JobStepCursor;
		FETCH JobStepCursor INTO  @step_id, @step_name, @subsystem, @command, @flags, @cmdexec_success_code, @on_success_action, @on_success_step_id, @on_fail_action, @on_fail_step_id, @server, @database_name, @database_user_name, @retry_attempts, @retry_interval, @os_run_priority, @output_file_name;
		WHILE ( @@fetch_status <> -1)
		BEGIN
			IF ( @@fetch_status <> -2)
			BEGIN
				----------------------------
				---------------------------- CURSOR LOOP TOP JOB STEPS

				--RAISERROR( '',-1,-1) WITH NOWAIT
				--RAISERROR( '  -- Preparation for job step %d ',-1,-1, @step_id) WITH NOWAIT
				--RAISERROR( '',-1,-1) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Preparation for job step ' + CAST(@step_id AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

				/***  Fix @output_file_name - job output file path (use the standard share 'servername_sqljob_logs') ***/
				--RAISERROR( '  -- Move the output file name and path to a variable' ,-1,-1) WITH NOWAIT
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Move the output file name and path to a variable' 

-- PRINT 2
-- PRINT @CMD
				If  @output_file_name is not null
				BEGIN
					Select @output_file_name = DBAOps.dbo.dbaudf_GetFileFromPath(@output_file_name)
					--RAISERROR( '  If  @logpath is not null' ,-1,-1) WITH NOWAIT
					--RAISERROR( '     begin' ,-1,-1) WITH NOWAIT
					--RAISERROR( '  Select  @save_output_filename =  @logpath + ''\%s''',-1,-1,@output_file_name) WITH NOWAIT
					--RAISERROR( '     end'  ,-1,-1) WITH NOWAIT
					--RAISERROR( '  Else'  ,-1,-1) WITH NOWAIT
					--RAISERROR( '     begin'  ,-1,-1) WITH NOWAIT
					--RAISERROR( '        Select  @save_output_filename = ''D:\%s''',-1,-1,@output_file_name) WITH NOWAIT
					--RAISERROR( '     end'  ,-1,-1) WITH NOWAIT
					--RAISERROR( '',-1,-1) WITH NOWAIT

					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  If  @logpath is not null' 
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     begin' 
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Select  @save_output_filename =  @logpath + ''\'+@output_file_name+''''
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     end'  
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Else'  
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     begin'  
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        Select  @save_output_filename = ''D:\'+@output_file_name+''''
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '     end'  
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
-- PRINT 2.1
				END
				ELSE
				BEGIN
					SET @output_file_name = dbo.dbaudf_Filter_ValidFileName(REPLACE(@jname,' ','_'),'_') + '.txt'

					--SET @output_file_name = DBAOps.dbo.dbaudf_FilterCharacters(STUFF(@JobName,1,1,isnull(nullif(LEFT(@JobName,1),'x'),'')),' -/:*?"<>|','I','_',1)+'.txt'
					--RAISERROR( '        Select  @save_output_filename =  @logpath + ''\%s''',-1,-1,@output_file_name) WITH NOWAIT
					--RAISERROR( '',-1,-1) WITH NOWAIT

					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '        Select  @save_output_filename =  @logpath + ''\'+COALESCE(@output_file_name,'?????')+''''
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''
-- PRINT 2.2
				END

-- PRINT 2.5
-- PRINT @CMD

				--/***  Print the process to save the command to a variable (needed to get the servername correct). ***/
				--RAISERROR( '  -- Move the command syntax for this job step to a variable' ,-1,-1) WITH NOWAIT
				SELECT	@command = REPLACE(@command,'''','''''')
				SELECT  @command_num  =  @command_num + 1

				--RAISERROR( '  Declare @command_vrb%d  NVARCHAR(MAX)' ,-1,-1,@command_num) WITH NOWAIT
				--RAISERROR( '  Select @command_vrb%d = ''',-1,-1,@command_num) WITH NOWAIT
				--EXEC DBAOps.dbo.dbasp_PrintLarge @Command
				--RAISERROR( '''',-1,-1) WITH NOWAIT
				--RAISERROR( '',-1,-1) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Declare @command_vrb'+CAST(@command_num AS Varchar(50))+'  NVARCHAR(MAX)' 
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Select @command_vrb'+CAST(@command_num AS Varchar(50))+' = ''' + @Command
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''''
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

				----  Fix CR's with out line feeds
				--Select  @pos = 1
				--Label90:
				--Select  @charpos = charindex(char(13), @command,  @pos)
				--IF  @charpos <> 0
				--   begin
				--	Select  @pos =  @charpos
				--	If substring( @command,  @charpos+1, 1) <> char(10)
				--	   begin
				--		select @command = stuff( @command,  @charpos, 1, char(13)+char(10))
				--		Select  @pos =  @pos + 1
				--	   end
				--   end


				--Select  @pos =  @pos + 1
				--Select  @charpos = charindex(char(13), @command,  @pos)
				--IF  @charpos <> 0
				--   begin
				--	goto label90
				--   end


				----  Fix line feeds with no preceeding CR
				--Select  @pos = 1
				--Label91:
				--Select  @charpos = charindex(char(10), @command,  @pos)
				--IF  @charpos <> 0
				--   begin
				--	Select  @pos =  @charpos
				--	If substring( @command,  @charpos-1, 1) <> char(13)
				--	   begin
				--		select @command = stuff( @command,  @charpos, 1, char(13)+char(10))
				--		Select  @pos =  @pos + 1
				--	   end
				--   end


				--Select  @pos =  @pos + 1
				--Select  @charpos = charindex(char(10), @command,  @pos)
				--IF  @charpos <> 0
				--   begin
				--	goto label91
				--   end


				----Select @command


				----  Split output into 3000 byte chunks, because print cannot handle more than 4000 at a time.
	   -- 			--RAISERROR( '  Select  ' +  @command_name + ' = ' +  @command_name + ''''
				----Print   @miscprint


				--Start_chunk:
				--IF len( @command) < 4000
				--BEGIN
				--	Select  @outprint01 = QUOTENAME(@command,'''')
				--	RAISERROR( '  Select  @command_vrb%d = @command_vrb%d + ''%s''',-1,-1,@command_num,@command_num,@outprint01) WITH NOWAIT
				--	goto end_chunks
				--END


				--SELECT  @pos = 3000
				--SELECT  @charpos = charindex(char(10), @command,  @pos)
				--IF  @charpos <> 0
				--BEGIN
				--	SELECT @outprint01 = QUOTENAME(left( @command,  @charpos),'''')
				--	SELECT @command = substring( @command,  @charpos+1, len( @command)- @charpos)
				--	RAISERROR( '  Select  @command_vrb%d = @command_vrb%d + ''%s''',-1,-1,@command_num,@command_num,@outprint01) WITH NOWAIT
				--END


				--If len( @command) > 0
				--   begin
				--	goto Start_chunk
				--   end


				--end_chunks:


				SET @flags = @flags | 6  -- make sure step is logging to a file and appending


				--RAISERROR( '',-1,-1) WITH NOWAIT
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

				/***  Now print the add job step command. ***/
				--RAISERROR( '  -- Add job step %d',-1,-1, @step_id) WITH NOWAIT
				--RAISERROR( '  Select  @save_sname = N''%s''',-1,-1,@step_name) WITH NOWAIT
				--RAISERROR( '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobstep  @job_id =  @JobID',-1,-1) WITH NOWAIT
				--RAISERROR( '                                               , @step_id = %d',-1,-1,@step_id) WITH NOWAIT
				--RAISERROR( '                                               , @step_name =  @save_sname' ,-1,-1) WITH NOWAIT
				--RAISERROR( '                                               , @command = @command_vrb%d',-1,-1,@command_num) WITH NOWAIT

-- PRINT 3
-- PRINT @CMD


				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Add job step '+ CAST(@step_id AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  Select  @save_sname = N'''+@step_name+''''
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobstep  @job_id =  @JobID'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @step_id = ' + CAST(@step_id AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @step_name =  @save_sname'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @command = @command_vrb' + CAST(@command_num AS Varchar(50))

				If @database_name is NULL
                BEGIN
					--RAISERROR( '                                               , @database_name = N''''',-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @database_name = N'''''
				END
				ELSE
                BEGIN
					--RAISERROR( '                                               , @database_name = N''%s''',-1,-1,@database_name) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @database_name = N'''+@database_name+''''
				END


				If @server is NULL
                BEGIN
					--RAISERROR( '                                               , @server = N''''' ,-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @server = N''''' 
				END
				Else If @server =  @@SERVERNAME
                BEGIN
					--RAISERROR( '                                               , @server =  @@servername' ,-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @server =  @@servername' 
				END
				ELSE
                BEGIN
					--RAISERROR( '                                               , @server = N''%s''',-1,-1,@server) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @server = N'''+@server+''''
				END


				If @database_user_name is NULL
                BEGIN
					--RAISERROR( '                                               , @database_user_name = N''''',-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @database_user_name = N'''''
				END
				ELSE
                BEGIN
					--RAISERROR( '                                               , @database_user_name = N''%s''',-1,-1,@database_user_name) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @database_user_name = N'''+@database_user_name+''''
				END

				--RAISERROR( '                                               , @subsystem = N''%s''',-1,-1,@subsystem) WITH NOWAIT
				--RAISERROR( '                                               , @cmdexec_success_code = %d',-1,-1,@cmdexec_success_code) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @subsystem = N'''+@subsystem+''''
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @cmdexec_success_code = '+ CAST(@cmdexec_success_code AS Varchar(50))

				IF @subsystem NOT IN ('CmdExec','ANALYSISCOMMAND','PowerShell')
				BEGIN
					--RAISERROR( '                                               , @flags = %d',-1,-1, @flags) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @flags = ' +CAST(@flags AS Varchar(50))
				END

				--RAISERROR( '                                               , @retry_attempts = %d',-1,-1, @retry_attempts) WITH NOWAIT
				--RAISERROR( '                                               , @retry_interval = %d',-1,-1, @retry_interval) WITH NOWAIT
				--RAISERROR( '                                               , @os_run_priority = %d',-1,-1, @os_run_priority) WITH NOWAIT

				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @retry_attempts = '+CAST(@retry_attempts AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @retry_interval = '+CAST(@retry_interval AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @os_run_priority = '+CAST(@os_run_priority AS Varchar(50))

-- PRINT 4
-- PRINT @CMD


				If @output_file_name is NULL
                BEGIN
					--RAISERROR( '                                               , @output_file_name = N''''',-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @output_file_name = N'''''
				END
				ELSE
                BEGIN
					--RAISERROR( '                                               , @output_file_name =  @save_output_filename',-1,-1) WITH NOWAIT
					SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @output_file_name =  @save_output_filename'
				END


				--RAISERROR( '                                               , @on_success_step_id = %d',-1,-1, @on_success_step_id) WITH NOWAIT
				--RAISERROR( '                                               , @on_success_action = %d',-1,-1, @on_success_action) WITH NOWAIT
				--RAISERROR( '                                               , @on_fail_step_id = %d',-1,-1, @on_fail_step_id) WITH NOWAIT
				--RAISERROR( '                                               , @on_fail_action = %d',-1,-1, @on_fail_action) WITH NOWAIT
				--RAISERROR( '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
				--RAISERROR( '',-1,-1) WITH NOWAIT


				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @on_success_step_id = '+CAST(@on_success_step_id AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @on_success_action = '+CAST(@on_success_action AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @on_fail_step_id = '+CAST(@on_fail_step_id AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                               , @on_fail_action = '+CAST(@on_fail_action AS Varchar(50))
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback'
				SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

				---------------------------- CURSOR LOOP BOTTOM JOB STEPS
				----------------------------
			END
 			FETCH NEXT FROM JobStepCursor INTO  @step_id, @step_name, @subsystem, @command, @flags, @cmdexec_success_code, @on_success_action, @on_success_step_id, @on_fail_action, @on_fail_step_id, @server, @database_name, @database_user_name, @retry_attempts, @retry_interval, @os_run_priority, @output_file_name;
		END
		CLOSE JobStepCursor;
		DEALLOCATE JobStepCursor;

-- PRINT 5
-- PRINT @CMD


		DECLARE JobScheduleCursor CURSOR
		FOR
		-- SELECT QUERY FOR CURSOR
		Select		d.schedule_id
					,d.name
					,d.enabled
					,d.freq_type
					,d.freq_interval
					,d.freq_subday_type
					,d.freq_subday_interval
					,d.freq_relative_interval
					,d.freq_recurrence_factor
					,d.active_start_date
					,d.active_end_date
					,d.active_start_time
					,d.active_end_time
					,js.next_run_date
					,js.next_run_time
					,d.date_created
		From		msdb.dbo.sysjobschedules  js, msdb.dbo.sysschedules  d
		where		js.schedule_id = d.schedule_id
			and		js.job_id =  @job_id


		OPEN JobScheduleCursor;
		FETCH JobScheduleCursor INTO  @schedule_id, @sname, @senabled, @sfreq_type, @sfreq_interval, @sfreq_subday_type, @sfreq_subday_interval, @sfreq_relative_interval, @sfreq_recurrence_factor, @sactive_start_date, @sactive_end_date, @sactive_start_time, @sactive_end_time, @snext_run_date, @snext_run_time, @sdate_created;
		WHILE ( @@fetch_status <> -1)
		BEGIN
			IF ( @@fetch_status <> -2)
			BEGIN
				----------------------------
				---------------------------- CURSOR LOOP TOP

					/***  Print add job schedule command ***/
					IF  @schedule_id is not null
					BEGIN
						--RAISERROR( '  -- Add the job schedules' ,-1,-1) WITH NOWAIT
						--RAISERROR( '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobschedule  @job_id =  @JobID' ,-1,-1) WITH NOWAIT
						--RAISERROR( '                                                   , @name = N''%s''',-1,-1,@sname ) WITH NOWAIT
						--RAISERROR( '                                                   , @enabled = %d',-1,-1, @senabled) WITH NOWAIT
						--RAISERROR( '                                                   , @freq_type = %d',-1,-1, @sfreq_type) WITH NOWAIT
						--RAISERROR( '                                                   , @active_start_date = %d',-1,-1, @sactive_start_date)  WITH NOWAIT
						--RAISERROR( '                                                   , @active_start_time = %d',-1,-1, @sactive_start_time)  WITH NOWAIT
						--RAISERROR( '                                                   , @freq_interval = %d',-1,-1, @sfreq_interval)  WITH NOWAIT
						--RAISERROR( '                                                   , @freq_subday_type = %d',-1,-1, @sfreq_subday_type)  WITH NOWAIT
						--RAISERROR( '                                                   , @freq_subday_interval = %d',-1,-1, @sfreq_subday_interval)  WITH NOWAIT
						--RAISERROR( '                                                   , @freq_relative_interval = %d',-1,-1, @sfreq_relative_interval)	 WITH NOWAIT
						--RAISERROR( '                                                   , @freq_recurrence_factor = %d',-1,-1, @sfreq_recurrence_factor)  WITH NOWAIT
						--RAISERROR( '                                                   , @active_end_date = %d',-1,-1, @sactive_end_date)  WITH NOWAIT
						--RAISERROR( '                                                   , @active_end_time = %d',-1,-1, @sactive_end_time)  WITH NOWAIT
						--RAISERROR( '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
						--RAISERROR( '',-1,-1) WITH NOWAIT



						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Add the job schedules' 
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobschedule  @job_id =  @JobID' 
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @name = N'''+@sname+''''
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @enabled = '+CAST(@senabled AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_type = '+CAST(@sfreq_type AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @active_start_date = '+CAST(@sactive_start_date AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @active_start_time = '+CAST(@sactive_start_time AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_interval = '+CAST(@sfreq_interval AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_subday_type = '+CAST(@sfreq_subday_type AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_subday_interval = '+CAST(@sfreq_subday_interval AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_relative_interval = '+CAST(@sfreq_relative_interval AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @freq_recurrence_factor = '+CAST(@sfreq_recurrence_factor AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @active_end_date = '+CAST(@sactive_end_date AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '                                                   , @active_end_time = '+CAST(@sactive_end_time AS Varchar(50))
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback'
						SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''



				END


				---------------------------- CURSOR LOOP BOTTOM
				----------------------------
			END
 			FETCH NEXT FROM JobScheduleCursor INTO  @schedule_id, @sname, @senabled, @sfreq_type, @sfreq_interval, @sfreq_subday_type, @sfreq_subday_interval, @sfreq_relative_interval, @sfreq_recurrence_factor, @sactive_start_date, @sactive_end_date, @sactive_start_time, @sactive_end_time, @snext_run_date, @snext_run_time, @sdate_created;
		END
		CLOSE JobScheduleCursor;
		DEALLOCATE JobScheduleCursor;

-- PRINT 6
-- PRINT @CMD


		/***  Print update job command ***/
		--RAISERROR( '  -- Update the job start step' ,-1,-1) WITH NOWAIT
		--RAISERROR( '  EXECUTE  @ReturnCode = msdb.dbo.sp_update_job  @job_id =  @JobID,  @start_step_id = %d',-1,-1, @jstart_step_id) WITH NOWAIT
		--RAISERROR( '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
		--RAISERROR( '',-1,-1) WITH NOWAIT

		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Update the job start step' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXECUTE  @ReturnCode = msdb.dbo.sp_update_job  @job_id =  @JobID,  @start_step_id = '+CAST(@jstart_step_id AS Varchar(50))
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

		/***  Print add job server command ***/
		--RAISERROR( '  -- Add the Target Servers' ,-1,-1) WITH NOWAIT
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Add the Target Servers'


		If  @vserver_id = 0
		BEGIN
			--RAISERROR( '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobserver  @job_id =  @JobID,  @server_name = N''(local)''',-1,-1) WITH NOWAIT
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobserver  @job_id =  @JobID,  @server_name = N''(local)'''
		END
		Else
		BEGIN
			Select  @saveserver_name = (Select srvname from master.sys.sysservers where srvid =  @vserver_id)
			--RAISERROR( '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobserver  @job_id =  @JobID,  @server_name = N''%s''',-1,-1,@saveserver_name) WITH NOWAIT
			SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  EXECUTE  @ReturnCode = msdb.dbo.sp_add_jobserver  @job_id =  @JobID,  @server_name = N'''+@saveserver_name+''''
		END


		--RAISERROR( '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' ,-1,-1) WITH NOWAIT
		--RAISERROR( '',-1,-1) WITH NOWAIT

		
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@ERROR <> 0 OR  @ReturnCode <> 0) GOTO QuitWithRollback' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

		/***  Print Update Production Job Status Info command ***/
		--RAISERROR( '  -- Update Production Job Status Info' ,-1,-1) WITH NOWAIT
		--RAISERROR( '  IF exists(select * from master.sys.sysdatabases where name = ''DBAOps'')',-1,-1) WITH NOWAIT
		--RAISERROR( '	  IF exists(select * from DBAOps.sys.objects where name = ''ProdJobStatus'')',-1,-1) WITH NOWAIT
		--RAISERROR( '		  IF exists(select * from DBAOps.dbo.ProdJobStatus where JobName = ''%s'')',-1,-1,@jname) WITH NOWAIT
		--RAISERROR( '			  update DBAOps.dbo.ProdJobStatus set JobStatus = %d where JobName = ''%s''',-1,-1,@jenabled,@jname) WITH NOWAIT
		--RAISERROR( '		  ELSE',-1,-1) WITH NOWAIT
		--RAISERROR( '			  insert into DBAOps.dbo.ProdJobStatus (JobName, JobStatus) values (''%s'',%d)',-1,-1,@jname,@jenabled) WITH NOWAIT
		--RAISERROR( '',-1,-1) WITH NOWAIT

		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  -- Update Production Job Status Info' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF exists(select * from master.sys.sysdatabases where name = ''DBAOps'')'
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '	  IF exists(select * from DBAOps.sys.objects where name = ''ProdJobStatus'')'
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '		  IF exists(select * from DBAOps.dbo.ProdJobStatus where JobName = '''+@jname+''')'
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '			  update DBAOps.dbo.ProdJobStatus set JobStatus = '+CAST(@jenabled AS Varchar(50))+' where JobName = '''+@jname+''''
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '		  ELSE'
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '			  insert into DBAOps.dbo.ProdJobStatus (JobName, JobStatus) values ('''+@jname+''','+CAST(@jenabled AS VarChar(50))+')'
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

-- PRINT 7
-- PRINT @CMD


		/***  Print the commit transaction commands ***/
		--RAISERROR( 'COMMIT TRANSACTION' ,-1,-1) WITH NOWAIT
		--RAISERROR( 'GOTO   EndSave' ,-1,-1) WITH NOWAIT
		--RAISERROR( 'QuitWithRollback:' ,-1,-1) WITH NOWAIT
		--RAISERROR( '  IF ( @@TRANCOUNT > 0) ROLLBACK TRANSACTION ' ,-1,-1) WITH NOWAIT
		--RAISERROR( 'EndSave:' ,-1,-1) WITH NOWAIT
		--RAISERROR( 'GO' ,-1,-1) WITH NOWAIT
		--RAISERROR( '',-1,-1) WITH NOWAIT

		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'COMMIT TRANSACTION' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'GOTO   EndSave' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'QuitWithRollback:' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ '  IF ( @@TRANCOUNT > 0) ROLLBACK TRANSACTION ' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'EndSave:' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ 'GO' 
		SET @CMD = @CMD+CHAR(13)+CHAR(10)+ ''

		Select  @output_flag	= 'y'
		EXEC dbo.dbasp_PrintLarge @CMD
		


		SET @ScriptFilePath = @PathAndFile + '\SQLAgentJob_' 
							+ CASE @@SERVERNAME 
								WHEN 'SDCPRORPT03'		 THEN 'CUBE_'
								WHEN 'SDCPROSQL04'		 THEN 'COMPOSER_'
								WHEN 'SDCPRORPT01'		 THEN 'REPORTING_'
								WHEN 'SDCPRODM02'		 THEN 'DATAMART_'
								WHEN 'SDCPROSQL05'		 THEN 'COMPOSER_'
								WHEN 'SDCPROSQL03'		 THEN 'COMPOSER_'
								WHEN 'SDCPROSSSQL02'	 THEN 'GRASP_'
								ELSE @@SERVERNAME +'_' END
							+ dbo.dbaudf_Filter_ValidFileName(REPLACE(@jname,' ','_'),'_') + '.sql'

		RAISERROR('-- Writing File %s',-1,-1,@ScriptFilePath) WITH NOWAIT

		EXEC DBAOps.dbo.dbasp_FileAccess_Write @InputText	= @CMD			
												,@path		= @ScriptFilePath
												,@append	= 0							
												,@ForceCrLf	= 1	

		IF @WriteToCentral = 1 AND @DontExtractReplica = 0
		BEGIN
			SET @ScriptFilePath = '\\SDCSQLTOOLS.DB.${{secrets.DOMAIN_NAME}}\dba_reports\AgentJobs\'
								+ CASE @@SERVERNAME 
									WHEN 'SDCPRORPT03'		 THEN 'CUBE\'
									WHEN 'SDCPROSQL04'		 THEN 'COMPOSER\'
									WHEN 'SDCPRORPT01'		 THEN 'REPORTING\'
									WHEN 'SDCPRODM02'		 THEN 'DATAMART\'
									WHEN 'SDCPROSQL05'		 THEN 'COMPOSER\'
									WHEN 'SDCPROSQL03'		 THEN 'COMPOSER\'
									WHEN 'SDCPROSSSQL02'	 THEN 'GRASP\'
									ELSE @@SERVERNAME +'' END
								+ '\SQLAgentJob_' 
								+ CASE @@SERVERNAME 
									WHEN 'SDCPRORPT03'		 THEN 'CUBE_'
									WHEN 'SDCPROSQL04'		 THEN 'COMPOSER_'
									WHEN 'SDCPRORPT01'		 THEN 'REPORTING_'
									WHEN 'SDCPRODM02'		 THEN 'DATAMART_'
									WHEN 'SDCPROSQL05'		 THEN 'COMPOSER_'
									WHEN 'SDCPROSQL03'		 THEN 'COMPOSER_'
									WHEN 'SDCPROSSSQL02'	 THEN 'GRASP_'
									ELSE @@SERVERNAME +'_' END
								+ dbo.dbaudf_Filter_ValidFileName(REPLACE(@jname,' ','_'),'_') + '.sql'

			RAISERROR('-- Writing File %s',-1,-1,@ScriptFilePath) WITH NOWAIT			

			EXEC DBAOps.dbo.dbasp_FileAccess_Write @InputText	= @CMD			
													,@path		= @ScriptFilePath
													,@append	= 0							
													,@ForceCrLf	= 1	

SkipScripting:

		RAISERROR('-------------------------------------------------------------------------------------------------------------------------------------------',-1,-1) WITH NOWAIT
		RAISERROR('-------------------------------------------------------------------------------------------------------------------------------------------',-1,-1) WITH NOWAIT
		RAISERROR('',-1,-1) WITH NOWAIT
		RAISERROR('',-1,-1) WITH NOWAIT
		RAISERROR('',-1,-1) WITH NOWAIT

		END
		---------------------------- CURSOR LOOP BOTTOM JOBS
		----------------------------
	END
 	FETCH NEXT FROM JobCursor INTO  @job_id, @jname, @jenabled, @jdescription, @jstart_step_id, @jcategory_id, @jnotify_level_eventlog, @jnotify_level_email, @jnotify_level_netsend, @jnotify_level_page, @jnotify_email_operator_id, @jnotify_netsend_operator_id, @jnotify_page_operator_id, @jdelete_level, @jowner_sid, @vserver_id, @cname, @category_class, @category_type;
END
CLOSE JobCursor;
DEALLOCATE JobCursor;


---------------------------  Finalization  -----------------------


If  @output_flag = 'n'
	RAISERROR('-- No output for this script.',-1,-1) WITH NOWAIT
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddjobs] TO [public]
GO
