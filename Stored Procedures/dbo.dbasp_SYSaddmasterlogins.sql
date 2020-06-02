SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSaddmasterlogins]


/**************************************************************
 **  Stored Procedure dbasp_SYSaddmasterlogins
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add logins
 **
 **  Output member is SYSaddmasterlogins.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	10/22/2002	Steve Ledridge		Now using isntgroup and isntuser
--	03/20/2006	Steve Ledridge		Modified for SQL 2005.
--	11/08/2006	Steve Ledridge		Added code for trusted logins.
--	04/16/2008	Steve Ledridge		Added check expiration and check policy.
--	06/06/2013	Steve Ledridge		Longer password for sql 2012.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(2000)
	,@G_O			nvarchar(2)
	,@DFLTdatabase		nvarchar(30)
	,@VCHARpassword		nvarchar(500)
	,@VCHARsid		nvarchar(128)
	,@pwlen			int
	,@pwpos			int
	,@i			int
	,@length		int
	,@binvalue		varbinary(256)
	,@hexstring		nchar(16)
	,@savename		sysname
	,@output_flag		char(1)
	,@tempint		int
	,@firstint		int
	,@secondint		int

DECLARE
	 @cu11Lname		sysname
	,@cu11Lpassword		sysname
	,@cu11Lsid		varbinary(85)
	,@cu11Lstatus		smallint
	,@cu11Ldbname		sysname
	,@cu11Llanguage		sysname
	,@cu11isntgroup		int
	,@cu11isntuser		int


DECLARE
	 @cu12Lname		sysname
	,@cu12Lpassword		sysname
	,@cu12Lsid		varbinary(85)
	,@cu12Lstatus		smallint
	,@cu12Ldbname		sysname
	,@cu12Llanguage		sysname
	,@cu12isntgroup		int
	,@cu12isntuser		int


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @savename 	= ' '
Select @output_flag	= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/*****************************************************************************'
Select @miscprint = 'Generated SQL - SYSaddmasterlogins'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '*****************************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/

----------------------  Print the headers  ----------------------
Print  '/***********************************************'
Select @miscprint = 'ADD SQL LOGINS for master '
Print  @miscprint
Print  '***********************************************/'
Print  ' '
Select @miscprint = 'USE master'
Print  @miscprint
Print  @G_O
Print  ' '


--------------------  Cursor 11  -----------------------


