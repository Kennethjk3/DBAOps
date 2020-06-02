SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[CheckConfigurationCompliance] @ProvisionModelName varchar(32), @ShowOnlyNoncompliant bit = 0, @AlertParamsOnly bit = 0


AS


-- Declare local vars
DECLARE @ProvisionModelID int,
        @CpuCount         smallint,
		@TempDBFileCount  smallint,
		@FoundSetting     varchar(256)


---------------------------------------------------------------------------
-- Clear last Compliance Check
DELETE  dbo.ParameterCheck


---------------------------------------------------------------------------
-- Lookup ProvisionModelName to get ProvisionModelId
---------------------------------------------------------------------------
SELECT @ProvisionModelID = ProvisionModelID
FROM  dbo.ProvisionModel
WHERE ProvisionModelName = @ProvisionModelName


---------------------------------------------------------------------------
-- Gather settings info
---------------------------------------------------------------------------
-- Get Server level configuration info
SELECT  *
INTO #sysconfigurations
FROM    sys.configurations
ORDER BY name


---------------------------------------------------------------------------
-- Get most of the DB settings (most settings for DB's are in sys.databases)
SELECT *
INTO #sysdatabases
FROM sys.Databases


---------------------------------------------------------------------------
-- Get logical CPU Count
---------------------------------------------------------------------------
SELECT @CpuCount = cpu_count
FROM sys.dm_os_sys_info


-- Perform Server level compliance checks using sys.configurations.
---------------------------------------------------------------------------
INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
                                ModelParameterID,
                                PreferredSetting,
                                ActualSetting,
                                DatabaseName,
                                IsSettingCompliant)
SELECT @ProvisionModelID,
       mp.ModelParameterID,
       mp.PreferredSetting,
	   CONVERT(varchar(256),sc.[value_in_use]) AS ActualSetting,
	   'N/A', -- Database name not used at server settings level
	   CASE
	      WHEN mp.PreferredSetting = CONVERT(varchar(256),sc.[value_in_use]) THEN 1
		  ELSE 0
       END AS IsSettingCompliant
FROM  dbo.ModelParameter mp
JOIN #sysconfigurations sc ON mp.ParameterName = sc.name
WHERE mp.ProvisionModelID = @ProvisionModelID
  AND mp.ParameterScope = 'SQL Server Instance'


---------------------------------------------------------------------------
-- Perform Database level compliance checks using sys.databases.
---------------------------------------------------------------------------
INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
                                ModelParameterID,
                                PreferredSetting,
                                ActualSetting,
                                DatabaseName,
                                IsSettingCompliant)
SELECT @ProvisionModelID,
       mp.ModelParameterID,
       mp.PreferredSetting,
	   -- CASE statement to flip DB Settings as needed
	   CASE
	      WHEN mp.ParameterName = 'auto update statistics'       THEN sd.is_auto_create_stats_on
	      WHEN mp.ParameterName = 'auto update statistics async' THEN sd.is_auto_update_stats_async_on
	      WHEN mp.ParameterName = 'auto create statistics'       THEN sd.is_auto_create_stats_on
	      WHEN mp.ParameterName = 'allow snapshot isolation'     THEN sd.snapshot_isolation_state
	      WHEN mp.ParameterName = 'read committed snapshot'      THEN sd.is_read_committed_snapshot_on
       END AS ActualSetting,
	   sd.name AS DatabaseName, -- Database name not used at server settings level
	   0 AS IsSettingCompliant
FROM  dbo.ModelParameter mp
OUTER APPLY (SELECT * FROM  #sysdatabases sd) sd
WHERE mp.ProvisionModelID = @ProvisionModelID
  AND mp.ParameterScope = 'SQL Server Database'
  AND sd.database_id > 4


UPDATE  dbo.ParameterCheck
SET IsSettingCompliant = 1
WHERE PreferredSetting = ActualSetting


---------------------------------------------------------------------------
-- Get Database File Information and perform file checks
---------------------------------------------------------------------------
-- Drop temporary table if it exists
DROP TABLE IF EXISTS #info;


---------------------------------------------------------------------------
-- Create table to house database file information
CREATE TABLE #info (
     databasename VARCHAR(128)
     ,name VARCHAR(128)
    ,fileid INT
    ,filename VARCHAR(1000)
    ,filegroup VARCHAR(128)
    ,SizeInKB VARCHAR(25)
    ,SizeInMB VARCHAR(25)
    ,SizeInGB VARCHAR(25)
    ,maxsize VARCHAR(25)
    ,growth VARCHAR(25)
    ,usage VARCHAR(25));

