SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_Install_Memory]


/*********************************************************
 **  Stored Procedure dbasp_HC_Install_Memory
 **  Written by Steve Ledridge, Virtuoso
 **  November 04, 2014
 **  This procedure runs the Install_Config portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	11/05/2014	Steve Ledridge		New process.
--	11/26/2014	Steve Ledridge		Set max reserved memory for OS at 16gb.
--	03/02/2015	Steve Ledridge		Set Multi-instance flag based on active instances.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--check minimum memory
--check max memory settings
--check MAXdop settings
--check lock pages in memory setting


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@save_test				nvarchar(4000)
	,@save_maxdop 				sysname
	,@save_maxdop_int 			INT
	,@save_Memory				INT
	,@save_memory_float			FLOAT
	,@save_memory_varchar			sysname
	,@save_SQLmax_memory			NVARCHAR(20)
	,@save_SQLmax_memory_int		INT
	,@save_OSmemory				INT
	,@save_OSmemory_vch			sysname
	,@save_multi_instance_flag		CHAR(1)
	,@save_multi_count			smallint
	,@save_awe				NCHAR(1)
	,@save_CPUcore 				sysname
	,@save_SQLSvcAcct			sysname
	,@save_active_instances			smallint
	,@save_InstName				sysname


declare  @hyperthreadingRatio			bit
	,@logicalCPUs				int
	,@HTEnabled				int
	,@physicalCPU				int
	,@SOCKET				int
	,@logicalCPUPerNuma			int
	,@NoOfNUMA				int
	,@MaxDOP				int


----------------  initial values  -------------------
Select @save_multi_instance_flag = 'n'


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


DECLARE @OutputComments TABLE	(
				OutputComment VARCHAR(MAX)
				)


CREATE TABLE #SQLInstances	(
				InstanceID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
				,InstName NVARCHAR(180)
				,Folder NVARCHAR(50)
				,StaticPort INT NULL
				,DynamicPort INT NULL
				,Platform INT NULL
				);


CREATE TABLE #miscTempTable	(
				cmdoutput NVARCHAR(400) NULL
				)


--  Check for multi-instance
Delete from #SQLInstances
INSERT INTO #SQLInstances (InstName, Folder)
EXEC xp_regenumvalues N'HKEY_LOCAL_MACHINE',N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Delete from #SQLInstances where InstName is null
Delete from #SQLInstances where InstName = 'MICROSOFT##SSEE'
--select * from #SQLInstances


Select @save_active_instances = 0
If (select count(*) from #SQLInstances) > 0
   begin
	Select @save_multi_count = (select count(*) from #SQLInstances)
	start_SQLInstances_check01:


	Select @save_InstName = (select top 1 InstName from #SQLInstances)


	If @save_InstName = 'MSSQLSERVER'
	   begin
		If (select top 1 check_detail01 from dbo.HealthCheckLog where HCcat = 'Install_Service' and HCtype = 'SvcState_MSSQLSERVER' order by HC_ID desc) = '4RUNNING'
		   begin
			Select @save_active_instances = @save_active_instances + 1
		   end
	   end
	Else
	   begin
		If (select top 1 check_detail01 from dbo.HealthCheckLog where HCcat = 'Install_Service' and HCtype = 'SvcState_MSSQL$' + @save_InstName order by HC_ID desc) = '4RUNNING'
		   begin
			Select @save_active_instances = @save_active_instances + 1
		   end
	   end


	Delete from #SQLInstances where InstName = @save_InstName
	If (select count(*) from #SQLInstances) > 0
	   begin
		goto start_SQLInstances_check01
	   end
   end


If @save_active_instances > 1
   begin
	Select @save_multi_instance_flag = 'y'
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - Insatll Memory'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--  Get Memory Info
SELECT @save_memory_varchar = (SELECT TOP 1 memory FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ',', '')


IF @save_memory_varchar LIKE '%MB%'
   BEGIN
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'MB', '')
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
	SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
	SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
	   END
	SELECT @save_memory = CONVERT(INT, @save_memory_varchar)
   END
ELSE IF @save_memory_varchar LIKE '%GB%'
   BEGIN
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'GB', '')
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
	SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
	SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
	   END
	SELECT @save_memory_float = CONVERT(FLOAT, @save_memory_varchar)
	SELECT @save_memory = @save_memory_float * 1024.0
   END
ELSE IF @save_memory_varchar LIKE '%KB%'
   BEGIN
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, 'KB', '')
	SELECT @save_memory_varchar = REPLACE (@save_memory_varchar, ' ', '')
	SELECT @save_memory_varchar = RTRIM(LTRIM(@save_memory_varchar))
	SELECT @charpos = CHARINDEX('.', @save_memory_varchar)
	IF @charpos <> 0
	   BEGIN
		SELECT @save_memory_varchar = LEFT(@save_memory_varchar, @charpos-1)
	   END
	SELECT @save_memory = CONVERT(INT, @save_memory_varchar)
	SELECT @save_memory = @save_memory / 1024.0
   END


--  Start Check for minimum memory
Print 'Start Check for minimum memory'
Print ''


Select @save_test = 'SELECT TOP 1 memory FROM DBAOps.dbo.dba_serverinfo'
IF @save_memory < 8190
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'Minimum Memory', 'Fail', 'Medium', @save_test, null, convert(varchar(10), @save_memory), 'Minimum = 8192', getdate())
	goto skip_memory_checks
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'Minimum Memory', 'Pass', 'Medium', @save_test, null, convert(varchar(10), @save_memory), null, getdate())
   END


--  Start Check max memory setting
Print 'Start Check max memory setting'
Print ''


--  Get sql memory
SELECT @save_SQLmax_memory = (SELECT TOP 1 SQLmax_memory FROM DBAOps.dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, ',', '')
SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'MB', '')
SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'GB', '')
SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, 'KB', '')
SELECT @save_SQLmax_memory = REPLACE (@save_SQLmax_memory, ' ', '')
SELECT @save_SQLmax_memory = RTRIM(LTRIM(@save_SQLmax_memory))
SELECT @save_SQLmax_memory_int = CONVERT(INT, @save_SQLmax_memory)


--  Set OS memory value
--  2GB plus 1GB for each 4GB up to 16GB plus 1GB for each 8GB from 16GB up (with max of 16GB)
If @save_memory <= 16384
   begin
	Select @save_OSmemory = 2 + (@save_memory/4096)
	Select @save_OSmemory = @save_OSmemory * 1024
   end
Else
   begin
	Select @save_OSmemory = 2 + 4 + ((@save_memory-16384)/8192)
	Select @save_OSmemory = @save_OSmemory * 1024
   end


If @save_OSmemory > 16384
   begin
	Select @save_OSmemory = 16384
   end


--  Override OS memory if needed
IF EXISTS (SELECT 1 FROM dbo.no_check WHERE NoCheck_type = 'OSmemory')
   BEGIN
	SELECT @save_OSmemory_vch = (SELECT TOP 1 Detail01 FROM dbo.no_check WHERE NoCheck_type = 'OSmemory')
	SELECT @save_OSmemory_vch = RTRIM(LTRIM(@save_OSmemory_vch))
	SELECT @save_OSmemory = CONVERT(INT, @save_OSmemory_vch)
   END


Select @save_test = 'SELECT TOP 1 SQLmax_memory FROM DBAOps.dbo.dba_serverinfo'


If @save_SQLmax_memory_int > 2000000000
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'SQLmax memory', 'Fail', 'High', @save_test, null, convert(varchar(10), @save_SQLmax_memory_int), 'SQL max memory has not been configured.  Should be ' + convert(varchar(10), (@save_memory - @save_OSmemory)), getdate())
	goto skip_memory_checks
   END
Else If @save_multi_instance_flag = 'y'
   BEGIN
	If (@save_SQLmax_memory_int * @save_multi_count) > (@save_memory - @save_OSmemory)
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'SQLmax memory', 'Fail', 'Medium', @save_test, null, convert(varchar(10), @save_SQLmax_memory_int), 'Multi SQL Should be ' + convert(varchar(10), (@save_memory - @save_OSmemory)/@save_multi_count), getdate())
		goto skip_memory_checks
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'SQLmax memory', 'Pass', 'Medium', @save_test, null, convert(varchar(10), @save_SQLmax_memory_int), 'Multi SQL Instances', getdate())
	   END
   END
Else If @save_SQLmax_memory_int > (@save_memory - @save_OSmemory)
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'SQLmax memory', 'Fail', 'Medium', @save_test, null, convert(varchar(10), @save_SQLmax_memory_int), 'Should be ' + convert(varchar(10), (@save_memory - @save_OSmemory)), getdate())
	goto skip_memory_checks
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'SQLmax memory', 'Pass', 'Medium', @save_test, null, convert(varchar(10), @save_SQLmax_memory_int), null, getdate())
   END


skip_memory_checks:


--  Start check awe
Print 'Start check awe'
Print ''


SELECT @save_awe = (SELECT TOP 1 awe_enabled FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)


Select @save_test = 'SELECT TOP 1 awe_enabled FROM dbo.dba_serverinfo'
IF @@version LIKE '%x64%'
   BEGIN
	IF @save_awe = 'y'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Warning', 'Low', @save_test, null, @save_awe, 'not needed for x64', getdate())
		goto skip_awe_checks
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Pass', 'Low', @save_test, null, @save_awe, null, getdate())
	   END
   END
ELSE IF @save_memory < 4100
   BEGIN
	IF @save_awe = 'y'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Fail', 'Low', @save_test, null, @save_awe, 'memory too low for this setting', getdate())
		goto skip_awe_checks
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Pass', 'Low', @save_test, null, @save_awe, null, getdate())
	   END
   END
ELSE
   BEGIN
	IF @save_awe = 'y'
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Pass', 'Low', @save_test, null, @save_awe, null, getdate())
	   END
	ELSE
	   BEGIN
		insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'awe_enabled', 'Fail', 'Low', @save_test, null, @save_awe, 'Should be set to Y', getdate())
		goto skip_awe_checks
	   END
   END


skip_awe_checks:


--  Start check MAXdop settings
Print 'Start check MAXdop settings'
Print ''


SELECT @save_maxdop = (SELECT MAXdop_value FROM dbo.dba_serverinfo WHERE sqlname = @@SERVERNAME)
SELECT @save_CPUcore = (SELECT CPUcore FROM dba_serverinfo WHERE sqlname = @@SERVERNAME)


Select @save_test = 'SELECT MAXdop_value FROM dbo.dba_serverinfo'


SELECT @save_maxdop = LTRIM(@save_maxdop)
SELECT @charpos = CHARINDEX(' ', @save_maxdop)
IF @charpos <> 0
   BEGIN
	SELECT @save_maxdop = LEFT(@save_maxdop, @charpos-1)
   END


SELECT @save_CPUcore = LTRIM(@save_CPUcore)
SELECT @charpos = CHARINDEX(' ', @save_CPUcore)
IF @charpos <> 0
   BEGIN
	SELECT @save_CPUcore = LEFT(@save_CPUcore, @charpos-1)
   END


IF @save_maxdop = 0 AND ISNUMERIC(@save_maxdop) = 1 AND ISNUMERIC(@save_CPUcore) = 1
   BEGIN
	SELECT @save_maxdop_int = CONVERT(INT,@save_CPUcore)/4
	IF @save_maxdop_int = 0
	   BEGIN
		SELECT @save_maxdop_int = 1
	   END

	IF @save_maxdop_int > 8
	   BEGIN
		SELECT @save_maxdop_int = 8
	   END


	SELECT @cmd = 'EXEC sp_configure ''max degree of parallelism'' , ' + CONVERT(sysname, @save_maxdop_int)
	--Print '		'+@cmd
	EXEC (@cmd)


	SELECT @cmd = 'RECONFIGURE WITH OVERRIDE'
	--Print '		'+@cmd
	EXEC (@cmd)

	Update dbo.dba_serverinfo set MAXdop_value = convert(nvarchar(5), @save_maxdop_int) where sqlname = @@SERVERNAME
   END


--  Set recommendation
select @logicalCPUs = cpu_count -- [Logical CPU Count]
    ,@hyperthreadingRatio = hyperthread_ratio --  [Hyperthread Ratio]
    ,@physicalCPU = cpu_count / hyperthread_ratio -- [Physical CPU Count]
    ,@HTEnabled = case
        when cpu_count > hyperthread_ratio
            then 1
        else 0
        end -- HTEnabled
from sys.dm_os_sys_info
option (recompile);


select @logicalCPUPerNuma = COUNT(parent_node_id) -- [NumberOfLogicalProcessorsPerNuma]
from sys.dm_os_schedulers
where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64
group by parent_node_id
option (recompile);


select @NoOfNUMA = count(distinct parent_node_id)
from sys.dm_os_schedulers -- find NO OF NUMA Nodes
where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64


IF @NoofNUMA > 1 AND @HTEnabled = 0
    SET @MaxDOP= @logicalCPUPerNuma
ELSE IF  @NoofNUMA > 1 AND @HTEnabled = 1
    SET @MaxDOP=round( @NoofNUMA  / @physicalCPU *1.0,0)
ELSE IF @HTEnabled = 0
    SET @MaxDOP=@logicalCPUs
ELSE IF @HTEnabled = 1
    SET @MaxDOP=@physicalCPU


IF @MaxDOP > 8
    SET @MaxDOP=8
IF @MaxDOP = 0
    SET @MaxDOP=1


--PRINT 'logicalCPUs : '         + CONVERT(VARCHAR, @logicalCPUs)
--PRINT 'hyperthreadingRatio : ' + CONVERT(VARCHAR, @hyperthreadingRatio)
--PRINT 'physicalCPU : '         + CONVERT(VARCHAR, @physicalCPU)
--PRINT 'HTEnabled : '           + CONVERT(VARCHAR, @HTEnabled)
--PRINT 'logicalCPUPerNuma : '   + CONVERT(VARCHAR, @logicalCPUPerNuma)
--PRINT 'NoOfNUMA : '            + CONVERT(VARCHAR, @NoOfNUMA)
--PRINT '---------------------------'
--Print 'MAXDOP setting should be : ' + CONVERT(VARCHAR, @MaxDOP)


SELECT @save_maxdop = (SELECT MAXdop_value FROM dbo.dba_serverinfo WHERE sqlname = @@SERVERNAME)
SELECT @save_maxdop = LTRIM(@save_maxdop)
SELECT @charpos = CHARINDEX(' ', @save_maxdop)
IF @charpos <> 0
   BEGIN
	SELECT @save_maxdop = LEFT(@save_maxdop, @charpos-1)
   END


IF @save_maxdop > 8 AND ISNUMERIC(@save_maxdop) = 1
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'MAXdop', 'Fail', 'Low', @save_test, null, @save_maxdop, 'Maximum is 8', getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'MAXdop', 'Pass', 'Low', @save_test, null, @save_maxdop, 'Recommend ' + CONVERT(VARCHAR, @MaxDOP), getdate())
   END


--  Start check lock pages in memory setting
Print 'Start check lock pages in memory setting'
Print ''


SELECT @save_SQLSvcAcct = (SELECT TOP 1 SQLSvcAcct FROM dbo.dba_serverinfo WITH (NOLOCK) WHERE sqlname = @@SERVERNAME)
SELECT @cmd = 'accesschk.exe /accepteula -q -a SeLockMemoryPrivilege'


DELETE FROM #miscTempTable
INSERT INTO #miscTempTable EXEC master.sys.xp_cmdshell @cmd--, no_output
DELETE FROM #miscTempTable WHERE cmdoutput IS NULL
--select * from #miscTempTable


Select @save_test = 'accesschk.exe /accepteula -q -a SeLockMemoryPrivilege'


IF exists (select 1 from #miscTempTable WHERE cmdoutput LIKE '%' + @save_SQLSvcAcct + '%')
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'LockMemoryPrivilege', 'Pass', 'Low', @save_test, null, @save_SQLSvcAcct, null, getdate())
   END
ELSE
   BEGIN
	insert into [dbo].[HealthCheckLog] values ('Install_Memory', 'LockMemoryPrivilege', 'Warning', 'Low', @save_test, null, @save_SQLSvcAcct, 'LockMemoryPrivilege needs to be granted for the current SQL service account.', getdate())
   END


Print '--select * from [dbo].[HealthCheckLog] where HCcat = ''Install_Memory'' and Check_date > getdate()-.02'
Print ''


--  Finalization  ------------------------------------------------------------------------------


label99:


drop TABLE #SQLInstances
drop TABLE #miscTempTable
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_Install_Memory] TO [public]
GO
