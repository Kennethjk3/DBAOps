SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BaselineFile_mover] ( @source_path nvarchar(500) = '\\DBAOpser03\DBAOpser03_BASE_'
				,@target_path nvarchar(500) = '\\10.207.130.149\SEASDBASQL01_BASE_'
				,@application sysname = null
				,@filename_mask sysname = null
				,@extension sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_BaselineFile_mover
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 17, 2004
 **
 **  This procedure is used for copying baseline files from one server
 **  to another where there is no trust relationship.
 **
 **  This proc accepts four input parms:
 **  - @source_path is the path where files are being copied from.
 **  - @target_path is the path where files are being copied to.
 **  - @application is the name of application folder where the files exist.
 **  - @extension is the file extension to be processed (BAK or *nxt).
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/16/2004	Steve Ledridge		New process
--	10/25/2005	Steve Ledridge		New account for stage and new parm to skip
--						creating the target application folder.
--	11/30/2006	Steve Ledridge		New share name for baseline files (_BASE_).
--	01/22/2007	Steve Ledridge		Fixed @target_path for (_BASE_) targets.
--	03/06/2007	Steve Ledridge		Moved code for fixing @target_path for (_BASE_) targets.
--	03/06/2007	Steve Ledridge		Updated for sql 2005.
--	06/22/2007	Steve Ledridge		New code for server_db_list file copy.
--	08/07/2007	Steve Ledridge		Fixed 'net use to target' command.
--	02/12/2008	Steve Ledridge		Added 'net use' for source command.
--	09/16/2008	Steve Ledridge		seafresqldba02 to seafresqldba01.
--	10/24/2008	Steve Ledridge		Removed passwords.
--	11/17/2008	Steve Ledridge	        Removed passwords from print out. Eliminated
--                                              net use of "@source_path" as not needed.
--	03/26/2009	Steve Ledridge		Check local_control table before deleting net use connection.
--	08/11/2009	Steve Ledridge		Updated IP for seafrestgsql.
--	11/19/2009	Steve Ledridge		New code for specific file transfer.
--	05/18/2010	Steve Ledridge		Changed retry to 30.
--	06/02/2010	Steve Ledridge		Changed seafrestgsql to fresdbasql01.
--	07/24/2013	Steve Ledridge		Added pre * for filename mask.
--	09/03/2013	Steve Ledridge		Changed fresdbasql01 to seasdbasql01.
--	10/07/2013	Steve Ledridge		Changed seaexsqlmail to seapdbasql02.
--	======================================================================================


/***
Declare @source_path nvarchar(500)
Declare @target_path nvarchar(500)
Declare @application sysname
Declare @filename_mask sysname
Declare @extension sysname


select @source_path = '\\DBAOpsER01\DBAOpsER01_BASE_'
select @target_path = '\\SEASDBASQL01\SEASDBASQL01_BASE_'
select @application = 'DW'
select @filename_mask = 'MercuryDM_prod'
Select @extension = 'sqb'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@error_count		int
	,@command 		nvarchar(512)
        ,@command2		nvarchar(512)
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


--  Check input parms
if @application is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BaselineFile_mover.  @application is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @extension is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BaselineFile_mover.  @extension is required'
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
If @target_path like '%seapdbasql02%'
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
select @command = 'net use ' + @target_path + ' /user:' + @source_user + ' ' + @source_pw
select @command2 = 'net use ' + @target_path + ' /user:' + @source_user + ' password_here'
print @command2
exec master.sys.xp_cmdshell @command--, no_output


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid)
   begin
	insert into dbo.local_control values ('net_use', @target_path, @newid, '')
   end


/****************************************************************
 *                MainLine
 ***************************************************************/

If @application = 'DBAOps_scriptserverlist'
   begin
    select @command = 'robocopy /Z /R:30 ' + @source_path + ' ' + @target_path + ' ' + @application + '*.' + rtrim(@extension)
    Print @command
    exec master.sys.xp_cmdshell @command
   end
Else If @filename_mask is not null and @filename_mask <> ''
   begin
    select @command = 'robocopy /Z /R:30 ' + @source_path + ' ' + @target_path + ' *' + @filename_mask + '*.' + rtrim(@extension)
    Print @command
    exec master.sys.xp_cmdshell @command
   end
Else
   begin
    select @command = 'robocopy /Z /R:30 ' + @source_path + ' ' + @target_path + ' *.' + rtrim(@extension)
    Print @command
    exec master.sys.xp_cmdshell @command
   end


-------------------------
-- Post copy verification
-------------------------


--  first, check to see how many files should have been copied


--  second, check to make sure all those files are now at the target (match name and date)


--  Last, make sure no matching files at the target have a date of 1/1/1980


-------------------   end   --------------------------


label99:


--  Disconnect the remote server connection
If exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid)
   begin
	delete from dbo.local_control where subject = 'net_use' and Detail01 = @target_path and Detail02 = @newid
   end


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @target_path)
   begin
	select @command = 'net use /DELETE ' + @target_path
	print @command
	exec master.sys.xp_cmdshell @command--, no_output
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
GRANT EXECUTE ON  [dbo].[dbasp_BaselineFile_mover] TO [public]
GO
