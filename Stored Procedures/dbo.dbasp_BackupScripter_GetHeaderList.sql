SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_BackupScripter_GetHeaderList]
		(
		@BackupEngine		VarChar(50)
		,@SetSize		INT
		,@FileName		VarChar(MAX)
		,@FullPathName		VarChar(MAX)
		)


/****************************************************************************
<CommentHeader>
  <VersionControl>
    <DatabaseName>DBAOps</DatabaseName>
    <SchemaName>dbo</SchemaName>
    <ObjectType>SQL_STORED_PROCEDURE</ObjectType>
    <ObjectName>dbasp_BackupScripter_GetHeaderList</ObjectName>
    <Version>_</Version>
    <Build Number="_" Application="_" Branch="_" />
    <Created By="_" On="2013-10-17 13:39:19" />
    <Modifications>
      <Mod By="" On="" Reason="" />
    </Modifications>
  </VersionControl>
  <Purpose>_</Purpose>
  <Description>_</Description>
  <Dependencies>
    <Object Type="" Schema="" Name="" VersionCompare="" Version="" />
  </Dependencies>
  <Parameters>
    <Parameter No="1" Type="varchar" Name="@BackupEngine" Description="" />
    <Parameter No="2" Type="int" Name="@SetSize" Description="" />
    <Parameter No="3" Type="varchar" Name="@FileName" Description="" />
    <Parameter No="4" Type="varchar" Name="@FullPathName" Description="" />
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


	DECLARE		@headerlist		TABLE
			(
			BackupName		nvarchar(128),
			BackupDescription	nvarchar(255) ,
			BackupType		smallint ,
			ExpirationDate		datetime ,
			Compressed		bit ,
			Position		smallint ,
			DeviceType		tinyint ,
			UserName		nvarchar(128) ,
			ServerName		nvarchar(128) ,
			DatabaseName		nvarchar(128) ,
			DatabaseVersion		int ,
			DatabaseCreationDate	datetime ,
			BackupSize		numeric(20,0) ,
			FirstLSN		numeric(25,0) ,
			LastLSN			numeric(25,0) ,
			CheckpointLSN		numeric(25,0) ,
			DatabaseBackupLSN	numeric(25,0) ,
			BackupStartDate		datetime ,
			BackupFinishDate	datetime ,
			SortOrder		smallint ,
			CodePage		smallint ,
			UnicodeLocaleId		int ,
			UnicodeComparisonStyle	int ,
			CompatibilityLevel	tinyint ,
			SoftwareVendorId	int ,
			SoftwareVersionMajor	int ,
			SoftwareVersionMinor	int ,
			SoftwareVersionBuild	int ,
			MachineName		nvarchar(128) ,
			Flags			int ,
			BindingID		uniqueidentifier ,
			RecoveryForkID		uniqueidentifier ,
			Collation		nvarchar(128) ,
			FamilyGUID		uniqueidentifier ,
			HasBulkLoggedData	bit ,
			IsSnapshot		bit ,
			IsReadOnly		bit ,
			IsSingleUser		bit ,
			HasBackupChecksums	bit ,
			IsDamaged		bit ,
			BeginsLogChain		bit ,
			HasIncompleteMetaData	bit ,
			IsForceOffline		bit ,
			IsCopyOnly		bit ,
			FirstRecoveryForkID	uniqueidentifier ,
			ForkPointLSN		numeric(25,0) NULL,
			RecoveryModel		nvarchar(60) ,
			DifferentialBaseLSN	numeric(25,0) NULL,
			DifferentialBaseGUID	uniqueidentifier ,
			BackupTypeDescription	nvarchar(60) ,
			BackupSetGUID		uniqueidentifier NULL ,
			CompressedBackupSize	bigint NULL,
			containment		bit,
			BackupFileName		[nvarchar](4000) NULL,
			[BackupDateRange_Start]	datetime NULL,
			[BackupDateRange_End]	datetime NULL,
			[BackupChainStartDate]	datetime NULL,
			[BackupLinkStartDate]	datetime NULL
			)


	IF OBJECT_ID('tempdb..#headerlist') IS NOT NULL
		DROP TABLE #headerlist


	CREATE TABLE #headerlist	(
					[id] INT IDENTITY PRIMARY KEY
					, [Data] VarChar(max) NULL
					)


	INSERT INTO @headerlist	(
				BackupName
				,BackupDescription
				,BackupType
				,ExpirationDate
				,Compressed
				,Position
				,DeviceType
				,UserName
				,ServerName
				,DatabaseName
				,DatabaseVersion
				,DatabaseCreationDate
				,BackupSize
				,FirstLSN
				,LastLSN
				,CheckpointLSN
				,DatabaseBackupLSN
				,BackupStartDate
				,BackupFinishDate
				,SortOrder
				,CodePage
				,UnicodeLocaleId
				,UnicodeComparisonStyle
				,CompatibilityLevel
				,SoftwareVendorId
				,SoftwareVersionMajor
				,SoftwareVersionMinor
				,SoftwareVersionBuild
				,MachineName
				,Flags
				,BindingID
				,RecoveryForkID
				,Collation
				,FamilyGUID
				,HasBulkLoggedData
				,IsSnapshot
				,IsReadOnly
				,IsSingleUser
				,HasBackupChecksums
				,IsDamaged
				,BeginsLogChain
				,HasIncompleteMetaData
				,IsForceOffline
				,IsCopyOnly
				,FirstRecoveryForkID
				,ForkPointLSN
				,RecoveryModel
				,DifferentialBaseLSN
				,DifferentialBaseGUID
				,BackupTypeDescription
				,BackupSetGUID
				,CompressedBackupSize
				,Containment
				)
	SELECT		*
	FROM		[DBAOps].[dbo].[dbaudf_RestoreHeader](@FullPathName)


	UPDATE		@headerlist
		SET	BackupFileName = CASE WHEN @SetSize > 1 THEN @FileName ELSE @FullPathName END


	SELECT		*
	FROM		@headerlist
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_BackupScripter_GetHeaderList] TO [public]
GO
