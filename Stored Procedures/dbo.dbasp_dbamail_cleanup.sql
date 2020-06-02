SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_dbamail_cleanup] (@purge_days smallint = 14
					   ,@save_SQLEnv sysname = '')


/**************************************************************
 **  Stored Procedure dbasp_dbamail_cleanup
 **  Written by Steve Ledridge, Virtuoso
 **  August 23, 2002
 **
 **  This dbasp is set up to cleanup the dba_mail folders.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/23/2002	Steve Ledridge		New SQLMail cleanup process.
--	12/27/2002	Steve Ledridge		Now using the UTIL_servers table.
--	06/09/2006	Steve Ledridge		Updated for SQL 2005.
--	08/27/2008	Steve Ledridge		Now using the dba_serverinfo table.
--	======================================================================================


/***
Declare @purge_days smallint
declare @save_SQLEnv sysname


Select @purge_days = 14
Select @save_SQLEnv = 'production'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@command 		nvarchar(4000)
	,@retcode		int
	,@charpos		int
	,@save_filedate_char	char(10)
	,@save_filedate		datetime
	,@save_filename		sysname
	,@save_mailshare	varchar(200)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_domain		sysname

DECLARE
	 @cu11SQLservername	sysname


DECLARE
	 @cu12cmdoutput		nvarchar(255)


----------------  initial values  -------------------


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)
create table #Smail_Info(ParmText nvarchar(4000) null)


Select @save_servername = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain = (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain')


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Cursor for SQL Servers to check
EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT p.SQLName
   From DBAOps.dbo.DBA_ServerInfo  p ' +
  'Where p.active = ''y''
     and p.SQLmail = ''y''
     and p.DomainName = ''' + @save_domain + '''
     and p.SQLEnv like ''%' + @save_SQLEnv + '%''
   Order by p.SQLName for Read Only')


OPEN cu11_cursor


WHILE (11=11)
 Begin
	FETCH Next From cu11_cursor Into @cu11SQLservername
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_cursor
	      BREAK
           end


	Select @charpos = charindex('\', @cu11SQLservername)
	IF @charpos <> 0
	   begin
		Select @cu11SQLservername = rtrim(substring(@cu11SQLservername, 1, (CHARINDEX('\', @cu11SQLservername)-1)))
	   end


	Select @save_mailshare = '\\'+ @cu11SQLservername + '\' + @cu11SQLservername + '_dba_mail'
print @save_mailshare
raiserror ('', -1, -1) with nowait


	--  Check for files in the dba_mail folder for this server
	Delete from #DirectoryTempTable
	Select @command = 'dir ' + @save_mailshare + '\*.*'
	Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command


	--  cursor for the dba_mail 'dir' results
	EXECUTE('DECLARE cu12_cursor Insensitive Cursor For ' +
	  'SELECT p.cmdoutput
	   From #DirectoryTempTable   p ' +
	  'Order by p.cmdoutput for Read Only')

	OPEN cu12_cursor

	WHILE (12=12)
	 Begin
		FETCH Next From cu12_cursor Into @cu12cmdoutput
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu12_cursor
		      BREAK
	           end


		--  Check for file dates and names
		If substring(@cu12cmdoutput, 3, 1) = '/' and substring(@cu12cmdoutput, 6, 1) = '/' and substring(@cu12cmdoutput, 25, 5) <> '<DIR>'
		   begin
			Select @save_filedate_char = substring(@cu12cmdoutput, 1, 10)
			Select @save_filedate = convert(datetime, @save_filedate_char)


			--  Check to see if file is older than the purge date parm
			If datediff(day, @save_filedate, getdate()) > @purge_days
			   begin
				Select @save_filename = ltrim(rtrim(substring(@cu12cmdoutput, 40, 200)))


				Select @command = 'del "' + @save_mailshare + '\' + @save_filename + '"'
				Print @command
				EXEC @retcode = master.sys.xp_cmdshell @command, no_output


				IF @@error <> 0 or @retcode <> 0
				   begin
					Select @miscprint = 'DBA WARNING: DBA mail cleanup process failed for file ' +  @save_mailshare + '\' + @save_filename
					raiserror(@miscprint,-1,-1) with log
				   end
			   end
		   end


	 End  -- loop 12
	DEALLOCATE cu12_cursor


 End  -- loop 11
DEALLOCATE cu11_cursor


----------------  End  -------------------


drop table #DirectoryTempTable


drop table #Smail_Info
GO
GRANT EXECUTE ON  [dbo].[dbasp_dbamail_cleanup] TO [public]
GO
