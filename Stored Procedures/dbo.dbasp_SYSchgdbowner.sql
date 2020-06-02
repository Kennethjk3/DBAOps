SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSchgdbowner]


/*********************************************************
 **  Stored Procedure dbasp_SYSchgdbowner
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 4, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  change database owner
 **
 **  Output member is SYSchgdbowner.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	06/21/2002	Steve Ledridge		Removed bracket formatting for database name.
--	10/01/2002	Steve Ledridge		Removed unused declares
--	10/28/2003	Steve Ledridge		Added set user status
--	11/09/2006	Steve Ledridge		Modified for SQL 2005
--	03/09/2007	Steve Ledridge		Added quotename for non-sa owners.
--	01/02/2009	Steve Ledridge		Converted to new no_check table.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@save_sidname		sysname
	,@G_O			varchar (2)
	,@output_flag		char(1)


DECLARE
	 @cu11DBName		sysname
	,@cu11DBsid		varbinary(85)


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'
Select @save_sidname = ''


--  Create table variable
declare @dbnames table	(name		sysname
			,sid		varbinary(85))


----------------------  Main header  ----------------------


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSchgdbowner'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/
--------------------  Capture DB names  -------------------
Insert into @dbnames (name, sid)
SELECT d.name, d.owner_sid
From master.sys.databases d with (NOLOCK)
Where d.name not in ('master', 'model', 'msdb', 'tempdb')
  and d.name not in (select detail01 from dbo.no_check where NoCheck_type = 'backup')


delete from @dbnames where name is null or name = ''
--select * from @dbnames


--, master.sys.server_principals p with (NOLOCK)
If (select count(*) from @dbnames) > 0
   begin
	start_dbnames:


	Select @cu11DBName = (select top 1 name from @dbnames order by name)
	Select @cu11DBsid = (select sid from @dbnames where name = @cu11DBName)


	Select @save_sidname = ''
	Select @save_sidname = (select name from master.sys.server_principals where sid = @cu11DBsid)


	If @save_sidname = '' or @save_sidname is null
	   begin
		SELECT @save_sidname = SUSER_SNAME(@cu11DBsid)
	   end


	----------------------  Output for database owner change  ----------------------


	Print  ' '
	Print  '/****************************************************'
	Select @miscprint = 'CHANGE DATABASE OWNER for Database: ' + @cu11DBName
	Print  @miscprint
	Print  '****************************************************/'
	Select @miscprint = 'USE [master]'
	Print  @miscprint
	Print  @G_O
	Print  ' '


	If @save_sidname = 'sa'
	   begin
		Select @miscprint = 'ALTER AUTHORIZATION ON DATABASE::' + @cu11DBName + ' TO sa;'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end
	Else
	   begin
		Select @miscprint = 'If (suser_sid(''' + @save_sidname + ''')) is null'
		Print  @miscprint
		Select @miscprint = '   begin'
		Print  @miscprint
		Select @miscprint = '      ALTER AUTHORIZATION ON DATABASE::' + @cu11DBName + ' TO sa;'
		Print  @miscprint
		Select @miscprint = '   end'
		Print  @miscprint
		Select @miscprint = 'Else'
		Print  @miscprint
		Select @miscprint = '   begin'
		Print  @miscprint
		Select @miscprint = '      ALTER AUTHORIZATION ON DATABASE::' + @cu11DBName + ' TO ' + QUOTENAME(@save_sidname) + ';'
		Print  @miscprint
		Select @miscprint = '   end'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end


	Select @output_flag	= 'y'


	--  Remove this record from @dbnames and go to the next
	delete from @dbnames where name = @cu11DBName
	If (select count(*) from @dbnames) > 0
	   begin
		goto start_dbnames
	   end


   end


---------------------------  Finalization  -----------------------


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSchgdbowner] TO [public]
GO
