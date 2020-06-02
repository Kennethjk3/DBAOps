SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Self_Register]
--
--/*********************************************************
-- **  Stored Procedure dbasp_Self_Register
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- **  March 22, 2007
-- **
-- **  This procedure registers the local SQL server instance
-- **  to the designated centrl SQL server.
-- **  are found.
-- ***************************************************************/
 as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/22/2007	Steve Ledridge			New Process
--	04/16/2007	Steve Ledridge			Added sql install date, number and size of user DB's
--	06/19/2007	Steve Ledridge			New register process for DEPL related servers.
--	06/21/2007	Steve Ledridge			Modify the new register process for all servers now.
--	08/24/2007	Steve Ledridge			Added backup processing info.
--	09/18/2007	Steve Ledridge			Allow null in new temp table.
--	09/21/2007	Steve Ledridge			Update for SQL2005.
--	11/05/2007	Steve Ledridge			Added sql and server config info.
--	11/06/2007	Steve Ledridge			Get Domain name from srvinfo.
--	11/07/2007	Steve Ledridge			Removed psinfo and added msinfo.
--	02/07/2008	Steve Ledridge			Added skip for database that are not online.
--	02/12/2008	Steve Ledridge			New code for DEPL table update.
--	03/06/2008	Steve Ledridge			Added dynamic code for DEPL table update.
--	06/23/2008	Steve Ledridge			New code for Compression backup info check in.
--	06/27/2008	Steve Ledridge			Fixed bug in getting cluster node names.
--	08/20/2008	Steve Ledridge			Major re-write.
--	08/22/2008	Steve Ledridge			Skip appl desc for DBAOps and systeminfo.
--	08/26/2008	Steve Ledridge			force reg2.exe for x64.
--	09/16/2008	Steve Ledridge			seafresqldba02 to seafresqldba01.
--	09/25/2008	Steve Ledridge			New code to check for clr enabled setting.
--	10/07/2008	Steve Ledridge			Added FAStT and Multi-Path for SAN flag.
--	10/13/2008	Steve Ledridge			Added section for general environment verification (file shares).
--	10/14/2008	Steve Ledridge			Skip DB's like "_new" and"_nxt".
--	10/20/2008	Steve Ledridge			Fixed code for fulltext DB's.
--	11/10/2008	Steve Ledridge			Code to force upper case on server name and sql name.
--	11/14/2008	Steve Ledridge			New code to add backup_type to Local_ServerEnviro table.
--	11/21/2008	Steve Ledridge			Added auto set for the local policy rights.
--	12/01/2008	Steve Ledridge			Fix to grant policy for non-standard cluster group names.
--  12/02/2008	Steve Ledridge			Added code to update the local DBAOps DBA_*info tables.
--	12/08/2008	Steve Ledridge			Added code to capture database compatibility level
--	12/12/2008	Steve Ledridge			Revised code to check for baseline date
--	12/29/2008	Steve Ledridge			Fully qualified all references to DBAOps objects.
--	03/11/2009	Steve Ledridge			Added DEPLstatus verification to the no_check table.
--	03/18/2009	Steve Ledridge			Added section for DiskPerfinfo. Also changed
--										pagefile from available to max size.
--	03/20/2009	Steve Ledridge			Only delete DBinfo rowsolder than 60 days (last moddate)
--	03/25/2009	Steve Ledridge			Updated code for DiskPerfinfo
--	03/27/2009	Steve Ledridge			Set robocopy to work for folders with spaces.  Changed
--										most echo commands to sqlcmd.
--	03/30/2009	Steve Ledridge			This sproc will now execute sproc dbasp_self_register_report.
--	04/03/2009	Steve Ledridge			Fix issue with null inserts for Litespeed and Redgate info.
--	08/19/2009	Steve Ledridge			Fixed code for Redgate and Litespeed version updates.
--	12/02/2010	Steve Ledridge			Added output file verification.
--	02/18/2011	Steve Ledridge			Added port number to local sqlcmd execution.
--	09/13/2011	Steve Ledridge			Modified share name for sql_register.
--										Central name from seafresqldba01 to seapsqldba01.
--	01/18/2012	Steve Ledridge			Added code to check for sql 2008 r2.
--	03/19/2012	Steve Ledridge			Added -l120 for longer timeout on sqlcmd
--	09/16/2013	Steve Ledridge			New code for ENVname = local.
--	04/16/2014	Steve Ledridge			Changed seapsqldba01 to seapdbasql01.
--	======================================================================================


