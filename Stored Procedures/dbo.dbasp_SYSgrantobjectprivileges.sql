SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSgrantobjectprivileges] (@outpath varchar(100) = null
						,@suppress_use_stmt nchar(1) = 'n'
						)


/*********************************************************
 **  Stored Procedure dbasp_SYSgrantobjectprivileges
 **  Written by Steve Ledridge, Virtuoso
 **  May 2, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  grant object privileges
 **
 **  Input parm @outpath:  Is the path the database specific files
 **  should be written to (e.g. \\servername\dba_archive\)
 **
 **
 **  Output member is SYSgrantobjectprivileges.gsql
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
--	06/07/2002	Steve Ledridge		Modified output path to handel cluster instance.
--	06/11/2002	Steve Ledridge		Added brackets around DB name in use stmt.
--	06/28/2002	Steve Ledridge		Adjusted osql output.
--	08/02/2002	Steve Ledridge		Added 'no_output' parm to xp_cmdshell command.
--	09/24/2002	Steve Ledridge		Modified default output share
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	05/24/2006	Steve Ledridge		Updated for SQL 2005.
--	11/30/2006	Steve Ledridge		Added suppress of the use stmt (for sfp processing)
--	03/12/2008	Steve Ledridge		Many updates including now using sys.all_objects
--						and including master and msdb.
--	======================================================================================


/*
Declare @outpath varchar(100)
Declare @suppress_use_stmt nchar(1)


Select @outpath = null
Select @suppress_use_stmt = 'n'
--*/


DECLARE
	 @miscprint		nvarchar(255)
	,@grantoption		nvarchar (25)
	,@G_O			nvarchar  (2)
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_servername3	sysname
	,@charpos		int
	,@cmd			nvarchar(255)
	,@result		int
	,@outfilename		sysname
	,@outfullpath		nvarchar(250)
	,@sqlcmd		nvarchar(4000)
	,@selectcmd		nvarchar(4000)
	,@output_flag		char(1)
	,@output_flag2		char(1)


DECLARE
	 @cu11DBName		sysname


DECLARE
	 @cu22action		int
	,@cu22protecttype	int
	,@cu22puid		int
	,@cu22objtype		nvarchar(20)
	,@cu22Schemaname	sysname
	,@cu22OBJname		sysname
	,@cu22grantee		sysname
	,@cu22uid		smallint
	,@cu22id		int
	,@cu22is_ms_shipped	bit


Declare
	 @cu33ActionName	sysname
	,@cu33ProtectTypeName	sysname
	,@cu33OwnerName		sysname
	,@cu33ObjectName	sysname
	,@cu33GranteeName	sysname
	,@cu33ColumnName	sysname
	,@cu33All_Col_Bits_On	tinyint


----------------  initial values  -------------------
Select @G_O			= 'go'
Select @selectcmd		= 'set nocount on select * from ##output01'
Select @output_flag		= 'n'
Select @output_flag2		= 'n'
Select @save_servername		= @@servername
Select @save_servername2	= @@servername
Select @save_servername3	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


If @outpath is null
   begin
	Select @outpath = '\\' + @save_servername + '\dba_archive\'
   end


/*********************************************************************
 *                Initialization
 ********************************************************************/


-- Create temp table for DENY processing
If (object_id('tempdb..#t1_Prots') is not null)
            drop table #t1_Prots


CREATE Table #t1_Prots
	(Id			int				Null
	,Type1Code		char(6)			NOT Null
	,ObjType		char(2)			Null
	,ActionName		varchar(20)		Null
	,ActionCategory		char(2)			Null
	,ProtectTypeName	char(10)		Null
	,Columns_Orig		varbinary(32)	Null
	,OwnerName		sysname			Null
	,ObjectName		sysname			Null
	,GranteeName		sysname			Null
	,GrantorName		sysname			Null
	,ColumnName		sysname			Null
	,ColId			smallint		Null
	,Max_ColId		smallint		Null
	,All_Col_Bits_On	tinyint			Null
	,new_Bit_On		tinyint			Null
	)


----------------------  Main header  ----------------------
Print  ' '
Print  '/************************************************************************'
Select @miscprint = 'Generated SQL - SYSgrantobjectprivileges'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '************************************************************************/'


--------------------  Cursor for DB names  -------------------


