SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_IndexMaintenance]
	 @usesOnlineReindex				bit				= 1
	,@mode							int				= 3
	,@fragThreshold					int				= 8
	,@RebuildThreshold				int				= 30
	,@fillFactor_HighRead			int				= 100
	,@fillFactor_LowRead			int				= 80
	,@fillFactor					int				= 90
	,@tranlog_bkp_flag				char(1)			= 'y'
	,@Limit_flag					char(1)			= 'n'
	,@Limit_large_table_count		int				= 5
	,@Set_large_table_page_count	int				= 80000
	,@databaseName					nvarchar(128)	= NULL
	,@maxIndexLevelToConsider		int				= 0
	,@sortInTempDb					bit				= 1
	,@minPages						int				= 500
	,@continueOnError				bit				= 0
	,@ScriptMode					Int			= 3
	,@Path							VARCHAR(1024)	= NULL
	,@Filename						VARCHAR(1024)	= 'IndexMaintenanceScript.sql'
	,@exceptionXML					xml				=
N'
<EXCEPTION>
	<Exclude ReadsPerHr="0.001" />
</EXCEPTION>
'

/***************************************************************
 **  Stored Procedure dbasp_IndexMaintenance
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  November 24, 2003
 **
 **
 **  Description: Scans Index Physical Stats from DMVs and optionally
 **  creates a script to rebuild or defrag indexes
 **
 **
 **  This proc accepts the following input parameters:
 **
 **  	@usesOnlineReindex		= Whether or not online reindexing is used.
 **
 **  	@mode				0= rebuild	(failback to reorganize if not allowd).
 **  						If using online rebuild, reorganize objects that can't
 **  						be rebuilt online.
 **  					1= rebuild only	(failback to offline if not allowed).
 **  						If using online rebuild, objects that can't be rebuilt
 **  						online will be rebuilt offline.
 **  					2= reorganize only.
 **  					3= Auto
 **  						Uses @RebuildThreshold to automaticly switch between
 **  						Rebuild(0) and Reorginize(2).  Will not rebuild offline.
 **
 **  	@fragThreshold			= Apply maintenance when fragementation is over this threshold
 **
 **  	@RebuildThreshold		= If in Auto Mode, Anything with Fragmentation >= this are rebuilt
 **  								instead of reorginized.
 **
 **  	@fillFactor_HighRead		= Value User for FILLFACTOR on REBUILDS when Read Percentage > 60%
 **  	@fillFactor_LowRead			= Value User for FILLFACTOR on REBUILDS when Read Precentage < 30%
 **  	@fillFactor					= Value User for FILLFACTOR on REBUILDS when neither high or low apply
 **
 **		@tranlog_bkp_flag			= 'y' for periodic tranlog backup for full recovery DB's (default is 'y')
 **
 **		@Limit_flag					= 'y' will turn on the limit function (number of large tables processed in one execution)
 **		@Limit_large_table_count	= Determines the number of large tables that will be processed per DB. Default = 5
 **		@Set_large_table_page_count	= Determines the minimum size in pages for a large table.  Default is 80000.
 **
 **  	@databaseName				= The target database (Otherwise all active databases).
 **
 **  	@maxIndexLevelToConsider	= Num levels of an index to check for fragmentation:
 **  								0= leaf level only
 **  								1= leaf + index_level 1
 **  								2.. etc.
 **
 **  	@sortInTempDb				1= sort in tempdb.
 **  								0= sort in user db
 **
 **  	@minPages					= Min pages for an index to be eligible for maintenance.
 **
 **  	@continueOnError			= Set to 1 to continue on and reindex other tables after catching an error.
 **  									The job will still fail after completion.
 **
 **  	@exceptionXML				= A list of exceptions: Elements to exclude from the job.
 **  									Reads SchemaName, TableName, and TndexName.
 **
 **  	@ScriptMode					0= Execute Now, Do not Create Script.
 **  								1= Output Script to a file\TBL. Nothing Executed Now.
 **  								2= Output Script to a Screen. Nothing Executed Now.
 **  								3= Output Script to a File\TBL & Screen. Nothing Executed Now.
 **
 **  	@Path & @Filename			= point to location of Script to be generated.
 **
 **		@XSpec XML:
 **									<EXCEPTION>
 **										<Exclude SchemaName="WTAB" />
 **										<Exclude SchemaName="EVT" TableName="Log" />
 **										<Exclude TableName="z%" />
 **										<Exclude ReadsPerHr="1" />
 **									</EXCEPTION>
 **
 **
 **  By default, this procedure creates a file to run the index maint process
 **  for each database specified in the selected maintenance plan.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	2008-05-19	Steve Ledridge			Created
--	2009-02-01	Steve Ledridge			Improved error handling, flow control, loops through indexes instead of partitions.
--	2009-02-07	Steve Ledridge			Added @exceptionXML parameter support.
--	2010-04-01	Steve Ledridge			Modified For ${{secrets.COMPANY_NAME}}Images.
--	2010-04-27	Steve Ledridge			Added Update stats, limit processing and tranlog backup features.
--	2010-06-07	Steve Ledridge			Modifid ReadsPerHr calculation to include seeks for population
--											of @getReindexItems at line 592.
--	2010-07-13	Steve Ledridge			Added print for excluded indexes.
--	2010-07-28	Steve Ledridge			Added one last tranlog backup and shrink LDF per DB.
--	2010-08-11	Steve Ledridge			Added brackets for DBname where missing.
--	2010-12-16	Steve Ledridge			Modified datatypes in memory table @reindex
--	2011-06-28	Steve Ledridge			Ignore tables with tempdb as part of the name.
--	2011-07-05	Steve Ledridge			Added no_check processing.
--	2012-01-25	Steve Ledridge			New code to skip tranlog backup for logshipped DB's
--	2012-03-06	Steve Ledridge			Added exec dbo.dbasp_set_maintplans
--	2012-07-23	Steve Ledridge			Modified to insert rows into the IndexMaintenanceProcess TBL.
--	2012-08-30	Steve Ledridge			Update non-completed rows for IndexMaintenanceProcess TBL to cancelled.
--											Added force reorg for varbinary(max) and skip update stats for rebuilds.
--	02/26/2013	Steve Ledridge			Modified Calls to functions supporting the replacement of OLE with CLR.
--	2014-03-13	Steve Ledridge			Changed ReadsPerHr default to "0.001".
--	2014-08-19	Steve Ledridge			New code to ignore secondary AvailGrp DB's.
--	08/08/2016	Steve Ledridge			Modified code for avail grp DB resolving.
--	======================================================================================


DECLARE
	 @miscprint					nvarchar(4000)
	,@example_flag				char(1)
	,@save_nocheckid			int
	,@save_nocheck_schema		sysname
	,@save_nocheck_table		sysname


BEGIN TRY -- Outer Try block
	DECLARE
		 @maxFragPercent 			int
		,@databaseID 				int
		,@pageCount 				bigint
		,@reindexId 				int
		,@schemaName 				sysname
		,@tableName 				sysname
		,@tableObjectId 			int
		,@objDescription 			nvarchar(1000)
		,@indexId 					int
		,@indexName 				sysname
		,@AllowPageLocks			int
		,@totalPages 				bigint
		,@indexSizeGB 				int
		,@sql 						nvarchar(max)
		,@onlineIndexingForbidden	bit
		,@operation 				nvarchar(50)
		,@runStarted 				datetime
		,@indexStartDate 			datetime
		,@getReindexItems 			nvarchar(max)
		,@checkOnlineIndexingSQL 	nvarchar(max)
		,@getPhysicalStatsSQL 		nvarchar(max)
		,@breakNow 					bit
		,@exclusionId 				int
		,@maxExclusionId 			int
		,@exclusionItem 			nvarchar(2000)
		,@rowcount 					bigint
		,@imPhysicalStatsId 		bigint
		,@ReadPct 					float
		,@Splits 					Int
		,@OrigFillFactor 			Int
		,@save_maxpage_count		bigint
		,@save_declare_block		nvarchar(4000)


	DECLARE
		 @OutputScript					VarChar(max)
		,@indexScript					VarChar(max)
		,@OutputString					VarChar(max)
		,@OutputReport					VarChar(max)
		,@OutputScreen					VarChar(8000)
		,@ExclusionReason				VarChar(8000)
		,@SummaryVCHR					VarChar(max)
		,@SummaryINT					INT
		,@ServerName					sysname
		,@Domain						sysname
		,@charpos						int
		,@Marker1						bigint
		,@Marker2						bigint
		,@save_tableObjectId			int
		,@save_databaseName				sysname
		,@save_tableName				sysname
		,@save_schemaName				sysname
		,@updatestats_flag				char(1)
		,@page_count					int
		,@backup_tran_limit				int
		,@tranlog_bkp_flag_internal		char(1)
		,@processed_large_table_count	int
		,@limit_skip					char(1)
		,@ips_mode						sysname
		,@PathAndFile					nVarChar(4000)


	--------------------------------------------
	-- DECLARE EVT VARIABLES
	--------------------------------------------
	BEGIN
		DECLARE
			 @cEModule 						sysname
			,@cEMessage 					varchar(32)
			,@lEType 						varchar(16)
			,@lMsg 							nvarchar(max)
			,@lError 						bit
			,@Diagnose 						bit
			,@lRunSpec 						xml
			,@processGUID 					uniqueidentifier


		SELECT @cEModule					= 'dbo.dbasp_IndexMaintenance'
			, @cEMessage					= 'EVT_SUR'
			, @lError						= 0
			, @Diagnose						= 1
			, @ProcessGUID					= newid()
			, @breakNow						= 0
			, @continueOnError				= coalesce(@continueOnError,0) -- if this is passed in null, default it to zero.
			, @tranlog_bkp_flag_internal	= 'n'
			, @backup_tran_limit			= 80000


	END


	--------------------------------------------
	-- DECLARE Table VARIABLES
	--------------------------------------------

		DECLARE @tvar_dbnames table (dbname sysname)


		DECLARE @exclusionTable table (
			exclusionId int identity primary key -- using tinyint on purpose: let's not support more than 255 exclusions
			,schemaName sysname
			,tableName sysname
			,indexName sysname
			,ReadsPerHr decimal(10,4)
			)

		DECLARE	@ExcludedIndexes TABLE
			(
			ID	INT IDENTITY PRIMARY KEY
			,DatabaseName	sysname
			,SchemaName	sysname
			,TableName	sysname
			,IndexName	sysname
			,Reason		VarChar(8000)
			)

		DECLARE	@SkipedIndexes TABLE
			(
			ID	INT IDENTITY PRIMARY KEY
			,DatabaseName	sysname
			,TableName	sysname
			,IndexName	sysname
			,Reason		VarChar(8000)
			)

		DECLARE	@LimitSkipedIndexes TABLE
			(
			ID	INT IDENTITY PRIMARY KEY
			,DatabaseName	sysname
			,TableName	sysname
			,IndexName	sysname
			,Reason		VarChar(8000)
			)


		DECLARE	@RebuiltIndexes TABLE
			(
			ID	INT IDENTITY PRIMARY KEY
			,DatabaseName	sysname
			,TableName	sysname
			,IndexName	sysname
			,Reason		VarChar(8000)
			)

		DECLARE	@ReorgedIndexes TABLE
			(
			ID	INT IDENTITY PRIMARY KEY
			,DatabaseName	sysname
			,TableName	sysname
			,IndexName	sysname
			,Reason		VarChar(8000)
			)

		DECLARE @reindex table
			(
			reindexId				int identity
			,SchemaName				sysname
			,tableName				sysname
			,tableObjectId			int
			,indexId				int
			,indexName				sysname
			,[allow_page_locks]		INT
			,totalPages				bigint
			,indexSizeMB			decimal(10,2)
			,user_seeks				bigint
			,user_scans				bigint
			,user_lookups			bigint
			,user_updates			bigint
			,ReadPct				numeric(38,15)
			,WritePct				numeric(38,15)
			,Splits					bigint
			,OrigFillFactor			int
			,IndexUsage				bigint
			,IndexUsagetoSizeRatio	decimal(10,2)
			,UptimeHr				numeric(18,6)
			,ReadsPerHr				numeric(38,13)
			)


	Select	@save_declare_block	= 'Declare @ScreenMsg VarChar(max)'

	EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\CurrentControlSet\services\Tcpip\Parameters', N'Domain',@Domain OUTPUT
	SELECT @ServerName =  UPPER(Cast(SERVERPROPERTY('MachineName') as nvarchar)+'.'+@Domain)


	If @Path is null
	   begin
		exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @path output
		SET @path = @Path + '\dbasql'
	   end


	SELECT	@PathAndFile = @Path + '\' + @Filename


	exec [dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS


	Select @ips_mode = case @maxIndexLevelToConsider when 0 then 'LIMITED' else 'DETAILED' END

	SET @OutputScript = ''


	--  Set non-completed IndexMaintenanceProcess rows to cancelled
	If exists (select 1 from dbo.IndexMaintenanceProcess where status not in ('completed', 'cancelled'))
	   begin
		Update dbo.IndexMaintenanceProcess set status = 'cancelled' where status not in ('completed', 'cancelled')
	   end


	----------------------  Main header  ----------------------
	SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + '/************************************************************************' + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + 'SQL Index Maintenance Process'  + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + 'Created For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9) + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + '************************************************************************/' + CHAR(13)+CHAR(10) + CHAR(13)+CHAR(10)


	SET	@OutputScript = @OutputScript + 'Print ''Starting SQL Index Maintenance Process '' + convert(varchar(30),getdate(),9)' + CHAR(13)+CHAR(10)
	SET	@OutputScript = @OutputScript + 'SET NOCOUNT ON' + CHAR(13)+CHAR(10)


	--  Initial creation of the output file (all others will append)
	If @ScriptMode IN (1,3)
	BEGIN
		--------------------------------------------
		-- LOG MESSAGE START
		--------------------------------------------
		SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_START'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------


		If @ScriptMode in (1,3)
		   begin
			EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,0,1
		   end


		If @ScriptMode in (2,3)
		   begin
			Print @OutputScript
		   end

		SET	@OutputScript = ''


		--------------------------------------------
		-- LOG MESSAGE SUCCESS
		--------------------------------------------
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_SUCCESS'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------
	END


	--  Get database(s) to process
	If @databaseName is not null and @databaseName in (select name from master.sys.databases where state_desc = 'online')
	   begin
		insert into @tvar_dbnames values (@databaseName)
	   end
	Else If @databaseName is not null and @databaseName not in (select name from master.sys.databases where state_desc = 'online')
	   begin
		--------------------------------------------
		-- LOG MESSAGE /W RAISERROR
		--------------------------------------------
		set @lMsg=N'Unable to determine DatabaseName(s) to process. Check parameters';
		--------------------------------------------
		exec [dbasp_LogMsg]
			 @ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_FAIL'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
		--------------------------------------------
		RAISERROR (@lMsg,16,1)
		--------------------------------------------
		SET @lError=1
		goto label99
	   end
	ELSE
	   BEGIN
		INSERT	@tvar_dbnames
		SELECT	name
		FROM	master.sys.databases
		WHERE	state_desc = 'online'
		  AND	database_id > 4
	   END


	Delete from @tvar_dbnames where dbname is null or dbname = ''
	--select * from @tvar_dbnames


	--  Delete any secondary AvailGrp DB's
	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		Delete from @tvar_dbnames where dbname in (Select dbcs.database_name
								FROM master.sys.availability_replicas AS AR
								INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
								   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
								INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
								   ON arstates.replica_id = dbcs.replica_id
								where AR.replica_server_name = @@servername
								and arstates.role_desc in ('SECONDARY', 'RESOLVING'))
	   end


	If (select count(*) from @tvar_dbnames) > 0
	   begin
		start_dbname:
		Select @databaseName = (Select top 1 dbname from @tvar_dbnames)
		Select @page_count = 0
		Select @processed_large_table_count = 0
		select @limit_skip = 'n'
		Set @updatestats_flag = 'n'

		-- Set tranlog backup flag
		If @tranlog_bkp_flag = 'y' and databaseproperty(@databaseName, 'IsTrunclog') = 0
		   begin
			If exists (select 1 from dbo.no_check where NoCheck_type = 'LOGSHIP' and detail01 = @databaseName)
			   begin
				Select @tranlog_bkp_flag_internal = 'n'
			   end
			Else
			If exists (select 1 from dbo.no_check where NoCheck_type = 'LOGSHIP' and detail01 = @databaseName)
			   begin
				Select @tranlog_bkp_flag_internal = 'y'
			   end
		   end
		Else
		   begin
			Select @tranlog_bkp_flag_internal = 'n'
		   end


		SELECT @databaseID=database_id from master.sys.databases where name=@databaseName;

		SET	@indexScript = ''
		SET	@save_tableObjectId = NULL


		--  Check the online reindex parm
		if @usesOnlineReindex in (1,2) AND CAST(SERVERPROPERTY('Edition') AS VarChar(255)) NOT like '%Enterprise%' AND CAST(SERVERPROPERTY('Edition') AS VarChar(255)) NOT like '%Developer%'
			BEGIN
				--  If we are not in Enterprise Edition, set @usesOnlineReindex to 0
				If @mode <> 1 -- auto mode
					BEGIN
						Select @usesOnlineReindex = 0

						--------------------------------------------
						-- LOG MESSAGE
						--------------------------------------------
						SET @lMsg = 'Setting the request for online index builds to ''NO'' due to SQL version (not Enterprise).'
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_INFO'
							,@ProcessGUID=@ProcessGUID
							,@AdHocMsg = @lMsg
						--------------------------------------------
						--------------------------------------------
					END
				Else
					BEGIN
						--------------------------------------------
						-- LOG MESSAGE /W RAISERROR
						--------------------------------------------
						set @lMsg=N'Server Edition ' + CAST(SERVERPROPERTY('Edition') AS VarChar(255)) + ': Online Reindexing Not Allowed'
						--------------------------------------------
						exec [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_FAIL'
							,@ProcessGUID=@ProcessGUID
							,@AdHocMsg = @lMsg
						--------------------------------------------
						RAISERROR (@lMsg,16,1)
						--------------------------------------------
					END
			END


		--  check mode and scriptmode parms
		if (@mode not in (0,1,2,3) or coalesce(@ScriptMode,-1) not in (0,1,2,3))
			begin
				--------------------------------------------
				-- LOG MESSAGE /W RAISERROR
				--------------------------------------------
				set @lMsg=N'Incorrect DatabaseName, Mode, or ScriptMode. Check parameters';
				--------------------------------------------
				exec [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_FAIL'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
				--------------------------------------------
				RAISERROR (@lMsg,16,1)
				--------------------------------------------
			end


		SET @runStarted = getdate() --Date that the entire run started


		--Log start of run to EVT
		--------------------------------------------
		-- LOG MESSAGE
		--------------------------------------------
		SET @lMsg = @databaseName + N': Starting Index Maintenance '
			+ case @ScriptMode
				when 0 then N'(Live Execution). '
				when 1 then N'(Script to File\Tbl). '
				when 2 then N'(Script to Screen). '
				when 3 then N'(Script to File\Tbl & Screen). '
				ELSE '(Unknown ScriptMode). '
				END
			+ N'Mode is ' + case @mode
						when 0 then N'rebuild online or reorganize. '
						when 1 then N'rebuild only. '
						when 2 then N'reorganize only. '
						when 3 then N'Auto. '
						ELSE 'Unknown. '
						end
			+ N'Index Page Threshold is ' + cast(@minPages as nvarchar(10)) + N' pages. '
			+ N'Fragmentation Threshold is ' + cast(@fragThreshold as nvarchar) + N'%. '
			+ CASE @mode
				WHEN 3 THEN 'AutoRebuild Threshold is '+ cast(@RebuildThreshold as nvarchar) + N'%. '
				ELSE ''
				END
			+ N'Sort In TempDb is ' + case @sortInTempDb
							when 1 then N'on. '
							else N'off. '
							end
		--------------------------------------------
		exec [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_START'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
		--------------------------------------------
		--------------------------------------------


		--------------------------------------------
		-- BUILD OBJECT TABLE
		--------------------------------------------
		delete from @reindex


		SELECT @getReindexItems = REPLACE(
	N'SELECT	schemaName = s.name
				, tableName = o.name
				, tableObjectId= o.object_id
				, si.index_id
				, indexName = si.name
				, CAST(SI.allow_page_locks AS INT)
				, totalPages=sum(au.Total_Pages)
				, indexSizeMB = cast(sum(au.Total_Pages) * 8.00 / 1024.00 as decimal(10,2))
				,MAX(COALESCE(user_seeks,0))user_seeks
				,MAX(COALESCE(user_scans,0))user_scans
				,MAX(COALESCE(user_lookups,0))user_lookups
				,MAX(COALESCE(user_updates,0))user_updates
				,MAX(COALESCE((([user_seeks]+[user_scans]+[user_lookups])*100.00)/(CASE when user_seeks+user_scans+user_lookups+user_updates = 0 then 1 Else user_seeks+user_scans+user_lookups+user_updates end),0)) AS ReadPct
				,MAX(COALESCE((([user_updates])*100.00)/(CASE when user_seeks+user_scans+user_lookups+user_updates = 0 then 1 Else user_seeks+user_scans+user_lookups+user_updates end),0)) AS WritePct
				,MAX(COALESCE(ios.leaf_allocation_count + ios.nonleaf_allocation_count,0)) AS [Splits]
				,MAX(COALESCE(si.Fill_Factor,100)) as OrigFillFactor
				,MAX(COALESCE(user_seeks+user_scans+user_lookups+user_updates,0)) as IndexUsage
				,cast(MAX(COALESCE(user_seeks+user_scans+user_lookups+user_updates,0))/(sum(au.Total_Pages)*8)+.01  as decimal(10,2)) IndexUsagetoSizeRatio
				,(SELECT datediff(minute,login_time,getdate())/60.00 From sys.sysprocesses where spid = 1) UptimeHr
				,(MAX(COALESCE(user_seeks,0)) + MAX(COALESCE(user_scans,0)))/(SELECT datediff(minute,login_time,getdate())/60.00 From sys.sysprocesses where spid = 1) ReadsPerHr
	FROM		[?].sys.objects o with (nolock)
	join		[?].sys.schemas s with (nolock)
		on		o.schema_id = s.schema_id
	join		[?].sys.indexes si with (nolock)
		on		o.[object_id]=si.[object_id]
		and		si.type <> 0 -- no heaps
	join		[?].sys.partitions par (nolock)
		on		si.[object_id]= par.[object_id]
		and		si.index_id=par.index_id
	join		[?].sys.allocation_units au (nolock)
		on		par.partition_id=au.container_id
	join		[?].sys.data_spaces ds with (nolock)
		on		si.data_space_id = ds.data_space_id
	left join	[?].sys.dm_db_index_usage_stats us
		on		us.database_id = db_id(''?'')
		and		us.object_id = si.object_id
		and		us.index_id = si.index_id
	LEFT JOIN	[?].sys.dm_db_index_operational_stats(DB_ID(''?''),NULL,NULL,NULL)ios
		ON		us.[database_id]	=ios.[database_id]
		AND		us.[object_id]		=ios.[object_id]
		AND		us.[index_id]		=ios.[index_id]
	WHERE		o.type_desc in (N''USER_TABLE'',N''VIEW'')
	AND		o.name not like ''%tempdb%''
	GROUP BY	s.name
				, o.name
				, o.object_id
				, si.index_id
				, si.name
				, si.allow_page_locks
	HAVING		sum(au.Total_Pages) > '+ cast(@minPages as nvarchar(10)) +'
	ORDER BY	s.name, o.name','?',@databaseName)


		--------------------------------------------
		-- LOG MESSAGE
		--------------------------------------------
		SET @lMsg = 'Getting indexes with more than '  + cast(@minPages as nvarchar(10)) + N' pages.'
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_INFO'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
		--------------------------------------------
		--------------------------------------------


		INSERT @reindex (schemaName, tableName, tableObjectId, indexId, indexName, [allow_page_locks], totalPages, indexSizeMb, user_seeks, user_scans, user_lookups, user_updates, ReadPct, WritePct, Splits, OrigFillFactor, IndexUsage, IndexUsagetoSizeRatio, UptimeHr, ReadsPerHr)
		EXEC sp_executesql @getReindexItems;


		SELECT @getReindexItems = REPLACE(
	N'SELECT		''?'' DatabaseName
				, SchemaName = s.name
				, tableName = o.name
				, indexName = CASE si.type
						WHEN 0 THEN ''Table is a Heap''
						ELSE si.name
						END
				, Reason = CASE
						WHEN si.type = 0 THEN ''NoClstIndx: Table has No Clustered Indexes''
						WHEN si.allow_row_locks <> 1 THEN ''NoRowLocks: Index does not allow row locks''
						ELSE ''IndxTooSml: Index has '' + cast(sum(au.Total_Pages) as nvarchar(10)) + '' Pages which is less than the limit of '  + cast(@minPages as nvarchar(10)) + ' pages''
						END
	FROM		[?].sys.objects o with (nolock)
	join		[?].sys.schemas s with (nolock)
		on		o.schema_id = s.schema_id
	join		[?].sys.indexes si with (nolock)
		on		o.[object_id]=si.[object_id]
	join		[?].sys.partitions par (nolock)
		on		si.[object_id]= par.[object_id]
		and		si.index_id=par.index_id
	join		[?].sys.allocation_units au (nolock)
		on		par.partition_id=au.container_id
	WHERE		o.type_desc in (N''USER_TABLE'',N''VIEW'')
	GROUP BY	s.name
			,o.name
			,si.name
			,si.type
			,si.allow_row_locks
	HAVING		sum(au.Total_Pages) <= '+ cast(@minPages as nvarchar(10)) +' OR si.type = 0 OR si.allow_row_locks <> 1
	ORDER BY	s.name,o.name, si.name','?',@databaseName)


		INSERT @ExcludedIndexes (DatabaseName, SchemaName, TableName, IndexName, Reason)
		EXEC sp_executesql @getReindexItems;


		IF @exceptionXML is not null
		BEGIN -- parse exclusions block

			--------------------------------------------
			-- LOG MESSAGE
			--------------------------------------------
			SELECT @lMsg = 'Parsing exclusion list'
			--------------------------------------------
			exec [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_INFO'
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
			--------------------------------------------
			--------------------------------------------


			INSERT @exclusionTable (schemaName, tableName, indexName,ReadsPerHr )
			SELECT DISTINCT
				schemaName=coalesce(x.SchemaName,'%')
				,tableName=coalesce(x.TableName,'%')
				,indexName=coalesce(x.IndexName,'%')
				,ReadsPerHr=coalesce(x.ReadsPerHr,0.0)
			FROM
			(
				SELECT DISTINCT
					SchemaName = e.i.value('@SchemaName','sysname')
					,TableName = e.i.value('@TableName','sysname')
					,IndexName = e.i.value('@IndexName','sysname')
					,ReadsPerHr = e.i.value('@ReadsPerHr','decimal(10,4)')
				FROM @exceptionXML.nodes('EXCEPTION/Exclude') e(i)
				WHERE (	e.i.value('@DatabaseName','sysname')=@databaseName or e.i.value('@DatabaseName','sysname') is null )
					and (
						e.i.value('@SchemaName','sysname') is not null
						or e.i.value('@TableName','sysname') is not null
						or e.i.value('@IndexName','sysname') is not null
						or e.i.value('@ReadsPerHr','decimal(10,4)') is not null
					)
				) x
			SELECT @maxExclusionId=@@ROWCOUNT, @exclusionId = 1;


			IF @maxExclusionId >0 --process exclusions. This could easily be done without a loop, but this makes the logging very clear.
				WHILE @exclusionId <= @maxExclusionId
				BEGIN -- process exclusions block
					SELECT @exclusionItem = '['+ schemaName + '].[' + tableName + '].[' + indexName + '] SPH <= ' + CAST(ReadsPerHr AS VarChar(50))
					from @exclusionTable
					where exclusionId = @exclusionId;


					INSERT INTO	@ExcludedIndexes (DatabaseName,SchemaName,TableName,IndexName,Reason)
					SELECT		@databaseName
							,r.schemaName
							,r.TableName
							,r.IndexName
							,'ExclsParam:'
							+ CASE x.schemaName
								WHEN '%' THEN ''
								ELSE ' Schema:'+ x.schemaName
								END
							+ CASE x.tableName
								WHEN '%' THEN ''
								ELSE ' Table:'+ x.tableName
								END
							+ CASE x.indexName
								WHEN '%' THEN ''
								ELSE ' Index:'+ x.indexName
								END
							+ CASE x.ReadsPerHr
								WHEN 0.0 THEN ''
								ELSE ' RPH:' + CAST(r.ReadsPerHr AS VarChar(50)) + ' (Index has only ' + CAST(r.ReadsPerHr AS VarChar(50)) + ' Reads Per Hr(RPH) which is less than the limit of '  + CAST(x.ReadsPerHr AS VarChar(50)) + ' RPH)'
								END
					FROM @reindex r
					JOIN @exclusionTable x on
						(r.SchemaName like x.schemaName or x.schemaName='%')
						and (r.tableName like x.tableName  or x.tableName = '%')
						and (r.indexName like x.indexName or x.indexName ='%')
						and (r.ReadsPerHr <= x.ReadsPerHr or x.ReadsPerHr =0.0)
					WHERE x.exclusionId =@exclusionId


					SELECT @exclusionId=@exclusionId+1
				END -- process exclusions block
		END -- parse exclusions block


		BEGIN -- REMOVE EXCLUSIONS FROM @reindex


			--------------------------------------------
			-- LOG MESSAGE
			--------------------------------------------
			SELECT	@lMsg		= 'Exclusion: Indexes excluded for database [' + @databaseName + ']  ------------------------'
				, @lEType	='EVT_INFO'
			--------------------------------------------
			EXEC [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword=@lEType
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
			--------------------------------------------
			--------------------------------------------

			-- GET MAXIMUM WIDTH FOR THIS SECTION SO THAT REASONS CAN ALL BE ALIGNED
			SELECT	@rowcount = MAX(LEN(schemaName+'.'+tableName+REPLACE('.'+indexName,'.Table is a Heap',''))) + 31
			FROM	@ExcludedIndexes

			DECLARE Remove_Exclusions_Cursor
			CURSOR
			FOR
			SELECT DatabaseName,SchemaName,TableName,IndexName,Reason From @ExcludedIndexes ORDER BY 1,2,3,4


			OPEN Remove_Exclusions_Cursor
			FETCH NEXT FROM Remove_Exclusions_Cursor INTO @databaseName, @schemaName, @tableName, @indexName, @ExclusionReason
			WHILE (@@fetch_status <> -1)
			BEGIN
				IF (@@fetch_status <> -2)
				BEGIN
					DELETE		@reindex
					WHERE		SchemaName	= @schemaName
						and	tableName	= @tableName
						and	indexName	= @indexName

					--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
						SELECT	@lMsg		= 'Exclusion:   Will not reindex '
									+ @schemaName
									+ '.' + @tableName
									+ REPLACE('.' + @indexName,'.Table is a Heap','')
							, @lEType	='EVT_INFO'

							-- ADD SPACING FOR ALIGNEMENT
							, @lMsg		= @lMsg
									+ REPLICATE(' ', @rowcount - LEN(@lMsg))
									+ ': ' + @ExclusionReason
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword=@lEType
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
					--------------------------------------------
					--------------------------------------------
				END
				FETCH NEXT FROM Remove_Exclusions_Cursor INTO @databaseName, @schemaName, @tableName, @indexName, @ExclusionReason
			END


			CLOSE Remove_Exclusions_Cursor
			DEALLOCATE Remove_Exclusions_Cursor


			--  Remove for no_check
			If exists (select 1 from dbo.no_check where NoCheck_type = 'indexmaint' and detail01 = @databaseName)
			   begin
				SELECT @rowcount = MAX(LEN(detail02+'.'+detail03+' Due to No_Check Entry')) + 31
				FROM dbo.no_check
				Where NoCheck_type = 'indexmaint'
				and detail01 = @databaseName


				Select @ExclusionReason = 'No Check Entry'
				Select @save_nocheckid = 0
				nocheck01:
				Select @save_nocheckid = (select top 1 nocheckid from dbo.no_check where NoCheck_type = 'indexmaint' and detail01 = @databaseName and nocheckid > @save_nocheckid order by nocheckid)
				Select @save_nocheck_schema = (select detail02 from dbo.no_check where nocheckid = @save_nocheckid)
				Select @save_nocheck_table = (select detail03 from dbo.no_check where nocheckid = @save_nocheckid)


				DELETE		@reindex
				WHERE		SchemaName	= @save_nocheck_schema
					and	tableName	= @save_nocheck_table

				--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
					SELECT	@lMsg		= 'Exclusion:   Will not reindex '
								+ @save_nocheck_schema
								+ '.' + @save_nocheck_table
								+ ' Due to No_Check Entry'
						, @lEType	='EVT_INFO'

						-- ADD SPACING FOR ALIGNEMENT
						, @lMsg		= @lMsg
								+ REPLICATE(' ', @rowcount - LEN(@lMsg))
								+ ': ' + @ExclusionReason
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword=@lEType
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
				--------------------------------------------
				--------------------------------------------

				If exists (select 1 from dbo.no_check where NoCheck_type = 'indexmaint' and detail01 = @databaseName and nocheckid > @save_nocheckid)
				   begin
					goto nocheck01
				   end
			   end


		END -- REMOVE EXCLUSIONS FROM @reindex


		--DECLARE the cursor
		DECLARE TableCursor CURSOR LOCAL FAST_FORWARD FOR
			SELECT reindexId, schemaName, tableName, tableObjectId, indexId, indexName, [allow_page_locks], totalPages, indexSizeMb, ReadPct, Splits, OrigFillFactor
			from @reindex
			order by schemaName, tableName, indexId

		OPEN TableCursor
		FETCH NEXT FROM TableCursor INTO @reindexId, @schemaName, @tableName, @tableObjectId, @indexId, @indexName, @AllowPageLocks, @totalPages, @indexSizeGB, @ReadPct, @Splits, @OrigFillFactor


		WHILE (@@FETCH_STATUS = 0 and @breakNow=0)

		BEGIN --block for WHILE @@FETCH_STATUS = 0 and @lError=0
		BEGIN TRY -- Try block within cursor


				SET @indexStartDate=GETDATE()
				SET @sql = null

				If @save_tableObjectId is not null
				   begin
					If @save_tableObjectId <> @tableObjectId and @updatestats_flag = 'y'
					   begin
						Set @updatestats_flag = 'n'


						Select @sql = 'dbo.dbasp_IndexUpdateStats @databaseName = ''' + @save_databaseName + ''', @schemaName = ''' + @save_schemaName + ''', @tableName = ''' + @save_tableName + ''', @ProcessGUID = ''' + convert(nvarchar(50), @ProcessGUID) + ''', @ScriptMode = 0'
					  	IF @ScriptMode=0
						BEGIN --Block for update stats
							--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_START'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @lMsg


							SELECT @SQL
							--The action happens here.
							EXEC sp_executesql @sql


							--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_SUCCESS'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @lMsg


						END --Block for update stats
						Else
						BEGIN --Script update stats
						   	--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							Set @lMsg = 'ScriptMode, Adding Entry For :' + @sql;
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_INFO'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @lMsg


							SET @indexScript = @indexScript + '--  UPDATE STATS for ' + @save_databaseName + '.' + @save_schemaName + '.' + @save_tableName + CHAR(13)+CHAR(10)
							SET @indexScript = @indexScript + 'Print ''Updates Stats for ' + @save_databaseName + '.' + @save_schemaName + '.' + @save_tableName + '''' + CHAR(13)+CHAR(10)
							SET @indexScript = @indexScript + 'Exec ' + @sql				+ CHAR(13)+CHAR(10)
							SET @indexScript = @indexScript 						+ CHAR(13)+CHAR(10)
							+'-- LOG MESSAGE - Update Stats'						+ CHAR(13)+CHAR(10)
							+'--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'EXEC dbo.dbasp_LogMsg'						+ CHAR(13)+CHAR(10)
							+'	 @ModuleName=''[dbasp_IndexUpdatestats]'''				+ CHAR(13)+CHAR(10)
							+'	,@MessageKeyword=''EVT_UDS'''						+ CHAR(13)+CHAR(10)
							+'	,@TypeKeyword=''EVT_INFO'''						+ CHAR(13)+CHAR(10)
							+'	,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
							+'	,@AdHocMsg = ''' + replace(@sql, '''', '''''') + ''''			+ CHAR(13)+CHAR(10)


							SET	@OutputScript = @indexScript
							SET	@indexScript = ''


							--------------------------------------------
							-- LOG MESSAGE START
							--------------------------------------------
							SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_START'
								,@AdHocMsg=@lMsg
								,@ProcessGUID=@ProcessGUID
								,@SuppressRaiseError=1;
							--------------------------------------------
							--------------------------------------------


							Insert into dbo.IndexMaintenanceProcess (DBname, TBLname, MAINTsql, Status) values(@save_databaseName, @save_tableName, @OutputScript, 'pending')
							SET	@OutputScript = @OutputScript + 'GO' + CHAR(13)+CHAR(10)


							If @ScriptMode in (1,3)
							   begin
								EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
							   end


							If @ScriptMode in (2,3)
							   begin
								Print @OutputScript
							   end

							SET	@OutputScript = ''

							--------------------------------------------
							-- LOG MESSAGE SUCCESS
							--------------------------------------------
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_SUCCESS'
								,@AdHocMsg=@lMsg
								,@ProcessGUID=@ProcessGUID
								,@SuppressRaiseError=1;
							--------------------------------------------
							--------------------------------------------
						   END
					   end
				   end


				-- cannot use online reindexing with disabled indices or with text/image/xml/LOB data
				SELECT @checkOnlineIndexingSQL =N'
					SELECT
					@fbdn = max(case when si.is_disabled = 1 then 1
							when t.name in (''text'',''ntext'',''image'',''xml'') then 1
							when t.name in (''char'',''nchar'',''varchar'',''nvarchar'', ''varbinary'') and c.max_length = -1 then 1
							else 0
							end)
					from	['+ @databaseName + N'].sys.indexes si with (nolock)
					join ['+ @databaseName + N'].sys.columns c with (nolock)
						on si.object_id = c.object_id
					join ['+ @databaseName + N'].sys.systypes t with (nolock)
						on c.system_type_id = t.xtype
					join ['+ @databaseName + N'].sys.data_spaces ds with (nolock)
						on si.data_space_id = ds.data_space_id
					where  si.object_id = ' + cast(@tableObjectId as nvarchar) + '
					and si.index_id = ' + cast(@indexId as nvarchar) + '
					group  by si.object_id
				'


				EXEC sp_executesql @stmt=@checkOnlineIndexingSQL, @params=N'@fbdn int OUTPUT', @fbdn=@onlineIndexingForbidden OUTPUT;


				--Set the object description.
				SET @objDescription = coalesce(@schemaName,'???') + N'.' + coalesce(@tableName,'???')
						+ N' index=' + coalesce(@indexName,'???')
						+ N' (' + coalesce(cast(@indexSizeGB as nvarchar),'?') + N'GB) '
						+ N'Online reindex ' + case @onlineIndexingForbidden when 1 then N'forbidden.' else N'OK.' end


				--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
				SET @cEMessage='EVT_SCI'
				SET @lMsg = @databaseName + N': Starting check for '
						+ @objDescription
				--------------------------------------------
				--Log start of index scan to EVT
				EXEC [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_START'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
				--------------------------------------------
				--------------------------------------------

				-- Set up the query to get the stats. Dynamic sql is required since we're pulling from a different database.
				SELECT @getPhysicalStatsSQL= N'
					SELECT
						insert_date=''' + convert(nvarchar, @indexStartDate, 126) + '''
						, scan_started = ''' + convert(nvarchar, @runStarted, 126) + '''
						, ps.database_id
						, ps.[object_id]
						, ''' + @schemaName + N'.' + @tableName + N'''
						, ps.index_id
						, ps.partition_number
						, ps.index_depth
						, ps.index_level
						, ps.avg_fragmentation_in_percent
						, ps.page_count
						, ps.avg_page_space_used_in_percent
						, ps.record_count
						, ps.min_record_size_in_bytes
						, ps.max_record_size_in_bytes
						, ps.avg_record_size_in_bytes
						, us.user_seeks
						, us.user_scans
						, us.user_lookups
						, us.user_updates
						, us.system_seeks
						, us.system_scans
						, us.system_lookups
						, us.system_updates
						, ios.leaf_allocation_count
						+ ios.nonleaf_allocation_count AS [Splits]
					from	[' + @databaseName + '].[sys].[dm_db_index_physical_stats]('
						+ cast(@databaseId as nvarchar)
						+ ',' + convert(nvarchar, @tableObjectId, 126)
						+ ',' + convert(nvarchar, @indexId, 126)
						+ ',null'
						+ ',''' + @ips_mode
						+ ''') ps
					join	[' + @databaseName + '].[sys].[dm_db_index_usage_stats] us
						on ps.database_id = us.database_id
						AND ps.[object_id] = us.[object_id]
						AND ps.index_id = us.index_id
					join	[' + @databaseName + '].[sys].[dm_db_index_operational_stats]('
						+ cast(@databaseId as nvarchar)
						+ ',' + convert(nvarchar, @tableObjectId, 126)
						+ ',' + convert(nvarchar, @indexId, 126)
						+ ',NULL'
						+ ') ios
						on ps.[database_id] = ios.[database_id]
						AND ps.[object_id] = ios.[object_id]
						AND ps.[index_id] = ios.[index_id]
					WHERE ps.index_type_desc <> ''HEAP''
				'
				-- Pull the stats for this index
				INSERT dbo.IndexMaintenancePhysicalStats
					(insert_date, scan_started, database_id, [object_id], tablename, index_id, partition_number, index_depth
					, index_level, avg_fragmentation_in_percent, page_count, avg_page_space_used_in_percent, record_count
					, min_record_size_in_bytes, max_record_size_in_bytes, avg_record_size_in_bytes
					,[user_seeks],[user_scans],[user_lookups],[user_updates],[system_seeks],[system_scans],[system_lookups],[system_updates],[Splits])
				EXEC sp_executesql @getPhysicalStatsSQL;


				SET @imPhysicalStatsId = SCOPE_IDENTITY()


				SELECT @maxFragPercent = max(avg_fragmentation_in_percent)
				FROM dbo.IndexMaintenancePhysicalStats
				WHERE insert_date=@indexStartDate
				and [object_id]=@tableObjectId
				and index_id = @indexId
				--and index_level <= @maxIndexLevelToConsider -- typically only look at leaf level and one level up.  most indexes won't be deeper than 4 levels
				and page_count > @minPages


				SELECT @save_maxpage_count = max(page_count)
				FROM dbo.IndexMaintenancePhysicalStats
				WHERE insert_date=@indexStartDate
				and [object_id]=@tableObjectId
				and index_id = @indexId


				-- Figure out the operation. The rules:
				--For partitioned indexes, you cannot rebuild an individual partition online in SQL 2005/2008.
				--You can rebuild an entire index which is partitioned online, however.
				--This script only supports rebuilding an entire index.


				-----------------------------------------------------------
				-----------------------------------------------------------
				-- LOGIC TO SELECT BETWEEN REORG OR REBUILD
				-----------------------------------------------------------
				-----------------------------------------------------------
				SELECT	@operation = CASE
							WHEN	@maxFragPercent is null			-- no qualifying indexes (e.g., < @minPages pages on every index_level)
							or	@maxFragPercent < @fragThreshold	--Isn't fragmented
							THEN	N'No maintenance'


							WHEN	@mode = 2				-- always reorganize if we're in reorganize only mode
							or						-- if mode = 0 and you can't do an online rebuild
							(						-- , reorganize
								@mode				= 0
								and @onlineIndexingForbidden	= 1
								and @usesOnlineReindex		= 1
							)
							or						-- if mode = 3 and you can't do an online rebuild
							(						-- , reorganize
								@mode				= 3
								and @onlineIndexingForbidden	= 1
							)
							or						-- if mode = 3 and you can't do an online rebuild
							(						-- , reorganize
								@mode				= 3
								and @usesOnlineReindex		= 0
							)


							or						-- if mode=3 and framentation is under the rebuild threshold.
							(
								@mode				= 3
								and @maxFragPercent		< @RebuildThreshold
							)
							THEN N'REORGANIZE'

							ELSE N'REBUILD'
							END


				If @operation <> 'No maintenance'
				   begin
					If @save_maxpage_count is not null
					   begin
						Select @page_count = @page_count + @save_maxpage_count

						If @save_maxpage_count > @set_large_table_page_count
						   begin
							Select @processed_large_table_count = @processed_large_table_count + 1
						   end
					   end

					If @Limit_flag = 'y' and @processed_large_table_count > @limit_large_table_count
					   begin
						select @limit_skip = 'y'
					   end
				   end


				IF @operation in ('REORGANIZE','REBUILD') --Always bracket the names (esp. for net conversions)
				   begin
					SET @sql = N'USE [' + @databaseName + N']; ALTER INDEX [' + @indexName + N'] ON ['+@schemaName + N'].['+ @tableName+ N'] '
							-- REBUILD OR REORG
							+ @operation


							-- Set options
							+ case @operation
								when 'REORGANIZE' then N''
								when 'REBUILD' then
									N' WITH (FILLFACTOR = ' + CASE
													WHEN @ReadPct > 60 THEN cast(@fillFactor_HighRead as nvarchar)
													WHEN @ReadPct < 30 THEN cast(@fillFactor_LowRead as nvarchar)
													ELSE cast(@fillFactor as nvarchar)
													END
									+ N', PAD_INDEX = ON'
									+ N', SORT_IN_TEMPDB = ' + case @sortInTempDb when 1 then N'ON' else N'OFF' end
									+ N', STATISTICS_NORECOMPUTE = OFF'
									+ N', ONLINE = '
										+ case when @usesOnlineReindex = 1 and isnull(@onlineIndexingForbidden,0) <> 1
											then N'ON'
											else N'OFF'
										end + N');'
								else null -- the no maint operation should do nothing but log
								end
				   end

				If @OrigFillFactor != CASE
							WHEN @ReadPct > 60 THEN @fillFactor_HighRead
							WHEN @ReadPct < 30 THEN @fillFactor_LowRead
							ELSE @fillFactor
							END
				AND @operation = 'REBUILD'
				BEGIN
					--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
					SELECT @lMsg= N'IdxFilFact: Index Fill Factor changing From '
						+ CAST(@OrigFillFactor AS nVarChar) +' to '
						+ CASE
							WHEN @ReadPct > 60 THEN cast(@fillFactor_HighRead as nvarchar)
							WHEN @ReadPct < 30 THEN cast(@fillFactor_LowRead as nvarchar)
							ELSE cast(@fillFactor as nvarchar)
							END
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_INFO'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
					--------------------------------------------
					--------------------------------------------
				END
				--Log completion of index scan to EVT
				--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
				SELECT @lMsg= CASE @operation
						WHEN 'No maintenance' THEN 'IdxNotFrag: '
						ELSE ''
						END
					+ N'DMV says '
					+ CASE WHEN @maxFragPercent is not null then
							N'Frag=' + cast(coalesce(@maxFragPercent,0) as nvarchar) + N'% '
						else N'All frag beneath threshold of ' + cast(@fragThreshold as nvarchar) + N'%. '
						end
					+ @operation + N': '
					+ @objDescription
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_SUCCESS'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
				--------------------------------------------
				--------------------------------------------


				IF @operation = 'No maintenance'
				BEGIN
					INSERT INTO @SkipedIndexes	(DatabaseName,TableName,IndexName,Reason)
					VALUES				(@DatabaseName,@TableName,@IndexName,@lMsg)

       				END
       				Else IF @limit_skip = 'y'
				BEGIN
					Select @operation = 'No maintenance'
					INSERT INTO @LimitSkipedIndexes	(DatabaseName,TableName,IndexName,Reason)
					VALUES				(@DatabaseName,@TableName,@IndexName,'Size Limit:')

       				END
				Else IF (coalesce(@onlineIndexingForbidden,0) = 1 and @usesOnlineReindex = 1 )
				BEGIN -- Block to log warning if object can't be rebuilt online
					--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
					IF @mode=1
						SELECT @lMsg= N'FBtoOffLin: Rebuild Online only SELECTed, but this index cannot be rebuilt online. Offline rebuild will be used for: '
							+ @objDescription
							+ N' Use @mode=0 to REORG objects that cannot be rebuilt online and REBUILD all others.'
							, @lEType= 'EVT_WARN';
					ELSE IF @mode in (0,3)
						SELECT @lMsg= N'FBtoReOrg: This index cannot be rebuilt online. @mode=0 or 3 so REORG will be used for: '
							+ @objDescription
							, @lEType= 'EVT_INFO';
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword=@lEType
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
					--------------------------------------------
					SET @indexScript = @indexScript
					+ ''+CHAR(13)+CHAR(10)
					+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
					+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
					+ '-- ' + QuoteName(@DatabaseName)+'.'+QUOTENAME(@TableName)+'.'+QUOTENAME(@IndexName)+CHAR(13)+CHAR(10)
					+ '-- ' +@lMsg+CHAR(13)+CHAR(10)
					If @maxFragPercent is not null and @save_maxpage_count is not null
					   begin
						SET @indexScript = @indexScript + '-- Avg Fragmentation: ' + convert(nvarchar(15), @maxFragPercent) + '%  Page Count: ' + convert(nvarchar(15), @save_maxpage_count) +CHAR(13)+CHAR(10)
					   end
					SET @indexScript = @indexScript
					+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
					+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)

					SET	@OutputScript = @indexScript
					SET	@indexScript = ''


					--------------------------------------------
					-- LOG MESSAGE START
					--------------------------------------------
					SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_START'
						,@AdHocMsg=@lMsg
						,@ProcessGUID=@ProcessGUID
						,@SuppressRaiseError=1;
					--------------------------------------------
					--------------------------------------------


					If @ScriptMode in (1,3)
					   begin
						EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
					   end


					If @ScriptMode in (2,3)
					   begin
						Print @OutputScript
					   end


					SET	@OutputScript = ''

					--------------------------------------------
					-- LOG MESSAGE SUCCESS
					--------------------------------------------
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_SUCCESS'
						,@AdHocMsg=@lMsg
						,@ProcessGUID=@ProcessGUID
						,@SuppressRaiseError=1;
					--------------------------------------------
					--------------------------------------------


					--------------------------------------------
					IF @operation = 'REBUILD'
					BEGIN
						INSERT INTO @RebuiltIndexes	(DatabaseName,TableName,IndexName,Reason)
						VALUES				(@DatabaseName,@TableName,@IndexName,@lMsg)
					END
					IF @operation	= 'REORGANIZE'
					BEGIN
						SET	@lMsg = 'IdxReorgnz: ' + @lMsg
						INSERT INTO @ReorgedIndexes	(DatabaseName,TableName,IndexName,Reason)
						VALUES				(@DatabaseName,@TableName,@IndexName,@lMsg)
					END
				END -- Block to log warning if object can't be rebuilt online
				ELSE
				BEGIN
					SET @lMsg	= 'Mode: ' + CAST(@mode as VarChar(1)) + ' Frag: ' + cast(coalesce(@maxFragPercent,0) as nvarchar)
					IF @operation	= 'REBUILD'
					BEGIN
						SET	@lMsg = 'IdxRebuild: ' + @lMsg
						INSERT INTO @RebuiltIndexes	(DatabaseName,TableName,IndexName,Reason)
						VALUES				(@DatabaseName,@TableName,@IndexName,@lMsg)
					END
					IF @operation	= 'REORGANIZE'
					BEGIN
						SET	@lMsg = 'IdxReorgnz: ' + @lMsg
						INSERT INTO @ReorgedIndexes	(DatabaseName,TableName,IndexName,Reason)
						VALUES				(@DatabaseName,@TableName,@IndexName,@lMsg)
					END
				END

				SET @lMsg	= @databaseName + N': ' + coalesce(@sql,@operation)
				SET @cEMessage	='EVT_RDX'


				IF @operation in ('REORGANIZE','REBUILD') and @sql is null
				BEGIN
					-- we have hit an error if we don't have @sql populated at this point!
					SELECT @lMsg = @databaseName + N': Reindex job error. @sql variable set to null when it should not be!'
					RAISERROR(@lMsg,16,1) -- if we are in error, go to the catch block
				END

				IF @operation in ('REORGANIZE','REBUILD')
				   begin
					IF @operation = 'REORGANIZE'
					   begin
						Select @updatestats_flag = 'y'
					   end

					IF @ScriptMode=0
					BEGIN --Block for index rebuild
						--------------------------------------------
						-- LOG MESSAGE
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_START'
							,@ProcessGUID=@ProcessGUID
							,@AdHocMsg = @lMsg
						--------------------------------------------
						UPDATE	dbo.IndexMaintenancePhysicalStats
						SET	ActionTaken		= @sql
							,ActionStarted		= GetDate()
						WHERE	imPhysicalStatsId	= @imPhysicalStatsId
						--------------------------------------------


						SELECT @SQL
						--The action happens here.
						EXEC sp_executesql @sql


						--------------------------------------------
						-- LOG MESSAGE
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_SUCCESS'
							,@ProcessGUID=@ProcessGUID
							,@AdHocMsg = @lMsg
						--------------------------------------------
						UPDATE	dbo.IndexMaintenancePhysicalStats
						SET	ActionCompleted		= GetDate()
						WHERE	imPhysicalStatsId	= @imPhysicalStatsId
						--------------------------------------------


						--  Backup the tranlog if requested and needed
						If @page_count > @backup_tran_limit and @tranlog_bkp_flag_internal = 'y'
						   begin
							Select @page_count = 0
							Select @SQL = 'dbo.dbasp_Backup_Tranlog @DBName = ''' + rtrim(@databaseName) + ''''


							--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_TLOG_START'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @SQL


							SELECT @SQL
							--The action happens here.
							EXEC sp_executesql @sql


							--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_TLOG_END'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @SQL
						   end
					END --Block for index rebuild
					ELSE --  When @ScriptMode!=0 Generate Script for File and/or Screen.
					BEGIN
						--------------------------------------------
						-- LOG MESSAGE
						--------------------------------------------
						Set @lMsg = 'ScriptMode, Adding Entry For :' + @sql;
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_INFO'
							,@ProcessGUID=@ProcessGUID
							,@AdHocMsg = @lMsg


						--------------------------------------------
						--------------------------------------------
						-- ADD HEADER FOR INDEX
						--------------------------------------------
						--------------------------------------------
						SET	@indexScript = @indexScript
						+ ''+CHAR(13)+CHAR(10)
						+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
						+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
						+ '-- ' + QuoteName(@DatabaseName)+'.'+QUOTENAME(@TableName)+'.'+QUOTENAME(@IndexName)+CHAR(13)+CHAR(10)
						+ '-- ' +@operation+CHAR(13)+CHAR(10)
						If @maxFragPercent is not null and @save_maxpage_count is not null
						   begin
							SET @indexScript = @indexScript + '-- Avg Fragmentation: ' + convert(nvarchar(15), @maxFragPercent) + '%  Page Count: ' + convert(nvarchar(15), @save_maxpage_count) +CHAR(13)+CHAR(10)
						   end
						SET @indexScript = @indexScript
						+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)
						+ '----------------------------------------------------------------------------'+CHAR(13)+CHAR(10)

						SET	@OutputScript = @indexScript
						SET	@indexScript = ''


						--------------------------------------------
						-- LOG MESSAGE START
						--------------------------------------------
						SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_START'
							,@AdHocMsg=@lMsg
							,@ProcessGUID=@ProcessGUID
							,@SuppressRaiseError=1;
						--------------------------------------------
						--------------------------------------------


						If @ScriptMode in (1,3)
						   begin
							EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
						   end


						If @ScriptMode in (2,3)
						   begin
							Print @OutputScript
						   end


						SET	@OutputScript = ''

						--------------------------------------------
						-- LOG MESSAGE SUCCESS
						--------------------------------------------
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_SUCCESS'
							,@AdHocMsg=@lMsg
							,@ProcessGUID=@ProcessGUID
							,@SuppressRaiseError=1;
						--------------------------------------------
						--------------------------------------------


						--  Syntax for index maint work starts here
						SET	@indexScript = @indexScript + @save_declare_block +CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)


						--------------------------------------------
						--------------------------------------------
						-- GENERATE SCRIPT BLOCK
						--------------------------------------------
						--------------------------------------------
						+ COALESCE
							(
							'BEGIN'											+ CHAR(13)+CHAR(10)
							+'	-- LOG MESSAGE - START'								+ CHAR(13)+CHAR(10)
							+'	EXEC dbo.dbasp_LogMsg'							+ CHAR(13)+CHAR(10)
							+'		@ModuleName=''[dbasp_IndexMaintenance]'''				+ CHAR(13)+CHAR(10)
							+'		,@MessageKeyword=''' + @cEMessage + ''''				+ CHAR(13)+CHAR(10)
							+'		,@TypeKeyword=''EVT_START'''						+ CHAR(13)+CHAR(10)
							+'		,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
							+'		,@AdHocMsg ='''+@sql+''''						+ CHAR(13)+CHAR(10)
							+'	--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'	UPDATE	dbo.IndexMaintenancePhysicalStats'				+ CHAR(13)+CHAR(10)
							+'	SET	ActionTaken		= '''+@sql+''''					+ CHAR(13)+CHAR(10)
							+'		,ActionStarted		= GetDate()'					+ CHAR(13)+CHAR(10)
							+'	WHERE	imPhysicalStatsId	= '+ convert(nvarchar(15), @imPhysicalStatsId)	+ CHAR(13)+CHAR(10)
							+'	--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'	'										+ CHAR(13)+CHAR(10)

							+ REPLACE(			-- ALTER INDEX
								REPLACE(		-- REBUILD
									REPLACE(	-- REORGINIZE
										@sql
										,'REORGINIZE'
										,CHAR(13)+CHAR(10)+'	REORGINIZE')
									,'REBUILD'
									,CHAR(13)+CHAR(10)+'	REBUILD')
								,'ALTER INDEX'
								,CHAR(13)+CHAR(10)
								+'	PRINT ''	**'+ QuoteName(@DatabaseName)+'.'+QUOTENAME(@TableName)+'.'+QUOTENAME(@IndexName)+'**'''+ CHAR(13)+CHAR(10)
								+'	SELECT @ScreenMsg = ''	  Frag Before:	'' + CAST(max(avg_fragmentation_in_percent) AS VarChar(10)) +CHAR(13) + CHAR(10)'+ CHAR(13)+CHAR(10)
								+'			+''	  Index Type:	'' + max(index_type_desc) +CHAR(13) + CHAR(10)'+ CHAR(13)+CHAR(10)
								+'			+''	  Index Size:	'' + CAST(max(page_count) as VarChar(10))'+ CHAR(13)+CHAR(10)
								+'			+ '' Pages'' FROM sys.dm_db_index_physical_stats ('+CAST(DB_ID(@DatabaseName) AS VarChar(25))+', '+CAST(@tableObjectId AS VarChar(25))+ ', '+CAST(@indexId AS VarChar(25))+ ', NULL, ''' + @ips_mode + ''') ps'+ CHAR(13)+CHAR(10)
								+'	PRINT @ScreenMsg'							+ CHAR(13)+CHAR(10)
								+'	PRINT ''	'+ @operation +'ing...'''				+ CHAR(13)+CHAR(10)
								+'	RAISERROR('''', -1,-1) with nowait'					+ CHAR(13)+CHAR(10)
								+	CASE @AllowPageLocks
										WHEN 0 THEN	CHAR(13)+CHAR(10)+'	-- INDEX HAS ALLOW_PAGE_LOCKS TURNED OFF, TURNING ON BEFORE WORK'+CHAR(13)+CHAR(10)+'	ALTER INDEX [' +@IndexName+ N'] ON ['+@SchemaName+ N'].['+@TableName+ N'] SET (ALLOW_PAGE_LOCKS=ON); ' +CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
										ELSE '' END
								+'	ALTER INDEX'
								)
							+ CHAR(13)+CHAR(10)
							+	CASE @AllowPageLocks
									WHEN 0 THEN	CHAR(13)+CHAR(10)+'	-- INDEX HAD ALLOW_PAGE_LOCKS TURNED OFF, TURNING BACK OFF AFTER WORK'+CHAR(13)+CHAR(10)+'	ALTER INDEX [' +@IndexName+ N'] ON ['+@SchemaName+ N'].['+@TableName+ N'] SET (ALLOW_PAGE_LOCKS=OFF); ' +CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
									ELSE '' END
							+'	PRINT ''	DONE'''								+ CHAR(13)+CHAR(10)
							+'	SELECT @ScreenMsg = ''	  Frag After:'
							+'	'' + CAST(max(avg_fragmentation_in_percent) AS VarChar(10))'
							+' FROM sys.dm_db_index_physical_stats ('+CAST(DB_ID(@DatabaseName) AS VarChar(25))+', '+CAST(@tableObjectId AS VarChar(25))+', '+CAST(@indexId AS VarChar(25))+ ', NULL, ''' + @ips_mode + ''') ps'+ CHAR(13)+CHAR(10)
							+'	PRINT @ScreenMsg'								+ CHAR(13)+CHAR(10)
							+''											+ CHAR(13)+CHAR(10)
							+'	-- LOG MESSAGE - done'								+ CHAR(13)+CHAR(10)
							+'	--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'	EXEC dbo.dbasp_LogMsg'							+ CHAR(13)+CHAR(10)
							+'		@ModuleName=''[dbasp_IndexMaintenance]'''				+ CHAR(13)+CHAR(10)
							+'		,@MessageKeyword=''' + @cEMessage + ''''				+ CHAR(13)+CHAR(10)
							+'		,@TypeKeyword=''EVT_SUCCESS'''						+ CHAR(13)+CHAR(10)
							+'		,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
							+'		,@AdHocMsg ='''+@sql+''''						+ CHAR(13)+CHAR(10)
							+'	--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'	UPDATE	dbo.IndexMaintenancePhysicalStats'				+ CHAR(13)+CHAR(10)
							+'	SET	ActionCompleted		= GetDate()'					+ CHAR(13)+CHAR(10)
							+'	WHERE	imPhysicalStatsId	= '+ convert(nvarchar(15), @imPhysicalStatsId)	+ CHAR(13)+CHAR(10)
							+'	--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'END'											+ CHAR(13)+CHAR(10)
							,'-- NULL VALUE ERROR GENERATING SCRIPT BLOCK --'					+ CHAR(13)+CHAR(10)
							)											+ CHAR(13)+CHAR(10)

						SET	@OutputScript = @indexScript
						SET	@indexScript = ''


						--------------------------------------------
						-- LOG MESSAGE START
						--------------------------------------------
						SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_START'
							,@AdHocMsg=@lMsg
							,@ProcessGUID=@ProcessGUID
							,@SuppressRaiseError=1;
						--------------------------------------------
						--------------------------------------------

						Insert into dbo.IndexMaintenanceProcess (DBname, TBLname, MAINTsql, Status) values(@DatabaseName, @TableName, @OutputScript, 'pending')
						SET	@OutputScript = @OutputScript + +'GO' + CHAR(13)+CHAR(10)


						If @ScriptMode in (1,3)
						   begin
							EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
						   end


						If @ScriptMode in (2,3)
						   begin
							Print @OutputScript
						   end


						SET	@OutputScript = ''

						--------------------------------------------
						-- LOG MESSAGE SUCCESS
						--------------------------------------------
						--------------------------------------------
						EXEC [dbasp_LogMsg]
							@ModuleName=@cEModule
							,@MessageKeyword=@cEMessage
							,@TypeKeyword='EVT_SUCCESS'
							,@AdHocMsg=@lMsg
							,@ProcessGUID=@ProcessGUID
							,@SuppressRaiseError=1;
						--------------------------------------------
						--------------------------------------------


						--  Backup the tranlog if requested and needed
						If @page_count > @backup_tran_limit and @tranlog_bkp_flag_internal = 'y'
						   begin
							Select @page_count = 0
							SET @indexScript = @indexScript + '-- Process TranLog backup for database [' + @databaseName + ']' + CHAR(13)+CHAR(10)


							Select @SQL = 'dbo.dbasp_Backup_Tranlog @DBName = ''' + rtrim(@databaseName) + ''''


						   	--------------------------------------------
							-- LOG MESSAGE
							--------------------------------------------
							Set @lMsg = 'ScriptMode, Adding Entry For :' + @sql;
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_INFO'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @lMsg


							SET @indexScript = @indexScript + 'Print ''TranLog Backup for database [' + @databaseName + ']''' + CHAR(13)+CHAR(10)
							SET @indexScript = @indexScript + 'Exec ' + @sql				+ CHAR(13)+CHAR(10)
							SET @indexScript = @indexScript							+ CHAR(13)+CHAR(10)
							+'-- LOG MESSAGE - Tranlog Backup Processing'					+ CHAR(13)+CHAR(10)
							+'--------------------------------------------'					+ CHAR(13)+CHAR(10)
							+'EXEC dbo.dbasp_LogMsg'						+ CHAR(13)+CHAR(10)
							+'	 @ModuleName=''[dbasp_Backup_Tranlog]'''				+ CHAR(13)+CHAR(10)
							+'	,@MessageKeyword=''EVT_TLOG'''						+ CHAR(13)+CHAR(10)
							+'	,@TypeKeyword=''EVT_INFO'''						+ CHAR(13)+CHAR(10)
							+'	,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
							+'	,@AdHocMsg = ''' + replace(@sql, '''', '''''') + ''''			+ CHAR(13)+CHAR(10)


							SET	@OutputScript = @indexScript
							SET	@indexScript = ''


							--------------------------------------------
							-- LOG MESSAGE START
							--------------------------------------------
							SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_START'
								,@AdHocMsg=@lMsg
								,@ProcessGUID=@ProcessGUID
								,@SuppressRaiseError=1;
							--------------------------------------------
							--------------------------------------------

							Insert into dbo.IndexMaintenanceProcess (DBname, TBLname, MAINTsql, Status) values(@DatabaseName, @TableName, @OutputScript, 'pending')
							SET	@OutputScript = @OutputScript + 'GO' + CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)


							If @ScriptMode in (1,3)
							   begin
								EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
							   end


							If @ScriptMode in (2,3)
							   begin
								Print @OutputScript
							   end


							SET	@OutputScript = ''

							--------------------------------------------
							-- LOG MESSAGE SUCCESS
							--------------------------------------------
							--------------------------------------------
							EXEC [dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword='EVT_SUCCESS'
								,@AdHocMsg=@lMsg
								,@ProcessGUID=@ProcessGUID
								,@SuppressRaiseError=1;
							--------------------------------------------
							--------------------------------------------


						   end
					END
				   end


		END TRY -- Try block within cursor
		BEGIN CATCH -- Catch from Try block within cursor


			--------------------------------------------
			-- LOG MESSAGE
			--------------------------------------------
			SELECT @lMsg = N'try/catch: Reindex job failed against ['
					+ @databaseName + N'].[' + @tableName + '].[' + @indexName + N']! The error message given was: ' + ERROR_MESSAGE()
					+ N'. The error severity originally raised was: ' + cast(ERROR_SEVERITY() as nvarchar) + N'.'
			--------------------------------------------
			EXEC [dbasp_LogMsg]
 				@ModuleName=@cEModule
    				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_FAIL'
				,@AdHocMsg=@lMsg
				,@ProcessGUID=@ProcessGUID
				,@SuppressRaiseError=1 -- Don't raise error here, it wouldn't gracefully close the cursor.
			--------------------------------------------
			SET @lError=1 -- Flag an error now. In a few lines we'll determine if we should continue.


		END CATCH -- Catch from Try block within cursor

		--  save current table info
		Select @save_tableObjectId = @tableObjectId
			,@save_databaseName = @databaseName
			,@save_tableName = @tableName
			,@save_schemaName = @schemaName


		FETCH NEXT FROM TableCursor INTO @reindexId, @schemaName, @tableName, @tableObjectId, @indexId, @indexName, @AllowPageLocks, @totalPages, @indexSizeGB, @ReadPct, @Splits, @OrigFillFactor


		--Evaluate if we should continue on the next loop...
		IF @continueOnError = 0 and @lError=1
			SET @breakNow = 1;


		END --Block for WHILE @@FETCH_STATUS = 0 and @lError=0


		CLOSE TableCursor
		DEALLOCATE TableCursor


		-- Clean up rows in dbo.IndexMaintenancePhysicalStats  which are older than 1 week
		DELETE
		FROM dbo.IndexMaintenancePhysicalStats
		WHERE scan_started < getdate()-7


		BEGIN -- LOG IndexMaintenanceLastRunDetails
			--------------------------------------------
			-- LOG MESSAGE START
			--------------------------------------------
			SELECT @lMsg = N'CLEAR IndexMaintenanceLastRunDetails for ' + @DatabaseName
			--------------------------------------------
			EXEC [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_START'
				,@AdHocMsg=@lMsg
				,@ProcessGUID=@ProcessGUID
				,@SuppressRaiseError=1;
			--------------------------------------------
			--------------------------------------------


			-- REMOVE ALL ENTRIES FOR THIS DATABASE
			DELETE		dbo.IndexMaintenanceLastRunDetails
			WHERE		DatabaseName = @DatabaseName


			--------------------------------------------
			-- LOG MESSAGE SUCCESS
			--------------------------------------------
			--------------------------------------------
			EXEC [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_SUCCESS'
				,@AdHocMsg=@lMsg
				,@ProcessGUID=@ProcessGUID
				,@SuppressRaiseError=1;
			--------------------------------------------
			--------------------------------------------


			--------------------------------------------
			--------------------------------------------
			-- LOG MESSAGE START
			--------------------------------------------
			SELECT @lMsg = N'Log to IndexMaintenanceLastRunDetails'
			--------------------------------------------
			EXEC [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_START'
				,@AdHocMsg=@lMsg
				,@ProcessGUID=@ProcessGUID
				,@SuppressRaiseError=1;
			--------------------------------------------
			--------------------------------------------

			-- ADD ENTRIES FROM THIS RUN
			INSERT INTO	dbo.IndexMaintenanceLastRunDetails
			SELECT		DatabaseName
					,TableName
					,IndexName
					,'Excluded' Process
					,Reason
					,getdate()
			FROM		@ExcludedIndexes
			UNION
			SELECT		DatabaseName
					,TableName
					,IndexName
					,'Skiped' Process
					,Reason
					,getdate()
			FROM		@SkipedIndexes
			UNION
			SELECT		DatabaseName
					,TableName
					,IndexName
					,'Skiped' Process
					,Reason
					,getdate()
			FROM		@LimitSkipedIndexes
			UNION
			SELECT		DatabaseName
					,TableName
					,IndexName
					,'Reorgonize' Process
					,Reason
					,getdate()
			FROM		@ReorgedIndexes
			UNION
			SELECT		DatabaseName
					,TableName
					,IndexName
					,'Rebuild' Process
					,Reason
					,getdate()
			FROM		@RebuiltIndexes
			ORDER BY	1,2,3

			--------------------------------------------
			-- LOG MESSAGE SUCCESS
			--------------------------------------------
			--------------------------------------------
			EXEC [dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_SUCCESS'
				,@AdHocMsg=@lMsg
				,@ProcessGUID=@ProcessGUID
				,@SuppressRaiseError=1;
			--------------------------------------------
			--------------------------------------------
		END




		BEGIN	-- PRINT SUMMARY

			SET	@SummaryVCHR = ''
			SELECT	@SummaryVCHR = @SummaryVCHR
				+ '--	'
				+ CAST('Excluded' AS CHAR(15))
				+ LEFT(Reason,11)
				+ CAST(count(*) AS CHAR(10))
				+ CHAR(13) + CHAR(10)
			FROM	@ExcludedIndexes
			GROUP BY LEFT(Reason,11)

			SELECT	@SummaryVCHR = @SummaryVCHR
				+ '--	'
				+ CAST('Skiped' AS CHAR(15))
				+ LEFT(Reason,11)
				+ CAST(count(*) AS CHAR(10))
				+ CHAR(13) + CHAR(10)
			FROM	@SkipedIndexes
			GROUP BY LEFT(Reason,11)


			SELECT	@SummaryVCHR = @SummaryVCHR
				+ '--	'
				+ CAST('Skiped' AS CHAR(15))
				+ LEFT(Reason,11)
				+ CAST(count(*) AS CHAR(10))
				+ CHAR(13) + CHAR(10)
			FROM	@LimitSkipedIndexes
			GROUP BY LEFT(Reason,11)


			SELECT	@SummaryVCHR = @SummaryVCHR
				+ '--	'
				+ CAST('Reorgonized' AS CHAR(15))
				+ LEFT(Reason,11)
				+ CAST(count(*) AS CHAR(10))
				+ CHAR(13) + CHAR(10)
			FROM	@ReorgedIndexes
			GROUP BY LEFT(Reason,11)

			SELECT	@SummaryVCHR = @SummaryVCHR
				+ '--	'
				+ CAST('Rebuilt' AS CHAR(15))
				+ LEFT(Reason,11)
				+ CAST(count(*) AS CHAR(10))
				+ CHAR(13) + CHAR(10)
			FROM	@RebuiltIndexes
			GROUP BY LEFT(Reason,11)


			--  One last call for update stats if any tables were processed
			If @updatestats_flag = 'y'
			  and (select count(*) FROM @ReorgedIndexes) > 0
			   begin
				Set @updatestats_flag = 'n'


				Select @sql = 'dbo.dbasp_IndexUpdateStats @databaseName = ''' + @databaseName + ''', @schemaName = ''' + @schemaName + ''', @tableName = ''' + @tableName + ''', @ProcessGUID = ''' + convert(nvarchar(50), @ProcessGUID) + ''', @ScriptMode = 0'
			  	IF @ScriptMode=0
				BEGIN --Block for update stats
					--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_START'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg


					SELECT @SQL
					--The action happens here.
					EXEC sp_executesql @sql


					--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_SUCCESS'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg


				END --Block for update stats
				Else
				BEGIN --Script update stats
				   	--------------------------------------------
					-- LOG MESSAGE
					--------------------------------------------
					Set @lMsg = 'ScriptMode, Adding Entry For :' + @sql;
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_INFO'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg


					SET @indexScript = @indexScript + '--  UPDATE STATS for ' + @databaseName + '.' + @schemaName + '.' + @tableName + CHAR(13)+CHAR(10)
					SET @indexScript = @indexScript + 'Print ''Updates Stats for ' + @databaseName + '.' + @schemaName + '.' + @tableName + '''' + CHAR(13)+CHAR(10)
					SET @indexScript = @indexScript + 'Exec ' + @sql				+ CHAR(13)+CHAR(10)
					SET @indexScript = @indexScript							+ CHAR(13)+CHAR(10)
					+'-- LOG MESSAGE - Update Stats'						+ CHAR(13)+CHAR(10)
					+'--------------------------------------------'					+ CHAR(13)+CHAR(10)
					+'EXEC dbo.dbasp_LogMsg'						+ CHAR(13)+CHAR(10)
					+'	 @ModuleName=''[dbasp_IndexUpdatestats]'''				+ CHAR(13)+CHAR(10)
					+'	,@MessageKeyword=''EVT_UDS'''						+ CHAR(13)+CHAR(10)
					+'	,@TypeKeyword=''EVT_INFO'''						+ CHAR(13)+CHAR(10)
					+'	,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
					+'	,@AdHocMsg = ''' + replace(@sql, '''', '''''') + ''''			+ CHAR(13)+CHAR(10)


					SET	@OutputScript = @indexScript
					SET	@indexScript = ''


					--------------------------------------------
					-- LOG MESSAGE START
					--------------------------------------------
					SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_START'
						,@AdHocMsg=@lMsg
						,@ProcessGUID=@ProcessGUID
						,@SuppressRaiseError=1;
					--------------------------------------------
					--------------------------------------------

					Insert into dbo.IndexMaintenanceProcess (DBname, TBLname, MAINTsql, Status) values(@databaseName, @tableName, @OutputScript, 'pending')
					SET	@OutputScript = @OutputScript + 'GO' + CHAR(13)+CHAR(10)


					If @ScriptMode in (1,3)
					   begin
						EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
					   end


					If @ScriptMode in (2,3)
					   begin
						Print @OutputScript
					   end


					SET	@OutputScript = ''

					--------------------------------------------
					-- LOG MESSAGE SUCCESS
					--------------------------------------------
					--------------------------------------------
					EXEC [dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_SUCCESS'
						,@AdHocMsg=@lMsg
						,@ProcessGUID=@ProcessGUID
						,@SuppressRaiseError=1;
					--------------------------------------------
					--------------------------------------------
				   END
			   end

			SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '-------------------------------------------------------------' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '-------------------------------------------------------------' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '--  MAINTENANCE SUMMARY FOR DB: [' + @databaseName + ']' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '-------------------------------------------------------------' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '--	' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + @SummaryVCHR
			SET	@OutputScript = @OutputScript + '--	' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '-------------------------------------------------------------' + CHAR(13)+CHAR(10)
			SET	@OutputScript = @OutputScript + '-------------------------------------------------------------' + CHAR(13)+CHAR(10)
		END

		SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--==========================================================================' + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--  	\/   SCRIPT START FOR DB: [' + @databaseName + ']   \/' + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--==========================================================================' + CHAR(13)+CHAR(10)

		SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)


		--------------------------------------------
		-- LOG MESSAGE START
		--------------------------------------------
		SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_START'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------


		If @ScriptMode in (1,3)
		   begin
			EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
		   end


		If @ScriptMode in (2,3)
		   begin
			Print @OutputScript
		   end


		SET	@OutputScript = ''

		--------------------------------------------
		-- LOG MESSAGE SUCCESS
		--------------------------------------------
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_SUCCESS'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------


		--  One last tranlog backup and shrink if the DB is in full recovery mode
		If @tranlog_bkp_flag_internal = 'y'
		   and ((select count(*) FROM @ReorgedIndexes) > 0 or (select count(*) FROM @RebuiltIndexes) > 0)
		   begin
			IF @ScriptMode=0
			   begin
				Select @SQL = 'dbo.dbasp_ShrinkLDFFiles @DBname @DBName = ''' + rtrim(@databaseName) + ''''
				--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName='[dbasp_ShrinkLDFFiles]'
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_TLOG_START'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @SQL


				SELECT @SQL
				--The action happens here.
				EXEC sp_executesql @sql


				--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName='[dbasp_ShrinkLDFFiles]'
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_TLOG_END'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @SQL
			   end
			Else
			   begin
				SET @indexScript = '-- Process Shrink LDF Files for database [' + @databaseName + ']' + CHAR(13)+CHAR(10)


				Select @SQL = 'dbo.dbasp_ShrinkLDFFiles @DBName = ''' + rtrim(@databaseName) + ''''


			   	--------------------------------------------
				-- LOG MESSAGE
				--------------------------------------------
				Set @lMsg = 'ScriptMode, Adding Entry For :' + @sql;
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName='[dbasp_ShrinkLDFFiles]'
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_INFO'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg


				SET @indexScript = @indexScript + 'Print ''Shrink LDF Files for database [' + @databaseName + ']''' + CHAR(13)+CHAR(10)
				SET @indexScript = @indexScript + 'Exec ' + @sql				+ CHAR(13)+CHAR(10)
				SET @indexScript = @indexScript							+ CHAR(13)+CHAR(10)
				+'-- LOG MESSAGE - Tranlog Backup Processing'					+ CHAR(13)+CHAR(10)
				+'--------------------------------------------'					+ CHAR(13)+CHAR(10)
				+'EXEC dbo.dbasp_LogMsg'						+ CHAR(13)+CHAR(10)
				+'	 @ModuleName=''[dbasp_ShrinkLDFFiles]'''				+ CHAR(13)+CHAR(10)
				+'	,@MessageKeyword=''EVT_TLOG'''						+ CHAR(13)+CHAR(10)
				+'	,@TypeKeyword=''EVT_INFO'''						+ CHAR(13)+CHAR(10)
				+'	,@ProcessGUID=''' + convert(nvarchar(40), @ProcessGUID) + ''''		+ CHAR(13)+CHAR(10)
				+'	,@AdHocMsg = ''' + replace(@sql, '''', '''''') + ''''			+ CHAR(13)+CHAR(10)


				SET @OutputScript = @OutputScript + @indexScript
				SET @indexScript = ''


				--------------------------------------------
				-- LOG MESSAGE START
				--------------------------------------------
				SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_START'
					,@AdHocMsg=@lMsg
					,@ProcessGUID=@ProcessGUID
					,@SuppressRaiseError=1;
				--------------------------------------------
				--------------------------------------------

				Insert into dbo.IndexMaintenanceProcess (DBname, TBLname, MAINTsql, Status) values(@save_databaseName, null, @OutputScript, 'pending')
				SET @OutputScript = @OutputScript + 'GO' + CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)


				If @ScriptMode in (1,3)
				   begin
					EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
				   end


				If @ScriptMode in (2,3)
				   begin
					Print @OutputScript
				   end


				SET	@OutputScript = ''

				--------------------------------------------
				-- LOG MESSAGE SUCCESS
				--------------------------------------------
				--------------------------------------------
				EXEC [dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_SUCCESS'
					,@AdHocMsg=@lMsg
					,@ProcessGUID=@ProcessGUID
					,@SuppressRaiseError=1;
				--------------------------------------------
				--------------------------------------------
			   end
		   end


		SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--==========================================================================' + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--  	/\	SCRIPT END FOR DB: [' + @databaseName + ']	/\' + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + '--==========================================================================' + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)
		SET	@OutputScript = @OutputScript + CHAR(13)+CHAR(10)


		--------------------------------------------
		-- LOG MESSAGE START
		--------------------------------------------
		SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_START'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------


		If @ScriptMode in (1,3)
		   begin
			EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
		   end


		If @ScriptMode in (2,3)
		   begin
			Print @OutputScript
		   end


		SET	@OutputScript = ''

		--------------------------------------------
		-- LOG MESSAGE SUCCESS
		--------------------------------------------
		--------------------------------------------
		EXEC [dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_SUCCESS'
			,@AdHocMsg=@lMsg
			,@ProcessGUID=@ProcessGUID
			,@SuppressRaiseError=1;
		--------------------------------------------
		--------------------------------------------


		--  Clear out the tables for the next DB
		delete from @ExcludedIndexes
		delete from @SkipedIndexes
		delete from @LimitSkipedIndexes
		delete from @ReorgedIndexes
		delete from @RebuiltIndexes

		SET @save_tableObjectId = NULL


		--  check for more row to process
		delete from @tvar_dbnames where dbname = @databaseName
		If (select count(*) from @tvar_dbnames) > 0
		   begin
			goto start_dbname
		   end
	   end


END TRY -- Outer Try block


BEGIN CATCH -- Catch from outer Try block
	--------------------------------------------
	-- LOG MESSAGE
	--------------------------------------------
	SELECT @lMsg = N'try/catch: Reindex job failed against database ['
			+ @databaseName + N']! The error message given was: ' + ERROR_MESSAGE()
			+ N'. The error severity originally raised was: ' + cast(ERROR_SEVERITY() as nvarchar) + N'.'
	--------------------------------------------
	EXEC [dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_FAIL'
		,@AdHocMsg=@lMsg
		,@ProcessGUID=@ProcessGUID
		,@SuppressRaiseError=1;
	--------------------------------------------
	--------------------------------------------
	SET @lError=1 -- Flag an error.


END CATCH -- Catch from outer Try block


SET @OutputScript = @OutputScript + 'Print ''Ending SQL Index Maintenance Process '' + convert(varchar(30),getdate(),9)' + CHAR(13)+CHAR(10)


--  Finish up  ----------------------------------------------------------------------------------------------------------------
label99:


--------------------------------------------
-- WRITE SCRIPT TO FILE
--------------------------------------------
If @ScriptMode IN (1,3)
BEGIN
	--------------------------------------------
	-- LOG MESSAGE START
	--------------------------------------------
	SELECT @lMsg = N'Write Script to File ' + @Path + '\' + @Filename
	--------------------------------------------
	EXEC [dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_START'
		,@AdHocMsg=@lMsg
		,@ProcessGUID=@ProcessGUID
		,@SuppressRaiseError=1;
	--------------------------------------------
	--------------------------------------------


	If @ScriptMode in (1,3)
	   begin

		EXEC DBAOps.[dbo].[dbasp_FileAccess_Write] @OutputScript,@PathAndFile,1,1
	   end

	--------------------------------------------
	-- LOG MESSAGE SUCCESS
	--------------------------------------------
	--------------------------------------------
	EXEC [dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_SUCCESS'
		,@AdHocMsg=@lMsg
		,@ProcessGUID=@ProcessGUID
		,@SuppressRaiseError=1;
	--------------------------------------------
	--------------------------------------------
END


-- OUTPUT SCRIPT TO WINDOW AFTER EVERYTHING ELSE
If @ScriptMode In (2,3)
BEGIN
	SET @Marker1 = 0


	PrintMore:


	SET @Marker2 = CHARINDEX(CHAR(10),@OutputScript,@Marker1 + 7000)
	IF @Marker2 = 0
	   begin
		SET @Marker2 = LEN(@OutputScript)
	   end


	SET @OutputString = SUBSTRING(@OutputScript,@Marker1,@Marker2-@Marker1)
	PRINT @OutputString


	SET @Marker1 = @Marker2 + 1


	If @Marker2 < LEN(@OutputScript)
	   begin
		GOTO PrintMore
	   end
END


--------------------------------------------
-- LOG MESSAGE
--------------------------------------------
IF @lError=0
BEGIN
	SET @lMsg=@databaseName + N': IndexMaintenance completed ' + CASE @ScriptMode when 1 then 'in Script mode (scan only, all reindexing to Script '+@Path+'\'+@Filename+').' END
	SET @lEType='EVT_SUCCESS'
END
ELSE
BEGIN
	SET @lEType='EVT_FAIL'


	EXEC [dbasp_LogMsg]
		@ModuleName		=@cEModule
		,@MessageKeyword	=@cEMessage
		,@TypeKeyword		=@lEType
		,@AdHocMsg		=@lMsg
		,@ProcessGUID		=@ProcessGUID
		,@SuppressRaiseError	=1;
END


--------------------------------------------
IF @lEType='EVT_FAIL'
	RAISERROR (@lMsg,16,1)WITH LOG;
--------------------------------------------


show_example:
--------------------------------------------
-- EXEC EXAMPLE
--------------------------------------------
--  Print out sample exection of this sproc
If @ScriptMode in (2,3) and @example_flag = 'y'
   begin
	Print  ' '
	Select @miscprint = '--Here is a sample execute command for this sproc:'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'exec dbo.dbasp_IndexMaintenance @fragThreshold = 8                  -- Min fragmentation to process'
	Print  @miscprint
	Select @miscprint = '                                 ,@RebuildThreshold = 30                     -- Cut off for reorg vs rebuild'
	Print  @miscprint
	Select @miscprint = '                                 ,@usesOnlineReindex = 1                     -- 0=''n'' 1=''y'''
	Print  @miscprint
	Select @miscprint = '                                 ,@mode = 3                                  -- 0=''rebuild'', 1=''rebuild online-only'',, 2=''reorg-only'', 3=''auto'''
	Print  @miscprint
	Select @miscprint = '                                 ,@ScriptMode = 3                            -- 0=''exec now'', 1=''file'', 2=''screen'', 3=''file/screen'''
	Print  @miscprint
	Select @miscprint = '                                 ,@PlanName = ''mplan_user_defrag''            -- Use This Maintenance Plan''auto'''
	Print  @miscprint
	Select @miscprint = '                                 --,@databaseName = ''wcds''                   -- For Single Database'
	Print  @miscprint
	Select @miscprint = '                                 --,@Path = ''d:\folder''                      -- NULL will send file to the dbasql share'
	Print  @miscprint
	Select @miscprint = '                                 --,@Filename = ''IndexMaintenanceScript.sql'' -- This is the default output filename'
	Print  @miscprint
	Select @miscprint = '                                 ,@fillFactor_HighRead = 100                 -- Used on REBUILDS when Read Percentage > 60%'
	Print  @miscprint
	Select @miscprint = '                                 ,@fillFactor_LowRead = 80                   -- Used on REBUILDS when Read Precentage < 30%'
	Print  @miscprint
	Select @miscprint = '                                 ,@fillFactor = 90                           -- Used on REBUILDS when neither high or low apply'
	Print  @miscprint
	Select @miscprint = '                                 ,@Limit_flag = ''n''                          -- Limit the number of large tables processed'
	Print  @miscprint
	Select @miscprint = '                                 ,@Limit_large_table_count = 5               -- Determines the number of large tables that will be processed'
	Print  @miscprint
	Select @miscprint = '                                 ,@Set_large_table_page_count = 80000        -- Determines the minimum size in pages for a large table'
	Print  @miscprint
	Select @miscprint = '                                 ,@minPages = 500                            -- Min pages for an index to be eligible'
	Print  @miscprint
	Select @miscprint = '                                 ,@maxIndexLevelToConsider = 0               -- 0=''leaf level only'', 1=''leaf + index_level 1'',, 2=''etc.'''
	Print  @miscprint
	Select @miscprint = '                                 ,@sortInTempDb = 1                          -- 0=''sort in user db'', 1=''sort in tempdb'''
	Print  @miscprint
	Select @miscprint = '                                 ,@tranlog_bkp_flag = ''y''                    -- periodic tranlog backup for full recovery databases.'
	Print  @miscprint
	Select @miscprint = '                                 ,@continueOnError = 1                       -- 0=''stop on error'', 1=''reindex other tables after catching an error'''
	Print  @miscprint
	Print  ' '
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_IndexMaintenance] TO [public]
GO
