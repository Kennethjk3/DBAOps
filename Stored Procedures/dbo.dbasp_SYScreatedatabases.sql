SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYScreatedatabases]


/*********************************************************
 **  Stored Procedure dbasp_SYScreatedatabases
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  create databases
 **
 **  Output member is SYScreatedatabases.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	04/30/2002	Steve Ledridge		Added brackets around dbname variable in select stmts.
--	05/06/2002	Steve Ledridge		Changed dbname type to sysname.
--	05/26/2006	Steve Ledridge		Updated for SQL 2005.
--	09/24/2008	Steve Ledridge		Added brackets for filegroup.
--	04/14/2009	Steve Ledridge		Skip db's not online.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@G_O			nvarchar(2)
	,@savegroupid		smallint
	,@savedefault		nvarchar(128)
	,@filegrowth		nvarchar(20)
	,@logfilegrowth		nvarchar(20)
	,@logname		nchar(128)
	,@logfilename		nchar(260)
	,@logsize		int
	,@logmaxsize		bigint
	,@AlterFlag		nchar(01)

DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu22fileid		smallint
	,@cu22groupid		smallint
	,@cu22size		int
	,@cu22maxsize		bigint
	,@cu22growth		int
	,@cu22status		int
	,@cu22perf		int
	,@cu22name		nchar(128)
	,@cu22filename		nchar(260)
	,@cu22FGname		nvarchar(128)
	,@cu22FGstatus		tinyint


----------------  initial values  -------------------


Select @G_O		= 'g' + 'o'


/*********************************************************************
 *                Initialization
 ********************************************************************/


Print  ' '


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cu11_DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.databases   d ' +
  'Order By d.name For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'Create Databases '
   Print  @miscprint
   Print  '***********************************************/'
   Print  ' '
   Select @miscprint = 'USE master'
   Print  @miscprint
   Print  @G_O
   Print  ' '


OPEN cu11_DBNames


WHILE (11=11)
 Begin
	FETCH Next From cu11_DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cu11_DBNames
	      BREAK
           end


	if DATABASEPROPERTYEX (@cu11DBName ,'status') <> 'ONLINE'
	   begin
		goto skip_dbname
	   end


----------------------  Print the headers  ----------------------


   Print  ' '
   Print  '/***********************************************'
   Select @miscprint = 'Create database ' + @cu11DBName
   Print  @miscprint
   Print  '***********************************************/'
   Print  ' '

   Select @savegroupid	= 0
   Select @logfilegrowth = ' '
   Select @logname = ' '
   Select @logfilename = ' '
   Select @logsize = null
   Select @logmaxsize = null
   Select @savedefault = ' '
   Select @AlterFlag = 'N'


   If @cu11DBName in ('master', 'model', 'msdb', 'tempdb')
	Print  '/*****'
	Print  ' '


   Select @miscprint = 'CREATE DATABASE ' + @cu11DBName
   Print  @miscprint
   Select @miscprint = 'ON'
   Print  @miscprint


--------------------  Cursor for 22DB  -----------------------


