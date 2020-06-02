SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SecurityAudit]
AS
BEGIN
	SET NOCOUNT ON
	DECLARE		@LoginName			SYSNAME
				,@ServerPerms		VarChar(8000)
				,@LoginType			SYSNAME

	DROP TABLE IF EXISTS #GroupMembers
	DROP TABLE IF EXISTS #DBUsers
	DROP TABLE IF EXISTS #DBPerms
	DROP TABLE IF EXISTS #ServerPerms

	CREATE TABLE #GroupMembers
	(
	GroupName				VarChar(max) NULL
	,LastName				VarChar(max) NULL
	,FirstName				VarChar(max) NULL
	,DomainAccount			VarChar(max) NULL
	,department				VarChar(max) NULL
	,manager				VarChar(max) NULL
	,employeeID				VarChar(max) NULL
	,ServerPermissions		VarChar(max) NULL
	,DBPermissions			VarChar(max) NULL
	,InAD					BIT NULL
	)

	CREATE TABLE #DBUsers (DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime)


	EXEC sp_MSforeachdb 
	'use [?]
	INSERT INTO #DBUsers
	SELECT ''?'' AS DB_Name,
	case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
	prin.type_desc AS LoginType,
	isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
	FROM sys.database_principals prin
	LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
	WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) and --prin.type_desc =''WINDOWS_GROUP'' AND
	prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%''
	AND prin.sid IN (SELECT sid from sys.server_principals)'
	-- SELECT * FROM #DBUsers

	DELETE #DBUsers WHERE DBName IN('DBAOps','DBAPerf','','','','')

	SELECT		username
				,DBAOps.dbo.dbaudf_ConcatenateUnique(dbname +'('+[AssociatedRoles]+')') AS [DBPermissions]
	INTO		#DBPerms
	FROM		(
				SELECT		username
							,dbname
							,DBAOps.dbo.dbaudf_ConcatenateUnique(AssociatedRole) AS [AssociatedRoles]
				FROM		#DBUsers
				GROUP BY	username
							,dbname
				) Data
	GROUP BY	username
	-- SELECT * FROM #DBPerms

	SELECT		type_desc
				,Login
				,DBAOps.dbo.dbaudf_ConcatenateUnique([ServerPermission]) AS [ServerPermissions]
	INTO		#ServerPerms
	FROM		(
				SELECT SP1.[name] AS 'Login', 'Role: ' + SP2.[name] COLLATE DATABASE_DEFAULT AS 'ServerPermission', sp1.type_desc
				FROM sys.server_principals SP1
				JOIN sys.server_role_members SRM
				ON SP1.principal_id = SRM.member_principal_id
				JOIN sys.server_principals SP2
				ON SRM.role_principal_id = SP2.principal_id
				--WHERE sp1.type_desc IN ('WINDOWS_GROUP')
				UNION 
				SELECT SP.[name] AS 'Login' , SPerm.state_desc + ' ' + SPerm.permission_name COLLATE DATABASE_DEFAULT AS 'ServerPermission',sp.type_desc
				FROM sys.server_principals SP
				JOIN sys.server_permissions SPerm
				ON SP.principal_id = SPerm.grantee_principal_id
				--WHERE sp.type_desc IN ('WINDOWS_GROUP')
				) T1
	GROUP BY	type_desc,Login
	ORDER BY	1,2,3
	-- select * From #ServerPerms


	DECLARE GroupCursor CURSOR
	FOR
	SELECT	Login
			,ServerPermissions
	FROM	#ServerPerms
	WHERE	type_desc = 'WINDOWS_GROUP'

	OPEN GroupCursor;
	FETCH GroupCursor INTO @LoginName,@ServerPerms;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			---------------------------- 
			---------------------------- CURSOR LOOP TOP
			SET @LoginName = REPLACE(@LoginName,'${{secrets.COMPANY_NAME}}\','')

			INSERT INTO #GroupMembers (GroupName,LastName,FirstName,DomainAccount,department,manager,employeeID)
			EXEC [DBAOps].[dbo].[dbasp_GetADGroupMembers] @LoginName

			UPDATE #GroupMembers SET ServerPermissions = @ServerPerms,InAD = 1,DomainAccount = '${{secrets.COMPANY_NAME}}\'+DomainAccount WHERE GroupName = @LoginName

			UPDATE T1 SET DBPermissions = T2.DBPermissions
			FROM	#GroupMembers T1
			JOIN	#DBPerms T2 ON REPLACE(T2.UserName,'${{secrets.COMPANY_NAME}}\','') = T1.GroupName

			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM GroupCursor INTO @LoginName,@ServerPerms;
	END
	CLOSE GroupCursor;
	DEALLOCATE GroupCursor;



	INSERT INTO #GroupMembers (GroupName,LastName,FirstName,DomainAccount,department,manager,employeeID,ServerPermissions,DBPermissions,InAD)
	SELECT		T1.type_desc,T3.sn,T3.GivenName,REPLACE(T1.Login,'${{secrets.COMPANY_NAME}}\','${{secrets.COMPANY_NAME}}\'),T3.department,T3.manager,T3.employeeID,T1.ServerPermissions,T2.DBPermissions,CASE WHEN T3.sAMAccountName IS NOT NULL THEN 1 ELSE 0 END
	FROM		#ServerPerms T1
	LEFT JOIN	#DBPerms T2				ON T2.UserName = T1.Login
	LEFT JOIN	(
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''_*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''A*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''B*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''C*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''D*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''E*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''F*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''G*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''H*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''I*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''J*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''K*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''L*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''M*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''N*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''O*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''P*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Q*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''R*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''S*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''T*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''U*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''V*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''W*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''X*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Y*''')  UNION
				SELECT * FROM OPENQUERY( ADSI, 'SELECT sn,GivenName,sAMAccountName,department,manager,employeeID FROM ''LDAP://dc=${{secrets.COMPANY_NAME}},dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Z*''')
				) T3  ON T3.sAMAccountName = REPLACE(T1.Login,'${{secrets.COMPANY_NAME}}\','') AND T1.Login LIKE '${{secrets.COMPANY_NAME}}\%'

	WHERE		T1.type_desc NOT IN ('WINDOWS_GROUP','','','')
		AND		T1.Login Not Like '##%'
		AND		T1.Login Not Like 'NT %'


	DROP TABLE IF EXISTS DBAOps.dbo.DBA_SecurityAudit

	DECLARE @Now DateTime = GetDate()

	SELECT		@@SERVERNAME [ServerName]
				,@Now [ModDate]
				,T1.GroupName	
				,T1.LastName	
				,T1.FirstName	
				,T1.DomainAccount	
				,T1.ServerPermissions	
				,T1.DBPermissions	
				,T2.[TempPermissionsGranted]
				,CASE	WHEN 	ServerPermissions LIKE '%sysadmin%'		THEN 3
						WHEN	DBPermissions LIKE '%db_owner%'			THEN 2
						WHEN	DBPermissions LIKE '%db_datawriter%'	THEN 1
						ELSE 0
						END [SecurityLevel]
	INTO		DBAOps.dbo.DBA_SecurityAudit
	FROM		#GroupMembers	T1
	LEFT JOIN	(
				SELECT		[Loginname]
							,DBAOps.dbo.dbaudf_ConcatenateUnique([DBname]+'( '+ [DBrole] + '  From:' +CAST(CAST([CreateDate] AS DATE) AS VarChar(50)) + '  To:' + CAST(CAST([DeleteDate] AS DATE) AS VarChar(50))+' )') [TempPermissionsGranted]
				FROM		[DBAOps].[dbo].[UserDB_Access_Ctrl]
				WHERE		DateDeleted IS NULL
				GROUP BY	[Loginname]
				) T2 ON T2.Loginname = T1.DomainAccount AND T1.GroupName = 'WINDOWS_LOGIN'
	
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_SecurityAudit] TO [public]
GO
