SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_regread] (@in_key sysname = 'HKEY_LOCAL_MACHINE'
				,@in_path sysname = null
				,@in_value sysname = null
				,@result_value nvarchar(500) OUTPUT)


/*********************************************************
 **  Stored Procedure dbasp_regread
 **  Written by Steve Ledridge, Virtuoso
 **  04/06/2006
 **
 **  This procedure gets values from the registry.
 ***************************************************************/
  as
set nocount on


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	04/06/2006	Steve Ledridge		New process for sql2005.
--	11/06/2007	Steve Ledridge		Added double quotes and xp_regread section.
--	12/13/2007	Steve Ledridge		Addewd return(0).
--	08/22/2007	Steve Ledridge		Addewd return(0).
--	08/26/2007	Steve Ledridge		Force reg2 for x64.
--	======================================================================================


/***
declare @in_key sysname
declare @in_path sysname
declare @in_value sysname
declare @result_value nvarchar(500)


select @in_key = 'HKEY_LOCAL_MACHINE'
select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
select @in_value = 'a'
Select @result_value = null
--***/


DECLARE
	 @miscprint			nvarchar(250)
	,@save_servername		sysname
	,@save_servername2		sysname
	,@charpos			int
	,@cmd				nvarchar(2000)
	,@save_value_result		nvarchar(500)


----------------  initial values  -------------------
Select @save_servername		= @@servername
Select @save_servername2	= @@servername


Select @charpos = charindex('\', @save_servername)
IF @charpos <> 0
   begin
	Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))


	Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')
   end


Create table #regresults(results nvarchar(1500) null)


--  Check input values
If @in_key is null or @in_key not in ('HKLM', 'HKEY_LOCAL_MACHINE', 'HKCU', 'HKEY_CURRENT_USER', 'HKCR', 'HKEY_CLASSES_ROOT', 'HKU', 'HKEY_USERS', 'HKCC', 'HKEY_CURRENT_CONFIG')
   begin
	Select @miscprint = 'DBA WARNING: dbasp_regread - Invalid input parm for @in_key (Must be ''HKLM'', ''HKCU'', ''HKCR'', ''HKU'' or ''HKCC'')'
	print @miscprint
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


If @in_path is null
   begin
	Select @miscprint = 'DBA WARNING: dbasp_regread - No input parm specified for @in_path'
	print @miscprint
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


If @in_value is null
   begin
	Select @miscprint = 'DBA WARNING: dbasp_regread - No input parm specified for @in_value'
	print @miscprint
	raiserror(@miscprint,-1,-1) with log
	goto label99
   end


/****************************************************************
 *                MainLine
 ***************************************************************/
If @@version like '%x64%'
   begin
	Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /v ' + @in_value
   end
Else
   begin
	Select @cmd = 'reg query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /v ' + @in_value
   end


--print @cmd


insert into #regresults exec master.sys.xp_cmdshell @cmd
delete from #regresults where results is null
delete from #regresults where results like '%but is for a machine type%'
delete from #regresults where results like '%ERROR:%'
delete from #regresults where results like '%' + @in_path + '%'
delete from #regresults where results not like '%' + @in_value + '%'
--select * from #regresults


If (select count(*) from #regresults) = 0
   begin
		Select @cmd = 'reg2 query "\\' + @save_servername + '\' + @in_key + '\' + @in_path + '" /v ' + @in_value
		--print @cmd


		insert into #regresults exec master.sys.xp_cmdshell @cmd
		delete from #regresults where results is null
		delete from #regresults where results like '%but is for a machine type%'
		delete from #regresults where results like '%ERROR:%'
		delete from #regresults where results like '%' + @in_path + '%'
		delete from #regresults where results not like '%' + @in_value + '%'
		--select * from #regresults
   end


select @save_value_result = (select top 1 results from #regresults)
--print @save_value_result


select @charpos = charindex('reg_', @save_value_result)
IF @charpos <> 0
   begin
	select @save_value_result = substring(@save_value_result, @charpos + 1, 500)
	select @charpos = charindex('  ', @save_value_result)
	IF @charpos <> 0
	   begin
		select @save_value_result = rtrim(substring(@save_value_result, @charpos + 1, 500))
		select @save_value_result = ltrim(@save_value_result)
	   end
   end


If @save_value_result like '%ERROR%' or @save_value_result is null or @save_value_result = ''
   begin
	--  using xp_regread as a last resort because reg query doesn't always work
	EXEC master.sys.xp_regread @rootkey = @in_key, @key = @in_path, @value_name = @in_value, @value = @save_value_result OUTPUT
   end


Select @result_value = @save_value_result
--print @result_value


--  Finalization  -------------------------------------------------------------------


label99:


drop table #regresults


return(0)
GO
GRANT EXECUTE ON  [dbo].[dbasp_regread] TO [public]
GO
