SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_JoblogRename] (@retention_days smallint = 14)

/*********************************************************
 **  Stored Procedure dbasp_Check_JoblogRename                  
 **  Written by Steve Ledridge, Virtuoso                
 **  November 11, 2004                                      
 **  
 **  This procedure is used to rename SQL job step logs.
 **  The process will add a date stamp at the end of the 
 **  file name, and will also delete files that are past the 
 **  retention period.
 **
 **  This proc accepts one input parm (outlined below):
 **
 **  - @retention_days is the number of days worth of sql job step
 **    logs that will be retained at any given time.
 **
 ***************************************************************/
 as
SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/11/2004	Steve Ledridge		New process 
--	06/01/2006	Steve Ledridge		Convert to SQL 2005. 
--	10/13/2008	Steve Ledridge		Moved temp table creation to start. 
--	03/18/2014	Steve Ledridge		Replaced Dynamic script Cursor with Standard Cursor Syntax.
--						Added Quotes arround File names to support spaces in the names.
--	======================================================================================



/***
Declare @retention_days smallint

Select @retention_days = 14
--***/



-----------------  declares  ------------------
DECLARE
			@miscprint					nvarchar(4000)
			,@cmd						nvarchar(4000)
			,@save_servername			sysname
			,@save_servername2			sysname
			,@charpos					int
			,@startpos					int
			,@dotpos					int
			,@uspos						int
			,@save_extention			nvarchar(50)
			,@BkUpDateStmp 				char(14)
			,@Hold_hhmmss				nvarchar(8)
			,@save_filedate				sysname
			,@error_count				int

DECLARE
			@cu11cmdoutput				nvarchar(255)


DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@PathAndFile				VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					VarChar(10)
			,@PathTree					VarChar(Max)
			,@Size						BIGINT
			,@FreeSpace					BIGINT
			,@diffPrediction			INT
			,@tmpvar1					VarChar(max)
			,@tmpvar2					VarChar(max)
			,@tmpvar3					VarChar(max)

----------------  initial values  -------------------

	EXEC DBAOps.dbo.dbasp_GetPaths
		 @DataPath			= @DataPath			 OUT
		,@LogPath			= @LogPath			 OUT
		,@BackupPathL		= @BackupPathL		 OUT
		,@BackupPathN		= @BackupPathN		 OUT
		,@BackupPathN2		= @BackupPathN2		 OUT
		,@DBASQLPath		= @DBASQLPath		 OUT
		,@SQLAgentLogPath	= @SQLAgentLogPath	 OUT
		,@DBAArchivePath	= @DBAArchivePath	 OUT
		,@EnvBackupPath		= @EnvBackupPath	 OUT
		,@SQLEnv			= @SQLEnv			 OUT


----------------  initial values  -------------------
Select @error_count = 0

If @SQLEnv != 'PRO'
	SET @retention_days = 1

Set @Hold_hhmmss = convert(nvarchar(8), getdate(), 8)
Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2) 


--  Create temp tables
create table #fileexists ( 
			 doesexist smallint
			,fileindir smallint
			,direxist smallint
			)

create table #DirectoryTempTable(cmdoutput nvarchar(255) null)



/****************************************************************
 *                MainLine
 ***************************************************************/

--  Verify sql job log path existance
delete from #fileexists
Insert into #fileexists exec master.sys.xp_fileexist @SQLAgentLogPath

--select * from #fileexists

If not exists (select fileindir from #fileexists where fileindir = 1)
   begin
	Select @miscprint = 'DBA WARNING: dbasp_Check_JoblogRename - SQL Job Log Path does not exist.  Check standard Shares.' 
	print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end



--  Check to see if there are files to process
select @cmd = 'dir ' + @SQLAgentLogPath + '*.*'

delete from #DirectoryTempTable
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput like ('%<DIR>%')
delete from #DirectoryTempTable where cmdoutput is null


--select * from #DirectoryTempTable

If (select count(*) from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) like '%File Not Found%') > 0
   begin
	Select @miscprint = 'DBA WARNING: dbasp_Check_JoblogRename - No files found for the Check SQL Job Log Rename process' 
	print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end




DECLARE CommandCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		p.cmdoutput
From		#DirectoryTempTable p
Order by	p.cmdoutput 

