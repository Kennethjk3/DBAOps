SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BaselineFile_moverESE] ( @source_path nvarchar(500) = '\\DBAOpser03\DBAOpser03_BASE_'
				,@target_path nvarchar(500) = '\\10.207.130.149\SEASDBASQL01_BASE_'
				,@application sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_BaselineFile_moverESE
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 17, 2004
 **
 **  This procedure is used for copying baseline files from one server
 **  to another using ESEutility.exe where there is no trust relationship.
 **
 **  This proc accepts four input parms:
 **  - @source_path is the path where files are being copied from.
 **  - @target_path is the path where files are being copied to.
 **  - @application is the name of application folder where the files exist.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/04/2010	Steve Ledridge		New process
--	09/03/2013	Steve Ledridge		Changed fresdbasql01 to seasdbasql01.
--	======================================================================================


/***
Declare @source_path nvarchar(500)
Declare @target_path nvarchar(500)
Declare @application sysname


select @source_path = '\\SEAPSQLDPLY05\SEAPSQLDPLY05_BASE_'
select @target_path = '\\SEASDBASQL01\SEASDBASQL01_BASE_'
select @application = 'cws'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_filename		sysname
	,@error_count		int
	,@try_count		int
	,@cmd	 		nvarchar(2000)
	,@cmd2	 		nvarchar(2000)
	,@source_user		sysname
	,@source_pw		sysname
	,@hold_string		sysname
	,@newid 		sysname


----------------  initial values  -------------------
Select @error_count = 0
select @newid = convert(sysname, newid())


Select @save_servername	= @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


-- Create temp table
create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


create table #ESEresults(ESEoutput nvarchar(500) null)


--  Check input parms
if @application is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BaselineFile_moverESE.  @application is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


-- Set target path for '_BASE_' shares
If @target_path like ('%_')
   begin
	Select @target_path = @target_path + @application
   end


If @source_path like ('%_')
   begin
	Select @source_path = @source_path + @application
   end


--  Connect to the remote server share
If @target_path like '%seaexsqlmail%'
   begin
	Select @source_user = 'PRODUCTION\SQLTransSVCAcct'
   end
Else
   begin
	Select @source_user = 'stage\sqlnxtpusher'
   end


Select @hold_string  = 'pw_' + @source_user
Select @source_pw  = (select top 1 detail01 from dbo.local_control where subject = @hold_string)
If @source_pw is null or @source_pw = ''
   begin
	Select @miscprint = 'DBA ERROR: Password not found for ' + @source_user + '.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


--  Connect using net use command
select @cmd = 'net use ' + @target_path + ' /user:' + @source_user + ' ' + @source_pw
select @cmd2 = 'net use ' + @target_path + ' /user:' + @source_user + ' password_here'
print @cmd
exec master.sys.xp_cmdshell @cmd--, no_output


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid)
   begin
	insert into dbo.local_control values ('net_use', @target_path, @newid, '')
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


select @cmd = 'dir ' + rtrim(@source_path) + ' /B /A-D'
print @cmd
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
select * from #DirectoryTempTable


If (select count(*) from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) like '%File Not Found%') > 0
   begin
	Select @miscprint = 'DBA WARNING: dbasp_BaselineFile_moverESE - No files found for the requested Baseline file move process at ' + rtrim(@source_path) + rtrim(@application) + '.'
	--print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end

If (select count(*) from #DirectoryTempTable) > 0
   begin
	start_ESE:
	Select @save_filename = (select top 1 cmdoutput from #DirectoryTempTable order by cmdoutput)

	select @try_count = 0

	start_ESE2:
	select @cmd = 'del ' + @target_path + '\' + rtrim(@save_filename)
	Print @cmd
	raiserror('', -1,-1) with nowait
	exec master.sys.xp_cmdshell @cmd

	delete from #ESEresults
	select @cmd = 'eseutil.exe /y ' + rtrim(@source_path) + '\' + rtrim(@save_filename) + ' /d ' + @target_path + '\' + rtrim(@save_filename)
	Print @cmd
	raiserror('', -1,-1) with nowait
	insert into #ESEresults exec master.sys.xp_cmdshell @cmd
	select * from #ESEresults

	If not exists (select 1 from #ESEresults where ESEoutput like '%completed successfully%') and @try_count < 5
	   begin
		select @try_count = @try_count + 1
		goto start_ESE2
	   end


	--  check for more rows to process
	Delete from #DirectoryTempTable where cmdoutput = @save_filename
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto start_ESE
	   end
   end


-------------------   end   --------------------------


label99:


drop table #DirectoryTempTable
drop table #ESEresults


--  Disconnect the remote server connection
If exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid)
   begin
	delete from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid
   end


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path)
   begin
	select @cmd = 'net use /DELETE ' + @target_path
	print @cmd
	exec master.sys.xp_cmdshell @cmd--, no_output
   end


If @error_count > 0
   begin
	raiserror(@miscprint,-1,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_BaselineFile_moverESE] TO [public]
GO
