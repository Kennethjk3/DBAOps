SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_IndexMaint_Postprocess]


/***************************************************************
 **  Stored Procedure dbasp_IndexMaint_Postprocess
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 21, 2010
 **
 **
 **  Description: Run update statistic, recompile and other post index maintenance
 **  commands from data located in the local_control table.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date			Author     			Desc
--	==========	====================	=============================================
--	2010-07-21	Steve Ledridge			New Process
--	2010-07-27	Steve Ledridge			Added recompile and forced exec within a transaction
--	2016-11-22	Steve Ledridge			Added Where clause to exclude recompiles on AG Secondaries.
--	======================================================================================


/***


--***/


DECLARE
	 @miscprint			nvarchar(4000)
	,@save_control_id		int
	,@save_detail01			sysname
	,@save_detail02			sysname
	,@save_detail03			nvarchar(4000)
	,@cmd				nvarchar(4000)


----------------  initial values  -------------------


create table #control_Info(control_id int IDENTITY(1,1) NOT NULL
			,detail01 sysname null
			,detail02 sysname null
			,detail03 nvarchar(4000) null)


----------------------  Main header  ----------------------
Print  ' '
Print  '/*******************************************************************'
Select @miscprint = 'Post Index Maintenance Processing'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


If (select count(*) from dbo.local_control where subject in ('UpdateStats','Recompile','PostIndexMaint')) = 0
   begin
	Print 'No rows to process for this sql instance'
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


-- Process Update Stats
delete from #control_Info
insert into #control_Info select detail01, detail02, detail03 from dbo.local_control where subject = 'UpdateStats'
--select * from ##control_Info


If (select count(*) from #control_Info) > 0
   begin
	Print '--Starting UpdateStats'
	Print ''

	start_updatestats:
	Select @save_control_id = (select top (1) control_id from #control_Info order by control_id)
	Select @save_detail01 = (select detail01 from #control_Info where control_id = @save_control_id)
	Select @save_detail02 = (select detail02 from #control_Info where control_id = @save_control_id)


	Select @cmd = @save_detail01 + ' ' + @save_detail02
	Print @cmd
	Select getdate()
	exec (@cmd)
	Print ''


	--  check for more rows to process
	delete from #control_Info where control_id = @save_control_id
	if (select count(*) from #control_Info) > 0
	   begin
		goto start_updatestats
	   end
   end


-- Process Recompiles
delete from #control_Info
insert into #control_Info --select detail01, detail02, detail03 from dbo.local_control where subject = 'Recompile'
select detail01, detail02, detail03
--,DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2)
--,DBAOps.dbo.dbaudf_GetDBAG(DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2))
--,DBAOps.dbo.dbaudf_AG_Get_Primary(DBAOps.dbo.dbaudf_GetDBAG(DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2)))
from dbo.local_control
where subject = 'Recompile'
AND DBAOps.dbo.dbaudf_AG_Get_Primary(DBAOps.dbo.dbaudf_GetDBAG(DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2))) = @@Servername


--select * from ##control_Info


If (select count(*) from #control_Info) > 0
   begin
	Print '--Starting Recompiles'
	Print ''


	start_Recompile:
	Select @save_control_id = (select top (1) control_id from #control_Info order by control_id)
	Select @save_detail01 = (select detail01 from #control_Info where control_id = @save_control_id)
	Select @save_detail02 = (select detail02 from #control_Info where control_id = @save_control_id)
	Select @save_detail03 = (select detail03 from #control_Info where control_id = @save_control_id)


	Select @cmd = @save_detail01 + ' @objname = ''' + @save_detail02 + ''''
	Print @cmd
	Select getdate()
	exec (@cmd)
	Print ''


	If @save_detail03 is not null and @save_detail03 <> ''
	   begin
		Print '--Forced first time execution for ' + @save_detail02
		Select @cmd = @save_detail03
		Print @cmd
		Select getdate()
		exec (@cmd)
		Print ''
	   end


	--  check for more rows to process
	delete from #control_Info where control_id = @save_control_id
	if (select count(*) from #control_Info) > 0
	   begin
		goto start_Recompile
	   end
   end


-- Process Recompiles with forced first time exec within a transaction
delete from #control_Info
insert into #control_Info select detail01, detail02, detail03 from dbo.local_control where subject = 'Recompile_withexec' AND DBAOps.dbo.dbaudf_AG_Get_Primary(DBAOps.dbo.dbaudf_GetDBAG(DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2))) = @@Servername


--select * from ##control_Info


If (select count(*) from #control_Info) > 0
   begin
	Print '--Starting Recompiles with forced first time exec within a transaction'
	Print ''


	start_Recompile_exec:
	Select @save_control_id = (select top (1) control_id from #control_Info order by control_id)
	Select @save_detail01 = (select detail01 from #control_Info where control_id = @save_control_id)
	Select @save_detail02 = (select detail02 from #control_Info where control_id = @save_control_id)
	Select @save_detail03 = (select detail03 from #control_Info where control_id = @save_control_id)


	Select @cmd = 'BEGIN TRANSACTION; ' + char(13)+char(10)
	Select @cmd = @cmd + @save_detail01 + ' @objname = ''' + @save_detail02 + '''' + ';' + char(13)+char(10)


	If @save_detail03 is not null and @save_detail03 <> ''
	   begin
		Select @cmd = @cmd + ' ' + @save_detail03 + ';' + char(13)+char(10)
	   end


	Select @cmd = @cmd + ' ' + 'COMMIT TRANSACTION; '
	Print @cmd
	Select getdate()
	exec (@cmd)
	Print ''


	--  check for more rows to process
	delete from #control_Info where control_id = @save_control_id
	if (select count(*) from #control_Info) > 0
	   begin
		goto start_Recompile_exec
	   end
   end


-- Process PostIndexMaint
delete from #control_Info
insert into #control_Info select detail01, detail02, detail03 from dbo.local_control where subject = 'PostIndexMaint' AND DBAOps.dbo.dbaudf_AG_Get_Primary(DBAOps.dbo.dbaudf_GetDBAG(DBAOps.dbo.dbaudf_ReturnPart(replace(replace(detail01,' ','|'),';','|'),2))) = @@Servername


select * from #control_Info


If (select count(*) from #control_Info) > 0
   begin
	Print '--Starting PostIndexMaint'
	Print ''


	start_PostIndexMaint:
	Select @save_control_id = (select top (1) control_id from #control_Info order by control_id)
	Select @save_detail01 = (select detail01 from #control_Info where control_id = @save_control_id)
	Select @save_detail03 = (select detail03 from #control_Info where control_id = @save_control_id)


	Select @cmd = @save_detail01 + ' ' + char(13)+char(10)
	Select @cmd = @cmd + ' ' + @save_detail03
	Print @cmd
	Select getdate()
	exec (@cmd)
	Print ''


	--  check for more rows to process
	delete from #control_Info where control_id = @save_control_id
	if (select count(*) from #control_Info) > 0
	   begin
		goto start_PostIndexMaint
	   end
   end


---------------------------  Finalization  -----------------------
label99:


Select @miscprint = 'Process completed: '  + convert(varchar(30),getdate(),9)
Print  @miscprint


drop table #control_Info
GO
GRANT EXECUTE ON  [dbo].[dbasp_IndexMaint_Postprocess] TO [public]
GO
