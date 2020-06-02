SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_AvailGrps_General]


/*********************************************************
 **  Stored Procedure dbasp_HC_AvailGrps_General
 **  Written by Steve Ledridge, Virtuoso
 **  April 20, 2016
 **  This procedure runs the Availability Group portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/20/2016	Steve Ledridge		New process.
--	01/20/2017	Steve Ledridge		Use SERVERPROPERTY('IsHadrEnabled') to check for availability groups enabled.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  For: Are availgrps activated
--     : Do we have any availgrps defined
--     : Is there a category in msdb for each availgrp. (self healing)
--     : Make sure the AG_Role_Change UTIL job exists.
--     : Make sure the AG_Role_Change UTIL alert exists.
--     : Check non-admin jobs for AvailGrp category.


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(2000)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@save_productversion			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@save_AGname				sysname
	,@save_AGname_alt			sysname
	,@job_id				uniqueidentifier


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


CREATE TABLE #miscTempTable (cmdoutput NVARCHAR(400) NULL)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - AvailGrps General'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Check SQL version
IF @@microsoftversion / 0x01000000 < 11
  or SERVERPROPERTY('IsHadrEnabled') = 0 -- availability groups enabled on the server
   BEGIN
	Select @miscprint = 'Skipping this process for server - ' + @@servername
	Print  @miscprint
	Print ''
	goto label99
   END


--  Check for availgrps - if none, exit
IF @@microsoftversion / 0x01000000 >= 11
  and SERVERPROPERTY('IsHadrEnabled') = 1 -- availability groups enabled on the server
   BEGIN
	If not exists (select 1 from sys.availability_groups_cluster)
	   begin
		Select @miscprint = 'Always On\Availability Groups are not activated.'
		Print  @miscprint
		goto label99
	   end
   END


--     : Do we have any availgrps defined
DELETE FROM #miscTempTable
INSERT INTO #miscTempTable
select name from sys.availability_groups_cluster


Delete from #miscTempTable where cmdoutput is null
--select * from #miscTempTable


--  Start the AG Check process
IF (SELECT COUNT(*) FROM #miscTempTable) = 0
   begin
	Select @miscprint = 'No Availability Groups found for this SQL instance.'
	Print  @miscprint
	goto label99
   end
Else
   BEGIN
	If not exists (select 1 from msdb.[dbo].[syscategories] where name = 'AG_none')
	   begin
		EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name= 'AG_none'


		Select @save_test = 'select name from msdb.[dbo].[syscategories] where name = ''AG_none'''


		insert into [dbo].[HealthCheckLog] values ('AvailGrp', 'Add_JobCategory', 'Warning', 'low', @save_test, 'msdb', 'Added AG_none job category', '', getdate())
	   end


	start_categories:


	Select @save_AGname = (select top 1 cmdoutput from #miscTempTable)


	--  Is there a category in msdb for each availgrp. (self healing)
	If not exists (select 1 from msdb.[dbo].[syscategories] where name = 'AG_' + @save_AGname)
	   begin
		Select @save_AGname_alt = 'AG_' + @save_AGname
		EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name= @save_AGname_alt


		Select @save_test = 'select name from msdb.[dbo].[syscategories] where name = ''' + @save_AGname_alt + ''''


		insert into [dbo].[HealthCheckLog] values ('AvailGrp', 'Add_JobCategory', 'Warning', 'low', @save_test, 'msdb', @save_AGname_alt, 'Added new job category', getdate())
	   end


	-- check for more rows to process
	delete from #miscTempTable where cmdoutput = @save_AGname
	IF (SELECT COUNT(*) FROM #miscTempTable) > 0
	   BEGIN
		goto start_categories
	   END


   END


--  Make sure the AG_Role_Change UTIL job exists.
select @job_id = (select top 1 job_id from msdb.dbo.sysjobs where name like '%UTIL - AG_Role_Change%')


if @job_id is null
   begin
	Select @save_test = 'select name from msdb.dbo.sysjobs where name like ''%UTIL - AG_Role_Change%'''


	insert into [dbo].[HealthCheckLog] values ('AvailGrp', 'Check Job', 'Fail', 'High', @save_test, 'msdb', 'UTIL - AG_Role_Change', 'Job does not exist', getdate())
   end


--  Make sure the 'AG Role Change' alert exists.
If not exists (select * from msdb.dbo.sysalerts where name = N'AG Role Change')
   begin
	Select @save_test = 'select * from msdb.dbo.sysalerts where name = N''AG Role Change'''


	insert into [dbo].[HealthCheckLog] values ('AvailGrp', 'Check Alert', 'Fail', 'High', @save_test, 'msdb', 'AG Role Change Alert', 'Alert does not exist', getdate())
   end


--     : Check non-admin jobs for AvailGrp category.
If exists (Select j.name, c.name
		from msdb.dbo.sysjobs j, msdb.dbo.syscategories c
		where j.category_id = c.category_id
		and c.name not like 'AG_%'
		and j.name not like 'BASE%'
		and j.name not like 'collection_set%'
		and j.name not like 'Create New%'
		and j.name not like 'Database Mirroring%'
		and j.name not like 'DBA%'
		and j.name not like 'Distribution clean up%'
		and j.name not like 'LS%'
		and j.name not like 'MAINT%'
		and j.name not like 'mdw_purge%'
		and j.name not like 'MON%'
		and j.name not like 'Rstr%'
		and j.name not like 'SPCL%'
		and j.name not like 'DBAOps%'
		and j.name not like 'syspolicy_purge%'
		and j.name not like 'sysutility%'
		and j.name not like 'UTIL%'
		and j.name not like 'x%'
		and j.name not like 'z%')
   begin
	Select @save_test = 'Select j.name, c.name from msdb.dbo.sysjobs j, msdb.dbo.syscategories c where j.category_id = c.category_id and c.name not like ''AG_%'' and j.name not like ''BASE%'''


	insert into [dbo].[HealthCheckLog] values ('AvailGrp', 'Check Job Category', 'Fail', 'Medium', @save_test, 'msdb', 'AG Job Category', 'Some non-admin jobs do not have AG category', getdate())
   end


Print '--select * from [dbo].[HealthCheckLog] where HCcat like ''AvailGrp%'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #miscTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_AvailGrps_General] TO [public]
GO
