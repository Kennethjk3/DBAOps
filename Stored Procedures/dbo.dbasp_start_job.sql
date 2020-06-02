SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_start_job]
		(
		@JobName			SYSNAME
		,@WaitIfRunning_Minutes		INT	= 0
		,@WaitIfRunning_TOD		CHAR(8)	= NULL	-- FORMAT 'HH:MM:SS' ex. '23:59:59'
		,@DelayMinAfterKill		INT	= 0
		,@ErrorIfRunning		BIT	= 1
		,@KillAfterWait			BIT	= 0
		)
AS


DECLARE		@JobSpid		INT
			,@job_id		UNIQUEIDENTIFIER
			,@StartDate		DATETIME
			,@StopDate		DATETIME
			,@CMD			VarChar(max)
			,@Wait1			INT
			,@Wait2			CHAR(8)
			,@Startkill		DateTime
			,@HangCheck		DateTime


CheckJob:


SELECT		@JobSpid					= p.spid
			,@StartDate					= ja.start_execution_date
			,@StopDate					= ja.stop_execution_date
			,@job_id					= j.job_id
			,@WaitIfRunning_Minutes		= ISNULL(@WaitIfRunning_Minutes,0)
			,@DelayMinAfterKill			= ISNULL(@DelayMinAfterKill,0)
FROM		msdb.dbo.sysjobactivity ja
JOIN		msdb.dbo.sysjobs j
	ON	ja.job_id = j.job_id
	AND	j.name = @JobName
LEFT JOIN	master.dbo.sysprocesses p
	ON	master.dbo.fn_varbintohexstr(convert(varbinary(16), j.job_id)) COLLATE Latin1_General_CI_AI = substring(replace(program_name, 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34)
	AND	ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)


IF @StartDate IS NOT NULL AND @StopDate IS NULL
BEGIN
	raiserror ('Job Is running.',-1,-1) WITH NOWAIT


	IF	@WaitIfRunning_Minutes > 0 OR @WaitIfRunning_TOD IS NOT NULL
	BEGIN
		IF	@WaitIfRunning_Minutes > 0 AND DATEDIFF(minute,@StartDate,getdate()) < @WaitIfRunning_Minutes
		BEGIN
			SELECT @Wait1 = @WaitIfRunning_Minutes - DATEDIFF(minute,@StartDate,getdate())
			raiserror ('Job HAS NOT been running longer than %d minutes. Waiting %d more minutes for Job to finish.',-1,-1,@WaitIfRunning_Minutes,@Wait1) WITH NOWAIT
			select @Wait2 = CONVERT(char(8),dateadd(minute,@Wait1,0),108)
			WAITFOR DELAY @Wait2
			GOTO CheckJob
		END
		ELSE IF	@WaitIfRunning_TOD IS NOT NULL AND CAST(CONVERT(char(8),getdate(),108)AS DateTime) < CAST(@WaitIfRunning_TOD AS DateTime)
		BEGIN
			SELECT @Wait1 = DATEDIFF(minute,CAST(CONVERT(char(8),getdate(),108)AS DateTime),CAST(@WaitIfRunning_TOD AS DateTime))


			raiserror ('Job HAS NOT been running past ''%s''. Waiting %d more minutes for Job to finish.',-1,-1,@WaitIfRunning_TOD,@Wait1) WITH NOWAIT
			select @Wait2 = CONVERT(char(8),dateadd(minute,@Wait1,0),108)
			WAITFOR DELAY @Wait2
			GOTO CheckJob
		END
		ELSE
		BEGIN
			SET @HangCheck = COALESCE(@HangCheck,getdate())


			IF @WaitIfRunning_Minutes > 0
				raiserror ('Job HAS been running longer than %d minutes. Killing Job and Restarting.',-1,-1,@WaitIfRunning_Minutes) WITH NOWAIT
			ELSE IF	@WaitIfRunning_TOD IS NOT NULL
				raiserror ('Job HAS been running past ''%s''. Killing Job and Restarting.',-1,-1,@WaitIfRunning_TOD) WITH NOWAIT


			IF @ErrorIfRunning = 0
			BEGIN
				SET @Startkill = getdate()
				EXEC msdb.dbo.sp_stop_job @job_name = @JobName;


				StartWait:


				WHILE		@StopDate IS NULL
					AND	DATEDIFF(minute,@Startkill,getdate()) < @DelayMinAfterKill
					AND	DATEDIFF(minute,@HangCheck,getdate()) < @DelayMinAfterKill * 4
				BEGIN
					raiserror ('Waiting for full stop.',-1,-1) WITH NOWAIT


					SELECT		@JobSpid		= p.spid
							,@StartDate		= ja.start_execution_date
							,@StopDate		= ja.stop_execution_date
							,@job_id		= j.job_id
					FROM		msdb.dbo.sysjobactivity ja
					JOIN		msdb.dbo.sysjobs j
						ON	ja.job_id = j.job_id
						AND	j.name = @JobName
					LEFT JOIN	master.dbo.sysprocesses p
						ON	master.dbo.fn_varbintohexstr(convert(varbinary(16), j.job_id)) COLLATE Latin1_General_CI_AI = substring(replace(program_name, 'SQLAgent - TSQL JobStep (Job ', ''), 1, 34)
						AND	ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
				END


				IF @StopDate IS NULL and @JobSpid IS NOT NULL
				BEGIN
					raiserror ('Job Not Stoping. Killing SPID',-1,-1) WITH NOWAIT
					SET @CMD = 'kill ' + CAST(@JobSpid AS VarChar(50))

					SET @Startkill = getdate()
					EXEC (@CMD)
					WHILE		EXISTS(SELECT 1 FROM master.dbo.sysprocesses WHERE spid = @JobSpid)
						AND	DATEDIFF(minute,@Startkill,getdate()) < @DelayMinAfterKill
						AND	DATEDIFF(minute,@HangCheck,getdate()) < @DelayMinAfterKill * 4
					BEGIN
						raiserror ('Waiting for SPID Kill.',-1,-1) WITH NOWAIT
					END


					IF EXISTS(SELECT 1 FROM master.dbo.sysprocesses WHERE spid = @JobSpid)
						raiserror ('Job Unable to be Stopped.',16,1,@WaitIfRunning_Minutes) WITH NOWAIT
				END
				ELSE IF @StopDate IS NULL
					raiserror ('Job Unable to be Stopped.',16,1,@WaitIfRunning_Minutes) WITH NOWAIT


				raiserror ('Job Has Stopped. Restarting Job.',-1,-1) WITH NOWAIT
				GOTO CheckJob
			END
			ELSE
				raiserror ('Job still Running after waiting %d minutes.',16,1,@WaitIfRunning_Minutes) WITH NOWAIT

		END

	END
	ELSE IF @ErrorIfRunning = 1
		raiserror ('Job Already Running.',16,1) WITH NOWAIT


END
ELSE
BEGIN
	WAITFOR DELAY '00:00:02'
	EXEC msdb.dbo.sp_start_job @job_name = @JobName;
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_start_job] TO [public]
GO
