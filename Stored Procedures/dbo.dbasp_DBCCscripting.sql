SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_DBCCscripting] (@DBname sysname = null,
				@PlanName sysname = null,
				@Process_mode sysname = null,
				@ARITHABORT_ON char(1) = 'n',
				@QUOTED_ID_ON char(1) = 'n')

/***************************************************************
 **  Stored Procedure dbasp_DBCCscripting
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 03, 2004
 **
 **  This procedure is used for various
 **  DBCC processing.
 **
 **  This proc accepts five input parms:
 **
 **  Either @dbname or @planname is required.
 **
 **  - @dbname is the name of the database to be processed.
 **    use 'ALL_USER_DBs' to process all user databases
 **    use 'ALL_SYS_DBs' to process all system databases
 **    use 'ALL_DBs' to process all databases
 **
 **  - @planname is the maintenance plan that is used to determine
 **    which database to process.
 **
 **  - @Process_mode must be 'weekly' or 'daily'. (Required)
 **
 **  - @ARITHABORT_ON is an optional parm to have this attribute set
 **    to on prior to running the DBCC command.
 **
 **  - @QUOTED_ID_ON is an optional parm to have this attribute set
 **    to on prior to running the DBCC command.
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/04/2004	Steve Ledridge		New DBCC process
--	08/11/2004	Steve Ledridge		Minor fix to maintenance plan processing
--	02/16/2006	Steve Ledridge		Modified for sql 2005
--	04/15/2010	Steve Ledridge		Change daily to checkalloc and checkcatalog only.
--						Added with physical_only to weekly checkdb.
--	03/20/2015	Steve Ledridge		Skip very large DB's for CheckDB.
--	01/13/2016	Steve Ledridge		New code to check for AvailGrp DBs.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================


/***
Declare @DBname sysname
Declare @PlanName sysname
Declare @Process_mode sysname
Declare @ARITHABORT_ON char(1)
Declare @QUOTED_ID_ON char(1)


--Select @DBname = 'DBAOps'
--Select @DBname = 'ALL_USER_DBs'
--Select @DBname = 'ALL_SYS_DBs'
--Select @DBname = 'ALL_DBs'
Select @PlanName = 'Mplan_user_all'
--Select @Process_mode = 'daily'
Select @Process_mode = 'weekly'
--Select @ARITHABORT_ON = 'y'
--Select @QUOTED_ID_ON = 'y'
--***/


DECLARE
	 @miscprint		varchar(500)
	,@cmd			nvarchar(4000)
	,@date 			char(14)
	,@Month  		varchar(4)
	,@Day  			varchar(4)
	,@year 			varchar(4)
	,@Hold_hhmmss		varchar(8)
	,@outpath 		varchar(255)
	,@error_count		int
	,@parm01		varchar(100)
	,@save_DBname		sysname
	,@save_backupname	sysname
	,@save_servername	sysname
	,@save_servername2	sysname
	,@cursor_text		varchar(500)
	,@charpos		int
	,@plan_flag		char(1)
	,@oneDB_flag		char(1)
	,@userDB_flag		char(1)
	,@sysDB_flag		char(1)
	,@allDB_flag		char(1)
	,@availgrp_flag		char(1)
	,@a			int
	,@save_productversion	sysname


DECLARE
	 @cu10DBName		sysname


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId		smallint
	,@cu11DBStatus		int


DECLARE
	 @cu12DBName		sysname
	,@cu12DBId		smallint
	,@cu12DBStatus		int


DECLARE
	 @cu13DBName		sysname
	,@cu13DBId		smallint
	,@cu13DBStatus		int


----------------  initial values  -------------------
Select @error_count = 0
Select @save_DBname = ''
Select @plan_flag = 'n'
Select @oneDB_flag = 'n'
Select @userDB_flag = 'n'
Select @sysDB_flag = 'n'
Select @allDB_flag = 'n'
Select @availgrp_flag = 'n'


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
BEGIN
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
END


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @date = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2) + substring(@Hold_hhmmss, 7, 2)


declare @DBnames table	(name		sysname)


