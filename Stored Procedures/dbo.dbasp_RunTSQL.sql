SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_RunTSQL]
	(
	@Name				VarChar(1000)	= NULL
	,@TSQL				VarChar(8000)	= NULL
	,@DBName			sysname			= NULL
	,@Server			sysname			= NULL
	,@Login				sysname			= NULL
	,@Password			sysname			= NULL
	,@OutputPath		VarChar(1000)	= NULL
	,@OutputFile		VarChar(1000)	= NULL
	,@SQLcmdOptions		VarChar(1000)	= ' -I -p -b -e'
	,@StartNestLevel	INT				= 0
	,@OutputText		VarChar(max)	= NULL OUTPUT
	,@OutputMatrix		INT				= NULL -- NULL=DYNAMIC,0=NONE Bit-Matrix(1=Screen,2=File,4=Parameter) ONLY APLIES TO QUERY RESULTS: DEBUG MESSAGES ALL GO TO SCREEN
	,@DebugMatrix		INT				= 0 -- NULL=0=NONE Bit-Matrix(1=Dont Delete Temp OUT File,2=Dont Delete Temp SQL File,4=,8=,16=)
	)
AS
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	04/29/2013	Steve Ledridge		Changed DEPLinfo to DBAOps.


--select * from sys.fn_listextendedproperty('EnableCodeComments', default, default, default, default, default, default)


--exec sp_updateExtendedProperty 'EnableCodeComments' ,1


