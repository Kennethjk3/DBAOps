SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_REPORTjobs]


/*********************************************************
 **  Stored Procedure dbasp_REPORTjobs
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 25, 2001
 **
 **  This dbasp is set up to create a report documenting
 **  enabled jobs on a specific SQL server.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	05/20/2002	Steve Ledridge		Fix the 'single quotes in the job name' problem
--	05/28/2002	Steve Ledridge		Changed hours to four didgit possible
--	06/21/2002	Steve Ledridge		Added code to handel negitive job step durrations.
--	09/26/2002	Steve Ledridge		Shortened long lines to 255
--	10/16/2008	Steve Ledridge		Updated for SQL 2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(255)
	,@cmd				varchar(4000)
	,@savecursor			varchar(4000)
	,@save_count			int
	,@save_runduration		int
	,@save_tot_seconds		int
	,@save_hr			int
	,@save_min			int
	,@save_sec			int
	,@save_dur_text			char (12)
	,@save_start_time		char (05)
	,@save_end_time			char (05)
	,@starthour			char (04)
	,@startmin			char (02)
	,@startsec			char (02)
	,@starttime			char (08)
	,@starthour1			char (01)
	,@starthour2			char (01)
	,@starthour3			char (01)
	,@starthour4			char (01)
	,@startmin1			char (01)
	,@startmin2			char (01)
	,@startsec1			char (01)
	,@startsec2			char (01)
	,@endtime			char (06)
	,@endhour1			char (01)
	,@endhour2			char (01)
	,@endmin1			char (01)
	,@endmin2			char (01)
	,@endsec1			char (01)
	,@endsec2			char (01)
	,@sched_flag			char (01)
	,@save_start_sun		char (10)
	,@save_start_mon		char (10)
	,@save_start_tue		char (10)
	,@save_start_wed		char (10)
	,@save_start_thur		char (10)
	,@save_start_fri		char (10)
	,@save_start_sat		char (10)
	,@day_suffix			char (02)
	,@output_flag			char(1)
	,@query_job_name		sysname
	,@startpos			int
	,@charpos			int

DECLARE
	 @cu10job_id			uniqueidentifier
	,@cu10job_name			sysname


DECLARE
	 @cu11step_id			int
	,@cu11run_duration		int


DECLARE
	 @cu12step_id			int
	,@cu12step_name			sysname


DECLARE
	 @cu13name			sysname
	,@cu13freq_type			int
	,@cu13freq_interval		int
	,@cu13freq_subday_type		int
	,@cu13freq_subday_interval	int
	,@cu13freq_relative_interval	int
	,@cu13freq_recurrence_factor	int
	,@cu13active_start_time		int
	,@cu13active_end_time		int


----------------  initial values  -------------------
Select @output_flag		= 'n'


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers


   Print  ' '
   Print  '/********************************************************************'
   Select @miscprint = '   REPORT SCHEDULED JOBS '
   Print  @miscprint
   Print  ' '
   Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
   Print  @miscprint
   Print  ' '
   Select @miscprint = '-- Note:  Averages are calculated for the past 30 days of activity'
   Print  @miscprint
   Print  '********************************************************************/'


