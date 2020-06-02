SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_depl_NXTdelete] @environment sysname = null


/*********************************************************
 **  Stored Procedure dbasp_depl_NXTdelete
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 01, 2005
 **
 **  This procedure is used to delete mdfnxt files prior to
 **  pushing deployment baseline files out to servers in
 **  the dev, test, load and stage environments.
 **
 **  MDFnxt and NDFnxt files are used as part of the
 **  file attach process in SQL deployments.  These files
 **  exist on a central SQL server and are pushed to the
 **  target servers as part of the weekly baseline process.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/01/2005	Steve Ledridge		New process
--	07/20/2005	Steve Ledridge		Delete MDFNXT files from active and non-active
--						sql servers.
--	10/12/2005	Steve Ledridge		Delete *NXT files from the new NXT shares
--	05/14/2007	Steve Ledridge		Added delete for NXT files on the central server.
--	05/14/2007	Steve Ledridge		Updated for SQL 2005.
--	06/19/2007	Steve Ledridge		New columns in depl_server_db_list
--	06/22/2007	Steve Ledridge		New select for temp table insert
--	08/06/2007	Steve Ledridge		Added delete for SQB files
--	02/11/2008	Steve Ledridge		Added unlocker processing for locked files.
--	02/25/2008	Steve Ledridge		Fixed lines that were commented out in error.
--	08/22/2008	Steve Ledridge		New table dba_dbinfo.
--	08/31/2009	Steve Ledridge		Changed Unlocker to Big Hammer and added kill code.
--	10/07/2009	Steve Ledridge		Added code for new environments (alpha, beta, etc.).
--	04/25/2011	Steve Ledridge		Changed code to delete all files from NXT and BASE.
--	11/14/2011	Steve Ledridge		Changed Big Hammer to the newer unlock and delete process.
--	02/11/2013	Steve Ledridge		Skip unlock and delete process.
--	05/28/2015	Steve Ledridge		New code for QA environment.
--	======================================================================================


/***
Declare @environment sysname


--Select @environment = 'dev'
Select @environment = 'central'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@charpos			int
	,@exists 			bit
	,@cmd				nvarchar(4000)
	,@error_count			int
	,@retry_nxt			smallint
	,@retry_sqb			smallint
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_trgt_servername		sysname
	,@save_trgt_servername2		sysname
	,@save_filename			nvarchar(255)
	,@check_path			nvarchar(500)
	,@parm01			nvarchar(500)
	,@drive_path			nvarchar(500)
	,@hammer_path			nvarchar(500)
	,@kCMD				sysname
	,@proc				sysname
	,@cmd1				nvarchar(4000)
	,@cmd2				nvarchar(4000)


DECLARE
	 @cu11depl_servername		sysname


DECLARE
	 @cu22depl_restore_folder	sysname


----------------  initial values  -------------------
Select @error_count = 0


--  Create table variable
declare @tvar_server_list table(detail01 sysname)


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


create table #tkill(cmd nvarchar(4000))


--  Verify imput parm
if @environment not in ('dev', 'test', 'load', 'stage', 'alpha', 'beta', 'candidate', 'prodsupport', 'QA', 'central')
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameter for @environment'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


if @environment = 'central'
   BEGIN
	goto skip_servername
   END


--  Start process for non-central servers
Insert @tvar_server_list SELECT distinct(SQLname)
				From DBAOps.dbo.DBA_DBInfo
				Where ENVname = @environment
				  and BaselineServername = @@servername
				  and BaselineFolder <> 'na'
				  and BaselineFolder <> ''


If (select count(*) from @tvar_server_list) > 0
   begin
	start_servername:
	Select @cu11depl_servername = (select top 1 detail01 from @tvar_server_list)


	Select @save_trgt_servername = @cu11depl_servername
	Select @save_trgt_servername2 = @cu11depl_servername


	Select @charpos = charindex('\', @cu11depl_servername)
	IF @charpos <> 0
	   begin
		Select @save_trgt_servername = substring(@cu11depl_servername, 1, (CHARINDEX('\', @cu11depl_servername)-1))
		Select @save_trgt_servername2 = stuff(@cu11depl_servername, @charpos, 1, '$')
	   end


	--  Format and execute the robocopy command to delete the 'nxt' file from the mdf share
	SELECT @cmd = 'DEL \\' + rtrim(@save_trgt_servername) + '\' + rtrim(@save_trgt_servername2) + '_mdf\*.*nxt /Q'
	PRINT @cmd
	EXEC master.sys.xp_cmdshell @cmd


	--  Format and execute the robocopy command to delete all files from the nxt share
	SELECT @cmd = 'DEL \\' + rtrim(@save_trgt_servername) + '\' + rtrim(@save_trgt_servername2) + '_nxt\*.* /Q'
	PRINT @cmd
	EXEC master.sys.xp_cmdshell @cmd


	--  Check to see if there are more records to process
	Delete from @tvar_server_list where detail01 = @cu11depl_servername
	If (select count(*) from @tvar_server_list) > 0
	   begin
		goto start_servername
	   end


   end


skip_servername:


--  Start process for the local central server


if @environment <> 'central'
   BEGIN
	goto skip_central
   END


Delete from @tvar_server_list
Insert @tvar_server_list select distinct (BaselineFolder)
				from DBAOps.dbo.DBA_DBInfo
				where BaselineServername = @@servername
				  and BaselineFolder <> 'na'
				  and BaselineFolder <> ''


If (select count(*) from @tvar_server_list) > 0
   begin
	start_central:


	Select @cu22depl_restore_folder = (select top 1 detail01 from @tvar_server_list)


	Select @retry_sqb = 0
	retry_sqb:


	--  Format and execute the robocopy command to delete the 'sqb' file from the BASE share
	SELECT @cmd = 'DEL \\' + @@servername + '\' + @@servername + '_BASE_' + rtrim(@cu22depl_restore_folder) + '\*.* /Q'
	PRINT @cmd
	Exec master.sys.xp_cmdshell @cmd


	--  Check to make sure files were deleted
	Select @cmd = 'DIR \\' + @@servername + '\' + @@servername + '_BASE_' + rtrim(@cu22depl_restore_folder) + '\*.* /B'
	print @cmd
	delete from #DirectoryTempTable
	insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
	delete from #DirectoryTempTable where cmdoutput is null
	delete from #DirectoryTempTable where cmdoutput not like '%.sqb%' and cmdoutput not like '%.bak%' and cmdoutput not like '%.cbak%'
	--select * from #DirectoryTempTable


	--  If all sqb files were not deleted, use the unlock and delete process
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		Print 'Note:  SQB file delete failed.  Unlocking this file now.'
		Print ''


		Print 'SPCL Note:  Skip unlock file process for now.'
		Print ''


		Select @save_filename = (select top 1 cmdoutput from #DirectoryTempTable)
		Select @save_filename = rtrim(ltrim(@save_filename))


		Select @miscprint = 'DBA Baseline error: File delete error encountered for: ' + @drive_path + '\' + @save_filename
		Print @miscprint
		RAISERROR( @miscprint, 16, -1 )


	--	Select @save_filename = (select top 1 cmdoutput from #DirectoryTempTable)
	--	Select @save_filename = rtrim(ltrim(@save_filename))
	--
	--	Print 'Note:  Using Unlock and Delete on file: ' + @save_filename
	--	exec dbo.dbasp_UnlockAndDelete @FileName = @save_filename, @Unlock = 1, @Delete = 1
	--
	--	If @retry_sqb < 3
	--	   begin
	--		Select @retry_sqb = @retry_sqb + 1
	--		goto retry_sqb
	--	   end
	--	Else
	--	   begin
	--		Select @miscprint = 'DBA Baseline error: File delete error encountered for: ' + @drive_path + '\' + @save_filename
	--		Print @miscprint
	--		RAISERROR( @miscprint, 16, -1 )
	--	   end
	    end


	--  Check to see if there are more records to process
	Delete from @tvar_server_list where detail01 = @cu22depl_restore_folder
	If (select count(*) from @tvar_server_list) > 0
	   begin
		goto start_central
	   end


   end


skip_central:


--  Finalization  -------------------------------------------------------------------


label99:


drop table #DirectoryTempTable
drop table #tkill
GO
GRANT EXECUTE ON  [dbo].[dbasp_depl_NXTdelete] TO [public]
GO
