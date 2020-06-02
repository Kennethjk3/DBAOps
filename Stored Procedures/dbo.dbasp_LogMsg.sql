SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_LogMsg]
 @ModuleName sysname = null
,@MessageKeyword varchar(32)=null
,@TypeKeyword varchar(16)=null
,@ProcessGUID uniqueidentifier=null
,@AdHocMsg nvarchar(max)=null
,@AdHocDefinition xml=null
,@RowsAffected int=null
,@LogPublisherMessage bit=0
,@SuppressRaiseError bit=0
,@Diagnose bit=1
as
/*
<DbDoc>
	<object description="Internal handler for printing log messages and logging them locally"/>
</DbDoc>
*/
begin
	set nocount on
	declare
	@cLogDBName sysname
	,@cLogSysuser sysname
	,@cLogModuleVersion nvarchar(32)
	,@cESpace varchar(32)
	,@lRC int


	set @cLogDBName=db_name()
	set @cLogSysuser=system_user
	set @cLogModuleVersion= '0.01' --DbDoc.GetVersion(N'NDX')
	set @cESpace='EVT_NDX'
	if @ProcessGUID is null set @ProcessGUID=newid()
	if @Diagnose is null set @Diagnose=1
	if @LogPublisherMessage is null set @LogPublisherMessage=1


	if @Diagnose=1
		print '-- ' + @ModuleName+N': '
			+cast(current_timestamp as nvarchar)
			--+N': type='+coalesce([Evt].[TypeGetName](@TypeKeyword),N'(undefined)')
			+N': type='+coalesce(@TypeKeyword,N'(undefined)')
			+case when @RowsAffected is null then N'' else
				N': rowcount='+cast(@RowsAffected as nvarchar)
				end
			+case when @AdHocMsg is null then N'' else
				N': '+@AdHocMsg
				end


	--exec @lRC=[Evt].[MessageHandle]
	--	@MessageSpaceKeyword=@cESpace
	--	,@MessageKeyword=@MessageKeyword
	--	,@TypeKeyword=@TypeKeyword
	--	,@ModuleName=@ModuleName
	--	,@ProcessGUID=@ProcessGUID
	--	,@AdHocMsg=@AdHocMsg
	--	,@AdHocDefinition=@AdHocDefinition
	--	,@RowsAffected=@RowsAffected
	--	,@SuppressRaiseError=@SuppressRaiseError
	--	,@SuppressLog=@ScriptMode


	return 0 --@lRC
end
GO
GRANT EXECUTE ON  [dbo].[dbasp_LogMsg] TO [public]
GO
