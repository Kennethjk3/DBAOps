SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_DataBaseMirroring_MonitoringCheck]
(
    @RequiredMirroredDBs	VarChar(max)
	,@ExpectedPrimary		SYSNAME
)
RETURNS INT
AS
BEGIN
		DECLARE		@ActualPrimary			SYSNAME
		DECLARE		@MinRole				INT
		DECLARE		@MaxRole				INT
		DECLARE		@Results				INT = 0


		SELECT		@MinRole = MIN(ISNULL(T4.mirroring_role,0))
					,@MaxRole = MAX(ISNULL(T4.mirroring_role,0))
					,@ActualPrimary = MAX(CASE T4.mirroring_role WHEN 1 THEN @@SERVERNAME ELSE T4.mirroring_partner_instance END)
		FROM		sys.databases T1
		JOIN		DBAOps.dbo.dbaudf_StringToTable(@RequiredMirroredDBs,'|') T2
				ON	T2.SplitValue = T1.name
		LEFT JOIN	sys.database_mirroring T4
			ON	T1.database_id = T4.database_id
		WHERE		T4.mirroring_guid IS NOT NULL
			OR		T1.name IN (SELECT SplitValue FROM DBAOps.dbo.dbaudf_StringToTable(@RequiredMirroredDBs,'|'))


		IF @MinRole = 0
			SET		@Results = -1						-- ONE OR MORE REQUIRED DATABASES ARE NOT MIRRORED
		ELSE IF @MinRole != @MaxRole
			SET		@Results = 0						-- SPLIT BRAIN-ish  SOME DATABASES ARE PRINCIPAL AND SOME ARE MIRRORS
		ELSE IF @ExpectedPrimary = @ActualPrimary
			SET		@Results = 1						-- ALL DATABASES ARE PRINCIPAL ON THE EXPECTED PRIMARY
		ELSE IF @ExpectedPrimary != @ActualPrimary
			SET		@Results = 2						-- ALL DATABASES ARE NOT PRINCIPAL ON THE EXPECTED PRIMARY


		RETURN		@Results


END
/*
--	EXAMPLE USAGE
	SELECT	[DBAOPS].[dbo].[dbaudf_DataBaseMirroring_MonitoringCheck] ('AppLogArchive|EnterpriseServices|TravelMart_DNN|VCOM|ComposerSL|GEOdata|TRANSIENT','SDCPROSQL01')


	-- RESULTS TRANSLATION
		-- -1	= ONE OR MORE REQUIRED DATABASES ARE NOT MIRRORED
		--  0	= SPLIT BRAIN-ish  SOME DATABASES ARE PRINCIPAL AND SOME ARE MIRRORS
		--  1	= ALL DATABASES ARE PRINCIPAL ON THE EXPECTED PRIMARY
		--  2	= ALL DATABASES ARE NOT PRINCIPAL ON THE EXPECTED PRIMARY


*/
GO
