SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_ReportToCentral] @PrintLocal BIT = 1
--
--/*********************************************************
-- **  Stored Procedure dbasp_HC_ReportToCentral
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- **  November 11, 2014
-- **
-- **  This procedure captures Failed and Warning rows from the HealthCheckLog
-- **  table and formats a file to be sent to the central server for
-- **  reporting.
-- ***************************************************************/
 as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/11/2014	Steve Ledridge		New Process
--	03/02/2015	Steve Ledridge		Fix single quote issue in @save_HCtest
--	01/24/2017	Steve Ledridge		Modified Report Header.
--	======================================================================================


/*
declare @PrintLocal BIT


Select @PrintLocal = 1
--*/


DECLARE
			 @miscprint					nvarchar(4000)
			,@cmd						nvarchar(4000)
			,@charpos					int
			,@outfile_name				sysname
			,@outfile_path				nvarchar(250)
			,@hold_source_path			sysname
			,@save_HC_ID				bigint
			,@save_Check_date			datetime
			,@save_HCcat				sysname
			,@save_HCtype				sysname
			,@save_HCstatus				sysname
			,@save_HCPriority			sysname
			,@save_HCtest				nvarchar(4000)
			,@save_DBname				sysname
			,@save_Check_detail01		sysname
			,@save_Check_detail02		nvarchar(4000)
			,@save_propertyname			sysname


DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@PathAndFile				VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					SYSNAME
			,@central_server			SYSNAME

	EXEC DBAOps.dbo.dbasp_GetPaths -- @verbose = 1
		 @DataPath			= @DataPath			 OUT
		,@LogPath			= @LogPath			 OUT
		,@BackupPathL		= @BackupPathL		 OUT
		,@BackupPathN		= @BackupPathN		 OUT
		,@BackupPathN2		= @BackupPathN2		 OUT
		,@DBASQLPath		= @DBASQLPath		 OUT
		,@SQLAgentLogPath	= @SQLAgentLogPath	 OUT
		,@DBAArchivePath	= @DBAArchivePath	 OUT
		,@EnvBackupPath		= @EnvBackupPath	 OUT
		,@SQLEnv			= @SQLEnv			 OUT
		,@CentralServerShare= @central_server	 OUT

/*********************************************************************
 *                Initialization
 ********************************************************************/


--Select @central_server = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'CentralServer'
--If @central_server is null
--   begin
--	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The nightly self check-in failed'
--	Print @miscprint
--	raiserror(@miscprint,-1,-1)
--	goto label99
--   end

-- \\sdcsqltools.db.${{secrets.DOMAIN_NAME}}\dba_reports\HealthChecks
Select @outfile_name = 'CentralHealthCheckUpdate_' + @@Servername + '.sql'
Select @outfile_path = @DBASQLPath + '\dba_reports\' + @outfile_name


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Create output file
EXEC [dbo].[dbasp_FileAccess_Write] ' ',@outfile_path,0,1


Select @miscprint = '--  SQL Health Check Central Update for server ' + @@servername + '  ' + convert(varchar(30), getdate(), 121)
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = ''
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @save_propertyname = (SELECT convert(sysname, serverproperty('ComputerNamePhysicalNetBIOS')))
Select @miscprint = '-- [ComputerNamePhysicalNetBIOS] = ' + @save_propertyname
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @save_propertyname = (SELECT convert(sysname, serverproperty('MachineName')))
Select @miscprint = '-- [MachineName] = ' + @save_propertyname
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @save_propertyname = (select @@SERVERNAME)
Select @miscprint = '-- [@@SERVERNAME] = ' + @save_propertyname
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @save_propertyname = (select @@SERVICENAME)
Select @miscprint = '-- [@@SERVICENAME] = ' + @save_propertyname
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = ''
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @save_HC_ID = (select top 1 HC_ID from dbo.HealthCheckLog where HCtype = 'start' order by HC_ID desc)
Select @save_Check_date = (select Check_date from dbo.HealthCheckLog where HC_ID = @save_HC_ID)


