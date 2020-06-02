SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_get_share_path] (@share_name varchar(255),@phy_path varchar(100) OUTPUT)


/*********************************************************
 **  Stored Procedure dbasp_get_share_path
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  10/28/2002
 **
 **  This procedure gets the drive path for a defined share.
 ***************************************************************/
  as


set nocount on


--     Created: 10-28-2002
--
--      Author: Steve Ledridge
--
--     Purpose: Retreive the physical path for a given share.
--
--        Note: This is only meant to work with servers that use the following share naming
--              convention \\<server_name>\<server_name>_<share_name>
--
--    Required: Share name, per convention above, i.e. only the share name as it would appear above
--
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	10/28/2002	Steve Ledridge			New process
--	02/15/2005	Steve Ledridge			Modified fro sql2005.
--	08/02/2007	Steve Ledridge			Added some diag lines.
--	04/16/2010	Steve Ledridge          Added logic to Return Directory if it is passed in as a Share Name.
--	11/20/2017	Steve Ledridge			Modified to Just Call dbaudf_GetSharePath2 Function
--	======================================================================================
IF CHARINDEX(':',@share_name) > 0 -- IF CONTAINS A ":" THEN IT MUST BE A DIRECTORY PATH
BEGIN
	SET @phy_path = @share_name
END
ELSE
	SET @phy_path = DBAOps.dbo.dbaudf_GetSharePath2(@share_name)


--/*
--declare @share_name varchar(255)
--declare @phy_path varchar(100)


--select @share_name = 'pcsqldev01$a_nxt'
--select @phy_path = ''


--DECLARE
--	 @netuse_servername	sysname
--	,@cmd			varchar(255)


--IF CHARINDEX(':',@share_name) > 0 -- IF CONTAINS A ":" THEN IT MUST BE A DIRECTORY PATH
--BEGIN
--	SET @phy_path = @share_name
--END
--ELSE
--BEGIN
--	Select @netuse_servername = case charindex('\', @@servername)
--	                            when 0 then @@servername
--	                            else substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
--	                            end


--	--PRINT @netuse_servername /* for debugging */


--	Create table #ShareTempTable(path nvarchar(500) null)
--	Select @cmd = 'RMTSHARE \\' + @netuse_servername + '\' + @share_name


--	Insert into #ShareTempTable
--	exec master.sys.xp_cmdshell @cmd


--	--select * from #ShareTempTable


--	Select @phy_path = substring(path,charindex('h',path)+1,len(path)-charindex('h',path))
--	from #ShareTempTable
--	where path like 'path%'


--	select @phy_path = ltrim(rtrim(@phy_path))
--	--print @phy_path


--	drop table #ShareTempTable


--END
----*/
----PRINT @phy_path


--/* Sample


--declare @outpath varchar(255)


--exec dbo.dbasp_get_share_path 'builds', @outpath output


--select @outpath


--*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_get_share_path] TO [public]
GO
