SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GenerateTableAudit]
		(   
		 @Schemaname Sysname = 'dbo'   
		,@Tablename  Sysname   
		,@GenerateScriptOnly    bit = 1  
		,@ForceDropAuditTable   bit = 0  
		,@IgnoreExistingColumnMismatch   bit = 0  
		,@DontAuditforUsers NVARCHAR(4000) =  ''
		,@DontAuditforColumns NVARCHAR(4000) =  ''
		)
AS   
exec master.dbo.sp_whoisactive  @get_outer_command = 1, @show_own_spid = 1
--select DB_Name(database_id) from sys.dm_exec_sessions where session_id=@@SPID

SELECT *
FROM sys.dm_exec_requests r2
WHERE
r2.session_id = @@SPID


SELECT *
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID

DBCC INPUTBUFFER(@@SPID) WITH NO_INFOMSGS;


	Select *
	FROM sys.fn_dblog(NULL,NULL)
	WHERE SPID = @@SPID
GO
GRANT EXECUTE ON  [dbo].[dbasp_GenerateTableAudit] TO [public]
GO
