SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_base_APPL_JobScripting]


/*********************************************************
 **  Stored Procedure dbasp_base_APPL_JobScripting
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 19, 2009
 **
 **  Process for baseline APPL job scripting.
 **  Note: This process will script out APPL jobs per
 **        application to the local Backup share.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	03/12/2010	Steve Ledridge		New process
--	03/15/2010	Steve Ledridge		Removed If stmt for initial insert into #saveAPPL
--	04/12/2010	Steve Ledridge		Skip if no local DEPL DBs exist
--	05/03/2010	Steve Ledridge		Added more no_check logic for APPLname.
--	05/20/2010	Steve Ledridge		Modified Check APPL Jobs for valid description.
--	05/24/2010	Steve Ledridge		Added more no_check logic.
--	08/31/2010	Steve Ledridge		Check for JobLogPathOveride keyword in description
--						to allow log to be written to any location.
--	03/04/2011	Steve Ledridge		New code for AHP processes.
--	04/29/2013	Steve Ledridge		Changed DEPLinfo to DBAOps.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	06/30/2014	Steve Ledridge		Added check for no deployable DB's.
--	03/05/2015	Steve Ledridge		Added pre=delete for output file.
--	05/04/2015	Steve Ledridge		Removed check for step pointed to master.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd				nvarchar(2000)
	,@charpos			int
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_APPLname			sysname
	,@save_jobname			sysname
	,@save_joblog_share		sysname
	,@joblog_outpath		sysname
	,@savesubject			sysname
	,@appl_name			sysname
	,@sqlcmd			nvarchar(2000)
	,@outpath 			nvarchar(500)
	,@save_baseline_servername	sysname
	,@save_dbname			sysname
	,@save_job_example		sysname


DECLARE
	 @sourcePath			nvarchar(256)
	,@targetEnv			nvarchar(16)
	,@targetServer			sysname
	,@targetShare			sysname
	,@file_name			sysname


----------------  initial values  -------------------


Select @save_servername	= @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Create table #saveAPPL (APPLname sysname)
CREATE TABLE #jobinfo (jobname sysname
			,jobdescription nvarchar(512))

CREATE TABLE #dbnames (dbname sysname)


Print '-- Script APPL jobs'
Print ' '
Print ' '


--  If not production, skip this process
If (select env_detail from dbo.Local_ServerEnviro where env_type = 'ENVname') <> 'production'
   begin
	Print 'Note:  This process is intended only for production instances.  Skipping this process.'
	Print ' '
	Print ' '
	goto label99
   end


--  If no local DEPL related databases exist, skip this process
If (select count(*) from DBAOps.dbo.db_sequence s, master.sys.databases d where s.db_name = d.name) = 0
   begin
	Print 'Note:  No local SQL Deployment related databases on the SQL instance.  Skipping this process.'
	Print ' '
	Print ' '
	goto label99
   end


--  If no local deployable databases exist, skip this process
If (select count(*) from DBAOps.dbo.dba_dbinfo where DEPLstatus = 'y') = 0
   begin
	Print 'Note:  No local deployable databases on the SQL instance.  Skipping this process.'
	Print ' '
	Print ' '
	goto label99
   end


--  If no_check is set for Post_Jobscript, skip this process
If exists(select 1 from DBAOps.dbo.no_check where nocheck_type = 'Post_Jobscript' and detail01 in ('DBAOps'))
   begin
	Print 'Note:  This process is being skipped due to no_check.  Skipping this process.'
	Print ' '
	Print ' '
	goto label99
   end


-- Check to see if there are any APPL jobs on this server
If not exists(select 1 from msdb.dbo.sysjobs where name like 'APPL%')
   begin
	Print 'Note:  No APPL jobs to script out for this SQL instance.'
	Print ' '
	Print ' '
	goto label99
   end


-- Check to see if the DBAOps database exists
If not exists(select 1 from master.sys.databases where name = 'DBAOps')
   begin
	Print 'Note:  This process requires the DBAOps database which is not present on this server.   Skipping this process.'
	Print ' '
	Print ' '
	goto label99
   end


--  Check APPL Jobs for valid description (only for the enable process)


--  First, determine which applications are represented on this SQL instance by looking at the local DB's
delete from #dbnames
insert into #dbnames select b.db_name from master.sys.databases d, dbo.db_sequence b where b.db_name = d.name
delete from #dbnames where dbname is null
delete from #dbnames where dbname in (select detail01 from dbo.no_check where NoCheck_type in ('DEPL_RD_Skip', 'DEPL_ahp_Skip'))


--  Now get the list of APPL jobs associated with the local SQL deployment related DB's
If (select count(*) from #dbnames) > 0
   begin
	delete from #jobinfo


	start_jobinfo_load:
	Select @save_dbname = (select top 1 dbname from #dbnames order by dbname)


	insert into #jobinfo select distinct j.name, j.description
				from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps s
				where j.name like 'APPL%'
				and j.job_id = s.job_id
				and (s.database_name in (select b.db_name
							from master.sys.databases d, dbo.db_sequence b
							where b.db_name = d.name)
				or s.command like ('%' + @save_dbname + '%'))
	--select * from #jobinfo


	--  check for more rows to process
	Delete from #dbnames where dbname = @save_dbname
	If (select count(*) from #dbnames) > 0
	   begin
		goto start_jobinfo_load
	   end


	select @appl_name = ''

	--start_appl_job_check:
	--If exists(select 1 from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name)
	--   begin
	--	Select @appl_name = (select top 1 RSTRfolder from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name order by RSTRfolder)
	--	--Print @appl_name
	--	delete from #jobinfo where jobdescription like rtrim(@appl_name) + '%'

	--	If exists(select 1 from DBAOps.dbo.db_BaseLocation where RSTRfolder > @appl_name)
	--	   begin
	--		goto start_appl_job_check
	--	   end
	--   end


	If (select count(*) from #jobinfo) > 0
	   begin
		Select @save_job_example = (select top 1 jobname from #jobinfo order by jobname)
		Select @miscprint = 'DBA WARNING: APPL job(s) found with invalid application name in the job description. (e.g. ' + @save_job_example + ')'
		Print @miscprint


		Select @savesubject = 'DBA WARNING: Baseline Job Scripting Error on server ' + @@servername


		Exec DBAOps.dbo.dbasp_sendmail
		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@subject = @savesubject,
		@message = @miscprint


		goto label99
	   end


   end


--  Get the job log output path
Select @save_joblog_share = @save_servername2 + '_SQLjob_logs'
--exec dbo.dbasp_get_share_path @save_joblog_share, @joblog_outpath output
SET @joblog_outpath = DBAOps.dbo.dbaudf_GetSharePath2(@save_joblog_share)


If @joblog_outpath is null or @joblog_outpath = ''
   begin
	Select @miscprint = 'DBA WARNING: Job Log output share path was not found.'
	Print @miscprint


	Select @savesubject = 'DBA WARNING: Baseline Job Scripting Error on server ' + @@servername


	Exec DBAOps.dbo.dbasp_sendmail
	@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
	@subject = @savesubject,
	@message = @miscprint


	goto label99
   end


--  Determin the deployment related applications on this sql instance
delete from #saveAPPL
insert into #saveAPPL select distinct baselineFolder from dbo.dba_dbinfo where DEPLstatus = 'y' and baselineFolder <> '' and baselineFolder is not null


--  Delete from #saveAPPL based on the no_check table
If exists(select 1 from DBAOps.dbo.no_check where nocheck_type = 'Post_Jobscript')
   begin
	delete from #saveAPPL where APPLname in (select detail01 from dbo.no_check where nocheck_type = 'Post_Jobscript')


	If (select count(*) from #saveAPPL) = 0
	   begin
		Select @miscprint = 'DBA NOTE: Skipping this process do to nocheck entries.'
		Print @miscprint
		goto label99
	   end
   end


Select @outpath = '\\' + @save_servername + '\' + @save_servername2 + '_backup'


/****************************************************************
 *                MainLine
 ***************************************************************/


