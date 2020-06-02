SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSrestoreBYsingledb] (@dbname sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_SYSrestoreBYsingledb
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 01, 2002
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Perform a full Restore of a user database
 **  using a full set of scripts
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/01/2002	Steve Ledridge		New process
--	04/17/2003	Steve Ledridge		Changes for new instance share names.
--	04/18/2003	Steve Ledridge		Modified revoke db access section.
--	10/16/2003	Steve Ledridge		Added identity column to output temp table to
--								force order.
--	10/28/2003	Steve Ledridge		Added set user status
--	06/22/2004	Steve Ledridge		Added code for set user status
--	07/20/2005	Steve Ledridge		Added code for change object owner
--	09/21/2005	Steve Ledridge		System objects will now be excluded from the
--								change object owner process
--	10/02/2005	Steve Ledridge		Added brackets for DBname in change object owner section
--	04/26/2006	Steve Ledridge		In sysmessages, changed double quotes to single quotes
--	11/07/2006	Steve Ledridge		Added code for LiteSpeed processing and mutilple backup files.
--	11/15/2006	Steve Ledridge		Re-created for SQL 2005.
--	11/27/2006	Steve Ledridge		Fixed double quotes in drop user section.  Added ^ for echo > and <.
--	12/21/2006	Steve Ledridge		Converted this to a 2 sproc process.  This sproc will now be
--								run for only a single DB at a time.
--	03/09/2007	Steve Ledridge		Added quotename to change db owner section.
--	07/25/2007	Steve Ledridge		Added RedGate processing.
--	08/23/2007	Steve Ledridge		Added Report Services processing for key extraction and adding.
--	03/12/2008	Steve Ledridge		Added sections for master and msdb access and permissions.
--	04/16/2008	Steve Ledridge		Added check expiration and check policy.
--	05/08/2008	Steve Ledridge		Added code to drop unused schemas.
--	05/16/2008	Steve Ledridge		Fixed syntax in drop user section (added brackets and 'go').
--	06/20/2008	Steve Ledridge		Added code for assemblies (alter authorization).
--	07/21/2008	Steve Ledridge		Fix for DBroles section.
--	09/23/2008	Steve Ledridge		Removed Report Services processing for key extraction.
--	07/16/2009	Steve Ledridge		Added bracketsd for dbname in sections 16 and 17.
--	12/07/2010	Steve Ledridge		Added code to suport Backup by filegroup processing.
--	07/18/2011	Steve Ledridge		Modified the population of #Backupinfo to filter out physical
--						devices that look like GUID's
--	10/17/2011	Steve Ledridge		Changed all use of smallint to Int to prevent overflow failures
--	10/17/2011	Steve Ledridge		subquery used max as set in update which is not allowed, changed
--						to use top 1 ordered by colid desc.
--	04/05/2012	Steve Ledridge		New code for enable_broker
--	11/20/2013	Steve Ledridge		Convert the restore to use dbasp_format_BackupRestore.
--	08/07/2015	Steve Ledridge		Skip users with authentication_type = 0.
--	08/27/2015	Steve Ledridge		Removed code for authentication_type.
--	======================================================================================


/***
Declare @dbname sysname


Select @dbname = 'DBAOps'
--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(1000)
	,@cmd			nvarchar(1000)
	,@G_O			nvarchar(2)
	,@rs_flag		char(1)
	,@charpos		int
	,@output_flag		char(1)
	,@output_flag2		char(1)
	,@out_file_name		nvarchar(500)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_instname		sysname
	,@syntax_out		varchar(max)


DECLARE
	 @DFLTdatabase		nvarchar   (30)
	,@VCHARpassword		nvarchar  (500)
	,@VCHARsid		nvarchar  (128)
	,@pwlen			int
	,@pwpos			int
	,@i			int
	,@length		int
	,@binvalue		varbinary(256)
	,@hexstring		nchar      (16)
	,@savename		sysname
	,@tempint		int
	,@firstint		int
	,@secondint		int
	,@startpos		int
	,@save_log		nvarchar(10)
	,@save_sidname		sysname
	,@optvalue		nvarchar(5)
	,@CommentThisDBOption	char(1)
	,@recovery_flag		char(1)
	,@restrict_flag		char(1)
	,@fulloptname		sysname
	,@alt_optname		sysname
	,@alt_optvalue		sysname
	,@exec_stmt		nvarchar(2000)
	,@save_repl_options	nvarchar(1000)
	,@catvalue		int
	,@output_flag02		char(1)
	,@save_altname		sysname
	,@save_schemaname	sysname
	,@grantoption		nvarchar (25)


DECLARE
	 @allstatopts		int
	,@alloptopts		int
	,@allcatopts		int


DECLARE
	 @cu11DBName		sysname
	,@cu11DBsid		varbinary(85)
	,@cu11DBcmptlevel	tinyint


DECLARE
	 @cu16Lname		sysname
	,@cu16Lpassword		sysname
	,@cu16Lsid		varbinary (85)
	,@cu16Lstatus		Int
	,@cu16Ldbname		sysname
	,@cu16Llanguage		sysname
	,@cu16isntgroup		int
	,@cu16isntuser		int


DECLARE
	 @cu17Lname		sysname
	,@cu17Lpassword		sysname
	,@cu17Lsid		varbinary (85)
	,@cu17Lstatus		Int
	,@cu17Ldbname		sysname
	,@cu17Llanguage		sysname
	,@cu17isntgroup		int
	,@cu17isntuser		int


DECLARE
	 @cu18name			sysname
	,@cu18type			sysname
	,@cu18default_schema_name	sysname


DECLARE
	 @cu20Uname		nvarchar(128)
	,@cu20Ualtuid		Int
	,@cu20Uissqlrole	int
	,@cu20Uisapprole	int


DECLARE
	 @cu22Urole		sysname
	,@cu22Uname		sysname


DECLARE
	 @cu24action		int
	,@cu24protecttype	int
	,@cu24puid		int
	,@cu24objtype		nvarchar(20)
	,@cu24Schemaname	sysname
	,@cu24OBJname		sysname
	,@cu24grantee		sysname
	,@cu24uid		Int
	,@cu24id		int
	,@cu24is_ms_shipped	bit


DECLARE
	 @cu26name			sysname
	,@cu26type			sysname
	,@cu26default_schema_name	sysname


DECLARE
	 @cu28Uname		nvarchar(128)
	,@cu28Ualtuid		Int
	,@cu28Uissqlrole	int
	,@cu28Uisapprole	int


DECLARE
	 @cu30Urole		sysname
	,@cu30Uname		sysname


DECLARE
	 @cu32action		int
	,@cu32protecttype	int
	,@cu32puid		int
	,@cu32objtype		nvarchar(20)
	,@cu32Schemaname	sysname
	,@cu32OBJname		sysname
	,@cu32grantee		sysname
	,@cu32uid		Int
	,@cu32id		int
	,@cu32is_ms_shipped	bit


DECLARE
	 @cu34Mmessage_id	nvarchar(10)
	,@cu34Mlanguage_id	nvarchar(50)
	,@cu34Mseverity		nvarchar(10)
	,@cu34Mis_event_logged	bit
	,@cu34Mtext		nvarchar(2048)


DECLARE
	 @cu36name			sysname
	,@cu36type			sysname
	,@cu36default_schema_name	sysname


DECLARE
	 @cu38Aname			sysname
	,@cu38Pname			sysname


DECLARE
	 @cu41Uname		nvarchar(128)
	,@cu41Ualtuid		Int
	,@cu41Uissqlrole	int
	,@cu41Uisapprole	int


DECLARE
	 @cu46Urole		sysname
	,@cu46Uname		sysname


DECLARE
	 @cu51action		int
	,@cu51protecttype	int
	,@cu51puid		int
	,@cu51objtype		nvarchar(20)
	,@cu51Schemaname	sysname
	,@cu51OBJname		sysname
	,@cu51grantee		sysname
	,@cu51uid		Int
	,@cu51id		int
	,@cu51is_ms_shipped	bit


Declare
	 @cu56ActionName	sysname
	,@cu56ProtectTypeName	sysname
	,@cu56OwnerName		sysname
	,@cu56ObjectName	sysname
	,@cu56GranteeName	sysname
	,@cu56ColumnName	sysname
	,@cu56All_Col_Bits_On	tinyint


----------------  initial values  -------------------
Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'
Select @rs_flag		= 'n'
Select @out_file_name = null


Select @save_servername	= @@servername
Select @save_servername2 = @@servername
Select @save_instname = ''


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
	Select @save_instname = substring(@@servername, @charpos+1, len(@@servername)-len(@save_servername)-1)
   end


--  Create temp tables and table variables
declare @tblvar_spt_values table
			(name			sysname
			,process_flag	char(1)
			)


declare @temp_options table (name		sysname)


declare @repl_options table (output		nvarchar(1000))


If (object_id('tempdb..#t1_Prots') is not null)
            drop table #t1_Prots


Create table #temp_dbusers (name		sysname)


CREATE Table #t1_Prots
	(Id			int		Null
	,Type1Code		char(6)		NOT Null
	,ObjType		char(2)		Null
	,ActionName		varchar(20)	Null
	,ActionCategory		char(2)		Null
	,ProtectTypeName	char(10)	Null
	,Columns_Orig		varbinary(32)	Null
	,OwnerName		sysname		Null
	,ObjectName		sysname		Null
	,GranteeName		sysname		Null
	,GrantorName		sysname		Null
	,ColumnName		sysname		Null
	,ColId			Int	Null
	,Max_ColId		Int	Null
	,All_Col_Bits_On	tinyint		Null
	,new_Bit_On		tinyint		Null
	)


/*
** Get bitmap of all options that can be set by sp_dboption.
*/
select @allstatopts=number from master.dbo.spt_values where type = 'D'
   and name = 'ALL SETTABLE OPTIONS'


select @allcatopts=number from master.dbo.spt_values where type = 'DC'
   and name = 'ALL SETTABLE OPTIONS'


select @alloptopts=number from master.dbo.spt_values where type = 'D2'
   and name = 'ALL SETTABLE OPTIONS'


--  Load the temp table for spt_values
Select @cmd = 'select name
		from master.dbo.spt_values
		where (type = ''D''
			and number & ' + convert(varchar(10), @allstatopts) + ' <> 0
			and number not in (0,' + convert(varchar(10), @allstatopts) + '))	-- Eliminate non-option entries
		 or (type = ''DC''
			and number & ' + convert(varchar(10), @allcatopts) + ' <> 0
			and number not in (0,' + convert(varchar(10), @allcatopts) + '))
		 or (type = ''D2''
			and number & ' + convert(varchar(10), @alloptopts) + ' <> 0
			and number not in (0,' + convert(varchar(10), @alloptopts) + '))
		order by name'


delete from @tblvar_spt_values


insert into @tblvar_spt_values (name) exec (@cmd)


delete from @tblvar_spt_values where name is null or name = ''
--select * from @tblvar_spt_values


--  Check input parm
If not exists(select 1 from master.sys.sysdatabases where name = @DBname)
   begin
	Print 'DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
	Goto label99
   end


/*********************************************************************
 *                SYSdbRestore
 ********************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSrestoreBYdb'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/


Select @cu11DBName = rtrim(@dbname)
Select @cu11DBsid = (select top 1 owner_sid from master.sys.databases where name = @cu11DBName)
Select @cu11DBcmptlevel = (select top 1 compatibility_level from master.sys.databases where name = @cu11DBName)


----------------------  Print the headers  ----------------------
Select @miscprint = ''
Print  @miscprint


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = '****************************************************************************************'
Print  @miscprint


Select @miscprint = 'START: Complete Restore script for database: ''' + @cu11DBName + '''   From server: ' + @@servername
Print  @miscprint


Select @miscprint = '****************************************************************************************'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = ''
Print  @miscprint


-------------------------------------------------------------------------------
--  START SYSdbRestore Section ------------------------------------------------
-------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Restore for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = ''
Print  @miscprint


Select @miscprint = 'Note: Prior to running the following restore command,'
Print  @miscprint


Select @miscprint = '      some changes in the syntax may be required, such'
Print  @miscprint


Select @miscprint = '      as the name of the backup file(s), or the path of the'
Print  @miscprint


Select @miscprint = '      restored files.'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = ''
Print  @miscprint


Select @miscprint = 'select @@servername, getdate()'
Print  @miscprint
Print  @G_O


Set @syntax_out = ''
exec dbo.dbasp_format_BackupRestore
			@DBName			= @cu11DBName
			, @Mode			= 'RD'
			, @FullReset		= 1
			, @NoLogRestores	= 1
			, @IncludeSubDir	= 1
			, @Verbose		= -1
			, @syntax_out		= @syntax_out output


Select @syntax_out = Replace(@syntax_out, 'DROP DATABASE', '--DROP DATABASE')
Select @syntax_out = Replace(@syntax_out, 'EXEC [msdb]', '--EXEC [msdb]')
Print ''
exec dbo.dbasp_PrintLarge @syntax_out
Print  @G_O
RAISERROR('',-1,-1) WITH NOWAIT


Print  ' '
Select @miscprint = 'select getdate()'
Print  @miscprint
Print  @G_O
Print  ' '
Print  ' '


Select @output_flag = 'y'


skip_SYSdbRestore:


-------------------------------------------------------------------------------------
--  END SYSdbRestore Section --------------------------------------------------------
-------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------
--  START SYSaddmasterlogins Section ------------------------------------------------
-------------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'ADD SQL and NT LOGINS for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE master'
Print  @miscprint


Print  @G_O


Print  ' '


Select @savename = ''


--------------------  Cursor 16  -----------------------


EXECUTE('DECLARE cursor_16 Insensitive Cursor For ' +
  'SELECT y.name, y.password, y.sid, y.status, y.dbname, y.language, y.isntgroup, y.isntuser
   From  master.sys.syslogins  y, [' + @cu11DBName + '].sys.database_principals  dp ' +
  'Where y.sid = dp.sid
	 And y.hasaccess = 1
	 And y.name not in (''probe'',''sa'',''repl_publisher'',''repl_subscriber'')
	 And y.name not like ''##%''
	 And y.name not like ''%BUILTIN\Administrators%''
	 And y.name not like ''%AUTHORITY\SYSTEM%''
	 And y.name not like ''%MSSQLSERVER%''
	 And y.isntgroup = 0
	 And y.isntuser = 0
   Order By y.name For Read Only')


--------------------  start cursor processing  -----------------------
OPEN cursor_16


WHILE (16=16)
   Begin
	FETCH Next From cursor_16 Into @cu16Lname, @cu16Lpassword, @cu16Lsid, @cu16Lstatus, @cu16Ldbname, @cu16Llanguage, @cu16isntgroup, @cu16isntuser
		IF (@@fetch_status < 0)
		   begin
			CLOSE cursor_16
			BREAK
		   end


--------------------  convert the password to unicode values  -----------------------
--print @cu16Lpassword
select @pwlen = len(@cu16Lpassword)
Select @pwpos = 1
Select @VCHARpassword = ''


If @pwpos <= @pwlen
   begin
	start_pw_revision:


	Select @VCHARpassword = @VCHARpassword + 'nchar(' + convert(varchar(10), unicode(Substring(@cu16Lpassword,@pwpos,1))) + ')+'


	Select @pwpos = @pwpos + 1


	If @pwpos <= @pwlen
	   begin
		goto start_pw_revision
	   end
   end


--------------------  convert the sid from varbinary to varchar  -----------------------
select @VCHARsid = '0x'
select @i = 1
select @binvalue = @cu16Lsid
select @length = datalength(@binvalue)
select @hexstring = '0123456789ABCDEF'


while (@i <= @length)
   begin

	select @tempint = convert(int, substring(@binvalue,@i,1))
	select @firstint = floor(@tempint/16)
	select @secondint = @tempint - (@firstint*16)

	select @VCHARsid = @VCHARsid +
		substring(@hexstring, @firstint+1, 1) +
		substring(@hexstring, @secondint+1, 1)

	select @i = @i + 1

   end


--------------------  set the default database  -----------------------


	SELECT @DFLTdatabase = @cu16Ldbname


--------------------  Format the output  -----------------------
	If @cu16Lname <> @savename
	   begin
		Insert into #temp_dbusers values(@cu16Lname)


		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint


		Select @miscprint = '-- Create login ''' + @cu16Lname + ''''
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


			Select @miscprint = '      Print ''ERROR:  Unable to create login ''''' + @cu16Lname + ''''' to this server.  This login was scripted from a SQL 9.00 environment.'''
			Print  @miscprint


			Select @miscprint = '   End'
			Print  @miscprint


			Select @miscprint = 'Else'
			Print  @miscprint


		   end


		Select @miscprint = 'If not exists (select * from master.sys.syslogins where name = N''' + @cu16Lname + ''')'
		Print  @miscprint


		Select @miscprint = '   Begin'
		Print  @miscprint


		Select @miscprint = '      Declare @cmd nvarchar(3000)'
		Print  @miscprint


		Select @miscprint = '      '
		Print  @miscprint


		Select @miscprint = '      select @cmd = ''CREATE LOGIN ' + @cu16Lname
		Print  @miscprint


		Select @miscprint = '             WITH PASSWORD = '''''' + '


		Select @miscprint = @miscprint + @VCHARpassword


		Select @miscprint = @miscprint + ''''''' HASHED'
		Print  @miscprint


		Select @miscprint = '                                 ,DEFAULT_DATABASE = [' + @DFLTdatabase + ']'
		Print  @miscprint


		IF @cu16Llanguage is not null
		   begin
			Select @miscprint = '                                 ,DEFAULT_LANGUAGE = ' + @cu16Llanguage
			Print  @miscprint
		   end


		If (select is_policy_checked from master.sys.sql_logins where name = @cu16Lname) = 1
		   begin
			Select @miscprint = '                                 ,CHECK_POLICY = ON'
			Print  @miscprint
		   end
		Else
		   begin
			Select @miscprint = '                                 ,CHECK_POLICY = OFF'
			Print  @miscprint
		   end


		If (select is_expiration_checked from master.sys.sql_logins where name = @cu16Lname) = 1
		   begin
			Select @miscprint = '                                 ,CHECK_EXPIRATION = ON'
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


		Select @miscprint = '      Print ''Note:  Login ''''' + @cu16Lname + ''''' already exists on this server.'''
		Print  @miscprint


		Select @miscprint = '   End'
		Print  @miscprint


		Print  @G_O


		Print  ' '


	   end


	select @savename = @cu16Lname


	Select @output_flag	= 'y'


   End  -- loop 16
   DEALLOCATE cursor_16


--------------------  Cursor 17  -----------------------


EXECUTE('DECLARE cursor_17 Insensitive Cursor For ' +
  'SELECT y.name, y.password, y.sid, y.status, y.dbname, y.language, y.isntgroup, y.isntuser
   From  master.sys.syslogins  y, [' + @cu11DBName + '].sys.database_principals  dp ' +
  'Where y.sid = dp.sid
	 And y.hasaccess = 1
	 And y.name not in (''probe'',''sa'',''repl_publisher'',''repl_subscriber'')
	 And y.name not like ''##%''
	 And y.name not like ''%BUILTIN\Administrators%''
	 And y.name not like ''%AUTHORITY\SYSTEM%''
	 And y.name not like ''%MSSQLSERVER%''
	 And (y.isntgroup <> 0 or y.isntuser <> 0)
   Order By y.name For Read Only')


--------------------  start cursor processing  -----------------------


OPEN cursor_17


WHILE (17=17)
   Begin
	FETCH Next From cursor_17 Into @cu17Lname, @cu17Lpassword, @cu17Lsid, @cu17Lstatus, @cu17Ldbname, @cu17Llanguage, @cu17isntgroup, @cu17isntuser
		IF (@@fetch_status < 0)
		   begin
			CLOSE cursor_17
			BREAK
		   end


	--------------------  set the default database  -----------------------
	SELECT @DFLTdatabase = @cu17Ldbname


	--------------------  Format the output  -----------------------
	If @cu17Lname <> @savename
	   begin
		Insert into #temp_dbusers values(@cu17Lname)


		Select @miscprint = '-------------------------------------------------'
		Print  @miscprint


		Select @miscprint = '-- Create login ''' + @cu17Lname + ''''
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


			Select @miscprint = '      Print ''ERROR:  Unable to create login ''''' + @cu17Lname + ''''' to this server.  This login was scripted from a SQL 9.00 environment.'''
			Print  @miscprint


			Select @miscprint = '   End'
			Print  @miscprint


			Select @miscprint = 'Else'
			Print  @miscprint
		   end


		If @cu17isntgroup <> 0 or @cu17isntuser <> 0
		   begin
			Select @miscprint = 'If not exists (select * from master.sys.syslogins where name = N''' + @cu17Lname + ''')'
			Print  @miscprint


			Select @miscprint = '   Begin'
			Print  @miscprint


			Select @miscprint = '      Print ''Add NT Login ''''' + @cu17Lname + ''''''''
			Print  @miscprint


			Select @miscprint = '      CREATE LOGIN [' + @cu17Lname + '] FROM WINDOWS'
			Print  @miscprint


			Select @miscprint = '             WITH DEFAULT_DATABASE = [' + @DFLTdatabase + ']'
			Print  @miscprint


			IF @cu17Llanguage is not null
			   begin
				Select @miscprint = '                 ,DEFAULT_LANGUAGE = ' + @cu17Llanguage
				Print  @miscprint
			   end


			Select @miscprint = '   End'
			Print  @miscprint


			Select @miscprint = 'Else'
			Print  @miscprint


			Select @miscprint = '   Begin'
			Print  @miscprint


			Select @miscprint = '      Print ''Note:  Login ''''' + @cu17Lname + ''''' already exists on this server.'''
			Print  @miscprint


			Select @miscprint = '   End'
			Print  @miscprint


			Print  @G_O


			Print  ' '
		   end
	   end


	select @savename = @cu17Lname


	Select @output_flag	= 'y'


   End  -- loop 17
   DEALLOCATE cursor_17


-----------------------------------------------------------------------------------
--  END SYSaddmasterlogins Section ------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYScreateMASTERusers Section ------------------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Create Users for Master'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [master]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 18DB  -----------------------
EXECUTE('DECLARE cu18_DBAccessb Insensitive Cursor For ' +
  'SELECT dp.name, dp.type, dp.default_schema_name
   From [master].sys.database_principals  dp ' +
  'Where dp.type <> ''R''
	 and dp.name in (select name from #temp_dbusers)
   Order By dp.type, dp.name For Read Only')


OPEN cu18_DBAccessb


WHILE (18=18)
   Begin
	FETCH Next From cu18_DBAccessb Into @cu18name, @cu18type, @cu18default_schema_name
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu18_DBAccessb
		  BREAK
		   end


	If @cu18default_schema_name is null or @cu18default_schema_name = 'dbo'
	   begin
		Select @miscprint = 'If not exists (select 1 from [master].sys.database_principals where name = ''' + @cu18name + ''' and type = ''' + @cu18type + ''')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      CREATE USER [' + @cu18name + '];'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end
	Else
	   begin
		Select @miscprint = 'CREATE USER [' + @cu18name + '] WITH DEFAULT_SCHEMA = ' + @cu18default_schema_name + ';'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	--  This code will fix the schema ownership for users that may have been previously removed from the database
	Select @miscprint = 'If exists (select 1 from [master].sys.schemas where name = ''' + @cu18name + ''' and principal_id = 1)'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      ALTER AUTHORIZATION ON SCHEMA::[' + @cu18name + '] TO [' + @cu18name + '];'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 18
   DEALLOCATE cu18_DBAccessb


-----------------------------------------------------------------------------------
--  END SYScreateMASTERusers Section --------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddMASTERroles Section ---------------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Roles for Master'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [master]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 20DB  -----------------------
EXECUTE('DECLARE cu20_DBRoleb Insensitive Cursor For ' +
  'SELECT r.name, r.altuid, r.issqlrole, r.isapprole
   From [master].sys.sysusers  u, [master].sys.sysusers  r, [master].sys.sysmembers  m ' +
  'Where (r.issqlrole = 1 or r.isapprole = 1)
	 and (r.uid < 16380 or r.name = ''RSExecRole'')
	 and r.name <> ''public''
         and u.uid > 4
	 and u.uid = m.memberuid
	 and m.groupuid = r.uid
         and u.name in (select name from #temp_dbusers)
   Order By r.uid For Read Only')


OPEN cu20_DBRoleb


WHILE (20=20)
   Begin
	FETCH Next From cu20_DBRoleb Into @cu20Uname, @cu20Ualtuid, @cu20Uissqlrole, @cu20Uisapprole
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu20_DBRoleb
		  BREAK
		   end


	If @cu20Uissqlrole = 1
	   begin


		Select @cmd = 'USE master'
				+ ' SELECT @save_altname = (select name from sys.sysusers where uid = ' + convert(varchar(10), @cu20Ualtuid) + ')'
		--Print @cmd


		EXEC sp_executesql @cmd, N'@save_altname sysname output', @save_altname output
		--print @save_altname


		Select @miscprint = 'If not exists (select 1 from master.sys.database_principals where name = ''' + @cu20Uname + ''' and type = ''R'')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      CREATE ROLE [' + @cu20Uname + '] AUTHORIZATION [' + @save_altname + '];'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Print  @G_O


		Print  ' '


		goto end_01b
	   end


	If @cu20Uisapprole = 1
	   begin
		Select @cmd = 'USE master'
				+ ' SELECT @save_schemaname = (select default_schema_name from sys.database_principals where name = ''' + @cu20Uname + ''')'
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


		Select @miscprint = 'select @cmd = N''CREATE APPLICATION ROLE [' + @cu20Uname + '] WITH DEFAULT_SCHEMA = [' + @save_schemaname + '], '' + N''PASSWORD = N'' + QUOTENAME(@randomPwd,'''''''')'
		Print  @miscprint


		Select @miscprint = 'EXEC dbo.sp_executesql @cmd'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	end_01b:


	Select @output_flag02 = 'y'


   End  -- loop 20
   DEALLOCATE cu20_DBRoleb


If @output_flag02 = 'n'
   begin
	Select @miscprint = '-- No output for master.'
	Print  @miscprint


	Print  ' '
   end


-----------------------------------------------------------------------------------
--  END SYSaddMASTERroles Section -----------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddMASTERrolemembers Section ---------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Role Members for Master'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [master]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 22DB  -----------------------
EXECUTE('DECLARE cu22_DBRoleb Insensitive Cursor For ' +
  'SELECT r.name, u.name
   From [master].sys.sysusers  u, [master].sys.sysusers  r, [master].sys.sysmembers  m ' +
  'Where u.uid > 4
	 and u.uid = m.memberuid
	 and m.groupuid = r.uid
         and u.name in (select name from #temp_dbusers)
   Order By r.name, u.uid For Read Only')


OPEN cu22_DBRoleb


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBRoleb Into @cu22Urole, @cu22Uname
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu22_DBRoleb
		  BREAK
		   end


	Select @miscprint = 'sp_addrolemember ''' + @cu22Urole + ''', '''  + @cu22Uname + ''''
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Select @output_flag02 = 'y'


   End  -- loop 22
   DEALLOCATE cu22_DBRoleb


If @output_flag02 = 'n'
   begin
	Print ''


	Select @miscprint = '-- No output for master.'
	Print  @miscprint


	Print ''
   end
Else
   begin
	Select @output_flag02 = 'n'
   end


-----------------------------------------------------------------------------------
--  END SYSaddMASTERrolemembers Section -----------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSgrantobjectprivileges (Master) Section -------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'GRANT OBJECT PRIVILEGES for Master'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [master]'
Print  @miscprint


Print  @G_O


Print  ' '


--  Create the temp table for sysprotects
If (object_id('tempdb..##tempprotects') is not null)
			drop table ##tempprotects


Exec('select * into ##tempprotects from [master].sys.sysprotects')


--------------------  Cursor for 24out  -----------------------
 EXECUTE('DECLARE cursor_24outb Insensitive Cursor For ' +
		'SELECT distinct CONVERT(int,p.action), p.protecttype, p.uid, o.type, x.name, o.name, u.name, u.uid, p.id, o.is_ms_shipped
		 From ##tempprotects  p
			 , [master].sys.all_objects  o
			 , [master].sys.sysusers  u
			 , [master].sys.schemas  x
	  Where  p.id = o.object_id
	  And    u.uid = p.uid
	  And    o.schema_id = x.schema_id
	 And    p.action in (193, 195, 196, 197, 224, 26)
	  And    p.uid not in (16382, 16383)
	  And    u.name in (select name from #temp_dbusers)
	  Order By p.uid, o.name, p.protecttype, CONVERT(int,p.action)
   For Read Only')


OPEN cursor_24outb


WHILE (24=24)
   Begin
	FETCH Next From cursor_24outb Into @cu24action, @cu24protecttype, @cu24puid, @cu24objtype, @cu24Schemaname, @cu24OBJname, @cu24grantee, @cu24uid, @cu24id, @cu24is_ms_shipped


	IF (@@fetch_status < 0)
		   begin
			  CLOSE cursor_24outb
		  BREAK
		   end


	If @cu24is_ms_shipped = 1 and @cu24uid < 5
	   begin
		goto skip24b
	   end


	If @cu24is_ms_shipped = 1 and @cu24grantee in ('TargetServersRole'
						    , 'SQLAgentUserRole'
						    , 'SQLAgentReaderRole'
						    , 'SQLAgentOperatorRole'
						    , 'DatabaseMailUserRole'
						    , 'db_dtsadmin'
						    , 'db_dtsltduser'
						    , 'db_dtsoperator')
	   begin
		goto skip24b
	   end


	If @cu24protecttype = 204
	   begin
		select @grantoption = 'WITH GRANT OPTION'
	   end
	Else
	   begin
		select @grantoption = ''
	   end


	IF @cu24action = 224 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT EXECUTE ON OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24action = 26 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT REFERENCES ON [' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24action = 193 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT SELECT ON OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24action = 195 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT INSERT ON OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24action = 196 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT DELETE ON OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24action = 197 and @cu24protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT UPDATE ON OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] to [' + @cu24grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu24protecttype = 206
	   begin
		delete from #t1_Prots


		--  Insert data into the temp table
		INSERT	#t1_Prots
				(Id
			,Type1Code
			,ObjType
			,ActionName
			,ActionCategory
			,ProtectTypeName
			,Columns_Orig
			,OwnerName
			,ObjectName
			,GranteeName
			,GrantorName
			,ColumnName
			,ColId
			,Max_ColId
			,All_Col_Bits_On
			,new_Bit_On
			)
			/*	1Regul indicates action can be at column level,
				2Simpl indicates action is at the object level */
			SELECT	sysp.id
				,case
					when sysp.columns is null then '2Simpl'
					else '1Regul'
					end
				,Null
				,val1.name
				,'Ob'
				,val2.name
				,sysp.columns
				,null
				,null
				,null
				,null
				,case
					when sysp.columns is null then '.'
					else Null
					end
				,-123
				,Null
				,Null
				,Null
			FROM	##tempprotects sysp
				,master.dbo.spt_values  val1
				,master.dbo.spt_values  val2
			where	sysp.id  = @cu24id
			and	val1.type     = 'T'
			and	val1.number   = sysp.action
			and	val2.type     = 'T' --T is overloaded.
			and	val2.number   = sysp.protecttype
			and	sysp.protecttype = 206
			and 	sysp.id != 0
			and	sysp.uid = @cu24uid


		IF EXISTS (SELECT * From #t1_Prots)
		   begin
			--  set owner name
			select @cmd = 'UPDATE #t1_Prots set OwnerName = ''' + @cu24Schemaname + ''' WHERE id = ' + convert(varchar(20), @cu24id)
			exec(@cmd)


			--  set object name
			select @cmd = 'UPDATE #t1_Prots set ObjectName = ''' + @cu24OBJname + ''' WHERE id = ' + convert(varchar(20), @cu24id)
			exec(@cmd)


			--  set grantee name
			select @cmd = 'UPDATE #t1_Prots set GranteeName = ''' + @cu24grantee + ''' WHERE id = ' + convert(varchar(20), @cu24id)
			exec(@cmd)


			--  set object type
			Exec('UPDATE #t1_Prots
			set ObjType = ob.type
			FROM [master].sys.objects ob
			WHERE ob.object_id = #t1_Prots.Id')

			--  set Max_ColId
			Exec('UPDATE #t1_Prots
			set Max_ColId = (select max(colid) From [master].sys.columns sysc where #t1_Prots.Id = sysc.object_id)	-- colid may not consecutive if column dropped
			where Type1Code = ''1Regul''')


			-- First bit set indicates actions pretains to new columns. (i.e. table-level permission)
			-- Set new_Bit_On accordinglly
			UPDATE	#t1_Prots
			SET new_Bit_On = CASE convert(int,substring(Columns_Orig,1,1)) & 1
						WHEN	1 then	1
						ELSE	0
						END
			WHERE	ObjType	<> 'V'	and	 Type1Code = '1Regul'

			-- Views don't get new columns
			UPDATE #t1_Prots
			set new_Bit_On = 0
			WHERE  ObjType = 'V'


			-- Indicate enties where column level action pretains to all columns in table All_Col_Bits_On = 1					*/
			Exec('UPDATE #t1_Prots
			set All_Col_Bits_On = 1
			where #t1_Prots.Type1Code = ''1Regul''
			  and not exists (select * from [master].sys.columns sysc, master.dbo.spt_values v
						where #t1_Prots.Id = sysc.object_id and sysc.column_id = v.number
						and v.number <= Max_ColId		-- column may be dropped/added after Max_ColId snap-shot
						and v.type = ''P'' and
						-- Columns_Orig where first byte is 1 means off means on and on means off
						-- where first byte is 0 means off means off and on means on
							case convert(int,substring(#t1_Prots.Columns_Orig, 1, 1)) & 1
								when 0 then convert(tinyint, substring(#t1_Prots.Columns_Orig, v.low, 1))
								else (~convert(tinyint, isnull(substring(#t1_Prots.Columns_Orig, v.low, 1),0)))
							end & v.high = 0)')

			-- Indicate entries where column level action pretains to only some of columns in table All_Col_Bits_On = 0
			UPDATE	#t1_Prots
			set All_Col_Bits_On = 0
			WHERE #t1_Prots.Type1Code = '1Regul'
			  and All_Col_Bits_On is null


			Update #t1_Prots
			set ColumnName = case
						when All_Col_Bits_On = 1 and new_Bit_On = 1 then '(All+New)'
						when All_Col_Bits_On = 1 and new_Bit_On = 0 then '(All)'
						when All_Col_Bits_On = 0 and new_Bit_On = 1 then '(New)'
						end
			from #t1_Prots
			where ObjType IN ('S ' ,'U ', 'V ')
			  and Type1Code = '1Regul'
			  and NOT (All_Col_Bits_On = 0 and new_Bit_On = 0)

			-- Expand and Insert individual column permission rows
			Exec('INSERT	into   #t1_Prots
				(Id
				,Type1Code
				,ObjType
				,ActionName
				,ActionCategory
				,ProtectTypeName
				,OwnerName
				,ObjectName
				,GranteeName
				,GrantorName
				,ColumnName
				,ColId	)
			   SELECT	prot1.Id
					,''1Regul''
					,ObjType
					,ActionName
					,ActionCategory
					,ProtectTypeName
					,OwnerName
					,ObjectName
					,GranteeName
					,GrantorName
					,null
					,val1.number
				from	#t1_Prots              prot1
					,master.dbo.spt_values  val1
					,[master].sys.columns sysc
				where	prot1.ObjType    IN (''S '' ,''U '' ,''V '')
				and prot1.Id	= sysc.object_id
				and	val1.type   = ''P''
				and	val1.number = sysc.column_id
				and	case convert(int,substring(prot1.Columns_Orig, 1, 1)) & 1
						when 0 then convert(tinyint, substring(prot1.Columns_Orig, val1.low, 1))
						else (~convert(tinyint, isnull(substring(prot1.Columns_Orig, val1.low, 1),0)))
						end & val1.high <> 0
				and prot1.All_Col_Bits_On <> 1')

			--  set column names
			Exec('UPDATE #t1_Prots
			set ColumnName = c.name
			FROM [master].sys.columns c
			WHERE c.object_id = #t1_Prots.Id
			and   c.column_id = #t1_Prots.ColId')


			delete from #t1_Prots
			where ObjType IN ('S ' ,'U ' ,'V ')
			  and All_Col_Bits_On = 0
			  and new_Bit_On = 0

		   end

		--------------------  Cursor for DB names  -------------------
		EXECUTE('DECLARE cursor_56b Insensitive Cursor For ' +
		  'SELECT t.ActionName, t.ProtectTypeName, t.OwnerName, t.ObjectName, t.GranteeName, t.ColumnName, t.All_Col_Bits_On
		   From #t1_Prots   t ' +
		  'Order By t.GranteeName For Read Only')


		OPEN cursor_56b

		WHILE (56=56)
		   Begin
			FETCH Next From cursor_56b Into @cu56ActionName, @cu56ProtectTypeName, @cu56OwnerName, @cu56ObjectName, @cu56GranteeName, @cu56ColumnName, @cu56All_Col_Bits_On
			IF (@@fetch_status < 0)
				   begin
					  CLOSE cursor_56b
				  BREAK
				   end


			If @cu56All_Col_Bits_On is not null or @cu56ColumnName = '.'
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			   end
			Else
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] ([' + @cu56ColumnName + ']) To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			   end

		   End  -- loop 56b
		DEALLOCATE cursor_56b
	   end
	ELSE
	   begin
		Print  ' '


		Select @miscprint = '-- Error on OBJECT::[' + @cu24Schemaname + '].[' + @cu24OBJname + '] for user [' + @cu24grantee + ']'
		Print  @miscprint
	   end


	Select @output_flag	= 'y'


   skip24b:


   End  -- loop 24b
   DEALLOCATE cursor_24outb


-----------------------------------------------------------------------------------
--  END SYSgrantobjectprivileges for Master Section ------------------------------------------
-----------------------------------------------------------------------------------


Print  ' '
Print  ' '


-----------------------------------------------------------------------------------
--  START SYScreateMSDBusers Section ------------------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Create Users for MSDB'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [msdb]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 26DB  -----------------------
EXECUTE('DECLARE cu26_DBAccessc Insensitive Cursor For ' +
  'SELECT dp.name, dp.type, dp.default_schema_name
   From [msdb].sys.database_principals  dp ' +
  'Where dp.type <> ''R''
	 and dp.name in (select name from #temp_dbusers)
   Order By dp.type, dp.name For Read Only')


OPEN cu26_DBAccessc


WHILE (26=26)
   Begin
	FETCH Next From cu26_DBAccessc Into @cu26name, @cu26type, @cu26default_schema_name
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu26_DBAccessc
		  BREAK
		   end


	If @cu26default_schema_name is null or @cu26default_schema_name = 'dbo'
	   begin
		Select @miscprint = 'If not exists (select 1 from [msdb].sys.database_principals where name = ''' + @cu26name + ''' and type = ''' + @cu26type + ''')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      CREATE USER [' + @cu26name + '];'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end
	Else
	   begin
		Select @miscprint = 'CREATE USER [' + @cu26name + '] WITH DEFAULT_SCHEMA = ' + @cu26default_schema_name + ';'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	--  This code will fix the schema ownership for users that may have been previously removed from the database
	Select @miscprint = 'If exists (select 1 from [msdb].sys.schemas where name = ''' + @cu26name + ''' and principal_id = 1)'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      ALTER AUTHORIZATION ON SCHEMA::[' + @cu26name + '] TO [' + @cu26name + '];'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 26
   DEALLOCATE cu26_DBAccessc


-----------------------------------------------------------------------------------
--  END SYScreateMSDBusers Section --------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddMSDBroles Section ---------------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Roles for MSDB'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [msdb]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 28DB  -----------------------
EXECUTE('DECLARE cu28_DBRolec Insensitive Cursor For ' +
  'SELECT r.name, r.altuid, r.issqlrole, r.isapprole
   From [msdb].sys.sysusers  u, [msdb].sys.sysusers  r, [msdb].sys.sysmembers  m ' +
  'Where (r.issqlrole = 1 or r.isapprole = 1)
	 and (r.uid < 16380 or r.name = ''RSExecRole'')
	 and r.name <> ''public''
         and u.uid > 4
	 and u.uid = m.memberuid
	 and m.groupuid = r.uid
         and u.name in (select name from #temp_dbusers)
   Order By r.uid For Read Only')


OPEN cu28_DBRolec


WHILE (28=28)
   Begin
	FETCH Next From cu28_DBRolec Into @cu28Uname, @cu28Ualtuid, @cu28Uissqlrole, @cu28Uisapprole
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu28_DBRolec
		  BREAK
		   end


	If @cu28Uissqlrole = 1
	   begin


		Select @cmd = 'USE msdb'
				+ ' SELECT @save_altname = (select name from sys.sysusers where uid = ' + convert(varchar(10), @cu28Ualtuid) + ')'
		--Print @cmd


		EXEC sp_executesql @cmd, N'@save_altname sysname output', @save_altname output
		--print @save_altname


		Select @miscprint = 'If not exists (select 1 from msdb.sys.database_principals where name = ''' + @cu28Uname + ''' and type = ''R'')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      CREATE ROLE [' + @cu28Uname + '] AUTHORIZATION [' + @save_altname + '];'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Print  @G_O


		Print  ' '


		goto end_01c
	   end


	If @cu28Uisapprole = 1
	   begin
		Select @cmd = 'USE msdb'
				+ ' SELECT @save_schemaname = (select default_schema_name from sys.database_principals where name = ''' + @cu28Uname + ''')'
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


		Select @miscprint = 'select @cmd = N''CREATE APPLICATION ROLE [' + @cu28Uname + '] WITH DEFAULT_SCHEMA = [' + @save_schemaname + '], '' + N''PASSWORD = N'' + QUOTENAME(@randomPwd,'''''''')'
		Print  @miscprint


		Select @miscprint = 'EXEC dbo.sp_executesql @cmd'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	end_01c:


	Select @output_flag02 = 'y'


   End  -- loop 28
   DEALLOCATE cu28_DBRolec


If @output_flag02 = 'n'
   begin
	Select @miscprint = '-- No output for msdb.'
	Print  @miscprint


	Print  ' '
   end


-----------------------------------------------------------------------------------
--  END SYSaddMSDBroles Section -----------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddMSDBrolemembers Section ---------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Role Members for MSDB'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [msdb]'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 30DB  -----------------------
EXECUTE('DECLARE cu30_DBRolec Insensitive Cursor For ' +
  'SELECT r.name, u.name
   From [msdb].sys.sysusers  u, [msdb].sys.sysusers  r, [msdb].sys.sysmembers  m ' +
  'Where u.uid > 4
	 and u.uid = m.memberuid
	 and m.groupuid = r.uid
         and u.name in (select name from #temp_dbusers)
   Order By r.name, u.uid For Read Only')


OPEN cu30_DBRolec


WHILE (30=30)
   Begin
	FETCH Next From cu30_DBRolec Into @cu30Urole, @cu30Uname
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu30_DBRolec
		  BREAK
		   end


	Select @miscprint = 'sp_addrolemember ''' + @cu30Urole + ''', '''  + @cu30Uname + ''''
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Select @output_flag02 = 'y'


   End  -- loop 30
   DEALLOCATE cu30_DBRolec


If @output_flag02 = 'n'
   begin
	Print ''


	Select @miscprint = '-- No output for msdb.'
	Print  @miscprint


	Print ''
   end
Else
   begin
	Select @output_flag02 = 'n'
   end


-----------------------------------------------------------------------------------
--  END SYSaddMSDBrolemembers Section -----------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSgrantobjectprivileges (MSDB) Section -------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'GRANT OBJECT PRIVILEGES for Msdb'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [msdb]'
Print  @miscprint


Print  @G_O


Print  ' '


--  Create the temp table for sysprotects
If (object_id('tempdb..##tempprotects') is not null)
			drop table ##tempprotects


Exec('select * into ##tempprotects from [msdb].sys.sysprotects')


--------------------  Cursor for 32out  -----------------------
 EXECUTE('DECLARE cursor_32outc Insensitive Cursor For ' +
		'SELECT distinct CONVERT(int,p.action), p.protecttype, p.uid, o.type, x.name, o.name, u.name, u.uid, p.id, o.is_ms_shipped
		 From ##tempprotects  p
			 , [msdb].sys.all_objects  o
			 , [msdb].sys.sysusers  u
			 , [msdb].sys.schemas  x
	  Where  p.id = o.object_id
	  And    u.uid = p.uid
	  And    o.schema_id = x.schema_id
	  And    p.action in (193, 195, 196, 197, 224, 26)
	  And    p.uid not in (16382, 16383)
	  And    u.name in (select name from #temp_dbusers)
	  Order By p.uid, o.name, p.protecttype, CONVERT(int,p.action)
   For Read Only')


OPEN cursor_32outc


WHILE (32=32)
   Begin
	FETCH Next From cursor_32outc Into @cu32action, @cu32protecttype, @cu32puid, @cu32objtype, @cu32Schemaname, @cu32OBJname, @cu32grantee, @cu32uid, @cu32id, @cu32is_ms_shipped


	IF (@@fetch_status < 0)
		   begin
			  CLOSE cursor_32outc
		  BREAK
		   end


	If @cu32is_ms_shipped = 1 and @cu32uid < 5
	   begin
		goto skip32c
	   end


	If @cu32is_ms_shipped = 1 and @cu32grantee in ('TargetServersRole'
						    , 'SQLAgentUserRole'
						    , 'SQLAgentReaderRole'
						    , 'SQLAgentOperatorRole'
						    , 'DatabaseMailUserRole'
						    , 'db_dtsadmin'
						    , 'db_dtsltduser'
						    , 'db_dtsoperator')
	   begin
		goto skip32c
	   end


	If @cu32protecttype = 204
	   begin
		select @grantoption = 'WITH GRANT OPTION'
	   end
	Else
	   begin
		select @grantoption = ''
	   end


	IF @cu32action = 224 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT EXECUTE ON OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu32action = 26 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT REFERENCES ON [' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu32action = 193 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT SELECT ON OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu32action = 195 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT INSERT ON OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	 end
	ELSE
	IF @cu32action = 196 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT DELETE ON OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu32action = 197 and @cu32protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT UPDATE ON OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] to [' + @cu32grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu32protecttype = 206
	   begin
		delete from #t1_Prots


		--  Insert data into the temp table
		INSERT	#t1_Prots
				(Id
			,Type1Code
			,ObjType
			,ActionName
			,ActionCategory
			,ProtectTypeName
			,Columns_Orig
			,OwnerName
			,ObjectName
			,GranteeName
			,GrantorName
			,ColumnName
			,ColId
			,Max_ColId
			,All_Col_Bits_On
			,new_Bit_On
			)
			/*	1Regul indicates action can be at column level,
				2Simpl indicates action is at the object level */
			SELECT	sysp.id
				,case
					when sysp.columns is null then '2Simpl'
					else '1Regul'
					end
				,Null
				,val1.name
				,'Ob'
				,val2.name
				,sysp.columns
				,null
				,null
				,null
				,null
				,case
					when sysp.columns is null then '.'
					else Null
					end
				,-123
				,Null
				,Null
				,Null
			FROM	##tempprotects sysp
				,master.dbo.spt_values  val1
				,master.dbo.spt_values  val2
			where	sysp.id  = @cu32id
			and	val1.type     = 'T'
			and	val1.number   = sysp.action
			and	val2.type     = 'T' --T is overloaded.
			and	val2.number   = sysp.protecttype
			and	sysp.protecttype = 206
			and 	sysp.id != 0
			and	sysp.uid = @cu32uid


		IF EXISTS (SELECT * From #t1_Prots)
		   begin
			--  set owner name
			select @cmd = 'UPDATE #t1_Prots set OwnerName = ''' + @cu32Schemaname + ''' WHERE id = ' + convert(varchar(20), @cu32id)
			exec(@cmd)


			--  set object name
			select @cmd = 'UPDATE #t1_Prots set ObjectName = ''' + @cu32OBJname + ''' WHERE id = ' + convert(varchar(20), @cu32id)
			exec(@cmd)


			--  set grantee name
			select @cmd = 'UPDATE #t1_Prots set GranteeName = ''' + @cu32grantee + ''' WHERE id = ' + convert(varchar(20), @cu32id)
			exec(@cmd)


			--  set object type
			Exec('UPDATE #t1_Prots
			set ObjType = ob.type
			FROM [msdb].sys.objects ob
			WHERE ob.object_id = #t1_Prots.Id')

			--  set Max_ColId
			Exec('UPDATE #t1_Prots
			set Max_ColId = (select max(colid) From [msdb].sys.columns sysc where #t1_Prots.Id = sysc.object_id)	-- colid may not consecutive if column dropped
			where Type1Code = ''1Regul''')


			-- First bit set indicates actions pretains to new columns. (i.e. table-level permission)
			-- Set new_Bit_On accordinglly
			UPDATE	#t1_Prots
			SET new_Bit_On = CASE convert(int,substring(Columns_Orig,1,1)) & 1
						WHEN	1 then	1
						ELSE	0
						END
			WHERE	ObjType	<> 'V'	and	 Type1Code = '1Regul'

			-- Views don't get new columns
			UPDATE #t1_Prots
			set new_Bit_On = 0
			WHERE  ObjType = 'V'


			-- Indicate enties where column level action pretains to all columns in table All_Col_Bits_On = 1					*/
			Exec('UPDATE #t1_Prots
			set All_Col_Bits_On = 1
			where #t1_Prots.Type1Code = ''1Regul''
			  and not exists (select * from [msdb].sys.columns sysc, master.dbo.spt_values v
						where #t1_Prots.Id = sysc.object_id and sysc.column_id = v.number
						and v.number <= Max_ColId		-- column may be dropped/added after Max_ColId snap-shot
						and v.type = ''P'' and
						-- Columns_Orig where first byte is 1 means off means on and on means off
						-- where first byte is 0 means off means off and on means on
							case convert(int,substring(#t1_Prots.Columns_Orig, 1, 1)) & 1
								when 0 then convert(tinyint, substring(#t1_Prots.Columns_Orig, v.low, 1))
								else (~convert(tinyint, isnull(substring(#t1_Prots.Columns_Orig, v.low, 1),0)))
							end & v.high = 0)')

			-- Indicate entries where column level action pretains to only some of columns in table All_Col_Bits_On = 0
			UPDATE	#t1_Prots
			set All_Col_Bits_On = 0
			WHERE #t1_Prots.Type1Code = '1Regul'
			  and All_Col_Bits_On is null


			Update #t1_Prots
			set ColumnName = case
						when All_Col_Bits_On = 1 and new_Bit_On = 1 then '(All+New)'
						when All_Col_Bits_On = 1 and new_Bit_On = 0 then '(All)'
						when All_Col_Bits_On = 0 and new_Bit_On = 1 then '(New)'
						end
			from #t1_Prots
			where ObjType IN ('S ' ,'U ', 'V ')
			  and Type1Code = '1Regul'
			  and NOT (All_Col_Bits_On = 0 and new_Bit_On = 0)

			-- Expand and Insert individual column permission rows
			Exec('INSERT	into   #t1_Prots
				(Id
				,Type1Code
				,ObjType
				,ActionName
				,ActionCategory
				,ProtectTypeName
				,OwnerName
				,ObjectName
				,GranteeName
				,GrantorName
				,ColumnName
				,ColId	)
			   SELECT	prot1.Id
					,''1Regul''
					,ObjType
					,ActionName
					,ActionCategory
					,ProtectTypeName
					,OwnerName
					,ObjectName
					,GranteeName
					,GrantorName
					,null
					,val1.number
				from	#t1_Prots              prot1
					,master.dbo.spt_values  val1
					,[msdb].sys.columns sysc
				where	prot1.ObjType    IN (''S '' ,''U '' ,''V '')
				and prot1.Id	= sysc.object_id
				and	val1.type   = ''P''
				and	val1.number = sysc.column_id
				and	case convert(int,substring(prot1.Columns_Orig, 1, 1)) & 1
						when 0 then convert(tinyint, substring(prot1.Columns_Orig, val1.low, 1))
						else (~convert(tinyint, isnull(substring(prot1.Columns_Orig, val1.low, 1),0)))
						end & val1.high <> 0
				and prot1.All_Col_Bits_On <> 1')

			--  set column names
			Exec('UPDATE #t1_Prots
			set ColumnName = c.name
			FROM [msdb].sys.columns c
			WHERE c.object_id = #t1_Prots.Id
			and   c.column_id = #t1_Prots.ColId')


			delete from #t1_Prots
			where ObjType IN ('S ' ,'U ' ,'V ')
			  and All_Col_Bits_On = 0
			  and new_Bit_On = 0

		   end

		--------------------  Cursor for DB names  -------------------
		EXECUTE('DECLARE cursor_56c Insensitive Cursor For ' +
		  'SELECT t.ActionName, t.ProtectTypeName, t.OwnerName, t.ObjectName, t.GranteeName, t.ColumnName, t.All_Col_Bits_On
		   From #t1_Prots   t ' +
		  'Order By t.GranteeName For Read Only')


		OPEN cursor_56c

		WHILE (56=56)
		   Begin
			FETCH Next From cursor_56c Into @cu56ActionName, @cu56ProtectTypeName, @cu56OwnerName, @cu56ObjectName, @cu56GranteeName, @cu56ColumnName, @cu56All_Col_Bits_On
			IF (@@fetch_status < 0)
				   begin
					  CLOSE cursor_56c
				  BREAK
				   end


			If @cu56All_Col_Bits_On is not null or @cu56ColumnName = '.'
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			   end
			Else
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] ([' + @cu56ColumnName + ']) To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			   end

		   End  -- loop 56c
		DEALLOCATE cursor_56c
	   end
	ELSE
	   begin
		Print  ' '


		Select @miscprint = '-- Error on OBJECT::[' + @cu32Schemaname + '].[' + @cu32OBJname + '] for user [' + @cu32grantee + ']'
		Print  @miscprint
	   end


	Select @output_flag	= 'y'


   skip32c:


   End  -- loop 32c
   DEALLOCATE cursor_32outc


-----------------------------------------------------------------------------------
--  END SYSgrantobjectprivileges for MSDB Section ------------------------------------------
-----------------------------------------------------------------------------------


Print  ' '
Print  ' '


-----------------------------------------------------------------------------------
--  START SYSaddmessages Section --------------------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'ADD MESSAGES for master'
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE master'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor 34  -----------------------


EXECUTE('DECLARE cursor_34 Insensitive Cursor For ' +
  'SELECT convert(varchar(10),m.message_id), convert(sysname,l.name), convert(varchar(10),m.severity), m.is_event_logged, convert(varchar(255),m.text)
   From master.sys.messages  m , master.sys.syslanguages  l ' +
  'Where m.message_id > 49999
     and m.language_id = l.lcid
   Order By m.message_id For Read Only')


OPEN cursor_34


WHILE (34=34)
   Begin
	FETCH Next From cursor_34 Into @cu34Mmessage_id, @cu34Mlanguage_id, @cu34Mseverity, @cu34Mis_event_logged, @cu34Mtext
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_34
	      BREAK
           end


	--  Fix single quote problem in @cu34name
	Select @startpos = 1
	label01:
	select @charpos = charindex('''', @cu34Mtext, @startpos)
	IF @charpos <> 0
	   begin
		select @cu34Mtext = stuff(@cu34Mtext, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @cu34Mtext, @startpos)
	IF @charpos <> 0
	   begin
		goto label01
	   end


	IF @cu34Mis_event_logged = 1
	   begin
		select @save_log = 'True'
	   end
	Else
	   begin
		select @save_log = 'False'
	   end


	Print  ' '


	Select @miscprint = 'if not exists (select 1 from master.sys.messages where message_id = ' + @cu34Mmessage_id + ')'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      exec sp_addmessage @msgnum = ' +@cu34Mmessage_id
	Print  @miscprint


	Select @miscprint = '                  ,@severity = ' +@cu34Mseverity
	Print  @miscprint


	Select @miscprint = '                  ,@lang = ''' +@cu34Mlanguage_id+ ''''
	Print  @miscprint


	Select @miscprint = '                  ,@msgtext = N''' +@cu34Mtext+ ''''
	Print  @miscprint


	Select @miscprint = '                  ,@with_log = ''' +@save_log+ ''''
	Print  @miscprint


	Select @miscprint = '                  ,@replace = ''replace'''
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Select @output_flag	= 'y'

   End  -- loop 34
   DEALLOCATE cursor_34


-----------------------------------------------------------------------------------
--  END SYSaddmessages Section ----------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSchangedbowner Section ------------------------------------------------
-----------------------------------------------------------------------------------


Select @save_sidname = ''
Select @save_sidname = (select name from master.sys.server_principals where sid = @cu11DBsid)


If @save_sidname = '' or @save_sidname is null
   begin
    SELECT @save_sidname = SUSER_SNAME(@cu11DBsid)
   end


----------------------  Output for database owner change  ----------------------


Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'CHANGE DATABASE OWNER for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE master'
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


----------------------------------------------------------------------------------
--  END SYSchangedbowner Section -------------------------------------------------
----------------------------------------------------------------------------------


----------------------------------------------------------------------------------
--  START SYSsetDBoptions Section ------------------------------------------------
----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Set database options for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Print  ' '


--  Print comatibility change command syntax  ----------------------
Print  ' '


Select @miscprint = '/*** Setting Database Compatibility Level ***/'
Print  @miscprint


Print  ' '


Select @miscprint = '/***'
Print  @miscprint


Select @miscprint = 'EXEC master.sys.sp_dbcmptlevel ''' + @cu11DBName + ''', ''' + convert(varchar(2), @cu11DBcmptlevel) + ''';'
Print  @miscprint


Select @miscprint = 'GO'
Print  @miscprint


Select @miscprint = '***/'
Print  @miscprint


Print  ' '


Print  ' '


Select @cmd = 'select v.name
   from master.dbo.spt_values v, master.sys.sysdatabases d
	where d.name=''' + @cu11DBname + '''
	  and ((number & ' + convert(varchar(10), @allstatopts) + ' <> 0
		and number not in (-1,' + convert(varchar(10), @allstatopts) + ')
		and v.type = ''D''
		and (v.number & d.status)=v.number)
	   or (number & ' + convert(varchar(10), @allcatopts) + ' <> 0
		and number not in (-1,' + convert(varchar(10), @allcatopts) + ')
		and v.type = ''DC''
		and d.category & v.number <> 0)
	   or (number & ' + convert(varchar(10), @alloptopts) + ' <> 0
		and number not in (-1,' + convert(varchar(10), @alloptopts) + ')
		and v.type = ''D2''
		and d.status2 & v.number <> 0))'


delete from @temp_options


insert into @temp_options (name) exec (@cmd)


delete from @temp_options where name is null or name = ''
--select * from @temp_options


--  Start the main process for this database
If (select count(*) from @tblvar_spt_values) > 0
   begin
	Update @tblvar_spt_values set process_flag = 'n'
	Select @recovery_flag = 'n'
	Select @restrict_flag = 'n'

	delete from @repl_options


	start_mainloop:


	Select @fulloptname = (select top 1 name from @tblvar_spt_values where process_flag = 'n')


    IF (@fulloptname IN ('ANSI null default'
        			,'dbo use only'
        			,'no chkpt on recovery'
        			,'read only'
        			,'select into/bulkcopy'
        			,'single user'
        			,'trunc. log on chkpt.'))
	   begin
		Select @CommentThisDBOption = 'N'
	   end
	ELSE
	   begin
		Select @CommentThisDBOption = 'Y'
	   end


	If @fulloptname in (select name from @temp_options)
	   begin
		Select @optvalue = 'true'
	   end
	Else
	   begin
		Select @optvalue = 'false'
	   end


	select @catvalue = 0
	select @catvalue = number
	  from master.dbo.spt_values
	  where lower(name) = lower(@fulloptname)
	  and type = 'DC'


	-- if replication options, format using sproc sp_replicationdboption
	If (@catvalue <> 0)
	   begin
		select @alt_optvalue = (case lower(@optvalue)
				when 'true' then 'true'
				when 'on' then 'true'
				else 'false'
			end)


		select @alt_optname = (case @catvalue
				when 1 then 'publish'
				when 2 then 'subscribe'
				when 4 then 'merge publish'
				else quotename(@fulloptname, '''')
			end)


		select @exec_stmt = quotename(@cu11DBName, '[')   + '.dbo.sp_replicationdboption'
		--print @exec_stmt


		select @cmd = 'EXEC ' + @exec_stmt + ' ' +  @cu11DBName + ', ' + @alt_optname + ', ' + @alt_optvalue
		Insert into @repl_options values (@cmd)


		goto get_next
	   end


	-- set option value in alter database
	select @alt_optvalue = (case lower(@optvalue)
			when 'true'	then 'ON'
			when 'on'	then 'ON'
			else 'OFF'
			end)


	-- set option name in alter database
	select @fulloptname = lower(@fulloptname)
	select @alt_optname = (case @fulloptname
			when 'auto create statistics' then 'AUTO_CREATE_STATISTICS'
			when 'auto update statistics' then 'AUTO_UPDATE_STATISTICS'
			when 'autoclose' then 'AUTO_CLOSE'
			when 'autoshrink' then 'AUTO_SHRINK'
			when 'ansi padding' then 'ANSI_PADDING'
			when 'arithabort' then 'ARITHABORT'
			when 'numeric roundabort' then 'NUMERIC_ROUNDABORT'
			when 'ansi null default' then 'ANSI_NULL_DEFAULT'
			when 'ansi nulls' then 'ANSI_NULLS'
			when 'ansi warnings' then 'ANSI_WARNINGS'
			when 'concat null yields null' then 'CONCAT_NULL_YIELDS_NULL'
			when 'cursor close on commit' then 'CURSOR_CLOSE_ON_COMMIT'
			when 'torn page detection' then 'TORN_PAGE_DETECTION'
			when 'quoted identifier' then 'QUOTED_IDENTIFIER'
			when 'recursive triggers' then 'RECURSIVE_TRIGGERS'
			when 'default to local cursor' then 'CURSOR_DEFAULT'
			when 'offline' then (case @alt_optvalue when 'ON' then 'OFFLINE' else 'ONLINE' end)
			when 'read only' then (case @alt_optvalue when 'ON' then 'READ_ONLY' else 'READ_WRITE' end)
			when 'dbo use only' then (case @alt_optvalue when 'ON' then 'RESTRICTED_USER' else 'MULTI_USER' end)
			when 'single user' then (case @alt_optvalue when 'ON' then 'SINGLE_USER' else 'MULTI_USER' end)
			when 'select into/bulkcopy' then 'RECOVERY'
			when 'trunc. log on chkpt.' then 'RECOVERY'
			when 'db chaining' then 'DB_CHAINING'
			else @alt_optname
			end)


	select @alt_optvalue = (case @fulloptname
			when 'default to local cursor' then (case @alt_optvalue when 'ON' then 'LOCAL' else 'GLOBAL' end)
			when 'offline' then ''
			when 'read only' then ''
			when 'dbo use only' then ''
			when 'single user' then ''
			else  @alt_optvalue
			end)


	--  Special set up for recovery option
	if lower(@fulloptname) = 'select into/bulkcopy' and @recovery_flag = 'n'
	   begin
		if @alt_optvalue = 'ON'
		   begin
			if databaseproperty(@cu11DBName, 'IsTrunclog') = 1
			   begin
				select @alt_optvalue = 'RECMODEL_70BACKCOMP'
				Select @recovery_flag = 'y'
			   end
			else
			   begin
				select @alt_optvalue = 'BULK_LOGGED'
				Select @recovery_flag = 'y'
			   end
		   end
		else
		   begin
			if databaseproperty(@cu11DBName, 'IsTrunclog') = 1
			   begin
				select @alt_optvalue = 'SIMPLE'
				Select @recovery_flag = 'y'
			   end
			else
			   begin
				select @alt_optvalue = 'FULL'
				Select @recovery_flag = 'y'
			   end
		   end
	   end
	Else if lower(@fulloptname) = 'select into/bulkcopy' and @recovery_flag = 'y'
	   begin
		goto get_next
	   end


	if lower(@fulloptname) = 'trunc. log on chkpt.' and @recovery_flag = 'n'
	   begin
		if @alt_optvalue = 'ON'
		   begin
			if databaseproperty(@cu11DBName, 'IsBulkCopy') = 1
			   begin
				select @alt_optvalue = 'RECMODEL_70BACKCOMP'
				Select @recovery_flag = 'y'
			   end
			else
			   begin
				select @alt_optvalue = 'SIMPLE'
				Select @recovery_flag = 'y'
			   end
		   end
		else
		   begin
			if databaseproperty(@cu11DBName, 'IsBulkCopy') = 1
			   begin
				select @alt_optvalue = 'BULK_LOGGED'
				Select @recovery_flag = 'y'
			   end
			else
			   begin
				select @alt_optvalue = 'FULL'
				Select @recovery_flag = 'y'
			   end
		   end
	   end
	Else if lower(@fulloptname) = 'trunc. log on chkpt.' and @recovery_flag = 'y'
	   begin
		goto get_next
	   end


	--  Special set up for restrict option
	if lower(@fulloptname) = 'dbo use only' and @restrict_flag = 'n'
	   begin
		if databaseproperty(@cu11DBName, 'IsDboOnly') = 1
		   begin
			select @alt_optname = 'RESTRICTED_USER'
			Select @restrict_flag = 'y'
		   end
		Else If databaseproperty(@cu11DBName, 'IsSingleUser') = 1
		   begin
			select @alt_optname = 'SINGLE_USER'
			Select @restrict_flag = 'y'
		   end
		Else
		   begin
			select @alt_optname = 'MULTI_USER'
			Select @restrict_flag = 'y'
		   end
	   end
	Else if lower(@fulloptname) = 'dbo use only' and @restrict_flag = 'y'
	   begin
		goto get_next
	   end


	if lower(@fulloptname) = 'single user' and @restrict_flag = 'n'
	   begin
		if databaseproperty(@cu11DBName, 'IsDboOnly') = 1
		   begin
			select @alt_optname = 'RESTRICTED_USER'
			Select @restrict_flag = 'y'
		   end
		Else If databaseproperty(@cu11DBName, 'IsSingleUser') = 1
		   begin
			select @alt_optname = 'SINGLE_USER'
			Select @restrict_flag = 'y'
		   end
		Else
		   begin
			select @alt_optname = 'MULTI_USER'
			Select @restrict_flag = 'y'
		   end
	   end
	Else if lower(@fulloptname) = 'single user' and @restrict_flag = 'y'
	   begin
		goto get_next
	   end


	-- construct the ALTER DATABASE command string
	IF (@CommentThisDBOption = 'Y')
	   begin
		Raiserror('%s%s',0,1,'/','***')
	   end


	select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET ' + @alt_optname + ' ' + @alt_optvalue + ' WITH NO_WAIT'
	print @exec_stmt


	IF (@CommentThisDBOption = 'Y')
	   begin
		Raiserror('%s%s',0,1,'***','/')
	   end


	print ' '


	get_next:


	--  Check for more rows to process
		Update @tblvar_spt_values set process_flag = 'y' where name = @fulloptname
	If (select count(*) from @tblvar_spt_values where process_flag = 'n') > 0
	   begin
		goto start_mainloop
	  end


   end


--  Print out the replication options here
If (select count(*) from @repl_options) > 0
   begin
	start_repl_options:


	Select @miscprint = '/***'
	Print @miscprint


	Select @save_repl_options = (select top 1 output from @repl_options)
	Print @save_repl_options


	Select @miscprint = '***/'
	Print @miscprint


	Print ' '
   end


--  Check for more rows to process
Delete from @repl_options where output = @save_repl_options
If (select count(*) from @repl_options) > 0
   begin
	goto start_repl_options
  end


--  Service broker
If exists (select 1 from master.sys.databases where name = @cu11DBName and is_broker_enabled = 1)
   begin
	select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET enable_broker WITH ROLLBACK IMMEDIATE'
	print @exec_stmt


	Print ' '
   end


-----------------------------------------------------------------------------------
--  END SYSsetDBoptions Section ---------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSdropDBusers Section --------------------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Drop Users for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


Select @miscprint = '---------------------------------------------------------------------------------------------------------------------------'
Print  @miscprint


Select @miscprint = '--  Use the Following code to DROP all Users from ''' + @cu11DBName + ''''
Print  @miscprint


Select @miscprint = '---------------------------------------------------------------------------------------------------------------------------'
Print  @miscprint


Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.assemblies where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '   begin'
Print  @miscprint


Select @miscprint = '      Declare @save_aname sysname'
Print  @miscprint


Select @miscprint = '      Declare @cmd nvarchar(500)'
Print  @miscprint


Select @miscprint = '      drop_user01:'
Print  @miscprint


Select @miscprint = '      Select @save_aname = (select top 1 name from [' + @cu11DBName + '].sys.assemblies where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '      Select @cmd = ''ALTER AUTHORIZATION ON Assembly::['' + @save_aname + ''] TO dbo;'''
Print  @miscprint


Select @miscprint = '      Print @cmd'
Print  @miscprint


Select @miscprint = '      Exec (@cmd)'
Print  @miscprint


Select @miscprint = '      If exists (select 1 from [' + @cu11DBName + '].sys.assemblies where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '         begin'
Print  @miscprint


Select @miscprint = '            goto drop_user01'
Print  @miscprint


Select @miscprint = '         end'
Print  @miscprint


Select @miscprint = '   end'
Print  @miscprint


Print  @G_O


Print  ' '


Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.schemas where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '   begin'
Print  @miscprint


Select @miscprint = '      Declare @save_sname sysname'
Print  @miscprint


Select @miscprint = '      Declare @cmd nvarchar(500)'
Print  @miscprint


Select @miscprint = '      drop_user02:'
Print  @miscprint


Select @miscprint = '      Select @save_sname = (select top 1 name from [' + @cu11DBName + '].sys.schemas where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '      Select @cmd = ''ALTER AUTHORIZATION ON SCHEMA::['' + @save_sname + ''] TO dbo;'''
Print  @miscprint


Select @miscprint = '      Print @cmd'
Print  @miscprint


Select @miscprint = '      Exec (@cmd)'
Print  @miscprint


Select @miscprint = '      If exists (select 1 from [' + @cu11DBName + '].sys.schemas where principal_id > 4 and principal_id < 16384)'
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


Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.database_principals where principal_id > 4 and type <> ''R'')'
Print  @miscprint


Select @miscprint = '   begin'
Print  @miscprint


Select @miscprint = '      Declare @save_uname sysname'
Print  @miscprint


Select @miscprint = '      Declare @cmd nvarchar(500)'
Print  @miscprint


Select @miscprint = '      drop_user03:'
Print  @miscprint


Select @miscprint = '      Select @save_uname = (select top 1 name from [' + @cu11DBName + '].sys.database_principals where principal_id > 4 and type <> ''R'')'
Print  @miscprint


Select @miscprint = '      Select @cmd = ''DROP USER ['' + @save_uname + ''];'''
Print  @miscprint


Select @miscprint = '      Print @cmd'
Print  @miscprint


Select @miscprint = '      Exec (@cmd)'
Print  @miscprint


Select @miscprint = '      If exists (select 1 from [' + @cu11DBName + '].sys.database_principals where principal_id > 4 and type <> ''R'')'
Print  @miscprint


Select @miscprint = '         begin'
Print  @miscprint


Select @miscprint = '            goto drop_user03'
Print  @miscprint


Select @miscprint = '         end'
Print  @miscprint


Select @miscprint = '   end'
Print  @miscprint


Print  @G_O


Print  ' '


Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.schemas where principal_id > 4 and principal_id < 16384)'
Print  @miscprint


Select @miscprint = '   begin'
Print  @miscprint


Select @miscprint = '      Declare @save_uname sysname'
Print  @miscprint


Select @miscprint = '      Declare @save_schema_id int'
Print  @miscprint


Select @miscprint = '      Declare @cmd nvarchar(500)'
Print  @miscprint


Select @miscprint = '      Select @save_schema_id = 4'
Print  @miscprint


Select @miscprint = '      drop_schema04:'
Print  @miscprint


Select @miscprint = '      Select @save_schema_id = (select top 1 schema_id from [' + @cu11DBName + '].sys.schemas where schema_id > @save_schema_id and schema_id < 16380 order by schema_id)'
Print  @miscprint


Select @miscprint = '      Select @save_uname = (select name from [' + @cu11DBName + '].sys.schemas where schema_id = @save_schema_id)'
Print  @miscprint


Select @miscprint = '      If (select count(*) from [' + @cu11DBName + '].sys.objects where schema_id = @save_schema_id) = 0'
Print  @miscprint


Select @miscprint = '         begin'
Print  @miscprint


Select @miscprint = '          Select @cmd = ''DROP SCHEMA ['' + @save_uname + ''];'''
Print  @miscprint


Select @miscprint = '            Print @cmd'
Print  @miscprint


Select @miscprint = '            Exec (@cmd)'
Print  @miscprint


Select @miscprint = '         end'
Print  @miscprint


Select @miscprint = '      If (select count(*) from [' + @cu11DBName + '].sys.schemas where schema_id > @save_schema_id and schema_id < 16380) > 0'
Print  @miscprint


Select @miscprint = '         begin'
Print  @miscprint


Select @miscprint = '            goto drop_schema04'
Print  @miscprint


Select @miscprint = '         end'
Print  @miscprint


Select @miscprint = '   end'
Print  @miscprint


Print  @G_O


Print  ' '


Print  ' '


Select @output_flag2 = 'y'


-----------------------------------------------------------------------------------
--  END SYSdropDBusers Section ----------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYScreateDBusers Section ------------------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Create Users for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 36DB  -----------------------


EXECUTE('DECLARE cu36_DBAccess Insensitive Cursor For ' +
  'SELECT dp.name, dp.type, dp.default_schema_name
   From [' + @cu11DBName + '].sys.database_principals  dp ' +
  'Where dp.type <> ''R''
	 and dp.principal_id > 4
   Order By dp.type, dp.name For Read Only')


OPEN cu36_DBAccess


WHILE (36=36)
   Begin
	FETCH Next From cu36_DBAccess Into @cu36name, @cu36type, @cu36default_schema_name
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu36_DBAccess
		  BREAK
		   end


	If @cu36default_schema_name is null or @cu36default_schema_name = 'dbo'
	   begin
		Select @miscprint = 'CREATE USER [' + @cu36name + '];'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end
	Else
	   begin
		Select @miscprint = 'CREATE USER [' + @cu36name + '] WITH DEFAULT_SCHEMA = [' + @cu36default_schema_name + '];'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	--  This code will fix the schema ownership for users that may have been previously removed from the database
	Select @miscprint = 'If exists (select 1 from [' + @cu11DBName + '].sys.schemas where name = ''' + @cu36name + ''' and principal_id = 1)'
	Print  @miscprint


	Select @miscprint = '   begin'
	Print  @miscprint


	Select @miscprint = '      ALTER AUTHORIZATION ON SCHEMA::[' + @cu36name + '] TO [' + @cu36name + '];'
	Print  @miscprint


	Select @miscprint = '   end'
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 36
   DEALLOCATE cu36_DBAccess


-----------------------------------------------------------------------------------
--  END SYScreateDBusers Section --------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START ALTER AUTHORIZATION ON Assembly Section ---------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'ALTER AUTHORIZATION ON Assembly (if any exist) for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 41DB  -----------------------
EXECUTE('DECLARE cu38_Assembly Insensitive Cursor For ' +
  'SELECT a.name, p.name
   From [' + @cu11DBName + '].sys.assemblies  a, [' + @cu11DBName + '].sys.database_principals  p ' +
  'Where a.principal_id > 4
    and  a.principal_id < 16384
    and  a.principal_id = p.principal_id
   Order By p.name, a.name For Read Only')


OPEN cu38_Assembly


WHILE (38=38)
   Begin
	FETCH Next From cu38_Assembly Into @cu38Aname, @cu38Pname
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu38_Assembly
		  BREAK
		   end


	Select @miscprint = 'ALTER AUTHORIZATION ON Assembly::' + @cu38Aname + ' TO ' + @cu38Pname + ';'
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Select @output_flag02 = 'y'


   End  -- loop 38
   DEALLOCATE cu38_Assembly


If @output_flag02 = 'n'
   begin
	Select @miscprint = '-- No output for this database.'
	Print  @miscprint


	Print  ' '
   end


-----------------------------------------------------------------------------------
--  END ALTER AUTHORIZATION ON Assembly Section -----------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddDBroles Section ---------------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Roles for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 41DB  -----------------------
EXECUTE('DECLARE cu41_DBRole Insensitive Cursor For ' +
  'SELECT u.name, u.altuid, u.issqlrole, u.isapprole
   From [' + @cu11DBName + '].sys.sysusers  u ' +
  'Where (u.issqlrole = 1 or u.isapprole = 1)
	 and (u.uid < 16380 or u.name = ''RSExecRole'' or u.uid > 16399)
	 and u.name <> ''public''
   Order By u.uid For Read Only')


OPEN cu41_DBRole


WHILE (41=41)
   Begin
	FETCH Next From cu41_DBRole Into @cu41Uname, @cu41Ualtuid, @cu41Uissqlrole, @cu41Uisapprole
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu41_DBRole
		  BREAK
		   end


	If @cu41Uissqlrole = 1
	   begin


		Select @cmd = 'USE ' + quotename(@cu11DBName)
				+ ' SELECT @save_altname = (select name from sys.sysusers where uid = ' + convert(varchar(10), @cu41Ualtuid) + ')'
		--Print @cmd


		EXEC sp_executesql @cmd, N'@save_altname sysname output', @save_altname output
		--print @save_altname


		Select @miscprint = 'If not exists (select 1 from ' + quotename(@cu11DBName) + '.sys.database_principals where name = ''' + @cu41Uname + ''' and type = ''R'')'
		Print  @miscprint


		Select @miscprint = '   begin'
		Print  @miscprint


		Select @miscprint = '      CREATE ROLE [' + @cu41Uname + '] AUTHORIZATION [' + @save_altname + '];'
		Print  @miscprint


		Select @miscprint = '   end'
		Print  @miscprint


		Print  @G_O


		Print  ' '


		goto end_01
	   end


	If @cu41Uisapprole = 1
	   begin
		Select @cmd = 'USE ' + quotename(@cu11DBName)
				+ ' SELECT @save_schemaname = (select default_schema_name from sys.database_principals where name = ''' + @cu41Uname + ''')'
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


		Select @miscprint = 'select @cmd = N''CREATE APPLICATION ROLE [' + @cu41Uname + '] WITH DEFAULT_SCHEMA = [' + @save_schemaname + '], '' + N''PASSWORD = N'' + QUOTENAME(@randomPwd,'''''''')'
		Print  @miscprint


		Select @miscprint = 'EXEC dbo.sp_executesql @cmd'
		Print  @miscprint


		Print  @G_O


		Print  ' '
	   end


	end_01:


	Select @output_flag02 = 'y'


   End  -- loop 41
   DEALLOCATE cu41_DBRole


If @output_flag02 = 'n'
   begin
	Select @miscprint = '-- No output for this database.'
	Print  @miscprint


	Print  ' '
   end


-----------------------------------------------------------------------------------
--  END SYSaddDBroles Section -----------------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSaddDBrolemembers Section ---------------------------------------------
-----------------------------------------------------------------------------------


Select @output_flag02 = 'n'


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'Add Role Members for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


--------------------  Cursor for 46DB  -----------------------
EXECUTE('DECLARE cu46_DBRole Insensitive Cursor For ' +
  'SELECT r.name, u.name
   From [' + @cu11DBName + '].sys.sysusers  u, [' + @cu11DBName + '].sys.sysusers  r, [' + @cu11DBName + '].sys.sysmembers  m ' +
  'Where u.uid > 3
	 and u.uid = m.memberuid
	 and m.groupuid = r.uid
   Order By r.name, u.uid For Read Only')


OPEN cu46_DBRole


WHILE (46=46)
   Begin
	FETCH Next From cu46_DBRole Into @cu46Urole, @cu46Uname
	IF (@@fetch_status < 0)
		   begin
			  CLOSE cu46_DBRole
		  BREAK
		   end


	Select @miscprint = 'sp_addrolemember ''' + @cu46Urole + ''', '''  + @cu46Uname + ''''
	Print  @miscprint


	Print  @G_O


	Print  ' '


	Select @output_flag02 = 'y'


   End  -- loop 46
   DEALLOCATE cu46_DBRole


If @output_flag02 = 'n'
   begin
	Print ''


	Select @miscprint = '-- No output for this database.'
	Print  @miscprint


	Print ''
   end
Else
   begin
	Select @output_flag02 = 'n'
   end


-----------------------------------------------------------------------------------
--  END SYSaddDBrolemembers Section -----------------------------------------------
-----------------------------------------------------------------------------------


-----------------------------------------------------------------------------------
--  START SYSgrantobjectprivileges Section ----------------------------------------
-----------------------------------------------------------------------------------


----------------------  Print the headers  ----------------------
Print  ' '


Select @miscprint = '/***************************************************************************************'
Print  @miscprint


Select @miscprint = 'GRANT OBJECT PRIVILEGES for Database: ' + @cu11DBName
Print  @miscprint


Select @miscprint = '***************************************************************************************/'
Print  @miscprint


Select @miscprint = 'USE [' + @cu11DBName + ']'
Print  @miscprint


Print  @G_O


Print  ' '


--  Create the temp table for sysprotects
If (object_id('tempdb..##tempprotects') is not null)
			drop table ##tempprotects


Exec('select * into ##tempprotects from ['+ @cu11DBName + '].sys.sysprotects')


--------------------  Cursor for 51out  -----------------------
 EXECUTE('DECLARE cursor_51out Insensitive Cursor For ' +
		'SELECT distinct CONVERT(int,p.action), p.protecttype, p.uid, o.type, x.name, o.name, u.name, u.uid, p.id, o.is_ms_shipped
		 From ##tempprotects  p
			 , [' + @cu11DBName + '].sys.all_objects  o
			 , [' + @cu11DBName + '].sys.sysusers  u
			 , [' + @cu11DBName + '].sys.schemas  x
	  Where  p.id = o.object_id
	  And    u.uid = p.uid
	  And    o.schema_id = x.schema_id
	  And    p.action in (193, 195, 196, 197, 224, 26)
	  And    p.uid not in (16382, 16383)
	  Order By p.uid, o.name, p.protecttype, CONVERT(int,p.action)
   For Read Only')


--DROP TABLE ##tempprotects
--select * into ##tempprotects FROM ${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM.sys.sysprotects
--SELECT distinct CONVERT(int,p.action), p.protecttype, p.uid, o.type, x.name, o.name, u.name, u.uid, p.id, o.is_ms_shipped
--		 From ##tempprotects  p
--			 , [${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM].sys.all_objects  o
--			 , [${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM].sys.sysusers  u
--			 , [${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM].sys.schemas  x
--	  Where  p.id = o.object_id
--	  And    u.uid = p.uid
--	  And    o.schema_id = x.schema_id
--	  And    p.action in (193, 195, 196, 197, 224, 26)
--	  And    p.uid not in (16382, 16383)
--	  AND    o.name like '%diagram%'
--	  Order By o.name, p.uid, p.protecttype, CONVERT(int,p.action)


OPEN cursor_51out


WHILE (51=51)
   Begin
	FETCH Next From cursor_51out Into @cu51action, @cu51protecttype, @cu51puid, @cu51objtype, @cu51Schemaname, @cu51OBJname, @cu51grantee, @cu51uid, @cu51id, @cu51is_ms_shipped


	IF (@@fetch_status < 0)
		   begin
			  CLOSE cursor_51out
		  BREAK
		   end


	If @cu51is_ms_shipped = 1 and @cu51uid < 5
	   begin
		goto skip51
	   end


	If @cu51is_ms_shipped = 1 and @cu51grantee in ('TargetServersRole'
						    , 'SQLAgentUserRole'
						    , 'SQLAgentReaderRole'
						    , 'SQLAgentOperatorRole'
						    , 'DatabaseMailUserRole'
						    , 'db_dtsadmin'
						    , 'db_dtsltduser'
						    , 'db_dtsoperator')
	   begin
		goto skip51
	   end


	If @cu51protecttype = 204
	   begin
		select @grantoption = 'WITH GRANT OPTION'
	   end
	Else
	   begin
		select @grantoption = ''
	   end


	IF @cu51action = 224 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT EXECUTE ON OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51action = 26 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT REFERENCES ON [' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51action = 193 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT SELECT ON OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51action = 195 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT INSERT ON OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51action = 196 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT DELETE ON OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51action = 197 and @cu51protecttype in (204, 205)
	   begin
		Print  ' '


		Select @miscprint = 'GRANT UPDATE ON OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] to [' + @cu51grantee + '] ' + @grantoption
		Print  @miscprint


		Print  @G_O
	   end
	ELSE
	IF @cu51protecttype = 206
	   begin
		delete from #t1_Prots


		--  Insert data into the temp table
		INSERT	#t1_Prots
				(Id
			,Type1Code
			,ObjType
			,ActionName
			,ActionCategory
			,ProtectTypeName
			,Columns_Orig
			,OwnerName
			,ObjectName
			,GranteeName
			,GrantorName
			,ColumnName
			,ColId
			,Max_ColId
			,All_Col_Bits_On
			,new_Bit_On
			)
			/*	1Regul indicates action can be at column level,
				2Simpl indicates action is at the object level */
			SELECT	sysp.id
				,case
					when sysp.columns is null then '2Simpl'
					else '1Regul'
					end
				,Null
				,val1.name
				,'Ob'
				,val2.name
				,sysp.columns
				,null
				,null
				,null
				,null
				,case
					when sysp.columns is null then '.'
					else Null
					end
				,-123
				,Null
				,Null
				,Null
			FROM	##tempprotects sysp
				,master.dbo.spt_values  val1
				,master.dbo.spt_values  val2
			where	sysp.id  = @cu51id
			and	val1.type     = 'T'
			and	val1.number   = sysp.action
			and	val2.type     = 'T' --T is overloaded.
			and	val2.number   = sysp.protecttype
			and	sysp.protecttype = 206
			and 	sysp.id != 0
			and	sysp.uid = @cu51uid


		IF EXISTS (SELECT * From #t1_Prots)
		   begin
			--  set owner name
			select @cmd = 'UPDATE #t1_Prots set OwnerName = ''' + @cu51Schemaname + ''' WHERE id = ' + convert(varchar(20), @cu51id)
			exec(@cmd)


			--  set object name
			select @cmd = 'UPDATE #t1_Prots set ObjectName = ''' + @cu51OBJname + ''' WHERE id = ' + convert(varchar(20), @cu51id)
			exec(@cmd)


			--  set grantee name
			select @cmd = 'UPDATE #t1_Prots set GranteeName = ''' + @cu51grantee + ''' WHERE id = ' + convert(varchar(20), @cu51id)
			exec(@cmd)


			--  set object type
			Exec('UPDATE #t1_Prots
			set ObjType = ob.type
			FROM ['+ @cu11DBName + '].sys.objects ob
			WHERE ob.object_id = #t1_Prots.Id')

			--  set Max_ColId
			Exec('UPDATE #t1_Prots
			set Max_ColId = (select top 1 colid From ['+ @cu11DBName + '].sys.columns sysc where #t1_Prots.Id = sysc.object_id order by colid desc)	-- colid may not consecutive if column dropped
			where Type1Code = ''1Regul''')


			-- First bit set indicates actions pretains to new columns. (i.e. table-level permission)
			-- Set new_Bit_On accordinglly
			UPDATE	#t1_Prots
			SET new_Bit_On = CASE convert(int,substring(Columns_Orig,1,1)) & 1
						WHEN	1 then	1
						ELSE	0
						END
			WHERE	ObjType	<> 'V'	and	 Type1Code = '1Regul'

			-- Views don't get new columns
			UPDATE #t1_Prots
			set new_Bit_On = 0
			WHERE  ObjType = 'V'


			-- Indicate enties where column level action pretains to all columns in table All_Col_Bits_On = 1					*/
			Exec('UPDATE #t1_Prots
			set All_Col_Bits_On = 1
			where #t1_Prots.Type1Code = ''1Regul''
			  and not exists (select * from ['+ @cu11DBName + '].sys.columns sysc, master.dbo.spt_values v
						where #t1_Prots.Id = sysc.object_id and sysc.column_id = v.number
						and v.number <= Max_ColId		-- column may be dropped/added after Max_ColId snap-shot
						and v.type = ''P'' and
						-- Columns_Orig where first byte is 1 means off means on and on means off
						-- where first byte is 0 means off means off and on means on
							case convert(int,substring(#t1_Prots.Columns_Orig, 1, 1)) & 1
								when 0 then convert(tinyint, substring(#t1_Prots.Columns_Orig, v.low, 1))
								else (~convert(tinyint, isnull(substring(#t1_Prots.Columns_Orig, v.low, 1),0)))
							end & v.high = 0)')

			-- Indicate entries where column level action pretains to only some of columns in table All_Col_Bits_On = 0
			UPDATE	#t1_Prots
			set All_Col_Bits_On = 0
			WHERE #t1_Prots.Type1Code = '1Regul'
			  and All_Col_Bits_On is null


			Update #t1_Prots
			set ColumnName = case
						when All_Col_Bits_On = 1 and new_Bit_On = 1 then '(All+New)'
						when All_Col_Bits_On = 1 and new_Bit_On = 0 then '(All)'
						when All_Col_Bits_On = 0 and new_Bit_On = 1 then '(New)'
						end
			from #t1_Prots
			where ObjType IN ('S ' ,'U ', 'V ')
			  and Type1Code = '1Regul'
			  and NOT (All_Col_Bits_On = 0 and new_Bit_On = 0)

			-- Expand and Insert individual column permission rows
			Exec('INSERT	into   #t1_Prots
				(Id
				,Type1Code
				,ObjType
				,ActionName
				,ActionCategory
				,ProtectTypeName
				,OwnerName
				,ObjectName
				,GranteeName
				,GrantorName
				,ColumnName
				,ColId	)
			   SELECT	prot1.Id
					,''1Regul''
					,ObjType
					,ActionName
					,ActionCategory
					,ProtectTypeName
					,OwnerName
					,ObjectName
					,GranteeName
					,GrantorName
					,null
					,val1.number
				from	#t1_Prots              prot1
					,master.dbo.spt_values  val1
					,['+ @cu11DBName + '].sys.columns sysc
				where	prot1.ObjType    IN (''S '' ,''U '' ,''V '')
				and prot1.Id	= sysc.object_id
				and	val1.type   = ''P''
				and	val1.number = sysc.column_id
				and	case convert(int,substring(prot1.Columns_Orig, 1, 1)) & 1
						when 0 then convert(tinyint, substring(prot1.Columns_Orig, val1.low, 1))
						else (~convert(tinyint, isnull(substring(prot1.Columns_Orig, val1.low, 1),0)))
						end & val1.high <> 0
				and prot1.All_Col_Bits_On <> 1')

			--  set column names
			Exec('UPDATE #t1_Prots
			set ColumnName = c.name
			FROM ['+ @cu11DBName + '].sys.columns c
			WHERE c.object_id = #t1_Prots.Id
			and   c.column_id = #t1_Prots.ColId')


			delete from #t1_Prots
			where ObjType IN ('S ' ,'U ' ,'V ')
			  and All_Col_Bits_On = 0
			  and new_Bit_On = 0

		   end

		--------------------  Cursor for DB names  -------------------
		EXECUTE('DECLARE cursor_56 Insensitive Cursor For ' +
		  'SELECT t.ActionName, t.ProtectTypeName, t.OwnerName, t.ObjectName, t.GranteeName, t.ColumnName, t.All_Col_Bits_On
		   From #t1_Prots   t ' +
		  'Order By t.GranteeName For Read Only')


		OPEN cursor_56

		WHILE (56=56)
		   Begin
			FETCH Next From cursor_56 Into @cu56ActionName, @cu56ProtectTypeName, @cu56OwnerName, @cu56ObjectName, @cu56GranteeName, @cu56ColumnName, @cu56All_Col_Bits_On
			IF (@@fetch_status < 0)
				   begin
					  CLOSE cursor_56
				  BREAK
				   end


			If @cu56All_Col_Bits_On is not null or @cu56ColumnName = '.'
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			   end
			Else
			   begin
				Print  ' '


				Select @miscprint = rtrim(upper(@cu56ProtectTypeName)) + ' ' + rtrim(upper(@cu56ActionName)) + ' ON OBJECT::[' + rtrim(@cu56OwnerName) + '].[' + @cu56ObjectName + '] ([' + @cu56ColumnName + ']) To [' + @cu56GranteeName + '] CASCADE'
				Print  @miscprint


				Print  @G_O
			 end

		   End  -- loop 56
		DEALLOCATE cursor_56
	   end
	ELSE
	   begin
		Print  ' '


		Select @miscprint = '-- Error on OBJECT::[' + @cu51Schemaname + '].[' + @cu51OBJname + '] for user [' + @cu51grantee + ']'
		Print  @miscprint
	   end


	Select @output_flag	= 'y'


   skip51:


   End  -- loop 51
   DEALLOCATE cursor_51out


-----------------------------------------------------------------------------------
--  END SYSgrantobjectprivileges Section ------------------------------------------
-----------------------------------------------------------------------------------


Print  ' '
Print  ' '


---------------------------  Finalization  -----------------------
label99:


drop table #temp_dbusers


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSrestoreBYsingledb] TO [public]
GO