DECLARE
	 @miscprint					nvarchar(4000)
	,@cmd						nvarchar(4000)
	,@cmd2						nvarchar(4000)
	,@central_server 			sysname
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_sqlinstance			sysname
	,@save_backup_type	    	sysname
	,@save_ls_version    		sysname
	,@save_rg_version	    	sysname
	,@save_compbackup_rg_flag	char(1)
	,@save_compbackup_ls_flag	char(1)
	,@save_rg_versiontype		sysname
	,@save_rg_license			sysname
	,@save_rg_installdate		datetime
	,@save_ls_versiontype		sysname
	,@save_ls_license			sysname
	,@save_ls_installdate		datetime
	,@charpos					int
	,@isNMinstance				char(1)
	,@outfile_name				sysname
	,@outfolder_path			nvarchar(250)
	,@outfile_path				nvarchar(250)
	,@hold_source_path			sysname
	,@save_ENVname	 			sysname
	,@save_port					nvarchar(10)


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
	Select @isNMinstance = 'y'
   end


Select @save_port = (select env_detail from dbo.Local_ServerEnviro where env_type = 'SQL Port')


--  Create temp table
create table #ls_ver 	(
			 name01 sysname
			,value02 sysname null)

create table #outfile_check(data01 nvarchar(4000) null)

Select @central_server = 'SDCSQLTOOLS.DB.${{secrets.DOMAIN_NAME}}'
--Select @central_server = env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer'
--If @central_server is null
--   begin
--	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The nightly self check-in failed'
--	Print @miscprint
--	raiserror(@miscprint,-1,-1)
--	goto label99
--   end


--Select @save_ENVname = env_detail from dbo.Local_ServerEnviro where env_type = 'ENVname'
--If @save_ENVname is null
--   begin
--	Select @miscprint = 'DBA WARNING: The envirnment name is not defined for ' + @@servername + '.  The nightly self check-in failed'
--	Print @miscprint
--	raiserror(@miscprint,-1,-1)
--	goto label99
--   end


Select	@outfile_name		= 'CentralTableUpdate_' + REPLACE(@@SERVERNAME,'\','$') + '.sql'
		,@outfolder_path	= '\\' + REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'') + '\SQLBackups\dbasql\dba_reports\'
		,@outfile_path		= @outfolder_path + @outfile_name

RAISERROR ('@outfile_path = %s',-1,-1,@outfile_path) WITH NOWAIT
exec [dbo].[dbasp_FileAccess_Write] '', @outfile_path,0,1 -- MAKE SURE FILE AND PATH EXISTS


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Capture Backup Type
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and Env_detail = 'LiteSpeed')
   begin
	Select @save_backup_type = 'LiteSpeed'
   end
Else If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and Env_detail = 'RedGate')
   begin
	Select @save_backup_type = 'RedGate'
   end
Else If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and Env_detail = 'Standard')
   begin
	Select @save_backup_type = 'Standard'
   end
Else
   begin
	Select @save_backup_type = 'Default'
 end


--  For 2008 R2 and above, skip the check for Redgate and Litespeed
If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
   begin
		goto skip_compbackup_reset
   end


