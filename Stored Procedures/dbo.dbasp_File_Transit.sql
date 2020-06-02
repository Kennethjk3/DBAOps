SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_File_Transit] 
				(
				@source_name		sysname				= null
				,@source_path		NVarchar(500)		= null
				,@target_env		sysname				= null
				,@target_server		sysname				= null
				,@target_share		sysname				= null
				,@retry_limit		Smallint			= 5
				)


/*********************************************************
 **  Stored Procedure dbasp_File_Transit
 **  Written by Steve Ledridge, Virtuoso
 **  August 01, 2005
 **
 **  This procedure is used for copying files and folders from one Domain
 **  to another where there is no trust relationship.
 **
 **  This proc accepts the following input parms:
 **  - @source_name is the name of the source file or folder.
 **  - @source_path is the path where files are being copied from.
 **  - @target_env is the environment where files are being copied to.
 **  - @target_server is the server where files need to be copied to.
 **  - @target_share is the share name where files need to be copied to.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/14/2005	Steve Ledridge		New process
--	10/11/2007	Steve Ledridge		Added ability to transit to share sub folders.
--	09/16/2008	Steve Ledridge		seafresqldba02 to seafresqldba01.
--	09/15/2009	Steve Ledridge		Convert DBAOpser04 to seafresqldba01.
--	03/16/2010	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply05.
--	09/13/2011	Steve Ledridge		Convert seafresqldba01 to seapsqldba01.
--	06/18/2012	Steve Ledridge		Changed central server from seapsqldply05 to DBAOpser04.
--	04/16/2014	Steve Ledridge		Changed central server from seapsqldba01 to seapdbasql01.
--	05/01/2014	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply04.
--	02/18/2015	Steve Ledridge		If target is central server share, bypass file transit.
--								Also converted from robocopy to dbasp_FileHandler.
--	11/21/2016	Steve Ledridge		Modified Error messages to include the value of bad parameters if not null.
--	======================================================================================


/***
Declare @source_name nvarchar(500)
Declare @source_path nvarchar(500)
Declare @target_env sysname
Declare @target_server sysname
Declare @target_share nvarchar(500)
Declare @retry_limit smallint


select @source_name = '*.html'
Select @source_path = '\\sdcprosssql02.db.virtuoso.com\DBASQL\dba_reports'
Select @target_env = 'virtuoso'
Select @target_server = 'SDCSQLTOOLS.db.virtuoso.com'
Select @target_share = 'dba_reports'
Select @retry_limit = 5

exec [dbo].[dbasp_File_Transit] 

				@source_name		
				,@source_path		
				,@target_env		
				,@target_server		
				,@target_share		
				,@retry_limit		

--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint				NVarchar(4000)
	,@error_count			int
	,@cmd	 				NVarchar(4000)
	,@retcode 				Int
	,@filecount				Smallint
	,@filename_wild			nvarchar(500)
	,@file_type				NVarchar(10)
	,@charpos				Int
	,@savefilename			nvarchar(500)
	,@hold_filedate			nvarchar(12)
	,@save_filedate			nvarchar(12)
	,@save_filedate2		nvarchar(20)
	,@save_fileYYYY			nvarchar(4)
	,@save_fileMM			nvarchar(2)
	,@save_fileDD			nvarchar(2)
	,@save_fileHH			nvarchar(2)
	,@save_fileMN			nvarchar(2)
	,@save_fileAMPM			nvarchar(1)
	,@retry_counter			smallint
	,@save_domain_name		sysname
	,@save_central_server	sysname
	,@save_newname			nvarchar(500)
	,@save_fullpath			nvarchar(500)
	,@save_depart_path		nvarchar(500)
	,@bypass_transit		char(1)

DECLARE
	  @cu11cmdoutput		nvarchar(255)
	 ,@CopyTo_path			nvarchar(500)
	 ,@CopyFrom_path		nvarchar(500)
	 ,@syntax_out			varchar(max)


DECLARE
	 @Source			Varchar(max)
	,@Destination		VarChar(max)
	,@Data				Xml


----------------  initial values  -------------------
Select @error_count = 0

create table #DirectoryTempTable(cmdoutput nvarchar(500) null)


create table #fileexists (
	doesexist smallint,
	fileindir smallint,
	direxist smallint)


--  Check input parms
if @source_name is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit.  @source_name is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @source_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit.  @source_path is required'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_server is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @target_server is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


if @target_share is null
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit. @target_share is required.'
	Print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   END


--  Verify source path existance
Insert into #fileexists exec master.sys.xp_fileexist @source_path
--select * from #fileexists


If not exists (select 1 from #fileexists where fileindir = 1)
   begin
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit - Source Path '''+@source_path+''' does not exist.  Check input parameter.'
	print @miscprint
	Select @error_count = @error_count + 1
	goto label99
   end


--  Verify source file existance
Delete from #fileexists
Select @save_fullpath = rtrim(@source_path) + '\' + rtrim(@source_name)
Insert into #fileexists exec master.sys.xp_fileexist @save_fullpath
--select * from #fileexists

IF EXISTS	(
			SELECT		FullPathName				AS [Source]
			FROM		dbo.dbaudf_DirectoryList2(@source_path,@source_name,0)
			)
BEGIN

	SELECT @filecount = COUNT(*) FROM dbo.dbaudf_DirectoryList2(@source_path,@source_name,0)

	RAISERROR(' -- %d Files Identified to copy',-1,-1,@filecount) WITH NOWAIT
	Select @file_type = 'file'


END
ELSE IF EXISTS	(
				SELECT		FullPathName				AS [Source]
				FROM		dbo.dbaudf_DirectoryList2(@save_fullpath,NULL,0)
				)
BEGIN
	Select @file_type = 'folder'


END
ELSE
BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameters to dbasp_File_Transit - Source File '''+@save_fullpath+''' does not exist.  Check input parameter.'
	print @miscprint
	Select @error_count = @error_count + 1
	goto label99
END


----  Set file type (file or folder)
--If (select top 1 doesexist from #fileexists) = 0 and (select top 1 fileindir from #fileexists) = 1
--   begin
--	Select @file_type = 'folder'
--   end
--Else
--   begin
--	Select @file_type = 'file'
--   end

--SELECT @file_type



/****************************************************************
 *                MainLine
 ***************************************************************/


