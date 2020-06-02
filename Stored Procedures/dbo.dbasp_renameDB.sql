SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_renameDB] ( @current_dbname sysname = null,
					@new_dbname sysname = null,
					@force_newldf char(1) = 'n',
					@auto_create_stats_on char(1) = 'y',
					@auto_update_stats_on char(1) = 'y',
					@auto_shrink_on char(1) = 'n',
					@partial_flag char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_renameDB
 **  Written by Steve Ledridge, Virtuoso
 **  August 06, 2008
 **
 **  This procedure is used to rename a DB using detach and reattach.
 **
 **  This proc accepts the following input parms:
 **  - @current_dbname is the name of the current database being renamed.
 **  - @new_dbname will be the name of the database after the rename.
 **  - @force_newldf is a flag to force the creation of a new ldf file
 **  - @auto_create_stats_on is a flag to set this DB option after the rename.
 **  - @auto_update_stats_on is a flag to set this DB option after the rename.
 **  - @auto_shrink_on is a flag to set this DB option after the rename.
 **  - @partial_flag is a flag to set for DB's that were restored minus one or more filegroups.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/06/2008	Steve Ledridge		New process.
--	09/25/2009	Steve Ledridge		Add kill process.
--	09/29/2009	Steve Ledridge		Increased the SPID default from 6 to 10.
--	10/26/2009	Steve Ledridge		Increased the SPID default from 10 to 49.
--	10/28/2009	Steve Ledridge		Removed code to set offline and then back to online.
--	12/09/2010	Steve Ledridge		New code for Partial DB processing.
--	12/07/2011	Steve Ledridge		Added DBCC FREEPROCCACHE
--	09/13/2012	Steve Ledridge		Fixed issue with trailing spaces in file path for files to skip.
--	======================================================================================


/***
Declare @current_dbname sysname
Declare @new_dbname sysname
Declare @force_newldf char(1)
Declare @auto_create_stats_on char(1)
Declare @auto_update_stats_on char(1)
Declare @auto_shrink_on char(1)
Declare @partial_flag char(1)


Select @current_dbname = 'ArtistListing_new'
Select @new_dbname = 'ArtistListing'
Select @force_newldf = 'y'
Select @auto_create_stats_on = 'y'
Select @auto_update_stats_on = 'y'
Select @auto_shrink_on = 'n'
Select @partial_flag = 'y'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
	,@cmd 				nvarchar(4000)
	,@charpos			int
	,@savepos			int
	,@save_file_path		nvarchar(500)
	,@hold_ldfpath			nvarchar(260)
	,@fileseed			smallint
	,@attach_cmd			nvarchar(4000)
	,@iSPID				int
	,@DBID				int


DECLARE
	 @cu12fileid			smallint
	,@cu12groupid			smallint
	,@cu12name			nvarchar(128)
	,@cu12filename			nvarchar(260)


----------------  initial values  -------------------
Select @error_count = 0


Create table #db_files (
		fileid smallint,
		groupid smallint,
		size int,
		maxsize int,
		growth int,
		status int,
		perf int,
		name nchar(128),
		filename nchar(260))


create table #fileexists (
	doesexist smallint,
	fileindir smallint,
	direxist smallint)


--  Check input parms
if DATABASEPROPERTYEX (@current_dbname,'status') <> 'ONLINE' or DATABASEPROPERTYEX (@current_dbname,'status') is null
   BEGIN
	Select @miscprint = 'DBA WARNING: @current_dbname must be a vaild (online) database'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if exists (select 1 from master.sys.databases where name = @new_dbname)
   BEGIN
	Select @miscprint = 'DBA WARNING: The value for input parm @new_dbname currently exists as a database.  Please drop that DB and rerun this process.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


--  Inset DBfile info into the #db_files table
Delete from #db_files


Select @cmd = 'Insert into #db_files  select * from [' + @current_dbname + '].sys.sysfiles'
exec (@cmd)
--select * from #db_files


If (select count(*) from #db_files) = 0
   begin
	Select @miscprint = 'DBA WARNING: No entries in the sys.sysfiles table for the current database ' + @current_dbname + '.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


Print '--  DB Rename Process Starting'
Print ' '
Select @miscprint = '--  Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print ' '


--  First we format the attach command
Select @attach_cmd = 'CREATE DATABASE [' + rtrim(@new_dbname) + '] ON '


Select @fileseed = 1


--------------------  Cursor for 12DB  -----------------------
select @cmd = 'DECLARE cu12_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.name, f.filename
   From #db_files  f ' +
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


	If @partial_flag = 'y'
	   begin
		--  Skip files that do not exist
		Delete from #fileexists
		Select @cu12filename = rtrim(ltrim(@cu12filename))
		print @cu12filename
		Insert into #fileexists exec master.sys.xp_fileexist @cu12filename
		select * from #fileexists


		If not exists (select 1 from #fileexists where doesexist = 1)
		   begin
			goto skip_filename
		   end
	   end


	If @fileseed = 1
	   begin
		If @cu12groupid <> 0 or @force_newldf = 'n'
		   begin
			SELECT @attach_cmd = @attach_cmd + '(FILENAME = ''' + rtrim(@cu12filename) + ''')'


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
		If @cu12groupid <> 0 or @force_newldf = 'n'
		   begin
			SELECT @attach_cmd = @attach_cmd + ', (FILENAME = ''' + rtrim(@cu12filename) + ''')'
		   end
	   end


	Select @fileseed = @fileseed + 1

	skip_filename:


   End  -- loop 12
   DEALLOCATE cu12_file


If @force_newldf = 'n'
   begin
	SELECT @attach_cmd = @attach_cmd + ' FOR ATTACH'
   end
Else
   begin
	SELECT @attach_cmd = @attach_cmd + ' FOR ATTACH_REBUILD_LOG'
   end


If (select is_db_chaining_on from master.sys.databases where name = @current_dbname) = 1
  and (select is_trustworthy_on from master.sys.databases where name = @current_dbname) = 1
   begin
	SELECT @attach_cmd = @attach_cmd + ' WITH TRUSTWORTHY ON, DB_CHAINING ON; '
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @current_dbname) = 0
  and (select is_trustworthy_on from master.sys.databases where name = @current_dbname) = 0
   begin
	SELECT @attach_cmd = @attach_cmd + ' WITH TRUSTWORTHY OFF, DB_CHAINING OFF; '
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @current_dbname) = 1
  and (select is_trustworthy_on from master.sys.databases where name = @current_dbname) = 0
   begin
	SELECT @attach_cmd = @attach_cmd + ' WITH TRUSTWORTHY OFF, DB_CHAINING ON; '
   end
Else If (select is_db_chaining_on from master.sys.databases where name = @current_dbname) = 0
  and (select is_trustworthy_on from master.sys.databases where name = @current_dbname) = 1
   begin
	SELECT @attach_cmd = @attach_cmd + ' WITH TRUSTWORTHY ON, DB_CHAINING OFF; '
   end


--  Kill process
Select @DBID = dbid FROM master.sys.sysdatabases where name = @current_dbname


Select @iSPID = 49
WHILE @iSPID IS NOT NULL
   begin
	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID and spid > @iSPID
	IF @iSPID IS NOT NULL
	   begin
		Select @cmd = 'KILL ' + convert(varchar(12), @iSPID )
		Print @cmd
		exec(@cmd)
	   end
   end


--  Now we start the detach process
select @cmd = 'alter database [' + @current_dbname + '] set RESTRICTED_USER WITH NO_WAIT'
Print 'Set current DB restricted user - command being executed;'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


select @cmd = 'alter database [' + @current_dbname + '] SET SINGLE_USER WITH NO_WAIT'
Print 'Set current DB single user - command being executed;'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


Select @cmd = 'exec master.sys.sp_detach_db ''' + rtrim(@current_dbname) + ''', @skipchecks = ''true'''
Print 'Here is the Detach command being executed;'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


If @@error<> 0
   begin
	select @miscprint = 'DBA Error:  Detach failure for command ' + @cmd
	print  @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


-- Pause before we re-attach
Waitfor delay '00:00:02'


If @force_newldf = 'y'
   begin
	If exists (select 1 from #db_files where groupid = 0)
	   begin
		start_ldf01:
		select @hold_ldfpath = (select top 1 filename from #db_files where groupid = 0)


		select @cmd = 'Del ' + @hold_ldfpath
		Print 'Delete current LDF file using command;'
		Print @cmd
		raiserror('', -1,-1) with nowait
		Exec master.sys.xp_cmdshell @cmd


		Delete from #db_files where filename = @hold_ldfpath
		If exists (select 1 from #db_files where groupid = 0)
		   begin
			goto start_ldf01
		   end
	   end


	select @cmd = 'Del ' + @save_file_path + '\' + @new_dbname + '_log.ldf'
	Print 'Make sure the new LDF file does not exist using command;'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec master.sys.xp_cmdshell @cmd
   end


-- reattach the DB
Print 'Here is the Attach command being executed;'
Print @attach_cmd
raiserror('', -1,-1) with nowait
Exec (@attach_cmd)


If @@error<> 0
   begin
	select @miscprint = 'DBA Error:  ReAttach Failure for command ' + @attach_cmd
	print  @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


-- Pause after we re-attach
Waitfor delay '00:00:02'


--  Check to make sure the DB is 'online'
If DATABASEPROPERTYEX (@new_dbname,'status') <> 'ONLINE'
   begin
	select @miscprint = 'DBA ERROR:  The database rename was not successful.'
	print  @miscprint
	Select @error_count = @error_count + 1
   end


--  Set DB options
Print ''
Print 'Here are the Alter Database Option commands being executed;'


If @auto_create_stats_on = 'y'
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end
Else
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end


If @auto_update_stats_on = 'y'
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end
Else
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end


If @auto_shrink_on = 'y'
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_SHRINK ON WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end
Else
   begin
	select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait
	Exec (@cmd)
   end


select @cmd = 'ALTER DATABASE [' + @new_dbname + '] SET MULTI_USER WITH NO_WAIT'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


select @cmd = 'ALTER AUTHORIZATION ON DATABASE::' + @new_dbname + ' TO sa;'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


select @cmd = 'DBCC FREEPROCCACHE'
Print @cmd
raiserror('', -1,-1) with nowait
Exec (@cmd)


Print '--  DB Rename Process Completed'
Print ' '
Select @miscprint = '--  ' + convert(varchar(30),getdate(),9)
Print  @miscprint


-------------------   end   --------------------------


label99:


drop table #db_files
drop table #fileexists


If @error_count > 0
   begin
	raiserror(@miscprint,16,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_renameDB] TO [public]
GO
