SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_REPORTsecurityaudit]


/*********************************************************
 **  Stored Procedure dbasp_REPORTsecurityaudit
 **  Written by Steve Ledridge, Virtuoso
 **  October 29, 2015
 **
 **  This dbasp is set up to create a report documenting
 **  SQL security on a specific SQL server.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	10/29/2015	Steve Ledridge		New process
--	======================================================================================


-----------------  declares  ------------------


DECLARE
	 @miscprint			varchar(255)


----------------  initial values  -------------------


create table #Login_Audit
(A nvarchar (500),B nvarchar (500)default (''),C nvarchar (200)default (''), D nvarchar (200)default (''))


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers


   Print  ' '
   Print  '/********************************************************************'
   Select @miscprint = '   SQL SERVER SECURITY AUDIT Report '
   Print  @miscprint
   Print  ' '
   Select @miscprint = '-- Generated on ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
   Print  @miscprint
   Print  '********************************************************************/'


/*

SQL Server Login Audit

Developed by: Mayur H. Sanap
Date:        25 oct 2012

This query will generate a report in one table having separate details for each task
like sql server & datbase roles, orphan users details get separately & orphan logins details separately.
*/


insert into #Login_Audit  (A,B,C,D)
SELECT
[Security Report] = '-----SQL SERVER SECURITY AUDIT Report-----','---------------','---------------','---------------'

insert into #Login_Audit  (A,B,C,D)
SELECT
[Login count] = 'Total Count of Login','Windows User','SQL server User','Windows Group'


insert into #Login_Audit
select a,b,c,d from
(select count(name)a from sys.syslogins where name not like '%#%') a, -- total count
(select count (name)b from sys.syslogins where name not like '%#%'and isntuser=1) b, --for login is windows user
(select count (name)c from sys.syslogins where name not like '%#%'and isntname=0) c, -- for login is sql server login
(select count (name)d from sys.syslogins where name not like '%#%'and isntgroup=1 )d;

select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit (A,B,C,D)
SELECT
[sysadmin_server role] = '-- SYSADMIN SERVER ROLE ASSIGN TO---','---------------','---------------',''

insert into #Login_Audit  (A,B,C,D)
SELECT
[Sys Admin role] = 'Login name','Type ','Login Status ',''


insert into #Login_Audit (A,B,C)
SELECT a.name as Logins, a.type_desc, case a.is_disabled
when 1 then 'Disable'
when 0 then 'Enable'
End
FROM sys.server_principals a
  INNER JOIN sys.server_role_members b ON a.principal_id = b.member_principal_id
WHERE b.role_principal_id = 3
ORDER BY a.name, a.type_desc


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Fixed_server role] = '-- FIXED SERVER ROLE DETAILS --','---------------','---------------',''

insert into #Login_Audit  (A,B,C,D)
SELECT
[Fixed_server role] = 'ROLE name','Members ','Type ',''


insert into #Login_Audit (A,B,C)
SELECT c.name as Fixed_roleName, a.name as logins ,a.type_desc
FROM sys.server_principals a
  INNER JOIN sys.server_role_members b ON a.principal_id = b.member_principal_id
  INNER JOIN sys.server_principals c ON c.principal_id = b.role_principal_id
--WHERE a.principal_id > 250
ORDER BY c.name, a.name


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Fixed_database_Roles] = '-- FIXED DATABASE ROLES DETAILS --','---------------','---------------','---------------'


insert into #Login_Audit  (A,B,C,D)
SELECT
[Fixed_database_Role] = 'Database Name','Role Name','Member','Type'


insert into #Login_Audit exec master.dbo.sp_MSforeachdb 'use [?]
SELECT db_name()as DBNAME, c.name as DB_ROLE ,a.name as Role_Member, a.type_desc
FROM sys.database_principals a
  INNER JOIN sys.database_role_members b ON a.principal_id = b.member_principal_id
  INNER JOIN sys.database_principals c ON c.principal_id = b.role_principal_id
WHERE a.name <> ''dbo''and c.is_fixed_role=1
order by db_name(), c.name'


select convert(char(40), A), convert(char(30), B), convert(char(50), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


------------ used is_fixed = 0 for non fixed database roles(need to run on each database)
insert into #Login_Audit  (A,B,C,D)
SELECT
[NON_Fixed_database_Roles] = '-- NON FIXED DATABASE ROLES DETAILS --','---------------','---------------','---------------'


insert into #Login_Audit  (A,B,C,D)
SELECT
[Non Fixed_database role] = 'Database Name','Role Name','Member ','Type'


insert into #Login_Audit exec master.dbo.sp_MSforeachdb 'use [?]
SELECT db_name()as DBNAME, c.name as DB_ROLE ,a.name as Role_Member, a.type_desc
FROM sys.database_principals a
  INNER JOIN sys.database_role_members b ON a.principal_id = b.member_principal_id
  INNER JOIN sys.database_principals c ON c.principal_id = b.role_principal_id
WHERE a.name <> ''dbo''and c.is_fixed_role=0
order by db_name(), c.name'


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Server_Level_Permission] = '-- SERVER LEVEL PERMISSION DETAILS --','---------------','---------------', '---------------'


