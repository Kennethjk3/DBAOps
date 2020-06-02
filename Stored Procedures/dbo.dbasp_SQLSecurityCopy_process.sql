SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SQLSecurityCopy_process]


/**************************************************************
 **  Stored Procedure dbasp_SQLSecurityCopy_process
 **  Written by Steve Ledridge, Virtuoso
 **  December 27, 2002
 **
 **  This dbasp is set up to gather and combine the SQL security
 **  reports.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/27/2002	Steve Ledridge		New copy process.
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	06/19/2003	Steve Ledridge		Fix for instance file name.
--	06/09/2006	Steve Ledridge		Updated for SQL 2005.
--	08/22/2008	Steve Ledridge		New table dba_serverinfo.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@command 		nvarchar(4000)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_domain			sysname
	,@charpos		int


DECLARE
	 @cu11sqlservername	sysname
	,@cu11sqlservername2	sysname
	,@cu11sqlservername3	sysname


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain = (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain')


Select @command = 'copy \\' + @save_servername + '\DBASQL\security_header.txt \\' + @save_servername + '\DBASQL\dba_reports\SQLServer_SecurityRpt.txt'
EXEC master..xp_cmdshell @command, no_output


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Cursor for SQL Servers to scan
EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT u.SQLname
   From DBAOps.dbo.DBA_Serverinfo  u ' +
  'Where u.active = ''y''
     and u.DomainName = ''' + @save_domain + '''
   Order by u.SQLname for Read Only')


OPEN cu11_cursor


WHILE (11=11)
 Begin
	FETCH Next From cu11_cursor Into @cu11sqlservername
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_cursor
	      BREAK
           end


	Select @cu11sqlservername2 = @cu11sqlservername
	Select @cu11sqlservername3 = @cu11sqlservername


	Select @charpos = charindex('\', @cu11sqlservername)
	IF @charpos <> 0
	   begin
		Select @cu11sqlservername = rtrim(substring(@cu11sqlservername, 1, (CHARINDEX('\', @cu11sqlservername)-1)))


		Select @cu11sqlservername2 = rtrim(stuff(@cu11sqlservername2, @charpos, 1, '$'))


		Select @cu11sqlservername3 = stuff(@cu11sqlservername3, @charpos, 1, '(')
		Select @cu11sqlservername3 = @cu11sqlservername3 + ')'


	   end


	Select @command = 'copy \\' + @save_servername + '\DBASQL\dba_reports\SQLServer_SecurityRpt.txt + \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_dbasql\dba_reports\' + @cu11sqlservername3 + '_REPORTsecurity.txt   \\' + @save_servername + '\DBASQL\dba_reports\SQLServer_SecurityRpt.txt'
	EXEC master.sys.xp_cmdshell @command, no_output


	Select @miscprint = 'Copy process completed for SQL Server ' + @cu11sqlservername
	Print  @miscprint


 End  -- loop 11
DEALLOCATE cu11_cursor


----------------  End  -------------------


Print  ' '
Select @miscprint = 'SQL Security Report copy process completed.'
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_SQLSecurityCopy_process] TO [public]
GO
