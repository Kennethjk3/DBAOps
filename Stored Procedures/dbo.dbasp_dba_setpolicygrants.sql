SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_dba_setpolicygrants]


/*********************************************************
 **  Stored Procedure dbasp_dba_setpolicygrants
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  November 13, 2008
 **
 **  This procedure sets user_rights for specific policies
 **  within Windows.  The normal SQL install will do this, but
 **  this sproc will grant those rights to a domain group, which
 **  will make it easier to change service accounts at some regular
 **  interval.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/13/2008	Steve Ledridge		New process
--	11/22/2008	Steve Ledridge		Removed loop on ##temp table
--	06/02/2010	Steve Ledridge		Commented out the output.
--	======================================================================================


/***


--***/


DECLARE
	 @miscprint				nvarchar(4000)
	,@cmd					nvarchar(500)
	,@charpos				int
	,@save_servername			sysname
	,@isNMinstance				char(1)
	,@save_svcaccount			sysname
	,@save_domain				sysname
	,@save_sqlinstance			sysname
	,@save_groupSID				nvarchar(500)
	,@save_infvalue				nvarchar(4000)
	,@SeTcbPrivilege_flag			char(1)
	,@SeChangeNotifyPrivilege_flag		char(1)
	,@SeLockMemoryPrivilege_flag		char(1)
	,@SeBatchLogonRight_flag		char(1)
	,@SeServiceLogonRight_flag		char(1)
	,@SeAssignPrimaryTokenPrivilege_flag	char(1)
	,@updated_flag				char(1)


----------------  initial values  -------------------
Select @SeTcbPrivilege_flag = 'n'
Select @SeChangeNotifyPrivilege_flag = 'n'
Select @SeLockMemoryPrivilege_flag = 'n'
Select @SeBatchLogonRight_flag = 'n'
Select @SeServiceLogonRight_flag = 'n'
Select @SeAssignPrimaryTokenPrivilege_flag = 'n'
Select @updated_flag = 'n'


--  Create temp tables
declare @tblv_DBname table (dbname sysname)
create table #DirectoryTempTable(cmdoutput nvarchar(255) null)
create table ##INF (INFValue nvarchar (4000) null)
create table ##INFout (INFValue nvarchar (4000) null)


--  Get server name info
Select @save_domain = ''
Select @save_servername = @@servername
Select @isNMinstance = 'n'


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
	Select @isNMinstance = 'y'
   end


--  Get domain name info
Select @cmd = 'whoami'


insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd--, no_output
delete from #DirectoryTempTable where cmdoutput is null
--select * from #DirectoryTempTable


