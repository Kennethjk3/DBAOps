SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ShrinkAllLargeLogs]
      (
      @MinLogSize_MB		INT			= 1000		-- LOG SIZE DEFALT MINIMUM IS 1GB
      ,@MinLogFreePct		INT			= 50		-- LOG PERCENT FREE MINIMUM IS 50%
      ,@FileTypes			VarChar(10)	= 'BOTH'	-- LOG,DATA,BOTH
      ,@DBNameFilter		sysname		= NULL		-- SINGLE DBName to PROCESS
      ,@ForceMajorInProd	Bit			= 0
      ,@DoItNow				Bit			= 0
      )
AS
/*
USE [master]
GO
ALTER DATABASE [test] MODIFY FILE ( NAME = N'test_log', SIZE = 1433600KB )
GO
ALTER DATABASE [test] MODIFY FILE ( NAME = N'test', SIZE = 10000000KB )
GO
USE [DBAOps]
GO
exec DBAOps.dbo.dbasp_ShrinkAllLargeLogs 1000,50,'BOTH','Test'
GO
exec	DBAOps.dbo.dbasp_ShrinkAllLargeLogs
			@FileTypes = 'Data'
			,@DoItNow = 1
GO
*/
BEGIN
            SET NOCOUNT ON


            PRINT '-- CHECK DB LOGS FOR NEEDED SHRINKING'

            DECLARE           @TSQL				VARCHAR(max)
                              ,@CMD				VARCHAR(max)
                              ,@DBName			SYSNAME
                              ,@FileName		SYSNAME
                              ,@FileType		SYSNAME
                              ,@Env				SYSNAME
                              ,@Size			FLOAT
                              ,@Free			FLOAT
                              ,@Ratio			FLOAT


            IF OBJECT_ID('Tempdb..#LogFileSpace') IS NOT NULL
                  DROP TABLE #LogFileSpace


            CREATE      TABLE					#LogFileSpace
                        (
                        [DATABASE_NAME]         SYSNAME
                        ,[FILE_TYPE]			SYSNAME
                        ,[FILE_NAME]			SYSNAME
                        ,[CurrentSizeMB]		FLOAT
                        ,[FreeSpaceMB]          FLOAT
                        )


            SELECT      @Env = env_detail
            FROM  DBAOps.dbo.Local_ServerEnviro
            WHERE env_type = 'ENVname'


            IF          @Env = 'Production' AND @ForceMajorInProd = 0
                  PRINT ' -- PRODUCTION: MINIMAL SHRINKING METHOD USED.'


            SET         @TSQL = CASE
            WHEN @Env = 'Production' AND @ForceMajorInProd = 0
            THEN
            'USE [$DBNAME$];
            PRINT ''  -- SHRINKING $FILETYPE$ FILE ($FILENAME$) FOR $DBNAME$''
            PRINT ''  -- BEFORE: $DBNAME$:$FILENAME$ Size=$SIZE$ Free=$FREE$ RATIO=$RATIO$''
            IF ''$FILETYPE$'' = ''DATA''
				DBCC SHRINKFILE (N''$FILENAME$'' , $USEDSIZE$) WITH NO_INFOMSGS;


				DBCC SHRINKFILE (N''$FILENAME$'' , 0, TRUNCATEONLY) WITH NO_INFOMSGS;
				DBCC SHRINKFILE (N''$FILENAME$'' , 0, NOTRUNCATE) WITH NO_INFOMSGS;
				DBCC SHRINKFILE (N''$FILENAME$'' , 0, TRUNCATEONLY) WITH NO_INFOMSGS;'
            ELSE
            'USE [MASTER];
			PRINT ''  -- SHRINKING $FILETYPE$ FILE ($FILENAME$) FOR $DBNAME$''
			PRINT ''  -- BEFORE: $DBNAME$:$FILENAME$ Size=$SIZE$ Free=$FREE$ RATIO=$RATIO$''
            IF ''$FILETYPE$'' != ''DATA''
				BACKUP LOG [$DBNAME$] WITH TRUNCATE_ONLY;'
            +CHAR(13)+CHAR(10)+'USE [$DBNAME$];
            IF ''$FILETYPE$'' = ''DATA''
				DBCC SHRINKFILE (N''$FILENAME$'' , $USEDSIZE$) WITH NO_INFOMSGS;


			DBCC SHRINKFILE (N''$FILENAME$'' , 0, TRUNCATEONLY) WITH NO_INFOMSGS;
			DBCC SHRINKFILE (N''$FILENAME$'' , 0, NOTRUNCATE) WITH NO_INFOMSGS;
			DBCC SHRINKFILE (N''$FILENAME$'' , 0, TRUNCATEONLY) WITH NO_INFOMSGS;'
            END
            +CHAR(13)+CHAR(10)+'
            DECLARE    @Size float, @Free Float, @Ratio float
            SELECT            @Size				=size/128.0
                              ,@Free            =size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0
                              ,@Ratio           =(@Free*100.0)/@Size
            FROM        sys.master_files
            WHERE       name = ''$FILENAME$''
                  AND   database_id = DB_ID()
            PRINT ''    -- AFTER:  $DBNAME$:$FILENAME$ Size=''+CAST(@Size AS VarChar(10))+'' Free=''+CAST(@Free AS VarChar(10))+'' RATIO=''+CAST(@Ratio AS VarChar(10))'


            EXEC  sp_MsForEachDB
            'USE [?];
            INSERT INTO		#LogFileSpace
            SELECT			DB_NAME(database_id)
							,CASE Type WHEN 1 THEN ''LOG'' ELSE ''DATA'' END
							,name
							,size/128.0
							,size/128.0 - CAST(FILEPROPERTY(name, ''SpaceUsed'') AS INT)/128.0
            FROM			sys.master_files
            WHERE			state = 0   -- ONLINE
                  AND		database_id = DB_ID()'


            DECLARE LogFileCursor CURSOR KEYSET
            FOR
            SELECT      [DATABASE_NAME]
						,[FILE_TYPE]
                        ,[FILE_NAME]
                        ,[CurrentSizeMB]
                        ,[FreeSpaceMB]
                        ,([FreeSpaceMB]*100.0)/[CurrentSizeMB]
            FROM        #LogFileSpace
            WHERE       ([FILE_TYPE] = @FileTypes OR @FileTypes = 'BOTH')
				AND		([DATABASE_NAME] = @DBNameFilter OR @DBNameFilter IS NULL)
				AND		[FreeSpaceMB] >= @MinLogSize_MB
				AND		([FreeSpaceMB] * 100) / [CurrentSizeMB] >= @MinLogFreePct
			ORDER BY	1,2,3
            OPEN LogFileCursor


            IF  @@CURSOR_ROWS = 0 PRINT '  --  ALL DATABASES ARE GOOD, NO SHRINKING PERFORMED.'
            FETCH NEXT FROM LogFileCursor INTO @DBName,@FileType,@FileName,@Size,@Free,@Ratio
            WHILE (@@fetch_status <> -1)
            BEGIN
                  IF (@@fetch_status <> -2)
                  BEGIN
                        SET @CMD = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@TSQL,'$DBNAME$',@DBName),'$USEDSIZE$',CAST(CAST(((@Size-@Free)* 1.05) AS INT) AS VarChar(50))),'$FILETYPE$',@FileType),'$FILENAME$',@FileName),'$SIZE$',CAST(@Size AS VarChar(10))),'$FREE$',CAST(@Free AS VarChar(10))),'$RATIO$',CAST(@Ratio AS VarChar(10)))
                        If @DoItNow = 0
						   BEGIN
							PRINT (@CMD)
							PRINT 'GO'
						   END
						ELSE
							EXEC (@CMD)
                  END
                  FETCH NEXT FROM LogFileCursor INTO @DBName,@FileType,@FileName,@Size,@Free,@Ratio
            END


            CLOSE LogFileCursor
            DEALLOCATE LogFileCursor


            IF OBJECT_ID('Tempdb..#LogFileSpace') IS NOT NULL
                  DROP TABLE #LogFileSpace
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_ShrinkAllLargeLogs] TO [public]
GO