--  Check for availability groups
IF @@microsoftversion / 0x01000000 >= 11
  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	Select @availgrp_flag = 'y'
   END


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'DBCC Processing for Standard Maintenance'
Print  @miscprint
Select @miscprint = 'Script Created For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'
Print  ' '


--  Check input parameters and determine backup process
If @Process_mode not in ('weekly', 'daily')
BEGIN
	Print '-- DBA Warning:  Invalid input parameter for @Process_mode.'
	Select @error_count = @error_count + 1
	Goto label99
END


If nullif(@PlanName,'') IS NOT NULL
BEGIN
	IF @PlanName NOT IN ('SIMPLE','FULL','BULK_LOGGED','ALL','SYSTEMDBS','USERDBS')
   BEGIN
		Print 'DBA WARNING: Invaild parameter passed to dbasp_backup - @PlanName parm is invalid'
		Select @error_count = @error_count + 1
		Goto label99
	END


	RAISERROR('Process mode: Maintenance plan = %s',-1,-1,@PlanName) WITH NOWAIT
END
ELSE IF NULLIF(@DBname,'') IS NOT NULL
BEGIN
	If not exists(select 1 from master.sys.sysdatabases where name = @DBname)
	BEGIN
		Print 'DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
		Select @error_count = @error_count + 1
		Goto label99
	END

	RAISERROR('Process mode: Single DB = %s',-1,-1,@DBname) WITH NOWAIT
END
ELSE
BEGIN
	Print 'DBA Warning:  Invalid input parameter.  @DBname or @PlanName must be specified'
	Select @error_count = @error_count + 1
	Goto label99
END


--If @PlanName is not null and @PlanName <> ''
--   begin
--	If not exists (select * from msdb.dbo.sysdbmaintplans Where plan_name = @PlanName)
--	   begin
--		Print '-- DBA WARNING: Invaild parameter passed to dbasp_DBCCscripting - @PlanName parm is invalid'
--		Select @error_count = @error_count + 1
--		Goto label99
--	   end
--	Else
--	   begin
--		If exists (select *
--			From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
--			Where d.plan_id = s.plan_id
--			and s.plan_name = @PlanName
--			and d.database_name = 'All User Databases')
--		   begin
--			Print '-- Process mode is for all User DBs using Maintenance plan [' + @PlanName + ']'
--			Select @userDB_flag = 'y'
--			goto label05
--		   end


--		If exists (select *
--			From msdb.dbo.sysdbmaintplan_databases  d, msdb.dbo.sysdbmaintplans  s
--			Where d.plan_id = s.plan_id
--			and s.plan_name = @PlanName
--			and d.database_name = 'All System Databases')
--		   begin
--			Print '-- Process mode is for all System DBs using Maintenance plan [' + @PlanName + ']'
--			Select @sysDB_flag = 'y'
--			goto label05
--		   end


--		Print '-- Process mode is from Maintenance plan [' + @PlanName + ']'
--		Select @plan_flag = 'y'
--		goto label05
--	   end
--   end


--If @DBname is not null
--   begin
--	If @DBname = 'ALL_USER_DBs'
--	   begin
--		Print '-- Process mode is for all User DBs.'
--		Select @userDB_flag = 'y'
--		goto label05
--	   end
--	Else If @DBname = 'ALL_SYS_DBs'
--	   begin
--		Print '-- Process mode is for all System DBs.'
--		Select @sysDB_flag = 'y'
--		goto label05
--	   end
--	Else If @DBname = 'ALL_DBs'
--	   begin
--		Print '-- Process mode is for all DBs.'
--		Select @allDB_flag = 'y'
--		goto label05
--	   end
--	Else
--	   begin
--		If not exists(select 1 from master.sys.sysdatabases where name = @DBname)
--		   begin
--			Print '-- DBA Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
--			Select @error_count = @error_count + 1
--			Goto label99
--		   end
--		Else
--		   begin
--			Print '-- Process mode is for a single DB - ' + @DBname
--			Select @oneDB_flag = 'y'
--			goto label05
--		   end
--	   end
--   end


--If @DBname is null and @PlanName is null
--   begin
--	Print '-- DBA Warning:  Invalid input parameter.  @DBname or @PlanName must be specified'
--	Select @error_count = @error_count + 1
--	Goto label99
--   end


