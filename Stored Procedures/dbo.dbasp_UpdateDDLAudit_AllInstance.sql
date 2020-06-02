SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_UpdateDDLAudit_AllInstance]
		(
		@central_server	sysname = NULL
		)
/****************************************************************************
<CommentHeader>
	<VersionControl>
 		<DatabaseName>DBAOps</DatabaseName>
		<SchemaName>dbo</SchemaName>
		<ObjectType>STORED PROCEDURE</ObjectType>
		<ObjectName>dbasp_UpdateDDLAudit_AllInstance</ObjectName>
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

	DECLARE @RC		INT
	DECLARE	@DBName		sysname
	DECLARE	@cEGUID		varChar(50)
	DECLARE @ID		UniqueIdentifier
	DECLARE @TSQL		varchar(max)


	SET		@ID			= NEWID()


	DECLARE DeployCursor CURSOR
	FOR
	SELECT	Name
	FROM	master.sys.databases
	WHERE	Name IN (SELECT [db_name] FROM [DBAOps].[dbo].[db_sequence])  -- ONLY USE DEPLOYABLE DB's
		OR	Name IN ('DBAOps','DBAOps','master','model','msdb')			-- AND THESE OPS OR SYSTEM DB's


	SELECT @cEGUID = DBAOps.[dbo].[dbaudf_GetDEPLInstanceID]()

	-- LOG START DEPLOY
	EXECUTE [DBAOps].[dbo].[dbasp_LogEvent]
		@cEGUID = @cEGUID,@cERE_ForceScreen = 1,@cEMethod_Screen = 1,@cEMethod_TableLocal = 1
		,@cEModule		= 'DDL Audit'
		,@cECategory	= 'Deploy ALL Instance'
		,@cEEvent		= 'Start'
		,@cEMessage		= @@ServerName


	OPEN DeployCursor
	-- GET DB
	FETCH NEXT FROM DeployCursor INTO @DBNAME
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			--DEPLOY TO DB
			EXEC	@RC	= DBAOps.dbo.dbasp_UpdateDDLAudit @DBNAME, @central_server
		END
		-- GET NEXT DB
		FETCH NEXT FROM DeployCursor INTO @DBNAME
	END
	CLOSE DeployCursor
	DEALLOCATE DeployCursor


	-- LOG START DEPLOY
	EXECUTE [DBAOps].[dbo].[dbasp_LogEvent]
		@cEGUID = @cEGUID,@cERE_ForceScreen = 1,@cEMethod_Screen = 1,@cEMethod_TableLocal = 1
		,@cEModule		= 'DDL Audit'
		,@cECategory	= 'Deploy ALL Instance'
		,@cEEvent		= 'Complete'
		,@cEMessage		= @@ServerName


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_UpdateDDLAudit_AllInstance] TO [public]
GO
