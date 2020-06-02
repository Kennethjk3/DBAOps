SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_code_update_prep]


/**************************************************************
 **  Stored Procedure dbasp_code_update_prep
 **  Written by Steve Ledridge, Virtuoso
 **  March 25, 2016
 **
 **  This dbasp is set up to check for new updates of sproc
 **  dbasp_code_updates.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/13/2008	Steve Ledridge		New process.
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @cmd			nvarchar(4000)
	,@sqlcmd		nvarchar(500)
	,@charpos		int
	,@central_server 	sysname
	,@ENVname	 	sysname
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_filename		sysname
	,@save_cmdoutput	nvarchar(255)
	,@vchLabel		varchar(100)


create table #DirectoryTempTable(cmdoutput nvarchar(255) null)


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @central_server = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'CentralServer'
Select @ENVname = env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'ENVname'
--print @central_server
--print @ENVname


--  DBAOps Process ---------------------------------------------------------------------------------------------
start_DBAOps:


--  capture dir from central server
delete from #DirectoryTempTable
select @cmd = 'dir /B \\' + @central_server + '\' + @central_server + '_builds\DBAOps\' + @ENVname
Print @cmd
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
delete from #DirectoryTempTable where cmdoutput is null
delete from #DirectoryTempTable where cmdoutput not like '%dbasp_code_updates%'
--select * from #DirectoryTempTable


--  start process
start_process01:
If (select count(*) from #DirectoryTempTable) > 0
   begin
	Select @save_cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like '%dbasp_code_updates%')
	Select @save_filename = @save_cmdoutput


	--  check to see if this file has already been run
	If @save_filename not in (select vchNotes from DBAOps.dbo.build where vchName = 'DBAOps')
	   begin
		select @sqlcmd = 'sqlcmd -S' + @@servername + ' -dDBAOps -i\\' + @central_server + '\' + @central_server + '_builds\DBAOps\' + @ENVname + '\' + rtrim(@save_filename) + ' -o\\' + @save_servername + '\' + @save_servername2 + '_SQLjob_logs\dbasp_code_updates.txt -E'
		print @sqlcmd
		exec master.sys.xp_cmdshell @sqlcmd
		Select @vchLabel = convert(char(8), getdate(), 112)
		exec dbo.dbasp_UpdateBuild @DatabaseName = 'DBAOps', @vchLabel = @vchLabel, @vchNotes = @save_filename
	   end
   end


----------------  End  -------------------


label99:


Print ''
Print 'Code Update Prep Process Complete.'


drop table #DirectoryTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_code_update_prep] TO [public]
GO
