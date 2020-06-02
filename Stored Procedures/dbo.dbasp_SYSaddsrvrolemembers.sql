SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSaddsrvrolemembers]


/*********************************************************
 **  Stored Procedure dbasp_SYSaddsrvrolemembers
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  add server role members
 **
 **  Output member is SYSaddsrvrolemembers.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	03/10/2008	Steve Ledridge		Updated for SQL2005.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@output_flag		char(1)

DECLARE
	 @cu11SPVname		nvarchar(128)
	,@cu11LGNname		nvarchar(128)
	,@cu11LGNsid		varbinary(85)


----------------  initial values  -------------------
Select @G_O		= 'g' + 'o'
Select @output_flag	= 'n'


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------


Print  ' '
Print  '/*******************************************************************'
Select @miscprint = 'Generated SQL - SYSaddsrvrolemembers'
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
   Print  '/*********************************************************'
   Select @miscprint = 'Add Server Role Members for server: ' + @@servername
   Print  @miscprint
   Print  '*********************************************************/'
   Print  ' '
   Select @miscprint = 'USE master'
   Print  @miscprint
   Print  @G_O
   Print  ' '

--------------------  Cursor 11  -----------------------


EXECUTE('DECLARE cursor_11 Insensitive Cursor For ' +
  'SELECT SUSER_NAME(rm.role_principal_id), lgn.name, lgn.sid
   From master.sys.server_role_members rm, master.sys.server_principals lgn ' +
  'Where rm.role_principal_id >=3
	and rm.role_principal_id <=10
	and rm.member_principal_id = lgn.principal_id
	and lgn.name not like ''%Administrators%''
	and lgn.name not like ''%NT AUTHORITY%''
	and lgn.name <> ''sa''
   Order By lgn.name For Read Only')


--------------------  start cursor processing  -----------------------


OPEN cursor_11


WHILE (11=11)
   Begin
	FETCH Next From cursor_11 Into @cu11SPVname, @cu11LGNname, @cu11LGNsid
           IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11
	      BREAK
           end


--------------------  Format the output  -----------------------


	Select @miscprint = 'exec sp_addsrvrolemember ''' + @cu11LGNname + ''', ''' + @cu11SPVname + ''';'
        Print  @miscprint
	Print  @G_O
	Print  ' '


	Select @output_flag	= 'y'


   End  -- loop 11


---------------------------  Finalization  -----------------------
   DEALLOCATE cursor_11


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSaddsrvrolemembers] TO [public]
GO
