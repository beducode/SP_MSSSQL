USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_PD_CHR_SUMM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_PD_CHR_SUMM] @DOWNLOAD_DATE DATE = '',                                         
 @RULE_ID INT = 0              
AS           
BEGIN           
 DECLARE @V_CURRDATE   DATE                                                                          
 DECLARE @V_PREVDATE   DATE            
 DECLARE @V_PREVMONTH DATE         
 DECLARE @LAST_YEAR DATE        
         
        
 IF @DOWNLOAD_DATE <> ''          
BEGIN           
SET @V_CURRDATE = EOMONTH(DATEADD(MONTH,-1,@DOWNLOAD_DATE)) -- LAG -1 MONTH BTPN          
SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)          
SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))          
END          
ELSE           
BEGIN         
SELECT @V_CURRDATE = EOMONTH(DATEADD(M,-1,CURRDATE) )          
FROM IFRS_PRC_DATE        
SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)        
SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))   
END        
          
        
-- get list date to calculate this month         
DECLARE @PD_RULE_ID INT         
DECLARE @HISTORICAL_DATA INT         
DECLARE @INCREMENT_PERIOD INT         
DECLARE @CUT_OFF_DATE DATE         
DECLARE @MIN_DATE DATE         
DECLARE @MAX_DATE DATE        
DECLARE @LIST_DATE DATE         
        
        
-- INITIAL INSERT BASE DETAIL DATA         
DELETE A          
FROM [IFRS_PD_CHR_BASE_DATA] A         
INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID         
WHERE DOWNLOAD_DATE =  EOMONTH(DATEADD(M,B.INCREMENT_PERIOD*-1,@V_CURRDATE)) AND A.PD_RULE_ID = @RULE_ID    
        
