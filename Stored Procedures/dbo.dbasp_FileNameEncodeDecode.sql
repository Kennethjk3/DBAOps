SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_FileNameEncodeDecode]
			(
			@OriginalFileName	nvarchar(4000) = NULL OUT
			,@Data			nvarChar(4000) = NULL OUT
			,@EncodedFileName	nvarChar(4000) = NULL OUT
			)
AS
BEGIN
	DECLARE @FileAndData XML
	IF @Data IS NULL
	BEGIN
		PRINT '@Data is Null : DECODE MODE'


		SELECT @FileAndData = [DBAOps].[dbo].[dbaudf_base64_decode] (@EncodedFileName)


		SELECT	@OriginalFileName = a.b.value('FileName[1]','nVarChar(4000)')
			, @Data = a.b.value('Data[1]','nVarChar(4000)')
		FROM @FileAndData.nodes('/root') a(b)

	END
	ELSE
	BEGIN
		PRINT '@Data is NOT Null : ENCODE MODE'
		SELECT @EncodedFileName = [DBAOps].[dbo].[dbaudf_base64_encode] ('<root><FileName>'+@OriginalFileName+'</FileName><Data>'+@Data+'</Data></root>')
	END


END
GO
GRANT EXECUTE ON  [dbo].[dbasp_FileNameEncodeDecode] TO [public]
GO
