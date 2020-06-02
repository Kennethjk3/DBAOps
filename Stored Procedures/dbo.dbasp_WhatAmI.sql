SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_WhatAmI]
			(
			@NoSelectOut	BIT		= 0
			,@ObjectType	sysname		= NULL OUT
			,@ObjectName	sysname		= NULL OUT
			,@ObjectID	Int		= NULL OUT
			)
AS
BEGIN
	DECLARE		@BinVar	varbinary(128)

	-- GET CONTEXT_INFO AND CLEAN OUT RIGHT PADDED 0's
	SELECT	@BinVar	= CAST(REPLACE(CAST(CONTEXT_INFO() AS VarChar(128)),CHAR(0),'') AS VarBinary(128))

	IF @BinVar = CAST(CAST(@@PROCID  AS varchar(128)) AS VarBinary(128))
	BEGIN
		-- CLEAR CONTEXT_INFO IF SET TO THIS SPROC
		SET @BinVar = 0x0
		SET CONTEXT_INFO @BinVar
	END


	SELECT		@ObjectType	= 'SQL AGENT JOB'
			,@ObjectName	= SJ.name
	FROM		master.dbo.sysprocesses p
	JOIN		msdb.dbo.sysjobs sj
		ON	DBAOps.dbo.dbaudf_hex_to_char(sj.job_id,16) = SUBSTRING(p.Program_name,32,32)
	where		p.Program_name Like 'SQLAgent%'
		AND	p.spid = @@spid


	IF @ObjectName IS NULL
		SELECT		@ObjectType	= type_desc
				,@ObjectName	= name
				,@ObjectID	= object_id
		FROM		sys.objects
		WHERE		object_id = CAST(REPLACE(CAST(@BinVar AS VarChar(128)),CHAR(0),'') AS INT)


	SELECT		@ObjectType = COALESCE(@ObjectType,'UNKNOWN')
			,@ObjectName = COALESCE(@ObjectName,'UNKNOWN')


	PRINT		'-- ' + @ObjectType + ':' + @ObjectName + ':' + CAST(COALESCE(@ObjectID,'') AS VarChar(50))

	If @NoSelectOut = 0
		SELECT @ObjectType AS [OBJECT_TYPE], @ObjectName AS [OBJECT_NAME], @ObjectID AS [OBJECT_ID]

	RETURN coalesce(@ObjectID,0)
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_WhatAmI] TO [public]
GO
