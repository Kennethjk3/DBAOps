SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupFile_mover_trusted] ( @source_server sysname = null,
				@source_path nvarchar(500) = null,
				@target_path nvarchar(500) = null,
				@backupname sysname = null,
				@backup_hh_period int = '300',
				@retry_limit smallint = 5,
				@delete_source char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_BackupFile_mover_trusted
 **  Written by Steve Ledridge, Virtuoso
 **  August 16, 2004
 **
 **  This procedure is used for copying files from one server
 **  to another where there is a trust relationship.
 **
 **  This proc accepts several input parms:
 **  - @source_server is the \\servername where files are being copied from.
 **  - @source_path is the path (share or folder name) where files are being copied from.
 **  - @target_path is the path where files are being copied to.
 **  - @backupname is the name pattern of the backup file to be copied.
 **  - @backup_hh_period is the number of hours allowed between the date
 **    the backup file was created and the current date/time.
 **  - @retry_limit is the number of retries performed if the file is not available.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/02/2005	Steve Ledridge		New process
--	06/23/2006	Steve Ledridge		Updated for SQL 2005.
--	03/30/2009	Steve Ledridge		New delete process.
--	03/23/2010	Steve Ledridge		Added code to ignore shortcut files.
--	05/04/2010	Steve Ledridge		Added '%cannot find the file%' to file delete code.
--	03/21/2011	Steve Ledridge		Added verify loop at the end.
--	04/21/2011	Steve Ledridge		Added raiserror with nowait.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	======================================================================================


/***
Declare @source_server sysname
Declare @source_path nvarchar(500)
Declare @target_path nvarchar(500)
Declare @backupname sysname
Declare @backup_hh_period int
Declare @retry_limit smallint
Declare @delete_source char(1)


select @source_server = '\\seadcsqlc01a'
select @source_path = 'seadcsqlc01a_backup'
select @target_path = '\\SEAFRESQLRPT01\SEAFRESQLRPT01_restore'
select @backupname = 'MSCRM_CONFIG_dfntl'
select @backup_hh_period = '3000'
select @retry_limit = 3
Select @delete_source = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@loop_count		int
	,@command 		nvarchar(512)
	,@retcode 		int
	,@filecount		smallint
	,@filename_wild		nvarchar(100)
	,@charpos		int
	,@counter		smallint
	,@savefilename		sysname
	,@hold_filedate		nvarchar(12)
	,@save_filedate		nvarchar(12)
	,@save_filedate2	nvarchar(20)
	,@save_fileYYYY		nvarchar(4)
	,@save_fileMM		nvarchar(2)
	,@save_fileDD		nvarchar(2)
	,@save_fileHH		nvarchar(2)
	,@save_fileMN		nvarchar(2)
	,@save_fileAMPM		nvarchar(1)
	,@retry_counter		smallint
	,@source_user 		sysname
	,@source_pw 		sysname
	,@save_subject		sysname
	,@save_message		nvarchar(4000)


DECLARE
	 @cu11cmdoutput		nvarchar(255)


----------------  initial values  -------------------
Select @error_count = 0
Select @hold_filedate = '200001010001'
Select @retry_counter = 0


select @filename_wild = '%' + @backupname + '%'


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


--  Check input parms
if @backupname is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover_trusted.  @backupname is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_BackupFile_mover_trusted. @target_path is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


/****************************************************************
 *                MainLine
 ***************************************************************/


Label01:

select @command = 'dir ' + @source_server + '\' + @source_path + '\*.*'
print @command


delete from #DirectoryTempTable
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
--select * from #DirectoryTempTable


delete from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) not like @filename_wild
delete from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) like '%Shortcut%'
delete from #DirectoryTempTable where cmdoutput is null
select * from #DirectoryTempTable
raiserror('', -1,-1) with nowait


select @filecount = (select count(*) from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) like @filename_wild)


if @filecount < 1
   BEGIN
	Select @miscprint = 'DBA WARNING: No files found for dbasp_BackupFile_mover_trusted at ' + @source_server + '\' + @source_path + ' ' + @backupname
	Print @miscprint
	raiserror('', -1,-1) with nowait
	If @retry_counter < @retry_limit
	   begin
		Select @retry_counter = @retry_counter + 1
		--Waitfor delay '00:05:00'
		Print 'Retry ' + convert(varchar(10), @retry_counter)
		goto label01
	   end
	Else
	   begin
		Select @error_count = @error_count + 1
		goto label99
	   end
   END
