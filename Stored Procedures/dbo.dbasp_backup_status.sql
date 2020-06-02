SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_backup_status]


/*********************************************************
 **  Stored Procedure dbasp_backup_status
 **  Written by Steve Ledridge, Virtuoso
 **  September 12, 2012
 **
 **  This dbasp will list the status for all active backups.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	09/12/2012	Steve Ledridge		New process from code Joe found.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(255)
	,@save_DBname			sysname
	,@save_percent_complete		real
	,@save_COMMAND			char(50)
	,@save_COMPLETION_TIME		char(14)
	,@save_ELAPSED_TIME		char(12)


----------------  initial values  -------------------


create table #temp_backups (DBname		sysname
			,ELAPSED_TIME		int null
			,COMPLETION_TIME	int null
			,PERCENT_COMPLETE	real null
			,COMMAND		varchar(4000) null
			)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   Report Active Backups '
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


delete from #temp_backups
insert into #temp_backups
SELECT A.NAME
	,B.TOTAL_ELAPSED_TIME/60000
	,B.ESTIMATED_COMPLETION_TIME/60000
	,B.PERCENT_COMPLETE
	,(SELECT TEXT FROM sys.dm_exec_sql_text(B.SQL_HANDLE))
FROM MASTER.SYS.SYSDATABASES A, sys.dm_exec_requests B
WHERE A.DBID=B.DATABASE_ID AND B.COMMAND LIKE '%BACKUP%'
--select * from #temp_backups


If (select count(*) from #temp_backups) = 0
   begin
	Print 'No backups in process at this time'
	goto label99
   end


Select @miscprint = 'DBname                     Elapsed Time  Remaining Time  Percent Complete  Command'
Print  @miscprint
Select @miscprint = '-------------------------  ------------  --------------  ----------------  --------------------------------------------------'
Print  @miscprint


Start_01:
Select @save_DBname = (select top 1 DBname from #temp_backups order by PERCENT_COMPLETE, ELAPSED_TIME)
Select @save_PERCENT_COMPLETE = (select top 1 convert(char(16), PERCENT_COMPLETE, 0) from #temp_backups where DBname = @save_DBname order by PERCENT_COMPLETE, ELAPSED_TIME)
Select @save_ELAPSED_TIME = (select top 1 convert(char(12), ELAPSED_TIME) from #temp_backups where DBname = @save_DBname)
Select @save_COMPLETION_TIME = (select top 1 convert(char(14), COMPLETION_TIME) from #temp_backups where DBname = @save_DBname)
Select @save_COMMAND = (select top 1 convert(char(50), COMMAND) from #temp_backups where DBname = @save_DBname)


Print convert(char(25), @save_DBname) + '  ' + @save_ELAPSED_TIME + '  ' + @save_COMPLETION_TIME + '  ' + convert(char(16), @save_PERCENT_COMPLETE, 0) + '  ' + @save_COMMAND


Delete from #temp_backups where DBname = @save_DBname
If (select count(*) from #temp_backups) > 0
   begin
	goto Start_01
   end


--  Finalization  ------------------------------------------------------------------------------
label99:


drop table #temp_backups
GO
GRANT EXECUTE ON  [dbo].[dbasp_backup_status] TO [public]
GO
