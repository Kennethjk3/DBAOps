SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSaddlinkedservers]


/**************************************************************
 **  Stored Procedure dbasp_SYSaddlinkedservers
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 24, 2001
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add linked servers and linked logons
 **
 **  Output member is SYSaddlinkedservers.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	05/06/2002	Steve Ledridge		Removed unused 'sa' select sid code.
--	06/14/2002	Steve Ledridge		Complete re-write.  Passwords not handeled.
--	06/20/2002	Steve Ledridge		Added code for status 96, found in 7.0 cluster.
--	12/16/2002	Steve Ledridge		Only linked servers will be included in this
--						output via 'isremote = 1'.
--	12/27/2002	Steve Ledridge		Disabled processing for SQL 7.0
--	05/11/2006	Steve Ledridge		Modified for SQL 2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint				varchar(255)
	,@G_O					varchar (2)
	,@output_flag			char(1)
	,@cur_text				varchar(2000)
	,@save_local_loginname	sysname


DECLARE
	 @cu11srvname				sysname
	,@cu11srvid					smallint
	,@cu11srvstatus				int
	,@cu11srvproduct			nvarchar(128)
	,@cu11providername			nvarchar(128)
	,@cu11datasource			nvarchar(4000)
	,@cu11location				nvarchar(4000)
	,@cu11providerstring		nvarchar(4000)
	,@cu11catalog				sysname
	,@cu11connecttimeout		int
	,@cu11querytimeout			int
	,@cu11rpc					bit
	,@cu11pub					bit
	,@cu11sub					bit
	,@cu11dist					bit
	,@cu11rpcout				bit
	,@cu11dataaccess			bit
	,@cu11collationcompatible	bit
	,@cu11useremotecollation	bit
	,@cu11lazyschemavalidation	bit
	,@cu11collation				sysname


DECLARE
	 @cu22server_id				int
	,@cu22local_principal_id	int
	,@cu22uses_self_credential	bit
	,@cu22remote_name			sysname


----------------  initial values  -------------------


Select @G_O				= 'g' + 'o'
Select @output_flag		= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSaddlinkedserver'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------


   Print  '/*********************************************************'
   Select @miscprint = 'ADD LINKED SERVERS '
   Print  @miscprint
   Print  ' '
   Select @miscprint = 'NOTE:  You may need to modify the some of the following'
   Print  @miscprint
   Select @miscprint = '       commands prior to execution (i.e. @rmtpassword).'
   Print  @miscprint
   Print  '*********************************************************/'
   Print  ' '


   Select @miscprint = 'USE master'
   Print  @miscprint
   Print  @G_O
   Print  ' '

--------------------  Cursor 11  -----------------------