--  DBCC process has been determined at this point
label05:


Print ' '
Select @miscprint = 'Set nocount on'
Print  @miscprint
Select @miscprint = 'go'
Print  @miscprint
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/
	delete from @DBnames


	If NULLIF(@PlanName,'') is not null
	BEGIN
		IF @PlanName IN ('SIMPLE','FULL','BULK_LOGGED')
			INSERT INTO	@DBnames
			SELECT		name
			FROM		sys.databases
			WHERE		state_desc = 'ONLINE'
				AND		recovery_model_desc = @PlanName

		IF @PlanName = 'ALL'
			INSERT INTO	@DBnames
			SELECT		name
			FROM		sys.databases
			WHERE		state_desc = 'ONLINE'

		IF @PlanName = 'USERDBS'
			INSERT INTO	@DBnames
			SELECT		name
			FROM		sys.databases
			WHERE		state_desc = 'ONLINE'
				AND		database_id > 4


		IF @PlanName = 'SYSTEMDBS'
			INSERT INTO	@DBnames
			SELECT		name
			FROM		sys.databases
			WHERE		state_desc = 'ONLINE'
				AND		database_id <= 4
	END
	ELSE
		INSERT INTO @DBnames (name) values(@DBname)

	--select * from @DBnames


	If (select count(*) from @DBnames) = 0
	BEGIN
		Print 'DBA Error:  No databases selected for DBCC.'
		select * from @DBnames
		Select @error_count = @error_count + 1
		Goto label99
	END


start_dbnames:


		Select @cu10DBName = (select top 1 name from @DBnames order by name)


		If @availgrp_flag = 'y'
		BEGIN
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			--			CHECK IF DATABASE IS PRIMARY REPLICA
			---------------------------------------------------------------------------------------------------------
			---------------------------------------------------------------------------------------------------------
			SET @a = 0
			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS

			-- ONLY VALID IN SQL 2014
			--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @cu10DBName  + ''')'


			Select @cmd = 'SELECT		@a = ars.role
					FROM		sys.dm_hadr_availability_replica_states ars
					INNER JOIN	sys.databases dbs
						ON	ars.replica_id = dbs.replica_id
					WHERE		dbs.name = ''' + @cu10DBName  + ''';
					SET	@a	= COALESCE(@a,1);'


			--Print @cmd
			--Print ''
			EXEC sp_executesql @cmd, N'@a int output', @a output


			IF @a = 0
				raiserror('--  DBA Note: DB %s is NOT part of the Availability Group.', -1,-1,@cu10DBName) with nowait
			ELSE IF @a = 1
				raiserror('--  DBA Note: DB %s is the Primary Replica in the Availability Group.', -1,-1,@cu10DBName) with nowait
			ELSE
			BEGIN
				raiserror('--  DBA Note: Skipping DB %s as it is not the Primary Replica in the Availability Group.', -1,-1,@cu10DBName) with nowait
				goto skip_MaintenanceplanDB
			END
		END


		If @save_DBname <> @cu10DBName
		begin
			Print ' '
			Print '--  Start ' + @Process_mode + ' DBCC processing for database [' + @cu10DBName + ']'
			Select @miscprint = 'Use ' + @cu10DBName
			Print @miscprint
			Print 'go'
			Print ' '


			Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + @cu10DBName + ']'''
			Print @miscprint
			Print 'Select getdate()'
			Print 'go'
			Print ' '


			Select @save_DBname = @cu10DBName
		END


		If @Process_mode = 'weekly'
		   begin
			If @ARITHABORT_ON = 'y'
			   begin
				Select @cmd = 'SET ARITHABORT ON'
				Print @cmd
			   end
			If @QUOTED_ID_ON = 'y'
			   begin
				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
				Print @cmd
			   end


			--  Note: Do not run DBCC Check DB locally if the DB is very large
			If (select sum((size*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @cu10DBName and type <> 1) < 999999
			   begin
				Select @cmd = 'DBCC CHECKDB (''' + rtrim(@cu10DBName) + ''') with physical_only'
				Print @cmd
				Print  'go'
				Print  ' '
			   end
			Else
			   begin
				Print '--  Very Large DB - DBCC CheckDB is being skipped.'
				Print  ' '
				Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu10DBName) + ''')'
				Print @cmd
				Print  'go'
				Print  ' '

				Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu10DBName) + ''')'
				Print @cmd
				Print  'go'
				Print  ' '
			   end
		   end
		Else If @Process_mode = 'daily'
		   begin
			If @ARITHABORT_ON = 'y'
			   begin
				Select @cmd = 'SET ARITHABORT ON'
				Print @cmd
			   end
			If @QUOTED_ID_ON = 'y'
			   begin
				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
				Print @cmd
			   end
			Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu10DBName) + ''')'
			Print @cmd
			Print  'go'
			Print  ' '

			Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu10DBName) + ''')'
			Print @cmd
			Print  'go'
			Print  ' '
		   end


skip_MaintenanceplanDB:


		--  check for more rows to process
		Delete from @DBnames where name = @cu10DBName
		If (select count(*) from @DBnames) > 0
		BEGIN
			goto start_dbnames
		END


----  Process a single DB
--Else If @oneDB_flag = 'y'
--   begin


--	If @save_DBname <> @DBname
--	   begin
--		Print ' '
--		Select @miscprint = 'Use ' + @DBname
--		Print @miscprint
--		Print 'go'
--		Print ' '


--		Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + @DBname + ']'''
--		Print @miscprint
--		Print 'Select getdate()'
--		Print 'go'
--		Print ' '


