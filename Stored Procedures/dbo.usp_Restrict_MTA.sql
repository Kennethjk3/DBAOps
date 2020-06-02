SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[usp_Restrict_MTA]
(
	@LoginAlias  dbo.Aliases readonly
)
As

select  ps.*
from	@LoginAlias a
join	ComposerSL. dbo.UserAccount ua	on a.LoginAlias = ua.LoginAlias
join	ComposerSL. dbo.profilestaff ps	on ua.MasterEntityID = ps.MasterEntityID

update  ps set IsNetworkVisible = 0
from	@LoginAlias a
join	ComposerSL. dbo.UserAccount ua	on a.LoginAlias = ua.LoginAlias
join	ComposerSL. dbo.profilestaff ps	on ua.MasterEntityID = ps.MasterEntityID

select  ps.*
from	@LoginAlias a
join	ComposerSL. dbo.UserAccount ua	on a.LoginAlias = ua.LoginAlias
join	ComposerSL. dbo.profilestaff ps	on ua.MasterEntityID = ps.MasterEntityID

/*
USE DBAOps
GO
declare @LoginAlias  dbo.Aliases
insert into @LoginAlias
      select 'abc'
union select 'def'

exec  dbo.usp_Restrict_MTA @LoginAlias
*/



--BEGIN
--IF OBJECT_ID('tempdb..@tmpTbl', 'U') IS NOT NULL
--	BEGIN    
--		DROP TABLE @tmpTbl
--	END

-- SET @LoginAlias=REPLACE(@LoginAlias,' ','')

--DECLARE @tmpTbl TABLE(LoginAlias Varchar(max))
--Declare @TempLoginAlias Varchar(max)

--If CharIndex(',',@LoginAlias)=0
--Begin

--	Insert Into @tmpTbl (LoginAlias) 
--	Select LoginAlias from @LoginAlias

--End
--ELSE
--While CharIndex(',',@LoginAlias)>0
	
		--Begin
		--	Set @TempLoginAlias=LEFT(@LoginAlias,CHARINDEX(',',@LoginAlias)-1)
		--	SET @LoginAlias=RIGHT(@LoginAlias,LEN(@LoginAlias)-CHARINDEX(',',@LoginAlias))
			
		--	If @LoginAlias <>'' And CharIndex(',',@LoginAlias)>0
			
		--	Begin
			
			--select * from ComposerSL. dbo.ProfileStaff
			--where masterentityid in 
			--(select masterentityid from ComposerSL. dbo.useraccount where loginalias in (@LoginAlias))

--Set @LoginAlias= @LoginAlias + ','

--update ComposerSL. dbo.profilestaff
--set isnetworkvisible=0
--where MasterEntityID in (select masterentityid from ComposerSL. dbo.useraccount where loginalias in (@LoginAlias))



--select * from ComposerSL. dbo.profilestaff
--where masterentityid in 
--(select masterentityid from ComposerSL. dbo.useraccount where loginalias in (@LoginAlias))


		--	End

		--End

		--Select t.Id,Name From test t 
		--Join @tmpTbl temp on t.Id=temp.Id

--END
GO
GRANT EXECUTE ON  [dbo].[usp_Restrict_MTA] TO [public]
GO
