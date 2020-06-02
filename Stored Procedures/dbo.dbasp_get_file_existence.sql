SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_get_file_existence] (
						@filename nvarchar(260),
						@exists bit = 0 output
						)


/*********************************************************
 **  Stored Procedure dbasp_get_file_existence
 **  From MSSQL2000 master database
 **
 **  This dbasp is set up to check for the existance of a file.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/16/2006	Steve Ledridge		New sproc for DBAOps.  This existed in master
--						in sql2000, but was not included in sql 2005.
--	======================================================================================


-----------------  declares  ------------------


/**
Declare @filename nvarchar(260)
Declare @exists bit


Declare @filename = '\\lkhslaslkhds'
Declare @exists = 0
--**/


    DECLARE @command nvarchar(512)
    DECLARE @retcode int
	declare @echo_text nvarchar(20)


	select @echo_text = 'file_exists'


    /*
    ** The return code from xp_cmdshell is not a reliable way to check whether the file exists or
    ** not. It is always 0 on Win95 as long as xp_cmdshell succeeds.
    */


	select @command = N'if exist "' + @filename + N'" echo ' + @echo_text


    create table #text_ret(cmdoutput nvarchar(20) collate database_default null)


    insert into #text_ret exec @retcode = master..xp_cmdshell @command
	if @@error <> 0 or @retcode <> 0
		return 1


    if exists (select * from #text_ret where ltrim(rtrim(cmdoutput)) = @echo_text)
        select @exists = 1
    else
        select @exists = 0


    drop table #text_ret
GO
GRANT EXECUTE ON  [dbo].[dbasp_get_file_existence] TO [public]
GO
