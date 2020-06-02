SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Install_Services] @Verbose Int = 0

/*********************************************************
 **  Stored Procedure dbasp_HC_Install_Services
 **  Written by Steve Ledridge, Virtuoso
 **  November 13, 2014
 **  This procedure runs the Install_Services portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
AS
SET NOCOUNT ON
--	======================================================================================
--	Revision History
--	Date		Author     			Desc
--	==========	=================	=============================================
--	11/13/2014	Steve Ledridge		New process.
--	12/02/2014	Steve Ledridge		Change to MSSQLServerOLAPService and SQLWriter sections.
--	05/20/2015	Steve Ledridge		Change Cluster to ClusterName.
--  03/27/2019	Steve Ledridge		Rewrote Process to use new dbasp_GetServices Sproc
--	======================================================================================
--
--
---------------------------
--  Checks for this sproc
---------------------------
--verify service account and local admin permissions
--verify sql services set properly



DECLARE		@TextString					varchar(MAX)
			,@cmd						nvarchar(500)
			,@save_test					nvarchar(4000)
			,@ServiceActLogin			varchar(max) 
			,@SID						INT
			,@SName						VarChar(200)
			,@SAccount					VarChar(200)
			,@SMode						VarChar(200)
			,@SState					VarChar(200)
			,@Path						Varchar(8000)
			,@MSG						VarChar(max)

DECLARE		@Services					Table				([ID] INT,[ServiceName] VarChar(200),[ServiceAccount] VarChar(200),[StartMode] VarChar(200),[State] VarChar(200))

--DROP TABLE IF EXISTS #miscTempTable
--DROP TABLE IF EXISTS #showgrps

CREATE TABLE #miscTempTable	(cmdoutput NVARCHAR(400) NULL)
CREATE TABLE #showgrps		(cmdoutput NVARCHAR(255) NULL)

SELECT @TextString = convert(varchar(30),getdate())

-- DELETE TODAYS DATA SO THAT IT CAN BE REPLACED IF THIS IS RUN MULTIPLE TIMES IN A DAY
DELETE		[dbo].[HealthCheckLog]
WHERE		HCcat		= 'Install_Service'
	AND		Check_date	>= CAST(GETDATE() AS Date)


IF @Verbose > 0
BEGIN
	RAISERROR('',-1,-1) WITH NOWAIT
	RAISERROR('/********************************************************************',-1,-1) WITH NOWAIT
	RAISERROR('   RUN SQL Health Check - Install Services',-1,-1) WITH NOWAIT
	RAISERROR('',-1,-1) WITH NOWAIT
	RAISERROR('   %s ForServer %s',-1,-1,@TextString,@@SERVERNAME) WITH NOWAIT
	RAISERROR('********************************************************************/',-1,-1) WITH NOWAIT
	RAISERROR('',-1,-1) WITH NOWAIT
END

IF EXISTS	(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_StringToTable(DBAOps.dbo.dbaudf_GetEV('path'),';')
			WHERE		SplitValue = 'C:\Tools' OR SplitValue = 'C:\Tools\'
			)
	SET @Path = 'C:\Tools'
ELSE IF EXISTS	(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_StringToTable(DBAOps.dbo.dbaudf_GetEV('path'),';')
			WHERE		SplitValue = 'C:\DBAFiles' OR SplitValue = 'C:\DBAFiles\'
			)
	SET @Path = 'C:\DBAFiles'
ELSE
	SET @Path = 'C:\Windows\system32'


SET @CMD = 'xcopy \\SDCPROFS.virtuoso.com\CleanBackups\DBAOps\System32\accesschk*.exe '+@Path+' /c /q /y'
IF @Verbose > 0 RAISERROR(@CMD,-1,-1) WITH NOWAIT
exec xp_cmdshell @CMD,no_output 

--  Start check Service Logon Right setting
IF @Verbose > 0 RAISERROR('Start check Service Logon Right setting',-1,-1) WITH NOWAIT
IF @Verbose > 0 RAISERROR('',-1,-1) WITH NOWAIT

