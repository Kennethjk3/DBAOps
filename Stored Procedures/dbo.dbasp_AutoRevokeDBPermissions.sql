SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE	[dbo].[dbasp_AutoRevokeDBPermissions] (@RID		INT = NULL) -- USE ID TO FORCE REVOKE NOW
AS
DECLARE @ServerName		SYSNAME				
DECLARE @LoginName		SYSNAME				
DECLARE @DBName			SYSNAME				
DECLARE @Permission		SYSNAME
DECLARE	@CreateDate		DATETIME
DECLARE @DelDate		DATETIME			
DECLARE @RequestID		INT
DECLARE @RequestorEMail	VarChar(1000)
DECLARE	@MSG			VarChar(8000)
DECLARE	@LC				BIT
DECLARE	@UC				BIT
DECLARE	@DateDeleted	DATETIME
DECLARE @SQL			VarChar(8000)



DECLARE LoginCleanupCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		MIN(CreateDate) [CreateDate]	
			,MAX(RequestID) [RequestID]	
			,MAX(CAST(LoginCreated AS INT)) [LoginCreated]	
			,DBname	
			,MAX(CAST(UserCreated AS Int))	[UserCreated]
			,Loginname	
			,DBrole	
			,MAX(DeleteDate) [DeleteDate]
			,NULL [DateDeleted]
FROM		[DBAOps].[dbo].[UserDB_Access_Ctrl] T1
WHERE		(
			[CreateDate] <= GetDate()
	AND		[DeleteDate] >= GetDate()
			)
	AND		NOT EXISTS	(
						SELECT				1
						FROM				master.sys.Server_role_members AS DRM  
						RIGHT OUTER JOIN	master.sys.Server_principals AS DP1		ON DRM.role_principal_id = DP1.principal_id  
						LEFT OUTER JOIN		master.sys.Server_principals AS DP2		ON DRM.member_principal_id = DP2.principal_id  
						WHERE				DP1.type = 'R'
							AND				DP2.name			= T1.LoginName
							AND				DP1.name			= CASE T1.DBrole
																	WHEN 'read' THEN 'db_datareader'
																	WHEN 'write' THEN 'db_datawriter'
																	WHEN 'execute' THEN 'db_executer'
																	WHEN 'dbo' THEN 'db_owner'
																	WHEN 'sysadmin' THEN 'sysadmin'
																	END
						UNION ALL
						SELECT				1  
						FROM				DBAOps.dbo.vw_AllDB_database_role_members AS DRM  
						RIGHT OUTER JOIN	DBAOps.dbo.vw_AllDB_database_principals AS DP1		ON DRM.database_name = DP1.database_name	AND   DRM.role_principal_id = DP1.principal_id  
						LEFT OUTER JOIN		DBAOps.dbo.vw_AllDB_database_principals AS DP2		ON DRM.database_name = DP2.database_name	AND   DRM.member_principal_id = DP2.principal_id  
						WHERE				DP1.type = 'R'
							AND				DP1.database_name	= T1.DBName
							AND				DP2.name			= T1.LoginName
							AND				DP1.name			= CASE T1.DBrole
																	WHEN 'read' THEN 'db_datareader'
																	WHEN 'write' THEN 'db_datawriter'
																	WHEN 'dbo' THEN 'db_owner'
																	WHEN 'execute' THEN 'db_executer'
																	WHEN 'sysadmin' THEN 'sysadmin'
																	END
						)
GROUP BY	DBname
			,Loginname
			,DBRole
ORDER BY	Loginname,DBname,DBRole

OPEN LoginCleanupCursor;
FETCH LoginCleanupCursor INTO @CreateDate,@RequestID,@LC,@DBName,@UC,@LoginName,@Permission,@DelDate,@DateDeleted;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
		SET	@MSG = ''
		SET @SQL = NULL

		IF NOT EXISTS (SELECT * FROM sys.syslogins where name = @LoginName)
		BEGIN
			SET @SQL = 'CREATE LOGIN ['+@LoginName+'] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]'
			RAISERROR(@SQL,-1,-1) WITH NOWAIT
			IF @SQL IS NOT NULL
				EXEC(@SQL)
		END

		SET @SQL = 
		'USE ['+@DBName+']
		IF NOT EXISTS (SELECT * FROM sys.sysusers where name = '''+@LoginName+''')
		BEGIN
			CREATE USER ['+@LoginName+'] FOR LOGIN ['+@LoginName+'] WITH DEFAULT_SCHEMA=[dbo]
		END'
		RAISERROR(@SQL,-1,-1) WITH NOWAIT
		IF @SQL IS NOT NULL
			EXEC(@SQL)

		IF @Permission = 'sysadmin'
			SET @SQL = 'USE [master];ALTER SERVER ROLE [sysadmin] ADD MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'read'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_datareader] ADD MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'write'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_datawriter] ADD MEMBER ['+@LoginName+'];ALTER ROLE [db_datareader] ADD MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'execute'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_executer] ADD MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'dbo'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_owner] ADD MEMBER ['+@LoginName+'];'

		SET @MSG = @MSG + COALESCE(@SQL,'') + CHAR(13) + CHAR(10)
		RAISERROR(@SQL,-1,-1) WITH NOWAIT
		BEGIN TRY
			IF @SQL IS NOT NULL
				EXEC(@SQL)
		END TRY
		BEGIN CATCH
			RAISERROR('Error Reapplying Permissions',-1,-1) WITH NOWAIT
		END CATCH
		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM LoginCleanupCursor INTO @CreateDate,@RequestID,@LC,@DBName,@UC,@LoginName,@Permission,@DelDate,@DateDeleted;
