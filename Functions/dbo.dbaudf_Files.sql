SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_Files]
(@Wildcard VARCHAR(100),
@Subdirectories INT=0,
@details INT=1
)
/*
Usage:
Select sum(size), count(*)
    from DBAOps.dbo.dbaudf_Files ('C:\Program Files\', 1,1)

*/
RETURNS @FileTable TABLE
                   (MyID		INT IDENTITY(1,1),
                   [name]		VARCHAR(1000),
                   FullPathName		VARCHAR(2000),
                   [ShortPath]		VARCHAR(2000),
                   [Type]		VARCHAR(100),
                   [DateCreated]	DATETIME,
                   [DateLastAccessed]	DATETIME,
                   [DateLastModified]	DATETIME,
                   [Attributes]		INT,
                   [size]		BIGINT,
                   [error]		VARCHAR(2000))

AS
--	======================================================================================
--	Revision History
--	Date		Author     		Desc
--	==========	====================	=============================================
--	01/25/2013	Steve Ledridge		Made sure all OA Objects are destroyed at end of sproc.
--	======================================================================================
BEGIN
DECLARE @hr			INT,		--the HRESULT returned from
       @objFileSystem		INT,		--the FileSystem object
       @objFile			INT,		--the File object
       @ErrorObject		INT,		--the error object
       @ErrorMessage		VARCHAR(255),	--the potential error message
       @Path			VARCHAR(5000),
       @ShortPath		VARCHAR(2000),
       @Type			VARCHAR(100),
       @DateCreated		DATETIME,
       @DateLastAccessed	DATETIME,
       @DateLastModified	DATETIME,
      @directory		VARCHAR(2000),
      @MyID			INT,
       @Attributes		INT,
       @size			BIGINT,
      @ii			INT,
      @iiMax			INT,
      @command			VARCHAR(8000),
      @FileName			VARCHAR(8000),
      @more			INT

DECLARE @FileAndDirectoryList TABLE
                   (MyID INT IDENTITY(1,1),
                   [name] VARCHAR(1000),
                   FullPathName VARCHAR(2000),
                   [isFolder] INT,
                   [ModifyDate] DATETIME,
                   [error] VARCHAR(2000),
                   [recursed] INT DEFAULT 0
                   )


SET @more=1


INSERT INTO  @FileAndDirectoryList([name],fullPathName, [ModifyDate], IsFolder, error)
   SELECT [name], [path], [ModifyDate], IsFolder, error
       FROM DBAOps.dbo.dbaudf_Dir(@wildcard)
       WHERE IsFileSystem =1
IF EXISTS (SELECT * FROM  @FileAndDirectoryList WHERE error IS NOT NULL)
   RETURN
WHILE @subdirectories<>0 AND @more>0
   BEGIN
   SELECT TOP 1  @MyID= MyID
       FROM  @FileAndDirectoryList WHERE isFolder=1 AND recursed =0
   SET @more= @@rowcount
   IF @more > 0
       BEGIN
       SELECT @directory= LEFT([FullPathName],2000)
               FROM  @FileAndDirectoryList
               WHERE MyID=@MyID
       INSERT INTO  @FileAndDirectoryList
                   ([name],fullPathName,[ModifyDate], IsFolder, error)
           SELECT [name],[path],[ModifyDate],IsFolder,error
               FROM dbo.dbaudf_dir(@directory)
               WHERE IsFileSystem =1
       UPDATE  @FileAndDirectoryList SET recursed=1 WHERE MyID=@MyID
       END
   END
INSERT INTO @fileTable ([name],fullPathName,DateLastModified)
   SELECT  [Name], fullPathName, [ModifyDate]
       FROM @FileAndDirectoryList WHERE isFolder=0
           OR REVERSE(fullPathName) LIKE 'piz.%'
SELECT @hr=0,@errorMessage='opening the file system object '
EXEC @hr = sp_OACreate 'Scripting.FileSystemObject',@objFileSystem OUT

SELECT @ii=MIN(MyID), @iiMax=MAX(MyID) FROM @FileTable
WHILE @hr=0 AND @ii<=@iiMax AND @Details<>0
   BEGIN
   SELECT @Filename=FullPathName FROM @fileTable
               WHERE MyID=@ii
   IF @hr=0
      SELECT @errorMessage='getting the attributes of '''
                                      +@Filename+'''',
          @ErrorObject=@objFileSystem
   IF @hr=0 EXEC @hr = sp_OAMethod @objFileSystem,
        'GetFile',  @objFile OUT,@Filename
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'ShortPath', @ShortPath OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'Type', @Type OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'DateCreated', @DateCreated OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'DateLastAccessed', @DateLastAccessed OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'DateLastModified', @DateLastModified OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'Attributes', @Attributes OUT
   IF @hr=0 EXEC @hr = sp_OAGetProperty
                @objFile, 'size', @size OUT
   IF @hr=0
       UPDATE @FileTable
           SET [ShortPath]			= @ShortPath,
               [Type]				= @Type,
               [DateCreated]		= @DateCreated ,
               [DateLastAccessed]	= @DateLastAccessed,
               [DateLastModified]	= @DateLastModified,
               [Attributes]			= @Attributes,
               [size]				= @size
           WHERE MyID=@ii
   SELECT @ii=@ii+1
   END
IF @hr<>0
       BEGIN
       DECLARE
               @Source VARCHAR(255),
               @Description VARCHAR(255),
               @Helpfile VARCHAR(255),
               @HelpID INT

       EXECUTE sp_OAGetErrorInfo  @errorObject,
               @source OUTPUT,@Description OUTPUT,
                               @Helpfile OUTPUT,@HelpID OUTPUT

       SELECT @ErrorMessage='Error whilst '
                               +@Errormessage+', '
                               +@Description
       INSERT INTO @FileTable (error) SELECT  LEFT(@ErrorMessage,2000)
       END
EXEC sp_OADestroy @objFileSystem
EXEC sp_OADestroy @objFile
RETURN
END
GO
