SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSaddsysdbrolemembers]


/*********************************************************
 **  Stored Procedure dbasp_SYSaddsysdbrolemembers
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 16, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add system database role member
 **
 **  Output member is SYSaddsysdbrolemembers.gsql
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
--	05/23/2006	Steve Ledridge		Updated for SQL 2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(255)
	,@G_O				nvarchar(2)
	,@filegrowth		nvarchar(20)
	,@saverolename		sysname
	,@output_flag		char(1)
	,@output_flag2		char(1)


DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu22Urole			sysname
	,@cu22Uname			sysname


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @saverolename	= ''
Select @output_flag	= 'n'
Select @output_flag2	= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSaddsysdbrolemembers'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.sysdatabases   d ' +
  'Where d.name in (''master'', ''model'', ''msdb'', ''tempdb'')
   Order By d.dbid For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/*******************************************************************'
   Select @miscprint = 'Add System Database Role Members for server: ' + @@servername
   Print  @miscprint
   Print  '*******************************************************************/'
   Print  ' '


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'Add Role Members for Database: ' + @cu11DBName
   Print  @miscprint
   Print  '***********************************************/'
   Select @miscprint = 'USE [' + @cu11DBName + ']'
   Print  @miscprint
   Print  @G_O
   Print  ' '


--------------------  Cursor for 22DB  -----------------------


EXECUTE('DECLARE cu22_DBRole Insensitive Cursor For ' +
  'SELECT r.name, u.name
   From [' + @cu11DBName + '].sys.sysusers  u, [' + @cu11DBName + '].sys.sysusers  r, [' + @cu11DBName + '].sys.sysmembers  m ' +
  'Where u.uid > 3
     and u.uid = m.memberuid
     and m.groupuid = r.uid
   Order By r.name, u.uid For Read Only')


OPEN cu22_DBRole


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBRole Into @cu22Urole, @cu22Uname
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_DBRole
	      BREAK
           end


	IF @cu22Urole <> @saverolename
	   begin
		Print ''
		Select @miscprint = '/*****  Add for Role ''' + @cu22Urole + '''  *****/'
		Print  @miscprint
		Print ''
		Select @saverolename = @cu22Urole
	   end

	Select @miscprint = 'sp_addrolemember ''' + @cu22Urole + ''', '''  + @cu22Uname + ''''
	Print  @miscprint
	Print  @G_O
	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 22
   DEALLOCATE cu22_DBRole


If @output_flag = 'n'
   begin
	Select @miscprint = '-- No output for database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
   end
Else
   begin
	Select @output_flag = 'n'
   end


Select @output_flag2 = 'y'


 End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cu11_DBNames


If @output_flag2 = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddsysdbrolemembers] TO [public]
GO
