SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_REPORTTempDB] (@check_top_offender char(5) = 'n', @kill char(5)='n')


/*********************************************************
 **  Stored Procedure dbasp_REPORTTempDB
 **  Written by Steve Ledridge, Virtuoso
 **  March 9, 2009
 **
 **  This dbasp is set up to report the current TempDB database space
 **  allocation.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/09/2009	Steve Ledridge		New report
--	03/10/2009	Steve Ledridge	        Added the following parameters:
--						@check_top_offender--Returns the Top 5 offenders
--						@kill --enables the kill of the SPID in the Top 5
--	======================================================================================


-----------------  declares  ------------------


declare	     @miscprint		nvarchar(255)
	    ,@volume		varchar(10)
	    ,@tempdbPath	varchar(255)
            ,@dirCmd		nvarchar(4000)
	    ,@fixeddrivefreeMB  int
	    ,@volumefreespace	int
	    ,@freespace		int
	    ,@usedspace		int
	    ,@totalspaceusage	int
	    ,@percentagework	decimal(18,2)


declare	     @spid		int
	    ,@cmd		nvarchar(4000)
/*
declare @check_top_offender char(5)
declare @kill char(5)
set @check_top_offender = 'n'
set @kill = 'n'


*/


/****************************************************************
 *                Initialization
 ***************************************************************/


declare @tempFixedDrives table(drl char(1), mbfree int)


create table #tempfiledir(toutput nvarchar(4000))


/****************************************************************
 *                MainLine
 ***************************************************************/
--Update the Space Usage information first
---DBCC UPDATEUSAGE (TempDB) WITH NO_INFOMSGS


--Get the TempDB Volume
select
    top(1)
    @volume  = substring(physical_name,1,1)
from sys.master_files
where db_name(database_id)='tempdb'
and type_desc = 'rows'


