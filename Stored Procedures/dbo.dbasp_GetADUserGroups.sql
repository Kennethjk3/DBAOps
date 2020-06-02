SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetADUserGroups]
(
    @Username NVARCHAR(256) 
)
AS
BEGIN

    DECLARE @Query NVARCHAR(1024), @Path NVARCHAR(1024)

 	SELECT		TOP (1) @Path = distinguishedName
	from		(
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''_*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''A*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''B*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''C*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''D*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''E*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''F*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''G*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''H*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''I*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''J*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''K*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''L*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''M*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''N*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''O*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''P*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Q*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''R*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''S*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''T*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''U*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''V*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''W*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''X*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Y*''')  UNION
			SELECT * FROM OPENQUERY( ADSI, 'SELECT cn, sAMAccountName, distinguishedName FROM ''LDAP://dc=virtuoso,dc=com'' WHERE objectCategory = ''Person'' AND SAMAccountName = ''Z*''')
			) Data
			
	WHERE		cn = @UserName OR sAMAccountName = @UserName OR sAMAccountName = REPLACE(@UserName,'virtuoso\','')

	PRINT @Path

    -- get all groups for a user
    -- replace "LDAP://DC=Domain,DC=local" with your own domain
    SET @Query = '
        SELECT '''+@UserName+''' [Login] ,cn [GroupName],AdsPath
        FROM OPENQUERY (ADSI, ''<LDAP://DC=virtuoso,DC=com>;(&(objectClass=group)(member:1.2.840.113556.1.4.1941:=' + @Path +'));cn, adspath;subtree'')'

    EXEC SP_EXECUTESQL @Query  

	--	EXEC DBAOps.[dbo].[dbasp_GetADUserGroups] 'virtuoso\sledridge'

END
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetADUserGroups] TO [public]
GO
