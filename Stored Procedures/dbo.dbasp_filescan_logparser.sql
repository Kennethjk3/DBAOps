SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_filescan_logparser]


/**************************************************************
 **  Stored Procedure dbasp_filescan_logparser
 **  Written by Steve Ledridge and Steve Ledridge, Virtuoso
 **  April 29, 2010
 **
 **  This dbasp is set up to run the local filescan log parser process.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	04/29/2009	Steve Ledridge			New process.
--	======================================================================================


/*


--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd				VarChar(8000)
	,@charpos			int
	,@central_server		sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@Machine			sysname
	,@Instance			sysname
	,@Last				DateTime
	,@LastDate			VarChar(12)
	,@LastTime			VarChar(8)
	,@LogBufferMin			INT
	,@new_runtime_char		nvarchar(20)
	,@old_runtime_char		nvarchar(20)
	,@old_runtime			datetime


----------------  initial values  -------------------
SET @LogBufferMin = -20


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


If exists (select 1 from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_logparser_time')
   begin
	Select @old_runtime_char = (select top 1 env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_logparser_time')
	Select @old_runtime = convert(datetime, @old_runtime_char)
   end
Else
   begin
	Select @old_runtime = getdate()
   end


Select @new_runtime_char = convert(nvarchar(20), getdate(), 120)


SET @Last = DATEADD(mi,@LogBufferMin,@old_runtime)


SET @Last = COALESCE(@Last,GetDate()-30)


SELECT		@Machine	= REPLACE(@@servername,'\'+@@SERVICENAME,'')
		,@Instance	= REPLACE(@@SERVICENAME,'MSSQLSERVER','')
		,@LastDate	= LEFT(CONVERT(VarChar(20),@Last,120),10)
		,@LastTime	= RIGHT(CONVERT(VarChar(20),@Last,120),8)
		,@central_server = env_detail
from		DBAOps.dbo.Local_ServerEnviro
where		env_type = 'CentralServer'


If @central_server is null
   begin
	Select @miscprint = 'DBA WARNING: The central SQL Server is not defined for ' + @@servername + '.  The local filescan process failed'
	Print @miscprint
	raiserror(@miscprint,-1,-1)
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


Print  ' '
Select @miscprint = 'Filescan Log Parser process starting. ' + convert(varchar(30),getdate(),9)
Print  @miscprint


--  Process SQL Errorlog
Select	@cmd = '%windir%\system32\LogParser "file:\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\Queries\'
		+ 'SQLErrorLog2.sql?startdate=' + @LastDate + '+starttime='
		+ @LastTime +'+machine='
		+ @Machine + '+instance='
		+ @Instance + '+machineinstance='
		+ UPPER(REPLACE(@@servername,'\','$')) + '+OutputFile=\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\SQLErrorLOG_'
		+ UPPER(REPLACE(@@servername,'\','$'))
		+ '.w3c" -i:TEXTLINE -o:W3C -fileMode:0 -encodeDelim'


Print 'Process SQL Errorlog'
Print @cmd
exec master.sys.xp_cmdshell @cmd


--  Set Instance for the next two commands
IF @Instance = ''
   begin
	SET @Instance = '-'
   end


--  Process SQL Agent logs
Select	@cmd = '%windir%\system32\LogParser "file:\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\Queries\'
		+ 'SQLAGENT.sql?startdate=' + @LastDate + '+starttime='
		+ @LastTime +'+machine='
		+ @Machine + '+instance='
		+ @Instance + '+machineinstance='
		+ UPPER(REPLACE(@@servername,'\','$')) + '+OutputFile=\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\SQLAGENT_'
		+ UPPER(REPLACE(@@servername,'\','$'))
		+ '.w3c" -i:TSV -o:W3C -fileMode:0 -iSeparator:space'
		+ ' -iHeaderFile:"\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\Queries\SQLAGENT.tsv"'


Print 'Process SQL Agent Logs'
Print @cmd
exec master.sys.xp_cmdshell @cmd


--  Process Server Event Logs
Select	@cmd = '%windir%\system32\LogParser "file:\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\Queries\'
		+ 'ServerEvent.sql?startdate=' + @LastDate + '+starttime='
		+ @LastTime +'+machine='
		+ @Machine + '+instance='
		+ @Instance + '+machineinstance='
		+ UPPER(REPLACE(@@servername,'\','$')) + '+OutputFile=\\'
		+ @central_server + '\' + @central_server
		+ '_filescan\Aggregates\ServerEvent_'
		+ UPPER(REPLACE(@@servername,'\','$'))
		+ '.w3c" -i:EVT -o:W3C -fileMode:0 -binaryFormat:ASC -oDQuotes:ON -encodeDelim:ON -resolveSIDs:ON'


Print 'Process Server Event Logs'
Print @cmd
exec master.sys.xp_cmdshell @cmd


delete from DBAOps.dbo.Local_ServerEnviro where env_type = 'check_logparser_time'
insert into DBAOps.dbo.Local_ServerEnviro(env_type, env_detail) Values ('check_logparser_time', @new_runtime_char)


----------------  End  -------------------
label99:


Print  ' '
Select @miscprint = 'Filescan Log Parser process completed. ' + convert(varchar(30),getdate(),9)
Print  @miscprint
GO
GRANT EXECUTE ON  [dbo].[dbasp_filescan_logparser] TO [public]
GO