BEGIN
	SET NOCOUNT ON
	EXEC [dbo].[dbasp_print] 'Database Extended Property "EnableCodeComments" is Enabled',@StartNestLevel
	DECLARE			@extprop_cmd	nVarChar(4000)
					,@PARAMETERS	nVarChar(4000)
					,@ExtPropChk	sysname
					,@CMD			VarChar(8000)
					,@Result		Int
					,@UniqueName	sysname
					,@Results		varChar(max)
					,@Results_part	varChar(8000)
					,@Marker1		INT
					,@Marker2		INT
					,@NestLevel		INT
					,@CRLF			CHAR(2)
					,@TXT			VarChar(max)
					,@HandleString	varchar(max)
					,@Handle		varchar(25)
					,@Pid			varchar(25)
					,@cEGUID		VarChar(50)
					,@ErrorCount	INT
					,@PathAndFile		nVarChar(4000)

	DECLARE			@HandleTab		TABLE([Row] VarChar(max) NULL)
	DECLARE			@ResultTab		TABLE([Lineno] INT, [Line] VarChar(max) NULL)


	IF DB_ID('DBAOps') IS NOT NULL
		SELECT		@cEGUID		= CAST(value as VarChar(50))
				,@ErrorCount	= 0
		FROM		DBAOps.sys.fn_listextendedproperty('DEPLInstanceID', default, default, default, default, default, default)


	SET	@TXT = 'Starting '+COALESCE(OBJECT_NAME(@@PROCID),'');EXEC DBAOps.dbo.dbasp_Print @TXT,@StartNestLevel


	-- SET CONSTANTS
	SELECT			@NestLevel	= @StartNestLevel + 1
				,@CRLF		= CHAR(13) + CHAR(10)
				,@UniqueName	= 'C:\Temp\'+ sys.fn_repluniquename(NEWID(),object_name(@@Procid),default,default,default)+'.out'
				,@Server	= COALESCE(@Server,@@servername)
				,@DBName	= COALESCE(@DBName,'master')
				,@SQLcmdOptions	= COALESCE(' -U' + @Login + ' -P' + @Password,' -E') + COALESCE(@SQLcmdOptions,'') + ' -o' + QUOTENAME(@UniqueName,'"')
				,@extprop_cmd	= 'DECLARE @TXT VarChar(max)' + @CRLF
								+ 'SET @TXT = ''Setting ''+@ExtProp+'' ExtendedProperty to "''+@ExtPropVal+''"''' + @CRLF
								+ 'EXEC DBAOps.dbo.dbasp_Print @TXT, @NestLevel' + @CRLF
								+ 'SELECT      @ExtPropChk = CAST(value AS SYSNAME)' + @CRLF
								+ 'FROM  '+@DBName+'.sys.fn_listextendedproperty(@ExtProp, default, default, default, default, default, default)' + @CRLF
								+ 'IF @@ROWCOUNT = 0' + @CRLF
								+ '  EXEC '+@DBName+'.sys.sp_addextendedproperty @name=@ExtProp, @value=@ExtPropVal' + @CRLF
								+ 'ELSE' + @CRLF
								+ '  EXEC '+@DBName+'.sys.sp_updateextendedproperty @name=@ExtProp, @value=@ExtPropVal'
				,@PARAMETERS	= '@ExtProp sysname,@ExtPropVal sysname,@ExtPropChk sysname OUT,@NestLevel INT'

	-- Set the extended property 'DeplFileName'
	exec sp_executesql
		@statement		= @extprop_cmd
		, @params		= @PARAMETERS
		, @ExtProp		= 'DeplFileName'
		, @ExtPropVal	= @Name
		, @ExtPropChk	= @ExtPropChk OUT
		, @NestLevel	= @NestLevel

	IF COALESCE(@cEGUID,'') != ''
	BEGIN
			INSERT INTO [DBAOps].[dbo].[BuildSchemaChanges]
					   (
					   [EventType]
					   ,[DatabaseName]
					   ,[DEPLFileName]
					   ,[SQLCommand]
					   ,[ObjectName]
					   ,[ObjectType]
					   ,[EventDate]
					   ,[Status]
						)
			select		'DEPL_RUN_SCRIPT'
						,@DBName
						,@Name
						,@TSQL
						,@OutputFile
						,@OutputPath
						,getdate()
						,'STARTING'
	END


	IF @TSQL IS NULL
	BEGIN	-- RUN FILE ----------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						START FILE BLOCK							--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------
	SET @TXT = 'Executing File'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		-- Execute the File
		SELECT	@Results	= @CRLF + @CRLF + 'Running DB\file: ' + @DBName + ' \ ' + @Name + '		'
							+ @CRLF + CAST(Getdate() AS VarChar(50))  + @CRLF + @CRLF
				,@NestLevel	= @NestLevel + 1
				,@cmd		= 'sqlcmd -S' + @Server
							+ ' -d' + @DBName
							+ ' -i' + @Name
							+ @SQLcmdOptions
		IF [dbo].[dbaudf_GetFileProperty] (@Name,'File','FullName') IS NULL
			BEGIN
				SELECT	@TXT			= 'Error: The File, ' + @Name + ', Does Not Exist.'
						,@OutputText	= @TXT
				EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1 -- ALWAYS PRINT ERROR
				RETURN -1
			END
		SET @TXT = @cmd; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		EXEC @Result = master.sys.xp_cmdshell @cmd,no_output
		If @Result !=0
		BEGIN
			SELECT	@TXT			= 'Error: Script Execution Returned This Error Code (' + CAST(@Result AS VarChar) + ')'
					,@OutputText	= @TXT
			EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1 -- ALWAYS PRINT ERROR
			RETURN	@Result
		END
	END		-- RUN FILE ----------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--							END FILE BLOCK							--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------
	ELSE
	BEGIN	-- RUN SCRIPT --------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						START SCRIPT BLOCK							--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------
	SET @TXT = 'Executing Script'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		-- Execute the TSQL Script
		SET		@Results = @CRLF + @CRLF + 'Running TSQL SCRIPT: 		' + CAST(Getdate() AS VarChar(50))  +@CRLF + @CRLF

		Select	@NestLevel	= @NestLevel + 1
				,@UniqueName= REPLACE(@UniqueName,'.out','.sql')
				,@cmd		= 'sqlcmd -S' + @Server
							+ ' -d' + @DBName
							+ ' -i' + QUOTENAME(@UniqueName,'"')
							+ @SQLcmdOptions

		SET @TXT = 'Writing Script to Temp File '+@UniqueName; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		EXEC	DBAOps.[dbo].[dbasp_FileAccess_Write]	@TSQL,@UniqueName,0,1

		SET @TXT = @cmd; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		EXEC @Result = master.sys.xp_cmdshell @cmd,no_output
		If @Result !=0
		BEGIN
			SELECT	@ErrorCount = @ErrorCount + 1
					,@NestLevel = @NestLevel + 1

			SET		@TXT			= 'Error: Script Execution Returned This Error Code (' + CAST(@Result AS VarChar) + ')';
			EXEC	DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1 -- ALWAYS PRINT ERROR
			SELECT	@NestLevel		= @NestLevel - 1

		END

		-- UNLOCK AND DELETE TEMP .SQL FILE
		IF @DebugMatrix & 2 != 2
		BEGIN
			SET @TXT = 'Deleting Temp .SQL File ' + @UniqueName; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
			SET @CMD = 'DEL '+@UniqueName;	EXEC xp_CmdShell @CMD, no_output;
		END
		ELSE
		BEGIN
			SET @TXT = 'Temp .SQL File ' + @UniqueName + ' was NOT Deleted.'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
		END

		SET		@UniqueName= REPLACE(@UniqueName,'.sql','.out')
	END		-- RUN SCRIPT --------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						END SCRIPT BLOCK							--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------


	SET @NestLevel = @NestLevel + 1
	BEGIN	-- GET OUTPUT --------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--					START GATHER OUTPUT BLOCK						--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------

		-- OUTPUT SCRIPT TO WINDOW AFTER EVERYTHING ELSE UNLESS OUTPUT FILE SET
		SET		@TXT = 'Getting Results'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel

		SELECT		@NestLevel	= @NestLevel + 1
					,@Marker1	= 0

		SET		@TXT = 'Reading Results into Table'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		INSERT INTO	@ResultTab([Lineno],[Line])
		SELECT		ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS [LineNo],[Line]
		FROM		DBAOps.dbo.dbaudf_FileAccess_Read(@UniqueName)


		SET		@TXT = 'Agrigating Results Into Variable'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		SELECT		@Results = @Results+COALESCE([Line],'') + @CRLF
		FROM		@ResultTab
		ORDER BY	[Lineno]


	END		-- GET OUTPUT --------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						END GATHER OUTPUT BLOCK						--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------


	BEGIN	-- SHOW OUTPUT -------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						START SHOW OUTPUT BLOCK						--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------


		If @OutputMatrix IS NULL -- DYNAMICLY BUILD MATRIX FROM PARAMETERS
		BEGIN
			SET		@TXT = '@OutputMatrix was NULL, Building Dynamicly.'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
			SET	@OutputMatrix = 0
			IF	@OutputPath IS NULL SET @OutputMatrix = @OutputMatrix | 1		--SET SCREEN BIT
			IF	@OutputPath IS NOT NULL SET @OutputMatrix = @OutputMatrix | 2	--SET FILE BIT
			SET @OutputMatrix = @OutputMatrix | 4								--SET PARAMETER BIT
		END


		IF @OutputMatrix & 1 = 1 -- CHECK SCREEN BIT
		BEGIN
			-- OUTPUT TO SCREEN
			SET		@TXT = '@OutputMatrix Screen=YES'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel

			PrintMore: -- LOOP THROUGH 1k+ Chunks of the results Printing them using the first LF after 1k as the break point so it looks right


				SET @Marker2 = CHARINDEX(CHAR(10),@Results,@Marker1 + 1024)
				IF @Marker2 = 0
					SET @Marker2 = LEN(@Results)


				SET @TXT = SUBSTRING(@Results,@Marker1,(@Marker2-@Marker1)-1); EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel,0,1;


				SET @Marker1 = @Marker2 + 1
				If @Marker2 < LEN(@Results)
					GOTO PrintMore
		END
		ELSE
		BEGIN
			SET		@TXT = '@OutputMatrix Screen=NO'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		END


		IF @OutputMatrix & 2 = 2 -- CHECK FILE BIT
		BEGIN
			-- OUTPUT TO FILE
			SET	@PathAndFile = @OutputPath + @OutputFile
			SET		@TXT = '@OutputMatrix File=YES'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
			EXEC	DBAOps.[dbo].[dbasp_FileAccess_Write]	@Results,@PathAndFile,1,1
		END
		ELSE
		BEGIN
			SET		@TXT = '@OutputMatrix File=NO'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		END

		IF @OutputMatrix & 4 = 4 -- CHECK PARAMETER BIT
		BEGIN
			-- OUTPUT TO PARAMETER
			SET		@TXT = '@OutputMatrix Parameter=YES'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
			SET		@OutputText = @Results
		END
		ELSE
		BEGIN
			SET		@TXT = '@OutputMatrix Parameter=NO'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		END

	END		-- SHOW OUTPUT -------------------------------------------------------
			----------------------------------------------------------------------
			--																	--
			--						END SHOW OUTPUT BLOCK						--
			--																	--
			----------------------------------------------------------------------
			----------------------------------------------------------------------


	-- UNLOCK AND DELETE TEMP .OUT FILE
	IF @DebugMatrix & 1 != 1
	BEGIN
		SET @TXT = 'Deleting Temp .OUT File ' + @UniqueName; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel
		SET @CMD = 'DEL '+@UniqueName;	EXEC xp_CmdShell @CMD, no_output;
	END
	ELSE
	BEGIN
		SET @TXT = 'Temp .OUT File ' + @UniqueName + ' was NOT Deleted.'; EXEC DBAOps.dbo.dbasp_Print @TXT,@NestLevel,1,1
	END

	-- CLEANUP AND CLOSE -------------------------------------------------
	----------------------------------------------------------------------
	--																	--
	--						CLEANUP AND CLOSE							--
	--																	--
	----------------------------------------------------------------------
	----------------------------------------------------------------------

	IF COALESCE(@cEGUID,'') != ''
	BEGIN
			INSERT INTO [DBAOps].[dbo].[BuildSchemaChanges]
					   (
					   [EventType]
					   ,[DatabaseName]
					   ,[DEPLFileName]
					   ,[SQLCommand]
					   ,[ObjectName]
					   ,[ObjectType]
					   ,[EventDate]
					   ,[Status]
						)
			select		'DEPL_RUN_SCRIPT'
						,@DBName
						,@Name
						,@TSQL
						,@OutputFile
						,@OutputPath
						,getdate()
						,'DONE'
	END
		-- Clear the extended property 'DeplFileName'
		exec sp_executesql
			@statement		= @extprop_cmd
			, @params		= @PARAMETERS
			, @ExtProp		= 'DeplFileName'
			, @ExtPropVal	= Null
			, @ExtPropChk	= @ExtPropChk OUT
			, @NestLevel	= @NestLevel


RETURN COALESCE(@ErrorCount,0)
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_RunTSQL] TO [public]
GO