EXECUTE('DECLARE cursor_11 Insensitive Cursor For ' +
  'SELECT y.name, y.password, y.sid, y.status, y.dbname, y.language, y.isntgroup, y.isntuser
   From  master.sys.syslogins  y ' +
  'Where y.hasaccess = 1
     And y.name not in (''probe'',''sa'',''repl_publisher'',''repl_subscriber'')
     And y.name not like ''##%''
     And y.name not like ''%BUILTIN\Administrators%''
     And y.name not like ''%AUTHORITY\SYSTEM%''
     And y.name not like ''%MSSQLSERVER%''
     And y.isntgroup = 0
     And y.isntuser = 0
   Order By y.name For Read Only')


-------------------- start cursor processing  -----------------------


OPEN cursor_11


WHILE (11=11)
   Begin
	FETCH Next From cursor_11 Into @cu11Lname, @cu11Lpassword, @cu11Lsid, @cu11Lstatus, @cu11Ldbname, @cu11Llanguage, @cu11isntgroup, @cu11isntuser
		IF (@@fetch_status < 0)
		   begin
			CLOSE cursor_11
			BREAK
		   end


--------------------  convert the password to unicode values  -----------------------
--print @cu11Lpassword
select @pwlen = len(@cu11Lpassword)
Select @pwpos = 1
Select @VCHARpassword = ''


If @pwpos <= @pwlen
   begin
	start_pw_revision:


	Select @VCHARpassword = @VCHARpassword + 'nchar(' + convert(varchar(10), unicode(Substring(@cu11Lpassword,@pwpos,1))) + ')+'


	Select @pwpos = @pwpos + 1


	If @pwpos <= @pwlen
	   begin
		goto start_pw_revision
	   end
   end


--------------------  convert the sid from varbinary to varchar  -----------------------
select @VCHARsid = '0x'
select @i = 1
select @binvalue = @cu11Lsid
select @length = datalength(@binvalue)
select @hexstring = '0123456789ABCDEF'


while (@i <= @length)
   begin
	select @tempint = convert(int, substring(@binvalue,@i,1))
	select @firstint = floor(@tempint/16)
	select @secondint = @tempint - (@firstint*16)

	select @VCHARsid = @VCHARsid + substring(@hexstring, @firstint+1, 1) + substring(@hexstring, @secondint+1, 1)
	select @i = @i + 1
   end


--------------------  set the default database  -----------------------


	SELECT @DFLTdatabase = @cu11Ldbname


--------------------  Format the output  -----------------------
	If @cu11Lname <> @savename
	   begin
		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint
		Select @miscprint = '-- Create login ''' + @cu11Lname + ''''
		Print  @miscprint
		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint


		--  If this is being run on a sql2005 server, add logic to make sure the result script is used on a sql2005 server.
		If ( 0 <> ( SELECT PATINDEX( '%[9].[00]%', @@version ) ) )
		   begin
			Select @miscprint = 'If ( 0 = ( SELECT PATINDEX( ''%[9].[00]%'', @@version ) ) )'
			Print  @miscprint
			Select @miscprint = '   Begin'
			Print  @miscprint
			Select @miscprint = '      Print ''ERROR:  Unable to create login ''''' + @cu11Lname + ''''' to this server.  This login was scripted from a SQL 9.00 environment.'''
			Print  @miscprint
			Select @miscprint = '   End'
			Print  @miscprint
			Select @miscprint = 'Else'
			Print  @miscprint
		   end


		Select @miscprint = 'If not exists (select * from master.sys.syslogins where name = N''' + @cu11Lname + ''')'
		Print  @miscprint
		Select @miscprint = '   Begin'
		Print  @miscprint
		Select @miscprint = '      Declare @cmd nvarchar(3000)'
		Print  @miscprint
		Select @miscprint = '      '
		Print  @miscprint
		Select @miscprint = '      select @cmd = ''CREATE LOGIN ' + @cu11Lname
		Print  @miscprint


		Select @miscprint = '             WITH PASSWORD = ''''''+'


		Select @miscprint = @miscprint + @VCHARpassword


		Select @miscprint = @miscprint + ''''''' HASHED'
		Print  @miscprint


		Select @miscprint = '                                 ,DEFAULT_DATABASE = [' + @DFLTdatabase + ']'
		Print  @miscprint


		IF @cu11Llanguage is not null
		   begin
			Select @miscprint = '                                 ,DEFAULT_LANGUAGE = ' + @cu11Llanguage
			Print  @miscprint
		   end


		If (select is_policy_checked from master.sys.sql_logins where name = @cu11Lname) = 1
		   begin
			Select @miscprint = '                                 ,CHECK_POLICY = ON'
			Print  @miscprint
		   end
		Else
		   begin
			Select @miscprint = '                                 ,CHECK_POLICY = OFF'
			Print  @miscprint
		   end


		If (select is_expiration_checked from master.sys.sql_logins where name = @cu11Lname) = 1
		   begin
			Select @miscprint = '           ,CHECK_EXPIRATION = ON'
			Print  @miscprint
		   end
		Else
		   begin
			Select @miscprint = '                                 ,CHECK_EXPIRATION = OFF'
			Print  @miscprint
		   end


		Select @miscprint = '                                 ,SID = ' + @VCHARsid + ''''
		Print  @miscprint
		Select @miscprint = '        Print @cmd'
		Print  @miscprint
		Select @miscprint = '        Exec (@cmd)'
		Print  @miscprint
		Select @miscprint = '   End'
		Print  @miscprint
		Select @miscprint = 'Else'
		Print  @miscprint
		Select @miscprint = '   Begin'
		Print  @miscprint
		Select @miscprint = '      Print ''Note:  Login ''''' + @cu11Lname + ''''' already exists on this server.'''
		Print  @miscprint
		Select @miscprint = '   End'
		Print  @miscprint
		Print  @G_O
		Print  ' '
	   end


	select @savename = @cu11Lname


	Select @output_flag	= 'y'


   End  -- loop 11
   DEALLOCATE cursor_11


----------------------  Print the headers  ----------------------
Print  ' '
Print  ' '
Print  ' '
Print  '/***********************************************'
Select @miscprint = 'ADD NT LOGINS for master '
Print  @miscprint
Print  '***********************************************/'
Print  ' '
Select @miscprint = 'USE master'
Print  @miscprint
Print  @G_O
Print  ' '


--------------------  Cursor 12  -----------------------


EXECUTE('DECLARE cursor_12 Insensitive Cursor For ' +
  'SELECT y.name, y.password, y.sid, y.status, y.dbname, y.language, y.isntgroup, y.isntuser
   From  master.sys.syslogins  y ' +
  'Where y.hasaccess = 1
     And y.name not in (''probe'',''sa'',''repl_publisher'',''repl_subscriber'')
     And y.name not like ''##%''
     And y.name not like ''%BUILTIN\Administrators%''
     And y.name not like ''%AUTHORITY\SYSTEM%''
     And y.name not like ''%MSSQLSERVER%''
     And (y.isntgroup <> 0 or y.isntuser <> 0)
   Order By y.name For Read Only')


--------------------  start cursor processing  -----------------------


OPEN cursor_12


WHILE (12=12)
   Begin
	FETCH Next From cursor_12 Into @cu12Lname, @cu12Lpassword, @cu12Lsid, @cu12Lstatus, @cu12Ldbname, @cu12Llanguage, @cu12isntgroup, @cu12isntuser
		IF (@@fetch_status < 0)
		   begin
			CLOSE cursor_12
			BREAK
		   end


--------------------  set the default database  -----------------------


	SELECT @DFLTdatabase = @cu12Ldbname


--------------------  Format the output  -----------------------
	If @cu12Lname <> @savename
	   begin
		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint
		Select @miscprint = '-- Create login ''' + @cu12Lname + ''''
		Print  @miscprint
		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint


		--  If this is being run on a sql2005 server, add logic to make sure the result script is used on a sql2005 server.
		If ( 0 <> ( SELECT PATINDEX( '%[9].[00]%', @@version ) ) )
		   begin
			Select @miscprint = 'If ( 0 = ( SELECT PATINDEX( ''%[9].[00]%'', @@version ) ) )'
			Print  @miscprint
			Select @miscprint = '   Begin'
			Print  @miscprint
			Select @miscprint = '      Print ''ERROR:  Unable to create login ''''' + @cu12Lname + ''''' to this server.  This login was scripted from a SQL 9.00 environment.'''
			Print  @miscprint
			Select @miscprint = '   End'
			Print  @miscprint
			Select @miscprint = 'Else'
			Print  @miscprint
		   end


		If @cu12isntgroup <> 0 or @cu12isntuser <> 0
		   begin
			Select @miscprint = 'If not exists (select * from master.sys.syslogins where name = N''' + @cu12Lname + ''')'
			Print  @miscprint
			Select @miscprint = '   Begin'
			Print  @miscprint
			Select @miscprint = '      Print ''Add NT Login ''''' + @cu12Lname + ''''''''
			Print  @miscprint
			Select @miscprint = '      CREATE LOGIN [' + @cu12Lname + '] FROM WINDOWS'
			Print  @miscprint
			Select @miscprint = '             WITH DEFAULT_DATABASE = [' + @DFLTdatabase + ']'
			Print  @miscprint
			IF @cu12Llanguage is not null
			   begin
				Select @miscprint = '                 ,DEFAULT_LANGUAGE = ' + @cu12Llanguage
				Print  @miscprint
			   end


			Select @miscprint = '   End'
			Print  @miscprint
			Select @miscprint = 'Else'
			Print  @miscprint
			Select @miscprint = '   Begin'
			Print  @miscprint
			Select @miscprint = '      Print ''Note:  Login ''''' + @cu12Lname + ''''' already exists on this server.'''
			Print  @miscprint
			Select @miscprint = '   End'
			Print  @miscprint
			Print  @G_O
			Print  ' '
		   end
	   end


	select @savename = @cu12Lname


	Select @output_flag	= 'y'


   End  -- loop 12
   DEALLOCATE cursor_12


---------------------------  Finalization  -----------------------


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddmasterlogins] TO [public]
GO
