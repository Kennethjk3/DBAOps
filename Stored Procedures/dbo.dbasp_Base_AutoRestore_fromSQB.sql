SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_AutoRestore_fromSQB]


/*********************************************************
 **  Stored Procedure dbasp_Base_AutoRestore_fromSQB
 **  Written by Steve Ledridge, Virtuoso
 **  March 3, 2004
 **
 **  This procedure is used to create local *nxt files for
 **  sql deployment restores using local compressed backup files
 **  in the NXT share.
 **
 **  This proc accepts no input parms at this time.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/03/2008	Steve Ledridge		New auto restore process
--	05/09/2008	Steve Ledridge		Altered how we check the size of the restored DB.
--	05/27/2008	Steve Ledridge		Added check of the Base_Skip_sqb2nxt table.
--	07/17/2008	Steve Ledridge		Added skip process if Redgate is not installed.
--	07/23/2008	Steve Ledridge		Fixed raise error issue when skpping process.
--	10/20/2008	Steve Ledridge		Skip DB's with fulltext indexes.
--	12/05/2008	Steve Ledridge		New code to handle failed restores.
--	12/16/2008	Steve Ledridge		New code to drop old (orphaned) *_nxt DB.
--	08/19/2009	Steve Ledridge		Removed systeminfo references.
--	05/14/2010	Steve Ledridge		Added NXT DB cleanup processing.
--	06/14/2010	Steve Ledridge		Added code for the new BASE folder.
--	04/20/2011	Steve Ledridge		New code for cBAK baseline files.
--	05/02/2011	Steve Ledridge		Fixed bug related to #filelist table.
--	05/11/2011	Steve Ledridge		Moved section that determines DBname from baseline file name.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd			nvarchar(4000)
	,@Restore_cmd		nvarchar(4000)
	,@query			nvarchar(4000)
	,@error_count		int
	,@mdf_path 		nvarchar(255)
	,@nxt_path 		nvarchar(255)
	,@base_path 		nvarchar(255)
	,@charpos		int
	,@savepos		int
	,@charpos2		int
	,@file_type		nvarchar(10)
	,@save_sqb_dirdata	nvarchar(255)
	,@save_sqbfile_date	nchar(8)
	,@save_sqbfile_time	nchar(4)
	,@save_sqbfile_datetime	nchar(12)
	,@save_sqbfile_size	sysname
	,@save_sqbfile_size_num	bigint
	,@save_sqbfile_name	sysname
	,@save_sqbfile_db	sysname
	,@save_nxt_dirdata	nvarchar(255)
	,@save_nxtfile_date	nchar(8)
	,@save_nxtfile_time	nchar(4)
	,@save_nxtfile_datetime	nchar(12)
	,@save_nxtfile_name	sysname
	,@savePhysicalNamePart	nvarchar(260)
	,@save_file_path	nvarchar(260)
	,@save_file_name	nvarchar(260)
	,@save_backup_path 	nvarchar(260)
	,@sv_freespace		nvarchar(255)
	,@parm01		nvarchar(100)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_dbname		sysname
	,@save_skipname		sysname
	,@hold_filename		sysname
	,@hold_fullpath		sysname
	,@hold_DBname		sysname
	,@hold_dbid		int


DECLARE
	 @iSPID			int
	,@DBID			int
	,@retry_count		smallint


DECLARE
	 @cu15fileid		smallint
	,@cu15groupid		smallint
	,@cu15name		nvarchar(128)
	,@cu15filename		nvarchar(260)


DECLARE
	 @cu22LogicalName	sysname
	,@cu22PhysicalName	nvarchar(260)
	,@cu22Type		char(1)
	,@cu22FileGroupName	sysname


----------------  initial values  -------------------
Select @error_count = 0
Select @retry_count = 0


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Create temp tables
create table #sqb_TempTable(cmdoutput nvarchar(255) null)


create table #Dbnames(dbname sysname null)


create table #nxt_TempTable(cmdoutput nvarchar(255) null)


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


create table #filelist(
		 LogicalName nvarchar(128) null
		,PhysicalName nvarchar(260) null
		,Type char(1)
		,FileGroupName nvarchar(128) null
		,Size numeric(20,0)
		,MaxSize numeric(20,0)
		,FileId bigint
		,CreateLSN numeric(25,0)
		,DropLSN numeric(25,0)
		,UniqueId uniqueidentifier
		,ReadOnlyLSN numeric(25,0)
		,ReadWriteLSN numeric(25,0)
		,BackupSizeInBytes bigint
		,SourceBlockSize int
		,FileGroupId int
		,LogGroupGUID uniqueidentifier null
		,DifferentialBaseLSN numeric(25,0)
		,DifferentialBaseGUID uniqueidentifier
		,IsReadOnly bit
		,IsPresent bit
		,TDEThumbprint varbinary(32) null
		)


create table #filelist_rg(
		 LogicalName nvarchar(128) null
		,PhysicalName nvarchar(260) null
		,Type char(1)
		,FileGroupName nvarchar(128) null
		,Size numeric(20,0)
		,MaxSize numeric(20,0)
		,FileId bigint
		,CreateLSN numeric(25,0)
		,DropLSN numeric(25,0)
		,UniqueId uniqueidentifier
		,ReadOnlyLSN numeric(25,0)
		,ReadWriteLSN numeric(25,0)
		,BackupSizeInBytes bigint
		,SourceBlockSize int
		,FileGroupId int
		,LogGroupGUID sysname null
		,DifferentialBaseLSN numeric(25,0)
		,DifferentialBaseGUID uniqueidentifier
		,IsReadOnly bit
		,IsPresent bit
		)


--  Verfiy nxt share and get nxt path
Select @parm01 = @save_servername2 + '_nxt'
--exec dbo.dbasp_get_share_path @parm01, @nxt_path output
SET @nxt_path = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)


if @nxt_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: NXT share is not properly in place.  Check utility RMTSHARE.EXE and/or Run sproc DBAOps.dbo.dbasp_create_NXTshare.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


--  Verfiy BASE share and get BASE path
Select @parm01 = @save_servername2 + '_BASE'
--exec dbo.dbasp_get_share_path @parm01, @base_path output
SET @base_path = DBAOps.dbo.dbaudf_GetSharePath2(@parm01)


if @base_path is null
   BEGIN
	Select @base_path = @nxt_path
   END


--  Verfiy mdf share and get mdf path
Select @parm01 = @save_servername2 + '_mdf'
--exec dbo.dbasp_get_share_path @parm01, @mdf_path output


if @mdf_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: MDF share is not properly in place.  Check utility RMTSHARE.EXE and/or Run sproc DBAOps.dbo.dbasp_dba_sqlsetup.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Before we start, make sure we have no *_nxt databases
If exists (select 1 from master.sys.databases where name like '%nxt')
   begin
	Delete from #Dbnames
	Insert into #Dbnames select name from master.sys.databases where name like '%nxt'
	Delete from #Dbnames where dbname is null
	--select * from #Dbnames

	Start_DBnxt01:
	Select @save_dbname = (select top 1 dbname from #Dbnames order by dbname)

	exec DBAOps.dbo.dbasp_SetStatusForRestore @dbname = @save_dbname, @dropDB = 'y'

	Delete from #Dbnames where dbname = @save_dbname
   	If (select count(*) from #Dbnames) > 0
	   begin
		goto Start_DBnxt01
	   end
   end


--  Get a list of the files in the nxt share
select @cmd = 'dir ' + @nxt_path


delete from #nxt_TempTable
insert into #nxt_TempTable exec master.sys.xp_cmdshell @cmd
delete from #nxt_TempTable where cmdoutput is null
delete from #nxt_TempTable where cmdoutput like '%<DIR>%'
delete from #nxt_TempTable where cmdoutput like '%Directory of%'
delete from #nxt_TempTable where cmdoutput like '% File(s) %'
delete from #nxt_TempTable where cmdoutput like '% Dir(s) %'
delete from #nxt_TempTable where cmdoutput like '%Volume in drive%'
delete from #nxt_TempTable where cmdoutput like '%Volume Serial Number%'
--select * from #nxt_TempTable


--  Get a list of the files in the BASE share
select @cmd = 'dir ' + @base_path


delete from #sqb_TempTable
insert into #sqb_TempTable exec master.sys.xp_cmdshell @cmd
delete from #sqb_TempTable where cmdoutput is null
delete from #sqb_TempTable where cmdoutput like '%<DIR>%'
delete from #sqb_TempTable where cmdoutput like '%Directory of%'
delete from #sqb_TempTable where cmdoutput like '% File(s) %'
delete from #sqb_TempTable where cmdoutput like '% Dir(s) %'
delete from #sqb_TempTable where cmdoutput like '%Volume in drive%'
delete from #sqb_TempTable where cmdoutput like '%Volume Serial Number%'
delete from #sqb_TempTable where cmdoutput like '%prod.bak%'
--select * from #sqb_TempTable


--  Process the SQB files one at a time


--
If (select count(*) from #sqb_TempTable) > 0
   begin


	start_sqb:


	Select @save_sqb_dirdata = (select top 1 cmdoutput from #sqb_TempTable order by cmdoutput)


	Print 'Processing file;'
	Print @save_sqb_dirdata
	Print ''


	--  Capture sqb file date, time, file size, name and db_name
	Select @save_sqbfile_date = (substring(@save_sqb_dirdata,7,4)) + (substring(@save_sqb_dirdata,1,2)) + (substring(@save_sqb_dirdata,4,2))


	Select @save_sqbfile_time = (substring(@save_sqb_dirdata,13,2)) + (substring(@save_sqb_dirdata,16,2))
	If (substring(@save_sqb_dirdata,19,2)) = 'PM'
	   begin
		Select @save_sqbfile_time = @save_sqbfile_time + '1200'
	   end


	Select @save_sqbfile_datetime = @save_sqbfile_date + @save_sqbfile_time


	Select @save_sqbfile_size = ltrim(rtrim(substring(@save_sqb_dirdata,22,17)))
	Select @save_sqbfile_size = replace(@save_sqbfile_size, ',', '')


	Select @save_sqbfile_name = rtrim(substring(@save_sqb_dirdata,40,200))


	select @charpos = charindex('_prod.', @save_sqbfile_name)
	IF @charpos <> 0
	   begin
		select @save_sqbfile_db = substring(@save_sqbfile_name, 1, @charpos-1)
	   end
	Else
	   begin
		Print 'DBA Warning: SQB file name format does not match expected format.  Skipping SQB file.'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	--  Check the table Base_Skip_sqb2nxt.  If this file is in the table, skip it.
	If (select count(*) from dbo.Base_Skip_sqb2nxt) > 0
	   begin
		Select @save_skipname = ''
		start_skipcheck:
		Select @save_skipname = (select top 1 SQBname from dbo.Base_Skip_sqb2nxt where SQBname > @save_skipname order by SQBname)
		If @save_sqb_dirdata like '%' + @save_skipname + '%'
		   begin
			Print 'DBA Note: Local baseline process skipping SQB file due to entry in the table [Base_Skip_sqb2nxt]'
			Print @save_sqb_dirdata
			Print ''
			goto skip_sqb
		   end


		If exists (select 1 from dbo.Base_Skip_sqb2nxt where SQBname > @save_skipname)
		   begin
			goto start_skipcheck
		   end
	   end


	--  Check for 01/01/1980 (file copy still in process)
	If @save_sqb_dirdata like '%01/01/1980%'
	   begin
		Print 'DBA Warning: Local baseline process skipping SQB file due to 01/01/1980 issue'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	--  Test for proper format
	If (substring(@save_sqb_dirdata,3,1)) <> '/'
	   or (substring(@save_sqb_dirdata,6,1)) <> '/'
	   or (substring(@save_sqb_dirdata,15,1)) <> ':'
	   begin
		Print 'DBA Warning: DIR format does not match expected format.  Skipping SQB file.'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	--  Look for better file to process
	If @save_sqbfile_name like '%prod.cBAK%'
	   begin
		Select @file_type = 'cBAK'
	   end
	Else If @save_sqbfile_name like '%prod.sqb%' and not exists (select 1 from #sqb_TempTable where cmdoutput like '%' + @save_sqbfile_db + '_prod.cBAK%')
	   begin
		Select @file_type = 'sqb'
	   end
	Else
	   begin
		delete from #sqb_TempTable where cmdoutput = @save_sqb_dirdata
		goto start_sqb
	   end


	--  Determine the file names for this DB (restore header only)
	--  Check to see if new NXT files already exist
	--  Restore database to NXT share using *_nxt dbname
	Select @save_backup_path = @base_path + '\' + ltrim(@save_sqbfile_name)


	If @file_type = 'sqb'
	   begin
		select @Restore_cmd = ''
		select @Restore_cmd = @Restore_cmd + '-SQL "RESTORE DATABASE [' + @save_sqbfile_db + '_nxt]'
		select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @save_backup_path + ''''
		select @Restore_cmd = @Restore_cmd + ' WITH RECOVERY'


		Print ''
		Print '-- Get file header info from the SQB backup file'
		Select @query = 'Exec master.dbo.sqlbackup ''-SQL "RESTORE FILELISTONLY FROM DISK = ''''' + rtrim(@save_backup_path) + '''''"'''
		Print @query
		delete from #filelist_rg
		insert into #filelist_rg exec (@query)
		--select * from #filelist_rg


		If (select count(*) from #filelist_rg) = 0
		   begin
			Select @miscprint = 'DBA WARNING: Unable to perform filelist only on this backup file:  ' + rtrim(@save_backup_path)
			raiserror(@miscprint,-1,-1) with log
			Print 'DBA Warning: Unable to perform filelist only on SQB file.  Skipping SQB file.'
			Print @save_sqb_dirdata
			Print ''
			goto skip_sqb
		   end


		If (select count(*) from #filelist_rg where type = 'f') > 0
		   begin
			Select @miscprint = 'DBA NOTE: DB has FullText index.  Unable to create NXT file:  ' + rtrim(@save_backup_path)
			raiserror(@miscprint,-1,-1) with log
			Print 'DBA NOTE: DB has FullText index.  Unable to create NXT file.  Skipping SQB file.'
			Print @save_sqb_dirdata
			Print ''
			goto skip_sqb
		   end


		--  Get the size of the DB from the backup file header and add 10 percent
		Select @save_sqbfile_size_num = sum(size) from #filelist_rg
		Select @save_sqbfile_size_num = @save_sqbfile_size_num / .9
	   end
	Else If @file_type = 'cBAK'
	   begin
		select @Restore_cmd = ''
		select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE [' + @save_sqbfile_db + '_nxt]'
		select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @save_backup_path + ''''
		select @Restore_cmd = @Restore_cmd + ' WITH RECOVERY, REPLACE'


		Print ''
		Print '-- Get file header info from the cBAK backup file'
		select @query = 'RESTORE FILELISTONLY FROM Disk = ''' + @save_backup_path + ''''
		delete from #filelist
		insert into #filelist exec (@query)
		--select * from #filelist


		If (select count(*) from #filelist) = 0
		   begin
			Select @miscprint = 'DBA WARNING: Unable to perform filelist only on this backup file:  ' + rtrim(@save_backup_path)
			raiserror(@miscprint,-1,-1) with log
			Print 'DBA Warning: Unable to perform filelist only on cBAK file.  Skipping cBAK file.'
			Print @save_sqb_dirdata
			Print ''
			goto skip_sqb
		   end


		If (select count(*) from #filelist where type = 'f') > 0
		   begin
			Select @miscprint = 'DBA NOTE: DB has FullText index.  Unable to create NXT file:  ' + rtrim(@save_backup_path)
			raiserror(@miscprint,-1,-1) with log
			Print 'DBA NOTE: DB has FullText index.  Unable to create NXT file.  Skipping cBAK file.'
			Print @save_sqb_dirdata
			Print ''
			goto skip_sqb
		   end


		--  Get the size of the DB from the backup file header and add 10 percent
		Select @save_sqbfile_size_num = sum(size) from #filelist
		Select @save_sqbfile_size_num = @save_sqbfile_size_num / .9
	   end


	--  Look to see how much freespace we have in the nxt share
	select @cmd = 'dir ' + @nxt_path
	delete from #DirectoryTempTable
	insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
	delete from #DirectoryTempTable where cmdoutput is null
	delete from #DirectoryTempTable where cmdoutput not like '% Dir(s) %'
	--select * from #DirectoryTempTable


	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		select @sv_freespace = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like '%bytes free%')
		Select @charpos = charindex('Dir(s)', @sv_freespace)
		Select @charpos2 = charindex('bytes free', @sv_freespace)
		select @sv_freespace = ltrim(substring(@sv_freespace, @charpos+6, (@charpos2-@charpos)-7))
		Select @sv_freespace = rtrim(replace(@sv_freespace, ',', ''))
	   end
	Else
	   begin
		Print 'DBA Warning: Cannot determine freespace in the NXT share.  Skipping SQB file.'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	--  If we don't have disk space for an NXT file for this DB, skip it
	If @save_sqbfile_size_num > convert(bigint, @sv_freespace)
	   begin
		Print 'DBA Warning: Unable to create NXT file for database ' + @save_sqbfile_db + ' due to lack of free space in the NXT share. Skipping baseline file.'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	header_parse01:
	If @file_type = 'cBAK'
	   begin
		Select @cu22LogicalName = (select top 1 LogicalName from #filelist)
		Select @cu22PhysicalName = (select PhysicalName from #filelist where LogicalName = @cu22LogicalName)
		Select @cu22Type = (select Type from #filelist where LogicalName = @cu22LogicalName)
		Select @cu22FileGroupName = (select FileGroupName from #filelist where LogicalName = @cu22LogicalName)
	   end
	Else If @file_type = 'sqb'
	   begin
		Select @cu22LogicalName = (select top 1 LogicalName from #filelist_rg)
		Select @cu22PhysicalName = (select PhysicalName from #filelist_rg where LogicalName = @cu22LogicalName)
		Select @cu22Type = (select Type from #filelist_rg where LogicalName = @cu22LogicalName)
		Select @cu22FileGroupName = (select FileGroupName from #filelist_rg where LogicalName = @cu22LogicalName)
	   end


	Select @savePhysicalNamePart = rtrim(@cu22PhysicalName)
	label41:
	select @charpos = charindex('\', @savePhysicalNamePart)
	IF @charpos <> 0
	   begin
		select @savePhysicalNamePart = substring(@savePhysicalNamePart, @charpos + 1, 100)
	   end

	select @charpos = charindex('\', @savePhysicalNamePart)
	IF @charpos <> 0
	   begin
		goto label41
 	   end


	If @cu22Type in ('D', 'F')
	   begin
		Select @save_file_path = @nxt_path + '\' + @savePhysicalNamePart
	   end
	Else IF @cu22Type = 'L'
	   begin
		Select @save_file_path = @nxt_path + '\' + @savePhysicalNamePart
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: Invalid file type in backup filelist results:  ' + @cu22Type
		raiserror(@miscprint,-1,-1) with log
		Print 'DBA Warning: Invalid file type in backup filelist results:  ' + @cu22Type + '.  Skipping Baseline file.'
		Print @save_sqb_dirdata
		Print ''
		goto skip_sqb
	   end


	--  If the *nxt version of this database exists, drop it
	If exists (select 1 from master.sys.databases where name = @save_sqbfile_db + '_nxt')
	   begin
		Print ''
		Print '-- Drop the current *_nxt version of this database'


		Select @cmd = 'use master alter database [' + rtrim(@save_sqbfile_db) + '_nxt] set OFFLINE with ROLLBACK IMMEDIATE'
		Print @cmd
		exec (@cmd)


		Select @cmd = 'use master drop database [' + rtrim(@save_sqbfile_db) + '_nxt];'
		Print @cmd
		exec (@cmd)
	   end


	--  Check to see if this file (or its *nxt twin) is already in the nxt share
	If exists(select 1 from #nxt_TempTable where cmdoutput like '%' + @savePhysicalNamePart + '%')
	   begin
		Print ''
		Print '--  Check for related files already in the NXT share'
		start_nxtcheck:
		Select @save_nxt_dirdata = (select top 1 cmdoutput from #nxt_TempTable where cmdoutput like '%' + @savePhysicalNamePart + '%')
		Select @save_nxtfile_name = rtrim(substring(@save_nxt_dirdata,40,200))


		If @save_nxt_dirdata like '%nxt%'
		   begin
			Select @save_nxtfile_date = (substring(@save_nxt_dirdata,7,4)) + (substring(@save_nxt_dirdata,1,2)) + (substring(@save_nxt_dirdata,4,2))


			Select @save_nxtfile_time = (substring(@save_nxt_dirdata,13,2)) + (substring(@save_nxt_dirdata,16,2))
			If (substring(@save_nxt_dirdata,19,2)) = 'PM'
			   begin
				Select @save_nxtfile_time = @save_nxtfile_time + '1200'
			   end


			Select @save_nxtfile_datetime = @save_nxtfile_date + @save_nxtfile_time


			--  if we have a *nxt file that is newer than the baseline file, skip this process
			If @save_nxtfile_name = @savePhysicalNamePart + 'nxt' and @save_nxtfile_datetime >= @save_sqbfile_datetime
			   begin
				Print 'DBA Note: New *nxt file found for this database (' + @save_sqbfile_db + ').  Skipping this baseline file.'
				Print @save_nxt_dirdata
				Print ''
				goto skip_sqb
			   end
		   end
		Else
		   begin
			If @save_nxtfile_name = @savePhysicalNamePart + 'nxt' or @save_nxtfile_name = @savePhysicalNamePart
			   begin
				--  If this file is connected to a DB in SQL, drop that DB
				Select @hold_fullpath = @nxt_path + '\' + @save_nxtfile_name
				If exists (select 1 from master.sys.master_files where physical_name = @hold_fullpath)
				   begin
					Select @hold_dbid = (select database_id from master.sys.master_files where physical_name = @hold_fullpath)
					Select @hold_DBname = (select name from master.sys.databases where database_id = @hold_dbid)


					Select @cmd = 'use master alter database [' + rtrim(@hold_DBname) + '] set OFFLINE with ROLLBACK IMMEDIATE'
					Print @cmd
					exec (@cmd)


					Select @cmd = 'use master drop database [' + rtrim(@hold_DBname) + '];'
					Print @cmd
					exec (@cmd)


					Waitfor delay '00:00:03'


					-- If this DB still exists, don't go any further with this one
					If exists (select 1 from master.sys.databases where database_id = @hold_dbid)
					   begin
						Print 'DBA Warning: A new *nxt file could not be created for this database (' + @save_sqbfile_db + ') because the target *.MDF file is in use.  Skipping this baseline file.'
						Print @save_nxt_dirdata
						Print ''
						goto skip_sqb
					   end
				   end


				Select @cmd = 'del ' + @nxt_path + '\' + @save_nxtfile_name
				Print @cmd
				exec master.sys.xp_cmdshell @cmd
			   end
		   end


		--  check for more rows to process
		delete from #nxt_TempTable where cmdoutput = @save_nxt_dirdata
		If exists(select 1 from #nxt_TempTable where cmdoutput like '%' + @savePhysicalNamePart + '%')
		   begin
			goto start_nxtcheck
		   end
	   end


	select @Restore_cmd = @Restore_cmd + ', MOVE ''' + rtrim(@cu22LogicalName) + ''' to ''' + rtrim(@save_file_path) + ''''


	Delete from #filelist_rg where LogicalName = @cu22LogicalName
	Delete from #filelist where LogicalName = @cu22LogicalName


	--  check to see if there are more rows to process
	If (select count(*) from #filelist_rg) > 0 or (select count(*) from #filelist) > 0
	   begin
		goto header_parse01
	   end


	If @file_type = 'cBAK'
	   begin
		select @Restore_cmd = @Restore_cmd + ' ,stats'
	   end
	Else If @file_type = 'sqb'
	   begin
		select @Restore_cmd = @Restore_cmd + ' ,REPLACE"'
	   end


	--  If the *nxt version of this DB exists, take it offline
	If (DATABASEPROPERTYEX(@save_sqbfile_db + '_nxt', N'Status') = N'ONLINE')
	   begin
		Print ''
		Print '-- An older *_nxt version of this database still exists.  Take it offline.'
		Select @cmd = 'use master alter database ' + rtrim(@save_sqbfile_db) + '_nxt set OFFLINE with ROLLBACK IMMEDIATE'
		Print @cmd
		exec (@cmd)
	  end


	--  Process the restore
	Print ''
	Print '-- Restore the baseline file to the *_nxt database name.'
	Print @Restore_cmd
	If @file_type = 'cBAK'
	   begin
		Exec (@Restore_cmd)
	   end
	Else If @file_type = 'sqb'
	   begin
		Exec master.dbo.sqlbackup @Restore_cmd
	   end


	--  Verify Restore (if restore failed, drop the DB and remove the files from the nxt share)
	If (DATABASEPROPERTYEX(@save_sqbfile_db + '_nxt', N'Status') <> N'ONLINE')
	   begin
		select @miscprint = 'DBA Error:  Restore Failure (baseline complete restore) for command ' + @Restore_cmd
		print  @miscprint


		--  Drop this *_nxt DB and delete the baseline file from the nxt share
		Select @cmd = 'use master drop database ' + rtrim(@save_sqbfile_db) + '_nxt;'
		Print @cmd
		exec (@cmd)


		Select @cmd = 'del ' + rtrim(@save_backup_path)
		Print @cmd
		exec master.sys.xp_cmdshell @cmd


		--  Delete the DB files if they still exist
		del_nxt_dbfiles_afterfail:
		Select @charpos = charindex(' to ', @Restore_cmd)
		IF @charpos <> 0
		   begin
			Select @Restore_cmd = substring(@Restore_cmd, @charpos+5, 500)
			Select @hold_filename = @Restore_cmd
			Select @charpos = charindex('''', @hold_filename)
			IF @charpos <> 0
			   begin
				Select @hold_filename = left(@hold_filename, @charpos-1)
				print @hold_filename


				Select @cmd = 'del ' + rtrim(@hold_filename)
				Print @cmd
				exec master.sys.xp_cmdshell @cmd
			   end


			If @Restore_cmd like '% to %'
			   begin
				goto del_nxt_dbfiles_afterfail
			   end


		   end


		goto skip_sqb
	   end


	--  Capture sysfile info for this *nxt database
	Print ''
	Print '-- Capture sysfiles info for this new *_nxt database.'
	select @cmd = 'If (object_id(''DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles'') is not null)
	   begin
		drop table DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles
	   end'
	exec  (@cmd)
	Select @cmd = 'Create table DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles (
			fileid smallint,
			groupid smallint,
			size int,
			maxsize int,
			growth int,
			status int,
			perf int,
			name nchar(128),
			filename nchar(260))'
	exec  (@cmd)


	Select @cmd = 'Delete from DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles'
	exec  (@cmd)
	Select @cmd = 'Insert into DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles  select * from [' + @save_sqbfile_db + '_nxt].sys.sysfiles'
	exec  (@cmd)
	--Select @cmd = 'select * from DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles'
	--exec  (@cmd)


	--  Make sure all connections to this database are removed
	--  Alter the database to offline mode
	retry_kill:
	Print ''
	Print '-- Remove all connections to the new *_nxt database.'


	Select @cmd = 'alter database [' + rtrim(@save_sqbfile_db) + '_nxt] set OFFLINE with ROLLBACK IMMEDIATE '
	print @cmd
	Exec(@cmd)
	print ' '


	--  Pause for a couple seconds
	waitfor delay '00:00:01'


	--  Alter the database to online mode
	Select @cmd = 'alter database [' + rtrim(@save_sqbfile_db) + '_nxt] set ONLINE with ROLLBACK IMMEDIATE '
	print @cmd
	Exec(@cmd)
	print ' '


	--  Pause for a couple seconds
	waitfor delay '00:00:01'


	Select @cmd = 'alter database [' + rtrim(@save_sqbfile_db) + '_nxt] set MULTI_USER with ROLLBACK IMMEDIATE'
	Print @cmd
	exec (@cmd)


	--  Set the dbid value
	Select @DBID = dbid FROM master.sys.sysdatabases where name = @save_sqbfile_db + '_nxt'


	Select @iSPID = 50
	WHILE @iSPID IS NOT NULL
	   begin
		Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID and spid > @iSPID
		IF @iSPID IS NOT NULL
		   begin
			Select @cmd = 'KILL ' + convert(varchar(12), @iSPID )
			Print @cmd
			exec(@cmd)
		   end
	   end


	Select @iSPID = min(spid) from master.sys.sysprocesses where dbid = @DBID
	If @iSPID is not null
	   begin
		Select @miscprint = 'Unable to kill spid related to database ' + @save_sqbfile_db + '_nxt.  spid = ' + convert(varchar(10),@iSPID)
		Print  @miscprint
		waitfor delay '00:05:00'
		Select @retry_count = @retry_count + 1
		If @retry_count < 5
		   begin
			goto retry_kill
		   end
	   end


	--  Create datach gsql file
	Print ''
	Print '-- Detach the new *_nxt database.'
	Select @cmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"print ''master.sys.sp_detach_db ''''' + rtrim(@save_sqbfile_db) + '_nxt'''', @skipchecks = ''''true''''''" -E -o\\' + @save_servername + '\DBASQL\' + rtrim(@save_sqbfile_db) + '_nxt_detach.gsql'
	Print  @cmd
	exec master.sys.xp_cmdshell @cmd


	waitfor delay '00:00:03'


	--  Detach *_nxt database, delete ldf and rename mdf and ldf files
	Select @cmd = 'sqlcmd -S' + @@servername + ' -u -E -i\\' + @save_servername + '\DBASQL\' + rtrim(@save_sqbfile_db) + '_nxt_detach.gsql'
	Print  @cmd
	exec master.sys.xp_cmdshell @cmd


	waitfor delay '00:00:03'


	--  Rename the mdf and ndf files and delete the ldf files
	--------------------  Cursor for 15DB  -----------------------
	Select @cmd = 'DECLARE cu15_file Insensitive Cursor For ' +
	  'SELECT f.fileid, f.groupid, f.name, f.filename
	   From DBAOps.dbo.' + rtrim(@save_sqbfile_db) + '_nxt_temp_sysfiles  f ' +
	  'Order By f.fileid For Read Only'
	EXECUTE(@cmd)


	OPEN cu15_file


	WHILE (15=15)
	   Begin
		FETCH Next From cu15_file Into @cu15fileid, @cu15groupid, @cu15name, @cu15filename
		IF (@@fetch_status < 0)
		   begin
		      CLOSE cu15_file
		      BREAK
		   end

		--  parse and save the file name
		Select @save_file_name = rtrim(@cu15filename)
		Select @charpos = charindex('\', @save_file_name)
		label15a:
		IF @charpos <> 0
		   begin
			Select @save_file_name = substring(@save_file_name, @charpos + 1, 200)
		   end
		Select @charpos = charindex('\', @save_file_name)
		IF @charpos <> 0
		   begin
			goto label15a
		   end


		--  parse and save the file path
		Select @save_file_path = ''
		Select @savepos = 1
		label15c:
		Select @charpos = charindex('\', @cu15filename, @savepos)
		IF @charpos <> 0
		   begin
			Select @savepos = @charpos+1
			goto label15c
		   end


		Select @save_file_path = @save_file_path + substring(@cu15filename, 1, @savepos-2)


		--  Rename the mdf and ndf files
		If @cu15groupid <> 0
		   begin
			Print ''
			Print '-- Rename mdf or ndf file (with nxt sufix).'


			--  Update the file permissions
			Select @cmd = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /G "Administrators":F /Y'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output

			Select @cmd = 'XCACLS "' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + '" /E /G "NT AUTHORITY\SYSTEM":R /Y'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd, no_output


			--  Rename the DB file, adding 'nxt' to the extention
			Select @cmd = 'REN ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name) + ' ' + rtrim(@save_file_name) + 'nxt'
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end
		Else
		   begin
			Print ''
			Print '-- Delete ldf file.'


			--  Delete the ldf files
			Select @cmd = 'Del ' + rtrim(@save_file_path) + '\' + rtrim(@save_file_name)
			Print @cmd
			EXEC master.sys.xp_cmdshell @cmd--, no_output
		   end


	   End  -- loop 15
	   DEALLOCATE cu15_file


	skip_sqb:


	--  Delete this row and check to see if there are more rows to process
	delete from #sqb_TempTable where cmdoutput like '%' + @save_sqbfile_db + '_prod%'
	If (select count(*) from #sqb_TempTable) > 0
	   begin
		goto start_sqb
	   end


   end


--  One last check for *_nxt databases
If exists (select 1 from master.sys.databases where name like '%nxt')
   begin
	Delete from #Dbnames
	Insert into #Dbnames select name from master.sys.databases where name like '%nxt'
	Delete from #Dbnames where dbname is null
	--select * from #Dbnames

	Start_DBnxt02:
	Select @save_dbname = (select top 1 dbname from #Dbnames order by dbname)

	exec DBAOps.dbo.dbasp_SetStatusForRestore @dbname = @save_dbname, @dropDB = 'y'

	Delete from #Dbnames where dbname = @save_dbname
   	If (select count(*) from #Dbnames) > 0
	   begin
		goto Start_DBnxt02
	   end
   end


--  Finalization  -------------------------------------------------------------------
label99:


drop table #nxt_TempTable
drop table #sqb_TempTable
drop table #DirectoryTempTable
drop table #filelist
drop table #filelist_rg
drop table #Dbnames


If  @error_count > 0
   begin
	raiserror(67016, 16, -1, @miscprint)


	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Base_AutoRestore_fromSQB] TO [public]
GO
