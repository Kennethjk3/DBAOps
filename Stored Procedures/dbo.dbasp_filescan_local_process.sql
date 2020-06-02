SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_filescan_local_process]


/**************************************************************
 **  Stored Procedure dbasp_filescan_local_process
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  June 16, 2009
 **
 **  This dbasp is set up to run the filescan process locally.
 ***************************************************************/
  as
  SET NOCOUNT ON
  SET ANSI_WARNINGS OFF


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/18/2009	Steve Ledridge		New filescan process.
--	06/19/2009	Steve Ledridge		Several fixes.
--	07/07/2009	Steve Ledridge		Code to remove trailing single quotes,
--						added Update dbo.dba_serverinfo set Filescan.
--	07/10/2009	Steve Ledridge		Always send file to central server.
--	07/13/2009	Steve Ledridge		Added delay of 30 seconds for intial file creation.
--	08/11/2009	Steve Ledridge		New section for local exclude using the no_check table.
--	03/23/2010	Steve Ledridge		Limit scan to dba_reports, dba_archive and sqljob_logs
--						and raise DBA Filescan messages to the SQL errorlog (no output files)
--	======================================================================================


/*


--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd 				nvarchar(4000)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@charpos			int
	,@save_nocheck_nocheckID	int
	,@save_nocheck_detail01		sysname
	,@save_nocheck_detail02		sysname
	,@save_nocheck_detail03		sysname
	,@save_nocheck_detail04		sysname
	,@save_nocheck_num		int


DECLARE
	 @save_scantext			nvarchar(256)
	,@hold_scantext			nvarchar(125)
	,@cu12fulltext			nvarchar(256)
	,@central_server 		sysname


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @central_server = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'CentralServer'
If @central_server is null
   begin
	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The local filescan process failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end


--  Clear filescan work tables
delete from dbo.filescan_bcpin


delete from dbo.filescan_temp


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Copy the include and exclude files from the central server
Select @cmd = 'copy \\' + @central_server + '\' + @central_server + '_builds\DBAOps\filescan\*.*  \\' + @save_servername + '\DBASQL\filescan /Y'
print @cmd
exec master.sys.xp_cmdshell @cmd


--  Scan the SQLjob_logs folder for asci
Select @cmd = 'findstr /i /g:\\' + @save_servername + '\DBASQL\filescan\includescan.txt \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\*.* | findstr /v /i /g:\\' + @save_servername + '\DBASQL\filescan\exclude_joblogs.txt >\\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_SQLjob_logs.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Scan the SQLjob_logs folder for unicode
Select @cmd = 'strings \\' + @save_servername + '\SQLServerAgent\*.* | findstr /i /g:\\' + @save_servername + '\DBASQL\filescan\includescan.txt | findstr /v /i /g:\\' + @save_servername + '\DBASQL\filescan\exclude_joblogs.txt >\\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_SQLjob_logs2.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Scan the Archive folder for ascii
Select @cmd = 'findstr /i /g:\\' + @save_servername + '\dbasql\filescan\includescan02.txt \\' + @save_servername + '\DBA_Archive\*.* | findstr /v /i /g:\\' + @save_servername + '\DBASQL\filescan\excludeall.txt >\\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_archive.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Scan the Archive folder for unicode
Select @cmd = 'strings \\' + @save_servername + '\DBA_Archive\*.* | findstr /i /g:\\' + @save_servername + '\dbasql\filescan\includescan02.txt | findstr /v /i /g:\\' + @save_servername + '\DBASQL\filescan\excludeall.txt >\\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_archive_uni.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


--  Scan the Reports folder for ascii
Select @cmd = 'findstr /i /g:\\' + @save_servername + '\dbasql\filescan\includescan02.txt \\' + @save_servername + '\dbasql\dba_reports\*.log | findstr /v /i /g:\\' + @save_servername + '\DBASQL\filescan\excludeall.txt >\\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_reports.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


Select @miscprint = 'Filescan completed for SQL Server ' + @save_servername2
Print  @miscprint


Print ' '


--  Combine files for this server
Select @cmd = 'copy /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_SQLjob_logs.rpt + /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_SQLjob_logs2.rpt  \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


Select @cmd = 'copy /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt + /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_archive.rpt  \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


Select @cmd = 'copy /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt + /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_archive_uni.rpt  \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


Select @cmd = 'copy /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt      + /B \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '_reports.rpt  \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt'
print @cmd
EXEC master.sys.xp_cmdshell @cmd--, no_output


Select @miscprint = 'Filescan files combined for SQL Server ' + @save_servername2
Print  @miscprint


----------------  Upload file process  -------------------
select @cmd = 'type \\' + @save_servername + '\DBASQL\filescan\filescan_temp\Filescan_' + @save_servername2 + '.rpt'
print @cmd


Delete from DBAOps.dbo.filescan_bcpin
insert into DBAOps.dbo.filescan_bcpin exec master.sys.xp_cmdshell @cmd
delete from DBAOps.dbo.filescan_bcpin where fulltext is null
delete from DBAOps.dbo.filescan_bcpin where fulltext = ''
--select * from DBAOps.dbo.filescan_bcpin


If (select count(*) from DBAOps.dbo.filescan_bcpin) = 0
   begin
	select @miscprint = 'DBA Note:  No filescan rows to process for server ' + @@servername
	print @miscprint
	goto label99
   end


--  Transfer data from the temp table to the filescan_temp table (varchar(max) to varchar(125)
insert into DBAOps.dbo.filescan_temp select convert(nvarchar(256),fulltext) from DBAOps.dbo.filescan_bcpin


delete from DBAOps.dbo.filescan_temp where fulltext = char(9)


delete from DBAOps.dbo.filescan_temp where fulltext not like '\\%'


delete from DBAOps.dbo.filescan_temp where fulltext like '%.mdmp%'


--  Local Exclude section
If exists (select 1 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport')
   begin
	Select @save_nocheck_nocheckID = 0
	start_local_exclude01:
	Select @save_nocheck_nocheckID = (select top 1 nocheckID from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID > @save_nocheck_nocheckID order by nocheckID)
	Select @save_nocheck_detail01 = (select detail01 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID = @save_nocheck_nocheckID)
	Select @save_nocheck_detail02 = (select detail02 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID = @save_nocheck_nocheckID)
	Select @save_nocheck_detail03 = (select detail03 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID = @save_nocheck_nocheckID)
	Select @save_nocheck_detail04 = (select detail04 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID = @save_nocheck_nocheckID)


	If (select isnumeric(@save_nocheck_detail04)) = 0
	   begin
		Select @save_nocheck_num = 0
	   end
	Else
	   begin
		Select @save_nocheck_num = @save_nocheck_detail04
	   end


	If @save_nocheck_num = 0
	   begin
		If (@save_nocheck_detail02 is null or @save_nocheck_detail02 = '') and (@save_nocheck_detail03 is null or @save_nocheck_detail03 = '')
		   begin
			delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01
		   end
		Else If @save_nocheck_detail03 is null or @save_nocheck_detail03 = ''
		   begin
			delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02
		   end
		Else If @save_nocheck_detail02 is null or @save_nocheck_detail02 = ''
		   begin
			delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext not like @save_nocheck_detail03
		   end
		Else
		   begin
			delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02 and fulltext not like @save_nocheck_detail03
		   end
	   end
	Else
	   begin
		If (@save_nocheck_detail02 is null or @save_nocheck_detail02 = '') and (@save_nocheck_detail03 is null or @save_nocheck_detail03 = '')
		   begin
			If (select count(*) from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01) < @save_nocheck_num
			   begin
				delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01
			   end
		   end
		Else If @save_nocheck_detail03 is null or @save_nocheck_detail03 = ''
		   begin
			If (select count(*) from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02) < @save_nocheck_num
			   begin
				delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02
			   end
		   end
		Else If @save_nocheck_detail02 is null or @save_nocheck_detail02 = ''
		   begin
			If (select count(*) from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext not like @save_nocheck_detail03) < @save_nocheck_num
			   begin
				delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext not like @save_nocheck_detail03
			   end
		   end
		Else
		   begin
			If (select count(*) from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02 and fulltext not like @save_nocheck_detail03) < @save_nocheck_num
			   begin
				delete from DBAOps.dbo.filescan_temp where fulltext like @save_nocheck_detail01 and fulltext like @save_nocheck_detail02 and fulltext not like @save_nocheck_detail03
			   end
		   end
	   end


	If exists (select 1 from dbo.No_Check where NoCheck_Type = 'Filescan_noreport' and nocheckID > @save_nocheck_nocheckID)
	   begin
		goto start_local_exclude01
	   end
   end


----------------  Delete all rows from the filescan_current table  -------------------
delete from DBAOps.dbo.filescan_current


----------------  Delete all dba_reports and dba_archive related rows from the filescan_exclude table  -------------------
delete from DBAOps.dbo.filescan_exclude where scantext like '%dba_archive%'
delete from DBAOps.dbo.filescan_exclude where scantext like '%dba_reports%'


----------------  Set filescan_exclude use flag  -------------------
update DBAOps.dbo.filescan_exclude set useflag = 'n'


--  Start data compare  -------------------
start_loop01:


Select @save_scantext = (select top 1 fulltext from DBAOps.dbo.filescan_temp)
Select @hold_scantext = left(@save_scantext, 125)
--print @hold_scantext
--raiserror('', -1,-1) with nowait


If exists (select 1 from DBAOps.dbo.filescan_exclude where scantext = @hold_scantext)
   begin
	update DBAOps.dbo.filescan_exclude set useflag = 'y' where scantext = @hold_scantext
   end
Else
   begin
	insert into DBAOps.dbo.filescan_exclude values (@hold_scantext, 'y')
	insert into DBAOps.dbo.filescan_current values (@save_scantext)
   end


--  Look for more rows to process
delete from DBAOps.dbo.filescan_temp where fulltext = @save_scantext
If (select count(*) from DBAOps.dbo.filescan_temp) > 0
   begin
	goto start_loop01
   end


delete from DBAOps.dbo.filescan_exclude where useflag = 'n'


If (select count(*) from DBAOps.dbo.filescan_current) = 0
   begin
	select @miscprint = 'DBA Note:  No filescan rows to process for server ' + @@servername
	print @miscprint
	goto label99
   end


--  cursor to raise filescan results to the sql error log
EXECUTE('DECLARE cu12_cursor Insensitive Cursor For ' +
  'SELECT fc.fulltext
   From DBAOps.dbo.filescan_current  fc ' +
  'for Read Only')


OPEN cu12_cursor


WHILE (12=12)
 Begin
	FETCH Next From cu12_cursor Into @cu12fulltext
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_cursor
	      BREAK
           end


	Print @cu12fulltext
	RAISERROR (68001, -1, -1, @cu12fulltext) with log


 End  -- loop 12
DEALLOCATE cu12_cursor


----------------  End  -------------------
label99:


Print  ' '
Select @miscprint = 'Filescan process completed.'
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_filescan_local_process] TO [public]
GO
