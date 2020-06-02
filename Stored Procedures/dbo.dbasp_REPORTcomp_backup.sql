SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_REPORTcomp_backup]


/*********************************************************
 **  Stored Procedure dbasp_REPORTcomp_backup
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 20, 2009
 **
 **  This dbasp is set up to create a report documenting
 **  compression backup license usage for all SQL servers.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/20/2009	Steve Ledridge		New report.
--	08/25/2009	Steve Ledridge		Changed display for OSname.
--	08/27/2009	Steve Ledridge		Added code for status.
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(255)
	,@charpos		int
	,@save_BU_ID		int
	,@save_servername	sysname
	,@save_SQLname		sysname
	,@save_CompType		sysname
	,@save_Version		sysname
	,@save_VersionType	sysname
	,@save_License		sysname
	,@save_VendorName	sysname
	,@save_Product		sysname
	,@save_LI_Version	sysname
	,@save_LI_Type		sysname
	,@save_LicenseNum	int
	,@save_Support_ExpDate	datetime
	,@save_active		char(1)
	,@hold_License		sysname
	,@save_detail_count	int
	,@save_detail01_ID	int
	,@save_OSname		sysname
	,@save_SQLver		sysname
	,@save_Status		sysname


----------------  initial values  -------------------


--  Create temp table
CREATE TABLE #temp_BackupInfo ([BU_ID] [int] IDENTITY(1,1) NOT NULL
			    ,[servername] [sysname] NULL
			    ,[SQLname] [sysname] NULL
			    ,[CompType] [sysname] NULL
			    ,[Version] [sysname] NULL
			    ,[VersionType] [sysname] NULL
			    ,[License] [sysname] NULL
			    )


CREATE TABLE #temp_detail01 ([detail01_ID] [int] IDENTITY(1,1) NOT NULL
			    ,[servername] [sysname] NULL
			    ,[SQLname] [sysname] NULL
			    ,[Version] [sysname] NULL
			    ,[VersionType] [sysname] NULL
			    )


--  load the temp table
Insert into #temp_BackupInfo
select servername, SQLname, CompType, Version, VersionType, License
from dbo.Compress_BackupInfo
--select * from #temp_BackupInfo order by comptype, License


/****************************************************************
 *                MainLine
 ***************************************************************/


----------------------  Print the headers  ----------------------
Print  '/*******************************************************************'
Select @miscprint = '   REPORT COMPERSSION BACKUP USAGE & LICENSE INFO'
Print  @miscprint
Print  ' '
Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate())
Print  @miscprint
Print  '*******************************************************************/'
Print  ''
Print  ''


