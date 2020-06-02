SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_SelfRegister_DBA_ClusterInfo] 
					(
					@ForceUpgrade BIT = 0
					)
AS
BEGIN
		IF OBJECT_ID('DBA_ClusterInfo') IS NOT NULL AND @ForceUpgrade = 1
		BEGIN
			RAISERROR ('"@ForceUpgrade = 1" so existing Table is being Dropped',-1,-1) WITH NOWAIT
			DROP TABLE [dbo].[DBA_ClusterInfo]
		END

		IF OBJECT_ID('DBA_ClusterInfo') IS NULL
		BEGIN
			RAISERROR ('Creating New DBA_ClusterInfo Table',-1,-1) WITH NOWAIT

			SELECT		*
			INTO		DBA_ClusterInfo
			FROM		(

						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterResource()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNode()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNetwork()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNetworkInterface()
						) Data

		END
		ELSE
		BEGIN
			RAISERROR ('Re-Populating DBA_ClusterInfo Table',-1,-1) WITH NOWAIT

			DELETE		[dbo].[DBA_ClusterInfo]

			INSERT INTO	DBA_ClusterInfo
			SELECT		*
			FROM		(

						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterResource()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNode()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNetwork()
						UNION ALL
						SELECT @@SERVERNAME [ServerName], GETDATE() [moddate], * FROM dbo.dbaudf_ListClusterNetworkInterface()
						) Data
		END
END
GO
GRANT EXECUTE ON  [dbo].[dbasp_SelfRegister_DBA_ClusterInfo] TO [public]
GO