--		Select @save_DBname = @DBname
--	   end


--	If @availgrp_flag = 'y'
--	   begin
--		---------------------------------------------------------------------------------------------------------
--		---------------------------------------------------------------------------------------------------------
--		--			CHECK IF DATABASE IS PRIMARY REPLICA
--		---------------------------------------------------------------------------------------------------------
--		---------------------------------------------------------------------------------------------------------
--		SET @a = 0
--		-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS

--		-- ONLY VALID IN SQL 2014
--		--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @save_DBname   + ''')'


--		Select @cmd = 'SELECT		@a = ars.role
--				FROM		sys.dm_hadr_availability_replica_states ars
--				INNER JOIN	sys.databases dbs
--					ON	ars.replica_id = dbs.replica_id
--				WHERE		dbs.name = ''' + @save_DBname   + ''';
--				SET	@a	= COALESCE(@a,1);'


--		--Print @cmd
--		--Print ''
--		EXEC sp_executesql @cmd, N'@a int output', @a output


--		IF @a = 0
--		   BEGIN
--			--print @save_DBname
--			raiserror('--  DBA Note: DB %s is NOT part of the Availability Group.', -1,-1,@save_DBname ) with nowait
--		   END
--		ELSE IF @a = 1
--		   BEGIN
--			--print @save_DBname
--			raiserror('--  DBA Note: DB %s is the Primary Replica in the Availability Group.', -1,-1,@save_DBname ) with nowait
--		   END
--		ELSE
--		   BEGIN
--			--print @save_DBname
--			raiserror('--  DBA Note: Skipping DB %s as it is not the Primary Replica in the Availability Group.', -1,-1,@save_DBname ) with nowait
--			goto skip_singleDB
--		   END
--	   END


--	Print  ' '
--	Select @miscprint = '-- DBCC PROCESS for database [' + (rtrim(@DBname)) + ']'
--	Print  @miscprint
--	Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + rtrim(@DBname) + ']'''
--	Print @miscprint
--	Print 'Select getdate()'


--	If @Process_mode = 'weekly'
--	   begin
--		If @ARITHABORT_ON = 'y'
--		   begin
--			Select @cmd = 'SET ARITHABORT ON'
--			Print @cmd
--		   end
--		If @QUOTED_ID_ON = 'y'
--		   begin
--			Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--			Print @cmd
--		   end


