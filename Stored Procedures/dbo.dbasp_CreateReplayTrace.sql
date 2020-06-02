SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_CreateReplayTrace]
		(
		@Path			sysname
		,@MaxFileSize		bigint	= 100
		,@FileCount		int		= NULL
		,@Minutes			int		= NULL
		,@TraceId			int		= NULL OUTPUT
		)
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


DECLARE @StopTime DATETIME = DATEADD(MINUTE, @Minutes, CURRENT_TIMESTAMP);


DECLARE @RC int, @EventClass int;


EXEC @RC = sp_trace_create
			@TraceId OUTPUT
			,@options	= 2                   -- file rollover
			,@tracefile	= @Path
			,@maxfilesize	= @MaxFileSize   -- mb
			,@stoptime	= @StopTime
			,@filecount	= @FileCount;

IF (@RC <> 0) OR (@@ERROR <> 0)
BEGIN;
 SELECT @RC AS ReturnCode, @@ERROR AS Error; RETURN(1);
END;


DECLARE @on bit = 1;

-- CursorClose
exec sp_trace_setevent @TraceId, 78, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 78, 11, @on -- LoginName
exec sp_trace_setevent @TraceId, 78, 12, @on -- SPID
exec sp_trace_setevent @TraceId, 78, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 78, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 78, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 78, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 78, 10, @on -- ApplicationName
exec sp_trace_setevent @TraceId, 78, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 78, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 78, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 78, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 78, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 78, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 78, 60, @on	-- IsSystem


-- CursorExecute
exec sp_trace_setevent @TraceId, 74, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 74, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 74, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 74, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 74, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 74, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 74, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 74, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 74, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 74, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 74, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 74, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 74, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 74, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 74, 60, @on	-- IsSystem


-- CursorOpen
exec sp_trace_setevent @TraceId, 53, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 53, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 53, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 53, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 53, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 53, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 53, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 53, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 53, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 53, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 53, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 53, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 53, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 53, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 53, 60, @on	-- IsSystem


-- CursorPrepare
exec sp_trace_setevent @TraceId, 70, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 70, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 70, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 70, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 70, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 70, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 70, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 70, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 70, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 70, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 70, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 70, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 70, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 70, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 70, 60, @on	-- IsSystem


-- CursorUnprepare
exec sp_trace_setevent @TraceId, 77, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 77, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 77, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 77, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 77, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 77, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 77, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 77, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 77, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 77, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 77, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 77, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 77, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 77, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 77, 60, @on	-- IsSystem


-- Attention
exec sp_trace_setevent @TraceId, 16, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 16, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 16, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 16, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 16, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 16, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 16, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 16, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 16, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 16, 15, @on	-- EndTime
exec sp_trace_setevent @TraceId, 16, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 16, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 16, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 16, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 16, 60, @on	-- IsSystem


-- Audit Login
exec sp_trace_setevent @TraceId, 14, 1, @on	-- TextData
exec sp_trace_setevent @TraceId, 14, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 14, 2, @on	-- BinaryData
exec sp_trace_setevent @TraceId, 14, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 14, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 14, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 14, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 14, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 14, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 14, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 14, 14, @on -- StartTime
exec sp_trace_setevent @TraceId, 14, 21, @on	-- EventSubClass
exec sp_trace_setevent @TraceId, 14, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 14, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 14, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 14, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 14, 60, @on	-- IsSystem


-- Audit Logout
exec sp_trace_setevent @TraceId, 15, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 15, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 15, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 15, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 15, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 15, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 15, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 15, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 15, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 15, 15, @on	-- EndTime
exec sp_trace_setevent @TraceId, 15, 21, @on	-- EventSubClass
exec sp_trace_setevent @TraceId, 15, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 15, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 15, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 15, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 15, 60, @on	-- IsSystem


-- ExistingConnection
exec sp_trace_setevent @TraceId, 17, 1, @on	-- TextData
exec sp_trace_setevent @TraceId, 17, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 17, 2, @on	-- BinaryData
exec sp_trace_setevent @TraceId, 17, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 17, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 17, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 17, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 17, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 17, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 17, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 17, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 17, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 17, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 17, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 17, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 17, 60, @on	-- IsSystem


-- RPC:OutputParameter
exec sp_trace_setevent @TraceId, 100, 1, @on	-- TextData
exec sp_trace_setevent @TraceId, 100, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 100, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 100, 11,@on	-- LoginName
exec sp_trace_setevent @TraceId, 100, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 100, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 100, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 100, 10,@on	-- HostName
exec sp_trace_setevent @TraceId, 100, 12,@on	-- SPID
exec sp_trace_setevent @TraceId, 100, 14,@on	-- StartTime
exec sp_trace_setevent @TraceId, 100, 26,@on	-- ServerName
exec sp_trace_setevent @TraceId, 100, 35,@on	-- DatabaseName
exec sp_trace_setevent @TraceId, 100, 49,@on	-- RequestID
exec sp_trace_setevent @TraceId, 100, 51,@on	-- EventSequence
exec sp_trace_setevent @TraceId, 100, 60,@on	-- IsSystem


