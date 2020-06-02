SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_FileAccess_Dir2]
	(
	@RootDir		VARCHAR(1024)
	,@Subdirectories	BIT		=0
	,@details		BIT		=1
	)
RETURNS @FileAndDirectoryList	TABLE
				(
				[MyID]		INT IDENTITY(1,1)
				,[Name]		nvarchar(4000)
				,[FullPathName]	nvarchar(4000)
				,[IsFolder]	bit
				,[Extension]	nvarchar(4000)
				,[DateCreated]	datetime
				,[DateAccessed]	datetime
				,[DateModified]	datetime
				,[Attributes]	nVarChar(4000)
				,[Size]		bigint
				,[recursed]	INT DEFAULT 0
				)
AS
--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/22/2013	Steve Ledridge		Rewrote to use CLR Functions
--	======================================================================================
BEGIN
DECLARE		@directory			VARCHAR(2048)
		,@MyID				INT
		,@more				INT

SET		@more		= 1

INSERT INTO	@FileAndDirectoryList([Name],[FullPathName],[IsFolder],[Extension],[DateCreated],[DateAccessed],[DateModified],[Attributes],[Size])
SELECT		[Name]
		,[FullPathName]
		,[IsFolder]
		,[Extension]
		,[DateCreated]
		,[DateAccessed]
		,[DateModified]
		,[Attributes]
		,[Size]
FROM		DBAOps.dbo.dbaudf_DirectoryList(@RootDir,null)

WHILE @subdirectories<>0 AND @more>0
BEGIN
	SELECT		TOP 1
			@MyID	= MyID
	FROM		@FileAndDirectoryList
	WHERE		isFolder	= 1
		AND	recursed	= 0

	SET		@more		= @@rowcount
	IF @more > 0
	BEGIN
		SELECT		@directory = [FullPathName]
		FROM		@FileAndDirectoryList
		WHERE		MyID = @MyID

		INSERT INTO	@FileAndDirectoryList([Name],[FullPathName],[IsFolder],[Extension],[DateCreated],[DateAccessed],[DateModified],[Attributes],[Size])
		SELECT		[Name]
				,[FullPathName]
				,[IsFolder]
				,[Extension]
				,[DateCreated]
				,[DateAccessed]
				,[DateModified]
				,[Attributes]
				,[Size]
		FROM		DBAOps.dbo.dbaudf_DirectoryList(@directory,null)

		UPDATE		@FileAndDirectoryList
			SET	recursed = 1
		WHERE		MyID = @MyID
	END
END
RETURN
END
GO
