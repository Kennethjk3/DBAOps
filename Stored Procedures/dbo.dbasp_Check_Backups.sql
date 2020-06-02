SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Backups] (@backup_full_dd_period int = 7
					,@backup_diff_dd_period int = 1
					,@tranlog_hh_period int = 24)

/*********************************************************
 **  Stored Procedure dbasp_Check_Backups
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  June 12, 2001
 **
 **  This proc accepts the following input parms (position does matter):
 **  @backup_full_dd_period - Specify the oldest allowed age for the most recent
 **                      full database backup (in days - 7 day is the default)
 **
 **  @backup_diff_dd_period - Specify the oldest allowed age for the most recent
 **                      differential backup (in days - 1 day is the default)
 **
 **  @tranlog_hh_period - Specify the oldest allowed age for the most recent
 **                       transaction log backup (in hours - 24 hours is the default)
 **
 **  Note: This process will not check for transaction log
 **        backups for databases set for 'truncate log on checkpoint'
 **
 **  This procedure checks for current backups for each
 **  database on the server and raises a DBA warning to
 **  the error log if any are not found within the specified
 **  parameters.
 ***************************************************************/
  as
	SET NOCOUNT ON;
	-- Do not lock anything, and do not get held up by any locks.
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	-- Do Not let this process be the winner in a deadlock
	SET DEADLOCK_PRIORITY LOW;


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/30/2002	Steve Ledridge		Added brackets around dbname variable in select stmts.
--	07/23/2002	Steve Ledridge		Added code for bulkcopy flag, and to check for DB copy
--						within one day if trans log is not being backed up.
--	01/23/2003	Steve Ledridge		Fixed check for transaction log backup.  Must be type 'L'
--						in msdb..backupset.
--	04/14/2005	Steve Ledridge		Added code for bulkcopy flag.  Somehow it was not in there.
--	04/18/2005	Steve Ledridge		New code to delete database names from the backup_nocheck
--						table after 30 days.  Converted cursor11 to table variable.
--	12/16/2005	Steve Ledridge		Modified error message with 'or differential'.
--	05/30/2006	Steve Ledridge		Updated for SQL 2005.
--	03/21/2007	Steve Ledridge		Added process to update the backup_nocheck_db table.
--	04/25/2007	Steve Ledridge		Added skip process for non-production.
--	05/11/2007	Steve Ledridge		New seperate input parms for full and diff's.
--	02/11/2008	Steve Ledridge		Skip check for DB's not online.
--	02/13/2008	Steve Ledridge		Added second Skip check.
--	01/02/2009	Steve Ledridge		Converted to new no_check table.
--	05/01/2009	Steve Ledridge		Remove check for Database names in DEPL jobs
--						due to new request
--	05/18/2009	Steve Ledridge		Added @base_flag.
--	12/07/2010	Steve Ledridge		New code for backup type 'F'
--	06/07/2012	Steve Ledridge		Updated parse for DBname in RSTR job.
--	07/12/2012	Steve Ledridge		Added the Tran. Iso. Level Setting to prevent locking
--	07/12/2012	Steve Ledridge		Added the DEADLOCK_PRIORITY Setting to prevent Winning Deadlocks
--	01/08/2015	Steve Ledridge		New section to check backup to tape (Tivoli).
--	02/03/2015	Steve Ledridge		Modify Tivoli section related to locked file.
--	05/20/2015	Steve Ledridge		Column name change cluster to clustername.
--	======================================================================================


/**
Declare @backup_full_dd_period int
Declare @backup_diff_dd_period int
Declare @tranlog_hh_period int


Select @backup_full_dd_period = 7
Select @backup_diff_dd_period = 1
Select @tranlog_hh_period = 24
--**/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(255)
	,@cmd				nvarchar(4000)
	,@cmd2				nvarchar(4000)
	,@hold_backup_start_date	datetime
	,@saveDBName			sysname
	,@saveDBName_retry		sysname
	,@charpos			int
	,@charpos2			int
	,@base_flag			char(1)
	,@filetext			varchar(8000)
	,@save_LastWriteTime		sysname
	,@save_OffSiteBkUp_Status	sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@OutputComment			nvarchar(max)
	,@outfile_name			sysname
	,@outfile_path			nvarchar(250)
	,@hold_source_path		sysname
	,@central_server 		sysname


