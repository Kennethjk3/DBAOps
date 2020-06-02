SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FixJobOutput]


/***************************************************************
 **  Stored Procedure dbasp_FixJobOutput
 **  Written by Steve Ledridge, Virtuoso
 **  December 27, 2005
 **
 **  This dbasp is set up to;
 **
 **  Change job output path from c:\ to the sqljob_logs share.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==================================================
--	12/27/2005	Steve Ledridge		New process.
--	02/15/2006	Steve Ledridge		Modified fro sql2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(4000)
	,@parm01		varchar(100)
	,@outpath 		varchar(255)
	,@new_filename		nvarchar(500)
	,@save_filename		nvarchar(500)
	,@save_job_id		uniqueidentifier
	,@save_step_id		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@charpos		int
	,@error_count		int


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @error_count = 0


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Verify the sqljob_logs shares and get the path
Select @parm01 = @save_servername2 + '_SQLjob_logs'
exec DBAOps.dbo.dbasp_get_share_path @parm01, @outpath output


If @outpath is null or @outpath = ''
   begin
	Print 'Warning:  The standard share to the ''sqljob_logs'' folder has not been defined.'
	Select @error_count = @error_count + 1
	Goto label99
   end


--  Create table variable
declare @tblv_filename table	(
				 job_id			uniqueidentifier
				,step_id		int
				,output_file_name	sysname
				)


/****************************************************************
 *                MainLine
 ***************************************************************/


Insert into @tblv_filename (job_id, step_id, output_file_name)
select job_id, step_id, output_file_name from msdb.dbo.sysjobsteps
where output_file_name like 'c:\%'


--select * from @tblv_filename


start_filename_process:


Select @save_job_id = (select top 1 job_id from @tblv_filename)
Select @save_step_id = (select top 1 step_id from @tblv_filename where job_id = @save_job_id)
Select @save_filename = (select output_file_name from @tblv_filename where job_id = @save_job_id and step_id = @save_step_id)


select @new_filename = substring(@save_filename, 4, 500)


--  Make sure this is a file being written to the root of c:\.  If so, convert it to point to the sqljob_logs folder.
Select @charpos = charindex('\', @new_filename)
IF @charpos = 0
   begin
	select @new_filename = @outpath + '\' + @new_filename
	Print 'Update SQL job output file name from ' + @save_filename + ' to ' + @new_filename
	update msdb.dbo.sysjobsteps set output_file_name = @new_filename where job_id = @save_job_id and step_id = @save_step_id
   end


-- Check for more rows to process
Delete from @tblv_filename where job_id = @save_job_id and step_id = @save_step_id and output_file_name = @save_filename


If (select count(*) from @tblv_filename) > 0
   begin
	goto start_filename_process
   end


---------------------------  Finalization  -----------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_FixJobOutput] TO [public]
GO
