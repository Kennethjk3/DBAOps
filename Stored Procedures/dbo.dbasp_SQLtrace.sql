SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SQLtrace] (@outPath sysname = null
					,@trace_name sysname = 'UTILtrace'
					,@dbid int = null
					,@maxfilesize bigint = 200
					,@events varchar(512) = ''
					,@columns varchar(512) = ''
					,@adtnl_events varchar(512) = ''
					,@adtnl_columns varchar(512) = ''
					,@stoponly char(1) = 'n')

/***************************************************************
 **  Stored Procedure dbasp_SQLtrace
 **  Converted from unknown and various sources by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 11, 2008
 **
 **  This proc accepts the followinf input parms:
 **  @outPath       - Drive letter output path where the trace files are written to.
 **
 **  @trace_name    - Defaults to UTILtrace and is used as part of the output file name.
 **
 **  @dbid          - For when you want to trace on a single DB.
 **
 **  @maxfilesize   - Maximul file size before roll-over.
 **
 **  @events        - Default to '10,11,12,16,17,21,33,37,43,45,55,58,61,67,69,80,81,92,93,94,95'
 **
 **  @columns       - Default to '1,2,3,4,8,10,11,12,13,14,15,16,17,18,21,22,24,25,27,28,30,31'
 **
 **  @adtnl_events  - Events added to the default list.
 **
 **  @adtnl_columns - Columns added to the default list.
 **
 **  @stoponly      - Used to stop previous traces.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	04/30/2008	Steve Ledridge		New process
--	05/19/2008	Steve Ledridge		Added event 11 (RPC:Starting)
--	06/03/2008	Steve Ledridge		Fixed code with the backup share.
--	11/24/2009	Steve Ledridge		Fixed code for @outpath input parm usage.
--	03/05/2013	Steve Ledridge		Removed event 45 from default.
--	======================================================================================


/*
Declare @outPath sysname
Declare @trace_name sysname
Declare @dbid int
Declare @maxfilesize bigint
Declare @events varchar(512)
Declare @columns varchar(512)
Declare @adtnl_events varchar(512)
Declare @adtnl_columns varchar(512)
Declare @stoponly char(1)


Select @outPath = 'e:\'
--Select @outPath = 'e:\SQLTrace'
Select @trace_name = 'UTILtrace'
--Select @dbid = 6
Select @maxfilesize = 200
Select @events = ''
Select @columns = ''
Select @adtnl_events = ''
Select @adtnl_columns = ''
Select @stoponly = 'y'
--*/


declare
	 @miscprint	    nvarchar(500)
	,@date		    nvarchar(30)
	,@traceid	    int
	,@options	    int
	,@tracefile	    nvarchar (245)
	,@stoptime	    datetime
	,@minMBfree	    bigint
	,@rc		    int
	,@on		    bit
	,@cmd		    nvarchar(4000)
	,@cmd1		    nvarchar(512)
	,@event		    int
	,@column	    int
	,@estart	    int
	,@enext		    int
	,@cstart	    int
	,@cnext		    int
	,@le		    int
	,@lc		    int
	,@filter	    nvarchar(245)
	,@filter_num	    int
	,@save_servername   sysname
	,@save_servername2  sysname
	,@save_outpath	    sysname
	,@charpos	    int
	,@Result	    int
	,@fileexist_path    sysname
	,@old_traceID	    int
	,@old_file_name	    nvarchar(245)


----------------  initial values  -------------------
Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Create table #ShareTempTable(path nvarchar(500) null)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


--  Find or create the SQLTrace folder
Delete from #ShareTempTable
Select @cmd = 'RMTSHARE \\' + @save_servername
Insert into #ShareTempTable exec master.sys.xp_cmdshell @cmd
delete from #ShareTempTable where path is null or path = ''
delete from #ShareTempTable where path not like @save_servername2 + '_backup%'


--select * from #ShareTempTable


