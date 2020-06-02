SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_sendmail]
				(
				@recipients						nvarchar(500) = null
				,@copy_recipients				nvarchar(500) = null
				,@blind_copy_recipients			nvarchar(500) = null
				,@stage_recipients				nvarchar(500) = null
				,@stage_copy_recipients			nvarchar(500) = null
				,@stage_blind_copy_recipients	nvarchar(500) = null
				,@test_recipients				nvarchar(500) = null
				,@test_copy_recipients			nvarchar(500) = null
				,@test_blind_copy_recipients	nvarchar(500) = null
				,@subject						nvarchar(255) = null
				,@attachments					nvarchar(4000) = null
				,@message						nvarchar(4000) = null
				,@outpath						nvarchar(255) = null)


/*********************************************************
 **  Stored Procedure dbasp_sendmail
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 1, 2002
 **
 **  This dbasp is set up to create a parameter file
 **  that is used in the DBA SQL Mail process.  The output
 **  file has an extension of 'sml', and is written to the
 **  dba_mail folder of the local server.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/01/2002	Steve Ledridge		New sproc
--	09/24/2002	Steve Ledridge		Modified dbasql share example
--	11/06/2002	Steve Ledridge		Changed osql -w to 4000
--	02/17/2003	Steve Ledridge		Added logic to drop temp table command
--	04/16/2003	Steve Ledridge		Attachments can now be up to 4000 bytes
--	04/18/2003	Steve Ledridge		Changes for new instance share names.
--	04/28/2003	Steve Ledridge		Global temp table (##) name now unique
--	05/06/2003	Steve Ledridge		Added wait for 2 seconds
--	04/05/2004	Steve Ledridge		New uniqueidentifier for global temp table name
--									and file output names (to avoid duplicates).
--	05/04/2006	Steve Ledridge		Updated for SQL 2005
--	07/13/2006	Steve Ledridge		Code to handel single quotes in the @message
--	10/09/2007	Steve Ledridge		Change temp table from nvarchar(max) to 4000.
--	05/15/2009	Steve Ledridge		Added support for test and stage recipients.
--  06/02/2017	Steve Ledridge		Modified to use standard DBMail
--	======================================================================================


EXEC msdb.dbo.sp_send_dbmail
		@recipients = @recipients,
		@copy_recipients = @copy_recipients,
		@blind_copy_recipients = @blind_copy_recipients,
		@file_attachments=@attachments,
		@subject=@subject,
		@body=@message
GO
GRANT EXECUTE ON  [dbo].[dbasp_sendmail] TO [public]
GO
