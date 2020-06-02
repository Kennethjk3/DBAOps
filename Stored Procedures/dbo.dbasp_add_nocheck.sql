SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_add_nocheck]  (@nocheck_type sysname = null
					,@detail01 sysname = null
					,@detail02 sysname = null
					,@detail03 sysname = null
					,@detail04 sysname = null
					,@delete_flag char(1) = 'n'
					,@nocheckID int = null
					)


/*********************************************************
 **  Stored Procedure dbasp_add_nocheck
 **  Written by Steve Ledridge, Virtuoso
 **  January 13, 2009
 **
 **  This proc requires the following input parms;
 **
 **  Note: The database name must be a vaild database name
 **        on the local server.
 **
 **  This procedure inserts a row to the DBAOps.dbo.No_Check
 **  table.  This table is accessed by several processes to
 **  determine if anything should be skipped or "not checked".
 ***************************************************************/
  AS
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/13/2009	Steve Ledridge		Revised old process (re-write)
--	03/11/2009	Steve Ledridge		Added DEPL_RD_Skip type.
--	07/13/2009	Steve Ledridge		Added code for login type.
--	08/10/2009	Steve Ledridge		Modified Filescan_noreport example.
--	03/04/2011	Steve Ledridge		Added DEPL_ahp_Skip type.
--	06/06/2011	Steve Ledridge		Added DBowner type.
--	07/05/2011	Steve Ledridge		Added indexmaint type.
--	07/25/2011	Steve Ledridge		Added SQLHealth type.
--	11/09/2011	Steve Ledridge		Added DB users.
--	01/06/2012	Steve Ledridge		Added DEFRAG.
--	01/20/2012	Steve Ledridge		Added LOGSHIP.
--	05/07/2012	Steve Ledridge		Added OSmemory.
--	11/02/2012	Steve Ledridge		Added Cluster, JobOwner.
--	01/31/2013	Steve Ledridge		Added SQLJobHistory.
--	02/27/2013	Steve Ledridge		Added AllDBs to DBowner expample and new JobDBpointer.
--	10/18/2013	Steve Ledridge		Added SQLjob.
--	11/27/2013	Steve Ledridge		Added base_pullsqb.
--	03/30/2015	Steve Ledridge		Added Post_Jobscript.
--	01/20/2017	Steve Ledridge		Added Cluster Node Paused.
--	======================================================================================


/***
declare @nocheck_type sysname
declare @detail01 sysname
declare @detail02 sysname
declare @detail03 sysname
declare @detail04 sysname
declare @delete_flag char(1)
declare @nocheckID int


select @nocheck_type = 'DBowner'
select @detail01 = 'AdminDb'
select @detail02 = 'AdminDb_dbo'
select @detail03 = ''
select @detail04 = ''
select @delete_flag = 'y'
--select @nocheckID = 3
--***/


--  Valid types:  backup, maint, indexmaint, Filescan_noreport, prerestore, Post_Jobscript
--  Valid types:  DEPL_RD_Skip, DEPL_ahp_Skip, login, DBuser, DBowner, LOGSHIP, OSmemory, Cluster, JobOwner, SQLJobHistory
--  Valid types:  JobDBpointer, SQLjob, DBCC_weekly, DBCC_daily


-----------------  declares  ------------------
Declare
	 @miscprint		varchar(500)
	,@cmd			varchar(4000)
	,@error_count		int


----------------  initial values  -------------------
Select @error_count = 0


----------------  Verify Input Parms  -------------------
if @nocheck_type is null
   BEGIN
	Select @error_count = @error_count + 1
	goto label99
   END