Select @miscprint = 'delete from DBAcentral.dbo.HealthCheckCentral where HCSQLname = ''' + @@servername + ''''
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = 'go'
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = ''
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = 'insert into DBAcentral.dbo.HealthCheckCentral (HCSQLname, HCcat, HCtype, HCstatus, Check_date) values (''' + @@servername + ''', ''SQL_Health_Check'', ''Start'', ''Success'', ''' + convert(varchar(30), @save_Check_date, 121) + ''')'
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = 'go'
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


Select @miscprint = ''
If @PrintLocal = 1
   begin
	Print @miscprint
   end
EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


If exists (select 1 from dbo.HealthCheckLog where HC_ID > @save_HC_ID and HCstatus in ('Fail', 'Warning'))
   begin
	log_loop_start:


	Select @save_HC_ID = (select top 1 HC_ID from dbo.HealthCheckLog where HC_ID > @save_HC_ID and HCstatus in ('Fail', 'Warning') order by HC_ID)


	Select @save_HCcat = HCcat, @save_HCtype = HCtype, @save_HCstatus = HCstatus, @save_HCPriority = HCPriority, @save_HCtest = HCtest, @save_DBname = DBname, @save_Check_detail01 = Check_detail01, @save_Check_detail02 = Check_detail02, @save_Check_date = Check_date
	From dbo.HealthCheckLog where HC_ID = @save_HC_ID


	Select @miscprint = 'insert into DBAcentral.dbo.HealthCheckCentral values (''' + @@servername + ''''
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	Select @miscprint = '                                                     , ''' + @save_HCcat + ''''
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	Select @miscprint = '                                                     , ''' + @save_HCtype + ''''
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	Select @miscprint = '                                                     , ''' + @save_HCstatus + ''''
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	If @save_HCPriority is null
	   begin
		Select @miscprint = '                                                     , null'
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end
	Else
	   begin
		Select @miscprint = '                            , ''' + @save_HCPriority + ''''
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end


	If @save_HCtest is null
	   begin
		Select @miscprint = '                                                     , null'
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end
	Else
	   begin
		Select @save_HCtest = Replace(@save_HCtest, '''', '''''')
		Select @miscprint = '                                                     , ''' + @save_HCtest + ''''
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end


	If @save_DBname is null
	   begin
		Select @miscprint = '                                                     , null'
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end
	Else
	   begin
		Select @miscprint = '                                                     , ''' + @save_DBname + ''''
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end


	If @save_Check_detail01 is null
	   begin
		Select @miscprint = '                                                     , null'
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end
	Else
	   begin
		Select @miscprint = '                                                     , ''' + @save_Check_detail01 + ''''
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end


	If @save_Check_detail02 is null
	   begin
		Select @miscprint = '                                                     , null'
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end
	Else
	   begin
		Select @miscprint = '                                                     , ''' + @save_Check_detail02 + ''''
		If @PrintLocal = 1
		   begin
			Print @miscprint
		   end
		EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1
	   end


	Select @miscprint = '                                                     , ''' + convert(varchar(30), @save_Check_date, 121) + ''')'
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	Select @miscprint = 'go'
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	Select @miscprint = ''
	If @PrintLocal = 1
	   begin
		Print @miscprint
	   end
	EXEC [dbo].[dbasp_FileAccess_Write] @miscprint,@outfile_path,1,1


	If exists (select 1 from dbo.HealthCheckLog where HC_ID > @save_HC_ID and HCstatus in ('Fail', 'Warning'))
	   begin
		goto log_loop_start
	   end
   end


--  Copy the file to the central server
Select @cmd = 'xcopy /Y /R "' + rtrim(@outfile_path) + '" "'+@central_server+'HealthChecks"'
If @PrintLocal = 1
   begin
	Print @cmd
   end
EXEC master.sys.xp_cmdshell @cmd, no_output

---- Update the local DBAOps database
--SET @cmd = 'sqlcmd -Slocalhost -dDBAOps -E -w265 -l120 -i'+@outfile_path+'  -o' + @DBASQLPath + '\dba_reports\' + 'HealthCeck_CentralUpdate.log'
--If @PrintLocal = 1
--   begin
--	Print @cmd
--   end
--EXEC master.sys.xp_cmdshell @cmd, no_output


-- Update the Central DBACentral database
SET @cmd = 'sqlcmd -S'+REPLACE(REPLACE(@central_server,'\\',''),'\dba_reports\','')+' -dDBACentral -E -w265 -l120 -i'+@outfile_path+'  -o' + @central_server + @@SERVERNAME+'_HealthCeck_CentralUpdate.log'
If @PrintLocal = 1
   begin
	Print @cmd
   end
EXEC master.sys.xp_cmdshell @cmd, no_output


file_copy_end:


---------------------------  Finalization  -----------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_ReportToCentral] TO [public]
GO