--Get the TempDB Path
select
    top(1)
    @tempdbPath = reverse(substring(reverse(physical_name),charindex('\',reverse(physical_name))+1,LEN(physical_name)))
from sys.master_files
where db_name(database_id)='tempdb'
and type_desc = 'rows'


select
     @usedspace =((sum (user_object_reserved_page_count)*8) +(sum (internal_object_reserved_page_count)*8) + (sum (version_store_reserved_page_count)*8)+(sum (mixed_extent_page_count)*8))/1024
    ,@freespace = ((sum (unallocated_extent_page_count)*8))/1024
from sys.dm_db_file_space_usage


set @totalspaceusage = @usedspace +@freespace


set @percentagework = (convert(numeric(18,2),@usedspace)/convert(numeric(18,2),@totalspaceusage))*100


----------------------  Print the headers  ----------------------


Print  '/*******************************************************************'
Select @miscprint = '   REPORT DISK & DATABASE USAGE FOR SERVER: ' + @@servername
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate())
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


--check and see if is alone or with others


set @dirCmd = 'dir '+@tempdbPath


insert into #tempfiledir
exec xp_cmdshell @dirCmd


delete from #tempfiledir where toutput like '%volume%'
delete from #tempfiledir where toutput like '%directory%'
delete from #tempfiledir where toutput like '%<DIR>%'
delete from #tempfiledir where toutput like '%file%'
delete from #tempfiledir where toutput like '%dir%'
delete from #tempfiledir where toutput is null


--print convert(varchar(10), @fixeddrivefreeMB)


if(select count(*) from #tempfiledir where toutput not like '%temp%') = 0


    begin


	Select @miscprint = 'Percentage used in TempDB = ' + convert(varchar(20),@percentagework )+'%'
	print  @miscprint
	print '  '
	Select @miscprint = 'Used Space for TempDB = '+convert(varchar(10),@usedspace)+' MB'
	print  @miscprint
	print '  '
	Select @miscprint = 'Free Space for TempDB = '+convert(varchar(10),@freespace)+' MB'
	print  @miscprint
	print '  '
	Select @miscprint = 'Total TempDB file size = '+convert(varchar(10),@totalspaceusage) +' MB'
	print  @miscprint
	print '  '
	Select @miscprint ='TempDB resides on '+@tempdbPath
	print  @miscprint
	print '  '
    end
else
    begin


	insert into @tempFixedDrives
	exec xp_fixeddrives


	set @fixeddrivefreeMB = (select mbfree from @tempFixedDrives where drl = @volume)


	Select @miscprint = 'Percentage used in TempDB = ' + convert(varchar(20),@percentagework )+'%'
	print  @miscprint
	print '  '
	Select @miscprint = 'Used Space for TempDB = '+convert(varchar(10),@usedspace)+' MB'
	print  @miscprint
	print '  '
	Select @miscprint = 'Free Space for TempDB = '+convert(varchar(10),@freespace)+' MB'
	print  @miscprint
	print '  '
	Select @miscprint = 'Total TempDB file size = '+convert(varchar(10),@totalspaceusage) +' MB'
	print  @miscprint
	print '  '
	Select @miscprint ='TempDB resides on '+@tempdbPath
	print  @miscprint
	print '  '
	Select @miscprint ='Free Space on disk '+@volume+' = '+convert(varchar(10),@fixeddrivefreeMB)+'MB'
	print  @miscprint
	print '  '
    end


if @check_top_offender = 'y'
    begin
	    print '  '
	    Select @miscprint ='The Top 5 space offenders'
	    print  @miscprint
	    Print  '*******************************************************************/'
	    Print  ' '
	    Print  ' '
	    select
	    TOP (5)
		us.session_id 'SPID'
		,ex.Login_time
		,ex.login_name
                ,ex.host_name
		,sum (us.user_objects_alloc_page_count)*8 + sum (us.internal_objects_alloc_page_count )*8 'Used Space'
	    from sys.dm_db_session_space_usage as us
	    join sys.dm_exec_sessions as ex on us.session_id = ex.session_id
	    group by us.session_id
		    ,user_objects_alloc_page_count,internal_objects_alloc_page_count
		    ,ex.Login_time
		    ,ex.login_name
		    ,ex.host_name
	    order by (us.user_objects_alloc_page_count + us.internal_objects_alloc_page_count)

	  if    @kill = 'y'
	    begin

		set @spid =(select TOP (1) us.session_id 'SPID'from sys.dm_db_session_space_usage as us order by (us.user_objects_alloc_page_count + us.internal_objects_alloc_page_count))
		set @cmd = 'Kill '+convert(varchar(5),@spid)
		exec(@cmd)


	    end

    end
---------------------------  Finalization for process  -----------------------


Print  ' '
Print  '/*******************************************************************'
Select @miscprint = '         END OF REPORT - FOR SERVER: ' + @@servername
Print  @miscprint
Print  '*******************************************************************/'


If  (@check_top_offender= 'n' and @kill = 'n')
begin
	Print  ' '
	Select @miscprint = '--------------------------------------------------'
	Print  @miscprint
	Select @miscprint = '--Here are sample execute commands for this sproc:'
	Print  @miscprint
	Select @miscprint = '--------------------------------------------------'
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- Include the Top 5 offending SPIDS:'
	Print  @miscprint
	Select @miscprint = 'exec DBAOps.dbo.dbasp_REPORTTempDB @check_top_offender = ''y'''
	Print  @miscprint
	Print  ' '
	Select @miscprint = '--Include the Top 5 offending SPIDS and Kill them:'
	Print  @miscprint
	Select @miscprint = 'exec DBAOps.dbo.dbasp_REPORTTempDB @check_top_offender = ''y'', @kill=''y'''
	Print  @miscprint
	Print  ' '
   end


drop table #tempfiledir
GO
GRANT EXECUTE ON  [dbo].[dbasp_REPORTTempDB] TO [public]
GO
