SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Cluster_Status]


/*********************************************************
 **  Stored Procedure dbasp_HC_Cluster_Status
 **  Written by Steve Ledridge, Virtuoso
 **  November 14, 2014
 **  This procedure runs the Cluster Status portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/14/2014	Steve Ledridge		New process.
--	12/29/2014	Steve Ledridge		Fixed code for multi-subnet IP's.
--	01/12/2016	Steve Ledridge		Fixed code for Network Name in multi-subnet.
--	01/20/2017	Steve Ledridge		No check fpr cluster paused node.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--CLUSTER VERIFICATIONS - NODES ONLINE
--CLUSTER VERIFICATIONS - INSTANCE ON NODE ALONE
--CLUSTER VERIFICATIONS - RESOURCES ONLINE


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@save_cluster_flag			CHAR(1)
	,@skip_networkname_flag			CHAR(1)
	,@save_tb11_id				int
	,@save_ResourceName			sysname
	,@save_State				sysname
	,@save_machine_name			sysname
	,@save_count01				int
	,@save_count02				int


----------------  initial values  -------------------
Select @save_cluster_flag = 'n'


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


create table #clust_tb11 ([tb11_id] [int] IDENTITY(1,1) NOT NULL,
			[ClusterName] [sysname] NULL,
			[ResourceType] [sysname] NULL,
			[ResourceName] [sysname] NULL,
			[ResourceDetail] [sysname] NULL,
			[GroupName] [sysname] NULL,
			[CurrentOwner] [sysname] NULL,
			[PreferredOwner] [sysname] NULL,
			[Dependencies] [nvarchar](500) NULL,
			[RestartAction] [sysname] NULL,
			[AutoFailback] [sysname] NULL,
			[State] [sysname] NULL
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Cluster Status'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Start check Cluster Resources
Print 'Start check Cluster Resources'
Print ''


--  Get the cluster name and related info
delete from #clust_tb11


insert into #clust_tb11
select * From DBAOps.dbo.dbaudf_ListClusterResource()
UNION ALL
select * From DBAOps.dbo.dbaudf_ListClusterNode()
UNION ALL
select * From DBAOps.dbo.dbaudf_ListClusterNetwork()
UNION ALL
select * From DBAOps.dbo.dbaudf_ListClusterNetworkInterface()
--select * from #clust_tb11


If (select count(*) from #clust_tb11) = 0
   begin
	Select @save_test = 'select * From DBAOps.dbo.dbaudf_ListClusterResource()'
	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Resources', 'Fail', 'High', @save_test, null, 'No cluster resources found', null, getdate())
	goto skip_cluster
   end


--  Start Check for CLUSTER - NODES ONLINE
Print 'Start Check for CLUSTER - NODES ONLINE'
Print ''


Select @save_test = 'select * From DBAOps.dbo.dbaudf_ListClusterNode()'


--  First check for multi-subnet clusters
If (select count(distinct (left(resourcedetail, 6))) From DBAOps.dbo.dbaudf_ListClusterResource() where resourcetype = 'IP Address') > 1
   begin
	Select @save_count01 = (Select count(*) from #clust_tb11 where ResourceType = 'Node')
	Select @save_count02 = (Select count(*) from #clust_tb11 where ResourceType = 'Node' and state in ('Online', 'Up'))


	If @save_count02 < (@save_count01/2)
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Node', 'Fail', 'High', @save_test, null, 'Node resources are not UP for this Multi-SubNet cluster ', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Node', 'Pass', 'High', @save_test, null, 'At least half of the Nodes for this Multi-SubNet cluster are UP', null, getdate())
	   END
   end
Else IF exists (select 1 from #clust_tb11 where ResourceType = 'Node' and State in ('Down')) and exists (select 1 from dbo.No_Check where NoCheck_type = 'Cluster' and detail01 = 'node paused')
   BEGIN
	Select @save_tb11_id = 0
	start_node_check01:
	Select @save_tb11_id = (Select top 1 tb11_id from #clust_tb11 where ResourceType = 'Node' and State in ('Down') and tb11_id > @save_tb11_id order by tb11_id)
	Select @save_ResourceName = (Select ResourceName from #clust_tb11 where tb11_id = @save_tb11_id)
	Select @save_State = (Select State from #clust_tb11 where tb11_id = @save_tb11_id)


	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Node', 'Fail', 'High', @save_test, null, @save_ResourceName, 'State = ' + @save_State, getdate())


	IF exists (select 1 from #clust_tb11 where ResourceType = 'Node' and State in ('Down') and tb11_id > @save_tb11_id)
	   BEGIN
		goto start_node_check01
	   END
   END
Else IF exists (select 1 from #clust_tb11 where ResourceType = 'Node' and State in ('Paused')) and not exists (select 1 from dbo.No_Check where NoCheck_type = 'Cluster' and detail01 = 'node paused')
   BEGIN
	Select @save_tb11_id = 0
	start_node_check02:
	Select @save_tb11_id = (Select top 1 tb11_id from #clust_tb11 where ResourceType = 'Node' and State in ('Paused') and tb11_id > @save_tb11_id order by tb11_id)
	Select @save_ResourceName = (Select ResourceName from #clust_tb11 where tb11_id = @save_tb11_id)
	Select @save_State = (Select State from #clust_tb11 where tb11_id = @save_tb11_id)


	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Node', 'Fail', 'High', @save_test, null, @save_ResourceName, 'State = ' + @save_State, getdate())


	IF exists (select 1 from #clust_tb11 where ResourceType = 'Node' and State in ('Paused') and tb11_id > @save_tb11_id)
	   BEGIN
		goto start_node_check02
	   END
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Node', 'Pass', 'High', @save_test, null, 'All nodes are Up', null, getdate())
   END


--CLUSTER VERIFICATIONS - INSTANCE ON NODE ALONE
Print 'Start Check for CLUSTER - INSTANCE ON NODE ALONE'
Print ''


Select @save_test = 'select * From DBAOps.dbo.dbaudf_ListClusterResource()'
Select @save_machine_name = (select convert(sysname, SERVERPROPERTY('ComputerNamePhysicalNetBIOS')))
IF (select count(*) from #clust_tb11 where ResourceType = 'SQL Server' and CurrentOwner = @save_machine_name) > 1
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Alone on Node', 'Fail', 'High', @save_test, null, 'Multiple SQL instances are running on node ' + @save_machine_name, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Alone on Node', 'Pass', 'High', @save_test, null, 'Single SQL instance on node ' + @save_machine_name, null, getdate())
   END


Delete from #clust_tb11 where ResourceType = 'Node'


--CLUSTER VERIFICATIONS - RESOURCES ONLINE
Print 'Start Check for CLUSTER - Resources'
Print ''


Select @save_test = 'select * From DBAOps.dbo.dbaudf_ListClusterResource() --dbaudf_ListClusterNode(), dbaudf_ListClusterNetwork(), dbaudf_ListClusterNetworkInterface()'
Select @skip_networkname_flag = 'n'


--  special processing for multi-subnet clusters (some IP Address may be offline)
If (select count(distinct (left(resourcedetail, 6))) From DBAOps.dbo.dbaudf_ListClusterResource() where resourcetype = 'IP Address') > 1
   begin
	Select @save_count01 = (Select count(*) from #clust_tb11 where ResourceType = 'IP Address')
	Select @save_count02 = (Select count(*) from #clust_tb11 where ResourceType = 'IP Address' and state in ('Online', 'Up'))


	If @save_count02 < (@save_count01/2)
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster IP Resources', 'Fail', 'High', @save_test, null, 'IP resources are offline for this Multi-SubNet cluster ', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster IP Resources', 'Pass', 'High', @save_test, null, 'At least half of the IP(s) for this Multi-SubNet cluster are online', null, getdate())
		Select @skip_networkname_flag = 'y'
	   END


	Delete from #clust_tb11 where ResourceType = 'IP Address'
   end


Delete from #clust_tb11 where state in ('Online', 'Up')


If @skip_networkname_flag = 'y'
   begin
	Delete from #clust_tb11 where ResourceType = 'Network Name'
   end


IF (select count(*) from #clust_tb11) > 0
   BEGIN
	start_Resources:
	Select @save_tb11_id = (Select top 1 tb11_id from #clust_tb11 order by tb11_id)
	Select @save_ResourceName = (Select ResourceName from #clust_tb11 where tb11_id = @save_tb11_id)
	Select @save_State = (Select State from #clust_tb11 where tb11_id = @save_tb11_id)


	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Resources', 'Fail', 'High', @save_test, null, @save_ResourceName, 'State = ' + @save_State, getdate())


	Delete from #clust_tb11 where @save_tb11_id = tb11_id
	IF (select count(*) from #clust_tb11) > 0
	   BEGIN
		goto start_Resources
	   END
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Cluster', 'Cluster Resources', 'Pass', 'High', @save_test, null, 'All Resources are Online\Up', null, getdate())
   END


skip_cluster:


Print '--select * from [dbo].[HealthCheckLog] where HCcat like ''Cluster%'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #clust_tb11
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Cluster_Status] TO [public]
GO
