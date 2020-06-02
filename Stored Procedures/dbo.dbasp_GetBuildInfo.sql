SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetBuildInfo]

/***************************************************************
 **  Stored Procedure dbasp_GetBuildInfo
 **  Written by Steve Ledridge, Virtuoso
 **  11/18/2008
 **
 **  This procedure is used to gather the build information from
 **  databases on the server.
 **
 ***************************************************************/
as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/18/2008	Steve Ledridge		New Process
--	11/24/2008	Steve Ledridge		Added check for Build Table and Database
--						availability status.
--						Added datetime and guid hash
--						to output filename to ensure uniqueness.
--	12/11/2008	Steve Ledridge		Changed how @dbStatus was populated.
--	07/07/2009	Steve Ledridge		Added rmtshare cmd if showacls result is blank.
--	10/09/2009	Steve Ledridge		Changed code from systeminfo to DEPLinfo.
--	02/22/2010	Steve Ledridge		Modified Check for Build table to only look in
--						databases that are in the db_sequence table.
--	09/13/2011	Steve Ledridge		Updated central servername and central share name.
--	04/29/2013	Steve Ledridge		Changed code from DEPLinfo to DBAOps.
--	09/16/2013	Steve Ledridge		New code for ENVname = local.
--	04/16/2014	Steve Ledridge		Changed seapsqldba01 to seapdbasql01.
--	06/23/2014	Steve Ledridge		Changed sys.sysobjects to sys.objects.
--	09/08/2014	Steve Ledridge		New code to skip secondary AvailGrp DB's.
--	======================================================================================


/*********************************************************************
 *                Variable Declaration
 ********************************************************************/
declare
          @cmd					nvarchar(4000)
         ,@cmd2					nvarchar(4000)
	 ,@cmd3					nvarchar(4000)
         ,@miscprint				nvarchar(4000)
         ,@miscprint2				sysname
         ,@hold_source_path			sysname
         ,@central_server 			sysname
	 ,@BkUpDateStmp 			char(14)
	 ,@Hold_hhmmss				varchar(8)
         ,@dbName				sysname
         ,@dbName2				sysname
	 ,@dbStatus				sysname
         ,@parm1def				nvarchar(500)
         ,@parm2def				nvarchar(500)
	 ,@parm3def				nvarchar(500)
         ,@baselinedt				varchar(20)
         ,@dmn					sysname
         ,@buildNumber				varchar(50)
         ,@buildDate				varchar(20)
	 ,@bExist				int
         ,@Enviro_Type				varchar(50)
         ,@outfile_name				sysname
         ,@outfile_name2			sysname
	 ,@outfile_path				nvarchar(250)
         ,@fileexist_path			sysname
         ,@save_servername			sysname
	 ,@save_servername2			sysname
         ,@save_domain_name			sysname
         ,@save_Administrators			sysname
         ,@charpos				int
	 ,@charpos2				int
	 ,@a					sysname


/*********************************************************************
 *                Initialization
 ********************************************************************/
Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


create table #regresults (results nvarchar(1500) null)
create table #onlineStatus (dName sysname)

Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
iF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain_name = (select env_detail from DBAOps.dbo.local_serverenviro where env_type = 'domain')
If @save_domain_name is not null
   begin
	Select @dmn = @save_domain_name
   end
Else
   begin
	Select @dmn = 'UnKnown'
   end


--Check for Domain and Environment information
select @Enviro_Type = null


if exists(select 1 from master.sys.databases where name = 'DBAOps')
   begin
	select @Enviro_Type = env_name from DBAOps.dbo.enviro_info where env_type = 'ENVnum'
    end


If @Enviro_Type is null
   begin
	select @Enviro_Type = env_detail from DBAOps.dbo.local_serverenviro where env_type = 'ENVname'
    end


Set @Hold_hhmmss = convert(varchar(8), getdate(), 8)
Set @BkUpDateStmp = convert(char(8), getdate(), 112) + substring(@Hold_hhmmss, 1, 2) + substring(@Hold_hhmmss, 4, 2)+ substring(@Hold_hhmmss, 7, 2)


--Create the output file
Select @outfile_name = 'BuildInformationTableUpdate_'+@BkUpDateStmp+'_'+@save_servername2 + '.gsql'
Select @outfile_name2 = 'BuildInformationTableUpdate_*.gsql'
Select @outfile_path = '\\' + @save_servername + '\DBASQL\dba_reports\' + @outfile_name


