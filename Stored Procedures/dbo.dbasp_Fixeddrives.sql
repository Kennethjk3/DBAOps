SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Fixeddrives]
			(
			@RootFolder			sysname		= NULL
			,@New_PercentFullOverride	sysname		= NULL
			)
/*********************************************************
 **  Stored Procedure dbasp_Fixeddrives
 **  Written by Steve Ledridge, Virtuoso
 **  August 25, 2014
 **
 **  This procedure is a replacement for xp_fixeddrives
 **  (which does not take mount oints into account.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/25/2008	Steve Ledridge		New process
--	09/05/2014	Steve Ledridge		Modified query to resolve Registry Value Joining problem.
--	01/21/2016	Steve Ledridge		Added ability to add override values to the registry
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd 				nvarchar(4000)
----------------  initial values  -------------------
DECLARE @Results TABLE
                 (
                    Value   NVARCHAR (100),
                    Data    NVARCHAR (100)
                 )


-- THIS MAKES SURE THAT THE Software\Virtuoso\Script\DiskMonitor BRANCH EXISTS
EXEC[sys].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor','XX','reg_sz','0'
EXEC[sys].[xp_instance_regdeletevalue] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor','XX'


IF EXISTS (SELECT 1 FROM DBAOps.dbo.dbaudf_ListDrives() WHERE RootFolder = @RootFolder)
BEGIN
	-- SET NEW OVERRIDE VALUE
	IF @New_PercentFullOverride IS NOT NULL
		EXEC[sys].[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor',@RootFolder,'reg_sz',@New_PercentFullOverride
	ELSE
		EXEC[sys].[xp_instance_regdeletevalue] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor',@RootFolder


	RETURN 0
END


-- GET DISK ALERT OVERRIDES AT Software\Virtuoso\Script\DiskMonitor
INSERT INTO @Results
EXEC [sys].[xp_instance_regenumvalues] N'HKEY_LOCAL_MACHINE',N'Software\Virtuoso\Script\DiskMonitor'


-- MAIN QUERY
SELECT		COALESCE(DriveLetter, LEFT(RootFolder,2)) DriveLetter
		,RootFolder
		,VolumeName
		,CASE	WHEN T2.Data = 0 THEN 0
			WHEN PercentUsed >= COALESCE (T2.Data, 90) THEN 1
			ELSE 0
			END [Alert]
		,DBAOps.dbo.dbaudf_FormatBytes(TotalSize,'Bytes') TotalSize
		,DBAOps.dbo.dbaudf_FormatBytes(TotalSize-FreeSpace,'Bytes') UsedSpace
		,DBAOps.dbo.dbaudf_FormatBytes(FreeSpace,'Bytes') FreeSpace
		,CAST(PercentUsed AS NUMERIC(10,2)) PercentUsed
		,REPLACE(REPLACE(UseChart,NCHAR(9633),NCHAR(9617)),NCHAR(9632),NCHAR(9608))	[CurrentUseChart]
		,T2.Data PercentFullOverride
		,DriveType
		,FileSystem
		,IsReady
FROM		DBAOps.dbo.dbaudf_ListDrives() T1
LEFT JOIN	@Results T2
	ON	CASE	WHEN LEN(T2.Value) = 1 THEN T2.Value+':\'
			WHEN LEN(T2.Value) = 2 THEN T2.Value+'\'
			ELSE T2.Value END = T1.RootFolder
       AND	isnumeric(T2.Data) = 1	-- Try to exclude other registry entries that are not simply the override value
order by	RootFolder


-------------------   end   -------------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_Fixeddrives] TO [public]
GO