insert into #Login_Audit  (A,B,C,D)
SELECT
[Server permission] = 'Logins','Permission Type','Permission_desc','Status'


insert into #Login_Audit
SELECT b.name,a.type,a.permission_name,a.state_desc
FROM sys.server_permissions a
  INNER JOIN sys.server_principals b ON a.grantee_principal_id = b.principal_id
  --INNER JOIN sys.server_principals b ON b.principal_id = b.role_principal_id
WHERE b.name not like '%#%'
ORDER BY b.name


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[DATABASE_Level_Permission] = '-- DATABASE LEVEL PERMISSION DETAILS ----','---------------','---------------','---------------'


insert into #Login_Audit  (A,B,C,D)
SELECT
[DB permission] = 'Database Name','Login Name','Permission ','Status'


insert into #Login_Audit
 exec master.dbo.sp_MSforeachdb 'use [?]
SELECT db_name () as DBNAME,b.name as users,a.permission_name,a.state_desc
FROM sys.database_permissions a
  INNER JOIN sys.database_principals b ON a.grantee_principal_id = b.principal_id
  where a.class =0 and b.name <> ''dbo'' and b.name <> ''guest''and   b.name not like ''%#%''
  order by db_name(), b.name, a.permission_name'

select convert(char(40), A), convert(char(50), B), convert(char(30), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Password_ Policy_Details] = '--- PASSWORD POLICY DETAILS ----','---------------','---------------','----------------------'


insert into #Login_Audit  (A,B,C,D)
SELECT
[Policy] = 'Users','type','Policy status','Password policy status'


insert into #Login_Audit
SELECT a.name AS SQL_Server_Login,a.type_desc,
CASE b.is_policy_checked
WHEN 1 THEN 'Password Policy Applied'
ELSE
'Password Policy Not Applied'
END AS Password_Policy_Status,
CASE b.is_expiration_checked
WHEN 1 THEN 'Password Expiration Check Applied'
ELSE
'Password Expiration Check Not Applied'
END AS Password_Expiration_Check_Status
FROM sys.server_principals a INNER JOIN sys.sql_logins b
ON a.principal_id = b.principal_id
where a.name not like '%#%'
order by a.name


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Password_ Policy_Details] = '--- LOGIN NON-USE DETAILS ----','---------------','',''


insert into #Login_Audit  (A,B,C,D)
SELECT
[Policy] = 'Logins','Last Date Used','',''


insert into #Login_Audit
select ul.Login_name, convert(nvarchar(30), ul.use_date), '', '' from dbaperf.[dbo].[unused_logins] ul, master.sys.syslogins dp
where ul.Login_name = dp.name
and (ul.use_date is null or ul.use_date < getdate()-90)
and ul.Login_name not like '##%'
and ul.Login_name not like 'dba%'
and ul.Login_name not like '%sqladmin%'
order by  ul.Login_name, ul.use_date


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Orphan_Login_Details] = '--- ORPHAN LOGINS ----','---------------','',''


insert into #Login_Audit  (A,B,C,D)
SELECT
[orphan logine] = 'Logins Name','ID','',''


insert into #Login_Audit (A,B) exec sp_validatelogins

select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Orphan_USERS_Details] = '--- ORPHAN USERS----','','',''


insert into #Login_Audit  (A,B,C,D)
SELECT
[orphan users] = 'User Name','','',''


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit

insert into #Login_Audit (A)
select u.name from master..syslogins l right join
    sysusers u on l.sid = u.sid
    where l.sid is null and issqlrole <> 1 and isapprole <> 1
    and (u.name <> 'INFORMATION_SCHEMA' and u.name <> 'guest'
    and u.name <> 'system_function_schema'and u.name <> 'sys')


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


delete from #Login_Audit


insert into #Login_Audit  (A,B,C,D)
SELECT
[Database_Owner_details] = '--- DATABASE OWENER DETAILS----','---------------','',''

insert into #Login_Audit  (A,B,C,D)
SELECT
[DB owner] = 'Database Name','Owener name','',''

insert into #Login_Audit (A,B)
select name, SUSER_sNAME (owner_sid) from sys.databases order by name asc


select convert(char(40), A), convert(char(40), B), convert(char(40), C), convert(char(40), D) from #Login_Audit


--  Finalization  ------------------------------------------------------------------------------


drop table #Login_Audit
GO
GRANT EXECUTE ON  [dbo].[dbasp_REPORTsecurityaudit] TO [public]
GO
