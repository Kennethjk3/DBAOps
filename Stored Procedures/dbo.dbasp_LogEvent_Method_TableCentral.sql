SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent_Method_TableCentral]
	(
	 @cEModule			sysname				=null
	,@cECategory		sysname				=null
	,@cEEvent			NVarchar(max)		=null
	,@cEGUID			UniqueIdentifier	=null
	,@cEMessage			NVarchar(max)		=null
	,@cEStat_Rows		BigInt				=null
	,@cEStat_Duration	FLOAT				=null
	)
AS
BEGIN
	DECLARE		@CentralServer				sysname
				,@CentralServerShortName	sysname
				,@TSQL						Varchar(8000)

	EXEC dbo.dbasp_GetPaths @CentralServer = @CentralServer OUTPUT	
	
	SET @CentralServerShortName = UPPER(REPLACE(@CentralServer,'.DB.VIRTUOSO.COM',''))


	IF NOT EXISTS (SELECT srv.name FROM [sys].[servers] srv WHERE srv.server_id != 0 AND srv.name = @CentralServerShortName)
	BEGIN
		EXEC master.dbo.sp_addlinkedserver @server = @CentralServerShortName, @srvproduct=N'SQL', @provider=N'SQLNCLI', @datasrc=N'tcp:SDCSQLTOOLS.DB.VIRTUOSO.COM'
		EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=@CentralServerShortName,@useself=N'False',@locallogin=NULL,@rmtuser=N'LinkedServer_User',@rmtpassword='4vnetonly'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'collation compatible', @optvalue=N'true'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'data access', @optvalue=N'true'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'dist', @optvalue=N'false'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'pub', @optvalue=N'false'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'rpc', @optvalue=N'true'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'rpc out', @optvalue=N'true'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'sub', @optvalue=N'false'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'connect timeout', @optvalue=N'0'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'collation name', @optvalue=null
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'lazy schema validation', @optvalue=N'false'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'query timeout', @optvalue=N'0'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'use remote collation', @optvalue=N'true'
		EXEC master.dbo.sp_serveroption @server=@CentralServerShortName, @optname=N'remote proc transaction promotion', @optvalue=N'true'
	END


	SET @TSQL = '
	INSERT INTO	[DBACentral].[dbo].[EventLog] (cEModule,cECategory,cEEvent,cEGUID,cEMessage,cEStat_Rows,cEStat_Duration)
	SELECT		cEModule			= ' + QUOTENAME(@cEModule,'''') + '
				,cECategory			= ' + QUOTENAME(@cECategory,'''') + '
				,cEEvent			= ' + QUOTENAME(@cEEvent,'''') + '
				,cEGUID				= ' + QUOTENAME(CAST(@cEGUID AS VarChar(50)),'''') + '
				,cEMessage			= ' + QUOTENAME(@cEMessage,'''') + '
				,cEStat_Rows		= ' + QUOTENAME(CAST(@cEStat_Rows AS VarChar(50)),'''') + '
				,cEStat_Duration	= ' + QUOTENAME(CAST(@cEStat_Duration AS VarChar(50)),'''') + '
'

	EXEC	(@TSQL) AT CentralServer


	RETURN 0


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent_Method_TableCentral] TO [public]
GO
