SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ProcessUpdateFiles]


/*********************************************************
 **  Stored Procedure dbasp_ProcessUpdateFiles
 **  Written by Steve Ledridge, Virtuoso
 **  June 08, 2009
 **
 **  This sproc will process files in the local dba_UpdateFiles
 **  folder under the dbasql share.  The process will rename the
 **  files once they have been processed and purge old files as well.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/08/2009	Steve Ledridge		New process.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd 				nvarchar(4000)
	,@sqlcmd			nvarchar(4000)
	,@filename_wild			nvarchar(100)
	,@tempcount			int
	,@Hold_filename			sysname
	,@Hold_filedate			varchar(14)
	,@charpos			bigint
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_share			sysname
	,@SaveDays			smallint
	,@Retention_filedate		varchar(14)
	,@new_ext			nvarchar(30)
	,@BkUpDateStmp 			char(14)
	,@Hold_hhmmss			varchar(8)
	,@new_filename			sysname


DECLARE
	 @cu12cmdoutput			nvarchar(255)


----------------  initial values  -------------------
select @SaveDays = 15


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)
Set @new_ext = '_' + @BkUpDateStmp + '.old'


create table #DirectoryTempTable (cmdoutput nvarchar(255) null)


/****************************************************************
 *                MainLine
 ***************************************************************/


Select @save_share = '\\'+ @save_servername + '\DBASQL\dba_UpdateFiles'


------------------------------------------------------------------------------------------
--  Start BAIupdate process  -------------------------------------------------------------
------------------------------------------------------------------------------------------
Print 'Start DBA UpdateFile Processing'


-- Process *.sql files
--  Check for files in the DEPLcontrol folder for this server
Delete from #DirectoryTempTable
Select @cmd = 'dir ' + @save_share + '\*.* /B'
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null or cmdoutput = ''
--select * from #DirectoryTempTable
delete from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) not like '%.sql'
--select * from #DirectoryTempTable


--  If any files were found, process them
If (select count(*) from #DirectoryTempTable) > 0
   begin
	start_cmdoutput01:


	Select @cu12cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable)


	select @sqlcmd = 'sqlcmd -S' + @@servername + ' -i' + @save_share + '\' + rtrim(@cu12cmdoutput) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\DBA_UpdateFile_' + rtrim(@cu12cmdoutput) + ' -E'
	print @sqlcmd
	exec master.sys.xp_cmdshell @sqlcmd


	Select @new_filename = replace(@cu12cmdoutput, '.sql' , @new_ext)


	Select @cmd = 'ren "' + @save_share + '\' + rtrim(@cu12cmdoutput) + '" "' + rtrim(@new_filename) + '"'
	print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	--  Remove this record from #DirectoryTempTable and go to the next
	delete from #DirectoryTempTable where cmdoutput = @cu12cmdoutput
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto start_cmdoutput01
	   end
   end


-- Process *.gsql files
--  Check for files in the DEPLcontrol folder for this server
Delete from #DirectoryTempTable
Select @cmd = 'dir ' + @save_share + '\*.* /B'
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null or cmdoutput = ''
--select * from #DirectoryTempTable
delete from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) not like '%.gsql'
--select * from #DirectoryTempTable


--  If any files were found, process them
If (select count(*) from #DirectoryTempTable) > 0
   begin
	start_cmdoutput02:


	Select @cu12cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable)


	select @sqlcmd = 'sqlcmd -S' + @@servername + ' -i' + @save_share + '\' + rtrim(@cu12cmdoutput) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\DBA_UpdateFile_' + rtrim(@cu12cmdoutput) + ' -E'
	print @sqlcmd
	exec master.sys.xp_cmdshell @sqlcmd


	Select @new_filename = replace(@cu12cmdoutput, '.gsql' , @new_ext)


	Select @cmd = 'ren "' + @save_share + '\' + rtrim(@cu12cmdoutput) + '" "' + rtrim(@new_filename) + '"'
	print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output


	--  Remove this record from #DirectoryTempTable and go to the next
	delete from #DirectoryTempTable where cmdoutput = @cu12cmdoutput
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto start_cmdoutput02
	   end
   end


--  Process to delete old files  -------------------
Print 'Start Delete Old Files Processing - dba_UpdateFiles folder'


Select @save_share = '\\'+ @save_servername + '\DBASQL\dba_UpdateFiles'


Set @Retention_filedate = convert(char(8), getdate()-@SaveDays, 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


select @cmd = 'dir ' + @save_share + '\*.old /B'


Delete from #DirectoryTempTable
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
Delete from #DirectoryTempTable where cmdoutput is null


Select @tempcount = (select count(*) from #DirectoryTempTable)


While (@tempcount > 0)
   begin
	Select @Hold_filename = (select TOP 1 cmdoutput from #DirectoryTempTable)


	Select @charpos = charindex('.old', @Hold_filename)
	IF @charpos <> 0
	   begin
 		Select @Hold_filedate = substring(@Hold_filename, @charpos -14, 14)
	   end


	If @Retention_filedate > @Hold_filedate
	   begin
		select @cmd = 'del ' + @save_share + '\' + @Hold_filename
		Print @cmd
		Exec master.sys.xp_cmdshell @cmd


		delete from #DirectoryTempTable where cmdoutput = @Hold_filename
	   end
	Else
	   begin
		delete from #DirectoryTempTable where cmdoutput = @Hold_filename
	   end


	Select @tempcount = (select count(*) from #DirectoryTempTable)


   end


----------------  End  -------------------
label99:


drop table #DirectoryTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_ProcessUpdateFiles] TO [public]
GO