start_process01:


If @file_type = 'file'
begin
	select @CopyTo_path = '\\' + @target_server + '\' + @target_share + '\'
	Select @CopyFrom_path = @source_path
	If left(reverse(@CopyFrom_path), 1) <> '\'
	   begin
		Select @CopyFrom_path = @CopyFrom_path + '\'
	   end


	--  Create XML for the copy process
	;WITH		Settings
				AS
				(
				SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
							,'false'	AS [ForceOverwrite]	-- true,false
							,0			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
							,30			AS [UpdateInterval]	-- rate of progress updates in Seconds
				)
				,CopyFile -- MoveFile, DeleteFile
				AS
				(
				SELECT		FullPathName				AS [Source]
							,@CopyTo_path + Name		AS [Destination]
				FROM		dbo.dbaudf_DirectoryList2(@CopyFrom_path,@source_name,0)
				)
	SELECT		@Data =	(
				SELECT *
					,(SELECT * FROM CopyFile FOR XML RAW ('CopyFile'), TYPE)
				FROM Settings
				FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
				)


	SET @syntax_out = [DBAOps].[dbo].[dbaudf_FormatXML2String](@Data)
	EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


	If @Data is not null
	   begin
		exec dbo.dbasp_FileHandler @Data
	   end
	Else
	   begin
		Select @miscprint = 'DBA ERROR: XML being passed to dbo.dbasp_FileHandler is null for bypass transit.'
		Print @miscprint
	   end
END

Else If @file_type = 'folder'
   begin
	-- create the folder at the target location
	Select @cmd = 'mkdir "' + rtrim(@save_depart_path) + '\' + rtrim(@save_newname) + '"'
	Print @cmd
	EXEC @retcode = master.sys.xp_cmdshell @cmd--, no_output


	select @CopyTo_path = rtrim(@save_depart_path) + '\' + rtrim(@save_newname) + '\'
	Select @CopyFrom_path = @source_path + '\' + @source_name
	If left(reverse(@CopyFrom_path), 1) <> '\'
	   begin
		Select @CopyFrom_path = @CopyFrom_path + '\'
	   end


	--  Create XML for the copy process
	;WITH		Settings
				AS
				(
				SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
							,'false'	AS [ForceOverwrite]	-- true,false
							,0			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
							,30			AS [UpdateInterval]	-- rate of progress updates in Seconds
				)
				,CopyFile -- MoveFile, DeleteFile
				AS
				(
				SELECT		FullPathName			AS [Source]
							,@CopyTo_path + Name 	AS [Destination]
				FROM		dbo.dbaudf_DirectoryList2(@CopyFrom_path,'*.*',0)
				)
	SELECT		@Data =	(
						SELECT	*
								,(SELECT * FROM CopyFile FOR XML RAW ('CopyFile'), TYPE)
						FROM Settings
						FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
						)


	SET @syntax_out = [DBAOps].[dbo].[dbaudf_FormatXML2String](@Data)
	EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


	If @Data is not null
	   begin
		exec dbo.dbasp_FileHandler @Data
	   end
	Else
	   begin
		Select @miscprint = 'DBA ERROR: XML being passed to dbo.dbasp_FileHandler is null for folder transit.'
		Print @miscprint
	   end
   end
Else
   begin


	select @CopyTo_path = rtrim(@save_depart_path) + '\'
	Select @CopyFrom_path = @source_path
	If left(reverse(@CopyFrom_path), 1) <> '\'
	   begin
		Select @CopyFrom_path = @CopyFrom_path + '\'
	   end


	--  Create XML for the copy process
	;WITH		Settings
			AS
			(
			SELECT		32			AS [QueueMax]		-- Max Number of files coppied at once.
						,'false'	AS [ForceOverwrite]	-- true,false
						,0			AS [Verbose]		-- -1 = Silent, 0 = Normal, 1 = Percent Updates
						,30			AS [UpdateInterval]	-- rate of progress updates in Seconds
			)
			,CopyFile -- MoveFile, DeleteFile
			AS
			(
			SELECT		FullPathName					AS [Source]
						,@CopyTo_path + @save_newname	AS [Destination]
			FROM		dbo.dbaudf_DirectoryList2(@CopyFrom_path,@source_name,0)
			)
	SELECT		@Data =	(
						SELECT	*
								,(SELECT * FROM CopyFile FOR XML RAW ('CopyFile'), TYPE)
						FROM Settings
						FOR XML RAW ('Settings'),TYPE, ROOT('FileProcess')
						)


	SET @syntax_out = [DBAOps].[dbo].[dbaudf_FormatXML2String](@Data)
	EXEC [DBAOps].[dbo].[dbasp_PrintLarge] @syntax_out


	If @Data is not null
	   begin
		exec dbo.dbasp_FileHandler @Data
	   end
	Else
	   begin
		Select @miscprint = 'DBA ERROR: XML being passed to dbo.dbasp_FileHandler is null for bypass transit.'
		Print @miscprint
	   end
   end


-------------------   end   --------------------------


label99:


drop table #DirectoryTempTable
drop table #fileexists


If @error_count > 0
   begin
	raiserror(@miscprint,-1,-1) with log
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_File_Transit] TO [public]
GO
