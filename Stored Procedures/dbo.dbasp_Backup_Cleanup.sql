SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Cleanup] (@BkUpPath varchar(100) = null
					,@Retention_DD int = 7
					,@BkUpType varchar(10) = 'tlog'
					,@LiteSpeed_Bypass char(1) = 'n'
					,@RedGate_Bypass char(1) = 'n'
					,@dup_delete char(1) = 'n'
					,@dup_namemask sysname = null)

/***************************************************************
 **  Stored Procedure dbasp_Backup_Cleanup
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 25, 2002
 **
 **  This proc accepts the followinf input parms:
 **  @BkUpPath      	- Full path where the backup files are
 **                 	  written to.
 **  @Retention_DD  	- The number of days backup files are retained
 **                 	  on disk.
 **  @BkUpType      	- 'tlog', 'dfntl' or 'db'.
 **  @LiteSpeed_Bypass 	- (y or n) indicates if you want to bypass
 **                    	  LiteSpeed processing.
 **  @RedGate_Bypass 	- (y or n) indicates if you want to bypass
 **                  	  RedGate processing.
 **  @dup_delete 	- (y or n) indicates if you want to delete duplicate
 **                       backup files with different time stamps.
 **
 **  @dup_namemask 	- Name mask for the @dup_delete request (e.g. wcds_db)
 **
 **  This procedure deletes older backup files from disk.  The
 **  length of retention depends on the passed parameter.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==================================================
--	04/26/2002	Steve Ledridge		Revision History added
--	08/18/2005	Steve Ledridge		Added code for LiteSpeed backups and differentials
--	08/19/2005	Steve Ledridge		Added code for LiteSpeed bypass.
--	02/15/2006	Steve Ledridge		Modified for sql2005.
--	07/24/2007	Steve Ledridge		Added procesing for RedGate.
--	12/26/2008	Steve Ledridge		Added duplicate delete section.
--	12/07/2010	Steve Ledridge		Fixed delete old file process.
--	04/20/2011	Steve Ledridge		Modified to process cBAK files.
--	======================================================================================


/*
Declare @BkUpPath varchar(100)
Declare @Retention_DD int
Declare @BkUpType varchar(10)
Declare @LiteSpeed_Bypass char(1)
Declare @RedGate_Bypass char(1)
Declare @dup_delete char(1)
Declare @dup_namemask sysname


Select @BkUpPath = '\\seafresqldba01\seafresqldba01_restore'
Select @Retention_DD = 7
Select @BkUpType = 'tlog'
Select @LiteSpeed_Bypass = 'y'
Select @RedGate_Bypass = 'y'
Select @dup_delete = 'y'
Select @dup_namemask = '${{secrets.COMPANY_NAME}}_Artists_db'
--*/


Declare
	 @miscprint		nvarchar(4000)
	,@Del_text 		nvarchar(500)
	,@BkUpMethod		nvarchar(5)
	,@BkUpSufx		nvarchar(10)
	,@BkUpDateStmp 		int
	,@Hold_hhmmss		nvarchar(8)
	,@Hold_filedate		sysname
	,@cmd 			nvarchar(500)
	,@command_text		nvarchar(500)
	,@cursor_text		nvarchar(1000)
	,@Result		int
	,@Error_count		int
	,@charpos		int
	,@scan			int
	,@check_num		int
	,@hold_filename		sysname


DECLARE
	 @cu11FileName		nvarchar(500)


Select @Error_count = 0


--  Check input parameters
If @BkUpPath is null or @BkUpPath = ''
   begin
	If exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'backup_path')
	   begin
		Select @BkUpPath = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'backup_path')
	   end
   end


If @BkUpPath is null
   begin
	select @miscprint = 'DBA WARNING: Invaild parameter passed to dbasp_backup_Cleanup - @BkUpPath cannot be null'
	raiserror(@miscprint,-1,-1) with log
	Select @Error_count = @Error_count + 1
	goto label99
   end


--  Set defaults
Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @BkUpDateStmp = convert(varchar(8), getdate()-@Retention_DD, 112) + substring(@Hold_hhmmss, 1, 2)
Set @Error_count = 0
Set @BkUpMethod = 'MS'


If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'LiteSpeed')
   and @LiteSpeed_Bypass = 'n'
  begin
	Set @BkUpMethod = 'LS'
   end


