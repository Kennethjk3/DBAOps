SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupScripter_GetFileList]
		(
		@DBName			SYSNAME
		,@NewDBName		SYSNAME
		,@BackupEngine		VarChar(50)
		,@SetSize		INT
		,@FileName		VarChar(MAX)
		,@FullPathName		VarChar(MAX)
		,@OverrideXML		XML
		)


/****************************************************************************
<CommentHeader>
  <VersionControl>
    <DatabaseName>DBAOps</DatabaseName>
    <SchemaName>dbo</SchemaName>
    <ObjectType>SQL_STORED_PROCEDURE</ObjectType>
    <ObjectName>dbasp_BackupScripter_GetFileList</ObjectName>
    <Version>_</Version>
    <Build Number="_" Application="_" Branch="_" />
    <Created By="_" On="2013-10-17 13:34:00" />
    <Modifications>
      <Mod By="" On="" Reason="" />
    </Modifications>
  </VersionControl>
  <Purpose>_</Purpose>
  <Description>_</Description>
  <Dependencies>
    <Object Type="" Schema="" Name="" VersionCompare="" Version="" />
    <Object Type="FN" Schema="dbo" Name="dbaudf_getShareUNC" VersionCompare="" Version="" />
    <Object Type="FN" Schema="dbo" Name="dbaudf_ReturnPart" VersionCompare="" Version="" />
    <Object Type="U " Schema="dbo" Name="Local_Control" VersionCompare="" Version="" />
  </Dependencies>
  <Parameters>
    <Parameter No="1" Type="sysname" Name="@DBName" Description="" />
    <Parameter No="2" Type="sysname" Name="@NewDBName" Description="" />
    <Parameter No="3" Type="varchar" Name="@BackupEngine" Description="" />
    <Parameter No="4" Type="int" Name="@SetSize" Description="" />
    <Parameter No="5" Type="varchar" Name="@FileName" Description="" />
    <Parameter No="6" Type="varchar" Name="@FullPathName" Description="" />
    <Parameter No="7" Type="xml" Name="@OverrideXML" Description="" />
    <Parameter No="" Type="" Name="" Description="" />
  </Parameters>
  <Permissions>
    <Perm Type="" Priv="" To="" With="" />
  </Permissions>
  <Examples>
    <Example Name="" Text="" />
  </Examples>
</CommentHeader>
*****************************************************************************/
AS


