SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Utilities]


/*********************************************************
 **  Stored Procedure dbasp_HC_Utilities
 **  Written by Steve Ledridge, Virtuoso
 **  January 13, 2015
 **  This procedure runs the Utilities check portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/13/2015	Steve Ledridge		New process.
--	02/12/2015	Steve Ledridge		New test to make sure d:\ dive is not the CD drive.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  verify DBAFiles\bin path
--  verify DBAFiles\bin path is in the default path
--  verify utility files exist


/***


--***/


DECLARE	 @miscprint			nvarchar(2000)
	,@cmd				nvarchar(500)
	,@save_DBApath			sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_servername3		sysname
	,@charpos			int
	,@save_test			nvarchar(4000)
	,@Path				VarChar(max)
	,@save_filepath			nvarchar(500)
	,@util_flag			char(1)


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Utilities'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Start verify DBAFiles\bin path (self healing)
Print 'Start verify DBAFiles\bin path (self healing)'
Print ''


If exists(select 1 from dbo.dbaudf_listdrives() where DriveLetter = 'D:' and TotalSize is not null)
   begin
	If DBAOps.dbo.dbaudf_GetFileProperty('d:\DBAFiles\bin','folder','exists') <> 'True'
	   begin
		EXEC master.sys.xp_create_subdir 'd:\DBAFiles\bin\'
	   end
   end
Else If exists(select 1 from dbo.dbaudf_listdrives() where DriveLetter = 'C:')
   begin
	If DBAOps.dbo.dbaudf_GetFileProperty('c:\DBAFiles\bin','folder','exists') <> 'True'
	   begin
		EXEC master.sys.xp_create_subdir 'c:\DBAFiles\bin\'
	   end
   end


Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''d:\DBAFiles\bin'',''folder'',''exists'')'
If DBAOps.dbo.dbaudf_GetFileProperty('d:\DBAFiles\bin','folder','exists') = 'True'
   BEGIN
	Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''d:\DBAFiles\bin'',''folder'',''exists'')'
	Select @save_DBApath = 'd:\DBAFiles\bin\'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'DBA path', 'Pass', 'High', @save_test, null, null, null, getdate())
   END
Else If DBAOps.dbo.dbaudf_GetFileProperty('c:\DBAFiles\bin','folder','exists') = 'True'
   BEGIN
	Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''c:\DBAFiles\bin'',''folder'',''exists'')'
	Select @save_DBApath = 'c:\DBAFiles\bin\'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'DBA path', 'Pass', 'High', @save_test, null, null, null, getdate())
   END
ELSE
   BEGIN
	Select @save_DBApath = 'unknown'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'DBA path', 'Fail', 'High', @save_test, null, null, null, getdate())
   END


If exists (select 1 from [dbo].[Local_ServerEnviro] where env_type = 'dba_bin_path')
   begin
	update [dbo].[Local_ServerEnviro] set env_detail = @save_DBApath where env_type = 'dba_bin_path'
   end
Else
   begin
	insert into [dbo].[Local_ServerEnviro] values('dba_bin_path', @save_DBApath)
   end


--  Start verify DBAFiles\bin is in the default path (self healing)
Print 'Start verify DBAFiles\bin is in the default path (self healing)'
Print ''


SELECT @Path = value FROM DBAOps.dbo.dbaudf_GetAllEVs() WHERE name = 'path'
If @Path not like '%' + @save_DBApath + '%'
   begin
	Select @cmd = 'setx PATH "%PATH%;' + @save_DBApath + '" /M'
	Print @cmd
	Print ''
	exec master.sys.xp_cmdshell @cmd, no_output
   end


--  Start check utilities in DBAFiles\bin path
/*
Print 'Start check utilities in DBAFiles\bin path'
Print ''


Select @util_flag = 'y'


Select @save_filepath = @save_DBApath + 'accesschk.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_accesschk.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'CHKCPU32.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_CHKCPU32.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'findstr.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_findstr.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'forfiles.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_forfiles.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'global.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_global.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'handle.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_handle.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'htdump.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_htdump.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'Kill.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_Kill.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'local.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_local.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'msinfo32.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_msinfo32.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'procexp.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_procexp.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'reg.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_reg.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'reg2.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_reg2.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'RMTSHARE.EXE'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_RMTSHARE.EXE', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'ROBOCOPY.EXE'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_ROBOCOPY.EXE', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'showacls.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_showacls.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'SHOWGRPS.EXE'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_SHOWGRPS.EXE', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'SLEEP.EXE'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_SLEEP.EXE', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'STRINGS.EXE'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_STRINGS.EXE', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'Tlist.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_Tlist.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_filepath = @save_DBApath + 'xcacls.exe'
Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''' + @save_filepath + ''',''file'',''exists'') <> ''True'''
If DBAOps.dbo.dbaudf_GetFileProperty(@save_filepath,'file','exists') <> 'True'
   begin
	Select @util_flag = 'n'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_xcacls.exe', 'Fail', 'Medium', @save_test, null, 'Util not found at ' + @save_DBApath, null, getdate())
   end


Select @save_test = 'na'
If @util_flag = 'y'
   BEGIN
	Select @save_test = 'If DBAOps.dbo.dbaudf_GetFileProperty(''d:\DBAFiles\bin'',''folder'',''exists'')'
	insert into [dbo].[HealthCheckLog] values ('Utilities', 'UtilFile_All', 'Pass', 'Medium', @save_test, null, 'All standard util files found at ' + @save_DBApath, null, getdate())
   END


*/


--  Finalization  ------------------------------------------------------------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Utilities] TO [public]
GO