Else
   BEGIN
	EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
	  'SELECT p.cmdoutput
	   From #DirectoryTempTable   p ' +
	  'Where ltrim(rtrim(p.cmdoutput)) like ''' + @filename_wild + '''
	   Order by p.cmdoutput for Read Only')


	OPEN cu11_cursor


	WHILE (11=11)
	 Begin
		FETCH Next From cu11_cursor Into @cu11cmdoutput
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu11_cursor
		      BREAK
	           end


		select @save_fileYYYY = substring(@cu11cmdoutput, 7, 4)
		select @save_fileMM = substring(@cu11cmdoutput, 1, 2)
		select @save_fileDD = substring(@cu11cmdoutput, 4, 2)
		select @save_fileHH = substring(@cu11cmdoutput, 13, 2)
		Select @save_fileAMPM = substring(@cu11cmdoutput, 18, 1)
		If @save_fileAMPM = 'a' and @save_fileHH = '12'
		   begin
			Select @save_fileHH = '00'
		   end
		Else If @save_fileAMPM = 'p' and @save_fileHH <> '12'
		   begin
			Select @save_fileHH = @save_fileHH + 12
		   end
		select @save_fileMN = substring(@cu11cmdoutput, 16, 2)
		Select @save_filedate = @save_fileYYYY + @save_fileMM + @save_fileDD + @save_fileHH + @save_fileMN
		Select @save_filedate2 = @save_fileYYYY + '-' + @save_fileMM + '-' + @save_fileDD + ' ' + @save_fileHH + ':' + @save_fileMN + ':00'


		If @hold_filedate < @save_filedate
		   begin
			select @savefilename = ltrim(rtrim(substring(@cu11cmdoutput, 40, 200)))
			select @hold_filedate = @save_filedate
		   end


	 End  -- loop 11
	 DEALLOCATE cu11_cursor


   END


-- If the source file is too old...
If @backup_hh_period < DATEDIFF(hour, convert(datetime, @save_filedate2), getdate())
   begin
	Select @miscprint = 'DBA WARNING: File at source is too old (' + @save_filedate2 + ').  Check your @backup_hh_period parm.'
	Print @miscprint
	raiserror('', -1,-1) with nowait
	If @retry_counter < @retry_limit
	   begin
		Select @retry_counter = @retry_counter + 1
		Waitfor delay '00:05:00'
		goto label01
	   end
	Else
	   begin
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


--  Check to see if this file is already at the target.  If not, delete the file at the target.
Delete from #DirectoryTempTable
Select @command = 'DIR ' + @target_path + '\*' + @backupname + '*.* /b'
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
delete from #DirectoryTempTable where cmdoutput is null


Select @filecount = (select count(*) from #DirectoryTempTable where cmdoutput not like '%File Not Found%')
select * from #DirectoryTempTable
raiserror('', -1,-1) with nowait


If not exists (select 1 from #DirectoryTempTable where cmdoutput like '%' + @savefilename + '%')
   begin
	Select @counter = 0


	start_file_delete:


	select @command = 'if exist ' + @target_path + '\*' + @backupname + '*.* del ' + @target_path + '\*' + @backupname + '*.*'
	Print @command
	raiserror('', -1,-1) with nowait
	exec master.sys.xp_cmdshell @command


	Delete from #DirectoryTempTable
	Select @command = 'DIR ' + @target_path + '\*' + @backupname + '*.* /b'
	Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
	delete from #DirectoryTempTable where cmdoutput is null


	Select @filecount = (select count(*) from #DirectoryTempTable where cmdoutput not like '%File Not Found%' and cmdoutput not like '%cannot find the file%')


	If @filecount > 0
	   begin
		If @counter < 5
		   begin
			select @counter = @counter + 1
			waitfor delay '00:00:15'
			goto start_file_delete
		   end
		Else
		   begin
			Select * from #DirectoryTempTable
			Select @miscprint = 'Unable to delete file using the following command. ' + @target_path + '\*' + @backupname + '*.*'
			Print @miscprint
			Select @error_count = @error_count + 1
			RAISERROR( 'DBA ERROR: Error Deleting Files.  Check to see what is holding this file (Backup to Tape?).', 16, -1 ) with log
			goto label99
		   end
	   end
   end


--  Perform the copy process
--  Note:  If the file being copied is already at the target, robocopy will skip it.
--         The reason we do it this way is - if the file is damaged, robocopy will overwrite it.
Select @loop_count = 0
start_copy01:
If @delete_source = 'y'
   begin
	select @command = 'robocopy /Z /R:3 /MOV ' + @source_server + '\' + @source_path + ' ' + @target_path + ' ' + rtrim(@savefilename)
   end
Else
   begin
	select @command = 'robocopy /Z /R:3 ' + @source_server + '\' + @source_path + ' ' + @target_path + ' ' + rtrim(@savefilename)
   end


Print @command
raiserror('', -1,-1) with nowait
exec master.sys.xp_cmdshell @command


If rtrim(@savefilename) like '%.zip'
   begin
	select @command = 'wzunzip ' + @target_path + '\' + @backupname + '*.zip ' + @target_path + '\'
	Print @command
	raiserror('', -1,-1) with nowait
	exec master.sys.xp_cmdshell @command


	select @command = 'if exist ' + @target_path + '\' + @backupname + '*.zip del ' + @target_path + '\' + @backupname + '*.zip'
	Print @command
	raiserror('', -1,-1) with nowait
	exec master.sys.xp_cmdshell @command
   end


--  Verify the file at the target
If @loop_count > 5
   begin
	Select @save_subject = 'DBAOps:  Backup File Mover Copy Process Failure for server ' + @@servername
	Select @save_message = 'Unable to copy source backup file ' + @savefilename + ' to the target path ' + @target_path + '.'
	EXEC DBAOps.dbo.dbasp_sendmail
		@recipients = 'DBANotify@virtuoso.com',
		--@recipients = 'DBANotify@virtuoso.com',
		@subject = @save_subject,
		@message = @save_message
	goto skip_copyloop
   end


Select @loop_count = @loop_count + 1

Delete from #DirectoryTempTable
Select @command = 'DIR ' + @target_path + '\' + @savefilename
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @command
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput not like '%' + @savefilename + '%'
select * from #DirectoryTempTable
raiserror('', -1,-1) with nowait


Select @filecount = (select count(*) from #DirectoryTempTable where cmdoutput like '%' + @savefilename + '%')

If @filecount = 0
   begin
	Print 'Retry copy process for file count = 0.'
	goto start_copy01
   end


If exists (select 1 from #DirectoryTempTable where cmdoutput like '%01/01/1980%')
   begin
	Print 'Retry copy process for incomplete copy (01/01/1980).'
	goto start_copy01
   end


raiserror('', -1,-1) with nowait


skip_copyloop:


-------------------   end   --------------------------


label99:


drop table #DirectoryTempTable


If @error_count > 0
   begin
	raiserror(@miscprint,16,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupFile_mover_trusted] TO [public]
GO
