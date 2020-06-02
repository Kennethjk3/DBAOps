SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_AG_Get_Primary]
(
    @AGroup SYSNAME
)
RETURNS SYSNAME
AS
BEGIN
	DECLARE @Primary	SYSNAME

	IF @@microsoftversion / 0x01000000 >= 11
	IF SERVERPROPERTY('IsHadrEnabled') = 1
	BEGIN
		select	@Primary = primary_replica
		from		sys.dm_hadr_availability_group_states ags
		join		sys.availability_groups ag
			on	ags.group_id = ag.group_id
		WHERE	ag.name = @AGroup
	END
	ELSE
		SET @Primary = 'ERROR: Server Configuration does not Support Availability Groups.'
	ELSE
		SET @Primary = 'ERROR: Server Version does not Support Availability Groups.'

    SET @Primary = COALESCE(@Primary,'ERROR: Availability Group '+@AGroup+' does NOT exist.')

    RETURN @Primary
END
GO
