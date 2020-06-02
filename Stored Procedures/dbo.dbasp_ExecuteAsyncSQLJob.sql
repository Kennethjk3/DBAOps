SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ExecuteAsyncSQLJob]	(
															@JobTitle				SYSNAME				= ''
															,@JobDescription		NVarChar(MAX)		= ''
															,@Step1Title			SYSNAME				= ''
															,@Step1Command			NVARCHAR(MAX)		
															,@Step2Title			SYSNAME				= ''
															,@Step2Command			NVARCHAR(MAX)		= ''
															,@Step3Title			SYSNAME				= ''
															,@Step3Command			NVARCHAR(MAX)		= ''
															,@DeleteOnFinish		BIT					= 1
															,@JobRunningUser		VARCHAR(100)		= NULL
															,@JobId					UNIQUEIDENTIFIER	= NULL OUTPUT
															)
AS
BEGIN
SET NOCOUNT ON;  

			DECLARE @Params					NVarChar(250)			
					,@Command				NVarChar(4000)
					,@SQLAgentLogPath		VarChar(2000)

			SET		@Params					= N'@jobid BINARY(16) OUT'

					-- GET AGENT LOG FILE PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths] @Verbose = 1
					EXEC DBAOps.dbo.dbasp_GetPaths @SQLAgentLogPath = @SQLAgentLogPath OUT

					-- DELETE JOB IF IT ALREADY EXISTS
					RAISERROR ('Deleting Dynamic Job %s if it already exists.',-1,-1,@JobTitle) WITH NOWAIT
					SET	@Command = 'DECLARE @jobId BINARY(16)
						SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = N''XXX_DBA_DYNAMIC_' + @JobTitle  + ''' 
						IF (@jobId IS NOT NULL)
						EXEC msdb.dbo.sp_delete_job @jobId'
					EXEC (@Command)

					-- CREATE JOB
					RAISERROR ('Creating Dynamic Job %s',-1,-1,@JobTitle) WITH NOWAIT
					SET @Command = 'EXEC msdb.dbo.sp_add_job @job_name=N''XXX_DBA_DYNAMIC_' + @JobTitle + ''', 
							@enabled=1, @notify_level_eventlog=0, @notify_level_email=0, 
							@notify_level_netsend=0, @notify_level_page=0, @delete_level='+CAST(@DeleteOnFinish AS CHAR(1))+', 
							@description=N'''+@JobDescription+''', 
							@category_name=N''[Uncategorized (Local)]'', 
							@owner_login_name=N''sa'', @job_id = @jobId OUTPUT'
					EXEC sp_executesql @Command,@Params,@jobid OUT

					-- ADD JOB STEP 1
					RAISERROR ('  - Adding Job Step 1',-1,-1) WITH NOWAIT
					SET	@Params = N'@jobid BINARY(16)'
					SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''1 - '+COALESCE(@Step1Title,'')+''', 
							@step_id=1, 
							@cmdexec_success_code=0, 
							@on_success_action=3, 
							@on_success_step_id=0, 
							@on_fail_action=2, 
							@on_fail_step_id=0, 
							@retry_attempts=0, 
							@retry_interval=0, 
							@os_run_priority=0, @subsystem=N''TSQL'', 
							@command=N'''+COALESCE(REPLACE(@Step1Command,'''',''''''),'')+''', 
							@database_name=N''master'', 
							@output_file_name=N''' +  COALESCE(@SQLAgentLogPath,'') + 'XXX_DBA_DYNAMIC_' + COALESCE(@JobTitle,'') +''',
							@flags=6'
					select @Command,@Step1Title,@Step1Command,@SQLAgentLogPath,@JobTitle
					EXEC sp_executesql @Command,@Params,@jobid

					IF NULLIF(@Step2Command,'') IS NOT NULL
					BEGIN
						-- ADD JOB STEP 2
						RAISERROR ('  - Adding Job Step 2',-1,-1) WITH NOWAIT
						SET	@Params = N'@jobid BINARY(16)'
						SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''2 - '+@Step2Title+''', 
								@step_id=2, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N''TSQL'', 
								@command=N'''+@Step2Command+''', 
								@database_name=N''master'', 
								@output_file_name=N''' +  @SQLAgentLogPath + 'XXX_DBA_DYNAMIC_' + @JobTitle +''',
								@flags=6'
						EXEC sp_executesql @Command,@Params,@jobid
					
						IF NULLIF(@Step3Command,'') IS NOT NULL
						BEGIN
							-- ADD JOB STEP 3
							RAISERROR ('  - Adding Job Step 3',-1,-1) WITH NOWAIT
							SET	@Params = N'@jobid BINARY(16)'
							SET	@Command = 'EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''3 - '+@Step3Title+''', 
									@step_id=3, 
									@cmdexec_success_code=0, 
									@on_success_action=1, 
									@on_success_step_id=0, 
									@on_fail_action=2, 
									@on_fail_step_id=0, 
									@retry_attempts=0, 
									@retry_interval=0, 
									@os_run_priority=0, @subsystem=N''TSQL'', 
									@command=N'''+@Step3Command+''', 
									@database_name=N''master'', 
									@output_file_name=N''' +  @SQLAgentLogPath + 'XXX_DBA_DYNAMIC_' + @JobTitle +''',
									@flags=6'
							EXEC sp_executesql @Command,@Params,@jobid
						END
						ELSE
							EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=2 , @on_success_action=1

					END
					ELSE
						EXEC msdb.dbo.sp_update_jobstep @job_id=@jobid, @step_id=1 , @on_success_action=1


					-- SET START STEP
					RAISERROR ('   - Setting Start Step for Job.',-1,-1) WITH NOWAIT
					SET	@Command = 'EXEC msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1'
					EXEC sp_executesql @Command,@Params,@jobid
				
					-- SET JOB SERVER
					RAISERROR ('   - Setting Job Server for Job.',-1,-1) WITH NOWAIT
					SET	@Command = 'EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)'''
					EXEC sp_executesql @Command,@Params,@jobid
				
					-- START JOB
					RAISERROR ('    - Starting Dynamic Job %s',-1,-1,@JobTitle) WITH NOWAIT
					SET	@Command = 'exec msdb.dbo.sp_start_job @job_id = @jobId'
					EXEC sp_executesql @Command,@Params,@jobid
