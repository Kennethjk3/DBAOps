SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Shares_Standard]


/*********************************************************
 **  Stored Procedure dbasp_HC_Shares_Standard
 **  Written by Steve Ledridge, Virtuoso
 **  January 07, 2015
 **  This procedure runs the Shares_Standard portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/07/2015	Steve Ledridge		New process.
--	03/11/2015	Steve Ledridge		Large file max set to 3gb.
--	======================================================================================



DECLARE	 @miscprint			nvarchar(2000)
	,@save_test			nvarchar(4000)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Insatll Config'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '

DECLARE @ShareName SYSNAME
DECLARE @SharePath VarChar(max)

DECLARE ShareCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		StandardShares.ShareName
			,CurentShares.SharePath
FROM		(
			SELECT		'BulkDataLoad'	[ShareName]	UNION
			SELECT		'SSIS'				UNION
			SELECT		'FileDrop'			UNION
			SELECT		'ImageUpload'		UNION
			SELECT		'Intellidon'		UNION
			SELECT		'DBASQL'			UNION
			SELECT		'DBA_Archive'		UNION
			SELECT		'SQLServerAgent'	UNION
			SELECT		'SQLBackups'		
			) StandardShares
LEFT JOIN	DBAOps.dbo.dbaudf_ListShares() CurentShares		ON StandardShares.ShareName = CurentShares.ShareName
 
OPEN ShareCursor;
FETCH ShareCursor INTO @ShareName,@SharePath
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
	
		IF @SharePath IS NULL
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('Share_Standard', @ShareName, 'Fail', 'High', '', null, 'The standard backup share does not exist', null, getdate())
		   END
		ELSE
		   BEGIN
			insert into [dbo].[HealthCheckLog] values ('Share_Standard', @ShareName, 'Pass', 'High', @SharePath, null, null, null, getdate())

			-- CHECK FOR LAREGE FILES
			Select @save_test = 'SELECT * FROM DBAOps.dbo.dbaudf_DirectoryList2(''' + @SharePath + ''', null, 1) where size > 3072000000'
			if exists (SELECT 1 FROM DBAOps.dbo.dbaudf_DirectoryList2(@SharePath, null, 1) where size > 3072000000) --3GB
			   begin
				insert into [dbo].[HealthCheckLog] values ('Share_Standard', @ShareName + '_largefiles', 'Fail', 'Medium', @save_test, null, 'A large file (3gb+) exists in the SQLjob_logs share', null, getdate())
			   end
		   END

		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM ShareCursor INTO @ShareName,@SharePath
END
CLOSE ShareCursor;
DEALLOCATE ShareCursor;




--  Finalization  ------------------------------------------------------------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Shares_Standard] TO [public]
GO