BEGIN
	DECLARE		@CMD			VarChar(MAX)
			,@NOW			VarChar(20)
			,@LogPath		VarChar(500)
			,@DataPath		VarChar(500)
			,@NDFPath		VarChar(500)


	DECLARE		@filelist		TABLE
			(
			LogicalName		NVARCHAR(128) NULL,
			PhysicalName		NVARCHAR(260) NULL,
			type			CHAR(1),
			FileGroupName		NVARCHAR(128) NULL,
			SIZE			NUMERIC(20,0),
			MaxSize			NUMERIC(20,0),
			FileId			BIGINT,
			CreateLSN		NUMERIC(25,0),
			DropLSN			NUMERIC(25,0),
			UniqueId		VARCHAR(50),
			ReadOnlyLSN		NUMERIC(25,0),
			ReadWriteLSN		NUMERIC(25,0),
			BackupSizeInBytes	BIGINT,
			SourceBlockSize		INT,
			FileGroupId		INT,
			LogGroupGUID		VARCHAR(50) NULL,
			DifferentialBaseLSN	NUMERIC(25,0),
			DifferentialBaseGUID	VARCHAR(50),
			IsReadOnly		BIT,
			IsPresent		BIT,
			TDEThumbprint		NVARCHAR(128) NULL,
			New_PhysicalName	NVARCHAR(1000) NULL,
			BackupFileName		NVARCHAR(4000) NULL
			)


	SELECT		@NOW			= REPLACE(REPLACE(REPLACE(CONVERT(VarChar(50),getdate(),120),'-',''),':',''),' ','')
			,@DataPath		= DBAOps.[dbo].[dbaudf_GetSharePath](DBAOps.[dbo].[dbaudf_getShareUNC]('mdf'))
			,@NdfPath		= COALESCE(DBAOps.[dbo].[dbaudf_GetSharePath](DBAOps.[dbo].[dbaudf_getShareUNC]('ndf')),@DataPath)
			,@LogPath		= DBAOps.[dbo].[dbaudf_GetSharePath](DBAOps.[dbo].[dbaudf_getShareUNC]('ldf'))
			,@NewDBName		= COALESCE(NULLIF(@NewDBName,''),@DBName)


	INSERT INTO	@filelist (LogicalName,PhysicalName,type,FileGroupName,SIZE,MaxSize,FileId,CreateLSN,DropLSN,UniqueId,ReadOnlyLSN,ReadWriteLSN,BackupSizeInBytes,SourceBlockSize,FileGroupId,LogGroupGUID,DifferentialBaseLSN,DifferentialBaseGUID,IsReadOnly,IsPresent,TDEThumbprint)
	SELECT		*
	FROM		[DBAOps].[dbo].[dbaudf_RestoreFileList](@FullPathName)


	UPDATE		T1
		SET	New_PhysicalName	= COALESCE	(
								T4.[New_PhysicalName] /* MANUAL OVERRIDE */
								,COALESCE	(
						/* DBAOps OVERRIDE */		T2.[detail03]
						--/* DBAOps OVERRIDE */	,T3.[NewPath]
						/* DEFAULT NDF SHARE PATH */	,CASE	WHEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE(T1.[PhysicalName],'.','|'),2) = 'ndf' THEN @NDFPath
						/* DEFAULT MDF SHARE PATH */		WHEN T1.TYPE = 'D' THEN @DataPath
						/* DEFAULT LDF SHARE PATH */		ELSE @LogPath END
										)
										+ '\'
						/* DATETIMESTAMP */		+ CASE WHEN @DBName != @NewDBName THEN @NOW + '_' ELSE '' END
										+ DBAOps.dbo.dbaudf_GetFileFromPath(T1.PhysicalName)
								)
			,BackupFileName		= CASE WHEN @SetSize > 1 THEN @FileName ELSE @FullPathName END
	FROM		@filelist T1
	LEFT JOIN	DBAOps.dbo.local_control T2
		ON	T2.subject = 'restore_override'
		AND	T2.detail01 = @NewDBName
		AND	T2.detail02 = T1.LogicalName
	--LEFT JOIN	(
	--		SELECT		DBAOps.dbo.dbaudf_ReturnPart(REPLACE([subject],'_','|'),3) [Type]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),1) ELSE [control01] END [DBName]
	--				,CASE subject WHEN 'auto_restore_file' THEN DBAOps.dbo.dbaudf_ReturnPart(REPLACE([control01],'\','|'),2) END [DeviceName]
	--				,[control02] [ServerName]
	--				,[control03] [NewPath]
	--		FROM		[DBAOps].[dbo].[ControlTable]
	--		WHERE		subject like 'auto_restore%'
	--		) T3
	--	ON	T3.[ServerName] = @@SERVERNAME
	--	AND	T3.[DBName] = @NewDBName
	--	AND	(T3.[DeviceName] = T1.LogicalName OR T3.[DeviceName] IS NULL)
	--	AND	(T3.[Type] = DBAOps.dbo.dbaudf_ReturnPart(REPLACE(T1.[PhysicalName],'.','|'),2) OR T3.[Type] IS NULL)
	LEFT JOIN	(
			SELECT		a.x.value('@LogicalName','sysname') [LogicalName]
					,a.x.value('@PhysicalName','varchar(500)') [PhysicalName]
					,a.x.value('@New_PhysicalName','varchar(500)') [New_PhysicalName]
			FROM		@OverrideXML.nodes('/RestoreFileLocations/*') a(x)
			) T4
		ON	T4.[LogicalName] = T1.LogicalName
		AND	T4.[PhysicalName] = T1.PhysicalName


	SELECT		*
	FROM		@filelist
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupScripter_GetFileList] TO [public]
GO