--		If (select sum((size*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @DBname and type <> 1) < 999999
--		   begin
--			Select @cmd = 'DBCC CHECKDB (''' + rtrim(@DBname) + ''') with physical_only'
--			Print @cmd
--			Print  'go'
--			Print  ' '
--		   end
--		Else
--		   begin
--			Print '--  Very Large DB - DBCC CheckDB is being skipped.'
--			Print  ' '
--			Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@DBname) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '

--			Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@DBname) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '
--		   end
--	   end
--	Else If @Process_mode = 'daily'
--	   begin
--		If @ARITHABORT_ON = 'y'
--		   begin
--			Select @cmd = 'SET ARITHABORT ON'
--			Print @cmd
--		   end
--		If @QUOTED_ID_ON = 'y'
--		   begin
--			Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--			Print @cmd
--		   end

--		Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@DBname) + ''')'
--		Print @cmd
--		Print  'go'
--		Print  ' '

--		Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@DBname) + ''')'
--		Print @cmd
--		Print  'go'
--		Print  ' '


--	   end


--	skip_singleDB:


--   end
----  Process all user DBs
--Else If @userDB_flag = 'y'
--   begin


--	Select @cmd = 'SELECT d.name
--	   From master.sys.sysdatabases   d ' +
--	  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


--	delete from @DBnames


--	insert into @DBnames (name) exec (@cmd)


--	delete from @DBnames where name is null or name = ''


--	If @Process_mode = 'weekly'
--	   begin
--		delete from @DBnames where name in (select detail01 from dbo.no_check where nocheck_type = 'DBCC_weekly')
--	   end
--	Else If @Process_mode = 'daily'
--	   begin
--		delete from @DBnames where name in (select detail01 from dbo.no_check where nocheck_type = 'DBCC_daily')
--	   end


--	--select * from @DBnames


--	If (select count(*) from @DBnames) > 0
--	   begin
--		start_dbnames11:


--		Select @cu11DBName = (select top 1 name from @DBnames order by name)


--		If @availgrp_flag = 'y'
--		   begin
--			---------------------------------------------------------------------------------------------------------
--			---------------------------------------------------------------------------------------------------------
--			--			CHECK IF DATABASE IS PRIMARY REPLICA
--			---------------------------------------------------------------------------------------------------------
--			---------------------------------------------------------------------------------------------------------
--			SET @a = 0
--			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS

--			-- ONLY VALID IN SQL 2014
--			--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @cu11DBName  + ''')'


--			Select @cmd = 'SELECT		@a = ars.role
--					FROM		sys.dm_hadr_availability_replica_states ars
--					INNER JOIN	sys.databases dbs
--						ON	ars.replica_id = dbs.replica_id
--					WHERE		dbs.name = ''' + @cu11DBName  + ''';
--					SET	@a	= COALESCE(@a,1);'


--			--Print @cmd
--			--Print ''
--			EXEC sp_executesql @cmd, N'@a int output', @a output


--			IF @a = 0
--			   BEGIN
--				--print @cu11DBName
--				raiserror('--  DBA Note: DB %s is NOT part of the Availability Group.', -1,-1,@cu11DBName) with nowait
--			   END
--			ELSE IF @a = 1
--			   BEGIN
--				--print @cu11DBName
--				raiserror('--  DBA Note: DB %s is the Primary Replica in the Availability Group.', -1,-1,@cu11DBName) with nowait
--			   END
--			ELSE
--			   BEGIN
--				--print @cu11DBName
--				raiserror('--  DBA Note: Skipping DB %s as it is not the Primary Replica in the Availability Group.', -1,-1,@cu11DBName) with nowait
--				goto skip_alluserDBs
--			   END
--		   END


--		If @save_DBname <> @cu11DBName
--		   begin
--			Print ' '
--			Select @miscprint = 'Use ' + @cu11DBName
--			Print @miscprint
--			Print 'go'
--			Print ' '


--			Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + @cu11DBName + ']'''
--			Print @miscprint
--			Print 'Select getdate()'
--			Print 'go'
--			Print ' '


--			Select @save_DBname = @cu11DBName
--		   end


--		Print  ' '
--		Select @miscprint = '-- DBCC PROCESS for database [' + (rtrim(@cu11DBName)) + ']'
--		Print  @miscprint
--		Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + rtrim(@cu11DBName) + ']'''
--		Print @miscprint
--		Print 'Select getdate()'


