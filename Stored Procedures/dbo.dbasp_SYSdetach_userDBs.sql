SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSdetach_userDBs]


/**************************************************************
 **  Stored Procedure dbasp_SYSdetach_userDBs
 **  Written by Steve Ledridge, Virtuoso
 **  June 10, 2002
 **
 **  This dbasp is set up to create a script that will
 **  detach all user databases.
 **
 **  Output member is SYSdetach_userDBs.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/10/2002	Steve Ledridge		Created
--	06/21/2002	Steve Ledridge		Removed bracket formatting for database name.
--	02/21/2006	Steve Ledridge		Modified for sql 2005
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@cmd			nvarchar(500)


DECLARE
	 @cu11DBName	sysname
	,@cu11DBId		smallint


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
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - SYSdetach_userDBs'
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
	Select @miscprint = 'detach files for Database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
	Print  '*********************************************************/'
	Print  ' '
	Print  'Use [master]'
	Print  'go'
	Print  ' '


	--  Now check to see if there are any full-text catalogs associated with this database
	Select @cmd = 'SELECT f.ftcatid, f.name, f.path
	   From [' + @cu11DBName + '].sys.sysfulltextcatalogs  f '


	delete from @filenames


	insert into @filenames (fileid, name, filename) exec (@cmd)


	delete from @filenames where name is null or name = ''
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		Select @miscprint = 'exec sp_detach_db @dbname = ''' + rtrim(@cu11DBName) + ''', @skipchecks = ''true'', @KeepFulltextIndexFile = ''true'';'
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'exec sp_detach_db @dbname = ''' + rtrim(@cu11DBName) + ''', @skipchecks = ''true'';'
		Print  @miscprint
	   end


	Print  'go '
	Print  ' '
	Print  ' '


	--  Check for more rows to process
	Delete from @DBnames where dbid = @cu11DBId
	If (select count(*) from @DBnames) > 0
	   begin
		goto start_dbnames
	  end


   end


---------------------------  Finalization -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSdetach_userDBs] TO [public]
GO