EXECUTE('DECLARE cu22_DBFile Insensitive Cursor For ' +
  'SELECT f.fileid, f.groupid, f.size, f.maxsize, f.growth, f.status, f.perf, f.name, f.filename, g.groupname, g.status
   From [' + @cu11DBName + '].sys.sysfiles  f LEFT OUTER JOIN
        [' + @cu11DBName + '].sys.sysfilegroups g
   on f.groupid = g.groupid
   Order By f.fileid For Read Only')


OPEN cu22_DBFile


WHILE (22=22)
   Begin
	FETCH Next From cu22_DBFile Into @cu22fileid, @cu22groupid, @cu22size, @cu22maxsize, @cu22growth, @cu22status, @cu22perf, @cu22name, @cu22filename, @cu22FGname, @cu22FGstatus
	IF (@@fetch_status < 0)
           begin
              CLOSE cu22_DBFile
	      BREAK
           end


	IF @cu22FGstatus = 16
	   begin
	     Select @savedefault = @cu22FGname
	   end


	IF @AlterFlag = 'N'
	   begin
		IF @cu22groupid > 0 and @cu22groupid <> @savegroupid
		   begin
			Select @savegroupid = @cu22groupid
			Select @filegrowth = (case @cu22status & 0x100000 when 0x100000 then
				convert(nvarchar(15), @cu22growth) + N'%'
				else
				convert(nvarchar(15), convert (bigint, @cu22growth) * 8) + N'KB' end)
			Select @miscprint = @cu22FGname
			Print  @miscprint
			Select @miscprint = '( NAME = ''' + rtrim(@cu22name) + ''''
			Print  @miscprint
			Select @miscprint = ' ,FILENAME = ''' + rtrim(@cu22filename) + ''''
			Print  @miscprint
			Select @miscprint = ' ,SIZE = ' + convert(nvarchar(15), convert(bigint, @cu22size) * 8) + N'KB'
			Print  @miscprint
			IF @cu22maxsize > 0
			   begin
				Select @miscprint = ' ,MAXSIZE = ' + convert(nvarchar(15), (convert (bigint, @cu22maxsize) * 8)/1024) + N'MB'
				Print  @miscprint
			   end
			Else IF @cu22maxsize = -1
			   begin
				Select @miscprint = ' ,MAXSIZE = N''Unlimited'''
				Print  @miscprint
			   end
			Select @miscprint = ' ,FILEGROWTH = ' +@filegrowth + ' )'
			Print  @miscprint
		   end
		Else IF @cu22groupid > 0 and @cu22groupid = @savegroupid
		   begin
			Select @filegrowth = (case @cu22status & 0x100000 when 0x100000 then
				convert(nvarchar(15), @cu22growth) + N'%'
				else
				convert(nvarchar(15), convert (bigint, @cu22growth) * 8) + N'KB' end)
			Select @miscprint = ',( NAME = ''' + rtrim(@cu22name) + ''''
			Print  @miscprint
			Select @miscprint = '  ,FILENAME = ''' + rtrim(@cu22filename) + ''''
			Print  @miscprint
			Select @miscprint = '  ,SIZE = ' + convert(nvarchar(15), convert(bigint, @cu22size) * 8) + N'KB'
			Print  @miscprint
			IF @cu22maxsize > 0
			   begin
				Select @miscprint = '  ,MAXSIZE = ' + convert(nvarchar(15), (convert (bigint, @cu22maxsize) * 8)/1024) + N'MB'
				Print  @miscprint
			   end
			Else IF @cu22maxsize = -1
			   begin
				Select @miscprint = ' ,MAXSIZE = N''Unlimited'''
				Print  @miscprint
			   end
			Select @miscprint = '  ,FILEGROWTH = ' +@filegrowth + ' )'
			Print  @miscprint
			IF @AlterFlag = 'Y'
			   begin
				Select @miscprint = 'GO'
				Print  @miscprint
				Select @miscprint = ' '
				Print  @miscprint
			   end
		   end
		else if	@cu22groupid = 0
		   begin
		   	Select @miscprint = 'LOG ON'
		   	Print  @miscprint
			Select @logfilegrowth = (case @cu22status & 0x100000 when 0x100000 then
				  convert(nvarchar(15), @cu22growth) + N'%'
				  else
				  convert(nvarchar(15), convert (bigint, @cu22growth) * 8) + N'KB' end)
			Select @logname = @cu22name
		   	Select @logfilename = @cu22filename
		   	Select @logsize = @cu22size
		   	Select @logmaxsize = @cu22maxsize
		   	Select @miscprint = '( NAME = ''' + rtrim(@logname) + ''''
		   	Print  @miscprint
		   	Select @miscprint = ' ,FILENAME = ''' + rtrim(@logfilename) + ''''
		   	Print  @miscprint
		   	Select @miscprint = ' ,SIZE = ' + convert(nvarchar(15), convert(bigint, @logsize) * 8) + N'KB'
		   	Print  @miscprint
			IF @logmaxsize > 0
		   	   begin
				Select @miscprint = ' ,MAXSIZE = ' + convert(nvarchar(15), (convert (bigint, @logmaxsize) * 8)/1024) + N'MB'
				Print  @miscprint
		   	   end
			Else IF @logmaxsize = -1
			   begin
				Select @miscprint = ' ,MAXSIZE = N''Unlimited'''
				Print  @miscprint
			   end
		   	Select @miscprint = ' ,FILEGROWTH = ' +@logfilegrowth + ' )'
		   	Print  @miscprint
		   	Print  @G_O
		   	Print  ' '
			Select @AlterFlag = 'Y'
		   end
	   end
	Else IF @AlterFlag = 'Y'
   	   begin
		IF @cu22groupid > 0 and @cu22FGname <> 'PRIMARY' and @cu22groupid <> @savegroupid
		   begin
			Select @savegroupid = @cu22groupid
			Select @miscprint = 'ALTER DATABASE ' + @cu11DBName
			Print  @miscprint
			Select @miscprint = 'ADD FILEGROUP [' + @cu22FGname + ']'
			Print  @miscprint
		   	Print  @G_O
		   	Print  ' '
		   end
		IF @cu22groupid > 0
		   begin
			Select @filegrowth = (case @cu22status & 0x100000 when 0x100000 then
				convert(nvarchar(15), @cu22growth) + N'%'
				else
				convert(nvarchar(15), convert (bigint, @cu22growth) * 8) + N'KB' end)
			Select @miscprint = 'ALTER DATABASE ' + @cu11DBName
			Print  @miscprint
			Select @miscprint = 'ADD FILE'
			Print  @miscprint
			Select @miscprint = '( NAME = ''' + rtrim(@cu22name) + ''''
			Print  @miscprint
			Select @miscprint = '  ,FILENAME = ''' + rtrim(@cu22filename) + ''''
			Print  @miscprint
			Select @miscprint = '  ,SIZE = ' + convert(nvarchar(15), convert(bigint, @cu22size) * 8) + N'KB'
			Print  @miscprint
			IF @cu22maxsize > 0
			   begin
				Select @miscprint = '  ,MAXSIZE = ' + convert(nvarchar(15), (convert (bigint, @cu22maxsize) * 8)/1024) + N'MB'
				Print  @miscprint
			   end
			Else IF @cu22maxsize = -1
			   begin
				Select @miscprint = ' ,MAXSIZE = N''Unlimited'''
				Print  @miscprint
			   end
			Select @miscprint = '  ,FILEGROWTH = ' + @filegrowth + ' )'
			Print  @miscprint
			Select @miscprint = 'TO FILEGROUP [' + @cu22FGname + ']'
			Print  @miscprint
			Select @miscprint = 'GO'
			Print  @miscprint
			Select @miscprint = ' '
			Print  @miscprint
		   end
		else if	@cu22groupid = 0
		   begin
			Select @logfilegrowth = (case @cu22status & 0x100000 when 0x100000 then
				  convert(nvarchar(15), @cu22growth) + N'%'
				  else
				  convert(nvarchar(15), convert (bigint, @cu22growth) * 8) + N'KB' end)
			Select @logname = @cu22name
		   	Select @logfilename = @cu22filename
		   	Select @logsize = @cu22size
		   	Select @logmaxsize = @cu22maxsize
			Select @miscprint = 'ALTER DATABASE ' + @cu11DBName
			Print  @miscprint
			Select @miscprint = 'ADD LOG FILE'
			Print  @miscprint
		   	Select @miscprint = '( NAME = ''' + rtrim(@logname) + ''''
		   	Print  @miscprint
		   	Select @miscprint = ' ,FILENAME = ''' + rtrim(@logfilename) + ''''
		   	Print  @miscprint
		   	Select @miscprint = ' ,SIZE = ' + convert(nvarchar(15), convert(bigint, @logsize) * 8) + N'KB'
		   	Print  @miscprint
		   	 IF @logmaxsize > 0
		   	   begin
		   	     Select @miscprint = ' ,MAXSIZE = ' + convert(nvarchar(15), (convert (bigint, @logmaxsize) * 8)/1024) + N'MB'
		   	     Print  @miscprint
		   	   end
			Else IF @logmaxsize = -1
			   begin
				Select @miscprint = ' ,MAXSIZE = N''Unlimited'''
				Print  @miscprint
			   end
		   	Select @miscprint = ' ,FILEGROWTH = ' +@logfilegrowth + ' )'
		   	Print  @miscprint
		   	Print  @G_O
		   	Print  ' '
		   end
	   end


   End  -- loop 22
   DEALLOCATE cu22_DBFile


   IF @savedefault <> 'PRIMARY'
      begin
	Select @miscprint = 'ALTER DATABASE ' + @cu11DBName
	Print  @miscprint
	Select @miscprint = 'MODIFY FILEGROUP [' + @savedefault + '] DEFAULT'
	Print  @miscprint
	Print  @G_O
	Print  ' '
      end


   If @cu11DBName in ('master', 'model', 'msdb', 'tempdb')
	Print  '*****/'
	Print  ' '


   skip_dbname:


 End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cu11_DBNames
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYScreatedatabases] TO [public]
GO