--		If @Process_mode = 'weekly'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end
--			If (select sum((size*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @cu11DBName and type <> 1) < 999999
--			   begin
--				Select @cmd = 'DBCC CHECKDB (''' + rtrim(@cu11DBName) + ''') with physical_only'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--			Else
--			   begin
--				Print '--  Very Large DB - DBCC CheckDB is being skipped.'
--				Print  ' '
--				Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu11DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '

--				Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu11DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--		   end
--		Else If @Process_mode = 'daily'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end

--			Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu11DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '

--			Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu11DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '
--		   end


--		skip_alluserDBs:


--		--  check for more rows to process
--		Delete from @DBnames where name = @cu11DBName
--		If (select count(*) from @DBnames) > 0
--		   begin
--			goto start_dbnames11
--		   end


--	   end


--   end
----  Process all system DBs
--Else If @sysDB_flag = 'y'
--   begin


--	Select @cmd = 'SELECT d.name
--	   From master.sys.sysdatabases   d ' +
--	  'Where d.name in (''master'', ''model'', ''msdb'')'


--	delete from @DBnames


--	insert into @DBnames (name) exec (@cmd)


--	delete from @DBnames where name is null or name = ''
--	--select * from @DBnames


--	If (select count(*) from @DBnames) > 0
--	   begin
--		start_dbnames12:


--		Select @cu12DBName = (select top 1 name from @DBnames order by name)


--		If @save_DBname <> @cu12DBName
--		   begin
--			Print ' '
--			Select @miscprint = 'Use ' + @cu12DBName
--			Print @miscprint
--			Print 'go'
--			Print ' '


--			Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + @cu12DBName + ']'''
--			Print @miscprint
--			Print 'Select getdate()'
--			Print 'go'
--			Print ' '


--			Select @save_DBname = @cu12DBName
--		   end


--		Print  ' '
--		Select @miscprint = '-- DBCC PROCESS for database [' + (rtrim(@cu12DBName)) + ']'
--		Print  @miscprint
--		Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + rtrim(@cu12DBName) + ']'''
--		Print @miscprint
--		Print 'Select getdate()'


--		If @Process_mode = 'weekly'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end
--			If (select sum((size*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @cu12DBName and type <> 1) < 999999
--			   begin
--				Select @cmd = 'DBCC CHECKDB (''' + rtrim(@cu12DBName) + ''') with physical_only'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--			Else
--			   begin
--				Print '--  Very Large DB - DBCC CheckDB is being skipped.'
--				Print  ' '
--				Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu12DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '

--				Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu12DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--		   end
--		Else If @Process_mode = 'daily'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end

--			Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu12DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '

--			Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu12DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '
--		   end


--		--  check for more rows to process
--		Delete from @DBnames where name = @cu12DBName
--		If (select count(*) from @DBnames) > 0
--		   begin
--			goto start_dbnames12
--		   end


--	   end


--   end
----  Process all DBs
--Else If @allDB_flag = 'y'
--   begin


--	Select @cmd = 'SELECT d.name
--	   From master.sys.sysdatabases   d ' +
--	  'Where d.name not in (''tempdb'')'


--	delete from @DBnames


--	insert into @DBnames (name) exec (@cmd)


--	delete from @DBnames where name is null or name = ''


--	If @Process_mode = 'weekly'
--	   begin
--		delete from @DBnames where name in (select detail01 from dbo.no_check where nocheck_type = 'DBCC_weekly')
--	   end
--	Else If @Process_mode = 'daily'
--	   begin
--		delete from @DBnames where name in (select detail01 from dbo.no_check where nocheck_type = 'DBCC_daily')
--	   end


--	--select * from @DBnames


--	If (select count(*) from @DBnames) > 0
--	   begin
--		start_dbnames13:


--		Select @cu13DBName = (select top 1 name from @DBnames order by name)


--		If @availgrp_flag = 'y'
--		   begin
--			---------------------------------------------------------------------------------------------------------
--			---------------------------------------------------------------------------------------------------------
--			--			CHECK IF DATABASE IS PRIMARY REPLICA
--			---------------------------------------------------------------------------------------------------------
--			---------------------------------------------------------------------------------------------------------
--			SET @a = 0
--			-- THIS IS BEING DONE TO PREVENT COMPILE ERRORS IN SQL VERSIONS THAT DO NOT SUPPORT AVAILABILITY GROUPS

--			-- ONLY VALID IN SQL 2014
--			--Select @cmd = 'SELECT @a = sys.fn_hadr_is_primary_replica (''' + @cu13DBName  + ''')'


--			Select @cmd = 'SELECT		@a = ars.role
--					FROM		sys.dm_hadr_availability_replica_states ars
--					INNER JOIN	sys.databases dbs
--						ON	ars.replica_id = dbs.replica_id
--					WHERE		dbs.name = ''' + @cu13DBName  + ''';
--					SET	@a	= COALESCE(@a,1);'


--			--Print @cmd
--			--Print ''
--			EXEC sp_executesql @cmd, N'@a int output', @a output


--			IF @a = 0
--			   BEGIN
--				--print @cu13DBName
--				raiserror('--  DBA Note: DB %s is NOT part of the Availability Group.', -1,-1,@cu13DBName) with nowait
--			   END
--			ELSE IF @a = 1
--			   BEGIN
--				--print @cu13DBName
--				raiserror('--  DBA Note: DB %s is the Primary Replica in the Availability Group.', -1,-1,@cu13DBName) with nowait
--			   END
--			ELSE
--			   BEGIN
--				--print @cu13DBName
--				raiserror('--  DBA Note: Skipping DB %s as it is not the Primary Replica in the Availability Group.', -1,-1,@cu13DBName) with nowait
--				goto skip_allDBs
--			   END
--		   END


--		If @save_DBname <> @cu13DBName
--		   begin
--			Print ' '
--			Select @miscprint = 'Use ' + @cu13DBName
--			Print @miscprint
--			Print 'go'
--			Print ' '


--			Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + @cu13DBName + ']'''
--			Print @miscprint
--			Print 'Select getdate()'
--			Print 'go'
--			Print ' '


--			Select @save_DBname = @cu13DBName
--		   end


--		Print  ' '
--		Select @miscprint = '-- DBCC PROCESS for database [' + (rtrim(@cu13DBName)) + ']'
--		Print  @miscprint
--		Select @miscprint = 'Print ''Start ' + @Process_mode + ' DBCC processing for database [' + rtrim(@cu13DBName) + ']'''
--		Print @miscprint
--		Print 'Select getdate()'


--		If @Process_mode = 'weekly'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end
--			If (select sum((size*8)/1024) from sys.master_files WHERE DB_NAME(database_id) = @cu13DBName and type <> 1) < 999999
--			   begin
--				Select @cmd = 'DBCC CHECKDB (''' + rtrim(@cu13DBName) + ''') with physical_only'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--			Else
--			   begin
--				Print '--  Very Large DB - DBCC CheckDB is being skipped.'
--				Print  ' '
--				Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu13DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '

--				Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu13DBName) + ''')'
--				Print @cmd
--				Print  'go'
--				Print  ' '
--			   end
--		   end
--		Else If @Process_mode = 'daily'
--		   begin
--			If @ARITHABORT_ON = 'y'
--			   begin
--				Select @cmd = 'SET ARITHABORT ON'
--				Print @cmd
--			   end
--			If @QUOTED_ID_ON = 'y'
--			   begin
--				Select @cmd = 'SET QUOTED_IDENTIFIER ON'
--				Print @cmd
--			   end

--			Select @cmd = 'DBCC CHECKALLOC (''' + rtrim(@cu13DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '

--			Select @cmd = 'DBCC CHECKCATALOG (''' + rtrim(@cu13DBName) + ''')'
--			Print @cmd
--			Print  'go'
--			Print  ' '
--		   end


--		skip_allDBs:


--		--  check for more rows to process
--		Delete from @DBnames where name = @cu13DBName
--		If (select count(*) from @DBnames) > 0
--		   begin
--			goto start_dbnames13
--		   end


--	   end


--   end


Label99:


If @error_count > 0
   begin
	return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_DBCCscripting] TO [public]
GO
