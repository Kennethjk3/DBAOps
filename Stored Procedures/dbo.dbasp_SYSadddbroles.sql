SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSadddbroles]


/***************************************************************
 **  Stored Procedure dbasp_SYSadddbroles
 **  Written by Steve Ledridge, Virtuoso
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add database roles
 **
 **  Output member is SYSadddbroles.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/30/2002	Steve Ledridge		Added brackets around dbname variable in select stmts.
--	06/11/2002	Steve Ledridge		Added brackets around DB name in use stmt.
--	05/22/2006	Steve Ledridge		Updated for SQL 2005.
--	03/05/2008	Steve Ledridge		Modified sysuser cursor - added uid > 16399.
--	06/28/2016	Steve Ledridge		Skip z_snap DB's.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@output_flag01		char(1)
	,@output_flag02		char(1)
	,@save_altname		sysname
	,@save_schemaname	sysname
	,@cmd			nvarchar(500)


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId		smallint


DECLARE
	 @cu22Uname		nvarchar(128)
	,@cu22Ualtuid		smallint
	,@cu22Uissqlrole	int
	,@cu22Uisapprole	int


----------------  initial values  -------------------
Select
	 @G_O		= 'g' + 'o'
	,@output_flag01	= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - SYSadddbroles'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '**************************************************************/'
Print  ' '
Print  ' '


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name, d.dbid
   From master.sys.sysdatabases   d ' +
  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')
   Order By d.dbid For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------
   Print  '/***********************************************'
   Select @miscprint = 'Add Database Roles for server: ' + @@servername
   Print  @miscprint
   Print  '***********************************************/'
   Print  ' '
   Select @output_flag02 = 'n'


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName, @cu11DBId
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


If @cu11DBName like 'z_snap%'
   begin
	goto skipDB_01
   end


----------------------  Print the headers  ----------------------
   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'Add Roles for Database: ' + @cu11DBName
   Print  @miscprint
   Print  '***********************************************/'
   Select @miscprint = 'USE [' + @cu11DBName + '];'
   Print  @miscprint
   Print  @G_O
   Print  ' '


--------------------  Cursor for 22DB  -----------------------
EXECUTE('DECLARE cu22_DBRole Insensitive Cursor For ' +
  'SELECT u.name, u.altuid, u.issqlrole, u.isapprole
   From [' + @cu11DBName + '].sys.sysusers  u ' +
  'Where (u.issqlrole = 1 or u.isapprole = 1)
	 and (u.uid < 16380 or u.uid > 16399)
	 and u.name <> ''public''
   Order By u.uid For Read Only')


OPEN cu22_DBRole


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBRole Into @cu22Uname, @cu22Ualtuid, @cu22Uissqlrole, @cu22Uisapprole
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_DBRole
	      BREAK
           end


	If @cu22Uissqlrole = 1
	   begin


		Select @cmd = 'USE ' + quotename(@cu11DBName)
				+ ' SELECT @save_altname = (select name from sys.sysusers where uid = ' + convert(varchar(10), @cu22Ualtuid) + ')'
		--Print @cmd


		EXEC sp_executesql @cmd, N'@save_altname sysname output', @save_altname output
		--print @save_altname


		Select @miscprint = 'CREATE ROLE [' + @cu22Uname + '] AUTHORIZATION [' + @save_altname + '];'
		Print  @miscprint
		Print  @G_O
		Print  ' '
		goto end_01
	   end


	If @cu22Uisapprole = 1
	   begin
		Select @cmd = 'USE ' + quotename(@cu11DBName)
				+ ' SELECT @save_schemaname = (select default_schema_name from sys.database_principals where name = ''' + @cu22Uname + ''')'
		--Print @cmd


		EXEC sp_executesql @cmd, N'@save_schemaname sysname output', @save_schemaname output
		--print @save_schemaname


		Select @miscprint = '/* CREATE APPLICATION ROLE ---------------------------------------------  */'
		Print  @miscprint
		Select @miscprint = '/* To avoid disclosure of passwords, the password is generated in script. */'
		Print  @miscprint
		Select @miscprint = 'declare @idx as int'
		Print  @miscprint
		Select @miscprint = 'declare @randomPwd as nvarchar(64)'
		Print  @miscprint
		Select @miscprint = 'declare @rnd as float'
		Print  @miscprint
		Select @miscprint = 'declare @cmd nvarchar(4000)'
		Print  @miscprint
		Select @miscprint = 'select @idx = 0'
		Print  @miscprint
		Select @miscprint = 'select @randomPwd = N'''
		Print  @miscprint
		Select @miscprint = 'select @rnd = rand((@@CPU_BUSY % 100) + ((@@IDLE % 100) * 100) +'
		Print  @miscprint
		Select @miscprint = '       (DATEPART(ss, GETDATE()) * 10000) + ((cast(DATEPART(ms, GETDATE()) as int) % 100) * 1000000))'
		Print  @miscprint
		Select @miscprint = 'while @idx < 64'
		Print  @miscprint
		Select @miscprint = 'begin'
		Print  @miscprint
		Select @miscprint = '   select @randomPwd = @randomPwd + char((cast((@rnd * 83) as int) + 43))'
		Print  @miscprint
		Select @miscprint = '   select @idx = @idx + 1'
		Print  @miscprint
		Select @miscprint = '   select @rnd = rand()'
		Print  @miscprint
		Select @miscprint = 'end'
		Print  @miscprint
		Select @miscprint = 'select @cmd = N''CREATE APPLICATION ROLE [' + @cu22Uname + '] WITH DEFAULT_SCHEMA = [' + @save_schemaname + '], '' + N''PASSWORD = N'' + QUOTENAME(@randomPwd,'''''''')'
		Print  @miscprint
		Select @miscprint = 'EXEC dbo.sp_executesql @cmd'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end


	end_01:


	Select @output_flag02 = 'y'


   End  -- loop 22
   DEALLOCATE cu22_DBRole


skipDB_01:


If @output_flag02 = 'n'
   begin
	Select @miscprint = '-- No output for database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
   end


Select @output_flag01 = 'y'
Select @output_flag02 = 'n'


 End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cu11_DBNames


If @output_flag01 = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSadddbroles] TO [public]
GO
