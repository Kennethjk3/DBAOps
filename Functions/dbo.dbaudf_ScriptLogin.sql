SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_ScriptLogin]
					(
					@Login_name	SYSNAME
					)
RETURNS VarChar(max)
AS
BEGIN
	DECLARE		@miscprint			nvarchar(2000)
				,@G_O				nvarchar(2)
				,@VCHARpassword		nvarchar(500)
				,@VCHARsid			nvarchar(128)
				,@pwlen				int
				,@pwpos				int
				,@i					int
				,@length			int
				,@binvalue			varbinary(256)
				,@hexstring			nchar(16)
				,@savename			sysname
				,@output_flag		char(1)
				,@tempint			int
				,@firstint			int
				,@secondint			int
				,@Login_password	sysname
				,@Login_sid			varbinary(85)
				,@Login_status		smallint
				,@Login_dbname		sysname
				,@Login_language	sysname
				,@Login_isntgroup	int
				,@Login_isntuser	int
				,@Script			VarChar(max)


	SELECT		@Login_name			= name
				,@Login_password	= password
				,@Login_sid			= sid
				,@Login_status		= status
				,@Login_dbname		= dbname
				,@Login_language	= language
				,@Login_isntgroup	= isntgroup
				,@Login_isntuser	= isntuser
	FROM		master.sys.syslogins
	WHERE		hasaccess = 1
			AND	name = @Login_name;


		IF @Login_isntgroup = 0 AND @Login_isntuser = 0
		BEGIN
			SELECT	@pwlen			= len(@Login_password)
					,@pwpos			= 0
					,@VCHARpassword	= NULL


			WHILE @pwpos < @pwlen
			BEGIN
				SET @pwpos +=1


				SET	@VCHARpassword =	COALESCE	(
													@VCHARpassword + '+ nchar(' + convert(varchar(10), unicode(Substring(@Login_password,@pwpos,1))) + ')'
													,'nchar(' + convert(varchar(10), unicode(Substring(@Login_password,@pwpos,1))) + ')'
													)
				--SELECT @pwlen,@Login_password,@pwpos,@VCHARpassword
			END


			--------------------  CONVERT THE SID FROM VARBINARY TO VARCHAR  -----------------------


			SELECT	@VCHARsid	= '0x'
					,@i			= 0
					,@binvalue	= @Login_sid
					,@length	= datalength(@binvalue)
					,@hexstring	= '0123456789ABCDEF'


			WHILE (@i < @length)
			BEGIN
				SET		@i +=1


				SELECT	@tempint		= convert(int, substring(@binvalue,@i,1))
						,@firstint		= floor(@tempint/16)
						,@secondint		= @tempint - (@firstint*16)
 						,@VCHARsid		= @VCHARsid + substring(@hexstring, @firstint+1, 1) + substring(@hexstring, @secondint+1, 1)
			END
		END


		--------------------  FORMAT THE OUTPUT  -----------------------
		SET @Script = ''


		SET @Script = @Script + '-------------------------------------------------'	+ CHAR(13) + CHAR(10)
		SET @Script = @Script + '-- Create login ''' + @Login_name + ''''			+ CHAR(13) + CHAR(10)
		SET @Script = @Script + '-------------------------------------------------'	+ CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)


		--  If this is being run on a sql2005 server, add logic to make sure the result script is used on a sql2005 server.
		IF ( 0 <> ( SELECT PATINDEX( '%[9].[00]%', @@version ) ) )
		BEGIN
			SET @Script = @Script + 'If ( 0 = ( SELECT PATINDEX( ''%[9].[00]%'', @@version ) ) )'	+ CHAR(13) + CHAR(10)
			SET @Script = @Script + 'BEGIN'															+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '	SET @Script = @Script + (''ERROR:  Unable to create login '''+@Login_name+''' to this server.  This login was scripted from a SQL 9.00 environment.''' + CHAR(13) + CHAR(10)
			SET @Script = @Script + 'END'	+ CHAR(13) + CHAR(10)
			SET @Script = @Script + 'ELSE'	+ CHAR(13) + CHAR(10)
		END
		ELSE
		BEGIN
			SET @Script = @Script + 'IF NOT EXISTS (SELECT * FROM master.sys.syslogins WHERE name = N'''+@Login_name+''')' + CHAR(13) + CHAR(10)
			SET @Script = @Script + '   BEGIN' + CHAR(13) + CHAR(10)
			SET @Script = @Script + '      DECLARE @cmd nvarchar(3000)' + CHAR(13) + CHAR(10)
			SET @Script = @Script + '' + CHAR(13) + CHAR(10)


			IF @Login_isntgroup = 0 AND @Login_isntuser = 0
			BEGIN
				SET @Script = @Script + '      SELECT @cmd = ''CREATE LOGIN ['+@Login_name+'] WITH PASSWORD = '''''' + '+@VCHARpassword+' +'''''' HASHED' + CHAR(13) + CHAR(10)
				SET @Script = @Script + '                                 ,DEFAULT_DATABASE = ['+@Login_dbname+']' + CHAR(13) + CHAR(10)
			END
			ELSE
			BEGIN
				SET @Script = @Script + '      SELECT @cmd = ''CREATE LOGIN ['+@Login_name+'] FROM WINDOWS' + CHAR(13) + CHAR(10)
				SET @Script = @Script + '                             WITH DEFAULT_DATABASE = ['+@Login_dbname+']' + CHAR(13) + CHAR(10)
			END


			IF @Login_language is not null
				SET @Script = @Script + '                                 ,DEFAULT_LANGUAGE = ['+@Login_language+']' + CHAR(13) + CHAR(10)


			IF @Login_isntgroup = 0 AND @Login_isntuser = 0
			BEGIN


				IF (SELECT is_policy_checked FROM master.sys.sql_logins WHERE name = @Login_name) = 1
					SET @Script = @Script + '                                 ,CHECK_POLICY = ON' + CHAR(13) + CHAR(10)
				Else
					SET @Script = @Script + '                                 ,CHECK_POLICY = OFF' + CHAR(13) + CHAR(10)


				IF (SELECT is_expiration_checked FROM master.sys.sql_logins WHERE name = @Login_name) = 1
					SET @Script = @Script + '                                 ,CHECK_EXPIRATION = ON' + CHAR(13) + CHAR(10)
				Else
					SET @Script = @Script + '                                 ,CHECK_EXPIRATION = OFF' + CHAR(13) + CHAR(10)


				SET @Script = @Script + '                                 ,SID = ' + @VCHARsid  + CHAR(13) + CHAR(10)
			END


			SET @Script = @Script + ''''					+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '        PRINT @cmd'	+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '        EXEC (@cmd)'	+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '   END'				+ CHAR(13) + CHAR(10)
			SET @Script = @Script + 'ELSE'					+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '   BEGIN'				+ CHAR(13) + CHAR(10)
			SET @Script = @Script + '      PRINT ''Note:  Login '''''+@Login_name+''''' already exists on this server.'''
			SET @Script = @Script + '   END'				+ CHAR(13) + CHAR(10)
			SET @Script = @Script + 'GO'					+ CHAR(13) + CHAR(10)
			SET @Script = @Script + ''						+ CHAR(13) + CHAR(10)


		END


	RETURN @Script


END
GO
