SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CreateAllDBViews]
			(
			@Age INT = 60 -- RECREATE IF OLDER THAN 60 MINUTES
			)
AS
-- DOCUMENTATION HEADDER
/****************************************************************************
<CommentHeader>
	<VersionControl>
 		<DatabaseName>DBAOps</DatabaseName>
		<SchemaName>dbo</SchemaName>
		<ObjectType>Procedure</ObjectType>
		<ObjectName>dbasp_CreateAllDBViews</ObjectName>
		<Version>1.0.0</Version>
		<Build Number="" Application="" Branch=""/>
		<Created By="Steve Ledridge" On="10/14/2011"/>
		<Modifications>
			<Mod By="Steve Ledridge" On="2/1/2012" Reason="Modified Process to use collation in DBAOps for all queries in views"/>
			<Mod By="" On="" Reason=""/>
		</Modifications>
	</VersionControl>
	<Purpose>Drop and Recreate a set ov views used by several Index Maint Processes</Purpose>
	<Description>Uses the default or passed in value to evaluate existing views or synonyms and replace them when older in minutes to the value</Description>
	<Dependencies>
		<Object Type="" Schema="" Name="" VersionCompare="" Version=""/>
	</Dependencies>
	<Parameters>
		<Parameter Type="Int" Name="@Age" Desc="Age limit to keep existing views rather than replacing them"/>
	</Parameters>
	<Permissions>
		<Perm Type="GRANT" Priv="EXEC" To="PUBLIC" With=""/>
	</Permissions>
</CommentHeader>
*****************************************************************************/


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	04/04/2012	Steve Ledridge		Added code to only process ONLINE DB's
--	08/27/2012	Steve Ledridge		Added Skip Check to not try to run if already running.
--	09/12/2012	Steve Ledridge		Modifid process to exclude z_% DB's and no_check entries.
--	08/19/2014	Steve Ledridge		New code to skip secondary AvailGrp DB's.
--	02/03/2016	Steve Ledridge		Added Stats_Columns to support rapid stats updates.
--	08/08/2016	Steve Ledridge		Modified code for avail grp DB resolving.
--	======================================================================================


/***
Declare @Age INT


Select @Age = 60
--***/