If (select count(*) from #temp_BackupInfo) = 0
   begin
	Select @miscprint = 'No License rows to report.'
	Print  @miscprint
   end
Else
   begin
	Select @hold_License = ''


	Start01:
	Select @save_BU_ID = (select top 1 BU_ID from #temp_BackupInfo order by CompType, VersionType, License, servername)
	Select @save_License = (select License from #temp_BackupInfo where BU_ID = @save_BU_ID)
	Select @save_CompType = (select CompType from #temp_BackupInfo where BU_ID = @save_BU_ID)


	If exists (select 1 from dbo.LicenseInfo where LicenseKey = @save_License)
	   begin
		Select @save_VendorName = (select VendorName from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_Product = (select Product from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_LI_Version = (select Version from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_LI_Type = (select Type from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_LicenseNum = (select LicenseNum from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_Support_ExpDate = (select Support_ExpDate from dbo.LicenseInfo where LicenseKey = @save_License)
		Select @save_active = (select active from dbo.LicenseInfo where LicenseKey = @save_License)
	   end
	Else
	   begin
		Select @save_VendorName = @save_CompType
		Select @save_Product = 'unknown'
		Select @save_LI_Version = 'unknown'
		Select @save_LI_Type = 'unknown'
		Select @save_LicenseNum = 0
		Select @save_Support_ExpDate = '01-01-1900'
		Select @save_active = 'n'
	   end


	Select @save_Status = 'Active'


	If datediff(d, @save_Support_ExpDate, getdate()) > 0
	   begin
		Select @save_Status = 'Support Expired'
	   end


	If @save_LicenseNum = 0
	   begin
		Select @save_Status = 'Not Valid'
	   end


	If @save_License <> @hold_License
	   begin
		Select @miscprint = 'Vendor: ' + @save_VendorName
		Print  @miscprint
		If getdate() > @save_Support_ExpDate
		  begin
			Select @miscprint = 'License Key: ' + @save_License + '   Type: ' + @save_LI_Type + '   Support Expired: ' + convert(nvarchar(12), @save_Support_ExpDate, 101)
			Print  @miscprint
		   end
		Else
		  begin
			Select @miscprint = 'License Key: ' + @save_License + '   Type: ' + @save_LI_Type + '   Support Expires: ' + convert(nvarchar(12), @save_Support_ExpDate, 101)
			Print  @miscprint
		   end
		Select @miscprint = 'Version: ' + @save_LI_Version
		Print  @miscprint
		Select @miscprint = 'Status: ' + @save_Status
		Print  @miscprint
		Select @miscprint = 'License Total: ' + convert(nvarchar(10), @save_LicenseNum)
		Print  @miscprint


		Select @hold_License = @save_License
	   end


		--  Load detail for this license key
		delete from #temp_detail01


		start02:
		Select @save_servername = (select servername from #temp_BackupInfo where BU_ID = @save_BU_ID)
		Select @save_SQLname = (select SQLname from #temp_BackupInfo where BU_ID = @save_BU_ID)
		Select @save_Version = (select Version from #temp_BackupInfo where BU_ID = @save_BU_ID)
		Select @save_VersionType = (select VersionType from #temp_BackupInfo where BU_ID = @save_BU_ID)


		Insert into #temp_detail01 values(@save_servername, @save_SQLname, @save_Version, @save_VersionType)


		--  Check for more detail rows to process
		delete from #temp_BackupInfo where servername = @save_servername and License = @hold_License


		If (select count(*) from #temp_BackupInfo where License = @hold_License) > 0
		   begin
			Select @save_BU_ID = (select top 1 BU_ID from #temp_BackupInfo where License = @hold_License order by CompType, VersionType, License, servername)
			goto Start02
		   end


		Select @save_detail_count = (select count(*) from #temp_detail01)
		If @save_detail_count is null
		    begin
			Select @save_detail_count = 0
		   end


		Select @miscprint = 'License''s Used: ' + convert(nvarchar(10), @save_detail_count)
		Print  @miscprint
		Print  ' '


		If @save_detail_count > 0
		   begin
			Select @miscprint = 'Server Name           SQL Name                   OS Version                      Version          Type'
			Print  @miscprint
			Select @miscprint = '====================  =========================  ==============================  ===============  ===================='
			Print  @miscprint


			detail01:

			Select @save_detail01_ID = (select top 1 detail01_ID from #temp_detail01 order by servername)
			Select @save_servername = (select servername from #temp_detail01 where detail01_ID = @save_detail01_ID)
			Select @save_SQLname = (select SQLname from #temp_detail01 where detail01_ID = @save_detail01_ID)
			Select @save_Version = (select Version from #temp_detail01 where detail01_ID = @save_detail01_ID)
			Select @save_VersionType = (select VersionType from #temp_detail01 where detail01_ID = @save_detail01_ID)


			Select @save_OSname = (select top 1 OSname from dbo.DBA_serverinfo where SQLname = @save_SQLname)
			If @save_OSname like '% 20%'
			   begin
				Select @charpos = charindex(' 20', @save_OSname)
				IF @charpos <> 0
				   begin
					Select @save_OSname = substring(@save_OSname, @charpos, 50)
				   end


				Select @save_SQLver = (select top 1 SQLver from dbo.DBA_serverinfo where SQLname = @save_SQLname)
				If @save_SQLver like '%x64%' and @save_OSname not like '%x64%'
				   begin
					Select @save_OSname = @save_OSname + 'x64'
				   end
			   end
			Else
			   begin
				Select @charpos = charindex('Standard', @save_OSname)
				IF @charpos <> 0
				   begin
					Select @save_OSname = substring(@save_OSname, @charpos, 50)
				   end
				Select @charpos = charindex('Enterprise', @save_OSname)
				IF @charpos <> 0
				   begin
					Select @save_OSname = substring(@save_OSname, @charpos, 50)
				   end
			   end


			Select @save_OSname = replace(@save_OSname, ',', '')
			Select @save_OSname = ltrim(@save_OSname)


			Select @miscprint = convert(char(20), @save_servername) + '  ' + convert(char(25), @save_SQLname) + '  ' + convert(char(30), @save_OSname) + '  ' + convert(char(15), @save_Version) + '  ' + convert(char(21), @save_VersionType)
			Print  @miscprint


			--  check for more rows
			delete from #temp_detail01 where detail01_ID = @save_detail01_ID
			If (select count(*) from #temp_detail01) > 0
			   begin
				goto detail01
			   end


		   end


	Print ''
	Print ''


	--  check for more rows to process
	delete from #temp_BackupInfo where License = @hold_License


	If (select count(*) from #temp_BackupInfo) > 0
	   begin
		goto Start01
	   end


   end


-----------------  Finalizations  ------------------
label99:


Print  ' '
Print  '/*******************************************************************'
Select @miscprint = '         END OF REPORT - FOR SERVER: ' + @@servername
Print  @miscprint
Print  '*******************************************************************/'
Print  ' '


drop table #temp_BackupInfo
drop table #temp_detail01
GO
GRANT EXECUTE ON  [dbo].[dbasp_REPORTcomp_backup] TO [public]
GO
