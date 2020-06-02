SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_ScriptIndexes]
(
    @DBName			SYSNAME		,--='ComposerSL',
	@SchemaName		sysname		,--='Alsek',
	@ObjectName		SYSNAME		--='Alsek2CSL_itineraryitem'
	,@IgnoreClsd	BIT	= 1
	,@IgnorePK		BIT	= 1
)
RETURNS VARCHAR(8000)
AS
BEGIN

DECLARE @CreateScript VARCHAR(8000) = ''
DECLARE @DropScript VARCHAR(8000) = ''

SELECT @CreateScript	= @CreateScript
						+ REPLACE(
							DBAOps.dbo.dbaudf_ConcatenateUnique(
							CASE si.index_id WHEN 0 THEN ''
							ELSE
								CASE is_primary_key WHEN 1 THEN
									N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' ADD CONSTRAINT ' + QUOTENAME(si.name) + N' PRIMARY KEY ' +
										CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED '
									ELSE N'CREATE ' +
										CASE WHEN si.is_unique = 1 then N'UNIQUE ' ELSE N'' END +
										CASE WHEN si.index_id > 1 THEN N'NON' ELSE N'' END + N'CLUSTERED ' +
										N'INDEX ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' '
								END +
								/* key def */ N'(' + key_definition + N')' +
								/* includes */ CASE WHEN include_definition IS NOT NULL THEN
									N' INCLUDE (' + include_definition + N')'
									ELSE N''
								END +
								/* filters */ CASE WHEN filter_definition IS NOT NULL THEN
									N' WHERE ' + filter_definition ELSE N''
								END + N' WITH (ONLINE=ON'+
								/* with clause - compression goes here */
								CASE WHEN row_compression_partition_list IS NOT NULL OR page_compression_partition_list IS NOT NULL
									THEN N',' +
										CASE WHEN row_compression_partition_list IS NOT NULL THEN
											N'DATA_COMPRESSION = ROW ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + row_compression_partition_list + N')' END
										ELSE N'' END +
										CASE WHEN row_compression_partition_list IS NOT NULL AND page_compression_partition_list IS NOT NULL THEN N', ' ELSE N'' END +
										CASE WHEN page_compression_partition_list IS NOT NULL THEN
											N'DATA_COMPRESSION = PAGE ' + CASE WHEN psc.name IS NULL THEN N'' ELSE + N' ON PARTITIONS (' + page_compression_partition_list + N')' END
										ELSE N'' END

									ELSE N''
								END + N')' +
								/* ON where? filegroup? partition scheme? */
								' ON ' + CASE WHEN psc.name is null
									THEN ISNULL(QUOTENAME(fg.name),N'')
									ELSE psc.name + N' (' + partitioning_column.column_name + N')'
									END
								+ N';'
							END --AS index_create_statement
							),';,',';'+CHAR(13)+CHAR(10)+'GO'+CHAR(13)+CHAR(10))+CHAR(13)+CHAR(10)+'GO'

		,@DropScript	= @DropScript
						+ REPLACE	(
									DBAOps.dbo.dbaudf_ConcatenateUnique(
																		N'DROP INDEX IF EXISTS ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(si.database_name) + N'.' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name)	+ N';'
																		)
									,';,'
									,';'+CHAR(13)+CHAR(10)+'GO'+CHAR(13)+CHAR(10)
									)

									+CHAR(13)+CHAR(10)+'GO'

FROM DBAOps.dbo.vw_AllDB_indexes AS si
JOIN DBAOps.dbo.vw_AllDB_tables AS t ON si.object_id=t.object_id AND si.database_name = t.database_name
JOIN DBAOps.dbo.vw_AllDB_schemas AS sc ON t.schema_id=sc.schema_id AND si.database_name = sc.database_name
LEFT JOIN sys.dm_db_index_usage_stats AS stat ON
    stat.database_id = si.database_id
    and si.object_id=stat.object_id
    and si.index_id=stat.index_id
