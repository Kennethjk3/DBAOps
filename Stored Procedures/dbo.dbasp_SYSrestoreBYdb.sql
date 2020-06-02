SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSrestoreBYdb] (@outfiles char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_SYSrestoreBYdb
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 01, 2002
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Perform a full Restore of a user database
 **  using a full set of scripts
 **
 **  Output member is SYSRestore_<dbname>.gsql if @outfiles = 'y'
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/01/2002	Steve Ledridge		New process
--	04/17/2003	Steve Ledridge		Changes for new instance share names.
--	04/18/2003	Steve Ledridge		Modified revoke db access section.
--	10/16/2003	Steve Ledridge		Added identity column to output temp table to
--						force order.
--	10/28/2003	Steve Ledridge		Added set user status
--	06/22/2004	Steve Ledridge		Added code for set user status
--	07/20/2005	Steve Ledridge		Added code for change object owner
--	09/21/2005	Steve Ledridge		System objects will now be excluded from the
--						change object owner process
--	10/02/2005	Steve Ledridge		Added brackets for DBname in change object owner section
--	04/26/2006	Steve Ledridge		In sysmessages, changed double quotes to single quotes
--	11/07/2006	Steve Ledridge		Added code for LiteSpeed processing and mutilple backup files.
--	11/15/2006	Steve Ledridge		Re-created for SQL 2005.
--	11/27/2006	Steve Ledridge		Fixed double quotes in drop user section.  Added ^ for echo > and <.
--	12/21/2006	Steve Ledridge		This new sproc calls sproc dbasp_SYSrestoreBYsingledb.
--	05/01/2007	Steve Ledridge		Changed sqlcmd outpt to unicode.
--	04/14/2009	Steve Ledridge		Skip db's not online.
--	======================================================================================


/***
Declare @outfiles char(1)


Select @outfiles = 'y'
--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd			nvarchar(4000)
	,@sqlcmd		nvarchar(4000)
	,@charpos		int
	,@output_flag		char(1)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_servername3	sysname
	,@out_file_name		nvarchar(500)
	,@result		int


DECLARE
	 @cu11DBName		sysname
	,@cu11DBsid		varbinary(85)
	,@cu11DBid		int
	,@cu11DBcmptlevel	tinyint


----------------  initial values  -------------------


Select @output_flag	= 'n'
Select @out_file_name = null


--  Set servername variables
Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @save_servername3	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


--  Create temp tables and table variables
declare @dbnames table	(name		sysname
			,sid		varbinary(85)
			,dbid		smallint
			,cmptlevel	smallint
			)


--------------------  Capture DB names  -------------------
Insert into @dbnames (name, sid, dbid, cmptlevel)
SELECT d.name, d.owner_sid, d.database_id, d.compatibility_level
From master.sys.databases d with (NOLOCK)
Where d.name not in ('master', 'model', 'msdb', 'tempdb')


delete from @dbnames where name is null or name = ''
--select * from @dbnames


/****************************************************************
 *                MainLine
 ***************************************************************/


If (select count(*) from @dbnames) > 0
   begin
	start_dbnames:


	Select @cu11DBName = (select top 1 name from @dbnames order by name)
	Select @cu11DBsid = (select top 1 sid from @dbnames where name = @cu11DBName)
	Select @cu11DBid = (select top 1 dbid from @dbnames where name = @cu11DBName)
	Select @cu11DBcmptlevel = (select top 1 cmptlevel from @dbnames where name = @cu11DBName)


	if DATABASEPROPERTYEX (@cu11DBName,'status') <> 'ONLINE'
	   begin
		goto skip_dbname
	   end


	If @outfiles = 'y'
	   begin
		--  Create the output file
		Select @out_file_name =  '\\' + @save_servername + '\dba_archive\' + @save_servername3 + '_SYSRestore_' + @cu11DBName + '.gsql'
		--Print @out_file_name


		SELECT @sqlcmd = 'sqlcmd -S' + @@servername + ' -dDBAOps -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSrestoreBYsingledb @dbname = ''' + @cu11DBName + '''" -E -o' + @out_file_name
		--Print @sqlcmd
		EXEC @result = master.sys.xp_cmdshell @sqlcmd
	   end
	Else
	   begin
		exec DBAOps.dbo.dbasp_SYSrestoreBYsingledb @dbname = @cu11DBName
	   end


	skip_dbname:


	--  Remove this record from @dbnames and go to the next
	delete from @dbnames where name = @cu11DBName
	If (select count(*) from @dbnames) > 0
	   begin
		goto start_dbnames
	   end


   end


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSrestoreBYdb] TO [public]
GO
