SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AG_PropagateJobInfo]


/*********************************************************
 **  Stored Procedure dbasp_AG_PropagateJobInfo
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 21, 2016
 **
 **  This dbasp will Propagate AvailGrp related job info to all nodes.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	04/21/2016	Steve Ledridge		New process.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(500)
	,@cmd				varchar(8000)
	,@save_productversion		sysname
	,@save_AGname			sysname
	,@save_AGrole			sysname
	,@save_nodename			sysname
	,@dynSql			NVARCHAR(MAX)


----------------  initial values  -------------------


CREATE TABLE #secondarynodes (cmdoutput NVARCHAR(400) NULL)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Check for availgrps - if none, exit
IF @@microsoftversion / 0x01000000 >= 11
  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	If not exists (select 1 from sys.availability_groups_cluster)
	   begin
		Select @miscprint = 'No Availability Groups found.'
		Print  @miscprint
		goto label99
	   end
   END


--  Check for availgrp jobs.  If none, exit
If not exists (select 1 from msdb.dbo.sysjobs j, msdb.dbo.syscategories c where j.category_id = c.category_id and c.name like 'AG%')
   BEGIN
	Select @miscprint = 'No Availability Group related jobs found.'
	Print  @miscprint
	goto label99
   END


--  Set status for jobs based in local_control table (subject = 'AG_JobStatus')
Select @save_AGname = ''


Start_AGname:


Select @save_AGname = (select top 1 name from sys.availability_groups_cluster where name > @save_AGname order by name)
--print @save_AGname


Select @save_AGrole = (SELECT ARS.role_desc
			FROM
			 sys.availability_groups_cluster AS AGC
			  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
			   ON
			    RCS.group_id = AGC.group_id
			  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
			   ON
			    ARS.replica_id = RCS.replica_id
			WHERE
			    AGC.name = @save_AGname
			and RCS.replica_server_name = @@servername)
--print @save_AGrole


If @save_AGrole = 'Primary'
   begin
	Select @miscprint = 'Propagate Availability Group related job info.'
	Print  @miscprint


	--  Creat script to update the local_control table for local primary
	Select @dynSql = 'Delete from DBAOps.dbo.local_control where subject = ''AG_job''' + ' '


	SELECT @dynSql = @dynSql + N'Insert into DBAOps.dbo.local_control values(''AG_job'', ''' + j.name + ''', ''' + @save_AGname + ''', ''' + convert(sysname, j.enabled) + ''')' + ' '
	FROM msdb.dbo.sysjobs j, msdb.dbo.syscategories c
	WHERE j.category_id = c.category_id
	and c.name = 'AG_' + @save_AGname
	ORDER BY j.name;
	--PRINT @dynSql
	Exec (@dynSql)


	--  Update all secondary nodes
	DELETE FROM #secondarynodes
	INSERT INTO #secondarynodes
	SELECT RCS.replica_server_name
		FROM
		 sys.availability_groups_cluster AS AGC
		  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
		   ON
		    RCS.group_id = AGC.group_id
		  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
		   ON
		    ARS.replica_id = RCS.replica_id
		WHERE
		    AGC.name = @save_AGname
		and ARS.role_desc <> 'PRIMARY'


	Delete from #secondarynodes where cmdoutput is null
	--select * from #secondarynodes


	If (select count(*) from #secondarynodes) > 0
	   begin
		Start_update_secondaries:
		Select @save_nodename = (select top 1 cmdoutput from #secondarynodes)


		Select @cmd = 'sqlcmd -S' + @save_nodename + ' -dDBAOps -E -Q"' + @dynSql + '"'
		--print @cmd
		EXEC master.sys.xp_cmdshell @cmd--, no_output


		delete from #secondarynodes where cmdoutput = @save_nodename
		If (select count(*) from #secondarynodes) > 0
		   begin
			goto Start_update_secondaries
		   end
	   end
   end


If exists (select top 1 name from sys.availability_groups_cluster where name > @save_AGname order by name)
   begin
	goto Start_AGname
   end


 ---------------------------  Finalization  -----------------------


 label99:


 drop TABLE #secondarynodes
GO
GRANT EXECUTE ON  [dbo].[dbasp_AG_PropagateJobInfo] TO [public]
GO
