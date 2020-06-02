SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSdbRestore_singleDB] (@dbname sysname = null
						,@NoLogRestores BIT = 1
						,@outpath varchar(500) = null)


/*********************************************************
 **  Stored Procedure dbasp_SYSdbRestore_singleDB
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  September 20, 2007
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Restore databases (including full, diff and tlog)
 **
 **  This proc accepts three input parms:
 **
 **  @dbname is required.
 **
 **  - @dbname is the name of the database to be restored.
 **
 **  - @outpath is the output path, including the file name,
 **    if an output file is being requested (default is null).
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/20/2007	Steve Ledridge		New process
--	09/21/2007	Steve Ledridge		Updated for SQL2005.
--	06/11/2008	Steve Ledridge		Change sys.sysfiles to sys.database_files.
--	04/14/2009	Steve Ledridge		Errorfor DB not online.
--	12/07/2010	Steve Ledridge		Added code for filegroup processing.
--	12/20/2010	Steve Ledridge		Changed @cmd to varchar(4000)
--	04/14/2011	Steve Ledridge		backup_set_id add to where clause to make results smaller.
--	07/18/2011	Steve Ledridge		Modified the population of #Backupinfo to filter out physical
--						devices the look like GUID's
--	10/24/2012	Steve Ledridge		Changed the data capture for #Backupinfo for FG processing.
--	11/21/2013	Steve Ledridge		Modified to use dbasp_format_BackupRestore.
--	11/11/2014	Steve Ledridge		New input parm for tranlog restores.
--	======================================================================================


/*
declare @dbname sysname
declare @NoLogRestores BIT
declare @outpath varchar(500)


select @dbname = 'ReportServer'
Select @NoLogRestores = 1
--Select @outpath = '\\seapsqldply02\seapsqldply02_dba_archive\seapsqldply02_RestoreFull_' + @dbname
--*/


-----------------  declares  ------------------


DECLARE
	 @miscprint		varchar(max)
	,@charpos		int
	,@CRLF			char(2)
	,@error_count		int
	,@G_O			nvarchar(2)
	,@output_flag		char(1)
	,@syntax_out		varchar(max)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@backup_path		nvarchar(500)


	----------------  initial values  -------------------
Select @error_count 	= 0
Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'
Select @CRLF = char(13)+char(10)


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @backup_path = '\\' + @save_servername + '\' + @save_servername2 + '_backup\'


--  Initialize output file
If @outpath is not null
   begin
	exec dbo.dbasp_FileAccess_Write @InputText = '', @path = @outpath, @append = 0, @ForceCrLf = 0
   end


----------------------  Main header  ----------------------
Select @miscprint = ' ' + @CRLF
Select @miscprint =  @miscprint + '/************************************************************************' + @CRLF
Select @miscprint =  @miscprint +  'Generated SQL - SYSdbRestore_singleDB' + @CRLF
Select @miscprint =  @miscprint + 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9) + @CRLF
Select @miscprint =  @miscprint + '************************************************************************/'
Select @miscprint =  @miscprint + ' ' + @CRLF


If @outpath is not null
   begin
	exec dbo.dbasp_FileAccess_Write @InputText = @miscprint, @path = @outpath, @append = 1, @ForceCrLf = 1
   end
Else
   begin
	exec dbo.dbasp_PrintLarge @miscprint
   end


--  Check input parms
if not exists (select * from master.sys.databases where name = @dbname)
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @dbname'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


if DATABASEPROPERTYEX (@dbname ,'status') <> 'ONLINE'
   begin
	Select @miscprint = 'DBA WARNING: Database not online.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------
Select @miscprint = ' ' + @CRLF
Select @miscprint =  @miscprint + '/*********************************************************' + @CRLF
Select @miscprint =  @miscprint + 'Restore for Database: ' + @dbname  + @CRLF
Select @miscprint =  @miscprint + ' ' + @CRLF
Select @miscprint =  @miscprint + 'Note: Prior to running the following restore command,' + @CRLF
Select @miscprint =  @miscprint + '      some changes in the syntax may be required, such' + @CRLF
Select @miscprint =  @miscprint + '      as the name of the backup file(s), or the path of the' + @CRLF
Select @miscprint =  @miscprint + '      restored files.' + @CRLF
Select @miscprint =  @miscprint + '*********************************************************/' + @CRLF
Select @miscprint =  @miscprint + ' ' + @CRLF


Select @output_flag = 'y'

Select @miscprint =  @miscprint + 'select @@servername, getdate()' + @CRLF
Select @miscprint =  @miscprint + @G_O + @CRLF