-- CALCULATE EXPECTED SERVICE ACCOUNT
IF @@ServerName Like 'SDT%'
BEGIN
	SELECT	@ServiceActLogin	= SUSER_NAME()
END
ELSE IF @@ServerName Like 'SDCPRO%' OR @@SERVERNAME LIKE 'SDCSTG%' OR @@SERVERNAME LIKE 'SDCSQLTOOLS' OR @@SERVERNAME LIKE 'FTWPRO%'
BEGIN
	SELECT	@ServiceActLogin	= 'virtuoso\sqlsvc'
END
ELSE
BEGIN
	SELECT	@ServiceActLogin	= 'virtuoso\_devsqlsvc'
END
IF @Verbose > 0 RAISERROR('Expected Service Account for %s should be %s',-1,-1,@@SERVERNAME,@ServiceActLogin) WITH NOWAIT

--  Start check sql services set properly
IF @Verbose > 0 RAISERROR('Checking SQL Services set properly...',-1,-1) WITH NOWAIT
IF @Verbose > 0 RAISERROR('',-1,-1) WITH NOWAIT

-- GET ALL SERVICES
IF @Verbose > 0 RAISERROR('  Getting Data for All Services...',-1,-1) WITH NOWAIT
INSERT INTO @Services
SELECT  *
FROM    OPENROWSET( 'SQLNCLI',
                    'Server=(local);Trusted_Connection=yes;',
                    'SET FMTONLY OFF; SET NOCOUNT ON; exec DBAOps.dbo.dbasp_GetServices'
                  )

SET @save_test = 'EXEC DBAOps.dbo.dbasp_GetServices'

DECLARE ServiceCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		*
FROM		@Services 

