SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_runIndexMaintenance]


/*********************************************************
 **  Stored Procedure dbasp_runIndexMaintenance
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 23, 2012
 **  This procedure runs Index Maintenance tsql code located
 **  in the IndexMaintenanceProcess table.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/23/2012	Steve Ledridge		New Process
--	08/24/2012	Steve Ledridge		Set status to in-work, and set in-work to cancelled.
--	09/11/2012	Steve Ledridge		Added runTSQL processing (forces work to xp_cmdshell)
--	05/29/2013	Steve Ledridge		New code to set in-work rows to cancelled or pending.
--	======================================================================================


/***
--***/


DECLARE
	 @miscprint		varchar(8000)
	,@charpos		int
	,@save_IMP_ID		int
	,@DBname		sysname
	,@sqlscript		nvarchar(max)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@TSQL			varchar(8000)
	,@OutputText		varchar(max)
	,@save_DBname		sysname
	,@save_TBLname		sysname


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Set in-work row to cancelled or back to pending
If exists (select 1 from [dbo].[IndexMaintenanceProcess] where status = 'in-work')
   begin
	If exists (select 1 from master.sys.sysprocesses where (cmd = 'dbcc' or cmd like 'UPDATE STATISTIC%'))
	   begin
		Select @save_DBname = (select top 1 DBname from dbo.IndexMaintenanceProcess where status = 'in-work')
		Select @save_TBLname = (select top 1 TBLname from dbo.IndexMaintenanceProcess where status = 'in-work')


		Print 'Index Maint Process:  In-work row (and all related rows) set to cancelled for Table ' + @save_TBLname
   		update dbo.IndexMaintenanceProcess set status = 'cancelled', ModDate = getdate() where status not in ('cancelled', 'completed') and DBname = @save_DBname and TBLname = @save_TBLname
	   end
	Else
	   begin
		Print 'Index Maint Process:  In-work row set back to pending'
	   	update dbo.IndexMaintenanceProcess set status = 'pending' where status = 'in-work'
	   end
   end


--  Check for rows to process
If exists (select 1 from [dbo].[IndexMaintenanceProcess] where status not in ('completed', 'cancelled'))
   begin
	Print 'Index Maint Process:  Start process'

	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_indexmaint')
	   begin
		update dbo.Local_ServerEnviro set env_detail = 'running' where env_type = 'check_indexmaint'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values ('check_indexmaint', 'running')
	   end
   end
Else
   begin
	Print 'Index Maint Process:  No rows to process'
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/

start01:


--  Check to see if a stop has been requested
If exists(select 1 from dbo.Local_ServerEnviro where env_type = 'check_indexmaint' and env_detail like 'stop%')
   begin
	Print 'DBA Note:  A stop for this Index Maint process has been requested'
	Print ''
	goto label99
   end

Select @save_IMP_ID = (select top 1 IMP_ID from [dbo].[IndexMaintenanceProcess] where status not in ('completed', 'cancelled') order by IMP_ID)
Select @DBname = (select DBname from [dbo].[IndexMaintenanceProcess] where IMP_ID = @save_IMP_ID)
Select @sqlscript = (select MAINTsql from [dbo].[IndexMaintenanceProcess] where IMP_ID = @save_IMP_ID)
--Select @sqlscript = replace(@sqlscript, '''', '''''')
Print @sqlscript
Print ''
raiserror('', -1,-1) with nowait


If (SELECT CONVERT(sysname, DATABASEPROPERTYEX(@DBname, 'status'))) <> 'ONLINE'
   begin
	Update [dbo].[IndexMaintenanceProcess] set status = 'cancelled', ModDate = getdate() where DBname = @DBname and status not in ('completed', 'cancelled')
	Print 'Skip DB ' + @DBname + '.  DB is not online.'
	Print ''
	raiserror('', -1,-1) with nowait
   end
Else
   begin
	Print 'Starting...'
	raiserror('', -1,-1) with nowait
	Update [dbo].[IndexMaintenanceProcess] set status = 'in-work', ModDate = getdate() where IMP_ID = @save_IMP_ID


	If len(@sqlscript) < 8000
	   begin
		Print ''
		Print '--dbo.dbasp_RunTSQL start'
		Print ''
		raiserror('', -1,-1) with nowait


		Select @TSQL = convert(varchar(8000), @sqlscript)
		exec dbo.dbasp_RunTSQL @TSQL = @TSQL, @OutputMatrix = 4, @OutputText = @OutputText out


		Print @OutputText
		Print ''
		Print '--dbo.dbasp_RunTSQL end'
		Print ''
		raiserror('', -1,-1) with nowait
	   end
	Else
	   begin
		EXEC master.sys.sp_executeSQL @sqlscript
	   end


	Update [dbo].[IndexMaintenanceProcess] set status = 'completed', ModDate = getdate() where IMP_ID = @save_IMP_ID
   end


--  Check for more rows to process
If exists (select 1 from [dbo].[IndexMaintenanceProcess] where status not in ('completed', 'cancelled'))
   begin
	goto start01
   end


----------------  End  -------------------
label99:


If exists (select 1 from [dbo].[IndexMaintenanceProcess] where status not in ('completed', 'cancelled'))
   begin
	Print 'Index Maint Process:  Process On-Hold'

	If exists (select 1 from dbo.Local_ServerEnviro where env_type = 'check_indexmaint')
	   begin
		update dbo.Local_ServerEnviro set env_detail = 'on-hold' where env_type = 'check_indexmaint'
	   end
	Else
	   begin
		Insert into dbo.Local_ServerEnviro values ('check_indexmaint', 'on-hold')
	   end
   end
Else
   begin
	Delete from dbo.Local_ServerEnviro where env_type = 'check_indexmaint'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_runIndexMaintenance] TO [public]
GO
