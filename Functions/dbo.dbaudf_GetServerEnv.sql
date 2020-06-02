SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetServerEnv]()
Returns		SYSNAME
--
--/*********************************************************
-- **  Function dbaudf_GetServerClass
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- ** January 27, 2020
-- **
-- **  This Function returns the Environment of server to be used for
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
	DECLARE		@SQLEnv		SYSNAME
	DECLARE		@SQLName	SYSNAME			= @@SERVERNAME

	SET @SQLEnv = CASE
					WHEN @SQLName Like '%VMSBETA%'										THEN 'VMSBETA'
					WHEN @SQLName Like 'SDT%'											THEN 'DESK'
					WHEN @SQLName Like 'SEA%'											THEN 'DESK'
					WHEN @SQLName Like '%PRO%'											THEN 'PRO'
					WHEN @SQLName Like '%STG2%'											THEN 'STG2'
					WHEN @SQLName Like '%STG%'											THEN 'STG'
					WHEN @SQLName Like '%CPI%'											THEN 'CPI'
					WHEN @SQLName Like '%QA1%'											THEN 'QA1'
					WHEN @SQLName Like '%QA2%'											THEN 'QA2'
					WHEN @SQLName Like '%QA%'											THEN 'QA'
					WHEN @SQLName Like '%DEV1%'											THEN 'DEV1'
					WHEN @SQLName Like '%DEV2%'											THEN 'DEV2'
					WHEN @SQLName Like '%DEV%'											THEN 'DEV'
					WHEN @SQLName Like '%RELEASE%'										THEN 'REL'
					WHEN @SQLName Like '%REL%'											THEN 'REL'
					WHEN @SQLName Like '%TST%'											THEN 'TST'
					WHEN @SQLName Like '%BACKLOG%'										THEN 'BLOG'
					WHEN @SQLName Like '%PREVIEW%'										THEN 'PRV'
					WHEN @SQLName IN ('SDCSQLBACKUPMGR','SDCSQLTOOLS','','','','','')	THEN 'PRO'
					WHEN @SQLName IN ('SDCSTGDM05','','','','','')						THEN 'VMSBETA'
					WHEN @SQLName IN ('SDCSTGDM06','','','','','')						THEN 'STG2'
					ELSE 'OTHER' 
					END 

	RETURN @SQLEnv
END
GO
