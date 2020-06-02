SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FileCleanup](@targetpath nvarchar(2000) = null
					,@retention int = 90
					,@process sysname = 'Report'
					,@filesonly char(1) = 'n'
					,@force_delete char(1) = 'n'
					,@skip_mask nvarchar(500) = 'PermanentRetention')

/*********************************************************
 **  Stored Procedure dbasp_FileCleanup
 **  Written by Steve Ledridge, Virtuoso
 **  December 10,2008
 **
 **  This procedure is used to delete files older than the
 **  specified retention value (in days).
 **
 **
 **  This proc accepts several input parms (outlined below):
 **
 **  - @targetpath is the path where files are located.
 **
 **  - @retention is the value of days back or days old. In others
 **    setting the parameter to 90 will delete files older than 90 days
 **    from the current date.
 **
 **  - @process - 'Report' for a report of what will be processed.
 **               'Delete' will do the work.
 **
 **  - @filesonly 'y' will process files, 'n' files and folders and 'x' folders only.
 **
 **  - @force_delete 'y' will delete files with no regard for other files or folders.
 **
 **  - @skip_mask - default is 'PermanentRetention'.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/10/2008	Steve Ledridge		New process
--	05/06/2010	Steve Ledridge		Major revision  (rewrite)
--	10/12/2010	Steve Ledridge		Added force delete input parm.
--	11/02/2011	Steve Ledridge		Added seperate section for folder deletes.
--	05/07/2012	Steve Ledridge		Added skip mask process.
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	04/10/2013	Steve Ledridge		Added DataMigration and deployment_logs to folder skip.
--	======================================================================================


/***
declare @targetpath nvarchar(2000)
declare @retention int
declare @process sysname
declare @filesonly char(1)
declare @force_delete char(1)
declare @skip_mask nvarchar(500)


set @targetpath = 'e:\appdata'
set @retention = 45
--set @process = 'report'
set @process = 'delete'
set @filesonly = 'n'
set @force_delete = 'n'
Set @skip_mask = 'PermanentRetention'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@charpos		int
	,@cmd	 		nvarchar(4000)
	,@save_folder_date	datetime
	,@save_folder_name	nvarchar(4000)
	,@save_cmdoutput	nvarchar(4000)
	,@save_cmdoutput_hold	nvarchar(4000)
	,@save_delete_cmd	nvarchar(4000)
	,@save_folder_cmd	nvarchar(4000)
	,@save_comp_cmd		nvarchar(2000)
	,@save_reverse_cmd	nvarchar(2000)
	,@save_reset_cmd	nvarchar(2000)
	,@save_f_id		int
	,@retention_char	nvarchar(10)


----------------  initial values  -------------------
Select @retention_char = convert(nvarchar(10), @retention)


--  create temp tables
create table #DirectoryTempTable(cmdoutput nvarchar(4000) null)
create table #DirTempTable2(cmdoutput nvarchar(4000) null)
create table #DirTempTable3(cmdoutput nvarchar(4000) null)


create table #DirectoryFolderTable (f_id [int] IDENTITY(1,1) NOT NULL
				,cmdoutput nvarchar(3000) null)


create table #fileexists (
	doesexist smallint,
	fileindir smallint,
	direxist smallint)


--  Verify source path existance
Insert into #fileexists exec master.sys.xp_fileexist @targetpath
--select * from #fileexists


If not exists (select 1 from #fileexists where fileindir = 1)
   begin
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_FileCleanup - Target Path does not exist.  Check input parameter.'
	print @miscprint
	goto label99
   end


select @cmd = 'forfiles /p '+@targetpath+' -s -m * -d -'+@retention_char+' -c "cmd /c echo del /q @path,@isdir"'
--Print @cmd


--  Table to process against - files
delete from #DirectoryTempTable
Insert into #DirectoryTempTable(cmdoutput) exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput like '%No files found%'
delete from #DirectoryTempTable where cmdoutput like '%,TRUE%'
delete from #DirectoryTempTable where cmdoutput like '%DS_Store%'
If @skip_mask is not null and @skip_mask <> ''
   begin
	delete from #DirectoryTempTable where cmdoutput like '%' + @skip_mask + '%'
   end
--select * from #DirectoryTempTable


select @cmd = 'forfiles /p '+@targetpath+' -s -c "cmd /c echo @path,@isdir"'
--Print @cmd


--  Table to process against -folders
delete from #DirectoryFolderTable
Insert into #DirectoryFolderTable(cmdoutput) exec master.sys.xp_cmdshell @cmd
delete from #DirectoryFolderTable where cmdoutput is null
delete from #DirectoryFolderTable where cmdoutput like '%No files found%'
delete from #DirectoryFolderTable where cmdoutput like '%,FALSE%'
delete from #DirectoryFolderTable where cmdoutput like '%DataMigration%'
delete from #DirectoryFolderTable where cmdoutput like '%deployment_logs%'
If @skip_mask is not null and @skip_mask <> ''
   begin
	delete from #DirectoryTempTable where cmdoutput like '%' + @skip_mask + '%'
   end
--select * from #DirectoryFolderTable


/****************************************************************
 *                MainLine
 ***************************************************************/


