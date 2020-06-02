SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FileVerify] ( @full_path nvarchar(500) = null,
					@premask sysname = '',
					@midmask sysname = '',
					@postmask sysname = '',
					@Fail_ifnotfound char(1) = 'y',
					@Fail_ifdupfound char(1) = 'y'
					)


/*********************************************************
 **  Stored Procedure dbasp_FileVerify
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  JULY 23, 2008
 **
 **  This procedure is used for Verifying the existance of a file.
 **
 **  This proc accepts the following input parms:
 **  - @full_path is the path where the file can be found
 **    example - "\\seafresqlwcds\seafresqlwcds_dbasql"
 **  - @premask is the mask for the beginning of the backup file name (i.e. 'wcds_db')
 **  - @midmask is the mask for the midpart of the file name (i.e. '_db_2')
 **  - @postmask is the mask for the last part of the file name (i.e. '.bak')
 **  - @Fail_ifnotfound is a flag to fail the process if a file is not found.
 **  - @Fail_ifdupfound is a flag to fail the process if more than one file is found.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/23/2008	Steve Ledridge		New process
--	09/16/2008	Steve Ledridge		seafresqldba02 to seafresqldba01.
--	07/28/2015	Steve Ledridge		New code to handle multi-file backups.
--	======================================================================================


/***
Declare @full_path nvarchar(500)
Declare @premask sysname
Declare @midmask sysname
Declare @postmask sysname
Declare @Fail_ifnotfound char(1)
Declare @Fail_ifdupfound char(1)


Select @full_path = '\\seafresqldba01\seafresqldba01_backup'
Select @premask = 'run'
Select @midmask = '_db'
Select @postmask = '5.BAK'
Select @Fail_ifnotfound = 'y'
Select @Fail_ifdupfound = 'y'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
	,@cmd 				nvarchar(4000)
	,@filecount			smallint
	,@filename_wild			nvarchar(100)


----------------  initial values  -------------------
Select @error_count = 0
Select @filename_wild = ''


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


--  Check input parms
if @full_path is null or @full_path = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_autorestore - @full_path is invaild.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @premask = ''and @midmask = '' and @postmask = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters - input parm @premask or @midmask or @postmask must be used'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


If @premask is not null and @premask <> ''
   begin
	Select @filename_wild = @filename_wild + @premask
   end


If @midmask is not null and @midmask <> ''
   begin
	Select @filename_wild = @filename_wild + '*' + @midmask
   end


If @postmask is not null and @postmask <> ''
   begin
	Select @filename_wild = @filename_wild + '*' + @postmask
   end
Else
   begin
	Select @filename_wild = @filename_wild + '*'
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


select @cmd = 'dir /B ' + @full_path + '\' + @filename_wild
print @cmd


start_dir:
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd


delete from #DirectoryTempTable where cmdoutput like '%File Not Found%'
delete from #DirectoryTempTable where cmdoutput is null
--select * from #DirectoryTempTable


if exists (select 1 from #DirectoryTempTable where cmdoutput like '%01_OF%')
   begin
	delete from #DirectoryTempTable where cmdoutput not like '%01_OF%'
   end


Select @filecount = (select count(*) from #DirectoryTempTable)


If @filecount = 0
   begin
	Select @miscprint = 'DBA Warning: FileVerify process could not find a file at "' + @full_path + '" using mask ''' + @filename_wild + '''.'
	Print @miscprint
	If @Fail_ifnotfound = 'y'
	   begin
		Select @error_count = @error_count + 1
		goto label99
	   end
   end
Else If @filecount = 1
   begin
	Select @miscprint = 'DBA Message: FileVerify process found one file at "' + @full_path + '" using mask ''' + @filename_wild + '''.'
	Print @miscprint
   end
Else If @filecount > 1
   begin
	Select @miscprint = 'DBA Warning: FileVerify process found more than one file at "' + @full_path + '" using mask ''' + @filename_wild + '''.'
	Print @miscprint
	If @Fail_ifdupfound = 'y'
	   begin
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


-------------------   end   --------------------------


label99:


drop table #DirectoryTempTable


If @error_count > 0
   begin
	--print @miscprint
	raiserror(@miscprint,16,-1) with log
	RETURN (1)
   end
Else
   begin
	--print @miscprint
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_FileVerify] TO [public]
GO
