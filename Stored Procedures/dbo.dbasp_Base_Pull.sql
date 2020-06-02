SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_Pull]


/*********************************************************
 **  Stored Procedure dbasp_Base_Pull
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 6, 2004
 **
 **  This procedure is used to pull baseline backup files
 **  from the central baseline server to the local BASE share.
 **
 **  This proc accepts no input parms at this time.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/06/2008	Steve Ledridge		New process
--	05/12/2008	Steve Ledridge		Change central server for stage domain.
--	07/17/2008	Steve Ledridge		Added skip process if Redgate is not installed.
--	07/23/2008	Steve Ledridge		Fixed raise error issue when skipping process.
--	09/23/2008	Steve Ledridge		Added code for stage and production domains.
--	10/06/2008	Steve Ledridge		Fixed rococopy retry parm.
--	05/13/2009	Steve Ledridge		Converted systeminfo references to DBAOps local tables.
--	07/20/2009	Steve Ledridge		Will now copy BAK files.
--	10/13/2009	Steve Ledridge		Removed the /z parm for robocopy.
--	04/20/2010	Steve Ledridge		Added no_check process for spcific DB's.
--	05/13/2010	Steve Ledridge		Added post file copy check for in-limbo files.
--	06/14/2010	Steve Ledridge		Added back the /z parm for robocopy and added /W:10.
--						Added code for the new BASE share.
--	08/04/2010	Steve Ledridge		Updated gmail address.
--	04/20/2011	Steve Ledridge		New code to support cBAK files.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	02/11/2014	Steve Ledridge		Converted for multi-file processing.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@error_count		int
	,@target_path 		nvarchar(2000)
	,@CopyFrom_path		nvarchar(2000)
	,@charpos		int
	,@parm01		nvarchar(100)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_database_id	int
	,@seq_id		int
	,@save_dbname		sysname
	,@save_companionDB_name	sysname
	,@save_RSTRfolder	sysname
	,@save_baseline_srvname	sysname
	,@Domain		sysname
	,@filemask		sysname


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
create table #baselocation(
		 dbname sysname null
		,RSRTfolder sysname null
		,baselineserver sysname null
		)


--  Verfiy BASE share and get target path
Select @parm01 = @save_servername2 + '_BASE'
exec dbo.dbasp_get_share_path @parm01, @target_path output


if @target_path is null
   BEGIN
	Select @miscprint = 'DBA WARNING: The BASE share is not properly in place.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Review the local databases and get a list of restore folders to process
Select @save_database_id = 4


start_dblist:


Select @save_database_id = (Select top 1 database_id from master.sys.databases where database_id > @save_database_id order by database_id)
Select @save_dbname = (Select name from master.sys.databases where database_id = @save_database_id)


If @save_database_id is not null and @save_database_id > 4
 begin
	Select @seq_id = 0


	get_baselocation:


	If exists (select 1 from dbo.no_check where NoCheck_type = 'base_pullsqb' and Detail01 = @save_dbname)
	   begin
		Select @miscprint = 'DBA Note: Skipping DB ' + @save_dbname + ' due to dbo.no_check table entry'
		Print @miscprint
		goto skipdb
	   end


	Select @seq_id = (select top 1 seq_id from dbo.db_ApplCrossRef where seq_id > @seq_id and db_name = @save_dbname order by seq_id)
	If @seq_id is not null and @seq_id > 0
	   begin
		Select @save_companionDB_name = (select companionDB_name from dbo.db_ApplCrossRef where seq_id = @seq_id)
		If @save_companionDB_name is null or @save_companionDB_name = ''
		   begin
			Select @save_RSTRfolder = (select RSTRfolder from dbo.db_ApplCrossRef where seq_id = @seq_id)
			Select @save_baseline_srvname = (select baseline_srvname from dbo.db_ApplCrossRef where seq_id = @seq_id)
		   end
		Else If exists(select 1 from master.sys.databases where name = rtrim(@save_companionDB_name))
		   begin
			Select @save_RSTRfolder = (select RSTRfolder from dbo.db_ApplCrossRef where seq_id = @seq_id)
			Select @save_baseline_srvname = (select baseline_srvname from dbo.db_ApplCrossRef where seq_id = @seq_id)
		   end
		Else
		   begin
			goto get_baselocation
		   end


		If (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'domain') in ('production', 'stage')
		   begin
			Select @save_baseline_srvname = (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer')
		   end


		If @save_dbname is not null and @save_RSTRfolder is not null and @save_baseline_srvname is not null
		   begin
			insert into #baselocation values(@save_dbname, @save_RSTRfolder, @save_baseline_srvname)
		   end


	   end


	skipdb:


	If exists(select 1 from master.sys.databases where database_id > @save_database_id)
	   begin
		goto start_dblist
	   end
   end


--  Robocopy all backup files files from the central baseline server to the BASE share
If (select count(*) from #baselocation) > 0
   begin
	start_copy:


	Select @save_RSTRfolder = (Select top 1 RSRTfolder from #baselocation)
	Select @save_dbname = (Select top 1 dbname from #baselocation where RSRTfolder = @save_RSTRfolder)
	Select @save_baseline_srvname = (select top 1 baselineserver from #baselocation where RSRTfolder = @save_RSTRfolder)

	If (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain') = 'STAGE'
	   begin
		Select @save_baseline_srvname = (select env_detail from dbo.Local_ServerEnviro where env_type = 'CentralServer')
	   end


	Select @Domain = (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'domain')
	Select @CopyFrom_path = '\\' + rtrim(@save_baseline_srvname) + '\' + rtrim(@save_baseline_srvname) + '_BASE_' + rtrim(@save_RSTRfolder) + '\'
	Select @filemask = @save_dbname + '_prod*'


	Print '--  Starting file copy from ' + @CopyFrom_path + ' to ' + @target_path + ' for file mask ' + @filemask
	raiserror('', -1,-1) with nowait
	exec DBAOps.dbo.dbasp_File_mover @Remote_server = @save_baseline_srvname
					,@Remote_Domain = @Domain
					,@CopyFrom_path = @CopyFrom_path
					,@CopyTo_path =  @target_path
					,@filemask = @filemask
					,@pre_delete_target = 'n'


	delete from #baselocation where RSRTfolder = @save_RSTRfolder and dbname = @save_dbname
	If (select count(*) from #baselocation) > 0
	   begin
		goto start_copy
	   end
   end


--  Finalization  -------------------------------------------------------------------
label99:


drop table #baselocation


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
GRANT EXECUTE ON  [dbo].[dbasp_Base_Pull] TO [public]
GO