if @nocheck_type not in ('DEFRAG','backup', 'maint', 'indexmaint', 'Filescan_noreport', 'prerestore'
			, 'DEPL_RD_Skip', 'DEPL_ahp_Skip', 'Post_Jobscript', 'login', 'DBuser'
			, 'DBowner', 'SQLHealth', 'LOGSHIP', 'OSmemory', 'Cluster', 'JobOwner'
			, 'SQLJobHistory', 'JobDBpointer', 'SQLjob', 'base_pullsqb', 'DBCC_weekly'
			, 'DBCC_daily', 'recovery_model')
   BEGIN
	Select @miscprint = '--DBA WARNING: Invalid input for @nocheck_type.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


If @nocheck_type in ('DEFRAG', 'prerestore') and @delete_flag = 'n' and not exists(select 1 from master.sys.databases where name = @detail01)
   begin
	Select @miscprint = '--DBA WARNING: Database name not found in master.sys.databases.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'backup' and @delete_flag = 'n' and exists(select 1 from DBAOps.dbo.no_check where nocheck_type = 'backup' and detail01 = @detail01)
   begin
	Select @miscprint = '--DBA WARNING: Database name already in DBAOps.dbo.No_Check.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'DEFRAG' and @delete_flag = 'n' and exists(select 1 from DBAOps.dbo.no_check where nocheck_type = 'DEFRAG' and detail01 = @detail01)
   begin
	Select @miscprint = '--DBA WARNING: Database name already in DBAOps.dbo.No_Check.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end

If @nocheck_type = 'DEPL_RD_Skip' and @detail01 <> 'all' and not exists(select 1 from master.sys.databases where name = @detail01)
   begin
	Select @miscprint = '--DBA WARNING: Database name not found in master.sys.databases.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'DEPL_ahp_Skip' and @detail01 <> 'all' and not exists(select 1 from master.sys.databases where name = @detail01)
   begin
	Select @miscprint = '--DBA WARNING: Database name not found in master.sys.databases.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'Post_Jobscript'
  and @detail01 not in ('DBAOps')
  and @detail01 not in (select distinct(RSTRfolder) from dbo.db_ApplCrossRef)
   begin
	Select @miscprint = '--DBA WARNING: @detail01 input invalid for nocheck type ''Post_Jobscript''.  must be ''DBAOps'' or valid baseline folder name.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'LOGSHIP' and @detail01 not in (select name from master.sys.databases)
   begin
	Select @miscprint = '--DBA WARNING: @detail01 input invalid for nocheck type ''LOGSHIP''.  Must be a valid DB within this SQL instance.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'DBowner' and @detail01 not in (select name from master.sys.databases)
   begin
	If @detail01 <> 'AllDBs'
	   begin
		Select @miscprint = '--DBA WARNING: @detail01 input invalid for nocheck type ''DBowner''.  Must be a valid DB within this SQL instance.'
		raiserror(@miscprint,-1,-1) with log
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @nocheck_type = 'DBowner' and @detail02 is null
   begin
	Select @miscprint = '--DBA WARNING: @detail02 input invalid for nocheck type ''DBowner''.  Entry for the DB owner cannot be null.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'Cluster' and @detail01 is null
   begin
	Select @miscprint = '--DBA WARNING: @detail01 input invalid for nocheck type ''Cluster''.  Try ''Node Paused'''
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheck_type = 'base_pullsqb' and @detail01 not in (select name from master.sys.databases)
   begin
	Select @miscprint = '--DBA WARNING: @detail01 input invalid for nocheck type ''base_pullsqb''.  Must be a valid DB within this SQL instance.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


If @nocheckID is not null
   begin
	If not exists (select 1 from DBAOps.dbo.no_check where nocheckid = @nocheckID)
	   begin
		Select @miscprint = '--DBA WARNING: Delete request - row for @nocheckID does not exist. '
		raiserror(@miscprint,-1,-1) with log
		Select @error_count = @error_count + 1
		goto label99
	   end
   end


If @delete_flag not in ('n', 'y')
   begin
	Select @miscprint = '--DBA WARNING: Invalid input for @delete_flag.  Must be ''n'' or ''y''.  '
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   end


----------------  Main Process  -------------------


