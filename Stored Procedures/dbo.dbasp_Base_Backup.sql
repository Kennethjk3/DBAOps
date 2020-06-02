SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_Backup] (@dbname sysname = null
					, @target_path nvarchar(200) = null
					, @backup_filename sysname = null
					, @Post_DropDB char(1) = 'y'
					, @delete_source_backup char(1) = 'n'
					, @source_backup_path nvarchar(200) = null
					, @RG_flag char(1) = 'n'
					, @RG_only_flag char(1) = 'n'
					, @backup_by_filegroup_flag char(1) = 'n'
					, @backup_filegroupname sysname = null
					, @ForceSetSize smallint = null
					, @skip_detach char(1) = 'n'
					,@BufferCount		INT		= NULL
					,@MaxTransferSize	INT		= NULL
					,@ForceB2Null		BIT		= NULL
					,@IgnoreMaintOvrd	BIT		= 0
					,@IgnoreB2NullOvrd	BIT		= 0
					)


/*********************************************************
 **  Stored Procedure dbasp_Base_Backup
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  November 20, 2002
 **
 **  This procedure is used to backup a database for the
 **  baseline process.
 **
 **  This proc accepts several input parms (outlined below):
 **
 **  - @dbname is the name of the database being processed.
 **
 **  - @target_path is the full path (unc) where the backup
 **    file will be created.
 **
 **  - @backup_filename is the name of the backup file that
 **    will be created.
 **
 **  - @Post_DropDB is a flag for dropping the DB once the
 **    backup is completed.
 **
 **  - @delete_source_backup is a flag for deleting the source
 **    production backup file from the local restore folder.
 **
 **  - @source_backup_path is the full path (unc) to the restore
 **    folder where the source production backup file was copied.
 **
 **  - @RG_flag is a flag for RedGate backup processing (y or n).
 **
 **  - @RG_only_flag is a flag for RedGate only backup processing (y or n).
 **
 **  - @backup_by_filegroup_flag is a flag for backup by filegroup processing (y or n).
 **
 **  - @backup_filegroupname is the name of the backup filegroup that will be processed.
 **
 **  - @ForceSetSize will force the number of backup files that are created.
 **
 **  - @skip_detach will skipp the ldf detach and attach process.
 **
 **	WARNING: BufferCount and MaxTransferSize values can cause Memory Errors
 **	   The total space used by the buffers is determined by: buffercount * maxtransfersize * DB_Data_Devices
 **	   blogs.msdn.com/b/sqlserverfaq/archive/2010/05/06/incorrect-buffercount-data-transfer-option-can-lead-to-oom-condition.aspx
 **
 **	@BufferCount		If Specified, Forces Value to be used				  X	  X
 **	@MaxTransferSize	If Specified, Forces Value to be used				  X	  X
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
--	11/03/2008	Steve Ledridge		Re-written to remove detach and move processing (renamed as well)
--	08/26/2009	Steve Ledridge		Added SQB converter process to make sure all SQB files are 5.4.
--	01/06/2010	Steve Ledridge		Re-added the code to delete the source backup file.
--	01/24/2010	Steve Ledridge		Removed SQBconvert and added code for FG backups.
--	04/20/2011	Steve Ledridge		New code to process cBAK files.
--	04/17/2013	Steve Ledridge		Change set RG flags.
--	02/05/2014	Steve Ledridge		Converted for multi-file backups.
--	02/13/2014	Steve Ledridge		Modified the pre-baseline delete precess.
--	03/04/2014	Steve Ledridge		Added input parm @ForceSetSize.
--	04/07/2014	Steve Ledridge		Modified cursors to select from temp table.
--	08/14/2014	Steve Ledridge		Added skip detach as input parm.
--	10/09/2014	Steve Ledridge		Fixed case - build to Build.
--	10/28/2014	Steve Ledridge		Added Parameters for @MaxTransferSize and @BufferCount to be used for both Backup and Restore Database scripts.
--	06/08/2016	Steve Ledridge		Modified code for @delete_mask.
--	======================================================================================


/***
Declare
	 @dbname sysname
	,@target_path nvarchar(200)
	,@backup_filename sysname
	,@Post_DropDB nchar(1)
	,@delete_source_backup nchar(1)
	,@source_backup_path nvarchar(200)
	,@RG_flag nchar(1)
	,@RG_only_flag nchar(1)
	,@backup_by_filegroup_flag char(1)
	,@backup_filegroupname sysname
	,@ForceSetSize smallint
	,@skip_detach char(1)


Select @dbname = 'WSS_Content_Request'
Select @target_path = '\\SEAPSQLDPLY01\SEAPSQLDPLY01_BASE_SPT'
Select @backup_filename = 'WSS_Content_Request_prod'
Select @Post_DropDB = 'n'
Select @delete_source_backup = 'n'
Select @source_backup_path = ''
Select @RG_flag = 'n'
Select @RG_only_flag = 'n'
Select @backup_by_filegroup_flag = 'n'
Select @backup_filegroupname = null
Select @ForceSetSize = null
Select @skip_detach = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd			nvarchar(4000)
	,@cmd2			nvarchar(max)
	,@sqlcmd		nvarchar(4000)
	,@dos_command		nvarchar(4000)
	,@parm01		nvarchar(100)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@hold_sharename	sysname
	,@error_count		int
	,@ldf_count		smallint
	,@charpos		int
	,@savepos		int
	,@save_file_path	nvarchar(260)
	,@save_file_name	nvarchar(260)
	,@fileseed		smallint
	,@kill_count		char(1)
	,@iSPID			int
	,@DBID			int
	,@Error			int
	,@vchCommand		nvarchar(255)
	,@ForceEngine		sysname
	,@SetSize		INT
	,@Size			BIGINT
	,@syntax_out		varchar(max)
	,@delete_mask		sysname
	,@delete_baseline	XML


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
	 @cu14fileid		smallint
	,@cu14groupid		smallint
	,@cu14name		nvarchar(128)
	,@cu14filename		nvarchar(260)


----------------  initial values  -------------------
Select @error_count = 0
Select @ForceEngine = 'MSSQL'


Select @save_servername	= @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Create temp tables
Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #temp_ldf_fullpath (filename nchar(260))


CREATE TABLE	#FGs
		(
		id			INT
		,name			SYSNAME
		,size			DECIMAL(15, 2)
		)


Create table #temp_sysfiles (
		fileid smallint,
		groupid smallint,
		name nchar(128),
		filename nchar(260))


--  Set redgate flags if redgate is not installed
If not exists (select 1 from master.sys.objects where name = 'sqlbackup' and type = 'x')
   begin
	Select @RG_flag = 'n'
	Select @RG_only_flag = 'n'
   end


--  Set target path to drive letter path (if it's a local share)
If @target_path like '\\' + @save_servername + '%'
   begin
	Select @hold_sharename = substring(@target_path, len(@save_servername)+4, len(@target_path)-(len(@save_servername)+3))
	If @hold_sharename not like '%\%'
	   begin
		exec DBAOps.dbo.dbasp_get_share_path @hold_sharename, @target_path output
	   end
   end


--  Verify input parm(s)
if @dbname is null or @target_path is null or @backup_filename is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm(s)'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


If @delete_source_backup = 'y' and @source_backup_path = ''
   begin
	Select @miscprint = 'DBA WARNING: Invalid input parms for @delete_source_backup and @source_backup_path.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


If @ForceSetSize is not null and @ForceSetSize > 64
   begin
	Select @ForceSetSize = 64
   end


--  Print Header
Print ''
Print '**************************************************************'
Print 'Start the Baseline Backup process for database ' + rtrim(@dbname)
Print '**************************************************************'
raiserror('', -1,-1) with nowait


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


--  Verify\set RG flags
if @RG_flag = 'n'
   BEGIN
	Select @RG_only_flag = 'n'
   END


if @RG_only_flag = 'y'
   BEGIN
	Select @RG_flag = 'y'
   END


if @RG_flag = 'y'
   BEGIN
	Select @ForceEngine = 'REDGATE'
   END


--  create perm temp table in DBAOps for this DB
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


Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
exec (@cmd)
Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  select * from [' + @dbname + '].sys.sysfiles'
exec (@cmd)
Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
Print @cmd
exec (@cmd)


--  load temp table for sysfiles
SELECT @cmd = 'SELECT fileid, groupid, name, filename From DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
INSERT INTO #temp_sysfiles EXEC (@cmd)


--  Inset a row into the @dbname build table
Select @cmd = 'If exists (select 1 from ' + @dbname + '.sys.objects where name = ''Build'' and type = ''u'')
   begin
	delete from ' + @dbname + '.dbo.Build where vchName = ''' + @dbname + ''' and vchLabel = ''Baseline Backup'' and dtBuildDate > getdate()-1


	INSERT INTO ' + @dbname + '.dbo.Build (vchName, vchLabel, dtBuildDate, vchNotes) VALUES (''' + @dbname + ''', ''Baseline Backup'', GETDATE(), ''' + @dbname + ' Baseline Backup'')
   end'
Print @cmd
exec (@cmd)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  For filegroup backups, skip the detatch
If @backup_by_filegroup_flag = 'y'
   begin
	goto start_backup
  end


If @skip_detach = 'y'
   begin
	goto skip_detach
   end


--  Format the detach command
Print ''
Print '**************************************************************'
Print 'Create the detach gsql file for database ' + rtrim(@dbname)
Print '**************************************************************'
raiserror('', -1,-1) with nowait


SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''master.sys.sp_detach_db ''''' + rtrim(@dbname) + ''''', @skipchecks = ''''true''''''" -E -o\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_detach.gsql'
PRINT  @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


--  Format the attach command
Print ''
Print '**************************************************************'
Print 'Create the attach gsql file for database ' + rtrim(@dbname)
Print '**************************************************************'
raiserror('', -1,-1) with nowait


SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''CREATE DATABASE [' + rtrim(@dbname) + '] ON''" -E >\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
PRINT  @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


Select @fileseed = 1
Select @ldf_count = 0


--------------------  Cursor for 12DB  -----------------------
select @cmd = 'DECLARE cu12_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From #temp_sysfiles  f ' +
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


	If @cu12groupid <> 0
	   begin
		If @fileseed = 1
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
		Else
		   begin
			SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''  ,(FILENAME = ''''' + rtrim(@cu12filename) + ''''')''" -E >>\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_attach.gsql'
			PRINT @sqlcmd
			EXEC master.sys.xp_cmdshell @sqlcmd
		   end
	   end
	Else
	   begin
		Select @ldf_count = @ldf_count + 1
	   end


	--  If more than one LDF file was found, skip the detach process
	If @ldf_count > 1
	   begin
		Select @skip_detach = 'y'
		goto skip_detach
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


--  Pause for a second
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
Select @kill_count = 0


start_kill:
If @kill_count > 5
   begin
	Select @skip_detach = 'y'
	goto skip_detach
   end

Select @iSPID = 50
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
			Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
			RAISERROR(@miscprint, -1, -1 ) with nowait
			Select @kill_count = @kill_count + 1
			waitfor delay '00:01:00'
			goto start_kill
		   end
	   end
   end


Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID
If @iSPID is not null
   begin
	Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
	RAISERROR(@miscprint, -1, -1 ) with nowait
	Select @kill_count = @kill_count + 1
	waitfor delay '00:01:00'
	goto start_kill
   end


--  Detach the database
Print ''
Print '**************************************************************'
Print 'Detach the database ' + rtrim(@dbname)
Print '**************************************************************'
RAISERROR('', -1, -1 ) with nowait
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -u -E -i\\' + @save_servername + '\DBASQL\' + rtrim(@dbname) + '_detach.gsql'
PRINT   @sqlcmd
EXEC master.sys.xp_cmdshell @sqlcmd


--  Delete the LDF DB file and update file permissions
--------------------  Cursor for 13  -----------------------
select @cmd = 'DECLARE cu13_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From #temp_sysfiles  f ' +
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
	RAISERROR('', -1, -1 ) with nowait


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


	RAISERROR('', -1, -1 ) with nowait


   End  -- loop 13
   DEALLOCATE cu13_file


--  Delete ldf DB file that might be at the new location
Print ''
Print '**************************************************************'
Print 'Delete LDF file at the new location: '
Print 'Note:  If old and new location is the same, this will error (which is fine).'
Print '**************************************************************'
Select @save_file_name = ''
Select @save_file_name = @save_file_path + '\' + rtrim(@dbname) + '*.ldf'
Select @cmd = 'Del ' + rtrim(@save_file_name)
Print @cmd
RAISERROR('', -1, -1 ) with nowait
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Attach the DB and force create a new LDF file
Print ''
Print '**************************************************************'
Print 'Attach the database creating a new LDF file'
Print '**************************************************************'
RAISERROR('', -1, -1 ) with nowait
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
RAISERROR('', -1, -1 ) with nowait


skip_detach:
--  Shrink the ldf file if the detach process was skipped
If @skip_detach = 'y'
   begin
	exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = @dbname


	Print ''
	Print '**************************************************************'
	Print 'The database ' + rtrim(@dbname) + ' has now been shrunk via dbasp_ShrinkLDFFiles.'
	Print '**************************************************************'
	RAISERROR('', -1, -1 ) with nowait
   end


start_backup:


--  Backup the DB
Print ''
Print '**************************************************************'
Print 'Starting the BACKUP section'
Print '**************************************************************'
RAISERROR('', -1, -1 ) with nowait


--  Delete old backup files
Select @delete_mask = rtrim(@dbname) + '*prod*'
SELECT @delete_baseline =
(
SELECT FullPathName [Source]
FROM DBAOps.dbo.dbaudf_DirectoryList2(@target_path, @delete_mask, 0)
FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
)


If @delete_baseline is not null
   begin
	exec dbo.dbasp_FileHandler @delete_baseline
   end


--  Verify the delete of the old backup files
SELECT @delete_baseline =
(
SELECT FullPathName [Source]
FROM DBAOps.dbo.dbaudf_DirectoryList2(@target_path, @delete_mask, 0)
FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
)


If @delete_baseline is not null
   begin
	Print 'Error:  The old baseline files were not deleted.'
	Select @error_count = @error_count + 1
	Goto label99
   end


--  Determine set size
Delete from #FGs
Select @CMD2	= REPLACE('USE {DBNAME};
			SET NOCOUNT ON;
			SET ANSI_WARNINGS OFF;
			INSERT INTO	#FGs
			SELECT		fg.data_space_id
					,fg.name
					,COALESCE((cast((sum(a.used_pages) * 8192/1048576.) as decimal(15, 2))*25)/100,0)
			FROM		sys.filegroups fg
			LEFT JOIN	sys.allocation_units a
				ON	fg.data_space_id = a.data_space_id


			LEFT JOIN	sys.partitions p
				ON	p.partition_id = a.container_id
			LEFT JOIN	sys.internal_tables it
				ON	p.object_id = it.object_id
			GROUP BY	fg.data_space_id
					,fg.name;','{DBNAME}',@DBNAME)
EXEC (@CMD2)


--select * from #FGs


If @backup_by_filegroup_flag = 'n'
   begin
	Select @Size = sum(size) FROM #FGs
   end
Else
   begin
	Select @Size = size FROM #FGs where name = @backup_filegroupname
   end


Select @Size = size FROM #FGs where name = @backup_filegroupname


SELECT @SetSize = COALESCE(@Size,(512*1))/(512*1)


If @SetSize < 1
   begin
	Select @SetSize = 1
   end
Else If @SetSize > 64
   begin
	Select @SetSize = 64
   end


If @ForceEngine = 'Redgate' and @SetSize > 32
   begin
	Select @SetSize = 32
   end


If @ForceSetSize is not null
   begin
	Select @SetSize = @ForceSetSize
   end


--  Backup the DB
If @backup_by_filegroup_flag = 'n'
   begin
	--  Create Backup code
	exec DBAOps.dbo.dbasp_format_BackupRestore
				@DBName			= @dbname
				, @ForceFileName	= @backup_filename
				, @Mode			= 'BF'
				, @FilePath		= @target_path
				, @ForceEngine		= @ForceEngine
				, @ForceChecksum	= 1
				, @ForceSetSize	= @SetSize
				, @SetName		= 'dbasp_Base_Backup'
				, @SetDesc		= 'DBAOps_baseline'
				, @Verbose		= 0
				, @BufferCount		= @BufferCount
				, @MaxTransferSize	= @MaxTransferSize
				, @ForceB2Null		= @ForceB2Null
				, @IgnoreMaintOvrd	= @IgnoreMaintOvrd
				, @IgnoreB2NullOvrd	= @IgnoreB2NullOvrd
				, @syntax_out		= @syntax_out output
   end
Else
   begin
	exec DBAOps.dbo.dbasp_format_BackupRestore
				@DBName			= @dbname
				, @ForceFileName	= @backup_filename
				, @Mode			= 'BF'
				, @FileGroups		= @backup_filegroupname
				, @FilePath		= @target_path
				, @ForceEngine		= @ForceEngine
				, @ForceChecksum	= 1
				, @ForceSetSize	= @SetSize
				, @SetName		= 'dbasp_Base_Backup'
				, @SetDesc		= 'DBAOps_baseline'
				, @Verbose		= 0
				, @BufferCount		= @BufferCount
				, @MaxTransferSize	= @MaxTransferSize
				, @ForceB2Null		= @ForceB2Null
				, @IgnoreMaintOvrd	= @IgnoreMaintOvrd
				, @IgnoreB2NullOvrd	= @IgnoreB2NullOvrd
				, @syntax_out		= @syntax_out output
   end


Print ''
exec DBAOps.dbo.dbasp_PrintLarge @syntax_out
RAISERROR('',-1,-1) WITH NOWAIT


--  Execute the backup
Exec (@syntax_out)


Print ' '
Print 'The database ' + rtrim(@dbname) + ' has now been backed up to the target location'
Print ' '
RAISERROR('', -1, -1 ) with nowait


--  Drop the DB if requested (and make sure the DB files no longer exist)
If @Post_DropDB = 'y'
   begin
	Print ' '
	Print ' '
	Print '-- Section to Drop the Database'


	--  Capture sysfile info for this database
	Print ''
	Print '-- Capture sysfiles info for this database.'


	Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
	--Print  @cmd
	exec  (@cmd)
	Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  select * from [' + @dbname + '].sys.sysfiles'
	--Print  @cmd
	exec  (@cmd)


	--Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
	--Print  @cmd
	--exec  (@cmd)


	RAISERROR('', -1, -1 ) with nowait


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


	Select @vchCommand = 'ALTER DATABASE [' + rtrim(@dbname) + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
	Print @vchCommand
	exec (@vchCommand)


	RAISERROR('', -1, -1 ) with nowait


	--  Set the dbid value
	Select @DBID = dbid FROM master.sys.sysdatabases where name = @dbname
	Select @kill_count = 0


	start_kill2:
	If @kill_count > 5
	   begin
		goto skip_kill2
	   end

	Select @iSPID = 50
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
				Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
				RAISERROR(@miscprint, -1, -1 ) with nowait
				Select @kill_count = @kill_count + 1
				waitfor delay '00:01:00'
				goto start_kill2
			   end
		   end
	   end


	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID
	If @iSPID is not null
	   begin
		Select @miscprint = 'Unable to kill spid related to database ' + rtrim(@dbname) + '.  spid = ' + convert(varchar(10),@iSPID)
		RAISERROR(@miscprint, -1, -1 ) with nowait
		Select @kill_count = @kill_count + 1
		waitfor delay '00:01:00'
		goto start_kill2
	   end


	skip_kill2:


	Select @cmd = 'drop database [' + @dbname + ']'
	Print  @cmd
	RAISERROR('', -1, -1 ) with nowait
	Exec(@cmd)


	waitfor delay '00:00:02'


	--  Verify the DB no longer exists
	If exists (select 1 from master.sys.databases where name = @dbname)
	   BEGIN
		Select @miscprint = 'DBA ERROR: Unable to drop database ' + @dbname + '. The Database must be dropped and the process restarted in the next step.'
		Print  @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   END


	--  Now make sure the DB files were deleted
	--------------------  Cursor for 14DB  -----------------------
	select @cmd = 'DECLARE cu14_file Insensitive Cursor For ' +
	  'SELECT f.fileid, f.groupid, f.name, f.filename
	   From #temp_sysfiles  f ' +
	  'Order By f.fileid For Read Only'


	EXECUTE(@cmd)


	OPEN cu14_file


	WHILE (14=14)
	   Begin
		FETCH Next From cu14_file Into @cu14fileid, @cu14groupid, @cu14name, @cu14filename
		IF (@@fetch_status < 0)
		   begin
		      CLOSE cu14_file
		      BREAK
		   end

		Select @cmd = rtrim(@cu14filename)
		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @cmd
		If (select doesexist from #fileexists) = 1
		   begin
			Select @cmd = 'Del ' + rtrim(@cmd)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


		waitfor delay '00:00:02'


		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @cmd
		If (select doesexist from #fileexists) = 1
		   begin
			Select @miscprint = 'DBA ERROR: Unable to delete database files for ' + @dbname + ' (file - ' + rtrim(@cu14filename) + ').  The files for this DB must be deleted and the process restarted in the next step.'
			Print  @miscprint
			Select @error_count = @error_count + 1
			goto label99
		   end


		RAISERROR('', -1, -1 ) with nowait


	   End  -- loop 14
	   DEALLOCATE cu14_file


   end


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


--  Finalization  -------------------------------------------------------------------


label99:


select @cmd = 'If (object_id(''DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'') is not null)
   begin
	drop table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles
   end'
exec (@cmd)


If (object_id('tempdb.dbo.#temp_ldf_fullpath') is not null)
   begin
	drop table #temp_ldf_fullpath
   end
If (object_id('tempdb.dbo.#fileexists') is not null)
   begin
	drop table #fileexists
   end


If (object_id('tempdb.dbo.#FGs') is not null)
   begin
	drop table #FGs
   end


If (object_id('tempdb.dbo.#temp_sysfiles') is not null)
   begin
	drop table #temp_sysfiles
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
GRANT EXECUTE ON  [dbo].[dbasp_Base_Backup] TO [public]
GO
