SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SetDriveSpaceOverrideValue]
	(
	@DriveLetter		nVarChar(100)
	,@OverrideValue		nVarChar(100) = NULL
	)
AS
SET NOCOUNT ON;


DECLARE @Results TABLE
                 (
                    DriveLetter		NVARCHAR (100)
                    ,OverrideValue	NVARCHAR (100)
                 )


-- THIS MAKES SURE THAT THE Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor BRANCH EXISTS
EXEC[sys].[xp_instance_regwrite]	N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor','XX','reg_sz','0'
EXEC[sys].[xp_instance_regdeletevalue]	N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor','XX'


	EXEC[sys].[xp_instance_regwrite]
		N'HKEY_LOCAL_MACHINE'
		,N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor'
		,@DriveLetter
		,'reg_sz'
		,@OverrideValue


IF @OverrideValue IS NULL


	EXEC[sys].[xp_instance_regdeletevalue]
		N'HKEY_LOCAL_MACHINE'
		,N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor'
		,@DriveLetter


-- GET DISK ALERT OVERRIDES AT Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor
INSERT INTO @Results
EXEC [sys].[xp_instance_regenumvalues] N'HKEY_LOCAL_MACHINE',N'Software\${{secrets.COMPANY_NAME}}\Script\DiskMonitor'
SELECT * FROM @Results
GO
GRANT EXECUTE ON  [dbo].[dbasp_SetDriveSpaceOverrideValue] TO [public]
GO