--select * from #saveAPPL


If (select count(*) from #saveAPPL) > 0
   begin
	start01:
	Select @save_APPLname = (select top 1 APPLname from #saveAPPL order by APPLname)
	--print @save_APPLname


	--  Check to make sure Job steps point to master and job log output has been set
--	If exists (select 1 from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
--			where j.name like 'APPL%'
--			and j.description like @save_APPLname + '%'
--			and j.job_id = js.job_id
--			and js.subsystem = 'TSQL'
--			and js.database_name <> 'master'
--			)
--	   begin
--		Select @save_jobname = (select top 1 j.name from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
--					where j.name like 'APPL%'
--					and j.description like @save_APPLname + '%'
--					and j.job_id = js.job_id
--					and js.subsystem = 'TSQL'
--					and js.database_name <> 'master'
--					order by j.name)

--		Select @miscprint = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs, due to job ' + @save_jobname + '.  TSQL job step does not point to master.'
--		Print @miscprint


--		Select @savesubject = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs on server ' + @@servername


--		Exec DBAOps.dbo.dbasp_sendmail
--		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
--		@subject = @savesubject,
--		@message = @miscprint


--		goto skip_jobscript
--	   end


	--  Check to make sure Job Log Output is set for all steps
	If exists (select 1 from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
			where j.name like 'APPL%'
			and j.description like @save_APPLname + '%'
			and j.job_id = js.job_id
			and	(
				js.output_file_name is null					-- PATH IS EMPTY
				or	(
					js.output_file_name not like @joblog_outpath + '%'	-- PATH EXISTS BUT ISNT IN LOG SHARE
					AND j.description not like '%JobLogPathOveride%'	-- UNLESS OVERIDE IS USED
					)
				)
			)
	   begin
   		Select @save_jobname = (select top 1 j.name from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
					where j.name like 'APPL%'
					and j.description like @save_APPLname + '%'
					and j.job_id = js.job_id
					and	(
						js.output_file_name is null					-- PATH IS EMPTY
						or	(
							js.output_file_name not like @joblog_outpath + '%'	-- PATH EXISTS BUT ISNT IN LOG SHARE
							AND j.description not like '%JobLogPathOveride%'	-- UNLESS OVERIDE IS USED
							)
						)
					order by j.name)


		Select @miscprint = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs, due to job ' + @save_jobname + '.  Job log output files are not set properly.'
		Print @miscprint


		Select @savesubject = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs on server ' + @@servername


		Exec DBAOps.dbo.dbasp_sendmail
		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@subject = @savesubject,
		@message = @miscprint


		goto skip_jobscript


	   end


	--  Check to make sure Job Log Output is set for all steps
	If exists (select 1 from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
			where j.name like 'APPL%'
			and j.description like @save_APPLname + '%'
			and j.job_id = js.job_id
			and js.command like '%@recipients%'
			and (js.command not like '%@stage_recipients%' or js.command not like '%@test_recipients%')
			)
	   begin
      		Select @save_jobname = (select top 1 j.name from msdb.dbo.sysjobs j, msdb.dbo.sysjobsteps js
					where j.name like 'APPL%'
					and j.description like @save_APPLname + '%'
					and j.job_id = js.job_id
					and js.command like '%@recipients%'
					and (js.command not like '%@stage_recipients%' or js.command not like '%@test_recipients%')
					order by j.name)


		Select @miscprint = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs, due to job ' + @save_jobname + '.  DBAsp_Sendmail stage or test recipients not in place.'
		Print @miscprint


		Select @savesubject = 'DBA WARNING: Skipping baseline job script process for "' + @save_APPLname + '" jobs on server ' + @@servername


		Exec DBAOps.dbo.dbasp_sendmail
		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@subject = @savesubject,
		@message = @miscprint


		goto skip_jobscript


	   end


	--   Pre-delete the output file
	Select @cmd = 'Del ' + @outpath + '\' + upper(@save_APPLname) + '_jobs.sql'
	EXEC master.sys.xp_cmdshell @cmd


	--  Script out the APPL jobs for this APPLname
	Print 'Scripting out SQL jobs for APPLname ' + @save_APPLname + ' to ' + @outpath + '.'
	SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w2000 -u -Q"exec DBAOps.dbo.dbasp_SYSaddjobs @jobname = ''APPL'', @appl_name = ''' + @save_APPLname + '''" -E -o' + @outpath + '\' + upper(@save_APPLname) + '_jobs.sql'
	PRINT   @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd


	skip_jobscript:


	--  Check for more APPLnames to process
	delete from #saveAPPL where APPLname = @save_APPLname


	If (select count(*) from #saveAPPL) > 0
	   begin
		goto start01
	   end
   end
Else
   begin
	Select @miscprint = 'DBA NOTE: No deployment related databases for this SQL instance.  Skipping this process.'
	Print @miscprint
   end


/**********************   End Proc  **************************/


label99:


drop table #saveAPPL
drop TABLE #jobinfo
drop TABLE #dbnames
GO
GRANT EXECUTE ON  [dbo].[dbasp_base_APPL_JobScripting] TO [public]
GO
