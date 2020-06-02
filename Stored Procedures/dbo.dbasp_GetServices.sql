SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetServices]
AS
DECLARE @XML XML
DECLARE @XML_as_String VARCHAR(MAX)
DECLARE @Results TABLE (TheXML VARCHAR(8000), theOrder INT IDENTITY(1,1) PRIMARY KEY)
declare @sql varchar(200)

set @sql = '@powershell -noprofile -command "Get-WmiObject win32_service | select name , startname, startmode, State|ConvertTo-XML -As string"'
INSERT INTO @Results(TheXML)
EXEC xp_cmdshell @sql

SELECT @XML_as_String=COALESCE(@XML_as_String,'') + theXML 
  FROM @Results 
  WHERE theXML IS NOT NULL 
  ORDER BY theOrder 

SELECT  @XML = @XML_as_String

;WITH		Results
			AS
			(
			SELECT		DENSE_RANK() OVER (ORDER BY [object]) AS unique_object
						,[property].value('@Name', 'Varchar(20)') AS [Attribute]
						,[property].value('(./text())[1]', 'Varchar(20)') AS [Value]
			FROM		@XML.nodes('Objects/Object') AS b ([object])
			CROSS APPLY	b.object.nodes('./Property') AS c (property)
			)

SELECT		T1.unique_object	[ID]
			,T1.Value			[ServiceName]
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
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetServices] TO [public]
GO
