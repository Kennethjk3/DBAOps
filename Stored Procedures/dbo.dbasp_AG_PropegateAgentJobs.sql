SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   PROCEDURE [dbo].[dbasp_AG_PropegateAgentJobs]
		(
		@WhatIF				Bit					= 1
		)
AS
SET NOCOUNT ON

--DECLARE		@WhatIF				Bit					= 1
DECLARE		@AGName				SYSNAME
DECLARE		@PrimaryNode		SYSNAME
DECLARE		@SecondaryNode		SYSNAME
DECLARE		@CMD				Varchar(8000)

DROP TABLE IF EXISTS #AGData


SELECT		name																						[AGName]
			,UPPER(r.replica_server_name) + '.DB.VIRTUOSO.COM'											[ServerName]
			,CASE r.replica_server_name WHEN  DBAOps.dbo.dbaudf_AG_Get_Primary(name) THEN 1 ELSE 0 END	[IsPrimary]
			,CASE r.replica_server_name WHEN  @@SERVERNAME THEN 1 ELSE 0 END							[IsMe]
INTO		#AGData
FROM		sys.availability_groups_cluster c
JOIN		sys.availability_replicas r				ON r.group_id = c.group_id


IF EXISTS (SELECT 1 FROM #AGData WHERE IsMe = 1 AND IsPrimary = 0)
BEGIN
	RAISERROR ('This Server is the Secondary Node for at least one Availability Group. Only Migrating Jobs For AGs that are Primary .',-1,-1) WITH NOWAIT

	DECLARE AGCursor CURSOR
	FOR
	SELECT		DISTINCT
				AGName
	FROM		#AGData

	OPEN AGCursor;
	FETCH AGCursor INTO @AGName;
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF (@@FETCH_STATUS <> -2)
		BEGIN
			---------------------------- 
			---------------------------- CURSOR LOOP TOP
			RAISERROR ('Checking %s Group .',-1,-1,@AGName) WITH NOWAIT

			SELECT		@PrimaryNode = [ServerName]
			FROM		#AGData
			WHERE		AGName = @AGName
				AND		IsPrimary = 1

			IF EXISTS (SELECT 1 FROM #AGData WHERE IsPrimary = 1 AND IsMe = 1 AND AGName = @AGName)
			BEGIN
				RAISERROR ('  This Server is the Primary Node.',-1,-1) WITH NOWAIT

				-- MODIFY JOB CATEGORY IF NOT ON PROD
				IF DBAOps.dbo.dbaudf_GetServerEnv() != 'PRO'
				BEGIN
					;WITH		CAT
								AS
								(
								SELECT		*
								FROM		msdb.dbo.syscategories
								WHERE		name LIKE 'AG_%'
								)
								,REP
								AS
								(
								SELECT		C1.category_id	[OldID]
											,C2.category_id	[NewID]
								FROM		CAT C1
								JOIN		CAT C2			ON C2.name = REPLACE(REPLACE(C1.name,'AG_EMS_AG_PRO','AG_OLTP_AG_PRO'),'_PRO','')
								WHERE		C1.name LIKE 'AG_%_PRO'
								)
					UPDATE		j 
						SET		j.category_id = r.NewID
					FROM		msdb.dbo.sysjobs j
					JOIN		REP r					ON r.OldID = j.category_id
				END


				DECLARE NodeCursor CURSOR
				FOR
				SELECT		[ServerName]
				FROM		#AGData
				WHERE		AGName = @AGName
					AND		IsPrimary = 0 

				OPEN NodeCursor;
				FETCH NodeCursor INTO @SecondaryNode;
				WHILE (@@fetch_status <> -1)
				BEGIN
					IF (@@fetch_status <> -2)
					BEGIN
						---------------------------- 
						---------------------------- CURSOR LOOP TOP
	
						-- COPY ALL LOGINS
						SET @CMD = 'powershell -Command "Copy-DbaLogin -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -ExcludeSystemLogins -Force'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"' 
						EXEC xp_CmdShell @CMD
						PRINT @CMD

						-- COPY ALL OPERATORS 
						SET @CMD = 'powershell -Command "Copy-DbaAgentOperator -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -FORCE'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'
						EXEC xp_CmdShell @CMD
						PRINT @CMD

						-- COPY ALL CATEGORIES
						SET @CMD = 'powershell -Command "Copy-DbaAgentJobCategory -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -FORCE'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'
						EXEC xp_CmdShell @CMD
						PRINT @CMD

						-- COPY ALL JOBS
						SET @CMD = 'powershell -Command "Get-DbaAgentJob -SqlInstance '+@PrimaryNode+' | Where-Object Category -eq "AG_'+@AGName+'" | Copy-DbaAgentJob -Destination '+@SecondaryNode+' -Force'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'  -- DO NOT DISABLE ON AG NODES
						EXEC xp_CmdShell @CMD
						PRINT @CMD

						---------------------------- CURSOR LOOP BOTTOM
						----------------------------
					END
 					FETCH NEXT FROM NodeCursor INTO @SecondaryNode;
				END
				CLOSE NodeCursor;
				DEALLOCATE NodeCursor;

			END
			ELSE
				RAISERROR ('  This Server is not the Primary Node. Exiting without any actions.',-1,-1,@AGName) WITH NOWAIT
			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM AGCursor INTO @AGName;
	END
	CLOSE AGCursor;
	DEALLOCATE AGCursor;

END
ELSE
BEGIN
	RAISERROR ('This Server is the Primary Node for all Availability Groups. Migrating All Jobs.',-1,-1,@AGName) WITH NOWAIT
	
	SET		@PrimaryNode = DBAOps.dbo.dbaudf_GetLocalFQDN()


	-- MODIFY JOB CATEGORY IF NOT ON PROD
	IF DBAOps.dbo.dbaudf_GetServerEnv() != 'PRO'
	BEGIN
		;WITH		CAT
					AS
					(
					SELECT		*
					FROM		msdb.dbo.syscategories
					WHERE		name LIKE 'AG_%'
					)
					,REP
					AS
					(
					SELECT		C1.category_id	[OldID]
								,C2.category_id	[NewID]
					FROM		CAT C1
					JOIN		CAT C2			ON C2.name = REPLACE(REPLACE(C1.name,'AG_EMS_AG_PRO','AG_OLTP_AG_PRO'),'_PRO','')
					WHERE		C1.name LIKE 'AG_%_PRO'
					)
		UPDATE		j 
			SET		j.category_id = r.NewID
		FROM		msdb.dbo.sysjobs j
		JOIN		REP r					ON r.OldID = j.category_id
	END

	DECLARE NodeCursor CURSOR
	FOR
	SELECT		DISTINCT
				[ServerName]
	FROM		#AGData
	WHERE		IsPrimary = 0 

	OPEN NodeCursor;
	FETCH NodeCursor INTO @SecondaryNode;
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN
			---------------------------- 
			---------------------------- CURSOR LOOP TOP
	
			-- COPY ALL LOGINS
			SET @CMD = 'powershell -Command "Copy-DbaLogin -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -ExcludeSystemLogins -Force'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"' 
			EXEC xp_CmdShell @CMD
			PRINT @CMD

			-- COPY ALL OPERATORS 
			SET @CMD = 'powershell -Command "Copy-DbaAgentOperator -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -FORCE'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'
			EXEC xp_CmdShell @CMD
			PRINT @CMD

			-- COPY ALL CATEGORIES
			SET @CMD = 'powershell -Command "Copy-DbaAgentJobCategory -Source '+@PrimaryNode+' -Destination '+@SecondaryNode+' -FORCE'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'
			EXEC xp_CmdShell @CMD
			PRINT @CMD

			-- COPY ALL JOBS
			SET @CMD = 'powershell -Command "Get-DbaAgentJob -SqlInstance '+@PrimaryNode+' | Copy-DbaAgentJob -Destination '+@SecondaryNode+' -Force'+ CASE @WhatIf WHEN 1 THEN ' -WhatIf' ELSE '' END  +'"'  -- DO NOT DISABLE ON AG NODES
			EXEC xp_CmdShell @CMD
			PRINT @CMD

			---------------------------- CURSOR LOOP BOTTOM
			----------------------------
		END
 		FETCH NEXT FROM NodeCursor INTO @SecondaryNode;
	END
	CLOSE NodeCursor;
	DEALLOCATE NodeCursor;

END
GO
