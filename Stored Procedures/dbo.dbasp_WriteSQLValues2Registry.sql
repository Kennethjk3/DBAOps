SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_WriteSQLValues2Registry]
--
--/*********************************************************
-- **  Stored Procedure dbasp_WriteSQLValues2Registry
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- **  April 18, 2012
-- **
-- **  This procedure writes several values to the registry to be
-- **  used by scom.
-- **
-- ***************************************************************/
AS
SET NOCOUNT ON
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	04/18/2012	Steve Ledridge			New Process
--
--	======================================================================================


DECLARE		@vchName			VarChar(40)
			,@vchLabel			VarChar(100)
			,@dtBuildDate		DateTime
			,@ServerKey			nVarChar(4000)
			,@InstanceKey		nVarChar(4000)
			,@Key				nVarChar(4000)
			,@ValueName			nVarChar(1000)
			,@Value				nVarChar(4000)
			,@OldValue			nVarChar(4000)
			,@ServerClass		SYSNAME


DECLARE		@Results			TABLE
			(
			Results				VarChar(max)
			)

DECLARE		@Values			TABLE
			(
			Value				nVarChar(1000)
			,Data				nVarChar(max)
			)

DECLARE		@RegValues			TABLE
			(
			Registry_Key		VarChar(max)
			,Value_Name			VarChar(max)
			,Current_Value		VarChar(max)
			,New_Value			VarChar(max)
			,Notes				VarChar(max)
			,Expected			bit
			)


---------------------------------------
---------------------------------------
--	BUILD LIST OF EXPECTED KEY VALUES
---------------------------------------
---------------------------------------


	SELECT	@ServerKey		= N'SOFTWARE\${{secrets.COMPANY_NAME}}\SQL'
			,@InstanceKey	= N'SOFTWARE\${{secrets.COMPANY_NAME}}\SQL\' + @@servicename


	-- GET CURRENT DB BUILD NUMBERS
	IF OBJECT_ID('DBAOps.dbo.DBA_DBInfo') IS NOT NULL
		INSERT INTO @RegValues
		SELECT	'InstanceKey','ModDate',NULL,CONVERT(VARCHAR(50),GetUTCDate(),121),NULL,1 FROM DBAOps.dbo.DBA_ServerInfo UNION ALL
		SELECT 'InstanceKey',[DBName],NULL,[Build],[modDate],1 FROM DBAOps.dbo.DBA_DBInfo WHERE NULLIF([Build],'') IS NOT NULL

	-- GET CURRENT SERVER INFO VALUES
	EXEC	DBAOps.dbo.dbasp_GetServerClass @ServerClass=@ServerClass OUT

	IF OBJECT_ID('DBAOps.dbo.DBA_ServerInfo') IS NOT NULL
		INSERT INTO @RegValues
		SELECT	'ServerKey','ModDate',NULL,CONVERT(VARCHAR(50),GetUTCDate(),121),NULL,1 FROM DBAOps.dbo.DBA_ServerInfo UNION ALL
		SELECT	'ServerKey','Environment',NULL,UPPER([SQLEnv]),[modDate],1		FROM DBAOps.dbo.DBA_ServerInfo UNION ALL
		SELECT	'ServerKey','Active',NULL,UPPER([Active]),[modDate],1			FROM DBAOps.dbo.DBA_ServerInfo UNION ALL
		SELECT	'ServerKey','Deployable',NULL,UPPER([DEPLstatus]),[modDate],1	FROM DBAOps.dbo.DBA_ServerInfo UNION ALL
		SELECT	'ServerKey','ServerClass',NULL,@ServerClass,NULL,1 UNION ALL

		SELECT	'ServerKey','CollectionInterval',NULL,CASE
					WHEN [SQLEnv] ='Production' AND @ServerClass IN ('CustomerImpacting'
																		,'EmployeeImpacting'
																		,'DR:CustomerImpacting'
																		,'DR:EmployeeImpacting'
																		,'OpsCentral')				THEN 'High'

					WHEN [SQLEnv]!='Production' AND @ServerClass NOT IN ('CustomerImpacting'
																		,'EmployeeImpacting'
																		,'DR:CustomerImpacting'
																		,'DR:EmployeeImpacting'
																		,'OpsCentral')				THEN 'Low'

					WHEN [SQLEnv] ='Production' AND @ServerClass =		'Test'						THEN 'Low'

					ELSE 'Med' END,NULL,1 FROM DBAOps.dbo.DBA_ServerInfo


