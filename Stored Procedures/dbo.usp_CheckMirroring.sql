SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[usp_CheckMirroring]
as


DECLARE @state VARCHAR(30)


DECLARE @DbMirrored INT


DECLARE @DbId INT


DECLARE @String VARCHAR(100)


DECLARE @databases TABLE (DBid INT, mirroring_state_desc VARCHAR(30))


-- get status for mirrored databases


INSERT @databases


SELECT database_id, mirroring_state_desc


FROM sys.database_mirroring


WHERE mirroring_role_desc IN ('PRINCIPAL','MIRROR')


AND mirroring_state_desc NOT IN ('SYNCHRONIZED','SYNCHRONIZING')


-- iterate through mirrored databases and send email alert


WHILE EXISTS (SELECT TOP 1 DBid FROM @databases WHERE mirroring_state_desc IS NOT NULL)


BEGIN


SELECT TOP 1 @DbId = DBid, @State = mirroring_state_desc


FROM @databases


SET @string = 'Host: '+@@servername+'.'+CAST(DB_NAME(@DbId) AS VARCHAR)+ ' - DB Mirroring is '+@state +' - notify DBA'


EXEC msdb.dbo.sp_send_dbmail @recipients = 'marlena.mattingly@23TouchPoints.com', @body = @string, @subject = @string


DELETE FROM @databases WHERE DBid = @DbId


END


--alert if there is no mirroring just in case there should be mirroring


SELECT @DbMirrored = COUNT(*)


FROM sys.database_mirroring


WHERE mirroring_state IS NOT NULL


IF @DbMirrored = 0


BEGIN


SET @string = 'Host: '+@@servername+' - No databases are mirrored on this server - notify DBA'


EXEC msdb.dbo.sp_send_dbmail @recipients = 'marlena.mattingly@23TouchPoints.com', @body = @string, @subject = @string


END
GO
GRANT EXECUTE ON  [dbo].[usp_CheckMirroring] TO [public]
GO
