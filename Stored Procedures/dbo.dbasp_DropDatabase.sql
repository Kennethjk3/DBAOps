SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_DropDatabase] (@dbname sysname,@debug bit = 0, @Retrys INT = 10)

/*********************************************************
 **  Stored Procedure dbasp_DropDatabase                  
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}                
 **  April 6, 2015                                      
 **  
 **  This procedure is used when dropping a database as
 **  part of an automated process.
 **
 **  This proc accepts the following input parm(s):
 **  - @dbname is the name of the database being dropped.
 ***************************************************************/
  as

SET NOCOUNT ON

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/06/2015	Steve Ledridge		New process.
--	04/13/2015	Steve Ledridge		Added Try Catches and Set Database Back to Online before dropping.
--						INFO: If the database or any one of its files is offline when it is dropped,
--						      the disk files are not deleted. These files must be deleted manually.
--	11/10/2017	Steve Ledridge		Modified to use Try/Catch better and loop drop attempts 10 times before giving up
--	======================================================================================

/*
	-- TEST SCRIPT 
	CREATE DATABASE [STEVE_TEST]
	EXEC [dbasp_DropDatabase] 'STEVE_TEST' , 1

*/

/***
Declare @dbname sysname

select @dbname = 'XXXX'
--***/

			

-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
	,@cmd 				nvarchar(4000)
	,@delete_DBfiles		XML

	

----------------  initial values  -------------------
Select @error_count = 0

--  Check input parms
IF DB_ID(@dbname) IS NULL
   BEGIN
	RAISERROR('DBA WARNING: DATABASE [%s] DOES NOT EXIST.',11,1,@dbname) with log
	RETURN (0) 
   END


--  Create Temp Tables
declare @DBfiles table	(physical_name nvarchar(260))



/****************************************************************
 *                MainLine
 ***************************************************************/

 ----------------------  Print the headers  ----------------------
Print  ' '
RAISERROR('/*********************************************************',-1,-1) WITH NOWAIT
RAISERROR('Drop Database [%s] for server: %s',-1,-1,@dbname,@@SERVERNAME) WITH NOWAIT
RAISERROR('*********************************************************/',-1,-1) WITH NOWAIT

		DECLARE @DropDBName SYSNAME
		DECLARE DropSnapshotCursor CURSOR
		FOR
		SELECT		name 
		FROM		sys.databases
		WHERE		source_database_id = DB_ID(@dbname)  

		DECLARE @RetrySnapLoop INT

		OPEN DropSnapshotCursor;
		FETCH DropSnapshotCursor INTO @DropDBName;
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				SET @RetrySnapLoop = 0

				RetrySnapDrop:

				SET @RetrySnapLoop = @RetrySnapLoop + 1

				EXEC dbo.dbasp_KillAllOnDB @DropDBName
				SET @CMD = 'DROP DATABASE ['+@DropDBName +'];'

				IF @Debug = 1
					EXEC	dbo.dbasp_PrintLarge @CMD
				BEGIN TRY
					EXEC (@CMD)
				END TRY
				BEGIN CATCH
					RAISERROR('-- DBA WARNING: Error while Droping Snapshot DB',-1,-1) WITH NOWAIT
					EXEC DBAOps.dbo.dbasp_GetErrorInfo
				END CATCH

				IF DB_ID(@DropDBName) IS NOT NULL AND @RetrySnapLoop <= @Retrys
					GOTO RetrySnapDrop

				IF DB_ID(@DropDBName) IS NOT NULL
				BEGIN
					raiserror('DBAERROR: UNABLE TO DROPP SNAPSHOT DATABASE [%s].',16,1,@DropDBName) with log
					RETURN (3) 
				END

			END
 			FETCH NEXT FROM DropSnapshotCursor INTO @DropDBName;
		END
		CLOSE DropSnapshotCursor;
		DEALLOCATE DropSnapshotCursor;
	

--  Prep for file delete (if needed)
INSERT INTO	@DBfiles 
SELECT		physical_name 
FROM		master.sys.master_files 
WHERE		database_id = DB_ID(@dbname)


EXEC DBAOps.[dbo].[dbasp_KillAllOnDB] @dbname

