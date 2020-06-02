SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogEvent]
	(
	-- REQUIRED VALUES --

	 @cEModule		sysname			=null
	,@cECategory		sysname			=null
	,@cEEvent		nVarChar(max)			=null
	,@cEGUID		uniqueidentifier	=null
	,@cEMessage		nvarchar(max)		=null

	-- OPTIONAL VALUES --
	,@cE_ThrottleType	VarChar(50)		=null
	,@cE_ThrottleNumber	INT			=null
	,@cE_ThrottleGrouping	VarChar(255)		=null

	,@cE_ForwardTo		VarChar(2048)		=null
	,@cE_RedirectTo		VarChar(2048)		=null

	,@cEStat_Rows		Int			=null
	,@cEStat_Duration	Int			=null

	,@cERE_ForceScreen	BIT			= 0
	,@cERE_Severity		INT			= 16
	,@cERE_State		INT			= 1
	,@cERE_With		VarChar(2048)		= 'WITH LOG' -- NOT NULL FOR EASY CONCATONATION TO COMMAND

	,@cEMail_Subject	VarChar(2048)		=null
	,@cEMail_To		VarChar(2048)		=null
	,@cEMail_CC		VarChar(2048)		=null
	,@cEMail_BCC		VarChar(2048)		=null
	,@cEMail_Urgent		BIT			= 1

	,@cEFile_Name		VarChar(2048)		=null
	,@cEFile_Path		VarChar(2048)		=null
	,@cEFile_OverWrite	BIT			= 0

	,@cEPage_Subject	VarChar(2048)		=null
	,@cEPage_To		VarChar(2048)		=null

	-- METHODS TO USE TO LOG THE MESSAGE MUST USE ONE OR MORE--


	,@cEMethod_Screen	BIT			= 1
	,@cEMethod_TableLocal	BIT			= 0
	,@cEMethod_TableCentral	BIT			= 0
	,@cEMethod_RaiseError	BIT			= 0
	,@cEMethod_EMail	BIT			= 0
	,@cEMethod_File		BIT			= 0
	,@cEMethod_Twitter	BIT			= 0
	,@cEMethod_DBAPager	BIT			= 0
	,@NestLevel		INT			= 0 -- ADDS ADITIONAL "  " (TWO SPACES) MULTIPLIED BY THIS VALUE TO BEGINING OF EACH LINE
	)


/***************************************************************
 **  Stored Procedure dbasp_LogEvent
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  MAY 8, 2010
 **
 **
 **  Description: Creates a common interface to perform all event logging and messaging across all
 **  Opperations databases, code and proccesses.
 **
 **
 **  This proc accepts the following input parameters:
 **
 	@cEModule		= GENERIC NAME OF SPROC, JOB, OR GENERAL TASK TO USE FOR GROUPING
	@cECategory		= THE CATEGORY KEYWORD
	@cEEvent		= THE EVENT KEYWORD
	@cEGUID			= GUID USED TO LINK RELATED EVENTS AS A PROCCESS OR INSTANCE ex (one execution of a sproc)
	@cEMessage		= THE ACTUAL MESSAGE BEING LOGGED

	-- OPTIONAL VALUES --
	@cE_ThrottleType	= ex('FilterPerXMin','FilterPerXSec','DelayPerXMin','DelayPerXSec')
					"Filter%"	= Will drop extra messages.
					"Delay%"	= Will queue messages and deliver at interval.
					"X"		= Value in @cE_ThrottleNumber Parameter

	@cE_ThrottleNumber	= Number used in ThrottleType Calculation.
	@cE_ThrottleGrouping	= Value Used to Identify Similar Message to be Throttled.

	@cE_ForwardTo		= A Comma Delimited String of Servers That will also execute this LogEvent (Event is also Logged Here)
	@cE_RedirectTo		= A Comma Delimited String of Servers That will execute this LogEvent instead of being Executed Here. (Event is not Logged Here)

	@cEStat_Rows		= PASS IN @@ROWCOUNT IF APPROPRIATE
	@cEStat_Duration	= USE FLOAT VALUE FOR MINUTES IF CALCULATED IN PROCCESS


	@cERE_ForceScreen	= RAISEERROR: FORCES ALL VALUES FOR RAISEERROR TO "raiserror('', -1,-1) with nowait" WICH CAUSES IMEDIATE SCREEN UPDATE
	@cERE_Severity		= RAISEERROR: SEVERITY VALUE
	@cERE_State		= RAISEERROR: STATE VALUE
	@cERE_With		= RAISEERROR: 'with nowait' or LOG,SETERROR

	@cEMail_Subject		= Subject Line For Email
	@cEMail_To		= Delimited List of Recipients
	@cEMail_CC		= Delimited List of Recipients
	@cEMail_BCC		= Delimited List of Recipients
	@cEMail_Urgent		= 1 IF UGENT 0 IF NORMAL


	@cEFile_Name		= FileName to write
	@cEFile_Path		= Path to Write File
	@cEFile_OverWrite	= 1 TO OVERWRITE 0 TO APPEND


	@cEPage_Subject	VarChar	= Subject Line For Page (SMS)
	@cEPage_To		= Delimited List of Recipients or CODEWORDS used to calculate Recipient ex(ONCALLDBA,ALLDBAS,CURENTDEPLDBA...)

	-- METHODS TO USE TO LOG THE MESSAGE MUST USE ONE OR MORE--


	@cEMethod_Screen	= Prints Message to screen prefixed wit "--" to make sure it doesnt interfere with scripting.
	@cEMethod_TableLocal	= Write to the Local [dbo].EventLog Table.
	@cEMethod_TableCentral	= Write to the Central dbacentral.dbo.EventLog Table
	@cEMethod_RaiseError	= Raises an Error
	@cEMethod_EMail		= Sends Email
	@cEMethod_File		= Writes to a File
	@cEMethod_Twitter	= Send a Twitter Update
	@cEMethod_DBAPager	= Send a Page

	EACH LOG_METHOD OTHER THAN SCREEN SHOULD BE WRITTEN AS A SEPERATE SPROC WHICH IS CALLED BY THIS ONE
	AND THEY SHOULD ALL BE CALLED BEFORE THE SCREEN LOG_METHOD IS EXECUTED SO THAT IT CAN RETURN ANY INFO
	GATHERED FROM THE OTHER LOG_METHOD's
	SO THAT THIS DOESNT GET TOO LARGE AND CONFUSING
 **
 ***************************************************************
 IDEAS:
	If logging to table, you could have it calculate duration on 'stop,end,finnish...' entries by looking at related 'start,begin..' entries


 ***************************************************************/
