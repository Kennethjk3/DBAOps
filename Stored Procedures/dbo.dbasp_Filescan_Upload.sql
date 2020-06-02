SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Filescan_Upload]
    @outshare varchar (255) = null     /** file output share name override **/
/***************************************************************
 **  Stored Procedure dbasp_Filescan_Upload
 **  Written by Steve Ledridge, Virtuoso
 **  July 3, 2001
 **
 **  This dbasp is set up to upload and process the daily
 **  filescan temp file.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	05/06/2002	Steve Ledridge		Added code to delete dba_archive and dba_reports
--                                              related data from the filescan_exclude table.
--	06/21/2002	Steve Ledridge		Modified @@servername usage.
--	09/24/2002	Steve Ledridge		Modified output share default
--	04/18/2003	Steve Ledridge		Modified to use filescan share
--	05/04/2006	Steve Ledridge		Updated for SQL 2005
--	07/10/2007	Anne Varnes		Changed fulltext column setting from nvarchar (4000) to nvarchar(MAX)
--	09/25/2008	Steve Ledridge		Bulk Insert changed to BCP and cursor removed.
--	======================================================================================


/*
declare @outshare nvarchar(255)


--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(255)
	,@save_scantext		nvarchar(256)
	,@hold_scantext		nvarchar(125)
	,@SQLString		nvarchar(255)
	,@Result		int
	,@error_flag		int
	,@save_servername	sysname
	,@charpos		int
	,@cmd			nvarchar(500)


----------------  Initialize values  -------------------
Select @error_flag = 0


Select @save_servername		= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
   end


If @outshare is null
   begin
	Select @outshare = @save_servername + '_filescan'
   end


--  Create temp table for upload
create table ##filescanTemp (fulltext nvarchar (MAX) NULL)


delete from DBAOps.dbo.filescan_temp


----------------  Upload file to process  -------------------
Select @cmd = 'bcp ##filescanTemp in "\\' + @save_servername + '\' + @outshare + '\filescan_result\filescanall_temp.rpt" -c -T'
Print @cmd
EXEC @Result = master.sys.xp_cmdshell @cmd


--select * from ##filescanTemp


IF @Result <> 0
   begin
	select @miscprint = 'DBA WARNING: Filescan file upload error on server ' + @@servername
	raiserror(@miscprint,-1,-1) with log
	Select @error_flag = 1
	goto label99
   end


If (select count(*) from ##filescanTemp) = 0
   begin
	goto label99
   end


--  Transfer data from the temp table to the filescan_temp table (varchar(max) to varchar(125)
delete from DBAOps.dbo.filescan_temp


insert into DBAOps.dbo.filescan_temp select convert(nvarchar(256),fulltext) from ##filescanTemp


delete from DBAOps.dbo.filescan_temp where fulltext = char(9)


delete from DBAOps.dbo.filescan_temp where fulltext not like '\\%'


delete from DBAOps.dbo.filescan_temp where fulltext like '%.mdmp%'


----------------  Delete all rows from the filescan_current table  -------------------
delete from DBAOps.dbo.filescan_current


----------------  Delete all dba_reports and dba_archive related rows from the filescan_exclude table  -------------------
delete from DBAOps.dbo.filescan_exclude where scantext like '%dba_archive%'
delete from DBAOps.dbo.filescan_exclude where scantext like '%dba_reports%'


----------------  Set filescan_exclude use flag  -------------------
update DBAOps.dbo.filescan_exclude set useflag = 'n'


--  Start data compare  -------------------
start_loop01:


Select @save_scantext = (select top 1 fulltext from DBAOps.dbo.filescan_temp)
Select @hold_scantext = left(@save_scantext, 125)
--print @hold_scantext
--raiserror('', -1,-1) with nowait


If exists (select 1 from DBAOps.dbo.filescan_exclude where scantext = @hold_scantext)
   begin
	update DBAOps.dbo.filescan_exclude set useflag = 'y' where scantext = @hold_scantext
   end
Else
   begin
	insert into DBAOps.dbo.filescan_exclude values (@hold_scantext, 'y')
	insert into DBAOps.dbo.filescan_current values (@save_scantext)
   end


--  Look for more rows to process
delete from DBAOps.dbo.filescan_temp where fulltext = @save_scantext
If (select count(*) from DBAOps.dbo.filescan_temp) > 0
   begin
	goto start_loop01
   end


---------------------------  Finalization  -----------------------


delete from DBAOps.dbo.filescan_exclude where useflag = 'n'


label99:


drop table ##filescanTemp


If @error_flag <> 0
   begin
        return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Filescan_Upload] TO [public]
GO
