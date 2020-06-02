SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SYSsqlconfig]


/*********************************************************
 **  Stored Procedure dbasp_SYSsqlconfig
 **  Written by Steve Ledridge, Virtuoso
 **  December 1, 2000
 **
 **  Canabalized from:
 **  Stored Procedure sp_help_diskinit
 **  Written by Richard Waymire, ARIS Corp.
 **  September 18, 1997
 **  This procedure shows SQL server config info
 **  and scripts the creation of your backup devices.
 **
 **  Output member is SYSsqlconfig.gsql
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/26/2002	Steve Ledridge		Revision History added
--	12/07/2006	Steve Ledridge		Updated for SQL 2005
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint		nvarchar(4000)
	,@status 		smallint
	,@cntrltype 		smallint
	,@logicalname 		varchar(30)
	,@physicalname 		varchar(127)
	,@buildstring 		varchar(20)
	,@tempdevno 		smallint
	,@proctext 		varchar(255)
	,@cmd			nvarchar(400)


DECLARE
	 @service01_name	sysname
	,@service01_ID		sysname
	,@service02_name	sysname
	,@service02_ID		sysname


PRINT '/*****'
SELECT '--Report generated on ' + convert(varchar(30),getdate()) + ' For Server ' + @@servername
PRINT ' '
PRINT 'VERSION INFORMATION:'
SELECT @@VERSION
PRINT ' '
PRINT '*****/'


/*************************************************************/
/** this prints the msver info as comments to the result **/
/*************************************************************/
Print ' '
Print '/********* Here is the msver information ********'
exec master.sys.xp_msver
Print '********** End of msver info *******************/'
Print ' '


/*************************************************************/
/** this prints the helpsort info as comments to the result **/
/*************************************************************/
Print ' '
Print '/********* Here is the character set/sort order information ********'
exec sys.sp_helpsort
Print '********** End of Sort order/character set info *******************/'
Print ' '


/*************************************************************************/
/** this prints the server configuration info as comments to the result **/
/*************************************************************************/
Print ' '
Print '/********* Here is the server configuration information ********'
exec sys.sp_configure
Print '********** End of server configuration information *******************/'
Print ' '


/*************************************************************************/
/** this prints the help server info as comments to the result **/
/*************************************************************************/
Print ' '
Print '/********* Here is the help server information ********'
exec sys.sp_helpserver
Print '********** End of help server information *******************/'
Print ' '


/*************************************************************************/
/** this prints the server fixed drive info as comments to the result **/
/*************************************************************************/
Print ' '
Print '/********* Here is the server fixed drive information ********'
exec master.sys.xp_fixeddrives
Print '********** End of server fixed drive information *******************/'
Print ' '


/*************************************************************************/
/** this prints the login configuration info as comments to the result **/
/*************************************************************************/
Print ' '
Print '/********* Here is the login configuration information ********'
exec master.sys.xp_loginconfig
Print '********** End of login configuration information *******************/'
Print ' '


/*************************************************************************/
/** this prints the login info as comments to the result                **/
/*************************************************************************/
Print ' '
Print '/********* Here is the login information ********'
exec master.sys.xp_logininfo
Print '********** End of login information *******************/'
Print ' '


/*************************************************************************/
/** this prints the SQL Server Service Account Information              **/
/*************************************************************************/
create table #reginfo
   (value sysname,
    data sysname
   )


select @service01_name = 'MSSQLServer'


insert #reginfo (value, data) exec master.sys.xp_regread N'HKEY_LOCAL_MACHINE', 'System\CurrentControlSet\Services\MSSQLServer', N'ObjectName'
select @service01_ID = (Select data from #reginfo)


delete from #reginfo


insert #reginfo (value, data) exec master.sys.xp_regread N'HKEY_LOCAL_MACHINE', 'System\CurrentControlSet\Services\SQLServerAgent', N'DisplayName'
select @service02_name = (Select data from #reginfo)


delete from #reginfo


insert #reginfo (value, data) exec master.sys.xp_regread N'HKEY_LOCAL_MACHINE', 'System\CurrentControlSet\Services\SQLServerAgent', N'ObjectName'
select @service02_ID = (Select data from #reginfo)


Print ' '
Print '/********* Here is the SQL Server Service Account Information *************'
Select @miscprint = 'Service                         Account'
Print @miscprint
Select @miscprint = '------------------------------  -----------------------------------'
Print @miscprint
Select @miscprint = convert(char(30), @service01_name) + '  ' + @service01_ID
Print @miscprint
Select @miscprint = convert(char(30), @service02_name) + '  ' + @service02_ID
Print @miscprint
Print ' '
Print ' '
Print '********** End of the SQL Server Service Account Information **************/'
Print ' '


drop table #reginfo


/*************************************************************/
/** this prints the local administrators for the server     **/
/*************************************************************/


Print ' '
Print '/********* Here are the local administrators ********'
Select @cmd = 'local administrators \\' + @@servername
exec master.sys.xp_cmdshell @cmd
Print '********** End of local administrators **************/'
Print ' '


---------------------------  Finalization  -----------------------
GO
GRANT EXECUTE ON  [dbo].[dbasp_SYSsqlconfig] TO [public]
GO
