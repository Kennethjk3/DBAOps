SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSaddsysmessages]


/*********************************************************
 **  Stored Procedure dbasp_SYSaddsysmessages
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add system messages
 **
 **  Output member is SYSaddsysmessages.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/26/2006	Steve Ledridge		Change double quotes to single quotes for message.
--	11/09/2006	Steve Ledridge		Modified for SQL 2005
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@output_flag		char(1)
	,@startpos		int
	,@charpos		int
	,@save_log		nvarchar(10)


DECLARE
	 @cu11Mmessage_id	nvarchar(10)
	,@cu11Mlanguage_id	nvarchar(50)
	,@cu11Mseverity		nvarchar(10)
	,@cu11Mis_event_logged	bit
	,@cu11Mtext		nvarchar(2048)


----------------  initial values  -------------------
Select @G_O	= 'g' + 'o'
Select @output_flag	= 'n'

/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/*******************************************************************'
Select @miscprint = 'Generated SQL - SYSaddsysmessages'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'ADD MESSAGES for master '
   Print  @miscprint
   Print  '***********************************************/'
   Print  ' '
   Select @miscprint = 'USE master'
   Print  @miscprint
   Print  @G_O
   Print  ' '


--------------------  Cursor 11  -----------------------


EXECUTE('DECLARE cursor_11 Insensitive Cursor For ' +
  'SELECT convert(varchar(10),m.message_id), convert(sysname,l.name), convert(varchar(10),m.severity), m.is_event_logged, convert(varchar(255),m.text)
   From master.sys.messages  m , master.sys.syslanguages  l ' +
  'Where m.message_id > 49999
     and m.language_id = l.lcid
   Order By m.message_id For Read Only')


OPEN cursor_11


WHILE (11=11)
   Begin
	FETCH Next From cursor_11 Into @cu11Mmessage_id, @cu11Mlanguage_id, @cu11Mseverity, @cu11Mis_event_logged, @cu11Mtext
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11
	      BREAK
           end


	--  Fix single quote problem in @cu11name
	Select @startpos = 1
	label01:
	select @charpos = charindex('''', @cu11Mtext, @startpos)
	IF @charpos <> 0
	   begin
		select @cu11Mtext = stuff(@cu11Mtext, @charpos, 1, '''''')
		select @startpos = @charpos + 2
	   end


	select @charpos = charindex('''', @cu11Mtext, @startpos)
	IF @charpos <> 0
	   begin
		goto label01
	   end


	IF @cu11Mis_event_logged = 1
	   begin
		select @save_log = 'True'
	   end
	Else
	   begin
		select @save_log = 'False'
	   end


	Print  ' '
	Select @miscprint = 'exec sp_addmessage @msgnum = ' +@cu11Mmessage_id
	Print  @miscprint
	Select @miscprint = '                  ,@severity = ' +@cu11Mseverity
	Print  @miscprint
	Select @miscprint = '                  ,@lang = ''' +@cu11Mlanguage_id+ ''''
	Print  @miscprint
	Select @miscprint = '                  ,@msgtext = N''' +@cu11Mtext+ ''''
	Print  @miscprint
	Select @miscprint = '                  ,@with_log = ''' +@save_log+ ''''
	Print  @miscprint
	Select @miscprint = '                  ,@replace = ''replace'''
	Print  @miscprint
	Print  @G_O


	Select @output_flag	= 'y'

   End  -- loop 11


---------------------------  Finalization  -----------------------
   DEALLOCATE cursor_11


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddsysmessages] TO [public]
GO
