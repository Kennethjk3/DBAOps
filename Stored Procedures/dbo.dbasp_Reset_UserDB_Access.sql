SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Reset_UserDB_Access] @db_name sysname = null


/***************************************************************
 **  Stored Procedure dbasp_Reset_UserDB_Access
 **  Written by Steve Ledridge, Virtuoso
 **  April 01, 2003
 **
 **  This sproc is set up to;
 **
 **  Reset user database access information after a restore.
 **  Information previously captured into a local DBAOps table
 **  is used for restore processing to dynamically maintain
 **  database security and access.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/01/2003	Steve Ledridge		New process.
--	04/15/2005	Steve Ledridge		Added some display statements.
--	04/04/2007	Steve Ledridge		New cleanup process for table UserDB_Access_Ctrl.
--	05/15/2007	Steve Ledridge		Converted for SQL 2005.
--	05/01/2008	Steve Ledridge		Changed sp_grantdbaccess to create user.
--	09/22/2008	Steve Ledridge		Added conditional to DB grant access.
--	09/26/2008	Steve Ledridge		varchar(255) to nvarchar(500).
--	======================================================================================


/**
declare @db_name sysname


Select @db_name = 'Virtuoso_Images_US_Inc__MSCRM'
--**/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@error_count			int
        ,@cmd				nvarchar(500)
        ,@sqlcmd			nvarchar(500)
	,@save_servername		sysname
	,@charpos			int


DECLARE
	 @cu11Loginname			sysname
	,@cu11Username			sysname
	,@cu11DfltDB			sysname


DECLARE
	 @cu12Loginname			sysname
	,@cu12Username			sysname
	,@cu12DBrole			sysname
	,@cu12DfltDB			sysname


----------------  initial values  -------------------
Select @error_count = 0


Select @save_servername		= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
   end


-- VALIDATE DATABASE NAME:
If not exists(select 1 from master.sys.databases where name = @db_name)
   begin
	Select @miscprint = 'DBA WARNING: Database name not found in master.sys.databases'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
end


-- Verify and clean UserDB_Access_Ctrl table
Delete from dbo.UserDB_Access_Ctrl
where loginname not in (select name from master.sys.syslogins)


-- START the Reset Database Access process


--  Get all captured database access records where role is 'public'
--------------------  Cursor for 11DB  -----------------------
EXECUTE('DECLARE cu11_Access Insensitive Cursor For ' +
  'SELECT u.Loginname, u.Username, u.DfltDB
   From DBAOps.dbo.UserDB_Access_Ctrl  u ' +
  'Where u.DBname = ''' + @db_name + '''
     and u.DBrole = ''public''
   Order By u.Loginname For Read Only')


OPEN cu11_Access


WHILE (11=11)
   Begin
	FETCH Next From cu11_Access Into @cu11Loginname, @cu11Username, @cu11DfltDB
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_Access
	      BREAK
           end


	--  Grant DB access for this login
	SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -d' + @db_name + ' -Q"If not exists (select 1 from sys.sysusers where name = ''' + @cu11Loginname + ''') CREATE USER [' + @cu11Loginname + '] FOR LOGIN [' + @cu11Username + ']" -E'
	Print @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd--, no_output


	Select @cmd = 'sp_defaultdb ''' + @cu11Loginname + ''', ''' + @cu11DfltDB + ''''
	Print @cmd
	exec (@cmd)


   End  -- loop 11
   DEALLOCATE cu11_Access


--  Now, get all captured database access records where role is not 'public'
--------------------  Cursor for 11DB  -----------------------
EXECUTE('DECLARE cu12_Access Insensitive Cursor For ' +
  'SELECT u.Loginname, u.Username, u.DBrole, u.DfltDB
   From DBAOps.dbo.UserDB_Access_Ctrl  u ' +
  'Where u.DBname = ''' + @db_name + '''
     and u.DBrole <> ''public''
   Order By u.Loginname For Read Only')


OPEN cu12_Access


WHILE (12=12)
   Begin
	FETCH Next From cu12_Access Into @cu12Loginname, @cu12Username, @cu12DBrole, @cu12DfltDB
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_Access
	      BREAK
           end


	--  Add role members as needed
	SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -d' + @db_name + ' -Q"sp_addrolemember ''' + @cu12DBrole + ''', ''' + @cu12Username + '''" -E'
	Print @sqlcmd
	EXEC master.sys.xp_cmdshell @sqlcmd--, no_output


   End  -- loop 12
   DEALLOCATE cu12_Access


--  Finalization  -------------------------------------------------------------------


label99:


If  @error_count > 0
   begin
	RETURN (1)
   end
Else
   begin
	RETURN (0)
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_Reset_UserDB_Access] TO [public]
GO
