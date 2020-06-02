SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AG_UpdateJobs] @AGname sysname = NULL
AS

--/*********************************************************
-- **  Stored Procedure dbasp_AG_UpdateJobs
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- **  April 21, 2016
-- **
-- **  This dbasp will Reset AvailGrp related jobs enabled status.
-- **
-- ***************************************************************/
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	04/21/2016	Steve Ledridge			New process.
--	01/20/2017	Steve Ledridge			Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================

DECLARE
	@cmd					Varchar(8000)
	,@productversion		sysname
	,@AGrole				sysname
	,@nodename				sysname
	,@jobname				sysname
	,@JobEnabled			sysname
	,@dynSql				Varchar(8000)


--  Check for availgrps - if none, exit
IF @@microsoftversion / 0x01000000 >= 11
  AND SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	IF NOT EXISTS (SELECT 1 FROM sys.availability_groups_cluster)
	   BEGIN
		RAISERROR('No Availability Groups found.',-1,-1) WITH NOWAIT
		RETURN
	   END
   END


-- MAKE SURE AG NAME IS CONFIGURED AS A JOB CATEGORY
SET @cmd = 'AG_' + @AGName
IF NOT EXISTS (SELECT * FROM msdb.dbo.syscategories WHERE name = @cmd)
	EXEC msdb.dbo.sp_add_category  @class=N'JOB',  @type=N'LOCAL',  @name=@cmd ;  

		
IF [dbo].[dbaudf_AG_Get_Primary](@AGName) = @@SERVERNAME -- ON PRIMARY SERVER
	RAISERROR('Running On PRIMARY %s: ENABELING Jobs.',-1,-1,@AGName) WITH NOWAIT
ELSE
	RAISERROR('Running On SECONDARY %s: DISABELING Jobs.',-1,-1,@AGName) WITH NOWAIT

DECLARE JobCursor CURSOR
FOR
SELECT		j.name
			,CASE	WHEN c.name = 'OPERATIONS UTILITY'		AND CHARINDEX('<DISABLED>',j.description) = 0		AND LEFT(j.name,2) != '--'		THEN 1
					WHEN c.name = 'OPERATIONS UTILITY'		AND CHARINDEX('<DISABLED>',j.description) > 0										THEN 0 -- HAS '<DISABLED>' KEYWORD IN DESCRIPTION
					WHEN c.name = 'OPERATIONS UTILITY'		AND LEFT(j.name,2) = '--'															THEN 0 -- JOB NAME STARTS WITH '--'

					WHEN c.name = 'Database Maintenance'	AND CHARINDEX('<DISABLED>',j.description) = 0		AND LEFT(j.name,2) != '--'		THEN 1
					WHEN c.name = 'Database Maintenance'	AND CHARINDEX('<DISABLED>',j.description) > 0										THEN 0 -- HAS '<DISABLED>' KEYWORD IN DESCRIPTION
					WHEN c.name = 'Database Maintenance'	AND LEFT(j.name,2) = '--'															THEN 0 -- JOB NAME STARTS WITH '--'

					WHEN c.name = 'AG_' + @AGname			AND CHARINDEX('<DISABLED>',j.description) = 0		AND LEFT(j.name,2) != '--'		THEN CASE WHEN [DBAOps].[dbo].[dbaudf_AG_Get_Primary](@AGName) = @@SERVERNAME THEN 1 ELSE 0 END
					WHEN c.name = 'AG_' + @AGname			AND CHARINDEX('<DISABLED>',j.description) > 0										THEN 0 -- HAS '<DISABLED>' KEYWORD IN DESCRIPTION
					WHEN c.name = 'AG_' + @AGname			AND LEFT(j.name,2) = '--'															THEN 0 -- JOB NAME STARTS WITH '--'
					ELSE 0 END
FROM		msdb.dbo.sysjobs j 
JOIN		msdb.dbo.syscategories c ON c.category_id = j.category_id
WHERE		c.name = 'AG_' + @AGname
		OR	c.name = 'OPERATIONS UTILITY'
		OR	c.name = 'Database Maintenance'

OPEN JobCursor;
FETCH JobCursor INTO @JobName,@JobEnabled;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
	
		SELECT		@dynSql = N'exec msdb.dbo.sp_update_job @job_name = ''' + @JobName + N''', @enabled = '+ @JobEnabled +';'

		EXEC DBAOps.dbo.dbasp_PrintLarge @dynSql
		EXEC (@dynSql)

		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM JobCursor INTO @JobName,@JobEnabled;
END
CLOSE JobCursor;
DEALLOCATE JobCursor;



GO
GRANT EXECUTE ON  [dbo].[dbasp_AG_UpdateJobs] TO [public]
GO