If @delete_flag = 'y'
   begin
	goto delete_sec
   end


--  Process backup type
If @nocheck_type = 'backup'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('backup', @detail01, getdate(), getdate())


	goto label99
   end


--  Process maint type
If @nocheck_type = 'maint'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('maint', 'skip_check', getdate(), getdate())


	goto label99
   end


--  Process indexmaint type
If @nocheck_type = 'indexmaint'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, detail03, createdate, moddate)
	    VALUES ('indexmaint', @detail01, @detail02, @detail03, getdate(), getdate())


	goto label99
   end


--  Process Filescan_noreport type
If @nocheck_type = 'Filescan_noreport'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, detail03, detail04, createdate, moddate)
	    VALUES ('Filescan_noreport', @detail01, @detail02, @detail03, @detail04, getdate(), getdate())


	goto label99
   end


--  Process prerestore type
If @nocheck_type = 'prerestore'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('prerestore', @detail01, getdate(), getdate())


	goto label99
   end


--  Process DEPL_RD_Skip type
If @nocheck_type = 'DEPL_RD_Skip'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('DEPL_RD_Skip', @detail01, getdate(), getdate())


	goto label99
   end


--  Process DEPL_ahp_Skip type
If @nocheck_type = 'DEPL_ahp_Skip'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('DEPL_ahp_Skip', @detail01, getdate(), getdate())


	goto label99
   end


--  Process Post_Jobscript type
If @nocheck_type = 'Post_Jobscript'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('Post_Jobscript', @detail01, getdate(), getdate())


	goto label99
   end


--  Process login type
If @nocheck_type = 'login'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('login', @detail01, getdate(), getdate())


	goto label99
   end


--  Process login type
If @nocheck_type = 'DBuser'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('DBuser', @detail01, @detail02, getdate(), getdate())


	goto label99
   end


--  Process DBowner type
If @nocheck_type = 'DBowner'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('DBowner', @detail01, @detail02, getdate(), getdate())


	goto label99
   end


--  Process SQLHealth type
If @nocheck_type = 'SQLHealth'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, detail03, createdate, moddate)
	    VALUES ('SQLHealth', @detail01, @detail02, @detail03, getdate(), getdate())


	goto label99
   end


--  Process LOGSHIP type
If @nocheck_type = 'LOGSHIP'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('LOGSHIP', @detail01, '', getdate(), getdate())


	goto label99
   end


--  Process OSmemory type
If @nocheck_type = 'OSmemory'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('OSmemory', @detail01, '', getdate(), getdate())


	goto label99
   end


--  Process Cluster type
If @nocheck_type = 'Cluster'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('Cluster', @detail01, '', getdate(), getdate())


	goto label99
   end


--  Process JobOwner type
If @nocheck_type = 'JobOwner'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('JobOwner', @detail01, '', getdate(), getdate())


	goto label99
   end


--  Process SQLJobJistory type
If @nocheck_type = 'SQLJobHistory'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('SQLJobHistory', '', '', getdate(), getdate())


	goto label99
   end


--  Process JobDBpointer type
If @nocheck_type = 'JobDBpointer'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('JobDBpointer', 'skip_check', getdate(), getdate())


	goto label99
   end


--  Process SQLjob type
If @nocheck_type = 'SQLjob'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('SQLjob', @detail01, getdate(), getdate())


	goto label99
   end


--  Process SQLjob type
If @nocheck_type = 'base_pullsqb'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('base_pullsqb', @detail01, getdate(), getdate())


	goto label99
   end


--  Process DBCC_weekly type
If @nocheck_type = 'DBCC_weekly'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('DBCC_weekly', @detail01, getdate(), getdate())


	goto label99
   end


--  Process DBCC_daily type
If @nocheck_type = 'DBCC_daily'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, createdate, moddate)
	    VALUES ('DBCC_daily', @detail01, getdate(), getdate())


	goto label99
   end


