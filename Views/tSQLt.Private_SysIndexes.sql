SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [tSQLt].[Private_SysIndexes] AS SELECT * FROM sys.indexes;
GO
GRANT SELECT ON  [tSQLt].[Private_SysIndexes] TO [public]
GO
