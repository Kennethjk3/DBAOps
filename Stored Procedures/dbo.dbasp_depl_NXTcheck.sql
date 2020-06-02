SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_depl_NXTcheck]    (@dbname sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_depl_NXTcheck
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 12, 2007
 **
 **  This procedure is used to check for local NXT files
 **  that are used as part of the DEPL DB restore process.
 **
 **  MDFnxt and NDFnxt files are used as part of the
 **  file attach process in SQL deployments.  These files
 **  are created on the local servers using backup files
 **  that were created as part of the weekly baseline process.
 **
 **  This process checks for DEPL restore jobs.  Then it checks
 **  for related NXT files in the NXT share.  The 'Base - Local Process'
 **  job is started if there is available disk space but no
 **  no NXT files.
 **
 **  If @dbname is specified, the process will check for NXT files
 **  related to that DB only.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/12/2007	Steve Ledridge		New process
--	03/23/2007	Steve Ledridge		Fix code for single dbname request
--	04/10/2007	Steve Ledridge		Updated for SQL 2005
--	04/30/2008	Steve Ledridge		Changes to support new local nxt creation process.
--	05/08/2008	Steve Ledridge		Several updates.  Will now alert for NXT's in the mdf share.
--						Check for nxt and mdf share on the same drive.
--						Skip entire process for production.
--	05/12/2008	Steve Ledridge		Fix start job syntax error.
--	09/17/2008	Steve Ledridge		Added skip for DBnames in ase_Skip_sqb2nxt table.
--	04/20/2011	Steve Ledridge		Updated to support cBAK files.
--	01/29/2014	Steve Ledridge		Changed tssqldba to tsdba.
--	======================================================================================


/***
Declare @dbname sysname


--Select @dbname = 'DBAOps'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			varchar(4000)
	,@outmessage			varchar(4000)
	,@outsubject			varchar(500)
	,@charpos			int
	,@charpos2			int
	,@cmd				varchar(4000)
	,@local_nxt_path		varchar(500)
	,@local_mdf_path		varchar(500)
	,@local_nxt_share		varchar(500)
	,@local_mdf_share		varchar(500)
	,@nxt_path			sysname
	,@mdf_path			sysname
	,@save_path			varchar(500)
	,@error_count			int
	,@save_servername		sysname
	,@save_servername2		sysname
	,@sv_filesize			nvarchar(255)
	,@sv_freespace			nvarchar(255)
	,@sv_cmdout			nvarchar(255)
	,@sv_filedate			nvarchar(10)
	,@save_dbname			sysname
	,@save_depljobname		sysname
	,@save_jname			sysname
	,@hold_full_jname		sysname
	,@save_mdfnxt_name		sysname
	,@save_mdf_name			sysname
	,@start_job			char(1)
	,@nxt_flag			char(1)
	,@status1 			varchar(10)
	,@save_sqb_name			sysname


DECLARE
	 @cu11filename			sysname


----------------  initial values  -------------------
Select @error_count = 0
Select @start_job = 'n'
Select @nxt_flag = 'y'
Select @outmessage = ''
Select @outsubject = 'DBA NXT Warning for SQL instance ' + @@servername


--  Create table variable
declare @dbnames table (dbname sysname)


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


create table #DirTmpTbl(cmdout nvarchar(255) null)
create table #DirTmpTbl2(cmdout nvarchar(255) null)
create table #DirTmpTbl3(cmdout nvarchar(255) null)


create table #fileexists (doesexist smallint,
			fileindir smallint,
			direxist smallint)


--  Skip this process for production
If (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname') = 'production'
   begin
	goto label99
   end


--  Process input parm.  Insert DB names into the table variable
if @dbname is null and (select count(*) from msdb.dbo.sysjobs where name like 'depl%' and name like '% - Restore %') > 0
   begin
	Select @hold_full_jname = ''
	start_jname_parse:
	select @save_jname = (select top 1 name from msdb.dbo.sysjobs
				where name like 'depl%'
				and name like '% - Restore %'
				and name > @hold_full_jname)
	--print @save_jname
	select @hold_full_jname = @save_jname


	If @save_jname is not null
	   begin
		select @charpos = charindex('- Restore', @save_jname)
		IF @charpos <> 0
		   begin
			select @save_jname = substring(@save_jname, @charpos + 10, 100)
			Insert into @dbnames values(@save_jname)
			--Print @save_jname
		   end
		goto start_jname_parse
	   end
   end
Else if @dbname is not null
   begin
	Insert into @dbnames values(@dbname)
   end


If (select count(*) from @dbnames) = 0
   begin
	Select @miscprint = 'No DEPL Restore jobs configured on this SQL instance'
	Print @miscprint
	goto label99
   end


--  Make sure the Base - Local Process job exists
if not exists (select 1 from msdb.dbo.sysjobs where name = 'BASE - Local Process')
   begin
	Select @miscprint = 'DBA Error:  The SQL job ''Base - Local Process'' does not exists on this SQL instance. ' + @@servername
	Print @miscprint
	raiserror(@miscprint,16,-1) with log
	goto label99
   end


--  Set and verify MDF share
Select @local_mdf_path = '\\' + @save_servername + '\' + @save_servername2 + '_mdf'
delete from #fileexists
Insert into #fileexists exec master.sys.xp_fileexist @local_mdf_path
--select * from #fileexists
If (select top 1 direxist from #fileexists) = 0
   begin
	Select @miscprint = 'DBA Error:  No MDF share configured for this SQL instance. ' + @@servername
	Print @miscprint
	raiserror(@miscprint,16,-1) with log
	goto label99
   end


--  Set and verify NXT share
Select @local_nxt_path = '\\' + @save_servername + '\' + @save_servername2 + '_nxt'
delete from #fileexists
Insert into #fileexists exec master.sys.xp_fileexist @local_nxt_path
--select * from #fileexists
If (select top 1 direxist from #fileexists) = 0
   begin
	Select @miscprint = 'DBA Warning:  No NXT share configured for this SQL instance. ' + @@servername
	Print @miscprint
	raiserror(@miscprint,16,-1) with log
	Select @nxt_flag = 'n'
   end
Else
   begin
	--  Make sure the mdf and nxt shares are on the same physical drive
	Select @local_mdf_share = @save_servername2 + '_mdf'
	Select @local_nxt_share = @save_servername2 + '_nxt'
	exec DBAOps.dbo.dbasp_get_share_path @local_mdf_share, @mdf_path output
	exec DBAOps.dbo.dbasp_get_share_path @local_nxt_share, @nxt_path output


	If @mdf_path is not null
	    and @nxt_path is not null
	    and left(@mdf_path, 3) <> left(@nxt_path, 3)
	   begin
		Select @miscprint = 'DBA Warning:  MDF and NXT shares are not on the same physical drive for this SQL instance. ' + @@servername
		Print @miscprint
		raiserror(@miscprint,16,-1) with log
	   end
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  First, check the MDF share for NXT files.  There should be none.  NXT files should only live in the NXT share.
--  Get info from the mdf share
Select @cmd = 'DIR ' + rtrim(@local_mdf_path) + '\*.*nxt /-c'
--print @cmd
delete from #DirTmpTbl
Insert into #DirTmpTbl exec master.sys.xp_cmdshell @cmd
delete from #DirTmpTbl where cmdout like '%network path was not found%' or cmdout is null
delete from #DirTmpTbl where cmdout like '%volume %' or cmdout is null
delete from #DirTmpTbl where cmdout like '%Directory %' or cmdout is null
--select * from #DirTmpTbl


If not exists (select 1 from #DirTmpTbl where cmdout like '%File Not Found%')
   begin
	select * from #DirTmpTbl
	Select @miscprint = 'DBA Warning:  NXT files exist in the local MDF share for this SQL instance (' + @@servername + ').  They should be deleted).'
	Print @miscprint
	raiserror(@miscprint,16,-1) with log
   end


--  Next, check the MDF share for baseline files.  There should be none.  Baseline files should only live in the BASE share.
--  Get info from the mdf share
Select @cmd = 'DIR ' + rtrim(@local_mdf_path) + '\*_prod.* /-c'
--print @cmd
delete from #DirTmpTbl
Insert into #DirTmpTbl exec master.sys.xp_cmdshell @cmd
delete from #DirTmpTbl where cmdout like '%network path was not found%' or cmdout is null
delete from #DirTmpTbl where cmdout like '%volume %' or cmdout is null
delete from #DirTmpTbl where cmdout like '%Directory %' or cmdout is null
--select * from #DirTmpTbl


If not exists (select 1 from #DirTmpTbl where cmdout like '%File Not Found%')
   begin
	select * from #DirTmpTbl
	Select @miscprint = 'DBA Warning:  Baseline files exist in the local MDF share for this SQL instance (' + @@servername + ').  They should be deleted).'
	Print @miscprint
	raiserror(@miscprint,16,-1) with log
   end


--  Get the first DB name to check
Start_dbnames:
Select @save_dbname = (select top 1 dbname from @dbnames)
--print @save_dbname


If exists (select SQBname from dbo.Base_Skip_sqb2nxt where SQBname = @save_dbname + '_prod.SQB')
   or exists (select SQBname from dbo.Base_Skip_sqb2nxt where SQBname = @save_dbname + '_prod.cBAK')
   begin
	Print 'Skip the dbname: ' + @save_dbname
	goto end_dbnames
   end


--  Get info from the nxt share
If @nxt_flag = 'y'
   begin
	Select @cmd = 'DIR ' + rtrim(@local_nxt_path) + '\*.* /-c'
	--print @cmd
	delete from #DirTmpTbl2
	Insert into #DirTmpTbl2 exec master.sys.xp_cmdshell @cmd
	delete from #DirTmpTbl2 where cmdout like '%network path was not found%' or cmdout is null
	--select * from #DirTmpTbl2
   end


--  Get the mdf and ndf files names related to this DB


--------------------  Cursor for sysfiles -----------------------
EXECUTE('DECLARE cursor_11files Insensitive Cursor For ' +
  'SELECT a.filename
   From ' + @save_dbname + '.sys.sysfiles a ' +
  'Where a.groupid > 0
   For Read Only')


OPEN cursor_11files


WHILE (11=11)
   Begin
	FETCH Next From cursor_11files Into @cu11filename
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11files
	      BREAK
           end


	--  Check to see if all components of the file attach process exist
	Select @save_mdfnxt_name = rtrim(@cu11filename)
	label10a:
	select @charpos = charindex('\', @save_mdfnxt_name)
	IF @charpos <> 0
	   begin
		select @save_mdfnxt_name = substring(@save_mdfnxt_name, @charpos + 1, 100)
	   end

	select @charpos = charindex('\', @save_mdfnxt_name)
	IF @charpos <> 0
	   begin
		goto label10a
	   end


	Select @save_mdf_name = rtrim(@save_mdfnxt_name)
	Select @save_mdfnxt_name = rtrim(@save_mdfnxt_name) + 'nxt'
	--Print rtrim(@save_mdfnxt_name)


	--  Check to see if we have an old nxt file in the nxt share.  Delete it if too old.
	If exists (select 1 from #DirTmpTbl2 where cmdout like '%' + @save_mdfnxt_name + '%')
	   and @nxt_flag = 'y'
	   begin
		select @sv_cmdout = (select top 1 cmdout from #DirTmpTbl2 where cmdout like '%' + @save_mdfnxt_name + '%')
		select @sv_filedate = rtrim(substring(@sv_cmdout, 1, 10))
		If datediff(d, convert(datetime, @sv_filedate), getdate()) > 8
		   begin
			select @cmd = 'del ' + rtrim(@local_nxt_path) + '\' + rtrim(@save_mdfnxt_name)
			Print @cmd
			exec master.sys.xp_cmdshell @cmd


			delete from #DirTmpTbl2 where cmdout like '%' + @save_mdfnxt_name + '%'


			Select @miscprint = 'DBA Warning: Old NXT file deleted from the NXT share on server ' + @@servername + '.  File: ' + @save_mdfnxt_name + '  Date: ' + @sv_filedate
			Print @miscprint
		   end
	   end


	If (select @@version) not like '%Server 2005%' and (select SERVERPROPERTY ('productversion')) > '10.50.0000'
	   begin
		Select @save_sqb_name = rtrim(@save_dbname) + '_prod.cBAK'
	   end
	Else
	   begin
		Select @save_sqb_name = rtrim(@save_dbname) + '_prod.sqb'
	   end


	If exists (select 1 from #DirTmpTbl2 where cmdout like '%' + @save_sqb_name + '%')
	   and @nxt_flag = 'y'
	   begin
		select @sv_cmdout = (select top 1 cmdout from #DirTmpTbl2 where cmdout like '%' + @save_sqb_name + '%')
		select @sv_filedate = rtrim(substring(@sv_cmdout, 1, 10))
		If datediff(d, convert(datetime, @sv_filedate), getdate()) > 8
		   begin
			select @cmd = 'del ' + rtrim(@local_nxt_path) + '\' + rtrim(@save_sqb_name)
			Print @cmd
			exec master.sys.xp_cmdshell @cmd


			delete from #DirTmpTbl2 where cmdout like '%' + @save_sqb_name + '%'


			Select @miscprint = 'DBA Warning: Old baseline file deleted from the NXT share on server ' + @@servername + '.  File: ' + @save_sqb_name + '  Date: ' + @sv_filedate
			Print @miscprint
		   end
	   end


	--  Now check to see if we have an NXT file in the NXT share.
	If not exists (select 1 from #DirTmpTbl2 where cmdout like '%' + @save_mdfnxt_name + '%')
	   and @nxt_flag = 'y'
	   begin
		--  The nxt file was not found.  Now check to see if there is room for the file
		--  Get the size of the current DB file
		Select @cmd = 'DIR ' + rtrim(@cu11filename) + ' /-c'
		--print @cmd
		delete from #DirTmpTbl3
		Insert into #DirTmpTbl3 exec master.sys.xp_cmdshell @cmd
		delete from #DirTmpTbl3 where cmdout like '%network path was not found%' or cmdout is null
		delete from #DirTmpTbl3 where cmdout not like '%' + @save_mdf_name + '%'
		--select * from #DirTmpTbl3
		select @sv_cmdout = (select top 1 cmdout from #DirTmpTbl3)
		select @sv_filesize = ltrim(substring(@sv_cmdout, 22, 17))


		--  get the amount of free space available for this share
		select @sv_freespace = (select top 1 cmdout from #DirTmpTbl2 where cmdout like '%bytes free%')
		Select @charpos = charindex('Dir(s)', @sv_freespace)
		Select @charpos2 = charindex('bytes free', @sv_freespace)
		select @sv_freespace = ltrim(substring(@sv_freespace, @charpos+6, (@charpos2-@charpos)-7))


		If convert(bigint, rtrim(@sv_filesize)) < convert(bigint, rtrim(@sv_freespace))
		   begin
			Select @miscprint = 'DBA Warning: NXT file missing from the NXT share on server ' + @@servername + '.  File: ' + @save_mdfnxt_name
			Print @miscprint
			Select @outmessage = @outmessage + @miscprint
			Select @outmessage = @outmessage + char(13)+char(10) + char(13)+char(10)
			Select @start_job = 'y'
		   end
		Else
		   begin
			Select @miscprint = 'DBA Message: NXT file missing due to disk space in the NXT share on server ' + @@servername + '.  File: ' + @save_mdfnxt_name
			Print @miscprint
		   end


	   end


	end_11:


   End  -- loop 11
Deallocate cursor_11files


end_dbnames:


Delete from @dbnames where dbname = @save_dbname
If (select count(*) from @dbnames) > 0
   begin
	goto Start_dbnames
   end


--  check @start_job.  If all DEPL jobs are idle, start the 'BASE - Local Process' job
If @start_job = 'y'
   begin
	Select @save_depljobname = ''
	start_jobstate:
	Select @save_depljobname = (select top 1 name from msdb.dbo.sysjobs where name like 'depl%' and name > @save_depljobname)
	If @save_depljobname is not null
	   begin
		exec DBAOps.dbo.dbasp_Check_Jobstate @save_depljobname, @status1 output


		IF @status1 <> 'idle'
		   begin
			Select @start_job = 'n'
			goto start_job_end
		   end
	   end


	If exists (select 1 from msdb.dbo.sysjobs where name like 'depl%' and name > @save_depljobname)
	   begin
		goto start_jobstate
	   end


	--  If the Base - Local Process job is not running, start it now
	exec DBAOps.dbo.dbasp_Check_Jobstate 'BASE - Local Process', @status1 output


	IF @status1 = 'idle'
	   begin
		exec msdb.dbo.sp_start_job @job_name = 'BASE - Local Process'
		Select @miscprint = 'Note: Started SQL job ''BASE - Local Process'' on SQL instance ' + @@servername
		Print @miscprint
		Select @outmessage = @outmessage + @miscprint
		Select @outmessage = @outmessage + char(13)+char(10) + char(13)+char(10)
	   end
   end


start_job_end:


If @outmessage <> ''
   begin
	--  Email TS SQL DBA with this information
	EXEC DBAOps.dbo.dbasp_sendmail
		--@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@recipients = 'DBANotify@${{secrets.DOMAIN_NAME}}',
		@subject = @outsubject,
		@message = @outmessage
   end


--  Finalization  -------------------------------------------------------------------


label99:


drop table #DirTmpTbl
drop table #DirTmpTbl2
drop table #DirTmpTbl3
drop table #fileexists
GO
GRANT EXECUTE ON  [dbo].[dbasp_depl_NXTcheck] TO [public]
GO
