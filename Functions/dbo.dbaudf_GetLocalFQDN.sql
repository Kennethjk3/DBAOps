SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Steve Ledridge
-- Create date: 2017-03-17
-- Description:	Return Local FQDN
-- =============================================
CREATE   FUNCTION [dbo].[dbaudf_GetLocalFQDN]
(
)
RETURNS SYSNAME
WITH EXECUTE AS OWNER 
AS
BEGIN
	DECLARE @FQDN SYSNAME
	EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters', N'Domain', @FQDN OUTPUT

	IF @FQDN Not Like '%${{secrets.DOMAIN_NAME}}'
		SET @FQDN = dbo.dbaudf_GetEV('USERDNSDOMAIN')

	SELECT @FQDN = Cast(SERVERPROPERTY('MachineName') as nvarchar) + '.' + COALESCE(@FQDN,'DB.${{secrets.DOMAIN_NAME}}')

	RETURN @FQDN
END
GO
