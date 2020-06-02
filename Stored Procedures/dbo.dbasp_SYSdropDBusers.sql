SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSdropDBusers]


/*********************************************************
 **  Stored Procedure dbasp_SYSdropDBusers
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 11, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  revoke database access
 **
 **  Output member is SYSdropDBusers.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/30/2002	Steve Ledridge		Added brackets around dbname variable in select stmts.
--	05/06/2002	Steve Ledridge		Changed dbname type to sysname.
--	06/11/2002	Steve Ledridge		Added brackets around DB name in use stmt.
--	08/27/2002	Steve Ledridge		Added code for deleting all users.
--	10/11/2002	Steve Ledridge		Changed code for deleting all users - now
--						referencing the 'islogin' field.
--	04/14/2003	Steve Ledridge		Added code for cleaning up permissions and objects owners
--	11/10/2006	Steve Ledridge		Modified for SQL 2005.
--	08/07/2015	Steve Ledridge		Skip users with authentication_type = 0.
--	08/27/2015	Steve Ledridge		Removed code for authentication_type.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@filegrowth		nvarchar(20)
	,@output_flag		char(1)
	,@output_flag2		char(1)


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId		smallint
	,@cu11DBStatus		int


DECLARE
	 @cu22name		sysname
	,@cu22type		sysname
	,@cu22principal_id	int


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'
Select @output_flag2	= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSdropDBusers'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  ' '
Select @miscprint = 'Drop Database Users'
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name, d.database_id
   From master.sys.databases   d ' +
  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')
   Order By d.name For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName, @cu11DBId
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


----------------------  Print the headers  ----------------------
   Print  ' '
   Print  '/****************************************************'
   Select @miscprint = 'Drop Users for Database: ' + @cu11DBName
   Print  @miscprint
   Print  '****************************************************/'
   Select @miscprint = 'USE [' + @cu11DBName + ']'
   Print  @miscprint
   Print  @G_O
   Print  ' '


--------------------  Cursor for 22DB  -----------------------


EXECUTE('DECLARE cu22_DBAccess Insensitive Cursor For ' +
  'SELECT dp.name, dp.type, dp.principal_id
   From [' + @cu11DBName + '].sys.database_principals  dp ' +
  'Where dp.type <> ''R''
     and dp.principal_id > 4
   Order By dp.type, dp.name For Read Only')


OPEN cu22_DBAccess


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBAccess Into @cu22name, @cu22type, @cu22principal_id
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_DBAccess
	      BREAK
           end


	Select @miscprint = '--  DROP User ' + @cu22name + '  --------------------------------------------------------------------'
	Print  @miscprint
	Select @miscprint = 'If exists (select 1 from ' + @cu11DBName + '.sys.schemas  s, ' + @cu11DBName + '.sys.database_principals  dp'
	Print  @miscprint
	Select @miscprint = '                    where dp.name = ''' + @cu22name + ''' and s.principal_id = dp.principal_id)'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '      Declare @save_sname sysname'
	Print  @miscprint
	Select @miscprint = '      Declare @cmd nvarchar(500)'
	Print  @miscprint
	Select @miscprint = '      drop_user01:'
	Print  @miscprint
	Select @miscprint = '      Select @save_sname = (select top 1 s.name from ' + @cu11DBName + '.sys.schemas  s, ' + @cu11DBName + '.sys.database_principals  dp'
	Print  @miscprint
	Select @miscprint = '                                              where dp.name = ''' + @cu22name + ''' and s.principal_id = dp.principal_id)'
	Print  @miscprint
	Select @miscprint = '      Select @cmd = ''ALTER AUTHORIZATION ON SCHEMA::['' + @save_sname + ''] TO dbo;'''
	Print  @miscprint
	Select @miscprint = '      Print @cmd'
	Print  @miscprint
	Select @miscprint = '      Exec (@cmd)'
	Print  @miscprint
	Select @miscprint = '      If exists (select 1 from ' + @cu11DBName + '.sys.schemas  s, ' + @cu11DBName + '.sys.database_principals  dp'
	Print  @miscprint
	Select @miscprint = '                          where dp.name = ''' + @cu22name + ''' and s.principal_id = dp.principal_id)'
	Print  @miscprint
	Select @miscprint = '         begin'
	Print  @miscprint
	Select @miscprint = '            goto drop_user01'
	Print  @miscprint
	Select @miscprint = '         end'
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'Print ''Drop User [' + @cu22name + ']'''
	Print  @miscprint
	Select @miscprint = 'drop user [' + @cu22name + '];'
	Print  @miscprint
	Print  @G_O
	Print  ' '
	Print  ' '


   End  -- loop 22
   DEALLOCATE cu22_DBAccess


	Select @miscprint = '---------------------------------------------------------------------------------------------------------------------------'
	Print  @miscprint
	Select @miscprint = '--  Use the Following code to DROP all Users from ''' + @cu11DBName + ''''
	Print  @miscprint
	Select @miscprint = '---------------------------------------------------------------------------------------------------------------------------'
	Print  @miscprint
	Select @miscprint = 'If exists (select 1 from ' + @cu11DBName + '.sys.schemas where principal_id > 4 and principal_id < 16384)'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '      Declare @save_sname sysname'
	Print  @miscprint
	Select @miscprint = '      Declare @cmd nvarchar(500)'
	Print  @miscprint
	Select @miscprint = '      drop_user02:'
	Print  @miscprint
	Select @miscprint = '      Select @save_sname = (select top 1 name from ' + @cu11DBName + '.sys.schemas where principal_id > 4 and principal_id < 16384)'
	Print  @miscprint
	Select @miscprint = '      Select @cmd = ''ALTER AUTHORIZATION ON SCHEMA::['' + @save_sname + ''] TO dbo;'''
	Print  @miscprint
	Select @miscprint = '      Print @cmd'
	Print  @miscprint
	Select @miscprint = '      Exec (@cmd)'
	Print  @miscprint
	Select @miscprint = '      If exists (select 1 from ' + @cu11DBName + '.sys.schemas where principal_id > 4 and principal_id < 16384)'
	Print  @miscprint
	Select @miscprint = '         begin'
	Print  @miscprint
	Select @miscprint = '            goto drop_user02'
	Print  @miscprint
	Select @miscprint = '         end'
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  @G_O
	Print  ' '


	Select @miscprint = 'If exists (select 1 from ' + @cu11DBName + '.sys.database_principals where principal_id > 4 and type <> ''R'')'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '      Declare @save_uname sysname'
	Print  @miscprint
	Select @miscprint = '      Declare @cmd nvarchar(500)'
	Print  @miscprint
	Select @miscprint = '      drop_user03:'
	Print  @miscprint
	Select @miscprint = '      Select @save_uname = (select top 1 name from ' + @cu11DBName + '.sys.database_principals where principal_id > 4 and type <> ''R'')'
	Print  @miscprint
	Select @miscprint = '      Select @cmd = ''DROP USER ['' + @save_uname + ''];'''
	Print  @miscprint
	Select @miscprint = '      Print @cmd'
	Print  @miscprint
	Select @miscprint = '      Exec (@cmd)'
	Print  @miscprint
	Select @miscprint = '      If exists (select 1 from ' + @cu11DBName + '.sys.database_principals where principal_id > 4 and type <> ''R'')'
	Print  @miscprint
	Select @miscprint = '         begin'
	Print  @miscprint
	Select @miscprint = '            goto drop_user03'
	Print  @miscprint
	Select @miscprint = '         end'
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  ' '
	Print  ' '


Select @output_flag2 = 'y'


 End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cu11_DBNames


If @output_flag2 = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSdropDBusers] TO [public]
GO