OPEN CommandCursor;
FETCH CommandCursor INTO @cu11cmdoutput;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
	
		--  Check to see if this is a record we want to process.  If not, get the next record
		If substring(@cu11cmdoutput, 3, 1) <> '/'
		   begin
			goto label50
		   end


		--  Next, remove everything but the file name.
		If substring(@cu11cmdoutput, 39, 1) = ' '
		   begin
			Select @cu11cmdoutput = substring(@cu11cmdoutput, 40, 500)
			Select @cu11cmdoutput = rtrim(@cu11cmdoutput)
		   end
		Else
		   begin
			Select @miscprint = 'DBA WARNING: dbasp_Check_JoblogRename - Unable to process the following.' 
			print @miscprint
			Select @miscprint = @cu11cmdoutput 
			print @miscprint
		   end



		--  Save the extension and get the dot location.
		Select @dotpos = 0
		Select @startpos = 1
		Label52:
		Select @charpos = charindex('.', @cu11cmdoutput, @startpos)
		IF @charpos <> 0
		   begin
			Select @startpos = @charpos + 1
			Select @dotpos = @charpos
			goto label52
		   end

		If @dotpos > 0
		   begin
			Select @save_extention = substring(@cu11cmdoutput, @dotpos+1, 50)
		   end
		Else
		   begin
			Select @save_extention = ''
			Select @dotpos = len(@cu11cmdoutput)
		   end



		--  Find the location of the last underscore.  If there is none, then this file needs to be renamed.
		Select @uspos = 0
		Select @startpos = 1
		Label54:
		Select @charpos = charindex('_', @cu11cmdoutput, @startpos)
		IF @charpos <> 0
		   begin
			Select @startpos = @charpos + 1
			Select @uspos = @charpos
			goto label54
		   end

		If @uspos = 0
		   begin
			Select @cmd = 'REN "' + @SQLAgentLogPath + @cu11cmdoutput + '" "' + substring(@cu11cmdoutput, 1, @dotpos-1) + '_' + @BkUpDateStmp + '.' + @save_extention + '"'
			Print @cmd	
			EXEC master.sys.xp_cmdshell @cmd--, no_output 
			goto label50
		   end


		--  If the difference between the last underscore and the last dot is not 15, then this file needs to be renamed.
		If @dotpos - @uspos <> 15
		   begin
			Select @cmd = 'REN "' + @SQLAgentLogPath + @cu11cmdoutput + '" "' + substring(@cu11cmdoutput, 1, @dotpos-1) + '_' + @BkUpDateStmp + '.' + @save_extention + '"'
			Print @cmd	
			EXEC master.sys.xp_cmdshell @cmd--, no_output 
			goto label50
		   end


		--  At this point, this is probably a file that was previously renamed, but we need to be sure.
		--  If any char between the underscore and the dot is alpha, rename the file.
		If substring(@cu11cmdoutput, @uspos+1, 1) not in ('2') or
		   substring(@cu11cmdoutput, @uspos+2, 1) not in ('0') or
		   substring(@cu11cmdoutput, @uspos+3, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+4, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+5, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+6, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+7, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+8, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+9, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+10, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		 substring(@cu11cmdoutput, @uspos+11, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+12, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+13, 1) not in ('1','2','3','4','5','6','7','8','9','0') or
		   substring(@cu11cmdoutput, @uspos+14, 1) not in ('1','2','3','4','5','6','7','8','9','0')
		   begin
			Select @cmd = 'REN "' + @SQLAgentLogPath + @cu11cmdoutput + '" "' + substring(@cu11cmdoutput, 1, @dotpos-1) + '_' + @BkUpDateStmp + '.' + @save_extention + '"'
			Print @cmd	
			EXEC master.sys.xp_cmdshell @cmd--, no_output 
			goto label50
		   end


		--  PURGE Processing  ------------------------------------------------------------------------------
		--  If we are at this point, we have a file that was previously renamed.  We need to check retention
		--  for this file to see if it should be deleted.
		Select @save_filedate = substring(@cu11cmdoutput, @uspos+1, @dotpos-@uspos-7)

		If datediff(d, convert(datetime, @save_filedate), getdate()) > @retention_days
		   begin
			Select @cmd = 'DEL "' + @SQLAgentLogPath + @cu11cmdoutput +'"'
			Print @cmd	
			EXEC master.sys.xp_cmdshell @cmd--, no_output 
		   end


		Label50:

		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM CommandCursor INTO @cu11cmdoutput;
END
CLOSE CommandCursor;
DEALLOCATE CommandCursor;







--  Finalization  -------------------------------------------------------------------

label99:


drop table #fileexists
drop table #DirectoryTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_JoblogRename] TO [public]
GO
