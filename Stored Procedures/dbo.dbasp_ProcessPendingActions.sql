SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_ProcessPendingActions]


/*********************************************************
 **  Stored Procedure dbasp_ProcessPendingActions
 **  Written by Steve Ledridge, Virtuoso
 **  January 06, 2012
 **
 **  This sproc will process entries in the Pending_Actions table.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/06/2012	Steve Ledridge		New process.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd 				nvarchar(4000)
	,@save_PAid			int
	,@charpos			bigint
	,@save_servername		sysname
	,@save_servername2		sysname


----------------  initial values  -------------------
Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  If any rows ready to process are found, process them
If (select count(*) from dbo.Pending_Actions where RequestDate < getdate() and CompletedDate is null) > 0
   begin
   	Print 'Start Pending_Actions processing.'


	start_process01:


	Select @save_PAid = (select top 1 PAid from dbo.Pending_Actions where RequestDate < getdate() and CompletedDate is null)
	Select @cmd = (select top 1 cmd_text from dbo.Pending_Actions where PAid = @save_PAid)


	print @cmd
	exec(@cmd)

	update dbo.Pending_Actions set CompletedDate = getdate() where PAid = @save_PAid


	--  Check for more rows to process
	If (select count(*) from dbo.Pending_Actions where RequestDate < getdate() and CompletedDate is null) > 0
	   begin
		goto start_process01
	   end
   end
Else
   begin
	Print 'No rows to process'
	Print convert(nvarchar(25), getdate(), 121)
	Print ''
   end


----------------  End  -------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_ProcessPendingActions] TO [public]
GO
