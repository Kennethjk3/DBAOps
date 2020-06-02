SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_script_DBsprocs] (@DBname sysname = null)


/*********************************************************
 **  Stored Procedure dbasp_script_DBsprocs
 **  Written by Steve Ledridge, Virtuoso
 **  September 27, 2002
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Script all sprcos for a specific DB
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/27/2002	Steve Ledridge		New process
--	10/01/2002	Steve Ledridge		Change default length tp 500 (from 255)
--	10/08/2002	Steve Ledridge		Fixed mutiple line feed problem and
--						changed IF @BasePos < @TextLength to
--						IF @BasePos <= @TextLength
--	02/14/2006	Steve Ledridge		Modified for sql2005.
--	06/13/2006	Steve Ledridge		Added 'order by lineid' to 'Select @save_lineid = '...
--	09/13/2007	Steve Ledridge		Added options ansi_nulls and quoted_identifier
--	05/08/2008	Steve Ledridge		Added no-drop code for sproc dbasp_Code_Updates.
--	08/22/2008	Steve Ledridge		Fixed no-drop flag.
--	10/21/2010	Steve Ledridge		Added no-drop code for sproc dpsp_ahp_controller.
--	12/03/2010	Steve Ledridge		Added condition create empty sproc followed by ALTER.
--	01/10/2010	Steve Ledridge		Modified CREATE OR ALTER PROCEDURE syntax.
--	02/28/2011	Steve Ledridge		Re-enabled no-drop code for 2 sprocs.
--	04/10/2013	Steve Ledridge		Modified create to alter code.
--	01/14/2016	Steve Ledridge		Ignore objects created for collection sets.
--	02/04/2016	Steve Ledridge		Fixed change create to alter code.
--	======================================================================================


-----------------  declares  ------------------


/**
Declare @DBname sysname


--Select @DBname = 'dbaperf'
--**/


DECLARE
	 @miscprint		nvarchar(500)
	,@DefinedLength		int
	,@BlankSpaceAdded	int
	,@output_flag		char(1)
	,@G_O			nvarchar(2)
	,@LFCR			int --lengths of line feed carriage return
	,@cmd			nvarchar(2000)
	,@LineId		int
	,@SyscomText		nvarchar(4000)
	,@save_number		smallint
	,@save_colid		smallint
	,@save_lineid		int
	,@save_objid		int
	,@charpos		int
	,@pos			int
	,@alter_sproc		char(1)


declare
	 @BasePos		int
	,@CurrentPos		int
	,@TextLength		int
	,@AddOnLen		int
	,@Line			nvarchar(500)
	,@commentText		nvarchar(500)


declare
	 @cu11_name		sysname
	,@cu11_id		int
	,@cu11_uname		sysname


----------------  initial values  -------------------


/* NOTE: Length of @SyscomText is 4000 to replace the length of
** text column in syscomments.
** Lengths on @Line, #CommentText Text column and
** value for @DefinedLength are all 500. These need to all have
** the same values.
*/

Select @G_O             = 'g' + 'o'
Select @DefinedLength   = 500
Select @BlankSpaceAdded = 0 /*Keeps track of blank spaces at end of lines. Note Len function ignores
							 trailing blank spaces*/
Select @output_flag	= 'n'


DROP TABLE IF EXISTS ##temp_com
DROP TABLE IF EXISTS ##temp_obj
DROP TABLE IF EXISTS #CommentText
DROP TABLE IF EXISTS #Syscom


--  Create tables and table variables
declare @objinfo table	(oname		sysname
			,oid		int
			,uname		sysname
			)


CREATE TABLE #CommentText (LineId	int
			,Text	nvarchar(500)
			)


CREATE TABLE #Syscom (SyscomText	nvarchar(4000)
			,number		smallint
			,colid		smallint
			)


If @DBname is null
   begin
	Select @DBname = 'DBAOps'
   end


/*********************************************************************
 *                Initialization
 ********************************************************************/


