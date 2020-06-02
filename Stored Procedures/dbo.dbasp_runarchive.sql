SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_runarchive]  @outpath varchar (255) = null

/*********************************************************
 **  Stored Procedure dbasp_runarchive                  
 **  Written by Steve Ledridge, Virtuoso                
 **  May 2, 2000                                      
 **  This procedure runs the archive process that is    
 **  used for disaster recovery.                        
 *********************************************************/
  as
set nocount on

--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	06/07/2002	Steve Ledridge		Canged output path to handel cluster instances.
--	06/10/2002	Steve Ledridge		Added cmds to create detach and attach scripts.
--	06/12/2002	Steve Ledridge		Added output path verification.
--	08/02/2002	Steve Ledridge		Added input parm for sysobjectprivledges.
--	08/30/2002	Steve Ledridge		Added new script for sysaddoperators.
--	10/01/2002	Steve Ledridge		Added new script for sysrestore_byDB.
--	10/10/2002	Steve Ledridge		Changed wait to 1 second between commands.
--	04/17/2003	Steve Ledridge		Changes for new instance share names.
--	09/16/2003	Steve Ledridge		Added new script for syscreateshares.
--	07/20/2005	Steve Ledridge		Added new script for SYSchangeobjectownerBYdb.
--	02/21/2006	Steve Ledridge		Modified for sql 2005.
--	05/19/2006	Steve Ledridge		Fixed servername in output path.
--	08/16/2006	Steve Ledridge		enabled syscreateshares
--	08/16/2006	Steve Ledridge		enabled dbasp_SYSrestoreBYdb
--	12/07/2006	Steve Ledridge		enabled dbasp_SYSsqlcomfig
--	05/01/2007	Steve Ledridge		Changed sqlcmd outpt to unicode.
--	03/10/2008	Steve Ledridge		Added dbasp_SYSaddsrvrolemembers.
--	05/16/2008	Steve Ledridge		Update width for sysjobs output to 2000.
--	08/31/2009	Steve Ledridge		Added BASE_archive process.
--	03/12/2010	Steve Ledridge		Added weekly baselinefor APPL jobs.
--	06/19/2010	Steve Ledridge		Added DR copy process using the local_control table.
--	06/21/2013	Steve Ledridge		Fixed bug with custom @outpath.
--	02/19/2016	Steve Ledridge		Added reporting section - output to dba_reports.
--	======================================================================================


/***
declare @outpath varchar (255)

select @outpath = null
--***/

DECLARE	 
	 @result		int
	,@miscprint		nvarchar(2000)
	,@print_flag		char(1)
	,@sqlcmd		nvarchar(500)
	,@cmd			nvarchar(500)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_servername3	sysname
	,@charpos		int
	,@Hold_hh		nvarchar(2)
	,@save_detail01		sysname
	,@save_detail02		sysname
	,@save_DRpath		nvarchar(500)
	,@save_Remote_server	sysname
	,@save_domain		sysname
	,@save_DBASQLpath	varchar (255)

DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@PathAndFile				VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@SQLEnv					SYSNAME
			,@central_server			SYSNAME

	EXEC DBAOps.dbo.dbasp_GetPaths -- @verbose = 1
		 @DataPath			= @DataPath			 OUT
		,@LogPath			= @LogPath			 OUT
		,@BackupPathL		= @BackupPathL		 OUT
		,@BackupPathN		= @BackupPathN		 OUT
		,@BackupPathN2		= @BackupPathN2		 OUT
		,@DBASQLPath		= @DBASQLPath		 OUT
		,@SQLAgentLogPath	= @SQLAgentLogPath	 OUT
		,@DBAArchivePath	= @DBAArchivePath	 OUT
		,@EnvBackupPath		= @EnvBackupPath	 OUT
		,@SQLEnv			= @SQLEnv			 OUT
		,@CentralServerShare= @central_server	 OUT



Select @print_flag = 'n'
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


If @outpath is null
   begin
		SET @outpath = @DBAArchivePath
	--Select @outpath = '\\' + @save_servername + '\' + @save_servername2 + '_dba_archive'
   end

