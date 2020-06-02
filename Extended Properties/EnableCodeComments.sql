DECLARE @xp int
SELECT @xp=0
EXEC sp_addextendedproperty N'EnableCodeComments', @xp, NULL, NULL, NULL, NULL, NULL, NULL
GO
