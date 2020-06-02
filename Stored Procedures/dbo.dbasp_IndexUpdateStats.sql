SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_IndexUpdateStats]
	(
	@databaseName			sysname				= NULL
	,@SchemaName			sysname				= NULL
	,@TableName				sysname				= NULL
	,@IndexName				sysname				= NULL
	,@sampling				int					= 0
	,@noRecompute			bit					= 0
	,@updateStatsSinceDays	float				= 0
	,@rowsUpdatedThreshold	int					= 2000
	,@ScriptMode			bit					= 1
	,@ScreenOutput			bit					= 1
	,@FileOutput			bit					= 0
	,@OutputSkiped			bit					= 0
	,@Path					VarChar(8000)		= NULL
	,@FileName				VarChar(1024)		= NULL
	,@Output				VarChar(max)		= NULL OUT
	,@ProcessGUID			uniqueidentifier	= NULL
	)


/***************************************************************
 **  Stored Procedure dbasp_IndexUpdateStats
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 28, 2010
 **
 **
 **  Description: Updates statistics against a database.
 **
 **
 **  This proc accepts the following input parameters:
 **
 **	@databaseName		The Database to Limit Updates for.
 **	@SchemaName		The Schema to Limit Updates for.
 **	@TableName		The Table to Limit Updates for.
 **	@IndexName		The Index to Limit Updates for.
 **
 **	Database,Schema,Table, and Index Filters are accumulative. Any Values Left NULL are not used to Filter
 **
 **	@sampling		Set to 100 for fullscan (longer runtime/higher IO/metadata locks). 0 =default sampling. 1-100 will use percentage sampling.
 **	@noRecompute		Set to 1 to cause statistics to not be automatically updated by SQL Server-- use with caution.
 **	@updateStatsSinceDays	Use to ignore statistics if they have been updated in the given number of days
 **	@rowsUpdatedThreshold	Set to -1 to ignore. Defaults to updating where > 2K rows have been changed in a statistic on the table.
 **
 **	@ScriptMode		Set to 1 to Output Scripts but not execute them.
 **
 **	The Following Parameters are only relivent if @ScriptMode=1
 **
 **	@ScreenOutput		Set to 1 to Output Script to the Screen
 **	@FileOutput		Set to 1 to Output Script to a File
 **	@Path			The Path Used if @ScriptMode=1 AND @FileOutput=1 ** DO NOT END IT WITH A SLASH **
 **	@FileName		The File Name Used if @ScriptMode=1 AND @FileOutput=1
 **	@OutputSkiped		Set to 1 to Include Comments on Skiped Updates.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	2010-04-28	SteveL			Created
--	2010-07-15	Steve Ledridge		Modified view for specific DB if specified.
--	2010-08-11	Steve Ledridge		Added brackets for DBname in sp_msforeachdb exec.
--	2011-10-14	Steve Ledridge		Moved the Maintenance of the AllDBView's to external sproc.
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	======================================================================================


/***
-------------------------------------------------------
-- U N C O M M E N T   T O   T E S T   L O C A L L Y --
-------------------------------------------------------


DECLARE	@databaseName		sysname
	,@SchemaName		sysname
	,@TableName		sysname
	,@IndexName		sysname
	,@sampling		int
	,@noRecompute		bit
	,@updateStatsSinceDays	float
	,@rowsUpdatedThreshold	int
	,@ScriptMode		bit
	,@ScreenOutput		bit
	,@FileOutput		bit
	,@OutputSkiped		bit
	,@Path			VarChar(8000)
	,@FileName		VarChar(1024)
	,@Output		VarChar(max)
	,@ProcessGUID		uniqueidentifier

SELECT	@databaseName		= 'WCDS'
	,@SchemaName		= 'dbo'
	,@TableName		= 'Download'
	,@IndexName		= NULL
	,@sampling		= 0
	,@noRecompute		= 0
	,@updateStatsSinceDays	= 0
	,@rowsUpdatedThreshold	= 2000
	,@ScriptMode		= 0
	,@ScreenOutput		= 0
	,@FileOutput		= 0
	,@Path			= NULL
	,@FileName		= NULL
	,@OutputSkiped		= 0


-- ***/


