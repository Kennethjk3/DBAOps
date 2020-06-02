SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Update_SQLjobs] @runtype	varchar(20) = 'report'


/***************************************************************
 **  Stored Procedure dbasp_Update_SQLjobs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 15, 2002
 **
 **  This dbasp is set up to;
 **
 **  Report Current Job status (parm=report)
 **
 **  Disable all enabled local sql jobs (parm=disable)
 **    - as long as no records exist in the DBAOps.dbo.DisabledJobs table
 **
 **  Disable all enabled sql jobs (parm=disable_force)
 **    - Even if records exist in the DBAOps.dbo.DisabledJobs table
 **
 **  Re-enable all previously disabled jobs (parm=enable)
 **
 **  Enable all disabled jobs (parm=enable_force)
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/15/2002	Steve Ledridge		New process
--	05/28/2009	Steve Ledridge		Convert To 2005
--	12/19/2011	Steve Ledridge		Added code to disable only APPL jobs (disable_APPL).
--	======================================================================================


--Declare @runtype varchar(20)
--Select  @runtype = 'report1'


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(4000)
	,@sql				varchar(500)
	,@currdate			datetime
	,@report_flag			char(1)
	,@disable_flag			char(1)
	,@enable_flag			char(1)
	,@Dforce_flag			char(1)
	,@DisAPPL_flag			char(1)
	,@Eforce_flag			char(1)
	,@output_flag			char(1)
	,@cursor11_text			nvarchar(1024)
	,@cursor12_text			nvarchar(1024)
	,@cursor13_text			nvarchar(1024)
	,@cursor21_text			nvarchar(1024)
	,@cursor22_text			nvarchar(1024)
	,@cursor23_text			nvarchar(1024)
	,@cursor31_text			nvarchar(1024)
	,@cursor32_text			nvarchar(1024)


DECLARE
	 @cu11name			sysname
	,@cu11originating_server	sysname


DECLARE
	 @cu12name			sysname
	,@cu12originating_server	sysname


DECLARE
	 @cu13jobname			sysname
	,@cu13disable_date		datetime


DECLARE
	 @cu21jobname			sysname
	,@cu21disable_date		datetime


DECLARE
	 @cu22job_id			varchar(50)
	,@cu22name			sysname
	,@cu22originating_server	sysname


DECLARE
	 @cu23name			sysname
	,@cu23originating_server	sysname


DECLARE
	 @cu31job_id			varchar(40)
	,@cu31jobname			sysname
	,@cu31disable_date		datetime


DECLARE
	 @cu32job_id			varchar(50)
	,@cu32name			sysname
	,@cu32originating_server	sysname


/*********************************************************************
 *                Initialization
 ********************************************************************/
Select @report_flag = 'n'
Select @disable_flag = 'n'
Select @Dforce_flag = 'n'
Select @DisAPPL_flag = 'n'
Select @enable_flag = 'n'
Select @Eforce_flag = 'n'
Select @currdate = getdate()


--  Check input parm
If @runtype = 'report'
   begin
	Select @report_flag = 'y'
   end
Else If @runtype = 'disable'
   begin
	Select @disable_flag = 'y'
   end
Else If @runtype = 'disable_force'
   begin
	Select @Dforce_flag = 'y'
   end
Else If @runtype = 'disable_APPL'
   begin
	Select @DisAPPL_flag = 'y'
   end
Else If @runtype = 'enable'
   begin
	Select @enable_flag = 'y'
   end
Else If @runtype = 'enable_force'
   begin
	Select @Eforce_flag = 'y'
   end
Else
   begin
	Select @miscprint = 'ERROR for sproc dbasp_Update_SQLjobs:  Invalid parameter used.  Must be ''report'', ''disable'', ''disable_force'', ''enable'', or ''enable_force''.'
	Print  @miscprint
	goto label99
   end


