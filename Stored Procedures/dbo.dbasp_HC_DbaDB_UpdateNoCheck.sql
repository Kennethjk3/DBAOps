SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_HC_DbaDB_UpdateNoCheck]


/*********************************************************
 **  Stored Procedure dbasp_HC_DbaDB_UpdateNoCheck
 **  Written by Steve Ledridge, Virtuoso
 **  March 20, 2015
 **  This procedure runs the Update NoCheck portion
 **  of the DBA SQL Health Check process.
 *********************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	03/20/2015	Steve Ledridge		New process.
--	======================================================================================


---------------------------
--  Checks for this sproc
---------------------------
--  For DB's: DBAOps
--  Update the NoCheck table


/***


--***/


DECLARE	 @miscprint				nvarchar(2000)
	,@cmd					nvarchar(500)
	,@save_servername			sysname
	,@save_servername2			sysname
	,@save_servername3			sysname
	,@charpos				int
	,@charpos2				int
	,@base_flag				char(1)
	,@save_DBname				sysname
	,@save_DBName_retry			sysname
	,@save_JobName				sysname


----------------  initial values  -------------------


Select @save_servername = @@servername
Select @save_servername2 = @@servername
Select @save_servername3 = @@servername


select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))
	select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')


	select @save_servername3 = stuff(@save_servername3, @charpos, 1, '(')
	select @save_servername3 = @save_servername3 + ')'
   end


declare @jobnames table	(name	sysname)


/****************************************************************
 *                MainLine
 ***************************************************************/


--  Print the headers
Print  ' '
Print  '/********************************************************************'
Select @miscprint = '   RUN SQL Health Check - DBAOps Update NoCheck'
Print  @miscprint
Print  ' '
Select @miscprint = '-- ' + convert(varchar(30),getdate()) + '  For Server ' + @@servername
Print  @miscprint
Print  '********************************************************************/'
Print  ' '


--------------------  Clean up DBAOps.dbo.no_check table  -------------------
update dbo.no_check set modDate = getdate() where modDate is null


update dbo.no_check set modDate = getdate() where detail01 in (select name from master.sys.databases)


--  Check for regular restored DB's and add them to the backup no_check table
Insert into @jobnames (name)
SELECT j.name
From msdb.dbo.sysjobs j with (NOLOCK)
Where j.name not like ('x%')
  and j.name not like ('%Start Restore%')
  and j.name not like ('%End Restore%')
  and j.name not like ('%Restores Complete%')
  and j.name not like ('%DFNTL Restore%')
  and j.name like ('%restore%')
  and (j.name like ('base%') or j.name like ('rstr%'))


delete from @jobnames where name is null or name = ''
--select * from @jobnames


IF (select count(*) from @jobnames) > 0
   begin
	start_jobnames:


	Set @base_flag = 'n'


	Select @save_JobName = (select top 1 name from @jobnames)

	Select @save_DBName = @save_JobName


	--  get the DB names for BASE
	IF @save_DBName like ('BASE%')
	   begin
		Set @base_flag = 'y'


		Select @charpos = charindex('Restore', @save_DBName)


		IF @charpos <> 0
		   begin
			Select @save_DBName = substring(@save_DBName, @charpos+7, 200)
			Select @save_DBName = ltrim(rtrim(@save_DBName))
		   end


	    goto end_jobname_parse
	   end


	--  get the DB names in ()
	Select @charpos = charindex('(', @save_DBName)
	IF @charpos <> 0
	   begin
		Select @charpos2 = charindex(')', @save_DBName, @charpos+1)
		IF @charpos2 <> 0
		   begin
			Select @save_DBName = substring(@save_DBName, @charpos+1, (@charpos2-@charpos-1))
		   end
	    goto end_jobname_parse
	   end


	--  get the DB names for Rstr jobs
	IF @save_DBName like ('Rstr%')
	   begin
		Select @charpos = charindex(' ', @save_DBName)
		IF @charpos <> 0
		   begin
			Select @save_DBName = substring(@save_DBName, @charpos+1, len(@save_DBName)-@charpos+1)
			Select @save_DBName = ltrim(rtrim(@save_DBName))

	   		rstr_retry:
			Select @charpos2 = charindex(' ', @save_DBName)
			IF @charpos2 <> 0
			   begin
				--  Keep both sides of the results.  If we don't get a valid DBname, loop around to try again.
				Select @save_DBName_retry = substring(@save_DBName, @charpos2, len(@save_DBName)-@charpos2+1)
				Select @save_DBName_retry = ltrim(rtrim(@save_DBName_retry))
				Select @save_DBName = left(@save_DBName, @charpos2-1)
				Select @save_DBName = ltrim(rtrim(@save_DBName))
				If not exists (select 1 from master.sys.databases where name = @save_DBName)
				   begin
					select @save_DBName = ltrim(@save_DBName_retry)
					goto rstr_retry
				   end
			   end
			Else
			   begin
				goto end_jobname_parse
			   end
		   end
	    goto end_jobname_parse
	   end


	end_jobname_parse:



	--  Update the no_check table
	If exists (select 1 from DBAOps.dbo.no_check where detail01 = @save_DBName and NoCheck_type = 'backup')
	   begin
		update DBAOps.dbo.no_check set modDate = getdate() where detail01 = @save_DBName and NoCheck_type = 'backup'
	   end
	Else
	   begin
		INSERT INTO DBAOps.dbo.no_check (nocheck_type, detail01, createdate, moddate) VALUES ('backup', @save_DBName, getdate(), getdate())
	   end


	If @base_flag = 'y'
	   begin
		If exists (select 1 from DBAOps.dbo.no_check where detail01 = @save_DBName and NoCheck_type = 'baseline')
		   begin
			update DBAOps.dbo.no_check set modDate = getdate() where detail01 = @save_DBName and NoCheck_type = 'baseline'
		   end
		Else
		   begin
			INSERT INTO DBAOps.dbo.no_check (nocheck_type, detail01, createdate, moddate) VALUES ('baseline', @save_DBName, getdate(), getdate())
		   end
	   end


	--  Remove this record from @jobnames and go to the next
	delete from @jobnames where name = @save_JobName
	If (select count(*) from @jobnames) > 0
	   begin
		goto start_jobnames
	   end
   end


Delete from DBAOps.dbo.no_check where nocheck_type = 'backup' and modDate < getdate()-30


Print '--  Completed.'
Print ' '


--  Finalization  ------------------------------------------------------------------------------


label99:
GO
GRANT EXECUTE ON  [dbo].[dbasp_HC_DbaDB_UpdateNoCheck] TO [public]
GO
