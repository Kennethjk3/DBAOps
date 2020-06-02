SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_create_NXTshare] (@path_nxt nvarchar(250) = NULL
					,@path_base nvarchar(250) = NULL
					,@delete_flag char(1) = 'n')


/**************************************************************
 **  Stored Procedure dbasp_create_NXTshare
 **  Written by Steve Ledridge, Virtuoso
 **  October 10, 2005
 **
 **  This dbasp is set up to create the NXT and BASE shares, which
 **  are used as part of the SQL deployment process.  The NXT share
 **  will allow for local storage of the *.mdfnxt files and the BASE
 **  share will hold the local baseline backup files.
 **
 **  NOTE:  These shares should not be configured on Production Servers!
 **
 **  To execute this sproc, the path to the desired location for
 **  the NXT folder and the BASE folder may be provided as input.
 **  If the path is not specified, the NXT folder will be created
 **  at the root directory on the drive that holds the MDF share
 **  and the BASE folder will be created on the drive that holds
 **  the backup share.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/10/2005	Steve Ledridge		New SQL setup process.
--	06/14/2010	Steve Ledridge		Major re-write.  Added BASE folder and share.
--	07/12/2010	Steve Ledridge		Fixed bug related to sql 2008 in a cluster.
--	======================================================================================


/***
Declare @path_nxt varchar(250)
Declare @path_base varchar(250)
Declare @delete_flag char(1)


--Select @path_nxt = 'g:\Backup'
--Select @path_base = 'g:\Backup'
Select @delete_flag = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@command 			nvarchar(4000)
	,@dos_command			varchar(500)
	,@result			int
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_sqlinstance		sysname
	,@save_domain			sysname
	,@save_envname			sysname
	,@charpos			int
	,@save_drive_letter_part	char(2)
	,@save_data2			nvarchar(4000)
	,@save_disk_resname		sysname
	,@save_group_resname		sysname
	,@save_network_resname		sysname
	,@fileexist_path		sysname
	,@found_nxt_fol			char(1)
	,@found_base_fol		char(1)
	,@found_nxt_shr			char(1)
	,@found_base_shr		char(1)
	,@save_iscluster		char(1)
	,@isNMinstance			char(1)
	,@in_key			sysname
	,@in_path			sysname
	,@in_value			sysname
	,@result_value			nvarchar(500)


----------------  initial values  -------------------
Select
	 @found_nxt_fol			= 'n'
	,@found_base_fol		= 'n'
	,@found_nxt_shr			= 'n'
	,@found_base_shr		= 'n'


-- Set variables ---------------------------------------------------------------------------
Select @save_sqlinstance = 'mssqlserver'
Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @isNMinstance = 'n'


Create table #ShareTempTable(path nvarchar(500) null)


Create table #loginconfig(name1 sysname null, config_value sysname null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #cluster_info1 (data1 nvarchar(4000))
Create table #cluster_info2 (data2 nvarchar(4000))


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
	Select @isNMinstance = 'y'
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


--  Capture Cluster (y/n)
If (SERVERPROPERTY('IsClustered')) = 0
   begin
	Select @save_iscluster = 'n'
   end
Else
   begin
	Select @save_iscluster = 'y'
	Select @command = 'cluster . res /prop'
	--Print @command
	Insert into #cluster_info1 exec master.sys.xp_cmdshell @command
	delete from #cluster_info1 where data1 is null
	delete from #cluster_info1 where rtrim(data1) = ''
--Select * from #cluster_info1


	Select @command = 'cluster . res /status'
	--Print @command
	Insert into #cluster_info2 exec master.sys.xp_cmdshell @command
	delete from #cluster_info2 where data2 is null
	delete from #cluster_info2 where rtrim(data2) = ''
	delete from #cluster_info2 where rtrim(data2) like '%Listing status%'
--Select * from #cluster_info2
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print Headers
Print 'Starting NXT and BASE share creation process'
Print '============================================'


--  Check input parm and if the @nxt_path input parm is null, find the path to the backup share.
If @path_nxt is null or @path_nxt = ''
   begin
	Delete from #ShareTempTable
	Select @command = 'RMTSHARE \\' + @save_servername
	Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
	delete from #ShareTempTable where path is null
	delete from #ShareTempTable where path not like @save_servername2 + '%'
	--select * from #ShareTempTable

	If (select count(*) from #ShareTempTable) > 0
	   begin
		Select @path_nxt = (select Top 1 path from #ShareTempTable where path like @save_servername2 + '_mdf%' order by path)


		Select @charpos = charindex(':\', @path_nxt)
		IF @charpos <> 0
		   begin
			Select @path_nxt = Substring(@path_nxt, @charpos-1, 1)
		   end
		Else
		   begin
			Select @miscprint = 'ERROR: MDF share path could not be found.  This process cannot run if the standard MDF share is not in place.'
			Print  @miscprint
			Print  ' '
			Select @miscprint = 'Nothing was done.'
			Print  @miscprint
			goto label99
		   end


		Select @path_nxt = @path_nxt + ':\nxt'
		If @isNMinstance = 'y'
		   begin
			Select @path_nxt = @path_nxt + '$' + @save_sqlinstance
		   end


 		Select @path_base = (select Top 1 path from #ShareTempTable where path like @save_servername2 + '_backup%' order by path)


		Select @charpos = charindex(':\', @path_base)
		IF @charpos <> 0
		   begin
			Select @path_base = Substring(@path_base, @charpos-1, 1)
		   end
		Else
		   begin
			Select @miscprint = 'ERROR: Backup share path could not be found.  This process cannot run if the standard Backup share is not in place.'
			Print  @miscprint
			Print  ' '
			Select @miscprint = 'Nothing was done.'
			Print  @miscprint
			goto label99
		   end

		Select @path_base = @path_base + ':\BASE'
		If @isNMinstance = 'y'
		   begin
			Select @path_base = @path_base + '$' + @save_sqlinstance
		   end
	   end
   end


--  If the @nxt_path is still null, error out.
If @path_nxt is null
   begin
	Select @miscprint = 'ERROR: MDF share path could not be found.  This process cannot run if the standard MDF share is not in place.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end

--  If the @BASE_path is still null, error out.
If @path_nxt is null
   begin
	Select @miscprint = 'ERROR: Backup path could not be found.  This process cannot run if the standard backup share is not in place.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end


--  Check to see if the 'nxt' folder exists
Delete from #fileexists
Select @fileexist_path = @path_nxt + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_nxt_fol = 'y'
   end


--  Check to see if the 'base' folder exists
Delete from #fileexists
Select @fileexist_path = @path_base + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_base_fol = 'y'
   end


If @save_envname not like '%prod%' and @found_nxt_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_nxt + '"'
	Print 'Creating nxt folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @save_envname not like '%prod%' and @found_base_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_base + '"'
	Print 'Creating base folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


Print ' '
Print 'Standard folders are in place'
Print ' '


Select @path_nxt = '"' + @path_nxt + '"'
Select @path_base = '"' + @path_base + '"'


If @save_iscluster = 'n' or @@VERSION like 'Microsoft SQL Server 2008%'
   begin
	--  Check to see if standard shares have already been set up
	Delete from #ShareTempTable
	Select @command = 'RMTSHARE \\' + @save_servername
	Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
	delete from #ShareTempTable where path is null or path = ''
	--select * from #ShareTempTable

	If exists (select 1 from #ShareTempTable where path like @save_servername2 + '_nxt%')
	   begin
		Select @found_nxt_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like @save_servername2 + '_base%')
	   begin
		Select @found_base_shr = 'y'
	   end


	--  If any standard shares are found, delete if requested and we will recreate them
	If @found_nxt_shr = 'y' and @delete_flag = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_nxt /DELETE'
		Print 'Deleting the ' + @save_servername + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
		Print 'Existing Standard share has been deleted'
		Print ' '
		Select @found_nxt_shr = 'n'
	   end


	If @found_base_shr = 'y' and @delete_flag = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_base /DELETE'
		Print 'Deleting the ' + @save_servername + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
		Print 'Existing Standard share has been deleted'
		Print ' '
		Select @found_base_shr = 'n'
	   end


	--  Create the shares, and share security, for nxt
	If @save_envname not like '%prod%' and @found_nxt_shr = 'n'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_nxt =' + @path_nxt + ' /unlimited'
		Print 'Creating the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_nxt /grant administrators:f'
		Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_nxt /Remove everyone'
		Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /G administrators:F /Y'
		Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G system:R /Y'
		Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	--  Create the shares, and share security, for base
	If @save_envname not like '%prod%' and @found_base_shr = 'n'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_base =' + @path_base + ' /unlimited'
		Print 'Creating the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_base /grant administrators:f'
		Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_base /Remove everyone'
		Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /G administrators:F /Y'
		Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G system:R /Y'
		Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	Print ' '
	Print ' '
	Print 'Standard shares, including folder and NTFS security, are in place'
	Print ' '
   end
Else
   begin
	--  Check to see if standard shares have already been set up
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_nxt%')
	   begin
		Select @found_nxt_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_base%')
	   begin
		Select @found_base_shr = 'y'
	   end


	--  If any standard shares are found, delete them if requested and we will recreate them.
	If @found_nxt_shr = 'y' and @delete_flag = 'n'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_nxt /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_nxt offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_nxt /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_nxt using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
		Select @found_nxt_shr = 'n'
		Print 'Existing Standard share has been deleted'
		Print ' '
	   end


	If @found_base_shr = 'y' and @delete_flag = 'n'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_base /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_base offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_base /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_base using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
		Select @found_nxt_shr = 'n'
		Print 'Existing Standard share has been deleted'
		Print ' '
	   end


	--  Create the shares, and share security, for nxt
	--  Get selected cluster info (disk)


	If @save_envname like '%prod%' or @found_nxt_shr = 'y'
	   begin
		goto skip_clust_nxt
	   end


	Select @save_drive_letter_part = substring(@path_nxt, 2,2)
	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like '%' + @save_drive_letter_part + '%')


	Select @save_disk_resname = @save_data2
	Select @charpos = charindex('   ', @save_data2)
	If @charpos > 0
	   begin
		Select @save_disk_resname = left(@save_data2, @charpos-1)
		Select @save_group_resname = substring(@save_data2, @charpos, 200)
		Select @save_group_resname = ltrim(@save_group_resname)
		Select @charpos = charindex('   ', @save_group_resname)
		If @charpos > 0
		   begin
			Select @save_group_resname = left(@save_group_resname, @charpos-1)
		   end
	   end
	Else
	   begin
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_nxt.'
		goto skip_clust_nxt
	   end


	--  Get selected cluster info (network)
	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like '%network%' and data2 like '%' + @save_group_resname + ' %')


	Select @save_network_resname = @save_data2
	Select @charpos = charindex(@save_group_resname + ' ', @save_network_resname)
	If @charpos > 0
	   begin
		Select @save_network_resname = left(@save_network_resname, @charpos-1)
		Select @save_network_resname = rtrim(@save_network_resname)
	   end
	Else
	   begin
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_nxt.'
		goto skip_clust_nxt
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /Create /Group:"' + @save_group_resname + '" /Type:"File Share"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv Path=' + @path_nxt
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv ShareName=' + @save_servername2 + '_nxt'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SQLnxtPusher",grant,c:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_nxt + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	skip_clust_nxt:


	--  Create the shares, and share security, for base
	--  Get selected cluster info (disk)


	If @save_envname like '%prod%' or @found_base_shr = 'y'
	   begin
		goto skip_clust_base
	   end


	Select @save_drive_letter_part = substring(@path_base, 2,2)
	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like '%' + @save_drive_letter_part + '%')


	Select @save_disk_resname = @save_data2
	Select @charpos = charindex('   ', @save_data2)
	If @charpos > 0
	   begin
		Select @save_disk_resname = left(@save_data2, @charpos-1)
		Select @save_group_resname = substring(@save_data2, @charpos, 200)
		Select @save_group_resname = ltrim(@save_group_resname)
		Select @charpos = charindex('   ', @save_group_resname)
		If @charpos > 0
		   begin
			Select @save_group_resname = left(@save_group_resname, @charpos-1)
		   end
	   end
	Else
	   begin
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_base.'
		goto skip_clust_base
	   end


	--  Get selected cluster info (network)
	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like '%network%' and data2 like '%' + @save_group_resname + ' %')


	Select @save_network_resname = @save_data2
	Select @charpos = charindex(@save_group_resname + ' ', @save_network_resname)
	If @charpos > 0
	   begin
		Select @save_network_resname = left(@save_network_resname, @charpos-1)
		Select @save_network_resname = rtrim(@save_network_resname)
	   end
	Else
	   begin
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_base.'
		goto skip_clust_base
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /Create /Group:"' + @save_group_resname + '" /Type:"File Share"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv Path=' + @path_base
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv ShareName=' + @save_servername2 + '_base'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SQLbasePusher",grant,c:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_base + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	skip_clust_base:


   end


----------------  End  -------------------


label99:


drop table #ShareTempTable
drop table #loginconfig
drop table #fileexists
drop table #cluster_info1
drop table #cluster_info2


Print ' '
Print 'Processing for dbasp_dba_sqlsetup - complete'
Print ' '
GO
GRANT EXECUTE ON  [dbo].[dbasp_create_NXTshare] TO [public]
GO
