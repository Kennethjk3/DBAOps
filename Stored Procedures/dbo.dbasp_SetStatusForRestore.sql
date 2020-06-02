SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetStatusForRestore] (@dbname sysname = null
						,@dropDB char(1) = 'n'
						)


/*********************************************************
 **  Stored Procedure dbasp_SetStatusForRestore
 **  Written by Steve Ledridge, Virtuoso
 **  March 23, 2004
 **
 **  This procedure is used to set the database status prior to
 **  the DB restore.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/23/2004	Steve Ledridge		New process
--	01/21/2005	Steve Ledridge		Set save_status for DB status
--	03/15/2006	Steve Ledridge		Updated for SQL 2005.
--	10/30/2006	Steve Ledridge		Added check/fix for schema ownership.
--	01/08/2007	Steve Ledridge		Added DB drop for DB's that are not online.
--	02/08/2008	Steve Ledridge		Added disable for service broker.
--	07/15/2008	Steve Ledridge		Added @dropDB input parm and section to drop the database.
--	07/21/2008	Steve Ledridge		Added code to drop assemblies.
--	03/31/2008	Steve Ledridge		Added code to drop dropassembly_modules.
--	04/02/2008	Steve Ledridge		New code to remove type dependencies.
--	09/30/2009	Steve Ledridge		Removed(commented out) the set single user and replace with
--						kill spid loop.
--	10/12/2011	Steve Ledridge		Modified dropping related types.
--	11/01/2011	Steve Ledridge		Set DB to restricted user at the start.
--	12/01/2011	Steve Ledridge		Processing for roles.
--	12/07/2011	Steve Ledridge		Changed sysusers to sys.database_principals.
--	09/10/2012	Steve Ledridge		Added function type FT.
--	03/30/2015	Steve Ledridge		Code to delete old DB files after DB drop if needed.
--	08/07/2015	Steve Ledridge		Skip users with authentication_type = 0.
--	08/27/2015	Steve Ledridge		Removed code for authentication_type.
--	======================================================================================


/**
declare @dbname sysname
declare @dropDB char(1)


select @dbname = 'PumpAudio_Live'
select @dropDB = 'y'
--**/


DECLARE
	 @miscprint		nvarchar(2000)
	,@hold_oldstatus	int
	,@cmd			nvarchar(2000)
	,@query_text		varchar(500)
	,@error_count		int
	,@return_name 		sysname
	,@return_type		sysname
	,@return_object_id	int
	,@save_object_name	sysname
	,@save_object_type	nvarchar(20)
	,@save_schema_name	sysname
	,@save_object_id	int
	,@DBID			int
	,@iSPID			int
	,@delete_DBfiles	XML


DECLARE
	 @cu11UName		sysname


DECLARE
	  @cu12UName		sysname
	 ,@cu12SName		sysname


DECLARE
	 @cu13UName		sysname


DECLARE
	 @cu15UName		sysname


DECLARE
	 @cu14fileid		int
	,@cu14groupid		int
	,@cu14name		nvarchar(128)
	,@cu14filename		nvarchar(260)


----------------  initial values  -------------------
Select @error_count = 0


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #objects (the_object_id int)


declare @DBfiles table	(physical_name nvarchar(260))


/****************************************************************
 *                MainLine
 ***************************************************************/


Print '-- Prepare the Restore process for database: ' + Upper(@dbname)
Print ' '
Print ' '


--  If the DB is not ONLINE, drop the database
If DATABASEPROPERTYEX(@dbname, N'Status') != N'ONLINE'
   begin
    Select @query_text = 'drop database [' + @dbname + ']'
    print @query_text
    Exec(@query_text)


    print ' '
    goto label99
   end


--  Set the DB to DBO Use Only
Print ' '
Print ' '
Print '-- Section to set the database to RESTRICTED_USER'


Select @query_text = 'alter database [' + @dbname + '] set RESTRICTED_USER with ROLLBACK IMMEDIATE '
print @query_text
Exec(@query_text)


Select @query_text = 'alter database [' + @dbname + '] set READ_WRITE with ROLLBACK IMMEDIATE '
print @query_text
Exec(@query_text)


print ' '


--  Disable Service Broker
Select @query_text = 'alter database [' + @dbname + '] SET DISABLE_BROKER with ROLLBACK IMMEDIATE;'
print @query_text
Exec(@query_text)


print ' '


--  Pause for a couple seconds
waitfor delay '00:00:02'


--  Kill process
Select @DBID = dbid FROM master.sys.sysdatabases where name = @dbname


