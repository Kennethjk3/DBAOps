SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_mirror_status] (@show_detail smallint = 0)


/*********************************************************
 **  Stored Procedure dbasp_mirror_status
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 30, 2010
 **
 **  This dbasp will list the status for all mirrored databases.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	03/30/2012	Steve Ledridge		New process
--	======================================================================================


/*
declare @show_detail smallint


select @show_detail = 1
--*/


-----------------  declares  ------------------


DECLARE
	 @miscprint				varchar(255)
	,@cmd					varchar(4000)
	,@save_DBname				sysname
	,@save_mirroring_state_desc		sysname
	,@save_mirroring_role_desc		sysname
	,@save_mirroring_partner_instance	sysname
	,@save_unsent_log			int
	,@save_send_rate			int
	,@save_time_recorded			datetime
	,@save_time_behind			datetime
	,@save_time_diff			int
	,@save_unrestored_log			int
	,@save_recovery_rate			int
	,@save_mirror_alert_datetime		sysname


----------------  initial values  -------------------


create table #database_mirroring (
	DBname sysname,
	mirroring_state int,
	mirroring_state_desc sysname,
	mirroring_role_desc sysname,
	mirroring_partner_instance sysname)


create table #dbmmonitorresults (
	DBname sysname,
	role int,
	mirroring_state int,
	witness_status int,
	log_generation_rate int,
	unsent_log int,
	send_rate int,
	unrestored_log int,
	recovery_rate int,
	transaction_delay int,
	transactions_per_sec int,
	average_delay int,
	time_recorded datetime,
	time_behind datetime,
	local_time datetime)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   Report Morrored Database Status '
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


delete from #database_mirroring
insert into #database_mirroring select db_name(database_id), mirroring_state, mirroring_state_desc, mirroring_role_desc, mirroring_partner_instance from msdb.sys.database_mirroring where mirroring_guid is not null
--select * from #database_mirroring


If (select count(*) from #database_mirroring) = 0
   begin
	Select @miscprint = 'No mirrored databases found for this SQL instance'
	Print  @miscprint
	Print  ' '
	goto label99
   end


--  Check for recent alerts
If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'mirror_alert_sent')
   begin
	Select @save_mirror_alert_datetime = (select top 1 env_detail from dbo.Local_ServerEnviro where env_type = 'mirror_alert_sent')
	Select @miscprint = 'ALERT: Recent mirroring alert was sent: ' + @save_mirror_alert_datetime
	Print @miscprint
	Print ''
   end


