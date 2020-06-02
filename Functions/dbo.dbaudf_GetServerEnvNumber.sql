SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE     FUNCTION [dbo].[dbaudf_GetServerEnvNumber](@SQLEnv SYSNAME = NULL)
Returns		INT
--
--/*********************************************************
-- **  Function dbaudf_GetServerClass
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- ** January 27, 2020
-- **
-- **  This Function returns the Environment Higherarchy Number of server to be used for
-- **  monitoring rules.
-- **
-- ***************************************************************/
AS
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	==================	======================================================
--	01/27/2020	Steve Ledridge		New Function
--	======================================================================================
BEGIN
	DECLARE			@SQLEnvNum	INT

	SET @SQLEnvNum = CASE @SQLEnv
					WHEN 'PRO'			 THEN 1

					WHEN 'STG'			 THEN 2
					WHEN 'STG2'			 THEN 2
					WHEN 'VMSBETA'		 THEN 2

					WHEN 'PRV'			 THEN 3
					
					WHEN 'REL'			 THEN 4
					WHEN 'TST'			 THEN 5

					WHEN 'QA'			 THEN 6
					WHEN 'QA1'			 THEN 6
					WHEN 'QA2'			 THEN 6
					
					WHEN 'CPI'			 THEN 7
					
					WHEN 'DEV'			 THEN 8
					WHEN 'DEV1'			 THEN 8
					WHEN 'DEV2'			 THEN 8
					
					WHEN 'BLOG'			 THEN 9
					ELSE 99
					END 

	RETURN @SQLEnvNum
END
GO
