SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[UpdateDBAaadminBuild]
	@DatabaseName 	varchar(30),
	@vchLabel 	varchar(100),
        @vchNotes       varchar(255) = NULL
AS
/* ---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Procedure: UpdateDBAaadminBuild
--
-- For: Virtuoso
--
-- Revision History
--      Modified 3/20/2001 - Modified sproc to accept the parameter of
--                           @vchNotes and changed the parameter of
--                           iBuildNumber to vchLabel.
--
-- Purpose
--  Inserts a record into DBAOps..Build when the build
--  gets run.
--
--
---------------------------------------------------------------------------
--------------------------------------------------------------------------- */
INSERT INTO dbo.Build
 (
	vchName,
 	vchLabel,
 	dtBuildDate,
        vchNotes
 )
VALUES
 (
 	@DatabaseName,
 	@vchLabel,
 	GETDATE(),
        @vchNotes
 )
GO
GRANT EXECUTE ON  [dbo].[UpdateDBAaadminBuild] TO [public]
GO