--  Loop for PRINCIPAL
delete from #database_mirroring where mirroring_role_desc <> 'PRINCIPAL'
If (select count(*) from #database_mirroring) > 0
   begin
	Select @miscprint = 'DB Name                    State            Role          Partner               Unsent Log    Send Rate  Time Behind (min)'
	Print  @miscprint
	Select @miscprint = '-------------------------  ---------------  ------------  --------------------  ------------  ---------  -----------------'
	Print  @miscprint


	start01:
	Select @save_DBname = (select top 1 DBname from #database_mirroring order by DBname)
	Select @save_mirroring_state_desc = (select mirroring_state_desc from #database_mirroring where DBname = @save_DBname)
	Select @save_mirroring_role_desc = (select mirroring_role_desc from #database_mirroring where DBname = @save_DBname)
	Select @save_mirroring_partner_instance = (select mirroring_partner_instance from #database_mirroring where DBname = @save_DBname)

	delete from #dbmmonitorresults
	insert into #dbmmonitorresults exec msdb.sys.sp_dbmmonitorresults @save_DBname, 0, 0
	--select * from #dbmmonitorresults


	Select @save_unsent_log = (select top 1 unsent_log from #dbmmonitorresults order by time_recorded desc)
	Select @save_send_rate = (select top 1 send_rate from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_recorded = (select top 1 time_recorded from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_behind = (select top 1 time_behind from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_diff = datediff(mi, @save_time_behind, @save_time_recorded)

	Select @miscprint = convert(char(25), @save_DBname) + '  '
			+ convert(char(15), @save_mirroring_state_desc) + '  '
			+ convert(char(12), @save_mirroring_role_desc) + '  '
			+ convert(char(20), @save_mirroring_partner_instance) + '  '
			+ convert(char(12), @save_unsent_log) + '  '
			+ convert(char(9), @save_send_rate) + '  '
			+ convert(char(9), @save_time_diff)
	Print  @miscprint

	--  check for more rows to process
	delete from #database_mirroring where DBname = @save_DBname
	If (select count(*) from #database_mirroring) > 0
	   begin
		delete from #dbmmonitorresults
		goto start01
	   end
   end


--  Loop for MIRROR
delete from #database_mirroring
insert into #database_mirroring select db_name(database_id), mirroring_state, mirroring_state_desc, mirroring_role_desc, mirroring_partner_instance from msdb.sys.database_mirroring where mirroring_guid is not null
--select * from #database_mirroring
delete from #database_mirroring where mirroring_role_desc <> 'MIRROR'
If (select count(*) from #database_mirroring) > 0
   begin
	Select @miscprint = 'DB Name                    State            Role          Partner               Unrestored Log    Recovery Rate  Time Behind (min)'
	Print  @miscprint
	Select @miscprint = '-------------------------  ---------------  ------------  --------------------  ----------------  -------------  -----------------'
	Print  @miscprint


	start02:
	Select @save_DBname = (select top 1 DBname from #database_mirroring order by DBname)
	Select @save_mirroring_state_desc = (select mirroring_state_desc from #database_mirroring where DBname = @save_DBname)
	Select @save_mirroring_role_desc = (select mirroring_role_desc from #database_mirroring where DBname = @save_DBname)
	Select @save_mirroring_partner_instance = (select mirroring_partner_instance from #database_mirroring where DBname = @save_DBname)

	delete from #dbmmonitorresults
	insert into #dbmmonitorresults exec msdb.sys.sp_dbmmonitorresults @save_DBname, 0, 0
	--select * from #dbmmonitorresults


	Select @save_unrestored_log = (select top 1 unrestored_log from #dbmmonitorresults order by time_recorded desc)
	Select @save_recovery_rate = (select top 1 recovery_rate from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_recorded = (select top 1 time_recorded from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_behind = (select top 1 time_behind from #dbmmonitorresults order by time_recorded desc)
	Select @save_time_diff = datediff(mi, @save_time_behind, @save_time_recorded)

	Select @miscprint = convert(char(25), @save_DBname) + '  '
			+ convert(char(15), @save_mirroring_state_desc) + '  '
			+ convert(char(12), @save_mirroring_role_desc) + '  '
			+ convert(char(20), @save_mirroring_partner_instance) + '  '
			+ convert(char(16), @save_unrestored_log) + '  '
			+ convert(char(13), @save_recovery_rate) + '  '
			+ convert(char(9), @save_time_diff)
	Print @miscprint


	--  check for more rows to process
	delete from #database_mirroring where DBname = @save_DBname
	If (select count(*) from #database_mirroring) > 0
	   begin
		delete from #dbmmonitorresults
		goto start02
	   end
   end


If @show_detail = 1
   begin
	delete from #database_mirroring
	insert into #database_mirroring select db_name(database_id), mirroring_state, mirroring_state_desc, mirroring_role_desc, mirroring_partner_instance from msdb.sys.database_mirroring where mirroring_guid is not null
	--select * from #database_mirroring


	If (select count(*) from #database_mirroring) > 0
	   begin
		start03:
		Select @save_DBname = (select top 1 DBname from #database_mirroring order by DBname)

		delete from #dbmmonitorresults
		insert into #dbmmonitorresults exec msdb.sys.sp_dbmmonitorresults @save_DBname, 1, 0
		Print ''
		select * from #dbmmonitorresults


		--  check for more rows to process
		delete from #database_mirroring where DBname = @save_DBname
		If (select count(*) from #database_mirroring) > 0
		   begin
			delete from #dbmmonitorresults
			goto start03
		   end
	   end


   end


--  Finalization  ------------------------------------------------------------------------------
label99:


drop table #database_mirroring
drop table #dbmmonitorresults
GO
GRANT EXECUTE ON  [dbo].[dbasp_mirror_status] TO [public]
GO