DECLARE
	 @cu10JobName			sysname


DECLARE
	 @cu11DBName			sysname


----------------  initial values  -------------------


Select @saveDBName	= ' '


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @outfile_name = 'CentralTivoliUpdate_' + @save_servername2 + '.gsql'
Select @outfile_path = '\\' + @save_servername + '\DBASQL\dba_reports\' + @outfile_name


Select @central_server = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'CentralServer'
If @central_server is null
   begin
	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The nightly self check-in failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end


--  Create table variable
declare @dbnames table	(name	sysname
			,dbid	smallint
			,status	int
			)


declare @jobnames table	(name	sysname)


/****************************************************************
 *                MainLine
 ***************************************************************/


--------------------  Clean up DBAOps.dbo.no_check table  -------------------
update dbo.no_check set modDate = getdate() where modDate is null


update dbo.no_check set modDate = getdate() where detail01 in (select name from master.sys.databases)


--  Skip this check for non-production servers
If (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname') <> 'production'
  and not exists (select md.database_name from msdb.dbo.sysdbmaintplans mp, msdb.dbo.sysdbmaintplan_databases md
		where mp.plan_id = md.plan_id
		  and mp.plan_name = 'Mplan_user_full')
   begin
	goto skip_all
   end
Else If exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_maint' and env_detail = 'skip')
   begin
	goto skip_all
   end


--  Check for regular restored DB's and add them to the backup no_check table
Insert into @jobnames (name)
SELECT j.name
From msdb.dbo.sysjobs j with (NOLOCK)
Where j.name not like ('x%')
  and j.name not like ('%Start Restore%')
  and j.name not like ('%End Restore%')
  and j.name not like ('%Restores Complete%')
  and j.name not like ('%DFNTL Restore%')
  and j.name like ('%restore%')
  and (j.name like ('base%') or j.name like ('rstr%'))


delete from @jobnames where name is null or name = ''
--select * from @jobnames


IF (select count(*) from @jobnames) > 0
   begin
	start_jobnames:


	Set @base_flag = 'n'


	Select @cu10JobName = (select top 1 name from @jobnames)

	Select @saveDBName = @cu10JobName


	--  get the DB names for BASE
	IF @saveDBName like ('BASE%')
	   begin
		Set @base_flag = 'y'


		Select @charpos = charindex('Restore', @saveDBName)


		IF @charpos <> 0
		   begin
			Select @saveDBName = substring(@saveDBName, @charpos+7, 200)
			Select @saveDBName = ltrim(rtrim(@saveDBName))
		   end


	    goto end_jobname_parse
	   end


	--  get the DB names in ()
	Select @charpos = charindex('(', @saveDBName)
	IF @charpos <> 0
	   begin
		Select @charpos2 = charindex(')', @saveDBName, @charpos+1)
		IF @charpos2 <> 0
		   begin
			Select @saveDBName = substring(@saveDBName, @charpos+1, (@charpos2-@charpos-1))
		   end
	    goto end_jobname_parse
	   end


	--  get the DB names for Rstr jobs
	IF @saveDBName like ('Rstr%')
	   begin
		Select @charpos = charindex(' ', @saveDBName)
		IF @charpos <> 0
		   begin
			Select @saveDBName = substring(@saveDBName, @charpos+1, len(@saveDBName)-@charpos+1)
			Select @saveDBName = ltrim(rtrim(@saveDBName))

	   		rstr_retry:
			Select @charpos2 = charindex(' ', @saveDBName)
			IF @charpos2 <> 0
			   begin
				--  Keep both sides of the results.  If we don't get a valid DBname, loop around to try again.
				Select @saveDBName_retry = substring(@saveDBName, @charpos2, len(@saveDBName)-@charpos2+1)
				Select @saveDBName_retry = ltrim(rtrim(@saveDBName_retry))
				Select @saveDBName = left(@saveDBName, @charpos2-1)
				Select @saveDBName = ltrim(rtrim(@saveDBName))
				If not exists (select 1 from master.sys.databases where name = @saveDBName)
				   begin
					select @saveDBName = ltrim(@saveDBName_retry)
					goto rstr_retry
				   end
			   end
			Else
			   begin
				goto end_jobname_parse
			   end
		   end
	    goto end_jobname_parse
	   end


	end_jobname_parse:



	--  Update the no_check table
	If exists (select 1 from DBAOps.dbo.no_check where detail01 = @saveDBName and NoCheck_type = 'backup')
	   begin
		update DBAOps.dbo.no_check set modDate = getdate() where detail01 = @saveDBName and NoCheck_type = 'backup'
	   end
	Else
	   begin
		INSERT INTO DBAOps.dbo.no_check (nocheck_type, detail01, createdate, moddate) VALUES ('backup', @saveDBName, getdate(), getdate())
	   end


	If @base_flag = 'y'
	   begin
		If exists (select 1 from DBAOps.dbo.no_check where detail01 = @saveDBName and NoCheck_type = 'baseline')
		   begin
			update DBAOps.dbo.no_check set modDate = getdate() where detail01 = @saveDBName and NoCheck_type = 'baseline'
		   end
		Else
		   begin
			INSERT INTO DBAOps.dbo.no_check (nocheck_type, detail01, createdate, moddate) VALUES ('baseline', @saveDBName, getdate(), getdate())
		   end
	   end


	--  Remove this record from @jobnames and go to the next
	delete from @jobnames where name = @cu10JobName
	If (select count(*) from @jobnames) > 0
	   begin
		goto start_jobnames
	   end
   end


Delete from DBAOps.dbo.no_check where nocheck_type = 'backup' and modDate < getdate()-30


Select @saveDBName = ' '


--------------------  Cursor for DB names  -------------------
Insert into @dbnames (name)
SELECT d.name
From master.sys.databases d with (NOLOCK)
Where d.name not in ('master', 'model', 'msdb', 'tempdb')
  and d.name not in (select detail01 from dbo.no_check where nocheck_type = 'backup')


delete from @dbnames where name is null or name = ''
--select * from @dbnames


If (select count(*) from @dbnames) > 0
   begin
	start_dbnames:


	Select @cu11DBName = (select top 1 name from @dbnames order by name)


	If (SELECT DATABASEPROPERTYEX (@cu11DBName,'status')) <> 'ONLINE'
	   begin
		goto label01
	   end
	Else
	--  Check to see if this database was specifically excluded from this check process.
	If exists(select 1 from DBAOps.dbo.no_check where detail01 = @cu11DBName and nocheck_type = 'backup')
	   begin
		goto label01
	   end
	Else
	--  Check the 'read only' option.  If it's 'on', set the 'done' flag for this database.
	If DATABASEPROPERTY(rtrim(@cu11DBName), 'IsReadOnly') = 1
	   begin
		goto label01
	   end


	--  Get the backup time for the last full database backup
	select @hold_backup_start_date  = (select top 1 backup_start_date from msdb.dbo.backupset
					    where database_name = @cu11DBName
					    and backup_finish_date is not null
					    and type in ('D', 'F')
					    order by backup_start_date desc)


	--  Check to see if the backup start date is null.  If so, this database may have never been backed up.
	-- Raise an error and move on to the next database.
	If @hold_backup_start_date is null
	   begin
		select @miscprint = 'DBA WARNING: No Full Backups exist for Database ''' + @cu11DBName + ''''
		raiserror(@miscprint,-1,-1) with log
		goto label01
	   end


	--  Check to see if the last full backup was within the requested database backup time period.
	--  If not, raise an error and move on to the next database.
	If @hold_backup_start_date < getdate()-@backup_full_dd_period
	   begin
		select @miscprint = 'DBA WARNING: No Full Backup exists for Database '''
							+ @cu11DBName + ''' within the past ' + convert(varchar(5), @backup_full_dd_period) + ' day(s)'
		raiserror(@miscprint,-1,-1) with log
		goto label01
	   end


	-- Check for the 'truncate log on check point' option.  If found, we're done checking this database.
	If databaseproperty(rtrim(@cu11DBName), 'IsTrunclog') = 1
	   begin
		goto label01
	   end


	-- Check for the 'bulk copy' option.  If found, we're done checking this database.
	If databaseproperty(rtrim(@cu11DBName), 'IsBulkCopy') = 1
	   begin
		goto label01
	   end


	--  If the last DB backup time was older than the @backup_diff_dd_period limit, check for differentials
	If @hold_backup_start_date < getdate()-@backup_diff_dd_period
	   begin
		select @hold_backup_start_date  = (select top 1 backup_start_date from msdb.dbo.backupset
						    where database_name = @cu11DBName
						    and backup_finish_date is not null
						    and type = 'I'
						    order by backup_start_date desc)


		--  Check to see if the last differential was within the requested database backup time period.
		--  If not, raise an error and move on to the next database.
		If @hold_backup_start_date < getdate()-@backup_full_dd_period
		   begin
			select @miscprint = 'DBA WARNING: No Differential Backup exists for Database '''
								+ @cu11DBName + ''' within the past ' + convert(varchar(5), @backup_diff_dd_period) + ' day(s)'
			raiserror(@miscprint,-1,-1) with log
			goto label01
		   end


	   end


	--  At this point we know the DB has a good backup file and is in recovery full mode, so it should have a valid tranlog backup
	select @hold_backup_start_date  = (select top 1 backup_start_date from msdb.dbo.backupset
					    where database_name = @cu11DBName
					    and backup_finish_date is not null
					    and type = 'L'
					    order by backup_start_date desc)


	--  Check to see if the backup start date is null.  If so, the tranlog may have never been backed up.
	--  Raise an error and move on to the next database.
	If @hold_backup_start_date is null
	   begin
		select @miscprint = 'DBA WARNING: No TranLog Backups exist for Database ''' + @cu11DBName + ''''
		raiserror(@miscprint,-1,-1) with log
		goto label01
	   end


	--  Check to see if the last TranLog backup was within the requested TranLog backup time period.
	--  If not, raise an error and move on to the next database.
	If @tranlog_hh_period < DATEDIFF(hour, @hold_backup_start_date, getdate())
	   begin
		select @miscprint = 'DBA WARNING: No Current Transaction Log Backup exists for Database ''' + @cu11DBName + ''''
		raiserror(@miscprint,-1,-1) with log
		goto label01
	   end


	label01:


	--  Remove this record from @dbname and go to the next
	delete from @dbnames where name = @cu11DBName
	If (select count(*) from @dbnames) > 0
	   begin
		goto start_dbnames
	   end


   end


--  Check the backup to tape process and report to the central server.
select @save_LastWriteTime = DBAOps.dbo.dbaudf_getfileproperty ('C:\Program Files\Tivoli\TSM\baclient\dsmsched.log', 'file', 'LastWriteTime')


If @save_LastWriteTime Like '%Not a valid File%'
   begin
	goto skip_tivoli_check
   end
Else
   begin
	exec DBAOps.dbo.dbasp_FileAccess_Read_Tail @FullFileName = 'C:\Program Files\Tivoli\TSM\baclient\dsmsched.log', @bytes = 8000, @filetext = @filetext output
	--print @filetext


	--  If the Tivoli log file is locked, skip this section
	If @filetext is null
	   begin
		Print 'DBANote:  Unable to check the Tivoli file at this time.'
		Select @save_OffSiteBkUp_Status = 'File Locked'
		goto skip_tivoli_check_file
	   end


	Select @filetext = reverse(@filetext)


	Select @charpos = charindex(':ssecca tsaL', @filetext)
	--Select @charpos = charindex('Last access:', @filetext)
	IF @charpos <> 0
	   begin
		select @save_LastWriteTime = substring(@filetext, @charpos-20, 19)
		Select @save_LastWriteTime = reverse(@save_LastWriteTime)
		--Print @save_LastWriteTime
	   end


	Select @filetext = reverse(@filetext)


	If @filetext Like '%Scheduled %' and @filetext Like '%completed successfully%'
	   begin
		Select @save_OffSiteBkUp_Status = 'Success'
	   end
	Else If @filetext Like '%Scheduled %' and @filetext Like '%failed.%'
	   begin
		Select @save_OffSiteBkUp_Status = 'Failed'
	   end
	Else
	   begin
		Select @save_OffSiteBkUp_Status = 'Unknown'
	   end


	skip_tivoli_check_file:

	-- Create script to insert this row on the central server dbo.DBA_ServerInfo related for this SQL server
	Select @OutputComment = ' ' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + '--  Start DBA_ServerInfo Updates' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'Print ''Start DBA_ServerInfo Updates''' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'if not exists (select 1 from dbo.DBA_ServerInfo where ServerName = ''' + upper(@save_servername) + ''' and SQLName = ''' + upper(@@servername) + ''')' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + '   begin' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + '      INSERT INTO dbo.DBA_ServerInfo (ServerName, SQLName, Active, Filescan, SQLmail, ClusterName, modDate) VALUES (''' + upper(@save_servername) + ''', ''' + upper(@@servername) + ''', ''Y'', ''Y'', ''Y'', '''', ''' + convert(nvarchar(30), getdate(), 121) + ''')' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + '   end' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'go' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + ' ' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'Update top (1) dbo.DBA_ServerInfo set OffSiteBkUp_Status = ''' + @save_OffSiteBkUp_Status + '''' +CHAR(13)+CHAR(10)


	If @save_LastWriteTime is null
	   begin
		Select @OutputComment = @OutputComment + '                                      ,OffSiteBkUp_Date = null' +CHAR(13)+CHAR(10)
	   end
	Else
	   begin
		Select @OutputComment = @OutputComment + '                                      ,OffSiteBkUp_Date = ''' + @save_LastWriteTime + '''' +CHAR(13)+CHAR(10)
	   end


	Select @OutputComment = @OutputComment + 'where ' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'ServerName = ''' + upper(@save_servername) + ''' and SQLName = ''' + upper(@@servername) + '''' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + 'go' +CHAR(13)+CHAR(10)


	Select @OutputComment = @OutputComment + ' ' +CHAR(13)+CHAR(10)


	--exec dbo.dbasp_PrintLarge @OutputComment


	exec dbo.dbasp_fileaccess_write @OutputComment, @outfile_path, 0, 1


	-- Update the local DBAOps database
	SET @cmd2 = 'sqlcmd -S'+@@servername+' -dDBAOps -E -w265 -l120 -i'+@outfile_path+'  -o\\' + @save_servername + '\DBASQL\dba_reports\DBA_Tivoli_localupdate.log'
	Print @cmd2
	EXEC master.sys.xp_cmdshell @cmd2, no_output


	If (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname') = 'local'
	   begin
		goto file_copy_end
	   end


	--  Copy the file to the central server
	Select @cmd = 'xcopy /Y /R "' + rtrim(@outfile_path) + '" "\\' + rtrim(@central_server) + '\DBA_SQL_Register"'
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	If @central_server = 'seapdbasql01'
	   begin
		goto file_copy_end
	 end


	If (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'domain') not in ('production', 'stage')
	   begin
		Select @cmd = 'xcopy /Y /R "' + rtrim(@outfile_path) + '" "\\seapdbasql01\DBA_SQL_Register"'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end
	Else
	   begin
		Select @hold_source_path = '\\' + upper(@save_servername) + '\' + upper(@save_servername2) + '_dbasql\dba_reports'
		exec DBAOps.dbo.dbasp_File_Transit @source_name = @outfile_name
			,@source_path = @hold_source_path
			,@target_env = 'AMER'
			,@target_server = 'seapdbasql01'
			,@target_share = 'DBA_SQL_Register'
	   end


	file_copy_end:


   end


skip_tivoli_check:


---------------------------  Finalization  -----------------------
label99:


skip_all:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Backups] TO [public]
GO
