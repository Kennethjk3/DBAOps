SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_UpdateDDLAudit]
		(
		@DBName				sysname
		,@central_server	sysname = NULL
		)
/****************************************************************************
<CommentHeader>
	<VersionControl>
 		<DatabaseName>DBAOps</DatabaseName>
		<SchemaName>dbo</SchemaName>
		<ObjectType>STORED PROCEDURE</ObjectType>
		<ObjectName>dbasp_UpdateDDLAudit</ObjectName>
		<Version>1.2.1</Version>
		<Build Number="" Application="" Branch=""/>
		<Created By="Steve Ledridge" On="3/22/2011"/>
		<Modifications>
			<Mod By="" On="" Reason=""/>
			<Mod By="Steve Ledridge" On="04292013" Reason="Change CentralServer lookup to DBAOps and changed DEPLinfo to DBAOps"/>
		</Modifications>
	</VersionControl>
	<Purpose>Used to deploy DDL Audit Table and Trigger to a Database</Purpose>
	<Description>This sproc will create or update the BuildSchemaChanges table and the tr_AuditDDLChange Database Trigger</Description>
	<Dependencies>
		<Object Type="" Schema="" Name="" VersionCompare="" Version=""/>
	</Dependencies>
	<Parameters>
		<Parameter Type="sysname" Name="@DBName" Desc="Name of Database to Deploy to"/>
	</Parameters>
	<Permissions>
		<Perm Type="" Priv="" To="" With=""/>
	</Permissions>
</CommentHeader>
*****************************************************************************/
AS
BEGIN
	-- LOOK UP CENTRAL SERVER IF NOT PASSED IN
	SELECT		@central_server = COALESCE(@central_server,[env_detail])
	FROM		[DBAOps].[dbo].[local_serverenviro]
	WHERE		env_type = 'CentralServer'

	IF nullif(@central_server,'') IS NULL RETURN -1

	DECLARE @RC					INT
			,@COMMAND			VarChar(8000)
			,@cEGUID			varChar(50)
			,@ID				UniqueIdentifier
			,@ScriptRoot		VarChar(max) -- ENDS WITH SLASH
			,@ScriptPath		VarChar(max) -- FILE NAME ONLY, NO SLASH
			,@TSQL				VarChar(max)


	SELECT	@ScriptRoot	= '\\'+@central_server+'\'+@central_server+'_builds\DDL_AUDIT\' -- ENDS WITH SLASH
			,@ID		= NEWID()


	SELECT @cEGUID = DBAOps.[dbo].[dbaudf_GetDEPLInstanceID]()

	BEGIN -- DEPLOY


		-- LOG START DEPLOY
		EXECUTE [DBAOps].[dbo].[dbasp_LogEvent]
			@cEGUID = @cEGUID,@cERE_ForceScreen = 1,@cEMethod_Screen = 1,@cEMethod_TableLocal = 1
			,@cEModule		= 'DDL Audit'
			,@cECategory	= 'Deploy'
			,@cEEvent		= 'Start'
			,@cEMessage		= @DBName


				--DEPLOY TABLE
				SELECT	@ScriptPath	= @ScriptRoot + 'BuildSchemaChanges.sql'
						,@COMMAND	= 'sqlcmd -S' + @@servername + ' -d' + @DBName + ' -u -I -E -b -i' + @ScriptPath
				EXEC	@RC			= master.sys.xp_cmdshell @COMMAND, no_output


				--DEPLOY TRIGGER
				SELECT	@ScriptPath	= @ScriptRoot + 'tr_AuditDDLChange.sql'
						,@COMMAND	= 'sqlcmd -S' + @@servername + ' -d' + @DBName + ' -u -I -E -b -i' + @ScriptPath
				EXEC	@RC			= master.sys.xp_cmdshell @COMMAND, no_output


				IF @DBName = 'DBAOps'
				BEGIN
					--DEPLOY TRIGGER
					SELECT	@ScriptPath	= @ScriptRoot + 'tr_ControlLocal_Update.sql'
							,@COMMAND	= 'sqlcmd -S' + @@servername + ' -d' + @DBName + ' -u -I -E -b -i' + @ScriptPath
					EXEC	@RC			= master.sys.xp_cmdshell @COMMAND, no_output
				END


				IF @DBName = 'DBAOps'
				BEGIN

					--DEPLOY SPROC
					SELECT	@ScriptPath	= @ScriptRoot + 'dbasp_UpdateDDLAudit.sql'
							,@COMMAND	= 'sqlcmd -S' + @@servername + ' -d' + @DBName + ' -u -I -E -b -i' + @ScriptPath
					EXEC	@RC			= master.sys.xp_cmdshell @COMMAND, no_output

					--DEPLOY SPROC
					SELECT	@ScriptPath	= @ScriptRoot + 'dbasp_UpdateDDLAudit_AllInstance.sql'
							,@COMMAND	= 'sqlcmd -S' + @@servername + ' -d' + @DBName + ' -u -I -E -b -i' + @ScriptPath
					EXEC	@RC			= master.sys.xp_cmdshell @COMMAND, no_output

				END


		-- LOG COMPLETE DEPLOY
		EXECUTE [DBAOps].[dbo].[dbasp_LogEvent]
			@cEGUID = @cEGUID,@cERE_ForceScreen = 1,@cEMethod_Screen = 1,@cEMethod_TableLocal = 1
			,@cEModule		= 'DDL Audit'
			,@cECategory	= 'Deploy'
			,@cEEvent		= 'Complete'
			,@cEMessage		= @DBName


	END -- DEPLOY


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_UpdateDDLAudit] TO [public]
GO