DECLARE		@TSQL				varchar(max)
		,@S				sysname
		,@T				sysname
		,@qualifiedTableName		nvarchar(1000)
		,@IndexId			int
		,@databaseId			int
		,@objectId			int
		,@updateStatsCommand		nvarchar(256)
		,@getStatisticsItems		nvarchar(max)
		,@pullScheduleObjectsSQL	nvarchar(max)


		-- Finds # of days since last update using stats_date(object_id, index_id)
		,@daysSinceStatsLastUpdated	float
		-- Max rows last modified in the table on any index from sys.sysindexes. Depreciated but still works.
		,@rowModCtr			int


		,@startTime			datetime
		,@endTime			datetime
		,@exclusionId			tinyint
		,@maxExclusionId		tinyint
		,@exclusionItem			nvarchar(2000)
		,@samplingId			tinyint
		,@maxSamplingId			tinyint
		,@samplingItem			nvarchar(2000)
		,@samplingRateException		tinyint
		,@noRecomputeException		bit
		,@rowcount			bigint
		,@OutputString			VarChar(8000)
		,@LastDB			sysname
		,@MaxCmdLength			INT

DECLARE		-- evt variables
		@cEModule sysname
		,@cEMessage varchar(32)
		,@lEType varchar(16)
		,@lMsg nvarchar(max)
		,@lError bit
		,@Diagnose bit
		,@lRunSpec xml
		,@typeKeyword nvarchar(25);


DECLARE		@exclusionTable table (
		exclusionId tinyint identity primary key -- using tinyint on purpose: let's not support more than 255 exclusions
		,schemaName sysname
		,tableName sysname
		)


DECLARE		@samplingTable table (
		samplingId tinyint identity primary key -- using tinyint on purpose: let's not support more than 255 exclusions
		,schemaName sysname
		,tableName sysname
		,samplingRate tinyint
		,[noRecompute] bit default 0
		)


-------------------------------------------------------
--  NEED TO USE A TEMP TABLE TO AGGREGATE STATS_DATE --
-------------------------------------------------------


IF OBJECT_ID('tempdb..#StatsTimes') IS NOT NULL
    DROP TABLE #StatsTimes

CREATE TABLE	#StatsTimes
		(
		database_id	int
		, object_id	bigint
		, stats_id	bigint
		, StatsDate	datetime
		);


exec	sp_msforeachdb 'Use [?];INSERT INTO #StatsTimes SELECT DB_ID(),object_id,stats_id,STATS_DATE(object_id,stats_id) FROM sys.stats where auto_created | user_created = 1'

-------------------------------------------------------
--        REBUILD ALL ALLDB VIEWS BEFORE USED        --
-------------------------------------------------------
EXEC	dbo.dbasp_CreateAllDBViews


-------------------------------------------------------
--      S E T    S T A R T I N G    V A L U E S      --
-------------------------------------------------------


SELECT		@cEModule=N'[dbo].[dbasp_IndexUpdateStats]'
		, @cEMessage='EVT_STX'
		, @lError=0
		, @Diagnose=1
		, @Output = ''
		, @lMsg	= NULL


