SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_depl_ScriptServerList] (@forServermask sysname = null)


/***************************************************************
 **  Stored Procedure dbasp_depl_ScriptServerList
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 13, 2005
 **
 **  This procedure creates a file that is used to populate the
 **  dba_dbinfo table.  This table is maintained on the DBA
 **  central server and is used by the deployment baseline servers.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	10/13/2005	Steve Ledridge		New process
--	01/10/2005	Steve Ledridge		Convert active to nvarchar(10)
--	05/15/2006	Steve Ledridge		Updated for SQL 2005
--	06/04/2007	Steve Ledridge		Added ENVnum column.
--	06/20/2005	Steve Ledridge		New columns in depl_server_db_list
--	06/21/2005	Steve Ledridge		New output for insert and update. Remove delete from output.
--	02/13/2008	Steve Ledridge		Added delete to start of output script.
--	08/22/2008	Steve Ledridge		New table dba_dbinfo.
--	10/09/2009	Steve Ledridge		Added code for DB DEPLinfo.
--	03/12/2010	Steve Ledridge		New code for active = 'm'.
--	03/13/2013	Steve Ledridge		Changed DBname systeminfo to DBAOps.
--	04/29/2013	Steve Ledridge		Removed DEPLinfo.
--	09/16/2013	Steve Ledridge		Added code for SQLenv = local.
--	======================================================================================


/***
Declare @forServermask sysname


--Select @forServermask = 'DBAOpser03'
--***/


Declare
	 @miscprint			nvarchar(4000)
	,@save_servername		sysname


DECLARE
	 @cu11Parent_name		sysname
	,@cu11App_name			sysname
	,@cu11SQLname			sysname
	,@cu11ENVname			sysname
	,@cu11ENVnum			sysname
	,@cu11BaselineFolder		sysname
	,@cu11DBname			sysname
	,@cu11Active			nvarchar(10)
	,@cu11push_to_nxt		nchar(1)
	,@cu11BaselineServerName	sysname
	,@cu11moddate   		datetime


----------------  initial values  -------------------


If @forServermask is not null and @forServermask <> ''
   begin
    Select @save_servername = @forServermask
    Select @forServermask = @forServermask + '%'
   end
Else
   begin
    Select @save_servername = @@servername
   end


--  Create table variable
declare @servernames table (SQLName sysname
			    ,DBName sysname
			    ,ENVname sysname
			    ,ENVnum sysname
			    ,BaselineFolder sysname
			    ,BaselineServername sysname
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Script DATA for Table ''DBA_DBinfo'' Process'
Print  @miscprint
Select @miscprint = 'Created From Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint


If @forServermask is not null and @forServermask <> ''
   begin
	Select @miscprint = 'Created For Server: ' + @save_servername
	Print  @miscprint
   end


Print  '************************************************************************/'
Print  ' '
Select @miscprint = 'Use DBAOps'
Print @miscprint
Print 'go'
Print ' '


--  Capture data from the DBA_DBinfo table
If @forServermask is null or @forServermask = ''
   begin
    insert @servernames select d.SQLName, d.DBName, d.ENVname, d.ENVnum, d.BaselineFolder, d.BaselineServername
			From dbo.DBA_DBinfo d, DBA_Serverinfo s
			where s.SQLname = d.SQLname
			  and d.DBName not in ('DBAOps', 'DBAOps')
			  and s.active in ('y', 'm')
			  and s.SQLenv <> 'local'
			  and d.BaselineServername is not null
			  and d.BaselineServername <> ''
   end
Else
   begin
    insert @servernames select d.SQLName, d.DBName, d.ENVname, d.ENVnum, d.BaselineFolder, d.BaselineServername
			From dbo.DBA_DBinfo d, DBA_Serverinfo s
			where s.SQLname = d.SQLname
			  and d.DBName not in ('DBAOps', 'DBAOps')
			  and s.active in ('y', 'm')
			  and s.SQLenv <> 'local'
			  and d.BaselineServername like @forServermask
   end


--select * from @servernames


If (select count(*) from @servernames) > 0
   begin
	start_output:


	Select @cu11SQLName = (select top 1 SQLName from @servernames order by SQLName)
	Select @cu11BaselineFolder = (select top 1 BaselineFolder from @servernames where SQLName = @cu11SQLname)
	Select @cu11DBname = (select top 1 DBname from @servernames where SQLName = @cu11SQLname and BaselineFolder = @cu11BaselineFolder)
	Select @cu11ENVname = (select ENVname from @servernames where SQLName = @cu11SQLname and BaselineFolder = @cu11BaselineFolder and DBname = @cu11DBname)
	Select @cu11ENVnum = (select ENVnum from @servernames where SQLName = @cu11SQLname and BaselineFolder = @cu11BaselineFolder and DBname = @cu11DBname)
	Select @cu11BaselineServerName = (select BaselineServerName from @servernames where SQLName = @cu11SQLname and BaselineFolder = @cu11BaselineFolder and DBname = @cu11DBname)

	Select @miscprint = 'If not exists (select 1 from dbo.DBA_DBinfo where SQLName = ''' + @cu11SQLname + ''' and DBname = ''' + @cu11DBname + ''')' + char(13)+char(10)
	Select @miscprint = @miscprint + '   begin' + char(13)+char(10)
	Select @miscprint = @miscprint + '      Insert into dbo.DBA_DBinfo (SQLName, DBName, ENVname, ENVnum, BaselineFolder, BaselineServername)' + char(13)+char(10)
	Select @miscprint = @miscprint + '      values (''' + @cu11SQLName + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '              ''' + @cu11DBname + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '              ''' + @cu11ENVname + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '              ''' + @cu11ENVnum + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '              ''' + @cu11BaselineFolder + ''',' + char(13)+char(10)
	Select @miscprint = @miscprint + '              ''' + @cu11BaselineServerName + ''')' + char(13)+char(10)
	Select @miscprint = @miscprint + '   end' + char(13)+char(10)


	Print @miscprint
	Print 'go'
	Print ' '


	--  Remove this record from @servernames and go to the next
	delete from @servernames where SQLname = @cu11SQLname and BaselineFolder = @cu11BaselineFolder and DBname = @cu11DBname
	If (select count(*) from @servernames) > 0
	   begin
		goto start_output
	   end
   end


-----------------------------------------------------------------------------------------------------------------
--  Finalization  -----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------


label99:


Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Script DATA for Table ''DBA_DBinfo'' Process Complete'
Print  @miscprint
Print  '************************************************************************/'
GO
GRANT EXECUTE ON  [dbo].[dbasp_depl_ScriptServerList] TO [public]
GO
