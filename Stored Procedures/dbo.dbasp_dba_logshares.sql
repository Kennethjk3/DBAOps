SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_dba_logshares]


/**************************************************************
 **  Stored Procedure dbasp_dba_logshares
 **  Written by Steve Ledridge, Virtuoso
 **  April 24, 2012
 **
 **  This dbasp is set up to create standard shares for
 **  the main SQL log folder and a sub-folder named sql_joblogs.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/24/2012	Steve Ledridge		New process (cloned from dbasp_dba_sqlsetup).
--	07/17/2012	Steve Ledridge		Modified _SQLjob_logs folder & share to be on the same drive as the _backup Share
--						-- _backup Share Must Exist before running this.
--	03/03/2015	Steve Ledridge		If backup share doesn't exist, _SQLjob_logs will be under the log share.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint				nvarchar(4000)
	,@command 				nvarchar(4000)
	,@dos_command				varchar(500)
	,@result				int
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_sqlinstance			sysname
	,@save_domain				sysname
	,@save_envname				sysname
	,@charpos				int
	,@fileexist_path			sysname
	,@path_log				sysname
	,@path_SQLjob_logs			sysname
	,@found_SQLjob_logs_fol			char(1)
	,@found_log_shr				char(1)
	,@found_SQLjob_logs_shr			char(1)
	,@isNMinstance				char(1)
	,@in_key				sysname
	,@in_path				sysname
	,@in_value				sysname
	,@result_value				nvarchar(500)
	,@ShareResType				nvarchar(500)
	,@share_name				varchar	(100)
	,@BackupPath				VarChar	(8000)
	,@LogPath				VarChar	(8000)
	,@SQLjob_logsPath			VarChar	(8000)


----------------  initial values  -------------------
Select
	@ShareResType			= 'File Share'
	,@found_SQLjob_logs_fol		= 'n'
	,@found_log_shr			= 'n'
	,@found_SQLjob_logs_shr		= 'n'


-- Set variables ---------------------------------------------------------------------------
Select @save_sqlinstance	= 'mssqlserver'
Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @isNMinstance		= 'n'


Create table #ShareTempTable(path nvarchar(500) null)


Create table #loginconfig(name1 sysname null, config_value sysname null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


declare @filenames table (fname		sysname)


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
	Select @isNMinstance = 'y'
   end


Select @share_name =  REPLACE(@@SERVERNAME,'\','$') + '_log'
EXEC DBAOps.dbo.dbasp_get_share_path @share_name = @share_name, @phy_path = @LogPath OUT


Select @share_name =  REPLACE(@@SERVERNAME,'\','$') + '_SQLjob_logs'
EXEC DBAOps.dbo.dbasp_get_share_path @share_name = @share_name, @phy_path = @SQLjob_logsPath OUT


--  If the log share and the SQLjob_logs share both exist, skip this process
IF @LogPath IS NOT NULL and @SQLjob_logsPath IS NOT NULL
   begin
	Select @miscprint = 'DBA Note:: Both the log share and the SQLjob_logs share exist.  This process (dbasp_dba_logshares) will be skipped.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
	Print  ' '
   end


Select @share_name =  REPLACE(@@SERVERNAME,'\','$') + '_backup'
EXEC DBAOps.dbo.dbasp_get_share_path @share_name = @share_name, @phy_path = @BackupPath OUT
--  Make sure the user has admin privileges
IF @BackupPath IS NULL
   begin
	Select @miscprint = 'WARNING: _backup share does not Exist.'
	Print  @miscprint
	Select @miscprint =  '	' + QUOTENAME(@share_name,'"') + ' Is not currently a valid share.'
	Print  @miscprint
	Print  ' '
	--Select @miscprint = 'Nothing was done.'
	--Print  @miscprint
	--goto label99
   end


--  Make sure the user has admin privileges
IF (not is_srvrolemember(N'sysadmin') = 1)
   begin
	Select @miscprint = 'ERROR: Current user does not have sufficient privileges to run this process.'
	Print  @miscprint
	Select @miscprint = '       Must have local admin privileges on the server.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end


--  Get the domain name and save it (Note:  We have to strip off the last byte from config_value because it's not printable)
If @isNMinstance = 'n'
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\MSSQLServer'
	select @in_value = 'ObjectName'
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end
Else
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'System\CurrentControlSet\Services\MSSQL$' + @save_sqlinstance
	select @in_value = 'ObjectName'
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


Select @save_domain = @result_value
Select @save_envname = @result_value


print @save_domain
print @save_envname


Select @charpos = charindex('\', @save_domain)
IF @charpos <> 0
   begin
	Select @save_domain = substring(@save_domain, 1, (CHARINDEX('\', @save_domain)-1))
	Select @save_envname = rtrim(substring(@save_envname, @charpos+1, 100))
	goto get_domain_end
   end


Select @charpos = charindex('@', @save_domain)
IF @charpos <> 0
   begin
	Select @save_domain = substring(@save_domain, @charpos+1, (CHARINDEX('.', @save_domain)-1)-@charpos)
	Select @save_envname = rtrim(substring(@save_envname, 1, @charpos-1))
	goto get_domain_end
   end


Insert into #loginconfig exec master.dbo.xp_loginconfig 'default domain'
Select @save_domain = config_value from #loginconfig


get_domain_end:


--  Reformat the service account name if needed (remove the @Virtuoso...)
Select @charpos = charindex('@', @save_envname)
IF @charpos <> 0
   begin
	Select @save_envname = substring(@save_envname, 1, @charpos-1)
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Get the path to the SQL log folder (s\b at the same level as the data folder which holds the master mdf)
select @path_log = filename from master.sys.sysfiles where name = 'master'


Select @charpos = charindex('\data\master.mdf', @path_log)
Select @path_log = substring(@path_log, 1, (@charpos - 1))
Select @path_log = @path_log + '\log'


If @BackupPath is null
   begin
	SELECT @path_SQLjob_logs = @path_log + '\SQLjob_logs' + REPLACE('$'+@@SERVICENAME,'$MSSQLSERVER','')
   end
Else
   begin
	SELECT @path_SQLjob_logs = Left(@BackupPath,2) + '\SQLjob_logs' + REPLACE('$'+@@SERVICENAME,'$MSSQLSERVER','')
   end


--  Check to see if the 'log' folder exists.  If not, error out
Delete from #fileexists
Select @fileexist_path = @path_log + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 0
   begin
	Select @miscprint = 'ERROR: Path to the ''log'' folder could not be found.  ' + @path_log
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end


--  Check to see if the 'SQLjob_logs' folder exists
Delete from #fileexists
Select @fileexist_path = @path_SQLjob_logs + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_SQLjob_logs_fol = 'y'
   end


--  Create the folders as needed


If @found_SQLjob_logs_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_SQLjob_logs + '"'
	Print 'Creating SQLjob_logs folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


Print ' '
Print 'Standard folders are in place'
Print ' '


Select @path_SQLjob_logs = '"' + @path_SQLjob_logs + '"'
Select @path_log = '"' + @path_log + '"'


--  Check to see if standard shares have already been set up
Delete from #ShareTempTable
Select @command = 'RMTSHARE \\' + @save_servername
Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
delete from #ShareTempTable where path is null or path = ''


--select * From #ShareTempTable


If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_log%')
   begin
	Select @found_log_shr = 'y'
   end
If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_SQLjob_logs%')
   begin
	Select @found_SQLjob_logs_shr = 'y'
   end


--  If any standard shares are found, delete them (we will recreate them)
If @found_log_shr = 'y'
   begin
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_log /DELETE'
	Print 'Deleting the ' + @save_servername2 + '_log share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end
ELSE
   begin
	PRINT '	- The ' + @save_servername2 + '_log share does not exist.'
   end


Print ' '


If @found_SQLjob_logs_shr = 'y'
   begin
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs /DELETE'
	Print 'Deleting the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end
ELSE
   begin
	PRINT '	- The ' + @save_servername2 + '_SQLjob_logs share does not exist.'
   end


Print ' '
Print ' '
Print 'Existing Standard shares have been deleted'
Print ' '


--  Check to see if the standard Local Groups have been created
Delete from #ShareTempTable
Select @command = 'net localgroup "' + @save_servername2 + '_SQL_Local_Read"'
Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
If exists (select * from #ShareTempTable where path like '%cannot be found%' or path like '%does not exist%' or path like '%System error 1788%')
   begin
	Select @dos_command = 'net localgroup "' + @save_servername2 + '_SQL_Local_Read" /add /COMMENT:"SQL Local Read group"'
	Print 'Creating the ' + @save_servername2 + '_SQL_Local_Read local group using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


Delete from #ShareTempTable
Select @command = 'net localgroup "' + @save_servername2 + '_SQL_Local_Write"'
Insert into #ShareTempTable exec master..xp_cmdshell @command
If exists (select * from #ShareTempTable where path like '%cannot be found%' or path like '%does not exist%' or path like '%System error 1788%')
   begin
	Select @dos_command = 'net localgroup "' + @save_servername2 + '_SQL_Local_Write" /add /COMMENT:"SQL Local Write group"'
	Print 'Creating the ' + @save_servername2 + '_SQL_Local_Write local group using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


Print ' '
Print ' '


--  Create the shares, and share security, for log
Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_log =' + @path_log + ' /unlimited'
Print 'Creating the ' + @save_servername2 + '_log share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_log /grant administrators:f'
Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_log share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_log /Remove everyone'
Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_log share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'XCACLS ' + @path_log + ' /G administrators:F /Y'
Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_log share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'XCACLS ' + @path_log + ' /E /G system:R /Y'
Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_log share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Print ' '


--  Create the shares, and share security, for SQLjob_logs
Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs =' + @path_SQLjob_logs + ' /unlimited'
Print 'Creating the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs /grant administrators:f'
Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs /grant "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":r'
Print 'Assign READ ONLY Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs /Remove everyone'
Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /G administrators:F /Y'
Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G system:R /Y'
Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":R /Y'
Print 'Assign READ ONLY NTFS Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


Print ' '


Print ' '
Print ' '
Print 'Standard shares, including folder and NTFS security, are in place'
Print ' '


----------------  End  -------------------


label99:


drop table #ShareTempTable
drop table #loginconfig
drop table #fileexists


Print ' '
Print 'Processing for dbasp_dba_logshares - complete'
Print ' '
GO
GRANT EXECUTE ON  [dbo].[dbasp_dba_logshares] TO [public]
GO
