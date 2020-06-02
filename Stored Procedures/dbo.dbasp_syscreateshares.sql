SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_syscreateshares]


/**************************************************************
 **  Stored Procedure dbasp_syscreateshares
 **  Written by Steve Ledridge, Virtuoso
 **  September 16, 2003
 **
 **  This dbasp is set up to help recreate shares.  The output
 **  from this process is executable code that will recreate the
 **  shares as they existed when the script was run.
 **
 **  Output member is SYScreateshares.gsql
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	09/08/2003	Steve Ledridge		New sproc
--	12/22/2003	Steve Ledridge		Change for short share names
--	08/16/2006	Steve Ledridge		Updated for SQL 2005
--	05/27/2008	Steve Ledridge		Fix servername with instance in the output.
--	11/03/2008	Steve Ledridge		Coverted to dynamic servername within the output script.
--	11/04/2008	Steve Ledridge		Added ode for clustered shares.
--	04/26/2013	Steve Ledridge		Chaned net share to net view.
--	======================================================================================


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd				nvarchar(4000)
	,@charpos			int
	,@save_sharepath		sysname
	,@perm_flag01			char(1)
	,@spcl_access_flag		char(1)
	,@first_flag			char(1)
	,@hold_user			sysname
	,@save_user			sysname
	,@save_user2			sysname
	,@save_perm			sysname
	,@save_perm_small		char(1)
	,@save_security_level		char(1)
	,@hold_parm			sysname
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_domain			sysname


DECLARE
	 @cu12path			nvarchar(500)


DECLARE
	 @cu14sharename			sysname


DECLARE
	 @cu16path			nvarchar(500)


DECLARE
	 @cu18path			nvarchar(500)


DECLARE
	 @cu26path			nvarchar(500)


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = 'domain')


--  Creat temp tables
Create table #ShareTempTable1(path nvarchar(500) null)


Create table #ShareList(sharename sysname null)


Create table #ShareTempTable2(path nvarchar(500) null)


Create table #ShareTempTable3(path nvarchar(500) null)


----------------------  Main header  ----------------------
Print  '/**************************************************************'
Select @miscprint = 'Generated SQL - SYScreateshares'
Print  @miscprint
Select @miscprint = 'For Server: ' + @@servername + ' on '  + convert(varchar(30),getdate(),9)
Print  @miscprint
Print  '**************************************************************/'
Print  ' '


--  Develope a list of shares on the local server
Select @cmd = 'net view \\' + @save_servername


--print @cmd /* for debugging */
Insert into #ShareTempTable1
exec master.sys.xp_cmdshell @cmd
Delete from #ShareTempTable1 where path is null
Delete from #ShareTempTable1 where path like 'Shared resources%'
Delete from #ShareTempTable1 where path like 'Share name%'
Delete from #ShareTempTable1 where path like '---------%'
Delete from #ShareTempTable1 where path like 'The command%'
--select * from #ShareTempTable1 /* for debugging */


--  cursor for the share temp table results - list of local shares
EXECUTE('DECLARE cu12_cursor Insensitive Cursor For ' +
  'SELECT p.path
   From #ShareTempTable1   p ' +
  'Order by p.path for Read Only')

OPEN cu12_cursor

