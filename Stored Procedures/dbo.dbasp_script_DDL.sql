SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_script_DDL] (@DBname sysname = 'all'
					,@objtype nvarchar(10) = 'all'
					,@suppress_use_stmt char(1) = 'n'
					,@suppress_drop_stmt char(1) = 'n'
					,@drop_only char(1) = 'n')


/*********************************************************
 **  Stored Procedure dbasp_script_DDL
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  October 15, 2007
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Script all objects for a specific DB or all databases.
 **
 **  Input parms:
 **  @DBname = The database name or 'ALL' for all user databases.
 **  @objtype = The object type you want to script, or 'ALL'.
 **  @suppress_use_stmt - For no 'USE' statement in the output script.
 **  @suppress_drop_stmt - For no drop statement in the output script
 **  @drop_only - For a drop only output script
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/27/2002	Steve Ledridge		New process
--	10/02/2008	Steve Ledridge		Added code for indexed views and drop only input parm.
--	10/23/2008	Steve Ledridge		Loop for multiple FK column references.
--	05/13/2009	Steve Ledridge		Changed @DefinedLength from 4000 back to 500.
--	05/21/2010	Steve Ledridge		Fix for function scripting.
--	06/02/2010	Steve Ledridge		Update to temp table for function types.
--	03/22/2012	Steve Ledridge		Added second line for output IF stmt.
--	======================================================================================


/*
'u' = USER_TABLE
'f' = FOREIGN_KEY_CONSTRAINT
'p' = SQL_STORED_PROCEDURE
'fn' = SQL_SCALAR_FUNCTION
'tf' = SQL_TABLE_VALUED_FUNCTION
'IF' = SQL inline table-valued function
'v' = VIEW (all views)
'vi' = VIEW with index


'it' = INTERNAL_TABLE
'sq' = SERVICE_QUEUE
's' = system table (not created with this script)
'pk' = PRIMARY_KEY_CONSTRAINT (not created seperatly with this script)
'uq' = UNIQUE_CONSTRAINT (not created seperatly with this script)
'd' = DEFAULT_CONSTRAINT (not created seperatly with this script)
*/


-----------------  declares  ------------------


/**
Declare @DBname sysname
Declare @objtype nvarchar(10)
Declare @suppress_use_stmt char(1)
Declare @suppress_drop_stmt char(1)
Declare @drop_only char(1)


Select @DBname = 'DBAOps'
Select @objtype = 'tf'
Select @suppress_use_stmt = 'n'
Select @suppress_drop_stmt = 'n'
Select @drop_only = 'n'
--**/


DECLARE
	 @miscprint			    nvarchar(500)
	,@query				    nvarchar(4000)
	,@caller_id			    nvarchar(10)
	,@save_dbname			    sysname
	,@save_colname			    sysname
	,@save_type_name		    sysname
	,@save_max_length		    smallint
	,@save_max_length_char		    nvarchar(20)
	,@save_collation_name		    sysname
	,@save_is_nullable		    nvarchar(10)
	,@save_indxname			    sysname
	,@save_type_desc		    nvarchar(60)
	,@save_index_id			    int
	,@save_data_space_name		    sysname
	,@save_PAD_INDEX		    nvarchar(10)
	,@save_STATISTICS_NORECOMPUTE	    nvarchar(10)
	,@save_IGNORE_DUP_KEY		    nvarchar(10)
	,@save_ALLOW_ROW_LOCKS		    nvarchar(10)
	,@save_ALLOW_PAGE_LOCKS		    nvarchar(10)
	,@save_filegroup		    sysname
	,@save_column_id		    int
	,@save_cnstname			    sysname
	,@save_definition		    nvarchar(max)
	,@save_indexkey_property	    char(1)
	,@save_minor_id			    int
	,@save_exprop_name		    sysname
	,@save_exprop_value		    sysname
	,@save_exprop_colname		    sysname
	,@save_seed_value		    sql_variant
	,@save_increment_value		    sql_variant
	,@save_is_system_named		    bit
	,@save_PKobject_id		    int
	,@save_precision		    tinyint
	,@save_scale			    tinyint
	,@save_type_tname		    sysname
	,@save_type_sname		    sysname
	,@save_system_type_id		    tinyint
	,@save_system_type_name		    sysname
	,@save_fgname			    sysname
	,@save_fgsize			    int
	,@save_dfname			    sysname
	,@save_dfsize			    int
	,@save_dfmax_size		    int
	,@save_dfgrowth			    int
	,@save_dfphysical_name		    nvarchar(260)
	,@save_fk_sname			    sysname
	,@save_fk_parent_object_id	    int
	,@save_fk_parent_object_name	    sysname
	,@save_fk_parent_object_sname	    sysname
	,@save_fk_parent_column_id	    int
	,@save_fk_parent_column_name	    sysname
	,@save_fk_referenced_object_id	    int
	,@save_fk_referenced_object_name    sysname
	,@save_fk_referenced_object_sname   sysname
	,@save_fk_referenced_column_id	    int
	,@save_fk_referenced_column_name    sysname
	,@save_fk_parent_names		    sysname
	,@save_fk_referenced_names	    sysname
	,@DefinedLength			    int
	,@BlankSpaceAdded		    int
	,@output_flag			    char(1)
	,@TEXTIMAGE_flag		    char(1)
	,@user_type_flag		    char(1)
	,@save_type			    char(2)
	,@G_O				    nvarchar(2)
	,@LFCR				    int --lengths of line feed carriage return
	,@cmd				    nvarchar(2000)
	,@LineId			    int
	,@SyscomText			    nvarchar(4000)
	,@save_number			    smallint
	,@save_colid			    smallint
	,@save_lineid			    int
	,@save_objid			    int
	,@charpos			    int
	,@pos				    int
	,@error_count			    int


declare
	 @BasePos		int
	,@CurrentPos		int
	,@TextLength		int
	,@AddOnLen		int
	,@Line			nvarchar(4000)
	,@commentText		nvarchar(4000)


declare
	 @objid			int
	,@objname		sysname
	,@indid			smallint
	,@groupid		int
	,@indname		sysname
	,@groupname		sysname
	,@status		int
	,@keys			nvarchar(2126)
	,@ignore_dup_key	bit
	,@is_unique		bit
	,@is_hypothetical	bit
	,@is_primary_key	bit
	,@is_unique_key 	bit
	,@auto_created		bit
	,@no_recompute		bit
	,@i			int
	,@thiskey		nvarchar(131) -- 128+3


declare
	 @cu11_name		sysname
	,@cu11_id		int
	,@cu11_type		char(2)
	,@cu11_schema_name	sysname


----------------  initial values  -------------------


/* NOTE: Length of @SyscomText is 4000 to replace the length of
** text column in syscomments.
** Lengths on @Line, #CommentText Text column and
** value for @DefinedLength are all 500. These need to all have
** the same values.
*/

Select @error_count	= 0
Select @G_O             = 'g' + 'o'
Select @DefinedLength   = 500
Select @BlankSpaceAdded = 0 /*Keeps track of blank spaces at end of lines. Note Len function ignores
							 trailing blank spaces*/
Select @output_flag	= 'n'


--  Create tables and table variables
declare @objinfo table	(oname		sysname
			,object_id	int
			,schema_name	sysname
			,type		char(2)
			,create_date	datetime
			)


CREATE TABLE #CommentText (LineId	int
			,Text	nvarchar(500)
			)


declare @tbl_Syscom table (SyscomText	nvarchar(4000)
			,number		smallint
			,colid		smallint
			)


declare @temp_com table (id		int
			,number		smallint
			,colid		smallint
			,status		smallint
			,encrypted	bit
			,text		nvarchar(4000)
			   )


declare @tbl_columns table (name		sysname
			,column_id		int
			,type_name		sysname
			,max_length		smallint
			,precision		tinyint
			,scale			tinyint
			,collation_name		sysname null
			,is_nullable		bit
			,is_ansi_padded		bit
			,is_rowguidcol		bit
			,is_identity		bit
			,is_computed		bit
			,is_filestream		bit
			,is_replicated		bit
			,is_non_sql_subscribed	bit
			,is_merge_published	bit
			,is_dts_replicated	bit
			,is_xml_document	bit
			,xml_collection_id	int
			,default_object_id	int
			,rule_object_id		int
			)


declare @tbl_indexes table (name		sysname
			,index_id		int
			,type			tinyint
			,type_desc		nvarchar(60)
			,is_unique		bit
			,data_space_id		int
			,data_space_name	sysname
			,ignore_dup_key		bit
			,is_primary_key		bit
			,is_unique_constraint	bit
			,fill_factor		tinyint
			,is_padded		bit
			,is_disabled		bit
			,is_hypothetical	bit
			,allow_row_locks	bit
			,allow_page_locks	bit
			,auto_created		bit
			,no_recompute		bit
			)


declare @tbl_cnst table (name			sysname
			,object_id		int
			,type			char(2)
			,parent_column_id	int
			,definition		nvarchar(max)
			)


