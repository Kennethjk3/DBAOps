SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_FileAccess_Dir]
	(
	@RootDir		VARCHAR(1024)
	,@Subdirectories	BIT		=0
	)

RETURNS @FileAndDirectoryList	TABLE
				(
				[Name]		nvarchar(4000)
				,[FullPathName]	nvarchar(4000)
				,[IsFolder]	bit
				,[Extension]	nvarchar(4000)
				,[DateCreated]	datetime
				,[DateAccessed]	datetime
				,[DateModified]	datetime
				,[Attributes]	nVarChar(4000)
				,[Size]		bigint
				)
AS
--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	02/22/2013	Steve Ledridge		Rewrote to use CLR Functions
--	======================================================================================
BEGIN

	INSERT INTO	@FileAndDirectoryList
	select * From dbo.dbaudf_DirectoryList(@RootDir,null)

	IF @Subdirectories = 0
		GOTO DoneReading

	InsertSubFolders:

	INSERT INTO	@FileAndDirectoryList
	SELECT		T2.*
	FROM		@FileAndDirectoryList T1
	CROSS APPLY	 dbo.dbaudf_DirectoryList([FullPathName],null)	T2
	WHERE		T1.[IsFolder] = 1
		AND	T1.[FullPathName] NOT IN	(
						SELECT	DISTINCT
							LEFT([FullPathName],LEN([FullPathName])-(LEN([Name])+1))
						From	@FileAndDirectoryList
						)

	IF @@ROWCOUNT > 0 goto InsertSubFolders

	DoneReading:

RETURN
END
GO
