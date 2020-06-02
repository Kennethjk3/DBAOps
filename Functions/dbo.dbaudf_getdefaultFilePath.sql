SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_getdefaultFilePath](@gfpType char(2))
returns nvarchar(500)
as

/**************************************************************
 **  User Defined Function dbaudf_getdefaultFilePath
 **  Written by Steve Ledridge, ${{secrets.COMPANY_NAME}}
 **  July 08/2009
 **
 **  This dbaudf is set up to check the the default path
 **  for the physical Data and Log File.
 **  Returns:
 **      path:    Which indicates the database default path is set.
 **	 Not Set: Which indicates the database default path is
 **		  the same as where SQL is installed.
 **
 ***************************************************************/


--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	07/08/2009	Steve Ledridge		New process
--
--	======================================================================================
begin


      DECLARE
		 @in_key			sysname
		,@in_path			sysname
		,@in_value			sysname
		,@in_value2			sysname
		,@result_value		        nvarchar(500)
		,@retVal			nvarchar(500)
		,@cmd			        nvarchar(4000)
		,@save_servername		sysname
		,@save_servername2		sysname
		,@save_ServerType		sysname
		,@save_sqlinstance		sysname
		,@charpos			int
		,@isNMinstance			char(1)
		,@save_install_folder		sysname
		,@save_whatwearelookingfor	nvarchar(20)
		,@save_regresult		sysname
		,@interimResult			nvarchar(4000)



	   /**
		  declare @gfpType char(2)
     		   set @gfpType = 'L'
	    --**/


       --Parameter check--

       if (@gfpType not like 'D' and  @gfpType  not like 'L')
	    begin
		    select @retval='invalid parameter passed'
		   --print @retval
		    return @retval
		    goto label99
	    end
        else
	    begin
		set @in_value =
		    case
			when @gfpType like '%D%'  then  'DefaultData'
			when @gfpType like '%L%'  then  'DefaultLog'
		    end
            end

	Select @save_whatwearelookingfor = @in_value

	declare @regresults table (results nvarchar(1500) null)


	Select @save_sqlinstance = 'mssqlserver'
	Select @save_servername = @@servername
	Select @save_servername2 = @@servername

	Select @charpos = charindex('\', @save_servername)
	IF @charpos <> 0
	   begin
		Select @save_servername = substring(@@servername, 1, (CHARINDEX('\', @@servername)-1))

		Select @save_servername2 = stuff(@save_servername2, @charpos, 1, '$')

		Select @save_sqlinstance = rtrim(substring(@@servername, @charpos+1, 100))
		Select @isNMinstance = 'y'
	   end


	--  Get the instalation directory folder name
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
	select @in_value2 = @save_sqlinstance
	exec DBAOps.dbo.dbasp_regread @in_key, @in_path, @in_value2, @result_value output

	If @result_value is null or @result_value = ''
	   begin
		goto label99
	   end

	--  Now ...
	select @save_install_folder = @result_value
	select @in_key = 'HKEY_LOCAL_MACHINE'
	select @in_path = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @save_install_folder + '\MSSQLServer'
	EXEC master..xp_regread @rootkey = @in_key , @key = @in_path, @value_name = @in_value, @value = @save_regresult OUTPUT


	If @save_regresult is not null and @save_regresult <> ''
	   begin
		select @retVal = @save_regresult
	   end


	If(@retVal is null)
	     begin
		    set @retVal = 'Not Set'
	     end

	--print @retVal


	----------finalization----------

	label99:

	return @retVal

end
GO
