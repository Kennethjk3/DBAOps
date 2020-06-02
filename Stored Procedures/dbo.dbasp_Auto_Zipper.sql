SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Auto_Zipper] (@source_path varchar(200) = null
					,@files_starttext sysname = null
					,@files_midtext sysname = null
					,@files_extension sysname = null
					,@ZipFile_name sysname = null
					,@delete_source_files char(1) = 'y'
					,@timestamp_on_zipfile char(1) = 'y'
					,@retention_days smallint = 7)


/*********************************************************
 **  Stored Procedure dbasp_Auto_Zipper
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  June 26, 2003...ccc
 **
 **  This procedure is used to compress multiple files located
 **  at a specific path, and either retain or remove the
 **  source files.  This is for local paths only, and the
 **  winzip command line feature must be installed locally.
 **
 **  This proc accepts several input parms (outlined below):
 **
 **  - @source_path is the drive letter path or the local share
 **    that holds the source files which are to be compressed.
 **
 **  - @files_starttext (optional) is the starting text of the
 **    file names you will be compressing. (i.e. al files that
 **    start with 'bac').  Do not use an * in this field.
 **
 **  - @files_midtext (optional) is the mid text of the file names
 **    you will be compressing.  (i.e. all files which have '_trn_'
 **    somewhere in the name).  Do not use an * in the field.
 **
 **  - @files_extension is the file extension, a wild card or a
 **    combination of the two.  Enter '*all*' in this field to
 **    compress all files in the directory.
 **
 **  - @ZipFile_name is the name of the output file.  A date/time
 **    stamp will be added to the file name along with a file
 **    extension of '.zip'.
 **
 **  - @delete_source_files is a flag for deleting the source
 **    files.  The default is to delete the files once they are
 **    compressed.  Specifiy 'n' to retain the source files in place.
 **
 **  - @timestamp_on_zipfile is a flag for suppressing the timestamp that
 **    is normally added to the output zip file name.  Specifiy 'n' to
 **    create a result zip file without the added timestamp as part of the
 **    file name.
 **
 ***************************************************************/
  as


SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/26/2003	Steve Ledridge		New process
--	07/18/2003	Steve Ledridge		Added purge process and check for files to zip
--	04/21/2004	Steve Ledridge		Added info to DBA Warnings
--	11/07/2006	Steve Ledridge		Modified for SQL 2005.
--	04/11/2008	Steve Ledridge		Added support for share sub-folders.
--	======================================================================================


/***
Declare
	 @source_path varchar(200)
	,@files_starttext sysname
	,@files_midtext sysname
	,@files_extension sysname
	,@ZipFile_name sysname
	,@delete_source_files char(1)
	,@timestamp_on_zipfile char(1)
	,@retention_days smallint


Select @source_path = 'seadcdwdmsppa_DBASQL\dba_reports'
--Select @source_path = 'd:\'
Select @files_starttext = 'ImageRankReport'
Select @files_midtext = ''
Select @files_extension = 'csv'
Select @ZipFile_name = 'test_zip01'
Select @delete_source_files = 'n'
Select @timestamp_on_zipfile = 'n'
Select @retention_days = 7
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		    nvarchar(4000)
	,@cmd			    nvarchar(4000)
	,@charpos		    int
	,@BkUpDateStmp 		    char(14)
	,@save_datestmp		    datetime
	,@save_ZipFile_name 	    sysname
	,@save_zip_path		    sysname
	,@save_source_path_extra    sysname
	,@Hold_hhmmss		    nvarchar(8)
	,@error_count		    int
	,@parm01		    nvarchar(100)
	,@outpath 		    nvarchar(255)
	,@zip_path 		 nvarchar(200)
	,@zip_path_name		    nvarchar(200)
	,@zip_action 		    nvarchar(5)
	,@selection		    sysname
	,@zip_selection		    sysname


----------------  initial values  -------------------
Select @error_count = 0


--  Verify imput parms
if @source_path is null or (@files_starttext is null and @files_midtext is null and @files_extension is null)
   BEGIN
	Select @miscprint = 'DBA WARNING: dbasp_Auto_Zipper - Invalid input parm(s)'
--print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


--  Verify/Set ZipFile Name
if @ZipFile_name is null or @ZipFile_name = ''
   BEGIN
	Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
	Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)
	If @timestamp_on_zipfile = 'y'
	   begin
		Select @ZipFile_name = 'DBAzip_' +  @BkUpDateStmp + '.zip'
	   end
	Else
	   begin
		Select @ZipFile_name = 'DBAzip.zip'
	   end
   END
Else
   BEGIN
	Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
	Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)
	If @timestamp_on_zipfile = 'y'
	   begin
		Select @ZipFile_name = @ZipFile_name + '_' + @BkUpDateStmp + '.zip'
	   end
	Else
	   begin
		Select @ZipFile_name = @ZipFile_name + '.zip'
	   end
   END


--  Verify @delete_source_files flag
if @delete_source_files not in ('n','y')
   BEGIN
	Select @miscprint = 'DBA WARNING: dbasp_Auto_Zipper - Invalid input parm for @delete_source_files.  Must be ''y'' or ''n''.'
--print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


/****************************************************************
 *                MainLine
 ***************************************************************/


