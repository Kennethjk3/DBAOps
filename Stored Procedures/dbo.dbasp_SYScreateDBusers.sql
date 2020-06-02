SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYScreateDBusers]


/*********************************************************
 **  Stored Procedure dbasp_SYScreateDBusers
 **  Written by Steve Ledridge, Virtuoso
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  grant database access
 **
 **  Output member is SYScreateDBusers.gsql
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
--	11/09/2006	Steve Ledridge		Modified for SQL 2005
--	08/07/2015	Steve Ledridge		Skip users with authentication_type = 0
--	08/27/2015	Steve Ledridge		Removed code for authentication_type.
--	06/28/2016	Steve Ledridge		Skip z_snap DB's.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(255)
	,@G_O				nvarchar(2)
	,@output_flag			char(1)
	,@output_flag2			char(1)


DECLARE
	 @cu11DBName			sysname
	,@cu11DBId			smallint


DECLARE
	 @cu22name			sysname
	,@cu22type			sysname
	,@cu22default_schema_name	sysname


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
Select @miscprint = 'Generated SQL - SYScreateDBusers'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
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


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'Create Database Users'
   Print  @miscprint
   Print  '***********************************************/'
   Print  ' '


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
   Print  '/****************************************************'
   Select @miscprint = 'Create Users for Database: ' + @cu11DBName
   Print  @miscprint
   Print  '****************************************************/'
   Select @miscprint = 'USE [' + @cu11DBName + ']'
   Print  @miscprint
   Print  @G_O
   Print  ' '


--------------------  Cursor for 22DB  -----------------------


EXECUTE('DECLARE cu22_DBAccess Insensitive Cursor For ' +
  'SELECT dp.name, dp.type, dp.default_schema_name
   From [' + @cu11DBName + '].sys.database_principals  dp ' +
  'Where dp.type <> ''R''
     and dp.principal_id > 4
   Order By dp.type, dp.name For Read Only')


OPEN cu22_DBAccess


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBAccess Into @cu22name, @cu22type, @cu22default_schema_name
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_DBAccess
	      BREAK
           end


	If @cu22default_schema_name is null or @cu22default_schema_name = 'dbo'
	   begin
		Select @miscprint = 'CREATE USER [' + @cu22name + '];'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end
	Else
	   begin
		Select @miscprint = 'CREATE USER [' + @cu22name + '] WITH DEFAULT_SCHEMA = ' + @cu22default_schema_name + ';'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end


	--  This code will fix the schema ownership for users that may have been previously removed from the database
	Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.schemas where name = ''' + @cu22name + ''' and principal_id = 1)'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '      ALTER AUTHORIZATION ON SCHEMA::[' + @cu22name + '] TO [' + @cu22name + '];'
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  @G_O
	Print  ' '
	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 22
   DEALLOCATE cu22_DBAccess


skipDB_01:


If @output_flag = 'n'
   begin
	Select @miscprint = '-- No output for database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
   end
Else
   begin
	Select @output_flag = 'n'
	Print  ' '
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
GRANT EXECUTE ON  [dbo].[dbasp_SYScreateDBusers] TO [public]
GO
