SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[getUIREPORTcomp_backup]


/*********************************************************
 **  Stored Procedure getUIDeplServersbyGearsID
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  August 27, 2009
 **
 **  This stored procedure is the Web UI version of
 **  dbo.dbasp_REPORTcomp_backup
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	08/27/2009	Steve Ledridge		New report
--	======================================================================================


-----------------  declares  ------------------


declare @tblCount table(rnk int, svrname sysname, sqlname sysname, lic sysname)
declare @tbllicenseVerInfo table (lic sysname, ver sysname)


/****************************************************************
 *                Initialization
 ***************************************************************/
insert into @tbllicenseVerInfo
select
	distinct
	license,
	version
from dbo.Compress_BackupInfo


insert into @tblCount
select
	rank() over(partition by servername order by sqlname, servername),
	servername,
	sqlname,
	license
from dbo.Compress_BackupInfo
order by servername


/****************************************************************
 *                MainLine
 ***************************************************************/


select
	li.VendorName,
	li.Type 'Version',
	vi.ver 'Product Version',
	tc.lic 'License Key',
	LicStatus =	case li.Active
					when 'y' then 'Active'
					when 'n' then 'In Active'
				end,
	li.LicenseNum 'License Allocated',
	count(*)'Licenses Used',
	(li.LicenseNum - count(*)) 'License Avaliable'
from @tblCount as tc
join dbo.licenseInfo as li on tc.lic = li.LicenseKey
join @tbllicenseVerInfo as vi on vi.Lic = tc.lic
where rnk = 1
group by
	tc.lic,
	li.VendorName,
	vi.ver,
	li.Type,
	li.LicenseNum,
	li.Active
GO
GRANT EXECUTE ON  [dbo].[getUIREPORTcomp_backup] TO [public]
GO