Select @iSPID = 10
WHILE @iSPID IS NOT NULL
   begin
	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID and spid > @iSPID
	IF @iSPID IS NOT NULL
	   begin
		Select @query_text = 'KILL ' + convert(varchar(12), @iSPID )
		Print @query_text
		exec(@query_text)
	   end
   end


----  Alter the database to single user mode
--print ' '
--Print '-- Section to set the database to single user'


--Select @query_text = 'alter database [' + @dbname + '] set SINGLE_USER with ROLLBACK IMMEDIATE '
--print @query_text
--Exec(@query_text)


--print ' '


--  Pause for a couple seconds
waitfor delay '00:00:02'


--  Alter the database to offline mode
print ' '
Print '-- Section to set the database to offline'


Select @query_text = 'alter database [' + @dbname + '] set OFFLINE with ROLLBACK IMMEDIATE '
print @query_text
Exec(@query_text)


print ' '


--  Pause for a couple seconds
waitfor delay '00:00:02'


--  Alter the database to online mode
print ' '
Print '-- Section to set the database to online'


Select @query_text = 'alter database [' + @dbname + '] set ONLINE with ROLLBACK IMMEDIATE '
print @query_text
Exec(@query_text)


print ' '


--  Pause for a couple seconds
waitfor delay '00:00:02'


If @dropDB = 'n'
   begin
	goto start_drop_DBusers
   end


--  Section to Drop Assemblies and related objects
Print '-- Drop Assemblies and related objects for Database ' + @DBname


--  Drop any assemblies


--  Remove type dependencies
Print '-- Start Remove type dependencies'
Select @cmd = 'use [' + @dbname + '] SELECT t.object_id
   FROM sys.triggers t
   INNER JOIN sys.assembly_modules m ON t.object_id = m.object_id
   INNER JOIN sys.assemblies a ON m.assembly_id = a.assembly_id
  UNION
  SELECT o.object_id
   FROM sys.objects o
   INNER JOIN sys.assembly_modules m ON o.object_id = m.object_id
   INNER JOIN sys.assemblies a ON m.assembly_id = a.assembly_id'


delete from #objects
Insert into #objects exec (@cmd)
--select * from #objects


