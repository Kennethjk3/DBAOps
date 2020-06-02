SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Logins]


/*********************************************************
 **  Stored Procedure dbasp_Check_Logins
 **  Written by Steve Ledridge, Virtuoso
 **  November 30, 2000
 **
 **  This procedure checks for orphaned SQL logins
 **  and raises a DBA warning to the error log if any
 **  are found.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	01/07/2005	Steve Ledridge		Added wait for delay between raiserror's
--	05/30/2006	Steve Ledridge		Updated for SQL 2005.
--	11/29/2006	Steve Ledridge		Added check for valid default DB.
--	02/11/2008	Steve Ledridge		Added skip for DB's not online.
--	04/30/2008	Steve Ledridge		Chg defaul DB to master if current default DB does not exist.
--	10/28/2008	Steve Ledridge		Allow for no access to defaul DB if it is master.
--	08/25/2010	Steve Ledridge		Added NoChecks to allow overides.
--	08/12/2011	Steve Ledridge		Add insert to Security_Orphan_Log tbl.
--	11/09/2011	Steve Ledridge		Added more nocheck processing.
--	04/25/2012	Steve Ledridge		Added brackets for the alter login.
--	08/07/2015	Steve Ledridge		Skip db users with authentication_type = 0
--	08/27/2015	Steve Ledridge		Remove code related to authentication_type
--	03/10/2016	Steve Ledridge		New code to check for avail grps.
--	======================================================================================


DECLARE
	 @miscprint		    nvarchar(4000)
	,@cmd			    nvarchar(500)
	,@save_dbname		    sysname


DECLARE
	 @cu11sid		    varbinary(85)
	,@cu11name		    sysname


DECLARE
	 @cu21sid		    varbinary(85)
	,@cu21Login_name	    sysname
	,@cu21default_database_name sysname


-------------------- NoCheck All -------------------
if exists(SELECT * From DBAOps.dbo.No_Check WHERE NoCheck_type = object_name(@@Procid) AND detail01 = 'all')
begin
	Print 'NoCheck All, Exiting Sproc.'
	return 0
end


--------------------  Capture Orphan Login Info  -------------------


create table #orphans(orph_sid varbinary(85), orph_name sysname null)


insert into #orphans exec master.sys.sp_validatelogins


--------------------  Define cursor  -------------------


EXECUTE('DECLARE cu11_cursor Insensitive Cursor For ' +
  'SELECT o.orph_sid, o.orph_name
   From #orphans   o ' +
  'For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


OPEN cu11_cursor


WHILE (11=11)
 Begin
	FETCH Next From cu11_cursor Into @cu11sid, @cu11name
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_cursor
	      BREAK
           end


	If @cu11name like '%SQLServer2005%'
	   begin
	    goto skip11
	   end
	Else If exists (select 1 from dbo.no_check where NoCheck_type = 'login' and detail01 = @cu11name)
	   begin
		goto skip11
	   end


	Select @miscprint = 'DBA WARNING: Orphaned SQL Login found on server ' + @@servername + ' - ''' + @cu11name + ''''
	--Print @miscprint
	raiserror(@miscprint,-1,-1) with log
	Waitfor delay '00:00:01'

	If not exists (select 1 from dbo.Security_Orphan_Log where SOL_name = @cu11name and Delete_flag = 'n')
	   begin
		Insert into dbo.Security_Orphan_Log values (@cu11name, 'login', '', getdate(), getdate(), 'n')
	   end
	Else
	   begin
		Update dbo.Security_Orphan_Log set Last_Date = getdate() where SOL_name = @cu11name and Delete_flag = 'n'
	   end

    skip11:


 End  -- loop 11


DEALLOCATE cu11_cursor


-- Now check to see if all Logins have access to their default DB


--------------------  Define cursor  -------------------
EXECUTE('DECLARE cu21_cursor Insensitive Cursor For ' +
  'SELECT sp.sid, sp.name, sp.default_database_name
   From master.sys.server_principals  sp ' +
  'Where sp.type <> ''R''
   and sp.name is not null
   For Read Only')


OPEN cu21_cursor


WHILE (21=21)
 Begin
	FETCH Next From cu21_cursor Into @cu21sid, @cu21Login_name, @cu21default_database_name


	IF (@@fetch_status < 0)
           begin
              CLOSE cu21_cursor
	      BREAK
           end


	If @cu21default_database_name <> 'master'
	   begin
		--Print @cu21Login_name
		--select @cu21dbid
		If (SELECT DB_ID(@cu21default_database_name)) is null
		   begin
			Select @cmd = 'ALTER LOGIN [' + @cu21Login_name + '] WITH DEFAULT_DATABASE = master;'
			Print @cmd
			Exec(@cmd)

			Select @miscprint = 'DBA WARNING: Default DB changed to MASTER for login ''' + @cu21Login_name + ''' on server ' + @@servername
			print @miscprint
			--raiserror(@miscprint,-1,-1) with log
			goto skip21
		   end


		If (SELECT DATABASEPROPERTYEX (@cu21default_database_name,'status')) <> 'ONLINE'
		   begin
			goto skip21
		   end


		IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
		   begin
			If @cu21default_database_name in (Select dbcs.database_name
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
					and dbcs.database_name = @cu21default_database_name) = 'SECONDARY'
				   begin
					goto skip21
				   end
			   end
		   end


		Select @cmd = 'use ' + quotename( @cu21default_database_name , '[') + ' select dp.principal_id from sys.database_principals  dp, master.sys.server_principals  sp
											where dp.sid = sp.sid
											and sp.name = ''' + @cu21Login_name + ''''
		Print @cmd
		Exec(@cmd)


		If @@rowcount = 0 and @cu21default_database_name <> 'master'
		   begin


			Select @miscprint = 'DBA WARNING: Login ''' + @cu21Login_name + ''' does not have access to default DB ''' + @cu21default_database_name + ''' on server ' + @@servername
			--print @miscprint
			raiserror(@miscprint,-1,-1) with log
			Waitfor delay '00:00:02'
		   end


		skip21:
		Print ''
	   end


 End  -- loop 21
DEALLOCATE cu21_cursor


---------------------------  Finalization  -----------------------
label99:


if (object_id('tempdb..#orphans') is not null)
            drop table #orphans


return (0)
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Logins] TO [public]
GO
