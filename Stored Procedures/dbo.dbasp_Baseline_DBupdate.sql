SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_Baseline_DBupdate] @DBname sysname = null


/*********************************************************
 **  Stored Procedure dbasp_Baseline_DBupdate
 **  Written by Steve Ledridge, Virtuoso
 **  March 18, 2015
 **
 **  This procedure is used to set DB related options as part of
 **  the Baseline process
 **
 **  Input Parms:
 **
 **  - @dbname is the name of the database that was just restored
 **
 ***************************************************************/
  as
SET NOCOUNT ON


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/15/2015	Steve Ledridge		New process
--	======================================================================================


/***
Declare @DBname sysname


Select @DBname = 'wcds'
--***/


DECLARE
	 @miscprint		nvarchar(2000)
	,@cmd			nvarchar(4000)
	,@query_text		nvarchar(4000)
	,@charpos		int
	,@save_servername	sysname
	,@save_servername2	sysname
	,@save_compat		varchar(5)


----------------  initial values  -------------------


Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


--  Check parameters
If @DBname is null or @DBname = ''
   begin
	Print 'Warning:  Invalid input parameter.  @DBname must be specified'
	Goto label99
   end


If not exists(select 1 from master.sys.databases where name = @DBname)
   begin
	Print 'Warning:  Invalid input parameter.  Database ' + @DBname + ' does not exist on this server.'
	Goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/


Print '-- Baseline Update for Database ' + @DBname
Print ' '
Print ' '


--  Section to CHANGE DATABASE OWNER to 'sa' and point DBO Name to 'sa'
Print '-- Section to CHANGE DATABASE OWNER to ''sa'''


Select @query_text = 'Use master ALTER AUTHORIZATION ON DATABASE::' + @DBname + ' TO sa;'
print @query_text
Exec(@query_text)
Print ' '


--  Section to Set database options
Print '-- Section to Set database options'


Select @query_text = 'ALTER DATABASE [' + @DBname + '] SET RECOVERY SIMPLE WITH NO_WAIT '
Print @query_text
Exec(@query_text)
Print ' '


Select @query_text = 'ALTER DATABASE [' + @DBname + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT '
Print @query_text
Exec(@query_text)
Print ' '


Select @query_text = 'ALTER DATABASE [' + @DBname + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT '
Print @query_text
Exec(@query_text)
Print ' '


Select @query_text = 'ALTER DATABASE [' + @DBname + '] SET AUTO_UPDATE_STATISTICS_ASYNC OFF WITH NO_WAIT '
Print @query_text
Exec(@query_text)
Print ' '


--  Set the DB Compatibility Level
SELECT @save_compat = CASE WHEN (select @@VERSION) like '%Microsoft SQL Server 2005%' THEN '90'
			WHEN (select @@VERSION) like '%Microsoft SQL Server 2008%' THEN '100'
			WHEN (select @@VERSION) like '%Microsoft SQL Server 2012%' THEN '110'
			WHEN (select @@VERSION) like '%Microsoft SQL Server 2014%' THEN '120'
			ELSE '999' END


If @save_compat <> '999'
   begin
	Select @query_text = 'ALTER DATABASE [' + @DBname + '] SET COMPATIBILITY_LEVEL = ' + @save_compat + ';'
	Print @query_text
	Exec(@query_text)
	Print ' '
   end


--  Create Build and BuildDetail Tables if needed
Select @query_text = 'if not exists (select * from ' + @DBname + '.sys.objects where name = ''Build'' and type = ''U'')
	BEGIN
		CREATE TABLE [' + rtrim(@DBname) + '].[dbo].[Build] (
		[iBuildID] [int] IDENTITY(1,1) PRIMARY KEY ,
		[vchName] [nvarchar] (40) NOT NULL ,
		[vchLabel] [nvarchar] (100) NOT NULL ,
		[dtBuildDate] [datetime] DEFAULT GETDATE() NOT NULL ,
		[vchNotes] [nvarchar] (255) NULL
		) ON [PRIMARY]
	END'
print @query_text
exec (@query_text)
print ''


Select @query_text = 'if not exists (select * from ' + @DBname + '.sys.objects where name = ''BuildDetail'' and type = ''U'')
	BEGIN
		CREATE TABLE [' + rtrim(@DBname) + '].[dbo].[BuildDetail] (
		[bd_id] [int] IDENTITY(1,1) NOT NULL,
		[vchLabel] [varchar] (100) NOT NULL,
		[ScriptName] [sysname] NULL,
		[ScriptPath] [nvarchar] (400) NULL,
		[ScriptResult] [nvarchar] (4000) NULL,
		[ScriptRundate] [datetime] NOT NULL DEFAULT GETDATE(),
		[ScriptRunduration_ss] [int] NULL,
		CONSTRAINT PKCL_BuildDetail
		 PRIMARY KEY CLUSTERED (bd_id)
		) ON [PRIMARY]
	END'
print @query_text
exec (@query_text)
print ''


--  Finalization  -------------------------------------------------------------------


Print '-- Baseline Update Complete.'


Label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_Baseline_DBupdate] TO [public]
GO