If @ProcessGUID IS NULL
BEGIN
	SET @ProcessGUID=newid()
	--Log start of run to EVT
	SET @lMsg = @@ServerName + N': Starting statistics maintenance'
		+ case @ScriptMode when 1 then N' in test mode' else '' end
		+ N'. Sampling is ' + case @sampling when 0 then N' default ' ELSE CAST(@sampling as nvarchar(3)) + '% ' end + N' (where exceptions not defined).'
		+ N' Norecompute is ' + case @noRecompute when 0 then 'off.' else 'on.' end;


	EXEC [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_START'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose


	SET @lMsg = '@ProcessGUID: Using Generated Proccess GUID.'
	EXEC [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_INFO'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose
END
ELSE
BEGIN
	--Log start of run to EVT
	SET @lMsg = @@ServerName + N': Starting statistics maintenance'
		+ case @ScriptMode when 1 then N' in test mode' else '' end
		+ N'. Sampling is ' + case @sampling when 0 then N' default ' ELSE CAST(@sampling as nvarchar(3)) + '% ' end + N' (where exceptions not defined).'
		+ N' Norecompute is ' + case @noRecompute when 0 then 'off.' else 'on.' end;


	EXEC [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_START'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose

	SET @lMsg = '@ProcessGUID: Using Proccess GUID Passed to Procedure.'
	EXEC [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_INFO'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose
END


BEGIN TRY -- Outer Try block
	-------------------------------------------------------
	--  R A I S E   A L L   W A R N I N G S   F I R S T  --
	-------------------------------------------------------

		SET	@lMsg	= CASE
				WHEN	@databaseName IS NOT NULL
				 AND	@databaseName NOT IN (SELECT [name] FROM sys.databases WITH(nolock))
					THEN '@databaseName: DB NAME WAS SPECIFIED BUT NOT ACCURATE'
				WHEN	coalesce(@ScriptMode,-1) not in (0,1)
					THEN '@ScriptMode: Parameter is Invalid'
				WHEN	coalesce(@noRecompute,-1) not in (0,1)
					THEN '@noRecompute: Parameter is Invalid'
				WHEN	coalesce(@rowsUpdatedThreshold,-2) < -1
					THEN '@rowsUpdatedThreshold: Parameter is Invalid'
				WHEN	@sampling not between 0 and 100
					THEN '@sampling: Parameter is Invalid'
				ELSE	NULL END

		IF @lMsg IS NOT NULL
		BEGIN --Error out if the  parameters don't make sense.
			exec [dbo].[dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_FAIL'
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
				,@Diagnose=@Diagnose
				,@SuppressRaiseError=1;
		RAISERROR (@lMsg,16,1)WITH LOG;
		END


	IF Exists (select * From dbo.vw_AllDB_stats where no_recompute = 1) -- DEFAULT IS 0
	BEGIN
		SET @lMsg = 'NoRecompute: One or More Statistics are set to NoRecompute.'
		exec [dbo].[dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_FAIL'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
			,@Diagnose=@Diagnose
			,@SuppressRaiseError=1;
	END


	IF Exists (select * From sys.databases where is_auto_create_stats_on = 0) -- DEFAULT IS 1
	BEGIN
		SET @lMsg = 'Auto_Create_Stats: is turned off on one or more databases.'
		exec [dbo].[dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_FAIL'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
			,@Diagnose=@Diagnose
			,@SuppressRaiseError=1;
	END


	IF Exists (select * From sys.databases where is_auto_update_stats_on = 0) -- DEFAULT IS 1
	BEGIN
		SET @lMsg = 'Auto_update_stats: is turned off on one or more databases.'
		exec [dbo].[dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_FAIL'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
			,@Diagnose=@Diagnose
			,@SuppressRaiseError=1;
	END


	IF Exists (select * From sys.databases where is_auto_update_stats_async_on = 1) -- DEFAULT IS 0
	BEGIN
		SET @lMsg = 'Auto_update_stats_async: is turned on on one or more databases.'
		exec [dbo].[dbasp_LogMsg]
			@ModuleName=@cEModule
			,@MessageKeyword=@cEMessage
			,@TypeKeyword='EVT_FAIL'
			,@ProcessGUID=@ProcessGUID
			,@AdHocMsg = @lMsg
			,@Diagnose=@Diagnose
			,@SuppressRaiseError=1;
	END


	SET @lMsg = 'Cursor: Getting tables with qualifying statistics.'
	EXEC [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_INFO'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose


	SELECT		@MaxCmdLength	=   MAX(LEN(N'[' + sc.[name] + N']'+ N'.'+ N'[' + ob.[name] + N']'))+ 45
	FROM		dbo.vw_AllDB_objects ob
	JOIN		dbo.vw_AllDB_schemas sc
		ON	ob.[database_name]	= sc.[database_name]
		AND	ob.schema_id		= sc.schema_id
	WHERE		(ob.type = 'U' or ob.type = 'V')
		AND	(ob.[database_name]	= @DatabaseName	or @DatabaseName is NULL)
		AND	(sc.[name]		= @SchemaName	or @SchemaName is NULL)
		AND	(ob.[name]		= @TableName	or @TableName is NULL)


	DECLARE updatestatscursor CURSOR
	FOR


	--This query will return tables and indexed views from the target database.
	--It uses the STATS_DATE() function to check the last time statistics were updated on the object.
	--The rowmodctr column tracks the number of changes that have occurred since the last statistics update.


	SELECT		[DatabaseName]
			, [objectId]
			, N'[' + schemaName + N']'+ N'.'+ N'[' + tableName+ N']' AS qualifiedTableName
			, [IndexId]
			, NULL AS [IndexName]
			, [daysSinceStatsLastUpdated]
			, [rowModCtr]
			, [sampling]
			, [noRecompute]
	FROM		(
			SELECT		ob.[database_name]		AS [DatabaseName]
					,sc.[name]			AS [schemaName]
					,ob.[object_id]			AS [ObjectId]
					,ob.[name]			AS [tableName]
					,min(COALESCE(ss.[stats_id],0))		AS [IndexId]
					,min(COALESCE(datediff(hh
						,coalesce(ss.StatsDate,ob.create_date)
						,getdate()
						)/24.000,0))		AS [daysSinceStatsLastUpdated]

					,max(coalesce(si.rowmodctr, 0))	AS [rowmodctr]
					,@sampling			AS [sampling]
					,@noRecompute			AS [noRecompute]


			FROM		dbo.vw_AllDB_objects ob
			JOIN		dbo.vw_AllDB_schemas sc
				ON	ob.[database_name]	= sc.[database_name]
				AND	ob.schema_id		= sc.schema_id


			LEFT JOIN	#StatsTimes ss
				ON	ob.[database_id]	= ss.[database_id]
				AND	ob.[object_id]		= ss.[object_id]


			LEFT join	dbo.vw_AllDB_sysindexes si		-- get rowmodctr from this table
				ON	ss.[database_id]	= si.[database_id]
				AND	ss.[object_id]		= si.id
				AND	ss.stats_id		= si.indid


			LEFT JOIN		dbo.vw_AllDB_indexes i
				ON	si.[database_id]	= i.[database_id]
				AND	si.id			= i.[object_id]
				AND	si.indid		= i.index_id


			WHERE		(ob.type = 'U' or (ob.type = 'V' and i.type_desc <> 'HEAP'))
				AND	(ob.[database_name]	= @DatabaseName	or @DatabaseName is NULL)
				AND	(sc.[name]		= @SchemaName	or @SchemaName is NULL)
				AND	(ob.[name]		= @TableName	or @TableName is NULL)
				AND	(i.[name]		= @IndexName	or @IndexName is NULL)


			GROUP BY	ob.[database_name]
					,sc.[name]
					,ob.[object_id]
					,ob.[name]
			) CoreData
	ORDER BY	1
			, 3


	OPEN updatestatscursor
	FETCH NEXT FROM updatestatscursor INTO @DatabaseName, @objectId, @qualifiedTableName, @IndexId, @indexName, @daysSinceStatsLastUpdated, @rowModCtr, @sampling, @noRecompute
	WHILE @@FETCH_STATUS=0 and @lError=0
	BEGIN --block for WHILE @@FETCH_STATUS = 0 and @lError=0
		BEGIN TRY -- try block within cursor
			SET @updateStatsCommand =''

			IF @LastDB IS NULL
			BEGIN
			set @lMsg= @DatabaseName + N': Starting Database.';
			exec [dbo].[dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_START'
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
				,@Diagnose=@Diagnose
			END

			ELSE IF @DatabaseName != @LastDB
			BEGIN
				IF @LastDB IS NOT NULL
				BEGIN
					set @lMsg= @LastDB + N': Finishing Database.';
					exec [dbo].[dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_END'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
						,@Diagnose=@Diagnose
				END
				set @lMsg= @DatabaseName + N': Starting Database.';
				exec [dbo].[dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_START'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
					,@Diagnose=@Diagnose
			END


			set @lMsg=N'Evaluating ' + @qualifiedTableName + N'.';
			exec [dbo].[dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword='EVT_INFO'
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
				,@Diagnose=@Diagnose


			select @startTime=getdate();


			-- ADD USE STATEMENT ONCE FOR EACH DATABASE IF  @scriptmode=1
			IF @ScriptMode=1 AND (@DatabaseName != @LastDB OR @LastDB IS NULL)
			BEGIN
				set @lMsg=N'SETTING USE DATABASE IN OUTPUT FOR ' + QUOTENAME(COALESCE(@databaseName,'??????????')) + N'.';
				exec [dbo].[dbasp_LogMsg]
					@ModuleName=@cEModule
					,@MessageKeyword=@cEMessage
					,@TypeKeyword='EVT_INFO'
					,@ProcessGUID=@ProcessGUID
					,@AdHocMsg = @lMsg
					,@Diagnose=@Diagnose

				SET @Output	= COALESCE(@Output,'')
						+ CHAR(13)+CHAR(10)
						+'GO'
						+ CHAR(13)+CHAR(10)
						+ N'Use [' + COALESCE(@databaseName,'??????????') + N']; '
						+ CHAR(13)+CHAR(10)
						+'GO'
						+ CHAR(13)+CHAR(10)
			END
			-------------------------------------------------------
			--      F I N D   A L L   S K I P S   F I R S T      --
			-------------------------------------------------------

			IF @daysSinceStatsLastUpdated  is null
				BEGIN --If statistics have not been created anywhere on the table, do nothing but log it.
					SET @lMsg=@qualifiedTableName + N' has not had statistics created.';
					exec [dbo].[dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_INFO'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
						,@Diagnose=@Diagnose

					IF @ScriptMode = 1 AND @OutputSkiped = 1
						SET @Output	= COALESCE(@Output,'')
								+ '-- '
								+ @lMsg
						 		+ CHAR(13)+CHAR(10)
				END

			ELSE IF @daysSinceStatsLastUpdated  <= @updateStatsSinceDays
				BEGIN --If statistics have been updated within the amount of time specified, do nothing but log it.
					SET @lMsg=@qualifiedTableName + N' was last updated ' + cast(@daysSinceStatsLastUpdated as nvarchar)
						+ N' days ago, which is within '
						+ cast(@updateStatsSinceDays as nvarchar)
						+ N' days. Stats will not be updated.';


					exec [dbo].[dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_INFO'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
						,@Diagnose=@Diagnose

					IF @ScriptMode = 1 AND @OutputSkiped = 1
						SET @Output	= COALESCE(@Output,'')
								+ '-- '
								+ @lMsg
						 		+ CHAR(13)+CHAR(10)
				END

			ELSE if @rowModCtr < @rowsUpdatedThreshold
				begin --If the rowModCtr is less than our threshold, do nothing but log it.
					set @lMsg=@qualifiedTableName + N' has only had '
						+ cast(@rowModCtr as nvarchar)
						+ N' row(s) changed in this statistic. This is less than '
						+ cast(@rowsUpdatedThreshold  as nvarchar) + N', so no update.';


					exec [dbo].[dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword='EVT_INFO'
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
						,@Diagnose=@Diagnose

					IF @ScriptMode = 1 AND @OutputSkiped = 1
						SET @Output	= COALESCE(@Output,'')
								+ '-- '
								+ @lMsg
						 		+ CHAR(13)+CHAR(10)
				end

			ELSE
			-------------------------------------------------------
			--  U  P  D  A  T  E   S  T  A  T  I  S  T  I  C  S  --
			-------------------------------------------------------
				begin -- Begin block to update statistics


					-- GENERATE COMMAND
					select @updateStatsCommand =  COALESCE(@updateStatsCommand,'') + CASE @ScriptMode WHEN 1 THEN '' ELSE N'Use [' + @databaseName + N']; 'END + N'UPDATE STATISTICS ' + COALESCE(@qualifiedTableName,'{TableName}') + COALESCE('(' + @indexName + ')','')
						+ CASE @sampling
							WHEN 100
								THEN CASE @noRecompute
									WHEN 1
										THEN N' WITH FULLSCAN, NORECOMPUTE;'
									ELSE N' WITH FULLSCAN;'
									END
							WHEN 0
								THEN CASE @noRecompute
									WHEN 1
										THEN N', NORECOMPUTE;'
									ELSE N';'
									END
							ELSE
								CASE @noRecompute
									WHEN 1
										THEN N' WITH SAMPLE ' + CAST(COALESCE(@sampling,1) as nvarchar(2)) + ' PERCENT, NORECOMPUTE;'
									ELSE ' WITH SAMPLE ' + CAST(COALESCE(@sampling,1) as nvarchar(2)) + ' PERCENT;'
								END
							END


					-- ADD COMMENTS
					SET @updateStatsCommand = COALESCE(@updateStatsCommand,'')+ REPLICATE(N' ',@MaxCmdLength-LEN(COALESCE(@updateStatsCommand,''))) + '-- '
						+ 'Last updated ' + cast(@daysSinceStatsLastUpdated as nvarchar) + N' days ago, '
						+ 'had ' + cast(@rowModCtr as nvarchar) + N' row(s) changed.'


					-- Log the command
					set @lMsg = case @ScriptMode when 1 then 'Testmode, not executing: ' else '' end + @updateStatsCommand
					set @typeKeyword = case @ScriptMode when 1 then 'EVT_INFO' ELSE 'EVT_START' END


					exec [dbo].[dbasp_LogMsg]
						@ModuleName=@cEModule
						,@MessageKeyword=@cEMessage
						,@TypeKeyword= @typeKeyword
						,@ProcessGUID=@ProcessGUID
						,@AdHocMsg = @lMsg
						,@Diagnose=@Diagnose


					-- If Scripting, Append the Command to the Output.
					IF @ScriptMode=1
						SET @Output = COALESCE(@Output,'') + COALESCE(@updateStatsCommand,'') + CHAR(13)+CHAR(10)


					ELSE  -- if not Scripting, actually update the statistics.
						begin
							exec sp_executesql @updateStatsCommand;
							exec [dbo].[dbasp_LogMsg]
								@ModuleName=@cEModule
								,@MessageKeyword=@cEMessage
								,@TypeKeyword= 'EVT_SUCCESS'
								,@ProcessGUID=@ProcessGUID
								,@AdHocMsg = @lMsg
								,@Diagnose=@Diagnose


						end
				END -- End block to update statistics
		END TRY -- try block within cursor

		BEGIN CATCH -- Catch for try block within cursor
			SELECT @lMsg = N'try/catch: dbasp_IndexUpdateStats failed againt '
					+ @databaseName + N'.' + @qualifiedTableName + '! The error message given was: ' + ERROR_MESSAGE()
					+ N'. The error severity originally raised was: ' + cast(ERROR_SEVERITY() as nvarchar) + N'.'


			EXEC [dbo].[dbasp_LogMsg]
				@ModuleName=@cEModule
				,@MessageKeyword=@cEMessage
				,@TypeKeyword= 'EVT_FAIL'
				,@ProcessGUID=@ProcessGUID
				,@AdHocMsg = @lMsg
				,@Diagnose=@Diagnose
				,@SuppressRaiseError=1;


			SET @lError = 1;
		END CATCH -- Catch for try block within cursor

		-- UPDATE VALUE SO IT CAN BE DETECTED WHEN WE GET TO THE NEXT DATABASE
		SET	@LastDB = @DatabaseName

		-- Move on to the next object.
		FETCH NEXT FROM updatestatscursor into @DatabaseName, @objectId, @qualifiedTableName, @IndexId, @indexName, @daysSinceStatsLastUpdated, @rowModCtr, @sampling, @noRecompute
	END --block for WHILE @@FETCH_STATUS = 0 and @lError=0
	CLOSE updatestatscursor
	DEALLOCATE updatestatscursor

	-- SET LAST FINISHING DATABASE LOG EVENT
	set @lMsg= @DatabaseName + N': Finishing Database.';
	exec [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_END'
		,@ProcessGUID=@ProcessGUID
		,@AdHocMsg = @lMsg
		,@Diagnose=@Diagnose
END TRY -- Outer Try block


BEGIN CATCH -- Catch from outer Try block


	SELECT @lMsg = N'try/catch: dbasp_IndexUpdateStats failed against ['
			+ @databaseName + N'].[' + @qualifiedTableName + N']! The error message given was: ' + ERROR_MESSAGE()
			+ N'. The error severity originally raised was: ' + cast(ERROR_SEVERITY() as nvarchar) + N'.'


	exec [dbo].[dbasp_LogMsg]
		@ModuleName=@cEModule
		,@MessageKeyword=@cEMessage
		,@TypeKeyword='EVT_FAIL'
		,@AdHocMsg=@lMsg
		,@ProcessGUID=@ProcessGUID
		,@LogPublisherMessage=0
		,@Diagnose=@Diagnose
		,@SuppressRaiseError=1;


	SET @lError=1 -- Flag an error.
END CATCH -- Catch from outer Try block


-- OUTPUT TO SCREEN
IF @scriptmode = 1 AND @ScreenOutput = 1
BEGIN
	DECLARE @Marker1 bigint, @Marker2 bigint
	SET	@Marker1 = 0


	PRINT	'---------------------------------------------------------------------------------'
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	''
	PRINT	'			\/ \/		START OF SCRIPT		\/ \/'
	PRINT	''
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	''
	PRINT	''
	PrintMore:
		--EXPECTING TO BREAK ON CR&LF


	SET	@Marker2 = CHARINDEX(CHAR(13),@Output,@Marker1 + 3500)
	IF	@Marker2 = 0
		SET @Marker2 = LEN(@Output)


	SET	@OutputString = SUBSTRING(@Output,@Marker1,@Marker2-@Marker1)
	PRINT	@OutputString


	SET	@Marker1 = @Marker2 + 2 -- USE +2 instead of + 1 to STRIP CRLF


	If	@Marker2 < LEN(@Output)
		GOTO PrintMore

	PRINT	''
	PRINT	''
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	''
	PRINT	'			/\ /\		END OF SCRIPT		/\ /\'
	PRINT	''
	PRINT	'---------------------------------------------------------------------------------'
	PRINT	'---------------------------------------------------------------------------------'

END


-- OUTPUT TO FILE
IF @scriptmode = 1 AND @FileOutput = 1 and LEN(@Output) > 10
BEGIN
	SET @Path = @Path+'\'+@FileName
	PRINT 'Writing File '+@Path
	EXECUTE [dbo].[dbasp_FileAccess_Write] @Output,@Path,0,1
END


-- DONE
SET @lMsg='End of dbasp_IndexUpdateStats run.'
IF @lError=0
	SET @lEType='EVT_SUCCESS'
ELSE
	SET @lEType='EVT_FAIL'


exec [dbo].[dbasp_LogMsg]
	@ModuleName=@cEModule
	,@MessageKeyword=@cEMessage
	,@TypeKeyword=@lEType
	,@AdHocMsg=@lMsg
	,@ProcessGUID=@ProcessGUID
	,@LogPublisherMessage=0
	,@Diagnose=@Diagnose


if @lEType='EVT_FAIL'
	RAISERROR (@lMsg,16,1)WITH LOG;


RETURN @lError;
GO
GRANT EXECUTE ON  [dbo].[dbasp_IndexUpdateStats] TO [public]
GO