EXECUTE('DECLARE cursor_11 Insensitive Cursor For ' +
 'SELECT s.srvname, s.srvid, s.srvstatus, s.srvproduct, s.providername, s.datasource, s.location, s.providerstring,
			s.catalog, s.connecttimeout, s.querytimeout, s.rpc, s.pub, s.sub, s.dist, s.rpcout,
			s.dataaccess, s.collationcompatible, s.useremotecollation, s.lazyschemavalidation, s.collation
   From master.sys.sysservers   s ' +
  'Where s.srvid > 0
     and s.isremote = 0
   Order By s.srvname For Read Only')


OPEN cursor_11


WHILE (11=11)
   Begin
	FETCH Next From cursor_11 Into @cu11srvname, @cu11srvid, @cu11srvstatus, @cu11srvproduct, @cu11providername,
									@cu11datasource, @cu11location, @cu11providerstring, @cu11catalog, @cu11connecttimeout, @cu11querytimeout,
									@cu11rpc, @cu11pub, @cu11sub, @cu11dist, @cu11rpcout, @cu11dataaccess,
									@cu11collationcompatible, @cu11useremotecollation, @cu11lazyschemavalidation, @cu11collation
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11
	      BREAK
           end


	--  Header Info
	Print  ' '
	Select @miscprint = '-------------------------------------------------------'
	Print  @miscprint
	Select @miscprint = '--  Add Linked Server ''' + @cu11srvname + ''''
	Print  @miscprint
	Select @miscprint = '-------------------------------------------------------'
	Print  @miscprint


	--  Add Linked server commands
	Select @miscprint = 'EXEC sp_addlinkedserver @server = ''' + @cu11srvname + ''''
	Print  @miscprint


	Select @miscprint = '                       ,@srvproduct = ''' + @cu11srvproduct + ''''
	Print  @miscprint

	If @cu11srvproduct <> 'SQL Server'
	   begin
		Select @miscprint = '                       ,@provider = ''' + @cu11providername + ''''
		Print  @miscprint
		Select @miscprint = '                       ,@datasrc = ''' + @cu11datasource + ''''
		Print  @miscprint
	   end


	If @cu11location is not null and @cu11srvproduct <> 'SQL Server'
	   begin
		Select @miscprint = '                       ,@location = ''' + @cu11location + ''''
		Print  @miscprint
	   end


	If @cu11providerstring is not null and @cu11srvproduct <> 'SQL Server'
	   begin
		Select @miscprint = '                       ,@provstr = ''' + @cu11providerstring + ''''
		Print  @miscprint
	   end


	If @cu11catalog is not null and @cu11srvproduct <> 'SQL Server'
	   begin
		Select @miscprint = '                       ,@catalog = ''' + @cu11catalog + ''''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	--  Add sp_serveroption commands
	If @cu11collationcompatible = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''collation compatible'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''collation compatible'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11dataaccess = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''data access'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''data access'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11dist = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''dist'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''dist'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11pub = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''pub'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''pub'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11rpc = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''rpc'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''rpc'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11rpcout = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''rpc out'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''rpc out'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11sub = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''sub'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''sub'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''connect timeout'', @optvalue=N''' + convert(nvarchar(10), @cu11connecttimeout) + ''''
	Print  @miscprint
	Print  @G_O
	Print  ' '


	Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''query timeout'', @optvalue=N''' + convert(nvarchar(10), @cu11querytimeout) + ''''
	Print  @miscprint
	Print  @G_O
	Print  ' '


	If @cu11collation is null
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''collation name'', @optvalue=null'
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''collation name'', @optvalue=N''' + rtrim(@cu11collation) + ''''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11lazyschemavalidation = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''lazy schema validation'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''lazy schema validation'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	If @cu11useremotecollation = 0
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''use remote collation'', @optvalue=N''false'''
		Print  @miscprint
	   end
	Else
	   begin
		Select @miscprint = 'EXEC master.sys.sp_serveroption @server=N''' + @cu11srvname + ''', @optname=N''use remote collation'', @optvalue=N''true'''
		Print  @miscprint
	   end


	Print  @G_O
	Print  ' '


	--  Add Linked server logins for this linked server
	Print  ' '
	Select @miscprint = '--  Add Linked Server Logins for ''' + @cu11srvname + ''''
	Print  @miscprint


	If not exists (select 1 from master.sys.linked_logins where server_id = @cu11srvid)
	   begin
	        Select @miscprint = 'EXEC master.sys.sp_droplinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @locallogin=null'
	        Print  @miscprint
		Print  @G_O
		Print  ' '
	   end
	Else
	   begin
		Select @cur_text = 'DECLARE cursor_22 Insensitive Cursor For ' +
		  'SELECT s.server_id, s.local_principal_id, s.uses_self_credential, s.remote_name
		   From master.sys.linked_logins  s ' +
		  'Where s.server_id = ' + convert(varchar(10), @cu11srvid) + '
		   Order By s.local_principal_id For Read Only'


		EXECUTE(@cur_text)


		OPEN cursor_22


		WHILE (22=22)
		   Begin
			FETCH Next From cursor_22 Into @cu22server_id, @cu22local_principal_id, @cu22uses_self_credential, @cu22remote_name
			IF (@@fetch_status < 0)
		        begin
					CLOSE cursor_22
					BREAK
		        end


			If @cu22uses_self_credential = 0 and @cu22local_principal_id = 0 and @cu22remote_name is null
			   begin
				Select @miscprint = 'EXEC master.sys.sp_addlinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @useself = ''false'''
				Print  @miscprint
				Print  @G_O
				Print  ' '
			   end


			If @cu22uses_self_credential = 1 and @cu22local_principal_id = 0 and @cu22remote_name is null
			   begin
				Select @miscprint = 'EXEC master.sys.sp_addlinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @useself = ''true'''
				Print  @miscprint
				Print  @G_O
				Print  ' '
			   end


			If @cu22uses_self_credential = 0 and @cu22local_principal_id = 0 and @cu22remote_name is not null
			   begin
				Print  ' '
				Select @miscprint = '-- NOTE:  Update @rmtpassword in the following command before you execute it!'
				Print  @miscprint
				Select @miscprint = 'EXEC master.sys.sp_addlinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @useself = ''false'', @rmtuser = ''' + @cu22remote_name + ''',  @rmtpassword = ''xyz'''
				Print  @miscprint
				Print  @G_O
				Print  ' '
			   end


			If @cu22local_principal_id > 0 and @cu22uses_self_credential = 1
			   begin
				Select @save_local_loginname = name from master.sys.server_principals where principal_id = @cu22local_principal_id
				Select @miscprint = 'EXEC master.sys.sp_addlinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @locallogin = ''' + rtrim(@save_local_loginname) + ''', @useself = ''true'''
				Print  @miscprint
				Print  @G_O
				Print  ' '
			   end


			If @cu22local_principal_id > 0 and @cu22uses_self_credential = 0
			   begin
				Print  ' '
				Select @miscprint = '-- NOTE:  Update @rmtpassword in the following command before you execute it!'
				Print  @miscprint
				Select @save_local_loginname = name from master.sys.server_principals where principal_id = @cu22local_principal_id
				Select @miscprint = 'EXEC master.sys.sp_addlinkedsrvlogin @rmtsrvname = ''' + @cu11srvname + ''', @locallogin = ''' + rtrim(@save_local_loginname) + ''', @useself = ''false'', @rmtuser = ''' + @cu22remote_name + ''',  @rmtpassword = ''xyz'''
				Print  @miscprint
				Print  @G_O
				Print  ' '
			   end


		  End  -- loop 22


		DEALLOCATE cursor_22
	   end


	Print  ' '
	Select @output_flag	= 'y'


   End  -- loop 11


DEALLOCATE cursor_11


---------------------------  Finalization  -----------------------


label99:


If @output_flag = 'n'
   begin
	Select @miscprint = '-- No linked server to configure '
	Print  @miscprint
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddlinkedservers] TO [public]
GO
