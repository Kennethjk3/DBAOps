SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_dbamail_process] (@server_name sysname = null
					   ,@save_SQLEnv sysname = '')


/**************************************************************
 **  Stored Procedure dbasp_dbamail_process
 **  Written by Steve Ledridge, Virtuoso
 **  March 10, 2002
 **
 **  This dbasp is set up to process sql mail requests using
 **  the DBAmail process in SQL 2005.
 ***************************************************************/
  as
  SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/10/2004	Steve Ledridge		New SQLMail process w/o Exchange.
--	03/29/2004	Steve Ledridge		Added 5 second wait between emails.
--	04/07/2004	Steve Ledridge		New server in staging.
--	01/05/2005	Steve Ledridge		Added support for DBAOpser and seafresqldba01.
--	03/04/2005	Steve Ledridge		Added carriage return char(10) to end of each message line.
--	11/16/2005	Steve Ledridge		New code to handle additional features (priority, from, from_name, etc.)
--	11/28/2005	Steve Ledridge		Removed cursors.  Added check of file attachment using
--						DBAOps.dbo.dbaudf_CheckFileStatus.
--	05/04/2006	Steve Ledridge		Converted for SQL 2005.
--	08/11/2006	Steve Ledridge		Added code to update @type parm.
--	11/21/2006	Steve Ledridge		Added code to fix orphan single quotes in the message.
--	04/17/2007	Steve Ledridge		Added truncate on messages over len=3200.
--	04/19/2007	Steve Ledridge		New code for very long attachment strings
--	05/04/2007	Steve Ledridge		Added print of servername for error diag
--	02/04/2008	Steve Ledridge		Added input parm for servername
--	02/05/2008	Steve Ledridge		Removed xp_getfiledetails and replaced with xp_cmdshell DIR.
--	07/30/2008	Steve Ledridge		Added print of file name and path for error diag
--	08/27/2008	Steve Ledridge		New table dba_serverinfo.
--	09/19/2008	Steve Ledridge		Addd dynamic profile creation for @FROM values.
--	09/24/2008	Steve Ledridge		Addded retry on rename.
--	10/22/2008	Steve Ledridge		Addded @subject to output for error diag.
--	11/10/2008	Steve Ledridge		New check to ignore mutiple rows for most parms.
--	04/10/2009	Steve Ledridge		Added /B to DIR.
--	04/13/2009	Steve Ledridge		Modified file rename process.
--	03/12/2010	Steve Ledridge		New code for active = 'm'.
--	06/02/2010	Steve Ledridge		Changed seafrestgsql to fresdbasql01.
--	02/26/2013	Steve Ledridge		Modified Calls to functions supporting the replacement of OLE with CLR.
--	09/03/2013	Steve Ledridge		Changed fresdbasql01 to seasdbasql01.
--	======================================================================================


/*
declare @server_name sysname
declare @save_SQLEnv sysname


select @server_name = 'DBAOpser02'
select @save_SQLEnv = ''
--*/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(4000)
	,@cmd 				nvarchar(4000)
	,@filename_wild			nvarchar(100)
	,@startpos			int
	,@charpos			bigint
	,@charpos2			bigint
	,@start_charpos			bigint
	,@length			int
	,@EOLWinNT 			nvarchar(2)
	,@message_flag			char(1)
	,@attach_continue		char(1)
	,@attach_fail_flag		char(1)
	,@last_char_test		char(1)
	,@retcode			int
	,@retry 			smallint
	,@parm_recipients		nvarchar(500)
	,@parm_copy_recipients 		nvarchar(500)
	,@parm_blind_copy_recipients	nvarchar(500)
	,@parm_attach			nvarchar(4000)
	,@parm_subject			nvarchar(255)
	,@parm_message			nvarchar(max)
	,@parm_priority			nvarchar(10)
	,@parm_type			nvarchar(100)
	,@save_cmdoutput2		nvarchar(255)
	,@save_parm_attach		nvarchar(4000)
	,@save_parm_attach_result	nvarchar(4000)
	,@save_parm_attach_single	nvarchar(4000)
	,@save_parm_attach_len		int
	,@save_mailshare		nvarchar(200)
	,@save_profile_name		sysname
	,@save_date			nvarchar(20)
	,@save_file_currdate		nchar(20)
	,@save_file_currtime		nchar(20)
	,@save_fileYYYY			nchar(4)
	,@save_fileMM			nchar(2)
	,@save_fileDD			nchar(2)
	,@save_fileHH			nchar(2)
	,@save_fileMN			nchar(2)
	,@save_fileSS			nchar(2)
	,@save_fileAMPM			nchar(2)
	,@hold_SQLservername		sysname
	,@hold_cmdoutput		nvarchar(255)
	,@hold_ParmText			nvarchar(max)
	,@check_single_quote		char(1)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@save_domain			sysname
	,@save_alt_filename		sysname
	,@extention			nvarchar(10)


