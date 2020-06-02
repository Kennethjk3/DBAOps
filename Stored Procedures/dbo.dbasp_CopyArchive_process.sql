SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CopyArchive_process] (@DomainName sysname = 'amer'
						,@SQLenv sysname = 'Production')


/**************************************************************
 **  Stored Procedure dbasp_CopyArchive_process
 **  Written by Steve Ledridge, Virtuoso
 **  October 22, 2008
 **
 **  This dbasp is set up to gather files from the dbasql
 **  and dba_archive folders for all supported SQL servers.
 **  The files and folders are placed in the Central_Archive
 **  share on each central server.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	10/22/2008	Steve Ledridge		New process.
--	01/05/2009	Steve Ledridge		Added code make sure we can connect to the
--						remote folder.
--	09/13/2011	Steve Ledridge		Updated central server share name.
--	======================================================================================


/***
Declare @DomainName sysname
Declare @SQLenv sysname


Select @DomainName = 'AMER'
Select @SQLenv = 'Production'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@cmd	 		nvarchar(4000)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@charpos		int
	,@save_dba_ServerName	sysname
	,@save_dba_SQLName	sysname
	,@hold_dba_SQLName	sysname
	,@fileexist_path	nvarchar(255)


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Create table variable
declare @servernames table (dba_servername sysname
			    ,dba_sqlname sysname)


Create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint)


/****************************************************************
 *                MainLine
 ***************************************************************/
Print  ' '
Select @miscprint = 'Start:  Copy Archive to central server process.'
Print  @miscprint


If @SQLenv like '%prod%'
   begin
	Insert into @servernames
	SELECT distinct ServerName, SQLName
	from dbo.DBA_Serverinfo
	where DomainName = @DomainName
	and SQLenv = 'Production'
	and active = 'y'
   end
Else
   begin
	Insert into @servernames
	SELECT distinct ServerName, SQLName
	from dbo.DBA_Serverinfo
	where DomainName = @DomainName
	and SQLenv <> 'Production'
	and active = 'y'
   end


--select * from @servernames order by dba_servername


If (select count(*) from @servernames) > 0
   begin
	start01:


	Select @save_dba_ServerName = (select top 1 dba_servername from @servernames order by dba_servername)
	Select @save_dba_SQLName = (select top 1 dba_sqlname from @servernames where dba_servername = @save_dba_ServerName)
	Select @hold_dba_SQLName = @save_dba_SQLName


	Select @charpos = charindex('\', @save_dba_SQLName)
	IF @charpos <> 0
	   begin
		Select @save_dba_SQLName = stuff(@save_dba_SQLName, @charpos, 1, '$')
	   end


	--  Make sure we can connect to the remote folder.
	Delete from #fileexists
	Select @fileexist_path = '\\' + @save_dba_ServerName + '\' + @save_dba_ServerName + '_dbasql'
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Print 'DBA Warning: Copy Archive Process unable to connect to remote dbasql share for server '+ @save_dba_ServerName
		goto skip_01
	   end


	--  Make sure we have a local folder for this sql instance
	--  If not, create one.  If so, remove it and create a new one.
	Delete from #fileexists
	Select @fileexist_path = '\\' + @save_servername + '\DBA_Central_Archive\' + @save_dba_SQLName
	Insert into #fileexists exec master.sys.xp_fileexist @fileexist_path
	If (select fileindir from #fileexists) <> 1
	   begin
		Select @cmd = 'mkdir "' + @fileexist_path + '"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @cmd = 'mkdir "' + @fileexist_path + '\dbasql"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @cmd = 'mkdir "' + @fileexist_path + '\dba_archive"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end
	Else
	   begin
		Select @cmd = 'rmdir "' + @fileexist_path + '" /S /Q'
		Print 'Remove central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @cmd = 'mkdir "' + @fileexist_path + '"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @cmd = 'mkdir "' + @fileexist_path + '\dbasql"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output


		Select @cmd = 'mkdir "' + @fileexist_path + '\dba_archive"'
		Print 'Creating central archivec folder using command '+ @cmd
		EXEC master.sys.xp_cmdshell @cmd, no_output
	   end


	--  Copy the dbasql files from the target server.
	select @cmd = 'robocopy /Z /R:3 /E \\' + @save_dba_ServerName + '\' + @save_dba_SQLName + '_dbasql ' + @fileexist_path + '\dbasql *.*'
	Print @cmd
	exec master.sys.xp_cmdshell @cmd


	--  Copy the dba_archive files from the target server.
	select @cmd = 'robocopy /Z /R:3 /E \\' + @save_dba_ServerName + '\DBA_Archive ' + @fileexist_path + '\dba_archive *.*'
	Print @cmd
	exec master.sys.xp_cmdshell @cmd


	skip_01:


	delete from @servernames where dba_servername = @save_dba_ServerName and dba_sqlname = @hold_dba_SQLName
	If (select count(*) from @servernames) > 0
	   begin
		goto start01
	   end


   end


----------------  End  -------------------
label99:


drop table #fileexists


Print  ' '
Select @miscprint = 'End:  Copy Archive to central server process.'
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_CopyArchive_process] TO [public]
GO