END
CLOSE LoginCleanupCursor;
DEALLOCATE LoginCleanupCursor;


SELECT		*
FROM		[DBAOps].[dbo].[UserDB_Access_Ctrl] WITH(TABLOCK)
WHERE		(
			[DateDeleted] IS NULL
	AND		[DeleteDate] <= GetDate()
			)
	OR		[RequestID] = COALESCE(@RID,0)


DECLARE LoginCleanupCursor2 CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		*
FROM		[DBAOps].[dbo].[UserDB_Access_Ctrl] WITH(TABLOCK)
WHERE		(
			[DateDeleted] IS NULL
	AND		[DeleteDate] <= GetDate()
			)
	OR		[RequestID] = COALESCE(@RID,0)
FOR UPDATE OF DateDeleted

OPEN LoginCleanupCursor2;
FETCH LoginCleanupCursor2 INTO @CreateDate,@RequestID,@LC,@DBName,@UC,@LoginName,@Permission,@DelDate,@DateDeleted;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP
		SET	@MSG = ''
		SET @SQL = NULL

		IF @Permission = 'sysadmin'
			SET @SQL = 'USE [master];ALTER SERVER ROLE [sysadmin] DROP MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'read'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_datareader] DROP MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'write'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_datawriter] DROP MEMBER ['+@LoginName+'];ALTER ROLE [db_datareader] DROP MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'execute'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_executer] DROP MEMBER ['+@LoginName+'];'
		ELSE IF @Permission = 'dbo'
			SET @SQL = 'USE ['+@DBName+'];ALTER ROLE [db_owner] DROP MEMBER ['+@LoginName+'];'

		SET @MSG = @MSG + COALESCE(@SQL,'') + CHAR(13) + CHAR(10)
		RAISERROR(@SQL,-1,-1) WITH NOWAIT

		BEGIN TRY
			IF @SQL IS NOT NULL
				EXEC(@SQL)
		END TRY
		BEGIN CATCH
			RAISERROR('Error Dropping Permissions',-1,-1) WITH NOWAIT
		END CATCH
		
		SET @SQL = NULL

		IF @UC = 1
			SET @SQL = 'USE ['+@DBName+'];DROP USER ['+@LoginName+'];'

		SET @MSG = @MSG + COALESCE(@SQL,'') + CHAR(13) + CHAR(10)
		RAISERROR(@SQL,-1,-1) WITH NOWAIT

		BEGIN TRY
			IF @SQL IS NOT NULL
				EXEC(@SQL)
		END TRY
		BEGIN CATCH
			RAISERROR('Error Dropping User',-1,-1) WITH NOWAIT
		END CATCH

		SET @SQL = NULL

		IF @LC = 1
			SET @SQL = 'USE [master];DROP LOGIN ['+@LoginName+'];'

		SET @MSG = @MSG + COALESCE(@SQL,'') + CHAR(13) + CHAR(10)
		RAISERROR(@SQL,-1,-1) WITH NOWAIT

		BEGIN TRY
			IF @SQL IS NOT NULL
				EXEC(@SQL)
		END TRY
		BEGIN CATCH
			RAISERROR('Error Dropping Login',-1,-1) WITH NOWAIT
		END CATCH

		UPDATE [DBAOps].[dbo].[UserDB_Access_Ctrl] SET DateDeleted = GetDate()
		WHERE  CURRENT OF LoginCleanupCursor2 ;

		UPDATE [SDCSQLTOOLS].[DBACentral].[dbo].[DBPermissionRequestQueue]
		SET	Revoked = 1,moddate = getdate()
		WHERE [RequestID] = @RequestID

		DECLARE @sub Varchar(8000) = 'DB Permissions have Been Revoked from ' + @@SERVERNAME

		EXEC		msdb.dbo.sp_send_dbmail				@from_address 		= 'DBA<DBA@VIRTUOSO.COM>' 
														,@recipients		= 'sledridge@virtuoso.com'
														,@subject			= @sub
														,@body				= @MSG
														,@body_format		= 'HTML'

		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM LoginCleanupCursor2 INTO @CreateDate,@RequestID,@LC,@DBName,@UC,@LoginName,@Permission,@DelDate,@DateDeleted;
END
CLOSE LoginCleanupCursor2;
DEALLOCATE LoginCleanupCursor2;



-- EXEC [dbaops].[dbo].[dbasp_AutoRevokeDBPermissions]
-- EXEC [dbaops].[dbo].[dbasp_AutoRevokeDBPermissions] 8
-- SELECT * FROM [DBAOps].[dbo].[UserDB_Access_Ctrl]
-- SELECT * FROM [DBAOps].[dbo].[UserDB_Access_Ctrl] WHERE DateDeleted IS NULL

GO
GRANT EXECUTE ON  [dbo].[dbasp_AutoRevokeDBPermissions] TO [public]
GO
