SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetADGroupMembers]
    (
      @groupName VARCHAR(35) 
    )
AS 
DECLARE		@dn		VarChar(4000)
DECLARE		@tsql	VARCHAR(4000)

SELECT		@dn = distinguishedName
from		openquery	(ADSI,'SELECT cn, distinguishedName FROM ''LDAP://DC=virtuoso,DC=com'' WHERE objectCategory = ''group''')
WHERE		cn = @groupName

    SET @tsql = 'SELECT '''+@groupName+''' GroupName,sn LastName,GivenName FirstName,sAMAccountName DomainAccount,
department,manager,employeeID 
 FROM OPENQUERY(ADSI,'
        + '''SELECT sn,GivenName,sAMAccountName,department,manager,employeeID,userAccountControl 
FROM ''''LDAP://DC=virtuoso,DC=com''''
WHERE objectCategory = ''''Person'''' AND objectClass = ''''user''''
AND memberOf='''''+@dn+''''' ''' + ')'

    EXEC(@tsql)
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetADGroupMembers] TO [public]
GO
