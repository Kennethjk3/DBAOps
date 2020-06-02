SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_BackupScripter_GetFileList]
		(
		@DBName			SYSNAME
		,@NewDBName		SYSNAME
		,@SetSize			INT
		,@FileName		VarChar(MAX)
		,@FullPathName		VarChar(MAX)
		,@OverrideXML		XML
		,@NOW			VarChar(20)
		,@DataPath		VarChar(500)
		,@NDFPath			VarChar(500)
		,@LogPath			VarChar(500)
		)

RETURNS TABLE AS RETURN
(

	SELECT		T1.*
			,New_PhysicalName	= REPLACE(COALESCE	(
								REPLACE(T5.[New_PhysicalName],'$DT$',@NOW)	/* MANUAL OVERRIDE */
								,T6.PhysicalName	/* EXISTING FILE IN RESTORING MODE */
								,REPLACE(REPLACE(COALESCE(
					/* DBAOps OVERRIDE */			T2.[detail03]
					--/* DBAOps FILE OVERRIDE */		,T3.[NewPath]
					--/* DBAOps EXTENSION OVERRIDE */	,T4.[NewPath]
					/* DEFAULT NDF SHARE PATH */		,CASE	WHEN REPLACE(DBAOps.dbo.dbaudf_GetExtensionFromFile(T1.[PhysicalName]),'.','') = 'ndf' THEN @NDFPath
					/* DEFAULT MDF SHARE PATH */		WHEN T1.TYPE = 'D' THEN @DataPath
					/* DEFAULT LDF SHARE PATH */		ELSE @LogPath END
										)
										+'\|','\\|','\'),'\|','\')
					/* DATETIMESTAMP */			+ CASE WHEN @DBName != @NewDBName THEN @NOW + '_' ELSE '' END
										+ DBAOps.dbo.dbaudf_GetFileFromPath(T1.PhysicalName)
								),'$DT$',@NOW)
			,BackupFileName		= @FileName

	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	-- T1					GET FILES FOR DIRECTORY
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	FROM		[DBAOps].[dbo].[dbaudf_RestoreFileList](@FullPathName) T1
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	-- T2		USE [DBAOps].[dbo].[local_control] FOR "restore_override" ENTRIES
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	LEFT JOIN	DBAOps.dbo.local_control T2
		ON	T2.subject = 'restore_override'
		AND	T2.detail01 = @NewDBName
		AND	T2.detail02 = T1.LogicalName
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	-- T3		USE [DBAOps].[dbo].[ControlTable] ONLY FOR "auto_restore_file" ENTRIES
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	--LEFT JOIN	(
	--		SELECT		DBAOps.dbo.dbaudf_ReturnPart(REPLACE([subject],'_','|'),3) [Type]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),1) ELSE [control01] END [DBName]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),2) END [DeviceName]
	--				,[control02] [ServerName]
	--				,[control03] [NewPath]
	--		FROM		[DBAOps].[dbo].[ControlTable]
	--		WHERE		subject like 'auto_restore_file'
	--		) T3
	--	ON	T3.[ServerName] = @@SERVERNAME
	--	AND	T3.[DBName] = @NewDBName
	--	AND	T3.[DeviceName] = T1.LogicalName

	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	-- T4	USE [DBAOps].[dbo].[ControlTable] ONLY FOR "auto_restore_*" ENTRIES FOR FILE EXTENSION
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	--LEFT JOIN	(
	--		SELECT		DBAOps.dbo.dbaudf_ReturnPart(REPLACE([subject],'_','|'),3) [Type]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),1) ELSE [control01] END [DBName]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),2) END [DeviceName]
	--				,[control02] [ServerName]
	--				,[control03] [NewPath]
	--		FROM		[DBAOps].[dbo].[ControlTable]
	--		WHERE		subject like 'auto_restore%'
	--			AND	subject NOT like 'auto_restore_file'
	--		) T4
	--	ON	T4.[ServerName] = @@SERVERNAME
	--	AND	T4.[DBName] = @NewDBName
	--	AND	T4.[Type] = REPLACE(DBAOps.dbo.dbaudf_GetExtensionFromFile(T1.[PhysicalName]),'.','')

	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	-- T5				USE XML ENTRIES FOR SPECIFIC FILES
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	LEFT JOIN	(
			SELECT		a.x.value('@LogicalName','sysname') [LogicalName]
						,a.x.value('@PhysicalName','varchar(500)') [PhysicalName]
						,a.x.value('@New_PhysicalName','varchar(500)') [New_PhysicalName]
			FROM		@OverrideXML.nodes('/RestoreFileLocations/*') a(x)
			) T5
		ON	T5.[LogicalName] = T1.LogicalName
		AND	T5.[PhysicalName] = T1.PhysicalName


	LEFT JOIN	(
			SELECT		name [LogicalName]
						,physical_name [PhysicalName]
			FROM		sys.master_files
			WHERE		DB_Name(database_id) = @NewDBName
				AND	(
					DATABASEPROPERTYEX(@NewDBName,'IsInStandBy') = 1
				   OR	DATABASEPROPERTYEX(@NewDBName,'Status') = 'RESTORING'
					)
			) T6
		ON	T6.LogicalName = T1.LogicalName

)
GO