BEGIN


	DECLARE		@TSQL1				Varchar(max)
				,@TSQL2				Varchar(max)
				,@TSQL3				Varchar(max)
				,@SchemaName		sysname
				,@TableName			sysname


	DECLARE		CreateAllDBViews	CURSOR
	FOR
	SELECT 'sys','tables'
	UNION ALL
	SELECT 'sys','schemas'
	UNION ALL
	SELECT 'sys','sysindexes'
	UNION ALL
	SELECT 'sys','indexes'
	UNION ALL
	SELECT 'sys','dm_db_partition_stats'
	UNION ALL
	--SELECT 'sys','dm_db_index_usage_stats'
	--UNION ALL
	SELECT 'sys','partition_schemes'
	UNION ALL
	SELECT 'sys','partition_functions'
	UNION ALL
	SELECT 'sys','filegroups'
	UNION ALL
	SELECT 'sys','allocation_units'
	UNION ALL
	SELECT 'sys','partitions'
	UNION ALL
	SELECT 'sys','columns'
	UNION ALL
	SELECT 'sys','index_columns'
	UNION ALL
	SELECT 'sys','foreign_keys'
	UNION ALL
	SELECT 'sys','foreign_key_columns'
	UNION ALL
	SELECT 'sys','objects'
	UNION ALL
	SELECT 'sys','stats'
	UNION ALL
	SELECT 'sys','stats_columns'
	UNION ALL
	SELECT 'sys','sysfilegroups'
	UNION ALL
	SELECT 'sys','internal_tables'
	UNION ALL
	SELECT 'sys','database_principals'
	UNION ALL
	SELECT 'sys','database_role_members'
	OPEN CreateAllDBViews
	FETCH NEXT FROM CreateAllDBViews INTO @SchemaName,@TableName
	WHILE (@@fetch_status <> -1)
	BEGIN


		IF (@@fetch_status <> -2)
		AND (
				NOT EXISTS (SELECT 1 FROM DBAOps.sys.objects WHERE Type = 'V' AND DATEDIFF(minute,create_date,GetDate()) < @Age AND name = 'vw_AllDB_'+@TableName)
			OR	NOT EXISTS (SELECT 1 FROM dbaperf.sys.objects WHERE Type = 'SN' AND DATEDIFF(minute,create_date,GetDate()) < @Age AND name = 'vw_AllDB_'+@TableName)
			)
		BEGIN

			SET		@TSQL3 = ''

			SELECT		@TSQL3 = @TSQL3 + '['+ name + ']'
						+ CASE WHEN nullif(collation_name,'') IS NOT NULL THEN ' COLLATE ' + collation_name ELSE '' END
						+ ','
			From		sys.system_columns
			WHERE		object_id = object_id('['+@SchemaName+'].['+@TableName+']')
			ORDER BY	column_id


			SET @TSQL3 = REPLACE(@TSQL3+'|',',|','')


			SET		@TSQL1	= 'IF OBJECT_ID(''[dbo].[vw_AllDB_'+@TableName+']'',''V'') IS NOT NULL'
							+ CHAR(13)+CHAR(10)
							+ 'DROP VIEW [dbo].[vw_AllDB_'+@TableName+']'

			SET		@TSQL2	= 'USE [DBAOps];'
							+ CHAR(13)+CHAR(10)
							+ 'EXEC (''' + REPLACE(@TSQL1,'''','''''') + ''')'

			PRINT 'Dropping [vw_AllDB_'+@TableName+'] View in DBAOps.'


			EXEC	(@TSQL2)


			SET		@TSQL2	= 'USE [dbaperf];'
							+ CHAR(13)+CHAR(10)
							+ 'EXEC (''' + REPLACE(@TSQL1,'''','''''') + ''')'

			PRINT 'Dropping [vw_AllDB_'+@TableName+'] View in dbaperf.'


			EXEC	(@TSQL2)

			SET		@TSQL1	= 'IF OBJECT_ID(''[dbo].[vw_AllDB_'+@TableName+']'',''SN'') IS NOT NULL'
							+ CHAR(13)+CHAR(10)
							+ 'DROP SYNONYM [dbo].[vw_AllDB_'+@TableName+']'

			SET		@TSQL2	= 'USE [dbaperf];'
							+ CHAR(13)+CHAR(10)
							+ 'EXEC (''' + REPLACE(@TSQL1,'''','''''') + ''')'

			PRINT 'Dropping [vw_AllDB_'+@TableName+'] Synonym in dbaperf.'


			EXEC	(@TSQL2)


			IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
			   begin
				SET		@TSQL1	= 'CREATE OR ALTER VIEW [dbo].[vw_AllDB_'+@TableName+'] AS' +CHAR(13)+CHAR(10)+'SELECT	''master'' AS database_name, DB_ID(''master'') AS database_id, * From [master].['+@SchemaName+'].['+@TableName+']'+CHAR(13)+CHAR(10)
				SELECT	@TSQL1	= @TSQL1
								+ 'UNION ALL'
								+ CHAR(13)+CHAR(10)
								+ 'SELECT	'''+name+''', DB_ID('''+name+'''),'
								+ @TSQL3
								+ ' From ['+name+'].['+@SchemaName+'].['+@TableName+']'
								+ CHAR(13)+CHAR(10)
				--SELECT *
				FROM	master.sys.databases
				WHERE	name not in ('master','model','tempdb','')
				  AND	name not in (SELECT [detail01] FROM [dbo].[No_Check] WHERE [NoCheck_type] = 'backup')
				  AND   name not in (Select dbcs.database_name
							FROM master.sys.availability_replicas AS AR
							INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
							   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
							INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
							   ON arstates.replica_id = dbcs.replica_id
							where AR.replica_server_name = @@servername
							and arstates.role_desc in ('SECONDARY', 'RESOLVING'))
				  AND	left(name,2) != 'z_'
				  and	state_desc = 'ONLINE'
			   end
			Else
			   begin
				SET		@TSQL1	= 'CREATE OR ALTER VIEW [dbo].[vw_AllDB_'+@TableName+'] AS' +CHAR(13)+CHAR(10)+'SELECT	''master'' AS database_name, DB_ID(''master'') AS database_id, * From [master].['+@SchemaName+'].['+@TableName+']'+CHAR(13)+CHAR(10)
				SELECT	@TSQL1	= @TSQL1
								+ 'UNION ALL'
								+ CHAR(13)+CHAR(10)
								+ 'SELECT	'''+name+''', DB_ID('''+name+'''),'
								+ @TSQL3
								+ ' From ['+name+'].['+@SchemaName+'].['+@TableName+']'
								+ CHAR(13)+CHAR(10)
				--SELECT *
				FROM	master.sys.databases
				WHERE	name not in ('master','model','tempdb','')
				  AND	name not in (SELECT [detail01] FROM [dbo].[No_Check] WHERE [NoCheck_type] = 'backup')
				  AND	left(name,2) != 'z_'
				  and	state_desc = 'ONLINE'
			   end


			SET		@TSQL2	= 'USE [DBAOps];'
							+ CHAR(13)+CHAR(10)
							+ 'EXEC (''' + REPLACE(@TSQL1,'''','''''') + ''')'

			PRINT 'Creating [vw_AllDB_'+@TableName+'] View in DBAOps.'


			EXEC	(@TSQL2)


			SET		@TSQL1	= 'CREATE SYNONYM [dbo].[vw_AllDB_'+@TableName+'] FOR [DBAOps].[dbo].[vw_AllDB_'+@TableName+']'

			SET		@TSQL2	= 'USE [dbaperf];'
							+ CHAR(13)+CHAR(10)
							+ 'EXEC (''' + REPLACE(@TSQL1,'''','''''') + ''')'

			PRINT 'Creating [vw_AllDB_'+@TableName+'] Synonym in dbaperf.'


			EXEC	(@TSQL2)


		END
		ELSE PRINT '[vw_AllDB_'+@TableName+'] Parts are Recent: Nothing Done.'
		FETCH NEXT FROM CreateAllDBViews INTO @SchemaName,@TableName
	END


	CLOSE CreateAllDBViews
	DEALLOCATE CreateAllDBViews


	SkipAlreadyRunning:
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_CreateAllDBViews] TO [public]
GO