Select @miscprint =  @miscprint + ' ' + @CRLF
Select @miscprint =  @miscprint + '--==========================================================' + @CRLF
Select @miscprint =  @miscprint + '--  Example call to dbasp_format_BackupRestore sproc' + @CRLF
Select @miscprint =  @miscprint + '--  Note: As is, this will generate a full restore script' + @CRLF
Select @miscprint =  @miscprint + '--        including backup, differential and all tran logs.' + @CRLF
Select @miscprint =  @miscprint + '--        Uncomment, update and execute as needed to create' + @CRLF
Select @miscprint =  @miscprint + '--        the restore script you need.' + @CRLF
Select @miscprint =  @miscprint + '--==========================================================' + @CRLF


Select @miscprint =  @miscprint + '--Declare @syntax_out varchar(max)' + @CRLF
Select @miscprint =  @miscprint + '--exec DBAOps.dbo.dbasp_format_BackupRestore' + @CRLF
Select @miscprint =  @miscprint + '--			  @DBName          = ''' + @dbname + '''' + @CRLF
Select @miscprint =  @miscprint + '--			, @Mode            = ''RD'''  + @CRLF
Select @miscprint =  @miscprint + '--			, @FilePath        = ''' + @backup_path + '''' + @CRLF
Select @miscprint =  @miscprint + '--			, @FileGroups      = null' + @CRLF
Select @miscprint =  @miscprint + '--			, @WorkDir         = null -- Used to copy the backup local prior to a restore' + @CRLF
Select @miscprint =  @miscprint + '--			, @FullReset       = 1' + @CRLF
Select @miscprint =  @miscprint + '--			, @IncludeSubDir   = 0' + @CRLF
Select @miscprint =  @miscprint + '--			, @Verbose         = 0' + @CRLF
Select @miscprint =  @miscprint + '--			, @LeaveNORECOVERY = 0' + @CRLF
Select @miscprint =  @miscprint + '--			, @NoLogRestores   = 0' + @CRLF
Select @miscprint =  @miscprint + '--			, @NoDifRestores   = 0' + @CRLF
Select @miscprint =  @miscprint + '--			, @syntax_out      = @syntax_out output' + @CRLF
Select @miscprint =  @miscprint + ' ' + @CRLF
Select @miscprint =  @miscprint + '--Select @syntax_out = Replace(@syntax_out, ''DROP DATABASE'', ''--DROP DATABASE'')' + @CRLF
Select @miscprint =  @miscprint + '--Select @syntax_out = Replace(@syntax_out, ''EXEC [msdb]'', ''--EXEC [msdb]'')' + @CRLF
Select @miscprint =  @miscprint + '--exec DBAOps.dbo.dbasp_PrintLarge @syntax_out' + @CRLF


If @outpath is not null
   begin
	exec dbo.dbasp_FileAccess_Write @InputText = @miscprint, @path = @outpath, @append = 1, @ForceCrLf = 1
   end
Else
   begin
	exec dbo.dbasp_PrintLarge @miscprint
   end


Set @syntax_out = ''
exec dbo.dbasp_format_BackupRestore
			@DBName			= @dbname
			, @Mode			= 'RD'
			, @FullReset		= 1
			, @IncludeSubDir	= 1
			, @NoLogRestores 	= @NoLogRestores
			, @Verbose		= -1
			, @syntax_out		= @syntax_out output


Select @syntax_out = Replace(@syntax_out, 'DROP DATABASE', '--DROP DATABASE')
Select @syntax_out = Replace(@syntax_out, 'EXEC [msdb]', '--EXEC [msdb]')


If @outpath is not null
   begin
	exec dbo.dbasp_FileAccess_Write @InputText = @syntax_out, @path = @outpath, @append = 1, @ForceCrLf = 1
   end
Else
   begin
	exec dbo.dbasp_PrintLarge @syntax_out
   end


Select @miscprint = ' ' + @CRLF
Select @miscprint =  @miscprint + @G_O + @CRLF
Select @miscprint =  @miscprint + ' ' + @CRLF
Select @miscprint =  @miscprint + ' ' + @CRLF
Select @miscprint =  @miscprint + 'select getdate()' + @CRLF
Select @miscprint =  @miscprint + @G_O + @CRLF


If @outpath is not null
   begin
	exec dbo.dbasp_FileAccess_Write @InputText = @miscprint, @path = @outpath, @append = 1, @ForceCrLf = 1
   end
Else
   begin
	exec dbo.dbasp_PrintLarge @miscprint
   end


---------------------------  Finalization  -----------------------
label99:


If @error_count > 0
   begin
	If @outpath is not null
	   begin
		exec dbo.dbasp_FileAccess_Write @InputText = @miscprint, @path = @outpath, @append = 1, @ForceCrLf = 1
	   end
	Else
	   begin
		exec dbo.dbasp_PrintLarge @miscprint
	   end
   end


If @output_flag = 'n'
   begin
	If @outpath is not null
	   begin
		exec dbo.dbasp_FileAccess_Write @InputText = '-- No output for this script.', @path = @outpath, @append = 1, @ForceCrLf = 1
	   end
	Else
	   begin
		Print '-- No output for this script.'
	   end
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSdbRestore_singleDB] TO [public]
GO
