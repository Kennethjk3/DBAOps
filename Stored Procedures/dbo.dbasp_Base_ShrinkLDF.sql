SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Base_ShrinkLDF] (@DBname sysname = null)

/*********************************************************
 **  Stored Procedure dbasp_Base_ShrinkLDF
 **  Written by Steve Ledridge, Virtuoso
 **  March 22, 2010
 **
 **  This proc accepts one optional input parm; DBname.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/22/2010	Steve Ledridge		New process
--	======================================================================================


/***
Declare @DBname sysname


Select @DBname = 'wcdswork'
--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(255)
	,@cmd				sysname


DECLARE
	 @cu22fileid			smallint
	,@cu22name			nvarchar(128)
	,@cu22filename			nvarchar(260)


----------------  initial values  -------------------


/****************************************************************
 *                MainLine
 ***************************************************************/


If @DBname is null or @DBname = ''
   begin
	Print 'DBA Warning:  DBname must be provided for this process.'
	goto label99
   end


If @DBname not in (select name from master.sys.databases)
   begin
	Print 'DBA Warning:  A valid DBname must be provided for this process.'
	goto label99
   end


If DATABASEPROPERTYEX (@DBname,'status') <> 'ONLINE'
   begin
	Print 'DBA Warning:  The DBname provided is offline.'
	Print ' '
	goto label99
   end


If DATABASEPROPERTY(rtrim(@DBname), 'IsReadOnly') = 1
   begin
	Print 'DBA Warning:  The DBname provided is in read only mode.'
	Print ' '
	goto label99
   end


--  Cursor for the log file names
EXECUTE('DECLARE cu22_file Insensitive Cursor For ' +
  'SELECT f.fileid, f.name, f.filename
   From [' + @DBname + '].sys.sysfiles  f ' +
  'Where f.groupid = 0
   Order By f.fileid For Read Only')


OPEN cu22_file


WHILE (22=22)
   Begin
	FETCH Next From cu22_file Into @cu22fileid, @cu22name, @cu22filename
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_file
	      BREAK
           end


	Select @cmd = 'sqlcmd -S' + @@servername + ' -d' + @DBname + ' -Q"DBCC SHRINKFILE ([' + rtrim(@cu22name) + '])" -E'
	Print @cmd


	EXEC master.sys.xp_cmdshell @cmd


	Print ' '


   End  -- loop 22
   DEALLOCATE cu22_file


---------------------------  Finalization  -----------------------
label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Base_ShrinkLDF] TO [public]
GO
