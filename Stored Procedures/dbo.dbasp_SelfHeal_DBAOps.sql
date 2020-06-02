SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SelfHeal_DBAOps]


/*********************************************************
 **  Stored Procedure dbasp_SelfHeal_DBAOps
 **  Written by Steve Ledridge, Virtuoso
 **  May 15, 2014
 **
 **  This dbasp is set up to fix security for auto SQL deployments.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	05/15/2014	Steve Ledridge		New Process
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@save_domain 		sysname
	,@share_path		sysname
	,@cmd			nvarchar(4000)
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname


declare  @outpath		varchar(255)


DECLARE @DriveLetter CHAR(1)


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername

Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end

Select @share_path = @save_servername+'_builds'


exec dbo.dbasp_get_share_path @share_path, @outpath output


Select @share_path = @outpath


----------------------  Main header  ----------------------


Print  ' '
Print  '/*******************************************************************'
Select @miscprint = 'Starting: dbasp_SelfHeal_DBAOps'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/

Select @save_domain = (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain')


If @save_domain = 'amer'
   begin
	If not exists (Select 1 from master.sys.server_principals where name = 'amer\seabuildbot')
	   begin
		Print 'Adding login ''amer\seabuildbot'''
		CREATE LOGIN [amer\seabuildbot] FROM WINDOWS WITH DEFAULT_DATABASE = [master], DEFAULT_LANGUAGE = us_english
	   end


	If not exists (SELECT 1 From master.sys.server_role_members rm, master.sys.server_principals lgn
				Where rm.role_principal_id = (select principal_id from master.sys.server_principals where name = 'sysadmin')
				and rm.member_principal_id = lgn.principal_id
				and lgn.name like '%amer\seabuildbot%')
	   begin
		Print 'Grant ''sa'' for amer\seabuildbot'
		exec sp_addsrvrolemember 'amer\seabuildbot', 'sysadmin';


		Select @cmd = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /grant "AMER\Seabuildbot":c'
		Print 'Assign CHANGE Permissions: "AMER\Seabuildbot" to the "' + @save_servername + '_builds" share using command: '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output

		Select @cmd = 'XCACLS "' + @share_path + '" /G "AMER\Seabuildbot":C /Y'
		Print 'Assign NTFS Permissions, "AMER\Seabuildbot" to the path "' + @share_path + '" using command: ' + @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	goto RESET_DRIVE_OWNERSHIP
   end


 If @save_domain = 'stage'
   begin
	If not exists (Select 1 from master.sys.server_principals where name = 'stage\Sbot-AHPagent')
	   begin
		Print 'Adding login ''stage\Sbot-AHPagent'''
		CREATE LOGIN [stage\Sbot-AHPagent] FROM WINDOWS WITH DEFAULT_DATABASE = [master], DEFAULT_LANGUAGE = us_english
	   end


	If not exists (SELECT 1 From master.sys.server_role_members rm, master.sys.server_principals lgn
				Where rm.role_principal_id = (select principal_id from master.sys.server_principals where name = 'sysadmin')
				and rm.member_principal_id = lgn.principal_id
				and lgn.name like '%stage\Sbot-AHPagent%')
	   begin
		Print 'Grant ''sa'' for stage\Sbot-AHPagent'
		exec sp_addsrvrolemember 'stage\Sbot-AHPagent', 'sysadmin';


		Select @cmd = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /grant "stage\Sbot-AHPagent":c'
		Print 'Assign CHANGE Permissions: "stage\Sbot-AHPagent" to the "' + @save_servername + '_builds" share using command: '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
		Print ' '

		Select @cmd = 'XCACLS "' + @share_path + '" /G "stage\Sbot-AHPagent":C /Y'
		Print 'Assign NTFS Permissions, "stage\Sbot-AHPagent" to the path "' + @share_path + '" using command: ' + @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
		Print ' '
	   end


	goto RESET_DRIVE_OWNERSHIP
   end


 If @save_domain = 'production'
   begin
	If not exists (Select 1 from master.sys.server_principals where name = 'production\pbot-ahpagent')
	   begin
		Print 'Adding login ''production\pbot-ahpagent'''
		CREATE LOGIN [production\pbot-ahpagent] FROM WINDOWS WITH DEFAULT_DATABASE = [master], DEFAULT_LANGUAGE = us_english
	   end


	If not exists (SELECT 1 From master.sys.server_role_members rm, master.sys.server_principals lgn
				Where rm.role_principal_id = (select principal_id from master.sys.server_principals where name = 'sysadmin')
				and rm.member_principal_id = lgn.principal_id
				and lgn.name like '%production\pbot-ahpagent%')
	   begin
		Print 'Grant ''sa'' for production\pbot-ahpagent'
		exec sp_addsrvrolemember 'production\pbot-ahpagent', 'sysadmin';


		Select @cmd = 'rmtshare \\' + @save_servername + '\' + @save_servername + '_builds /grant "production\pbot-ahpagent":c'
		Print 'Assign CHANGE Permissions: "production\pbot-ahpagent" to the "' + @save_servername + '_builds" share using command: '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
		Print ' '

		Select @cmd = 'XCACLS "' + @share_path + '" /G "production\pbot-ahpagent":C /Y'
		Print 'Assign NTFS Permissions, "production\pbot-ahpagent" to the path "' + @share_path + '" using command: ' + @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
		Print ' '
	   end


	goto RESET_DRIVE_OWNERSHIP
   end


RESET_DRIVE_OWNERSHIP:


-- RESET DRIVE OWNERSHIP
DECLARE DriveCursor CURSOR
FOR
select distinct drivename from DBAOps.dbo.dba_diskinfo where active = 'y' and drivename <> 'c'


OPEN DriveCursor;
FETCH DriveCursor INTO @DriveLetter;
WHILE (@@fetch_status <> -1)
   BEGIN
	IF (@@fetch_status <> -2)
	   BEGIN
		SET @CMD = 'takeown /f '+@DriveLetter+': /r /d y'
		exec xp_cmdshell @CMD
		SET @CMD = 'icacls '+@DriveLetter+':\ /setowner BUILTIN\Administrators /T /C /Q'
		exec xp_cmdshell @CMD
		SET @CMD = 'iCACLS '+@DriveLetter+':\ /T /C /Q /grant BUILTIN\Administrators:(OI)(CI)F /inheritance:e'


		exec xp_cmdshell @CMD
		SET @CMD = 'attrib '+@DriveLetter+':\* -s -r -h /S /D'
		exec xp_cmdshell @CMD
	   END


	FETCH NEXT FROM DriveCursor INTO @DriveLetter;
   END
CLOSE DriveCursor;
DEALLOCATE DriveCursor;


---------------------------  Finalization  -----------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_SelfHeal_DBAOps] TO [public]
GO
