SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[fn_QueryTextFromHandle](@handle varbinary(64), @statement_start_offset int, @statement_end_offset int)
RETURNS @query_text TABLE (database_id smallint, object_id int, encrypted bit, query_text nvarchar(max))
begin
	if @handle is not null
	begin
		declare @start int, @end int
		declare @dbid smallint, @objectid int, @encrypted bit
		declare @batch nvarchar(max), @query nvarchar(max)

		-- statement_end_offset is zero prior to beginning query execution (e.g., compilation)
		select
			@start = isnull(@statement_start_offset, 0),
			@end = case when @statement_end_offset is null or @statement_end_offset = 0 then -1
						else @statement_end_offset
					end

		select @dbid = t.dbid,
			@objectid = t.objectid,
			@encrypted = t.encrypted,
			@batch = t.text
		from sys.dm_exec_sql_text(@handle) as t

		select @query = case
				when @encrypted = cast(1 as bit) then N'encrypted text'
				else ltrim(substring(@batch, @start / 2 + 1, ((case when @end = -1 then datalength(@batch)
							else @end end) - @start) / 2))
			end

		-- Found internal queries (e.g., CREATE INDEX) with end offset of original batch that is
		-- greater than the length of the internal query and thus returns nothing if we don't do this
		if datalength(@query) = 0
		begin
			select @query = @batch
		end

		insert into @query_text (database_id, object_id, encrypted, query_text)
		values (@dbid, @objectid, @encrypted, @query)
	end

	return
end
GO
