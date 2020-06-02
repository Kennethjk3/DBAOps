SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   VIEW [dbo].[DBA_ShareInfo]
AS
select *,getdate()[rundate],@@ServerName[ServerName] From dbaops.dbo.dbaudf_ListShares()
GO
GRANT SELECT ON  [dbo].[DBA_ShareInfo] TO [public]
GO