If @report_flag = 'y'
   begin
	--  Print the headers
	Print  ' '
	Print  '/********************************************************************'
	Select @miscprint = '   dbasp_Update_SQLjobs:  Flag = ' + @runtype
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- Executed on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
	Print  @miscprint
	Print  '********************************************************************/'
	Print  ' '
	Select @miscprint = 'The following SQL jobs are currently enabled'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Local Job Name'
	Print  @miscprint
	Select @miscprint = '----------------------------------------------------------'
	Print  @miscprint
	Select @output_flag = 'n'


	Select @cursor11_text = 'DECLARE cu11_cursor Insensitive Cursor For ' +
	  'SELECT j.name, m.srvname
	   From msdb.dbo.sysjobs j
	   join master.sys.sysservers as m on j.originating_server_id = m.srvid ' +
	  'Where j.enabled = 1
	     and (m.srvname = ''(local)'' or UPPER(m.srvname) = UPPER(CONVERT(NVARCHAR(30), @@servername)))
	   Order by m.srvname, j.name For Read Only'


	EXECUTE (@cursor11_text)


	OPEN cu11_cursor


	WHILE (11=11)
	 Begin
		FETCH Next From cu11_cursor Into @cu11name, @cu11originating_server
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu11_cursor
		      BREAK
	           end


		Select @miscprint = @cu11name
		Print  @miscprint
		Select @output_flag = 'y'


	 End  -- loop 11


	DEALLOCATE cu11_cursor


	If @output_flag = 'n'
	   begin
		Select @miscprint = 'No local enabled jobs to report'
		Print  @miscprint
	   end


	Print  ' '
	Select @miscprint = 'MultiServer Job Name                                          Originating Server'
	Print  @miscprint
	Select @miscprint = '----------------------------------------------------------    -------------------------'
	Print  @miscprint
	Select @output_flag = 'n'


	Select @cursor12_text = 'DECLARE cu12_cursor Insensitive Cursor For ' +
	  'SELECT j.name, m.srvname
	   From msdb.dbo.sysjobs j ' +
	  ' join master.sys.sysservers as m on j.originating_server_id = m.srvid  ' +
	  'Where j.enabled = 1
	     and (m.srvname <> ''(local)'' and UPPER(m.srvname) <> UPPER(CONVERT(NVARCHAR(30), @@servername)))
	   Order by m.srvname, j.name For Read Only'


	EXECUTE (@cursor12_text)


	OPEN cu12_cursor


	WHILE (12=12)
	 Begin
		FETCH Next From cu12_cursor Into @cu12name, @cu12originating_server
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu12_cursor
		      BREAK
	           end


		Select @miscprint = convert(char(60), @cu12name) + '  ' + convert(char(27), @cu12originating_server)
		Print  @miscprint
		Select @output_flag = 'y'


	 End  -- loop 12


	DEALLOCATE cu12_cursor


	If @output_flag = 'n'
	   begin
		Select @miscprint = 'No MultiServer enabled jobs to report'
		Print  @miscprint
	   end


	Print  ' '
	Print  ' '
	Print  ' '
	Select @miscprint = 'The following SQL jobs were previously disabled by this process'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Disabled Job Name                                             Disable Date'
	Print  @miscprint
	Select @miscprint = '----------------------------------------------------------    -------------------------'
	Print  @miscprint
	Select @output_flag = 'n'


	Select @cursor13_text = 'DECLARE cu13_cursor Insensitive Cursor For ' +
	  'SELECT d.jobname, d.disable_date
	   From DBAOps.dbo.DisabledJobs d ' +
	  'Order by d.jobname For Read Only'


	EXECUTE (@cursor13_text)


	OPEN cu13_cursor


	WHILE (13=13)
	 Begin
		FETCH Next From cu13_cursor Into @cu13jobname, @cu13disable_date
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu13_cursor
		      BREAK
	           end


		Select @miscprint = convert(char(60), @cu13jobname) + '   ' + convert(varchar(20), @cu13disable_date, 120)
		Print  @miscprint
		Select @output_flag = 'y'


	 End  -- loop 13


	DEALLOCATE cu13_cursor


	If @output_flag = 'n'
	   begin
		Select @miscprint = 'No previously disabled jobs to report'
		Print  @miscprint
	   end


   end


