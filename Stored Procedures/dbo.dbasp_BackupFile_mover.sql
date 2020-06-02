SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupFile_mover] ( @Remote_server sysname = null,
					@Remote_Domain sysname = null,
					@DBname sysname = null,
					@CopyFrom_path nvarchar(500) = null,
					@CopyTo_path nvarchar(500) = null,
					@filemask sysname = null,
					@file_ext sysname = null,
					@pre_delete_target char(1) = 'y')


/*********************************************************
 **  Stored Procedure dbasp_BackupFile_mover
 **  Written by Steve Ledridge, Virtuoso
 **  January 13, 2014
 **
 **  This procedure is used for copying backup files from one server.
 **
 **  This proc accepts several input parms:
 **  - @Remote_server is the remote \\servername where files are being copied to or from.
 **  - @Remote_Domain is the domain where files are being copied to or from.
 **  - @DBname is the database name associated with the backup files that are being copied.
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
--	04/22/2014	Steve Ledridge		New process based on dbasp_File_mover.
--	05/20/2015	Steve Ledridge		Change AvailGrp to AGName.
--	======================================================================================


/***
Declare @Remote_server sysname
Declare @Remote_Domain sysname
Declare @DBname sysname
Declare @CopyFrom_path nvarchar(500)
Declare @CopyTo_path nvarchar(500)
Declare @filemask sysname
Declare @file_ext sysname
Declare @pre_delete_target char(1)


select @Remote_server = '\\seapcolbsql01.production.local'
select @Remote_Domain = 'production'
select @DBname = 'Collaboration'
select @CopyFrom_path = '\\seapcolbsql01.production.local\seapcolbsql01_backup\'
select @CopyTo_path = '\\SEAPSQLRPT02\SEAPSQLRPT02_restore\'
select @filemask = 'Collaboration_D*'
--Select @file_ext = 'cDIF'
Select @pre_delete_target = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd				varchar(8000)
	,@query				varchar(8000)
	,@charpos			int
	,@error_count			int
	,@command 			nvarchar(512)
	,@source_user 			sysname
	,@source_pw 			sysname
	,@hold_string			sysname
	,@newid 			sysname
	,@syntax_out			varchar(max)
	,@hold_local_domain		sysname
	,@using_local_domain		char(1)
	,@save_domain			sysname
	,@save_central_server		sysname
	,@db_query1			varchar(8000)
	,@db_query2			sysname
	,@pong_count			smallint
	,@save_rq_stamp			sysname
	,@save_FQDN			varchar(8000)
	,@process_FQDN			varchar(8000)
	,@current_server		varchar(8000)
	,@current_server_nonFQDN	varchar(8000)
	,@save_Directory		nvarchar(4000)


DECLARE
	 @Source			VarChar(max)
	,@Destination			VarChar(max)
	,@Data				XML


----------------  initial values  -------------------
Select @error_count = 0
Select @using_local_domain = 'n'


--  Creat temp table
declare @sourcefiles table (
			 FullPathName nvarchar(4000)
			 ,Directory nvarchar(4000)
			 ,name sysname
			 ,Extension sysname
			 ,DateCreated datetime)


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


--  Check to see if we are dealing with an AvailGrp DB
Select @save_central_server = (select env_detail from [dbo].[Local_ServerEnviro] where env_type = 'CentralServer')


--  Get FQDN's if there is an AvailGrp
If ltrim(@Remote_server) like '\\%'
   begin
	Select @Remote_server = substring(@Remote_server, 3, len(@Remote_server)-2)
   end


Select @save_rq_stamp = convert(sysname, getdate(), 121)
Select @db_query1 = ''
Select @db_query1 = @db_query1 + 'Set nocount on '
Select @db_query1 = @db_query1 + 'Declare @save_SQLname sysname '
Select @db_query1 = @db_query1 + 'Declare @save_AGName sysname '
Select @db_query1 = @db_query1 + 'Declare @listStr VARCHAR(MAX) '
Select @db_query1 = @db_query1 + 'Select @save_SQLname = (Select top 1 SQLname from DBAcentral.dbo.DBA_serverinfo where servername = ''''' + @Remote_server + ''''' or FQDN = ''''' + @Remote_server + ''''') '
Select @db_query1 = @db_query1 + 'If @save_SQLname is not null'
Select @db_query1 = @db_query1 + '  begin'
Select @db_query1 = @db_query1 + '    Select @save_AGName = (Select top 1 AGName from DBAcentral.dbo.DBA_DBinfo where SQLname = @save_SQLname and DBname = ''''' + @DBname + ''''')'
Select @db_query1 = @db_query1 + '    If @save_AGName is not null and @save_AGName <> '''''''''
Select @db_query1 = @db_query1 + '      begin'
Select @db_query1 = @db_query1 + '        Select @listStr = COALESCE(@listStr+'''','''' ,'''''''') + s.FQDN'
Select @db_query1 = @db_query1 + '        from DBAcentral.dbo.dba_serverinfo s'
Select @db_query1 = @db_query1 + '        inner join DBAcentral.dbo.dba_DBinfo d'
Select @db_query1 = @db_query1 + '                on s.SQLname = d.SQLname'
Select @db_query1 = @db_query1 + '        where d.DBname = ''''' + @DBname + ''''''
Select @db_query1 = @db_query1 + '        and s.DomainName = ''''' + @Remote_Domain + ''''''
Select @db_query1 = @db_query1 + '        and d.AGName = @save_AGName'
Select @db_query1 = @db_query1 + '      end '
Select @db_query1 = @db_query1 + '  end '
Select @db_query1 = @db_query1 + 'Select coalesce(@listStr, ''''none'''')'


Select @db_query2 = '@query_out sysname OUTPUT'
select @query = 'exec DBAOps.dbo.dbasp_pong @rq_servername = ''' + @@servername
	    + ''', @rq_stamp = ''' + @save_rq_stamp
	    + ''', @rq_type = ''db_query'', @rq_detail01 = ''' + @db_query1 + ''', @rq_detail02 = ''' + @db_query2 + ''''
Select @miscprint = 'Requesting Info from the central server'
Print @miscprint
Select @cmd = 'sqlcmd -S' + @save_central_server + ' -dDBAOps -E -Q"' + @query + '"'
print @cmd
EXEC master.sys.xp_cmdshell @cmd, no_output


--  capture pong results
select @pong_count = 0
start_pong_result01:
Waitfor delay '00:00:03'
If exists (select 1 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
   begin
	Select @save_FQDN = (select pong_detail01 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
   end
Else If @pong_count < 3
   begin
	Select @pong_count = @pong_count + 1
	goto start_pong_result01
   end


--Select @save_FQDN
If @save_FQDN = 'none'
   begin
	Select @save_FQDN = @Remote_server
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


Select @process_FQDN = @save_FQDN


Start_netuse_01:
Select @charpos = charindex(',', @process_FQDN)
IF @charpos <> 0
   begin
	select @current_server = substring(@process_FQDN, 1, @charpos-1)


	select @process_FQDN = substring(@process_FQDN, @charpos+1, len(@process_FQDN)-@charpos)
	select @process_FQDN = rtrim(ltrim(@process_FQDN))
   end
Else
   begin
	select @current_server = @process_FQDN
	select @process_FQDN = ''
   end


If ltrim(@current_server) not like '\\%'
   begin
	Select @current_server = '\\' + ltrim(@current_server)
   end


--  Connect to the remote server share
select @command = 'net use ' + @current_server + ' /user:' + @source_user + ' xxxxx'
print @command
select @command = 'net use ' + @current_server + ' /user:' + @source_user + ' ' + @source_pw
--print @command
exec master.sys.xp_cmdshell @command--, no_output


select @newid = convert(sysname, newid())


If not exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @current_server and Detail02 = @newid)
   begin
	insert into dbo.local_control values ('net_use', @current_server, @newid, '')
   end


If len(@process_FQDN) > 0
   begin
	goto Start_netuse_01
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


--  Load the temp table
Select @process_FQDN = @save_FQDN


Start_load_01:
Select @charpos = charindex(',', @process_FQDN)
IF @charpos <> 0
   begin
	select @current_server = substring(@process_FQDN, 1, @charpos-1)


	select @process_FQDN = substring(@process_FQDN, @charpos+1, len(@process_FQDN)-@charpos)
	select @process_FQDN = rtrim(ltrim(@process_FQDN))
   end
Else
   begin
	select @current_server = @process_FQDN
	select @process_FQDN = ''
   end


Select @charpos = charindex('.', @current_server)
IF @charpos <> 0
   begin
	select @current_server_nonFQDN = substring(@current_server, 1, @charpos-1)
   end
Else
   begin
	select @current_server_nonFQDN = @current_server
   end


If ltrim(@current_server) not like '\\%'
   begin
	Select @current_server = '\\' + ltrim(@current_server)
   end


Select @current_server = @current_server + '\' + @current_server_nonFQDN + '_backup\'


Insert into @sourcefiles
		SELECT		FullPathName
				,Directory
				,Name
				,Extension
				,DateCreated
		FROM		dbo.dbaudf_DirectoryList2(@current_server,@filemask,0)


If len(@process_FQDN) > 0
   begin
	goto Start_load_01
   end


--  Weed out @sourcefiles


-- BAK files
Select @save_Directory = ''
Select @save_Directory = (select top 1 Directory from @sourcefiles where Extension like '%BAK%' order by DateCreated DESC)


If @save_Directory is not null and @save_Directory <> ''
   begin
	Delete from @sourcefiles where Extension like '%BAK%' and Directory <> @save_Directory
   end


-- DIF files
Select @save_Directory = ''
Select @save_Directory = (select top 1 Directory from @sourcefiles where Extension like '%DIF%' order by DateCreated DESC)


If @save_Directory is not null and @save_Directory <> ''
   begin
	Delete from @sourcefiles where Extension like '%DIF%' and Directory <> @save_Directory
   end


--TRN files
Select @save_Directory = ''
Select @save_Directory = (select top 1 Directory from @sourcefiles where Extension like '%TRN%' order by DateCreated DESC)


If @save_Directory is not null and @save_Directory <> ''
   begin
	Delete from @sourcefiles where Extension like '%TRN%' and Directory <> @save_Directory
   end


--select * from @sourcefiles


--  Create XML for the copy process
;WITH		Settings
		AS
		(
		SELECT		32		AS [QueueMax]		-- Max Number of files coppied at once.
				,'false'	AS [ForceOverwrite]	-- true,false
				,1		AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
				,30		AS [UpdateInterval]	-- rate of progress updates in Seconds
		)
		,CopyFile -- MoveFile, DeleteFile
		AS
		(
		SELECT		FullPathName			AS [Source]
				,@CopyTo_path + Name		AS [Destination]
		FROM		@sourcefiles
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


Select @process_FQDN = @save_FQDN


Start_netuse_99:
Select @charpos = charindex(',', @process_FQDN)
IF @charpos <> 0
   begin
	select @current_server = substring(@process_FQDN, 1, @charpos-1)


	select @process_FQDN = substring(@process_FQDN, @charpos+1, len(@process_FQDN)-@charpos)
	select @process_FQDN = rtrim(ltrim(@process_FQDN))
   end
Else
   begin
	select @current_server = @process_FQDN
	select @process_FQDN = ''
   end


If ltrim(@current_server) not like '\\%'
   begin
	Select @current_server = '\\' + ltrim(@current_server)
   end


If exists(select 1 from dbo.local_control where subject = 'net_use' and Detail01 = @current_server)
   begin
	delete from dbo.local_control where subject = 'net_use' and Detail01 = @current_server


	select @command = 'net use /DELETE ' + @current_server
	print @command
	exec master.sys.xp_cmdshell @command--, no_output
   end


If len(@process_FQDN) > 0
   begin
	goto Start_netuse_99
   end


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupFile_mover] TO [public]
GO