If (select count(*) from #ShareTempTable) = 0
   begin
	Select @miscprint = 'DBA ERROR: Backup share was not found.  Unable to create trace file output path.'
	Print  @miscprint
	goto label99
   end


Select @save_outpath = (Select top 1 path from #ShareTempTable where path like @save_servername2 + '_backup%')
Select @charpos = charindex(':\', @save_outpath)
IF @charpos <> 0
   begin
	Select @save_outpath = substring(@save_outpath, @charpos-1, 3)
   end
Else
   begin
	Select @miscprint = 'DBA ERROR: Backup share is not formatted correctly.  Unable to create trace file output path.'
	Print  @miscprint
	goto label99
   end


--  If input parm for @outPath is specified, use it
If @outPath is not null and @outPath like '%:\%'
   begin
	If reverse(@outPath) not like '\%'
	   begin
		Select @outPath = @outPath + '\'
	   end


	Select @save_outpath = @outPath
   end


Select @save_outpath = @save_outpath + 'SQLTrace'


--  check to see if the SQLTrace folder exists.  If not, create it.
Delete from #fileexists
Select @fileexist_path = @save_outpath + '\'
Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
If (select fileindir from #fileexists) <> 1
   begin
	Select @cmd = 'mkdir "' + @save_outpath + '"'
	Print 'Creating SQLTrace folder using command '+ @cmd
	EXEC @Result = master.sys.xp_cmdshell @cmd, no_output


	IF @Result <> 0
	   BEGIN
		PRINT 'DBA ERROR: FILE PATH ' + @save_outpath + ' COULD NOT BE CREATED'
		goto label99
	   end
   end


--  Set event and columns
If @events is null or @events = ''
   begin
	Select @events = '10,11,12,16,17,21,33,37,43,55,58,61,67,69,80,81,92,93,94,95'
  end


If @columns is null or @columns = ''
   begin
	select @columns = '1,2,3,4,8,10,11,12,13,14,15,16,17,18,21,22,24,25,27,28,30,31'
   end


If @adtnl_events is not null and @adtnl_events <> ''
   begin
	select @events = @events + ',' + @adtnl_events
	select @events = replace(@events, ',,', ',')
   end


If @adtnl_columns is not null and @adtnl_columns <> ''
   begin
	select @columns = @columns + ',' + @adtnl_columns
	select @columns = replace(@columns, ',,', ',')
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


-- Stop an old traces from this process if running
check_oldtrace:
If exists (Select * from :: fn_trace_getinfo(DEFAULT)
	    where property = 2	-- TRACE FILE NAME
	    and convert(sysname, value) like '%\'+ @trace_name +'%')
   begin
	Select @old_traceID = traceid, @old_file_name = convert(nvarchar(245), value)
	from :: fn_trace_getinfo(DEFAULT)
	where property = 2 -- TRACE FILE NAME
	and convert(sysname, value)like '%\'+ @trace_name +'%'


	Print 'Stopping trace ' + @old_file_name + '.  Trace number ' + convert(sysname, @old_traceID)


	EXEC @Result = sp_trace_setstatus @OLD_TRACEID, 0	-- STOPS SPECIFIED TRACE
	If @Result = 0  Print 'DBA Message: SP_TRACE_SETSTATUS: STOPPED TRACE ID ' + STR(@OLD_TRACEID )
	If @Result = 1  Print 'DBA ERROR: SP_TRACE_SETSTATUS: - UNKNOWN ERROR'
	If @Result = 8  Print 'DBA ERROR: SP_TRACE_SETSTATUS: THE SPECIFIED STATUS IS NOT VALID'
	If @Result = 9  Print 'DBA ERROR: SP_TRACE_SETSTATUS: THE SPECIFIED TRACE HANDLE IS NOT VALID'
	If @Result = 13 Print 'DBA ERROR: SP_TRACE_SETSTATUS: OUT OF MEMORY'
	If @Result <> 0 goto label99


	EXEC sp_trace_setstatus @OLD_TRACEID, 2 -- DELETE SPECIFIED TRACE


	If @Result = 0  Print 'DBA Message: SP_TRACE_SETSTATUS: DELETED TRACE ID ' + STR(@OLD_TRACEID)
	If @Result = 1  Print 'DBA ERROR: SP_TRACE_SETSTATUS: - UNKNOWN ERROR'
	If @Result = 8  Print 'DBA ERROR: SP_TRACE_SETSTATUS: THE SPECIFIED STATUS IS NOT VALID'
	If @Result = 9  Print 'DBA ERROR: SP_TRACE_SETSTATUS: THE SPECIFIED TRACE HANDLE IS NOT VALID'
	If @Result = 13 Print 'DBA ERROR: SP_TRACE_SETSTATUS: OUT OF MEMORY'
	If @Result <> 0 goto label99


	Waitfor delay '00:00:04'


	goto check_oldtrace
   end


If @stoponly = 'y'
   begin
	goto label99
   end


-- Build the trace file name (with date/time stamp)
Select @date = convert(sysname, getdate(), 120)
Select @date = replace(@date, '-', '')
Select @date = replace(@date, ':', '')
Select @date = replace(@date, ' ', '_')
Select @date = rtrim(@date)


Select @trace_name = @trace_name + '_' + @save_servername2 + '_' + @date + '_'


print @trace_name


select @tracefile = @save_outpath + '\' + @trace_name    --- Define Trace file Path
select @stoptime = (select dateadd(hh,2, getdate()))	--- Limits Trace to 2 Hour duration
select @options = 2


-- If trace is defined, start it
set @traceid = 0
select @traceid = traceid FROM :: fn_trace_getinfo(0) where property = 2 and value = @tracefile
if @traceid != 0 goto finish


--  Delete any files that could be named like this trace
set @cmd1 = 'if exist ' + @tracefile + '*.trc ' + 'del ' + @tracefile + '*.trc'
exec @rc = master.sys.xp_cmdshell @cmd1, no_output


--  create the trace
exec @rc = sp_trace_create @traceid output, @options, @tracefile, @maxfilesize, @stoptime


--Set Trace Definitions
select @estart = 1
select @enext = charindex(',',@events,@estart)
select @cstart = 1
select @cnext = charindex(',',@columns,@cstart)
set @le = len(@events)
set @lc = len(@columns)
set @on = 1


while @enext > 0
   begin
	select @event = cast(substring(@events,@estart,@enext-@estart) as int)
	while @cnext > 0
	   begin
		select @column = cast(substring(@columns,@cstart,@cnext-@cstart) as int)
		exec sp_trace_setevent @traceid, @event, @column, @on
		select @cstart = @cnext + 1
		select @cnext = charindex(',',@columns,@cstart)
		if @cnext = 0 set @cnext = @lc + 1
		if @cstart >@lc set @cnext = 0
	   end


	select @cstart = 1
	select @cnext = charindex(',',@columns,@cstart)
	select @estart = @enext + 1
	select @enext = charindex(',',@events,@estart)
	if @enext = 0 set @enext = @le + 1
	if @estart > @le set @enext = 0
   end


--  set database filter if requested
If @dbid is not null
   begin
	EXEC sp_trace_setfilter @traceid, 3, 1, 0, @dbid
   end


-- Define each Filter event
exec sp_trace_setfilter @traceid, 10, 0, 7, N'SQL Profiler'
exec sp_trace_setfilter @traceid, 10, 0, 7, N'SQLAgent%'
exec sp_trace_setfilter @traceid, 10, 0, 7, N'SQL Query%'
exec sp_trace_setfilter @traceid, 10, 0, 7, N'MS SQLEM%'


--  exclude system objects
exec sp_trace_setfilter @traceid, 22, 0, 4, 100


finish:


-- start the trace
exec sp_trace_setstatus @traceid, 1


----------------  End  -------------------


label99:
drop table #ShareTempTable
drop table #fileexists
GO
GRANT EXECUTE ON  [dbo].[dbasp_SQLtrace] TO [public]
GO
