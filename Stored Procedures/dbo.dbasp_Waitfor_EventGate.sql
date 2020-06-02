SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Waitfor_EventGate]	(@ConditionDef Xml,@TSQLBetweenChecks Varchar(8000) = null)
AS						
SET NOCOUNT ON
--
-- THE @TSQLBetweenChecks Parameter is intended to perform a task between each check that either loggs activity or returns a progress statement.
--  This would then show in the Azure Pipeline log while it is waiting for completion.
--
--
DECLARE		@Set_Type				SYSNAME
			,@Set_Verbose			INT
			,@Set_UpdateInterval	SYSNAME
			,@Set_LookbackMinutes	Int
			,@Set_TimeoutAfter		Int
			,@Set_TimeoutState		SYSNAME
            ,@TestType				SYSNAME
			,@TestValue				SYSNAME
			,@FailOn				SYSNAME
			,@PassOn				SYSNAME
			,@LastCheck				DateTime
			,@PassOrFail			Bit
            ,@job_status			SYSNAME
			,@job_status_desc		SYSNAME
			,@CMD					Varchar(8000)
			,@StartTime				DateTime		= GETDATE()
			,@StatusDate			DateTime
			,@Action				SYSNAME
			,@FirstPass				Bit				= 1
			,@Set_OutputTable		INT
            ,@Set_OutputStatus		Int
            ,@Status				INT

DECLARE		@TestItems				Table	(
											TestType		SYSNAME
											,Action			SYSNAME		NULL
											,Value			SYSNAME
											,FailOn			SYSNAME		NULL
											,PassOn			SYSNAME		NULL
											,LastCheck		DateTime	NULL
											,PassOrFail		BIT			NULL
											)

SELECT		@Set_Type				= a.x.value('../@Type','SYSNAME')			
			,@Set_Verbose			= a.x.value('../@Verbose','INT')			
			,@Set_UpdateInterval	= a.x.value('../@UpdateInterval','SYSNAME')	
			,@Set_LookBackMinutes	= a.x.value('../@LookBackMinutes','INT')
			,@Set_TimeoutAfter		= a.x.value('../@TimeoutAfter','INT')	
			,@Set_TimeoutState		= a.x.value('../@TimeoutState','SYSNAME')
			,@Set_OutputTable		= a.x.value('../@OutputTable','INT')
			,@Set_OutputStatus		= a.x.value('../@OutputStatus','INT')
FROM		@ConditionDef.nodes('/WaitForCondition/Set/*') a(x)

INSERT INTO	@TestItems(TestType,Action,Value,FailOn,PassOn)
SELECT		a.x.value('local-name(.)', 'SYSNAME')			[TestType]
			,a.x.value('@Action','sysname')					[Action]
			,a.x.value('@Value','sysname')					[Value]
			,a.x.value('@FailOn','sysname')					[FailOn]
			,a.x.value('@PassOn','sysname')					[PassOn]
FROM		@ConditionDef.nodes('/WaitForCondition/Set/*') a(x)

TopOfTheLoop:

DECLARE TestCursor CURSOR
FOR
-- SELECT QUERY FOR CURSOR
SELECT * FROM @TestItems WHERE PassOrFail IS NULL

OPEN TestCursor;
FETCH TestCursor INTO @TestType,@Action,@TestValue,@FailOn,@PassOn,@LastCheck,@PassOrFail;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		---------------------------- 
		---------------------------- CURSOR LOOP TOP

		IF @TestType = 'AgentJob'
		BEGIN
			IF NOT EXISTS(SELECT * From msdb.dbo.sysjobs where name = @TestValue)
			BEGIN
				IF @Set_Verbose >= 1 
					RAISERROR('"%s" is not a valid job name.',-1,-1,@TestValue) WITH NOWAIT

				UPDATE @TestItems SET LastCheck = GETDATE(),PassOrFail = 0 WHERE TestType = @TestType AND [Value] = @TestValue
			END

			SELECT @job_status = [DBAOps].[dbo].[dbaudf_GetJobStatus2](@TestValue)

			IF @Action = 'Start' AND @FirstPass = 1 AND @job_status != 4
			BEGIN
				IF @Set_Verbose >= 1 
					RAISERROR('Starting Job "%s".',-1,-1,@TestValue) WITH NOWAIT

				EXEC DBAOps.dbo.dbasp_start_job @JobName		= @TestValue	-- sysname
											   ,@ErrorIfRunning = 0				-- bit
				GOTO SkipTestingStatus							   
			END

			SELECT		@StatusDate = DBAOps.dbo.dbaudf_max_datetime(DBAOps.dbo.dbaudf_max_datetime(OA.start_execution_date,OA.stop_execution_date),OA.run_requested_date)
			FROM		MSDB.DBO.SYSJOBS O
			JOIN		MSDB.DBO.SYSJOBACTIVITY OA				ON	O.job_id = OA.job_id
			LEFT JOIN	MSDB.DBO.SYSJOBHISTORY JH				ON	OA.job_history_id = JH.instance_id
			WHERE		O.name = @TestValue

			IF @StatusDate < DATEADD(MINUTE,(@Set_LookBackMinutes * -1),@StartTime) AND @job_status != 4
			BEGIN
				IF @Set_Verbose >= 1 
					RAISERROR('"%s" has not been started in the last %d minutes, Waiting...',-1,-1,@TestValue,@Set_LookBackMinutes) WITH NOWAIT

				UPDATE @TestItems SET LastCheck = GETDATE() WHERE TestType = @TestType AND [Value] = @TestValue
				GOTO SkipTestingStatus
			END


			-- -2 = Job was not Found
			--  0 = Failed
			--  1 = Succeeded
			--  2 = Retry
			--  3 = Canceled
			--  4 = In progress
			--  5 = Idle
			--	+10 Job is Disabled

			SET @job_status_desc	= CASE @job_status
										WHEN '-2' THEN 'Job was not Found'
										WHEN '0'  THEN 'Failed'
										WHEN '1'  THEN 'Succeeded'
										WHEN '2'  THEN 'Retry'
										WHEN '3'  THEN 'Canceled'
										WHEN '4'  THEN 'In progress'
										WHEN '5'  THEN 'Idle'
										
										WHEN '10'  THEN 'Failed (Disabled)'
										WHEN '11'  THEN 'Succeeded (Disabled)'
										WHEN '12'  THEN 'Retry (Disabled)'
										WHEN '13'  THEN 'Canceled (Disabled)'
										WHEN '14'  THEN 'In progress (Disabled)'
										WHEN '15'  THEN 'Idle (Disabled)'	
														
										ELSE 'Unknown' END

			IF @Set_Verbose >= 1 
				RAISERROR('"%s" Is Currently %s',-1,-1,@TestValue,@job_status_desc) WITH NOWAIT

			IF @job_status IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@PassOn,','))
			BEGIN
				IF @Set_Verbose >= 0 
					RAISERROR(' -- Job status is "Pass"',-1,-1) WITH NOWAIT

				UPDATE @TestItems SET LastCheck = GETDATE(),PassOrFail = 1 WHERE TestType = @TestType AND [Value] = @TestValue
			END

			IF @job_status IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@FailOn,','))
			BEGIN
				IF @Set_Verbose >= 0 
					RAISERROR(' -- Job status is "Fail"',-1,-1) WITH NOWAIT

				UPDATE @TestItems SET LastCheck = GETDATE(),PassOrFail = 0 WHERE TestType = @TestType AND [Value] = @TestValue
			END
		END

		SkipTestingStatus:


		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM TestCursor INTO @TestType,@Action,@TestValue,@FailOn,@PassOn,@LastCheck,@PassOrFail;
