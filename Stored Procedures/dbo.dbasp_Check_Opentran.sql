SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Check_Opentran]
/*********************************************************
 **  Stored Procedure dbasp_Check_Opentran
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  December 12, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Check for Open Transactions Older Than 10 Minutes
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge				Revision History added
--	06/10/2002	Steve Ledridge				Changed isql to osql
--	06/01/2006	Steve Ledridge				Updated for SQL 2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar (255)
	,@G_O				nvarchar (2)
	,@OTtimespan		int
	,@OTsavesuid		nvarchar (46)
	,@OTmindate_conv	datetime
	,@OTdatediff		int
	,@dbcccmd			nvarchar (255)
	,@sqlcmd			nvarchar (255)

DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu22OTtag			nvarchar (30)
	,@cu22OTvalue		nvarchar (46)


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'
Select @OTtimespan	= 10  --number in minutes


--------------------  Create Tempdb table  -----------------------
create table ##OpenTran
   (OTtag   varchar(30) not null
   ,OTvalue varchar(46) not null)


/*********************************************************************
 *                Initialization
 ********************************************************************/


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cursor_11DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.databases   d ' +
  'Where d.database_id > 0
  Order By d.name For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/
----------------------  Open the database cursor  ----------------------


OPEN cursor_11DBNames


WHILE (11=11)
   Begin
	FETCH Next From cursor_11DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11DBNames
	      BREAK
           end


	--------------------  clear out Temp table  -----------------------
	delete from ##OpenTran


	----------------------  Capture data into the temp table  ----------------------


	select @dbcccmd = 'dbcc opentran(''' + @cu11DBName + ''') with tableresults, NO_INFOMSGS'
	select @sqlcmd = 'sqlcmd -S' + @@servername + ' -Q''insert ##OpenTran (OTtag, OTvalue) exec (''' + @dbcccmd + ''')'' -E'


	EXEC master.sys.xp_cmdshell @sqlcmd, no_output


	select * from ##OpenTran


	----------------------  Declare the temp table cursor  ----------------------


	EXECUTE('DECLARE cursor_22OpenTran Insensitive Cursor For ' +
	  'SELECT t.OTtag, t.OTvalue
	   From ##OpenTran  t ' +
	  'Order by t.OTtag For Read Only')


	----------------------  Open the temp table cursor  ----------------------


	OPEN cursor_22OpenTran


	WHILE (22=22)
	   Begin
		FETCH next from cursor_22OpenTran into @cu22OTtag, @cu22OTvalue
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cursor_22OpenTran
			      BREAK
	           end


		----------------------  check for open trans and report if any are found  ----------------------


		IF @cu22OTtag = 'OLDACT_SPID'
		   begin
			Select @OTsavesuid = @cu22OTvalue
		   end
		Else
		IF @cu22OTtag = 'OLDACT_STARTTIME'
		   begin
			Select @OTmindate_conv = convert(datetime, @cu22OTvalue, 100)
			Select @OTdatediff = datediff(mi, @OTmindate_conv, getdate())


			If @OTdatediff > @OTtimespan
			   begin
				Select @miscprint = 'DBA WARNING: A transaction has been open for ' + convert(nvarchar(20),@OTdatediff) + ' minutes in database ''' + @cu11DBName + ''' for user SUID = ' + @OTsavesuid
				raiserror(@miscprint,-1,-1) with log
			   end
		   end


	End  -- loop 22
	Deallocate cursor_22OpenTran


End  -- loop 11
DEALLOCATE cursor_11DBNames


----------------------  End the data capture process  ----------------------


Drop table ##OpenTran
GO
GRANT EXECUTE ON  [dbo].[dbasp_Check_Opentran] TO [public]
GO
