SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ShrinkLDFFiles] (@DBname sysname = null)

/*********************************************************
 **  Stored Procedure dbasp_ShrinkLDFFiles
 **  Written by Steve Ledridge, Virtuoso
 **  July 22, 2003
 **
 **  This proc accepts one optional input parm; DBname.
 **  If an input parm is not given, all non-system LDF files
 **  will be processed.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/22/2003	Steve Ledridge		New process
--	01/23/2006	Steve Ledridge		Added skip for no-check databases
--	05/03/2006	Steve Ledridge		Modified for SQL 2005
--	07/17/2008	Steve Ledridge		Do not skip DB if specified with @Dbname input parm.
--	01/02/2009	Steve Ledridge		Converted to new no_check table.
--	02/25/2009	Steve Ledridge		New code for skipping DB's
--	03/12/2009	Steve Ledridge		Fixed bug with @dbname variable.
--	06/08/2009	Steve Ledridge		Added brackets [] for dbname.
--	07/28/2010	Steve Ledridge		Added tranlog backup prior to shrink.
--	09/14/2012	Steve Ledridge		Do not skip DB if specified with @Dbname input parm.
--	08/02/2013	Steve Ledridge		Added skip for non-DBAOpsable databases
--	08/21/2014	Steve Ledridge		New code to skip secondary AvailGrp DB's.
--	08/10/2015	Steve Ledridge		Added code for @DBname = 'all'.
--	======================================================================================


/***
Declare @DBname sysname


--Select @DBname = 'DBAOps'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(255)
	,@cursor_text			nvarchar(500)
	,@cmd				nvarchar(4000)
	,@DB_done_flag			char(1)
	,@DBname_input_flag		char(1)
	,@hold_backup_start_date	datetime
	,@hold_backup_set_id		int
	,@hold_file_type		char(1)
	,@saveDBName			sysname
	,@a				sysname


DECLARE
	 @cu11DBName			sysname


DECLARE
	 @cu22fileid			smallint
	,@cu22name			nvarchar(128)
	,@cu22filename			nvarchar(260)


----------------  initial values  -------------------


/****************************************************************
 *                MainLine
 ***************************************************************/


If @DBname is null or @DBname = '' or @DBname = 'all'
   begin
	Select @DBname_input_flag = 'n'
	Select @cursor_text = 'DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.sysdatabases   d ' +
  'Where d.name not in (''master'', ''msdb'', ''model'', ''tempdb'')
   Order By d.dbid For Read Only'
   end
Else
   begin
	Select @DBname_input_flag = 'y'
	Select @cursor_text = 'DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.sysdatabases   d ' +
  'Where d.name = ''' + @DBname + '''
   Order By d.dbid For Read Only'
   end


If @DBname = 'all'
   begin
	Select @DBname_input_flag = 'a'
   end


--------------------  Cursor for DB names  -------------------
EXECUTE(@cursor_text)


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		Select @cmd = 'SELECT @a = (select name from master.sys.databases where name = ''' + @cu11DBName  + ''' and replica_id is not null and group_database_id is not null)'
		--Print @cmd
		--Print ''


		EXEC sp_executesql @cmd, N'@a sysname output', @a output


		--  check to see if this DB is secondary in the availgrp
		If @a is not null and exists (SELECT 1
					FROM master.sys.availability_groups AS AG
					LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
					   ON AG.group_id = agstates.group_id
					INNER JOIN master.sys.availability_replicas AS AR
					   ON AG.group_id = AR.group_id
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					   ON arstates.replica_id = dbcs.replica_id
					LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
					   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
					where dbcs.database_name = @cu11DBName
					and   agstates.primary_replica <> @@servername)
		   begin
			Print 'DBA Note: Skipping DB ' + @cu11DBName + '.  This DB is a secondary replica in an Always On Availability Group.'
			raiserror('', -1,-1) with nowait


			goto skip_database
		   end
	   end


	If @cu11DBName in (select detail01 from dbo.no_check where NoCheck_type = 'backup')
	 and @DBname_input_flag = 'n'
	   begin
		Print 'Skip database ' + @cu11DBName
		Print ' '
		goto skip_database
	   end


	If @cu11DBName like 'z_%' or @cu11DBName like '%_new'
	 and @DBname_input_flag = 'y'
	   begin
		Print 'Skip database ' + @cu11DBName
		Print ' '
		goto skip_database
	   end


	If DATABASEPROPERTYEX (@cu11DBName,'status') <> 'ONLINE'
	   begin
		Print 'Skip database ' + @cu11DBName
		Print ' '
		goto skip_database
	   end


	If DATABASEPROPERTY(rtrim(@cu11DBName), 'IsReadOnly') = 1
	   begin
		Print 'Skip read only database ' + @cu11DBName
		Print ' '
		goto skip_database
	   end


	If @DBname_input_flag <> 'a'
	   and (not exists (select 1 from dbo.db_sequence where db_name = @cu11DBName)
	        or exists(select 1 from dbo.No_Check where NoCheck_type in ('DEPL_RD_Skip', 'DEPL_ahp_Skip') and (detail01 = @cu11DBName or detail01 = 'all')))
	   begin
		Print 'Skip non-DBAOpsable database ' + @cu11DBName
		Print ' '
		goto skip_database
	   end


	--  One last tranlog backup before the shrink
	If databaseproperty(@cu11DBName, 'IsTrunclog') = 0
	   begin
		Exec dbo.dbasp_Backup_Tranlog @DBName = @cu11DBName
	   end


	--------------------  Cursor for 22DB  -----------------------
	EXECUTE('DECLARE cu22_file Insensitive Cursor For ' +
	  'SELECT f.fileid, f.name, f.filename
	   From [' + @cu11DBName + '].sys.sysfiles  f ' +
	  'Where f.groupid = 0
	   Order By f.fileid For Read Only')


	OPEN cu22_file


	WHILE (22=22)
	   Begin
		FETCH Next From cu22_file Into @cu22fileid, @cu22name, @cu22filename
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu22_file
		      BREAK
	           end


		Select @cmd = 'sqlcmd -S' + @@servername + ' -d' + @cu11DBName + ' -Q"DBCC SHRINKFILE ([' + rtrim(@cu22name) + '])" -E'


		Print @cmd


		EXEC master.sys.xp_cmdshell @cmd


		Print ' '


	   End  -- loop 22
	   DEALLOCATE cu22_file


skip_database:


End  -- loop 11
DEALLOCATE cu11_DBNames


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_ShrinkLDFFiles] TO [public]
GO
