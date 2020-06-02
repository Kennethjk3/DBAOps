SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_filescan_process] (@save_SQLEnv sysname = '')


/**************************************************************
 **  Stored Procedure dbasp_filescan_process
 **  Written by Steve Ledridge, Virtuoso
 **  December 26, 2002
 **
 **  This dbasp is set up to run the filescan process.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/26/2002	Steve Ledridge		New filescan process.
--	04/22/2003	Steve Ledridge		Changes for new instance share names.
--	05/04/2006	Steve Ledridge		Converted for SQL 2005.
--	06/13/2006	Steve Ledridge		Fixed dba_reports related syntax.
--	06/14/2006	Steve Ledridge		Only scan for dba_reports *.log files.
--	05/11/2007	Steve Ledridge		Added Unicode scan for archive folder.
--	07/15/2008	Steve Ledridge		Added scan for SQL job_logs share.
--	08/22/2008	Steve Ledridge		New table dba_serverinfo.
--	08/22/2008	Steve Ledridge		New input parm @save_SQLEnv.
--	10/08/2008	Steve Ledridge		Added ascii check for sqljob_logs and separate exclude file.
--	======================================================================================


/*
declare @save_SQLEnv sysname


Select @save_SQLEnv = 'production'
--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@command 			nvarchar(4000)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_domain			sysname
	,@charpos			int


DECLARE
	 @cu11sqlservername		sysname
	,@cu11sqlservername2		sysname


DECLARE
	 @cu12sqlservername		sysname
	,@cu12sqlservername2		sysname


----------------  initial values  -------------------
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


--  Cursor for SQL Servers to scan
EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT u.SQLName
   From DBAOps.dbo.DBA_ServerInfo u ' +
  'Where u.active = ''y''
     and u.filescan = ''y''
     and u.DomainName = ''' + @save_domain + '''
     and u.SQLEnv like ''%' + @save_SQLEnv + '%''
   Order by u.SQLName for Read Only')


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


	Select @charpos = charindex('\', @cu11sqlservername)
	IF @charpos <> 0
	   begin
		Select @cu11sqlservername = substring(@cu11sqlservername, 1, (CHARINDEX('\', @cu11sqlservername)-1))


		Select @cu11sqlservername2 = stuff(@cu11sqlservername2, @charpos, 1, '$')
	   end


	--  Scan the LOG folder for asci
	Select @command = 'findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan.txt \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_LOG\*.* | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\excludeall.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_asc.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the Log folder for unicode
	Select @command = 'strings \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_LOG\*.* | findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan.txt | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\excludeall.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_uni.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the SQLjob_logs folder for asci
	Select @command = 'findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan.txt \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_SQLjob_logs\*.* | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\exclude_joblogs.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_SQLjob_logs.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the SQLjob_logs folder for unicode
	Select @command = 'strings \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_SQLjob_logs\*.* | findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan.txt | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\exclude_joblogs.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_SQLjob_logs2.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the Archive folder for ascii
	Select @command = 'findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan02.txt \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_dba_archive\*.* | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\excludeall.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_archive.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the Archive folder for unicode
	Select @command = 'strings \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_dba_archive\*.* | findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan02.txt | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\excludeall.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_archive_uni.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Scan the Reports folder for ascii
	Select @command = 'findstr /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\includescan02.txt \\' + @cu11sqlservername + '\' + @cu11sqlservername2 + '_dbasql\dba_reports\*.log | findstr /v /i /g:\\' + @save_servername + '\' + @save_servername + '_filescan\excludeall.txt >\\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu11sqlservername2 + '_reports.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


Select @miscprint = 'Filescan completed for SQL Server ' + @cu11sqlservername2
Print  @miscprint


 End  -- loop 11
DEALLOCATE cu11_cursor


Print ' '


--  Prepare the new combined result file
Select @command = 'del \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall6.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall5.rpt Filescanall6.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall4.rpt Filescanall5.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall3.rpt Filescanall4.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall2.rpt Filescanall3.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall1.rpt Filescanall2.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'ren \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall_temp.rpt Filescanall1.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\uploadheader.txt \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall_temp.rpt'
print @command
EXEC master.sys.xp_cmdshell @command--, no_output


--  cursor to combine files
EXECUTE('DECLARE cu12_cursor Insensitive Cursor For ' +
  'SELECT u.SQLName
   From DBAOps.dbo.DBA_ServerInfo  u ' +
  'Where u.active = ''y''
     and u.filescan = ''y''
     and u.DomainName = ''' + @save_domain + '''
     and u.SQLEnv like ''%' + @save_SQLEnv + '%''
   Order by u.SQLName for Read Only')


OPEN cu12_cursor


WHILE (12=12)
 Begin
	FETCH Next From cu12_cursor Into @cu12sqlservername
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_cursor
	      BREAK
           end


	Select @cu12sqlservername2 = @cu12sqlservername


	Select @charpos = charindex('\', @cu12sqlservername)
	IF @charpos <> 0
	   begin
		Select @cu12sqlservername = rtrim(substring(@cu12sqlservername, 1, (CHARINDEX('\', @cu12sqlservername)-1)))


		Select @cu12sqlservername2 = stuff(@cu12sqlservername2, @charpos, 1, '$')
	   end


print @cu12sqlservername2


	--  Combine files for this server
	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_asc.rpt  + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_uni.rpt \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_SQLjob_logs.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_SQLjob_logs2.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_archive.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_archive_uni.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt      + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '_reports.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


	--  Combine files for all servers
	Select @command = 'copy /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall_temp.rpt + /B \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_temp\Filescan_' + @cu12sqlservername2 + '.rpt  \\' + @save_servername + '\' + @save_servername + '_filescan\filescan_result\Filescanall_temp.rpt'
	print @command
	EXEC master.sys.xp_cmdshell @command--, no_output


Select @miscprint = 'Filescan files combined for SQL Server ' + @cu11sqlservername2
Print  @miscprint


 End  -- loop 12
DEALLOCATE cu12_cursor


----------------  End  -------------------


Print  ' '
Select @miscprint = 'Filescan process completed.'
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_filescan_process] TO [public]
GO