declare @tbl_exprop table (class		tinyint
			,major_id		int
			,minor_id		int
			,colname		sysname
			,name			sysname
			,value			sql_variant
			)


declare @tbl_types table (tname			sysname
			, system_type_id	tinyint
			, sname			sysname
			, principal_id		int null
			, max_length		smallint
			, precision		tinyint
			, scale			tinyint
			, collation_name	sysname null
			, is_nullable		bit
			, is_user_defined	bit
			, is_assembly_type	bit
			, default_object_id	int
			, rule_object_id	int
			)


declare @tbl_filegroups table (fgname		sysname
			,dfname			sysname
			,size			int
			,max_size		int
			,growth			int
			,physical_name		nvarchar(260)
			,is_media_read_only	bit
			,is_read_only		bit
			,is_sparse		bit
			,is_percent_growth	bit
			,is_name_reserved	bit
			)


declare @tbl_forkeys table (fname		sysname
			,sname			sysname
			,parent_object_id	int
			,parent_column_id	int
			,referenced_object_id	int
			,referenced_column_id	int
			,is_disabled		bit
			,is_not_trusted		bit
			,is_system_named	bit
			)


--  Verify input parms
if not exists (select * from master.sys.sysdatabases where name = @dbname)
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @dbname'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


if (select name from master.sys.sysdatabases where name = @dbname) in ('master', 'model', 'msdb', 'tempdb')
   BEGIN
	Select @miscprint = 'DBA WARNING: This process is not allowed for a system database'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


if @objtype not in ('all', 'u', 'f', 'p', 'fn', 'v', 'vi', 'tr', 'tf', 'IF')
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parm for @objtype.  Must be ''all'', ''u'', ''f'', ''p'', ''fn'', ''v'', ''vi'', ''tr'', ''tf'' or ''IF''.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


If @suppress_drop_stmt = 'y' and @drop_only = 'y'
   BEGIN
	Select @miscprint = 'DBA WARNING: Invalid input parms for @suppress_drop_stmt and @drop_only.  Both parms cannot be ''y''.'
	raiserror(@miscprint,-1,-1) with log
	Select @error_count = @error_count + 1
	goto label99
   END


/*********************************************************************
 *                Initialization
 ********************************************************************/


Select @save_dbname = rtrim(@DBname)


Select @cmd = 'SELECT c.id, c.number, c.colid, c.status, c.encrypted, c.text From ' + @save_dbname + '.sys.syscomments  c'


insert into @temp_com (id, number, colid, status, encrypted, text) exec (@cmd)
--select * from @temp_com


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - DDL For Database [' + @save_dbname + ']'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '**************************************************************/'


--------------------  Capture object info  -------------------
Select @cmd = 'SELECT o.name, o.object_id, s.name, o.type, o.create_date
   From ' + @save_dbname + '.sys.objects  o, ' + @save_dbname + '.sys.schemas  s ' +
  'Where o.is_ms_shipped <> 1
     and o.schema_id = s.schema_id'
