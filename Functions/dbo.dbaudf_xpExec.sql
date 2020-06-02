SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_xpExec](@cmd nvarchar(4000))
returns nvarchar(4000)

/**************************************************************
 **  User Defined Function dbaudf_xpExec
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 10, 2008
 **
 **  This dbaudf is set up to execute a shell command utilizing
 **  xp_cmdshell. This especially useful when used in table
 **  processing; thus eliminating the need for those nasty little cursors.
 **
 **  For Example:
 **
 **	SELECT DBAOps.dbo.dbaudf_xpExec('del '+columnvalue) from #cmdtable
 **
 **  Returns the submitted command.
 ***************************************************************/
as


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	12/10/2008	Steve Ledridge		New process
--
--	======================================================================================

/**
    declare @cmd nvarchar(4000)
    set @cmd = 'dir c:\'
**/


begin
    -----------------  declares  ------------------
    declare @ret nvarchar(4000)


    /****************************************************************
     *                MainLine
     ***************************************************************/
    exec master.sys.xp_cmdShell @cmd
    set @ret = 'exec master.sys.xp_cmdshell '''+@cmd+''''
    return @ret
END
GO