If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'backup_type' and env_detail = 'RedGate')
   and @RedGate_Bypass = 'n'
  begin
	Set @BkUpMethod = 'RG'
   end


If @BkUpType = 'tlog'
   begin
	If @BkUpMethod = 'LS'
	   begin
		Select @BkUpSufx = 'TNL'
	   end
	Else If @BkUpMethod = 'RG'
	   begin
		Select @BkUpSufx = 'SQT'
	   end
	Else
	   begin
		Select @BkUpSufx = 'TRN'
	   end
   end
Else If @BkUpType = 'db'
   begin
	If @BkUpMethod = 'LS'
	   begin
		Select @BkUpSufx = 'BKP'
	   end
	Else If @BkUpMethod = 'RG'
	   begin
		Select @BkUpSufx = 'SQB'
	   end
	Else
	   begin
		Select @BkUpSufx = 'BAK'
	   end
   end
Else If @BkUpType = 'dfntl'
   begin
	If @BkUpMethod = 'LS'
	   begin
		Select @BkUpSufx = 'DFL'
	   end
	Else If @BkUpMethod = 'RG'
	   begin
		Select @BkUpSufx = 'SQD'
	   end
	Else
	   begin
		Select @BkUpSufx = 'DIF'
	   end
   end
Else
   begin
	select @miscprint = 'DBA WARNING: Invaild parameter passed to dbasp_backup_Cleanup - @BkUpType must be ''db'',''dfntl'' or ''tlog'''
	raiserror(@miscprint,-1,-1) with log
	Select @Error_count = @Error_count + 1
	goto label99
   end


--  Create temp table for the file information
CREATE TABLE #temp_tbl	(text01	varchar(400))


/****************************************************************
 *                MainLine
 ***************************************************************/
-- If this is a duplicate delete request, go to that section of the code
If @dup_delete = 'y'
   begin
	goto dup_delete_start
   end


--  execute the dir command via cmdshell and drop the results in the temp table
select @cmd = 'dir ' + @BkUpPath + '\*.*' + @BkUpSufx
insert #temp_tbl (text01) exec master.sys.xp_cmdshell @cmd
delete from #temp_tbl where text01 is null
--select * from #temp_tbl


