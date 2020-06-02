SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSattach_userDBs]


/**************************************************************
 **  Stored Procedure dbasp_SYSattach_userDBs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  June 10, 2002
 **
 **  This dbasp is set up to create a script that will
 **  attach all user database files.
 **
 **  Output member is SYSattach_userDBs.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/10/2002	Steve Ledridge		Created
--	06/21/2002	Steve Ledridge		Removed bracket formatting for database name.
--	04/27/2007	Steve Ledridge		sql 2005 - added logical names and filegroup names to output.
--	09/24/2008	Steve Ledridge		Added brackets for filegroup.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@fileseed		smallint
	,@cmd			nvarchar(500)
	,@first_flag		nchar(1)
	,@save_groupid		smallint
	,@save_groupname	sysname


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId		smallint


DECLARE
	 @cu12fileid		smallint
	,@cu12name		nvarchar(128)
	,@cu12filename		nvarchar(260)
	,@cu12groupid		smallint


----------------  initial values  -------------------


--  Create table variable
declare @dbnames table
			(name		sysname
			,dbid		smallint
			)


declare @filenames table
			(fileid		smallint
			,name		sysname
			,filename	nvarchar(260)
			,groupid	smallint
			)


declare @groupname table (name		sysname)


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - SYSattach_userDBs'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '**************************************************************/'
Print  ' '


Select @cmd = 'SELECT d.name, d.dbid
   From master.sys.sysdatabases   d ' +
  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


delete from @DBnames


insert into @DBnames (name, dbid) exec (@cmd)


delete from @DBnames where name is null or name = ''
--select * from @DBnames


If (select count(*) from @DBnames) > 0
   begin
	start_dbnames:


	Select @cu11DBId = (select top 1 dbid from @DBnames order by dbid)
	Select @cu11DBName = (select name from @DBnames where dbid = @cu11DBId)


	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'Attach files for Database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
	Print  '*********************************************************/'
	Print  'Use [master] '
	Print  'go '
	Print  ' '


	Select @miscprint = 'CREATE DATABASE ' + quotename(@cu11DBName , '[')
	Print  @miscprint


	--  Now get the file names and paths
	Select @cmd = 'SELECT f.fileid, f.name, f.filename, f.groupid
	   From [' + @cu11DBName + '].sys.sysfiles f where groupid <> 0'


	delete from @filenames
	insert into @filenames (fileid, name, filename, groupid) exec (@cmd)
	delete from @filenames where name is null or name = ''
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		Select @first_flag = 'y'


		start_filenames:


		Select @cu12fileid = (select top 1 fileid from @filenames order by fileid)
		Select @cu12name = (select name from @filenames where fileid = @cu12fileid)
		Select @cu12filename = (select filename from @filenames where fileid = @cu12fileid)
		Select @cu12groupid = (select groupid from @filenames where fileid = @cu12fileid)


		If @first_flag = 'y'
		   begin
			Select @cmd = 'SELECT groupname From [' + @cu11DBName + '].sys.sysfilegroups where groupid = ' + convert(nvarchar(10), @cu12groupid)
			delete from @groupname
			insert into @groupname (name) exec (@cmd)
			delete from @groupname where name is null or name = ''
			--select * from @groupname
			Select @save_groupname = (select name from @groupname)


			Select @miscprint = 'ON ' +  @save_groupname
			Print  @miscprint
			Select @miscprint = '    (NAME = ' + @cu12name + ', FILENAME = ''' + @cu12filename + ''')'
			Print  @miscprint
			Select @save_groupid = @cu12groupid
			Select @first_flag = 'n'
		   end
		Else If @save_groupid <> @cu12groupid
		   begin
			Select @cmd = 'SELECT groupname From [' + @cu11DBName + '].sys.sysfilegroups where groupid = ' + convert(nvarchar(10), @cu12groupid)
			delete from @groupname
			insert into @groupname (name) exec (@cmd)
			delete from @groupname where name is null or name = ''
			--select * from @groupname
			Select @save_groupname = (select name from @groupname)


			Select @miscprint = ',FILEGROUP [' +  @save_groupname + ']'
			Print  @miscprint
			Select @miscprint = '    (NAME = ' + @cu12name + ', FILENAME = ''' + @cu12filename + ''')'
			Print  @miscprint
			Select @save_groupid = @cu12groupid
		   end
		Else
		   begin
			Select @miscprint = '   ,(NAME = ' + @cu12name + ', FILENAME = ''' + @cu12filename + ''')'
			Print  @miscprint
			Select @save_groupid = @cu12groupid
		   end


		--  Check for more file rows to process
		Delete from @filenames where fileid = @cu12fileid
		If (select count(*) from @filenames) > 0
		   begin
			goto start_filenames
		  end


	   end


	--  Now check to see if there are any full-text catalogs associated with this database
	Select @cmd = 'SELECT f.ftcatid, f.name, f.path
	   From [' + @cu11DBName + '].sys.sysfulltextcatalogs  f '


	delete from @filenames


	insert into @filenames (fileid, name, filename) exec (@cmd)


	delete from @filenames where name is null or name = ''
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		start_ftnames:


		Select @cu12fileid = (select top 1 fileid from @filenames order by fileid)
		Select @cu12name = (select name from @filenames where fileid = @cu12fileid)
		Select @cu12filename = (select filename from @filenames where fileid = @cu12fileid)


		Select @miscprint = '   ,(FILENAME = ''' + @cu12filename + ''') -- This is a full-text catalog file'
		Print  @miscprint


		--  Check for more ft rows to process
		Delete from @filenames where fileid = @cu12fileid
		If (select count(*) from @filenames) > 0
		   begin
			goto start_ftnames
		  end


	   end


	--  Now get the LOG file names and paths
	Select @cmd = 'SELECT f.fileid, f.name, f.filename, f.groupid
	   From [' + @cu11DBName + '].sys.sysfiles f where groupid = 0'


	delete from @filenames
	insert into @filenames (fileid, name, filename, groupid) exec (@cmd)
	delete from @filenames where name is null or name = ''
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		Select @first_flag = 'y'


		start_logfilenames:


		Select @cu12fileid = (select top 1 fileid from @filenames order by fileid)
		Select @cu12name = (select name from @filenames where fileid = @cu12fileid)
		Select @cu12filename = (select filename from @filenames where fileid = @cu12fileid)


		If @first_flag = 'y'
		   begin
			Select @miscprint = 'LOG ON'
			Print  @miscprint
			Select @miscprint = '    (NAME = ' + @cu12name + ', FILENAME = ''' + @cu12filename + ''')'
			Print  @miscprint
			Select @first_flag = 'n'
		   end
		Else
		   begin
			Select @miscprint = '   ,(NAME = ' + @cu12name + ', FILENAME = ''' + @cu12filename + ''')'
			Select @save_groupid = @cu12groupid
		   end


		--  Check for more file rows to process
		Delete from @filenames where fileid = @cu12fileid
		If (select count(*) from @filenames) > 0
		   begin
			goto start_logfilenames
		  end


	   end


	Print  'FOR ATTACH;'
	Print  'go'
	Print  ' '
	Print  ' '


	--  Check for more rows to process
	Delete from @DBnames where dbid = @cu11DBId
	If (select count(*) from @DBnames) > 0
	   begin
		goto start_dbnames
	  end


   end


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSattach_userDBs] TO [public]
GO
