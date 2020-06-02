SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FixOrphanedUsersInDB]
				(
				@DBName			SYSNAME
				,@FromServer	SYSNAME
				,@JustPrint		BIT		= 0
				)
AS
-- FIX LOGINS
DECLARE @FixScript	VarChar(8000)
DECLARE @CMD		VarChar(max)
DECLARE @Fixes		TABLE			(FixScript VarChar(8000))


SET		@CMD		= '
USE ['+@DBName+'];
SELECT	CASE
			WHEN u.isntuser = 1 AND EXISTS(SELECT * FROM sysusers WHERE NAME = REPLACE(u.Name,'''+@FromServer+'''+''\'',@@SERVERNAME+''\''))
				THEN ''-- MATCH ALREADY EXISTS --		USE ['+@DBName+'];DROP USER [''+u.Name+''];''
			WHEN u.isntuser = 1
				THEN ''USE ['+@DBName+'];ALTER USER [''+u.Name+''] WITH NAME = [''+REPLACE(u.Name,'''+@FromServer+'''+''\'',@@SERVERNAME+''\'')+''], LOGIN = [''+REPLACE(u.Name,'''+@FromServer+'''+''\'',@@SERVERNAME+''\'')+'']''
			ELSE		''USE ['+@DBName+'];exec sp_change_users_login ''''Update_One'''', ''''''+u.Name+'''''',''''''+REPLACE(u.Name,'''+@FromServer+'''+''\'',@@SERVERNAME+''\'')+''''''''
			END [FixScript]
FROM	sysusers	U
JOIN	sys.syslogins	L
	ON	u.name COLLATE SQL_Latin1_General_CP1_CI_AS = L.name COLLATE SQL_Latin1_General_CP1_CI_AS
	OR  REPLACE(u.Name COLLATE SQL_Latin1_General_CP1_CI_AS,'''+@FromServer+'''+''\'',@@SERVERNAME+''\'') = L.name COLLATE SQL_Latin1_General_CP1_CI_AS

WHERE	u.islogin = 1
AND		U.sid != L.sid
AND		u.name Not Like ''${{secrets.COMPANY_NAME}}\%''
and		u.issqlrole = 0
and		u.isapprole = 0
and		u.name != ''dbo''
and		u.name != ''guest''
and		u.name != ''INFORMATION_SCHEMA''
and		u.name != ''sys''
and		(
		(u.isntuser = 1 AND u.name Like '''+@FromServer+'''+''\%'')
		OR
		u.isntuser = 0
		)


'
INSERT INTO @Fixes
EXEC(@CMD)


DECLARE OrphanedUserCursor CURSOR
FOR
SELECT * FROM @Fixes


OPEN OrphanedUserCursor;
FETCH OrphanedUserCursor INTO @FixScript;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		----------------------------
		---------------------------- CURSOR LOOP TOP

		exec DBAOPS.dbo.dbasp_print @FixScript,1,1,1
		IF @JustPrint = 0
		BEGIN
			BEGIN TRY
				EXEC(@FixScript)
			END TRY
			BEGIN CATCH
				exec DBAOPS.dbo.dbasp_print 'Fix Failed...',1,1,1
			END CATCH
		END
		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM OrphanedUserCursor INTO @FixScript;
END
CLOSE OrphanedUserCursor;
DEALLOCATE OrphanedUserCursor;
GO
GRANT EXECUTE ON  [dbo].[dbasp_FixOrphanedUsersInDB] TO [public]
GO
