SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSbase_archive]

/***************************************************************
 **  Stored Procedure dbasp_SYSbase_archive
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 31, 2009
 **
 **  This proc will archive all the local baseline folders and
 **  related SQL files in a folder under the backup share.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	08/31/2009	Steve Ledridge		New process
--	======================================================================================


/***


--***/


Declare
	 @miscprint		nvarchar(500)
	,@BkUpPath		nvarchar(500)
	,@save_sharepath	nvarchar(500)
	,@save_sharename	sysname
	,@save_foldername	sysname
	,@cmd			nvarchar(2000)
	,@parm01		nvarchar(100)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@charpos		int
	,@fileexist_path	nvarchar(255)


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Creat temp tables
Create table #ShareTempTable1(path nvarchar(500) null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


--  set the backup path
Select @parm01 = @save_servername2 + '_backup'
exec DBAOps.dbo.dbasp_get_share_path @parm01, @BkUpPath output


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Develope a list of shares on the local server
Select @cmd = 'net share'


--print @cmd /* for debugging */
Insert into #ShareTempTable1
exec master.sys.xp_cmdshell @cmd


delete from #ShareTempTable1 where path not like '%_BASE_%'
delete from #ShareTempTable1 where path is null
--select * from #ShareTempTable1 /* for debugging */


If (select count(*) from #ShareTempTable1) > 0
   begin
	--  check to see if the BASE_archive folder exists (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @BkUpPath  + '\BASE_archive'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @BkUpPath + '\BASE_archive"'
		Print 'Creating BASE_archive folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	--  set @BkUpPath
	Select @BkUpPath = @BkUpPath + '\BASE_archive'


	start01:
	Select @save_sharename = (select top 1 path from #ShareTempTable1)


	--  Get drive letter path to this share
	Select @parm01 = @save_sharename
	exec DBAOps.dbo.dbasp_get_share_path @parm01, @save_sharepath output
	--print @save_sharepath


	--  Get folder name for this share
	set @save_foldername = right(@save_sharepath,charindex('\',reverse(@save_sharepath))-1)
	--print @save_foldername


	--  check to see if this folder exists under the BASE_archive folder (create it if needed)
	Delete from #fileexists
	Select @fileexist_path = @BkUpPath  + '\' + @save_foldername
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @BkUpPath + '\' + @save_foldername + '"'
		Print 'Creating BASE_archive\' + @save_foldername + ' folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	select @cmd = 'robocopy /Z /R:5 ' + @save_sharepath + ' ' + @BkUpPath + '\' + @save_foldername + ' *.sql'
	Print @cmd
	exec master.sys.xp_cmdshell @cmd


	--  Check for more folders to process
	delete from #ShareTempTable1 where path = @save_sharename
	If (select count(*) from #ShareTempTable1) > 0
	   begin
		goto start01
	   end


   end


--  End ---------------------------------------------------------------------------------------------

Label99:


drop table #ShareTempTable1
drop table #fileexists
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSbase_archive] TO [public]
GO