-- RPC:Completed
exec sp_trace_setevent @TraceId, 10, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 10, 2, @on	-- BinaryData
exec sp_trace_setevent @TraceId, 10, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 10, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 10, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 10, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 10, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 10, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 10, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 10, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 10, 15, @on	-- EndTime
exec sp_trace_setevent @TraceId, 10, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 10, 31, @on	-- Error
exec sp_trace_setevent @TraceId, 10, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 10, 48, @on	-- RowCounts
exec sp_trace_setevent @TraceId, 10, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 10, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 10, 60, @on	-- IsSystem
exec sp_trace_setevent @TraceId, 10, 22, @on	-- ObjectID
exec sp_trace_setevent @TraceId, 10, 34, @on	-- ObjectName


-- RPC:Starting
exec sp_trace_setevent @TraceId, 11, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 11, 2, @on	-- BinaryData
exec sp_trace_setevent @TraceId, 11, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 11, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 11, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 11, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 11, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 11, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 11, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 11, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 11, 26, @on	-- Handle
exec sp_trace_setevent @TraceId, 11, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 11, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 11, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 11, 60, @on	-- IsSystem
exec sp_trace_setevent @TraceId, 11, 22, @on	-- ObjectID
exec sp_trace_setevent @TraceId, 11, 34, @on	-- ObjectName


-- Exec Prepared SQL
exec sp_trace_setevent @TraceId, 72, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 72, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 72, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 72, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 72, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 72, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 72, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 72, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 72, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 72, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 72, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 72, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 72, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 72, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 72, 60, @on	-- IsSystem


-- PrepareSQL
exec sp_trace_setevent @TraceId, 71, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 71, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 71, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 71, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 71, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 71, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 71, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 71, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 71, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 71, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 71, 33, @on	-- Handle
exec sp_trace_setevent @TraceId, 71, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 71, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 71, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 71, 60, @on	-- IsSystem


-- SQL:BatchCompleted
exec sp_trace_setevent @TraceId, 12, 1, @on	-- TextData
exec sp_trace_setevent @TraceId, 12, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 12, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 12, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 12, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 12, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 12, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 12, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 12, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 12, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 12, 15, @on	-- EndTime
exec sp_trace_setevent @TraceId, 12, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 12, 31, @on	-- Error
exec sp_trace_setevent @TraceId, 12, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 12, 48, @on	-- RowCounts
exec sp_trace_setevent @TraceId, 12, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 12, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 12, 60, @on	-- IsSystem
exec sp_trace_setevent @TraceId, 12, 22, @on	-- ObjectID
exec sp_trace_setevent @TraceId, 12, 34, @on	-- ObjectName


-- SQL:BatchStarting
exec sp_trace_setevent @TraceId, 13, 1, @on	-- TextData
exec sp_trace_setevent @TraceId, 13, 9, @on	-- ClientProcessID
exec sp_trace_setevent @TraceId, 13, 3, @on	-- DatabaseID
exec sp_trace_setevent @TraceId, 13, 11, @on	-- LoginName
exec sp_trace_setevent @TraceId, 13, 6, @on	-- NTUserName
exec sp_trace_setevent @TraceId, 13, 7, @on	-- NTDomainName
exec sp_trace_setevent @TraceId, 13, 8, @on	-- HostName
exec sp_trace_setevent @TraceId, 13, 10, @on	-- ApplicationName
exec sp_trace_setevent @TraceId, 13, 12, @on	-- SPID
exec sp_trace_setevent @TraceId, 13, 14, @on	-- StartTime
exec sp_trace_setevent @TraceId, 13, 26, @on	-- ServerName
exec sp_trace_setevent @TraceId, 13, 35, @on	-- DatabaseName
exec sp_trace_setevent @TraceId, 13, 49, @on	-- RequestID
exec sp_trace_setevent @TraceId, 13, 51, @on	-- EventSequence
exec sp_trace_setevent @TraceId, 13, 60, @on	-- IsSystem
exec sp_trace_setevent @TraceId, 13, 22, @on	-- ObjectID
exec sp_trace_setevent @TraceId, 13, 34, @on	-- ObjectName


/*
sp_trace_setfilter @TraceId, @columnid, @logical_operator, @comparison_operator, @value ;

@logical_operator AND (0) or OR (1)

@comparison_operator
0 = Equal, 1 = Not equal, 2 = Greater than, 3 = Less than, 4 = Greater than or equal,
5 = Less than or equal, , 6 = Like, 7 = Not like
*/


-- Exclude ApplicationName
EXEC sp_trace_setfilter @TraceId, 10, 0, 7, N'SQL Server Profiler';
--EXEC sp_trace_setfilter @TraceId, 10, 0, 7, N'Replication Distribution Agent';

-- Exclude TextData
--EXEC sp_trace_setfilter @TraceId, 1, 0, 7, N'exec sp_reset_connection%';

-- Exclude HostName
--EXEC sp_trace_setfilter @TraceId, 8, 0, 7, @@servername;


-- Include DatabaseName
--EXEC sp_trace_setfilter @TraceId, 35, 0, 6, N'BillingDWH';


--EXCLUDE Databases
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'master';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'model';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'msdb';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'tempdb';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'DBAOps';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'dbaperf';
EXEC sp_trace_setfilter @TraceId, 35, 0, 7, N'DBAOps';

-- EXCLUDE CURRENT LOGIN
DECLARE	@LoginName	SYSNAME
SET		@LoginName	= ORIGINAL_LOGIN()
EXEC sp_trace_setfilter @TraceId, 11, 0, 7, @LoginName;


-- Start trace
EXEC sp_trace_setstatus @TraceId, 1 ;


SELECT TraceID = @TraceId;
RETURN(0);
GO
GRANT EXECUTE ON  [dbo].[dbasp_CreateReplayTrace] TO [public]
GO
