SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AG_ManageJobs]
AS

--/*********************************************************
-- **  Stored Procedure dbasp_AG_ManageJobs
-- **  Written by Steve Ledridge, Virtuoso
-- **  April 21, 2016
-- **
-- **  This dbasp will Propagate AvailGrp related job info to all nodes.
-- **
-- ***************************************************************/
SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	04/21/2016	Steve Ledridge		New process.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================

DECLARE
	@cmd					Varchar(8000)
	,@productversion		sysname
	,@AGName				sysname
	,@AGrole				sysname
	,@AGrole_old			sysname
	,@nodename				sysname
	,@jobname				sysname
	,@JobEnabled			sysname
	,@dynSql				Varchar(8000)
	,@miscprint				Varchar(8000)

--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL AvailGrps Manage Jobs Process'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Check for availgrps - if none, exit
IF @@microsoftversion / 0x01000000 >= 11
  AND SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	IF NOT EXISTS (SELECT * FROM sys.availability_groups_cluster)
	   BEGIN
		RAISERROR('No Availability Groups found.',-1,-1) WITH NOWAIT
		RETURN
	   END
   END


DECLARE AGCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT name FROM sys.availability_groups_cluster 

OPEN AGCursor;
FETCH AGCursor INTO @AGName;
WHILE (@@FETCH_STATUS <> -1)
BEGIN
	IF (@@FETCH_STATUS <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP

		EXEC DBAOps.dbo.[dbasp_AG_UpdateJobs] @AGName


		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM AGCursor INTO @AGName;
END
CLOSE AGCursor;
DEALLOCATE AGCursor;


GO
GO
GO
GO
GO
GO
GRANT EXECUTE ON  [dbo].[dbasp_AG_ManageJobs] TO [public]
GO
