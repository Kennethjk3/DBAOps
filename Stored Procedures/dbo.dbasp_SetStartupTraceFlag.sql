SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetStartupTraceFlag]
	(
	@traceflag_to_add	NVARCHAR(20)
	,@Action		VarChar(50) = 'add'
	)
AS
SET NOCOUNT ON;
/*
DECLARE	@traceflag_to_add	NVARCHAR(20)
	,@Action		VarChar(50)


SELECT	@traceflag_to_add	= '272'
	,@action		= 'add'
				--'drop'
*/
-- *********  EXAMPLES  ***********
/*
EXEC dbasp_SetStartupTraceFlag '272','add'
GO
EXEC dbasp_SetStartupTraceFlag '272','drop'
GO
*/


DECLARE @instance_name		NVARCHAR(2000)
        ,@subkey		NVARCHAR(2000)
        ,@tmp_int		INT
        ,@my_value_name		NVARCHAR(4000)
        ,@my_value		NVARCHAR(4000)


IF OBJECT_ID('tempdb..#trace_flag_status') IS NOT NULL DROP TABLE #trace_flag_status;
CREATE TABLE #trace_flag_status
(
    TraceFlag NVARCHAR(10),
    Status BIT,
    Global BIT,
    Session BIT
);


IF OBJECT_ID('tempdb..#temp_store') IS NOT NULL DROP TABLE #temp_store;
CREATE TABLE #temp_store
(
    value_name VARCHAR(255),
    value VARCHAR(255)
)


--------------------------------------------------------------------------------------------
-- SET STARTUP PARAMETERS
--------------------------------------------------------------------------------------------


SELECT	@subkey			= N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\Parameters'
	,@my_value		= '-T ' + CAST(@traceflag_to_add AS NVARCHAR(10))
	,@instance_name		= CAST(ISNULL(SERVERPROPERTY('InstanceName'), @@SERVICENAME) AS NVARCHAR(MAX))


INSERT  INTO #trace_flag_status EXEC ('DBCC Tracestatus(-1) WITH NO_INFOMSGS');


--------------------------------------------------------------------------------------------
-- Set trace flag if necessary
--------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM #trace_flag_status WHERE TraceFlag = @traceflag_to_add)
BEGIN
    IF @Action = 'drop'
    BEGIN
	PRINT 'Dropping Trace Flag ' + @traceflag_to_add;
	EXECUTE('DBCC TRACEOFF(' + @traceflag_to_add + ', -1) WITH NO_INFOMSGS');


    END
    ELSE
	PRINT 'Trace Flag ' + @traceflag_to_add + ' has already been set';
END
ELSE
BEGIN
    IF @Action = 'drop'
	PRINT 'Trace Flag ' + @traceflag_to_add + ' has not already been set';
    ELSE
    BEGIN
	PRINT 'Setting Trace Flag ' + @traceflag_to_add;
	EXECUTE('DBCC TRACEON(' + @traceflag_to_add + ', -1) WITH NO_INFOMSGS');
    END
END


--SELECT * FROM #trace_flag_status;
IF OBJECT_ID('tempdb..#trace_flag_status') IS NOT NULL DROP TABLE #trace_flag_status;


--------------------------------------------------------------------------------------------
-- Calculate the key name, such as: SQLArg3
--------------------------------------------------------------------------------------------
INSERT #temp_store EXEC master..xp_instance_regenumvalues @rootkey = N'HKEY_LOCAL_MACHINE', @key = @subkey;
--SELECT * FROM #temp_store;
SELECT  @tmp_int = COUNT(*) FROM #temp_store;
SELECT @my_value_name = 'SQLArg' + CAST(@tmp_int AS NVARCHAR(3));


--SELECT * FROM #temp_store WHERE replace(value, ' ', '') = replace('-T ' + CAST(@traceflag_to_add AS NVARCHAR(10)), ' ', '')


IF EXISTS ( SELECT * FROM #temp_store WHERE replace(value, ' ', '') = replace('-T ' + CAST(@traceflag_to_add AS NVARCHAR(10)), ' ', ''))
BEGIN
    IF @Action = 'drop'
    BEGIN
	SELECT @my_value_name = value_name FROM #temp_store WHERE replace(value, ' ', '') = replace('-T ' + CAST(@traceflag_to_add AS NVARCHAR(10)), ' ', '')
	PRINT 'Dropping Trace Flag ' + @traceflag_to_add + ' from the service startup parameters for ' + @instance_name;
	PRINT 'Dropping ' + @my_value_name
	EXEC[sys].[xp_instance_regdeletevalue] @rootkey = 'HKEY_LOCAL_MACHINE',
				     @key = @subkey,
				     @value_name = @my_value_name
    END
    ELSE
	PRINT 'Trace Flag ' + @traceflag_to_add + ' has already been added to the startup parameters for ' + @instance_name;
END
ELSE
BEGIN
    IF @Action = 'drop'
	PRINT 'Trace Flag ' + @traceflag_to_add + ' has not already been added to the startup parameters for ' + @instance_name;
    ELSE
	BEGIN
	    PRINT 'Adding Trace Flag ' + @traceflag_to_add + ' to the service startup parameters for ' + @instance_name;
	    EXEC master.dbo.xp_instance_regwrite @rootkey = 'HKEY_LOCAL_MACHINE',
				     @key = @subkey,
				     @value_name = @my_value_name,
				     @type = 'REG_SZ',
				     @value = @my_value;
	END
END


IF OBJECT_ID('tempdb..#temp_store') IS NOT NULL DROP TABLE #temp_store;
GO
GRANT EXECUTE ON  [dbo].[dbasp_SetStartupTraceFlag] TO [public]
GO