--  Disable process
If @disable_flag = 'y' or @Dforce_flag = 'y' or @DisAPPL_flag = 'y'
   begin
	--  Print the headers
	Print  ' '
	Print  '/********************************************************************'
	Select @miscprint = '   dbasp_Update_SQLjobs:  Flag = ' + @runtype
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- Executed on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
	Print  @miscprint
	Print  '********************************************************************/'
	Print  ' '


	If @Dforce_flag = 'y'
	   begin
		Delete from DBAOps.dbo.DisabledJobs
	   end


	If (select count(*) from DBAOps.dbo.DisabledJobs) > 0
	   begin
		Select @miscprint = 'Warning:  Unable to disable jobs with this parameter.'
		Print  @miscprint
		Select @miscprint = '          To force the disable, use ''disable_force''.'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'The following SQL jobs were previously disabled by this process'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'Disabled Job Name                                             Disable Date'
		Print  @miscprint
		Select @miscprint = '----------------------------------------------------------    -------------------------'
		Print  @miscprint


		Select @cursor21_text = 'DECLARE cu21_cursor Insensitive Cursor For ' +
		  'SELECT d.jobname, d.disable_date
		   From DBAOps.dbo.DisabledJobs d ' +
		  'Order by d.jobname For Read Only'


		EXECUTE (@cursor21_text)


		OPEN cu21_cursor


		WHILE (21=21)
		 Begin
			FETCH Next From cu21_cursor Into @cu21jobname, @cu21disable_date
			IF (@@fetch_status < 0)
		           begin
		              CLOSE cu21_cursor
			      BREAK
		           end


			Select @miscprint = convert(char(60), @cu21jobname) + '  ' + convert(varchar(20), @cu21disable_date, 120)
			Print  @miscprint


		 End  -- loop 21


		DEALLOCATE cu21_cursor
	   end
	Else
	   begin
		Select @miscprint = 'The following SQL jobs have now been disabled'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'Local Job Name'
		Print  @miscprint
		Select @miscprint = '----------------------------------------------------------'
		Print  @miscprint
		Select @output_flag = 'n'


		If @DisAPPL_flag = 'y'
		   begin
			Select @cursor22_text = 'DECLARE cu22_cursor Insensitive Cursor For ' +
			  'SELECT convert(varchar(50), j.job_id), j.name, m.srvname
			   From msdb.dbo.sysjobs j ' +
			  'join master.sys.sysservers as m on j.originating_server_id = m.srvid '+
			  'Where j.enabled = 1
			     and j.name like ''APPL%''
			     and (m.srvname = ''(local)'' or UPPER(m.srvname) = UPPER(CONVERT(NVARCHAR(30), @@servername)))
			   Order by m.srvname, j.name For Read Only'
		   end
		Else
		   begin
			Select @cursor22_text = 'DECLARE cu22_cursor Insensitive Cursor For ' +
			  'SELECT convert(varchar(50), j.job_id), j.name, m.srvname
			   From msdb.dbo.sysjobs j ' +
			  'join master.sys.sysservers as m on j.originating_server_id = m.srvid '+
			  'Where j.enabled = 1
			     and (m.srvname = ''(local)'' or UPPER(m.srvname) = UPPER(CONVERT(NVARCHAR(30), @@servername)))
			   Order by m.srvname, j.name For Read Only'
		   end


		EXECUTE (@cursor22_text)


		OPEN cu22_cursor


		WHILE (22=22)
		 Begin
			FETCH Next From cu22_cursor Into @cu22job_id, @cu22name, @cu22originating_server
			IF (@@fetch_status < 0)
		           begin
		              CLOSE cu22_cursor
			      BREAK
		           end


			Select @sql = 'msdb.dbo.sp_update_job @job_id = ''' + @cu22job_id + ''', @enabled = 0'
			exec (@sql)

			Insert into DBAOps.dbo.DisabledJobs(Job_ID, JobName, Disable_date) values (@cu22job_id, @cu22name, @currdate)


			Select @miscprint = @cu22name
			Print  @miscprint
			Select @output_flag = 'y'


		 End  -- loop 22

		DEALLOCATE cu22_cursor


		If @output_flag = 'n'
		   begin
			Select @miscprint = 'No local enabled jobs to disable'
			Print  @miscprint
		   end


		Print  ' '
		Print  ' '
		Print  ' '
		Select @miscprint = 'The following MultiServer SQL jobs cannot be disabled locally'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'MultiServer Job Name                                          Originating Server'
		Print  @miscprint
		Select @miscprint = '----------------------------------------------------------    -------------------------'
		Print  @miscprint
		Select @output_flag = 'n'


		If @DisAPPL_flag = 'y'
		   begin
			Select @cursor23_text = 'DECLARE cu23_cursor Insensitive Cursor For ' +
			  'SELECT j.name, m.srvname
			   From msdb.dbo.sysjobs j ' +
			  'join master.sys.sysservers as m on j.originating_server_id = m.srvid '+
			  'Where j.enabled = 1
			     and j.name like ''APPL%''
			     and (m.srvname <> ''(local)'' and UPPER(m.srvname) <> UPPER(CONVERT(NVARCHAR(30), @@servername)))
			   Order by m.srvname, j.name For Read Only'
		   end
		Else
		   begin
			Select @cursor23_text = 'DECLARE cu23_cursor Insensitive Cursor For ' +
			  'SELECT j.name, m.srvname
			   From msdb.dbo.sysjobs j ' +
			  'join master.sys.sysservers as m on j.originating_server_id = m.srvid '+
			  'Where j.enabled = 1
			     and (m.srvname <> ''(local)'' and UPPER(m.srvname) <> UPPER(CONVERT(NVARCHAR(30), @@servername)))
			   Order by m.srvname, j.name For Read Only'
		   end


		EXECUTE (@cursor23_text)

		OPEN cu23_cursor


		WHILE (23=23)
		 Begin
			FETCH Next From cu23_cursor Into @cu23name, @cu23originating_server
			IF (@@fetch_status < 0)
		           begin
		              CLOSE cu23_cursor
			      BREAK
		           end


			Select @miscprint = convert(char(60), @cu23name) + '  ' + convert(char(27), @cu23originating_server)
			Print  @miscprint
			Select @output_flag = 'y'


		 End  -- loop 23


		DEALLOCATE cu23_cursor


		If @output_flag = 'n'
		   begin
			Select @miscprint = 'No MultiServer enabled jobs to report'
			Print  @miscprint
		   end


	   end


   end


--  Enable process
If @enable_flag = 'y'
   begin
	--  Print the headers
	Print  ' '
	Print  '/********************************************************************'
	Select @miscprint = '   dbasp_Update_SQLjobs:  Flag = ' + @runtype
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- Executed on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
	Print  @miscprint
	Print  '********************************************************************/'
	Print  ' '


	If (select count(*) from DBAOps.dbo.DisabledJobs) = 0
	   begin
		Select @miscprint = 'No previously disabled jobs were found.'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'To enable all SQL jobs on this server, use the ''enable_force'' parameter.'
		Print  @miscprint


	   end
	Else
	   begin
		Select @miscprint = 'The following SQL jobs have now been enabled'
		Print  @miscprint
		Print  ' '
		Select @miscprint = 'Local Job Name'
		Print  @miscprint
		Select @miscprint = '----------------------------------------------------------'
		Print  @miscprint


		Select @cursor31_text = 'DECLARE cu31_cursor Insensitive Cursor For ' +
		  'SELECT d.job_id, d.jobname, d.disable_date
		   From DBAOps.dbo.DisabledJobs d ' +
		  'Order by d.jobname For Read Only'


		EXECUTE (@cursor31_text)


		OPEN cu31_cursor


		WHILE (31=31)
		 Begin
			FETCH Next From cu31_cursor Into @cu31job_id, @cu31jobname, @cu31disable_date
			IF (@@fetch_status < 0)
		           begin
		              CLOSE cu31_cursor
			      BREAK
		           end


			If exists(select 1 from msdb.dbo.sysjobs where name = @cu31jobname)
			   begin
				Select @sql = 'msdb.dbo.sp_update_job @job_name = ''' + @cu31jobname + ''', @enabled = 1'
				exec (@sql)

				Select @miscprint = @cu31jobname
				Print  @miscprint
			   end
			Else
			   begin
				Select @miscprint = convert(varchar(60), @cu31jobname) + '   ' + '(This job no longer exists'
				Print  @miscprint
			   end


			delete from DBAOps.dbo.DisabledJobs where job_id = @cu31job_id


		 End  -- loop 31


		DEALLOCATE cu31_cursor


	   end
   end


If @Eforce_flag = 'y'
   begin
	--  Print the headers
	Print  ' '
	Print  '/********************************************************************'
	Select @miscprint = '   dbasp_Update_SQLjobs:  Flag = ' + @runtype
	Print  @miscprint
	Print  ' '
	Select @miscprint = '-- Executed on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
	Print  @miscprint
	Print  '********************************************************************/'
	Print  ' '


	Delete from DBAOps.dbo.DisabledJobs


	Select @miscprint = 'The following local SQL jobs have now been enabled'
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Local Job Name'
	Print  @miscprint
	Select @miscprint = '----------------------------------------------------------'
	Print  @miscprint
	Select @output_flag = 'n'


	Select @cursor32_text = 'DECLARE cu32_cursor Insensitive Cursor For ' +
	  'SELECT convert(varchar(50), j.job_id), j.name, m.srvname
	   From msdb.dbo.sysjobs j ' +
	  'join master.sys.sysservers as m on j.originating_server_id = m.srvid '+
	  'Where j.enabled = 0
	     and (m.srvname = ''(local)'' or UPPER(m.srvname) = UPPER(CONVERT(NVARCHAR(30), @@servername)))
	   Order by m.srvname, j.name For Read Only'


	EXECUTE (@cursor32_text)

	OPEN cu32_cursor


	WHILE (32=32)
	 Begin
		FETCH Next From cu32_cursor Into @cu32job_id, @cu32name, @cu32originating_server
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu32_cursor
		      BREAK
	           end


		Select @sql = 'msdb.dbo.sp_update_job @job_id = ''' + @cu32job_id + ''', @enabled = 1'
		exec (@sql)


		Select @miscprint = @cu32name
		Print  @miscprint
		Select @output_flag = 'y'


	 End  -- loop 32


	DEALLOCATE cu32_cursor


	If @output_flag = 'n'
	   begin
		Select @miscprint = 'No local disabled jobs found'
		Print  @miscprint
	   end
   end


---------------------------  Finalization  -----------------------
Label99:


Select @miscprint = ' '
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_Update_SQLjobs] TO [public]
GO