--  Cursor for active jobs  -----------------------------------------------------------------
EXECUTE('DECLARE cursor_jobs Insensitive Cursor For ' +
  'SELECT j.job_id, j.name
   From msdb.dbo.sysjobs j ' +
  'Where j.enabled = 1
   Order By j.name For Read Only')


OPEN cursor_jobs


WHILE (10=10)
   Begin
	FETCH Next From cursor_jobs Into @cu10job_id, @cu10job_name


	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_jobs
	      BREAK
           end


--  If there are single quotes in the job name, change them to double single quotes for the query  ----------------
Select @query_job_name = @cu10job_name
Select @startpos = 1
label01:
	select @charpos = charindex('''', @query_job_name, @startpos)
	IF @charpos <> 0
	   begin
	    select @query_job_name = stuff(@query_job_name, @charpos, 1, '''''')
	    select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @query_job_name, @startpos)
	IF @charpos <> 0
	   begin
	    goto label01
 	   end


--  Load the run duration information for this job into a temp table  ----------------
create table #temp_duration(step_id int, run_duration int)


select @cmd = 'insert into #temp_duration(step_id, run_duration) select h.step_id, h.run_duration from msdb.dbo.sysjobhistory  h , msdb.dbo.sysjobs  j
		where j.name = ''' + @query_job_name + ''' and j.job_id = h.job_id and h.run_date > convert(int, (convert(char(8), getdate()-30, 112)))'


--print @cmd
exec (@cmd)


--  Convert run duration to seconds (math with time is a pain!)


--  Cursor for run duration info  -----------------------------------------------------------------
EXECUTE('DECLARE cursor_dur Cursor For ' +
  'SELECT d.step_id, d.run_duration
   From #temp_duration  d ' +
  'For Update')


OPEN cursor_dur

WHILE (11=11)
   Begin
	FETCH Next From cursor_dur Into @cu11step_id, @cu11run_duration

	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_dur
	      BREAK
           end


If @cu11run_duration < 0
   begin
	Select @cu11run_duration = 0
   end


Select @starttime  = str(@cu11run_duration, 8)
Select @starthour1  = substring(@starttime, 1, 1)
Select @starthour2  = substring(@starttime, 2, 1)
Select @starthour3  = substring(@starttime, 3, 1)
Select @starthour4  = substring(@starttime, 4, 1)
Select @startmin1   = substring(@starttime, 5, 1)
Select @startmin2   = substring(@starttime, 6, 1)
Select @startsec1   = substring(@starttime, 7, 1)
Select @startsec2   = substring(@starttime, 8, 1)

If @starthour1= ' '
   select @starthour1 = '0'
If @starthour2= ' '
   select @starthour2 = '0'
If @starthour3= ' '
   select @starthour3 = '0'
If @starthour4= ' '
   select @starthour4 = '0'
If @startmin1 = ' '
   select @startmin1 = '0'
If @startmin2 = ' '
   select @startmin2 = '0'
If @startsec1 = ' '
   select @startsec1 = '0'
If @startsec2 = ' '
   select @startsec2 = '0'


select @save_tot_seconds = convert(int, @startsec2)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @startsec1) * 10)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @startmin2) * 60)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @startmin1) * 600)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @starthour4) * 3600)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @starthour3) * 36000)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @starthour2) * 360000)
select @save_tot_seconds = @save_tot_seconds + (convert(int, @starthour1) * 3600000)


update #temp_duration set run_duration = @save_tot_seconds where current of cursor_dur


 End  -- run duration loop
DEALLOCATE cursor_dur


--  Select and format job duration
Select @save_count = (select count(*) from #temp_duration where step_id = 0)


If @save_count > 0
   begin
	Select @save_runduration = (select sum(run_duration)/count(*) from #temp_duration where step_id = 0)
   end
Else
   begin
	Select @save_runduration = 0
   end


If @save_runduration > 3599
   begin
	Select @save_hr = (@save_runduration/3600)
	Select @save_runduration = @save_runduration - (@save_hr * 3600)
   end
Else
   begin
	Select @save_hr = 0
   end


If @save_runduration > 59
   begin
	Select @save_min = (@save_runduration/60)
	Select @save_runduration = @save_runduration - (@save_min * 60)
   end
Else
   begin
	Select @save_min = 0
   end


Select @save_sec = @save_runduration


Select @starthour  = str(@save_hr, 4)
Select @starthour1  = substring(@starthour, 1, 1)
Select @starthour2  = substring(@starthour, 2, 1)
Select @starthour3  = substring(@starthour, 3, 1)
Select @starthour4  = substring(@starthour, 4, 1)
Select @startmin  = str(@save_min, 2)
Select @startmin1   = substring(@startmin, 1, 1)
Select @startmin2   = substring(@startmin, 2, 1)
Select @startsec  = str(@save_sec, 2)
Select @startsec1   = substring(@startsec, 1, 1)
Select @startsec2   = substring(@startsec, 2, 1)


   If @starthour3= ' '
      select @starthour3 = '0'
   If @starthour4= ' '
      select @starthour4 = '0'
   If @startmin1 = ' '
      select @startmin1 = '0'
   If @startmin2 = ' '
      select @startmin2 = '0'
   If @startsec1 = ' '
      select @startsec1 = '0'
   If @startsec2 = ' '
      select @startsec2 = '0'


Select @save_dur_text = @starthour1 + @starthour2 + @starthour3 + @starthour4 + ':' + @startmin1 + @startmin2 + ':' + @startsec1 + @startsec2


--  Print the job information  -----------------------------------------------------
Print  ' '
Print  ' '
Select @miscprint = '** Job/Step Name(s)                                     Avg Run Time'
Print  @miscprint
If @save_runduration = 0 and (select count(*) from #temp_duration) > 0
   begin
	Select @miscprint = convert(char(50), @cu10job_name) + '     Not Available'
	Print  @miscprint
   end
Else
   begin
	Select @miscprint = convert(char(50), @cu10job_name) + '     ' + @save_dur_text
	Print  @miscprint
   end


--  Cursor for job steps  ----------------------------------------------------------
select @savecursor = 'DECLARE cursor_steps Insensitive Cursor For ' +
  'SELECT s.step_id, s.step_name
   From msdb.dbo.sysjobsteps  s, msdb.dbo.sysjobs  j ' +
  'Where j.name = ''' + @query_job_name + '''
     and j.job_id = s.job_id
   Order By s.step_id For Read Only'


EXECUTE(@savecursor)


OPEN cursor_steps


WHILE (12=12)
   Begin
	FETCH Next From cursor_steps Into @cu12step_id,
					@cu12step_name


	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_steps
	      BREAK
           end


--  Select and format step duration
Select @save_count = (select count(*) from #temp_duration where step_id = @cu12step_id)
If @save_count > 0
   begin
	Select @save_runduration = (select sum(run_duration)/count(*) from #temp_duration where step_id = @cu12step_id)
   end
Else
   begin
	Select @save_runduration = 0
   end


If @save_runduration > 3599
   begin
	Select @save_hr = (@save_runduration/3600)
	Select @save_runduration = @save_runduration - (@save_hr * 3600)
   end
Else
   begin
	Select @save_hr = 0
   end


If @save_runduration > 59
   begin
	Select @save_min = (@save_runduration/60)
	Select @save_runduration = @save_runduration - (@save_min * 60)
   end
Else
   begin
	Select @save_min = 0
   end


Select @save_sec = @save_runduration


Select @starthour  = str(@save_hr, 4)
Select @starthour1  = substring(@starthour, 1, 1)
Select @starthour2  = substring(@starthour, 2, 1)
Select @starthour3  = substring(@starthour, 3, 1)
Select @starthour4  = substring(@starthour, 4, 1)
Select @startmin  = str(@save_min, 2)
Select @startmin1   = substring(@startmin, 1, 1)
Select @startmin2   = substring(@startmin, 2, 1)
Select @startsec  = str(@save_sec, 2)
Select @startsec1   = substring(@startsec, 1, 1)
Select @startsec2   = substring(@startsec, 2, 1)


   If @starthour3= ' '
      select @starthour3 = '0'
   If @starthour4= ' '
      select @starthour4 = '0'
   If @startmin1 = ' '
      select @startmin1 = '0'
   If @startmin2 = ' '
      select @startmin2 = '0'
   If @startsec1 = ' '
select @startsec1 = '0'
If @startsec2 = ' '
      select @startsec2 = '0'


Select @save_dur_text = @starthour1 + @starthour2 + @starthour3 + @starthour4 + ':' + @startmin1 + @startmin2 + ':' + @startsec1 + @startsec2


--  Print the jobstep information
Select @miscprint = '   ' + convert(char(50), @cu12step_name) + '     ' + @save_dur_text
Print  @miscprint


 End  -- sched loop
DEALLOCATE cursor_steps


Select @sched_flag = 'n'

--  Cursor for enabled job schedules  ----------------------------------------------------------
Select @savecursor = 'DECLARE cursor_sched Insensitive Cursor For ' +
  'SELECT s.name, s.freq_type, s.freq_interval, s.freq_subday_type, s.freq_subday_interval, s.freq_relative_interval, s.freq_recurrence_factor, s.active_start_time, s.active_end_time
   From msdb.dbo.sysschedules s, msdb.dbo.sysjobschedules  sj, msdb.dbo.sysjobs  j ' +
  'Where s.enabled = 1
     and s.schedule_id = sj.schedule_id
     and j.name = ''' + @query_job_name + '''
     and j.job_id = sj.job_id
   Order By s.schedule_id For Read Only'


EXECUTE(@savecursor)


OPEN cursor_sched


WHILE (13=13)
   Begin
	FETCH Next From cursor_sched Into @cu13name,
					@cu13freq_type,
					@cu13freq_interval,
					@cu13freq_subday_type,
					@cu13freq_subday_interval,
					@cu13freq_relative_interval,
					@cu13freq_recurrence_factor,
					@cu13active_start_time,
					@cu13active_end_time


	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_sched
	      BREAK
           end


--Print ' '
--Print '@cu13freq_type is ' + convert(varchar(20), @cu13freq_type)
--Print '@cu13freq_interval is ' + convert(varchar(20), @cu13freq_interval)
--Print '@cu13freq_subday_type is ' + convert(varchar(20), @cu13freq_subday_type)
--Print '@cu13freq_subday_interval is ' + convert(varchar(20), @cu13freq_subday_interval)
--Print '@cu13freq_relative_interval is ' + convert(varchar(20), @cu13freq_relative_interval)
--Print '@cu13freq_recurrence_factor is ' + convert(varchar(20), @cu13freq_recurrence_factor)
--Print '@cu13active_start_time is ' + convert(varchar(20), @cu13active_start_time)
--Print '@cu13active_end_time is ' + convert(varchar(20), @cu13active_end_time)


--  Set schedule flag  ---------------------------------------------------------
Select @sched_flag = 'y'


--  Process for special schedules  ---------------------------------------------------------
If @cu13freq_type = 64
   begin
	Print ' '
	Select @miscprint = '   Schedule: ' + @cu13name
	Print  @miscprint
	Select @miscprint = '   Starts automatically when SQL Server Agent Starts'
	Print  @miscprint
	goto label02
   end


If @cu13freq_type = 16
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_mon = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2
	If @cu13freq_interval in (1, 21, 31)
	   begin
		select @day_suffix = 'st'
	   end
	Else If @cu13freq_interval in (2, 22)
	   begin
		select @day_suffix = 'nd'
	   end
	Else If @cu13freq_interval in (3, 23)
	   begin
		select @day_suffix = 'rd'
	   end
	Else
	   begin
		select @day_suffix = 'th'
	   end
	Print ' '
	Select @miscprint = '   Schedule: ' + @cu13name
	Print  @miscprint
	Select @miscprint = '   Once a month on the ' + convert(varchar(5), @cu13freq_interval) + @day_suffix + ' at ' + @save_start_mon
	Print  @miscprint
	goto label02
   end


If @cu13freq_type = 1
   begin
	Print ' '
	Select @miscprint = '   Schedule: ' + @cu13name
	Print  @miscprint
	Select @miscprint = '   Set for ''one time'' execution'
	Print  @miscprint
	goto label02
   end


--  Set daily job start times  -------------------------------------------------
Select @save_start_sun = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (1,3,5,7,9,11,13,15,17,19,21,23,25,
							27,29,31,33,35,37,39,41,43,45,47,49,
							51,53,55,57,59,61,63,65,67,69,71,73,
							75,77,79,81,83,85,87,89,91,93,95,97,
							99,101,103,105,107,109,111,113,115,117,
							119,121,123,125,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_sun = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_mon = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (2,3,6,7,10,11,14,15,18,19,22,23,26,27,30,31,34,35,
							38,39,42,43,46,47,50,51,54,55,58,59,62,63,66,67,
							70,71,74,75,78,79,82,83,86,87,90,91,94,95,98,99,
							102,103,106,107,110,111,114,115,118,119,122,123,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_mon = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_tue = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (4,5,6,7,12,13,14,15,20,21,22,23,28,29,30,31,36,37,38,
							39,44,45,46,47,52,53,54,55,60,61,62,63,68,69,70,71,
							76,77,78,79,84,85,86,87,92,93,94,95,100,101,102,103,
							108,109,110,111,116,117,118,119,124,125,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_tue = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_wed = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (8,9,10,11,12,13,14,15,24,25,26,27,28,29,30,31,40,41,42,43,
							44,45,46,47,56,57,58,59,60,61,62,63,72,73,74,75,76,77,78,
							79,88,89,90,91,92,93,94,95,104,105,106,107,108,109,110,111,
							120,121,122,123,124,125,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_wed = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_thur = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,48,49,50,
							51,52,53,54,55,56,57,58,59,60,61,62,63,80,81,82,83,84,85,
							86,87,88,89,90,91,92,93,94,95,112,113,114,115,116,117,118,
							119,120,121,122,123,124,125,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_thur = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_fri = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,
							50,51,52,53,54,55,56,57,58,59,60,61,62,63,96,97,98,99,
							100,101,102,103,104,105,106,107,108,109,110,111,112,113,
							114,115,116,117,118,119,120,121,122,123,124,125,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_fri = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


Select @save_start_sat = '          '
If @cu13freq_type = 4
 or ((@cu13freq_type = 8) and (@cu13freq_interval in (64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,
							83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,
							101,102,103,104,105,106,107,108,109,110,111,112,113,114,
							115,116,117,118,119,120,121,122,123,124,125,126,127)))
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_sat = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2

   end


If @save_start_sun = ' '
   begin
	Select @save_start_sun = 'n/a'
   end
If @save_start_mon = ' '
   begin
	Select @save_start_mon = 'n/a'
   end
If @save_start_tue = ' '
   begin
	Select @save_start_tue = 'n/a'
   end
If @save_start_wed = ' '
   begin
	Select @save_start_wed = 'n/a'
   end
If @save_start_thur = ' '
   begin
	Select @save_start_thur = 'n/a'
   end
If @save_start_fri = ' '
   begin
	Select @save_start_fri = 'n/a'
   end
If @save_start_sat = ' '
   begin
	Select @save_start_sat = 'n/a'
   end


Print ' '
Select @miscprint = '   Schedule: ' + @cu13name
Print  @miscprint
Select @miscprint = '   Sun       Mon       Tue       Wed       Thur      Fri       Sat'
Print  @miscprint
Select @miscprint = '   ' + @save_start_sun + @save_start_mon + @save_start_tue + @save_start_wed + @save_start_thur + @save_start_fri + @save_start_sat
Print  @miscprint


If @cu13freq_subday_type in (4, 8)
   begin
	Select @starttime  = str(@cu13active_start_time, 6)
	Select @starthour1  = substring(@starttime, 1, 1)
	Select @starthour2  = substring(@starttime, 2, 1)
	Select @startmin1   = substring(@starttime, 3, 1)
	Select @startmin2   = substring(@starttime, 4, 1)
		If @starthour1= ' '
		   begin
			select @starthour1 = '0'
		   end
		If @starthour2= ' '
		   begin
			select @starthour2 = '0'
		   end
		If @startmin1 = ' '
		   begin
			select @startmin1 = '0'
		   end
		If @startmin2 = ' '
		   begin
			select @startmin2 = '0'
		   end
		Select @save_start_time = @starthour1 + @starthour2 + ':' + @startmin1 + @startmin2


	Select @endtime  = str(@cu13active_end_time, 6)
	Select @endhour1  = substring(@endtime, 1, 1)
	Select @endhour2  = substring(@endtime, 2, 1)
	Select @endmin1   = substring(@endtime, 3, 1)
	Select @endmin2   = substring(@endtime, 4, 1)
		If @endhour1= ' '
		   begin
			select @endhour1 = '0'
		   end
		If @endhour2= ' '
		   begin
			select @endhour2 = '0'
		   end
		If @endmin1 = ' '
		   begin
			select @endmin1 = '0'
		   end
		If @endmin2 = ' '
		   begin
			select @endmin2 = '0'
		   end
		Select @save_end_time = @endhour1 + @endhour2 + ':' + @endmin1 + @endmin2


	If @cu13freq_subday_type = 4
	   begin
		Select @miscprint  = '    ###-executed every ' + (convert(varchar(5), @cu13freq_subday_interval)) + ' minutes from ' + @save_start_time + ' to ' + @save_end_time
		Print  @miscprint
          end
	Else
	   begin
		Select @miscprint  = '    ###-executed every ' + (convert(varchar(5), @cu13freq_subday_interval)) + ' hour(s) from ' + @save_start_time + ' to ' + @save_end_time
		Print  @miscprint
          end
   end


label02:


 End  -- sched loop
DEALLOCATE cursor_sched


If @sched_flag = 'n'
   begin
	Print ' '
	Select @miscprint = '   Note: This job is not currently scheduled!'
	Print  @miscprint
   end


Select @output_flag	= 'y'


--  Finalization  ------------------------------------------------------------------------------


drop table #temp_duration


 End  -- job loop
DEALLOCATE cursor_jobs


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_REPORTjobs] TO [public]
GO
