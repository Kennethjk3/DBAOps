SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[BuildNumberSet]
	-- Add the parameters for the stored procedure here
	@DatabaseName NVarchar(128) NULL
   ,@BuildNumber  NVarchar(128) NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @query NVarchar(MAX);
	DECLARE @count_query NVarchar(MAX);
	DECLARE @count Int;

	SET @count_query
		= N'select COUNT(*) FROM  [' + @DatabaseName
		  + N'].[dbo].[SystemConfig] WHERE ConfigGroup like ''Build'' and ConfigName like ''BuildNumber'';';

	EXEC sp_executesql @count_query, N'@count int out', @count OUT;

	IF(@count < 1)
		SET @query
			= N'
 INSERT INTO [' + @DatabaseName
			  + N'].[dbo].[SystemConfig]
 	([ConfigGroup]
 	,[ConfigName]
 	,[ConfigValue])
 VALUES
 	(''Build'',''BuildNumber'',''' + @BuildNumber + N''');
 '		;
	ELSE
		SET @query
			= N'
       UPDATE [' + @DatabaseName + N'].[dbo].[SystemConfig]
    SET [ConfigValue] = ''' + @BuildNumber
			  + N'''
    WHERE ConfigGroup like ''Build'' and ConfigName like ''BuildNumber'';
 '		;

	EXEC(@query);
END;
GO
GRANT EXECUTE ON  [dbo].[BuildNumberSet] TO [public]
GO
