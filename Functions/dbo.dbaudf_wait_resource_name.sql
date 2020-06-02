SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_wait_resource_name](@obj nvarchar(max))
RETURNS @wait_resource TABLE (
    wait_resource_database_name sysname,
    wait_resource_schema_name sysname,
    wait_resource_object_name sysname
)
AS
BEGIN
    DECLARE @dbid int
    DECLARE @objid int

    IF @obj IS NULL RETURN
    IF @obj NOT LIKE 'OBJECT: %' RETURN

    SET @obj = SUBSTRING(@obj, 9, LEN(@obj) - 9 + CHARINDEX(':', @obj, 9))

    SET @dbid = LEFT(@obj, CHARINDEX(':', @obj, 1) - 1)
    SET @objid = SUBSTRING(@obj, CHARINDEX(':', @obj, 1) + 1, CHARINDEX(':', @obj, CHARINDEX(':', @obj, 1) + 1) - CHARINDEX(':', @obj, 1) - 1)

    INSERT INTO @wait_resource (wait_resource_database_name, wait_resource_schema_name, wait_resource_object_name)
    SELECT db_name(@dbid), object_schema_name(@objid, @dbid), object_name(@objid, @dbid)

    RETURN
END
GO
