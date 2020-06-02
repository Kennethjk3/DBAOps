SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_DecimalToBinary]
(
	@Input bigint
)
RETURNS varchar(255)
AS
BEGIN

	DECLARE @Output varchar(255) = ''

	WHILE @Input > 0 BEGIN

		SET @Output = @Output + CAST((@Input % 2) AS varchar)
		SET @Input = @Input / 2

	END

	RETURN REVERSE(@Output)

END
GO