EXECUTE('DECLARE cursor_11DBNames Insensitive Cursor For ' +
  'SELECT d.name
   From master.sys.databases   d ' +
  'Where d.name not in (''model'', ''tempdb'')
  Order By d.database_id For Read Only')


/****************************************************************
 *                MainLine
 ***************************************************************/


OPEN cursor_11DBNames


WHILE (11=11)
   Begin
	FETCH Next From cursor_11DBNames Into @cu11DBName
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_11DBNames
	      BREAK
           end

----------------------  Print the headers  ----------------------
Print  ' '
Print  '/*********************************************************'
Select @miscprint = 'GRANT OBJECT PRIVILEGES for database ' + @cu11DBName
Print  @miscprint
Print  '*********************************************************/'
Print  ' '


If @suppress_use_stmt = 'y'
   begin
	Select @miscprint = '--USE [' + @cu11DBName + ']'
	Print  @miscprint
	Print  @G_O
   end
Else
   begin
	Select @miscprint = 'USE [' + @cu11DBName + ']'
	Print  @miscprint
	Print  @G_O
   end


Select @miscprint = ' '
Print  @miscprint
Select @miscprint = 'Print ''Start GRANT OBJECT PRIVILEGES'''
Print  @miscprint
Select @miscprint = 'Select getdate()'
Print  @miscprint
Print  @G_O


--------------------  Set the output file name and path  -----------------------
Select @outfilename = @save_servername3 + '_SYSgrantpriv_' + @cu11DBName + '.gsql'
Select @outfullpath = @outpath + @outfilename


--------------------  Create the temp table for permissions  -----------------------
If (object_id('tempdb..##output01') is not null)
            drop table ##output01


CREATE TABLE ##output01 (
	[permission_commands] [nvarchar] (255) NULL
		)


----------------------  Write headers to the temp table  ----------------------
Insert into ##output01 (permission_commands)
values (' ')


Insert into ##output01 (permission_commands)
values ('/****************************************************')


Select @miscprint = 'GRANT OBJECT PRIVILEGES for database ' + @cu11DBName
Insert into ##output01 (permission_commands)
values (@miscprint)


Select @miscprint = 'From Server: ' + @@servername + '  Created on '  + convert(varchar(30),getdate(),9)
Insert into ##output01 (permission_commands)
values (@miscprint)


Insert into ##output01 (permission_commands)
values ('****************************************************/')


Insert into ##output01 (permission_commands)
values (' ')


If @suppress_use_stmt = 'y'
   begin
	Select @miscprint = '--USE [' + @cu11DBName + ']'
   end
Else
   begin
	Select @miscprint = 'USE [' + @cu11DBName + ']'
   end
Insert into ##output01 (permission_commands)
values (@miscprint)


Insert into ##output01 (permission_commands)
values ('GO')


Insert into ##output01 (permission_commands)
values (' ')


Select @miscprint = 'Print ''Start GRANT OBJECT PRIVILEGES'''
Insert into ##output01 (permission_commands)
values (@miscprint)


Select @miscprint = 'Select getdate()'
Insert into ##output01 (permission_commands)
values (@miscprint)

Insert into ##output01 (permission_commands)
values ('GO')


Insert into ##output01 (permission_commands)
values (' ')


--  Create the temp table for sysprotects
If (object_id('tempdb..##tempprotects') is not null)
            drop table ##tempprotects


Exec('select * into ##tempprotects from ['+ @cu11DBName + '].sys.sysprotects')


