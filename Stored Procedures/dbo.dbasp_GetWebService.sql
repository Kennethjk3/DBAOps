SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetWebService]
    @TheURL VARCHAR(255),-- the url of the web service
    @TheResponse NVARCHAR(4000) OUTPUT --the resulting JSON
  AS
    BEGIN
      DECLARE @obj INT, @hr INT, @status INT, @message VARCHAR(255);
      /**
  Summary: >
    This is intended for using web services that 
    utilize JavaScript Object Notation (JSON). You pass it the link to
    a webservice and it returns the JSON string
  Note: >
    OLE Automation objects can be used within a Transact-SQL batch, but 
    SQL Server blocks access to OLE Automation stored procedures because
    this component is turned off as part of the security configuration.

  Examples:
     - >
     DECLARE @response NVARCHAR(MAX) 
     EXECUTE dbo.dbasp_GetWebService 'http://headers.jsontest.com/', @response OUTPUT
     SELECT  @response 
  Returns: >
    nothing
  **/
      EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHttp', @obj OUT;
      SET @message = 'sp_OAMethod Open failed';
      IF @hr = 0 EXEC @hr = sp_OAMethod @obj, 'open', NULL, 'GET', @TheURL, false;
      SET @message = 'sp_OAMethod setRequestHeader failed';
      IF @hr = 0
        EXEC @hr = sp_OAMethod @obj, 'setRequestHeader', NULL, 'Content-Type',
          'application/x-www-form-urlencoded';
      SET @message = 'sp_OAMethod Send failed';
      IF @hr = 0 EXEC @hr = sp_OAMethod @obj, send, NULL, '';
      SET @message = 'sp_OAMethod read status failed';
      IF @hr = 0 EXEC @hr = sp_OAGetProperty @obj, 'status', @status OUT;
      IF @status <> 200 BEGIN
                          SELECT @message = 'sp_OAMethod http status ' + Str(@status), @hr = -1;
        END;
      SET @message = 'sp_OAMethod read response failed';
      IF @hr = 0
        BEGIN
          EXEC @hr = sp_OAGetProperty @obj, 'responseText', @Theresponse OUT;
          END;
      EXEC sp_OADestroy @obj;
      IF @hr <> 0 RAISERROR(@message, 16, 1);
      END;
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetWebService] TO [public]
GO