If (select count(*) from #objects) > 0
   begin
	start_delete_tpye_dependents:


	Select @save_object_id = (select top 1 the_object_id from #objects order by the_object_id)


	Select @cmd = 'use [' + @dbname + '] select @save_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @save_object_id) + ')'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_object_name sysname output', @save_object_name output
	print @save_object_name


	Select @cmd = 'use [' + @dbname + '] select @save_object_type = (select type from sys.objects where object_id = ' + convert(nvarchar(20), @save_object_id) + ')'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_object_type sysname output', @save_object_type output


	Select @cmd = 'use [' + @dbname + '] select @save_schema_name = (select s.name from sys.objects o, sys.schemas s where o.object_id = ' + convert(nvarchar(20), @save_object_id) + ' and o.schema_id = s.schema_id)'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_schema_name sysname output', @save_schema_name output


	If @save_object_type in ('P', 'PC')
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP procedure [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
	   end
	Else If @save_object_type in ('FN', 'FS', 'TF', 'FT')
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP function [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
	   end
	Else If @save_object_type = 'AF'
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP AGGREGATE [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
	   end
	Else If @save_object_type = 'U'
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP table [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
	   end
	Else If @save_object_type = 'TR'
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP trigger [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
	   end


	delete from #objects where the_object_id = @save_object_id
	If (select count(*) from #objects) > 0
	   begin
		goto start_delete_tpye_dependents
	   end
   end


--  First, drop any related types
Print '-- Start drop any related types'
start_drop_types:


Select @cmd = 'use [' + @dbname + '] select @return_type = (SELECT top 1 name from sys.assembly_types where assembly_id in (select assembly_id FROM sys.ASSEMBLY_MODULES) order by name)'
--print @cmd
EXEC sp_executesql @cmd, N'@return_type sysname output', @return_type output


If @return_type is not null
   begin
	Select @cmd = 'use [' + @dbname + '] DROP type [' + @return_type + '];'
	Print @cmd
	Exec (@cmd)
	goto start_drop_types
   end


--  Next, drop any assembly_modules
Print '-- Start drop any assembly_modules'
start_dropassembly_modules:


Select @cmd = 'use [' + @dbname + '] select @return_object_id = (select top 1 object_id FROM sys.ASSEMBLY_MODULES)'
--print @cmd
EXEC sp_executesql @cmd, N'@return_object_id int output', @return_object_id output


If @return_object_id is not null
   begin
	Select @cmd = 'use [' + @dbname + '] select @save_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @return_object_id) + ')'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_object_name sysname output', @save_object_name output


	Select @cmd = 'use [' + @dbname + '] select @save_object_type = (select type from sys.objects where object_id = ' + convert(nvarchar(20), @return_object_id) + ')'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_object_type sysname output', @save_object_type output


	Select @cmd = 'use [' + @dbname + '] select @save_schema_name = (select s.name from sys.objects o, sys.schemas s where o.object_id = ' + convert(nvarchar(20), @return_object_id) + ' and o.schema_id = s.schema_id)'
	--print @cmd
	EXEC sp_executesql @cmd, N'@save_schema_name sysname output', @save_schema_name output


	If @save_object_type in ('P', 'PC')
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP procedure [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
		goto start_dropassembly_modules
	   end
	Else If @save_object_type in ('FN', 'FS', 'TF')
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP function [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
		goto start_dropassembly_modules
	   end
	Else If @save_object_type = 'AF'
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP AGGREGATE [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
		goto start_dropassembly_modules
	   end
	Else If @save_object_type = 'TR'
	   begin
		Select @cmd = 'use [' + @dbname + '] DROP trigger [' + @save_schema_name + '].[' + @save_object_name + '];'
		Print @cmd
		Exec (@cmd)
		goto start_dropassembly_modules
	   end
   end


Print '-- Start drop assemblies'
start_dropassemblies:

Select @cmd = 'use [' + @dbname + '] select @return_name = (select top 1 name FROM sys.assemblies where principal_id > 4 and principal_id < 16384)'
--print @cmd
EXEC sp_executesql @cmd, N'@return_name sysname output', @return_name output


If @return_name is not null
   begin
	Select @cmd = 'use [' + @dbname + '] DROP ASSEMBLY [' + @return_name + '];'
	Print @cmd
	Exec (@cmd)
	goto start_dropassemblies
   end


start_drop_DBusers:


--  Section to Drop all DB Users
Print '-- Drop All Database Users for Database ' + @DBname


--  Drop any schemas with the same name as the user
--------------------  Cursor for database users -----------------------
EXECUTE('DECLARE cursor_11 Insensitive Cursor For ' +
  'SELECT u.Name
   From [' + @DBname + '].sys.database_principals  u ' +
  'Where u.type <> ''R''
   and u.principal_id > 4
   Order by u.name For Read Only')


OPEN cursor_11


WHILE (11=11)
   Begin
	FETCH Next From cursor_11 Into @cu11UName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11
	      BREAK
           end


	Select @cmd = 'use [' + @DBname + '] if exists (select 1 from sys.schemas where name = ''' + @cu11UName + ''') DROP SCHEMA [' + @cu11UName + '];'
	Print @cmd
	Exec (@cmd)


   End  -- loop 11
Deallocate cursor_11


Print ' '


--  Modify ownership of any schema that is owned by a user we are about to drop
--------------------  Cursor for database schemas -----------------------
EXECUTE('DECLARE cursor_12 Insensitive Cursor For ' +
  'SELECT u.Name, s.name
   From [' + @DBname + '].sys.database_principals  u, [' + @DBname + '].sys.schemas  s ' +
  'Where u.principal_id = s.principal_id
   and u.type <> ''R''
   and u.principal_id > 4
   Order by u.name For Read Only')


OPEN cursor_12


WHILE (12=12)
   Begin
	FETCH Next From cursor_12 Into @cu12UName, @cu12SName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_12
	      BREAK
           end


	Select @cmd = 'use [' + @DBname + '] If exists(select 1 from sys.database_principals where name = ''' + @cu12SName + ''')
   begin
	ALTER AUTHORIZATION ON SCHEMA::' + @cu12SName + ' TO ' + @cu12SName + '
   end
Else
   begin
	ALTER AUTHORIZATION ON SCHEMA::' + @cu12SName + ' TO dbo
   end
'
	Print @cmd
	Exec (@cmd)


   End  -- loop 12
Deallocate cursor_12


Print ' '


--  Modify ownership of any roles that are owned by a user we are about to drop
--------------------  Cursor for database schemas -----------------------
EXECUTE('DECLARE cursor_13 Insensitive Cursor For ' +
  'SELECT u.Name
   From [' + @DBname + '].sys.database_principals  u ' +
  'Where u.type <> ''R''
   and u.owning_principal_id <> 1
   Order by u.name For Read Only')


OPEN cursor_13


WHILE (13=13)
   Begin
	FETCH Next From cursor_13 Into @cu13UName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_13
	      BREAK
           end


	Select @cmd = 'use [' + @DBname + '] If exists(select 1 from sys.database_principals where name = ''' + @cu13UName + ''')
   begin
	ALTER AUTHORIZATION ON ROLE::' + @cu13UName + ' TO dbo
   end
'
	Print @cmd
	Exec (@cmd)


   End  -- loop 13
Deallocate cursor_13


Print ' '


--  Now, drop the users
--------------------  Cursor for database users -----------------------
EXECUTE('DECLARE cursor_15 Insensitive Cursor For ' +
  'SELECT u.Name
   From [' + @DBname + '].sys.database_principals  u ' +
  'Where u.type <> ''R''
   and u.principal_id > 4
   Order by u.name For Read Only')


OPEN cursor_15


WHILE (15=15)
   Begin
	FETCH Next From cursor_15 Into @cu15UName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_15
	      BREAK
           end


	Select @cmd = 'use [' + @DBname + '] DROP USER [' + @cu15UName + '];'
	Print @cmd
	Exec (@cmd)


   End  -- loop 15
Deallocate cursor_15


Print ' '


--  Drop the DB if requested (and make sure the DB files no longer exist)
start_DBdrop:
If @dropDB = 'y'
   begin
	Print ' '
	Print ' '
	Print '-- Section to Drop the Database'


	--  Capture sysfile info for this database
	Print ''
	Print '-- Capture sysfiles info for this database.'


	Insert into @DBfiles select physical_name from master.sys.master_files where database_id = DB_ID(@dbname)


	select @cmd = 'If (object_id(''DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'') is not null)
	   begin
		drop table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles
	   end'
	Print  @cmd
	exec  (@cmd)
	Print ''


	Select @cmd = 'Create table DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles (
			fileid int,
	 		groupid int,
			size int,
			maxsize int,
			growth int,
			status int,
	    		perf int,
			name nchar(128),
			filename nchar(260))'
	Print  @cmd
	exec  (@cmd)
	Print ''


	Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
	Print  @cmd
	exec  (@cmd)
	Print ''


	Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  select * from [' + @dbname + '].sys.sysfiles'
	Print  @cmd
	exec  (@cmd)
	Print ''


	Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles'
	Print  @cmd
	exec  (@cmd)


	Select @cmd = 'drop database [' + @dbname + ']'
	Print  @cmd
	Exec(@cmd)


	waitfor delay '00:00:05'


	--  Make sure files from the old DB have been deleted.
	delete from @DBfiles where DBAOps.dbo.dbaudf_GetFileProperty(physical_name,'file','exists') <> 'True'


	If (select count(*) from @DBfiles) > 0
	   begin
		SELECT @delete_DBfiles =
		(
		select physical_name from @DBfiles
		FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
		)


		If @delete_DBfiles is not null
		   begin
			Print 'Deleting files related to the old DB (making sure orphaned files are gone).'
			exec DBAOps.dbo.dbasp_FileHandler @delete_DBfiles
		   end
	   end


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
	   From DBAOps.dbo.' + rtrim(@dbname) + '_temp_sysfiles  f ' +
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


		waitfor delay '00:00:05'


		Delete from #fileexists
		Insert into #fileexists exec master.sys.xp_fileexist @cmd
		If (select doesexist from #fileexists) = 1
		   begin
			Select @miscprint = 'DBA ERROR: Unable to delete database files for ' + @dbname + ' (file - ' + rtrim(@cu14filename) + ').  The files for this DB must be deleted and the process restarted in the next step.'
			Print  @miscprint
			Select @error_count = @error_count + 1
			goto label99
		   end


	   End  -- loop 14
	   DEALLOCATE cu14_file


   end


--  Finalization  -------------------------------------------------------------------


label99:


drop table #fileexists
drop table #objects


If @error_count = 0
   begin
	Print ' '
	Print '-- Completed prepare for the Restore process for database: ' + Upper(@dbname)
	Print ' '
	Print ' '
   end
Else
   begin
	Print ' '
	Print '-- PROCESS FAILED: Prepare for the Restore process for database: ' + Upper(@dbname)
	Print ' '
	Print ' '
	raiserror(@miscprint,16,-1) with log
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SetStatusForRestore] TO [public]
GO
