SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSsetDBoptions]


/*********************************************************
 **  Stored Procedure dbasp_SYSsetDBoptions
 **  Written by Steve Ledridge, Virtuoso
 **  October 10, 2000
 **
 **  This dbasp is set up to create executable sql to;
 **
 **  Set DB Options
 **
 **  Output member is SYSsetDBoptions.gsql
 ***************************************************************/
  as


set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	====================	=============================================
--	02/27/2002	Steve Ledridge		Added a 'select into' temp table for all options
--						currently true.  Then I added the 'If In' clause
--						to the three If statments that determine if an
--						option should be true or false.
--	06/12/2002	Steve Ledridge		Added DB compatibility level command and added
--						formatting for DB option cmds.
--	06/21/2002	Steve Ledridge		Removed bracket formatting for database name.
--	02/04/2003	Steve Ledridge		Uncommented db chaining commands.
--	03/03/2006	Steve Ledridge		Modified for sql 2005.
--	04/05/2012	Steve Ledridge		New code for enable_broker.
--	08/09/2012	Steve Ledridge		New code for page verify.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			nvarchar(255)
	,@cmd				nvarchar(2000)
	,@optvalue			nvarchar(5)
	,@CommentThisDBOption		char(1)
	,@recovery_flag			char(1)
	,@restrict_flag			char(1)
	,@fulloptname			sysname
	,@alt_optname			sysname
	,@alt_optvalue			sysname
	,@exec_stmt			nvarchar(2000)
	,@catvalue			int


DECLARE
	 @allstatopts		int
	,@alloptopts		int
	,@allcatopts		int


DECLARE
	 @cu11DBname		sysname
	,@cu11DBid		int
	,@cu11DBcmptlevel	tinyint


----------------  initial values  -------------------


--  Create table variable
declare @dbnames table
			(name		sysname
			,dbid		smallint
			,cmptlevel	smallint
			)


declare @tblvar_spt_values table
			(name			sysname
			,process_flag	char(1)
			)


declare @temp_options table (name		sysname)


declare @repl_options table (output		nvarchar(1000))


/*
** Get bitmap of all options that can be set by sp_dboption.
*/
select @allstatopts=number from master.dbo.spt_values where type = 'D'
   and name = 'ALL SETTABLE OPTIONS'


select @allcatopts=number from master.dbo.spt_values where type = 'DC'
   and name = 'ALL SETTABLE OPTIONS'


select @alloptopts=number from master.dbo.spt_values where type = 'D2'
   and name = 'ALL SETTABLE OPTIONS'


--  Load the temp table for spt_values
Select @cmd = 'select name
			from master.dbo.spt_values
			where (type = ''D''
				and number & ' + convert(varchar(10), @allstatopts) + ' <> 0
				and number not in (0,' + convert(varchar(10), @allstatopts) + '))	-- Eliminate non-option entries
			 or (type = ''DC''
				and number & ' + convert(varchar(10), @allcatopts) + ' <> 0
				and number not in (0,' + convert(varchar(10), @allcatopts) + '))
			 or (type = ''D2''
				and number & ' + convert(varchar(10), @alloptopts) + ' <> 0
				and number not in (0,' + convert(varchar(10), @alloptopts) + '))
			order by name'


delete from @tblvar_spt_values


insert into @tblvar_spt_values (name) exec (@cmd)


delete from @tblvar_spt_values where name is null or name = ''
--select * from @tblvar_spt_values


/*********************************************************************
 *                Initialization
 ********************************************************************/


----------------------  Main header  ----------------------


Print  ' '
Print  '/*******************************************************************'
Select @miscprint = 'Generated SQL - SYSsetdboptions'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


/****************************************************************
 *                MainLine
 ***************************************************************/


Select @cmd = 'SELECT d.name, d.dbid, d.cmptlevel
   From master.sys.sysdatabases   d ' +
  'Where d.name not in (''master'', ''model'', ''msdb'', ''tempdb'')'


delete from @DBnames


insert into @DBnames (name, dbid, cmptlevel) exec (@cmd)


delete from @DBnames where name is null or name = ''
--select * from @DBnames


