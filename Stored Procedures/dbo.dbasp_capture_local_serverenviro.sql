SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_capture_local_serverenviro]


/***************************************************************
 **  Stored Procedure dbasp_capture_local_serverenviro
 **  Written by Steve Ledridge, Virtuoso
 **  January 03, 2003
 **
 **  This sproc is set up to;
 **
 **  Capture local server information such as the servername
 **  and the drive path's for the local shares.  This information
 **  will then be used by the maintenance process.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     			Desc
--	==========	==================	=============================================
--	01/03/2003	Steve Ledridge		New process.
--	02/21/2003	Steve Ledridge		Modified delete from local_serverinfo table.
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	02/04/2005	Steve Ledridge		Added capture for Instance and ShareHeader info.
--	03/29/2005	Steve Ledridge		Set central server name.
--	05/20/2005	Steve Ledridge		Added SQL Port Info.
--	08/19/2005	Steve Ledridge		Modify delete from table Local_ServerEnviro so
--									that backup_type is maintained.
--	12/13/2005	Steve Ledridge		Added row for ENVname info.
--	02/15/2006	Steve Ledridge		Modified for sql2005.
--	03/13/2006	Steve Ledridge		Added code for royaltydatabase service account.
--	04/04/2006	Steve Ledridge		If the domain is not in the listed domains, the
--									server will be it's own central server.
--	04/07/2006	Steve Ledridge		Code for new sproc dbasp_regread.
--	05/03/2006	Steve Ledridge		Added clean up for the service account to remove the '@'
--	06/01/2006	Steve Ledridge		Added Alpha environment.
--	01/03/2007	Steve Ledridge		Changed central server DBAOpser to DBAOpser04.
--	03/23/2007	Steve Ledridge		New code for Alliant 'rylwdb' servers.
--	08/28/2007	Steve Ledridge		New check for service accounts with @ embedded.
--	11/06/2007	Steve Ledridge		Fixed reg read for port num.
--	11/12/2007	Steve Ledridge		Changed HKLM to HKEY_LOCAL_MACHINE.
--	11/13/2007	Steve Ledridge		Fixed port number section (bad if stmt).
--	12/13/2007	Steve Ledridge		Added return(0).
--	04/30/2008	Steve Ledridge		Added step to drop job 'Base - Local Process' in production.
--	05/06/2008	Steve Ledridge		Code for new svc account in prod (sqladminprod2008).
--	05/22/2008	Steve Ledridge		Check for one more reg key for port info.
--	05/06/2008	Steve Ledridge		Code for new svc account in stage (sqladminstage2008).
--	08/26/2008	Steve Ledridge		New path for port in x64 reg.
--	09/16/2008	Steve Ledridge		seafresqldba02 to seafresql01.
--	11/06/2008	Steve Ledridge		Code to enable job MON - SQL Performance Reporting in prod.
--	11/25/2008	Steve Ledridge		More code for royaltydatabase service account.
--	01/30/2009	Steve Ledridge		Changed the code to accommodate the new service account naming standard
--	10/07/2009	Steve Ledridge		Added code for new environments (alpha, beta, etc.).
--	03/16/2010	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply05.
--	06/02/2010	Steve Ledridge		Changed seafrestgsql to fresdbasql01.
--	08/12/2010	Steve Ledridge		Added If stmt for port capture.
--	09/13/2011	Steve Ledridge		seafresqldba01 to seapsqldba01.
--	06/18/2012	Steve Ledridge		Changed central server seapsqldply05 to DBAOpser04.
--	07/18/2012	Steve Ledridge		Changes missing share message to DBA Note.
--	09/03/2013	Steve Ledridge		Changed fresdbasql01 to seasdbasql01.
--	09/16/2013	Steve Ledridge		New code for ENVname = local.
--	10/08/2013	Steve Ledridge		Changed seaexsqlmail to seapdbasql02.
--	04/16/2014	Steve Ledridge		Changed seapsqldba01 to seapdbasql01.
--	05/01/2014	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply04.
--	05/28/2015	Steve Ledridge		New code for QA environment. Also added BackupPathOverride.
--	04/21/2016	Steve Ledridge		New code AG Group processing.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint					NVARCHAR(4000)
	,@command 					NVARCHAR(4000)
	,@len						INT
	--,@save_servername			sysname
	--,@save_servername2			sysname
	,@save_domain				sysname
	,@save_port					sysname
	,@save_sqlinstance			sysname
	,@save_envname				sysname
	,@save_install_folder		sysname
	,@parm01					VARCHAR(100)
	,@outpath					VARCHAR(255)
	,@save_BackupPathOverride	varchar(500)
	,@charpos					INT
	,@isNMinstance				char(1)
	,@fileexist_path			sysname
	,@error_count				int
	,@in_key					sysname
	,@in_path					sysname
	,@in_value					sysname
	,@result_value				nvarchar(500)
 	,@save_productversion		sysname
	,@save_AGname				sysname
	,@save_AGrole				sysname

			-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
DECLARE		@DataPath					VarChar(8000)
			,@LogPath					VarChar(8000)
			,@BackupPathL				VarChar(8000)
			,@BackupPathN				VarChar(8000)
			,@BackupPathN2				VarChar(8000)
			,@BackupPathA				VarChar(8000)
			,@DBASQLPath				VarChar(8000)
			,@SQLAgentLogPath			VarChar(8000)
			,@DBAArchivePath			VarChar(8000)
			,@EnvBackupPath				VarChar(8000)
			,@CleanBackupPath			VARCHAR(8000)
			,@SQLEnv					VarChar(10)	
			,@RootNetworkBackups		VarChar(8000)
			,@RootNetworkFailover		VarChar(8000)
			,@RootNetworkArchive		VarChar(8000)
			,@RootNetworkClean			VARCHAR(8000)

DECLARE		@ShareName					SYSNAME
			,@SharePath					VarChar(8000)
			,@ShareDesc					Varchar(8000)
			,@SQLShareDrive				CHAR(2)

DECLARE		@PathAndFile				VarChar(8000)

DECLARE		@CMD		VarChar(8000)
			,@Path		VarChar(8000)


		----------------  initial values  -------------------

		-- GET PATHS FROM [DBAOps].[dbo].[dbasp_GetPaths]
		EXEC DBAOps.dbo.dbasp_GetPaths
			@DataPath				= @DataPath				OUT
			,@LogPath				= @LogPath				OUT
			,@BackupPathL			= @BackupPathL			OUT
			,@BackupPathN			= @BackupPathN			OUT
			,@BackupPathN2			= @BackupPathN2			OUT
			,@BackupPathA			= @BackupPathA			OUT
			,@DBASQLPath			= @DBASQLPath			OUT
			,@SQLAgentLogPath		= @SQLAgentLogPath		OUT
			,@DBAArchivePath		= @DBAArchivePath		OUT
			,@EnvBackupPath			= @EnvBackupPath		OUT
			,@SQLEnv				= @SQLEnv				OUT
			,@RootNetworkBackups	= @RootNetworkBackups	OUT	
			,@RootNetworkFailover	= @RootNetworkFailover	OUT	
			,@RootNetworkArchive	= @RootNetworkArchive	OUT
			,@RootNetworkClean		= @RootNetworkClean		OUT
			,@Verbose				= 0				


Select
	 @save_domain 			= ' '
	,@isNMinstance			= 'n'
	,@error_count			= 0


--  Create Temp Tables
Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


Create table #loginconfig(name1 sysname null, config_value sysname null)


IF EXISTS	(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_StringToTable(DBAOps.dbo.dbaudf_GetEV('path'),';')
			WHERE		SplitValue = 'C:\Tools' OR SplitValue = 'C:\Tools\'
			)
	SET @Path = 'C:\Tools'
ELSE IF EXISTS	(
			SELECT		*
			FROM		DBAOps.dbo.dbaudf_StringToTable(DBAOps.dbo.dbaudf_GetEV('path'),';')
			WHERE		SplitValue = 'C:\DBAFiles' OR SplitValue = 'C:\DBAFiles\'
			)
	SET @Path = 'C:\DBAFiles'
ELSE
	SET @Path = 'C:\Windows\system32'


SET @CMD = 'xcopy \\SDCPROFS.virtuoso.com\CleanBackups\DBAOps\System32\rmtshare.exe '+@Path+' /c /q /y'
exec xp_cmdshell @CMD

--  Clear out the serverenviro table
delete from DBAOps.dbo.Local_ServerEnviro
where env_type not like ('check%')
  and env_type <> 'backup_type'
  and env_detail not in ('PRIMARY', 'SECONDARY')

  SET @save_ENVname = CASE WHEN @SQLEnv = 'pro' THEN 'Production' WHEN @SQLEnv = 'STG' THEN 'STAGE' ELSE @SQLEnv END

--  Inset Domain and Servername info
SET @save_domain = dbaops.dbo.dbaudf_GetLocalFQDN()

	insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('domain',				@save_domain					)
	insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('SRVname',				@@servername					)
	insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('Instance',				@@servicename					)
	insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('CentralServer',		'SDCSQLTOOLS.DB.VIRTUOSO.COM'	)
	
	IF @save_ENVname		IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('ENVname',				@save_ENVname		)

	IF @DataPath			IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('DataPath',				@DataPath			)
	IF @LogPath				IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('LogPath',				@LogPath			)
	IF @BackupPathL			IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('BackupPathL',			@BackupPathL		)
	IF @BackupPathN			IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('BackupPathN',			@BackupPathN		)
	IF @BackupPathN2		IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('BackupPathN2',			@BackupPathN2		)
	IF @BackupPathA			IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('BackupPathA',			@BackupPathA		)
	IF @DBASQLPath			IS NOT NULL INSERT into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('DBASQLPath',			@DBASQLPath			)
	IF @SQLAgentLogPath		IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('SQLAgentLogPath',		@SQLAgentLogPath	)
	IF @DBAArchivePath		IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('DBAArchivePath',		@DBAArchivePath		)
	IF @EnvBackupPath		IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('EnvBackupPath',		@EnvBackupPath		)
	IF @SQLEnv				IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('SQLEnv',				@SQLEnv				)
	IF @RootNetworkBackups	IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('RootNetworkBackups',	@RootNetworkBackups	)
	IF @RootNetworkFailover IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('RootNetworkFailover',	@RootNetworkFailover)
	IF @RootNetworkArchive	IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('RootNetworkArchive',	@RootNetworkArchive	)
	IF @RootNetworkClean	IS NOT NULL insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('RootNetworkClean',		@RootNetworkClean	)


SELECT	@SQLShareDrive = MAX(DriveLetter)
FROM	DBAOps.dbo.dbaudf_ListDrives() 
WHERE	DriveLetter IN ('C:','D:')


	DECLARE ShareCursor CURSOR
	FOR
	SELECT		'BulkDataLoad'				,@SQLShareDrive + '\SQLShare\BulkDataLoad'		,'Virtuoso Specific Share'							UNION ALL
	SELECT		'SSIS'						,'C:\SSIS'										,'Virtuoso Specific Share'							UNION ALL
	SELECT		'FileDrop'					,@SQLShareDrive + '\SQLShare\FileDrop'			,'Virtuoso Specific Share'							UNION ALL
	SELECT		'ImageUpload'				,@SQLShareDrive + '\SQLShare\Imageupload'		,'Virtuoso Specific Share'							UNION ALL
	SELECT		'Intellidon'				,@SQLShareDrive + '\SQLShare\Intellidon'		,'Virtuoso Specific Share'							UNION ALL
	SELECT		'DBASQL'					,@DBASQLPath									,'DBAOps - Report Output Share'						UNION ALL
	SELECT		'DBA_Archive'				,@DBAArchivePath								,'DBAOps - Archive Scripts Used to recreate Server'	UNION ALL
	SELECT		'SQLServerAgent'			,@SQLAgentLogPath								,'DBAOps - Agent Job Log Files Share'				UNION ALL
	SELECT		'SQLBackups'				,@BackupPathL									,'DBAOps - Local Backup Path'


OPEN ShareCursor;
FETCH ShareCursor INTO @ShareName,@SharePath,@ShareDesc;
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		----------------------------
		---------------------------- CURSOR LOOP TOP
		IF LEN(@SharePath) > 3													-- REMOVE TRAILING SLASH ON ANYTHING BUT ROOT DIRECTORIES
			SET @SharePath = REPLACE(REPLACE(@SharePath+'|','\|','|'),'|','')

		--  **************************************************************************************
		--  Create Share
		--  **************************************************************************************
		SELECT	@PathAndFile	= @SharePath + '\' + 'tests.txt'

		exec [DBAOps].[dbo].[dbasp_FileAccess_Write] '', @PathAndFile,0,1 -- MAKE SURE FILE AND PATH EXISTS


		Select @cmd = 'rmtshare \\' + @@SERVERNAME + '\' + @ShareName + ' /DELETE'
		RAISERROR('Removing the "%s" share using command: %s',-1,-1,@ShareName,@cmd) WITH NOWAIT
		EXEC master.sys.xp_cmdshell @cmd , no_output
		RAISERROR ('',-1,-1) WITH NOWAIT

		Select @cmd = 'rmtshare \\' + @@SERVERNAME + '\' + @ShareName + ' = "' + @SharePath + '" /unlimited'
		RAISERROR('Creating the "%s" share using command: %s',-1,-1,@ShareName,@cmd) WITH NOWAIT
		EXEC master.sys.xp_cmdshell @cmd , no_output
		RAISERROR ('',-1,-1) WITH NOWAIT

		Select @cmd = 'NET SHARE '+ @ShareName + ' /REMARK:"'+@ShareDesc+'"'
		RAISERROR('Adding Description to the "%s" share using command: %s',-1,-1,@ShareName,@cmd) WITH NOWAIT
		EXEC master.sys.xp_cmdshell @cmd , no_output
		RAISERROR ('',-1,-1) WITH NOWAIT

		Select @cmd = 'rmtshare \\' + @@SERVERNAME + '\' + @ShareName + ' /grant administrators:f'
		Print 'Assign FULL Permissions, Local administrators to the "BulkDataLoad" share using command: ' + @cmd
		EXEC master.sys.xp_cmdshell @cmd , no_output
		Print ' '

		--Select @cmd = 'rmtshare \\' + @@SERVERNAME + '\' + @ShareName + ' /Remove everyone'
		--Print 'Remove Share permissions for "Everyone" from the "BulkDataLoad" share using command: ' + @cmd
		--EXEC master.sys.xp_cmdshell @cmd , no_output
		--Print ' '


		---------------------------- CURSOR LOOP BOTTOM
		----------------------------
	END
 	FETCH NEXT FROM ShareCursor INTO @ShareName,@SharePath,@ShareDesc;
END
CLOSE ShareCursor;
DEALLOCATE ShareCursor;



--  Get Port Info for this instance
Set @result_value = ''
If @@servername not like '%\%'
   begin
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp'
	select @in_value = 'TcpPort'
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


If @result_value is null or @result_value = ''
   begin
	--  Get the instalation directory folder name
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
	select @in_value = @save_sqlinstance
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output


	select @save_install_folder = @result_value
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @save_install_folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPall'
	select @in_value = 'TcpPort'
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output


	If @result_value is null or @result_value = ''
	   begin
		select @in_key = 'HKEY_LOCAL_MACHINE'
		select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @save_install_folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPall'
		select @in_value = 'TcpDynamicPorts'
		exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
	   end


	If @result_value is null or @result_value = ''
	   begin
		select @in_key = 'HKEY_LOCAL_MACHINE'
		select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @save_install_folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPall'
		select @in_value = 'TcpPort'
		exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
	   end
   end


If @@version like '%x64%' and (@result_value is null or @result_value = '')
   begin
	select @save_install_folder = @result_value
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\' + @save_sqlinstance + '\MSSQLServer\SuperSocketNetLib\Tcp'
	select @in_value = 'TcpPort'
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value, @result_value output
   end


If @result_value is null or @result_value = ''
   begin
	Select @result_value = 'Error'
   end


Select @save_port = @result_value
--Print @save_port
insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('SQL Port', @save_port)


--  Remove 'Base - Local Process' from production if it exists
If exists (Select * from msdb.dbo.sysjobs where (name = N'BASE - Local Process'))
   and (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'envname') = 'production'
   begin
	EXEC msdb.dbo.sp_delete_job @job_name = N'Base - Local Process'
   end


--  Enable job 'MON - SQL Performance Reporting' in production
If exists (Select * from msdb.dbo.sysjobs where (name = N'MON - SQL Performance Reporting'))
   and (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'envname') = 'production'
   begin
	exec msdb.dbo.sp_update_job @job_name = 'MON - SQL Performance Reporting', @enabled = 1
   end


--  Set AvailGroup Status


--  Check SQL version
IF @@microsoftversion / 0x01000000 < 11
  or SERVERPROPERTY('IsHadrEnabled') = 0 -- availability groups not enabled on the server
   BEGIN
	Select @miscprint = 'Skipping Set AvailGroup Status process for server - ' + @@servername
	Print  @miscprint
	Print ''
	goto skip_AGsection
   END


--  Check for availgrps - if none, exit
IF @@microsoftversion / 0x01000000 >= 11
  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	If not exists (select 1 from sys.availability_groups_cluster)
	   begin
		Select @miscprint = 'No Availability Groups found.'
		Print  @miscprint
		goto skip_AGsection
	   end
   END


select * from [dbo].[Local_ServerEnviro]


Select @save_AGname = ''


Start_AGchange:


Select @save_AGname = (select top 1 name from sys.availability_groups_cluster where name > @save_AGname order by name)
--print @save_AGname


Select @save_AGrole = (SELECT ARS.role_desc
			FROM
			 sys.availability_groups_cluster AS AGC
			  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
			   ON
			    RCS.group_id = AGC.group_id
			  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
			   ON
			    ARS.replica_id = RCS.replica_id
			WHERE
			    AGC.name = @save_AGname
			and RCS.replica_server_name = @@servername)


If @save_AGrole is null
   begin
	Select @save_AGrole = 'unknown'
   end


--print @save_AGrole


If exists (select 1 from [dbo].[Local_ServerEnviro] where env_type = @save_AGname)
   begin
	Update [dbo].[Local_ServerEnviro] set env_detail = @save_AGrole where env_type = @save_AGname
   end
Else
   begin
	Insert into [dbo].[Local_ServerEnviro] values (@save_AGname, @save_AGrole)
   end


Start_AGchange_skip:


If exists (select top 1 name from sys.availability_groups_cluster where name > @save_AGname order by name)
   begin
	goto Start_AGchange
   end


skip_AGsection:


--  Process AvailGrp jobs
exec dbo.dbasp_AG_PropagateJobInfo


-------------------------------------------------------------------------------------------------------------
drop table #loginconfig
drop table #fileexists


If @error_count > 0
   begin
	return(1)
   end
Else
   begin
	Print 'Environment information has been loaded and standard folders and shares verified'
	return(0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_capture_local_serverenviro] TO [public]
GO
