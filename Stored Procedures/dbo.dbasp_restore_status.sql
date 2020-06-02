SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_restore_status]


/*********************************************************
 **  Stored Procedure dbasp_restore_status
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 09, 2010
 **
 **  This dbasp will list the status for all active restores.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	12/09/2010	Steve Ledridge		New process
--	06/22/2011	Steve Ledridge		Added code for restore verifyonly.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(255)
	,@cmd				varchar(4000)
	,@save_session_id		smallint
	,@save_start_time		char(19)
	,@save_percent_complete		sysname
	,@save_EventInfo		char(70)


----------------  initial values  -------------------


create table #temp_restores (session_id 		smallint
				,start_time 		datetime null
				,percent_complete	real null
				)


create table #temp_dbcc (EventType		sysname
			,Parameters		int null
			,EventInfo		nvarchar(4000) null
				)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers


Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   Report Active Restores '
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


delete from #temp_restores
insert into #temp_restores select session_id, start_time, percent_complete from master.sys.dm_exec_requests where command like '%restore%'
--select * from #temp_restores


If (select count(*) from #temp_restores) = 0
   begin
	Print 'No restores in process at this time'
	goto label99
   end


Select @miscprint = 'SPID  Start Time           Percent Complete  DBCC InputBuffer'
Print  @miscprint
Select @miscprint = '----  -------------------  ----------------  ----------------------------------------------------------------------'
Print  @miscprint


Start_01:
Select @save_session_id = (select top 1 session_id from #temp_restores order by start_time)
Select @save_start_time = (select convert(char(19), start_time, 121) from #temp_restores where session_id = @save_session_id)
Select @save_percent_complete = (select convert(nvarchar(10), percent_complete, 0) from #temp_restores where session_id = @save_session_id)


select @cmd =  'dbcc inputbuffer(' + convert(nvarchar(10), @save_session_id) + ') with no_infomsgs'
delete from #temp_dbcc
insert into #temp_dbcc exec (@cmd)
--select * from #temp_dbcc
If exists (select 1 from #temp_dbcc where EventInfo like '%RESTORE DATABASE%')
   begin
	Select @save_EventInfo = (select top 1 convert(char(70), EventInfo) from #temp_dbcc where EventInfo like '%RESTORE DATABASE%')
   end
Else If exists (select 1 from #temp_dbcc where EventInfo like '%dpsp_auto_DBrestore%')
   begin
	Select @save_EventInfo = 'dpsp_auto_DBrestore'
   end
Else If exists (select 1 from #temp_dbcc where EventInfo like '%RESTORE VERIFYONLY%')
   begin
	Select @save_EventInfo = 'RESTORE VERIFYONLY'
   end
Else
   begin
	Select @save_EventInfo = 'unknown'
   end


Select @miscprint = convert(char(4), @save_session_id) + '  ' + @save_start_time + '  ' + convert(char(15), @save_percent_complete + '%') + '   ' + @save_EventInfo
Print  @miscprint


--  check for more rows to process
Delete from #temp_restores where session_id = @save_session_id
If (select count(*) from #temp_restores) > 0
   begin
	goto Start_01
   end


--  Finalization  ------------------------------------------------------------------------------
label99:


drop table #temp_restores
drop table #temp_dbcc
GO
GRANT EXECUTE ON  [dbo].[dbasp_restore_status] TO [public]
GO
