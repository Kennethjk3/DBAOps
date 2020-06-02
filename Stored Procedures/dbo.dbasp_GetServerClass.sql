SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_GetServerClass]
			(
			@SQLName		SYSNAME = NULL
			,@ServerClass	SYSNAME = NULL OUT
			)
--
--/*********************************************************
-- **  Stored Procedure dbasp_GetServerClass
-- **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
-- **  April 18, 2012
-- **
-- **  This procedure returns the class of server to be used for
-- **  monitoring rules.
-- **
-- ***************************************************************/
AS
SET NOCOUNT ON
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	==================	======================================================
--	04/18/2012	Steve Ledridge		New Process
--	04/23/2012	Steve Ledridge		Added Alliant to 'CustomerImpacting'
--	06/13/2012	Steve Ledridge		Changed to new deploy server seapsqldply05
--	06/20/2012	Steve Ledridge		Added Filter for SEADCCSO01
--	09/20/2012	Steve Ledridge		Forced 'SEAPSQLRPT01','SEAPLOGSQL01','SEAPLOGSQL01\GMS' to be Employee Impacting
--	12/07/2012	Steve Ledridge		Changed DBAOpser01 and 02 to seapsqldply01 and 02.
--	03/11/2013	Steve Ledridge		Added frepsqlrylr01 to customerimpacting. Also added Sabrix.
--	05/01/2014	Steve Ledridge		Changed central server DBAOpser04 to seapsqldply04.
--	09/11/2015	Steve Ledridge		Added seapsqldply06.
--	07/27/2016	Steve Ledridge		Added seapsqldply07 and 08.
--	======================================================================================


BEGIN
	DECLARE @PartnerServer		SYSNAME
	DECLARE @PartnerServerClass	SYSNAME
	DECLARE @Output			TABLE(Data VarChar(max))
	DECLARE @TSQL			VarChar(8000)

	SET	@SQLName = ISNULL(NULLIF(@SQLName,''),@@SERVERNAME)


	IF @SQLName IN
		(
		SELECT	DISTINCT SQLName FROM dbo.DBA_DBInfo
		WHERE	[SQLName] IN ('SEAPSQLDPLY01','SEAPSQLDPLY02','SEAPSQLDPLY03','SEAPSQLDPLY04','SEAPSQLDPLY05', 'SEAPSQLDPLY06','SEAPSQLDPLY07', 'SEAPSQLDPLY08')
			OR	Appl_Desc IN ('OpsCentral')
		)
		SET	@ServerClass = 'OpsCentral'
	ELSE IF EXISTS (SELECT 1 FROM DBAOps.dbo.dba_dbinfo WHERE status = 'RESTORING' AND Mirroring!='n' AND SQLName=@SQLName)
	BEGIN
		SELECT Distinct @PartnerServer = nullif(Mirroring,'n') FROM DBAOps.dbo.dba_dbinfo WHERE nullif(Mirroring,'n') IS NOT NULL
		SET @TSQL = 'sqlcmd -Q"SET NOCOUNT ON;DECLARE @Value nVarChar(255);EXECUTE [master]..[xp_instance_regread] @rootkey = N''HKEY_LOCAL_MACHINE'',@key = ''SOFTWARE\${{secrets.COMPANY_NAME}}\SQL'',@value_name = ''ServerClass'',@value = @Value OUT;SELECT @Value;" -h -1 -S ' + @PartnerServer
		INSERT INTO @Output(Data)
		exec xp_cmdshell @TSQL
		SELECT TOP 1 @PartnerServerClass = Data FROM @Output WHERE Data IS NOT NULL

		SET	@ServerClass = 'DR:'+ISNULL(@PartnerServerClass,QUOTENAME(@PartnerServer))
	END
	ELSE IF @SQLName IN
		(
		SELECT	DISTINCT SQLName FROM dbo.DBA_DBInfo
		WHERE	[SQLName] NOT IN	('SEAPSQLRPT01','SEADCCSO01','','','')
			AND	(
					[SQLName] IN		('SEADCASPSQLA\A','FREPSQLRYLR01','','','')
				OR	(
						[status]='ONLINE'
					AND	(
							[DEPLstatus]='y' AND Appl_Desc IN	('Barbarian/Moodstream'
													,'Bundle'
													,'Channel Feeds'
													,'CRM'
													,'ED'
													,'EF'
													,'Gestalt'
													,'Legacy Commerce Service'
													,'Legacy Creative'
													,'Legacy Delivery'
													,'Legacy HardGoods'
													,'PumpAudio'
													,'Search Data Tools (AKS, MRT)'
													,'Search Data Tools (VMT)'
													,'SSL Tool Manager'
													,'Transcoder (Rhozet)'
													,'UNAdatabases'
													,'Varicent'
													,'WebVision Newsmaker')
						OR	Appl_Desc IN	('DEWDS (Picture Desk)'
										, 'Alliant'
										, 'Sabrix')
						)
					)
				)
		)
		SET	@ServerClass = 'CustomerImpacting'

	ELSE IF @SQLName IN
		(
		SELECT	DISTINCT SQLName FROM dbo.DBA_DBInfo
		WHERE	[SQLName] NOT IN	('','','','','')
			AND	(
					[SQLName] IN		('SEAPSQLRPT01','SEAPLOGSQL01','SEAPLOGSQL01\GMS','','')
				OR	(
						[status]='ONLINE'
					AND	(
							[DEPLstatus]='y' AND Appl_Desc IN	('CRM','','')
						OR	Appl_Desc IN	('','','')
						)
					)
				)
		)
		SET	@ServerClass = 'EmployeeImpacting'


	ELSE
		SET	@ServerClass = 'Normal'
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_GetServerClass] TO [public]
GO
