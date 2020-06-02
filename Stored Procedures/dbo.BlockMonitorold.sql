SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[BlockMonitorold]
(
            @SendResultsInEmail         BIT             = 1
,           @PollingDelayInSeconds      SMALLINT        = 60
,           @recipients                 NVARCHAR(MAX)   = 'DBANotify@${{secrets.DOMAIN_NAME}}'
)
AS
BEGIN


/*
*******************************************************************************
**   Intellectual property of ${{secrets.COMPANY_NAME}} LTD.
**   Copyright 2008-2011 ${{secrets.COMPANY_NAME}} LTD
**   This computer program is protected by copyright law
**   and international treaties.
*******************************************************************************
**
** Object Name: BlockMonitor
** Description: This procedure will be used to check for blocking on the server and send out email
**
** Revision History:
** ------------------------------------------------------------------------------------------------------
** Date          Description
** ------------- -------------------------------------------------
** 8/15/2011     Created
** 9/2/2011      Listed locked object name
*******************************************************************************
*/


    /* Initialize email settings */
    DECLARE     @copy_recipients            VARCHAR(MAX)  = NULL
    ,           @blind_copy_recipients      VARCHAR(MAX)  = NULL
    ,           @subject                    NVARCHAR(255) = 'Block Monitor Alert'
    ,           @body                       NVARCHAR(MAX) = 'There is blocking on server ' + @@SERVERNAME + '.  See attachment for more information.'
    ,           @body_format                VARCHAR(20)   = NULL
    ,           @importance                 VARCHAR(6)    = 'NORMAL'
    ,           @sensitivity                VARCHAR(12)   = 'NORMAL'
    ,           @file_attachments           NVARCHAR(MAX) = NULL
    ,           @query                      NVARCHAR(MAX) = 'SET NOCOUNT ON ; SELECT ''SPID'' + char(9) + ''Chain'' + char(9) + ''blocked'' + char(9) + ''waittime'' + char(9) + ''lastwaittype'' + char(9) + ''uid'' + char(9) + ''cpu'' + char(9) + ''physical_io'' + char(9) + ''memusage'' + char(9) + ''login_time'' + char(9) + ''last_batch'' + char(9) + ''open_tran'' + char(9) + ''status'' + char(9) + ''hostname'' + char(9) + ''program_name'' + char(9) + ''cmd'' + char(9) + ''nt_domain'' + char(9)
 + ''nt_username'' + char(9) + ''loginame'' + char(9) + ''stmt_start'' + char(9) + ''stmt_end'' ; SELECT CAST(spid AS NVARCHAR) + char(9) + CAST(Chain AS NVARCHAR) + char(9) + CAST(blocked AS NVARCHAR) + char(9) + CAST(waittime AS NVARCHAR) + char(9) + CAST(lastwaittype AS NVARCHAR) + char(9) + CAST(uid AS NVARCHAR) + char(9) + CAST(cpu AS NVARCHAR) + char(9) + CAST(physical_io AS NVARCHAR) + char(9) + CAST(memusage AS NVARCHAR) + char(9) + CAST(login_time AS NVARCHAR) + char(9) + CAST(last_batc
h AS NVARCHAR) + char(9) + CAST(open_tran AS NVARCHAR) + char(9) + CAST(status AS NVARCHAR) + char(9) + CAST(hostname AS NVARCHAR) + char(9) + CAST(program_name AS NVARCHAR) + char(9) + CAST(cmd AS NVARCHAR) + char(9) + CAST(nt_domain AS NVARCHAR) + char(9) + CAST(nt_username AS NVARCHAR) + char(9) + CAST(loginame AS NVARCHAR) + char(9) + CAST(stmt_start AS NVARCHAR) + char(9) + CAST(stmt_end AS NVARCHAR) from ##BlockingChain order by Chain; SELECT CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13); SELE
CT ''SPID'' + CHAR(9) + ''DatabaseName'' + CHAR(9) + ''request_status'' + CHAR(9) + ''request_mode'' + CHAR(9) + ''resource_type'' + CHAR(9) + ''LockedObjectID'' + CHAR(9) + ''LockedObjectName'' ; SELECT CAST(SPID AS NVARCHAR(MAX)) + CHAR(9) + DatabaseName + CHAR(9) + CAST(request_status AS NVARCHAR(MAX)) + CHAR(9) + CAST(request_mode AS NVARCHAR(MAX)) + CHAR(9) + resource_type + CHAR(9) + CAST(LockedObjectID AS NVARCHAR(MAX)) + CHAR(9) + CAST(LockedObjectName AS NVARCHAR(MAX)) FROM ##TableLocks
 ; SELECT CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) ; SELECT ''SPID'' + char(9) + ''DatabaseName'' + char(9) + ''SQLText'' ; SELECT CAST(spid AS NVARCHAR) + char(9) + CAST(DatabaseName AS NVARCHAR) + CHAR(9) + CAST(SQLText AS VARCHAR(4000)) from ##BlockingChain ;   '
    ,           @execute_query_database     sysname       = NULL
    ,           @attach_query_result_as_file BIT          = 1
    ,           @query_attachment_filename  NVARCHAR(260) = 'BlockingChain.xls'
    ,           @query_result_header        BIT           = 0
    ,           @query_result_width         INT           = 32000
    ,           @query_result_separator     CHAR(1)       = CHAR(9)
    ,           @exclude_query_output       BIT           = 0
    ,           @append_query_error         BIT           = 0
    ,           @query_no_truncate          BIT           = 1
    ,           @query_result_no_padding    BIT           = 0
    ,           @from_address               VARCHAR(max)  = @@SERVERNAME + '@${{secrets.DOMAIN_NAME}}'
    ,           @reply_to                   VARCHAR(max)  = NULL


    IF OBJECT_ID('tempdb..##BlockingChain') IS NOT NULL
        DROP TABLE ##BlockingChain
    IF OBJECT_ID('tempdb..##TableLocks') IS NOT NULL
        DROP TABLE ##TableLocks

	DECLARE     @HeadBlocker TABLE ( SPID SMALLINT NOT NULL PRIMARY KEY, IsHeadBlocker BIT NOT NULL)

	INSERT      @HeadBlocker ( SPID, IsHeadBlocker )
	SELECT      DISTINCT
	            R.spid
	,           1   /* Head blocker */
	FROM        sys.sysprocesses            R WITH (NOLOCK)
	WHERE       blocked                     =	0	/* blocking spids are > 0  */
	AND         EXISTS  (   SELECT		*
                            FROM        sys.sysprocesses            R2 WITH (NOLOCK)
                            WHERE       R2.blocked                  =   R.spid
                            AND         R2.blocked                  <>  R2.spid
                            AND         R2.hostname                 NOT LIKE '%zenoss%'
                            AND         R2.spid                     >   50  /* Ignore blocked admin processes */ )


    IF EXISTS ( SELECT * FROM @HeadBlocker )
    BEGIN
        DECLARE @WaitUntilTime      VARCHAR(100)
        SELECT  @WaitUntilTime      =   RIGHT('00' + CAST(DATEPART(HOUR, DATEADD(second, @PollingDelayInSeconds, GETDATE())) AS VARCHAR), 2)+ ':' + RIGHT('00' + CAST(DATEPART(MINUTE, DATEADD(second, @PollingDelayInSeconds, GETDATE())) AS VARCHAR), 2) + ':' + RIGHT('00' + CAST(DATEPART(SECOND, DATEADD(second, @PollingDelayInSeconds, GETDATE())) AS VARCHAR),2)

        WAITFOR TIME @WaitUntilTime /* Wait before rechecking for same blocking chain */


        /* After some time has passed, check again for the same head of chain blocker */
        IF EXISTS   (   SELECT      * /* Head of chain blocker */
	                    FROM        sys.sysprocesses            R WITH (NOLOCK)
                        JOIN        @HeadBlocker                W
                        ON          W.SPID                      =   R.spid
	                    WHERE       blocked                     =	0	/* blocking spids are > 0  */
	                    AND         EXISTS  (   SELECT		*
                                                FROM        sys.sysprocesses            R2  WITH (NOLOCK)
                                                WHERE       R2.blocked                  =   R.spid
                                                AND         R2.blocked                  <>  R2.spid
                                                /* AND         R2.spid                     >   50 */ /* Ignore admin processes */ )
                    )
        BEGIN

	        SELECT      'Blocked'                   AS Chain        /* Blocked processes query and stats */
	        ,           R.*
	        ,           D.name                      AS DatabaseName
    	    ,			LEFT(ST.text, 8000)		    AS SQLText
           INTO        ##BlockingChain
    	    FROM        sys.sysprocesses            R       WITH (NOLOCK)
            JOIN        @HeadBlocker                W
            ON          W.SPID                      =   R.blocked
            JOIN        sys.sysdatabases            D       WITH (NOLOCK)
            ON          R.dbid                      =   D.dbid
	        CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) ST
            UNION
	        SELECT      'Blocker'                   AS Chain        /* Head blocker query and stats */
	        ,           R.*
	        ,           D.name                      AS DatabaseName
    	    ,			LEFT(ST.text, 8000)		    AS SQLText
    	    FROM        sys.sysprocesses            R       WITH (NOLOCK)
            JOIN        @HeadBlocker                W
            ON          W.SPID                      =   R.spid
            JOIN        sys.sysdatabases            D       WITH (NOLOCK)
            ON          R.dbid                      =   D.dbid
	        CROSS APPLY sys.dm_exec_sql_text(R.sql_handle) ST


            /* Gather table locks from blocking and blocked spids */
            SELECT      TOP 10
                        'SPID'              =   request_session_id
            ,           'DatabaseName'      =   D.name
            ,           request_status
            ,           request_mode
            ,           resource_type
            ,           resource_associated_entity_id   AS LockedObjectID
            ,           CAST('' AS sysname) AS LockedObjectName
            INTO        ##TableLocks
            FROM        sys.dm_tran_locks  L    WITH (NOLOCK)
            JOIN        sys.sysdatabases   D    WITH (NOLOCK)
            ON          L.resource_database_id  =   D.dbid
            AND         L.resource_type         =   'OBJECT'
            JOIN        ( SELECT DISTINCT spid FROM ##BlockingChain ) AS C
            ON          L.request_session_id    =   C.spid


            /* get locked table name */
            DECLARE     @SQL varchar(max)
            SELECT      @SQL = ''

            SELECT      TOP 1
                        @SQL = 'UPDATE W SET LockedObjectName = O.name FROM ##TableLocks W JOIN ' + L.DatabaseName + '.sys.objects O WITH (NOLOCK) ON W.LockedObjectID = O.object_id '
            FROM        ##TableLocks        L
            WHERE       LockedObjectName    =   ''

            IF @SQL <> ''
                EXEC        (@SQL)


            SELECT      @SQL = ''

            SELECT      TOP 1
                        @SQL = 'UPDATE W SET LockedObjectName = O.name FROM ##TableLocks W JOIN ' + L.DatabaseName + '.sys.objects O WITH (NOLOCK) ON W.LockedObjectID = O.object_id '
            FROM        ##TableLocks        L
            WHERE       LockedObjectName    =   ''

            IF @SQL <> ''
                EXEC        (@SQL)


            SELECT      @SQL = ''

            SELECT      TOP 1
                        @SQL = 'UPDATE W SET LockedObjectName = O.name FROM ##TableLocks W JOIN ' + L.DatabaseName + '.sys.objects O WITH (NOLOCK) ON W.LockedObjectID = O.object_id '
            FROM        ##TableLocks        L
            WHERE       LockedObjectName    =   ''

            IF @SQL <> ''
                EXEC        (@SQL)


            IF @SendResultsInEmail = 1
            AND EXISTS ( SELECT * FROM ##BlockingChain )
            BEGIN
                /* Email report as query attachment*/
                EXEC msdb.dbo.sp_send_dbmail    @Profile_Name               = null,
                                                @recipients                 = @recipients,
                                                @copy_recipients            = @copy_recipients,
                             @blind_copy_recipients      = @blind_copy_recipients,
                                                @from_address               = @from_address,
                                                @subject                    = @subject,
                                                @body                       = @body,
                                                @body_format                = @body_format,
                                                @sensitivity                = @Sensitivity,
                                                @file_attachments           = @file_attachments,
                                                @query                      = @query,
                                                @attach_query_result_as_file = @attach_query_result_as_file,
                                                @query_result_header        = @query_result_header,
                                                @query_result_width         = @query_result_width,
                                                @query_attachment_filename  = @query_attachment_filename,
                                                @query_no_truncate          = @query_no_truncate
            END
            ELSE
            BEGIN
                /* If not emailed, print out */
                SELECT * FROM ##BlockingChain
                SELECT * FROM ##TableLocks
            END
        END /* Check if blocking still exists after some time */
    END /* SELECT * FROM @HeadBlocker */


    /* Query these tables for status of email msdb.dbo.sysmail_sentitems, msdb.dbo.sysmail_allitems, msdb.dbo.sysmail_faileditems, msdb.dbo.sysmail_event_log) */

END /* Proc */
GO
GRANT EXECUTE ON  [dbo].[BlockMonitorold] TO [public]
GO