--first delete pre-existing output file
Select @cmd2 = 'del \\' + @save_servername + '\DBASQL\dba_reports\' + @outfile_name2+' /Q '
EXEC master.sys.xp_cmdshell @cmd2, no_output


--Create fresh copy of the output file
Select @cmd = 'copy nul ' + @outfile_path
EXEC master.sys.xp_cmdshell @cmd, no_output


Select @miscprint = '--  Build Information Table Update Script from server: ''' + @@servername + ''''
Print  @miscprint
Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
EXEC master.sys.xp_cmdshell @cmd, no_output


Select @miscprint = '--  Created: '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
exec master.sys.xp_cmdshell @cmd, no_output


Select @miscprint = ' '
Print  @miscprint
Select @cmd = 'echo.>>' + @outfile_path
exec master.sys.xp_cmdshell @cmd, no_output


----------------------------------------------------------------------------------------------
-- General Environment verification
----------------------------------------------------------------------------------------------
--  Check to see if the 'builds' folder exists


Delete from #fileexists
Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername + '_builds'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
--select * from #fileexists


If (select fileindir from #fileexists) = 1
   begin
	Select @cmd = 'showacls ' + @fileexist_path


	delete from #regresults
	insert into #regresults exec master.sys.xp_cmdshell @cmd
	delete from #regresults where results is null
	--select * from #regresults


	If (select count(*) from #regresults) = 0
	   begin
		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


		delete from #regresults
		insert into #regresults exec master.sys.xp_cmdshell @cmd
		delete from #regresults where results is null
		--select * from #regresults
	   end


	If exists (select 1 from #regresults where results like '%Administrators%')
	   begin
		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
		If @save_Administrators not like '%Full Control%'
		   begin
			Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
			Print @miscprint
			raiserror(@miscprint,-1,-1) with log
		   end
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
		Print @miscprint
		raiserror(@miscprint,-1,-1) with log
	   end
   end
Else
   begin
	Select @miscprint = 'DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	Print @miscprint
	raiserror(@miscprint,-1,-1) with log
   end


--  Check to see if the 'mdf' share exists


Delete from #fileexists
Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_mdf'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
--select * from #fileexists


If (select fileindir from #fileexists) = 1
   begin
	Select @cmd = 'showacls ' + @fileexist_path


	delete from #regresults
	insert into #regresults exec master.sys.xp_cmdshell @cmd
	delete from #regresults where results is null
	--select * from #regresults


	If (select count(*) from #regresults) = 0
	   begin
		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


		delete from #regresults
		insert into #regresults exec master.sys.xp_cmdshell @cmd
		delete from #regresults where results is null
		--select * from #regresults
	   end


	If exists (select 1 from #regresults where results like '%Administrators%')
	   begin
		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
		If @save_Administrators not like '%Full Control%'
		   begin
			Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
			Print @miscprint
			raiserror(@miscprint,-1,-1) with log
			goto label99
		   end
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
		Print @miscprint
		raiserror(@miscprint,-1,-1) with log
		goto label99
	   end
   end
Else
   begin
	Select @miscprint = 'DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	Print @miscprint
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


--  Check to see if the 'nxt' share exists


Delete from #fileexists
Select @fileexist_path = '\\' + @save_servername + '\' + @save_servername2 + '_nxt'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
--select * from #fileexists


If (select fileindir from #fileexists) = 1
   begin
	Select @cmd = 'showacls ' + @fileexist_path


	delete from #regresults
	insert into #regresults exec master.sys.xp_cmdshell @cmd
	delete from #regresults where results is null
	--select * from #regresults


	If (select count(*) from #regresults) = 0
	   begin
		Select @cmd = 'rmtshare ' + @fileexist_path + ' /users'


		delete from #regresults
		insert into #regresults exec master.sys.xp_cmdshell @cmd
		delete from #regresults where results is null
		--select * from #regresults
	   end


	If exists (select 1 from #regresults where results like '%Administrators%')
	   begin
		Select @save_Administrators = (select top 1 results from #regresults where results like '%Administrators%')
		If @save_Administrators not like '%Full Control%'
		   begin
			Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators full control.  ' + @fileexist_path
			Print @miscprint
			raiserror(@miscprint,-1,-1) with log
			goto label99
		   end
	   end
	Else
	   begin
		Select @miscprint = 'DBA WARNING: Standard share is missing local adminitrators.  ' + @fileexist_path
		Print @miscprint
		raiserror(@miscprint,-1,-1) with log
		goto label99
	   end
   end
Else
   begin
	Select @miscprint = 'DBA WARNING: Standard share could not be found.  ' + @fileexist_path
	Print @miscprint
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/
----------------------------------------------------------------------------------------------
--  Check whether the database is online or not. If not, record status
----------------------------------------------------------------------------------------------
declare offlineCur cursor for
select distinct
     s.name
    ,s.state_desc
from master.sys.databases as s
join DBAOps.dbo.db_sequence c on s.name = c.db_name


open offlineCur


fetch next from offlineCur into @dbName,@dbStatus


while @@fetch_status = 0
begin
	--  Skip AvailGrp DB's
	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		Select @cmd = 'SELECT @a = (select name from master.sys.databases where name = ''' + @dbName  + ''' and replica_id is not null and group_database_id is not null)'
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
					where dbcs.database_name = @dbName
					and   agstates.primary_replica <> @@servername)
		   begin
			Print 'DBA Note: Skipping DB ' + @dbName + '.  This DB is a secondary replica in an Always On Availability Group.'
			raiserror('', -1,-1) with nowait
			break
			fetch next from offlineCur into @dbName
		   end
	   end


	if @dbStatus <> 'ONLINE'
	    begin

		Select @miscprint = 'delete from DBAOps.dbo.DBA_DeplInfo where SQLName = '''+@@servername+''' and dbName = '''+@dbName+ ''''
		Print  @miscprint
		Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output


		Select @miscprint = 'GO '
		Print  @miscprint
		Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output


		Select @miscprint = 'insert into DBAOps.dbo.DBA_DeplInfo (Domain, Enviro_Type, ServerName, SQLName, DBName, Build_Number, Build_Date,  Baseline_Date,  Record_Date)'
		Print  @miscprint
		Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output


		Select @miscprint = 'VALUES ('''+@save_domain_name+''', '''+@Enviro_Type+''',''' + @save_servername + ''',''' + UPPER(@@servername) + ''', ''' + @dbName + ''', ''NOT ONLINE(' + @dbStatus + ')'','''+CONVERT(VARCHAR(20),getdate())+''','''+CONVERT(VARCHAR(20),getdate())+''','''+CONVERT(VARCHAR(20),getdate())+''')'
		print 'VALUES ('''+@save_domain_name+''', '''+@Enviro_Type+''',''' + @save_servername + ''',''' + UPPER(@@servername) + ''', ''' + @dbName + ''', ''NOT ONLINE(' + @dbStatus + ')'','''+CONVERT(VARCHAR(20),getdate())+''','''+CONVERT(VARCHAR(20),getdate())+''','''+CONVERT(VARCHAR(20),getdate())+''')'
		Print  @miscprint
		Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output


		Select @miscprint = 'GO '
		Print  @miscprint
		Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output


		Select @miscprint = ' '
		Print  @miscprint
		Select @cmd = 'echo.>>' + @outfile_path
		exec master.sys.xp_cmdshell @cmd, no_output
		fetch next from offlineCur into @dbName,@dbStatus
		break
	    end
	else
	    --Since added check for database status, now will place the online databases
	    --into a temporary table.
	    begin
		insert into #onlineStatus (dName) values (@dbname)
		 fetch next from offlineCur into @dbName,@dbStatus
	    end


	skip_offlineCur:


end
close offlineCur
deallocate offlineCur


----------------------------------------------------------------------------------------------
--  Start the Capture Process
----------------------------------------------------------------------------------------------
--get databases while I do not like cursors, a cursor, given the size of the dataset, is acceptable.


declare dbCur cursor for
select
    dname
from #onlineStatus


open dbCur


fetch next from dbCur into @dbName


while @@fetch_status = 0


	begin


	--  Skip AvailGrp DB's
	IF (select @@version) not like '%Server 2005%' and (SELECT SERVERPROPERTY ('productversion')) > '11.0.0000' --sql2012 or higher
	   begin
		Select @cmd = 'SELECT @a = (select name from master.sys.databases where name = ''' + @dbName  + ''' and replica_id is not null and group_database_id is not null)'
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
					where dbcs.database_name = @dbName
					and   agstates.primary_replica <> @@servername)
		   begin
			Print 'DBA Note: Skipping DB ' + @dbName + '.  This DB is a secondary replica in an Always On Availability Group.'
			raiserror('', -1,-1) with nowait
			break
			fetch next from dbCur into @dbName
		   end
	   end


	--  Check for existence of "Build" table. If no "Build" table, raise warning and move on.
	set @cmd3 = N'Use '+quotename(@dbname)+ ' select @buildExist = count(*) from sys.objects where name = ''build'' and schema_id in (select schema_id from sys.schemas where name = ''dbo'')'
        set @parm3def = N'@buildExist int OUTPUT'
        execute sp_executesql @cmd3,@parm3def, @buildExist = @bExist output


	if (@bExist = 0)
	    begin
		Select @miscprint = 'DBA WARNING: '+ @dbName + ' is missing the "Build" table.'
		--Print @miscprint
		raiserror(@miscprint,-1,-1) with log
		break
		fetch next from dbCur into @dbName
	    end
	else
	    begin
		    --Get Baseline Date
		 set @cmd = N'Use '+quotename(@dbName)+' select @bDate = dtBuildDate from dbo.build where vchLabel = ''Baseline Backup'' or vchLabel=''Backup, Detach & Move'''
		 set @parm1def = N'@bDate varchar(20)OUTPUT'
		 execute sp_executesql @cmd, @parm1def, @bDate = @baselinedt output

		 if(@baselinedt is null)
		    begin
			select @baselinedt = 'No Baseline'
		    end


		    --Get most recent Build Date and Build Number


		    set @cmd = N'Use '+quotename(@dbName)+' SELECT @build = vchLabel, @buDate = dtbuildDate FROM dbo.build WHERE  vchlabel not like ''%backup%'' and dtBuildDate =(SELECT MAX(dtBuildDate)FROM build)'
		    set @parm2def = N'@buDate varchar(20)OUTPUT, @build varchar(50) OUTPUT'
		    execute sp_executesql @cmd, @parm2def, @buDate = @buildDate output, @build = @buildNumber output


		    --Write out the data


		    Select @miscprint = 'delete from DBAOps.dbo.DBA_DeplInfo where SQLName = '''+@@servername+''' and dbName = '''+@dbName+ ''''
		    Print  @miscprint
		    Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    Select @miscprint = 'GO '
		    Print  @miscprint
		    Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    Select @miscprint = 'insert into DBAOps.dbo.DBA_DeplInfo (Domain, Enviro_Type, ServerName, SQLName, DBName, Build_Number, Build_Date,  Baseline_Date,  Record_Date)'
		    Print  @miscprint
		    Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    Select @miscprint = 'VALUES (''' + upper(@dmn) + ''', '''+UPPER(@Enviro_type)+''',''' + @save_servername + ''',''' + UPPER(@@servername) + ''', ''' + @dbName + ''', ''' + @buildNumber + ''','''+@buildDate+''','''+@baselinedt+''','''+CONVERT(VARCHAR(20),getdate())+''')'
		    Print  @miscprint
		    Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    Select @miscprint = 'GO '
		    Print  @miscprint
		    Select @cmd = 'echo ' + @miscprint + '>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    Select @miscprint = ' '
		    Print  @miscprint
		    Select @cmd = 'echo.>>' + @outfile_path
		    exec master.sys.xp_cmdshell @cmd, no_output


		    fetch next from dbCur into @dbName
	    end


	    skip_dbCur:


	end
close dbCur
deallocate dbCur


If @Enviro_Type = 'local'
   begin
	goto skip_filecopytocentral
   end


-- Copy the file to the main central server, in this case SEAPDBASQL01
If @save_domain_name not in ('production', 'stage')
   begin
	Select @cmd = 'xcopy "' + rtrim(@outfile_path) + '" "\\seapdbasql01\DBA_SQL_Register"'
	Select @cmd = @cmd + ' /Y /R'
	Print @cmd
	EXEC master.sys.xp_cmdshell @cmd, no_output
   end
Else
   begin
	Select @hold_source_path = '\\' + upper(@save_servername) + '\' + upper(@save_servername2) + '_dbasql\dba_reports'
	exec DBAOps.dbo.dbasp_File_Transit @source_name = @outfile_name
		,@source_path = @hold_source_path
		,@target_env = 'AMER'
		,@target_server = 'seapdbasql01'
		,@target_share = 'DBA_SQL_Register'
   end


skip_filecopytocentral:


---------------------------  Finalization  -----------------------


label99:


drop table #fileexists
drop table #regresults
drop table #onlineStatus
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetBuildInfo] TO [public]
GO
