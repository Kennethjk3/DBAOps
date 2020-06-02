SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_updatestats] (@Large_count int = 100000
					,@med_count int = 10000
					,@Small_count int = 1000
					,@Large_pct dec(10,5) = 0.01000
					,@Med_pct dec(10,5) = 0.05000
					,@Small_pct dec(10,5) = 0.10000
					,@PlanName varchar(500) = 'mplan_user_defrag'
					)


/***************************************************************
 **  Stored Procedure dbasp_updatestats
 **  Written by Steve Ledridge, Virtuoso
 **  February 08, 2006
 **
 **  This procedure creates a file to run the update stats process.
 **  Commands to update stats are based on a percentage of rows modified
 **  compared to the row count (both found in sysindexes).  Using the
 **  input parms, you can specifiy different percentages for large, medium
 **  and small row counts.  You can also set the values to define what a
 **  large, medium and small row count is.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/08/2006	Steve Ledridge		New process
--	02/17/2006	Steve Ledridge		Modified for sql 2005
--	======================================================================================


/***
declare @Large_count int
declare @med_count int
declare @Small_count int
declare @Large_pct float
declare @Med_pct float
declare @Small_pct float
declare @PlanName varchar(500)


select @Large_count = 100000
select @med_count = 1000
select @Small_count = 100
select @Large_pct = 0.01000
select @Med_pct = 0.05000
select @Small_pct = 0.10000
select @PlanName = 'mplan_user_defrag'
--***/


Declare
	 @miscprint			nvarchar(4000)
	,@save_DBname		sysname
	,@error_count		int
	,@cmd				nvarchar(500)
	,@query				nvarchar(3000)
	,@owner				sysname
	,@rowmodctr_limit	int
	,@save_ObjectName	sysname
	,@save_rowcnt		bigint
	,@save_rowmodctr	int
	,@save_objid		int
	,@save_pct			float


DECLARE
	 @cu11DBName		sysname
	,@cu11DBId			smallint
	,@cu11DBStatus		int


----------------  initial values  -------------------
Select @error_count = 0
Select @save_DBname = ''
Select @rowmodctr_limit = 0


--  Create table variable
declare @dbnames table	(name		sysname
			,dbid		smallint
			,status		int
			)


Create table #temp_upstat (
		objid int,
		owner nvarchar(255),
		objname sysname,
		rowcnt bigint,
		rowmodctr int
		)


/****************************************************************
*                MainLine
***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'SQL Update Statistics Process'
Print  @miscprint
Select @miscprint = 'Created For Server: ' + @@servername + ' on ' + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  ' '
Print  '************************************************************************/'


Insert into @dbnames (name, dbid, status)
Select distinct(d.database_name), db.dbid, db.status
From msdb.dbo.sysdbmaintplan_databases  d with (NOLOCK), msdb.dbo.sysdbmaintplans  s with (NOLOCK), master.sys.sysdatabases db with (NOLOCK)
Where d.plan_id = s.plan_id
  and s.plan_name = @PlanName
  and db.name = d.database_name


delete from @dbnames where name is null or name = ''
--select * from @dbnames