--  Verify output path existance
create table #fileexists ( 
	doesexist smallint,
	fileindir smallint,
	direxist smallint)

Insert into #fileexists exec master.sys.xp_fileexist @outpath

If exists (select fileindir from #fileexists where fileindir = 1)
   begin
	Select @print_flag = 'y'
   end



If @print_flag = 'n'
   begin
	goto label99
   end

Select @outpath = @outpath + '\'


--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddalerts" -E -o' + @outpath + @save_servername3 + '_SYSaddalerts.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbaliases" -E -o' + @outpath + @save_servername3 + '_SYSadddbaliases.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSadddbrolemembers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbroles" -E -o' + @outpath + @save_servername3 + '_SYSadddbroles.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddextendedsps" -E -o' + @outpath + @save_servername3 + '_SYSaddextendedsps.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd
	
WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddlinkedservers" -E -o' + @outpath + @save_servername3 + '_SYSaddlinkedservers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd
	
WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddmasterlogins" -E -o' + @outpath + @save_servername3 + '_SYSaddmasterlogins.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd
	
--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddmasterloginsBYdb" -E -o' + @outpath + @save_servername3 + '_SYSaddmasterloginsBYdb.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd
	
--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddoperators" -E -o' + @outpath + @save_servername3 + '_SYSaddoperators.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddothermastersps" -E -o' + @outpath + @save_servername3 + '_SYSaddothermastersps.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd
	
WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddsrvrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSaddsrvrolemembers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddsysdbaliases" -E -o' + @outpath + @save_servername3 + '_SYSaddsysdbaliases.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddsysdbroles" -E -o' + @outpath + @save_servername3 + '_SYSaddsysdbroles.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddsysdbrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSaddsysdbrolemembers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSaddsysmessages" -E -o' + @outpath + @save_servername3 + '_SYSaddsysmessages.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSattach_userDBs" -E -o' + @outpath + @save_servername3 + '_SYSattach_userDBs.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSchgdbowner" -E -o' + @outpath + @save_servername3 + '_SYSchgdbowner.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSchangeobjectownerBYdb" -E -o' + @outpath + @save_servername3 + '_SYSchangeobjectownerBYdb.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSchguserdefaultdb" -E -o' + @outpath + @save_servername3 + '_SYSchguserdefaultdb.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYScreatedatabases" -E -o' + @outpath + @save_servername3 + '_SYScreatedatabases.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYScreateDBusers" -E -o' + @outpath + @save_servername3 + '_SYScreateDBusers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_syscreateshares" -E -o' + @outpath + @save_servername3 + '_SYScreateshares.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdbRestore" -E -o' + @outpath + @save_servername3 + '_SYSdbRestore.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdeletedbaliases" -E -o' + @outpath + @save_servername3 + '_SYSdeletedbaliases.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdetach_userDBs" -E -o' + @outpath + @save_servername3 + '_SYSdetach_userDBs.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropdbrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSdropdbrolemembers.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropdbroles" -E -o' + @outpath + @save_servername3 + '_SYSdropdbroles.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropDBusers" -E -o' + @outpath + @save_servername3 + '_SYSdropDBusers.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdroplinkedservers" -E -o' + @outpath + @save_servername3 + '_SYSdroplinkedservers.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropmasterlogins" -E -o' + @outpath + @save_servername3 + '_SYSdropmasterlogins.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropmasterloginsBYdb" -E -o' + @outpath + @save_servername3 + '_SYSdropmasterloginsBYdb.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropsrvrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSdropsrvrolemembers.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropsysdbrolemembers" -E -o' + @outpath + @save_servername3 + '_SYSdropsysdbrolemembers.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSdropsysdbroles" -E -o' + @outpath + @save_servername3 + '_SYSdropsysdbroles.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSgrantsysdbaccess" -E -o' + @outpath + @save_servername3 + '_SYSgrantsysdbaccess.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSgrantmasterlogins" -E -o' + @outpath + @save_servername3 + '_SYSgrantmasterlogins.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSgrantmasterloginsBYdb" -E -o' + @outpath + @save_servername3 + '_SYSgrantmasterloginsBYdb.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSgrantextSPprivileges" -E -o' + @outpath + @save_servername3 + '_SYSgrantextSPprivileges.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSgrantobjectprivileges @outpath = ''' + @outpath + ''' " -E -o' + @outpath + @save_servername3 + '_SYSgrantobjectprivileges.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSrestoreBYdb @outfiles = ''y''" -E'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSsetDBoptions" -E -o' + @outpath + @save_servername3 + '_SYSsetDBoptions.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSsetServerOptions" -E -o' + @outpath + @save_servername3 + '_SYSsetServerOptions.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSsetLinkedServerOptions" -E -o' + @outpath + @save_servername3 + '_SYSsetLinkedServerOptions.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSsetprocoption" -E -o' + @outpath + @save_servername3 + '_SYSsetprocoption.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSsqlconfig" -E -o' + @outpath + @save_servername3 + '_SYSsqlconfig.txt'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbmaintplan_DBs" -E -o' + @outpath + @save_servername3 + '_SYSadddbmaintplan_DBs.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbmaintplan_jobs" -E -o' + @outpath + @save_servername3 + '_SYSadddbmaintplan_jobs.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

--WAITFOR DELAY '000:00:01'
--SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSadddbmaintplans" -E -o' + @outpath + @save_servername3 + '_SYSadddbmaintplans.gsql'
--PRINT   @sqlcmd
--EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w2000 -u -Q"exec DBAOps.dbo.dbasp_SYSaddjobs @jobname = ''XXX''" -E -o' + @outpath + @save_servername3 + '_SYSaddjobs.gsql'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_SYSbase_archive" -E -o' + @outpath + @save_servername3 + '_BASE_archive.txt'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd


--  Baseline the deployment related APPL jobs every Friday night/Saturday morning
Set @Hold_hh = convert(nvarchar(2), getdate(), 8)

If (select datepart(weekday, getdate())) = 6 and @Hold_hh > 12
or (select datepart(weekday, getdate())) = 7 and @Hold_hh < 6
   begin
	EXEC @result = dbo.dbasp_base_APPL_JobScripting
   end



--  DR copy process
If exists (select 1 from dbo.Local_Control where subject = 'DR_ArchiveCopy')
   begin
	Select @save_detail01 = (select top 1 detail01 from dbo.Local_Control where subject = 'DR_ArchiveCopy')
	Select @save_DRpath = @save_detail01 + '\dba_archive' 

	Select @save_Remote_server = (select top 1 detail02 from dbo.Local_Control where subject = 'DR_ArchiveCopy')
	Select @save_domain = (select top 1 env_detail from dbo.local_serverenviro where env_type = 'domain')

	exec DBAOps.dbo.dbasp_File_mover @Remote_server = @save_Remote_server
					,@Remote_Domain = @save_domain
					,@CopyFrom_path = @outpath
					,@CopyTo_path =  @save_DRpath
					,@filemask = '*.*'
					,@pre_delete_target = 'y'

	Select @save_DRpath = @save_detail01 + '\dbasql'
	Select @save_DBASQLpath = '\\' + @save_servername + '\' + @save_servername2 + '_dbasql'
 
	exec DBAOps.dbo.dbasp_File_mover @Remote_server = @save_Remote_server
					,@Remote_Domain = @save_domain
					,@CopyFrom_path = @save_DBASQLpath
					,@CopyTo_path =  @save_DRpath
					,@filemask = '*.*'
					,@pre_delete_target = 'y'
   end







--  Reporting Section

Select @outpath = '\\' + @save_servername + '\' + @save_servername2 + '_dbasql\dba_reports\'

WAITFOR DELAY '000:00:01'
SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -u -Q"exec DBAOps.dbo.dbasp_REPORTsecurityaudit" -E -o' + @outpath + @save_servername3 + '_Security_Audit.txt'
PRINT   @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd





label99:

DROP TABLE #fileexists


If @print_flag = 'n'
   begin
	select @miscprint = 'DBA WARNING: Unable to write dba_archive file(s) to output path ''' + @outpath + ''''
	raiserror(@miscprint,1,-1) with log
	return 1
   end
Else
   begin
	return 0
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_runarchive] TO [public]
GO
