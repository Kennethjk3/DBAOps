SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_cleanup]


/*********************************************************
 **  Stored Procedure dbasp_Base_cleanup
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 13, 2010
 **
 **  This procedure is used to clear out the local BASE share
 **  in preperation for new baseline files.
 **
 **  This proc accepts no input parms at this time.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	05/13/2008	Steve Ledridge		New process
--	08/04/2010	Steve Ledridge		Updated gmail address.
--	01/04/2010	Steve Ledridge		Added delete for 'file not found' from temp table.
--	04/20/2011	Steve Ledridge		Minor message change to support cBAK files.
--	06/21/2011	Steve Ledridge		Bypass if no DEPL related DB's exist.
--	04/27/2012	Steve Ledridge		Added builds folder cleanup (90 days)
--	02/11/2014	Steve Ledridge		Removed code for NXT files.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_dbname		sysname
	,@save_builds_path	sysname
	,@save_base_path	sysname
	,@save_path1		sysname
	,@outpath 		varchar(255)


----------------  initial values  -------------------
Select @error_count = 0
Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Create temp tables
create table #Dbnames(dbname sysname null)


--  Check for local DB's that are part of the deployment process
If not exists (select 1 from master.sys.databases as s join DBAOps.dbo.db_sequence c on s.name = c.db_name)
   begin
	goto label99
   end


If not exists (select 1 from dbo.dba_dbinfo where DEPLstatus = 'y')
   begin
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--------------------------------
--  BASE share cleanup section
--------------------------------


Select @save_base_path = @save_servername2 + '_base'


exec dbo.dbasp_get_share_path @save_base_path, @outpath output


Select @save_path1 = @outpath
exec DBAOps.dbo.dbasp_FileCleanup @targetpath = @save_path1
					,@retention = 8
					,@process = 'Delete'
					,@filesonly = 'y'
					,@force_delete = 'y'


--------------------------------
--  Build share cleanup section
--------------------------------
Select @save_builds_path = (select env_detail from local_serverenviro where env_type = 'builds_path')
Select @save_path1 = @save_builds_path + '\deployment_logs'
exec DBAOps.dbo.dbasp_FileCleanup @targetpath = @save_path1
					,@retention = 90
					,@process = 'Delete'
					,@filesonly = 'y'
					,@force_delete = 'y'


Select @save_path1 = @save_builds_path + '\DataMigration'
exec DBAOps.dbo.dbasp_FileCleanup @targetpath = @save_path1
					,@retention = 60
					,@process = 'Delete'
					,@filesonly = 'y'
					,@force_delete = 'y'


--  folders only
Select @save_path1 = @save_builds_path
exec DBAOps.dbo.dbasp_FileCleanup @targetpath = @save_path1
					,@retention = 30
					,@process = 'Delete'
					,@filesonly = 'x'
					,@force_delete = 'y'


--  Finalization  -------------------------------------------------------------------
label99:


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
GRANT EXECUTE ON  [dbo].[dbasp_Base_cleanup] TO [public]
GO
