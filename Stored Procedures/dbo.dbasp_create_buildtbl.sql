SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_create_buildtbl]


/*********************************************************
 **  Stored Procedure dbasp_create_buildtbl
 **  Written by Steve Ledridge, Virtuoso
 **  February 23, 2011
 **
 **  This sproc is set up to create the build and build_detail tables
 **  in all local DB's that are part of the standard deployment process.
 **
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	==============================================
--	02/23/2011	Steve Ledridge		New process
--	======================================================================================


/***


--***/


-----------------  declares  ------------------
DECLARE
	 @miscprint			nvarchar(500)
	,@query				nvarchar(4000)
	,@save_dbname			sysname


----------------  initial values  -------------------


create table #dbnames(detail sysname)
create table #temp_build (data01 sysname)


/****************************************************************
 *                MainLine
 ***************************************************************/


insert into #dbnames select name from master.sys.databases where name in (select db_name from dbo.db_sequence)
--select * from #dbnames


If (select count(*) from #dbnames) > 0
   begin
	start01:
	Select @save_dbname = (select top 1 detail from #dbnames order by detail)

	--  Make sure the build table exists in the local database
	Select @query = 'select name from ' + @save_dbname + '.sys.objects where name = ''build'''
	delete from #temp_build
	Insert into #temp_build exec (@query)


	If (select count(*) from #temp_build) = 0
	   begin
		Select @query = 'CREATE TABLE ' + rtrim(@save_dbname) + '.[dbo].[Build] (
		[iBuildID] [int] IDENTITY(1,1) PRIMARY KEY ,
		[vchName] [nvarchar] (40) NOT NULL ,
		[vchLabel] [nvarchar] (100) NOT NULL ,
		[dtBuildDate] [datetime] DEFAULT GETDATE() NOT NULL ,
		[vchNotes] [nvarchar] (255) NULL
	) ON [PRIMARY]'
		print @query
		exec (@query)
		print ''
	   end


	--  Make sure the builddetail table exists in the local database
	Select @query = 'select name from ' + @save_dbname + '.sys.objects where name = ''BuildDetail'''
	delete from #temp_build
	Insert into #temp_build exec (@query)


	If (select count(*) from #temp_build) = 0
	   begin
		Select @query = 'CREATE TABLE ' + rtrim(@save_dbname) + '.[dbo].[BuildDetail] (
		[bd_id] [int] IDENTITY(1,1) NOT NULL,
		[vchLabel] [varchar] (100) NOT NULL,
		[ScriptName] [sysname] NULL,
		[ScriptPath] [nvarchar] (400) NULL,
		[ScriptResult] [nvarchar] (4000) NULL,
		[ScriptRundate] [datetime] NOT NULL DEFAULT GETDATE(),
		[ScriptRunduration_ss] [int] NULL,
		CONSTRAINT PKCL_BuildDetail
		 PRIMARY KEY CLUSTERED (bd_id)
	) ON [PRIMARY]'
		print @query
		exec (@query)
		print ''
	   end



	Delete from #dbnames where detail = @save_dbname
	If (select count(*) from #dbnames) > 0
	   begin
		goto start01
	   end

   end


---------------------------  Finalization  -----------------------
label99:


drop table #dbnames
drop table #temp_build
GO
GRANT EXECUTE ON  [dbo].[dbasp_create_buildtbl] TO [public]
GO