--  Process recovery_model type
If @nocheck_type = 'recovery_model'
   begin
	INSERT INTO DBAOps.dbo.no_check (NoCheck_type, detail01, detail02, createdate, moddate)
	    VALUES ('recovery_model', @detail01, @detail02, getdate(), getdate())


	goto label99
   end


--  Delete Section  ------------------------------------------------------------------
delete_sec:


If @delete_flag <> 'y'
   begin
	goto label99
   end


If @nocheckID is not null
   begin
	If exists (select 1 from DBAOps.dbo.no_check where nocheckid = @nocheckID)
	   begin
		delete from DBAOps.dbo.no_check where nocheckID = @nocheckID
		goto label99
	   end
   end


--  Process backup type delete
If @nocheck_type = 'backup'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'backup' and detail01 = @detail01
	goto label99
   end


--  Process maint type delete
If @nocheck_type = 'maint'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'maint'


	goto label99
   end


--  Process indexmaint type delete
If @nocheck_type = 'indexmaint'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'indexmaint'
					    and detail01 = @detail01
					    and detail02 = @detail02
					    and detail03 = @detail03
	goto label99
   end


--  Process Filescan_noreport type delete
If @nocheck_type = 'Filescan_noreport'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'Filescan_noreport'
					    and detail01 = @detail01
	goto label99
   end


--  Process prerestore type delete
If @nocheck_type = 'prerestore'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'prerestore' and detail01 = @detail01
	goto label99
   end


--  Process DEPL_RD type delete
If @nocheck_type = 'DEPL_RD_Skip'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DEPL_RD_Skip' and detail01 = @detail01
	goto label99
   end


--  Process DEPL_ahp type delete
If @nocheck_type = 'DEPL_ahp_Skip'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DEPL_ahp_Skip' and detail01 = @detail01
	goto label99
   end


--  Process Post_Jobscript type delete
If @nocheck_type = 'Post_Jobscript'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'Post_Jobscript' and detail01 = @detail01
	goto label99
   end


--  Process DBowner type delete
If @nocheck_type = 'DBowner'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DBowner' and detail01 = @detail01 and detail02 = @detail02
	goto label99
   end


--  Process login type delete
If @nocheck_type = 'login'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'login' and detail01 = @detail01
	goto label99
   end


--  Process DBuser type delete
If @nocheck_type = 'DBuser'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DBuser' and detail01 = @detail01 and detail02 = @detail02
	goto label99
   end


--  Process SQLHealth type delete
If @nocheck_type = 'SQLHealth'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'SQLHealth'
					    and detail01 = @detail01
					    and detail02 = @detail02
	goto label99
   end


--  Process LOGSHIP type delete
If @nocheck_type = 'LOGSHIP'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'LOGSHIP' and detail01 = @detail01
	goto label99
   end


--  Process OSmemory type
If @nocheck_type = 'OSmemory'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'OSmemory'
	goto label99
   end


--  Process Cluster type
If @nocheck_type = 'Cluster'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'Cluster'
					    and detail01 = @detail01
	goto label99
   end


--  Process JobOwner type
If @nocheck_type = 'JobOwner'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'JobOwner'
					    and detail01 = @detail01
	goto label99
   end


--  Process SQLJobHistory type
If @nocheck_type = 'SQLJobHistory'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'SQLJobHistory'
					    and detail01 = @detail01
	goto label99
   end


--  Process JobDBpointer type delete
If @nocheck_type = 'JobDBpointer'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'JobDBpointer'


	goto label99
   end


--  Process SQLjob type
If @nocheck_type = 'SQLjob'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'SQLjob'
					    and detail01 = @detail01
	goto label99
   end


--  Process base_pullsqb type
If @nocheck_type = 'base_pullsqb'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'base_pullsqb'
					    and detail01 = @detail01
	goto label99
   end


--  Process DBCC_weekly type
If @nocheck_type = 'DBCC_weekly'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DBCC_weekly'
					    and detail01 = @detail01
	goto label99
   end


