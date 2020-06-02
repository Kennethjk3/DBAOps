SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CheckEfectivePermissions]
							(
							@LoginName			SYSNAME
							,@DBName			SYSNAME
							,@ObjectSchema		SYSNAME = NULL
							,@ObjectName		SYSNAME = NULL
							)
AS
DECLARE @SQL			VarChar(8000)


SET		@SQL			= '
USE ['+@DBName+'];
EXECUTE AS LOGIN = '''+@LoginName+'''
SELECT * FROM fn_my_permissions(NULL, ''SERVER'')
UNION ALL
SELECT * FROM fn_my_permissions(NULL, ''DATABASE'')
UNION ALL
SELECT * FROM fn_my_permissions('+COALESCE(''''+@ObjectSchema+'.'+@ObjectName+'''','NULL')+', ''OBJECT'');
REVERT '


EXEC(@SQL)


/*		EXAMPLE USAGE


EXEC  DBAOps.dbo.dbasp_CheckEfectivePermissions
		@LoginName		= 'SDCPROSQL01\anonuser'
		,@DBName		= 'ComposerSL'
		,@ObjectSchema	= 'dbo'
		,@ObjectName	= 'GetUserRoles'


*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_CheckEfectivePermissions] TO [public]
GO
