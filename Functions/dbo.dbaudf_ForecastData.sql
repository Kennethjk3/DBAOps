SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[dbaudf_ForecastData](@Data VarChar(max),@HistEvalLimit Int = 10,@SmoothingRange Int = 1,@KeyDataType VarChar(50) = 'BigInt')
RETURNS @DataTable TABLE
(
    -- columns returned by the function
    Period VarChar(20) NULL,
    Value Float NULL,
    SmValue Float NULL,
    CntUp int NULL,
    History Bit NULL
)
AS
BEGIN
	DECLARE	@HistoryCount		BigInt
	DECLARE	@ForecastCount		BigInt	= 0
	DECLARE	@MaxPeriod		BigInt
	DECLARE	@Interval			Int
	DECLARE	@SaveValue		Int
	DECLARE	@RSquared			FLOAT	= 0
	DECLARE	@MinDate			DateTime
	DECLARE	@MaxDate			DateTime



	-- POPULATE HISTORY DATA

	IF @KeyDataType = 'DateTime'
	BEGIN

	--DECLARE	@Data			VarChar(max)	= '2017-01-09 15:31:03=0|2017-01-09 15:25:58=0|2017-01-09 15:20:54=0|2017-01-09 15:15:49=0|2017-01-09 15:10:44=0|2017-01-09 15:05:40=0|2017-01-09 15:00:36=0|2017-01-09 14:55:32=0|2017-01-09 14:50:27=0|2017-01-09 14:45:23=0|2017-01-09 14:40:18=0|2017-01-09 14:35:10=0|2017-01-09 14:30:06=0|2017-01-09 14:25:03=0|2017-01-09 14:19:56=0|2017-01-09 14:14:49=0|2017-01-09 14:09:47=0|2017-01-09 14:04:41=0|2017-01-09 13:59:36=0|2017-01-09 13:54:31=0|2017-01-09 13:49:26=0|2017-01-09 13:44:22=0|2017-01-09 13:39:16=0|2017-01-09 13:34:07=0|2017-01-09 13:29:02=0|2017-01-09 13:23:59=0|2017-01-09 13:18:56=0|2017-01-09 13:13:51=0|2017-01-09 13:08:46=0|2017-01-09 13:03:42=0|2017-01-09 12:58:34=0|2017-01-09 12:53:30=0|2017-01-09 12:48:26=0|2017-01-09 12:43:23=0|2017-01-09 12:38:17=0|2017-01-09 12:33:13=0|2017-01-09 12:28:10=0|2017-01-09 12:23:06=0|2017-01-09 12:18:01=0|2017-01-09 12:12:56=0|2017-01-09 12:07:51=0|2017-01-09 12:02:47=0|2017-01-09 11:57:44=0|2017-01-09 11:52:39=0|2017-01-09 11:47:33=|2017-01-09 11:42:29=0|2017-01-09 11:37:21=0|2017-01-09 11:32:17=0|2017-01-09 11:27:09=0|2017-01-09 11:22:01=0'
	--DECLARE	@MinDate			DateTime
	--DECLARE	@MaxDate			DateTime
	--DECLARE	@HistoryCount		BigInt
	--DECLARE	@HistEvalLimit		INT			= 24
	--DECLARE	@DataTable TABLE	(
	--						Period VarChar(20) NOT NULL,
	--						Value Float NOT NULL,
	--						SmValue Float NULL,
	--						CntUp int NOT NULL,
	--						History Bit NOT NULL
	--						)

		SELECT		@MinDate = MIN(CAST([Label] AS DateTime))
					,@MaxDate = DATEADD	(
									Minute
									,DATEDIFF	(
											Minute
											,MIN(CAST([Label] AS DateTime))
											,MAX(CAST([Label] AS DateTime))
											) * 2
									,MAX(CAST([Label] AS DateTime))
									)
					,@HistoryCount = COUNT(*)
		FROM			DBAOps.dbo.dbaudf_StringToTable_Pairs(@Data,'|','=')

		INSERT INTO	@DataTable ([Period],[Value],[CntUp],[History])
		SELECT		CAST	(
						DATEDIFF	(
								ss
								,DATEADD(ss,-1,@MinDate)
								,CAST([Label] AS DateTime)
								)
						AS BigInt
						) [Period]
					,CAST([Value] AS Float) [Value]
					,ROW_NUMBER() OVER (ORDER BY CAST([Label] AS DateTime)) [CntUp]
					,1 [History]
		FROM			DBAOps.dbo.dbaudf_StringToTable_Pairs(@Data,'|','=') T1

		SET @HistoryCount = @@ROWCOUNT

	END
	ELSE
	BEGIN
		INSERT INTO	@DataTable ([Period],[Value],[CntUp],[History])
		SELECT		CAST([Label] AS BigInt)
					,CAST([Value] AS Float)
					,ROW_NUMBER() OVER (ORDER BY CAST([Label] AS BigInt)) [CntUp]
					,1
		FROM			DBAOps.dbo.dbaudf_StringToTable_Pairs(@Data,'|','=')

		SET @HistoryCount = @@ROWCOUNT
	END

	IF @HistoryCount < @HistEvalLimit
		SET @HistEvalLimit = @HistoryCount

	-- CALCULATE AVERAGE INTERVAL FOR PASSED IN PERIODS
	SELECT	@MaxPeriod = MAX([Period])
			,@Interval = AVG([Interval])
	FROM		(
			SELECT	[Period]
					,[Period] - (SELECT MAX(CAST([Period] AS BigInt)) FROM @DataTable WHERE CAST([Period] AS BigInt) < T1.[Period]) [Interval]
			FROM		(
					SELECT	TOP(@HistEvalLimit)
							CAST([Period] AS BigInt) [Period]
							,[Value]
							,[SmValue]
							,[CntUp]
							,[History]
					FROM		@DataTable
					ORDER BY	[Period] DESC
					)T1
			WHERE	(SELECT MAX(CAST([Period] AS BigInt)) FROM @DataTable WHERE CAST([Period] AS BigInt) < T1.[Period]) IS NOT NULL
			)T1

	-- SET SMOOTHED VALUES BY AVERAGING RANGE OF RECORDS
	UPDATE	T1
		SET	SmValue = T2.SmValue
	FROM		@DataTable T1
	JOIN		(
			SELECT	T1.Period
					,T1.Value
					,AVG(T2.Value) [SmValue]
			FROM		@DataTable T1
			LEFT JOIN	@DataTable T2
				ON	T2.CntUp			>= T1.CntUp - @SmoothingRange
				AND	T2.CntUp			<= T1.CntUp + @SmoothingRange
			GROUP BY	T1.Period
					,T1.Value
			)T2
		ON	T1.Period = T2.Period

	SET @SaveValue = @HistEvalLimit

	-- GENERATE FORECASTED VALUES
	WHILE @ForecastCount < @HistoryCount
	BEGIN
		SET @ForecastCount += 1
		SET @HistEvalLimit = @SaveValue + 1
		SET @RSquared = 0

		-- REDUCE HISTOR BEING EVALUATED UNTIL RSquared (Confidence Factor) Is at least .5 the clossest to 1.0 is the most reliable.
		WHILE @RSquared < .5 AND  @HistEvalLimit >= (@SaveValue/2)
		BEGIN
			SET @HistEvalLimit -= 1

			SELECT	@RSquared = [RSquared]
			FROM		(
					SELECT	@MaxPeriod + (@Interval * @ForecastCount) [Period]
							,MAX([CntUp]) +1 [CntUp]
							,MAX([Value]) [MaxValue]
							,MIN([Value]) [MinValue]
							,DBAOps.dbo.dbaudf_Slope		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[Slope]
							,DBAOps.dbo.dbaudf_Intercept	(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[Intercept]
							,DBAOps.dbo.dbaudf_RSquared		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[RSquared]

							,MAX([Value]) [SmMaxValue]
							,MIN([Value]) [SmMinValue]
							,DBAOps.dbo.dbaudf_Slope		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmSlope]
							,DBAOps.dbo.dbaudf_Intercept	(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmIntercept]
							,DBAOps.dbo.dbaudf_RSquared		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmRSquared]
							,0 [History]
					FROM		(
							SELECT	TOP(@HistEvalLimit)
									CAST([Period] AS BigInt) [Period]
									,[Value]
									,[SmValue]
									,[CntUp]
									,[History]
							FROM		@DataTable
							ORDER BY	[Period] DESC
							)T1
					)T1
		END

		-- INSERT FORECASTED VALUES
		INSERT INTO @DataTable ([Period],[Value],[SmValue],[CntUp],[History])
		SELECT	[Period]
				,[Intercept]+([Slope]*[Period]) [Value]
				,[SmIntercept]+([SmSlope]*[Period]) [smValue]
				,[CntUp]
				,[History]
		FROM		(
				SELECT	MAX([Period]) + @Interval [Period]
						,MAX([CntUp]) +1 [CntUp]
						,MAX([Value]) [MaxValue]
						,MIN([Value]) [MinValue]
						,DBAOps.dbo.dbaudf_Slope		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[Slope]
						,DBAOps.dbo.dbaudf_Intercept	(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[Intercept]
						,DBAOps.dbo.dbaudf_RSquared		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[RSquared]

						,MAX([Value]) [SmMaxValue]
						,MIN([Value]) [SmMinValue]
						,DBAOps.dbo.dbaudf_Slope		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmSlope]
						,DBAOps.dbo.dbaudf_Intercept	(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmIntercept]
						,DBAOps.dbo.dbaudf_RSquared		(CAST([Period] as nVarChar(100))	+ CHAR(0) +	CAST([Value] as nVarChar(100)))	[SmRSquared]
						,0 [History]
				FROM		(
						SELECT	TOP(@HistEvalLimit)
								CAST([Period] AS BigInt) [Period]
								,[Value]
								,[SmValue]
								,[CntUp]
								,[History]
						FROM		@DataTable
						ORDER BY	[Period] DESC
						)T1
				)T1

	END


	IF @KeyDataType = 'DateTime'
	BEGIN
		UPDATE		@DataTable
			SET		[Period] = CONVERT(VarChar(20),DATEADD(ss,CAST([Period] AS BigInt),DATEADD(ss,-1,@MinDate)),120)
	END

   RETURN
END
GO
