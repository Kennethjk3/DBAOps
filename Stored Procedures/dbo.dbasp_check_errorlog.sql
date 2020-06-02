SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_check_errorlog] (@size_limit int = 500000)


/**************************************************************
 **  Stored Procedure dbasp_check_errorlog
 **  Written by Steve Ledridge, Virtuoso
 **  Based on code from Francis Stanisci
 **  October 9, 2003
 **
 **  This dbasp is set up to check the size of the SQL errorlog.
 **  If the errorlog is larger than the specified size limit,
 **  it will be recycled using master..sp_cycle_errorlog.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	10/09/2003	Steve Ledridge				New process.
--	11/20/2003	Steve Ledridge				Fixed substring of the file size number.
--	08/22/2006	Steve Ledridge				Updated for SQL 2005.
--	11/21/2012	Steve Ledridge				@file_size to bigint.
--	======================================================================================


/***
Declare @size_limit bigint
Select @size_limit = 500
--***/


-----------------  declares  ------------------
DECLARE
	 @cmd	 			nvarchar(500)
	,@file_size 			bigint
	,@max_file_size 		bigint
	,@charpos			int
	,@path_log			sysname
	,@save_text			nvarchar(500)


--  Maximum allowed file size set in next statement. Adjust accordingly
If @size_limit is not null
   begin
	SET @max_file_size = @size_limit
   end
Else
   begin
	SET @max_file_size = 500000 --  set to 500kb
   end


--  Create table to hold results from DIR command
CREATE table #dir_results (dir_row varchar(255))


--  Get the path to the SQL log folder (s\b at the same path as the data folder which holds the master mdf)
select @path_log = filename from master.sys.sysfiles where name = 'master'


Select @charpos = charindex('\data\master.mdf', @path_log)
Select @path_log = substring(@path_log, 1, (@charpos - 1))
Select @path_log = @path_log + '\log'


SELECT @cmd = 'DIR "' + @path_log + '\errorlog*" /-c'


--  Execute DIR command
INSERT #dir_results
EXEC ('master.sys.xp_cmdshell ''' + @cmd + '''')


--  EXEC ('master..xp_cmdshell ''' + @install_path + '''')  /* for debugging */


--  select * from #dir_results where dir_row like '% errorlog%' /* for debugging  */


--  Extract file size for active Errorlog
SELECT @save_text = (select * FROM #dir_results WHERE dir_row like '%errorlog')
SELECT @save_text = substring(@save_text, (PATINDEX('% errorlog', @save_text))-15, 15)
SELECT @file_size = ltrim(rtrim(@save_text))


If @save_text is null
   begin
	SELECT @save_text = (select * FROM #dir_results WHERE dir_row like '%ERRORLOG.OUT')
	SELECT @save_text = substring(@save_text, (PATINDEX('% ERRORLOG.OUT', @save_text))-15, 15)
	SELECT @file_size = ltrim(rtrim(@save_text))
   end


--  Report file size
PRINT 'ERRORLOG File size is: ' + cast(@file_size as varchar(30))


IF @file_size > @max_file_size
   BEGIN
	PRINT 'This file is too large.  Cycling the SQL Errorlog'
	EXEC master.sys.sp_cycle_errorlog
   END
ELSE
   BEGIN
	PRINT 'This file size is OK'
   END


----------------  End  -------------------


drop table #dir_results
GO
GRANT EXECUTE ON  [dbo].[dbasp_check_errorlog] TO [public]
GO
