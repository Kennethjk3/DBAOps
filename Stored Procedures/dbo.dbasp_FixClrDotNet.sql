SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FixClrDotNet]
AS
DECLARE		@AssemblyName		VarChar(8000)
DECLARE		@OldPathName		VarChar(8000)
DECLARE		@NewPathName		VarChar(8000)
DECLARE		@AlterCommand		VarChar(8000)
DECLARE		@MSG			VarChar(8000)
DECLARE		AssemblyCursor		CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT		'ALTER ASSEMBLY [' + T3.name + '] FROM '''+ T1.FullPathName + ''''
		,T3.Name [AssemblyName]
		,T1.FullPathName [NewPath]
		,T2.Name [OldPath]
--FROM		DBAOps.dbo.dbaudf_DirectoryList2('C:\WINDOWS\Microsoft.NET\Framework\',null,1) T1
FROM		DBAOps.dbo.dbaudf_DirectoryList2('C:\WINDOWS\assembly\',null,1) T1 -- ACTUALLY LOOK IN THE GAC
JOIN		sys.assembly_files T2
	ON	T1.Name = DBAOps.dbo.dbaudf_GetFileFromPath(T2.name)
JOIN		sys.assemblies T3
	ON	T2.assembly_id = T3.assembly_id
WHERE		T3.name != 'Microsoft.SqlServer.Types'


OPEN AssemblyCursor;
FETCH AssemblyCursor INTO @AlterCommand,@AssemblyName,@NewPathName,@OldPathName;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		----------------------------
		---------------------------- CURSOR LOOP TOP

		BEGIN TRY
			exec(@AlterCommand)
			SET @MSG = 'Sucessfully Updated Assembly %s from %s replacing %s'
			RAISERROR (@MSG,-1,-1,@AssemblyName,@NewPathName,@OldPathName) WITH NOWAIT
		END TRY
		BEGIN CATCH

			SET @MSG = CASE ERROR_NUMBER()
				    WHEN 6285 THEN 'No update necessary (MVID match) for %s'
				    WHEN 6501 THEN 'Physical assembly not found  for %s at specified location (SQL Error 6501) %s'
				    ELSE ERROR_MESSAGE() + ' (SQL Error ' + convert(varchar(10), ERROR_NUMBER()) + ') | %s | %s | %s'
				    END
			RAISERROR (@MSG,-1,-1,@AssemblyName,@OldPathName,@NewPathName) WITH NOWAIT
		END CATCH


		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM AssemblyCursor INTO @AlterCommand,@AssemblyName,@NewPathName,@OldPathName;
END
CLOSE AssemblyCursor;
DEALLOCATE AssemblyCursor;
GO
GRANT EXECUTE ON  [dbo].[dbasp_FixClrDotNet] TO [public]
GO
