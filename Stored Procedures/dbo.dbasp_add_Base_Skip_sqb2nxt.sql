SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_add_Base_Skip_sqb2nxt]  @SQBname sysname = NULL


/*********************************************************
 **  Stored Procedure dbasp_add_Base_Skip_sqb2nxt
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 27, 2008
 **
 **  This proc requires one input parm for a Baseline SQB file name.
 **
 **  This procedure inserts a row to the DBAOps.dbo.Base_Skip_sqb2nxt
 **  table.  This table is used in the 'Base - Local Process' SQL job.
 **  That process will not create a local NXT file for any SQB,
 **  BAK or cBAK file listed in the table.
 ***************************************************************/
AS
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	05/27/2008	Steve Ledridge		New Process
--	04/20/2011	Steve Ledridge		Changed to process BAK and cBAK files.
--	======================================================================================


/***
declare @SQBname sysname


select @SQBname = 'rightsprice'
--***/


Declare @error_count int


Select @error_count = 0


-- VALIDATE SQB input value:
If @SQBname is null or @SQBname = '' or @SQBname not like '%_prod%'
   begin
	raiserror('DBA WARNING: Invalid input for @SQBname.  Try ''DBname_prod.sqb''.',-1,-1)
	Select @error_count = @error_count + 1
	goto label99
   end


-- VALIDATE SQB input value - Already IN TARGET TABLE:
If exists(select * from DBAOps.dbo.Base_Skip_sqb2nxt where sqbname = @SQBname)
   begin
	raiserror('DBA WARNING: SQB name already in DBAOps.dbo.Base_Skip_sqb2nxt',-1,-1)
	Select @error_count = @error_count + 1
	goto label99
   end


-- INSERT SQB NAME INTO THE TARGET TABLE:
INSERT INTO DBAOps.dbo.Base_Skip_sqb2nxt VALUES (@SQBname, getdate())

-- FINALIZATION: RETURN SUCCESS/FAILURE --
label99:


Print ''
Print 'Current rows in dbo.Base_Skip_sqb2nxt'


Select * from DBAOps.dbo.Base_Skip_sqb2nxt


if @error_count > 0
   begin
	return (1)
   end
Else
   begin
	return  (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_add_Base_Skip_sqb2nxt] TO [public]
GO
