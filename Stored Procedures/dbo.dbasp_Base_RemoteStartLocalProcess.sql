SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_RemoteStartLocalProcess] (@environment sysname = null, @baseline_server sysname =null)


/*********************************************************
 **  Stored Procedure dbasp_Base_RemoteStartLocalProcess
 **  Written by Anne Varnes, Virtuoso
 **  June 24, 2008
 **
 **  This procedure is used to start the 'BASE - Local Process'
 **  baseline job out on dev, test, load, stage, alpha, QA,
 **  beta, candidate or prodsupport servers depending on priority.
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	06/24/2008	Anne Varnes		New process to start the BASE - Local Process
--						job based on priority.
--	08/22/2008	Steve Ledridge		New table dba_dbinfo.  No longer user start_priority.
--	10/13/2008	Steve Ledridge		Added "baselinefolder <> ''" to insert.
--      11/17/2008      Steve Ledridge	        Added "baseline_server" parameter to start remote
--                                              Base-LocalProcess jobs in Stage.
--	09/14/2009	Steve Ledridge		Added riaserror with nowait so we can see what has been done.
--	10/07/2009	Steve Ledridge		Added code for new environments (alpha, beta, etc.).
--	06/18/2010	Steve Ledridge		Insert rows into new table BaseLocal_Control.
--	05/28/2015	Steve Ledridge		New code for QA environment.
--	======================================================================================


/***
Declare @environment sysname
Declare @baseline_server sysname


Select @environment = 'test'
Select @baseline_server = 'DBAOpser02'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@charpos		int
	,@cmd			nvarchar(4000)
	,@error_count		int
	,@save_servername	sysname
	,@base_servername	sysname


DECLARE
	 @cu11base_sqlname	sysname


----------------  initial values  -------------------
Select @error_count = 0


--  Verify imput parm
if @environment not in ('dev', 'test', 'load', 'stage', 'alpha', 'beta', 'candidate', 'prodsupport', 'QA')
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid parameter for @environment'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


if @baseline_server IS NULL
   BEGIN
	SELECT @baseline_server = @@servername
   END


--  Create table variable
declare @servernames table (depl_sqlname sysname)

Select @save_servername = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


Insert into @servernames
SELECT distinct i.SQLName
from dbo.DBA_DBInfo AS i
JOIN dbo.db_ApplCrossRef AS d ON i.BaseLineFolder = d.RSTRfolder
where i.ENVname = @environment
and i.baselinefolder <> ''
and i.BaselineServername = @@servername
and d.Baseline_srvname = @baseline_server


--select * from @servernames


print 'Starting baseline server selection'
print ''
raiserror('', -1,-1) with nowait


If (select count(*) from @servernames) > 0
   begin
	Start_Baseline_JobStart_Selection:


	Select @cu11base_sqlname = (select top 1 depl_sqlname from @servernames order by depl_sqlname)

	Select @base_servername = @cu11base_sqlname


	Select @charpos = charindex('\', @base_servername)
	IF @charpos <> 0
	   begin
		Select @base_servername = substring(@base_servername, 1, (CHARINDEX('\', @base_servername)-1))
	   end


	--  Insert rows into the BaseLocal_Control table
	Insert into dbo.BaseLocal_Control values(@base_servername, @cu11base_sqlname, 'pending')


	--  Remove this record from @servernames and go to the next
	Delete from @servernames where depl_sqlname = @cu11base_sqlname
	If (select count(*) from @servernames) > 0
	   begin
		goto Start_Baseline_JobStart_Selection
	   end


   end


--  Finalization  -------------------------------------------------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Base_RemoteStartLocalProcess] TO [public]
GO
