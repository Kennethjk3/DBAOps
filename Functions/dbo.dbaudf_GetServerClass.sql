SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_GetServerClass]
			(
			@SQLName sysname = NULL
			)
Returns		SYSNAME
--
--/*********************************************************
-- **  Function dbaudf_GetServerClass
-- **  Written by Steve Ledridge, Virtuoso
-- **  April 18, 2012
-- **
-- **  This Function returns the class of server to be used for
-- **  monitoring rules.
-- **
-- ***************************************************************/
AS
--	======================================================================================
--	Revision History
--	Date		Author     				Desc
--	==========	==================	======================================================
--	04/18/2012	Steve Ledridge		New Process
--	04/23/2012	Steve Ledridge		Added Alliant to 'CustomerImpacting'
--	06/13/2012	Steve Ledridge		Changed to new deploy server seapsqldply05
--	06/20/2012	Steve Ledridge		Added Filter for SEADCCSO01
--	09/20/2012	Steve Ledridge		Forced 'SEAPSQLRPT01','SEAPLOGSQL01','SEAPLOGSQL01\GMS' to be Medium
--	12/07/2012	Steve Ledridge		Changed DBAOpser01 and 02 to seapsqldply01 and 02.
--	05/06/2014	Steve Ledridge		Changed DBAOpser04 to seapsqldply04.
--	06/25/2016	Steve Ledridge		Added Several Apps and modified the logic a bit.
--	======================================================================================
BEGIN
	DECLARE	@ServerClass SYSNAME

	SET	@SQLName = ISNULL(NULLIF(@SQLName,''),@@SERVERNAME)

	IF	(
			(SELECT Active From dbo.DBA_ServerInfo WHERE SQLName = @SQLName) = 'y'
		AND	(
			   @SQLName Like '%SQLLOG%'
			OR @SQLName Like '%LOGSQL%'
			OR @SQLName Like '%SQLRPT%'
			OR @SQLName LIKE '%dply%'
			)
		)
		SET	@ServerClass = 'Medium'
	ELSE IF @SQLName IN
		(
		SELECT	DISTINCT SQLName
		FROM		dbo.DBA_DBInfo
		WHERE	(
				([SQLName] LIKE '%SQLEDW%' AND [ENVname]='Production')
				OR [SQLName] IN ('','','','','') --SERVERS TO INCLUDE
				)
			OR	(
					(
					[status] IN ('ONLINE','RESTORING')
					OR [Mirroring]='y'
					)
				AND	[ENVname]='Production'
				AND	(
					[SQLName] NOT IN ('SEAPSQLRPT01','SEADCCSO01','','','') -- SERVERS TO EXCLUDE
					AND [SQLName] NOT LIKE 'ASHT%'
					AND	(
							(
							[DEPLstatus]='y'
							AND Appl_Desc IN	(					-- LIST OF DEPLOYABLE APPLICATIONS TO INCLUDE
											'Barbarian/Moodstream'
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
											,'WebVision Newsmaker'
											,'Collaboration'
											,'UNAdatabases'
											,'TAX'
											,'ACH'
											,'CTB'
											)
							)
						OR Appl_Desc IN ('DEWDS (Picture Desk)','OpsCentral') -- LIST OF APPLICATIONS TO INCLUDE EVEN IF NOT DEPLOYABLE
						)
					)
				)
			) AND (SELECT Active From dbo.DBA_ServerInfo WHERE SQLName = @SQLName) = 'y'
		SET	@ServerClass = 'High'
	ELSE
		SET	@ServerClass = 'Normal'

	RETURN @ServerClass
END
GO