END
CLOSE TestCursor;
DEALLOCATE TestCursor;

SET @FirstPass = 0


IF @Set_TimeoutAfter > 0 AND DATEDIFF(MINUTE,@StartTime,GETDATE()) >= @Set_TimeoutAfter
BEGIN

	SELECT * FROM @TestItems
		
	IF @Set_TimeoutState = 'Error'
	BEGIN
		IF @Set_Verbose >= 0 
			raiserror(' -- PROCESS TIMED OUT AFTER WAITING FOR %d MINUTES',15,1,@Set_TimeoutAfter) WITH NOWAIT

	END
	ELSE
	BEGIN
		IF @Set_Verbose >= 0 
			raiserror(' -- PROCESS TIMED OUT AFTER WAITING FOR %d MINUTES',-1,-1,@Set_TimeoutAfter) WITH NOWAIT
	END

	SET @Status = -2

	IF @Set_OutputStatus = 1
		SELECT @Status [Status]

	RETURN @Status
END
ELSE IF EXISTS(SELECT * FROM @TestItems WHERE PassOrFail IS NULL)  
BEGIN
	IF @Set_Verbose >= 1 
		RAISERROR('     -- WAITING...',-1,-1) WITH NOWAIT

	IF NULLIF(@TSQLBetweenChecks,'') IS NOT NULL
		EXEC (@TSQLBetweenChecks)

	SET @CMD = 'WAITFOR DELAY '''+@Set_UpdateInterval+''''
	EXEC (@CMD)



	GOTO TopOfTheLoop
END

IF @Set_OutputTable = 1
	SELECT * FROM @TestItems

IF EXISTS(SELECT * FROM @TestItems WHERE PassOrFail = 0)
	SET @Status = -1
ELSE
	SET @Status = 1

IF @Set_OutputStatus = 1
	SELECT @Status [Status]

RETURN @Status
/*

DECLARE @ConditionDef Xml =
'
<WaitForCondition>
  <Set Type="AND" Verbose="1" UpdateInterval="00:01:00" LookBackMinutes="600" TimeoutAfter="180" TimeoutState="Error" OutputTable="0" OutputStatus="1">
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_ClientLeads"				FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_dmbooking"					FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_DMODS"						FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_ETLConfig"					FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_GlobalDB"					FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRODM02.DB.${{secrets.DOMAIN_NAME}}_SupplierEtl"				FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPRORPT03.DB.${{secrets.DOMAIN_NAME}}_MarketingListTool"		FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSQL03.DB.${{secrets.DOMAIN_NAME}}_ComposerSL"				FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSQL03.DB.${{secrets.DOMAIN_NAME}}_EnterpriseServices"		FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSSSQL02.DB.${{secrets.DOMAIN_NAME}}_Globalmatrix"			FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSSSQL02.DB.${{secrets.DOMAIN_NAME}}_MDI"					FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSSSQL02.DB.${{secrets.DOMAIN_NAME}}_V1_CONSOLIDATED"		FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSSSQL02.DB.${{secrets.DOMAIN_NAME}}_${{secrets.COMPANY_NAME}}_Utility"		FailOn="0,3,5" PassOn="1" />
    <AgentJob Action="Start" Value="RESTOREDB_SDCPROSSSQL02.DB.${{secrets.DOMAIN_NAME}}_Web Reporting - Admin"	FailOn="0,3,5" PassOn="1" />
  </Set>
</WaitForCondition>
'

EXEC DBAOps.dbo.dbasp_Waitfor_EventGate @ConditionDef

*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_Waitfor_EventGate] TO [public]
GO