--------------------  Cursor for 22out  -----------------------
 EXECUTE('DECLARE cursor_22out Insensitive Cursor For ' +
        'SELECT distinct CONVERT(int,p.action), p.protecttype, p.uid, o.type, x.name, o.name, u.name, u.uid, p.id, o.is_ms_shipped
         From ##tempprotects  p
             , [' + @cu11DBName + '].sys.all_objects  o
             , [' + @cu11DBName + '].sys.sysusers  u
             , [' + @cu11DBName + '].sys.schemas  x
      Where  p.id = o.object_id
      And    u.uid = p.uid
      And    o.schema_id = x.schema_id
      And    p.action in (193, 195, 196, 197, 224, 26)
      And    p.uid not in (16382, 16383)
      Order By p.uid, o.name, p.protecttype, CONVERT(int,p.action)
   For Read Only')


OPEN cursor_22out


WHILE (22=22)
   Begin
	FETCH Next From cursor_22out Into @cu22action, @cu22protecttype, @cu22puid, @cu22objtype, @cu22Schemaname, @cu22OBJname, @cu22grantee, @cu22uid, @cu22id, @cu22is_ms_shipped
	IF (@@fetch_status < 0)
           begin
              CLOSE cursor_22out
	      BREAK
           end


	If @cu22is_ms_shipped = 1 and @cu22uid < 5
	   begin
		goto skip22
	   end


	If @cu22is_ms_shipped = 1 and @cu22grantee in ('TargetServersRole'
						    , 'SQLAgentUserRole'
						    , 'SQLAgentReaderRole'
						    , 'SQLAgentOperatorRole'
						    , 'DatabaseMailUserRole'
						    , 'db_dtsadmin'
						    , 'db_dtsltduser'
						    , 'db_dtsoperator')
	   begin
		goto skip22
	   end


	If @cu22protecttype = 204
	   begin
		select @grantoption = 'WITH GRANT OPTION'
	   end
	Else
	   begin
		select @grantoption = ''
	   end


	IF @cu22action = 224 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT EXECUTE ON OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')


	   end
	ELSE
	IF @cu22action = 26 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT REFERENCES ON [' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')
	   end
	ELSE
	IF @cu22action = 193 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT SELECT ON OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')
	   end
	ELSE
	IF @cu22action = 195 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT INSERT ON OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')
	   end
	ELSE
	IF @cu22action = 196 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT DELETE ON OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')
	   end
	ELSE
	IF @cu22action = 197 and @cu22protecttype in (204, 205)
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = 'GRANT UPDATE ON OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] to [' + @cu22grantee + '] ' + @grantoption
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
		Print  @G_O
		Insert into ##output01 (permission_commands)
		values ('GO')
	   end
	ELSE
	IF @cu22protecttype = 206
	   begin
		delete from #t1_Prots


		--  Insert data into the temp table
		INSERT	#t1_Prots
		        (Id
			,Type1Code
			,ObjType
			,ActionName
			,ActionCategory
			,ProtectTypeName
			,Columns_Orig
			,OwnerName
			,ObjectName
			,GranteeName
			,GrantorName
			,ColumnName
			,ColId
			,Max_ColId
			,All_Col_Bits_On
			,new_Bit_On
			)
			/*	1Regul indicates action can be at column level,
				2Simpl indicates action is at the object level */
			SELECT	sysp.id
				,case
					when sysp.columns is null then '2Simpl'
					else '1Regul'
					end
				,Null
				,val1.name
				,'Ob'
				,val2.name
				,sysp.columns
				,null
				,null
				,null
				,null
				,case
					when sysp.columns is null then '.'
					else Null
					end
				,-123
				,Null
				,Null
				,Null
			FROM	##tempprotects sysp
				,master.dbo.spt_values  val1
				,master.dbo.spt_values  val2
			where	sysp.id  = @cu22id
			and	val1.type     = 'T'
			and	val1.number   = sysp.action
			and	val2.type     = 'T' --T is overloaded.
			and	val2.number   = sysp.protecttype
			and	sysp.protecttype = 206
			and 	sysp.id != 0
			and	sysp.uid = @cu22uid


		IF EXISTS (SELECT * From #t1_Prots)
		   begin
			--  set owner name
			select @cmd = 'UPDATE #t1_Prots set OwnerName = ''' + @cu22Schemaname + ''' WHERE id = ' + convert(varchar(20), @cu22id)
			exec(@cmd)


			--  set object name
			select @cmd = 'UPDATE #t1_Prots set ObjectName = ''' + @cu22OBJname + ''' WHERE id = ' + convert(varchar(20), @cu22id)
			exec(@cmd)


			--  set grantee name
			select @cmd = 'UPDATE #t1_Prots set GranteeName = ''' + @cu22grantee + ''' WHERE id = ' + convert(varchar(20), @cu22id)
			exec(@cmd)


			--  set object type
			Exec('UPDATE #t1_Prots
			set ObjType = ob.type
			FROM ['+ @cu11DBName + '].sys.objects ob
			WHERE ob.object_id = #t1_Prots.Id')

			--  set Max_ColId
			Exec('UPDATE #t1_Prots
			set Max_ColId = (select max(column_id) From ['+ @cu11DBName + '].sys.columns sysc where #t1_Prots.Id = sysc.object_id)	-- colid may not consecutive if column dropped
			where Type1Code = ''1Regul''')


			-- First bit set indicates actions pretains to new columns. (i.e. table-level permission)
			-- Set new_Bit_On accordinglly
			UPDATE	#t1_Prots
			SET new_Bit_On = CASE convert(int,substring(Columns_Orig,1,1)) & 1
						WHEN	1 then	1
						ELSE	0
						END
			WHERE	ObjType	<> 'V'	and	 Type1Code = '1Regul'

			-- Views don't get new columns
			UPDATE #t1_Prots
			set new_Bit_On = 0
			WHERE  ObjType = 'V'


			-- Indicate enties where column level action pretains to all columns in table All_Col_Bits_On = 1					*/
			Exec('UPDATE #t1_Prots
			set All_Col_Bits_On = 1
			where #t1_Prots.Type1Code = ''1Regul''
			  and not exists (select * from ['+ @cu11DBName + '].sys.columns sysc, master.dbo.spt_values v
						where #t1_Prots.Id = sysc.object_id and sysc.column_id = v.number
						and v.number <= Max_ColId		-- column may be dropped/added after Max_ColId snap-shot
						and v.type = ''P'' and
						-- Columns_Orig where first byte is 1 means off means on and on means off
						-- where first byte is 0 means off means off and on means on
							case convert(int,substring(#t1_Prots.Columns_Orig, 1, 1)) & 1
								when 0 then convert(tinyint, substring(#t1_Prots.Columns_Orig, v.low, 1))
								else (~convert(tinyint, isnull(substring(#t1_Prots.Columns_Orig, v.low, 1),0)))
							end & v.high = 0)')


			-- Indicate entries where column level action pretains to only some of columns in table All_Col_Bits_On = 0
			UPDATE	#t1_Prots
			set All_Col_Bits_On = 0
			WHERE #t1_Prots.Type1Code = '1Regul'
			  and All_Col_Bits_On is null


			Update #t1_Prots
			set ColumnName = case
						when All_Col_Bits_On = 1 and new_Bit_On = 1 then '(All+New)'
						when All_Col_Bits_On = 1 and new_Bit_On = 0 then '(All)'
						when All_Col_Bits_On = 0 and new_Bit_On = 1 then '(New)'
						end
			from #t1_Prots
			where ObjType IN ('S ' ,'U ', 'V ')
			  and Type1Code = '1Regul'
			  and NOT (All_Col_Bits_On = 0 and new_Bit_On = 0)

			-- Expand and Insert individual column permission rows
			Exec('INSERT	into   #t1_Prots
				(Id
				,Type1Code
				,ObjType
				,ActionName
				,ActionCategory
				,ProtectTypeName
				,OwnerName
				,ObjectName
				,GranteeName
				,GrantorName
				,ColumnName
				,ColId	)
			   SELECT	prot1.Id
					,''1Regul''
					,ObjType
					,ActionName
					,ActionCategory
					,ProtectTypeName
					,OwnerName
					,ObjectName
					,GranteeName
					,GrantorName
					,null
					,val1.number
				from	#t1_Prots              prot1
					,master.dbo.spt_values  val1
					,['+ @cu11DBName + '].sys.columns sysc
				where	prot1.ObjType    IN (''S '' ,''U '' ,''V '')
				and prot1.Id = sysc.object_id
				and	val1.type   = ''P''
				and	val1.number = sysc.column_id
				and	case convert(int,substring(prot1.Columns_Orig, 1, 1)) & 1
						when 0 then convert(tinyint, substring(prot1.Columns_Orig, val1.low, 1))
						else (~convert(tinyint, isnull(substring(prot1.Columns_Orig, val1.low, 1),0)))
						end & val1.high <> 0
				and prot1.All_Col_Bits_On <> 1')

			--  set column names
			Exec('UPDATE #t1_Prots
			set ColumnName = c.name
			FROM ['+ @cu11DBName + '].sys.columns c
			WHERE c.object_id = #t1_Prots.Id
			and   c.column_id = #t1_Prots.ColId')


			delete from #t1_Prots
			where ObjType IN ('S ' ,'U ' ,'V ')
			  and All_Col_Bits_On = 0
			  and new_Bit_On = 0

		   end

		--------------------  Cursor for DB names  -------------------
		EXECUTE('DECLARE cursor_33 Insensitive Cursor For ' +
		  'SELECT t.ActionName, t.ProtectTypeName, t.OwnerName, t.ObjectName, t.GranteeName, t.ColumnName, t.All_Col_Bits_On
		   From #t1_Prots   t ' +
		  'Order By t.GranteeName For Read Only')


		OPEN cursor_33

		WHILE (33=33)
		   Begin
			FETCH Next From cursor_33 Into @cu33ActionName, @cu33ProtectTypeName, @cu33OwnerName, @cu33ObjectName, @cu33GranteeName, @cu33ColumnName, @cu33All_Col_Bits_On
			IF (@@fetch_status < 0)
		           begin
		              CLOSE cursor_33
			      BREAK
		           end


			If @cu33All_Col_Bits_On is not null or @cu33ColumnName = '.'
			   begin
				Print  ' '
				Insert into ##output01 (permission_commands)
				values (' ')
				Select @miscprint = rtrim(upper(@cu33ProtectTypeName)) + ' ' + rtrim(upper(@cu33ActionName)) + ' ON OBJECT::[' + rtrim(@cu33OwnerName) + '].[' + @cu33ObjectName + '] To [' + @cu33GranteeName + '] CASCADE'
				Print  @miscprint
				Insert into ##output01 (permission_commands)
				values (@miscprint)
				Print  'Go'
				Insert into ##output01 (permission_commands)
				values ('GO')
			   end
			Else
			   begin
				Print  ' '
				Insert into ##output01 (permission_commands)
				values (' ')
				Select @miscprint = rtrim(upper(@cu33ProtectTypeName)) + ' ' + rtrim(upper(@cu33ActionName)) + ' ON OBJECT::[' + rtrim(@cu33OwnerName) + '].[' + @cu33ObjectName + '] ([' + @cu33ColumnName + ']) To [' + @cu33GranteeName + '] CASCADE'
				Print  @miscprint
				Insert into ##output01 (permission_commands)
				values (@miscprint)
				Print  'Go'
				Insert into ##output01 (permission_commands)
				values ('GO')
			   end

		   End  -- loop 33
		DEALLOCATE cursor_33
	   end
	ELSE
	   begin
		Print  ' '
		Insert into ##output01 (permission_commands)
		values (' ')
		Select @miscprint = '-- Error on OBJECT::[' + @cu22Schemaname + '].[' + @cu22OBJname + '] for user [' + @cu22grantee + ']'
		Print  @miscprint
		Insert into ##output01 (permission_commands)
		values (@miscprint)
	   end


	Select @output_flag	= 'y'


   skip22:

   End  -- loop 22

   DEALLOCATE cursor_22out


----------------------  Write a seperate permissions file for this database  ----------------------


If @output_flag = 'n'
   begin
	Print  ' '
	Select @miscprint = '-- No output for database: ' + @cu11DBName
	Print  @miscprint
	Print  ' '
	Insert into ##output01 (permission_commands)
	values (@miscprint)
   end
Else
   begin
	Select @miscprint = ' '
	Print  @miscprint
	Insert into ##output01 (permission_commands)
	values (@miscprint)


	Select @miscprint = 'Print ''End GRANT OBJECT PRIVILEGES'''
	Print  @miscprint
	Insert into ##output01 (permission_commands)
	values (@miscprint)


	Select @miscprint = 'Select getdate()'
	Print  @miscprint
	Insert into ##output01 (permission_commands)
	values (@miscprint)

	Print  @G_O
	Insert into ##output01 (permission_commands)
	values ('GO')


	Select @output_flag = 'n'
   end


SELECT 	@sqlcmd = 'sqlcmd -S' + @@servername + ' -w265 -h-1 -Q"' + @selectcmd + '" -E -o' + @outfullpath
--print @sqlcmd
EXEC @result = master.sys.xp_cmdshell @sqlcmd, no_output


DROP TABLE ##output01


drop table ##tempprotects


Select @output_flag2 = 'y'


End  -- loop 11


---------------------------  Finalization  -----------------------


DEALLOCATE cursor_11DBNames


drop Table #t1_Prots


If @output_flag2 = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSgrantobjectprivileges] TO [public]
GO