EXEC ('SELECT id, number, colid, status, encrypted, text INTO ##temp_com FROM ' + @DBname + '.sys.syscomments')
--select * from ##temp_com


EXEC ('SELECT id, xtype INTO ##temp_obj FROM ' + @DBname + '.sys.sysobjects')
--select * from ##temp_obj


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Main header  ----------------------
Print  ' '
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - script_DBsprocs For Database ' + @dbname
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '**************************************************************/'
Print  ' '


----------------------  Print the headers  ----------------------
Print  '/*********************************************************'
Select @miscprint = 'ADD STORED PROCEDURES FOR DATABASE ' + @DBName
Print  @miscprint
Print  '*********************************************************/'
Print  ' '
Select @miscprint = 'USE ' + @DBname
Print  @miscprint
Print  @G_O
Print  ' '


--------------------  Capture Sproc names  -------------------


Select @cmd = 'SELECT o.name, o.object_id, s.name
   From ' + @DBname + '.sys.objects  o, ' + @DBname + '.sys.schemas  s ' +
  'Where o.type = ''p''
     and o.schema_id = s.schema_id
     and s.name not like ''%snapshot%''
     and s.name not like ''%sysutility%''
     and s.name <> ''core'''


insert into @objinfo (oname, oid, uname) exec (@cmd)


delete from @objinfo where oname is null or oname = ''
--select * from @objinfo


If (select count(*) from @objinfo) > 0
   begin
	start_objinfo:


	Select @cu11_id = (select top 1 oid from @objinfo order by oname)
	Select @cu11_name = (select oname from @objinfo where oid = @cu11_id)
	Select @cu11_uname = (select uname from @objinfo where oid = @cu11_id)


	-------------  Save the first object id  -------------


	--  Find out how many lines of text are coming back, and return if there are none.
	if (select count(*) from ##temp_com c, ##temp_obj o
		where o.xtype not in ('S', 'U')
		  and o.id = c.id
		  and o.id = @cu11_id) = 0
	   begin
		raiserror(15197,-1,-1,@cu11_name)
		goto label89
	   end


	if (select count(*) from ##temp_com
		where id = @cu11_id
		  and encrypted = 0) = 0
	   begin
		raiserror(15471,-1,-1)
		goto label89
	   end


	--  get the object text.
	delete from #CommentText


	SELECT @LFCR = 2
	SELECT @LineId = 1


	delete from #Syscom
	insert into #Syscom (SyscomText, number, colid)
	SELECT text, number, colid FROM ##temp_com
				WHERE id = @cu11_id
				  and encrypted = 0


	If (select count(*) from #Syscom) > 0
	   begin
		start_syscom:


		Select @SyscomText = (select top 1 SyscomText from #Syscom order by number, colid)
		Select @save_number = (select top 1 number from #Syscom where SyscomText = @SyscomText order by number, colid)
		Select @save_colid = (select top 1 colid from #Syscom where SyscomText = @SyscomText order by number, colid)


		SELECT  @BasePos	= 1
		SELECT  @CurrentPos	= 1
		SELECT	@TextLength = LEN(@SyscomText)


		WHILE @CurrentPos  != 0
		   BEGIN
			--Looking for end of line followed by carriage return
			SELECT @CurrentPos =   CHARINDEX(char(13)+char(10), @SyscomText, @BasePos)


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
				SELECT @Line	= isnull(@Line, N'') + isnull(SUBSTRING(@SyscomText, @BasePos, @CurrentPos-@BasePos + @LFCR), N'')
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
						SELECT @AddOnLen = @DefinedLength - (isnull(LEN(@Line),0)  + @BlankSpaceAdded )
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
		delete from #Syscom where SyscomText = @SyscomText and number = @save_number and colid = @save_colid
		If (select count(*) from #Syscom) > 0
		   begin
			goto start_syscom
		   end


	   end


	IF @Line is NOT NULL
	   begin
		INSERT #CommentText VALUES( @LineId, @Line )
	   end


	print ''
	print ''
	select @miscprint = '------------------------------------------------------------------------------------------------------- '
	print  @miscprint
	select @miscprint = '-- ' + @cu11_name
	print  @miscprint
	select @miscprint = '------------------------------------------------------------------------------------------------------- '
	print  @miscprint


	Select @alter_sproc = 'y'


	--If @cu11_name like '%dbasp_Code_Updates%' or @cu11_name like '%dpsp_ahp_controller%'
	--   begin
	--	Select @alter_sproc = 'n'
	--	--select @miscprint = 'if exists (select * from sys.objects where object_id = object_id(N''[' + @cu11_uname + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsProcedure'') = 1)'
	--	--print  @miscprint
	--	--select @miscprint = 'drop procedure [' + @cu11_uname + '].[' + @cu11_name + ']'
	--	--print  @miscprint
	--	--print  'GO'
	--   end
	--Else
	--   begin
	--	Select @alter_sproc = 'y'
	--	select @miscprint = 'declare @cmd sysname'
	--	print  @miscprint
	--	select @miscprint = 'if not exists (select 1 from sys.objects where object_id = object_id(N''[' + @cu11_uname + '].[' + @cu11_name + ']'') and OBJECTPROPERTY(object_id, N''IsProcedure'') = 1)'
	--	print  @miscprint
	--	select @miscprint = '   begin'
	--	print  @miscprint
	--	select @miscprint = '	    Select @cmd = ''CREATE OR ALTER PROCEDURE [' + @cu11_uname + '].[' + @cu11_name + '] as set nocount on'''
	--	print  @miscprint
	--	select @miscprint = '	    exec(@cmd)'
	--	print  @miscprint
	--	select @miscprint = '   end'
	--	print  @miscprint
	--	print  'GO'
	--	print ''
	--   end


	--  set ANSI_NULLS option
	Select @cmd = 'use [' + @DBname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_uname + '].[' + @cu11_name + ']''), N''ExecIsAnsiNullsOn'')'
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
    	Select @cmd = 'use [' + @DBname + '] select @save_objid = OBJECTPROPERTY(object_id(N''[' + @cu11_uname + '].[' + @cu11_name + ']''), N''ExecIsQuotedIdentOn'')'
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


	If @alter_sproc = 'n'
	   begin
		print  ''
		select @miscprint = 'IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[' + @cu11_uname + '].[' + @cu11_name + ']'') AND type in (N''P'', N''PC''))'
		print  @miscprint
		select @miscprint = 'Begin'
		print  @miscprint
		select @miscprint = 'EXEC dbo.sp_executesql @statement = N'''
		print  @miscprint
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


		If @alter_sproc = 'n'
		   begin
			Select @commentText = replace(@commentText, '''', '''''')
		   end


		--  Replace CREATE with ALTER
		If @commentText like '%create %' and @commentText like '%PROCEDURE%' and @commentText like '%' + @cu11_name + '%' and @alter_sproc = 'y'
		   begin
			Select @commentText = replace(@commentText, 'create ', 'CREATE OR ALTER ')
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

	Print  ' '


	If @alter_sproc = 'n'
	   begin
		print  ''
		select @miscprint = ''''
		print  @miscprint
		select @miscprint = 'End'
		print  @miscprint
	   end


	Print  @G_O


	Select @output_flag	= 'y'


	label89:


	--  Check for more objects to process
	Delete from @objinfo where oid = @cu11_id
	If (select count(*) from @objinfo) > 0
	   begin
		goto start_objinfo
	   end


   end


---------------------------  Finalization  -----------------------
label99:


If @output_flag = 'n'
   begin
	Print '-- No output for this script.'
   end


DROP TABLE ##temp_com
DROP TABLE ##temp_obj
DROP TABLE #CommentText
DROP TABLE #Syscom
GO
GRANT EXECUTE ON  [dbo].[dbasp_script_DBsprocs] TO [public]
GO
