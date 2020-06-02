SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_DB_Backups] (@dbname sysname = null
					,@HCcat sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_HC_DB_Backups
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 10, 2015
 **  This procedure runs the DB Backup portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/10/2015	Steve Ledridge		New process.
--	03/11/2015	Steve Ledridge		Modified AvailGrp code.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  Check Backups


/***
Declare @dbname sysname
Declare @HCcat sysname


Select @dbname = 'DWstage'
Select @HCcat = 'UserDB'
--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@hold_backup_start_date		DATETIME
	,@save_backup_start_date		sysname
	,@save_AvailGrp_role			sysname
	,@save_AvailGrp				char(1)


----------------  initial values  -------------------


Select @save_AvailGrp = 'n'


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


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Select @miscprint = 'Start DB Backup check for: ' + @dbname
Print  @miscprint
Print  ' '


--  Check for Availability Group - preferred backup location
IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
   begin
	If @dbname in (Select dbcs.database_name
			FROM master.sys.availability_groups AS AG
			LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
			   ON AG.group_id = agstates.group_id
			INNER JOIN master.sys.availability_replicas AS AR
			   ON AG.group_id = AR.group_id
			INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
			   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
			INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
			   ON arstates.replica_id = dbcs.replica_id)
	   begin
		Select @save_AvailGrp = 'y'


		If (select sys.fn_hadr_backup_is_preferred_replica(@dbname)) = 0
		   begin
			Select @miscprint = 'Skipping DB ' + @dbname + '.  Not preferred backup location for AvailGrp DB.'
			Print  @miscprint
			Print  ' '
			goto label99
		   end
	   end
   end


--  Check to see if AvailGrp is secondary
If @save_AvailGrp = 'y'
   begin
	Select @save_AvailGrp_role = (Select arstates.role_desc
					FROM master.sys.availability_replicas AS AR
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					   ON arstates.replica_id = dbcs.replica_id
					where AR.replica_server_name = @@servername
					and dbcs.database_name = @dbname)
   end


--  Check for backups
Print 'Start ''' + @dbname + ''' Backup check'
Print ''


--  Get the backup time for the last full database backup
SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
					WHERE database_name = @dbname
					AND backup_finish_date IS NOT NULL
					AND type IN ('D', 'F')
					ORDER BY backup_start_date DESC)

SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)

Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''' + @dbname + ''' AND backup_finish_date IS NOT NULL AND type IN (''D'', ''F'') ORDER BY backup_start_date DESC'
IF @hold_backup_start_date IS NULL
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Full', 'Fail', 'Critical', @save_test, @dbname, 'No DBbackup found', null, getdate())
   END
If DATABASEPROPERTY(rtrim(@dbname), 'IsReadOnly') = 1
    BEGIN
	IF @hold_backup_start_date < getdate()-28
	   BEGIN
		insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Full', 'Fail', 'Critical', @save_test, @dbname, 'No recent DBbackup found for ReadOnly DB', null, getdate())
	   END
	Else
	   BEGIN
		insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Full', 'Pass', 'Critical', @save_test, @dbname, @save_backup_start_date, 'ReadOnly DB', getdate())
	   END
   END
ELSE IF @hold_backup_start_date < getdate()-8
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Full', 'Fail', 'Critical', @save_test, @dbname, 'No recent DBbackup found', null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Full', 'Pass', 'Critical', @save_test, @dbname, @save_backup_start_date, null, getdate())
   END


--  Check for differentials
Print 'Start ''' + @dbname + ''' Differential check'
Print ''


If @save_AvailGrp = 'y' and @save_AvailGrp_role = 'SECONDARY'
   begin
	Select @miscprint = 'Skipping DB ' + @dbname + '.  AvailGrp differentials not created on secondaries.'
	Print  @miscprint
	Print  ' '
	goto skip_diff
   end


SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
						WHERE database_name =@dbname
						AND backup_finish_date IS NOT NULL
						AND type = 'I'
						ORDER BY backup_start_date DESC)

SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)


Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''' + @dbname + ''' AND backup_finish_date IS NOT NULL AND type = ''I'' ORDER BY backup_start_date DESC'
IF @hold_backup_start_date IS NULL
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Dfntl', 'Fail', 'Critical', @save_test, @dbname, 'No Differential backup found', null, getdate())
   END
ELSE IF @hold_backup_start_date < getdate()-2
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Dfntl', 'Fail', 'Critical', @save_test, @dbname, 'No recent Differential backup found', null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup Dfntl', 'Pass', 'Critical', @save_test, @dbname, @save_backup_start_date, null, getdate())
   END


skip_diff:


--  check for tranlog backups
IF DATABASEPROPERTY(RTRIM(@dbname), 'IsTrunclog') = 0
   BEGIN
	Print 'Start ''' + @dbname + ''' Tranlog check'
	Print ''


	If @save_AvailGrp = 'y' and @save_AvailGrp_role = 'SECONDARY'
	   begin
		Select @miscprint = 'Skipping DB ' + @dbname + '.  AvailGrp TranLog backups may or may not be created on secondaries.'
		Print  @miscprint
		Print  ' '
		goto skip_TLog
	   end


	SELECT @hold_backup_start_date  = (SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset
						WHERE database_name = @dbname
						AND backup_finish_date IS NOT NULL
						AND type = 'L'
						ORDER BY backup_start_date DESC)

	SELECT @save_backup_start_date = CONVERT(NVARCHAR(30), @hold_backup_start_date, 121)


	Select @save_test = 'SELECT TOP 1 backup_start_date FROM msdb.dbo.backupset WHERE database_name = ''' + @dbname + ''' AND backup_finish_date IS NOT NULL AND type = ''L'' ORDER BY backup_start_date DESC'
	IF @hold_backup_start_date IS NULL
	   BEGIN
		insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup TrnLog', 'Fail', 'Critical', @save_test, @dbname, 'No Tranlog backup found', null, getdate())
	   END
	ELSE IF @hold_backup_start_date < getdate()-1
	   BEGIN
		insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup TrnLog', 'Fail', 'Critical', @save_test, @dbname, 'No recent Tranlog backup found', null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values (@HCcat, 'Backup TrnLog', 'Pass', 'Critical', @save_test, @dbname, @save_backup_start_date, null, getdate())
	   END
   END


skip_TLog:


--  Finalization  ------------------------------------------------------------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_DB_Backups] TO [public]
GO