--  File Processing
If @process <> 'delete'
   begin
	Select @miscprint = 'Here are the files older than ' + @retention_char + ' days.'
	Print @miscprint
	Select @miscprint = 'Use the input parm @process = ''delete'' to delete these files and any empty folders.'
	Print @miscprint

	select * from #DirectoryTempTable
	goto label99
   end

--  At this point we are in delete mode
If @filesonly = 'x'
   begin
	goto folder_processing
   end


If (select count(*) from #DirectoryTempTable) > 0
   begin
	start_file_delete:
	Select @save_cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable order by cmdoutput)
	Select @save_cmdoutput_hold = @save_cmdoutput
	Select @save_cmdoutput = replace(@save_cmdoutput, ',FALSE', '')

	If @force_delete = 'y'
	   begin
		goto file_delete
	   end

	--  Check to see if there are other files in this folder not within the retention date
	--  If so, skip the delete for this file
	Select @save_comp_cmd = replace(@save_cmdoutput, ',FALSE', '')
	Select @save_reverse_cmd = reverse(@save_comp_cmd)


	Select @charpos = charindex('\', @save_reverse_cmd)
	IF @charpos <> 0
	   begin
		Select @save_reverse_cmd = substring(@save_reverse_cmd, @charpos+1, len(@save_reverse_cmd)-@charpos)
		Select @save_comp_cmd = reverse(@save_reverse_cmd) + '"'
	   end

	Select @save_comp_cmd = replace(@save_comp_cmd, 'del /q', '')
	Select @save_comp_cmd = ltrim(@save_comp_cmd)

	select @cmd = 'forfiles /p '+@save_comp_cmd+' -s -m * -d -'+@retention_char+' -c "cmd /c echo del /q @path,@isdir"'
	--Print @cmd
	delete from #DirTempTable2
	Insert into #DirTempTable2(cmdoutput) exec master.sys.xp_cmdshell @cmd
	delete from #DirTempTable2 where cmdoutput is null
	delete from #DirTempTable2 where cmdoutput like '%,TRUE%'
	--select * from ##DirTempTable2

	select @cmd = 'forfiles /p '+@save_comp_cmd+' -s -m * -d -0 -c "cmd /c echo del /q @path,@isdir"'
	--Print @cmd
	delete from #DirTempTable3
	Insert into #DirTempTable3(cmdoutput) exec master.sys.xp_cmdshell @cmd
	delete from #DirTempTable3 where cmdoutput is null
	delete from #DirTempTable3 where cmdoutput like '%,TRUE%'
	--select * from ##DirTempTable3

	If (Select count(*) from #DirTempTable3) > (Select count(*) from #DirTempTable2)
	   begin
		Select @miscprint = 'Skipping delete for files in folder ' + @save_comp_cmd + ' because other files in this folder are not past retention.'
		Print @miscprint
		goto skip_file_delete
	   end

	--  Verify the folder this file lives in is also past the retention period
	--  If not, skip the delete for this file
	Select @save_folder_date = dbo.dbaudf_GetFileProperty (replace(@save_comp_cmd, '"', ''), 'Folder', 'CreationTime')
	If datediff(dd, @save_folder_date, getdate()) < @retention
	   begin
		Select @miscprint = 'Skipping delete for files in folder ' + @save_comp_cmd + ' because the folder is not past retention.'
		Print @miscprint
		goto skip_file_delete
	   end


	file_delete:
	--  File delete process
	Select @save_reset_cmd = @save_cmdoutput
	Select @save_reset_cmd = replace(@save_reset_cmd, 'del /q', 'attrib -r -h -s')
	Print @save_reset_cmd
	exec master.sys.xp_cmdshell @save_reset_cmd


	Select @save_delete_cmd = @save_cmdoutput
	Print @save_delete_cmd
	exec master.sys.xp_cmdshell @save_delete_cmd


	skip_file_delete:
	--  check for more rows to process
	delete from #DirectoryTempTable where cmdoutput = @save_cmdoutput_hold
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto start_file_delete
	   end
   end


--  Folder Processing
folder_processing:


If @filesonly = 'y'
   begin
	goto label99
   end


If (select count(*) from #DirectoryFolderTable) > 0
   begin
	start_folder_delete:
	Select @save_f_id = (select top 1 f_id from #DirectoryFolderTable order by f_id desc)
	Select @save_cmdoutput = (select cmdoutput from #DirectoryFolderTable where f_id = @save_f_id)
	Select @save_cmdoutput = replace(@save_cmdoutput, ',TRUE', '')


	--  Check folder date
	Select @save_folder_date = dbo.dbaudf_GetFileProperty (replace(@save_cmdoutput, '"', ''), 'Folder', 'CreationTime')
	If datediff(dd, @save_folder_date, getdate()) < @retention
	   begin
		Select @miscprint = 'Skipping delete for folder ' + @save_cmdoutput + ' because the folder is not past retention.'
		Print @miscprint
		goto skip_folder_delete
	   end


	--  Check To see if this folder is empty
	select @cmd = 'dir '+@save_cmdoutput+' /B'
	--Print @cmd
	delete from #DirTempTable2
	Insert into #DirTempTable2(cmdoutput) exec master.sys.xp_cmdshell @cmd
	delete from #DirTempTable2 where cmdoutput is null
	--select * from ##DirTempTable2


	If (select count(*) from #DirTempTable2) > 0
	   begin
		Select @miscprint = 'Skipping delete for folder ' + @save_cmdoutput + ' because the folder is not empty.'
		Print @miscprint
		goto skip_folder_delete
	   end


	--  Check to see if this is a level01 folder we want to keep
	Select @save_folder_name = replace(@save_cmdoutput, '"', '')
	Select @save_folder_name = replace(@save_folder_name, @targetpath, '')


	If left(@save_folder_name, 1) = '\'
	   begin
		Select @save_folder_name = substring(@save_folder_name, 2, len(@save_folder_name)-1)
	   end

	If @save_folder_name in (select db_name from dbo.db_ApplCrossRef)
	   or @save_folder_name in (select appl_desc from dbo.db_ApplCrossRef)
	   or @save_folder_name in (select RSTRfolder from dbo.db_ApplCrossRef)
	   begin
		Select @miscprint = 'Skipping delete for folder ' + @save_cmdoutput + ' because this level01 folder is one we want to save.'
		Print @miscprint
		goto skip_folder_delete
	   end


	--  Delete the Folder
	Select @save_delete_cmd = 'rmdir ' + @save_cmdoutput + ' /Q'
	Print @save_delete_cmd
	exec master.sys.xp_cmdshell @save_delete_cmd


	skip_folder_delete:
	--  check for more rows to process
	delete from #DirectoryFolderTable where f_id = @save_f_id
	If (select count(*) from #DirectoryFolderTable) > 0
	   begin
		goto start_folder_delete
	   end


   end


---------------------------  Finalization  -----------------------
label99:


drop table #DirectoryTempTable
drop table #DirectoryFolderTable
drop table #DirTempTable2
drop table #DirTempTable3
drop table #fileexists
GO
GRANT EXECUTE ON  [dbo].[dbasp_FileCleanup] TO [public]
GO
