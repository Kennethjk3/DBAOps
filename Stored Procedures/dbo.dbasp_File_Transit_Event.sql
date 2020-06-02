SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_File_Transit_Event] (@target_env sysname = null
				,@target_server sysname = null
				,@target_SQLserver sysname = null
				,@Fail_replyto sysname = 'DBANotify@${{secrets.DOMAIN_NAME}}'
				,@SQLcode nvarchar(max) = '')


/*********************************************************
 **  Stored Procedure dbasp_File_Transit_Event
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 26, 2008
 **
 **  This procedure is used to create an action event from one Domain
 **  to another where there is no trust relationship.  This will
 **  create and output file (*.act) that will be copied to the target
 **  domain and processed by the central SQL server in that domain.
 **
 **  This proc accepts the following input parms:
 **  - @target_env is the environment where the action event will take place.
 **  - @target_server is the server the action is intended for.
 **  - @target_SQLserver is SQL server the the action is intended for.
 **  - @Fail_replyto is the email address the process will reply to if the target server is unavailable.
 **  - @SQLcode is the code to be executed as the action event (start job, etc.).
 ***************************************************************/
  as
  SET NOCOUNT ON


--	=====================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/26/2008	Steve Ledridge		New process
--	09/15/2009	Steve Ledridge		Convert DBAOpser04 to seafresqldba01.
--	03/16/2010	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply05.
--	09/13/2011	Steve Ledridge		Convert seafresqldba01 to seapsqldba01.
--	06/18/2012	Steve Ledridge		Changed central server seapsqldply05 to DBAOpser04.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	04/16/2014	Steve Ledridge		Changed seapsqldba01 to seapdbasql01.
--	05/01/2014	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply04.
--	=====================================================================================


/***
Declare @target_env sysname
Declare @target_server sysname
Declare @target_SQLserver sysname
Declare @Fail_replyto sysname
Declare @SQLcode nvarchar(max)


Select @target_env = 'production'
Select @target_server = 'g1sqla'
Select @target_SQLserver = 'g1sqla$a'
Select @Fail_replyto = 'DBANotify@${{secrets.DOMAIN_NAME}}'
Select @SQLcode = 'use master
exec sp_who2
go


--comments


xp_fixeddrives
go'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@cmd	 		nvarchar(4000)
	,@retcode 		int
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@savefilename		nvarchar(500)
	,@save_domain_name	sysname
	,@save_central_server	sysname
	,@save_fullpath		nvarchar(500)
	,@save_depart_path	nvarchar(500)
	,@DateStmp 		char(14)
	,@Hold_hhmmss		varchar(8)
	,@out_filename		nvarchar(2000)
	,@hold_SQLcode		nvarchar(4000)


----------------  initial values  -------------------
Select @error_count = 0
select @save_domain_name = env_detail from dbo.Local_ServerEnviro where env_type = 'domain'


select @save_central_server = env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer'
If @save_central_server = 'seapsqldply04'
   begin
	select @save_central_server = 'seapdbasql01'
   end


Select @save_depart_path = '\\' + rtrim(@save_central_server) + '\' + 'Station_' + rtrim(@save_domain_name) + '_Depart'


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


create table #DirectoryTempTable(cmdoutput nvarchar(500) null)


create table #fileexists (
	doesexist smallint,
	fileindir smallint,
	direxist smallint)


--  Check input parms
if @target_env is null or @target_env not in ('production', 'stage', 'amer')
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @target_env is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_server is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @target_server is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_SQLserver is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @target_SQLserver is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @Fail_replyto is null or @Fail_replyto not like '%@%'
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @Fail_replyto is invalid.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @SQLcode is null or @SQLcode = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. No action found in @SQLcode input parm.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


--  Set file name
Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @DateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


Select @savefilename = rtrim(@target_env) + '_x_' + rtrim(@target_server) + '_y_' + rtrim(@target_SQLserver) + '_z_' + rtrim(@DateStmp) + '.actn'


--  Make sure the file does not alreay exist at the station depart folder
Delete from #fileexists
Select @save_fullpath = rtrim(@save_depart_path) + '\' + rtrim(@savefilename)
Insert into #fileexists exec master.sys.xp_fileexist @save_fullpath
--select * from #fileexists


If (select top 1 doesexist from #fileexists) = 1 or (select top 1 fileindir from #fileexists) = 1
   begin
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit - File already exists in the central depart folder. ' + rtrim(@savefilename)
	print @miscprint
	Select @error_count = @error_count + 1
	goto label99
  end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Create the output file
Select @out_filename = '\\' + @save_servername + '\DBASQL\dba_reports\' + @savefilename
Print  ' '
Select @cmd = 'copy nul ' + @out_filename
Print @cmd
EXEC master.sys.xp_cmdshell @cmd, no_output


Select @cmd = 'echo @Fail_replyto = "' + @Fail_replyto + '">>' + @out_filename
Print @cmd
EXEC master.sys.xp_cmdshell @cmd, no_output


If @SQLcode like '%' + CHAR(13)+CHAR(10) + '%'
   begin
	Select @cmd = 'echo @SQLcode = _x_>>' + @out_filename
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	SQLcode_loop:
	Select @charpos = charindex(CHAR(13)+CHAR(10), @SQLcode)
	IF @charpos <> 0
	   begin
		Select @hold_SQLcode = left(@SQLcode, @charpos-1)
		Select @SQLcode = substring(@SQLcode, @charpos+2, len(@SQLcode)-@charpos+2)


		If @hold_SQLcode <> ''
		   begin
			Select @cmd = 'echo ' + @hold_SQLcode + '>>' + @out_filename
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output
		   end
	   end


	If @SQLcode like '%' + CHAR(13)+CHAR(10) + '%'
	   begin
		goto SQLcode_loop
	   end


	Select @cmd = 'echo ' + @SQLcode + '_y_>>' + @out_filename
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end
Else
   begin
	Select @cmd = 'echo @SQLcode = _x_' + @SQLcode + '_y_>>' + @out_filename
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end


select @cmd = 'robocopy /Z /R:3 /MOV "' + '\\' + @save_servername + '\DBASQL\dba_reports' + '" "' + @save_depart_path + '" "' + rtrim(@savefilename) + '"'
Print @cmd
EXEC @retcode = master.sys.xp_cmdshell @cmd--, no_output
print @retcode


-------------------   end   --------------------------


label99:


drop table #DirectoryTempTable
drop table #fileexists


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
GRANT EXECUTE ON  [dbo].[dbasp_File_Transit_Event] TO [public]
GO
