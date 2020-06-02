SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_DBUsers]


/*********************************************************
 **  Stored Procedure dbasp_Check_DBUsers
 **  Written by Steve Ledridge, Virtuoso
 **  February 6, 2001
 **
 **  This procedure checks for orphaned SQL Users
 **  and raises a DBA warning to the error log if any
 **  are found.  This process also checks for object ownership
 **  issues related to any DB users.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	10/04/2002	Steve Ledridge		Fixed main select from sysusers
--										(added sid is not null)
--	10/11/2002	Steve Ledridge		Added check for out-of-sync users
--	04/14/2003	Steve Ledridge		Added check for orphaned permissions and
--										orphaned sysobject owners.
--	06/27/2003	Steve Ledridge		Fix error on sysobject uid output
--	08/02/2004	Steve Ledridge		Fix bracket problem on dbname (with dash) in cursor
--	11/01/2004	Steve Ledridge		Added check for DBO status (should be 2)
--	11/19/2004	Steve Ledridge		Updated dbo check (sid must be in master..sysxlogins)
--	09/26/2005	Steve Ledridge		New code to check for suser_sname for orphaned DB owner
--	05/31/2006	Steve Ledridge		Updated for SQL 2005.
--	07/23/2007	Steve Ledridge		Added check for object ownership problems.
--	05/07/2008	Steve Ledridge		Added skip DB if status != online.
--										Also added drop unused schemas.
--	05/09/2008	Steve Ledridge		Added if not read only to unused schema delete code.
--	07/07/2009	Steve Ledridge		Revised code for suser_sname.
--	07/09/2009	Steve Ledridge		Added code for no_check table - baseline.
--	08/12/2009	Steve Ledridge		Added check for invalid default schema.
--	10/28/2009	Steve Ledridge		New code to fix invalid default schema.
--	08/25/2010	Steve Ledridge		Added NoChecks to allow overides.
--	08/19/2011	Steve Ledridge		Added insert\update to Security_Orphan_Log
--	10/24/2011	Steve Ledridge		New code to skip specific users
--	11/11/2011	Steve Ledridge		Updated query for orphaned users - added len(sid)
--	02/10/2012	Steve Ledridge		Added skip for dbo as orphaned user.
--	03/09/2012	Steve Ledridge		New cleanup for security_orphan_log.
--	05/02/2012	Steve Ledridge		Now only process ONLINE DB's.
--	11/02/2012	Steve Ledridge		Do not drop schemas that start with GI.
--	09/24/2014	Steve Ledridge		Do not drop schemas that start with ICM.
--	03/10/2016	Steve Ledridge		New code for avail grps.
--	======================================================================================


DECLARE
	 @miscprint				NVARCHAR(4000)
	,@count					INT
	,@cmd 					NVARCHAR(500)
	,@vars 					NVARCHAR(500)
	,@return_var 			int
	,@save_sid				VARBINARY(85)
	,@query					NVARCHAR(4000)
	,@save_schema_name		sysname


DECLARE
	 @cu11DBName			sysname


DECLARE
	 @cu22Oname				sysname
	,@cu22orph_sid			varbinary(85)
	,@cu23Oname				sysname
	,@cu23orph_sid			varbinary(85)
	,@cu24grantee			smallint
	,@cu26schema_id			smallint
	,@cu27schema_name		sysname
	,@cu28principal_name	sysname
	,@cu31user_name			sysname


--  Create temp tables


create table #orphans(orph_sid varbinary(85), orph_name sysname null)
create table #orphan_perms (orph_grantee smallint)
create table #orphan_obj (orph_schema_id smallint)
create table #orphan_sch (orph_schema_name sysname)
create table #orphan_prn (orph_name sysname null)
Create table #enyc_info (enyc_name sysname)


-------------------- NoCheck All -------------------
if exists(SELECT * From dbo.No_Check WHERE NoCheck_type = object_name(@@Procid) AND detail01 = 'all')
begin
	Print 'NoCheck All, Exiting Sproc.'
	return 0
end


--------------------  Cursor for DB names  -------------------
SET	@miscprint = ''
SELECT	@miscprint = @miscprint + COALESCE(detail01 + ', ','')
FROM	dbo.No_Check
WHERE	NoCheck_type = object_name(@@Procid)


If	@miscprint > ''
PRINT	'Databases ' + @miscprint + ' skiped because of NoCheck Entry'


EXECUTE('DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.databases   d ' +
  'Where d.name not in (''model'', ''tempdb'')
  and d.state_desc = ''ONLINE''
  and d.name not in (SELECT detail01 FROM dbo.No_Check WHERE NoCheck_type = object_name(@@Procid))
   Order By d.name For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


    If (DATABASEPROPERTYEX(@cu11DBName, N'Status') != N'ONLINE')
       begin
          goto skip_db
       end


    If @cu11DBName in (select detail01 from dbo.no_check where nocheck_type = 'baseline')
       begin
          goto skip_db
       end


	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		If @cu11DBName in (Select dbcs.database_name
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
				   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id)
		   begin
			If (Select arstates.role_desc
				FROM master.sys.availability_replicas AS AR
				INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
				   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
				INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
				   ON arstates.replica_id = dbcs.replica_id
				where AR.replica_server_name = @@servername
				and dbcs.database_name = @cu11DBName) = 'SECONDARY'
			   begin
				goto skip_db
			   end
		   end
	   end


    --------------------  Capture and Process Orphan user Info  -------------------
    delete from #orphans
    insert into #orphans 	Execute('SELECT sid, name
  				     From [' + @cu11DBName + '].sys.database_principals ' +
				    'Where sid not in (select sid from master.sys.syslogins where sid is not null)
				     and sid is not null
				     and (len(sid) <= 16)
				     and type in (''S'', ''U'')
				     and name not in (''dbo'', ''guest'', ''MS_DataCollectorInternalUser'')
				    ')


    --  clean up dbo.Security_Orphan_Log table
    If exists (select 1 from dbo.Security_Orphan_Log where SOL_name not in (select orph_name from #orphans)
							and SOL_type = 'user'
							and SOL_DBname = @cu11DBName
							and Delete_flag = 'n')
       begin
          Update dbo.Security_Orphan_Log set Delete_flag = 'x'
                 where SOL_name not in (select orph_name from #orphans)
                 and SOL_type = 'user'
		 and SOL_DBname = @cu11DBName
		 and Delete_flag = 'n'
       end


    select @count = (select count(*) from #orphans)


    If @count > 0
       begin
	    EXECUTE('DECLARE cu22_orphs Insensitive Cursor For ' +
	      'SELECT o.orph_name, o.orph_sid
	      From #orphans  o ' +
	      'For Read Only')


	    OPEN cu22_orphs


	    WHILE (22=22)
	       Begin
		    FETCH Next From cu22_orphs Into @cu22Oname, @cu22orph_sid
		    IF (@@fetch_status < 0)
		       begin
			  CLOSE cu22_orphs
			  BREAK
		       end


		--  skip specific users
		If @cu22Oname in ('MS_DataCollectorInternalUser', 'dbo')
		   begin
			goto loop_22_end
		   end
		Else If exists (select 1 from dbo.no_check where NoCheck_type = 'DBuser' and detail01 = @cu11DBName and detail02 = @cu22Oname)
		   begin
			goto loop_22_end
		   end


		If exists (Select 1 from master.sys.syslogins where name = @cu22Oname)
		   begin
			Select @miscprint = 'DBA WARNING: Out-of-Sync SQL USER ''' + @cu22Oname + ''' found in database '''
						    + @cu11DBName + ''' on server ' + @@servername
			raiserror(@miscprint,-1,-1) with log
		   end
		Else If suser_sname(@cu22orph_sid) is null
		   begin
			Select @miscprint = 'DBA WARNING: Orphaned SQL USER ''' + @cu22Oname + ''' found in database '''
						    + @cu11DBName + ''' on server ' + @@servername
			raiserror(@miscprint,-1,-1) with log
		   end


		If not exists (select 1 from dbo.Security_Orphan_Log where SOL_name = @cu22Oname and SOL_DBname = @cu11DBName and Delete_flag = 'n')
		   begin
		 	Insert into dbo.Security_Orphan_Log values (@cu22Oname, 'user', @cu11DBName, getdate(), getdate(), 'n')
		   end
		Else
		   begin
			Update dbo.Security_Orphan_Log set Last_Date = getdate() where SOL_name = @cu22Oname and SOL_DBname = @cu11DBName and Delete_flag = 'n'
		   end


		loop_22_end:


	       End  -- loop 22
	       DEALLOCATE cu22_orphs
       end


    --------------------  Capture and Process orphaned Principal Info  -------------------
    delete from #orphan_prn


    insert into #orphan_prn		Execute('SELECT name
  				     From [' + @cu11DBName + '].sys.database_principals ' +
				    'Where sid not in (select sid from master.sys.syslogins where sid is not null)
				     and sid is not null
				     and (len(sid) <= 16)
				     and type in (''S'', ''U'')
				     and name not in (''dbo'', ''guest'', ''MS_DataCollectorInternalUser'')
				    ')


    select @count = (select count(*) from #orphan_prn)


    EXECUTE('DECLARE cu28_prn Insensitive Cursor For ' +
      'SELECT o.orph_name
       From #orphan_prn  o ' +
      'For Read Only')


    OPEN cu28_prn


    WHILE (28=28)
       Begin
	    FETCH Next From cu28_prn Into @cu28principal_name
	    IF (@@fetch_status < 0)
	       begin
		  CLOSE cu28_prn
		  BREAK
	       end


	    If SUSER_SID(@cu28principal_name) is null
	       begin
		    Select @miscprint = 'DBA WARNING: Orphaned principal found in database ''' + @cu11DBName + ''' on server '
						    + @@servername + '.  Principal name = ' + @cu28principal_name + '.  The related login does not exist.'
		    raiserror(@miscprint,-1,-1) with log
	       end


       End  -- loop 28
       DEALLOCATE cu28_prn


    --------------------  Capture and Process Orphan Permissions Info  -------------------
    delete from #orphan_perms


    insert into #orphan_perms	Execute('SELECT distinct grantee
  				     From [' + @cu11DBName + '].sys.syspermissions ' +
				    'Where grantee not in (select uid from [' + @cu11DBName + '].sys.sysusers)
				    ')


    select @count = (select count(*) from #orphan_perms)


    EXECUTE('DECLARE cu24_perms Insensitive Cursor For ' +
      'SELECT o.orph_grantee
       From #orphan_perms  o ' +
      'For Read Only')


    OPEN cu24_perms


    WHILE (24=24)
       Begin
	    FETCH Next From cu24_perms Into @cu24grantee
	    IF (@@fetch_status < 0)
	       begin
		  CLOSE cu24_perms
		  BREAK
	       end


	    Select @miscprint = 'DBA WARNING: Orphaned permissions found in database ''' + @cu11DBName + ''' on server '
						    + @@servername + '.  SQL user is UID=' + convert(varchar(10), @cu24grantee) + '.  No such user exists.'
	    raiserror(@miscprint,-1,-1) with log


       End  -- loop 24
       DEALLOCATE cu24_perms


    --------------------  Capture and Process Orphan Object Schema Info  -------------------
    delete from #orphan_obj


    insert into #orphan_obj		Execute('SELECT distinct schema_id
  				     From [' + @cu11DBName + '].sys.objects ' +
				    'Where schema_id not in (select schema_id from [' + @cu11DBName + '].sys.schemas)
				    ')


    select @count = (select count(*) from #orphan_obj)


    EXECUTE('DECLARE cu26_obj Insensitive Cursor For ' +
      'SELECT o.orph_schema_id
       From #orphan_obj  o ' +
      'For Read Only')


    OPEN cu26_obj


    WHILE (26=26)
       Begin
	    FETCH Next From cu26_obj Into @cu26schema_id
	    IF (@@fetch_status < 0)
	       begin
		  CLOSE cu26_obj
		  BREAK
	       end


	    Select @miscprint = 'DBA WARNING: Orphaned sys.object schema found in database ''' + @cu11DBName + ''' on server '
						    + @@servername + '.  Schema_id=' + convert(varchar(10), @cu26schema_id) + '.  No such schema exists.'
	    raiserror(@miscprint,-1,-1) with log


       End  -- loop 26
       DEALLOCATE cu26_obj


    --------------------  Remove un-used Schemas  -------------------
    If (DATABASEPROPERTYEX(@cu11DBName, N'Updateability') != N'READ_ONLY')
       begin
	    delete from #orphan_sch

	    insert into #orphan_sch		Execute('SELECT distinct name
	  				     From [' + @cu11DBName + '].sys.schemas s ' +
					    'Where s.schema_id > 4 and s.schema_id < 16380 and not exists (select name from [' + @cu11DBName + '].sys.objects o where o.schema_id = s.schema_id)
					    ')


	    Delete from #orphan_sch where orph_schema_name like 'GI%'
	    Delete from #orphan_sch where orph_schema_name like 'ICM%'


	    select @count = (select count(*) from #orphan_sch)


	    If @count > 0
	       begin
		drop_schema01:
		Select @save_schema_name = (select top 1 orph_schema_name from #orphan_sch)
		Select @cmd = 'use [' + @cu11DBName + '] DROP SCHEMA [' + @save_schema_name + '];'
		Print @cmd
		Exec (@cmd)
	       end


	    Delete from #orphan_sch where orph_schema_name = @save_schema_name
	    If (select count(*) from #orphan_sch) > 0
	       begin
		    goto drop_schema01
	       end
       end


    --------------------  Capture and Process Orphan Schema Info  -------------------
    delete from #orphan_sch


    insert into #orphan_sch		Execute('SELECT distinct name
  				     From [' + @cu11DBName + '].sys.schemas ' +
				    'Where principal_id not in (select principal_id from [' + @cu11DBName + '].sys.database_principals)
				    ')


    select @count = (select count(*) from #orphan_sch)


    EXECUTE('DECLARE cu27_sch Insensitive Cursor For ' +
      'SELECT o.orph_schema_name
       From #orphan_sch  o ' +
      'For Read Only')


    OPEN cu27_sch


    WHILE (27=27)
       Begin
	    FETCH Next From cu27_sch Into @cu27schema_name
	    IF (@@fetch_status < 0)
	       begin
		  CLOSE cu27_sch
		  BREAK
	       end


	    Select @miscprint = 'DBA WARNING: Orphaned schema found in database ''' + @cu11DBName + ''' on server '
						    + @@servername + '.  Schema name = ' + @cu27schema_name + '.  The related principal_id does not exist.'
	    raiserror(@miscprint,-1,-1) with log


       End  -- loop 27
       DEALLOCATE cu27_sch


    --------------------  Capture and Process (fix) Orphan default-Schema Info  -------------------
    delete from #orphan_sch


    insert into #orphan_sch		Execute('SELECT distinct name
  				     From [' + @cu11DBName + '].sys.database_principals ' +
				    'Where type NOT IN (''R'',''S'',''C'') AND default_schema_name not in (select name from [' + @cu11DBName + '].sys.schemas)
				    ')


					--SELECT * FROM sys.database_principals


    select @count = (select count(*) from #orphan_sch)


    EXECUTE('DECLARE cu31_sch Insensitive Cursor For ' +
      'SELECT o.orph_schema_name
       From #orphan_sch  o ' +
      'For Read Only')


    OPEN cu31_sch


    WHILE (31=31)
       Begin
	    FETCH Next From cu31_sch Into @cu31user_name
	    IF (@@fetch_status < 0)
	       begin
		  CLOSE cu31_sch
		  BREAK
	       end


	    Select @miscprint = 'DBA WARNING: DB User with invalid default schema found in database ''' + @cu11DBName + ''' on server '
						    + @@servername + '.  User name = ' + @cu31user_name + '.  The default schema does not exist and is being changed to dbo.'


	    raiserror(@miscprint,-1,-1) with log


		select @cmd = 'use [' + @cu11DBName + '] ALTER USER [' + @cu31user_name + '] WITH DEFAULT_SCHEMA=dbo'


		EXEC sp_executesql @cmd


       End  -- loop 31
       DEALLOCATE cu31_sch


    --------------------  Check DBO Status  -------------------


	    --  Check for null sid
	    set @return_var = 0
	    SET @cmd = N'IF exists (SELECT 1 FROM [' + @cu11DBName + '].sys.sysusers WHERE name = ''dbo'' and sid is null) SET @return_var = @return_var + 1'
	    SET @vars = N'@return_var integer OUTPUT'


	    exec sp_executeSQL @cmd, @vars, @return_var OUTPUT


	    If @return_var <> 0
	       begin
		    Select @miscprint = 'DBA WARNING: Invalid Status (null sid) for DBO found in database '''
							    + @cu11DBName + ''' on server ' + @@servername + '. '
		    raiserror(@miscprint,-1,-1) with log
		    --Print @miscprint
		    goto label91
	       end


	    --  Check for dbo sid that does not exist in master
	    set @return_var = 0
	    SET @cmd = N'IF not exists (SELECT 1 FROM [' + @cu11DBName + '].sys.sysusers u, master.sys.syslogins x '
				    + 'WHERE u.name = ''dbo'' and u.sid = x.sid) SET @return_var = @return_var + 1'
	    SET @vars = N'@return_var integer OUTPUT'


	    exec master.sys.sp_executeSQL @cmd, @vars, @return_var OUTPUT


	    --  The database owner is not in master.sys.syslogins.  Now make sure it is a valid NT account.
	    If @return_var <> 0
	       begin

		    If (Select suser_sname(owner_sid) from master.sys.databases where name = @cu11DBName) is null
		       begin
			    Select @miscprint = 'DBA WARNING: Invalid SID for DBO found in database ''' + @cu11DBName + ''' on server ' + @@servername + '. '
			    raiserror(@miscprint,-1,-1) with log
			    --Print @miscprint
			    goto label91
		       end
	       end


	    label91:


    --------------------  Check Object Ownership  -------------------


    --  Check encryption related ownership
    Select @query = 'select sk.name
			    from [' + @cu11DBName + '].sys.database_principals dp
			    inner join [' + @cu11DBName + '].sys.symmetric_keys sk
			    on dp.principal_id = sk.principal_id
			    where dp.name <> ''dbo'''
    --print @query
    Delete from #enyc_info
    Insert into #enyc_info exec (@query)


    If (select count(*) from #enyc_info) > 0
       begin
	    Select @miscprint = 'DBA WARNING: A symmetric_key in database [' + @cu11DBName + '] is not owned by ''dbo''.  Check table sys.symmetric_keys.'
	    raiserror(@miscprint,-1,-1) with log
	    --Print @miscprint
       end


    Select @query = 'select sk.name
			    from [' + @cu11DBName + '].sys.database_principals dp
			    inner join [' + @cu11DBName + '].sys.asymmetric_keys sk
			    on dp.principal_id = sk.principal_id
			    where dp.name <> ''dbo'''
    --print @query
    Delete from #enyc_info
    Insert into #enyc_info exec (@query)


    If (select count(*) from #enyc_info) > 0
       begin
	    Select @miscprint = 'DBA WARNING: An asymmetric_key in database [' + @cu11DBName + '] is not owned by ''dbo''.  Check table sys.asymmetric_keys.'
	    raiserror(@miscprint,-1,-1) with log
	    --Print @miscprint
       end


    Select @query = 'select sk.name
			    from [' + @cu11DBName + '].sys.database_principals dp
			    inner join [' + @cu11DBName + '].sys.certificates sk
			    on dp.principal_id = sk.principal_id
			    where dp.name <> ''dbo'''
    --print @query
    Delete from #enyc_info
    Insert into #enyc_info exec (@query)


    If (select count(*) from #enyc_info) > 0
       begin
	    Select @miscprint = 'DBA WARNING: A certificate in database [' + @cu11DBName + '] is not owned by ''dbo''.  Check table sys.certificates.'
	    raiserror(@miscprint,-1,-1) with log
	    --Print @miscprint
       end


    skip_db:


 End  -- loop 11


---------------------------  Finalization  -----------------------
DEALLOCATE cu11_DBNames


drop table #orphans
drop table #orphan_perms
drop table #orphan_obj
drop table #orphan_sch
drop table #orphan_prn
drop table #enyc_info


return (0)
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_DBUsers] TO [public]
GO