--  check to see if the source path is a full path or a local share
--  and either way, set the output path variable
Select @charpos = charindex(':\', @source_path)
IF @charpos <> 0
   begin
	select @zip_path = @source_path
   end
Else
   begin
	--  Get the path to the source file share
	Select @parm01 = @source_path
	Select @save_source_path_extra = ''


	Select @charpos = charindex('\', @parm01)
	IF @charpos <> 0
	   begin
		Select @save_source_path_extra = substring(@parm01, @charpos, 255)
		Select @parm01 = substring(@parm01, 1, @charpos-1)
	   end


	--exec DBAOps.dbo.dbasp_get_share_path @parm01, @outpath output
	SET @outpath = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)
	If @outpath is null
	   begin
		Select @miscprint = 'DBA WARNING: dbasp_Auto_Zipper - Unable to find file share for given source path.  Check input parameter.'
		--print @miscprint
		raiserror(@miscprint,-1,-1) with log
		Select @error_count = @error_count + 1
		goto label99
	   end
	Else
	   begin
		select @zip_path = @outpath + @save_source_path_extra
	   end
   end


print @zip_path


--  Verify source path existance
create table #fileexists (
	doesexist smallint,
	fileindir smallint,
	direxist smallint)


Insert into #fileexists exec master.sys.xp_fileexist @zip_path


--select * from #fileexists


If not exists (select fileindir from #fileexists where fileindir = 1)
   begin
	Select @miscprint = 'DBA WARNING: dbasp_Auto_Zipper - Source Path does not exist.  Check input parameter.'
--print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


--  Set output file name
If @zip_path like '%\'
   begin
	Select @zip_path_name = @zip_path + @ZipFile_name
   end
Else
   begin
	Select @zip_path_name = @zip_path + '\' + @ZipFile_name
   end


--  Build the zip command string


--  First we build the selection string
Select @selection = '*.'


If @files_midtext is not null and @files_midtext <> ''
   begin
	Select @selection = '*' + rtrim(@files_midtext) + @selection
   end


If @files_starttext is not null and @files_starttext <> ''
   begin
	Select @selection = rtrim(@files_starttext) + @selection
   end


If @files_extension is not null and @files_extension <> ''
   begin
	Select @selection = @selection + rtrim(@files_extension)
   end
Else
   begin
	Select @selection = @selection + '*'
   end


--  Code for special case to zip everything
If @files_extension = '*all*'
   begin
	Select @selection = '*.*'
   end


--  Set output file name
If @zip_path like '%\'
   begin
	Select @zip_selection = @zip_path + @selection
   end
Else
   begin
	Select @zip_selection = @zip_path + '\' + @selection
   end


--  Set zip action variable
If @delete_source_files = 'y'
   begin
	Select @zip_action = '-m'
   end
Else
   begin
	Select @zip_action = '-a'
   end


--  Check to see if there are files to zip
create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


select @cmd = 'dir ' + @zip_selection


insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd


If (select count(*) from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) like '%File Not Found%') > 0
   begin
	Select @miscprint = 'DBA WARNING: dbasp_Auto_Zipper - No files found for the requested zip process (' + @zip_selection + ')'