--  loop through the dir results looking for files to delete
If (select count(*) from #temp_tbl) > 0
   begin
	start_loop01:


	Select @cu11FileName = (select top 1 text01 From #temp_tbl)


	If @BkUpType = 'tlog'
	   begin
		Select @scan = CHARINDEX('_tlog_', @cu11FileName)


		If @scan > 0
		   begin
			Select @Hold_filedate = reverse(@cu11FileName)
			Select @charpos = charindex('_', @Hold_filedate)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
			   end
			Select @Hold_filedate = reverse(@Hold_filedate)


			Select @Hold_filedate = left(@Hold_filedate, 10)


			Select @check_num = convert(int, @Hold_filedate)


			If @check_num < @BkUpDateStmp
			   begin
				Select @Del_text = @BkUpPath + '\' + substring(@cu11FileName, 40, 50)
				Select @command_text 	= 'Del ' + rtrim(@Del_text)

				EXEC @Result = master.sys.xp_cmdshell @command_text


				IF @Result <> 0
				   begin
					select @miscprint = 'DBA WARNING: Backup file delete processing failed.  Command was ' + @command_text
					raiserror(@miscprint,-1,-1) with log
					Select @Error_count = @Error_count + 1
				   end
				Else
				   begin
					select @miscprint = 'Deleted file ' + rtrim(@Del_text)
					Print  @miscprint
				   end


			   end
		   end
	   end


	If @BkUpType = 'db'
	   begin
		Select @scan = CHARINDEX('_db_', @cu11FileName)


		If @scan > 0
		   begin
			Select @Hold_filedate = reverse(@cu11FileName)
			Select @charpos = charindex('_', @Hold_filedate)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
			   end
			Select @Hold_filedate = reverse(@Hold_filedate)


			Select @Hold_filedate = left(@Hold_filedate, 10)


			Select @check_num = convert(int, @Hold_filedate)

			If @check_num < @BkUpDateStmp
			   begin
				Select @Del_text = @BkUpPath + '\' + substring(@cu11FileName, 40, 50)
				Select @command_text 	= 'Del ' + rtrim(@Del_text)


				EXEC @Result = master.sys.xp_cmdshell @command_text


				IF @Result <> 0
				   begin
					select @miscprint = 'DBA WARNING: Backup file delete processing failed.  Command was ' + @command_text
					raiserror(@miscprint,-1,-1) with log
					Select @Error_count = @Error_count + 1
				   end
				Else
				   begin
					select @miscprint = 'Deleted file ' + rtrim(@Del_text)
					Print  @miscprint
				   end


			   end
		   end
	   end


	If @BkUpType = 'dfntl'
	   begin
		Select @scan = CHARINDEX('_dfntl_', @cu11FileName)


		If @scan > 0
		   begin
			Select @Hold_filedate = reverse(@cu11FileName)
			Select @charpos = charindex('_', @Hold_filedate)
			IF @charpos <> 0
			   begin
				Select @Hold_filedate = substring(@Hold_filedate, 1, @charpos-1)
			   end
			Select @Hold_filedate = reverse(@Hold_filedate)


			Select @Hold_filedate = left(@Hold_filedate, 10)


			Select @check_num = convert(int, @Hold_filedate)

			If @check_num < @BkUpDateStmp
			   begin
				Select @Del_text = @BkUpPath + '\' + substring(@cu11FileName, 40, 50)
				Select @command_text 	= 'Del ' + rtrim(@Del_text)


				EXEC @Result = master.sys.xp_cmdshell @command_text


				IF @Result <> 0
				   begin
					select @miscprint = 'DBA WARNING: Backup file delete processing failed.  Command was ' + @command_text
					raiserror(@miscprint,-1,-1) with log
					Select @Error_count = @Error_count + 1
				   end
				Else
				   begin
					select @miscprint = 'Deleted file ' + rtrim(@Del_text)
					Print  @miscprint
				   end


			   end
		   end
	   end


	--  Check for more rows to process
	Delete From #temp_tbl where text01 = @cu11FileName
	If (select count(*) from #temp_tbl) > 0
	   begin
		goto start_loop01
	   end


   end


-----------------------------------------------------------------------------------------------------------------
--  Delete Duplicate Section                                                                                   --
--  Note:  This process will delete duplicate backup files as long as they have different time stamps          --
--         as part of the backup file name.                                                                    --
-----------------------------------------------------------------------------------------------------------------
dup_delete_start:


-- If this is not a duplicate delete request, go to the end
If @dup_delete = 'n'
   begin
	goto label99
   end


--  execute the dir command via cmdshell and drop the results in the temp table
select @cmd = 'dir ' + @BkUpPath + '\' + @dup_namemask + '* /b'
delete from #temp_tbl
insert #temp_tbl (text01) exec master.sys.xp_cmdshell @cmd
delete from #temp_tbl where text01 is null
--select * from #temp_tbl


Select @hold_filename = ''


--  loop through the dir results looking for files to delete
If (select count(*) from #temp_tbl) > 1
   begin
	start_loop02:


	Select @cu11FileName = (select top 1 text01 From #temp_tbl)


	If @hold_filename = ''
	   begin
		Select @hold_filename = @cu11FileName
	   end
	Else If @hold_filename < @cu11FileName
	   begin
		Select @Del_text = @BkUpPath + '\' + rtrim(@hold_filename)
		Select @command_text 	= 'Del ' + @Del_text
		Print @command_text


		EXEC @Result = master.sys.xp_cmdshell @command_text


		IF @Result <> 0
		   begin
			select @miscprint = 'DBA WARNING: Backup file delete processing failed.  Command was ' + @command_text
			raiserror(@miscprint,-1,-1) with log
			Select @Error_count = @Error_count + 1
		   end


		Select @hold_filename = @cu11FileName
	   end


	--  Check for more rows to process
	Delete From #temp_tbl where text01 = @cu11FileName
	If (select count(*) from #temp_tbl) > 0
	   begin
		goto start_loop02
	   end


   end


---------------------------  Finalization  -----------------------
label99:


drop table #temp_tbl


If @Error_count > 0
   begin
	select @miscprint = 'DBA WARNING: dbasp_Backup_Cleanup failed with ' + convert(varchar(10), @Error_count) + ' errors'
	raiserror(@miscprint,-1,-1) with log
	return (1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Cleanup] TO [public]
GO