---------------------------------------
---------------------------------------
--	READ LIST OF CURRENT KEY VALUES
---------------------------------------
---------------------------------------
	--	GET INSTANCE VALUES
	DELETE	@Values


	EXECUTE [master]..[xp_instance_regwrite]
			  @rootkey = N'HKEY_LOCAL_MACHINE'
			 ,@key = @InstanceKey
			 ,@value_name = 'tmpCheckKey'
			 ,@type = N'REG_SZ'
			 ,@value = '1'

	EXECUTE [master]..[xp_instance_regdeletevalue]
			  @rootkey = N'HKEY_LOCAL_MACHINE'
			 ,@key = @InstanceKey
			 ,@value_name = 'tmpCheckKey'

	INSERT INTO @Values
	exec sys.xp_instance_regenumvalues 'HKEY_LOCAL_MACHINE', @InstanceKey;

	UPDATE	T1
		SET	Current_Value = T2.Data
	FROM	@RegValues T1
	JOIN	@Values T2
		ON	T1.Value_Name = T2.Value
		AND	T1.Registry_Key = 'InstanceKey'


	INSERT INTO	@RegValues
	SELECT		'InstanceKey',Value,Data,NULL,NULL,0
	FROM		@Values
	WHERE		Value NOT IN (SELECT Value_Name FROM @RegValues WHERE Registry_Key = 'InstanceKey')


	--	GET SERVER VALUES
	DELETE	@Values

	EXECUTE [master]..[xp_instance_regwrite]
			  @rootkey = N'HKEY_LOCAL_MACHINE'
			 ,@key = @ServerKey
			 ,@value_name = 'tmpCheckKey'
			 ,@type = N'REG_SZ'
			 ,@value = '1'

	EXECUTE [master]..[xp_instance_regdeletevalue]
			  @rootkey = N'HKEY_LOCAL_MACHINE'
			 ,@key = @ServerKey
			 ,@value_name = 'tmpCheckKey'

	INSERT INTO @Values
	exec sys.xp_instance_regenumvalues 'HKEY_LOCAL_MACHINE', @ServerKey;


	UPDATE	T1
		SET	Current_Value = T2.Data
	FROM	@RegValues T1
	JOIN	@Values T2
		ON	T1.Value_Name = T2.Value
		AND	T1.Registry_Key = 'ServerKey'


	INSERT INTO	@RegValues
	SELECT		'ServerKey',Value,Data,NULL,NULL,0
	FROM		@Values
	WHERE		Value NOT IN (SELECT Value_Name FROM @RegValues WHERE Registry_Key = 'ServerKey')


	DECLARE KeyCursor
	CURSOR
	FOR
	SELECT [Registry_Key],[Value_Name],[New_Value],[Current_Value]
	FROM @RegValues

	WHERE ([Current_Value] IS NULL AND [New_Value] IS NOT NULL) OR [Current_Value] != [New_Value]


	OPEN KeyCursor
	FETCH NEXT FROM KeyCursor INTO @Key, @ValueName, @Value, @OldValue
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN

			SET @Key = CASE @Key
				WHEN 'ServerKey' THEN @ServerKey
				WHEN 'InstanceKey' THEN @InstanceKey
				END

			PRINT	CASE WHEN @OldValue IS NULL THEN 'Writing New Entry ' ELSE 'Updating Existing Entry ' END
					+ @key + '  ' + @ValueName + '=' + @Value
			PRINT	'   Old Value was : ' + @OldValue

 			EXECUTE [master]..[xp_instance_regwrite]
				@rootkey = N'HKEY_LOCAL_MACHINE'
				,@key = @key
				,@value_name = @ValueName
				,@type = N'REG_SZ'
				,@value = @Value


		END
		FETCH NEXT FROM KeyCursor INTO @Key, @ValueName, @Value, @OldValue
	END


	CLOSE KeyCursor
	DEALLOCATE KeyCursor
GO
GRANT EXECUTE ON  [dbo].[dbasp_WriteSQLValues2Registry] TO [public]
GO
