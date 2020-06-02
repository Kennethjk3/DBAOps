SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_sys32_copy]


/*********************************************************
 **  Stored Procedure dbasp_sys32_copy
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  April 24, 2013
 **
 **  This procedure is used for copying files from the
 **  central system32_standard folder to the local Windows
 **  system32 folder.
 **
 **  Note:  Local files will not be overwritten if they already exist.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/24/2013	Steve Ledridge		New process
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	  @miscprint		nvarchar(4000)
	 ,@cmd			nvarchar(500)
	 ,@central_server	sysname


----------------  initial values  ------------------


Select @central_server = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'CentralServer'


/****************************************************************
 *                MainLine
 ***************************************************************/


Print 'Start sys32 copy process'
Print ''


Select @cmd = 'robocopy /Z /R:3 /XO /XN /XX \\' + @central_server + '\' + @central_server + '_builds\DBAOps\System32_standard %windir%\system32'
print @cmd
exec master.sys.xp_cmdshell @cmd


Select @cmd = 'robocopy /Z /R:3 /XO /XN /XX \\' + @central_server + '\' + @central_server + '_builds\DBAOps c:\ DBA_DiskCheck_DoNotDelete.txt'
print @cmd
exec master.sys.xp_cmdshell @cmd


-------------------   end   --------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_sys32_copy] TO [public]
GO