WHILE (12=12)
 Begin
	FETCH Next From cu12_cursor Into @cu12path
	IF (@@fetch_status < 0)
           begin
              CLOSE cu12_cursor
	      BREAK
           end


	If left(@cu12path, 2) not in ('  ', '--') and left(@cu12path, 11) not in ('Share name ', 'The command')
	   begin
		select @charpos = charindex('  ', @cu12path)
		IF @charpos <> 0
		   begin
			select @cu12path = rtrim(substring(@cu12path, 1, @charpos-1))
		   end


		select @charpos = charindex(':\', @cu12path)
		IF @charpos <> 0
		   begin
			select @cu12path = rtrim(substring(@cu12path, 1, @charpos-2))
		   end


		If @cu12path not like '%$'
		   begin
			Insert into #ShareList (sharename) Values (@cu12path)
		   end
	   end


 End  -- loop 12
DEALLOCATE cu12_cursor


--select * from #ShareList /* for debugging */


--  Process each share one at a time, getting information via RMTSHARE and creating the output script
EXECUTE('DECLARE cu14_cursor Insensitive Cursor For ' +
  'SELECT s.sharename
   From #ShareList   s ' +
  'Order by s.sharename for Read Only')

OPEN cu14_cursor

WHILE (14=14)
 Begin
	FETCH Next From cu14_cursor Into @cu14sharename
	IF (@@fetch_status < 0)
           begin
              CLOSE cu14_cursor
	      BREAK
           end


	--  Get information about this share using RMTSHARE
	Select @cmd = 'RMTSHARE \\' + @save_servername + '\' + @cu14sharename
	--print @cmd /* for debugging */
	Insert into #ShareTempTable2
	exec master.sys.xp_cmdshell @cmd


	--  parse the drive letter path to the share and verify the path exists
	select @save_sharepath = ltrim(substring(path, 5, 100)) from #ShareTempTable2 where left(path, 4) = 'Path'


	--Select * from #ShareTempTable2 /* for debugging */
	--Print @cu14sharename
	--Print @save_sharepath


	Print  ' '
	Print  '--  **************************************************************************************'
	Print  '--  Create Share ''' + @cu14sharename + ''''
	Print  '--  **************************************************************************************'


	If @cu14sharename like '%' + @save_servername + '%'
	    and (@cu14sharename like '%dba_mail%'
		or @cu14sharename like '%builds%'
		or @cu14sharename like '%Central_Archive%'
		or @cu14sharename like '%filescan%'
		or @cu14sharename like '%SQL_Register%'
		or @cu14sharename like '%SQLPerfReports%'
		or @cu14sharename like '%restore%')
	   begin
		Select @cu14sharename = replace(@cu14sharename, @save_servername, ''' + @save_servername + ''')
	   end


	If @cu14sharename like '%' + @save_servername2 + '%'
	   begin
		Select @cu14sharename = replace(@cu14sharename, @save_servername2, ''' + @save_servername2 + ''')
	   end


	Select @miscprint = 'Set nocount on'
	Print  @miscprint
	Select @miscprint = 'Declare @share_path sysname'
	Print  @miscprint
	Select @miscprint = '       ,@cmd nvarchar(4000)'
	Print  @miscprint
	Select @miscprint = '       ,@charpos int'
	Print  @miscprint
	Select @miscprint = '       ,@save_servername sysname'
	Print  @miscprint
	Select @miscprint = '       ,@save_servername2 sysname'
	Print  @miscprint
	Select @miscprint = '       ,@save_drive_letter_part char(2)'
	Print  @miscprint
	Select @miscprint = '       ,@save_data2 nvarchar(4000)'
	Print  @miscprint
	Select @miscprint = '       ,@save_disk_resname sysname'
	Print  @miscprint
	Select @miscprint = '       ,@save_group_resname sysname'
	Print  @miscprint
	Select @miscprint = '       ,@save_network_resname sysname'
	Print  @miscprint
	Select @miscprint = '       ,@save_domain sysname'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'Select @share_path = ''' + @save_sharepath + ''''
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'Create table #cluster_info2 (data2 nvarchar(4000))'
	Print  @miscprint
	Select @miscprint = 'Create table #fileexists (doesexist smallint, fileindir smallint, direxist smallint)'
	Print  @miscprint
	Select @miscprint = 'Insert into #fileexists exec master.sys.xp_fileexist @share_path'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'If (SERVERPROPERTY(''IsClustered'')) = 1'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '	Select @save_domain = (select env_detail from DBAOps.dbo.Local_ServerEnviro where env_type = ''domain'')'
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''cluster . res /status'''
	Print  @miscprint
	Select @miscprint = '	Insert into #cluster_info2 exec master.sys.xp_cmdshell @cmd'
	Print  @miscprint
	Select @miscprint = '	delete from #cluster_info2 where data2 is null'
	Print  @miscprint
	Select @miscprint = '	delete from #cluster_info2 where rtrim(data2) = '''''
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'Select @save_servername = @@servername'
	Print  @miscprint
	Select @miscprint = 'Select @save_servername2 = @@servername'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'Select @charpos = charindex(''\'', @save_servername)'
	Print  @miscprint
	Select @miscprint = 'IF @charpos <> 0'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '	Select @save_servername = substring(@@servername, 1, (CHARINDEX(''\'', @@servername)-1))'
	Print  @miscprint
	Select @miscprint = '	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, ''$'')'
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Print  ' '


	Select @miscprint = 'If (select fileindir from #fileexists) = 0'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = '	Print ''ERROR: Share "' + @cu14sharename + '" will not be created.'''
	Print  @miscprint
	Select @miscprint = '	Print ''       Path "'' + @share_path + ''" could not be found.'''
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = '   end'
	Print  @miscprint
	Select @miscprint = 'Else If (SERVERPROPERTY(''IsClustered'')) = 0'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''rmtshare \\'' + @save_servername + ''\' + @cu14sharename + ' = "'' + @share_path + ''" /unlimited'''
	Print  @miscprint
	Select @miscprint = '	Print ''Creating the "' + @cu14sharename + '" share using command: '' + @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''rmtshare \\'' + @save_servername + ''\' + @cu14sharename + ' /grant administrators:f'''
	Print  @miscprint
	Select @miscprint = '	Print ''Assign FULL Permissions, Local administrators to the "' + @cu14sharename + '" share using command: '' + @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''rmtshare \\'' + @save_servername + ''\' + @cu14sharename + ' /Remove everyone'''
	Print  @miscprint
	Select @miscprint = '	Print ''Remove Share permissions for "Everyone" from the "' + @cu14sharename + '" share using command: '' + @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint


	Select @perm_flag01 = 'n'
	Select @hold_user = ' '


	--  Get the share permissions
	EXECUTE('DECLARE cu16_cursor Insensitive Cursor For ' +
	  'SELECT t.path
	   From #ShareTempTable2   t ' +
	  'for Read Only')

	OPEN cu16_cursor

	WHILE (16=16)
	 Begin
		FETCH Next From cu16_cursor Into @cu16path
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu16_cursor
		      BREAK
	           end


		If @perm_flag01 = 'y' and @cu16path is not null
		   begin
			Select @charpos = charindex(':', @cu16path)
			IF @charpos <> 0
			   begin
				Select @save_user = ltrim(substring(@cu16path, 1, @charpos-1))
				Select @save_perm = ltrim(substring(@cu16path, @charpos+1, 20))


				If rtrim(@save_user) <> rtrim(@hold_user)
				   and @save_user <> 'BUILTIN\Administrators'
				   begin
					If rtrim(@save_perm) = 'FULL CONTROL'
					   begin
						Select @save_perm_small = 'f'
					   end
					Else  If rtrim(@save_perm) = 'CHANGE'
					   begin
						Select @save_perm_small = 'c'
					   end
					Else
					   begin
						Select @save_perm_small = 'r'
					   end
					If left(@save_user, 1) = '\'
					   begin
						Select @save_user = substring(@save_user, 2, len(@save_user)-1)
					   end


					If @save_user like '%\' + @save_servername2 + '%'
					   begin
						Select @save_user = replace(@save_user, @save_servername2, ''' + @save_servername2 + ''')
					   end


					If @save_user like '%' + @save_servername + '%'
					   begin
						Select @save_user = replace(@save_user, @save_servername, ''' + @save_servername + ''')
					   end


					--  Create the script for share permissions
					Select @miscprint = ' '
					Print  @miscprint
					Select @miscprint = '	Select @cmd = ''rmtshare \\'' + @save_servername + ''\' + @cu14sharename + ' /grant "' + rtrim(@save_user) + '":' + @save_perm_small + ''''
					Print  @miscprint
					Select @miscprint = '	Print ''Assign ' + @save_perm + ' Permissions: "' + rtrim(@save_user) + '" to the "' + @cu14sharename + '" share using command: ''+ @cmd'
					Print  @miscprint
					Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
					Print  @miscprint
					Select @miscprint = '	Print '' '''
					Print  @miscprint


				   end


			   end


		   end
		Else If @cu16path is null
		   begin
			Select @perm_flag01 = 'n'
		   end


		--  The rows after the permissions header are what we need.  This sets a flag
		--  telling the program we are there.
		If left(@cu16path, 11) = 'Permissions'
		   begin
			Select @perm_flag01 = 'y'
		   end


	 End  -- loop 16
	DEALLOCATE cu16_cursor


	--  Get information about this share using XCACLS
	Select @cmd = 'XCACLS "' + @save_sharepath + '"' /* double quotes are used in case folder names have spaces */
	--print @cmd /* for debugging */
	Insert into #ShareTempTable3
	exec master.sys.xp_cmdshell @cmd


	--Select * from #ShareTempTable3 /* for debugging */


	Select @hold_user = ' '
	Select @hold_parm = '/G'
	Select @spcl_access_flag = 'n'
	Select @first_flag = 'y'


	--  Get the share security info
	EXECUTE('DECLARE cu18_cursor Insensitive Cursor For ' +
	  'SELECT s.path
	   From #ShareTempTable3   s ' +
	  'for Read Only')

	OPEN cu18_cursor

	WHILE (18=18)
	 Begin
		FETCH Next From cu18_cursor Into @cu18path
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu18_cursor
		      BREAK
	           end


		If @cu18path is not null


/***
C:\share_test BUILTIN\Administrators:(OI)(CI)R
              AMER\dmarsten:(CI)R
              AMER\dmarsten:(OI)(CI)(special access:)


                                    SYNCHRONIZE
                                    FILE_EXECUTE

              AMER\jwilson:(OI)(CI)C
              NT AUTHORITY\SYSTEM:(OI)(CI)F
***/


		   begin
			Select @charpos = charindex('special access:', @cu18path)
			IF @charpos <> 0
			   begin
				Select @spcl_access_flag = 'y'
			   end
			Else
			   begin
				Select @save_security_level = right(rtrim(@cu18path), 1)
			   end


			If @cu18path = ' ' and @spcl_access_flag = 'y'
			   begin
				Select @spcl_access_flag = 'n'
				Select @miscprint = '	Print '' '''
				Print  @miscprint
				goto label45
			   end


			Select @charpos = charindex(@save_sharepath, @cu18path)
			IF @charpos <> 0
			   begin
				Select @cu18path = ltrim(substring(@cu18path, len(@save_sharepath)+1, 200))
			   end


			Select @cu18path = ltrim(rtrim(@cu18path))


			Select @charpos = charindex(':', @cu18path)
			IF @charpos <> 0
			   begin
				Select @cu18path = left(@cu18path, @charpos-1)
			   end


			IF left(@cu18path, 8) = 'BUILTIN\'
			   begin
				Select @cu18path = Right(@cu18path, len(@cu18path)-8)
			   end


			If @spcl_access_flag = 'y'
			   begin
				Select @miscprint = ' '
				Print  @miscprint
				If @first_flag = 'y'
				   begin
					Select @miscprint = '	Print ''Unable to Assign Special Access NTFS Permissions for "' + @cu18path + '".'''
					Print  @miscprint
					Select @hold_user = @cu18path
					Select @first_flag = 'n'
				   end
				Else
				   begin
					Select @miscprint = '	Print ''Unable to Assign Special Access NTFS Permissions for "' + @hold_user + '", "' + @cu18path + '".'''
					Print  @miscprint
				   end
			   end
			Else If @hold_user <> @cu18path
			   begin
				Select @save_user2 = @cu18path
				If @save_user2 like '%\' + @save_servername2 + '%'
				   begin
					Select @save_user2 = replace(@cu18path, @save_servername2, ''' + @save_servername2 + ''')
				   end


				If @save_user2 like '%' + @save_servername + '%'
				   begin
					Select @save_user2 = replace(@save_user2, @save_servername, ''' + @save_servername + ''')
				   end


				Select @miscprint = ' '
				Print  @miscprint
				Select @miscprint = '	Select @cmd = ''XCACLS "'' + @share_path + ''" ' + @hold_parm + ' "' + @save_user2 + '":' + @save_security_level + ' /Y'''
				Print  @miscprint
				Select @miscprint = '	Print ''Assign NTFS Permissions, "' + @save_user2 + '" to the path "'' + @share_path + ''" using command: '' + @cmd'
				Print  @miscprint
				Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
				Print  @miscprint
				Select @miscprint = '	Print '' '''
				Print  @miscprint
			   end


			If @spcl_access_flag = 'n'
			   begin
				Select @hold_user = @cu18path
				Select @hold_parm = '/E /G'
			   end


			label45:


		   end


	 End  -- loop 18
	DEALLOCATE cu18_cursor


	Select @miscprint = '   end'
	Print  @miscprint


	--  Start process for clustered shares
	Select @miscprint = 'Else If (SERVERPROPERTY(''IsClustered'')) = 1'
	Print  @miscprint
	Select @miscprint = '   begin'
	Print  @miscprint

	--  If any standard shares are found, delete them (we will recreate them)
	Select @miscprint = '	--  Delete the share before we re-create it'
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''cluster . res ' + @cu14sharename + ' /off'''
	Print  @miscprint
	Select @miscprint = '	Print ''Take the File Share Resource "' + @cu14sharename + '" offline using command: '' + @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''cluster . res ' + @cu14sharename + ' /delete'''
	Print  @miscprint
	Select @miscprint = '	Print ''Deleting the File Share Resource "' + @cu14sharename + '" using command: '' + @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	--  Get selected cluster info (disk)
	Select @miscprint = '	--  Get selected cluster info (disk)'
	Print  @miscprint
	Select @miscprint = '	Select @save_drive_letter_part = substring(@share_path, 1,2)'
	Print  @miscprint
	Select @miscprint = '	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like ''%'' + @save_drive_letter_part + ''%'')'
	Print  @miscprint
	Select @miscprint = '	Select @save_disk_resname = @save_data2'
	Print  @miscprint
	Select @miscprint = '	Select @charpos = charindex(''   '', @save_data2)'
	Print  @miscprint
	Select @miscprint = '	If @charpos > 0'
	Print  @miscprint
	Select @miscprint = '	   begin'
	Print  @miscprint
	Select @miscprint = '		Select @save_disk_resname = left(@save_data2, @charpos-1)'
	Print  @miscprint
	Select @miscprint = '		Select @save_group_resname = substring(@save_data2, @charpos, 200)'
	Print  @miscprint
	Select @miscprint = '		Select @save_group_resname = ltrim(@save_group_resname)'
	Print  @miscprint
	Select @miscprint = '		Select @charpos = charindex(''   '', @save_group_resname)'
	Print  @miscprint
	Select @miscprint = '		If @charpos > 0'
	Print  @miscprint
	Select @miscprint = '		   begin'
	Print  @miscprint
	Select @miscprint = '			Select @save_group_resname = left(@save_group_resname, @charpos-1)'
	Print  @miscprint
	Select @miscprint = '		   end'
	Print  @miscprint
	Select @miscprint = '	   end'
	Print  @miscprint
	Select @miscprint = '	Else'
	Print  @miscprint
	Select @miscprint = '	   begin'
	Print  @miscprint
	Select @miscprint = '		Print ''Unable to find the cluster resource for the disk '' + @save_drive_letter_part + ''\.  Skipping create share process for ' + @cu14sharename + '.'''
	Print  @miscprint
	Select @miscprint = '		goto skip_create_share'
	Print  @miscprint
	Select @miscprint = '	   end'
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	--  Get selected cluster info (network)
	Select @miscprint = '	--  Get selected cluster info (network)'
	Print  @miscprint
	Select @miscprint = '	Select @save_data2 = (select top 1 data2 from #cluster_info2 where data2 like ''%network%'' and data2 like ''%'' + @save_group_resname + '' %'')'
	Print  @miscprint
	Select @miscprint = '	Select @save_network_resname = @save_data2'
	Print  @miscprint
	Select @miscprint = '	Select @charpos = charindex(@save_group_resname + '' '', @save_network_resname)'
	Print  @miscprint
	Select @miscprint = '	If @charpos > 0'
	Print  @miscprint
	Select @miscprint = '	   begin'
	Print  @miscprint
	Select @miscprint = '		Select @save_network_resname = left(@save_network_resname, @charpos-1)'
	Print  @miscprint
	Select @miscprint = '		Select @save_network_resname = rtrim(@save_network_resname)'
	Print  @miscprint
	Select @miscprint = '	   end'
	Print  @miscprint
	Select @miscprint = '	Else'
	Print  @miscprint
	Select @miscprint = '	   begin'
	Print  @miscprint
	Select @miscprint = '		Print ''Unable to find the cluster network resource for the group '' + @save_group_resname + ''.  Skipping create share process for ' + @cu14sharename + '.'''
	Print  @miscprint
	Select @miscprint = '		goto skip_create_share'
	Print  @miscprint
	Select @miscprint = '	   end'
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	--  Create the share, and share security
	Select @miscprint = '	--  Create the share, and share security'
	Print  @miscprint
	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /Create /Group:"'' + @save_group_resname + ''" /Type:"File Share"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Create the File Share Resource in the cluster group ['' + @save_group_resname + ''] using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv Path="'' + @share_path + ''"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share Path using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv ShareName=' + @cu14sharename + ''''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share ShareName using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint

	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv Remark="DBA File Share"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share Remark using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /prop Description="DBA Clustered Share"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share Description using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /AddDep:"'' + @save_disk_resname + ''"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share dependency using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /AddDep:"'' + @save_network_resname + ''"'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share dependency using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /On'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share OnLine using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv security="' + @save_domain + '\Domain Admins",grant,f:security'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share permissions using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @miscprint = '	Select @cmd = ''XCACLS '' + @share_path + '' /E /G "' + @save_domain + '\Domain Admins":F /Y'''
	Print  @miscprint
	Select @miscprint = '	Print ''Assign FULL NTFS Permissions using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint

	Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv security=everyone,revoke:security'''
	Print  @miscprint
	Select @miscprint = '	Print ''Set the File Share permissions using command: ''+ @cmd'
	Print  @miscprint
	Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
	Print  @miscprint
	Select @miscprint = '	Print '' '''
	Print  @miscprint
	Select @miscprint = ' '
	Print  @miscprint


	Select @perm_flag01 = 'n'
	Select @hold_user = ' '


	--  Get the share permissions
	EXECUTE('DECLARE cu26_cursor Insensitive Cursor For ' +
	  'SELECT t.path
	   From #ShareTempTable2   t ' +
	  'for Read Only')

	OPEN cu26_cursor

	WHILE (26=26)
	 Begin
		FETCH Next From cu26_cursor Into @cu26path
		IF (@@fetch_status < 0)
	           begin
	              CLOSE cu26_cursor
		      BREAK
	           end


		If @perm_flag01 = 'y' and @cu26path is not null
		   begin
			Select @charpos = charindex(':', @cu26path)
			IF @charpos <> 0
			   begin
				Select @save_user = ltrim(substring(@cu26path, 1, @charpos-1))
				Select @save_perm = ltrim(substring(@cu26path, @charpos+1, 20))


				If rtrim(@save_user) <> rtrim(@hold_user)
				   and @save_user <> 'BUILTIN\Administrators'
				   and @save_user not like '%Domain Admins%'


				   begin
					If rtrim(@save_perm) = 'FULL CONTROL'
					   begin
						Select @save_perm_small = 'F'
					   end
					Else  If rtrim(@save_perm) = 'CHANGE'
					   begin
						Select @save_perm_small = 'C'
					   end
					Else
					   begin
						Select @save_perm_small = 'R'
					   end
					If left(@save_user, 1) = '\'
					   begin
						Select @save_user = substring(@save_user, 2, len(@save_user)-1)
					   end


					If @save_user like '%\' + @save_servername2 + '%'
					   begin
						Select @save_user = replace(@save_user, @save_servername2, ''' + @save_servername2 + ''')
					   end


					If @save_user like '%' + @save_servername + '%'
					   begin
						Select @save_user = replace(@save_user, @save_servername, ''' + @save_servername + ''')
					   end


					--  Create the script for share permissions
					Select @miscprint = '	Select @cmd = ''cluster . res "' + @cu14sharename + '" /priv security="' + rtrim(@save_user) + '",grant,' + @save_perm_small + ':security'''
					Print  @miscprint
					Select @miscprint = '	Print ''Assign ' + @save_perm + ' Permissions: "' + rtrim(@save_user) + '" to the "' + @cu14sharename + '" share using command: ''+ @cmd'
					Print  @miscprint
					Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
					Print  @miscprint
					Select @miscprint = '	Print '' '''
					Print  @miscprint
					Select @miscprint = ' '
					Print  @miscprint


					Select @miscprint = '	Select @cmd = ''XCACLS '' + @share_path + '' /E /G "' + @save_user + '":' + @save_perm_small + ' /Y'''
					Print  @miscprint
					Select @miscprint = '	Print ''Assign XCACLS ' + @save_perm + ' Permissions: "' + rtrim(@save_user) + '" to the "' + @cu14sharename + '" share using command: ''+ @cmd'
					Print  @miscprint
					Select @miscprint = '	EXEC master.sys.xp_cmdshell @cmd, no_output'
					Print  @miscprint
					Select @miscprint = '	Print '' '''
					Print  @miscprint
					Select @miscprint = ' '
					Print  @miscprint
				   end
			   end
		   end
		Else If @cu26path is null
		   begin
			Select @perm_flag01 = 'n'
		   end


		--  The rows after the permissions header are what we need.  This sets a flag
		--  telling the program we are there.
		If left(@cu26path, 11) = 'Permissions'
		   begin
			Select @perm_flag01 = 'y'
		   end


	 End  -- loop 26
	DEALLOCATE cu26_cursor


	Select @miscprint = '   end'
	Print  @miscprint


	Print  ' '
	Select @miscprint = 'skip_create_share:'
	Print  @miscprint
	Select @miscprint = 'Print '' '''
	Print  @miscprint
	Select @miscprint = 'Print '' '''
	Print  @miscprint
	Print  ' '
	Select @miscprint = 'Drop table #fileexists'
	Print  @miscprint
	Select @miscprint = 'Drop table #cluster_info2'
	Print  @miscprint
	Print  'go '
	Print  ' '
	Print  ' '
	Print  ' '
	Print  ' '


	delete from #ShareTempTable1
	delete from #ShareTempTable3


 End  -- loop 14
DEALLOCATE cu14_cursor


--  fyi, security related info (xcacls)
/***
OUTPUT    		ACE Applies To
OI 			- This folder and files
CI 			- This folder and subfolders
IO 			- The ACE does not apply to the current file/directory.
No output message 	- This folder only
(IO)(CI) 		- This folder, subfolders and files
(OI)(CI)(IO) 		- Subfolders and files only
(CI)(IO) 		- Subfolders only
(OI)(IO) 		- Files only
***/


----------------  End  -------------------


drop table #ShareTempTable1


drop table #ShareList


drop table #ShareTempTable2


drop table #ShareTempTable3
GO
GRANT EXECUTE ON  [dbo].[dbasp_syscreateshares] TO [public]
GO
