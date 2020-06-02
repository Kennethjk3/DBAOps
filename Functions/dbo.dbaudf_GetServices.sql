SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetServices]()
RETURNS @services TABLE 
(
	[ServiceName]		SYSNAME
	,[ServiceAccount]	SYSNAME
	,[StartMode]		SYSNAME
	,[State]			SYSNAME
)
AS
BEGIN
	DECLARE @XML XML
	DECLARE @sql NVarChar(4000)

	set @sql = 
	'DECLARE @XML_as_String VARCHAR(MAX)
	DECLARE @Results TABLE (TheXML VARCHAR(8000), theOrder INT IDENTITY(1,1) PRIMARY KEY)
	INSERT INTO @Results(TheXML)
	EXEC xp_cmdshell ''@powershell -noprofile -command "Get-WmiObject win32_service | select name , startname, startmode, State|ConvertTo-XML -As string"''
	SELECT @XML_as_String=COALESCE(@XML_as_String,'''') + theXML 
	  FROM @Results 
	  WHERE theXML IS NOT NULL 
	  ORDER BY theOrder 
	SELECT  @XML = @XML_as_String'


	DECLARE @OutputText VarChar(max)
	--EXEC DBAOps.dbo.dbasp_RunQuery @Name= 'GetServices', @Query = 'Select @@ServerName [ServerName]', @ServerName = @@ServerName, @DBName = 'DBAOps'
	--								, @Login = 'LinkedServer_User', @Password = '4vnetonly'	
	--								, @OutputFile = 'T:\GetServices.txt', @OutputText = @OutputText 
	--SELECT @OutputText

	--EXEC sp_executesql @stmt = @sql, @params = N'@XML XML OUT',@XML = @XML OUT
	SELECT @OutputText = dbaops.dbo.dbaudf_execute_tsql('SELECT 1 [A],2 [B],3 [C]' )

	;WITH		Results
				AS
				(
				SELECT		DENSE_RANK() OVER (ORDER BY [object]) AS unique_object
							,[property].value('@Name', 'Varchar(20)') AS [Attribute]
							,[property].value('(./text())[1]', 'Varchar(20)') AS [Value]
				FROM		@XML.nodes('Objects/Object') AS b ([object])
				CROSS APPLY	b.object.nodes('./Property') AS c (property)
				)
	INSERT INTO	@services
	SELECT		T1.Value			[ServiceName]
				,T2.Value			[ServiceAccount]
				,T3.Value			[StartMode]
				,T4.Value			[State]
	FROM		(
				SELECT		unique_object
							,Value
				FROM		Results
				WHERE		Attribute = 'name'
				) T1
	JOIN		(
				SELECT		unique_object
							,Value
				FROM		Results
				WHERE		Attribute = 'startname'
				)T2										ON T2.unique_object = T1.unique_object
	JOIN		(
				SELECT		unique_object
							,Value
				FROM		Results
				WHERE		Attribute = 'startmode'
				)T3										ON T3.unique_object = T1.unique_object
	JOIN		(
				SELECT		unique_object
							,Value
				FROM		Results
				WHERE		Attribute = 'State'
				)T4										ON T4.unique_object = T1.unique_object

    RETURN 
END
GO
