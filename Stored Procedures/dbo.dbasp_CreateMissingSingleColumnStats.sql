SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CreateMissingSingleColumnStats]
		(
		@DatabaseName	SYSNAME = NULL
		,@Verbose	TINYINT	= 0		-- -1 = Silent, 0 = Quiet, 1 = Debug
		)
AS


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	05/14/2013	Steve Ledridge		Revision History added.  Skip to end added.
--	08/16/2013	Steve Ledridge		Added check for DB = online.
--	03/18/2015	Steve Ledridge		Added Verbose Flag to prevent noisy output.
--	07/16/2015	Steve Ledridge		Added an exclusion for VarChar(max) Columns
--	02/03/2016	Steve Ledridge		Wraped Create into Try Catch so it doesnt stop at error
--						Added Database name to normal output for troubleshooting
--	======================================================================================


BEGIN
	SET	TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET	NOCOUNT		ON
	SET	ANSI_WARNINGS	ON

	--reset ALLDBViews to deal with database state changes
	EXEC DBAOps.dbo.dbasp_CreateAllDBViews @age=1

	DECLARE	@Cmd			NVARCHAR(MAX)
			,@Msg			NVARCHAR(MAX)
			,@TableName		SYSNAME
			,@ColumnName	SYSNAME


	DECLARE	@MissingStats	TABLE
				(
				[DatabaseName]	SYSNAME
				,[tablename]	SYSNAME
				,[ColumnName]	SYSNAME
				)


	--  Check for active rows in the index maintenance process
	If exists (select 1 from dbo.IndexMaintenanceProcess where status in ('pending', 'in-work'))
	   begin
		If @Verbose >= 0
			Print 'DBA Note: Skipping dbasp_CreateMissingSingleColumnStats process due to active index maintenance processing'
		goto label99
	   end


	  -- DECLARE @DatabaseName SYSNAME
	;WITH		StatsList
			AS
			(     -- DECLARE @DatabaseName SYSNAME
			SELECT		s.database_name
						,s.object_id
						,s.stats_id
						,sc.column_id
			FROM		DBAOps.dbo.vw_AllDB_stats			s WITH(NOLOCK)
			JOIN		DBAOps.dbo.vw_AllDB_stats_columns	sc WITH(NOLOCK)
				ON		s.database_name		= sc.database_name
				AND		s.object_id			= sc.object_id
				AND		s.stats_id			= sc.stats_id
			WHERE		sc.stats_column_id	= 1	--only look at stats where the statistic is on the first column
				AND	s.database_name = COALESCE(@DatabaseName,s.database_name)
				AND	DATABASEPROPERTYEX (s.database_name,'status') = 'ONLINE'
			)
	INSERT INTO	@MissingStats
	SELECT		o.database_name
			,'['+sch.name+'].['+o.name+']' AS tablename
			,c.name AS ColumnName
	FROM		DBAOps.dbo.vw_AllDB_objects o WITH(NOLOCK)
	JOIN		DBAOps.dbo.vw_AllDB_schemas sch WITH(NOLOCK)
		ON	sch.database_name = o.database_name
		AND	o.database_name = COALESCE(@DatabaseName,o.database_name)
		AND	sch.schema_id = o.schema_id
		AND	(
			  o.type = 'U'
		  OR	  (o.type = 'V' AND o.object_id IN (SELECT OBJECT_ID FROM DBAOps.dbo.vw_AllDB_indexes WHERE database_name = o.database_name))
			)

	JOIN		DBAOps.dbo.vw_AllDB_columns c WITH(NOLOCK)
		ON	c.database_name		= o.database_name
		AND	c.object_id		= o.object_id
		AND	c.user_type_id NOT IN (99,241,128,129,130)		-- ignore VarChar(max) XML and spatial columns
		AND	c.is_computed = 0
	LEFT JOIN	StatsList s
		ON	c.database_name = s.database_name
		AND	c.object_id = s.object_id
		AND	c.column_id = s.column_id
	WHERE		s.stats_id IS NULL			--only find columns where there are no stats


	DECLARE statsCursor CURSOR LOCAL READ_ONLY
	FOR
	SELECT		DatabaseName
				,tablename
				,ColumnName
	FROM		@MissingStats


	OPEN StatsCursor
	FETCH NEXT FROM StatsCursor INTO @DatabaseName,@TableName,@ColumnName
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
		BEGIN


			SELECT	@Cmd	= 'USE [' + @DatabaseName + ']; '
					+ 'create statistics [CustomStat_'+REPLACE(@ColumnName,' ','_')+'] on '+@TableName + '(['+@ColumnName+'])'
				,@Msg	= '-- creating stats on '+@DatabaseName+'.'+@TableName+'(['+@ColumnName+'])'


			If @Verbose >= 0
				PRINT @Msg


			If @Verbose >= 1
				PRINT @Cmd


			BEGIN TRY
				EXEC (@Cmd)
			END TRY
			BEGIN CATCH
				PRINT ''
				PRINT '****************************************************************************************'
				PRINT '*                             ERROR CREATING STATISTIC                                 *'
				PRINT '****************************************************************************************'

				-- PRINT CMD IF IT WASNT ALREADY PRINTED BECAUSE OF VERBOSE LEVEL
				If @Verbose < 1
					PRINT @Cmd


				PRINT '* ' + ERROR_MESSAGE()
				PRINT '****************************************************************************************'
				PRINT ''
			END CATCH


		END
		FETCH NEXT FROM StatsCursor INTO @DatabaseName,@TableName,@ColumnName
	END
	CLOSE StatsCursor
	DEALLOCATE StatsCursor


---------------------------  Finalization  -----------------------
label99:


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_CreateMissingSingleColumnStats] TO [public]
GO
