SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Estimate_Diff_Size] (@DBname sysname = null
						,@diffPrediction int OUTPUT)


/*********************************************************
 **  Stored Procedure dbasp_Estimate_Diff_Size
 **  Written by Steve Ledridge, Virtuoso
 **  August 13, 2013
 **
 **  This procedure is used for estimating the size of the next
 **  differential backup file (in MB).
 **
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/13/2013	Steve Ledridge		New process (borrowed from Darwin Hatheway and Doug Zuck)
--	03/032014	Steve Ledridge		Modified DBCC PAGE Call to use QUOTENAME(@DBname) to resolve dashes in @@DBName
--	======================================================================================


/***
-------------------------------------------------------
-- U N C O M M E N T   T O   T E S T   L O C A L L Y --
-------------------------------------------------------


DECLARE	 @DBName SYSNAME
	,@diffPrediction int


SELECT	@DBName = 'DBAOps'
	,@diffPrediction = null


-- ***/


DECLARE @currentFileID INT,
	@totalExtentsOfFile BIGINT,
	@SQL VARCHAR(200),
	@currentDCM BIGINT,
	@step INT,
	@cmd varchar(4000)


----------------  initial values  -------------------
SET @step = 511232


IF isNULL(object_id('tempdb.dbo.#showFileStats'), 1) <> 1
	DROP TABLE #showFileStats

CREATE TABLE #showFileStats (
	fileID INT,
	fileGroup INT,
	totalExtents BIGINT,
	usedExtents BIGINT,
	logicalFileName VARCHAR (500),
	filePath VARCHAR (1000)
)


IF isNULL(object_id('tempdb.dbo.#DCM'), 1) <> 1
	DROP TABLE #DCM

CREATE TABLE #DCM (
	parentObject VARCHAR(5000),
	[object] VARCHAR(5000),
	field VARCHAR (5000),
	value VARCHAR (5000)
)

/*we need to get a list of all the files in the database.  each file needs to be looked at*/
set @cmd = 'use ' + QUOTENAME(@DBname) + '; INSERT INTO #showFileStats EXEC(''DBCC SHOWFILESTATS with tableresults, NO_INFOMSGS'')'
exec ( @cmd )


DECLARE myCursor SCROLL CURSOR FOR
SELECT fileID, totalExtents
FROM #showFileStats


OPEN myCursor
FETCH NEXT FROM myCursor INTO @currentFileID, @totalExtentsOfFile


/*look at each differential change map page in each data file of the database and put the output into #DCM*/
WHILE @@FETCH_STATUS = 0
BEGIN


	SET @currentDCM = 6
	WHILE @currentDCM <= @totalExtentsOfFile*8
	BEGIN
		SET @SQL = 'dbcc page('+ QUOTENAME(@DBname) + ', ' + CAST(@currentFileID AS VARCHAR) + ', ' + CAST(@currentDCM AS VARCHAR) + ', 3) WITH TABLERESULTS, NO_INFOMSGS'
		INSERT INTO #DCM EXEC (@SQL)
		SET @currentDCM = @currentDCM + @step
	END

	FETCH NEXT FROM myCursor INTO @currentFileID, @totalExtentsOfFile
END
CLOSE myCursor
DEALLOCATE myCursor


/*remove all unneeded rows from our results table*/
DELETE FROM #DCM WHERE value = 'NOT CHANGED' OR parentObject NOT LIKE 'DIFF_MAP%'
--SELECT * FROM #DCM


/*sum the extentTally column*/
Select @diffPrediction = SUM(extentTally)/16
			FROM
				/*create extentTally column*/
				(SELECT extentTally =
				CASE
					WHEN secondChangedExtent > 0 THEN CAST(secondChangedExtent AS BIGINT) - CAST(firstChangedExtent AS BIGINT) + 1
					ELSE 1
				END
				FROM
					/*parse the 'field' column to give us the first and last extents of the range*/
					(SELECT (SUBSTRING(field,(SELECT CHARINDEX(':', field, 0))+1,(CHARINDEX(')', field, 0))-(CHARINDEX(':', field, 0))-1))/8 as firstChangedExtent,
					secondChangedExtent =
					CASE
						WHEN CHARINDEX(':', field, CHARINDEX(':', field, 0)+1) > 0 THEN (SUBSTRING(field,(CHARINDEX(':', field, CHARINDEX(':', field, 0)+1)+1),(CHARINDEX(')', field,CHARINDEX(')', field, 0)+1))-(CHARINDEX(':', field, CHARINDEX(':', field, 0)+1))-1))/8
						ELSE ''
					END
					FROM #DCM)parsedFieldColumn)extentTallyColumn


--  Finalization  -------------------------------------------------------------------
label99:


DROP TABLE #showFileStats
DROP TABLE #DCM


--Print convert(varchar(15), @diffPrediction)


RAISERROR('',-1,-1) WITH NOWAIT


/* Sample


declare @diffPrediction int


exec dbo.dbasp_Estimate_Diff_Size @DBName = 'dbname', @diffPrediction = @diffPrediction output


Print convert(nvarchar(12), @diffPrediction)


*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_Estimate_Diff_Size] TO [public]
GO