OPEN ServiceCursor;
FETCH ServiceCursor INTO @SID,@SName,@SAccount,@SMode,@SState;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
		IF @Verbose > 0 RAISERROR('  -- Checking Service %s',-1,-1,@SName) WITH NOWAIT

		-- CHECK Service Account
		IF @SName IN ('MsDtsServer130','MSSQLSERVER','MSSQLServerOLAPService','ReportServer','ReportServer$CPI','ReportServer$QA','ReportServer$REL','SQLSERVERAGENT','','','','','','') 
		BEGIN
			IF @SAccount = @ServiceActLogin
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcAcct'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SAccount				AS CHAR(35))															-- Check_Detail01
							+ CAST('The Service Account Should Be ' + @ServiceActLogin  AS CHAR(100))								-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcAcct_' + @SName, 'Pass', 'High', @save_test, null, @SAccount, 'The service account should be ' + @ServiceActLogin, getdate())
			END
			ELSE
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcAcct'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('FAIL'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SAccount				AS CHAR(35))															-- Check_Detail01
							+ CAST('The Service Account Should Be ' + @ServiceActLogin  AS CHAR(100))								-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcAcct_' + @SName, 'Fail', 'High', @save_test, null, @SAccount, 'The service account should be ' + @ServiceActLogin, getdate())
			END
		END

		-- SERVICES THAT SHOULD BE DISABLED
		IF		@SName IN ('SQLBrowser','SQLsafe Backup Service','SQLsafe Filter Service','SQLSafeOLRService','','','','')
			OR	@SName Like '%TELEMETRY%'
		BEGIN
			IF @SMode = 'Disabled'
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcMode'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SMode					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be set to Disabled' AS CHAR(100))											-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcMode_' + @SName, 'Pass', 'Low', @save_test, null, @SMode, 'This Service Should Be Set to Disabled', getdate())
			END
			ELSE
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcMode'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('WARNING'				AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SMode					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be set to Disabled' AS CHAR(100))											-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcMode_' + @SName, 'Warning', 'Low', @save_test, null, @SMode, 'This Service Should Be Set to Disabled', getdate())
			END
		END

		-- SERVICES THAT SHOULD BET SET TO AUTO START
		IF @SName IN ('MsDtsServer130','MSSQLSERVER','MSSQLServerOLAPService','ReportServer','ReportServer$CPI','ReportServer$QA','ReportServer$REL','SQLSERVERAGENT','','','','','') --CHECK Service Mode
		BEGIN
			IF @SMode = 'Auto'
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcMode'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SMode					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be set to Automatic' AS CHAR(100))											-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcMode_' + @SName, 'Pass', 'High', @save_test, null, @SMode, 'This Service Should Be set to Automatic', getdate())
			END
			ELSE
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcMode'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('FAIL'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SMode					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be set to Automatic' AS CHAR(100))											-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcMode_' + @SName, 'Fail', 'High', @save_test, null, @SMode, 'This Service Should Be set to Automatic', getdate())
			END
		END

		--SERVICES THAT SHOULD BE RUNNING
		IF @SName IN ('MsDtsServer130','MSSQLFDLauncher','MSSQLSERVER','MSSQLServerOLAPService','ReportServer','ReportServer$CPI','ReportServer$QA','ReportServer$REL','SQLSERVERAGENT','','','','','') --CHECK Service State
		BEGIN
			IF @SState = 'Running'
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcState'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SState					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be Running' AS CHAR(100))													-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcState_' + @SName, 'Pass', 'High', @save_test, null, @SState, 'This Service Should Be Running', getdate())
			END
			ELSE
			BEGIN
				SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
							+ CAST('SvcState'				AS CHAR(10))															-- HCType
							+ CAST(@SName					AS CHAR(25))
							+ CAST('FAIL'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
							+ CAST('HIGH'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
							+ CAST(''						AS CHAR(25))															-- HCDBName
							+ CAST(@SState					AS CHAR(35))															-- Check_Detail01
							+ CAST('This Service Should Be Running' AS CHAR(100))													-- Check_Detail02
							+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcState_' + @SName, 'Fail', 'High', @save_test, null, @SState, 'This Service Should Be Running', getdate())
			END
		END
		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM ServiceCursor INTO @SID,@SName,@SAccount,@SMode,@SState;
END
CLOSE ServiceCursor;
DEALLOCATE ServiceCursor;


-- CHECKING SERVICE ACCOUNT PERMISSIONS
IF @Verbose > 0 RAISERROR('Checking Service Account Permissions...',-1,-1) WITH NOWAIT
IF @Verbose > 0 RAISERROR('',-1,-1) WITH NOWAIT

SELECT @cmd = 'accesschk.exe /accepteula -q -a SeServiceLogonRight'
Select @save_test = 'EXEC master.sys.xp_cmdshell ''' + @cmd + ''''

DELETE FROM #miscTempTable
INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd
DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
--select * from #miscTempTable

IF exists (select 1 from #miscTempTable WHERE cmdoutput LIKE '%' + @ServiceActLogin + '%')
   BEGIN
			SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
						+ CAST('ServiceLogonRight'		AS CHAR(35))															-- HCType
						+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
						+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
						+ CAST(''						AS CHAR(25))															-- HCDBName
						+ CAST(@ServiceActLogin			AS CHAR(35))															-- Check_Detail01
						+ CAST('ServiceLogonRight needs to be granted for the current SQL service account' AS CHAR(100))		-- Check_Detail02
						+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
			IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
			insert into [dbo].[HealthCheckLog] values ('Install_Service', 'ServiceLogonRight', 'Pass', 'Low', @save_test, null, @ServiceActLogin, 'ServiceLogonRight needs to be granted for the current SQL service account', getdate())
   END
ELSE
   BEGIN
   			SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
						+ CAST('ServiceLogonRight'		AS CHAR(35))															-- HCType
						+ CAST('WARNING'				AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
						+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
						+ CAST(''						AS CHAR(25))															-- HCDBName
						+ CAST(@ServiceActLogin			AS CHAR(35))															-- Check_Detail01
						+ CAST('ServiceLogonRight needs to be granted for the current SQL service account' AS CHAR(100))		-- Check_Detail02
						+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
			IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
			insert into [dbo].[HealthCheckLog] values ('Install_Service', 'ServiceLogonRight', 'Warning', 'Low', @save_test, null, @ServiceActLogin, 'ServiceLogonRight needs to be granted for the current SQL service account.', getdate())
   END


--  Start check Local Administrators
IF @Verbose > 0 RAISERROR('Checking Local Administrators...',-1,-1) WITH NOWAIT
IF @Verbose > 0 RAISERROR('',-1,-1) WITH NOWAIT

SELECT @cmd = 'net localgroup Administrators' 
Select @save_test = 'EXEC master.sys.xp_cmdshell ''' + @cmd + ''''

DELETE FROM #showgrps
INSERT INTO #showgrps EXEC master.sys.xp_cmdshell @cmd
DELETE FROM #showgrps WHERE cmdoutput IS NULL
DELETE FROM #showgrps WHERE cmdoutput LIKE '%is a member of%'
DELETE FROM #showgrps WHERE cmdoutput LIKE '%The command completed successfully%'
DELETE FROM #showgrps WHERE cmdoutput LIKE 'Alias name%'
DELETE FROM #showgrps WHERE cmdoutput LIKE 'Comment%'
DELETE FROM #showgrps WHERE cmdoutput LIKE 'Members%'
DELETE FROM #showgrps WHERE cmdoutput LIKE '----------%'
UPDATE #showgrps SET cmdoutput = LTRIM(RTRIM(cmdoutput))
--select * from #showgrps


IF EXISTS (SELECT 1 FROM #showgrps WHERE cmdoutput Like '%'+@ServiceActLogin+'%')
   BEGIN
   			SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
						+ CAST('SvcAccount_LocalAdmin'	AS CHAR(35))															-- HCType
						+ CAST('PASS'					AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
						+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
						+ CAST(''						AS CHAR(25))															-- HCDBName
						+ CAST(@ServiceActLogin			AS CHAR(35))															-- Check_Detail01
						+ CAST('The SQL service account needs to be in the the local administrators group' AS CHAR(100))		-- Check_Detail02
						+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose > 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				insert into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcAccount_LocalAdmin', 'Pass', 'Low', @save_test, null, @ServiceActLogin, 'The SQL service account needs to be in the the local administrators group', getdate())
   END
ELSE
   BEGIN
			SET @MSG	= CAST('  -- Install_Service'	AS CHAR(25))															-- HCCat
						+ CAST('SvcAccount_LocalAdmin'	AS CHAR(35))															-- HCType
						+ CAST('WARNING'				AS CHAR(10))	-- PASS,WARNING,FAIL									-- HCStatus
						+ CAST('LOW'					AS CHAR(10))	-- LOW,MEDIUM,HIGH										-- HCPriority
						+ CAST(''						AS CHAR(25))															-- HCDBName
						+ CAST(@ServiceActLogin			AS CHAR(35))															-- Check_Detail01
						+ CAST('The SQL service account needs to be added the the local administrators group' AS CHAR(100))		-- Check_Detail02
						+ CAST(@save_test				AS CHAR(100))															-- HCTest
						
				IF @Verbose >= 0 RAISERROR(@MSG,-1,-1) WITH NOWAIT
				INSERT into [dbo].[HealthCheckLog] values ('Install_Service', 'SvcAccount_LocalAdmin', 'Warning', 'Low', @save_test, null, @ServiceActLogin, 'The SQL service account needs to be in the the local administrators group.', getdate())
   END

IF @Verbose > 1
	SELECT		*
	FROM		[dbo].[HealthCheckLog]
	WHERE		HCcat		= 'Install_Service'
		AND		Check_date	>= CAST(GETDATE() AS Date)

/*

-- THIS IS CALLED BY  -- EXEC dbaops.dbo.dbasp_HC_control

EXEC [dbaops].[dbo].[dbasp_HC_Install_Services] -1		-- RUN SILENT
EXEC [dbaops].[dbo].[dbasp_HC_Install_Services]			-- NORMAL ONLY SHOW FAILURES
EXEC [dbaops].[dbo].[dbasp_HC_Install_Services] 1		-- SHOW ALL COMMENTS
EXEC [dbaops].[dbo].[dbasp_HC_Install_Services] 2		-- ALSO SHOW TABLE RESULTS 
GO
EXEC dbaops.dbo.dbasp_Export_Checkin_Data 'dbaops.dbo.HealthCheckLog'
GO

*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Install_Services] TO [public]
GO