DECLARE
	 @from_flag			char(1)
	,@save_mailserver		sysname
	,@parm_from			sysname
	,@parm_from_name		sysname
	,@parm_replyto			sysname


DECLARE
	 @cu11SQLservername		sysname


DECLARE
	 @cu12cmdoutput			nvarchar(255)


DECLARE
	 @cu13ParmText			nvarchar(max)
	,@cu13PT_row			int


----------------  initial values  -------------------
select @filename_wild 	= '%.sml'
Select @extention 	= 'sml'
Select @EOLWinNT        = char(13)+char(10)
Select @message_flag	= 'n'
select @attach_continue = 'n'
Select @save_mailserver = 'mail.Virtuoso.com'


Select @save_servername = @@servername
Select @save_servername2 = @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = rtrim(substring(@@servername, 1, (CHARINDEX('\', @@servername)-1)))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Select @save_domain = (select env_detail from dbo.Local_ServerEnviro where env_type = 'domain')


If @@servername in ('fresdbasql01', 'seasdbasql01')
   begin
	Select @save_profile_name = 'sqladminstage'
   end
Else
   begin
	Select @save_profile_name = 'sqladminproduction'
   end


create table #DirectoryTempTable (cmdoutput nvarchar(255) null)


create table #DirectoryTempTable2 (cmdoutput nvarchar(255) null)


create table #Smail_Info_bulk(ParmText nvarchar(max) null)


create table #Smail_Info(
			 ParmText nvarchar(max) null
			,pt_row [int] IDENTITY (1, 1) NOT NULL
			)


create table #fileexists (
		doesexist smallint,
		fileindir smallint,
		direxist smallint
		)


--  Create table variable
declare @servers table	(SQLservername sysname null)


/****************************************************************
 *                MainLine
 ***************************************************************/
If @server_name is null
   begin
	Insert into @servers (SQLservername)
	SELECT p.SQLname
	From DBAOps.dbo.DBA_Serverinfo  p with (NOLOCK)
	Where p.active in ('y', 'm')
	  and p.SQLmail = 'y'
          and p.DomainName = @save_domain
	  and p.SQLEnv like '%' + @save_SQLEnv + '%'


   end
Else
   begin
	Insert into @servers (SQLservername) values (@server_name)
   end


delete from @servers where SQLservername is null or SQLservername = ''
--select * from @servers


-- Check to see if there are servers to process
If (select count(*) from @servers) > 0
   begin
	start_servers:


	Select @cu11SQLservername = (select top 1 SQLservername from @servers order by SQLservername)
	Select @hold_SQLservername =  @cu11SQLservername
Print @cu11SQLservername


	Select @charpos = charindex('\', @cu11SQLservername)
	IF @charpos <> 0
	   begin
		Select @cu11SQLservername = rtrim(substring(@cu11SQLservername, 1, (CHARINDEX('\', @cu11SQLservername)-1)))
	   end


	Select @save_mailshare = '\\'+ @cu11SQLservername + '\' + @cu11SQLservername + '_dba_mail'


	--  Check for files in the dba_mail folder for this server
	Delete from #DirectoryTempTable
	Select @cmd = 'dir ' + @save_mailshare + '\*.' + @extention + ' /B'
	Print @cmd
	Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
	delete from #DirectoryTempTable where cmdoutput is null or cmdoutput = ''
	--select * from #DirectoryTempTable
	delete from #DirectoryTempTable where cmdoutput like '%File Not Found%'
	delete from #DirectoryTempTable where ltrim(rtrim(cmdoutput)) not like @filename_wild
select * from #DirectoryTempTable


	--  If a sql mail request file was found, process the request
	If (select count(*) from #DirectoryTempTable) > 0
	   begin
		start_cmdoutput:


		Select @cu12cmdoutput = (select top 1 cmdoutput from #DirectoryTempTable)


		select @hold_cmdoutput = @cu12cmdoutput
		select @cu12cmdoutput = ltrim(rtrim(@cu12cmdoutput))


		--  Capture the sql mail parameters for this request
		Delete from #Smail_Info_bulk
		Select @cmd = 'bulk insert #Smail_Info_bulk from  ''' + @save_mailshare + '\' + @cu12cmdoutput + ''''
		--Print @cmd
		exec master.sys.sp_executesql @cmd
		delete from #Smail_Info_bulk where ParmText = char(9)
		--select * from #Smail_Info_bulk


		Delete from #Smail_Info
		Insert into #Smail_Info select ParmText from #Smail_Info_bulk
		--select * from #Smail_Info


		--  Process the sql mail request
		If (select count(*) from #Smail_Info) > 0
		   begin
			--  Reset parameters
			Select @parm_from = ''
			Select @parm_from_name = ''
			Select @parm_replyto = ''
			Select @parm_recipients = ' '
			Select @parm_attach = ' '
			Select @parm_subject = ' '
			Select @parm_message = ' '
			Select @parm_copy_recipients = ' '
			Select @parm_blind_copy_recipients = ' '
			Select @parm_priority = 'NORMAL'
			Select @parm_type = 'text'
			Select @from_flag = 'n'


			If @@servername in ('fresdbasql01', 'seasdbasql01')
			   begin
				Select @save_profile_name = 'sqladminstage'
			   end
			Else
			   begin
				Select @save_profile_name = 'sqladminproduction'
			   end


			start_smail:


			Select @cu13PT_row = (select top 1 pt_row from #Smail_Info order by pt_row)
			Select @cu13ParmText = (select ParmText from #Smail_Info where pt_row = @cu13PT_row)


			Select @hold_ParmText = @cu13ParmText


			--  Here we check the parameters in the sql mail request file
			If @cu13ParmText is null
			   begin
				select @cu13ParmText = ' '
			   end


			select @charpos = charindex('@FROM ', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_from = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_from = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				If @parm_from like '%@%'
				   begin
					Select @from_flag = 'y'
				   end
				goto label01
			   end


			select @charpos = charindex('@FROM_NAME', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_from_name = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_from_name = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@replyto', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_replyto = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_replyto = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@recipients', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@TO ', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@subject', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_subject = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_subject = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@copy_recipients', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@CC ', @cu13ParmText)
			If @charpos > 0
			   begin


				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@blind_copy_recipients', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_blind_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_blind_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				goto label01
			   end


			select @charpos = charindex('@BCC ', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				If @charpos2 > @charpos
				   begin
					select @parm_blind_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				   end
				Else
				   begin
					select @parm_blind_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, len(@cu13ParmText)-@charpos)))
				   end


				select @parm_blind_copy_recipients = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				goto label01
			   end


			select @charpos = charindex('@priority', @cu13ParmText)
			If @charpos > 0
			   begin
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				select @parm_priority = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				goto label01
			   end


			select @charpos = charindex('@type', @cu13ParmText)
			If @charpos > 0
			   begin
				Select @cu13ParmText = REPLACE(@cu13ParmText, 'text/plain', 'text')
				select @charpos = charindex('''', @cu13ParmText)
				select @charpos2 = charindex('''', @cu13ParmText, @charpos+1)
				select @parm_type = ltrim(rtrim(substring(@cu13ParmText, @charpos+1, (@charpos2-@charpos)-1)))
				goto label01
			   end


			select @charpos = charindex('@attachments', @cu13ParmText)
			If @charpos > 0
			   begin
				Select @parm_attach = ltrim(rtrim(substring(@cu13ParmText, @charpos+16, len(@cu13ParmText))))


				select @last_char_test = substring(rtrim(@parm_attach), len(@parm_attach), 1)
				If @last_char_test = char(39)
				   begin
					select @parm_attach = substring(rtrim(@parm_attach), 1, len(@parm_attach)-1)
					select @parm_attach = rtrim(@parm_attach)
				   end
				Else
				   begin
					select @parm_attach = substring(rtrim(@parm_attach), 1, len(@parm_attach))
					select @parm_attach = rtrim(@parm_attach)


					select @attach_continue = 'y'
				   end


				goto label01
			   end


			If @attach_continue = 'y'
			   begin
				select @last_char_test = substring(rtrim(@cu13ParmText), len(@cu13ParmText), 1)
				If @last_char_test = char(39)
				   begin
					select @parm_attach = @parm_attach + substring(rtrim(@cu13ParmText), 1, len(@cu13ParmText)-1)
					select @attach_continue = 'n'
				   end
				Else
				   begin
					select @parm_attach = @parm_attach + substring(rtrim(@cu13ParmText), 1, len(@cu13ParmText))
				   end


				goto label01
			   end


			select @charpos = charindex('@message', @cu13ParmText)
			If @charpos > 0
			   begin
				select @message_flag	= 'y'
				select @charpos = charindex('@message = ''', @cu13ParmText)
				select @parm_message = substring(@cu13ParmText, @charpos+12, (len(@cu13ParmText)-@charpos+12))
				select @parm_message = rtrim(@parm_message)
				select @length = len(@parm_message)
				select @last_char_test = substring(rtrim(@parm_message), @length, 1)
				If @last_char_test = char(39)
				   begin
					select @parm_message = substring(rtrim(@parm_message), 1, @length-1)
					select @message_flag	= 'n'
				   end


				--  Check for orphaned single quotes and fix any that are found
				Select @start_charpos = 1
				dbl_check_single_quote01:
				select @charpos = charindex('''', @parm_message, @start_charpos)
				If @charpos > 0
				   begin
					select @check_single_quote = substring(@parm_message, @charpos+1, 1)
					If @check_single_quote <> char(39)
					   begin
						Select @parm_message = stuff(@parm_message, @charpos, 1, '''''')
					   end
					Select @start_charpos = @charpos+2
					goto dbl_check_single_quote01
				   end


				goto label01
			   end


			If @message_flag = 'y'
			   begin
				select @parm_message = @parm_message + @EOLWinNT
				select @length = len(rtrim(@cu13ParmText))
				select @last_char_test = substring(rtrim(@cu13ParmText), @length, 1)


				If @last_char_test = char(39)
				   begin
					select @cu13ParmText = substring(rtrim(@cu13ParmText), 1, @length-1)
					select @message_flag	= 'n'
				   end


				--  Check for orphaned single quotes and fix any that are found
				Select @start_charpos = 1
				dbl_check_single_quote02:
				select @charpos = charindex('''', @cu13ParmText, @start_charpos)
				If @charpos > 0
				   begin
					select @check_single_quote = substring(@cu13ParmText, @charpos+1, 1)
					If @check_single_quote <> char(39)
					   begin
						Select @cu13ParmText = stuff(@cu13ParmText, @charpos, 1, '''''')
					   end


					Select @start_charpos = @charpos+2
					goto dbl_check_single_quote02
				   end


				--  Add this line to the message
				select @parm_message = @parm_message + rtrim(@cu13ParmText)
			   end


			Label01:


		--  Remove this record from #Smail_Info and go to the next
		delete from #Smail_Info where pt_row = @cu13PT_row
		If (select count(*) from #Smail_Info) > 0
		   begin
			goto start_smail
		   end


	   end


		--  Now we verify the attachment if one was specified
		IF @parm_attach <> ' '
		   begin
			Select @attach_fail_flag = 'n'
			Select @save_parm_attach_result = ''
			Select @save_parm_attach = ltrim(@parm_attach)
			Select @save_parm_attach_len = len(@parm_attach)
			Select @startpos = 1
			label06:
				Select @charpos = charindex(';', @save_parm_attach, @startpos)
				IF @charpos <> 0
				   begin
					Select @save_parm_attach_single = substring(@save_parm_attach, @startpos, @charpos-@startpos)

					Delete from #fileexists
					Insert into #fileexists exec master.sys.xp_fileexist @save_parm_attach_single

					If exists (select 1 from #fileexists where doesexist <> 1)
					   begin
						Select @miscprint = 'DBA WARNING: xp_sendmail attachment does not exist. ' +  @parm_attach
						Select @parm_message = @parm_message + '


NOTE: Attachment Error for file ' + @save_parm_attach_single
						goto next_attach_multi
					   end


					--  Check to see if the file is ready to be attached
					If DBAOps.dbo.dbaudf_GetFileProperty(@save_parm_attach_single,'file','InUse') <> 0
					   begin
						--  The file is not ready to be attached.  If the file is less than 5 minutes old, skip this request for now.
						Select @attach_fail_flag = 'y'


						Delete from #DirectoryTempTable2
						Select @cmd = 'dir /4 ' + @save_parm_attach_single
						Print @cmd
						Insert into #DirectoryTempTable2 exec master.sys.xp_cmdshell @cmd
						delete from #DirectoryTempTable2 where cmdoutput is null or cmdoutput = ''
						delete from #DirectoryTempTable2 where cmdoutput like ' Volume%'
						delete from #DirectoryTempTable2 where cmdoutput like ' Directory%'
						delete from #DirectoryTempTable2 where cmdoutput like '% bytes %'
						delete from #DirectoryTempTable2 where cmdoutput like '%File(s)%'
						--select * from #DirectoryTempTable2


						If (select count(*) from #DirectoryTempTable2) = 1
						   begin
							Select @save_cmdoutput2 = (select top 1 cmdoutput from #DirectoryTempTable2)
							select @save_fileYYYY = substring(@save_cmdoutput2, 7, 4)
							select @save_fileMM = substring(@save_cmdoutput2, 1, 2)
							select @save_fileDD = substring(@save_cmdoutput2, 4, 2)


							Select @save_fileHH = substring(@save_cmdoutput2, 13, 2)
							Select @save_fileMN = substring(@save_cmdoutput2, 16, 2)
							Select @save_fileSS = '00'
							Select @save_fileAMPM = substring(@save_cmdoutput2, 19, 2)


							If @save_fileAMPM = 'PM'
							   begin
								Select @save_fileHH = convert(nchar(2), (convert(smallint,@save_fileHH) + 12))
							   end


							select @save_date = @save_fileYYYY + '-' + @save_fileMM + '-' + @save_fileDD + ' ' + @save_fileHH + ':' + @save_fileMN + ':' + @save_fileSS


							If (select datediff(mi, convert(datetime, @save_date), getdate())) < 6
							   begin
								-- skip this email request for now
								goto get_next_request
							   end
						   end
					   end


					--  Attach the file and go onto the next one
					Select @save_parm_attach_result = @save_parm_attach_result + @save_parm_attach_single + ';'


					next_attach_multi:
					Select @startpos = @charpos + 1
					goto label06
				   end
				Else
				   begin
					Select @save_parm_attach_single = substring(@save_parm_attach, @startpos, @save_parm_attach_len - @startpos + 1)

					Delete from #fileexists
					Insert into #fileexists exec master.sys.xp_fileexist @save_parm_attach_single

					If exists (select 1 from #fileexists where doesexist <> 1)
					   begin
						Select @miscprint = 'DBA WARNING: xp_sendmail attachment does not exist. ' +  @parm_attach
						Select @parm_message = @parm_message + '


NOTE: Attachment Error for file ' + @save_parm_attach_single
						Select @save_parm_attach_len = len(@save_parm_attach_result)
						If @save_parm_attach_len > 0
						   begin
							Select @save_parm_attach_result = substring(@save_parm_attach_result, 1, @save_parm_attach_len - 1)
						   end
						Else
						   begin
							Select @save_parm_attach_result = ' '
						   end
					   end
					Else
					   begin
						--  Check to see if the file is ready to be attached
						If DBAOps.dbo.dbaudf_GetFileProperty(@save_parm_attach_single,'file','InUse') <> 0
						   begin
							--  The file is not ready to be attached.  If the file is less than 5 minutes old, skip this request for now.
							Select @attach_fail_flag = 'y'


							Delete from #DirectoryTempTable2
							Select @cmd = 'dir /4 ' + @save_parm_attach_single
							Print @cmd
							Insert into #DirectoryTempTable2 exec master.sys.xp_cmdshell @cmd
							delete from #DirectoryTempTable2 where cmdoutput is null or cmdoutput = ''
							delete from #DirectoryTempTable2 where cmdoutput like ' Volume%'
							delete from #DirectoryTempTable2 where cmdoutput like ' Directory%'
							delete from #DirectoryTempTable2 where cmdoutput like '% bytes %'
							delete from #DirectoryTempTable2 where cmdoutput like '%File(s)%'
							--select * from #DirectoryTempTable2


							If (select count(*) from #DirectoryTempTable2) = 1
							   begin
								Select @save_cmdoutput2 = (select top 1 cmdoutput from #DirectoryTempTable2)
								select @save_fileYYYY = substring(@save_cmdoutput2, 7, 4)
								select @save_fileMM = substring(@save_cmdoutput2, 1, 2)
								select @save_fileDD = substring(@save_cmdoutput2, 4, 2)

								Select @save_fileHH = substring(@save_cmdoutput2, 13, 2)
								Select @save_fileMN = substring(@save_cmdoutput2, 16, 2)
								Select @save_fileSS = '00'
								Select @save_fileAMPM = substring(@save_cmdoutput2, 19, 2)


								If @save_fileAMPM = 'PM'
								   begin
									Select @save_fileHH = convert(nchar(2), (convert(smallint,@save_fileHH) + 12))
								   end


								select @save_date = @save_fileYYYY + '-' + @save_fileMM + '-' + @save_fileDD + ' ' + @save_fileHH + ':' + @save_fileMN + ':' + @save_fileSS


								If (select datediff(mi, convert(datetime, @save_date), getdate())) < 6
								   begin
									-- skip this email request for now
									goto get_next_request
								   end
							   end
						   end


						Select @save_parm_attach_result = @save_parm_attach_result + @save_parm_attach_single
					   end
				   end


			Select @parm_attach = @save_parm_attach_result


			--  If there was an attachment that was not ready to be attached, and the request is no longer being skipped...
			If @attach_fail_flag = 'y'
			   begin
				Select @miscprint = 'DBA WARNING: xp_sendmail attachment failed. ' +  @parm_attach
				Select @parm_message = @parm_message + '


NOTE: Attachment Error'
				Select @parm_attach = ' '
			   end


		   end


		--  Verfiy we have a recipient and a subject for this email
		IF @parm_recipients = ' '
		   begin
			Select @miscprint = 'DBA WARNING: SQL Mail parameter file does not include recipients. ' +  @cu12cmdoutput
			raiserror(@miscprint,-1,-1) with log
			goto label89
		   end


		IF @parm_subject = ' '
		   begin
			Select @miscprint = 'DBA WARNING: SQL Mail parameter file does not include subject. ' +  @cu12cmdoutput
			raiserror(@miscprint,-1,-1) with log
			goto label89
		   end


		--  Truncate message if it's over len=3200
		If (select len(@parm_message)) > 3200
		   begin
			Select @parm_message = left(@parm_message, 3200) + '... (Message has been truncated due to length)...' + @EOLWinNT
		   end


		--  Truncate message depedning on lenght of attachments
		If (select len(@parm_message)) + (select len(@parm_attach)) > 3500
		   begin
			Select @parm_message = left(@parm_message, 3500-len(@parm_attach)) + '... (Message has been truncated due to length)...' + @EOLWinNT
		   end


		--  If @FROM was used, update the @save_profile_name value
		If @from_flag = 'y'
		   begin
			--  Check @parm_from_name value
			If  @parm_from_name = ''
			   begin
				select @parm_from_name = @parm_from
			   end


			If @parm_from_name like '%@%'
			   begin
				select @charpos = charindex('@', @parm_from_name)
				If @charpos > 0
				   begin
					Select @parm_from_name = left(@parm_from_name, @charpos-1)
				   end
			   end

			--  Make sure we have a profile set up for this @parm_from_name value
			if not exists (select 1 from msdb.dbo.sysmail_profile where name = @parm_from_name)
			   begin


				EXECUTE msdb.dbo.sysmail_add_profile_sp
					@profile_name = @parm_from_name,
					@description = @parm_from_name

				EXECUTE msdb.dbo.sysmail_add_account_sp
					@account_name = @parm_from_name,
					@description = @parm_from_name,
					@email_address = @parm_from,
					@display_name = @parm_from_name,
					@replyto_address = @parm_replyto,
					@mailserver_name = @save_mailserver


				EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
					@profile_name = @parm_from_name,
					@account_name = @parm_from_name,
					@sequence_number =1 ;


				EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
					@profile_name = @parm_from_name,
					@principal_id = 0,
					@is_default = 'false'
			   end


			Select @save_profile_name = @parm_from_name


		   end


		--  Format  and exectute the sp_send_dbmail command
		Select @cmd = 'msdb.dbo.sp_send_dbmail @profile_name = ''' + @save_profile_name
						+ ''', @recipients = ''' + @parm_recipients
						+ ''', @subject = ''' + @parm_subject
						+ ''', @body = ''' + @parm_message
						+ ''', @importance = ''' + @parm_priority
						+ ''', @body_format = ''' + @parm_type
						+ ''''


		If @parm_copy_recipients <> ' '
		   begin
			Select @cmd = @cmd + ', @copy_recipients = ''' + @parm_copy_recipients + ''''
		   end


		If @parm_blind_copy_recipients <> ' '
		   begin
			Select @cmd = @cmd + ', @blind_copy_recipients = ''' + @parm_blind_copy_recipients + ''''
		   end


		If @parm_attach <> ' '
		   begin
			If charindex(';', @parm_attach) > 0
			   begin
				Select @cmd = @cmd + ', @file_attachments = ''' + @parm_attach + ''''
			   end
			Else
			   begin
				Select @cmd = @cmd + ', @file_attachments = ''' + @parm_attach + ''''
			   end
		   end


		Print @save_mailshare + '\' + @cu12cmdoutput
		--print @cmd
		raiserror('', -1,-1) with nowait
		EXEC @retcode = master.sys.sp_executesql @cmd


		Waitfor delay '00:00:02'


label89:


		IF @@error <> 0 or @retcode <> 0
		   begin
			Select @save_alt_filename = replace(@cu12cmdoutput, '.'+@extention, '.err')
			Select @cmd = 'ren "' + @save_mailshare + '\' + @cu12cmdoutput + '" "' + @save_alt_filename + '"'
			select @retry = 0


			rename_error:


			print @cmd
			raiserror('', -1,-1) with nowait
			EXEC @retcode = master.sys.xp_cmdshell @cmd, no_output


			IF @@error <> 0 or @retcode <> 0
			   begin
				select @retry = @retry  + 1
				If @retry < 5
				   begin
					Waitfor delay '00:00:10'
					goto rename_error
				   end
			   end


			Select @miscprint = 'DBA WARNING: msdb.dbo.sp_send_dbmail process failed for file ' +  @save_mailshare + '\' + @cu12cmdoutput
			Print 'Mail ERROR for server\file: ' + @save_mailshare + '\' + @cu12cmdoutput + '  ' + convert(nvarchar(30), getdate(), 121)
			Print 'Subject: ' + @parm_subject


			raiserror(@miscprint,-1,-1) with log
		   end
		Else
		   begin
			Print 'Mail sent for server\file: ' + @save_mailshare + '\' + @cu12cmdoutput + '  ' + convert(nvarchar(30), getdate(), 121)
			Print 'Subject: ' + @parm_subject
			Select @save_alt_filename = replace(@cu12cmdoutput, '.'+@extention, '.old')
			Select @cmd = 'ren "' + @save_mailshare + '\' + @cu12cmdoutput + '" "' + @save_alt_filename + '"'
			select @retry = 0


			rename_sml2:


			print @cmd
			raiserror('', -1,-1) with nowait
			EXEC @retcode = master.sys.xp_cmdshell @cmd, no_output


			IF @@error <> 0 or @retcode <> 0
			   begin
				select @retry = @retry  + 1
				If @retry < 5
				   begin
					Waitfor delay '00:00:10'
					goto rename_sml2
				   end
			   end
		   end


		--  Remove special Profile
		If @from_flag = 'y'
		   begin
			EXECUTE msdb.dbo.sysmail_delete_profile_sp @profile_name = @parm_from_name


			EXECUTE msdb.dbo.sysmail_delete_account_sp @account_name = @parm_from_name
		   end


		get_next_request:


		--  Remove this record from #DirectoryTempTable and go to the next
		delete from #DirectoryTempTable where cmdoutput = @hold_cmdoutput
		If (select count(*) from #DirectoryTempTable) > 0
		   begin
			goto start_cmdoutput
		   end


	   end


	--  Remove this record from @servers and go to the next
	delete from @servers where SQLservername = @hold_SQLservername
	If (select count(*) from @servers) > 0
	   begin
		goto start_servers
	   end


   end


----------------  End  -------------------
label99:


drop table #DirectoryTempTable


drop table #DirectoryTempTable2


drop table #Smail_Info_bulk


drop table #Smail_Info


drop table #fileexists
GO
GRANT EXECUTE ON  [dbo].[dbasp_dbamail_process] TO [public]
GO