If (select count(*) from #DirectoryTempTable) > 0
   begin
	Select @save_svcaccount = (select top 1 cmdoutput from #DirectoryTempTable)
   end


Select @charpos = charindex('\', @save_svcaccount)
IF @charpos <> 0
   begin
	Select @save_domain = substring(@save_svcaccount, 1, (CHARINDEX('\', @save_svcaccount)-1))
   end


Print '/*'
Print '--  Set Policy Grants Process Starting  ----------------------------------------------- '
Print ''


/****************************************************************
 *                MainLine
 ***************************************************************/


-- Step 1: Verfiy the local *.sdb file is in place (move it to c:\)
Select @cmd = 'dir %windir%\security\Database\secedit.sdb'
Delete from #DirectoryTempTable
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd
Delete from #DirectoryTempTable where cmdoutput not like '%secedit.sdb%'
Delete from #DirectoryTempTable where cmdoutput is null
--select * from #DirectoryTempTable
If (select count(*) from #DirectoryTempTable) = 0
   begin
	Select @miscprint = 'DBA ERROR: Local secedit.sdb file not found.'
	Print @miscprint
	Select @miscprint = 'DBA ERROR: Unable to complete User_Rights Policy Updates for server ' + @@servername
	Print @miscprint
	goto label99
   end


Print 'Copy *.sdb file to c:\'
Select @cmd = 'xcopy "%windir%\security\Database\secedit.sdb" "c:\"'
Select @cmd = @cmd + ' /Y /R'
Print @cmd
Print ''
EXEC master.sys.xp_cmdshell @cmd--, no_output


-- Step 2: Create new *.INF template file using secedit /export
Select @cmd = 'secedit /export /cfg c:\dba_user_rights_now.INF /areas user_rights'
Print @cmd
Print ''
EXEC master.sys.xp_cmdshell @cmd--, no_output


-- Step 3: Get the SID that matches the SQL service account domain group
Select @cmd = 'whoami /groups'
Print @cmd
Print ''


delete from #DirectoryTempTable
insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd--, no_output
delete from #DirectoryTempTable where cmdoutput is null
--select * from #DirectoryTempTable


If exists (select 1 from #DirectoryTempTable where cmdoutput like 'AMER\SG-AMER-SeaSQLProdsvc%' or cmdoutput like 'STAGE\SeaSQLStageSvc%' or cmdoutput like 'PRODUCTION\SeaSQLProdsvc%')
   begin
	Select @save_groupSID = (select top 1 cmdoutput from #DirectoryTempTable where cmdoutput like 'AMER\SG-AMER-SeaSQLProdsvc%' or cmdoutput like 'STAGE\SeaSQLStageSvc%' or cmdoutput like 'PRODUCTION\SeaSQLProdsvc%')


	Select @charpos = charindex('Group', @save_groupSID)
	IF @charpos <> 0
	   begin
		Select @save_groupSID = substring(@save_groupSID, @charpos+5, 200)
		Select @save_groupSID = ltrim(@save_groupSID)
	   end
	Else
	   begin
		Select @miscprint = 'DBA ERROR: Group SID not found for AMER\SG-AMER-SeaSQLProdsvc.'
		Print @miscprint
		Select @miscprint = 'DBA ERROR: Unable to complete User_Rights Policy Updates for server ' + @@servername
		Print @miscprint
		goto label99
	   end


	Select @charpos = charindex(' ', @save_groupSID)
	IF @charpos <> 0
	   begin
		Select @save_groupSID = substring(@save_groupSID, 1, @charpos-1)
	   end


	Select @save_groupSID = rtrim(@save_groupSID)


   end


Print 'SQL service domain group SID is ' + @save_groupSID
Print ''


-- Step 4: Read in the *.INF file created in Step 2, and create a modified version using the SID from Step 3.
Select @cmd = 'bcp ##INF in "c:\dba_user_rights_now.INF" -S' + @@servername + ' -m 0 -w -b 1000 -T'
Print @cmd
Print ''


delete from ##INF
insert into ##INF exec master.sys.xp_cmdshell @cmd--, no_output
delete from ##INF where INFValue is null
--select * from ##INF


If not exists (select 1 from ##INF where INFvalue like '%Privilege Rights%')
   begin
	Select @miscprint = 'DBA ERROR: The created *.INF file for this process is invalid.'
	Print @miscprint
	Select @miscprint = 'DBA ERROR: Unable to complete User_Rights Policy Updates for server ' + @@servername
	Print @miscprint
	goto label99
   end


--  Check for policies
Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeTcbPrivilege%')
If @save_infvalue like 'SeTcbPrivilege%'
   begin
	Select @SeTcbPrivilege_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeChangeNotifyPrivilege%')
If @save_infvalue like 'SeChangeNotifyPrivilege%'
   begin
	Select @SeChangeNotifyPrivilege_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeLockMemoryPrivilege%')
If @save_infvalue like 'SeLockMemoryPrivilege%'
   begin
	Select @SeLockMemoryPrivilege_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeBatchLogonRight%')
If @save_infvalue like 'SeBatchLogonRight%'
   begin
	Select @SeBatchLogonRight_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeServiceLogonRight%')
If @save_infvalue like 'SeServiceLogonRight%'
   begin
	Select @SeServiceLogonRight_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


Select @save_infvalue = (select top 1 INFvalue from ##INF where INFvalue like '%SeAssignPrimaryTokenPrivilege%')
If @save_infvalue like 'SeAssignPrimaryTokenPrivilege%'
   begin
	Select @SeAssignPrimaryTokenPrivilege_flag = 'y'
	If @save_infvalue not like '%' + @save_groupSID + '%'
	   begin
		Select @updated_flag = 'y'
		Select @save_infvalue = rtrim(@save_infvalue) + ',*' + @save_groupSID
		Insert into ##INFout values(@save_infvalue)
		--Print @save_infvalue
	   end
   end


end_inf:


--  Now check to see if specific policies were not in the INF file at all.
If @SeTcbPrivilege_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeTcbPrivilege = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


If @SeChangeNotifyPrivilege_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeChangeNotifyPrivilege = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


If @SeLockMemoryPrivilege_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeLockMemoryPrivilege = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


If @SeBatchLogonRight_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeBatchLogonRight = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


If @SeServiceLogonRight_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeServiceLogonRight = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


If @SeAssignPrimaryTokenPrivilege_flag = 'n'
   begin
	Select @updated_flag = 'y'
	Select @save_infvalue = 'SeAssignPrimaryTokenPrivilege = *' + @save_groupSID
	Insert into ##INFout values(@save_infvalue)
   end


--Select * from ##INFout
Select @cmd = 'bcp ##INFout out "c:\dba_user_rights_new.INF" -S' + @@servername + ' -w -T'
Print @cmd
Print ''
exec master.sys.xp_cmdshell @cmd--, no_output


-- Verfiy output file exists
Select @cmd = 'dir c:\dba_user_rights_new.INF'
Delete from #DirectoryTempTable
Insert into #DirectoryTempTable exec master.sys.xp_cmdshell @cmd--, no_output
Delete from #DirectoryTempTable where cmdoutput not like '%dba_user_rights_new.INF%'
Delete from #DirectoryTempTable where cmdoutput is null
--select * from #DirectoryTempTable
If (select count(*) from #DirectoryTempTable) = 0
   begin
	Select @miscprint = 'DBA ERROR: New c:\dba_user_rights_new.INF file was not created properly.'
	Print @miscprint
	Select @miscprint = 'DBA ERROR: Unable to complete User_Rights Policy Updates for server ' + @@servername
	Print @miscprint
	goto label99
   end


-- Step 5: Update the user_rights policy permissions using secedit /configure and the *.INF file created in Step 4.
If @updated_flag = 'y'
   begin
	Print ''
	Print 'Start secedit /configure process'


	Select @cmd = 'secedit /configure /db c:\secedit.sdb /cfg c:\dba_user_rights_new.INF /overwrite /areas user_rights /quiet'
	Print @cmd
	Print ''
	EXEC master.sys.xp_cmdshell @cmd--, no_output
   end
Else
   begin
	Print 'No policy user_rights updates needed.'
	Print ''
   end


--  Finalization  --------------------------------------------------------------------------------------------------
label99:


Print ' '
Print '*/'


drop table #DirectoryTempTable
drop table ##INF
drop table ##INFout
GO
GRANT EXECUTE ON  [dbo].[dbasp_dba_setpolicygrants] TO [public]
GO
