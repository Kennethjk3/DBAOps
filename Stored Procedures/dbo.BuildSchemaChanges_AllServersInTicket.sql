SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[BuildSchemaChanges_AllServersInTicket]
		(
		@GearsID		INT
		)
AS
BEGIN
	DECLARE @ServerName		varchar(40)
	DECLARE @LSName			varchar(40)
	DECLARE	@TSQL			VarChar(max)
	DECLARE	@CMD			VarChar(max)
	DECLARE	@CMD2			VarChar(8000)
	DECLARE	@DEPLInstanceID	VarChar(50)
	DECLARE	@ServerCnt		INT
	DECLARE	@NewInstanceID	UniqueIdentifier


	DECLARE	@Output			Table ([Output] VarChar(max))
	DECLARE	@Servers		Table ([ServerName] sysname,[DEPLInstanceID] UniqueIdentifier)


	SET		@NewInstanceID	= NEWID()
	SET		@ServerCnt		= 0


	SET		@TSQL		= 'SELECT ''$ServerName$'' [ServerName],[LogId],[EventType],[DatabaseName],[SchemaName]'
						+ ',[ObjectName],[ObjectType],[SqlCommand],[EventDate],[LoginName],[UserName],[VC_DatabaseName]'
						+ ',[VC_SchemaName],[VC_ObjectType],[VC_ObjectName],[VC_Version],[VC_CreatedBy],[VC_CreatedOn]'
						+ ',[VC_ModifiedBy],[VC_ModifiedOn],[VC_Purpose],[VC_BuildApp],[VC_BuildBrnch],[VC_BuildNum]'
						+ ',[DB_BuildApp],[DB_BuildBrnch],[DB_BuildNum],[Status],[DEPLFileName],'''+CAST(@NewInstanceID AS VarChar(50))+''' [DEPLInstanceID] '
						+ 'FROM [$LSName$].[DBAOps].[dbo].[BuildSchemaChanges] WITH(NOLOCK) '
						+ 'WHERE [DEPLInstanceID] IN '
						+ '(SELECT DISTINCT [DEPLInstanceID] FROM [$LSName$].[DBAOps].[dbo].[BuildSchemaChanges] WITH(NOLOCK) '
						+ 'WHERE [VC_Purpose] LIKE ''%GEARS_TICKET_'+CAST(@GearsID AS VarChar(10))+'%'')'


	SET		@CMD		= ''


	DECLARE TicketServer CURSOR
	FOR
	SELECT		DISTINCT
				[SQL] [ServerName]
	FROM		[DEPLcontrol].[dbo].[DBA_DashBoard_TicketDetail]
	WHERE		Gears_id = @GearsID


	-- DROP REMOTE LOGINS IF THEY ALREADY EXIST

	OPEN TicketServer
	FETCH NEXT FROM TicketServer INTO @ServerName
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SET	@ServerCnt = @ServerCnt + 1
			SET	@LSName = 'ReportSource' + CAST(@ServerCnt AS VarChar(10))


			SET @CMD2 = 'IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N''ReportReader'') DROP USER [ReportReader]'

			SET		@CMD2	= 'sqlcmd -S' + @ServerName + ' -dDBAOps -y 0 -Y 8000 -u -I -E -b -Q"'+@CMD2+'"'
			EXEC	master.sys.xp_cmdshell @CMD2, no_output


			SET @CMD2 = 'IF  EXISTS (SELECT * FROM sys.server_principals WHERE name = N''ReportReader'') DROP LOGIN [ReportReader]'

			SET		@CMD2	= 'sqlcmd -S' + @ServerName + ' -dmaster -y 0 -Y 8000 -u -I -E -b -Q"'+@CMD2+'"'
			EXEC	master.sys.xp_cmdshell @CMD2, no_output

		END
		FETCH NEXT FROM TicketServer INTO @ServerName
	END
	CLOSE TicketServer
	DEALLOCATE TicketServer


	SET		@ServerCnt		= 0

	DECLARE TicketServer CURSOR
	FOR
	SELECT		DISTINCT
				[SQL] [ServerName]
	FROM		[DEPLcontrol].[dbo].[DBA_DashBoard_TicketDetail]
	WHERE		Gears_id = @GearsID


	OPEN TicketServer
	FETCH NEXT FROM TicketServer INTO @ServerName
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SET	@ServerCnt = @ServerCnt + 1
			SET	@LSName = 'ReportSource' + CAST(@ServerCnt AS VarChar(10))


			IF EXISTS (SELECT * From master.sys.Servers WHERE name = @LSName)
				EXEC master.dbo.sp_dropserver @LSName, 'droplogins'

			EXEC	master.dbo.sp_addlinkedserver
						@server=@LSName,
						@srvproduct='',
						@provider='SQLNCLI',
						@datasrc=@ServerName

			SET @CMD2 = 'USE MASTER;CREATE LOGIN [ReportReader] WITH PASSWORD=N''R3p0rtR3ad3r'' , DEFAULT_DATABASE=[DBAOps];USE [DBAOps];CREATE USER [ReportReader] FOR LOGIN [ReportReader];EXEC sp_addrolemember N''db_datareader'', N''ReportReader'''

			SET		@CMD2	= 'sqlcmd -S' + @ServerName + ' -dDBAOps -y 0 -Y 8000 -u -I -E -b -Q"'+@CMD2+'"'
			EXEC	master.sys.xp_cmdshell @CMD2, no_output

			EXEC	master.dbo.sp_addlinkedsrvlogin
						@rmtsrvname = @LSName
						, @locallogin = NULL
						, @useself = N'False'
						, @rmtuser = N'ReportReader'
						, @rmtpassword = N'R3p0rtR3ad3r'

			IF @ServerCnt > 1
				SET @CMD	= @CMD + CHAR(13) + CHAR(10) + 'UNION ALL'+ CHAR(13) + CHAR(10)

			SET	@CMD		= @CMD + REPLACE(REPLACE(@TSQL,'$ServerName$',@ServerName),'$LSName$',@LSName)

		END
		FETCH NEXT FROM TicketServer INTO @ServerName
	END
	CLOSE TicketServer
	DEALLOCATE TicketServer


	SET		@ServerCnt		= 0

	TRUNCATE TABLE	[DBAOps].[dbo].[BuildSchemaChanges_Agg]

	INSERT INTO	[DBAOps].[dbo].[BuildSchemaChanges_Agg]
	EXEC (@CMD)


	DECLARE TicketServer CURSOR
	FOR
	SELECT		DISTINCT
				[SQL] [ServerName]
	FROM		[DEPLcontrol].[dbo].[DBA_DashBoard_TicketDetail]
	WHERE		Gears_id = @GearsID


	OPEN TicketServer
	FETCH NEXT FROM TicketServer INTO @ServerName
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			SET	@ServerCnt = @ServerCnt + 1
			SET	@LSName = 'ReportSource' + CAST(@ServerCnt AS VarChar(10))


			IF EXISTS (SELECT * From master.sys.Servers WHERE name = @LSName)
				EXEC master.dbo.sp_dropserver @LSName, 'droplogins'


			SET @CMD2 = 'IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N''ReportReader'') DROP USER [ReportReader]'

			SET		@CMD2	= 'sqlcmd -S' + @ServerName + ' -dDBAOps -y 0 -Y 8000 -u -I -E -b -Q"'+@CMD2+'"'
			EXEC	master.sys.xp_cmdshell @CMD2, no_output


			SET @CMD2 = 'IF  EXISTS (SELECT * FROM sys.server_principals WHERE name = N''ReportReader'') DROP LOGIN [ReportReader]'

			SET		@CMD2	= 'sqlcmd -S' + @ServerName + ' -dmaster -y 0 -Y 8000 -u -I -E -b -Q"'+@CMD2+'"'
			EXEC	master.sys.xp_cmdshell @CMD2, no_output

		END
		FETCH NEXT FROM TicketServer INTO @ServerName
	END
	CLOSE TicketServer
	DEALLOCATE TicketServer
END
GO
GRANT EXECUTE ON  [dbo].[BuildSchemaChanges_AllServersInTicket] TO [public]
GO
