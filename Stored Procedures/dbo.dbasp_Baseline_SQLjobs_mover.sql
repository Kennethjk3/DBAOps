SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Baseline_SQLjobs_mover] ( @source_server sysname = '\\10.240.8.6',
				@source_path nvarchar(500) = 'SQLTrans',
				@target_path nvarchar(500) = null,
				@filename sysname = null,
				@retry_limit smallint = 5,
				@retry_num smallint = 3,
				@wait_num smallint = 30,
				@delete_source char(1) = 'n',
				@pre_delete_target char(1) = 'y',
				@trusted char(1) = 'y')


/*********************************************************
 **  Stored Procedure dbasp_Baseline_SQLjobs_mover
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 12, 2010
 **
 **  This procedure is used for copying Baseline APPL
 **  job script files from one server to another where
 **  there is no trust relationship.
 **
 **  This proc accepts several input parms:
 **  - @source_server is the \\servername where files are being copied from.
 **  - @source_path is the path (share or folder name) where files are being copied from.
 **  - @target_path is the path where files are being copied to.
 **  - @filesource is the name of the server where the file originated.
 **  - @filename is the name of the script file being copied.
 **  - @retry_limit is the number of retries performed if the file is not available.
 **  - @retry_num is the number of retries performed if the network fails.
 **  - @wait_num is the number of seconds to wait between retries.
 **  - @trusted (y or n) if the server is in a non-trusted domain, this should be 'n'.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/12/2010	Steve Ledridge		New process
--	03/15/2010	Steve Ledridge		Fixed issue with checking source server for non-trusted.
--	05/20/2010	Steve Ledridge		Fixed net use code for non-trusted connections.
--	05/09/2011	Steve Ledridge		Added verification at end.
--	05/23/2011	Steve Ledridge		Fixed logic related to @trusted.
--	08/02/2013	Steve Ledridge		Removed \\seapshlsql0a from list of servers.
--	======================================================================================


/***
Declare @source_server sysname
Declare @source_path nvarchar(500)
Declare @target_path nvarchar(500)
Declare @filename sysname
Declare @retry_limit smallint
Declare @wait_num smallint
Declare @delete_source char(1)
Declare @pre_delete_target char(1)
Declare @trusted char(1)


select @source_server = '\\g1sqlb'
select @source_path = 'g1sqlb$b_backup'
--select @source_server = '\\ginssqla'
--select @source_path = 'ginssqla$a_backup'
select @target_path = '\\DBAOpsER02\DBAOpsER02_base_gmsb'
Select @filename = 'gmsb_Jobs.sql'
select @retry_limit = 3
Select @wait_num = 11
Select @delete_source = 'n'
Select @pre_delete_target = 'n'
Select @trusted = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@command 		nvarchar(512)
	,@retry_counter		smallint
	,@source_user 		sysname
	,@source_pw 		sysname
	,@hold_string		sysname
	,@newid 		sysname


----------------  initial values  -------------------
Select @error_count = 0
Select @retry_counter = 0
select @newid = convert(sysname, newid())


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


--  Check input parms
if @filename is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_Baseline_SQLjobs_mover.  @backupname is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_Baseline_SQLjobs_mover. @target_path is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


--  Set login and password
If @trusted = 'n' and @source_server in ('\\g1sqla', '\\g1sqlb', '\\seadcpcsqla', '\\seadcaspsqla', '\\seadcshsqla')
   begin
	Select @source_user = 'PRODUCTION\SQLTransSVCAcct'
	Select @hold_string  = 'pw_' + @source_user
	Select @source_pw  = (select top 1 detail01 from dbo.local_control where subject = @hold_string)
	If @source_pw is null or @source_pw = ''
	   begin
		Select @miscprint = 'DBA ERROR: Password not found for ' + @source_user + '.'
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @trusted = 'n'
   begin
	select @command = 'net use'
	exec master.sys.xp_cmdshell @command--, no_output


	--  Connect to the remote server share
	select @command = 'net use ' + @source_server + ' /user:' + @source_user + ' xxxxx'
	print @command
	select @command = 'net use ' + @source_server + ' /user:' + @source_user + ' ' + @source_pw
	--print @command
	exec master.sys.xp_cmdshell @command--, no_output


	If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @source_server and Detail02 = @newid)
	   begin
		insert into dbo.local_control values ('net_use', @source_server, @newid, '')
	   end


	select @command = 'net use'
	exec master.sys.xp_cmdshell @command--, no_output
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


Label01:


select @command = 'dir ' + @source_server + '\' + @source_path + '\' + @filename + ' /b'
print @command


delete from #DirectoryTempTable
exec master.sys.xp_cmdshell @command
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
delete from #DirectoryTempTable where cmdoutput is null
select * from #DirectoryTempTable


if (select count(*) from #DirectoryTempTable) < 1
   BEGIN
	Select @miscprint = 'DBA WARNING: No matching files found for dbasp_Baseline_SQLjobs_mover at ' + @source_server + '\' + @source_path
	If @retry_counter < @retry_limit
	   begin
		Select @retry_counter = @retry_counter + 1
		--Waitfor delay '00:05:00'
		Print 'Retry ' + convert(varchar(10), @retry_counter)
		goto label01
	   end
	Else
	   begin
		Select @error_count = @error_count + 1
		goto label89
	   end
   END


--  Check to see if this file is already at the target.  If not, delete the file at the target.
If @pre_delete_target = 'y'
   begin
	Delete from #DirectoryTempTable
	Select @command = 'DIR ' + @target_path + '\' + @filename + ' /b'
	Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
	delete from #DirectoryTempTable where cmdoutput is null
	select * from #DirectoryTempTable


	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		select @command = 'if exist ' + @target_path + '\' + @filename + ' del ' + @target_path + '\' + @filename
		Print @command
		exec master.sys.xp_cmdshell @command
	   end
   end


--  Perform the copy process
--  Note:  If the file being copied is already at the target, robocopy will skip it.
--         The reason we do it this way is - if the file is damaged, robocopy will overwrite it.
If @delete_source = 'y'
   begin
	select @command = 'robocopy /Z /W:' + convert(nvarchar(10), @wait_num) + ' /R:' + convert(nvarchar(10), @retry_limit) + ' /MOV ' + @source_server + '\' + @source_path + ' ' + @target_path + ' ' + rtrim(@filename)
   end
Else
   begin
	select @command = 'robocopy /Z /W:' + convert(nvarchar(10), @wait_num) + ' /R:' + convert(nvarchar(10), @retry_limit) + ' ' + @source_server + '\' + @source_path + ' ' + @target_path + ' ' + rtrim(@filename)
   end


Print @command
exec master.sys.xp_cmdshell @command


--  verify contents at the target
select @command = 'dir ' + @source_server + '\' + @source_path + '\' + @filename + ' /b'
print @command


delete from #DirectoryTempTable
exec master.sys.xp_cmdshell @command
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
delete from #DirectoryTempTable where cmdoutput is null
select * from #DirectoryTempTable


-------------------   end   --------------------------
label89:


If @trusted = 'n'
   begin
	--  Disconnect the remote server connection
	If exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @source_server and Detail02 = @newid)
	   begin
		delete from dbo.local_control where subject = 'net_use' and Detail01 = @source_server and Detail02 = @newid
	   end


	If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @source_server)
	   begin
		select @command = 'net use /DELETE ' + @source_server
		print @command
		exec master.sys.xp_cmdshell @command--, no_output
	   end
   end


label99:


drop table #DirectoryTempTable


If @error_count > 0
   begin
	raiserror(@miscprint,16,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Baseline_SQLjobs_mover] TO [public]
GO
