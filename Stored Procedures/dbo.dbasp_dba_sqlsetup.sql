SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_dba_sqlsetup] (@backup_path varchar(200) = NULL
					,@mdf_path varchar(200) = NULL
					,@ldf_path varchar(200) = NULL
					,@DropOnly bit = 0)


/**************************************************************
 **  Stored Procedure dbasp_dba_sqlsetup
 **  Written by Steve Ledridge, Virtuoso
 **  September 6, 2002
 **
 **  This dbasp is set up to help in the standard SQL setup
 **  process, which includes standard folders and shares.
 **
 **  To execute this sproc, the full path to the backup folder
 **  must be provided as input, unless shares to the dbasql and
 **  dba_archive folders had previously been created.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
----	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/06/2002	Steve Ledridge		New SQL setup process.
--	10/22/2002	Steve Ledridge		Added SQLjob_logs and deployment_logs folders.
--	11/06/2002	Steve Ledridge		Added mdf and ldf shares.
--	02/11/2003	Steve Ledridge		Moved location of SQLjob_logs folder and added share.
--	04/17/2003	Steve Ledridge		Changes for new instance share names.
--	06/09/2003	Steve Ledridge		Added permissionsfor AMER domain users.
--	10/17/2003	Steve Ledridge		Added double quotes around all paths.
--	03/01/2004	Steve Ledridge		Added local read and write groups.
--	07/13/2004	Steve Ledridge		Check for error 1788 when adding local read and write groups.
--	08/27/2004	Steve Ledridge		Add bracket in cursor cu11 for dbname.
--	09/29/2004	Steve Ledridge		Fix order of folder creation.
--	01/07/2005	Steve Ledridge		Added double quotes for mkdir statements.
--	12/29/2005	Steve Ledridge		exec dbasp_FixJobOutput at end to fix current jobs.
--	02/14/2006	Steve Ledridge		Converted for sql2005.
--	05/04/2007	Steve Ledridge		Fixed spelling for 'local'.
--	07/26/2007	Steve Ledridge		exec dbasp_create_NXTshare to create NXT share.
--	12/28/2007	Steve Ledridge		Added cluster processing. NXT is now done within this sproc also.
--	03/04/2008	Steve Ledridge		Added default setting for @isNMinstance.
--	04/30/2008	Steve Ledridge		Set DBAOps and systeminfo owner and recovery option.
--	05/06/2008	Steve Ledridge		New code for production group seasqlprodsvc.
--	05/12/2008	Steve Ledridge		New code for sqladminprod2008 svc accounts.
--	05/27/2008	Steve Ledridge		Added more new code for stage group seasqlstagesvc.
--	06/09/2008	Steve Ledridge		Added XCACLS permissions to cluster shares.
--	01/09/2009	Steve Ledridge		Changed cluster share perms from "domain admins" to "NOC".
--	02/06/2009	Steve Ledridge		Fixed bug for Disk s: in clusters.
--	06/09/2009	Steve Ledridge		Added code for dba_UpdateFiles folder.
--	06/18/2009	Steve Ledridge		Added code for filescan folder.
--	05/21/2010	Steve Ledridge		Removed systeminfo references.
--	06/07/2010	Steve Ledridge		BASE share is now done within this sproc also.
--	09/28/2011	Steve Ledridge		Added @DropOnly Feature to remove all standard Shares.
--						Modified Scripting to Use non-clustered method if windows
--						2008 clustering is used.
--	07/17/2012	Steve Ledridge		Modified _SQLjob_logs folder & share to be on the same drive as the _backup Share
--	10/02/2012	Steve Ledridge		Chenged temp table for file name to nvarchar(4000) and now ignore ftcat files.
--	03/03/2015	Steve Ledridge		Will now use default paths if no input is provided.
--						Will also reset default paths if new are provided.
--	08/06/2015	Steve Ledridge		Get mdf and ldf paths from DBAOps, dbaperf or DBAOps.
--	======================================================================================


/***
Declare @backup_path varchar(200)
Declare @mdf_path varchar(200)
Declare @ldf_path varchar(200)
Declare @DropOnly bit


Select @backup_path = 'D:\Backup'
--Select @mdf_path = 'e:\mssql$a\data'
Select @ldf_path = 'D:\MSSQL.1\MSSQL\Log'
Select @DropOnly = 0
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@command 			nvarchar(4000)
	,@dos_command			varchar(500)
	,@result			int
	,@len				int
	,@save_DBname			sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_sqlinstance		sysname
	,@save_domain			sysname
	,@save_envname			sysname
	,@charpos			int
	,@save_charpos			int
	,@save_drive_letter_part	char(2)
	,@save_data2			nvarchar(4000)
	,@save_disk_resname		sysname
	,@save_group_resname		sysname
	,@save_network_resname		sysname
	,@fileexist_path		sysname
	,@path_log			sysname
	,@path_dbasql			sysname
	,@path_dba_archive		sysname
	,@path_dba_reports		sysname
	,@path_dba_UpdateFiles		sysname
	,@path_filescan			sysname
	,@path_dba_mail			sysname
	,@path_builds			sysname
	,@path_datamigration		sysname
	,@path_backup			sysname
	,@path_mdf			sysname
	,@path_ldf			sysname
	,@path_SQLjob_logs		sysname
	,@path_nxt			sysname
	,@path_base			sysname
	,@newpath_mdf			sysname
	,@newpath_ldf			sysname
	,@found_dbasql_fol		char(1)
	,@found_dba_archive_fol		char(1)
	,@found_dba_reports_fol		char(1)
	,@found_dba_UpdateFiles_fol	char(1)
	,@found_filescan_fol		char(1)
	,@found_dba_mail_fol		char(1)
	,@found_builds_fol		char(1)
	,@found_datamigration_fol	char(1)
	,@found_SQLjob_logs_fol		char(1)
	,@found_deployment_logs_fol	char(1)
	,@found_backup_fol		char(1)
	,@found_nxt_fol			char(1)
	,@found_base_fol		char(1)
	,@found_dbasql_shr		char(1)
	,@found_dba_archive_shr		char(1)
	,@found_dba_mail_shr		char(1)
	,@found_builds_shr		char(1)
	,@found_backup_shr		char(1)
	,@found_log_shr			char(1)
	,@found_mdf_shr			char(1)
	,@found_ldf_shr			char(1)
	,@found_SQLjob_logs_shr		char(1)
	,@found_nxt_shr			char(1)
	,@found_base_shr		char(1)
	,@save_iscluster		char(1)
	,@isNMinstance			char(1)
	,@in_key			sysname
	,@in_path			sysname
	,@in_value			sysname
	,@result_value			nvarchar(500)
	,@ShareResType			nvarchar(500)
	,@ClusterVersion		varchar(100)
	,@Version_Parts			INT
	,@CLSTVer_Major			INT
	,@CLSTVer_Minor			INT
	,@CLSTVer_Bld_Major		INT
	,@CLSTVer_Bld_Minor		INT
	,@rc				int
	,@SQLDataRoot			nvarchar(4000)
	,@SQLLogRoot			nvarchar(4000)
	,@SQLBackupRoot			nvarchar(4000)


DECLARE
	 @cu11filename			sysname


DECLARE
	 @cu12path			nvarchar(500)


SELECT		@ClusterVersion		= REPLACE(product_version,':','.')
			,@Version_Parts		= LEN(@ClusterVersion) - LEN(REPLACE(@ClusterVersion,'.','')) + 1
			,@CLSTVer_Major		= Cast(Parsename(@ClusterVersion,@Version_Parts)AS INT)
			,@CLSTVer_Minor		= Cast(Parsename(@ClusterVersion,@Version_Parts-1)AS INT)
			,@CLSTVer_Bld_Major	= Cast(Parsename(@ClusterVersion,@Version_Parts-2)AS INT)
			,@CLSTVer_Bld_Minor	= Cast(Parsename(@ClusterVersion,@Version_Parts-3)AS INT)
FROM		[master].[sys].[dm_os_loaded_modules]
WHERE		description = 'Microsoft Cluster Resource Utility DLL'


----------------  initial values  -------------------
Select
	@ShareResType			= 'File Share'
	,@found_dbasql_fol		= 'n'
	,@found_dba_archive_fol		= 'n'
	,@found_dba_reports_fol		= 'n'
	,@found_dba_UpdateFiles_fol	= 'n'
	,@found_filescan_fol		= 'n'
	,@found_dba_mail_fol		= 'n'
	,@found_builds_fol		= 'n'
	,@found_datamigration_fol	= 'n'
	,@found_SQLjob_logs_fol		= 'n'
	,@found_deployment_logs_fol	= 'n'
	,@found_backup_fol		= 'n'
	,@found_nxt_fol			= 'n'
	,@found_base_fol		= 'n'
	,@found_dbasql_shr		= 'n'
	,@found_dba_archive_shr		= 'n'
	,@found_dba_mail_shr		= 'n'
	,@found_builds_shr		= 'n'
	,@found_backup_shr		= 'n'
	,@found_log_shr			= 'n'
	,@found_mdf_shr			= 'n'
	,@found_ldf_shr			= 'n'
	,@found_SQLjob_logs_shr		= 'n'
	,@found_nxt_shr			= 'n'
	,@found_base_shr		= 'n'
	,@newpath_mdf 			= ''
	,@newpath_ldf 			= ''


-- Set variables ---------------------------------------------------------------------------
Select @save_sqlinstance	= 'mssqlserver'
Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @isNMinstance		= 'n'


Create table #ShareTempTable(path nvarchar(500) null)


Create table #loginconfig(name1 sysname null, config_value sysname null)


Create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #cluster_info1 (data1 nvarchar(4000))
Create table #cluster_info2 (data2 nvarchar(4000))


declare @filenames table (fname		nvarchar(4000))


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


--  Capture Current default paths
exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'DefaultData', @SQLDataRoot output, 'no_output'
if (@SQLDataRoot is null)
   begin
	exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @SQLDataRoot output, 'no_output'
	select @SQLDataRoot = @SQLDataRoot + N'\Data'
   end


exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'DefaultLog', @SQLLogRoot output, 'no_output'
if (@SQLLogRoot is null)
   begin
	exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @SQLLogRoot output, 'no_output'
	select @SQLLogRoot = @SQLLogRoot + N'\Data'
   end


exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory', @SQLBackupRoot output, 'no_output'
if (@SQLBackupRoot is null)
   begin
	exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'BackupDirectory', @SQLBackupRoot output, 'no_output'
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Check input parm and if the @backup_path input parm is null, try to fill it in.
If @backup_path is null
   begin
	Delete from #ShareTempTable
	Select @command = 'RMTSHARE \\' + @save_servername
	Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
	delete from #ShareTempTable where path is null
	delete from #ShareTempTable where path not like '%dba%'
	--select * from #ShareTempTable


	If (select count(*) from #ShareTempTable) > 0
	   begin
		start_cu12:
		Select @cu12path = (select Top 1 path from #ShareTempTable order by path)


		Select @charpos = charindex('dbasql', @cu12path)
		IF @charpos <> 0
		   begin
			Select @charpos = charindex('\backup\', @cu12path)
			IF @charpos <> 0
			   begin
				Select @save_charpos = @charpos
				Select @charpos = charindex(':\', @cu12path)
				Select @backup_path = substring(@cu12path, @charpos-1, (@save_charpos - @charpos+8))
				goto end_cu12
			   end
		   end


		Select @charpos = charindex('dba_archive', @cu12path)
		IF @charpos <> 0
		   begin
			Select @charpos = charindex('\backup\', @cu12path)
			IF @charpos <> 0
			   begin
				Select @save_charpos = @charpos
				Select @charpos = charindex(':\', @cu12path)
				Select @backup_path = substring(@cu12path, @charpos-1, (@save_charpos - @charpos+8))
				goto end_cu12
			   end
		   end


		Delete from #ShareTempTable where path = @cu12path
		If (select count(*) from #ShareTempTable) > 0
		   begin
			goto start_cu12
		   end


	   end


	end_cu12:


   end


--  If the @backup_path is still null, grab the default backup path.
If @backup_path is null
   begin
	Select @backup_path = @SQLBackupRoot
   end


--  If the @backup_path is still null, error out.  If not, verify the folder exists and set variables
If @backup_path is null
   begin
	Select @miscprint = 'ERROR: Backup path could not be found.'
	Print  @miscprint
	Select @miscprint = '       Please provide full path to the backup folder via the input parm ''@backup_path''.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end
Else
   begin
	Delete from #fileexists
	Select @fileexist_path = @backup_path + '\'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) = 0
	   begin
		Select @miscprint = 'ERROR: Backup path provided could not be found.'
		Print  @miscprint
		Select @miscprint = '       Make sure the folder has been created and please provide'
		Print  @miscprint
		Select @miscprint = '       full path to the backup folder via the input parm ''@backup_path''.'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'Nothing was done.'
		Print  @miscprint
		goto label99
	   end
	Else
	   begin
		Select @found_backup_fol = 'y'
		Select @path_dba_archive = @backup_path + '\dba_archive'
		Select @path_dbasql = @backup_path + '\dbasql'
		Select @path_dba_reports = @backup_path + '\dbasql\dba_reports'
		Select @path_dba_UpdateFiles = @backup_path + '\dbasql\dba_UpdateFiles'
		Select @path_filescan = @backup_path + '\dbasql\filescan'
		Select @path_backup = @backup_path
		Select @path_dba_mail = substring(@backup_path, 1, 1) + ':\dba_mail'
		Select @path_builds = substring(@backup_path, 1, 1) + ':\builds'
		Select @path_datamigration = @path_builds + '\DataMigration'
	   end
   end


--  Get the path to the SQL log folder (s\b at the same level as the data folder which holds the master mdf)
select @path_log = filename from master.sys.sysfiles where name = 'master'


Select @charpos = charindex('\data\master.mdf', @path_log)
Select @path_log = substring(@path_log, 1, (@charpos - 1))
Select @path_log = @path_log + '\log'


-- CHANGED TO BE IN ROOT OF BACKUP DRIVE
--Select @path_SQLjob_logs = @path_log + '\SQLjob_logs'
Select @path_SQLjob_logs = LEFT(@backup_path,2) + '\SQLjob_logs' + REPLACE('$'+@@SERVICENAME,'$MSSQLSERVER','')


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


--  Get the path for the mdf files
If @mdf_path is null
   begin
	Select @save_DBname = (select top 1 name
			from master.sys.sysdatabases
			where name in ('DBAOps', 'dbaperf', 'DBAOps'))


	Select @command = 'SELECT filename From [' + @save_DBname + '].sys.sysfiles '
	--Print @command
	Delete from @filenames
	insert into @filenames (fname) exec (@command)


	delete from @filenames where fname is null or fname = ''
	delete from @filenames where fname like '%ftcat%'
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		start_filenames_mdf:


		Select @cu11filename = (select top 1 fname from @filenames)


		--  Format the path for the mdf files
		Select @charpos = charindex('.mdf', @cu11filename)


		If @charpos > 0
		   begin
			Select @path_mdf = @cu11filename
			Select @charpos = charindex('\', @path_mdf)


			If @charpos > 0
			   begin
				label01_mdf:
				Select @charpos = charindex('\', @path_mdf)
				Select @newpath_mdf = @newpath_mdf + substring(@path_mdf, 1, (@charpos))
				Select @path_mdf = substring(@path_mdf, (@charpos+ 1), 200)

				Select @charpos = charindex('\', @path_mdf)
				If @charpos > 0
				   begin
					goto label01_mdf
				   end


				Select @len = len(@newpath_mdf)
				Select @newpath_mdf = substring(@newpath_mdf, 1, (@len - 1))
			   end
			Select @mdf_path = @newpath_mdf
		   end
		Else
		   begin
			--  check for more rows to process
			Delete from @filenames where fname = @cu11filename
			If (select count(*) from @filenames) > 0
			   begin
				goto start_filenames_mdf
			   end
		   end
	   end
   end


--  Get the paths for the ldf files
If @ldf_path is null
   begin
	Select @save_DBname = (select top 1 name
			from master.sys.sysdatabases
			where name in ('DBAOps', 'dbaperf', 'DBAOps'))


	Select @command = 'SELECT filename From [' + @save_DBname + '].sys.sysfiles '
	--Print @command
	Delete from @filenames
	insert into @filenames (fname) exec (@command)


	delete from @filenames where fname is null or fname = ''
	delete from @filenames where fname like '%ftcat%'
	--select * from @filenames


	If (select count(*) from @filenames) > 0
	   begin
		start_filenames_ldf:


		Select @cu11filename = (select top 1 fname from @filenames)


		--  Format the path for the ldf files
		Select @charpos = charindex('.ldf', @cu11filename)


		If @charpos > 0
		   begin
			Select @path_ldf = @cu11filename
			Select @charpos = charindex('\', @path_ldf)


			If @charpos > 0
			   begin
				label02:
				Select @charpos = charindex('\', @path_ldf)
				Select @newpath_ldf = @newpath_ldf + substring(@path_ldf, 1, (@charpos))
				Select @path_ldf = substring(@path_ldf, (@charpos+ 1), 200)

				Select @charpos = charindex('\', @path_ldf)
				If @charpos > 0
				   begin
					goto label02
				   end


				Select @len = len(@newpath_ldf)
				Select @newpath_ldf = substring(@newpath_ldf, 1, (@len - 1))
			   end
			Select @ldf_path = @newpath_ldf
		   end
		Else
		   begin
			--  check for more rows to process
			Delete from @filenames where fname = @cu11filename
			If (select count(*) from @filenames) > 0
			   begin
				goto start_filenames_ldf
			   end
		   end
	   end
   end


--  If mdf or ldf paths are still null, use the default paths
If @mdf_path is null or @mdf_path = ''
   begin
	Select @mdf_path = @SQLDataRoot
   end


If @ldf_path is null or @ldf_path = ''
   begin
	Select @ldf_path = @SQLLogRoot
   end


--  If mdf or ldf paths are still null, error out.
If @mdf_path is null or @ldf_path is null or
   @mdf_path = '' or @ldf_path = ''
   begin
	Select @miscprint = 'ERROR: MDF or LDF paths could not be found.'
	Print  @miscprint
	Select @miscprint = '       Please provide full paths to both the MDF files and the LDF files via the input parms ''@mdf_path'' and ''@ldf_path''.'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Nothing was done.'
	Print  @miscprint
	goto label99
   end
Else
   begin
	Select @path_mdf = @mdf_path
	Select @path_ldf = @ldf_path
   end


--  Set the NXT path
Select @path_nxt = substring(@path_mdf, 1, 1) + ':\nxt'
If @isNMinstance = 'y'
   begin
	Select @path_nxt = @path_nxt + '$' + @save_sqlinstance
   end


--  Set the BASE path
Select @path_base = substring(@path_backup, 1, 1) + ':\BASE'
If @isNMinstance = 'y'
   begin
	Select @path_base = @path_base + '$' + @save_sqlinstance
   end


--  Check to see if the 'dba_archive' folder exists
Delete from #fileexists
Select @fileexist_path = @path_dba_archive + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_dba_archive_fol = 'y'
   end


--  Check to see if the 'dbasql' folder exists
Delete from #fileexists
Select @fileexist_path = @path_dbasql + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_dbasql_fol = 'y'
   end


--  Check to see if the 'dba_reports' folder exists
Delete from #fileexists
Select @fileexist_path = @path_dba_reports + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_dba_reports_fol = 'y'
   end


--  Check to see if the 'dba_UpdateFiles' folder exists
Delete from #fileexists
Select @fileexist_path = @path_dba_UpdateFiles + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_dba_UpdateFiles_fol = 'y'
   end


--  Check to see if the 'filescan' folder exists
Delete from #fileexists
Select @fileexist_path = @path_filescan + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_filescan_fol = 'y'
   end


--  Check to see if the 'dba_mail' folder exists
Delete from #fileexists
Select @fileexist_path = @path_dba_mail + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_dba_mail_fol = 'y'
   end


--  Check to see if the 'builds' folder exists
Delete from #fileexists
Select @fileexist_path = @path_builds + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_builds_fol = 'y'
   end


--  Check to see if the 'DataMigration' folder exists
Delete from #fileexists
Select @fileexist_path = @path_datamigration + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_datamigration_fol = 'y'
   end


--  Check to see if the 'deployment_logs' folder exists
Delete from #fileexists
Select @fileexist_path = @path_builds + '\deployment_logs' + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_deployment_logs_fol = 'y'
   end


--  Check to see if the 'SQLjob_logs' folder exists
Delete from #fileexists
Select @fileexist_path = @path_SQLjob_logs + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) = 1
   begin
	Select @found_SQLjob_logs_fol = 'y'
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


--  Create the folders as needed
If @found_dba_archive_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_dba_archive + '"'
	Print 'Creating dba_archive folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_dbasql_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_dbasql + '"'
	Print 'Creating dbasql folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_dba_reports_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_dba_reports + '"'
	Print 'Creating dba_reports folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_dba_UpdateFiles_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_dba_UpdateFiles + '"'
	Print 'Creating dba_UpdateFiles folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_filescan_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_filescan + '"'
	Print 'Creating filescan folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'mkdir "' + @path_filescan + '\filescan_result"'
	Print 'Creating filescan folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'mkdir "' + @path_filescan + '\filescan_temp"'
	Print 'Creating filescan folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_dba_mail_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_dba_mail + '"'
	Print 'Creating dba_mail folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_builds_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_builds + '"'
	Print 'Creating builds folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_datamigration_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_datamigration + '"'
	Print 'Creating DataMigration folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_deployment_logs_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_builds + '\deployment_logs' + '"'
	Print 'Creating deployment_logs folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
   end


If @found_SQLjob_logs_fol = 'n'
   begin
	Select @dos_command = 'mkdir "' + @path_SQLjob_logs + '"'
	Print 'Creating SQLjob_logs folder using command '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
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


--  For mdf, ldf and backup paths, reset default if needed
If @path_mdf <> @SQLDataRoot
   begin
	EXEC   [sys].[xp_instance_regwrite]
	       N'HKEY_LOCAL_MACHINE',
	       N'Software\Microsoft\MSSQLServer\MSSQLServer',
	       N'DefaultData',
	       REG_SZ,
	       @path_mdf
   end


If @path_ldf <> @SQLLogRoot
   begin
	EXEC   [sys].[xp_instance_regwrite]
	       N'HKEY_LOCAL_MACHINE',
	       N'Software\Microsoft\MSSQLServer\MSSQLServer',
	       N'DefaultLog',
	       REG_SZ,
	       @path_ldf
   end


If @path_backup <> @SQLBackupRoot
   begin
	EXEC   [sys].[xp_instance_regwrite]
	       N'HKEY_LOCAL_MACHINE',
	       N'Software\Microsoft\MSSQLServer\MSSQLServer',
	       N'BackupDirectory',
	       REG_SZ,
	       @path_backup
   end


Print ' '
Print 'Standard folders are in place'
Print ' '


Select @path_dba_archive = '"' + @path_dba_archive + '"'
Select @path_dbasql = '"' + @path_dbasql + '"'
Select @path_dba_reports = '"' + @path_dba_reports + '"'
Select @path_dba_UpdateFiles = '"' + @path_dba_UpdateFiles + '"'
Select @path_filescan = '"' + @path_filescan + '"'
Select @path_datamigration = '"' + @path_datamigration + '"'
Select @path_backup = '"' + @path_backup + '"'
Select @path_dba_mail = '"' + @path_dba_mail + '"'
Select @path_builds = '"' + @path_builds + '"'
Select @path_SQLjob_logs = '"' + @path_SQLjob_logs + '"'
Select @path_log = '"' + @path_log + '"'
Select @path_mdf = '"' + @path_mdf + '"'
Select @path_ldf = '"' + @path_ldf + '"'
Select @path_nxt = '"' + @path_nxt + '"'
Select @path_base = '"' + @path_base + '"'


If @save_iscluster = 'n' OR @CLSTVer_Major >= 6
   begin
	--  Check to see if standard shares have already been set up
	Delete from #ShareTempTable
	Select @command = 'RMTSHARE \\' + @save_servername
	Insert into #ShareTempTable exec master.sys.xp_cmdshell @command
	delete from #ShareTempTable where path is null or path = ''


	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_dba_archive%')
	   begin
		Select @found_dba_archive_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_dbasql%')
	   begin
		Select @found_dbasql_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+ @save_servername + '_dba_mail%')
	   begin
		Select @found_dba_mail_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+ @save_servername + '_builds%')
	   begin
		Select @found_builds_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_backup%')
	   begin
		Select @found_backup_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_log%')
	   begin
		Select @found_log_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_mdf%')
	   begin
		Select @found_mdf_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_ldf%')
	   begin
		Select @found_ldf_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_SQLjob_logs%')
	   begin
		Select @found_SQLjob_logs_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_nxt%')
	   begin
		Select @found_nxt_shr = 'y'
	   end
	If exists (select 1 from #ShareTempTable where path like '%'+REPLACE(@@SERVERNAME,'\','$') + '_base%')
	   begin
		Select @found_base_shr = 'y'
	   end


	--  If any standard shares are found, delete them (we will recreate them)
	If @found_dba_archive_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dba_archive /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_dbasql_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dbasql /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_dba_mail_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_dba_mail /DELETE'
		Print 'Deleting the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_builds_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /DELETE'
		Print 'Deleting the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_backup_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_backup /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_log_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_log /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_mdf_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_mdf /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_ldf_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_ldf /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_SQLjob_logs_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs /DELETE'
		Print 'Deleting the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_nxt_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_nxt /DELETE'
		Print 'Deleting the ' + @save_servername + '_nxt share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_base_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_base /DELETE'
		Print 'Deleting the ' + @save_servername + '_base share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	Print ' '
	Print 'Existing Standard shares have been deleted'
	Print ' '


	If @DropOnly = 1 Goto label99


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


	--  Create the shares, and share security, for dba_archive
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dba_archive =' + @path_dba_archive + ' /unlimited'
	Print 'Creating the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dba_archive /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dba_archive /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	--  Create the shares, and share security, for dbasql
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dbasql =' + @path_dbasql + ' /unlimited'
	Print 'Creating the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dbasql /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dbasql /grant "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":r'
	Print 'Assign READ ONLY Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dbasql /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dbasql + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":R /Y'
	Print 'Assign READ ONLY NTFS Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	--  Create the shares, and share security, for dba_mail
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_dba_mail =' + @path_dba_mail + ' /unlimited'
	Print 'Creating the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_dba_mail /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_dba_mail /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_dba_mail share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_dba_mail share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	--  Create the shares, and share security, for builds
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds =' + @path_builds + ' /unlimited'
	Print 'Creating the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /grant "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":r'
	Print 'Assign READ ONLY Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_builds + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read":R /Y'
	Print 'Assign READ ONLY NTFS Permissions: ' + @save_servername + '\' + @save_servername2 + '_SQL_Local_Read to the ' + @save_servername + '_builds share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	--  Create the shares, and share security, for backup
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_backup =' + @path_backup + ' /unlimited'
	Print 'Creating the ' + @save_servername2 + '_backup share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_backup /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_backup /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_backup share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_backup + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


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


	--  Create the shares, and share security, for mdf
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_mdf =' + @path_mdf + ' /unlimited'
	Print 'Creating the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_mdf /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_mdf /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_mdf + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Print ' '


	--  Create the shares, and share security, for ldf
	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_ldf =' + @path_ldf + ' /unlimited'
	Print 'Creating the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_ldf /grant administrators:f'
	Print 'Assign FULL Permissions, Local administrators to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername2 + '_ldf /Remove everyone'
	Print 'Remove Share permissions for ''Everyone'' from the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_ldf + ' /G administrators:F /Y'
	Print 'Assign FULL NTFS Permissions, Local administrators to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G system:R /Y'
	Print 'Assign READ ONLY NTFS Permissions: Local System to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
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


	--  Create the shares, and share security, for nxt
	If @save_envname not like '%prod%'
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
	   end


	--  Create the shares, and share security, for base
	If @save_envname not like '%prod%'
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
	   end


	Print ' '


	Print ' '
	Print ' '
	Print 'Standard shares, including folder and NTFS security, are in place'
	Print ' '
   end
Else
   begin
	--  Check to see if standard shares have already been set up
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_dba_archive%')
	   begin
		Select @found_dba_archive_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_dbasql%')
	   begin
		Select @found_dbasql_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername + '_dba_mail%')
	   begin
		Select @found_dba_mail_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername + '_builds%')
	   begin
		Select @found_builds_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_backup%')
	   begin
		Select @found_backup_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_log%')
	   begin
		Select @found_log_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_mdf%')
	   begin
		Select @found_mdf_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '' + @save_servername2 + '_ldf%')
	   begin
		Select @found_ldf_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_SQLjob_logs%')
	   begin
		Select @found_SQLjob_logs_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_nxt%')
	   begin
		Select @found_nxt_shr = 'y'
	   end
	If exists (select 1 from #cluster_info2 where data2 like '%' + @save_servername2 + '_base%')
	   begin
		Select @found_base_shr = 'y'
	   end


	--  If any standard shares are found, delete them (we will recreate them)
	If @found_dba_archive_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_dba_archive /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_dba_archive offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_dba_archive /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_dba_archive using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_dbasql_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_dbasql /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_dbasql offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_dbasql /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_dbasql using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_dba_mail_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername + '_dba_mail /off'
		Print 'Take the File Share Resource ' + @save_servername + '_dba_mail offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername + '_dba_mail /delete'
		Print 'Deleting the File Share Resource ' + @save_servername + '_dba_mail using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_builds_shr = 'y'
	   begin
		Select @dos_command = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /DELETE'
		Print 'Deleting the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
		Select @dos_command = 'cluster . res ' + @save_servername + '_builds /off'
		Print 'Take the File Share Resource ' + @save_servername + '_builds offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername + '_builds /delete'
		Print 'Deleting the File Share Resource ' + @save_servername + '_builds using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_backup_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_backup /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_backup offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_backup /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_backup using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_log_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_log /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_log offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_log /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_log using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_mdf_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_mdf /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_mdf offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_mdf /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_mdf using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_ldf_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_ldf /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_ldf offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_ldf /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_ldf using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_SQLjob_logs_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_SQLjob_logs /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_SQLjob_logs offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_SQLjob_logs /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_SQLjob_logs using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_nxt_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_nxt /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_nxt offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_nxt /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_nxt using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	If @found_base_shr = 'y'
	   begin
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_base /off'
		Print 'Take the File Share Resource ' + @save_servername2 + '_base offline using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Select @dos_command = 'cluster . res ' + @save_servername2 + '_base /delete'
		Print 'Deleting the File Share Resource ' + @save_servername2 + '_base using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
		Print ' '
	   end


	Print ' '
	Print 'Existing Standard shares have been deleted'
	Print ' '


	If @DropOnly = 1 Goto label99

	--  Local groups are not allowed for use in cluster share permissions so none will be created


	--  Create the shares, and share security, for dba_archive
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_dba_archive, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_dba_archive.'
		goto skip_clust_dba_archive
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_dba_archive.'
		goto skip_clust_dba_archive
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv Path=' + @path_dba_archive
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv ShareName=' + @save_servername2 + '_dba_archive'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_archive + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_dba_archive share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dba_archive" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_dba_archive:


	--  Create the shares, and share security, for dbasql
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_dbasql, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_dbasql.'
		goto skip_clust_dbasql
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_dbasql.'
		goto skip_clust_dbasql
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv Path=' + @path_dbasql
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv ShareName=' + @save_servername2 + '_dbasql'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	 begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dbasql + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_dbasql share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_dbasql" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_dbasql:


	--  Create the shares, and share security, for dba_mail
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_dba_mail, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername + '_dba_mail.'
		goto skip_clust_dba_mail
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername + '_dba_mail.'
		goto skip_clust_dba_mail
	   end


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv Path=' + @path_dba_mail
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv ShareName=' + @save_servername + '_dba_mail'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_dba_mail + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername + '_dba_mail share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_dba_mail" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_dba_mail:


	--  Create the shares, and share security, for builds
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_builds, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername + '_builds.'
		goto skip_clust_builds
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername + '_builds.'
		goto skip_clust_builds
	   end


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv Path=' + @path_builds
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv ShareName=' + @save_servername + '_builds'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_builds + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername + '_builds share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername + '_builds" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_builds:


	--  Create the shares, and share security, for backup
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_backup, 2,2)
	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like '%' + @save_drive_letter_part + '%')


	Select @save_disk_resname = @save_data2
	Select @charpos = charindex('  ', @save_data2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_backup.'
		goto skip_clust_backup
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_backup.'
		goto skip_clust_backup
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv Path=' + @path_backup
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv ShareName=' + @save_servername2 + '_backup'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SQLTransSVCAcct",grant,r:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SQLTransSVCAcct":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLTransSVCAcct" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_backup + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_backup share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_backup" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_backup:


	--  Create the shares, and share security, for log
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_log, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_log.'
		goto skip_clust_log
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_log.'
		goto skip_clust_log
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv Path=' + @path_log
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv ShareName=' + @save_servername2 + '_log'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_log + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_log share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_log" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_log:


	--  Create the shares, and share security, for mdf
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_mdf, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_mdf.'
		goto skip_clust_mdf
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_mdf.'
		goto skip_clust_mdf
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv Path=' + @path_mdf
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv ShareName=' + @save_servername2 + '_mdf'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_mdf + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_mdf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_mdf" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_mdf:


	--  Create the shares, and share security, for ldf
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_ldf, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_ldf.'
		goto skip_clust_ldf
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_ldf.'
		goto skip_clust_ldf
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv Path=' + @path_ldf
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv ShareName=' + @save_servername2 + '_ldf'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_ldf + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_ldf share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_ldf" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_ldf:


	--  Create the shares, and share security, for SQLjob_logs
	--  Get selected cluster info (disk)
	Select @save_drive_letter_part = substring(@path_SQLjob_logs, 2,2)
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
		Print 'Unable to find the cluster resource for the disk ' + @save_drive_letter_part + '\.  Skipping create share process for ' + @save_servername2 + '_SQLjob_logs.'
		goto skip_clust_SQLjob_logs
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
		Print 'Unable to find the cluster network resource for the group ' + @save_group_resname + '.  Skipping create share process for ' + @save_servername2 + '_SQLjob_logs.'
		goto skip_clust_SQLjob_logs
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
	Print 'Create the File Share Resource in the cluster group [' + @save_group_resname + '] using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv Path=' + @path_SQLjob_logs
	Print 'Set the File Share Path using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv ShareName=' + @save_servername2 + '_SQLjob_logs'
	Print 'Set the File Share ShareName using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv Remark="DBA File Share"'
	Print 'Set the File Share Remark using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /prop Description="DBA Clustered Share"'
	Print 'Set the File Share Description using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	If @save_domain = 'Production'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SeaSQLProdsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SQLDBA",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SeaSQLProdsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdsvc" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SQLDBA":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQLDBA" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_domain = 'stage'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SeaSQLSTAGEsvc",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SQL Stage Admins",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SeaSQLSTAGEsvc":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLSTAGEsvc" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SQL Stage Admins":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SQL Stage Admins" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else If @save_envname like '%prod%'
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end
	Else
	   begin
		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"NOC",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SeaSQLProdFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=' + @save_domain + '\"SeaSQLTestFull",grant,f:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /priv security=everyone,revoke:security'
		Print 'Set the File Share permissions using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\NOC":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\NOC" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SeaSQLProdFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLProdFull" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


		Select @dos_command = 'XCACLS ' + @path_SQLjob_logs + ' /E /G "' + @save_domain + '\SeaSQLTestFull":F /Y'
		Print 'Assign FULL NTFS Permissions: "' + @save_domain + '\SeaSQLTestFull" to the ' + @save_servername2 + '_SQLjob_logs share using command: '+ @dos_command
		EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output
	   end


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /AddDep:"' + @save_disk_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /AddDep:"' + @save_network_resname + '"'
	Print 'Set the File Share dependency using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_SQLjob_logs" /On'
	Print 'Set the File Share OnLine using command: '+ @dos_command
	EXEC @Result = master.sys.xp_cmdshell @dos_command, no_output


	skip_clust_SQLjob_logs:


	--  Create the shares, and share security, for nxt
	--  Get selected cluster info (disk)


	If @save_envname like '%prod%'
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


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_nxt" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
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


	skip_clust_nxt:


	--  Create the shares, and share security, for base
	--  Get selected cluster info (disk)


	If @save_envname like '%prod%'
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


	Select @dos_command = 'cluster . res "' + @save_servername2 + '_base" /Create /Group:"' + @save_group_resname + '" /Type:"'+@ShareResType+'"'
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


	skip_clust_base:


   end


--  Fix existing job output paths
exec DBAOps.dbo.dbasp_FixJobOutput


--  Fix owner and options for DBAOps
ALTER AUTHORIZATION ON DATABASE::DBAOps TO sa;


ALTER DATABASE [DBAOps] SET RECOVERY SIMPLE WITH NO_WAIT


----------------  End  -------------------


label99:


drop table #ShareTempTable
drop table #loginconfig
drop table #DirectoryTempTable
drop table #fileexists
drop table #cluster_info1
drop table #cluster_info2


Print ' '
Print 'Processing for dbasp_dba_sqlsetup - complete'
Print ' '
GO
GRANT EXECUTE ON  [dbo].[dbasp_dba_sqlsetup] TO [public]
GO
