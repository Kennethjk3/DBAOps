SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_foreachdb]
   @command             NVARCHAR(MAX),
   @replace_character   NCHAR(1)       = N'?',
   @print_dbname        BIT            = 0,
   @print_command_only  BIT            = 0,
   @suppress_quotename  BIT            = 0,
   @system_only         BIT            = NULL,
   @user_only           BIT            = NULL,
   @operations_only     BIT		    = NULL,
   @name_pattern        NVARCHAR(300)  = N'%',
   @database_list       NVARCHAR(MAX)  = NULL,
   @recovery_model_desc NVARCHAR(120)  = NULL,
   @compatibility_level TINYINT        = NULL,
   @state_desc          NVARCHAR(120)  = N'ONLINE',
   @is_read_only        BIT            = 0,
   @is_auto_close_on    BIT            = NULL,
   @is_auto_shrink_on   BIT            = NULL,
   @is_broker_enabled   BIT            = NULL,
   @is_ag_secondary	    BIT		    = NULL,
   @in_ag			    SYSNAME	    = NULL
AS
BEGIN
   SET NOCOUNT ON;


	--If Table already exists, USE IT
	IF OBJECT_ID('tempdb..#AGInfo') IS NULL
	BEGIN
		CREATE TABLE #AGInfo ([DBName] sysname,[AGName] SYSNAME, [primary_replica] sysname)


		IF @@microsoftversion / 0x01000000 >= 11
		IF SERVERPROPERTY('IsHadrEnabled') = 1
		BEGIN
			INSERT INTO #AGInfo
			SELECT	DISTINCT
					dbcs.database_name [DBName],AG.Name [AGName],primary_replica
			FROM		master.sys.availability_groups AS AG
			LEFT JOIN	master.sys.availability_replicas AS AR
				ON	AG.group_id = AR.group_id
			LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				ON	AR.replica_id = dbcs.replica_id
			LEFT JOIN	sys.dm_hadr_availability_group_states ags
				ON	ags.group_id = ag.group_id
			WHERE	db_id(dbcs.database_name) IS NOT NULL
				AND	AG.Name IS NOT NULL
		END
	END


   DECLARE
       @sql    NVARCHAR(MAX),
       @dblist NVARCHAR(MAX),
       @db     NVARCHAR(300),
       @i      INT;


   IF @database_list > N''
   BEGIN
       ;WITH n(n) AS
       (
           SELECT ROW_NUMBER() OVER (ORDER BY s1.name) - 1
            FROM sys.objects AS s1
            CROSS JOIN sys.objects AS s2
       )
       SELECT @dblist = REPLACE(REPLACE(REPLACE(x,'</x><x>',','),
           '<x>',''),'</x>','')
       FROM
       (
           SELECT DISTINCT x = 'N''' + LTRIM(RTRIM(SUBSTRING(
            @database_list, n,
            CHARINDEX(',', @database_list + ',', n) - n))) + ''''
            FROM n WHERE n <= LEN(@database_list)
            AND SUBSTRING(',' + @database_list, n, 1) = ','
            FOR XML PATH('')
       ) AS y(x);
   END


   CREATE TABLE #x(db NVARCHAR(300));


   SET @sql = N'SELECT name FROM sys.databases T1 LEFT JOIN #AGInfo T2 on T1.name = T2.DBName WHERE 1=1'
       + CASE WHEN @system_only = 1 THEN
           ' AND database_id IN (1,2,3,4)'
           ELSE '' END
       + CASE WHEN @user_only = 1 THEN
           ' AND database_id NOT IN (1,2,3,4)'
           ELSE '' END


		-- ONLY OPERATIONS DATABASES
       + CASE WHEN @operations_only = 1 THEN
           ' AND Name IN (''DBAOps'',''dbaperf'',''DBAOps'',''dbacentral'',''dbaperf_reports'',''DeployCentral'')'
           ELSE '' END
		-- NO OPERATIONS DATABASES
       + CASE WHEN @operations_only = 0 THEN
           ' AND Name NOT IN (''DBAOps'',''dbaperf'',''DBAOps'',''dbacentral'',''dbaperf_reports'',''DeployCentral'')'
           ELSE '' END


		-- ONLY DATABASES IN SPECIFIED AVAILABILITY GROUP
       + CASE WHEN @in_ag IS NOT NULL THEN
           ' AND T2.AGName = ''' +  @in_ag + ''''
           ELSE '' END


		 -- ONLY DATABASES THAT ARE SECONDARIES IN ANY AVAILABILITY GROUP
       + CASE WHEN @is_ag_secondary = 1 THEN
           ' AND T2.primary_replica != ''' +  @@SERVERNAME + ''''
           ELSE '' END
		-- ONLY DATABASES THAT ARE NOT SECONDARIES IN ANY AVAILABILITY GROUP (PRIMARIES AND NON AG DBs)
       + CASE WHEN @is_ag_secondary = 0 THEN
           ' AND COALESCE(T2.primary_replica,@@SERVERNAME) = ''' +  @@SERVERNAME + ''''
           ELSE '' END


       + CASE WHEN @name_pattern <> N'%' THEN
           ' AND name LIKE N''%' + REPLACE(@name_pattern, '''', '''''') + '%'''
           ELSE '' END
       + CASE WHEN @dblist IS NOT NULL THEN
           ' AND name IN (' + @dblist + ')'
           ELSE '' END
       + CASE WHEN @recovery_model_desc IS NOT NULL THEN
           ' AND recovery_model_desc = N''' + @recovery_model_desc + ''''
           ELSE '' END
       + CASE WHEN @compatibility_level IS NOT NULL THEN
           ' AND compatibility_level = ' + RTRIM(@compatibility_level)
           ELSE '' END
       + CASE WHEN @state_desc IS NOT NULL THEN
           ' AND state_desc = N''' + @state_desc + ''''
           ELSE '' END
       + CASE WHEN @is_read_only IS NOT NULL THEN
           ' AND is_read_only = ' + RTRIM(@is_read_only)
           ELSE '' END
       + CASE WHEN @is_auto_close_on IS NOT NULL THEN
           ' AND is_auto_close_on = ' + RTRIM(@is_auto_close_on)
           ELSE '' END
       + CASE WHEN @is_auto_shrink_on IS NOT NULL THEN
           ' AND is_auto_shrink_on = ' + RTRIM(@is_auto_shrink_on)
           ELSE '' END
       + CASE WHEN @is_broker_enabled IS NOT NULL THEN
           ' AND is_broker_enabled = ' + RTRIM(@is_broker_enabled)
           ELSE '' END;


	-- PRINT @sql
   INSERT #x EXEC sp_executesql @sql;


   DECLARE c CURSOR
       LOCAL FORWARD_ONLY STATIC READ_ONLY
       FOR SELECT CASE WHEN @suppress_quotename = 1 THEN
              db
           ELSE
              QUOTENAME(db)
           END
       FROM #x ORDER BY db;


   OPEN c;


   FETCH NEXT FROM c INTO @db;


   WHILE @@FETCH_STATUS = 0
   BEGIN
       SET @sql = REPLACE(@command, @replace_character, @db);


       IF @print_command_only = 1
       BEGIN
           PRINT '/* For ' + @db + ': */'
               + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
               + @sql
               + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
       END
       ELSE
       BEGIN
           IF @print_dbname = 1
           BEGIN
               PRINT '/* ' + @db + ' */';
           END


           EXEC sp_executesql @sql;
       END


       FETCH NEXT FROM c INTO @db;
   END


   CLOSE c;
   DEALLOCATE c;
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_foreachdb] TO [public]
GO