If (select count(*) from @dbnames) > 0
   begin
	start_dbnames:


	Select @cu11DBName = (select top 1 name from @dbnames)
	Select @cu11DBId = dbid from @dbnames where name = @cu11DBName
	Select @cu11DBStatus = status from @dbnames where name = @cu11DBName
	Print ' '
	Print ' '


	Print '---------------------------------------------------------------------------'
	Print '--  Start process for database ' + @cu11DBName
	Print '---------------------------------------------------------------------------'
	Select @miscprint = 'Use ' + @cu11DBName
	Print @miscprint
	Print 'go'
	Print ' '


	Print  ' '
	Select @miscprint = '-- UPDATING USAGE for database ' + (rtrim(@cu11DBName))
	Print  @miscprint
	Select @miscprint = 'Print ''Start Update Usage for database ' + rtrim(@cu11DBName) + ''''
	Print @miscprint
	Print 'Select getdate()'
	Print  ' '
	Select @cmd = 'dbcc updateusage(' + rtrim(@cu11DBName) + ') with no_infomsgs'
	Print @cmd
	Print  ' '
	Print  ' '


	Delete from #temp_upstat
	Select @query = 'select so.object_id, sc.name, so.name, si.rowcnt, si.rowmodctr
	from ' + @cu11DBName + '.sys.sysindexes  si, ' + @cu11DBName + '.sys.objects so, ' + @cu11DBName + '.sys.schemas  sc
	where si.id = so.object_id
	and so.type = ''u''
	and si.rowmodctr > ' + convert(varchar(20), @rowmodctr_limit) + '
	and si.rowcnt > 0
    and sc.schema_id = so.schema_id
	order by so.name'


	Insert into #temp_upstat exec (@query)
	--select * from #temp_upstat


	If (select count(*) from #temp_upstat) > 0
	   begin
		Select @miscprint = 'Print ''Start Update Stats Processing for database ' + @cu11DBName + ''''
		Print @miscprint
		Print 'Select getdate()'
		Print 'go'
		Print ' '


		start_loop:


		Select @save_objid = (select top 1 objid from #temp_upstat)
		Select @save_rowcnt = (select rowcnt from #temp_upstat where objid = @save_objid)
		Select @save_rowmodctr = (select rowmodctr from #temp_upstat where objid = @save_objid)
		Select @save_ObjectName = (select top 1 objname from #temp_upstat where objid = @save_objid)
		Select @owner = (select owner from #temp_upstat where objid = @save_objid and objname = @save_ObjectName)


	--print @save_ObjectName
	--select @save_rowmodctr
	--select @save_rowcnt
	--print @owner


		Select @save_pct = CONVERT(float, @save_rowmodctr) / CONVERT(float, @save_rowcnt)


		If (@save_pct > @Large_pct and @save_rowcnt > @Large_count)
		  or (@save_pct > @Med_pct and @save_rowcnt > @med_count)
		  or (@save_pct > @Small_pct and @save_rowcnt < @med_count)
		   begin
	--print @save_ObjectName
	--select @save_rowmodctr
	--select @save_rowcnt


			Print  ' '
			Print  ' '
			Select @miscprint = '-- UPDATING STATISTICS for table ' + (rtrim(@save_ObjectName)) + ' (rowcnt = ' + convert(varchar(20), @save_rowcnt) + ', rowmodcnt = ' + convert(varchar(20), @save_rowmodctr) + ')'
			Print  @miscprint
			Select @miscprint = 'Print ''Start Update Stats on table ' + rtrim(@save_ObjectName) + ''''
			Print @miscprint
			Print 'Select getdate()'
			Print  ' '


			If @save_rowcnt > @Large_count
			   begin
				Select @cmd = 'UPDATE STATISTICS [' + @owner + '].[' + rtrim(@save_ObjectName) + '] WITH SAMPLE 10 PERCENT'
				Print @cmd
			   end
			Else
			   begin
				Select @cmd = 'UPDATE STATISTICS [' + @owner + '].[' + rtrim(@save_ObjectName) + '] WITH SAMPLE 20 PERCENT'
				Print @cmd
			   end


		   end


		Delete from #temp_upstat where objname = @save_ObjectName and objid = @save_objid


		If (select count(*) from #temp_upstat) > 0
		   begin
			goto start_loop
		   end


	   end


	--  Remove this record from @dbname and go to the next
	delete from @dbnames where name = @cu11DBName
	If (select count(*) from @dbnames) > 0
	   begin
		goto start_dbnames
	   end


   end


--  Finalization
--------------------------------------------------------------------
Print ' '
Select @miscprint = 'Print ''End Update Stats on database ' + @cu11DBName + ''''
Print @miscprint
Print 'Select getdate()'
Print 'go'
Print ' '


Print  ' '
Print
'/************************************************************************'
Select @miscprint = 'SQL Update Stats Process Complete '
Print  @miscprint
Print
'************************************************************************/'


drop table #temp_upstat
GO
GRANT EXECUTE ON  [dbo].[dbasp_updatestats] TO [public]
GO
