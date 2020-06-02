SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Backup_Retention_RestoreScript]
		(
		@DBName					SYSNAME
		,@PrimaryFile_Path		VarChar(2000)
		,@PrimaryFile_Mask		VarChar(2000)
		,@SupportFile_Path		VarChar(2000)
		,@SupportFile_Mask		VarChar(2000)
		,@OverrideXML			XML				= NULL OUT
		,@syntax_out			VarChar(max)	= NULL OUT
		)
AS
BEGIN

	SELECT		@PrimaryFile_Mask = LEFT(@PrimaryFile_Mask,CHARINDEX('_SET_',@PrimaryFile_Mask))+'*'
	SELECT		@SupportFile_Mask = LEFT(@SupportFile_Mask,CHARINDEX('_SET_',@SupportFile_Mask))+'*'

	--SELECT		@PrimaryFile_Mask	= REPLACE(REPLACE(@PrimaryFile_Mask,'_SET_[0-9][0-9]_OF_[0-9][0-9].cBAK',''),'_SET_[0-9][0-9]_OF_[0-9][0-9].cDIF','')
	--			,@SupportFile_Mask	= REPLACE(REPLACE(@SupportFile_Mask,'_SET_[0-9][0-9]_OF_[0-9][0-9].cBAK',''),'_SET_[0-9][0-9]_OF_[0-9][0-9].cDIF','')


	IF NULLIF(@SupportFile_Mask,'') IS NOT NULL
	BEGIN
		EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
				@LeaveNORECOVERY	= 1
				,@FilePath			= @SupportFile_Path
				,@ForceFileName		= @SupportFile_Mask
				,@DBName			= @DBName
				,@Mode				= 'RD'
				,@Verbose			= -1
				,@FullReset         = 1
				,@IgnoreSpaceLimits	= 1
				,@UseGO				= 0
				,@UseTryCatch		= 0
				,@syntax_out		= @syntax_out		OUTPUT
				,@OverrideXML		= @OverrideXML		OUTPUT


		--EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
		--		@FilePath			= @PrimaryFile_Path
		--		,@ForceFileName		= @PrimaryFile_Mask
		--		,@DBName			= @DBName
		--		,@Mode				= 'RD'
		--		,@Verbose			= -1
		--		,@FullReset         = 1
		--		,@IgnoreSpaceLimits	= 1
		--		,@UseGO				= 0
		--		,@UseTryCatch		= 0
		--		,@syntax_out		= @syntax_out		OUTPUT
		--		,@OverrideXML		= @OverrideXML		OUTPUT
	END
	--ELSE


	EXEC [DBAOps].[dbo].[dbasp_format_BackupRestore]
			@FilePath			= @PrimaryFile_Path
			,@ForceFileName		= @PrimaryFile_Mask
			,@DBName			= @DBName
			,@Mode				= 'RD'
			,@Verbose			= -1
			,@FullReset         = 1
			,@IgnoreSpaceLimits	= 1
			,@UseGO				= 0
			,@UseTryCatch		= 0
			,@syntax_out		= @syntax_out		OUTPUT
			,@OverrideXML		= @OverrideXML		OUTPUT


	SELECT	DBAOps.dbo.dbaudf_FormatXML2String(@OverrideXML) [OverrideXML]
			,@syntax_out [SyntaxOutput]
			,'EXEC DBAOps.dbo.[dbasp_Restore]
		@DBName			= ''<$DBName$>''
		,@FromServer			= ''<$ServerName$>''


		PARAMETER				DEFAULT		DESCRIPTION

		@dbname				NULL		Name of Database to Restore
		@NewDBName			NULL		New Name if Changing from the Original
		@FromServer				NULL		The Server FQDN from which the database comes (real name, not alias) ex. SDCPROSQL01.DB.VIRTUOSO.COM
		@FilePath				NULL		Only used to force a restore from a nonstandard location
		@FileGroups				NULL		Only used to restore a single file group (if the file group was backed up independently)
		@ForceFileName			NULL		Only used to force a restore from a nonstandard location or naming convention
		@LeaveNORecovery		0			Leave the database in restoring mode so that additional diff or tranlog backups can be applied or when implementing replication/mirroring/availabilities/log shipping
		@NoFullRestores			0			Only offer restore of diff or tranlogs, used for adding to a database in restoring mode
		@NoDifRestores			0			Do not apply diff if it exist, just restore full
		@NoLogRestores			1			Do not apply logs if they exist
		@OverrideXML			NULL		Used to specify new location to place restored files
		@BufferCount				100			Used to override MS Standard value to improve performance (WARNING: can Cause Memory problems)
		@MaxTransferSize			4194304		Used to override MS Standard value to improve performance (WARNING: can Cause Memory problems)
		@Verbose				0			Values from -1 = silent to 2 = Extremely verbose add messages to output
		@FullReset				1			Force restore over an existing database (will error if 0 and database exists)
		@post_shrink				0			Force a full shrink of data and log devices after restore to remove all free space
		@post_shrink_OnlyLog		1			Force a shrink of only the log file to its default empty size
		@post_set_recovery		''SIMPLE''		Which recovery model to leave the database as
		@Debug					0			Shows additional debug info in the output including an example value for the @OverrideXML parameter to use as a template
		@NoExec					0			Go through the steps but do not actually do the restore
		@NoSnap				1			Do not generate a snapshot after restore
		@NoRevert				1			Do not revert instead of restore if date is the same
		@ForceRevert				0			Force a revert even if the backup file is newer
		@IgnoreAGRestrict			0			Ignore restrictions from database being in availability group
		@ForceBHLID				NULL		Only restore backup with a specific BHLID (used to ensure encryption key matches other databases)
		@DropAllCustomStats		1			Drop all custom stats after the restore
		@PreShrinkAllLogs			1			Shrink all other database logs to free up space before the restore is attempted


		' [RestoreSproc]


END


/*


EXEC	DBAOps.dbo.dbasp_Backup_Retention_RestoreScript
		@DBName					= 'dmbooking'
		,@PrimaryFile_Path		= '\\SDCPROFS.virtuoso.com\DatabaseBackups\SDCPRODM01.db.virtuoso.com'
		,@PrimaryFile_Mask		= 'dmbooking_DB_20180831010123_SET_01_OF_32.cBAK'
		,@SupportFile_Path		= ''
		,@SupportFile_Mask		= ''


SELECT		*
FROM		[dbaops].[dbo].[dbaudf_BackupScripter_GetBackupFiles] ('dmbooking','\\SDCPROFS.virtuoso.com\DatabaseBackups\SDCPRODM01.db.virtuoso.com',0,'dmbooking_DB_20180831010123_SET_01_OF_32.cBAK')





*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_Backup_Retention_RestoreScript] TO [public]
GO