AS
BEGIN

	/*--------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------
	INITALIZE VARIABLES
	----------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------*/
	SET NOCOUNT ON
	DECLARE		@cLogDBName		[sys].[sysname]
			,@cLogSysuser		[sys].[sysname]
			,@cLogModuleVersion	nvarchar(32)
			,@cESpace		varchar(32)
			,@lRC			int
			,@NowString		VarChar(50)
			,@NestString		VarChar(100)
			,@CRLF			CHAR(2)
			,@Text			VarChar(8000)


	SET		@cLogDBName		= db_name()
	SET		@cLogSysuser		= system_user
	SET		@cLogModuleVersion	= '0.01'
	SET		@cESpace		= 'EVT_NDX'
	SET		@NowString		= CONVERT(nvarchar(50),GETUTCDATE(),120)

	SELECT		@CRLF			= CHAR(13) + CHAR(10)
			,@NestString		= COALESCE(REPLICATE('  ',@NestLevel),'')

	-- IF @cEGUID IS NULL THEN CREATE ONE AND THIS EVENT WILL NOT BE LINKED TO ANY OTHERS
	IF @cEGUID is null
		set @cEGUID=newid()


	/*--------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------
	CHECK FOR FORWARD AND REDIRECT FLAGS
	----------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------*/


	if @cE_ForwardTo IS NOT NULL OR @cE_RedirectTo IS NOT NULL
	BEGIN
----------------------------------------------------
---------- CALL SPROC ON REMOTE TABLES
----------------------------------------------------
		SET @cE_ForwardTo = @cE_ForwardTo
		--TODO:
		--	GENERATE CURSOR OF SERVERS TO SEND SPROC CALL TO.
		--	DELIVER COMMAND TO FIRE SPROC ON REMOTE SERVER.


	END

	if @cE_RedirectTo IS NOT NULL
	BEGIN
----------------------------------------------------
---------- EXIT NOW IF REDIRECT
----------------------------------------------------
		RETURN 0
	END


	/*--------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------
	START CALLING LOG_METHOD's
	----------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------*/


----------------------------------------------------
---------- LOG_METHOD:	TABLE_LOCAL
----------------------------------------------------


	IF @cEMethod_TableLocal = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_TableLocal]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEStat_Rows
			,@cEStat_Duration


	END

----------------------------------------------------
---------- LOG_METHOD:	TABLE_CENTRAL
----------------------------------------------------


	IF @cEMethod_TableCentral = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_TableCentral]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEStat_Rows
			,@cEStat_Duration


	END


----------------------------------------------------
---------- LOG_METHOD:	RAISEERROR
----------------------------------------------------


	IF @cEMethod_RaiseError = 1 or @cERE_ForceScreen = 1
	BEGIN
		-- Declare here because only used here
		DECLARE @cEMessage2		VarChar(MAX)

		-- RESET VAULES IF @cERE_ForceScreen = 1
		SELECT	@cEMessage2		= CASE @cERE_ForceScreen
							WHEN 1 THEN ''
							ELSE @cEMessage END
			,@cERE_Severity		= CASE @cERE_ForceScreen
							WHEN 1 THEN -1
							ELSE @cERE_Severity END
			,@cERE_State		= CASE @cERE_ForceScreen
							WHEN 1 THEN -1
							ELSE @cERE_State END
			,@cERE_With	= CASE @cERE_ForceScreen
							WHEN 1 THEN 'WITH NOWAIT'
							ELSE @cERE_With END


		EXEC [dbo].[dbasp_LogEvent_Method_RaiseError]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage2
			,@cERE_Severity
			,@cERE_State
			,@cERE_With


	END