If (select count(*) from @DBnames) > 0
   begin
	start_dbnames:


	Select @cu11DBId = (select top 1 dbid from @DBnames order by dbid)
	Select @cu11DBName = (select name from @DBnames where dbid = @cu11DBId)
	Select @cu11DBcmptlevel = (select cmptlevel from @DBnames where dbid = @cu11DBId)


	----------------------  Print the headers  ----------------------
	Print  '/*********************************************************'
	Select @miscprint = 'Set database options for database ' + @cu11DBName
	Print  @miscprint
	Print  '*********************************************************/'
	Print  ' '


	--  Print comatibility change command syntax  ----------------------
	Print  ' '
	Print  '/*** Setting Database Compatibility Level ***/'
	Print  ' '


	Select @miscprint = '/***'
	Print  @miscprint
	Select @miscprint = 'EXEC master.sys.sp_dbcmptlevel ''' + @cu11DBName + ''', ''' + convert(varchar(2), @cu11DBcmptlevel) + ''';'
	Print  @miscprint
	Select @miscprint = 'GO'
	Print  @miscprint
	Select @miscprint = '***/'
	Print  @miscprint
	Print  ' '
	Print  ' '


	Select @cmd = 'select v.name
	   from master.dbo.spt_values v, master.sys.sysdatabases d
		where d.name=''' + @cu11DBname + '''
		  and ((number & ' + convert(varchar(10), @allstatopts) + ' <> 0
			and number not in (-1,' + convert(varchar(10), @allstatopts) + ')
			and v.type = ''D''
			and (v.number & d.status)=v.number)
		   or (number & ' + convert(varchar(10), @allcatopts) + ' <> 0
			and number not in (-1,' + convert(varchar(10), @allcatopts) + ')
			and v.type = ''DC''
			and d.category & v.number <> 0)
		   or (number & ' + convert(varchar(10), @alloptopts) + ' <> 0
			and number not in (-1,' + convert(varchar(10), @alloptopts) + ')
			and v.type = ''D2''
			and d.status2 & v.number <> 0))'


	delete from @temp_options


	insert into @temp_options (name) exec (@cmd)


	delete from @temp_options where name is null or name = ''
	--select * from @temp_options


	--  Start the main process for this database
	If (select count(*) from @tblvar_spt_values) > 0
	   begin
		Update @tblvar_spt_values set process_flag = 'n'
		Select @recovery_flag = 'n'
		Select @restrict_flag = 'n'

		delete from @repl_options

		start_mainloop:


		Select @fulloptname = (select top 1 name from @tblvar_spt_values where process_flag = 'n')


        IF (@fulloptname IN ('ANSI null default'
            			,'dbo use only'
            			,'no chkpt on recovery'
            			,'read only'
            			,'select into/bulkcopy'
            			,'single user'
            			,'trunc. log on chkpt.'))
		   begin
			Select @CommentThisDBOption = 'N'
		   end
		ELSE
		   begin
			Select @CommentThisDBOption = 'Y'
		   end


		If @fulloptname in (select name from @temp_options)
		   begin
			Select @optvalue = 'true'
		   end
		Else
		   begin
			Select @optvalue = 'false'
		   end


		select @catvalue = 0
		select @catvalue = number
		  from master.dbo.spt_values
		  where lower(name) = lower(@fulloptname)
		  and type = 'DC'


		-- if replication options, format using sproc sp_replicationdboption
		If (@catvalue <> 0)
		   begin
			select @alt_optvalue = (case lower(@optvalue)
					when 'true' then 'true'
					when 'on' then 'true'
					else 'false'
				end)


			select @alt_optname = (case @catvalue
					when 1 then 'publish'
					when 2 then 'subscribe'
					when 4 then 'merge publish'
					else quotename(@fulloptname, '''')
				end)


			select @exec_stmt = quotename(@cu11DBName, '[')   + '.dbo.sp_replicationdboption'
			--print @exec_stmt


			select @cmd = 'EXEC ' + @exec_stmt + ' ' +  @cu11DBName + ', ' + @alt_optname + ', ' + @alt_optvalue
			Insert into @repl_options values (@cmd)

			goto get_next
		   end


		-- set option value in alter database
		select @alt_optvalue = (case lower(@optvalue)
				when 'true'	then 'ON'
				when 'on'	then 'ON'
				else 'OFF'
				end)


		-- set option name in alter database
		select @fulloptname = lower(@fulloptname)
		select @alt_optname = (case @fulloptname
				when 'auto create statistics' then 'AUTO_CREATE_STATISTICS'
				when 'auto update statistics' then 'AUTO_UPDATE_STATISTICS'
				when 'autoclose' then 'AUTO_CLOSE'
				when 'autoshrink' then 'AUTO_SHRINK'
				when 'ansi padding' then 'ANSI_PADDING'
				when 'arithabort' then 'ARITHABORT'
				when 'numeric roundabort' then 'NUMERIC_ROUNDABORT'
				when 'ansi null default' then 'ANSI_NULL_DEFAULT'
				when 'ansi nulls' then 'ANSI_NULLS'
				when 'ansi warnings' then 'ANSI_WARNINGS'
				when 'concat null yields null' then 'CONCAT_NULL_YIELDS_NULL'
				when 'cursor close on commit' then 'CURSOR_CLOSE_ON_COMMIT'
				when 'torn page detection' then 'TORN_PAGE_DETECTION'
				when 'quoted identifier' then 'QUOTED_IDENTIFIER'
				when 'recursive triggers' then 'RECURSIVE_TRIGGERS'
				when 'default to local cursor' then 'CURSOR_DEFAULT'
				when 'offline' then (case @alt_optvalue when 'ON' then 'OFFLINE' else 'ONLINE' end)
				when 'read only' then (case @alt_optvalue when 'ON' then 'READ_ONLY' else 'READ_WRITE' end)
				when 'dbo use only' then (case @alt_optvalue when 'ON' then 'RESTRICTED_USER' else 'MULTI_USER' end)
				when 'single user' then (case @alt_optvalue when 'ON' then 'SINGLE_USER' else 'MULTI_USER' end)
				when 'select into/bulkcopy' then 'RECOVERY'
				when 'trunc. log on chkpt.' then 'RECOVERY'
				when 'db chaining' then 'DB_CHAINING'
				else @alt_optname
				end)


		select @alt_optvalue = (case @fulloptname
				when 'default to local cursor' then (case @alt_optvalue when 'ON' then 'LOCAL' else 'GLOBAL' end)
				when 'offline' then ''
				when 'read only' then ''
				when 'dbo use only' then ''
				when 'single user' then ''
				else  @alt_optvalue
				end)


		--  Special set up for recovery option
		if lower(@fulloptname) = 'select into/bulkcopy' and @recovery_flag = 'n'
		   begin
			if @alt_optvalue = 'ON'
			   begin
				if databaseproperty(@cu11DBName, 'IsTrunclog') = 1
				   begin
					select @alt_optvalue = 'RECMODEL_70BACKCOMP'
					Select @recovery_flag = 'y'
				   end
				else
				   begin
					select @alt_optvalue = 'BULK_LOGGED'
					Select @recovery_flag = 'y'
				   end
			   end
			else
			   begin
				if databaseproperty(@cu11DBName, 'IsTrunclog') = 1
				   begin
					select @alt_optvalue = 'SIMPLE'
					Select @recovery_flag = 'y'
				   end
				else
				   begin
					select @alt_optvalue = 'FULL'
					Select @recovery_flag = 'y'
				   end
			   end
		   end
		Else if lower(@fulloptname) = 'select into/bulkcopy' and @recovery_flag = 'y'
		   begin
			goto get_next
		   end


		if lower(@fulloptname) = 'trunc. log on chkpt.' and @recovery_flag = 'n'
		   begin
			if @alt_optvalue = 'ON'
			   begin
				if databaseproperty(@cu11DBName, 'IsBulkCopy') = 1
				   begin
					select @alt_optvalue = 'RECMODEL_70BACKCOMP'
					Select @recovery_flag = 'y'
				   end
				else
				   begin
					select @alt_optvalue = 'SIMPLE'
					Select @recovery_flag = 'y'
				   end
			   end
			else
			   begin
				if databaseproperty(@cu11DBName, 'IsBulkCopy') = 1
				   begin
					select @alt_optvalue = 'BULK_LOGGED'
					Select @recovery_flag = 'y'
				   end
				else
				   begin
					select @alt_optvalue = 'FULL'
					Select @recovery_flag = 'y'
				   end
			   end
		   end
		Else if lower(@fulloptname) = 'trunc. log on chkpt.' and @recovery_flag = 'y'
		   begin
			goto get_next
		   end


		--  Special set up for restrict option
		if lower(@fulloptname) = 'dbo use only' and @restrict_flag = 'n'
		   begin
			if databaseproperty(@cu11DBName, 'IsDboOnly') = 1
			   begin
				select @alt_optname = 'RESTRICTED_USER'
				Select @restrict_flag = 'y'
			   end
			Else If databaseproperty(@cu11DBName, 'IsSingleUser') = 1
			   begin
				select @alt_optname = 'SINGLE_USER'
				Select @restrict_flag = 'y'
			   end
			Else
			   begin
				select @alt_optname = 'MULTI_USER'
				Select @restrict_flag = 'y'
			   end
		   end
		Else if lower(@fulloptname) = 'dbo use only' and @restrict_flag = 'y'
		   begin
			goto get_next
		   end


		if lower(@fulloptname) = 'single user' and @restrict_flag = 'n'
		   begin
			if databaseproperty(@cu11DBName, 'IsDboOnly') = 1
			   begin
				select @alt_optname = 'RESTRICTED_USER'
				Select @restrict_flag = 'y'
			   end
			Else If databaseproperty(@cu11DBName, 'IsSingleUser') = 1
			   begin
				select @alt_optname = 'SINGLE_USER'
				Select @restrict_flag = 'y'
			   end
			Else
			   begin
				select @alt_optname = 'MULTI_USER'
				Select @restrict_flag = 'y'
			   end
		   end
		Else if lower(@fulloptname) = 'single user' and @restrict_flag = 'y'
		   begin
			goto get_next
		   end


		-- construct the ALTER DATABASE command string
		IF (@CommentThisDBOption = 'Y')
		   begin
			Raiserror('%s%s',0,1,'/','***')
		   end


		select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET ' + @alt_optname + ' ' + @alt_optvalue + ' WITH NO_WAIT'
		print @exec_stmt


		IF (@CommentThisDBOption = 'Y')
		   begin
			Raiserror('%s%s',0,1,'***','/')
		   end


		print ' '


		get_next:


		--  Check for more rows to process
		Update @tblvar_spt_values set process_flag = 'y' where name = @fulloptname
		If (select count(*) from @tblvar_spt_values where process_flag = 'n') > 0
		   begin
			goto start_mainloop
		  end


	   end


	--  Print out the replication options here
	If (select count(*) from @repl_options) > 0
	   begin
		start_repl_options:


		Select @miscprint = (select top 1 output from @repl_options)
		Raiserror('%s%s',0,1,'/','***')
		Print @miscprint
		Raiserror('%s%s',0,1,'***','/')
		Print ' '
	   end


	--  Check for more rows to process
	Delete from @repl_options where output = @miscprint
	If (select count(*) from @repl_options) > 0
	   begin
		goto start_repl_options
	  end


	--  Service broker
	If exists (select 1 from master.sys.databases where name = @cu11DBName and is_broker_enabled = 1)
	   begin
		select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET enable_broker WITH ROLLBACK IMMEDIATE'
		print @exec_stmt
		Print ' '
	   end


	--  Page Verify
	If exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 1)
	   begin
		select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET PAGE_VERIFY TORN_PAGE_DETECTION WITH ROLLBACK IMMEDIATE'
		print @exec_stmt
		Print ' '
	   end
	Else If exists (select 1 from master.sys.databases where name = @cu11DBName and page_verify_option = 2)
	   begin
		select @exec_stmt = 'ALTER DATABASE ' + quotename(@cu11DBName) + ' SET PAGE_VERIFY CHECKSUM WITH ROLLBACK IMMEDIATE'
		print @exec_stmt
		Print ' '
	   end


	--  Check for more rows to process
	Delete from @DBnames where dbid = @cu11DBId
	If (select count(*) from @DBnames) > 0
	   begin
		goto start_dbnames
	  end


   end


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSsetDBoptions] TO [public]
GO
