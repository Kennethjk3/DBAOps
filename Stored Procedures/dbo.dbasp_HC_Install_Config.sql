SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Install_Config]


/*********************************************************
 **  Stored Procedure dbasp_HC_Install_Config
 **  Written by Steve Ledridge, Virtuoso
 **  November 04, 2014
 **  This procedure runs the Install_Config portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/04/2014	Steve Ledridge		New process.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--xp_cmdshell (self healing)
--verify login mode
--verify audit level


/***


--***/


DECLARE	 @miscprint			nvarchar(2000)
	,@cmd				nvarchar(500)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_servername3		sysname
	,@charpos			int
	,@save_test			nvarchar(4000)
	,@save_loginmode		sysname
	,@save_login_name		sysname
	,@save_auditlevel		sysname


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


CREATE TABLE 	#loginconfig		(
					name sysname NULL
					,configvalue sysname NULL
					)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Insatll Config'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Start xp_cmdshell (self healing)
Print 'Start xp_cmdshell (self healing)'
Print ''


IF NOT EXISTS (SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE '%xp_cmdshell%' AND value = 1)
   BEGIN
	SELECT @cmd = 'sp_configure ''xp_cmdshell'', ''1'''
	EXEC master.sys.sp_executeSQL @cmd


	SELECT @cmd = 'RECONFIGURE WITH OVERRIDE;'
	EXEC master.sys.sp_executeSQL @cmd
   END


Select @save_test = 'SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE ''%xp_cmdshell%'' AND value = 1'
IF EXISTS (SELECT 1 FROM sys.configurations WITH (NOLOCK) WHERE name LIKE '%xp_cmdshell%' AND value = 1)
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'xp_cmdshell', 'Pass', 'High', @save_test, null, null, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'xp_cmdshell', 'Fail', 'High', @save_test, null, null, null, getdate())
   END


--  Populate #loginconfig
INSERT INTO #loginconfig EXEC master.sys.xp_loginconfig
DELETE FROM #loginconfig WHERE name IS NULL
--select * from #loginconfig


--  Start verify login mode
Print 'Start verify login mode'
Print ''


Select @save_test = 'EXEC master.sys.xp_loginconfig'
SELECT @save_loginmode = (SELECT configvalue FROM #loginconfig WHERE name = 'login mode')
IF @save_loginmode IS NULL
   BEGIN
	SELECT @save_loginmode = 'unknown'
   END

IF  @save_loginmode = 'Mixed'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'login mode', 'Pass', 'Low', @save_test, null, @save_loginmode, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'login mode', 'Warning', 'Low', @save_test, null, @save_loginmode, null, getdate())
   END


--  Start verify audit level
--  Verify security audit level set to 'failure' (self heal)
Print 'Start verify audit level'
Print ''


Select @save_test = 'EXEC master.sys.xp_loginconfig'
SELECT @save_auditlevel = (SELECT configvalue FROM #loginconfig WHERE name = 'audit level')
IF @save_auditlevel IS NULL
   BEGIN
	SELECT @save_auditlevel = 'unknown'
   END

IF  @save_auditlevel = 'failure'
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'audit level', 'Pass', 'Low', @save_test, null, @save_auditlevel, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Config', 'audit level', 'Warning', 'Low', @save_test, null, @save_auditlevel, null, getdate())
   END


--  Finalization  ------------------------------------------------------------------------------


label99:


drop table #loginconfig
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Install_Config] TO [public]
GO
