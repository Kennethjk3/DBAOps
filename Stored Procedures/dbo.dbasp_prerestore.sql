SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_prerestore] ( @full_path nvarchar(500) = null,
					@dbname sysname = null,
					@ALTdbname sysname = null,
					@backupname sysname = null,
					@backmidmask sysname = '_db_2',
					@diffmidmask sysname = '_dfntl_2',
					@datapath nvarchar(100) = null,
					@data2path nvarchar(100) = null,
					@logpath nvarchar(100) = null,
					@db_norecovOnly_flag char(1) = 'n',
					@post_shrink char(1) = 'n',
					@complete_on_diffOnly_fail char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_prerestore
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 29, 2008
 **
 **  This procedure is used for automated database
 **  restore processing for the pre-restore method.
 **  The pre-restore method is where we restore the
 **  DB along side of the DB of the same name using "_new"
 **  added to the DBname.  The mdf and ldf file names are
 **  changed as well.  When the restore is completed, the old
 **  DB is droped and the "_new" DB is renamed, completing the
 **  restore.  This gives the end user greater DB availability.
 **
 **  This proc accepts the following input parms:
 **  - @full_path is the path where the backup file can be found
 **    example - "\\seafresqlwcds\seafresqlwcds_dbasql"
 **  - @dbname is the name of the database being restored.
 **  - @ALTdbname is the "new" name of the database being restored (e.g. DBname_new).
 **  - @backupname is the name pattern of the backup file to be restored.
 **  - @backmidmask is the mask for the midpart of the backup file name (i.e. '_db_2')
 **  - @diffmidmask is the mask for the midpart of the differential file name (i.e. '_dfntl_2')
 **  - @datapath is the target path for the data files (optional)
 **  - @logpath is the target path for the log files (optional)
 **  - @db_norecovOnly_flag indicates a DB recovery with the norecovery parm,
 **    which should be followed later by a differential only restore.
 **  - @post_shrink is for a post restore file shrink (y or n)
 **  - @complete_on_diffOnly_fail will finish the restore of a DB after a failed
 **    differential restore'
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/29/2008	Steve Ledridge		New process based on dbasp_autorestore.
--	12/08/2010	Steve Ledridge		Added code for filegroup processing.
--	04/22/2011	Steve Ledridge		New code for 2008 processing.
--	10/24/2011	Steve Ledridge		Remove systema dn hidden attributes from the restore paths.
--	11/23/2011	Steve Ledridge		Added code for path override via local_control table.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	======================================================================================


/***
Declare @full_path nvarchar(100)
Declare @dbname sysname
Declare @ALTdbname sysname
Declare @backupname sysname
Declare @backmidmask sysname
Declare @diffmidmask sysname
Declare @datapath nvarchar(100)
Declare @data2path nvarchar(100)
Declare @logpath nvarchar(100)
Declare @db_norecovOnly_flag char(1)
Declare @post_shrink char(1)
Declare @complete_on_diffOnly_fail char(1)


select @full_path = '\\DBAOpser02\e$\mssql.1\restore'
select @dbname = '${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM'
select @ALTdbname = 'z_${{secrets.COMPANY_NAME}}_Images_US_Inc__MSCRM_new'
--Select @backupname = 'RM_Integration_db'
Select @backmidmask = '_db_FG_PRIMARY_2'
Select @diffmidmask = '_dfntl_2'
select @datapath = 'e:\mssql.1\data'
select @data2path = 'e:\mssql.1\data'
select @logpath = 'e:\mssql.1\data'
select @db_norecovOnly_flag = 'y'
Select @post_shrink = 'n'
Select @complete_on_diffOnly_fail = 'n'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
	,@retry_count			int
	,@cmd 				nvarchar(4000)
	,@Restore_cmd			nvarchar(4000)
	,@filecount			smallint
	,@filename_wild			nvarchar(100)
	,@diffname_wild			nvarchar(100)
	,@charpos			int
	,@query 			nvarchar(4000)
	,@mssql_data_path		nvarchar(255)
	,@savePhysicalNamePart		nvarchar(260)
	,@savefilepath			nvarchar(260)
	,@save_override_path		nvarchar(260)
	,@hold_filedate			nvarchar(12)
	,@save_filedate			nvarchar(12)
	,@save_fileYYYY			nvarchar(4)
	,@save_fileMM			nvarchar(2)
	,@save_fileDD			nvarchar(2)
	,@save_fileHH			nvarchar(2)
	,@save_fileMN			nvarchar(2)
	,@save_fileAMPM			nvarchar(1)
	,@save_cmdoutput		nvarchar(255)
	,@save_subject			sysname
	,@save_message			nvarchar(500)
	,@hold_backupfilename		sysname
	,@hold_diff_file_name		sysname
	,@fileseq			smallint
	,@diffname			sysname
	,@BkUpMethod			nvarchar(5)
	,@DateStmp 			nvarchar(15)
	,@Hold_hhmmss			nvarchar(8)
	,@check_dbname 			sysname
	,@hold_FGname			sysname
	,@FG_flag			char(1)

DECLARE
	 @cu11cmdoutput			nvarchar(255)


DECLARE
	 @cu21LogicalName		nvarchar(128)
	,@cu21PhysicalName		nvarchar(260)
	,@cu21Type			char(1)
	,@cu21FileGroupName		nvarchar(128)


DECLARE
	 @cu22LogicalName		nvarchar(128)
	,@cu22PhysicalName		nvarchar(260)
	,@cu22Type			char(1)
	,@cu22FileGroupName		nvarchar(128)


DECLARE
	 @cu25cmdoutput			nvarchar(255)


----------------  initial values  -------------------
Select @retry_count = 0
Select @error_count = 0
Select @hold_filedate = '200001010001'
Select @BkUpMethod = 'MS'
select @filename_wild = ''
select @diffname_wild = ''
select @DateStmp = ''
Select @FG_flag = 'n'


Select @check_dbname = @ALTdbname


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @DateStmp = '_' + convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)
create table #filelist(LogicalName nvarchar(128) null,
						PhysicalName nvarchar(260) null,
						Type char(1),
						FileGroupName nvarchar(128) null,
						Size numeric(20,0),
						MaxSize numeric(20,0),
						FileId bigint,
						CreateLSN numeric(25,0),
						DropLSN numeric(25,0),
						UniqueId uniqueidentifier,
						ReadOnlyLSN numeric(25,0),
						ReadWriteLSN numeric(25,0),
						BackupSizeInBytes bigint,
						SourceBlockSize int,
						FileGroupId int,
						LogGroupGUID uniqueidentifier null,
						DifferentialBaseLSN numeric(25,0),
						DifferentialBaseGUID uniqueidentifier,
						IsReadOnly bit,
						IsPresent bit,
						TDEThumbprint varbinary(32) null
						)


create table #filelist_rg(LogicalName nvarchar(128) null,
						PhysicalName nvarchar(260) null,
						Type char(1),
						FileGroupName nvarchar(128) null,
						Size numeric(20,0),
						MaxSize numeric(20,0),
						FileId bigint,
						CreateLSN numeric(25,0),
						DropLSN numeric(25,0),
						UniqueId uniqueidentifier,
						ReadOnlyLSN numeric(25,0),
						ReadWriteLSN numeric(25,0),
						BackupSizeInBytes bigint,
						SourceBlockSize int,
						FileGroupId int,
						LogGroupGUID sysname null,
						DifferentialBaseLSN numeric(25,0),
						DifferentialBaseGUID uniqueidentifier,
						IsReadOnly bit,
						IsPresent bit
						)


--  Check input parms
if @full_path is null or @full_path = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore - @full_path must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @dbname is null or @dbname = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore - @dbname must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @ALTdbname is null or @ALTdbname = ''
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_prerestore - @ALTdbname must be specified.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


If @backupname is null or @backupname = ''
   begin
	select @filename_wild = @filename_wild + @dbname + @backmidmask + '*'
	select @diffname_wild = @diffname_wild + @dbname + @diffmidmask + '*'
   end
Else
   begin
	Select @diffname = REPLACE(@backupname, '_db_', '_dfntl_')
	select @filename_wild = @filename_wild + @backupname
	select @diffname_wild = @diffname_wild + @diffname
   end


If @data2path is null
   begin
	select @data2path = @datapath
   end


--  Make sure the System and Hidden attributes do not exist on the restore paths
Select @cmd = 'attrib -S -H "' + @datapath + '" /D /S'
exec master.sys.xp_cmdshell @cmd


Select @cmd = 'attrib -S -H "' + @data2path + '" /D /S'
exec master.sys.xp_cmdshell @cmd


Select @cmd = 'attrib -S -H "' + @logpath + '" /D /S'
exec master.sys.xp_cmdshell @cmd


Select @mssql_data_path = (select filename from master.sys.sysfiles where fileid = 1)
Select @cmd = 'attrib -S -H "' + @mssql_data_path + '" /D /S'
exec master.sys.xp_cmdshell @cmd


/****************************************************************
 *                MainLine
 ***************************************************************/


select @cmd = 'dir ' + @full_path + '\' + @filename_wild
--print @cmd


start_dir:
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput like '%<DIR>%'
delete from #DirectoryTempTable where cmdoutput like '%Directory of%'
delete from #DirectoryTempTable where cmdoutput like '% File(s) %'
delete from #DirectoryTempTable where cmdoutput like '% Dir(s) %'
delete from #DirectoryTempTable where cmdoutput like '%Volume in drive%'
delete from #DirectoryTempTable where cmdoutput like '%Volume Serial Number%'
--select * from #DirectoryTempTable


select @filecount = (select count(*) from #DirectoryTempTable)


If @filecount < 1
   BEGIN
	If @retry_count < 5
	   begin
		Select @retry_count = @retry_count + 1
		Waitfor delay '00:00:10'
		delete from #DirectoryTempTable
		goto start_dir
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: No files found for dbasp_prerestore at ' + @full_path + ' using mask "' + @filename_wild + '"'
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end
   END
Else
   BEGIN
	Start_cmdoutput01:
	Select @save_cmdoutput = (Select top 1 cmdoutput from #DirectoryTempTable order by cmdoutput)
	Select @cu11cmdoutput = @save_cmdoutput


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


	If @hold_filedate < @save_filedate
	   begin
		select @hold_backupfilename = ltrim(rtrim(substring(@cu11cmdoutput, 40, 200)))
	   end


	Delete from #DirectoryTempTable where cmdoutput = @save_cmdoutput
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto Start_cmdoutput01
	   end
   END


--  Check file name to determin if we can process the file
If @hold_backupfilename like '%.SQB%'
   begin
	If exists (select 1 from master.sys.objects where name = 'sqlbackup' and type = 'x')
	   begin
		Print '--  Note:  RedGate Syntax will be used for this request'
		Print ' '
		Select @BkUpMethod = 'RG'
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: RedGate backups cannot be processed by dbasp_prerestore on this server. ' + @full_path + '\' + @hold_backupfilename
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @hold_backupfilename like '%[_]FG[_]%'
   begin
	Select @FG_flag = 'y'

	select @charpos = charindex('_FG_', @hold_backupfilename)
	IF @charpos <> 0
	   begin
		select @hold_FGname = substring(@hold_backupfilename, @charpos+4, 100)


		select @charpos = charindex('_', @hold_FGname)
		IF @charpos <> 0
		   begin
			select @hold_FGname = substring(@hold_FGname, 1, @charpos-1)
		   end
	   end
   end


--  Check to see if DBname_new exists, is in loading mode, and was restored using the current DB backup file
--  If so, skip to the differential restore section
If DATABASEPROPERTYEX (@check_dbname,'status') = 'RESTORING'
   begin
	Print 'DB is in restoring mode.  ' + @check_dbname
	If @hold_backupfilename in (select detail02 from dbo.No_Check where nocheck_type = 'prerestore' and detail01 = @check_dbname)
	   begin
		Print 'DB is in restoring mode and backup file used matches current.  Skipping to diff_start'
		goto diff_start
	   end
   end


--  At this point, if the database "DBname_new" exists, drop it
If exists (select 1 from master.sys.databases where name = @check_dbname)
   begin
	Select @cmd = 'drop database [' + @check_dbname + ']'
	Print  @cmd
	Exec(@cmd)


	waitfor delay '00:00:05'
   end


--  Verify the DB no longer exists
If exists (select 1 from master.sys.databases where name = @check_dbname)
   BEGIN
	Select @miscprint = 'DBA ERROR: Unable to drop database ' + @check_dbname + '.  The prerestore process is not able to continue.'
	Print  @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


--  Reset any related rows in the no_check table
delete from dbo.No_Check where nocheck_type = 'prerestore' and detail01 = @check_dbname


insert into dbo.No_Check (nocheck_type, detail01, detail02) values ('prerestore', @check_dbname, @hold_backupfilename)


--  Restore DB for Redgate
If @BkUpMethod = 'RG'
   begin
	select @miscprint = 'Declare @cmd nvarchar(4000)'
	print  @miscprint
	select @miscprint = 'Select @cmd = ''-SQL "RESTORE DATABASE [' + @check_dbname + ']'
	If @FG_flag = 'y'
	   begin
		select @miscprint = @miscprint + ' FILEGROUP=''''' + @hold_FGname + ''''''
	   end
	print  @miscprint
	select @miscprint = '	 FROM DISK = ''''' + @full_path + '\' + @hold_backupfilename + ''''''
	print  @miscprint


	If @FG_flag = 'y'
	   begin
		select @miscprint = '	 WITH PARTIAL, NORECOVERY'
		print  @miscprint
	   end
	Else
	   begin
		select @miscprint = '	 WITH NORECOVERY'
		print  @miscprint
	   end


	select @Restore_cmd = ''
	select @Restore_cmd = @Restore_cmd + '-SQL "RESTORE DATABASE [' + @check_dbname + ']'
	If @FG_flag = 'y'
	   begin
		select @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @hold_FGname + ''''
	   end


	select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''


	If @FG_flag = 'y'
	   begin
		select @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, NORECOVERY'
	   end
	Else
	   begin
		select @Restore_cmd = @Restore_cmd + ' WITH NORECOVERY'
	   end


	-- Get file header info from the SQB backup file
	delete from #filelist_rg


	Select @query = 'Exec master.dbo.sqlbackup ''-SQL "RESTORE FILELISTONLY FROM DISK = ''''' + rtrim(@full_path) + '\' + rtrim(@hold_backupfilename) + '''''"'''
	insert into #filelist_rg exec (@query)
	If (select count(*) from #filelist_rg) = 0
	   begin
		Select @miscprint = 'DBA Error: Unable to process RedGate filelistonly for file ' + @full_path + '\' + @hold_backupfilename
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  set the default path just in case we need it
	Select @mssql_data_path = (select filename from master.sys.sysfiles where fileid = 1)
	select @charpos = charindex('master', @mssql_data_path)
	select @mssql_data_path = left(@mssql_data_path, @charpos-1)
	select @fileseq = 1


	EXECUTE('DECLARE cu21_cursor Insensitive Cursor For ' +
	  'SELECT f.LogicalName, f.PhysicalName, f.Type, f.FileGroupName
	   From #filelist_rg   f ' +
	  'for Read Only')


	OPEN cu21_cursor

	WHILE (21=21)
	 Begin
		FETCH Next From cu21_cursor Into @cu21LogicalName, @cu21PhysicalName, @cu21Type, @cu21FileGroupName
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu21_cursor
		      BREAK
	           end


		select @savePhysicalNamePart = @cu21PhysicalName
		label02:
			select @charpos = charindex('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   begin
	  		    select @savePhysicalNamePart = substring(@savePhysicalNamePart, @charpos + 1, 100)
			   end

			select @charpos = charindex('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   begin
			    goto label02
	 		   end


		If @savePhysicalNamePart like '%.mdf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.mdf', @DateStmp + '.mdf')
		   end
		Else If @savePhysicalNamePart like '%.ndf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.ndf', @DateStmp + '.ndf')
		   end
		Else If @savePhysicalNamePart like '%.ldf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.ldf', @DateStmp + '.ldf')
		   end
		Else
		   begin
			Select @savePhysicalNamePart = @savePhysicalNamePart + @DateStmp
		   end


		If @datapath is not null and @cu21Type in ('D', 'F')
		   begin
			If exists (select 1 from dbo.local_control where subject = 'restore_override' and detail01 = @check_dbname and detail02 = @cu21LogicalName)
			   begin
				Select @save_override_path = (select top 1 detail03 from dbo.local_control where subject = 'restore_override' and detail01 = @check_dbname and detail02 = @cu21LogicalName)
				Select @savefilepath = @save_override_path + '\' + @savePhysicalNamePart
			   end
			Else If @savePhysicalNamePart not like '%mdf' and @data2path is not null
			   begin
				Select @savefilepath = @data2path + '\' + @savePhysicalNamePart
			   end
			Else
			   begin
				Select @savefilepath = @datapath + '\' + @savePhysicalNamePart
			   end
		   end
		Else IF @logpath is not null and @cu21Type = 'L'
		   begin
			Select @savefilepath = @logpath + '\' + @savePhysicalNamePart
		   end
		Else
		   begin
			Select @savefilepath = @mssql_data_path + @savePhysicalNamePart
		   end


		select @miscprint = '	,MOVE ''''' + rtrim(@cu21LogicalName) + ''''' to ''''' + rtrim(@savefilepath) + ''''''
		print  @miscprint


		select @Restore_cmd = @Restore_cmd + ', MOVE ''' + rtrim(@cu21LogicalName) + ''' to ''' + rtrim(@savefilepath) + ''''


		select @fileseq = @fileseq + 1


	End  -- loop 21
	DEALLOCATE cu21_cursor


	select @miscprint = '	,REPLACE"'''
	print  @miscprint
	select @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(9),'''')'
	print  @miscprint
	select @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(13)+char(10),'' '')'
	print  @miscprint
	select @miscprint = 'Exec master.dbo.sqlbackup @cmd'
	print  @miscprint
	select @miscprint = 'go'
	print  @miscprint
	Print ' '


	select @Restore_cmd = @Restore_cmd + ' ,REPLACE"'


	-- Restore the database
	select @cmd = 'Exec master.dbo.sqlbackup ' + @Restore_cmd
	Print 'Here is the restore command being executed;'
	Print @cmd
	raiserror('', -1,-1) with nowait


	Exec master.dbo.sqlbackup @Restore_cmd


	If DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
	   begin
		select @miscprint = 'DBA Error:  Restore Failure (Redgate partial restore) for command ' + @cmd
		print  @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end


	If @db_norecovOnly_flag = 'y'
	   begin
		Print ' '
		select @miscprint = '--  Note:  This will leave the database in recovery pending mode.'
		print  @miscprint
		goto label99
	   end
   end


--  If not a RedGate file, restore DB for standard
If @BkUpMethod = 'MS'
   begin
	select @miscprint = 'RESTORE DATABASE ' + @check_dbname
	print  @miscprint
	select @miscprint = 'FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''
	If @FG_flag = 'y'
	   begin
		select @miscprint = @miscprint + ' FILEGROUP=''''' + @hold_FGname + ''''''
	   end
	print  @miscprint


	select @miscprint = 'WITH NORECOVERY,'
	print  @miscprint
	select @miscprint = 'REPLACE,'
	print  @miscprint


	select @Restore_cmd = ''
	select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname
	If @FG_flag = 'y'
	   begin
		select @Restore_cmd = @Restore_cmd + ' FILEGROUP=''' + @hold_FGname + ''''
	   end


	select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_backupfilename + ''''


	If @FG_flag = 'y'
	   begin
		select @Restore_cmd = @Restore_cmd + ' WITH PARTIAL, NORECOVERY,'
	   end
	Else
	   begin
		select @Restore_cmd = @Restore_cmd + ' WITH NORECOVERY,'
	   end

	select @Restore_cmd = @Restore_cmd + ' REPLACE,'


	delete from #filelist


	select @query = 'RESTORE FILELISTONLY FROM Disk = ''' + @full_path + '\' + @hold_backupfilename + ''''
	If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.00.0000' --sql2008 or higher
	   begin
		insert into #filelist exec (@query)
	   end
	Else
	   begin
		insert into #filelist (LogicalName
			, PhysicalName
			, Type
			, FileGroupName
			, Size
			, MaxSize
			, FileId
			, CreateLSN
			, DropLSN
			, UniqueId
			, ReadOnlyLSN
			, ReadWriteLSN
			, BackupSizeInBytes
			, SourceBlockSize
			, FileGroupId
			, LogGroupGUID
			, DifferentialBaseLSN
			, DifferentialBaseGUID
			, IsReadOnly
			, IsPresent)
		exec (@query)
	   end


	--select * from #filelist
	If (select count(*) from #filelist) = 0
	   begin
		Select @miscprint = 'DBA Error: Unable to process standard filelistonly for file ' + @full_path + '\' + @hold_backupfilename
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end


	--  set the default path just in case we need it
	Select @mssql_data_path = (select filename from master.sys.sysfiles where fileid = 1)
	select @charpos = charindex('master', @mssql_data_path)
	select @mssql_data_path = left(@mssql_data_path, @charpos-1)
	select @fileseq = 1


	EXECUTE('DECLARE cu22_cursor Insensitive Cursor For ' +
	  'SELECT f.LogicalName, f.PhysicalName, f.Type, f.FileGroupName
	   From #filelist   f ' +
	  'for Read Only')


	OPEN cu22_cursor

	WHILE (22=22)
	 Begin
		FETCH Next From cu22_cursor Into @cu22LogicalName, @cu22PhysicalName, @cu22Type, @cu22FileGroupName
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu22_cursor
		      BREAK
	           end


		select @savePhysicalNamePart = @cu22PhysicalName
		label03:
			select @charpos = charindex('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   begin
	  		    select @savePhysicalNamePart = substring(@savePhysicalNamePart, @charpos + 1, 100)
			   end

			select @charpos = charindex('\', @savePhysicalNamePart)
			IF @charpos <> 0
			   begin
			    goto label03
	 		   end


		If @savePhysicalNamePart like '%.mdf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.mdf', @DateStmp + '.mdf')
		   end
		Else If @savePhysicalNamePart like '%.ndf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.ndf', @DateStmp + '.ndf')
		   end
		Else If @savePhysicalNamePart like '%.ldf'
		   begin
			Select @savePhysicalNamePart = replace(@savePhysicalNamePart, '.ldf', @DateStmp + '.ldf')
		   end
		Else
		   begin
			Select @savePhysicalNamePart = @savePhysicalNamePart + @DateStmp
		   end


		If @datapath is not null and @cu22Type in ('D', 'F')
		   begin
			If exists (select 1 from dbo.local_control where subject = 'restore_override' and detail01 = @check_dbname and detail02 = @cu22LogicalName)
			   begin
				Select @save_override_path = (select top 1 detail03 from dbo.local_control where subject = 'restore_override' and detail01 = @check_dbname and detail02 = @cu22LogicalName)
				Select @savefilepath = @save_override_path + '\' + @savePhysicalNamePart
			   end
			Else If @savePhysicalNamePart not like '%mdf' and @data2path is not null
			   begin
				Select @savefilepath = @data2path + '\' + @savePhysicalNamePart
			   end
			Else
			   begin
				Select @savefilepath = @datapath + '\' + @savePhysicalNamePart
			   end
		   end
		Else IF @logpath is not null and @cu22Type = 'L'
		   begin
			Select @savefilepath = @logpath + '\' + @savePhysicalNamePart
		   end
		Else
		   begin
			Select @savefilepath = @mssql_data_path + @savePhysicalNamePart
		   end


		select @miscprint = 'MOVE ''' + @cu22LogicalName + ''' to ''' + @savefilepath + ''','
		print  @miscprint


		select @Restore_cmd = @Restore_cmd + ' MOVE ''' + @cu22LogicalName + ''' to ''' + @savefilepath + ''','


		select @fileseq = @fileseq + 1


	End  -- loop 22
	DEALLOCATE cu22_cursor


	select @miscprint = 'stats'
	print  @miscprint
	select @miscprint = 'go'
	print  @miscprint
	Print ' '


	select @Restore_cmd = @Restore_cmd + ' stats'


	-- Restore the database
	select @cmd = @Restore_cmd
	Print 'Here is the restore command being executed;'
	Print @cmd
	raiserror('', -1,-1) with nowait


	Exec (@cmd)


	If @@error<> 0
	   begin
		Print 'DBA Error:  Restore Failure (Standard Restore) for command ' + @cmd
		Select @error_count = @error_count + 1
		goto label99
	   end


	If @db_norecovOnly_flag = 'y'
	   begin
		Print ' '
		select @miscprint = '--  Note:  This will leave the database in recovery pending mode.'
		print  @miscprint
		goto label99

	   end


   end


diff_start:


-- Differentail Processing
If @db_norecovOnly_flag <> 'y'
   begin


	If DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
	   begin
		select @miscprint = 'DBA ERROR:  A differential restore cannot be completed because the database is not in ''RESTORING'' mode.'
		print  @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   end


	select @cmd = 'dir ' + @full_path + '\' + @diffname_wild
	--print @cmd


	Delete from #DirectoryTempTable
	insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
	delete from #DirectoryTempTable where cmdoutput is null
	delete from #DirectoryTempTable where cmdoutput like '%<DIR>%'
	delete from #DirectoryTempTable where cmdoutput like '%Directory of%'
	delete from #DirectoryTempTable where cmdoutput like '% File(s) %'
	delete from #DirectoryTempTable where cmdoutput like '% Dir(s) %'
	delete from #DirectoryTempTable where cmdoutput like '%Volume in drive%'
	delete from #DirectoryTempTable where cmdoutput like '%Volume Serial Number%'
	--select * from #DirectoryTempTable


	select @filecount = (select count(*) from #DirectoryTempTable)


	if @filecount < 1
	   BEGIN
		Select @miscprint = 'DBA WARNING: No differential files found for dbasp_prerestore at ' + @full_path
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   END


	Start_cmdoutput02:
	Select @save_cmdoutput = (Select top 1 cmdoutput from #DirectoryTempTable order by cmdoutput)
	Select @cu25cmdoutput = @save_cmdoutput


	select @save_fileYYYY = substring(@cu25cmdoutput, 7, 4)
	select @save_fileMM = substring(@cu25cmdoutput, 1, 2)
	select @save_fileDD = substring(@cu25cmdoutput, 4, 2)
	select @save_fileHH = substring(@cu25cmdoutput, 13, 2)
	Select @save_fileAMPM = substring(@cu25cmdoutput, 18, 1)
	If @save_fileAMPM = 'a' and @save_fileHH = '12'
	   begin
		Select @save_fileHH = '00'
	   end
	Else If @save_fileAMPM = 'p' and @save_fileHH <> '12'
	   begin
		Select @save_fileHH = @save_fileHH + 12
	   end
	select @save_fileMN = substring(@cu25cmdoutput, 16, 2)
	Select @save_filedate = @save_fileYYYY + @save_fileMM + @save_fileDD + @save_fileHH + @save_fileMN


	If @hold_filedate < @save_filedate
	   begin
		select @hold_diff_file_name = ltrim(rtrim(substring(@cu25cmdoutput, 40, 200)))
	   end


	Delete from #DirectoryTempTable where cmdoutput = @save_cmdoutput
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		goto Start_cmdoutput02
	   end


	If @hold_diff_file_name is null or @hold_diff_file_name = ''
	   BEGIN
		Select @miscprint = 'DBA ERROR: Unable to determine differential file for dbasp_prerestore at ' + @full_path
		Print @miscprint
		Select @error_count = @error_count + 1
		goto label99
	   END


	If @hold_diff_file_name like '%.DFL'
	   begin
		--  This code is for LiteSpeed files
		select @miscprint = 'EXEC master.dbo.xp_restore_database'
		print  @miscprint
		select @miscprint = '  @database = ''' + @check_dbname + ''''
		print  @miscprint
		select @miscprint = ', @filename = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		print  @miscprint
		select @miscprint = ', @with = RECOVERY'
		print  @miscprint
		select @miscprint = ', @with = ''stats'''
		print  @miscprint
		select @miscprint = 'go'
		print  @miscprint
		Print ' '


		select @Restore_cmd = ''
		select @Restore_cmd = @Restore_cmd + 'EXEC master.dbo.xp_restore_database'
		select @Restore_cmd = @Restore_cmd + '  @database = ''' + @check_dbname + ''''
		select @Restore_cmd = @Restore_cmd + ', @filename = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		select @Restore_cmd = @Restore_cmd + ', @with = RECOVERY'
		select @Restore_cmd = @Restore_cmd + ', @with = ''stats'''


		-- Restore the differential
		select @cmd = @Restore_cmd
		Print 'Here is the restore command being executed;'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)


		If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
		   begin
			If @complete_on_diffOnly_fail = 'y'
			   begin
				--  finish the restore and send the DBA's an email
				Select @save_subject = 'DBAOps:  prerestore Failure for server ' + @@servername
				Select @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
				EXEC DBAOps.dbo.dbasp_sendmail
					@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					@subject = @save_subject,
					@message = @save_message


				select @Restore_cmd = ''
				select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


				select @cmd = @Restore_cmd
				Print 'The differential restore failed.  Completing restore for just the database using the following command;'
				Print @cmd
				raiserror('', -1,-1) with nowait


				Exec (@cmd)


				If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
				   begin
					Print 'DBA Error:  Restore Failure (LiteSpeed DFL restore - Unable to finish restore without the DFL) for command ' + @cmd
					Select @error_count = @error_count + 1
					goto label99
				   end
			   end
			Else
			   begin
				Print 'DBA Error:  Restore Failure (LiteSpeed DFL restore) for command ' + @cmd
				Select @error_count = @error_count + 1
				goto label99
			   end
		   end
	   end
	Else If @hold_diff_file_name like '%.SQD'
	   begin
		--  This code is for RedGate files
		select @miscprint = 'Declare @cmd nvarchar(4000)'
		print  @miscprint
		select @miscprint = 'Select @cmd = ''-SQL "RESTORE DATABASE [' + @check_dbname + ']'
		print  @miscprint
		select @miscprint = ' FROM DISK = ''''' + @full_path + '\' + @hold_diff_file_name + ''''''
		print  @miscprint
		select @miscprint = ' WITH RECOVERY"'''
		print  @miscprint
		select @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(9),'''')'
		print  @miscprint
		select @miscprint = 'SET @cmd = REPLACE(@cmd,CHAR(13)+char(10),'' '')'
		print  @miscprint
		select @miscprint = 'Exec master.dbo.sqlbackup @cmd'
		print  @miscprint
		select @miscprint = 'go'
		print  @miscprint
		Print ' '


		select @Restore_cmd = ''
		select @Restore_cmd = @Restore_cmd + '-SQL "RESTORE DATABASE [' + @check_dbname + ']'
		select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		select @Restore_cmd = @Restore_cmd + ' WITH RECOVERY"'


		-- Restore the differential
		select @cmd = 'Exec master.dbo.sqlbackup ' + @Restore_cmd
		Print 'Here is the restore command being executed;'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec master.dbo.sqlbackup @Restore_cmd


		If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
		   begin
			If @complete_on_diffOnly_fail = 'y'
			   begin
				--  finish the restore and send the DBA's an email
				Select @save_subject = 'DBAOps:  prerestore Failure for server ' + @@servername
				Select @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
				EXEC DBAOps.dbo.dbasp_sendmail
					@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					@subject = @save_subject,
					@message = @save_message


				select @Restore_cmd = ''
				select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


				select @cmd = @Restore_cmd
				Print 'The differential restore failed.  Completing restore for just the database using the following command;'
				Print @cmd
				raiserror('', -1,-1) with nowait


				Exec (@cmd)


				If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
				   begin
					Print 'DBA Error:  Restore Failure (Redgate SQD restore - Unable to finish restore without the SQD) for command ' + @cmd
					Select @error_count = @error_count + 1
					goto label99
				   end
			   end
			Else
			   begin
				Print 'DBA Error:  Restore Failure (Redgate SQD restore) for command ' + @cmd
				Select @error_count = @error_count + 1
				goto label99
			   end
		   end
	   end
	Else
	   begin
		--  This code is for non-LiteSpeed and non-RadGate files
		select @miscprint = 'RESTORE DATABASE ' + @check_dbname
		print  @miscprint
		select @miscprint = 'FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		print  @miscprint
		select @miscprint = 'WITH RECOVERY,'
		print  @miscprint
		select @miscprint = 'stats'
		print  @miscprint
		select @miscprint = 'go'
		print  @miscprint
		Print ' '


		select @Restore_cmd = ''
		select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname
		select @Restore_cmd = @Restore_cmd + ' FROM DISK = ''' + @full_path + '\' + @hold_diff_file_name + ''''
		select @Restore_cmd = @Restore_cmd + ' WITH RECOVERY,'
		select @Restore_cmd = @Restore_cmd + ' stats'


		-- Restore the differential
		select @cmd = @Restore_cmd
		Print 'Here is the restore command being executed;'
		Print @cmd
		raiserror('', -1,-1) with nowait


		Exec (@cmd)


		If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
		   begin
			If @complete_on_diffOnly_fail = 'y'
			   begin
				--  finish the restore and send the DBA's an email
				Select @save_subject = 'DBAOps:  prerestore Failure for server ' + @@servername
				Select @save_message = 'Unable to restore the differential file for database ''' + @check_dbname + ''', the restore will be completed without the differential.'
				EXEC DBAOps.dbo.dbasp_sendmail
					@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
					@subject = @save_subject,
					@message = @save_message


				select @Restore_cmd = ''
				select @Restore_cmd = @Restore_cmd + 'RESTORE DATABASE ' + @check_dbname + ' WITH RECOVERY'


				select @cmd = @Restore_cmd
				Print 'The differential restore failed.  Completing restore for just the database using the following command;'
				Print @cmd
				raiserror('', -1,-1) with nowait


				Exec (@cmd)


				If DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
				   begin
					Print 'DBA Error:  Restore Failure (Standard DIF restore - Unable to finish restore without the DIF) for command ' + @cmd
					Select @error_count = @error_count + 1
					goto label99
				   end
			   end
			Else
			   begin
				Print 'DBA Error:  Restore Failure (Standard DIF restore) for command ' + @cmd
				Select @error_count = @error_count + 1
				goto label99
			   end
		   end
	   end
   end


--  Trun off auto shrink and auto stats for ALTdbname restores
If @ALTdbname is not null and @ALTdbname <> '' and DATABASEPROPERTYEX (@check_dbname,'status') = 'ONLINE'
   begin
	select @miscprint = '--  ALTER DATABASE OPTIONS'
	Print @miscprint
	select @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
	Print @miscprint
	Print ''
	select @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
	Print @miscprint
	Print ''
	select @miscprint = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
	Print @miscprint
	Print ''


	Print 'Here are the Alter Database Option commands being executed;'
	select @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_CREATE_STATISTICS OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait


	Exec (@cmd)


	select @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_UPDATE_STATISTICS OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait


	Exec (@cmd)


	select @cmd = 'ALTER DATABASE [' + @ALTdbname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
	Print @cmd
	raiserror('', -1,-1) with nowait


	Exec (@cmd)
   end


-- Shrink DB LDF Files if requested
If @post_shrink = 'y' and DATABASEPROPERTYEX (@check_dbname,'status') = 'ONLINE'
   begin
	Print '--NOTE:  Post Restore LDF file shrink was requested'
	Print ' '


	Select @miscprint = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @check_dbname + ''''
	print  @miscprint
	Select @cmd = 'exec DBAOps.dbo.dbasp_ShrinkLDFFiles @DBname = ''' + @check_dbname + ''''


	select @miscprint = 'go'
	print  @miscprint
	Print ' '


	If DATABASEPROPERTYEX (@check_dbname,'status') = 'ONLINE'
	   begin
		select @miscprint = 'Shrink file using command: ' + @cmd
		print  @miscprint
		exec(@cmd)
	   end
   end


-------------------   end   --------------------------


label99:


--  Check to make sure the DB is in 'restoring' mode if requested
If @db_norecovOnly_flag = 'y' and DATABASEPROPERTYEX (@check_dbname,'status') <> 'RESTORING'
   begin
	select @miscprint = 'DBA ERROR:  A norecovOnly restore was requested and the database is not in ''RESTORING'' mode.'
	print  @miscprint
	Select @error_count = @error_count + 1
   end


If @error_count = 0 and @db_norecovOnly_flag = 'n' and DATABASEPROPERTYEX (@check_dbname,'status') <> 'ONLINE'
   begin
	select @miscprint = 'DBA ERROR:  The prerestore process has failed for database ' + @check_dbname + '.  That database is not ''ONLINE'' at this time.'
	print  @miscprint
	Select @error_count = @error_count + 1
   end


drop table #DirectoryTempTable
drop table #filelist
drop table #filelist_rg


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
GRANT EXECUTE ON  [dbo].[dbasp_prerestore] TO [public]
GO