INSERT INTO [IFRS_PD_CHR_BASE_DATA] (DOWNLOAD_DATE        
,PROJECTION_DATE        
,PD_RULE_ID        
,PD_RULE_NAME        
,BUCKET_GROUP        
,PD_UNIQUE_ID        
,SEGMENT        
,CALC_METHOD        
,BUCKET_ID        
,BUCKET_NAME        
,OUTSTANDING        
,DEFAULT_FLAG        
,BI_COLLECTABILITY        
,RATING_CODE        
,DAY_PAST_DUE        
,NEXT_12M_DEFAULT_FLAG)        
SELECT DOWNLOAD_DATE        
,EOMONTH(@V_CURRDATE) AS PROJECTION_DATE        
,PD_RULE_ID        
,MAX(PD_RULE_NAME)        
,MAX(A.BUCKET_GROUP)        
,A.PD_UNIQUE_ID        
,MAX(SEGMENT)        
,MAX(A.CALC_METHOD)        
,MAX(A.BUCKET_ID)        
,MAX(CASE WHEN C.BUCKET_NAME IS NULL THEN 'FP' ELSE C.BUCKET_NAME END) AS BUCKET_NAME        
,SUM(OUTSTANDING)        
,MAX(CASE WHEN DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS DEFAULT_FLAG        
,MAX(BI_COLLECTABILITY)        
,MAX(RATING_CODE)        
,MAX(DAY_PAST_DUE)        
,MAX(CASE WHEN NEXT_12M_DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS NEXT_12M_DEFAULT_FLAG         
FROM IFRS_PD_SCENARIO_DATA A         
INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID AND  B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0        
LEFT JOIN (SELECT * FROM IFRS_BUCKET_DETAIL WHERE IS_DELETE = 0 AND ACTIVE_FLAG = 1) C  ON A.BUCKET_GROUP = C.BUCKET_GROUP AND A.BUCKET_ID = C.BUCKET_ID         
 WHERE  DOWNLOAD_DATE = EOMONTH(DATEADD(M,B.INCREMENT_PERIOD*-1,@V_CURRDATE)) AND  A.PD_METHOD = 'CHR' AND A.PD_RULE_ID = @RULE_ID    
 GROUP BY DOWNLOAD_DATE,PD_RULE_ID,PD_UNIQUE_ID        
        
        
TRUNCATE TABLE TMP_IFRS_PD_LIST_DATE         
        
DECLARE LOOP_DATE1                   
  CURSOR FOR  SELECT PKID AS PD_RULE_ID ,HISTORICAL_DATA, INCREMENT_PERIOD, CUT_OFF_DATE FROM IFRS_PD_RULES_CONFIG 
  WHERE  IS_DELETE = 0 AND ACTIVE_FLAG = 1 AND PD_METHOD = 'CHR'    AND PKID = @RULE_ID
  AND CUT_OFF_DATE <= EOMONTH(DATEADD(M,INCREMENT_PERIOD*-1, @V_CURRDATE))        
  OPEN LOOP_DATE1        
  FETCH LOOP_DATE1 INTO @PD_RULE_ID, @HISTORICAL_DATA,@INCREMENT_PERIOD,@CUT_OFF_DATE        
  WHILE @@FETCH_STATUS = 0         
 BEGIN        
         
 SET @MIN_DATE = EOMONTH(DATEADD(M,@HISTORICAL_DATA*-1, @V_CURRDATE))         
 SET @MAX_DATE = EOMONTH(DATEADD(M,@INCREMENT_PERIOD*-1, @V_CURRDATE))        
         
 WHILE @MIN_DATE <= @MAX_DATE        
 BEGIN         
  INSERT INTO TMP_IFRS_PD_LIST_DATE         
  (PD_RULE_ID        
  ,LIST_DATE        
  ,REMARK)        
  SELECT @PD_RULE_ID AS PD_RULE_ID        
  ,@MIN_DATE AS LIST_DATE        
  ,'SP_IFRS_IMP_PD_CHR_SUMM' AS REMARK        
  WHERE @CUT_OFF_DATE<= @MIN_DATE        
SET @MIN_DATE = EOMONTH(DATEADD(M,@INCREMENT_PERIOD,@MIN_DATE))        
 END         
 FETCH NEXT FROM LOOP_DATE1 INTO  @PD_RULE_ID, @HISTORICAL_DATA,@INCREMENT_PERIOD,@CUT_OFF_DATE        
 END         
CLOSE LOOP_DATE1        
DEALLOCATE LOOP_DATE1        
        
TRUNCATE TABLE [TMP_IFRS_PD_CHR_BASE_DATA]        
INSERT INTO [TMP_IFRS_PD_CHR_BASE_DATA]         
SELECT a.* FROM IFRS_PD_CHR_BASE_DATA a        
inner join TMP_IFRS_PD_LIST_DATE b on A.PD_RULE_ID = B.PD_RULE_ID AND  A.DOWNLOAD_DATE = B.LIST_DATE  
AND A.PD_RULE_ID = @RULE_ID       
        
set @PD_RULE_ID = null        
        
DELETE [IFRS_PD_CHR_DATA] WHERE PROJECTION_DATE = @V_CURRDATE  AND PD_RULE_ID  = @RULE_ID    
        
DECLARE LOOP_DATE                   
  CURSOR FOR  SELECT PD_RULE_ID, LIST_DATE from TMP_IFRS_PD_LIST_DATE WHERE PD_RULE_ID = @RULE_ID      
  OPEN LOOP_DATE        
  FETCH LOOP_DATE INTO @PD_RULE_ID, @LIST_DATE        
 WHILE @@FETCH_STATUS = 0         
 BEGIN        
         
  IF OBJECT_ID ('TEMPDB.DBO.#BASE') IS NOT NULL DROP TABLE #BASE        
  SELECT * INTO #BASE        
  FROM [TMP_IFRS_PD_CHR_BASE_DATA] WHERE DOWNLOAD_DATE = @LIST_DATE   AND PD_RULE_ID = @PD_RULE_ID         
           
  IF OBJECT_ID ('TEMPDB.DBO.#NEXT_PERIOD') IS NOT NULL DROP TABLE #NEXT_PERIOD        
  SELECT @V_CURRDATE AS PROJECTION_DATE,A.PD_RULE_ID,PD_UNIQUE_ID,MAX(CASE WHEN NEXT_12M_DEFAULT_FLAG = 1 THEN 1 ELSE 0 END) AS NEXT_12M_DEFAULT_FLAG          
  INTO #NEXT_PERIOD  FROM  [TMP_IFRS_PD_CHR_BASE_DATA] A         
  WHERE  A.PD_RULE_ID = @PD_RULE_ID  AND DOWNLOAD_DATE>= @LIST_DATE        
  GROUP BY A.PD_RULE_ID,PD_UNIQUE_ID        
        
   INSERT INTO [IFRS_PD_CHR_DATA] (DOWNLOAD_DATE        
  ,PROJECTION_DATE        
  ,PD_RULE_ID        
  ,PD_RULE_NAME        
  ,BUCKET_GROUP        
  ,PD_UNIQUE_ID        
  ,SEGMENT        
  ,CALC_METHOD        
  ,BUCKET_ID        
  ,BUCKET_NAME        
  ,OUTSTANDING        
  ,DEFAULT_FLAG        
  ,BI_COLLECTABILITY        
  ,RATING_CODE        
  ,DAY_PAST_DUE        
  ,NEXT_12M_DEFAULT_FLAG)        
  SELECT A.DOWNLOAD_DATE        
  ,@V_CURRDATE AS PROJECTION_DATE        
  ,A.PD_RULE_ID        
  ,A.PD_RULE_NAME        
  ,A.BUCKET_GROUP        
  ,A.PD_UNIQUE_ID        
  ,A.SEGMENT        
  ,A.CALC_METHOD        
  ,A.BUCKET_ID        
  ,CASE WHEN A.BUCKET_ID = 0 THEN 'FP' ELSE A.BUCKET_NAME END         
  ,A.OUTSTANDING        
  ,A.DEFAULT_FLAG        
  ,A.BI_COLLECTABILITY        
  ,A.RATING_CODE        
  ,A.DAY_PAST_DUE        
  ,B.NEXT_12M_DEFAULT_FLAG FROM #BASE A         
  LEFT JOIN #NEXT_PERIOD B ON  A.PD_RULE_ID = B.PD_RULE_ID AND A.PD_UNIQUE_ID =  B.PD_UNIQUE_ID    
  AND A.PD_RULE_ID = @RULE_ID    
        
 FETCH NEXT FROM LOOP_DATE INTO  @PD_RULE_ID, @LIST_DATE        
 END        
CLOSE LOOP_DATE        
DEALLOCATE LOOP_DATE        
        
DELETE [IFRS_PD_CHR_SUMM] WHERE PROJECTION_DATE = @V_CURRDATE   AND PD_RULE_ID= @RULE_ID     
        
INSERT INTO [dbo].[IFRS_PD_CHR_SUMM] (DOWNLOAD_DATE        
,PROJECTION_DATE        
,PD_RULE_ID        
,PD_RULE_NAME        
,SEGMENT        
,CALC_METHOD        
,BUCKET_GROUP        
,BUCKET_ID        
,BUCKET_NAME        
,SEQ_YEAR        
,TOTAL_COUNT        
,TOTAL_DEFAULT        
,CUMULATIVE_ODR        
,MARGINAL_COUNT        
,MARGINAL_DEFAULT_COUNT        
,MARGINAL_ODR        
,CREATEDBY        
,CREATEDDATE)        
SELECT A.DOWNLOAD_DATE        
,@V_CURRDATE AS PROJECTION_DATE        
,A.PD_RULE_ID AS PD_RULE_ID        
,MAX(A.PD_RULE_NAME)        
,MAX(A.SEGMENT)        
,MAX(A.CALC_METHOD)        
,MAX(A.BUCKET_GROUP) AS BUCKET_GROUP        
,A.BUCKET_ID        
,MAX(A.BUCKET_NAME) AS BUCKET_NAME        
,DATEDIFF(MONTH, DOWNLOAD_DATE,PROJECTION_DATE)/MAX(B.INCREMENT_PERIOD) AS SEQ_YEAR        
,COUNT(1) AS TOTAL_COUNT        
,SUM (CASE WHEN NEXT_12M_DEFAULT_FLAG  = 1 THEN 1 ELSE 0 END ) AS TOTAL_DEFAULT        
,CAST(SUM (CASE WHEN NEXT_12M_DEFAULT_FLAG  = 1 THEN 1 ELSE 0 END ) AS FLOAT)/CAST(COUNT(1) AS FLOAT)  AS CUMULATIVE_ODR        
,NULL AS MARGINAL_COUNT        
,NULL AS MARGINAL_DEFAULT_COUNT        
,NULL AS MARGINAL_ODR        
,'SYSTEM' AS CREATEDBY        
,GETDATE() AS CREATEDDATE        
FROM [IFRS_PD_CHR_DATA] A         
INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID WHERE PROJECTION_DATE = @V_CURRDATE  AND A.PD_RULE_ID = @RULE_ID
GROUP BY A.PD_RULE_ID, A.DOWNLOAD_DATE,A.PROJECTION_DATE, A.BUCKET_ID         
ORDER BY A.PD_RULE_ID,A.DOWNLOAD_DATE,A.PROJECTION_DATE, A.BUCKET_ID        
        
--- UPDATE MARGINAL         
--IF OBJECT_ID ('TEMPDB.DBO.#CHR_CURR') IS NOT NULL DROP TABLE #CHR_CURR        
--SELECT * INTO #CHR_CURR FROM [IFRS_PD_CHR_SUMM] WHERE PROJECTION_DATE = @V_CURRDATE        
        
IF OBJECT_ID ('TEMPDB.DBO.#CHR_PREV') IS NOT NULL DROP TABLE #CHR_PREV        
SELECT A.* INTO #CHR_PREV FROM [IFRS_PD_CHR_SUMM] A INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID         
 WHERE PROJECTION_DATE = EOMONTH(DATEADD(M,B.INCREMENT_PERIOD*-1,@V_CURRDATE))  AND A.PD_RULE_ID = @RULE_ID      
        
UPDATE A        
SET MARGINAL_COUNT   = isnull(A.TOTAL_COUNT,0) - isnull(B.TOTAL_COUNT,0)        
,MARGINAL_DEFAULT_COUNT = isnull(A.TOTAL_DEFAULT,0) - isnull(B.TOTAL_DEFAULT,0)        
,MARGINAL_ODR =  CAST(isnull(A.TOTAL_DEFAULT,0) - isnull(B.TOTAL_DEFAULT,0) AS FLOAT)/A.TOTAL_COUNT        
FROM [IFRS_PD_CHR_SUMM] A        
LEFT JOIN #CHR_PREV B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.PD_RULE_ID = B.PD_RULE_ID AND A.BUCKET_ID = B.BUCKET_ID        
WHERE A.PROJECTION_DATE = @V_CURRDATE   AND A.PD_RULE_ID = @RULE_ID  
        
        
  
END 

GO
