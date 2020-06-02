SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Filescan_Report]
    @outshare varchar (255) = null     /** file output share name override **/
/***************************************************************
 **  Stored Procedure dbasp_Filescan_Report
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
--	======================================================================================


/*
Declare @outshare varchar (255)
Select @outshare = null
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
	 @cu11fulltext		nvarchar(MAX)
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


If @outshare is null
   begin
	Select @outshare = @save_servername + '_filescan'
   end


---------------- Before creating the report, we process to get rid of non-reportable items--------


if(select count(*) from DBAOps.dbo.No_Check where NoCheck_Type = 'Filescan_noreport') > 0
begin


    declare tempcheck_cur cursor for
    select
       detail01,
       detail02,
       detail03,
       detail04
    from DBAOps.dbo.No_Check
    where NoCheck_Type = 'Filescan_noreport'


    open tempcheck_cur


    fetch next from tempcheck_cur into @dt01,@dt02,@dt03,@dt04


    while @@fetch_status = 0
    begin


	set @cnt = convert(int,@dt04)


        if (select COUNT(*) from DBAOps.dbo.filescan_current where FullText like @dt01 and FullText like @dt02 and FullText like @dt03)< @cnt
	    begin
		delete
		from dbo.filescan_current
		where fulltext like @dt01
		      and FullText like @dt02
		      and FullText like @dt03
	    end


	 fetch next from tempcheck_cur into @dt01,@dt02,@dt03,@dt04
    end
    close tempcheck_cur
    deallocate tempcheck_cur


end


----------------  Create temp table for upload  -------------------
create table ##filescanHeader (fulltext nvarchar (MAX) NULL)


----------------  Upload file to process  -------------------
Select @SQLString = 'bulk insert ##filescanHeader from  ''\\' + @save_servername + '\' + @outshare + '\uploadheader.txt'''
--Print @SQLString
EXEC @Result = master.sys.sp_executesql @SQLString
--select * from ##filescanHeader


IF @Result <> 0
   begin
	select @miscprint = 'DBA WARNING: Filescan header file upload error on server ' + @@servername
	raiserror(@miscprint,-1,-1) with log
	Select @error_flag = 1
	goto label99
   end


Select @hold_header = (select fulltext from ##filescanHeader)


----------------  Print headers for filescan report  -------------------
Print  ' '
Print  '**********************************************************************'
Print  @hold_header
Print  '**********************************************************************'
Select @miscprint = '** Date: ' + convert(char(30), getdate(), 109)
Print  @miscprint
Print  '**********************************************************************'
Print  ' '


----------------  Cursor for filescan upload data  -------------------
EXECUTE('DECLARE cu11_current Insensitive Cursor For ' +
  'SELECT c.fulltext
   From DBAOps.dbo.filescan_current  c
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


---------------------------  Finalization  -----------------------


Print  ' '
Print  '**********************************************************************'
Print  '** End of File Scan Report'
Print  '**********************************************************************'


label99:


drop table ##filescanHeader


If @error_flag <> 0
   begin
       return(1)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Filescan_Report] TO [public]
GO
