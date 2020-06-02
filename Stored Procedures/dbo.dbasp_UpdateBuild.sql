SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [dbo].[dbasp_UpdateBuild]
	@DatabaseName 	varchar(30),
	@vchLabel 	varchar(100),
        @vchNotes       varchar(255) = NULL
AS
/* ---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Procedure: dbasp_UpdateBuild
--
-- For: Virtuoso
--
-- Revision History
--      Modified 3/20/2001 - Modified sproc to accept the parameter of
--                           @vchNotes and changed the parameter of
--                           iBuildNumber to vchLabel.
--
-- Purpose
--  Inserts a record into dbo.Build.
--
--
---------------------------------------------------------------------------
--------------------------------------------------------------------------- */
INSERT INTO Build
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
GRANT EXECUTE ON  [dbo].[dbasp_UpdateBuild] TO [public]
GO