---------------------------------------------------------------------------
-- Get database file information for each database
SET NOCOUNT ON;
INSERT INTO #info
EXEC sp_MSforeachdb 'use [?]
select ''[?]'',name,  fileid, filename,
filegroup = filegroup_name(groupid),
''SizeInKB'' = convert(nvarchar(15), convert (bigint, size) * 8) ,
''SizeInMB'' = convert(nvarchar(15), convert (bigint, size) * 8)/1024 ,
''SizeInGB'' = convert(nvarchar(15), convert (bigint, size) * 8)/(1024*1024),
''maxsize'' = (case maxsize when -1 then N''Unlimited''
               else
convert(nvarchar(15), convert (bigint, maxsize) * 8) + N'' KB'' end),
''growth'' = (case status & 0x100000 when 0x100000 then
convert(nvarchar(15), growth) + N''%''
else
convert(nvarchar(15), convert (bigint, growth/1024) * 8) + N'' MB'' end),
''usage'' = (case status & 0x40 when 0x40 then ''LogFile'' else ''DataFile'' end)
from sysfiles
';

---------------------------------------------------------------------------
-- Debug check File Volume info
/*
SELECT * FROM #info
ORDER BY databasename
*/
---------------------------------------------------------------------------
-- Check system CPU Count against TempDB file count


UPDATE ModelParameter
SET PreferredSetting = @CpuCount
WHERE ParameterName = 'TempDB file count matches CPU count'


SELECT @TempDBFileCount = COUNT(*)
FROM #info
WHERE databasename = '[tempdb]'
  AND usage = 'DataFile'


INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
                                ModelParameterID,
                                PreferredSetting,
                                ActualSetting,
                                DatabaseName,
                                IsSettingCompliant)
SELECT @ProvisionModelID,
       mp.ModelParameterID,
       mp.PreferredSetting,
	   CONVERT(varchar(256),@TempDBFileCount) AS ActualSetting,
	   'TempDB', -- Database name
	   CASE
	      WHEN mp.PreferredSetting = CONVERT(varchar(256),@TempDBFileCount) THEN 1
		  ELSE 0
       END AS IsSettingCompliant
FROM  dbo.ModelParameter mp
WHERE mp.ProvisionModelID = @ProvisionModelID
  AND mp.ParameterName = 'TempDB file count matches CPU count'


---------------------------------------------------------------------------
-- Auto-Growth Settings as 256MB for data and 128MB for Log <<TODO>>
--INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
--                                ModelParameterID,
--                                PreferredSetting,
--                                ActualSetting,
--                                DatabaseName,
--                                IsSettingCompliant)
--SELECT @ProvisionModelID,
--       mp.ModelParameterID,
--       mp.PreferredSetting,
--	   CONVERT(varchar(256),@TempDBFileCount) AS ActualSetting,
--	   'TempDB', -- Database name
--	   CASE
--	      WHEN mp.PreferredSetting = CONVERT(varchar(256),@TempDBFileCount) THEN 1
--		  ELSE 0
--       END AS IsSettingCompliant
--FROM  dbo.ModelParameter mp
--WHERE mp.ProvisionModelID = @ProvisionModelID
--  AND mp.ParameterName = 'TempDB file count matches CPU count'


--'Data [Auto-Growth=256MB]: <Logical_Filename>'


---------------------------------------------------------------------------
-- Sizing for disk block/clusters


-- Determine which volumes SQL Server is using for Data
SELECT DISTINCT(LEFT(filename,3)) DriveLetter
INTO #SQLServerDvrLetter
FROM #info


-- Get block allocations per Drive Letter
--DROP TABLE #DrvLetter
CREATE TABLE #DrvLetter (rowid int identity(1,1) primary key,Result varchar(500))


INSERT INTO #DrvLetter
EXEC xp_cmdshell 'powershell.exe -noprofile -command "gwmi -Class win32_volume | ft Name, Blocksize -a"'


SELECT LEFT(dl.Result,3) AS DriveLetter,
       LTRIM(RTRIM(SUBSTRING(dl.Result,4,1024))) AS Blocksize
INTO #OSDriveLetter
FROM #DrvLetter dl
WHERE Result IS NOT NULL
  AND Result NOT LIKE '\\%'
  AND Result NOT LIKE 'Name%'
  AND Result NOT LIKE '----%'


-- Combine found drive letters to check OS drive cluster sizing and do parameter check


INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
                                ModelParameterID,
                                PreferredSetting,
                                ActualSetting,
                                DatabaseName,
                                IsSettingCompliant)
SELECT @ProvisionModelID,
       mp.ModelParameterID,
       mp.PreferredSetting,
	   CONVERT(varchar(256),drivecheck.Blocksize) AS ActualSetting,
	   drivecheck.DriveLetter, -- Database name
	   CASE
	      WHEN (mp.PreferredSetting = drivecheck.Blocksize) THEN 1                                    -- If Cluster is 64K we are alright
		  WHEN (mp.PreferredSetting < drivecheck.Blocksize AND drivecheck.Blocksize%65536= 0 ) THEN 1 -- If cluster increment of 64K we are alright as well
		  ELSE 0
       END AS IsSettingCompliant
FROM  dbo.ModelParameter mp
OUTER APPLY (SELECT osdl.DriveLetter,
                    osdl.Blocksize
            FROM #OSDriveLetter      osdl
            JOIN #SQLServerDvrLetter ssdl on osdl.DriveLetter = ssdl.DriveLetter) drivecheck
WHERE mp.ProvisionModelID = @ProvisionModelID
  AND mp.ParameterName = 'File Volume Cluster Size'


---------------------------------------------------------------------------
-- get rid of temp table for file configurations
DROP TABLE IF EXISTS #info;


---------------------------------------------------------------------------
-- Check if Instant File Initialization is on (SQL Server 2008 and up)


-- Drop temporary table if it exists
DROP TABLE IF EXISTS #PrivList


CREATE TABLE #PrivList (textoutput varchar(256))


-- Get privs list for SQL Service account
INSERT INTO #PrivList (textoutput)
exec xp_cmdshell 'whoami /priv'


-- Check if the SeManageVolumePrivileg (Perform Volume Maintenance Tasks) has been granted to Service Account
IF EXISTS(SELECT 1 FROM #PrivLIst where textoutput like 'SeManageVolumePrivileg%')
BEGIN
   SELECT @FoundSetting = 'Enabled'
END
ELSE
BEGIN
   SELECT @FoundSetting = 'Disabled'
END


INSERT INTO  dbo.ParameterCheck (ProvisionModelID,
                                ModelParameterID,
                                PreferredSetting,
                                ActualSetting,
                                DatabaseName,
                                IsSettingCompliant)
SELECT @ProvisionModelID,
       mp.ModelParameterID,
       mp.PreferredSetting,
	   CONVERT(varchar(256),@TempDBFileCount) AS ActualSetting,
	   'N/A', -- Database name
	   CASE
	      WHEN mp.PreferredSetting = @FoundSetting THEN 1
		  ELSE 0
       END AS IsSettingCompliant
FROM  dbo.ModelParameter mp
WHERE mp.ProvisionModelID = @ProvisionModelID
  AND mp.ParameterName = 'Instant File Initialization privilege'


---------------------------------------------------------------------------
-- Return results of this compliance check
---------------------------------------------------------------------------
SELECT pm.ProvisionModelName,
       mp.ParameterName,
	   mp.ParameterScope,
	   CASE
	     WHEN mp.IsPerDatabase = 1 THEN DatabaseName
		 ELSE ISNULL(DatabaseName,'N/A')
       END AS DatabaseOrVolumeName,
	   mp.PreferredSetting,
	   pc.ActualSetting,
	   CASE pc.IsSettingCompliant
	      WHEN 1 THEN 'Yes' ELSE 'No'
	   END AS [InCompliance],
	   CASE pc.IsSettingCompliant
	      WHEN 1 THEN '' ELSE mp.CorrectiveAction
	   END AS [CorrectiveAction]
FROM  dbo.ParameterCheck pc
JOIN  dbo.ProvisionModel pm ON pc.ProvisionModelID = pm.ProvisionModelID
JOIN  dbo.ModelParameter mp ON pc.ModelParameterID = mp.ModelParameterID
WHERE 1=1
    AND mp.ProvisionModelID = @ProvisionModelID
    AND ((@ShowOnlyNoncompliant = 0) OR (@ShowOnlyNoncompliant = 1 AND pc.IsSettingCompliant=0))
	AND ((@AlertParamsOnly = 0)      OR (@AlertParamsOnly = 1      AND mp.IsAlertOnNonCompliance = 1))
ORDER BY InCompliance,ParameterScope, ParameterName
GO
GRANT EXECUTE ON  [dbo].[CheckConfigurationCompliance] TO [public]
GO