----------------------------------------------------
---------- LOG_METHOD:	EMAIL
----------------------------------------------------


	IF @cEMethod_Email = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_EMail]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEStat_Rows
			,@cEMail_To
			,@cEMail_CC
			,@cEMail_BCC
			,@cEMail_Urgent


	END


----------------------------------------------------
---------- LOG_METHOD:	FILE
----------------------------------------------------


	IF @cEMethod_File = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_File]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEFile_Name
			,@cEFile_Path
			,@cEFile_OverWrite
	END

----------------------------------------------------
---------- LOG_METHOD:	TWITTER
----------------------------------------------------


	IF @cEMethod_Twitter = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_Twitter]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage


	END

----------------------------------------------------
---------- LOG_METHOD:	DBAPager
----------------------------------------------------


	IF @cEMethod_DBAPager = 1
	BEGIN
		EXEC [dbo].[dbasp_LogEvent_Method_DBAPager]
			@cEModule
			,@cECategory
			,@cEEvent
			,@cEGUID
			,@cEMessage
			,@cEPage_Subject
			,@cEPage_To


	END

----------------------------------------------------
---------- LOG_METHOD:	SCREEN
----------------------------------------------------


	if @cEMethod_Screen=1
	BEGIN
		SET @Text = @NestString + '-- Module=%s Date=%s Category=%s Event=%s Message=%s RowCount=%d Duration=%d'
		RAISERROR (@Text,-1,-1,@cEModule,@NowString,@cECategory,@cEEvent,@cEMessage,@cEStat_Rows,@cEStat_Duration) WITH NOWAIT

		--PRINT	'-- Module=' + @cEModule
		--	+ N'  Date=' + CONVERT(nvarchar(50),GETUTCDATE(),120)
		--	+ N'  Category=' +coalesce(@cECategory,N'(undefined)')
		--	+ N'  Event=' +coalesce(@cEEvent,N'(undefined)')
		--	+ COALESCE(N'  Message=' + @cEMessage, N'')
		--	+ COALESCE(N'  RowCount=' + cast(@cEStat_Rows as nvarchar), N'')
		--	+ COALESCE(N'  Duration=' + cast(@cEStat_Duration as nvarchar), N'')


	END

	/*--------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------
	DONE
	----------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------*/
	return 0
end


/*
USAGE:


	--------------------------------------------------
	-- DECLARE ALL cE VARIABLES AT HEAD OF PROCCESS --
	--------------------------------------------------
	DECLARE	@cEModule		sysname
		,@cECategory		sysname
		,@cEEvent		sysname
		,@cEGUID		uniqueidentifier
		,@cEMessage		nvarchar(max)
		,@cERE_ForceScreen	BIT
		,@cERE_Severity		INT
		,@cERE_State		INT
		,@cERE_With		VarChar(2048)
		,@cEStat_Rows		BigInt
		,@cEStat_Duration	FLOAT
		,@cEMethod_Screen	BIT
		,@cEMethod_TableLocal	BIT
		,@cEMethod_TableCentral	BIT
		,@cEMethod_RaiseError	BIT
		,@cEMethod_Twitter	BIT
	--------------------------------------------------
	--           SET GLOBAL cE VARIABLES            --
	--------------------------------------------------
	SELECT	@cEModule		= 'TestLogingProccess'	-- SHOULD BE SET ONCE AT BEGINNING OF PROCCESS
		,@cEGUID		= NEWID()		-- SHOULD BE SET ONCE AT BEGINNING OF PROCCESS


--------------------------------------------------
--     \/         PER EVENT CODE        \/      --
--------------------------------------------------


	--------------------------------------------------
	--            SET EVENT cE VARIABLES            --
	--------------------------------------------------
	SELECT	@cECategory		= 'STEP'
		,@cEEvent		= 'INITALIZE VARIABLES'
		,@cEMessage		= 'Initializing Variables'
	--------------------------------------------------
	--            CALL LOG EVENT SPROC              --
	--------------------------------------------------
	exec [dbo].[dbasp_LogEvent]
				 @cEModule
				,@cECategory
				,@cEEvent
				,@cEGUID
				,@cEMessage
	-- OPTIONAL VALUES  ONLY UNCOMMENT IF NONDEFAULT--
				--,@cEStat_Rows		= @@ROWCOUNT
				--,@cEStat_Duration	= DATEDIFF(ss,@StartDate,@StopDate) / 60.0000			-- GRANULARITY IN SECONDS
							--= DATEDIFF(ms,@StartDate,@StopDate) / 1000.0000 / 60.0000	-- GRANULARITY IN MILISECONDS
				--,@cERE_ForceScreen
				--,@cERE_Severity
				--,@cERE_State
				--,@cERE_With
				--,@cEMethod_Screen
				--,@cEMethod_TableLocal
				--,@cEMethod_TableCentral
				--,@cEMethod_RaiseError
				,@cEMethod_Twitter	= 1
	--------------------------------------------------
	--                    DONE                      --
	--------------------------------------------------


--------------------------------------------------
--   /\         END PER EVENT CODE      /\      --
--------------------------------------------------


--*/
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogEvent] TO [public]
GO