--print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label89
   end


--  Set the command variable
Select @cmd = 'wzzip ' + @zip_action + ' ' + @zip_path_name + ' ' + @zip_selection


Print 'The following wzzip command will be used.'
Print @cmd
Print ' '


EXEC master.sys.xp_cmdshell @cmd


label89:


--  Purge Section  -------------------------------------------------------------------


If @zip_path like '%\'
   begin
	Select @save_zip_path = @zip_path
   end
Else
   begin
	Select @save_zip_path = @zip_path + '\'
   end


If @timestamp_on_zipfile = 'y'
   begin
	Select @save_datestmp = left(@BkUpDateStmp, 8)
	Select @save_datestmp = Dateadd(day, -@retention_days, @save_datestmp)


	Select @save_ZipFile_name = STUFF (@ZipFile_name , len(@ZipFile_name)-17 , 18 , convert(varchar(8), @save_datestmp, 112) + '*.zip' )
	Select @cmd = 'del ' + @save_zip_path + @save_ZipFile_name
	Print 'The following delete command will be used.'
	Print @cmd
	Print ' '
	EXEC master.sys.xp_cmdshell @cmd


	Select @save_datestmp = Dateadd(day, -1, @save_datestmp)
	Select @save_ZipFile_name = STUFF (@ZipFile_name , len(@ZipFile_name)-17 , 18 , convert(varchar(8), @save_datestmp, 112) + '*.zip' )
	Select @cmd = 'del ' + @save_zip_path + @save_ZipFile_name
	Print 'The following delete command will be used.'
	Print @cmd
	Print ' '
	EXEC master.sys.xp_cmdshell @cmd


	Select @save_datestmp = Dateadd(day, -1, @save_datestmp)
	Select @save_ZipFile_name = STUFF (@ZipFile_name , len(@ZipFile_name)-17 , 18 , convert(varchar(8), @save_datestmp, 112) + '*.zip' )
	Select @cmd = 'del ' + @save_zip_path + @save_ZipFile_name
	Print 'The following delete command will be used.'
	Print @cmd
	Print ' '
	EXEC master.sys.xp_cmdshell @cmd


	Select @save_datestmp = Dateadd(day, -1, @save_datestmp)
	Select @save_ZipFile_name = STUFF (@ZipFile_name , len(@ZipFile_name)-17 , 18 , convert(varchar(8), @save_datestmp, 112) + '*.zip' )
	Select @cmd = 'del ' + @save_zip_path + @save_ZipFile_name
	Print 'The following delete command will be used.'
	Print @cmd
	Print ' '
	EXEC master.sys.xp_cmdshell @cmd


	Select @save_datestmp = Dateadd(day, -1, @save_datestmp)
	Select @save_ZipFile_name = STUFF (@ZipFile_name , len(@ZipFile_name)-17 , 18 , convert(varchar(8), @save_datestmp, 112) + '*.zip' )
	Select @cmd = 'del ' + @save_zip_path + @save_ZipFile_name
	Print 'The following delete command will be used.'
	Print @cmd
	Print ' '
	EXEC master.sys.xp_cmdshell @cmd
   end


--  Finalization  -------------------------------------------------------------------


label99:


If (object_id('tempdb..#fileexists') is not null)
   begin
	drop table #fileexists
   end


If (object_id('tempdb..#DirectoryTempTable') is not null)
   begin
	drop table #DirectoryTempTable
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Auto_Zipper] TO [public]
GO
