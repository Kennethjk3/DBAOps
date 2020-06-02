SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE     FUNCTION [dbo].[dbaudf_GetDbServerName]
(
    @DBName SYSNAME
)
RETURNS SYSNAME
AS
BEGIN
	DECLARE @ServerName SYSNAME

	IF DB_ID(@DBName) IS NOT NULL
	IF @@microsoftversion / 0x01000000 >= 11
	IF SERVERPROPERTY('IsHadrEnabled') = 1
	BEGIN
		SELECT		@ServerName = l.dns_name
		FROM		sys.availability_groups g
		JOIN		sys.availability_group_listeners l		ON l.group_id = g.group_id
		WHERE		g.name = [dbo].[dbaudf_GetDbAg](@DBName)
	END
	ELSE
		SET @ServerName = dbo.dbaudf_GetLocalFQDN()
	ELSE
		SET @ServerName = dbo.dbaudf_GetLocalFQDN()
	ELSE
		SET @ServerName = dbo.dbaudf_GetLocalFQDN()

    SELECT @ServerName = REPLACE(dbo.dbaudf_GetLocalFQDN(),@@SERVERNAME,ISNULL(@ServerName,@@SERVERNAME))

    RETURN @ServerName
END
GO
