SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_DB_OrphanedUsers] (@dbname sysname = null
					,@HCcat sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_HC_DB_OrphanedUsers
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  February 10, 2015
 **  This procedure runs the DB Orphaned Users portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/10/2015	Steve Ledridge		New process.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  Check Orphaned Users


/***
Declare @dbname sysname
Declare @HCcat sysname


Select @dbname = 'DBAOps'
Select @HCcat = 'DbaDB'
--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@hold_backup_start_date		DATETIME
	,@save_backup_start_date		sysname
	,@save_user_name			sysname
	,@save_user_sid				VARCHAR(255)
	,@SQL					NVARCHAR(4000)
	,@save_ObjectName			sysname
	,@save_ObjectType			sysname


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


CREATE TABLE 	#orphans (
			 orph_sid VARBINARY(85) NOT NULL
			,orph_name sysname NULL
			)


CREATE TABLE 	#Objects (
			DatabaseName sysname,
			UserName sysname,
			ObjectName sysname,
			ObjectType NVARCHAR(60)
			)


CREATE TABLE	#temp_tbl1 (
			 tb11_id [INT] IDENTITY(1,1) NOT NULL
			,text01	NVARCHAR(400) NULL
			)


CREATE TABLE	#SchemaObjCounts (
				 SchemaName sysname
				,objCount BIGINT
				)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Check for Orphaned Users
Print 'Start ''' + @dbname + ''' Orphaned Users check'
Print ''


--  Double Check users marked as orphaned.  If any were marked in error, set delete flag to 'x'
INSERT INTO #orphans 	EXECUTE('select sid, name from [' + @dbname + '].sys.sysusers
			where sid not in (select sid from master.sys.syslogins where name is not null and sid is not null)
			and name not in (''guest'')
			and sid is not null
			and issqlrole = 0
			')


UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'x'
			WHERE Delete_flag = 'n'
			AND SOL_type = 'user'
			AND SOL_DBname = @dbname
			AND SOL_name NOT IN (SELECT orph_name FROM #orphans)


--  Drop users orphaned for more than 7 days
DELETE FROM #temp_tbl1
INSERT #temp_tbl1(text01) SELECT SOL_name
   FROM dbo.Security_Orphan_Log
   WHERE Delete_flag = 'n'
   AND SOL_type = 'user'
   AND SOL_DBname = @dbname
   AND Initial_Date < getdate()-7
DELETE FROM #temp_tbl1 WHERE text01 IS NULL


start_delete_DBusers:
IF (SELECT COUNT(*) FROM #temp_tbl1) > 0
   BEGIN
	-----------------------------------------------------------------------------------------
	--  Start verify (and cleanup) for Users
	-----------------------------------------------------------------------------------------
	SELECT @save_user_name = (SELECT TOP 1 text01 FROM #temp_tbl1)


	SELECT @cmd = N'select top 1 @save_user_sid = sid from [' + @dbname +'].[sys].[database_principals] where name = ''' + @save_user_name + ''''
	EXEC sp_executesql @cmd, N'@save_user_sid varchar(255) output', @save_user_sid = @save_user_sid OUTPUT


	DELETE FROM #Objects


	-- Checking for cases in sys.objects where ALTER AUTHORIZATION has been used
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			  SELECT ''' + @dbname + ''', dp.name, so.name, so.type_desc
			  FROM [' + @dbname + '].sys.database_principals dp
				JOIN [' + @dbname + '].sys.objects so
				  ON dp.principal_id = so.principal_id
			  WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);

	-- Checking for cases where the login owns one or more schema
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			 SELECT ''' + @dbname + ''', dp.name, sch.name, ''SCHEMA''
			 FROM [' + @dbname + '].sys.database_principals dp
			   JOIN [' + @dbname + '].sys.schemas sch
				 ON dp.principal_id = sch.principal_id
			 WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);


	-- Checking for cases where the login owns assemblies
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			 SELECT ''' + @dbname + ''', dp.name, assemb.name, ''Assembly''
			 FROM [' + @dbname + '].sys.database_principals dp
			JOIN [' + @dbname + '].sys.assemblies assemb
				 ON dp.principal_id = assemb.principal_id
			 WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);

	-- Checking for cases where the login owns asymmetric keys
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			 SELECT ''' + @dbname + ''', dp.name, asym.name, ''Asymm. Key''
			 FROM [' + @dbname + '].sys.database_principals dp
			   JOIN [' + @dbname + '].sys.asymmetric_keys asym
				 ON dp.principal_id = asym.principal_id
			 WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);

	-- Checking for cases where the login owns symmetric keys
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			 SELECT ''' + @dbname + ''', dp.name, sym.name, ''Symm. Key''
			 FROM [' + @dbname + '].sys.database_principals dp
			   JOIN [' + @dbname + '].sys.symmetric_keys sym
				 ON dp.principal_id = sym.principal_id
			 WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);

	-- Checking for cases where the login owns certificates
	SET @SQL = 'INSERT INTO #Objects (DatabaseName, UserName, ObjectName, ObjectType)
			 SELECT ''' + @dbname + ''', dp.name, cert.name, ''Certificate''
			 FROM [' + @dbname + '].sys.database_principals dp
			   JOIN [' + @dbname + '].sys.certificates cert
				 ON dp.principal_id = cert.principal_id
			 WHERE dp.sid = ''' + @save_user_sid + ''';';
	EXEC(@SQL);


	DELETE FROM #Objects WHERE ObjectName IS NULL

	IF (SELECT COUNT(*) FROM #Objects) > 0
	   BEGIN
		Start_dbuser_alterauth:
		SELECT @save_ObjectName = (SELECT TOP 1 ObjectName FROM #Objects)
		SELECT @save_ObjectType = (SELECT TOP 1 ObjectType FROM #Objects WHERE ObjectName = @save_ObjectName)


		IF @save_ObjectType = 'SCHEMA'
		   BEGIN
			SELECT @cmd = 'use [' + @dbname + '] ALTER AUTHORIZATION ON SCHEMA::[' + @save_ObjectName + '] TO dbo;'
			--Print '		'+@cmd
			EXEC (@cmd)
		   END
		ELSE IF @save_ObjectType = 'Assembly'
		   BEGIN
			SELECT @cmd = 'use [' + @dbname + '] ALTER AUTHORIZATION ON Assembly::[' + @save_ObjectName + '] TO dbo;'
			--Print '		'+@cmd
			EXEC (@cmd)
		   END
		ELSE IF @save_ObjectType = 'Symm. Key'
		   BEGIN
			SELECT @cmd = 'use [' + @dbname + '] ALTER AUTHORIZATION ON SYMMETRIC KEY::[' + @save_ObjectName + '] TO dbo;'
			--Print '		'+@cmd
			EXEC (@cmd)
		   END
		ELSE IF @save_ObjectType = 'Certificate'
		   BEGIN
			SELECT @cmd = 'use [' + @dbname + '] ALTER AUTHORIZATION ON Certificate::[' + @save_ObjectName + '] TO dbo;'
			--Print '		'+@cmd
			EXEC (@cmd)
		   END
		ELSE
		   BEGIN
			SELECT @cmd = 'use [' + @dbname + '] ALTER AUTHORIZATION ON OBJECT::[' + @save_ObjectName + '] TO dbo;'
			--Print '		'+@cmd
			EXEC (@cmd)
		   END
	   END


	DELETE FROM #Objects WHERE ObjectName = @save_ObjectName AND ObjectType = @save_ObjectType
	IF (SELECT COUNT(*) FROM #Objects) > 0
	   BEGIN
		GOTO Start_dbuser_alterauth
	   END

	--  GET OBJECT COUNTS FOR ALL SCHEMAS
	SELECT @cmd = 'Use [' + @dbname + '];
	TRUNCATE TABLE #SchemaObjCounts;
	INSERT INTO	#SchemaObjCounts
	select		ss.name
				,COUNT(so.object_id) as objCount
	From		sys.schemas ss WITH(NOLOCK)
	LEFT JOIN	sys.objects so WITH(NOLOCK)
			ON	so.schema_id = ss.schema_id
	GROUP BY	ss.name'
	--Print '		'+@cmd
	EXEC (@cmd)


	--  LIST ALL CURRENT SCHEMAS AND OBJECT COUNTS UNDER THEM
	--SELECT * FROM #SchemaObjCounts


	--  DROP SCHEMA IF IT EXISTS AND NO OBJECTS ARE USING IT.
	SELECT @cmd = 'Use [' + @dbname + ']; IF EXISTS(SELECT 1 FROM #SchemaObjCounts where SchemaName ='''+@save_user_name+''' and objCount = 0) DROP SCHEMA [' + @save_user_name + '];'
	--Print '		'+@cmd
	EXEC (@cmd)

	--  DROP USER IF IT STILL EXISTS
	SELECT @cmd = 'Use [' + @dbname + ']; IF User_ID('''+@save_user_name+''') IS NOT NULL DROP User [' + @save_user_name + '];'
	--Print '		'+@cmd
	EXEC (@cmd)


	UPDATE dbo.Security_Orphan_Log SET Delete_flag = 'y'
			WHERE Delete_flag = 'n'
			AND SOL_name = @save_user_name
			AND SOL_DBname = @dbname


	--  Loop to process more logins
	DELETE FROM #temp_tbl1 WHERE text01 = @save_user_name
	GOTO start_delete_DBusers
   END


-----------------------------------------------------------------------------------------
--  Check for orphaned Users
-----------------------------------------------------------------------------------------


Select @save_test = 'SELECT * FROM DBAOps.dbo.Security_Orphan_Log WHERE Delete_flag = ''n'' AND SOL_DBname = ''' + @dbname + ''''
IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE Delete_flag = 'n' AND SOL_DBname = @dbname AND Initial_Date < getdate()-7)
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Orphaned User', 'Fail', 'Medium', @save_test, @dbname, 'Orphaned User(s) found (not auto-cleaned)', null, getdate())
   END
ELSE IF EXISTS (SELECT 1 FROM dbo.Security_Orphan_Log WHERE Delete_flag = 'n' AND SOL_DBname = @dbname)
   BEGIN
	insert into [dbo].[HealthCheckLog] values (@HCcat, 'Orphaned User', 'Warning', 'Medium', @save_test, @dbname, 'Orphaned User(s) found (not yet auto-cleaned)', null, getdate())
   END


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #orphans
drop TABLE #temp_tbl1
drop TABLE #Objects
drop TABLE #SchemaObjCounts
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_DB_OrphanedUsers] TO [public]
GO
