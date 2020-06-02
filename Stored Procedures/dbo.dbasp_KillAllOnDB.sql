SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_KillAllOnDB]
	( 
	@dbName		varchar(4000)
	) 
AS 
BEGIN 
	IF DB_ID(@DBName) IS NOT NULL
	BEGIN
		--DECLARE @CMD VarChar(8000)
		--SET	@CMD = REPLACE('ALTER DATABASE [$DBNAME$] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE','$DBNAME$',@DBName)
		--EXEC (@CMD);
		DECLARE		@LoopCount	INT		= 0
		DECLARE		@LoopLimit	INT		= 100

		declare		@tsql		nvarchar(4000) 
	
		while	( 
				SELECT		count(distinct spid)
				FROM		(
							select		spid
							from		[master].[dbo].[sysprocesses] p 
							WHERE		p.dbid = DB_ID(@dbName) 
								AND		SPId <> @@SPId 
								AND		SPID > 50
							UNION
							SELECT		spid
							from		[master].[dbo].[sysprocesses] p 
							cross apply	sys.dm_exec_sql_text(p.sql_handle) t
							WHERE		p.dbid = DB_ID('master')
								AND		p.program_name Like '%SQLsafe%'
								AND		T.text Like '%'+@dbName+'%'
								AND		SPId <> @@SPId AND SPID > 50
							) p
				) > 0 AND @LoopCount < @LoopLimit
		BEGIN 
			SET			@LoopCount = @LoopCount + 1
			SET			@tsql = ''
			
			SELECT		@tsql = @tsql + 'kill ' + convert(varchar(4), spid)+';' + CHAR(13)+CHAR(10)
			--SELECT		*
			FROM		(
							select		spid
							from		[master].[dbo].[sysprocesses] p 
							WHERE		p.dbid = DB_ID(@dbName)
								AND		SPId <> @@SPId 
								AND		SPID > 50
							UNION
							SELECT		spid
							from		[master].[dbo].[sysprocesses] p 
							cross apply	sys.dm_exec_sql_text(p.sql_handle) t
							WHERE		p.dbid = DB_ID('master')
								AND		p.program_name Like '%SQLsafe%'
								AND		T.text Like '%'+@dbName+'%'
								AND		SPId <> @@SPId 
								AND		SPID > 50
						) p

			RAISERROR('    -- %s',-1,-1,@tsql) WITH NOWAIT
			BEGIN TRY
				EXEC	[dbo].[sp_executesql] @tsql 
			END TRY
			BEGIN CATCH
				RAISERROR('-- Failure Durring Kill',-1,-1) WITH NOWAIT
				EXEC DBAOps.dbo.dbasp_GetErrorInfo
			END CATCH
		END 
	END
END
--	exec [dbasp_KillAllOnDB] 'DBAPerf'
GO
GRANT EXECUTE ON  [dbo].[dbasp_KillAllOnDB] TO [public]
GO
