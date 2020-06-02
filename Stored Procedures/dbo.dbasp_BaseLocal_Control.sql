SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BaseLocal_Control]


/*********************************************************
 **  Stored Procedure dbasp_BaseLocal_Control
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  June 18, 2010
 **
 **  This sproc will control the SQL baseline push process.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	06/18/2010	Steve Ledridge		New process.
--	======================================================================================


/***
--***/


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(2000)
	,@query				nvarchar(2000)
	,@cmd				nvarchar(4000)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_servername3		sysname
	,@save_baseservername		sysname
	,@save_basesqlname		sysname
	,@save_rq_stamp			sysname
	,@save_more_info		nvarchar(4000)
	,@db_query1			nvarchar(4000)
	,@db_query2			sysname
	,@pong_count			smallint
	,@charpos			int


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @save_servername3	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


--  Create temp tables
CREATE TABLE #SQLname (Servername sysname
			,SQLname sysname)


----------------------  Print the headers  ----------------------


Print  ' '
Select @miscprint = 'SQL Baseline Process:  Start Base Local Processing from Server: ' + @@servername
Print  @miscprint
Select @miscprint = '-- Process run: ' + convert(varchar(30),getdate())
Print  @miscprint
Print  ' '
raiserror('', -1,-1) with nowait


--  Make sure we have rows to process
If (select count(*) from dbo.BaseLocal_Control where status = 'pending') = 0
   begin
	Select @miscprint = 'DBA Warning: No rows to process in dbo.BaseLocal_Control table. '
	Print @miscprint
	raiserror('', -1,-1) with nowait
	GOTO label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


start01:


--  Load the temp table
delete from #SQLname
Insert into #SQLname select ServerName, SQLName from dbo.BaseLocal_Control where status = 'pending'
--select * from #SQLname


--  Start Job process
start02:
Select @save_baseservername = (select top 1 Servername from #SQLname order by ServerName)
Print @save_baseservername
raiserror('', -1,-1) with nowait


If exists (select 1 from dbo.BaseLocal_Control where ServerName = '@save_baseservername' and status = 'in-work')
   begin
	Select @miscprint = 'Skip this server due to in-work process: ' + @save_baseservername
	Print @miscprint
	raiserror('', -1,-1) with nowait
	goto skip01
   end


Select @save_basesqlname = (select top 1 SQLName from #SQLname where servername = @save_baseservername order by SQLName desc)
Print @save_basesqlname
raiserror('', -1,-1) with nowait


--Start baseline job on remote server
SELECT @cmd = 'sqlcmd -S' + @save_basesqlname + ' -E -Q"exec msdb.dbo.sp_start_job @job_name = ''BASE - Local Process''"'
PRINT @cmd
raiserror('', -1,-1) with nowait
EXEC master.sys.xp_cmdshell @cmd


update dbo.BaseLocal_Control set Status = 'in-work' where ServerName = @save_baseservername and SQLName = @save_basesqlname


skip01:
Delete from #SQLname where ServerName = @save_baseservername
If (select count(*) from #SQLname) > 0
   begin
	goto start02
   end


--  Monitor Job process
If exists (select 1 from dbo.BaseLocal_Control where status = 'in-work')
   begin
	--  Load the temp table
	delete from #SQLname
	Insert into #SQLname select ServerName, SQLName from dbo.BaseLocal_Control where status = 'in-work'
	--select * from #SQLname


	start22:
	Select @save_basesqlname = (select top 1 SQLName from #SQLname order by SQLName desc)
	Print @save_basesqlname
	raiserror('', -1,-1) with nowait


	Select @save_rq_stamp = convert(sysname, getdate(), 121) + convert(nvarchar(40), newid())
	Select @db_query1 = 'BASE - Local Process'
	Select @db_query2 = ''
	select @query = 'exec DBAOps.dbo.dbasp_pong @rq_servername = ''' + @@servername
		    + ''', @rq_stamp = ''' + @save_rq_stamp
		    + ''', @rq_type = ''job'', @rq_detail01 = ''' + @db_query1 + ''', @rq_detail02 = ''' + @db_query2 + ''''
	Select @miscprint = 'Requesting info from server ' +@save_basesqlname + '.'
	Print @miscprint
	Select @cmd = 'sqlcmd -S' + @save_basesqlname + ' -E -Q"' + @query + '"'
	print @cmd
	raiserror('', -1,-1) with nowait
	EXEC master.sys.xp_cmdshell @cmd, no_output


	--  capture pong results
	Select @save_more_info = ''
	select @pong_count = 0
	start_pong_result:
	Waitfor delay '00:00:05'
	If exists (select 1 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
	   begin
		Select @save_more_info = (select pong_detail01 from DBAOps.dbo.pong_return where pong_stamp = @save_rq_stamp)
	   end
	Else If @pong_count < 5
	   begin
		Select @pong_count = @pong_count + 1
		goto start_pong_result
	   end


	If @save_more_info like '%JOB Running%'
	   begin
		Delete from #SQLname where SQLname = @save_basesqlname
	   end
	Else
	   begin
		Delete from dbo.BaseLocal_Control where SQLname = @save_basesqlname
		Delete from #SQLname where SQLname = @save_basesqlname
	   end

	Print @save_more_info
	Print ''
	raiserror('', -1,-1) with nowait


	If (select count(*) from #SQLname) > 0
	   begin
		goto start22
	   end


   end


If (select count(*) from dbo.BaseLocal_Control) > 0
   begin
	Waitfor delay '00:00:35'
	goto start01
   end


-----------------  Finalizations  ------------------


label99:


drop table #SQLname
GO
GRANT EXECUTE ON  [dbo].[dbasp_BaseLocal_Control] TO [public]
GO