--  Capture LiteSpeed Version (if installed)
Select @save_ls_version = 'na'
If exists (select * from master.sys.objects where name = 'xp_sqllitespeed_version' and type = 'x')
   begin
	Delete from dbo.Local_ServerEnviro where env_type like 'backup_ls_%'


	insert into #ls_ver exec master.dbo.xp_sqllitespeed_version
	--select * from #ls_ver
	Select @save_ls_version = (select value02 from #ls_ver where name01 = 'Product Version')


	If @save_ls_version is null
	   begin
		Select @save_ls_version = 'unknown'
	   end


	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_ls_version')
	   begin
		Update dbo.Local_ServerEnviro set env_detail = @save_ls_version where env_type = 'backup_ls_version'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values('backup_ls_version', @save_ls_version)
	   end


	If exists (select 1 from #ls_ver where name01 = 'Professional Edition' and value02 = '1')
	   begin
		select @save_ls_versiontype = 'Professional Edition'
	   end
	Else If exists (select 1 from #ls_ver where name01 = 'Developer Edition' and value02 = '1')
	   begin
		select @save_ls_versiontype = 'Developer Edition'
	   end
	Else If exists (select 1 from #ls_ver where name01 = 'MSDE Edition' and value02 = '1')
	   begin
		select @save_ls_versiontype = 'MSDE Edition'
	   end
	Else
	   begin
		select @save_ls_versiontype = 'Unknown'
	   end


	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_ls_versiontype')
	   begin
		Update dbo.Local_ServerEnviro set env_detail = @save_ls_versiontype where env_type = 'backup_ls_versiontype'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values('backup_ls_versiontype', @save_ls_versiontype)
	   end


	Select @save_ls_license = 'na'


	Select @save_ls_installdate = (select create_date from master.sys.objects where name = 'xp_sqllitespeed_version' and type = 'x')


	Select @save_compbackup_ls_flag = 'y'
   end


--  Capture RedGate Version (if installed)
Select @save_rg_version = 'na'
If exists (select 1 from master.sys.objects where name = 'sqlbackup' and type = 'x')
   begin
	Delete from dbo.Local_ServerEnviro where env_type like 'backup_rg_%'


	exec master.dbo.sqbutility 1030, @save_rg_version OUTPUT


	If @save_rg_version is null
	   begin
		Select @save_rg_version = 'Error'
	   end
	Else
	   begin
		exec master.dbo.sqbutility 1021, @save_rg_versiontype OUTPUT, NULL, @save_rg_license OUTPUT;
		Select @save_rg_versiontype = case @save_rg_versiontype
						when '0' THEN 'Trial: Expired'
						when '1' THEN 'Trial'
						when '2' THEN 'Standard'
						when '3' THEN 'Professional'
						when '6' THEN 'Lite'
						else 'unknown'
						end


		Select @save_rg_installdate = (select create_date from master.sys.objects where name = 'sqlbackup' and type = 'x')


		Select @save_compbackup_rg_flag = 'y'
	   end


	If @save_rg_versiontype is null
	   begin
		Select @save_rg_versiontype = 'unknown'
	   end


	If @save_rg_license is null
	   begin
		Select @save_rg_license = 'unknown'
	   end


	Delete from dbo.Local_ServerEnviro where env_type like 'backup_rg_%'


	Insert into dbo.Local_ServerEnviro values('backup_rg_version', @save_rg_version)


	Insert into dbo.Local_ServerEnviro values('backup_rg_versiontype', @save_rg_versiontype)


	Insert into dbo.Local_ServerEnviro values('backup_rg_license', @save_rg_license)


   end


If @save_compbackup_rg_flag = 'y' and @save_backup_type = 'Default'
   begin
	Select @save_backup_type = 'RedGate'


	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type')
	   begin
		Update dbo.Local_ServerEnviro set env_detail = 'RedGate' where env_type = 'backup_type'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values('backup_type', 'RedGate')
	   end
   end
Else If @save_compbackup_ls_flag = 'y' and @save_backup_type = 'Default'
   begin
	Select @save_backup_type = 'LiteSpeed'


	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type')
	   begin
		Update dbo.Local_ServerEnviro set env_detail = 'LiteSpeed' where env_type = 'backup_type'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values('backup_type', 'LiteSpeed')
	   end
   end


skip_compbackup_reset:


--  Create output file
If @save_port is not null and @save_port <> 'error'
   begin
	SELECT @cmd = 'sqlcmd -S' + @@servername + ',' + @save_port + ' -w265 -u -l120 -Q"exec DBAOps.dbo.dbasp_Self_Register_Report" -E -o' + @outfile_path
   end
Else
   begin
	SELECT @cmd = 'sqlcmd -S' + @@servername + ' -w265 -u -l120 -Q"exec DBAOps.dbo.dbasp_Self_Register_Report" -E -o' + @outfile_path
   end


print @cmd
EXEC master.sys.xp_cmdshell @cmd --, no_output


----  Verify output file
--Select @cmd = 'type ' + @outfile_path
--Print @cmd
--delete from #outfile_check
--insert into #outfile_check exec master.sys.xp_cmdshell @cmd--, no_output
--delete from #outfile_check where data01 is null
----select * from #outfile_check


--If not exists (select 1 from #outfile_check where data01 like '%Start DBA_DiskPerfinfo Insert%')
--   begin
--	Select @miscprint = 'DBA ERROR: The dbasp_Self_Register_Report output file could not be validated for SQLname ' + @@servername + '.  The file will not be sent to the central server.'
--	Print @miscprint
--	raiserror(@miscprint,-1,-1)
--	goto file_copy_end
--   end
--Else
--   begin
--	Select @miscprint = 'dbasp_Self_Register_Report: output file verified.'
--	Print @miscprint
--	Print ''
--   end


-- Update the local DBAOps database
SET @cmd2 = 'sqlcmd -S'+@@servername+' -dDBAOps -E -w265 -l120 -i'+@outfile_path+'  -o' + @outfolder_path + 'DBA_SelfReg_localupdate.log'
Print @cmd2
EXEC master.sys.xp_cmdshell @cmd2, no_output


If @save_ENVname = 'local'
   begin
	goto file_copy_end
   end


----  Copy the file to the central server
--Select @cmd = 'xcopy /Y /R "' + rtrim(@outfile_path) + '" "\\' + rtrim(@central_server) + '\DBA_SQL_Register"'
--Print @cmd
--EXEC master.sys.xp_cmdshell @cmd, no_output


--If @central_server = 'seapdbasql01'
--   begin
--	goto file_copy_end
--   end


--If (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'domain') not in ('production', 'stage')
--   begin
--	Select @cmd = 'xcopy /Y /R "' + rtrim(@outfile_path) + '" "\\seapdbasql01\DBA_SQL_Register"'
--	Print @cmd
--	EXEC master.sys.xp_cmdshell @cmd, no_output
--   end
--Else
--   begin
--	Select @hold_source_path = '\\' + upper(@save_servername) + '\' + upper(@save_servername2) + '_dbasql\dba_reports'
--	exec dbo.dbasp_File_Transit @source_name = @outfile_name
--		,@source_path = @hold_source_path
--		,@target_env = 'AMER'
--		,@target_server = 'seapdbasql01'
--		,@target_share = 'DBA_SQL_Register'
--   end


file_copy_end:


---------------------------  Finalization  -----------------------
label99:

EXEC [dbo].[dbasp_SelfRegister_DBA_AGInfo] @ForceUpgrade = 0

EXEC dbo.dbasp_SecurityAudit

EXEC [dbo].[dbasp_SelfRegister_DBA_AGInfo] @ForceUpgrade = 0

EXEC dbo.dbasp_SecurityAudit

EXEC [dbo].[dbasp_Export_Checkin_Data]

drop table #ls_ver
drop table #outfile_check
GO
GRANT EXECUTE ON  [dbo].[dbasp_Self_Register] TO [public]
GO
