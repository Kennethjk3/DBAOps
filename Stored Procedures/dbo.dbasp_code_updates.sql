SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_code_updates] (@DBname sysname = 'all')


/**************************************************************
 **  Stored Procedure dbasp_code_updates
 **  Written by Steve Ledridge, Virtuoso
 **  February 13, 2008
 **
 **  This dbasp is set up to check for new updates of DBAOps
 **  DBAperf and SQLdeploy.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/13/2008	Steve Ledridge		New process for SQL 2005.
--	03/16/2010	Steve Ledridge		Added section for dbaperf DB.
--	05/14/2012	Steve Ledridge		Added DBname input parm.
--	08/06/2012	Steve Ledridge		Fixed code for processing 2008 release files.
--	04/02/2013	Steve Ledridge		Added goto end of section for DEPLinfo and SQLdeploy.
--	04/11/2013	Steve Ledridge		Remove DEPLinfo.
--	04/22/2013	Steve Ledridge		Removed references to 2005 and 2008.
--	04/25/2013	Steve Ledridge		Removed references to 20.
--	03/24/2016	Steve Ledridge		New code to pull All CLR file to dbasql share.
--	======================================================================================


/***
Declare @DBname sysname


Select @DBname = 'all'
--***/


-----------------  declares  ------------------
DECLARE
	 @cmd			nvarchar(4000)
	,@sqlcmd		nvarchar(500)
	,@charpos		int
	,@central_server 	sysname
	,@ENVname	 	sysname
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_filename		sysname
	,@save_cmdoutput	nvarchar(255)
	,@singleDB		char(1)


set @singleDB = 'n'


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @central_server = env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer'
Select @ENVname = env_detail from dbo.Local_ServerEnviro where env_type = 'ENVname'
--print @central_server
--print @ENVname


If @DBname = 'DBAOps'
   begin
	set @singleDB = 'y'
	goto start_DBAOps
   end


If @DBname = 'DBAperf'
   begin
	set @singleDB = 'y'
	goto start_DBAperf
   end


If @DBname = 'SQLdeploy'
   begin
	set @singleDB = 'y'
	goto start_SQLdeploy
   end


--  DBAOps Process ---------------------------------------------------------------------------------------------
start_DBAOps:


--  capture dir from central server
delete from #DirectoryTempTable
select @cmd = 'dir /B \\' + @central_server + '\' + @central_server + '_builds\DBAOps\' + @ENVname
Print @cmd
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput not like '%DBAOps_release%'
--select * from #DirectoryTempTable


--  start process
start_process01:
If (select count(*) from #DirectoryTempTable) > 0
   begin
	Select @save_cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like '%DBAOps_release%')
	Select @save_filename = @save_cmdoutput


	--  check to see if this file has already been run
	If @save_filename not in (select vchNotes from dbo.build where vchName = 'DBAOps')
	   begin
		select @sqlcmd = 'sqlcmd -S' + @@servername + ' -dDBAOps -i\\' + @central_server + '\' + @central_server + '_builds\DBAOps\' + @ENVname + '\' + rtrim(@save_filename) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\DBAOps_release.txt -E'
		print @sqlcmd
		exec master.sys.xp_cmdshell @sqlcmd
	   end
   end


--  Copy All CLR file (if does not match already) to the local dbasql share
Select @cmd = 'robocopy \\' + @central_server + '\' + @central_server + '_builds\DBAOps\production \\' + @save_servername + '\' + @save_servername2 + '_dbasql ALL_DBAOps_32_CLR.sql /E /Z /R:3'
Print @cmd
EXEC master.sys.xp_cmdshell @cmd
Print ' '


If @singleDB = 'y'
   begin
	goto label99
   end


--  DBAPERF Process ---------------------------------------------------------------------------------------------
start_DBAperf:


--  capture dir from central server
delete from #DirectoryTempTable
select @cmd = 'dir /B \\' + @central_server + '\' + @central_server + '_builds\dbaperf\' + @ENVname
Print @cmd
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput not like '%dbaperf_release%'
--select * from #DirectoryTempTable


--  start process
start_process02:
If (select count(*) from #DirectoryTempTable) > 0
   begin
	Select @save_cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like '%dbaperf_release%')
	Select @save_filename = @save_cmdoutput


	--  check to see if this file has already been run
	If @save_filename not in (select vchNotes from dbo.build where vchName = 'dbaperf')
	   begin
		select @sqlcmd = 'sqlcmd -S' + @@servername + ' -ddbaperf -i\\' + @central_server + '\' + @central_server + '_builds\dbaperf\' + @ENVname + '\' + rtrim(@save_filename) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\dbaperf_release.txt -E'
		print @sqlcmd
		exec master.sys.xp_cmdshell @sqlcmd
	   end
   end


Delete from #DirectoryTempTable where cmdoutput = @save_cmdoutput
If (select count(*) from #DirectoryTempTable) > 0
   begin
	goto start_process02
   end


If @singleDB = 'y'
   begin
	goto label99
   end


--  SQLdeploy Process ---------------------------------------------------------------------------------------------
start_SQLdeploy:


If (SELECT DATABASEPROPERTYEX ('SQLdeploy','status')) <> 'ONLINE' or (SELECT DATABASEPROPERTYEX ('SQLdeploy','status')) is null
   begin
	goto end_SQLdeploy
   end


--  capture dir from central server
delete from #DirectoryTempTable
select @cmd = 'dir /B \\' + @central_server + '\' + @central_server + '_builds\SQLdeploy\'
Print @cmd
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput not like '%SQLdeploy_release%'
--select * from #DirectoryTempTable


--  start process
start_process04:
If (select count(*) from #DirectoryTempTable) > 0
   begin
	Select @save_cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like '%SQLdeploy_release%')
	Select @save_filename = @save_cmdoutput


	--  check to see if this file has already been run
	If @save_filename not in (select vchNotes from SQLdeploy.dbo.build where vchName = 'SQLdeploy')
	   begin
		select @sqlcmd = 'sqlcmd -S' + @@servername + ' -dSQLdeploy -i\\' + @central_server + '\' + @central_server + '_builds\SQLdeploy\' + rtrim(@save_filename) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\SQLdeploy_release.txt -E'
		print @sqlcmd
		exec master.sys.xp_cmdshell @sqlcmd
	   end
   end


Delete from #DirectoryTempTable where cmdoutput = @save_cmdoutput
If (select count(*) from #DirectoryTempTable) > 0
   begin
	goto start_process04
   end


If @singleDB = 'y'
   begin
	goto label99
   end


end_SQLdeploy:


----------------  End  -------------------


label99:


Print ''
Print 'Code Update Process Complete.'


drop table #DirectoryTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_code_updates] TO [public]
GO
