SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Filescan_Central_Report]
/***************************************************************
 **  Stored Procedure dbasp_Filescan_Central_Report
 **  Written by Steve Ledridge, Virtuoso
 **  July 3, 2001
 **
 **  This dbasp is set up to create the daily filescan report.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==================================================
--	04/26/2002	Steve Ledridge		Revision History added
--	09/24/2002	Steve Ledridge		Modified output share default
--	10/11/2002	Steve Ledridge		Limit output to a width of 255
--	04/18/2003	Steve Ledridge		Modified to use filescan share
--	05/04/2006	Steve Ledridge		Updated for SQL 2005
--	06/21/2006	Steve Ledridge		Added blank line for each new server.
--	08/16/2006	Steve Ledridge		Added blank space after file path end
--	06/06/2007	Steve Ledridge		Combined failed logins into one line per server if over 50
--	07/10/2007	Anne Varnes		Changed nvarchar(4000) to nvarchar(MAX) on @cu11fulltext AND ##filescanHeader
--	12/29/2008	Steve Ledridge		Added functionality to exclude certain items via a pre
--					        pre-determined threshold.
--	06/17/2009	Steve Ledridge		Major revision to support local filescan process.
--	07/01/2009	Steve Ledridge		Seperate section for production and non-production.
--	08/10/2009	Steve Ledridge		Moved the nocheck section to the local filescan process.
--	======================================================================================


--/*
--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint		nvarchar(4000)
	,@hold_scantext		nvarchar(100)
	,@hold_header		nvarchar(255)
	,@SQLString		nvarchar(255)
	,@Result		int
	,@error_flag		int
	,@save_servername	sysname
	,@match_name		nvarchar(255)
	,@hold_name		sysname
	,@charpos		int
	,@failed_login_count	int


DECLARE
	 @cu10servername	sysname
	,@cu11fulltext		nvarchar(MAX)
	,@cu12fulltext		nvarchar(MAX)
	,@cnt			int
	,@dt01			sysname
	,@dt02			sysname
        ,@dt03			sysname
	,@dt04			sysname


----------------  Initialize values  -------------------
Select @error_flag = 0
Select @hold_name = ''
Select @failed_login_count = 0


Select @save_servername		= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
   end


Select @hold_header = '** SQL FileScan for All Environments:  MSSQL Logs, SQL Agent Logs, Job Logs, Reporting Files, Archive Files.'


----------------  Print headers for filescan report  -------------------
Print  ' '
Print  '************************************************************************************************************'
Print  @hold_header
Print  '************************************************************************************************************'
Select @miscprint = '** Date: ' + convert(char(30), getdate(), 109)
Print  @miscprint
Print  '************************************************************************************************************'


update DBAOps.dbo.filescan_central set reported = 'y' where reported = 'n'


----------------  Cursor10  -------------------
EXECUTE('DECLARE cu10_current Insensitive Cursor For ' +
  'SELECT s.ServerName
   From DBAOps.dbo.DBA_ServerInfo  s
   Where s.active = ''y''
   and s.SQLEnv = ''production''
   Order by s.ServerName For Read Only')


OPEN cu10_current


WHILE (10=10)
 Begin
	FETCH Next From cu10_current Into @cu10servername
	IF (@@fetch_status < 0)
           begin
              CLOSE cu10_current
	      BREAK
           end


	--  Set all rows that include this servername
	update DBAOps.dbo.filescan_central set reported = 'x' where fulltext like '\\' + @cu10servername + '%'


 End  -- loop 10
DEALLOCATE cu10_current


--  Report production issues


Print  ' '
Print  '************************************************************************************************************'
Print  '--  Production Section'
Print  '************************************************************************************************************'
Print  ' '


----------------  Cursor for filescan upload data  -------------------
EXECUTE('DECLARE cu11_current Insensitive Cursor For ' +
  'SELECT c.fulltext
   From DBAOps.dbo.filescan_central  c
   Where c.reported = ''x''
   Order by c.fulltext For Read Only')


OPEN cu11_current


WHILE (11=11)
 Begin
	FETCH Next From cu11_current Into @cu11fulltext
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_current
	      BREAK
           end


	--  Add a blank line to the report if this is a line from a different server
	Select @match_name = left(@cu11fulltext, 255)
	If left(@match_name, 2) = '\\'
	   begin
		Select @charpos = charindex('\', @match_name, 3)
		IF @charpos <> 0
		   begin
			Select @match_name = substring(@match_name, 1, @charpos)
			--print @match_name
			If @match_name <> @hold_name
			   begin
				If @failed_login_count > 50
				   begin
				    Print @hold_name + ' Failed Logins: ' + convert(varchar(10), @failed_login_count)
				   end
				Print ''
				Select @hold_name = @match_name
				Select @failed_login_count = 0
			   end
		   end
	   end


	--  add blank space after first ":"
	Select @charpos = charindex(':', @cu11fulltext)
	IF @charpos <> 0
	   begin
		Select @cu11fulltext = stuff(@cu11fulltext, @charpos, 1, ' :')
	   end


	If @cu11fulltext like '%Login failed for user%'
	   begin
	    Select @failed_login_count = @failed_login_count + 1
	   end
	Else
	   begin
	    Print left(@cu11fulltext, 255)
	   end


 End  -- loop 11
DEALLOCATE cu11_current


delete from DBAOps.dbo.filescan_central where reported = 'x'


--  Report non-production issues


Print  ' '
Print  '************************************************************************************************************'
Print  '--  Non-Production Section'
Print  '************************************************************************************************************'


----------------  Cursor for filescan upload data  -------------------
EXECUTE('DECLARE cu12_current Insensitive Cursor For ' +
  'SELECT c.fulltext
   From DBAOps.dbo.filescan_central  c
   Where c.reported = ''y''
   Order by c.fulltext For Read Only')


OPEN cu12_current


WHILE (12=12)
 Begin
	FETCH Next From cu12_current Into @cu12fulltext
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_current
	      BREAK
           end


	--  Add a blank line to the report if this is a line from a different server
	Select @match_name = left(@cu12fulltext, 255)
	If left(@match_name, 2) = '\\'
	   begin
		Select @charpos = charindex('\', @match_name, 3)
		IF @charpos <> 0
		   begin
			Select @match_name = substring(@match_name, 1, @charpos)
			--print @match_name
			If @match_name <> @hold_name
			   begin
				If @failed_login_count > 50
				   begin
				    Print @hold_name + ' Failed Logins: ' + convert(varchar(10), @failed_login_count)
				   end
				Print ''
				Select @hold_name = @match_name
				Select @failed_login_count = 0
			   end
		   end
	   end


	--  add blank space after first ":"
	Select @charpos = charindex(':', @cu12fulltext)
	IF @charpos <> 0
	   begin
		Select @cu12fulltext = stuff(@cu12fulltext, @charpos, 1, ' :')
	   end


	If @cu12fulltext like '%Login failed for user%'
	   begin
	    Select @failed_login_count = @failed_login_count + 1
	   end
	Else
	   begin
	    Print left(@cu12fulltext, 255)
	   end


End  -- loop 12
DEALLOCATE cu12_current


delete from DBAOps.dbo.filescan_central where reported = 'y'


---------------------------  Finalization  -----------------------


Print  ' '
Print  '**********************************************************************'
Print  '** End of File Scan Report'
Print  '**********************************************************************'


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Filescan_Central_Report] TO [public]
GO
