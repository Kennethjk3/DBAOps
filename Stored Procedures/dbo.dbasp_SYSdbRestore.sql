SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSdbRestore]


/*********************************************************
 **  Stored Procedure dbasp_SYSdbRestore
 **  Written by Steve Ledridge, Virtuoso
 **  October 13, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Restore databases
 **
 **  Output member is SYSdbRestore.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/30/2002	Steve Ledridge		Added brackets around dbname variable in select stmts.
--	06/22/2004	Steve Ledridge		Added code for diferential restores.
--	08/19/2005	Steve Ledridge		Added code for LiteSpeed processing.
--	12/22/2005	Steve Ledridge		New code for mutilple backup files.
--	05/30/2006	Steve Ledridge		Updated for SQL 2005.
--	07/24/2007	Steve Ledridge		Added RedGate processing.
--	06/11/2008	Steve Ledridge		Change sys.sysfiles to sys,database_files.
--	01/02/2009	Steve Ledridge		Converted to new no_check table.
--	04/14/2009	Steve Ledridge		Skip db's not online.
--	11/19/2009	Steve Ledridge		Added filegroup processing
--	12/20/2010	Steve Ledridge		Changed @cmd to varchar(4000)
--	07/18/2011	Steve Ledridge		Modified the population of #Backupinfo to filter out physical
--						devices the look like GUID's
--	11/20/2013	Steve Ledridge		Changed to use dbasp_format_BackupRestore
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@output_flag		char(1)
	,@syntax_out		varchar(max)


DECLARE
	 @cu11DBName		sysname


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'


--  Create table variable
declare @dbnames table	(name		sysname)


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSdbRestore'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


--------------------  Capture DB names  -------------------
Insert into @dbnames (name)
SELECT d.name
From master.sys.databases d with (NOLOCK)
Where d.name not in ('master', 'model', 'msdb', 'tempdb')
  and d.name not in (select detail01 from dbo.no_check where NoCheck_type = 'backup')


delete from @dbnames where name is null or name = ''
--select * from @dbnames


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------
Print  ' '
Print  '/*********************************************************'
Select @miscprint = 'Restore Database''s for server: ' + @@servername
Print  @miscprint
Print  '*********************************************************/'
Print  ' '
Print  ' '


If (select count(*) from @dbnames) > 0
   begin
	start_dbnames:


	Select @cu11DBName = (select top 1 name from @dbnames order by name)


	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'Restore for Database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Note: Prior to running the following restore command,'
	Print  @miscprint
	Select @miscprint = '      some changes in the syntax may be required, such'
	Print  @miscprint
	Select @miscprint = '      as the name of the backup file, or the path of the'
	Print  @miscprint
	Select @miscprint = '      restored files.'
	Print  @miscprint
	Print  '*********************************************************/'
	Print  ' '


	If DATABASEPROPERTYEX (@cu11DBName ,'status') <> 'ONLINE'
	   begin
		Select @miscprint = '--  Skipping this DB.  It is currently NOT online.'
		Print  @miscprint
		goto skip_dbname
	   end


	Select @miscprint = 'select @@servername, getdate()'
	Print  @miscprint
	Print  @G_O


	Set @syntax_out = ''
	exec dbo.dbasp_format_BackupRestore
				@DBName			= @cu11DBName
				, @Mode			= 'RD'
				, @FullReset		= 1
				, @NoLogRestores	= 1
				, @IncludeSubDir	= 1
				, @Verbose		= -1
				, @syntax_out		= @syntax_out output


	Select @syntax_out = Replace(@syntax_out, 'DROP DATABASE', '--DROP DATABASE')
	Select @syntax_out = Replace(@syntax_out, 'EXEC [msdb]', '--EXEC [msdb]')
	Print ''
	exec dbo.dbasp_PrintLarge @syntax_out
	Print 'go'
	RAISERROR('',-1,-1) WITH NOWAIT


	Select @output_flag = 'y'


	skip_dbname:


	--  Remove this record from @dbnames and go to the next
	delete from @dbnames where name = @cu11DBName
	If (select count(*) from @dbnames) > 0
	   begin
		goto start_dbnames
	   end
   end


---------------------------  Finalization  -----------------------
label99:


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSdbRestore] TO [public]
GO
