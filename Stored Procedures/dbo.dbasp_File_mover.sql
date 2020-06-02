SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_File_mover] ( @Remote_server sysname = null,
					@Remote_Domain sysname = null,
					@CopyFrom_path nvarchar(500) = null,
					@CopyTo_path nvarchar(500) = null,
					@filemask sysname = null,
					@file_ext sysname = null,
					@pre_delete_target char(1) = 'y')


/*********************************************************
 **  Stored Procedure dbasp_File_mover
 **  Written by Steve Ledridge, Virtuoso
 **  January 13, 2014
 **
 **  This procedure is used for copying files from one server,
 **  even if there is no domain trust relationship.
 **
 **  This proc accepts several input parms:
 **  - @Remote_server is the remote \\servername where files are being copied to or from.
 **  - @Remote_Domain is the domain where files are being copied to or from.
 **  - @CopyFrom_path is the path (share or folder name) where files are being copied from.
 **  - @CopyTo_path is the path where files are being copied to.
 **  - @filemask is the name pattern of the file to be copied.
 **  - @file_ext is the extention name for the file.
 **  - @pre_delete_target (y or n) will delete files at the target path that match the file mask.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/13/2014	Steve Ledridge		New process based on dbasp_BackupFile_mover.
--	01/31/2014	Steve Ledridge		Updated for local domain copies.
--	03/03/2014	Steve Ledridge		Fixed check for local domain in stage and prod.
--	======================================================================================


/***
Declare @Remote_server sysname
Declare @Remote_Domain sysname
Declare @CopyFrom_path nvarchar(500)
Declare @CopyTo_path nvarchar(500)
Declare @filemask sysname
Declare @file_ext sysname
Declare @pre_delete_target char(1)


select @Remote_server = '\\seadcpcsqla'
select @Remote_Domain = 'production'
select @CopyFrom_path = '\\seadcpcsqla\seadcpcsqla$a_backup\'
select @CopyTo_path = '\\SEAPSQLDPLY01\SEAPSQLDPLY01_restore\PC\'
select @filemask = 'MessageQueue_d*'
--Select @file_ext = 'cDIF'
Select @pre_delete_target = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@command 		nvarchar(512)
	,@source_user 		sysname
	,@source_pw 		sysname
	,@hold_string		sysname
	,@newid 		sysname
	,@syntax_out		varchar(max)
	,@hold_local_domain	sysname
	,@using_local_domain	char(1)
	,@save_domain		sysname


DECLARE
	 @Source		VarChar(max)
	,@Destination		VarChar(max)
	,@Data			XML


----------------  initial values  -------------------
Select @error_count = 0
Select @using_local_domain = 'n'


--  Check input parms
if @filemask is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_mover.  @filemask is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @Remote_server is null or @Remote_server = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover. @Remote_server is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @Remote_Domain is null or @Remote_Domain = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover. @Remote_Domain is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @CopyFrom_path is null or @CopyFrom_path = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover. @CopyFrom_path is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @CopyTo_path is null or @CopyTo_path = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover. @CopyTo_path is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


If @file_ext is not null and @file_ext <> ''
   begin
	Select @filemask = @filemask + '.' + @file_ext
   end


If rtrim(@CopyFrom_path) not like '%\'
   begin
	Select @CopyFrom_path = rtrim(@CopyFrom_path) + '\'
   end


If rtrim(@CopyTo_path) not like '%\'
   begin
	Select @CopyTo_path = rtrim(@CopyTo_path) + '\'
   end


Select @save_domain = (select env_detail from [dbo].[Local_ServerEnviro] where env_type = 'domain')


--  Set login and password
If @Remote_Domain = @save_domain
   begin
	Select @miscprint = 'DBA NOTE: Local domain processing.'
	Print @miscprint
   end
Else If @Remote_Domain = 'production'
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
Else If @Remote_Domain = 'stage'
   begin
	Select @source_user = 'stage\sqlnxtpusher'
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
Else
   begin
	Select @miscprint = 'DBA ERROR: Unable to process Unknown Domain.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


If ltrim(@Remote_server) not like '\\%'
   begin
	Select @Remote_server = '\\' + ltrim(@Remote_server)
   end


--  Check to see if we are staying in the same domain
Select @hold_local_domain = (select env_detail from [dbo].[Local_ServerEnviro] where env_type = 'domain')
Select @hold_local_domain = rtrim(@hold_local_domain)
If @hold_local_domain = @Remote_Domain
   begin
	Select @using_local_domain = 'y'
	goto net_use_skip01
   end


select @command = 'net use'
exec master.sys.xp_cmdshell @command--, no_output


--  Connect to the remote server share
select @command = 'net use ' + @Remote_server + ' /user:' + @source_user + ' xxxxx'
print @command
select @command = 'net use ' + @Remote_server + ' /user:' + @source_user + ' ' + @source_pw
--print @command
exec master.sys.xp_cmdshell @command--, no_output


select @newid = convert(sysname, newid())


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @Remote_server and Detail02 = @newid)
   begin
	insert into dbo.local_control values ('net_use', @Remote_server, @newid, '')
   end


select @command = 'net use'
exec master.sys.xp_cmdshell @command--, no_output


net_use_skip01:


/****************************************************************
 *                MainLine
 ***************************************************************/


Print 'File Mask is ' + @filemask
Print ''


If @pre_delete_target = 'y'
   begin
	--  Create XML for the delete process
	Select @Data = (
			SELECT		FullPathName [Source]
			FROM		dbo.dbaudf_DirectoryList2(@CopyTo_path,@filemask,0)
			FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess')
			)


	SET @syntax_out = [DBAOps].[dbo].[dbaudf_FormatXML2String](@Data)
	EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


	If @Data is not null
	   begin
		exec dbo.dbasp_FileHandler @Data
	   end


   end


--  Create XML for the copy process
;WITH		Settings
		AS
		(
		SELECT		32		AS [QueueMax]		-- Max Number of files coppied at once.
				,'false'	AS [ForceOverwrite]	-- true,false
				,1		AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
				,60		AS [UpdateInterval]	-- rate of progress updates in Seconds
		)
		,CopyFile -- MoveFile, DeleteFile
		AS
		(
		SELECT		FullPathName			AS [Source]
				,@CopyTo_path + Name		AS [Destination]
		FROM		dbo.dbaudf_DirectoryList2(@CopyFrom_path,@filemask,0)
		)
SELECT		@Data =	(
			SELECT *
				,(SELECT * FROM CopyFile FOR XML RAW ('CopyFile'), TYPE)
			FROM Settings
			FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
			)


SET @syntax_out = [DBAOps].[dbo].[dbaudf_FormatXML2String](@Data)
EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


If @Data is not null
   begin
	exec dbo.dbasp_FileHandler @Data
   end
Else
   begin
	Select @miscprint = 'DBA ERROR: XML being passed to dbo.dbasp_FileHandler is null.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


-------------------   end   --------------------------


--  Disconnect the remote server connection
If @using_local_domain = 'y'
   begin
	goto label99
   end


If exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @Remote_server and Detail02 = @newid)
   begin
	delete from dbo.local_control where subject = 'net_use' and Detail01 = @Remote_server and Detail02 = @newid
   end


If not exists(select * from dbo.local_control where subject = 'net_use' and Detail01 = @Remote_server)
   begin
	select @command = 'net use /DELETE ' + @Remote_server
	print @command
	exec master.sys.xp_cmdshell @command--, no_output
   end


label99:


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
GRANT EXECUTE ON  [dbo].[dbasp_File_mover] TO [public]
GO