LEFT JOIN DBAOps.dbo.vw_AllDB_partition_schemes AS psc		ON si.data_space_id=psc.data_space_id	AND psc.database_name = si.database_name
LEFT JOIN DBAOps.dbo.vw_AllDB_partition_functions AS pf		ON psc.function_id=pf.function_id		AND pf.database_name = si.database_name
LEFT JOIN DBAOps.dbo.vw_AllDB_filegroups AS fg				ON si.data_space_id=fg.data_space_id	AND fg.database_name = si.database_name

/* Key list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name) +
        CASE ic.is_descending_key WHEN 1 then N' DESC' ELSE N'' END
    FROM DBAOps.dbo.vw_AllDB_index_columns AS ic
    JOIN DBAOps.dbo.vw_AllDB_columns AS c ON
        ic.column_id=c.column_id
        and ic.object_id=c.object_id
		AND ic.database_name = c.database_name
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.key_ordinal > 0
		AND ic.database_name = si.database_name
    ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS keys ( key_definition )

/* Partitioning Ordinal */ OUTER APPLY (
    SELECT MAX(QUOTENAME(c.name)) AS column_name
    FROM DBAOps.dbo.vw_AllDB_index_columns AS ic
    JOIN DBAOps.dbo.vw_AllDB_columns AS c ON
        ic.column_id=c.column_id
        and ic.object_id=c.object_id
		AND ic.database_name = c.database_name
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.partition_ordinal = 1
		AND ic.database_name = @DBName) AS partitioning_column

/* Include list */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + QUOTENAME(c.name)
    FROM DBAOps.dbo.vw_AllDB_index_columns AS ic
    JOIN DBAOps.dbo.vw_AllDB_columns AS c ON
        ic.column_id=c.column_id
        and ic.object_id=c.object_id
		AND ic.database_name = c.database_name
    WHERE ic.object_id = si.object_id
        and ic.index_id=si.index_id
        and ic.is_included_column = 1
		AND ic.database_name = @DBName
    ORDER BY c.name FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS includes ( include_definition )

/* Partitions */ OUTER APPLY (
    SELECT
        COUNT(*) AS partition_count,
        CAST(SUM(ps.in_row_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_in_row_GB,
        CAST(SUM(ps.lob_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_LOB_GB,
        SUM(ps.row_count) AS row_count
    FROM DBAOps.dbo.vw_AllDB_partitions AS p
    JOIN DBAOps.dbo.vw_AllDB_dm_db_partition_stats AS ps ON p.partition_id=ps.partition_id AND p.database_name = ps.database_name
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
		AND p.database_name = @DBName
    ) AS partition_sums

/* row compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM DBAOps.dbo.vw_AllDB_partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 1
		AND p.database_name = @DBName
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS row_compression_clause ( row_compression_partition_list )

/* data compression list by partition */ OUTER APPLY ( SELECT STUFF (
    (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
    FROM DBAOps.dbo.vw_AllDB_partitions AS p
    WHERE p.object_id = si.object_id
        and p.index_id=si.index_id
        and p.data_compression = 2
		AND p.database_name = @DBName
    ORDER BY p.partition_number FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'),1,2,'')) AS page_compression_clause ( page_compression_partition_list )
WHERE
    si.type IN (0,1,2) /* heap, clustered, nonclustered */
		AND si.database_name = @DBName
		AND sc.name = @SchemaName
		AND T.name = @ObjectName

		AND (si.is_primary_key = 0 OR @IgnorePK = 0)
		AND (si.index_id != 1 OR @IgnoreClsd = 0)

--ORDER BY table_name, si.index_id
--ORDER BY si.index_id
    OPTION (RECOMPILE);

	DECLARE @FullObjectName SYSNAME
	SET @FullObjectName =  N'IndexCreate_'+@DBName+'.'+@SchemaName+'.'+@ObjectName
	EXEC sys.sp_set_session_context @key = @FullObjectName, @value = @CreateScript, @read_only = 0

	SET @FullObjectName =  N'IndexDrop_'+@DBName+'.'+@SchemaName+'.'+@ObjectName
	EXEC sys.sp_set_session_context @key = @FullObjectName, @value = @DropScript, @read_only = 0

    RETURN @DropScript + '|'+ @CreateScript

END
GO
