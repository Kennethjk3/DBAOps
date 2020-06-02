SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Jobstate]
   @job_name	sysname		= NULL
  ,@job_status	varchar(10)	OUTPUT


/*********************************************************
 **  Stored Procedure dbasp_Check_Jobstate
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  March 9, 2001
 **
 **  This dbasp is set up to check the job status of a
 **  specific job.  The intended use of this proc is to
 **  check to see if maintenance jobs are running prior to
 **  running a transaction log backup.
 **
 **  Syntax to run this proc is:
 **  declare @status varchar(10)
 **  exec DBAOps..dbasp_Check_Jobstate "job name here...", @status output
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	05/30/2006	Steve Ledridge		Updated for SQL 2005.
--	01/11/2013	Steve Ledridge		Modified to return(1) on Job not existing.
--	======================================================================================


/**
declare @job_name	sysname
declare @job_status	varchar(10)


select @job_name = 'UTIL - DBA Archive process'
select @job_status = null
--**/


DECLARE
	 @is_sysadmin		INT
	,@retval			INT
	,@job_owner			sysname
	,@job_id			UNIQUEIDENTIFIER
	,@job_status_num	tinyint


-- Initialize and clean-up variables
SELECT @job_name		= LTRIM(RTRIM(@job_name))
SELECT @job_id 			= NULL


-- Check for job name
if not exists(SELECT name FROM msdb.dbo.sysjobs where name = @job_name) OR (@job_name = N'') or (@job_name IS null)
   BEGIN
	--Print '-- Failure'
	RETURN(1) -- Failure
   END


EXECUTE @retval = msdb.dbo.sp_verify_job_identifiers '@job_name',
                                                '@job_id',
                                                 @job_name OUTPUT,
                                                 @job_id   OUTPUT
IF (@retval <> 0)
   BEGIN
	--Print '-- Failure'
	RETURN(1) -- Failure
   END


-- Step 1: Create intermediate work tables
CREATE TABLE #xp_results (job_id                UNIQUEIDENTIFIER NOT NULL,
                          last_run_date         INT              NOT NULL,
                          last_run_time         INT              NOT NULL,
                          next_run_date         INT              NOT NULL,
                          next_run_time         INT              NOT NULL,
                          next_run_schedule_id  INT              NOT NULL,
                          requested_to_run      INT              NOT NULL, -- BOOL
                          request_source        INT              NOT NULL,
                          request_source_id     sysname          NULL,
                          running               INT              NOT NULL, -- BOOL
                          current_step          INT              NOT NULL,
                          current_retry_attempt INT              NOT NULL,
                          job_state             INT              NOT NULL)


-- Step 2: Capture job execution information (for local jobs only since that's all SQLServerAgent caches)
SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
SELECT @job_owner = SUSER_SNAME()

INSERT INTO #xp_results
   EXECUTE master.sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner


select @job_status_num = (select job_state from #xp_results where job_id = @job_id)


DROP TABLE #xp_results


IF @job_status_num = 4
   begin
	select @job_status = 'idle'
   end
ELSE
   begin
	select @job_status = 'active'
   end


RETURN(0)
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Jobstate] TO [public]
GO
