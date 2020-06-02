SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetDbAg]
(
    @DBName SYSNAME
)
RETURNS SYSNAME
AS
BEGIN
	DECLARE @AGroup SYSNAME

	IF DB_ID(@DBName) IS NOT NULL
	IF @@microsoftversion / 0x01000000 >= 11
	IF SERVERPROPERTY('IsHadrEnabled') = 1
	BEGIN
		SELECT	DISTINCT
				@AGroup = AG.Name
		FROM		master.sys.availability_groups AS AG
		LEFT JOIN	master.sys.availability_replicas AS AR
			ON	AG.group_id = AR.group_id
		LEFT JOIN	master.sys.dm_hadr_database_replica_cluster_states AS dbcs
			ON	AR.replica_id = dbcs.replica_id
		WHERE	dbcs.database_name = @DBName
			and	db_id(dbcs.database_name) IS NOT NULL
			AND	AG.Name IS NOT NULL
	END
	ELSE
		SET @AGroup = 'ERROR: Server Configuration does not Support Availability Groups.'
	ELSE
		SET @AGroup = 'ERROR: Server Version does not Support Availability Groups.'
	ELSE
		SET @AGroup = 'ERROR: Database '+@DBName+' does NOT Exist.'

    SET @AGroup = COALESCE(@AGroup,'ERROR: Database '+@DBName+' is NOT in an Availability Group.')

    RETURN @AGroup
END
GO