--  Process DBCC_daily type
If @nocheck_type = 'DBCC_daily'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'DBCC_daily'
					    and detail01 = @detail01
	goto label99
   end


--  Process recovery_model type
If @nocheck_type = 'recovery_model'
   begin
	delete from DBAOps.dbo.no_check where NoCheck_type = 'recovery_model'
					    and detail01 = @detail01
					    and detail02 = @detail02
	goto label99
   end


--  Finalization  -------------------------------------------------------------------


label99:


If @error_count > 0
   begin
	If @delete_flag is null or @delete_flag = 'n'
	   begin
		Print  ' '
		Select @miscprint = '--Here are sample execute commands for this sproc:'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''DEFRAG''                 -- Backup type'
		Print  @miscprint
		Select @miscprint = '    ,@detail01 = ''wcdswork''                   -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''backup''                 -- Backup type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''wcdswork''                   -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''login''                  -- login type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''sql_test''                   -- Login name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''DBuser''                 -- DBuser type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBname''                     -- DB name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''sql_test''                   -- user name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''maint''                  -- Maint type'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''indexmaint''             -- Index Maint type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBName''                     -- Database Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''schemaName''                 -- Schema Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail03 = ''tableName''                  -- Table Name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''Filescan_noreport''      -- Filescan_noreport type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''%Error: 67015%''             -- Include Text string 1'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''%Severity: 16, State: 1.%''  -- Include Text string 2 (optional)'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail03 = ''%APPL%''                     -- Exclude Text string 1 (optional)'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail04 = ''5''                          -- Threshold number (use "0" to show no rows of this type)'
		Print  @miscprint
		Select @miscprint = '                                                                             -- Note: Rows of this type will be suppressed unless there are more than this number.'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''prerestore''             -- prerestore type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''wcdswork''                   -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''DEPL_RD_Skip''           -- DEPL_RD_Skip type (or DEPL_ahp_Skip)'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''all''                        -- SQL instance will be marked for no automated SQL deployments'
		Print  @miscprint
		Select @miscprint = '                                   --,@detail01 = ''DBname''                   -- DBname instance will be marked for no automated SQL deployments'
		Print  @miscprint
		Select @miscprint = '                                   --,@delete_flag = ''n''                     -- Delete request parm'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''DBowner''                -- Database owner'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''dbname''                     -- Database name (use AllDBs for more than one DB)'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''owner''                      -- Database owner'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''SQLHealth''              -- SQL Health type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''SQLjob''                     -- SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''Job Name''                   -- Job Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail03 = ''# of days between runs''     -- Numeric value'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''recovery_model''         -- recovery_model type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''model''                      -- DBname'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''simple''                     -- recovery model'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''LOGSHIP''                -- Log Shipping'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''dbname''                     -- Database name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''OSmemory''               -- OSmemory'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''6144''                       -- Memory for OS (in MB)'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''Cluster''                -- Cluster'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''Analysis Services''          -- Cluster Resource'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''JobOwner''               -- JobOwner'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''joe_job_owner''              -- JobOwner value'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''SQLjob''                 -- SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''JOBname''                    -- Job name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''Post_Jobscript''         -- Post_Jobscript'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBAOps''                  -- DBAOps or valid baseline folder name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''base_pullsqb''           -- base_pullsqb'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBname''                     -- Job name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''SQLJobHistory''          -- SQLJobHistory'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @nocheck_type = ''JobDBpointer''           -- JobDBpointer type'
		Print  @miscprint
		Print  ' '
		Print  ' '
		Select @miscprint = '--Current Contents of the No_Check Table:'
		Print  @miscprint
		Select nocheckID
		    , convert(char(20), NoCheck_type) as NoCheck_type
		    , convert(char(30), detail01) as Detail01
		    , convert(char(40), detail02) as Detail02
		    , convert(char(20), detail03) as Detail03
		    , convert(char(20), detail04) as Detail04
		    , convert(char(20), addedby) as addedby
		    , createdate
		    , moddate
		    from DBAOps.dbo.No_Check
	   end
	Else
	   begin
		Print  ' '
		Select @miscprint = '--Here are sample execute (delete) commands for this sproc:'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request by row ID'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheckID = 5                           -- Row ID'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for backup'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''backup''                 -- Backup type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''wcdswork''                   -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for maint'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''maint''                  -- Maint type'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for Index Maint'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''indexmaint''             -- Index Maint type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBName''                     -- Database Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''schemaName''                 -- Schema Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail03 = ''tableName''                  -- Table Name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for Filescan_noreport'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''Filescan_noreport''      -- Filescan_noreport type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''%Error: 67015%''             -- Include Text string 1'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for prerestore'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''prerestore''             -- prerestore type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''wcdswork''                   -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for DEPL_RD_Skip'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''DEPL_RD_Skip''           -- DEPL_RD_Skip type (or DEPL_ahp_Skip)'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''all''                        -- DBname or All'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for DBowner'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''DBowner''                -- Database owner'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''dbname''                     -- Database name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''owner''                      -- Database owner'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for SQLHealth'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''SQLHealth''              -- SQLHealth type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''SQLjob''                     -- SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''Job Name''                   -- Job Name'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail03 = ''# of days between runs''     -- Numeric value'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for recovery_model'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''recovery_model''         -- recovery_model type'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''model''                      -- DBname'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail02 = ''simple''                     -- recovery model'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for LOGSHIP'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''LOGSHIP''                -- Log Shipping'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''dbname''                     -- Database name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for OSmemory'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''OSmemory''               -- OSmemory'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for Cluster'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''Cluster''                -- Cluster'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''Analysis Services''          -- Cluster Resource'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for JobOwner'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''JobOwner''               -- JobOwner'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''joe_job_owner''              -- JobOwner value'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''SQLjob''                 -- SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''JOBname''                    -- Job name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for SQLjob'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''Post_Jobscript''         -- Post_Jobscript'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBAOps''               -- DBAOps or a valid baseline folder name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for base_pullsqb'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''base_pullsqb''           -- base_pullsqb'
		Print  @miscprint
		Select @miscprint = '                                   ,@detail01 = ''DBname''                     -- DB name'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete for SQLJobHistory'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''SQLJobHistory''          -- SQLJobHistory'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'exec DBAOps.dbo.dbasp_add_nocheck @delete_flag = ''y''                       -- Delete request for maint'
		Print  @miscprint
		Select @miscprint = '                                   ,@nocheck_type = ''JobDBpointer''           -- JobDBpointer type'
		Print  @miscprint
		Print  ' '
		Print  ' '
		Select @miscprint = '--Current Contents of the No_Check Table:'
		Print  @miscprint
		Select nocheckID
		    , convert(char(20), NoCheck_type) as NoCheck_type
		    , convert(char(30), detail01) as Detail01
		    , convert(char(40), detail02) as Detail02
		    , convert(char(40), detail03) as Detail03
		    , convert(char(40), detail04) as Detail04
		    , convert(char(20), addedby) as addedby
		    , createdate
		    , moddate
		    from DBAOps.dbo.No_Check
	   end
   end
Else
   begin
	Print  ' '
	Select @miscprint = '--Current Contents of the No_Check Table:'
	Print  @miscprint
	Select nocheckID
	    , convert(char(20), NoCheck_type) as NoCheck_type
	    , convert(char(30), detail01) as Detail01
	    , convert(char(40), detail02) as Detail02
	    , convert(char(40), detail03) as Detail03
	    , convert(char(40), detail04) as Detail04
	    , convert(char(20), addedby) as addedby
	    , createdate
	    , moddate
	    from DBAOps.dbo.No_Check
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_add_nocheck] TO [public]
GO