--  Drop the database if it exists
BEGIN TRY
	IF DATABASEPROPERTYEX (@dbname,'status') <> 'RESTORING'
	BEGIN
		SET @cmd = 'ALTER DATABASE [' + @dbname + '] SET OFFLINE WITH ROLLBACK IMMEDIATE'
		if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
			EXEC(@cmd)

		--SET @cmd = 'ALTER DATABASE [' + @dbname + '] SET ONLINE WITH ROLLBACK IMMEDIATE'
		--if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
		--EXEC(@cmd)
	END
END TRY
BEGIN CATCH
	EXEC DBAOps.dbo.dbasp_GetErrorInfo
	RAISERROR('-- DBA WARNING: Unable Change DB Status',-1,-1) WITH NOWAIT
END CATCH

	Declare @RetryLoop INT = 0

	RetryDrop:

	SET @RetryLoop = @RetryLoop + 1

	EXEC dbo.dbasp_KillAllOnDB @DBName
	SET @cmd = 'drop database [' + @dbname + '];'
	if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
	BEGIN TRY
		EXEC (@CMD)
	END TRY
	BEGIN CATCH
		EXEC DBAOps.dbo.dbasp_GetErrorInfo
		RAISERROR('-- DBA WARNING: ERROR WHILE DROPPING DB',-1,-1) WITH NOWAIT
	END CATCH

	IF DB_ID(@dbname) IS NOT NULL AND @RetryLoop <= @Retrys
		GOTO RetryDrop

	IF DB_ID(@dbname) IS NOT NULL
	BEGIN
		raiserror('DBAERROR: UNABLE TO DROP DATABASE [%s].',16,1,@dbname) with log
		exec sp_whoisactive 
				@get_full_inner_text=1
				,@get_outer_command=1
				,@filter_type = 'database'
				,@filter = @dbname
				,@show_system_spids = 1
				,@show_own_spid = 1
				,@show_sleeping_spids = 1
				,@get_transaction_info = 1
				,@get_task_info = 2
				,@get_locks = 1
				,@get_avg_time = 1
				,@get_additional_info = 1
				,@find_block_leaders = 1

		RETURN (2) 
	END

	--SET @cmd = 'DELETE msdb.dbo.restorefile WHERE restore_history_id IN (SELECT restore_history_id from msdb.dbo.restorehistory WHERE destination_database_name = ''' + @dbname + ''')'
	--if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
	--EXEC(@cmd)

	--SET @cmd = 'DELETE msdb.dbo.restorefilegroup WHERE restore_history_id IN (SELECT restore_history_id from msdb.dbo.restorehistory WHERE destination_database_name = ''' + @dbname + ''')'
	--if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
	--EXEC(@cmd)

	--SET @cmd = 'DELETE msdb.dbo.restorehistory WHERE destination_database_name = ''' + @dbname + ''''
	--if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
	--EXEC(@cmd)

	--SET @cmd = 'EXEC [msdb].[dbo].[sp_delete_database_backuphistory] ''' + @dbname + ''''
	--if @debug = 1 RAISERROR ('-- %s',-1,-1,@cmd) WITH NOWAIT
	--EXEC(@cmd)


--  Make sure files from the old DB have been deleted (if needed).
delete from @DBfiles where dbo.dbaudf_GetFileProperty(physical_name,'file','exists') <> 'True'

If (select count(*) from @DBfiles) > 0
   begin
	SELECT @delete_DBfiles = 
	( 
	select physical_name from @DBfiles
	FOR XML RAW ('DeleteFile'), TYPE, ROOT('FileProcess') 
	) 

	If @delete_DBfiles is not null
		BEGIN TRY
			if @debug = 1 RAISERROR('-- Deleting Orphaned Files.',-1,-1) WITH NOWAIT
			exec dbo.dbasp_FileHandler @delete_DBfiles
		END TRY
		BEGIN CATCH
			EXEC dbo.dbasp_GetErrorInfo
			PRINT ''
			EXEC dbo.dbasp_PrintLarge @delete_DBfiles
			PRINT ''
			raiserror('DBAERROR: ERROR OCCURED WHILE DELETING DATABASE FILES.',16,1,@dbname) with log
			RETURN (3) 
		END CATCH
   end
ELSE
	if @debug = 1 RAISERROR('-- No Orphaned Files to Cleanup.',-1,-1) WITH NOWAIT

RETURN (0)
GO
GRANT EXECUTE ON  [dbo].[dbasp_DropDatabase] TO [public]
GO