--    and o.name = ''test_tbl'''
--     and o.schema_id = s.schema_id and object_id = 2137058649'


insert into @objinfo (oname, object_id, schema_name, type, create_date) exec (@cmd)
delete from @objinfo where oname is null or oname = ''
--select * from @objinfo


If (@objtype = 'all' or @objtype = 'U')
 and (select count(*) from @objinfo where type = 'u') > 0
   begin
	select @caller_id = 's_u' -- single, type 'u'
	select @save_type = 'u'
	Select @output_flag = 'y'


	goto start_header


	s_u:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


If (@objtype = 'all' or @objtype = 'F')
 and (select count(*) from @objinfo where type = 'f') > 0
   begin
	select @caller_id = 's_f' -- single, type 'f'
	select @save_type = 'f'
	Select @output_flag = 'y'


	goto start_header


	s_f:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


If (@objtype = 'all' or @objtype = 'P')
 and (select count(*) from @objinfo where type = 'p') > 0
   begin
	select @caller_id = 's_p' -- single, type 'p'
	select @save_type = 'p'
	Select @output_flag = 'y'


	goto start_header


	s_p:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


If (@objtype = 'all' or @objtype = 'fn' or @objtype = 'tf' or @objtype = 'if')
 and (select count(*) from @objinfo where type in ('fn', 'tf', 'if')) > 0
   begin
	select @caller_id = 's_fn' -- single, type 'fn'
	select @save_type = 'fn'
	Select @output_flag = 'y'


	goto start_header


	s_fn:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


If (@objtype = 'all' or @objtype in ('v', 'vi'))
 and (select count(*) from @objinfo where type = 'v') > 0
   begin
	select @caller_id = 's_v' -- single, type 'v'
	select @save_type = 'v'
	Select @output_flag = 'y'


	goto start_header


	s_v:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


If (@objtype = 'all' or @objtype = 'tr')
 and (select count(*) from @objinfo where type = 'tr') > 0
   begin
	select @caller_id = 's_tr' -- single, type 'v'
	select @save_type = 'tr'
	Select @output_flag = 'y'


	goto start_header


	s_tr:


	If @objtype <> 'all'
	   begin
		goto label99
	   end
   end


goto label99


--  Header Section
start_header:
If @save_type = 'U'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD NON-DEFAULT FILEGROUPS FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '

	goto filegroups


	filegroups_return:


	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD USER_TYPES FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '

	goto user_types


	user_type_return:


	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD USER_TABLES FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '

	goto start01
   end


If @save_type = 'f'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD FORIEGN KEYS FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '


	goto start01
   end


If @save_type = 'p'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD STORED PROCEDURES FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '


	goto start01
   end


If @save_type = 'fn'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD FUNCTIONS FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '


	goto start01
   end


If @save_type = 'V'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD VIEWS FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '


	goto start01
   end


If @save_type = 'TR'
   begin
	----------------------  Print the headers  ----------------------
	Print  ' '
	Print  ' '
	Print  '/*********************************************************'
	Select @miscprint = 'ADD TRIGGERS FOR DATABASE [' + @save_dbname + ']'
	Print  @miscprint
	Print  '*********************************************************/'
	If @suppress_use_stmt <> 'y'
	   begin
		Print  ' '
		Select @miscprint = 'USE ' + @save_dbname
		Print  @miscprint
		Print  @G_O
	   end
	Print  ' '


	goto start01
   end


-------------------------------------
--  START: Sub routine for filegroups
-------------------------------------
filegroups:
Select @cmd = 'SELECT fg.name
		    , df.name
		    , df.size
		    , df.max_size
		    , df.growth
		    , df.physical_name
		    , df.is_media_read_only
		    , df.is_read_only
		    , df.is_sparse
		    , df.is_percent_growth
		    , df.is_name_reserved
   From ' + @save_dbname + '.sys.filegroups  fg , ' + @save_dbname + '.sys.database_files  df ' +
  'Where fg.data_space_id = df.data_space_id
     and fg.type = ''FG''
     and FG.is_default <> 1'


delete from @tbl_filegroups


insert into @tbl_filegroups (fgname
		    ,dfname
		    ,size
		    ,max_size
		    ,growth
		    ,physical_name
		    ,is_media_read_only
		    ,is_read_only
		    ,is_sparse
		    ,is_percent_growth
		    ,is_name_reserved
			) exec (@cmd)


--select * from @tbl_filegroups


--  Add user data types if any exist
If (select count(*) from @tbl_filegroups) > 0
   begin
	start_filegroups:
	Select @save_fgname = (select top 1 fgname from @tbl_filegroups)
	Select @save_dfname = (select dfname from @tbl_filegroups where fgname = @save_fgname)
	Select @save_dfsize = (select size from @tbl_filegroups where fgname = @save_fgname)
	Select @save_dfmax_size = (select max_size from @tbl_filegroups where fgname = @save_fgname)
	Select @save_dfgrowth = (select growth from @tbl_filegroups where fgname = @save_fgname)
	Select @save_dfphysical_name = (select physical_name from @tbl_filegroups where fgname = @save_fgname)


	--  Print header
	select @miscprint = '------------------------------------------------------------------------------------------------------- '
	print  @miscprint
	select @miscprint = '-- ' + @save_fgname
	print  @miscprint
	select @miscprint = '------------------------------------------------------------------------------------------------------- '
	print  @miscprint


	--  Start to format column output
	select @miscprint = 'If not exists (select 1 from sys.filegroups where name = ''' + @save_fgname + ''')'
	Print @miscprint
	select @miscprint = '   begin'
	Print @miscprint
	select @miscprint = '      ALTER DATABASE [' + @save_dbname + ']'
	Print @miscprint
	select @miscprint = '         ADD FILEGROUP ' + @save_fgname
	Print @miscprint
	select @miscprint = '   end'
	Print @miscprint
	Print 'GO'
	Print ''


	select @miscprint = 'If not exists (select 1 from sys.database_files where name = ''' + @save_dfname + ''')'
	Print @miscprint
	select @miscprint = '   begin'
	Print @miscprint
	select @miscprint = '      ALTER DATABASE [' + @save_dbname + ']'
	Print @miscprint
	select @miscprint = '         ADD FILE ('
	Print @miscprint
	select @miscprint = '            NAME = ' + @save_dfname
	Print @miscprint
	select @miscprint = '           ,FILENAME = ''' + @save_dfphysical_name + ''''
	Print @miscprint
	If @save_dfsize < 128
	   begin
		select @miscprint = '           ,SIZE = 1MB'
		Print @miscprint
	  end
	Else
	   begin
		select @miscprint = '           ,SIZE = ' + convert(nvarchar(12), (@save_dfsize/128)) + 'MB'
		Print @miscprint
	  end


	If @save_dfmax_size < 128
	   begin
		select @miscprint = '           ,MAXSIZE = 1MB'
		Print @miscprint
	   end
	Else
	   begin
		select @miscprint = '           ,MAXSIZE = ' + convert(nvarchar(12), (@save_dfmax_size/128)) + 'MB'
		Print @miscprint
	   end


	If (select is_percent_growth from @tbl_filegroups where fgname = @save_fgname) = 1
	   begin
		select @miscprint = '           ,FILEGROWTH = ' + convert(nvarchar(12), @save_dfgrowth) + '%'
		Print @miscprint
	   end
	Else If @save_dfgrowth < 128
	   begin
		select @miscprint = '           ,FILEGROWTH = 1MB'
		Print @miscprint
	   end
	Else
	   begin
		select @miscprint = '           ,FILEGROWTH = ' + convert(nvarchar(12), (@save_dfgrowth/128)) + 'MB'
		Print @miscprint
	   end


	select @miscprint = '           )'
	Print @miscprint
	select @miscprint = '        TO FILEGROUP ' + @save_fgname
	Print @miscprint
	select @miscprint = '   end'
	Print @miscprint
	Print 'GO'
	Print ''


	--  check for more user types
	Delete from @tbl_filegroups where fgname = @save_fgname
	If (select count(*) from @tbl_filegroups) > 0
	   begin
		goto start_filegroups
	   end
   end
Else
   begin
	Print '--  None Found'
	Print ''
   end


goto filegroups_return
-------------------------------------
--  END: Sub routine for filegroups
-------------------------------------


-------------------------------------
--  START: Sub routine for user types
-------------------------------------
user_types:
Select @cmd = 'SELECT t.name
		    , t.system_type_id
		    , s.name
		    , t.principal_id
		    , t.max_length
		    , t.precision
		    , t.scale
		    , t.collation_name
		    , t.is_nullable
		    , t.is_user_defined
		    , t.is_assembly_type
		    , t.default_object_id
		    , t.rule_object_id
   From ' + @save_dbname + '.sys.types  t , ' + @save_dbname + '.sys.schemas  s ' +
  'Where t.schema_id = s.schema_id
     and t.is_user_defined = 1'


delete from @tbl_types


insert into @tbl_types (tname
		    , system_type_id
		    , sname
		    , principal_id
		    , max_length
		    , precision
		    , scale
		    , collation_name
		    , is_nullable
		    , is_user_defined
		    , is_assembly_type
		    , default_object_id
		    , rule_object_id
			) exec (@cmd)


--select * from @tbl_types


--  Add user data types if any exist
If (select count(*) from @tbl_types) > 0
   begin
	start_user_types:
	Select @save_type_tname = (select top 1 tname from @tbl_types)
	Select @save_type_sname = (select sname from @tbl_types where tname = @save_type_tname)
	Select @save_system_type_id = (select system_type_id from @tbl_types where tname = @save_type_tname)
	Select @cmd = 'use [' + @save_dbname + '] select @save_system_type_name = (select name from sys.types where system_type_id = ' + convert(nvarchar(10), @save_system_type_id ) + ' and is_user_defined = 0)'
	EXEC sp_executesql @cmd, N'@save_system_type_name sysname output', @save_system_type_name output


	--  Start to format column output
	select @miscprint = 'CREATE TYPE [' + @save_type_sname + '] [' + @save_type_tname + '] FROM ' + @save_system_type_name


	--  add length data to column line output
	If @save_system_type_name in ('nvarchar', 'nchar', 'varchar', 'char', 'binary', 'varbinary')
	   begin
		Select @save_max_length_char = (select convert(nvarchar(10), max_length) from @tbl_types where tname = @save_type_tname)
		select @miscprint = @miscprint + '(' + @save_max_length_char + ')'
	   end


	If @save_system_type_name in ('decimal', 'numeric')
	   begin
		Select @save_precision = (select precision from @tbl_types where tname = @save_type_tname)
		Select @save_scale = (select scale from @tbl_types where tname = @save_type_tname)
		select @miscprint = @miscprint + '(' + convert(nvarchar(5), @save_precision) + ', ' + convert(nvarchar(5), @save_scale) + ')'
	   end


	If (select is_nullable from @tbl_types where tname = @save_type_tname) = 1
	   begin
		select @miscprint = @miscprint + ' NULL ;'
	   end
	Else
	   begin
		select @miscprint = @miscprint + ' NOT NULL ;'
	   end


	Print @miscprint
	Print 'GO'
	Print ''


	--  check for more user types
	Delete from @tbl_types where tname = @save_type_tname
	If (select count(*) from @tbl_types) > 0
	   begin
		goto start_user_types
	   end
   end
Else
   begin
	Print '--  None Found'
	Print ''
   end


goto user_type_return
-------------------------------------
--  END: Sub routine for user types
-------------------------------------


-------------------------------------------------------------------
--  START: Sub routine for tables, sprocs, functions, views, triggers
-------------------------------------------------------------------
start01:


update @objinfo set type = 'fn' where type = 'tf'
update @objinfo set type = 'fn' where type = 'if'


If (select count(*) from @objinfo where type = @save_type) > 0
   begin
	start_objinfo:


	-------------  Save the top 1 object id  -------------
	If @save_type = 'fn'
	   begin
		Select @cu11_id = (select top 1 object_id from @objinfo where type in ('fn', 'tf', 'if') order by create_date)
	   end
	Else
	   begin
		Select @cu11_id = (select top 1 object_id from @objinfo where type = @save_type order by create_date)
	   end


	Select @cu11_type = (select type from @objinfo where object_id = @cu11_id)
	Select @cu11_name = (select oname from @objinfo where object_id = @cu11_id)
	Select @cu11_schema_name = (select schema_name from @objinfo where object_id = @cu11_id)
	Select @objname = '[' + @cu11_schema_name + '].[' + @cu11_name + ']'
	Select @TEXTIMAGE_flag = 'n'


	If @save_type = 'u' --tables
	   begin
		--  Now start on the tables
		Select @cmd = 'SELECT c.name
					, c.column_id
					, t.name
					, c.max_length
					, c.precision
					, c.scale
					, c.collation_name
					, c.is_nullable
					, c.is_ansi_padded
					, c.is_rowguidcol
					, c.is_identity
					, c.is_computed
					, c.is_filestream
					, c.is_replicated
					, c.is_non_sql_subscribed
					, c.is_merge_published
					, c.is_dts_replicated
					, c.is_xml_document
					, c.xml_collection_id
					, c.default_object_id
					, c.rule_object_id
		   From ' + @save_dbname + '.sys.columns  c, ' + @save_dbname + '.sys.types  t ' +
		  'Where c.system_type_id = t.system_type_id
		     and c.user_type_id = t.user_type_id
		     and c.object_id = '+ convert(nvarchar(20), @cu11_id)


		delete from @tbl_columns


		insert into @tbl_columns (name
					, column_id
					, type_name
					, max_length
					, precision
					, scale
					, collation_name
					, is_nullable
					, is_ansi_padded
					, is_rowguidcol
					, is_identity
					, is_computed
					, is_filestream
					, is_replicated
					, is_non_sql_subscribed
					, is_merge_published
					, is_dts_replicated
					, is_xml_document
					, xml_collection_id
					, default_object_id
					, rule_object_id
					) exec (@cmd)


		--select * from @tbl_columns


		Select @cmd = 'SELECT c.name
				    , c.object_id
				    , c.type
				    , c.parent_column_id
				    , c.definition
		   From ' + @save_dbname + '.sys.default_constraints  c ' +
		  'Where c.type in (''d'', ''c'')
		     and c.parent_object_id = '+ convert(nvarchar(20), @cu11_id)


		delete from @tbl_cnst


		insert into @tbl_cnst (name
				    ,object_id
				    ,type
				    ,parent_column_id
				    ,definition
					) exec (@cmd)


		--select * from @tbl_cnst


		Select @cmd = 'SELECT ep.class
				    , ep.major_id
				    , ep.minor_id
				    , c.name
				    , ep.name
				    , ep.value
		   From ' + @save_dbname + '.sys.extended_properties  ep , ' + @save_dbname + '.sys.columns  c ' +
		  'Where ep.minor_id = c.column_id
		     and ep.major_id = ' + convert(nvarchar(20), @cu11_id) + '
		     and c.object_id = '+ convert(nvarchar(20), @cu11_id)


		delete from @tbl_exprop


		insert into @tbl_exprop (class
				    ,major_id
				    ,minor_id
				    ,colname
				    ,name
				    ,value
					) exec (@cmd)


		--select * from @tbl_exprop


		If (select count(*) from @tbl_columns) = 0
		   begin
			goto label89
		   end


		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint
		select @miscprint = '-- ' + @cu11_name
		print  @miscprint
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint


		If @suppress_drop_stmt = 'n'
		   begin
			select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsTable'') = 1)'
			print  @miscprint
			select @miscprint = 'drop table [' + @cu11_schema_name + '].[' + @cu11_name + ']'
			print  @miscprint
			print  'GO'
		   end


		If @drop_only = 'y'
		   begin
			goto label89
		   end


		--  set ANSI_NULLS option
		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''IsAnsiNullsOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET ANSI_NULLS ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET ANSI_NULLS OFF'
			print  @miscprint
			print  'GO'
		   end


		--  set QUOTED_IDENTIFIER option
		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''IsQuotedIdentOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER OFF'
			print  @miscprint
			print  'GO'
		   end


		select @miscprint = 'CREATE TABLE [' + @cu11_schema_name + '].[' + @cu11_name + ']('
		print  @miscprint


		--  Start the table column process
		start_table_col:


		Select @save_colname = (select top 1 name from @tbl_columns order by column_id)
		Select @save_type_name = (select type_name from @tbl_columns where name = @save_colname)
		Select @save_max_length = (select max_length from @tbl_columns where name = @save_colname)
		Select @save_column_id = (select column_id from @tbl_columns where name = @save_colname)
		If @save_max_length = -1
		   begin
			Select @save_max_length_char = 'max'
		   end
		Else If @save_type_name in ('nvarchar', 'nchar')
		   begin
			Select @save_max_length_char = convert(nvarchar(20), @save_max_length / 2)
		   end
		Else
		   begin
			Select @save_max_length_char = convert(nvarchar(20), @save_max_length)
		   end


		--  Check for large columns
		If @save_type_name in ('text', 'ntext', 'image', 'xml')
		    or (@save_type_name in ('varchar', 'nvarchar', 'varbinary') and @save_max_length_char = 'max')
		   begin
			Select @TEXTIMAGE_flag = 'y'
		   end


		--  Start to format column output
		select @miscprint = '        [' + @save_colname + '] [' + @save_type_name + ']'


		--  add length data to column line output
		If @save_type_name in ('nvarchar', 'nchar', 'varchar', 'char', 'binary', 'varbinary')
		   begin
			select @miscprint = @miscprint + '(' + @save_max_length_char + ')'
		   end


		If @save_type_name in ('decimal', 'numeric')
		   begin
			Select @save_precision = (select precision from @tbl_columns where name = @save_colname)
			Select @save_scale = (select scale from @tbl_columns where name = @save_colname)
			select @miscprint = @miscprint + '(' + convert(nvarchar(5), @save_precision) + ', ' + convert(nvarchar(5), @save_scale) + ')'
		   end


		--  Check for (and set) identity
		If (select is_identity from @tbl_columns where name = @save_colname) = 1
		   begin
			Select @cmd = 'use [' + @save_dbname + '] select @save_seed_value = (select seed_value from sys.identity_columns where object_id = ' + convert(nvarchar(20), @cu11_id)
								+ ' and column_id = ' + convert(nvarchar(10), @save_column_id) + ')'
			EXEC sp_executesql @cmd, N'@save_seed_value sql_variant output', @save_seed_value output


			Select @cmd = 'use [' + @save_dbname + '] select @save_increment_value = (select increment_value from sys.identity_columns where object_id = ' + convert(nvarchar(20), @cu11_id)
								+ ' and column_id = ' + convert(nvarchar(10), @save_column_id) + ')'
			EXEC sp_executesql @cmd, N'@save_increment_value sql_variant output', @save_increment_value output


			If @save_seed_value is not null and  @save_increment_value is not null
			   begin
				Select @miscprint = @miscprint + ' IDENTITY(' + convert(nvarchar(10), @save_seed_value) + ',' + convert(nvarchar(10), @save_increment_value) + ')'
			   end
		   end


		--  Set collation
		Select @save_collation_name = (select collation_name from @tbl_columns where name = @save_colname)
		If @save_collation_name is not null
		   begin
			Select @miscprint = @miscprint + ' COLLATE ' + @save_collation_name
		   end


		--  Tack on NULL or NOT NULL
		Select @save_is_nullable = case when ((select is_nullable from @tbl_columns where name = @save_colname) = 1) then 'NULL' else 'NOT NULL' end
		Select @miscprint = @miscprint + ' ' + @save_is_nullable


		--  Add default constraints
		If exists (select 1 from @tbl_cnst where type = 'd' and parent_column_id = @save_column_id)
		   begin
			Select @save_cnstname = (select name from @tbl_cnst where type = 'd' and parent_column_id = @save_column_id)
			Select @save_definition = (select definition from @tbl_cnst where type = 'd' and parent_column_id = @save_column_id)


			Select @miscprint = @miscprint + ' CONSTRAINT [' + rtrim(@save_cnstname) + '] DEFAULT ' + rtrim(@save_definition)
		   end


		If (select count(*) from @tbl_columns) > 1
		   begin
			Select @miscprint = @miscprint + ','
		   end


		--  Print the column line output
		print  @miscprint


		--  check for more columns
		Delete from @tbl_columns where name = @save_colname
		If (select count(*) from @tbl_columns) > 0
		   begin
			goto start_table_col
		   end


		--  Now create the primary key or UNIQUE CONSTRAINT if one exists
		Select @save_PKobject_id = null
		If (select count(*) from @tbl_indexes) > 0
		   begin
			Select @save_indxname = (select top 1 name from @tbl_indexes order by index_id)
			Select @cmd = 'use [' + @save_dbname + '] Select @save_PKobject_id = (select object_id from sys.objects where name = '''
					+ @save_indxname + ''' and type in (''pk'', ''uq'') and parent_object_id = ' + convert(nvarchar(20), @cu11_id) + ')'
			EXEC sp_executesql @cmd, N'@save_PKobject_id int output', @save_PKobject_id output
		   end


		If @save_PKobject_id is not null
		   begin
			Select @save_index_id = (select top 1 index_id from @tbl_indexes where name = @save_indxname)
			Select @save_type_desc = (select top 1 type_desc from @tbl_indexes where name = @save_indxname)
			Select @save_data_space_name = (select top 1 data_space_name from @tbl_indexes where name = @save_indxname)


			--  start building string
			select @miscprint = ' ,'


			--  Check to see if the index is system named
			Select @cmd = 'use [' + @save_dbname + '] Select @save_is_system_named = (select is_system_named from sys.key_constraints where name = ''' + @save_indxname + ''')'
			EXEC sp_executesql @cmd, N'@save_is_system_named bit output', @save_is_system_named output


			If @save_is_system_named <> 1
			   begin
				select @miscprint = @miscprint + 'CONSTRAINT [' + @save_indxname + ']'
			   end


			--  Now check to see if this is a primary key
			If (select is_primary_key from @tbl_indexes where name = @save_indxname) = 1
			   begin
				select @miscprint = @miscprint + ' PRIMARY KEY'
			   end


			--  Now check to see if this is a unique key
			If (select is_unique_constraint from @tbl_indexes where name = @save_indxname) = 1
			   begin
				select @miscprint = @miscprint + ' UNIQUE'
			   end


			select @miscprint = @miscprint + ' ' + @save_type_desc
			print  @miscprint


			select @miscprint = '('
			print  @miscprint


			-- get the index keys
			Select @cmd = 'use [' + @save_dbname + '] Select @keys = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', 1)'
			EXEC sp_executesql @cmd, N'@keys nvarchar(2126) output', @keys output


			Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', 1, ''isdescending'')'
			EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


			If @save_indexkey_property = 1
			   begin
				select @miscprint = '        [' + @keys + '] DESC'
				print  @miscprint
			   end
			Else
			   begin
				select @miscprint = '        [' + @keys + '] ASC'
				print  @miscprint
			   end


			Select @i = 2
			Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
			EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output


			while (@thiskey is not null )
			   begin
				Select @keys = @thiskey


				Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ', ''isdescending'')'
				EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


				If @save_indexkey_property = 1
				   begin
					select @miscprint = '       ,[' + @keys + '] DESC'
					print  @miscprint
				   end
				Else
				   begin
					select @miscprint = '       ,[' + @keys + '] ASC'
					print  @miscprint
				   end


				Select @i = @i + 1
				Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
				EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output
			   end


			--  Now set the index options
			Select @save_PAD_INDEX = case when ((select is_padded from @tbl_indexes where name = @save_indxname) = 1) then 'ON' else 'OFF' end
			Select @save_STATISTICS_NORECOMPUTE = case when ((select no_recompute from @tbl_indexes where name = @save_indxname) = 1) then 'ON' else 'OFF' end
			Select @save_IGNORE_DUP_KEY = case when ((select ignore_dup_key from @tbl_indexes where name = @save_indxname) = 1) then 'ON' else 'OFF' end
			Select @save_ALLOW_ROW_LOCKS = case when ((select allow_row_locks from @tbl_indexes where name = @save_indxname) = 1) then 'ON' else 'OFF' end
			Select @save_ALLOW_PAGE_LOCKS = case when ((select allow_page_locks from @tbl_indexes where name = @save_indxname) = 1) then 'ON' else 'OFF' end


			select @miscprint = ')WITH (PAD_INDEX = ' + @save_PAD_INDEX + ', STATISTICS_NORECOMPUTE = '
							+ @save_STATISTICS_NORECOMPUTE + ', IGNORE_DUP_KEY = '
							+ @save_IGNORE_DUP_KEY + ', ALLOW_ROW_LOCKS = '
							+ @save_ALLOW_ROW_LOCKS + ', ALLOW_PAGE_LOCKS = '
							+ @save_ALLOW_PAGE_LOCKS + ') ON [' + @save_data_space_name + ']'
			print  @miscprint


			--  delete this index from @tbl_indexes
			delete from @tbl_indexes where name = @save_indxname


		  end


		--  now set the filegroups
		Select @cmd = 'use [' + @save_dbname + '] select @save_filegroup = (select d.name
										    from sys.data_spaces d
										    where d.data_space_id = (select i.data_space_id
													    from sys.indexes i
													    where i.object_id = ' + convert(nvarchar(20), @cu11_id) + '
													    and i.index_id < 2)
										    )'
		EXEC sp_executesql @cmd, N'@save_filegroup sysname output', @save_filegroup output


		select @miscprint = ') ON [' + @save_filegroup + ']'


		If @TEXTIMAGE_flag = 'y'
		   begin
			Select @cmd = 'use [' + @save_dbname + '] select @save_filegroup = (select d.name
 											    from sys.data_spaces d, sys.tables t
											    where t.object_id = ' + convert(nvarchar(20), @cu11_id) + '
											      and d.data_space_id = t.lob_data_space_id
											    )'
			EXEC sp_executesql @cmd, N'@save_filegroup sysname output', @save_filegroup output


			select @miscprint = @miscprint + ' TEXTIMAGE_ON [' + @save_filegroup + ']'
		   end


		print  @miscprint


		print  'GO'


		--  check to see if there are more indexes to process
		If (select count(*) from @tbl_indexes) > 0
		   begin
			start_indexes:
			Select @save_index_id = (select top 1 index_id from @tbl_indexes order by index_id)
			Select @save_indxname = (select top 1 name from @tbl_indexes where index_id = @save_index_id)
			Select @save_type_desc = (select top 1 type_desc from @tbl_indexes where index_id = @save_index_id)
			Select @save_data_space_name = (select top 1 data_space_name from @tbl_indexes where index_id = @save_index_id)


			--  Now check to see if this is a unique index
			If (select is_unique from @tbl_indexes where index_id = @save_index_id) = 1
			   begin
				select @save_type_desc = 'UNIQUE ' + @save_type_desc
			   end


			select @miscprint = 'CREATE ' +  rtrim(@save_type_desc) + ' INDEX [' + rtrim(@save_indxname) + '] ON ' + @objname
			print  @miscprint
			select @miscprint = '('
			print  @miscprint


			-- get the index keys
			Select @cmd = 'use [' + @save_dbname + '] Select @keys = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', 1)'
			EXEC sp_executesql @cmd, N'@keys nvarchar(2126) output', @keys output


			Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', 1, ''isdescending'')'
			EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


			If @save_indexkey_property = 1
			   begin
				select @miscprint = '        [' + @keys + '] DESC'
				print  @miscprint
			   end
			Else
			   begin
				select @miscprint = '        [' + @keys + '] ASC'
				print  @miscprint
			   end


			Select @i = 2
			Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
			EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output


			while (@thiskey is not null )
			   begin
				Select @keys = @thiskey


				Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ', ''isdescending'')'
				EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


				If @save_indexkey_property = 1
				   begin
					select @miscprint = '       ,[' + @keys + '] DESC'
					print  @miscprint
				   end
				Else
				   begin
					select @miscprint = '       ,[' + @keys + '] ASC'
					print  @miscprint
				   end


				Select @i = @i + 1
				Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
				EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output
			   end


			--  Now set the index options
			Select @save_PAD_INDEX = case when ((select is_padded from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
			Select @save_STATISTICS_NORECOMPUTE = case when ((select no_recompute from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
			Select @save_IGNORE_DUP_KEY = case when ((select ignore_dup_key from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
			Select @save_ALLOW_ROW_LOCKS = case when ((select allow_row_locks from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
			Select @save_ALLOW_PAGE_LOCKS = case when ((select allow_page_locks from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end


			select @miscprint = ')WITH (PAD_INDEX = ' + @save_PAD_INDEX + ', STATISTICS_NORECOMPUTE = '
							+ @save_STATISTICS_NORECOMPUTE + ', IGNORE_DUP_KEY = '
							+ @save_IGNORE_DUP_KEY + ', ALLOW_ROW_LOCKS = '
							+ @save_ALLOW_ROW_LOCKS + ', ALLOW_PAGE_LOCKS = '
							+ @save_ALLOW_PAGE_LOCKS + ') ON [' + @save_data_space_name + ']'
			print  @miscprint
			print  'GO'


			delete from @tbl_indexes where index_id = @save_index_id
			If (select count(*) from @tbl_indexes) > 0
			   begin
				goto start_indexes
			   end
		  end


		--  Now check for extended properties
		If (select count(*) from @tbl_exprop where class = 1) > 0
		   begin
			Print ''
			start_exprop:
			Select @save_minor_id = (select top 1 minor_id from @tbl_exprop where class = 1 order by minor_id)
			Select @save_exprop_name = (select name from @tbl_exprop where class = 1 and minor_id = @save_minor_id)
			Select @save_exprop_value = (select convert(sysname,value) from @tbl_exprop where class = 1 and minor_id = @save_minor_id)
			Select @save_exprop_colname = (select colname from @tbl_exprop where class = 1 and minor_id = @save_minor_id)


			select @miscprint = 'EXEC sys.sp_addextendedproperty @name=N''' + @save_exprop_name + ''', @value=N''' + @save_exprop_value
						+ ''', @level0type=N''SCHEMA'', @level0name=N''' + @cu11_schema_name
						+ ''', @level1type=N''TABLE'', @level1name=N''' + @cu11_name
						+ ''', @level2type=N''COLUMN'', @level2name=N''' + @save_exprop_colname + ''''
			print  @miscprint
			print  'GO'


			Delete from @tbl_exprop where class = 1 and minor_id = @save_minor_id
			If (select count(*) from @tbl_exprop where class = 1) > 0
			   begin
				goto start_exprop
			   end


		   end


		print ''


		--  End type='u' section (tables)
		goto label89


	   end


	-----------------------------------------------------------
	--  start ForeignKeys
	-----------------------------------------------------------
	If @save_type = ('f') --foreignKeys
	   begin
		--  Here we start the foreign key process
		Select @cmd = 'SELECT f.name
					, s.name
					, f.parent_object_id
					, fc.parent_column_id
					, fc.referenced_object_id
					, fc.referenced_column_id
					, f.is_disabled
					, f.is_not_trusted
					, f.is_system_named
		   From ' + @save_dbname + '.sys.foreign_keys  f, '
			  + @save_dbname + '.sys.foreign_key_columns  fc, '
			  + @save_dbname + '.sys.schemas s ' +
		  'Where f.object_id = fc.constraint_object_id
		     and f.schema_id = s.schema_id
		     and f.is_ms_shipped = 0
		     and f.is_disabled = 0
		     and f.object_id = '+ convert(nvarchar(20), @cu11_id)


		delete from @tbl_forkeys


		insert into @tbl_forkeys (fname
					,sname
					,parent_object_id
					,parent_column_id
					,referenced_object_id
					,referenced_column_id
					,is_disabled
					,is_not_trusted
					,is_system_named
					) exec (@cmd)


		--select * from @tbl_forkeys


		If (select count(*) from @tbl_forkeys) = 0
		   begin
			goto label89
		   end


		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint
		select @miscprint = '-- ' + @cu11_name
		print  @miscprint
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint


		Select @save_fk_sname = (select top 1 sname from @tbl_forkeys where fname = @cu11_name)
		Select @save_fk_parent_object_id = (select top 1 parent_object_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname)
		Select @save_fk_parent_column_id = (select top 1 parent_column_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id)
		Select @save_fk_referenced_object_id = (select referenced_object_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id and parent_column_id = @save_fk_parent_column_id)
		Select @save_fk_referenced_column_id = (select referenced_column_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id and parent_column_id = @save_fk_parent_column_id)


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_parent_object_name sysname output', @save_fk_parent_object_name output


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_object_sname = (select s.name from sys.schemas s, sys.objects o where s.schema_id = o.schema_id and o.object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_parent_object_sname sysname output', @save_fk_parent_object_sname output


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_column_name = (select name from sys.columns where object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ' and column_id = ' + convert(nvarchar(20), @save_fk_parent_column_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_parent_column_name sysname output', @save_fk_parent_column_name output


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_referenced_object_name sysname output', @save_fk_referenced_object_name output


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_object_sname = (select s.name from sys.schemas s, sys.objects o where s.schema_id = o.schema_id and o.object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_referenced_object_sname sysname output', @save_fk_referenced_object_sname output


		Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_column_name = (select name from sys.columns where object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ' and column_id = ' + convert(nvarchar(20), @save_fk_referenced_column_id) + ')'
		EXEC sp_executesql @cmd, N'@save_fk_referenced_column_name sysname output', @save_fk_referenced_column_name output


		If @suppress_drop_stmt = 'n'
		   begin
			select @miscprint = 'if exists (select * from sys.foreign_keys where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'')'
			print  @miscprint
			select @miscprint = '				and parent_object_id = OBJECT_ID(N''[' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + ']''))'
			print  @miscprint
			select @miscprint = 'ALTER TABLE [' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + '] DROP CONSTRAINT [' + @cu11_name + ']'
			print  @miscprint
			print  'GO'
		   end


		If @drop_only = 'y'
		   begin
			goto label89
		   end


		Select @save_fk_parent_names = '[' + @save_fk_parent_column_name + ']'
		Select @save_fk_referenced_names = '[' + @save_fk_referenced_column_name + ']'
		fk_start01:
		If (select count(*) from @tbl_forkeys where sname = @save_fk_sname and fname = @cu11_name) > 1
		   begin
			Delete from @tbl_forkeys where sname = @save_fk_sname and fname = @cu11_name and parent_object_id = @save_fk_parent_object_id and parent_column_id = @save_fk_parent_column_id and referenced_object_id = @save_fk_referenced_object_id


			Select @save_fk_parent_object_id = (select top 1 parent_object_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname)
			Select @save_fk_parent_column_id = (select top 1 parent_column_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id)
			Select @save_fk_referenced_object_id = (select referenced_object_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id and parent_column_id = @save_fk_parent_column_id)
			Select @save_fk_referenced_column_id = (select referenced_column_id from @tbl_forkeys where fname = @cu11_name and sname = @save_fk_sname and parent_object_id = @save_fk_parent_object_id and parent_column_id = @save_fk_parent_column_id)


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_parent_object_name sysname output', @save_fk_parent_object_name output


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_object_sname = (select s.name from sys.schemas s, sys.objects o where s.schema_id = o.schema_id and o.object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_parent_object_sname sysname output', @save_fk_parent_object_sname output


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_parent_column_name = (select name from sys.columns where object_id = ' + convert(nvarchar(20), @save_fk_parent_object_id) + ' and column_id = ' + convert(nvarchar(20), @save_fk_parent_column_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_parent_column_name sysname output', @save_fk_parent_column_name output


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_object_name = (select name from sys.objects where object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_referenced_object_name sysname output', @save_fk_referenced_object_name output


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_object_sname = (select s.name from sys.schemas s, sys.objects o where s.schema_id = o.schema_id and o.object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_referenced_object_sname sysname output', @save_fk_referenced_object_sname output


			Select @cmd = 'use [' + @save_dbname + '] select @save_fk_referenced_column_name = (select name from sys.columns where object_id = ' + convert(nvarchar(20), @save_fk_referenced_object_id) + ' and column_id = ' + convert(nvarchar(20), @save_fk_referenced_column_id) + ')'
			EXEC sp_executesql @cmd, N'@save_fk_referenced_column_name sysname output', @save_fk_referenced_column_name output


			select @miscprint = @miscprint + ', [' + @save_fk_referenced_column_name + ']'


			Select @save_fk_parent_names = @save_fk_parent_names + ', [' + @save_fk_parent_column_name + ']'
			Select @save_fk_referenced_names = @save_fk_referenced_names + ', [' + @save_fk_referenced_column_name + ']'


			goto fk_start01
		   end


		select @miscprint = 'IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'')'
		print  @miscprint
		select @miscprint = '			and parent_object_id = OBJECT_ID(N''[' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + ']''))'
		print  @miscprint


		select @miscprint = 'ALTER TABLE [' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + ']'


		If (select top 1 is_not_trusted from @tbl_forkeys where fname = @cu11_name) = 0
		   begin
			select @miscprint = @miscprint + ' WITH CHECK'
		   end
		Else
		   begin
			select @miscprint = @miscprint + ' WITH NOCHECK'
		   end


		select @miscprint = @miscprint + ' ADD CONSTRAINT [' + @cu11_name + '] FOREIGN KEY(' + @save_fk_parent_names + ')'
		print  @miscprint
		select @miscprint = 'REFERENCES [' + @save_fk_referenced_object_sname + '].[' + @save_fk_referenced_object_name + '] (' + @save_fk_referenced_names + ')'
		print  @miscprint
		print 'GO'


		If (select is_disabled from @tbl_forkeys where fname = @cu11_name) = 0
		   begin
			select @miscprint = 'ALTER TABLE [' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + '] CHECK CONSTRAINT [' + @cu11_name + ']'
			print  @miscprint
			print 'GO'
			print ''
		   end
		Else
		   begin
			select @miscprint = 'ALTER TABLE [' + @save_fk_parent_object_sname + '].[' + @save_fk_parent_object_name + '] NOCHECK CONSTRAINT [' + @cu11_name + ']'
			print  @miscprint
			print 'GO'
			print ''
		   end


	   end
	-----------------------------------------------------------
	--  end ForeignKeys
	-----------------------------------------------------------


	-----------------------------------------------------------
	--  start views
	-----------------------------------------------------------
	If @save_type in ('v', 'vi') --views
	   begin
		--  Find out how many lines of text are coming back, and return if there are none.
		if (select count(*) from @temp_com where id = @cu11_id) = 0
		   begin
			raiserror(15197,-1,-1,@cu11_name)
			goto label89
		   end


		if (select count(*) from @temp_com where id = @cu11_id and encrypted = 0) = 0
		   begin
			raiserror(15471,-1,-1)
			goto label89
		   end


		--  Get index related to this view
		Select @cmd = 'SELECT i.name
				, i.index_id
				, i.type
				, i.type_desc
				, i.is_unique
				, i.data_space_id
				, d.name
				, i.ignore_dup_key
				, i.is_primary_key
				, i.is_unique_constraint
				, i.fill_factor
				, i.is_padded
				, i.is_disabled
				, i.is_hypothetical
				, i.allow_row_locks
				, i.allow_page_locks
				, s.auto_created
				, s.no_recompute
		   From ' + @save_dbname + '.sys.indexes  i, ' + @save_dbname + '.sys.stats  s, ' + @save_dbname + '.sys.data_spaces  d ' +
		  'Where i.object_id = s.object_id
		     and i.index_id = s.stats_id
		     and i.data_space_id = d.data_space_id
		     and i.object_id = '+ convert(nvarchar(20), @cu11_id)


		delete from @tbl_indexes


		insert into @tbl_indexes (name
					,index_id
					,type
					,type_desc
					,is_unique
					,data_space_id
					,data_space_name
					,ignore_dup_key
					,is_primary_key
					,is_unique_constraint
					,fill_factor
					,is_padded
					,is_disabled
					,is_hypothetical
					,allow_row_locks
					,allow_page_locks
					,auto_created
					,no_recompute
					) exec (@cmd)


		--select * from @tbl_indexes


		If @objtype = 'vi' and (select count(*) from @tbl_indexes) = 0
		   begin
			goto skip_view
		   end


		--  get the object text.
		delete from #CommentText


		SELECT @LFCR = 2
		SELECT @LineId = 1


		delete from @tbl_Syscom
		insert into @tbl_Syscom (SyscomText, number, colid)
		SELECT text, number, colid FROM @temp_com
					WHERE id = @cu11_id
					  and encrypted = 0


		If (select count(*) from @tbl_Syscom) > 0
		   begin
			start_syscom1:


			Select @SyscomText = (select top 1 SyscomText from @tbl_Syscom order by number, colid)
			Select @save_number = (select top 1 number from @tbl_Syscom where SyscomText = @SyscomText order by number, colid)
			Select @save_colid = (select top 1 colid from @tbl_Syscom where SyscomText = @SyscomText order by number, colid)


			SELECT @BasePos = 1
			SELECT @CurrentPos = 1
			SELECT @TextLength = LEN(@SyscomText)


			WHILE @CurrentPos  != 0
			   BEGIN
				--Looking for end of line followed by carriage return
				SELECT @CurrentPos = CHARINDEX(char(13)+char(10), @SyscomText, @BasePos)


				--If carriage return found
				IF @CurrentPos != 0
				   BEGIN
					/*If new value for @Lines length will be > then the
					**set length then insert current contents of @line
					**and proceed.
					*/
					While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @CurrentPos-@BasePos + @LFCR) > @DefinedLength
					   BEGIN
						SELECT @AddOnLen = @DefinedLength-(isnull(LEN(@Line),0) + @BlankSpaceAdded)
						INSERT #CommentText VALUES (@LineId, isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
						SELECT @Line = NULL
						SELECT @LineId = @LineId + 1
						SELECT @BasePos = @BasePos + @AddOnLen
						SELECT @BlankSpaceAdded = 0
					   END
					SELECT @Line = isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'')
					SELECT @BasePos = @CurrentPos+2
					INSERT #CommentText VALUES( @LineId, @Line )
					SELECT @LineId = @LineId + 1
					SELECT @Line = NULL
				   END
				ELSE
				--else carriage return not found
				   BEGIN
					IF @BasePos <= @TextLength
					   BEGIN
						/*If new value for @Lines length will be > then the
						**defined length
						*/
						While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @TextLength-@BasePos+1 ) > @DefinedLength
						   BEGIN
							SELECT @AddOnLen = @DefinedLength - (isnull(LEN(@Line),0) + @BlankSpaceAdded )
							INSERT #CommentText VALUES (@LineId, isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
							SELECT @Line = NULL
							SELECT @LineId = @LineId + 1
							SELECT @BasePos = @BasePos + @AddOnLen
							SELECT @BlankSpaceAdded = 0
						   END
						SELECT @Line = isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @TextLength-@BasePos+1 ), N'')
						if charindex(' ', @SyscomText, @TextLength+1 ) > 0
						   BEGIN
							SELECT @Line = @Line + ' '
							SELECT @BlankSpaceAdded = 1
						   END
						BREAK
					END
				END
			END


			-- check for more syscom rows to process
			delete from @tbl_Syscom where SyscomText = @SyscomText and number = @save_number and colid = @save_colid
			If (select count(*) from @tbl_Syscom) > 0
			   begin
				goto start_syscom1
			   end


		   end


		IF @Line is NOT NULL
		   begin
			INSERT #CommentText VALUES( @LineId, @Line )
		   end


		print ''
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint
		select @miscprint = '-- ' + @cu11_name
		print  @miscprint
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint


		If @suppress_drop_stmt = 'n'
		   begin
			select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsView'') = 1)'
			print  @miscprint
			select @miscprint = 'drop view [' + @cu11_schema_name + '].[' + @cu11_name + ']'


			print  @miscprint
			print  'GO'
			print  ' '
		   end


		If @drop_only = 'y'
		   begin
			goto label89
		   end


		--  set ANSI_NULLS option
		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''ExecIsAnsiNullsOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET ANSI_NULLS ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET ANSI_NULLS OFF'
			print  @miscprint
			print  'GO'
		   end


		--  set QUOTED_IDENTIFIER option
    		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''ExecIsQuotedIdentOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER OFF'
			print  @miscprint
			print  'GO'
		   end


		If (select count(*) from #CommentText) > 0
		   begin
			start_commenta:


			Select @save_lineid = (select top 1 lineid from #CommentText order by lineid)
			Select @commentText = (select text from #CommentText where lineid = @save_lineid)


			--  Fix CR's with out line feeds
			Select @pos = 1
			Label90a:
			Select @charpos = charindex(char(13), @commentText, @pos)
			IF @charpos <> 0
			   begin
				Select @pos = @charpos
				If substring(@commentText, @charpos+1, 1) <> char(10)
				   begin
					select @commentText = stuff(@commentText, @charpos, 1, char(13)+char(10))
					Select @pos = @pos + 1
				   end
			   end


			Select @pos = @pos + 1
			Select @charpos = charindex(char(13), @commentText, @pos)
			IF @charpos <> 0
			   begin
				goto label90a
			   end


			--  Fix line feeds with no preceeding CR
			Select @pos = 1
			Label91a:
			Select @charpos = charindex(char(10), @commentText, @pos)
			IF @charpos <> 0
			   begin
				Select @pos = @charpos
				If substring(@commentText, @charpos-1, 1) <> char(13)
				   begin
					select @commentText = stuff(@commentText, @charpos, 1, char(13)+char(10))
					Select @pos = @pos + 1
				   end
			   end


			Select @pos = @pos + 1
			Select @charpos = charindex(char(10), @commentText, @pos)
			IF @charpos <> 0
			   begin
				goto label91a
			   end


			select @miscprint = @commentText
			print  @miscprint


			-- check for more comment rows to process
			Delete from #CommentText where lineid = @save_lineid
			If (select count(*) from #CommentText) > 0
			   begin
				goto start_commenta
			   end


			SELECT @Line = NULL

			Print  @G_O
			Print  ' '


			--  check to see if there are indexes for this view to process
			If (select count(*) from @tbl_indexes) > 0
			   begin
				start_vw_indexes:
				Select @save_index_id = (select top 1 index_id from @tbl_indexes order by index_id)
				Select @save_indxname = (select top 1 name from @tbl_indexes where index_id = @save_index_id)
				Select @save_type_desc = (select top 1 type_desc from @tbl_indexes where index_id = @save_index_id)
				Select @save_data_space_name = (select top 1 data_space_name from @tbl_indexes where index_id = @save_index_id)


				--  Now check to see if this is a unique index
				If (select is_unique from @tbl_indexes where index_id = @save_index_id) = 1
				   begin
					select @save_type_desc = 'UNIQUE ' + @save_type_desc
				   end


				select @miscprint = 'CREATE ' +  rtrim(@save_type_desc) + ' INDEX [' + rtrim(@save_indxname) + '] ON ' + @objname
				print  @miscprint
				select @miscprint = '('
				print  @miscprint


				-- get the index keys
				Select @cmd = 'use [' + @save_dbname + '] Select @keys = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', 1)'
				EXEC sp_executesql @cmd, N'@keys nvarchar(2126) output', @keys output


				Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', 1, ''isdescending'')'
				EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


				If @save_indexkey_property = 1
				   begin
					select @miscprint = '        [' + @keys + '] DESC'
					print  @miscprint
				   end
				Else
				   begin
					select @miscprint = '        [' + @keys + '] ASC'
					print  @miscprint
				   end


				Select @i = 2
				Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
				EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output


				while (@thiskey is not null )
				   begin
					Select @keys = @thiskey


					Select @cmd = 'use [' + @save_dbname + '] Select @save_indexkey_property = indexkey_property(' + convert(nvarchar(20), @cu11_id) + ', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ', ''isdescending'')'
					EXEC sp_executesql @cmd, N'@save_indexkey_property char(1) output', @save_indexkey_property output


					If @save_indexkey_property = 1
					   begin
						select @miscprint = '       ,[' + @keys + '] DESC'
						print  @miscprint
					   end
					Else
					   begin
						select @miscprint = '       ,[' + @keys + '] ASC'
						print  @miscprint
					   end


					Select @i = @i + 1
					Select @cmd = 'use [' + @save_dbname + '] Select @thiskey = index_col(''' + @objname + ''', ' + convert(nvarchar(20), @save_index_id) + ', ' + convert(nvarchar(10), @i) + ')'
					EXEC sp_executesql @cmd, N'@thiskey nvarchar(131) output', @thiskey output
				   end


				--  Now set the index options
				Select @save_PAD_INDEX = case when ((select is_padded from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
				Select @save_STATISTICS_NORECOMPUTE = case when ((select no_recompute from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
				Select @save_IGNORE_DUP_KEY = case when ((select ignore_dup_key from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
				Select @save_ALLOW_ROW_LOCKS = case when ((select allow_row_locks from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end
				Select @save_ALLOW_PAGE_LOCKS = case when ((select allow_page_locks from @tbl_indexes where index_id = @save_index_id) = 1) then 'ON' else 'OFF' end


				select @miscprint = ')WITH (PAD_INDEX = ' + @save_PAD_INDEX + ', STATISTICS_NORECOMPUTE = '
								+ @save_STATISTICS_NORECOMPUTE + ', IGNORE_DUP_KEY = '
								+ @save_IGNORE_DUP_KEY + ', ALLOW_ROW_LOCKS = '
								+ @save_ALLOW_ROW_LOCKS + ', ALLOW_PAGE_LOCKS = '
								+ @save_ALLOW_PAGE_LOCKS + ') ON [' + @save_data_space_name + ']'
				print  @miscprint
				SELECT @Line = NULL

				Print  @G_O
				Print  ' '


				delete from @tbl_indexes where index_id = @save_index_id
				If (select count(*) from @tbl_indexes) > 0
				   begin
					goto start_vw_indexes
				   end
			  end


		   end


		Print  ' '


		Select @output_flag	= 'y'


		skip_view:


		goto label89


	   end
	-----------------------------------------------------------
	--  end view section
	-----------------------------------------------------------


	-----------------------------------------------------------
	--  start sprocs, function, triggers
	-----------------------------------------------------------
	If @save_type in ('p', 'fn', 'tr') --sprocs, function, triggers
	   begin
		--  Find out how many lines of text are coming back, and return if there are none.
		if (select count(*) from @temp_com where id = @cu11_id) = 0
		   begin
			raiserror(15197,-1,-1,@cu11_name)
			goto label89
		   end


		if (select count(*) from @temp_com where id = @cu11_id and encrypted = 0) = 0
		   begin
			raiserror(15471,-1,-1)
			goto label89
		   end


		--  get the object text.
		delete from #CommentText


		SELECT @LFCR = 2
		SELECT @LineId = 1


		delete from @tbl_Syscom
		insert into @tbl_Syscom (SyscomText, number, colid)
		SELECT text, number, colid FROM @temp_com
					WHERE id = @cu11_id
					  and encrypted = 0


		--select * from @tbl_Syscom


		If (select count(*) from @tbl_Syscom) > 0
		   begin
			start_syscom:


			Select @SyscomText = (select top 1 SyscomText from @tbl_Syscom order by number, colid)
			Select @save_number = (select top 1 number from @tbl_Syscom where SyscomText = @SyscomText order by number, colid)
			Select @save_colid = (select top 1 colid from @tbl_Syscom where SyscomText = @SyscomText order by number, colid)


			SELECT @BasePos = 1
			SELECT @CurrentPos = 1
			SELECT @TextLength = LEN(@SyscomText)


			WHILE @CurrentPos  != 0
			   BEGIN
				--Looking for end of line followed by carriage return
				SELECT @CurrentPos = CHARINDEX(char(13)+char(10), @SyscomText, @BasePos)


				--If carriage return found
				IF @CurrentPos != 0
				   BEGIN
					/*If new value for @Lines length will be > then the
					**set length then insert current contents of @line
					**and proceed.
					*/
					While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @CurrentPos-@BasePos + @LFCR) > @DefinedLength
					   BEGIN
						SELECT @AddOnLen = @DefinedLength-(isnull(LEN(@Line),0) + @BlankSpaceAdded)
						INSERT #CommentText VALUES (@LineId, isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
						SELECT @Line = NULL
						SELECT @LineId = @LineId + 1
						SELECT @BasePos = @BasePos + @AddOnLen
						SELECT @BlankSpaceAdded = 0
					   END
					SELECT @Line = isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'')
					SELECT @BasePos = @CurrentPos+2
					INSERT #CommentText VALUES( @LineId, @Line )
					SELECT @LineId = @LineId + 1
					SELECT @Line = NULL
				   END
				ELSE
				--else carriage return not found
				   BEGIN
					IF @BasePos <= @TextLength
					   BEGIN
						/*If new value for @Lines length will be > then the
						**defined length
						*/
						While (isnull(LEN(@Line),0) + @BlankSpaceAdded + @TextLength-@BasePos+1 ) > @DefinedLength
						   BEGIN
							SELECT @AddOnLen = @DefinedLength - (isnull(LEN(@Line),0) + @BlankSpaceAdded )
							INSERT #CommentText VALUES (@LineId, isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
							SELECT @Line = NULL
							SELECT @LineId = @LineId + 1
							SELECT @BasePos = @BasePos + @AddOnLen
							SELECT @BlankSpaceAdded = 0
						   END
						SELECT @Line = isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @TextLength-@BasePos+1 ), N'')
						if charindex(' ', @SyscomText, @TextLength+1 ) > 0
						   BEGIN
							SELECT @Line = @Line + ' '
							SELECT @BlankSpaceAdded = 1
						   END
						BREAK
					END
				END
			END


			-- check for more syscom rows to process
			delete from @tbl_Syscom where SyscomText = @SyscomText and number = @save_number and colid = @save_colid
			If (select count(*) from @tbl_Syscom) > 0
			   begin
				goto start_syscom
			   end


		   end


		IF @Line is NOT NULL
		   begin
			INSERT #CommentText VALUES( @LineId, @Line )
		   end


		print ''
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint
		select @miscprint = '-- ' + @cu11_name
		print  @miscprint
		select @miscprint = '------------------------------------------------------------------------------------------------------- '
		print  @miscprint


		If @suppress_drop_stmt = 'n'
		   begin
			If @save_type = 'p'
			   begin
				select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsProcedure'') = 1)'
				print  @miscprint
				select @miscprint = 'drop procedure [' + @cu11_schema_name + '].[' + @cu11_name + ']'
				print  @miscprint
				print  'GO'
				print  ''
			   end
			Else If @save_type = 'fn' and @cu11_type = 'if'
			   begin
				select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsInlineFunction'') = 1)'
				print  @miscprint
				select @miscprint = 'drop function [' + @cu11_schema_name + '].[' + @cu11_name + ']'
				print  @miscprint
				print  'GO'
				print  ''
			   end
			Else If @save_type = 'fn' and @cu11_type = 'fn'
			   begin
				select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsScalarFunction'') = 1)'
				print  @miscprint
				select @miscprint = 'drop function [' + @cu11_schema_name + '].[' + @cu11_name + ']'
				print  @miscprint
				print  'GO'
				print  ''
			   end
			Else If @save_type = 'fn' and @cu11_type = 'tf'
			   begin
				select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsTableFunction'') = 1)'
				print  @miscprint
				select @miscprint = 'drop function [' + @cu11_schema_name + '].[' + @cu11_name + ']'
				print  @miscprint
				print  'GO'
				print  ''
			   end
			Else If @save_type = 'tr'
			   begin
				select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsTrigger'') = 1)'
				print  @miscprint
				select @miscprint = 'drop trigger [' + @cu11_schema_name + '].[' + @cu11_name + ']'
				print  @miscprint
				print  'GO'
				print  ''
			   end
		   end


		If @drop_only = 'y'
		   begin
			goto label89
		   end


		--  set ANSI_NULLS option
		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''ExecIsAnsiNullsOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET ANSI_NULLS ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET ANSI_NULLS OFF'
			print  @miscprint
			print  'GO'
		   end


		--  set QUOTED_IDENTIFIER option
    		Select @cmd = 'use [' + @save_dbname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_schema_name + '].[' + @cu11_name + ']''), N''ExecIsQuotedIdentOn'')'
		EXEC sp_executesql @cmd, N'@save_objid int output', @save_objid output
		If @save_objid = 1
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER ON'
			print  @miscprint
			print  'GO'
		   end
		Else
		   begin
			select @miscprint = 'SET QUOTED_IDENTIFIER OFF'
			print  @miscprint
			print  'GO'
		   end


		If (select count(*) from #CommentText) > 0
		   begin
			start_comment:


			Select @save_lineid = (select top 1 lineid from #CommentText order by lineid)
			Select @commentText = (select text from #CommentText where lineid = @save_lineid)


			--  Fix CR's with out line feeds
			Select @pos = 1
			Label90:
			Select @charpos = charindex(char(13), @commentText, @pos)
			IF @charpos <> 0
			   begin
				Select @pos = @charpos
				If substring(@commentText, @charpos+1, 1) <> char(10)
				   begin
					select @commentText = stuff(@commentText, @charpos, 1, char(13)+char(10))
					Select @pos = @pos + 1
				   end
			   end


			Select @pos = @pos + 1
			Select @charpos = charindex(char(13), @commentText, @pos)
			IF @charpos <> 0
			   begin
				goto label90
			   end


			--  Fix line feeds with no preceeding CR
			Select @pos = 1
			Label91:
			Select @charpos = charindex(char(10), @commentText, @pos)
			IF @charpos <> 0
			   begin
				Select @pos = @charpos
				If substring(@commentText, @charpos-1, 1) <> char(13)
				   begin
					select @commentText = stuff(@commentText, @charpos, 1, char(13)+char(10))
					Select @pos = @pos + 1
				   end
			   end


			Select @pos = @pos + 1
			Select @charpos = charindex(char(10), @commentText, @pos)
			IF @charpos <> 0
			   begin
				goto label91
			   end


			select @miscprint = @commentText
			print  @miscprint


			-- check for more comment rows to process
			Delete from #CommentText where lineid = @save_lineid
			If (select count(*) from #CommentText) > 0
			   begin
				goto start_comment
			   end


		   end


		SELECT @Line = NULL

		Print  @G_O
		Print  ' '
		Print  ' '


		Select @output_flag	= 'y'


		goto label89


	   end
	-----------------------------------------------------------
	--  end sprocs, function, triggers section
	-----------------------------------------------------------


	label89:


	--  Check for more objects to process
	Delete from @objinfo where object_id = @cu11_id
	If (select count(*) from @objinfo where type = @save_type) > 0
	   begin
		goto start_objinfo
	   end


	--  Return to the caller
	If @caller_id = 's_u'
	   begin
		goto s_u
	   end


	If @caller_id = 's_f'
	   begin
		goto s_f
	   end


	If @caller_id = 's_p'
	   begin
		goto s_p
	   end


	If @caller_id = 's_fn'
	   begin
		goto s_fn
	   end


	If @caller_id = 's_v'
	   begin
		goto s_v
	   end


	If @caller_id = 's_tr'
	   begin
		goto s_tr
	   end


   end
-------------------------------------------------------------------
--  END: Sub routine for tables, sprocs, functions, views, triggers
-------------------------------------------------------------------


---------------------------  Finalization  -----------------------
label99:


DROP TABLE #CommentText


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end
GO
GRANT EXECUTE ON  [dbo].[dbasp_script_DDL] TO [public]
GO
