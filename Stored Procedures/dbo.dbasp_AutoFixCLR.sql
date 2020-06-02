SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_AutoFixCLR]
AS
SET NOCOUNT ON
DROP TABLE IF EXISTS #CMDOutput

DECLARE	@central_server		SYSNAME
		,@ENVname			SYSNAME
		,@Path				VarChar(max)
		,@FileName			VarChar(max)
		,@sqlcmd			VarChar(8000)

CREATE TABLE	#CMDOutput	(cmdoutput nvarchar(max) null)

SELECT	@Path		= '\\' + REPLACE(@@SERVERNAME,'\'+@@SERVICENAME,'')+'\SQLBackups\dbasql'
		,@FileName	= @Path + '\DBAOps_CLR.SQL'
		,@sqlcmd		= 'sqlcmd -S' + @@servername + ' -dDBAOps -i' + @FileName + ' -E'

BEGIN TRY
	IF EXISTS (select * from DBAOps.dbo.dbaudf_DirectoryList2('c:\',null,0))
		RAISERROR('CLR dbaudf_DirectoryList2 Test Passed.',-1,-1) WITH NOWAIT
	IF EXISTS (Select * From DBAOps.dbo.dbaudf_ListDrives())
		RAISERROR('CLR dbaudf_ListDrives Test Passed.',-1,-1) WITH NOWAIT

	RAISERROR('All Tests Passed, No Changes Needed.',-1,-1) WITH NOWAIT
END TRY

BEGIN CATCH
	--PRINT		@SQLCMD
	RAISERROR('CLR Tests Failed, Reloading CLR From Local Share (%s)...',-1,-1,@FileName) WITH NOWAIT

	TRUNCATE TABLE	#CMDOutput
	INSERT INTO	#CMDOutput
	EXEC		master.sys.xp_cmdshell @sqlcmd

	IF NOT EXISTS	(SELECT * FROM #CMDOutput WHERE cmdoutput like '%C:\Windows\System32\ScriptSQLObject.exe written sucessfully%')
	BEGIN
		RAISERROR('  CLR Deployment From Local Share FAILED',-1,-1) WITH NOWAIT
	
		SELECT		@Path		= '\\SDCPROFS.virtuoso.com\CleanBackups\DBAOps'
					,@FileName	= @Path + '\DBAOps_CLR.SQL'
					,@sqlcmd	= 'sqlcmd -S' + @@servername + ' -dDBAOps -i' + @FileName + ' -E'

		--PRINT		@SQLCMD
		RAISERROR('   Reloading CLR From Central Server (%s)...',-1,-1,@FileName) WITH NOWAIT

		TRUNCATE TABLE	#CMDOutput
		INSERT INTO	#CMDOutput
		EXEC		master.sys.xp_cmdshell @sqlcmd

		IF NOT EXISTS	(SELECT * FROM #CMDOutput WHERE cmdoutput like '%C:\Windows\System32\ScriptSQLObject.exe written sucessfully%')
		BEGIN
			RAISERROR('  CLR Deployment From Central Server FAILED',-1,-1) WITH NOWAIT
			--SELECT @sqlcmd
			--SELECT * FROM #CMDOutput
		END
		ELSE
			RAISERROR('CLR Deployment Successfull',-1,-1) WITH NOWAIT
	END
	ELSE
		RAISERROR('CLR Deployment Successfull',-1,-1) WITH NOWAIT
END CATCH
GO
GRANT EXECUTE ON  [dbo].[dbasp_AutoFixCLR] TO [public]
GO
