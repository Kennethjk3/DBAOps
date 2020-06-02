SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ShowBackupRestoreStatus]
AS
	-----------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------
	--				SHOW SYS PROCESSES THAT IDENTIFY A PERCENT DONE GENERALLY BACKUP AND RESTORES
	-----------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------


	CREATE TABLE #TempOutput ([dd:hh:mm:ss.mss] VARCHAR(15),[sql_text] XML,[login_name] SYSNAME,[percent_complete] FLOAT,[program_name] VARCHAR(MAX))

	EXEC master.dbo.sp_whoisactive @destination_table = '#TempOutput',@output_column_list = '[dd%][sql_text][login_name][percent_complete][program_name]'

	SELECT		[dd:hh:mm:ss.mss]
				,dbaops.dbo.dbaudf_returnPart(REPLACE(REPLACE(CAST(sql_text as VarChar(max)),'<?query --',''),'FROM','|'),1) [Command]
				,[percent_complete]
				,[program_name]
				,DBAOps.[dbo].[dbaudf_Translate_APP_NAME] ([program_name],'JobName') [JobName]
				,DBAOps.[dbo].[dbaudf_Translate_APP_NAME] ([program_name],'StepName') [StepName]

	FROM		#TempOutput T1

	WHERE	percent_complete IS NOT NULL
	
	ORDER BY [percent_complete] DESC
GO
GRANT EXECUTE ON  [dbo].[dbasp_ShowBackupRestoreStatus] TO [public]
GO