END
/*

USE [DBAOps]
GO

DECLARE @RC					int
DECLARE @JobTitle			sysname						
DECLARE @JobDescription		nvarchar(max)				
DECLARE @Step1Title			sysname						
DECLARE @Step1Command		nvarchar(max)				
DECLARE @Step2Title			sysname						
DECLARE @Step2Command		nvarchar(max)				
DECLARE @Step3Title			sysname						
DECLARE @Step3Command		nvarchar(max)				
DECLARE @DeleteOnFinish		bit							
DECLARE @JobRunningUser		varchar(100)				
DECLARE @JobId				uniqueidentifier

SET		@JobTitle			= 'Test Job 1'
SET		@JobDescription		= 'this is a test'
SET		@Step1Title			= 'test step 1'
SET		@Step1Command		= 'select @@SERVERNAME'
SET		@Step2Title			= 'test step 2'
SET		@Step2Command		= 'select @@SERVERNAME'
SET		@Step3Title			= 'test step 3'
SET		@Step3Command		= 'select @@SERVERNAME'
SET		@DeleteOnFinish		= 1
SET		@JobRunningUser		= 'sa'


EXECUTE @RC = [dbo].[dbasp_ExecuteAsyncSQLJob] 
   @JobTitle
  ,@JobDescription
  ,@Step1Title
  ,@Step1Command
  ,@Step2Title
  ,@Step2Command
  ,@Step3Title
  ,@Step3Command
  ,@DeleteOnFinish
  ,@JobRunningUser
  ,@JobId OUTPUT

  SELECT @JobId

*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_ExecuteAsyncSQLJob] TO [public]
GO
