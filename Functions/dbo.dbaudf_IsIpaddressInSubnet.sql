SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_IsIpaddressInSubnet]
(
    @networkAddress NVARCHAR(15), -- 'eg: '192.168.0.0'
    @subnetMask NVARCHAR(15), -- 'eg: '255.255.255.0' for '/24'
    @testAddress NVARCHAR(15) -- 'eg: '192.168.0.1'
)
RETURNS BIT AS
BEGIN
    RETURN CASE WHEN (DBAOps.dbo.dbaudf_IPAddress2BigInt(@networkAddress) & DBAOps.dbo.dbaudf_IPAddress2BigInt(@subnetMask))
        = (DBAOps.dbo.dbaudf_IPAddress2BigInt(@testAddress) & DBAOps.dbo.dbaudf_IPAddress2BigInt(@subnetMask))
    THEN 1 ELSE 0 END
END
GO
