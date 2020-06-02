SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_detach_move] (@dbname sysname = null
					, @target_path nvarchar(200) = null
					, @backup_filename sysname = null
					, @backup_to_target char(1) = 'y'
					, @copy_mdf char(1) = 'y'
					, @copy_ldf char(1) = 'n'
					, @delete_source_files char(1) = 'n'
					, @delete_source_backup char(1) = 'n'
					, @source_backup_path nvarchar(200) = null
					, @RG_flag char(1) = 'y'
					, @RG_only_flag char(1) = 'n'
					, @Force_StartFromTop nchar(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_Backup_detach_move
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  November 20, 2002
 **
 **  This procedure is used to backup and detach a database,
 **  and then copy the backup file along with the database
 **  mdf, ndf and (optionaly) the ldf files to a designated
 **  location.
 **
 **  This proc accepts several input parms (outlined below):
 **
 **  - @dbname is the name of the database being processed.
 **
 **  - @target_path is the full path (unc) where the backup
 **    file and the DB files will be copied.
 **
 **  - @backup_filename is the name of the backup file that
 **    will be created.
 **
 **  - @backup_to_target is a flag to force the backup process
 **    to point directly to the target path provided in @target_path.
 **
 **  - @copy_mdf is a flag for copying the DB mdf and ndf files
 **    to the target path.
 **
 **  - @copy_ldf is a flag for copying the DB ldf file to the
 **    target path.
 **
 **  - @delete_source_files is a flag for deleting the source
 **    DB mdf, ndf and ldf files, along with the local copy
 **    of the backup file.
 **
 **  - @delete_source_backup is a flag for deleting the source
 **    production backup file from the local restore folder.
 **
 **  - @source_backup_path is the full path (unc) to the restore
 **    folder where the source production backup file was copied.
 **
 **  - @RG_flag is a flag for RedGate backup processing (y or n).
 **
 **  - @Force_StartFromTop (y or n) is a flag to allow for a restart
 **    (from where it left off last time) or force restart from the top.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/20/2002	Steve Ledridge		New backup detach and move process
--	11/25/2002	Steve Ledridge		Added code to kill spids
--	12/02/2002	Steve Ledridge		Added waitfor commands after the delete stmtscode to kill spids
--	03/31/2003	Steve Ledridge		Added input parm and code to backup directly to the target path
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	11/26/2003	Steve Ledridge		Reset ownership chaining option after reattach.
--	07/22/2005	Steve Ledridge		Added insert to the @dbname build table.
--	06/22/2006	Steve Ledridge		Updated for SQL 2005.
--	06/22/2006	Steve Ledridge		New process to delete source production backup file.
--	06/08/2007	Steve Ledridge		Moved delete of old nxt file before rename of new mdf or ldf.
--	07/25/2007	Steve Ledridge		Added RedGate processing.
--	07/31/2007	Steve Ledridge		Added pre-delete for *.SQB files.
--	10/22/2007	Steve Ledridge		Added RedGate-only flag.
--	11/12/2007	Steve Ledridge		Added verify for RedGate backup file existence.
--	12/07/2007	Steve Ledridge		Fix delete of ldf file after initial detach.
--	01/18/2008	Steve Ledridge		Added /mov to robocopy.
--	01/25/2008	Steve Ledridge		Added alternate MOVE if source and target are on the same drive.
--	01/28/2008	Steve Ledridge		Added 2nd LDF delete just before the attach.
--	01/29/2008	Steve Ledridge		Added code for restarting (lots of code for this).
--	02/21/2008	Steve Ledridge		Changed single use mode to offline\online.
--	10/01/2008	Steve Ledridge		Added /Z /R:3 for robocopy
--	04/20/2011	Steve Ledridge		New code for cBAK backups.
--	04/27/2012	Steve Ledridge		Look up backup path from local_serverenviro.
--	======================================================================================


/***
Declare
	 @dbname sysname
	,@target_path nvarchar(200)
	,@backup_filename sysname
	,@backup_to_target nchar(1)
	,@copy_mdf nchar(1)
	,@copy_ldf nchar(1)
	,@delete_source_files nchar(1)
	,@delete_source_backup nchar(1)
	,@source_backup_path nvarchar(200)
	,@RG_flag nchar(1)
	,@RG_only_flag nchar(1)
	,@Force_StartFromTop nchar(1)


Select @dbname = 'DataExtract'
Select @target_path = '\\DBAOpsER04\DBAOpsER04_base_gmsh'
Select @backup_filename = 'DataExtract_prod'
Select @backup_to_target ='y'
Select @copy_mdf = 'y'
Select @copy_ldf = 'n'
Select @delete_source_files = 'y'
Select @delete_source_backup = 'n'
Select @source_backup_path = ''
Select @RG_flag = 'y'
Select @RG_only_flag = 'n'
Select @Force_StartFromTop = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd			nvarchar(4000)
	,@Restore_cmd		nvarchar(4000)
	,@sqlcmd		nvarchar(4000)
	,@detach_cmd		nvarchar(4000)
	,@attach01_cmd		nvarchar(4000)
	,@dos_command		nvarchar(4000)
	,@parm01		nvarchar(100)
	,@outpath 		nvarchar(255)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@hold_sharename	sysname
	,@central_server	nvarchar(100)
	,@error_count		int
	,@mdf_path 		nvarchar(255)
	,@ldf_path 		nvarchar(255)
	,@filename_wild		nvarchar(100)
	,@command 		nvarchar(512)
	,@filecount		smallint
	,@charpos		int
	,@savepos		int
	,@query 		nvarchar(255)
	,@savePhysicalNamePart	nvarchar(260)
	,@save_file_path	nvarchar(260)
	,@full_backup_path 	nvarchar(100)
	,@save_file_name	nvarchar(260)
	,@save_mdfnxt_name	nvarchar(260)
	,@save_newldf_fullpath	nvarchar(260)
	,@save_oldldf_fullpath	nvarchar(260)
	,@save_newldf_path	nvarchar(260)
	,@save_oldldf_path	nvarchar(260)
	,@save_newldf_name	nvarchar(260)
	,@save_oldldf_name	nvarchar(260)
	,@save_env_type		sysname
	,@save_env_detail	sysname
	,@attach_process_flag	nchar(1)
	,@fileseed		smallint


DECLARE
	 @save_option_cmd	nvarchar(255)
	,@TrueFalse		nvarchar(5)
	,@cursor33		nvarchar(2000)


DECLARE
	 @iSPID			int
	,@DBID			int
	,@Error			int
	,@vchCommand		nvarchar(255)


DECLARE
	 @cu12fileid		smallint
	,@cu12groupid		smallint
	,@cu12name		nvarchar(128)
	,@cu12filename		nvarchar(260)


DECLARE
	 @cu13fileid		smallint
	,@cu13groupid		smallint
	,@cu13name		nvarchar(128)
	,@cu13filename		nvarchar(260)


DECLARE
	 @cu15fileid		smallint
	,@cu15groupid		smallint
	,@cu15name		nvarchar(128)
	,@cu15filename		nvarchar(260)


----------------  initial values  -------------------
Select @error_count = 0


If not exists (select 1 from master.sys.objects where name = 'sqlbackup' and type = 'x')
   begin
    Select @RG_flag = 'n'
   end


Select @save_servername	= @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Set target path to drive letter path (if it's a local share)
If @target_path like '\\' + @save_servername + '%'
   begin
	Select @hold_sharename = substring(@target_path, len(@save_servername)+4, len(@target_path)-(len(@save_servername)+3))
	If @hold_sharename not like '%\%'
	   begin
		--exec DBAOps.dbo.dbasp_get_share_path @hold_sharename, @target_path output
		SET @target_path = DBAOps.dbo.dbaudf_GetSharePath2(@hold_sharename)
	   end
   end


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #temp_ldf_fullpath (filename nchar(260))


--  Verify input parm
if @dbname is null or @target_path is null or @backup_filename is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm(s)'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


--  Determine restart option
If @Force_StartFromTop = 'y' or not exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_bdm_' + rtrim(@dbname) + '_status')
   begin
	Print ''
	Print '**************************************************************'
	Print 'Start the Backup Detach and Move process from the TOP.'
	Print '**************************************************************'
	delete from DBAOps.dbo.Local_ServerEnviro where env_type like 'check_bdm_' + rtrim(@dbname) + '%'
	Select @save_env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
	insert into DBAOps.dbo.Local_ServerEnviro values(@save_env_type, 'start')
   end
Else
   begin
	Select @save_env_detail = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_bdm_' + rtrim(@dbname) + '_status')
	If @save_env_detail is null
	  or @save_env_detail not in ('first_detach_before', 'first_detach_after', 'attach_before', 'attach_after', 'backup_before', 'backup_after', 'second_detach_before', 'rename_move_before')
	   begin
		Print ''
		Print '**************************************************************'
		Print 'Start the Backup Detach and Move process from the TOP.'
		Print '**************************************************************'
		delete from DBAOps.dbo.Local_ServerEnviro where env_type like 'check_bdm_' + rtrim(@dbname) + '%'
		Select @save_env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
		insert into DBAOps.dbo.Local_ServerEnviro values(@save_env_type, 'start')
	   end
	Else If @save_env_detail = 'first_detach_before'
	   begin
		If exists (select 1 from master.sys.databases where name = @dbname) and (SELECT DATABASEPROPERTYEX (@dbname,'status')) = 'ONLINE'
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''First_Detach_Before'''
			Print '**************************************************************'
			goto First_Detach_Before
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''First_Detach_Before''.  Database does not exists or is not online.'
			Print  @miscprint
			Print 'Note:  Fix this issue or use the input parm @Force_StartFromTop = ''y''.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'first_detach_after'
	   begin
		If not exists (select 1 from master.sys.databases where name = @dbname)
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''First_Detach_After'''
			Print '**************************************************************'
			goto First_Detach_After
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''First_Detach_After''.  The Database still exists.'
			Print  @miscprint
			Print 'Note:  Suggest using input parm @Force_StartFromTop = ''y''.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'attach_before'
	   begin
		If not exists (select 1 from master.sys.databases where name = @dbname)
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Attach_Before'''
			Print '**************************************************************'
			goto Attach_Before
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''attach_Before''.  The Database still exists.'
			Print  @miscprint
			Print 'Note:  Suggest using input parm @Force_StartFromTop = ''y''.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'attach_after'
	   begin
		If exists (select 1 from master.sys.databases where name = @dbname) and (SELECT DATABASEPROPERTYEX (@dbname,'status')) = 'ONLINE'
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Attach_After'''
			Print '**************************************************************'
			goto Attach_After
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''Attach_After''.  Database does not exists or is not online.'
			Print  @miscprint
			Print 'Note:  You may need to attach this DB manually.  If that is not possible, the DB restore will need to be re-run.'
			Print '       A re-run of this process is not possible until the DB exists and is online.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'backup_before'
	   begin
		If exists (select 1 from master.sys.databases where name = @dbname) and (SELECT DATABASEPROPERTYEX (@dbname,'status')) = 'ONLINE'
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Backup_Before'''
			Print '**************************************************************'
			goto Backup_Before
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''Backup_Before''.  Database does not exists or is not online.'
			Print  @miscprint
			Print 'Note:  The DB attach may have failed.'
			Print '       You may need to attach this DB manually.  If that is not possible, the DB restore will need to be re-run.'
			Print '       A re-run of this process is not possible until the DB exists and is online.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'backup_after'
	   begin
		If exists (select 1 from master.sys.databases where name = @dbname) and (SELECT DATABASEPROPERTYEX (@dbname,'status')) = 'ONLINE'
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Backup_After'''
			Print '**************************************************************'
			goto Backup_After
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''Backup_After''.  Database does not exists or is not online.'
			Print  @miscprint
			Print 'Note:  It should not be possible to get to this point in the code (but just in case).'
			Print '       If you are here, you need to check to see if the backups completed properly.  If not, you will need'
			Print '       to either restore the DB or attach the DB.  Then you should modify the status record in the table'
			Print '       DBAOps.dbo.Local_ServerEnviro to ''backup_before''.'
			Print '       A re-run of this process is not possible until the DB exists and is online.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'second_detach_before'
	   begin
		If exists (select 1 from master.sys.databases where name = @dbname) and (SELECT DATABASEPROPERTYEX (@dbname,'status')) = 'ONLINE'
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Second_Detach_Before'''
			Print '**************************************************************'
			goto Second_Detach_Before
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''Second_Detach_Before''.  Database does not exists or is not online.'
			Print  @miscprint
			Print 'Note:  Possible problem with the Backup process,or even the attach process prior to the backups.'
			Print '       Check the backups and determine why the database is gone.'
			Print '       A re-run of this process is not possible until the DB exists and is online.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
	Else If @save_env_detail = 'rename_move_before'
	   begin
		If not exists (select 1 from master.sys.databases where name = @dbname)
		   begin
			Print ''
			Print '**************************************************************'
			Print 'Start the Backup Detach and Move process at ''Rename_Move_Before'''
			Print '**************************************************************'
			goto Rename_Move_Before
		   end
		Else
		   begin
			Print ''
			Print '**************************************************************'
			Select @miscprint = 'Unable to restart at ''Rename_Move_Before''.  The Database still exists.'
			Print  @miscprint
			Print 'Note:  Determine why the second detach failed.  You should be able to detach the DB'
			Print '       and then re-run this step.'
			Print '**************************************************************'
			raiserror(@miscprint,-1,-1) with log
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
   end


--  Verify database
If not exists (select 1 from master.sys.databases where name = @dbname)
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @dbname.  No such database exists.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END
Else If (SELECT DATABASEPROPERTYEX (@dbname,'status')) <> 'ONLINE'
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @dbname.  Database exists but is not online.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


if (select name from master.sys.sysdatabases where name = @dbname) in ('master', 'model', 'msdb', 'tempdb')
   BEGIN
	Select @miscprint = 'DBA WARNING: This process is not allowed for a system database'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


--  Verify backup_to_target flag
if @backup_to_target not in ('n','y')
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @backup_to_target.  Must be ''y'' or ''n''.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


--  Verify RG flags
if @RG_flag = 'n' and @RG_only_flag = 'y'
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @RG_flag.  Must be ''y'' if input parm @RG_only_flag = ''y''.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


select @cmd = 'If (object_id(''DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'') is not null)
   begin
	drop table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles
   end'
exec (@cmd)
Select @cmd = 'Create table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles (
		fileid smallint,
		groupid smallint,
		size int,
		maxsize int,
		growth int,
		status int,
		perf int,
		name nchar(128),
		filename nchar(260))'
exec (@cmd)


--  Inset a row into the @dbname build table
Select @cmd = 'If exists (select 1 from ' + @dbname + '.sys.objects where name = ''build'' and type = ''u'')
   begin
	INSERT INTO ' + @dbname + '.dbo.Build (vchName, vchLabel, dtBuildDate, vchNotes) VALUES (''' + @dbname + ''', ''Backup, Detach & Move'', GETDATE(), ''' + @dbname + ' Backup, Detach & Move'')
   end'
Print @cmd
exec (@cmd)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Prepare attach and detach commands
Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
exec (@cmd)
Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  select * from [' + @dbname + '].sys.sysfiles'
exec (@cmd)
--Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
--exec (@cmd)


--  Format the detach command
Print ''
Print '**************************************************************'
Print 'Create the detach gsql file for database ' + rtrim(@dbname)
Print '**************************************************************'


SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''master.sys.sp_detach_db ''''' + rtrim(@dbname) + ''''', @skipchecks = ''''true''''''" -E -o\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_detach.gsql'
PRINT  @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


--  Format the attach command
Print ''
Print '**************************************************************'
Print 'Create the attach gsql file for database ' + rtrim(@dbname)
Print '**************************************************************'


SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''CREATE DATABASE [' + rtrim(@dbname) + '] ON''" -E >\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
PRINT  @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


Select @fileseed = 1


--------------------  Cursor for 12DB  -----------------------
select @cmd = 'DECLARE cu12_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  f ' +
  'Order By f.fileid For Read Only'


EXECUTE(@cmd)


OPEN cu12_file


WHILE (12=12)
   Begin
	FETCH Next From cu12_file Into @cu12fileid, @cu12groupid, @cu12name, @cu12filename
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_file
	      BREAK
           end


	If @fileseed = 1
	   begin
		If @cu12groupid <> 0
		   begin
			SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''  (FILENAME = ''''' + rtrim(@cu12filename) + ''''')''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
			PRINT @sqlcmd
			EXEC master.sys.xp_cmdshell @sqlcmd


			--  parse and save the file path
			Select @save_file_path = ''
			Select @savepos = 1
			label12a:
			Select @charpos = charindex('\', @cu12filename, @savepos)
			IF @charpos <> 0
			   begin
				Select @savepos = @charpos+1
				goto label12a
			   end


			Select @save_file_path = @save_file_path + substring(@cu12filename, 1, @savepos-2)

		   end
	   end
	Else
	   begin
		If @cu12groupid <> 0
		   begin
			SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''  ,(FILENAME = ''''' + rtrim(@cu12filename) + ''''')''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
			PRINT @sqlcmd
			EXEC master.sys.xp_cmdshell @sqlcmd

		   end
	   end


	Select @fileseed = @fileseed + 1


   End  -- loop 12
   DEALLOCATE cu12_file


If (select is_db_chaining_on from master.sys.databases where name = @dbname) = 1
  and (select is_trustworthy_on from master.sys.databases where name = @dbname) = 1
   begin
	SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print '' FOR ATTACH_REBUILD_LOG WITH TRUSTWORTHY ON, DB_CHAINING ON;''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
	PRINT @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @dbname) = 0
  and (select is_trustworthy_on from master.sys.databases where name = @dbname) = 0
   begin
	SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print '' FOR ATTACH_REBUILD_LOG WITH TRUSTWORTHY OFF, DB_CHAINING OFF;''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
	PRINT @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @dbname) = 1
  and (select is_trustworthy_on from master.sys.databases where name = @dbname) = 0
   begin
	SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print '' FOR ATTACH_REBUILD_LOG WITH TRUSTWORTHY OFF, DB_CHAINING ON;''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
	PRINT @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @dbname) = 0
  and (select is_trustworthy_on from master.sys.databases where name = @dbname) = 1
   begin
	SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print '' FOR ATTACH_REBUILD_LOG WITH TRUSTWORTHY ON, DB_CHAINING OFF;''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
	PRINT @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd
   end


--  Make sure all connections to this database are removed
--  Alter the database to offline mode
Select @vchCommand = 'alter database [' + rtrim(@dbname) + '] set OFFLINE with ROLLBACK IMMEDIATE '
print @vchCommand
Exec(@vchCommand)
print ' '


--  Pause for a couple seconds
waitfor delay '00:00:01'


--  Alter the database to online mode
Select @vchCommand = 'alter database [' + rtrim(@dbname) + '] set ONLINE with ROLLBACK IMMEDIATE '
print @vchCommand
Exec(@vchCommand)
print ' '


--  Pause for a couple seconds
waitfor delay '00:00:01'


Select @vchCommand = 'ALTER DATABASE [' + rtrim(@dbname) + '] SET MULTI_USER WITH ROLLBACK IMMEDIATE'
Print @vchCommand
exec (@vchCommand)


--  Set the dbid value
Select @DBID = dbid FROM master.sys.sysdatabases where name = @dbname


Select @iSPID = 6
WHILE @iSPID IS NOT NULL
   begin


	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID and spid > @iSPID
	IF @iSPID IS NOT NULL
	   begin
		Select @vchCommand = 'KILL ' + convert(varchar(12), @iSPID )
		Print @vchCommand
		exec(@vchCommand)
		Select @Error = @@ERROR
		IF @error <> 0
		   begin
			RAISERROR( 'Error Killing Spid', 16, -1 )
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
   end


Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID
If @iSPID is not null
   begin
	Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
	RAISERROR( @miscprint, 16, -1 )
	Select @error_count = @error_count + 1
	goto label99
   end


--  Detach the database
update DBAOps.dbo.Local_ServerEnviro set env_detail = 'first_detach_before' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
First_Detach_Before:


Print ''
Print '**************************************************************'
Print 'Detach the database ' + rtrim(@dbname)
Print '**************************************************************'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -u -E -i\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_detach.gsql'
PRINT   @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'first_detach_after' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
First_Detach_After:


--  Delete the LDF DB files
--------------------  Cursor for 13  -----------------------
select @cmd = 'DECLARE cu13_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  f ' +
  'Order By f.fileid For Read Only'
EXECUTE(@cmd)


OPEN cu13_file


WHILE (13=13)
   Begin
	FETCH Next From cu13_file Into @cu13fileid, @cu13groupid, @cu13name, @cu13filename
	IF (@@fetch_status < 0)
           begin
              CLOSE cu13_file
	      BREAK
           end

	--  Update the file permissions
	Print ''
	Print '**************************************************************'
	Print 'Update file permissions for: ' + rtrim(@cu13filename)
	Print '**************************************************************'


	Select @dos_command = 'XCACLS "' + rtrim(@cu13filename) + '" /G "Administrators":F /Y'
	Print @dos_command
	EXEC master.sys.xp_cmdshell @dos_command, no_output

	Select @dos_command = 'XCACLS "' + rtrim(@cu13filename) + '" /E /G "NT AUTHORITY\SYSTEM":R /Y'
	Print @dos_command
	EXEC master.sys.xp_cmdshell @dos_command, no_output


	--  Delete the LDF DB file
	If @cu13groupid = 0
	   begin
		Print ''
		Print '**************************************************************'
		Print 'Delete LDF file: ' + rtrim(@cu13filename)
		Print '**************************************************************'


		Select @save_file_name = rtrim(@cu13filename)
		Select @cmd = 'Del ' + rtrim(@save_file_name)
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output
	   end


   End  -- loop 13
   DEALLOCATE cu13_file


--  Delete ldf DB file that might be at the new location
Select @save_file_name = ''
Select @save_file_name = @save_file_path + '\' + rtrim(@dbname) + '*.ldf'
Select @cmd = 'Del ' + rtrim(@save_file_name)
Print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Attach the DB and force create a new LDF file


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'attach_before' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Attach_Before:


Print ''
Print '**************************************************************'
Print 'Attach the database creating a new LDF file'
Print '**************************************************************'
SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -u -E -i\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
PRINT @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


Waitfor delay '00:00:02'


If not exists (select 1 from master.sys.databases where name = @dbname)
   BEGIN
	Select @miscprint = 'DBA WARNING: Attach failed for database ' + @dbname + '.  No such database exists.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END
Else If (SELECT DATABASEPROPERTYEX (@dbname,'status')) <> 'ONLINE'
   BEGIN
	Select @miscprint = 'DBA WARNING: Attach failed for database ' + @dbname + '  Database exists but is not online.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


Print ''
Print '**************************************************************'
Print 'The database ' + rtrim(@dbname) + ' has now been shrunk (ldf recreated)'
Print '**************************************************************'


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'attach_after' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Attach_After:


--  Reset the sysfiles info in the temp table
Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
exec (@cmd)
Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  select * from [' + @dbname + '].sys.sysfiles'
exec (@cmd)
Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
exec (@cmd)


--  Backup the DB to either the target location, or locally


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'backup_before' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Backup_Before:


Print ''
Print '**************************************************************'
Print 'Starting the BACKUP section'
Print '**************************************************************'


If @backup_to_target = 'y'
   begin
	--  Backup the DB
	If @RG_only_flag <> 'y'
	   begin
		If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
		   begin
			Select @cmd = 'Backup database [' + @DBname + '] to disk = ''' + rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.cBAK'' with init, COMPRESSION'
			Print @cmd
			Exec(@cmd)
		   end
		Else
		   begin
			Select @cmd = 'Backup database [' + @DBname + '] to disk = ''' + rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.BAK'' with init'
			Print @cmd
			Exec(@cmd)
		   end


		Print ' '
		Print 'The database ' + rtrim(@dbname) + ' has now been backed up directly to the target location'
		Print ' '
	   end


	If @RG_flag = 'y'
	   begin
		--  Delete any old redgate backup files
		Select @parm01 = rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.SQB'
		Select @cmd = 'DEL ' + @parm01
		Print @cmd
		Exec master.sys.xp_cmdshell @cmd


		--  Verify the old backup file does not exist at the target
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Print 'Error:  The old SQB backup file could not be deleted prior to creation of the new SQB backup. ' + @parm01
			Select @error_count = @error_count + 1
			Goto label99
		   end


		--  Backup the DB via RedGate
		Select @cmd = 'exec master.dbo.sqlbackup ''-SQL "BACKUP DATABASE [' + rtrim(@dbname) + ']'
				+ ' TO DISK = ''''' + rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.SQB'
				+ ''''' WITH THREADCOUNT = 3, COMPRESSION = 1, MAXTRANSFERSIZE = 1048576, VERIFY"'''
		Print @cmd
		Exec(@cmd)


		--  Verify the new backup file now exists.
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) <> 1
		   begin
			Print 'Error:  The new SQB backup file was not created as expected. ' + @parm01
			Select @error_count = @error_count + 1
			Goto label99
		   end


		Print ' '
		Print 'The database ' + rtrim(@dbname) + ' has now been backed up via RedGate to the target location'
		Print ' '
	   end
   end
Else
   begin
	--  Get the path to the backup folder
	Select @parm01 = @save_servername2 + '_backup'
	If exists (select 1 from dbo.local_serverenviro where env_type = 'backup_path')
	   begin
		Select @outpath = (select top 1 env_detail from dbo.local_serverenviro where env_type = 'backup_path')
	   end
	Else
	   begin
		--exec DBAOps.dbo.dbasp_get_share_path @parm01, @outpath output
		SET @outpath = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)
	   end


	If @outpath is null
	   begin
		Print 'Warning:  The standard share to the ''backup'' folder has not been defined.'
		Select @error_count = @error_count + 1
		Goto label99
	   end


	--  Backup the DB
	If @RG_only_flag <> 'y'
	   begin
		If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
		   begin
			Select @cmd = 'Backup database [' + @DBname + '] to disk = ''' + @outpath + '\' + rtrim(@backup_filename) + '.cBAK'' with init, COMPRESSION'
			Print @cmd
			Exec(@cmd)
		   end
		Else
		   begin
			Select @cmd = 'Backup database [' + @DBname + '] to disk = ''' + @outpath + '\' + rtrim(@backup_filename) + '.BAK'' with init'
			Print @cmd
			Exec(@cmd)
		   end


		Print ' '
		Print 'The database ' + rtrim(@dbname) + ' has now been backed up'
		Print ' '
	   end


	If @RG_flag = 'y'
	   begin
		--  Delete any old redgate backup files
		Select @parm01 = rtrim(@outpath) + '\' + rtrim(@backup_filename) + '.SQB'
		Select @cmd = 'DEL ' + @parm01
		Print @cmd
		Exec master.sys.xp_cmdshell @cmd


		--  Verify the old backup file does not exist at the target
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Print 'Error:  The old SQB backup file could not be deleted prior to creation of the new SQB backup. ' + @parm01
			Select @error_count = @error_count + 1
			Goto label99
		   end


		--  Backup the DB via RedGate
		Select @cmd = 'exec master.dbo.sqlbackup ''-SQL "BACKUP DATABASE [' + rtrim(@dbname) + ']'
				+ ' TO DISK = ''''' + rtrim(@outpath) + '\' + rtrim(@backup_filename) + '.SQB'
				+ ''''' WITH THREADCOUNT = 3, COMPRESSION = 1, MAXTRANSFERSIZE = 1048576, VERIFY"'''
		Print @cmd
		Exec(@cmd)


		--  Verify the new backup file now exists.
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) <> 1
		   begin
			Print 'Error:  The new SQB backup file was not created as expected. ' + @parm01
			Select @error_count = @error_count + 1
			Goto label99
		   end


		Print ' '
		Print 'The database ' + rtrim(@dbname) + ' has now been backed up via RedGate to the target location'
		Print ' '
	   end
   end


--  If we still need to move the backup file to the target location, check to see if the backup file exists in the target location.
--  If so, delete the old backup file at the target location.
If @backup_to_target = 'n'
   begin
	If @RG_only_flag <> 'y'
	   begin
		If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
		   begin
			Select @parm01 = rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.cBAK'
		   end
		Else
		   begin
			Select @parm01 = rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.BAK'
		   end


		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Select @cmd = 'Del ' + rtrim(@parm01)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


		Waitfor delay '00:00:02'
	   end


	If @RG_flag = 'y'
	   begin
		Select @parm01 = rtrim(@target_path) + '\' + rtrim(@backup_filename) + '.SQB'
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Select @cmd = 'Del ' + rtrim(@parm01)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


		Waitfor delay '00:00:02'
	   end


	--  Copy the backup file to the central server target
	If @RG_only_flag <> 'y'
	   begin
		If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
		   begin
			Select @cmd = 'move ' + @outpath + '\' + rtrim(@backup_filename) + '.cBAK ' + rtrim(@target_path)
		   end
		Else
		   begin
			Select @cmd = 'move ' + @outpath + '\' + rtrim(@backup_filename) + '.BAK ' + rtrim(@target_path)
		   end


		print @cmd
		EXEC master.sys.xp_cmdshell @cmd


		Print ' '
		Print 'The backup file for database ' + rtrim(@dbname) + ' has now been moved to the target location.'
		Print ' '
	   end


	If @RG_flag = 'y'
	   begin
		--  Copy the RedGate backup file to the central server target
		Select @cmd = 'move ' + @outpath + '\' + rtrim(@backup_filename) + '.SQB ' + rtrim(@target_path)
		print @cmd
		EXEC master.sys.xp_cmdshell @cmd


		Print ' '
		Print 'The RedGate backup file for database ' + rtrim(@dbname) + ' has now been moved to the target location.'
		Print ' '
	   end
   end


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'backup_after' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Backup_After:


--  General wait between backup processing and final detach
Waitfor delay '00:00:02'


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'second_detach_before' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Second_Detach_Before:


Print ''
Print '**************************************************************'
Print 'Starting final Detach section'
Print '**************************************************************'


--  Make sure all connections to this database are removed
--  Alter the database to offline mode
Select @vchCommand = 'alter database [' + rtrim(@dbname) + '] set OFFLINE with ROLLBACK IMMEDIATE '
print @vchCommand
Exec(@vchCommand)
print ' '


--  Pause for a couple seconds
waitfor delay '00:00:01'


--  Alter the database to online mode
Select @vchCommand = 'alter database [' + rtrim(@dbname) + '] set ONLINE with ROLLBACK IMMEDIATE '
print @vchCommand
Exec(@vchCommand)
print ' '


--  Pause for a couple seconds
waitfor delay '00:00:01'


Select @vchCommand = 'ALTER DATABASE [' + rtrim(@dbname) + '] SET MULTI_USER WITH ROLLBACK IMMEDIATE'
Print @vchCommand
exec (@vchCommand)


--  Set the dbid value
Select @DBID = dbid FROM master.sys.sysdatabases where name = @dbname


Select @iSPID = 6
WHILE @iSPID IS NOT NULL
   begin
	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID and spid > @iSPID
	IF @iSPID IS NOT NULL
	   begin
		Select @vchCommand = 'KILL ' + convert(varchar(12), @iSPID )
		Print @vchCommand
		exec(@vchCommand)
		Select @Error = @@ERROR
		IF @error <> 0
		   begin
			RAISERROR( 'Error Killing Spid', 16, -1 )
			Select @error_count = @error_count + 1
			goto label99
		   end
	   end
   end


Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID
If @iSPID is not null
   begin
	Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
	RAISERROR( @miscprint, 16, -1 )
	Select @error_count = @error_count + 1
	goto label99
   end


--  Detach the database again
Print ''
Print '**************************************************************'
Print 'Detach the database ' + rtrim(@dbname)
Print '**************************************************************'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -u -E -i\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_detach.gsql'
PRINT   @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


Waitfor delay '00:00:02'


update DBAOps.dbo.Local_ServerEnviro set env_detail = 'rename_move_before' where env_type = 'check_bdm_' + rtrim(@dbname) + '_status'
Rename_Move_Before:


Print ''
Print '**************************************************************'
Print 'Starting the DB file rename (nxt) and move section'
Print '**************************************************************'


--  Copy all mdf and ndf files to the target location, and delete the local mdf, ndf and ldf files
--------------------  Cursor for 15DB  -----------------------
Select @cmd = 'DECLARE cu15_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  f ' +
  'Order By f.fileid For Read Only'
EXECUTE(@cmd)


OPEN cu15_file


WHILE (15=15)
   Begin
	FETCH Next From cu15_file Into @cu15fileid, @cu15groupid, @cu15name, @cu15filename
	IF (@@fetch_status < 0)
           begin
              CLOSE cu15_file
	      BREAK
           end


	--  parse and save the file name
	Select @save_file_name = rtrim(@cu15filename)
	Select @charpos = charindex('\', @save_file_name)
	label15a:
	IF @charpos <> 0
	   begin
		Select @save_file_name = substring(@save_file_name, @charpos + 1, 200)
	   end
	Select @charpos = charindex('\', @save_file_name)
	IF @charpos <> 0
	   begin
		goto label15a
	   end


	--  parse and save the file path
	Select @save_file_path = ''
	Select @savepos = 1
	label15c:
	Select @charpos = charindex('\', @cu15filename, @savepos)
	IF @charpos <> 0
	   begin
		Select @savepos = @charpos+1
		goto label15c
	   end


	Select @save_file_path = @save_file_path + substring(@cu15filename, 1, @savepos-2)


	--  Move the files to the target location if requested
	If @cu15groupid <> 0 and @copy_mdf = 'y'
	   begin
		--  For mdf and ndf files, delete existing file at the target location
		Select @parm01 = rtrim(@target_path) + '\' + rtrim(@save_file_name) + 'nxt'
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Select @cmd = 'Del ' + rtrim(@parm01)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


		Waitfor delay '00:00:02'


		--  Update the file permissions
		Select @dos_command = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /G "Administrators":F /Y'
		Print @dos_command
		EXEC master.sys.xp_cmdshell @dos_command, no_output

		Select @dos_command = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /E /G "NT AUTHORITY\SYSTEM":R /Y'
		Print @dos_command
		EXEC master.sys.xp_cmdshell @dos_command, no_output


		--  Rename the DB file, adding 'nxt' to the extention
		Select @cmd = 'REN ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + ' ' + rtrim(@save_file_name) + 'nxt'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output


		Select @save_file_name = rtrim(@save_file_name) + 'nxt'


		Waitfor delay '00:00:02'


		--  copy the file to the target location
		If @target_path not like '\\%' and left(@target_path, 3) = left(@save_file_path, 3)
		   begin
			Select @cmd = 'move ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + ' ' + rtrim(@target_path)
			print @cmd
			EXEC master.sys.xp_cmdshell @cmd
		   end
		Else
		   begin
			Select @cmd = 'robocopy ' + rtrim(@save_file_path) + ' ' + rtrim(@target_path) + ' ' + rtrim(@save_file_name) + ' /NP /MOV /Z /R:3'
			Print @cmd
	    		EXEC master.sys.xp_cmdshell @cmd
		   end
	   end
	Else If @cu15groupid = 0 and @copy_ldf = 'y'
	   begin
		--  For ldf files, delete existing file at the target location
		Select @parm01 = rtrim(@target_path) + '\' + rtrim(@save_file_name) + 'nxt'
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @parm01
		If (select doesexist from #fileexists) = 1
		   begin
			Select @cmd = 'Del ' + rtrim(@parm01)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


		Waitfor delay '00:00:02'


		--  Update the file permissions
		Select @dos_command = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /G "Administrators":F /Y'
		Print @dos_command
		EXEC master.sys.xp_cmdshell @dos_command, no_output

		Select @dos_command = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /E /G "NT AUTHORITY\SYSTEM":R /Y'
		Print @dos_command
		EXEC master.sys.xp_cmdshell @dos_command, no_output


		--  Rename the DB file, adding 'nxt' to the extention
		Select @cmd = 'REN ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + ' ' + rtrim(@save_file_name) + 'nxt'
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output


		Select @save_file_name = rtrim(@save_file_name) + 'nxt'


		Waitfor delay '00:00:02'


		--  copy the file to the target location
		If @target_path not like '\\%' and left(@target_path, 3) = left(@save_file_path, 3)
		   begin
			Select @cmd = 'move ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + ' ' + rtrim(@target_path)
			print @cmd
			EXEC master.sys.xp_cmdshell @cmd
		   end
		Else
		   begin
			Select @cmd = 'robocopy ' + rtrim(@save_file_path) + ' ' + rtrim(@target_path) + ' ' + rtrim(@save_file_name) + ' /NP /MOV /Z /R:3 '
			Print @cmd
	    		EXEC master.sys.xp_cmdshell @cmd
		   end
	   end


	--  Now delete the local copy of this file (in case it is still there)
	If @delete_source_files = 'y'
	   begin
		Select @cmd = 'Del ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name)
		Print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output
	   end


   End  -- loop 15
   DEALLOCATE cu15_file


--  Delete the source production backup file if requested
If @delete_source_backup = 'y' and @source_backup_path <> '' and @source_backup_path is not null
   begin
	Select @cmd = 'Del ' + rtrim(@source_backup_path) + '\' + rtrim(@dbname) + '_db_*.*'
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd--, no_output


	Print ' '
	Print 'The source production backup file has been deleted'
	Print ' '
   end


If @copy_mdf = 'y'
   begin
	Print ' '
	Print 'The database files (mdf and ndf) have been moved to the target location'
	Print ' '
   end


If @copy_ldf = 'y'
   begin
	Print ' '
	Print 'The database files (ldf) have been moved to the target location'
	Print ' '
   end


If @delete_source_files = 'y'
   begin
	Print ' '
	Print 'The local database files (mdf, ndf and ldf) have been deleted'
	Print ' '
   end


--  Finalization  -------------------------------------------------------------------


delete from DBAOps.dbo.Local_ServerEnviro where env_type like 'check_bdm_' + rtrim(@dbname) + '%'


select @cmd = 'If (object_id(''DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'') is not null)
   begin
	drop table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles
   end'
exec (@cmd)


label99:


If (object_id('tempdb.dbo.#temp_ldf_fullpath') is not null)
   begin
	drop table #temp_ldf_fullpath
   end
If (object_id('tempdb.dbo.#fileexists') is not null)
   begin
	drop table #fileexists
   end


If @error_count > 0
   begin
	raiserror('DBA Error',16,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_detach_move] TO [public]
GO
