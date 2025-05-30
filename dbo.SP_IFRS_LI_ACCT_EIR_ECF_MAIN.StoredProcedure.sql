USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_EIR_ECF_MAIN]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_EIR_ECF_MAIN]                  
AS                  
DECLARE @V_CURRDATE DATE                  
 ,@V_PREVDATE DATE                  
 ,@VMIN_ID BIGINT                  
 ,@VMAX_ID BIGINT                  
 ,@VX BIGINT                  
 ,@ID2 BIGINT                  
 ,@VX_INC BIGINT                  
 ,@PARAM_DISABLE_ACCRU_PREV BIGINT                  
 ,@V_ROUND INT                  
 ,@V_FUNCROUND INT                  
                  
BEGIN                  
 SELECT @V_CURRDATE = MAX(CURRDATE)                  
  ,@V_PREVDATE = MAX(PREVDATE)                  
 FROM IFRS_LI_PRC_DATE_AMORT                  
                  
 SELECT @V_ROUND = CAST(VALUE1 AS INT)                  
  ,@V_FUNCROUND = CAST(VALUE2 AS INT)                  
 FROM TBLM_COMMONCODEDETAIL                  
 WHERE COMMONCODE = 'SCM003'                  
                  
 --DISABLE ACCRU PREV CREATE ON NEW ECF AND RETURN ACCRUAL TO UNAMORT                      
 --ADD YAHYA                    
 SELECT @PARAM_DISABLE_ACCRU_PREV = CASE                   
   WHEN COMMONUSAGE = 'Y'                  
    THEN 1                  
   ELSE 0                  
   END                  
 FROM TBLM_COMMONCODEHEADER                  
 WHERE COMMONCODE = 'SCM013' -- 'CALC_FROM_LASTPAYMDATE'                  

 --SET @PARAM_DISABLE_ACCRU_PREV = 1                        
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'START'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,''                  
  )                  
                  
 --RESET DATA BEFORE PROCESSING                            
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_ACCRU_PREV                  
 WHERE DOWNLOAD_DATE >= @V_CURRDATE                  
  AND SRCPROCESS = 'ECF'                  
                  
 UPDATE IFRS_LI_ACCT_COST_FEE                  
 SET STATUS = 'ACT'                  
 WHERE STATUS = 'PNL'                  
  AND CREATEDBY = 'EIRECF1'                  
  AND DOWNLOAD_DATE = @V_CURRDATE                  
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_PREV                  
 SET STATUS = 'ACT'                  
 WHERE STATUS = 'PNL'                  
  AND CREATEDBY = 'EIRECF2'                  
  AND DOWNLOAD_DATE = @V_CURRDATE                  
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_PREV                  
 SET STATUS = 'ACT'                  
 WHERE STATUS = 'PNL2'                  
  AND CREATEDBY = 'EIRECF2'                  
  AND DOWNLOAD_DATE = @V_PREVDATE                  
                  
 TRUNCATE TABLE TMP_LI_T7                  
                  
 INSERT INTO TMP_LI_T7 (                  
  MID                  
  ,STAFFLOAN                  
  ,PKID                  
  ,NPVRATE                  
  )                  
 SELECT A.MASTERID                  
  ,CASE                   
   WHEN COALESCE(STAFF_LOAN_FLAG, 'N') IN (                  
     'N'                  
     ,''                  
     )                  
    THEN 0                  
   ELSE 1                  
   END                  
  ,A.ID                  
  ,CASE                   
   WHEN STAFF_LOAN_FLAG = 'Y'                  
    THEN COALESCE(P.MARKET_RATE, 0)                  
   ELSE 0                  
   END MARKET_RATE                  
 FROM IFRS_LI_IMA_AMORT_CURR A                  
 LEFT JOIN IFRS_LI_PRODUCT_PARAM P ON P.DATA_SOURCE = A.DATA_SOURCE                  
  AND (P.PRD_TYPE = A.PRODUCT_TYPE OR P.PRD_TYPE = 'ALL')    
  AND (P.PRD_CODE = A.PRODUCT_CODE OR P.PRD_CODE = 'ALL')               
  AND (P.CCY = A.CURRENCY OR ISNULL(P.CCY, 'ALL') = 'ALL')                  
 WHERE A.EIR_STATUS = 'Y'                  
  AND A.AMORT_TYPE <> 'SL'                
                  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_CF_ECF                  
                  
 --20180116 ACCT WITH REVERSAL TODAY                            
 SELECT MASTERID                  
 INTO #TODAYREV                  
 FROM IFRS_LI_ACCT_COST_FEE     
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND FLAG_REVERSE = 'Y'                  
  AND CF_ID_REV IS NOT NULL                  
                  
 -- TODAY NEW COST FEE                            
 INSERT INTO IFRS_LI_ACCT_EIR_CF_ECF (                  
  MASTERID                  
  ,FEE_AMT                  
  ,COST_AMT                  
  ,FEE_AMT_ACRU                  
  ,COST_AMT_ACRU                  
  ,STAFFLOAN                  
  ,PKID                  
  ,NPV_RATE                  
  ,GAIN_LOSS_CALC --20180226 SET N                          
  )                  
 SELECT A.MID                  
  ,SUM(COALESCE(CASE                   
     WHEN C.FLAG_CF = 'F'                  
      THEN CASE                   
        WHEN C.FLAG_REVERSE = 'Y'                  
         THEN - 1 * C.AMOUNT                  
        ELSE C.AMOUNT                  
        END                  
     ELSE 0                  
     END, 0))                  
  ,SUM(COALESCE(CASE                   
     WHEN C.FLAG_CF = 'C'                  
      THEN CASE                   
     WHEN C.FLAG_REVERSE = 'Y'                  
         THEN - 1 * C.AMOUNT                  
        ELSE C.AMOUNT                  
        END                  
     ELSE 0                  
     END, 0))                  
  ,0                  
  ,0                  
  ,A.STAFFLOAN                  
  ,A.PKID                  
  ,A.NPVRATE                  
  ,'N' --20180226                          
 FROM TMP_LI_T7 A                  
 LEFT JOIN IFRS_LI_ACCT_COST_FEE C ON C.DOWNLOAD_DATE = @V_CURRDATE                  
  AND C.MASTERID = A.MID                  
  AND C.STATUS = 'ACT'                  
  AND C.METHOD = 'EIR'                  
  --20180108 EXCLUDE CF REVERSAL AND ITS PAIR                            
  AND C.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                 
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
 --WHERE C.METHOD = 'EIR'                           
 GROUP BY A.MID                  
  ,A.STAFFLOAN                  
  ,A.PKID                  
  ,A.NPVRATE                  
                  
 --20180226 FILL TO COLUMN FOR NEW COST/FEE                          
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET NEW_FEE_AMT = ISNULL(FEE_AMT, 0)                  
  ,NEW_COST_AMT = ISNULL(COST_AMT, 0)                  
  ,NEW_TOTAL_AMT = ISNULL(NEW_FEE_AMT, 0) + ISNULL(NEW_COST_AMT, 0)                  
                  
 -- SISA UNAMORT                            
 TRUNCATE TABLE TMP_LI_T10                  
                  
 INSERT INTO TMP_LI_T10 (                  
  MASTERID                  
  ,FEE_AMT                  
  ,COST_AMT                  
  )                  
 SELECT B.MASTERID                  
  ,SUM(COALESCE(CASE                   
     WHEN B.FLAG_CF = 'F'                  
      THEN CASE                   
        WHEN B.FLAG_REVERSE = 'Y'                  
         THEN - 1 * CASE                   
           WHEN CFREV.MASTERID IS NULL                  
            THEN B.AMOUNT                  
           ELSE B.AMOUNT                  
           END                  
        ELSE CASE                   
          WHEN CFREV.MASTERID IS NULL                  
           THEN B.AMOUNT                  
          ELSE B.AMOUNT                  
          END                  
        END         
     ELSE 0                  
     END, 0)) AS FEE_AMT                  
  ,SUM(COALESCE(CASE                   
     WHEN B.FLAG_CF = 'C'                  
      THEN CASE                   
        WHEN B.FLAG_REVERSE = 'Y'                  
         THEN - 1 * CASE                   
           WHEN CFREV.MASTERID IS NULL                  
            THEN B.AMOUNT                  
           ELSE B.AMOUNT          
           END                  
        ELSE CASE                   
          WHEN CFREV.MASTERID IS NULL                  
           THEN B.AMOUNT                  
          ELSE B.AMOUNT                  
          END                  
        END                  
     ELSE 0                  
     END, 0)) AS COST_AMT                  
 FROM IFRS_LI_ACCT_EIR_COST_FEE_PREV B                  
 JOIN VW_LI_LAST_EIR_CF_PREV X ON X.MASTERID = B.MASTERID                  
  AND X.DOWNLOAD_DATE = B.DOWNLOAD_DATE                  
  AND B.SEQ = X.SEQ                  
 --20160407 EIR STOP REV                            
 LEFT JOIN (                  
  SELECT DISTINCT MASTERID                  
  FROM IFRS_LI_ACCT_EIR_STOP_REV                  
  WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  ) A ON A.MASTERID = B.MASTERID                  
 --20180116 RESONA REQ                            
 LEFT JOIN #TODAYREV CFREV ON CFREV.MASTERID = B.MASTERID                  
 WHERE B.DOWNLOAD_DATE IN (                  
   @V_CURRDATE                  
   ,@V_PREVDATE                  
   )                  
  AND B.STATUS = 'ACT'                  
  AND A.MASTERID IS NULL                  
  --20180116 EXCLUDE CF REVERSAL AND ITS PAIR                            
  AND B.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
  --20180426 EXCLUDE PREVDATE IF NOT FROM SP ACF ACCRU                    
  AND CASE                   
   WHEN B.DOWNLOAD_DATE = @V_PREVDATE                  
    AND B.SEQ <> '2'                  
    THEN 0                  
   ELSE 1                  
   END = 1                  
 GROUP BY B.MASTERID                  
                  
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET FEE_AMT = IFRS_LI_ACCT_EIR_CF_ECF.FEE_AMT + B.FEE_AMT                  
  ,COST_AMT = IFRS_LI_ACCT_EIR_CF_ECF.COST_AMT + B.COST_AMT                  
 FROM TMP_LI_T10 B                  
 WHERE B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID                  
                  
 IF @PARAM_DISABLE_ACCRU_PREV != 0                  
 BEGIN                  
  -- NO ACCRU IF TODAY IS DOING AMORT                            
  TRUNCATE TABLE TMP_LI_T1                  
                  
  INSERT INTO TMP_LI_T1 (                  
   MASTERID                  
   ,ACCTNO                  
   )                  
  SELECT DISTINCT MASTERID                  
   ,ACCTNO                  
  FROM IFRS_LI_ACCT_EIR_ACF                  
  WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   AND DO_AMORT = 'Y'               
             
  TRUNCATE TABLE TMP_LI_T3                  
                  
  INSERT INTO TMP_LI_T3 (MASTERID)                  
  SELECT MASTERID                  
  FROM IFRS_LI_ACCT_EIR_CF_ECF                  
  WHERE MASTERID NOT IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T1                  
    )                  
                  
  -- GET LAST ACF WITH DO_AMORT=N                            
  TRUNCATE TABLE TMP_LI_P1                  
                  
  INSERT INTO TMP_LI_P1 (ID)                  
  SELECT MAX(ID) AS ID                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  WHERE MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   AND DO_AMORT = 'N'                  
   AND DOWNLOAD_DATE < @V_CURRDATE                  
   AND DOWNLOAD_DATE >= @V_PREVDATE                  
  GROUP BY MASTERID                  
                  
  UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
  SET FEE_AMT = FEE_AMT - B.N_ACCRU_FEE                  
   ,COST_AMT = COST_AMT - B.N_ACCRU_COST                  
  FROM (                  
   SELECT *               
   FROM IFRS_LI_ACCT_EIR_ACF                  
   WHERE ID IN (                  
     SELECT ID                  
     FROM TMP_LI_P1                  
     )                  
   ) B                  
  WHERE (B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
   --20160407 EIR STOP REV                            
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID NOT IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_EIR_STOP_REV                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    )            
 ----ADD 20180924          
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID NOT IN (          
 SELECT DISTINCT MASTERID FROM IFRS_LI_ACCT_SWITCH          
 WHERE DOWNLOAD_DATE = @V_CURRDATE          
 )                     
                  
  --20180116 FEE ADJ REV AMBIL DARI UNAMORT UNTUK PAIR DARI CF REV                            
  UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
  SET FEE_AMT = FEE_AMT + B.N_AMOUNT                  
  FROM (                  
   SELECT *                  
   FROM IFRS_LI_ACCT_JOURNAL_INTM                  
   WHERE CF_ID IN (           
     SELECT CF_ID_REV                  
     FROM IFRS_LI_ACCT_COST_FEE                  
     WHERE DOWNLOAD_DATE = @V_CURRDATE                  
      AND FLAG_REVERSE = 'Y'                  
      AND CF_ID_REV IS NOT NULL                  
     )                  
    AND DOWNLOAD_DATE = @V_PREVDATE                  
    AND [REVERSE] = 'N'                  
    AND JOURNALCODE = 'ACCRU'                  
    AND FLAG_CF = 'F'                  
   ) B                  
  WHERE (B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
   --20180404 ADD FILTER                        
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   --20160407 SL STOP REV                            
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID NOT IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_EIR_STOP_REV                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    )                  
                  
  --20180116 COST ADJ REV AMBIL DARI UNAMORT UNTUK PAIR DARI CF REV                            
  UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
  SET COST_AMT = COST_AMT + B.N_AMOUNT                  
  FROM (                  
   SELECT *                  
   FROM IFRS_LI_ACCT_JOURNAL_INTM                  
   WHERE CF_ID IN (                  
     SELECT CF_ID_REV                  
     FROM IFRS_LI_ACCT_COST_FEE                  
     WHERE DOWNLOAD_DATE = @V_CURRDATE                  
      AND FLAG_REVERSE = 'Y'                  
      AND CF_ID_REV IS NOT NULL                  
     )                  
    AND DOWNLOAD_DATE = @V_PREVDATE                  
    AND [REVERSE] = 'N'                  
    AND JOURNALCODE = 'ACCRU'                  
    AND FLAG_CF = 'C'                  
   ) B                  
  WHERE (B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
   --20180404 ADD FILTER                        
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   --20160407 SL STOP REV                            
   AND IFRS_LI_ACCT_EIR_CF_ECF.MASTERID NOT IN (     
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_EIR_STOP_REV                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    )                  
 END --IF @PARAM_DISABLE_ACCRU_PREV != 0                            
                  
 -- ACCRU                            
 TRUNCATE TABLE TMP_LI_T10                  
                  
 INSERT INTO TMP_LI_T10 (                  
  MASTERID                  
  ,FEE_AMT                  
  ,COST_AMT                  
  )                  
 SELECT B.MASTERID                  
  ,SUM(COALESCE(CASE                   
     WHEN B.FLAG_CF = 'F'                  
      THEN CASE                   
        WHEN B.FLAG_REVERSE = 'Y'                  
         THEN - 1 * B.AMOUNT                  
        ELSE B.AMOUNT                  
        END           
     ELSE 0                  
     END, 0)) AS FEE_AMT                  
  ,SUM(COALESCE(CASE                   
     WHEN B.FLAG_CF = 'C'                  
      THEN CASE                   
        WHEN B.FLAG_REVERSE = 'Y'                  
         THEN - 1 * B.AMOUNT                  
        ELSE B.AMOUNT                  
        END                  
     ELSE 0                  
     END, 0)) AS COST_AMT                  
 FROM IFRS_LI_ACCT_EIR_ACCRU_PREV B                  
 WHERE B.STATUS = 'ACT'                  
  --20180116 EXCLUDE CF REV AND ITS PAIR                            
  AND B.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
 GROUP BY B.MASTERID                  
                  
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET FEE_AMT_ACRU = B.FEE_AMT                  
  ,COST_AMT_ACRU = B.COST_AMT                  
 FROM TMP_LI_T10 B                  
 WHERE (B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
                  
 -- UPDATE TOTAL                            
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET TOTAL_AMT = ROUND(FEE_AMT + COST_AMT, 0)                  
  ,TOTAL_AMT_ACRU = ROUND(FEE_AMT + COST_AMT + FEE_AMT_ACRU + COST_AMT_ACRU, 0)                  
                  
 -- UPDATE PREV EIR                            
 TRUNCATE TABLE TMP_LI_T13                  
                  
 INSERT INTO TMP_LI_T13 (                  
  MASTERID                  
  ,N_EFF_INT_RATE                  
  ,ENDAMORTDATE                  
  )                  
 SELECT B.MASTERID                  
  ,B.N_EFF_INT_RATE                  
  ,B.ENDAMORTDATE                  
 FROM IFRS_LI_ACCT_EIR_ECF B                  
 WHERE B.AMORTSTOPDATE IS NULL                  
  AND B.PMT_DATE = B.PREV_PMT_DATE                  
                  
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET PREV_EIR = N_EFF_INT_RATE                  
  ,PREV_ENDAMORTDATE = B.ENDAMORTDATE                  
 FROM TMP_LI_T13 B                  
 WHERE (B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
                  
 --20180226 SET GAIN_LOSS_CALC TO Y IF PREPAYMENT EVENT DETECTED WITHOUT OTHER EVENT (SIMPLIFY FOR NOW)                          
 --PARTIAL PAYMENT EVENTID IS 6                          
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET GAIN_LOSS_CALC = 'Y'                  
 WHERE MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_EVENT_CHANGES                  
   WHERE EVENT_ID = 6                  
    AND EFFECTIVE_DATE = @V_CURRDATE                  
   )                  
  AND MASTERID NOT IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_EVENT_CHANGES                  
   WHERE EVENT_ID IN (                  
     0                  
     ,1                  
     ,2                  
     ,3                  
  )                  
    AND EFFECTIVE_DATE = @V_CURRDATE                  
   )                  
                  
 --20180226 IF DONT HAVE PREV EIR THEN SET BACK TO N                          
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET GAIN_LOSS_CALC = 'N'                  
 WHERE PREV_EIR IS NULL                  
  AND GAIN_LOSS_CALC = 'Y'                  
                  
 -- DO FULL AMORT IF SUM COST FEE ZERO AND DONT CREATE NEW ECF                            
 UPDATE IFRS_LI_ACCT_COST_FEE                  
 SET STATUS = 'PNL'                  
  ,CREATEDBY = 'EIRECF1'                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   WHERE TOTAL_AMT = 0                  
    OR TOTAL_AMT_ACRU = 0                  
   )                  
  AND STATUS = 'ACT'                  
  --20180116 EXCLUDE CF REV AND ITS PAIR, WILL BE HANDLED BY ACF_ABN                            
  AND CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
                  
 -- IF LAST COST FEE PREV IS CURRDATE                            
 TRUNCATE TABLE TMP_LI_T11                  
                  
 INSERT INTO TMP_LI_T11 (                  
  MASTERID                  
  ,DOWNLOAD_DATE                  
,SEQ                  
  ,CURRDATE                  
  )                  
 SELECT B.MASTERID                  
  ,B.DOWNLOAD_DATE                  
  ,B.SEQ                  
  ,P.CURRDATE                  
 FROM VW_LI_LAST_EIR_CF_PREV B                  
 CROSS JOIN IFRS_LI_PRC_DATE_AMORT P                  
 WHERE B.MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   WHERE TOTAL_AMT = 0                  
    OR TOTAL_AMT_ACRU = 0                  
   )                  
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_PREV                  
 SET STATUS = CASE                   
   WHEN STATUS = 'ACT'                  
    THEN 'PNL'                  
   ELSE STATUS                  
   END                  
  ,CREATEDBY = 'EIRECF2'                  
 FROM TMP_LI_T11 B                  
 WHERE IFRS_LI_ACCT_EIR_COST_FEE_PREV.DOWNLOAD_DATE = B.CURRDATE                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.MASTERID = B.MASTERID                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.DOWNLOAD_DATE = B.DOWNLOAD_DATE                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.SEQ = B.SEQ                  
  --20180116 EXCLUDE CF REV AND ITS PAIR, WILL BE HANDLED BY SP ACF ABN                            
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
          
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
                  
 -- IF LAST COST FEE PREV IS PREVDATE                            
 TRUNCATE TABLE TMP_LI_T12                  
                  
 INSERT INTO TMP_LI_T12 (                  
  MASTERID                  
  ,DOWNLOAD_DATE                  
  ,SEQ                  
  ,PREVDATE                  
  )                  
 SELECT B.MASTERID                  
  ,B.DOWNLOAD_DATE                  
  ,B.SEQ                  
  ,P.PREVDATE                  
 FROM VW_LI_LAST_EIR_CF_PREV B                  
 CROSS JOIN IFRS_LI_PRC_DATE_AMORT P                  
 WHERE B.MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   WHERE TOTAL_AMT = 0                  
    OR TOTAL_AMT_ACRU = 0                  
   )                  
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_PREV                  
 SET STATUS = CASE                   
   WHEN STATUS = 'ACT'                  
    THEN 'PNL2'                  
   ELSE STATUS                  
   END                  
  ,CREATEDBY = 'EIRECF2'                  
 FROM TMP_LI_T12 B                  
 WHERE IFRS_LI_ACCT_EIR_COST_FEE_PREV.DOWNLOAD_DATE = B.PREVDATE                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.MASTERID = B.MASTERID                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.DOWNLOAD_DATE = B.DOWNLOAD_DATE                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.SEQ = B.SEQ                  
  --20180116 EXCLUDE CF REV AND ITS PAIR, WILL BE HANDLED BY SP ACF ABN                            
  AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
  --20180426 EXCLUDE PREVDATE IF NOT FROM SP ACF ACCRU                    
  AND CASE                   
   WHEN IFRS_LI_ACCT_EIR_COST_FEE_PREV.DOWNLOAD_DATE = @V_PREVDATE                  
    AND IFRS_LI_ACCT_EIR_COST_FEE_PREV.SEQ <> '2'                  
    THEN 0                  
   ELSE 1                  
   END = 1                  
                  
 IF @PARAM_DISABLE_ACCRU_PREV != 0                  
 BEGIN          
  -- INSERT ACCRU PREV ONLY FOR PNL ED                            
  -- GET LAST ACF WITH DO_AMORT=N                            
  TRUNCATE TABLE TMP_LI_P1                  
                  
  INSERT INTO TMP_LI_P1 (ID)                  
  SELECT MAX(ID) AS ID                  
  FROM IFRS_LI_ACCT_EIR_ACF                  
  WHERE MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   AND DO_AMORT = 'N'                  
   AND DOWNLOAD_DATE < @V_CURRDATE                 
   AND DOWNLOAD_DATE >= @V_PREVDATE                  
   -- ADD FILTER PNL ED ACCTNO                            
   AND MASTERID IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_EIR_CF_ECF                  
    WHERE TOTAL_AMT = 0                  
     OR TOTAL_AMT_ACRU = 0                  
    )                  
  GROUP BY MASTERID                  
                  
  -- GET FEE SUMMARY                            
  TRUNCATE TABLE TMP_LI_TF                  
                  
  INSERT INTO TMP_LI_TF (                  
   SUM_AMT                  
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT        
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
    AND A.FLAG_CF = 'F'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
                  
  -- GET COST SUMMARY                            
  TRUNCATE TABLE TMP_LI_TC                  
                  
  INSERT INTO TMP_LI_TC (                  
   SUM_AMT                  
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT                  
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
    AND A.FLAG_CF = 'C'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
                  
  --INSERT FEE 1                             
  INSERT INTO IFRS_LI_ACCT_EIR_ACCRU_PREV (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,AMORTDATE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,METHOD                  
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO                  
   ,@V_CURRDATE                  
   ,A.ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                  
        THEN - 1 * B.AMOUNT                  
       ELSE B.AMOUNT                  
END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_FEE, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,NULL AS AMORTDATE                  
   ,'ECF'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'F'                  
  JOIN TMP_LI_TF C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20180108 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
    )                  
                  
  --COST 1                            
  INSERT INTO IFRS_LI_ACCT_EIR_ACCRU_PREV (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,AMORTDATE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,METHOD                  
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO         ,@V_CURRDATE                  
   ,A.ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                
        THEN - 1 * B.AMOUNT                 ELSE B.AMOUNT                  
       END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_COST, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,NULL AS AMORTDATE                  
   ,'ECF'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'C'                  
  JOIN TMP_LI_TC C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20180108 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
    )                  
 END                              
                  
 -- AMORT ACRU                            
 UPDATE IFRS_LI_ACCT_EIR_ACCRU_PREV                  
 SET STATUS = CONVERT(VARCHAR(8), @V_CURRDATE, 112)                  
 WHERE STATUS = 'ACT'                  
  AND MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   WHERE TOTAL_AMT = 0                  
    OR TOTAL_AMT_ACRU = 0                  
   )                  
                  
 -- STOP OLD ECF                            
 UPDATE IFRS_LI_ACCT_EIR_ECF                  
 SET AMORTSTOPDATE = @V_CURRDATE                  
  ,AMORTSTOPMSG = 'SP_ACCT_EIR_ECF'                  
 WHERE MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   )                  
  AND AMORTSTOPDATE IS NULL                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'2'                  
  );                  
                  
 TRUNCATE TABLE TMP_LI_T1                  
                  
 INSERT INTO TMP_LI_T1 (MASTERID)                  
 SELECT MASTERID                  
 FROM IFRS_LI_PAYM_CORE_SRC                  
 WHERE PREV_PMT_DATE = PMT_DATE                  
  AND MASTERID IN (                  
   SELECT B.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF B                  
   WHERE (                  
     (                  
      B.TOTAL_AMT <> 0                  
      AND B.TOTAL_AMT_ACRU <> 0                  
      )                  
     OR B.STAFFLOAN = 1                  
     --20170927, ANYINK                            
     OR (                  
      B.MASTERID IN (                  
       SELECT DISTINCT MASTERID                  
       FROM IFRS_LI_EVENT_CHANGES                  
       WHERE DOWNLOAD_DATE = @V_CURRDATE                  
        AND EVENT_ID = 4                  
       )                  
      )                  
     )                  
   )                  
                  
 TRUNCATE TABLE IFRS_LI_GS_MASTERID                  
                  
 INSERT INTO IFRS_LI_GS_MASTERID (MASTERID)                  
 SELECT A.MASTERID                  
 FROM TMP_LI_T1 A                  
                  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_PAYM                  
                  
 SELECT @VMIN_ID = MIN(ID)                  
  ,@VMAX_ID = MAX(ID)                  
 FROM IFRS_LI_GS_MASTERID                  
                  
 SET @VX = @VMIN_ID                  
 SET @VX_INC = 500000                  
                  
 WHILE @VX <= @VMAX_ID                  
 BEGIN --LOOP                            
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_PAYM_CORE_PROCESS'                  
   ,CAST(@VX AS VARCHAR(30))                  
   )                  
                  
  TRUNCATE TABLE IFRS_LI_PAYM_CORE                  
                  
  INSERT INTO IFRS_LI_PAYM_CORE (                  
   MASTERID                  
   ,ACCTNO                  
   ,PREV_PMT_DATE                  
   ,PMT_DATE                  
   ,INT_RATE                  
   ,I_DAYS                  
   ,COUNTER                  
   ,OS_PRN_PREV                  
   ,PRN_AMT                  
  ,INT_AMT                  
   ,OS_PRN                  
   ,DISB_PERCENTAGE                  
   ,DISB_AMOUNT                  
   ,PLAFOND                  
   ,ICC                  
   ,GRACE_DATE                  
   )                  
  /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */                  
  SELECT MASTERID                  
   ,ACCTNO                  
   ,PREV_PMT_DATE                  
   ,PMT_DATE                  
   ,INTEREST_RATE                  
   ,I_DAYS                  
   ,COUNTER                  
   ,OS_PRN_PREV                  
   ,PRN_AMT                  
   ,INT_AMT                  
   ,OS_PRN                  
   ,DISB_PERCENTAGE                  
   ,DISB_AMOUNT                  
   ,PLAFOND                  
   ,ICC                  
   ,GRACE_DATE                  
  /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */                  
  FROM IFRS_LI_PAYM_CORE_SRC                  
  WHERE MASTERID IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_GS_MASTERID                  
    WHERE ID >= @VX                  
     AND ID < (@VX + @VX_INC)                  
    )                  
                  
  EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_PAYM_CORE_PROC_NOP' -- TANPA EFEKTIFISASI                            
   --EXEC SP_IFRS_LI_PAYM_CORE_PROCESS;    -- DENGAN EFEKTIFISASI                            
                  
 SET @VX = @VX + @VX_INC                  
 END --LOOP;                            
                  
 -- INSERT PAYMENT SCHEDULE                            
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'3'                  
  )                  
                  
 -- UPDATE NPV RATE FOR STAFF LOAN                            
 UPDATE IFRS_LI_ACCT_EIR_PAYM                  
 SET NPV_RATE = B.NPV_RATE                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF B                  
 WHERE B.TOTAL_AMT = 0                  
  AND B.TOTAL_AMT_ACRU = 0                  
  AND B.STAFFLOAN = 1                  
  AND IFRS_LI_ACCT_EIR_PAYM.MASTERID = B.MASTERID                  
  AND COALESCE(B.NPV_RATE, 0) > 0                  
                  
 -- UPDATE NPV_INSTALLMENT FOR STAFF LOAN                            
 UPDATE IFRS_LI_ACCT_EIR_PAYM                  
 SET NPV_INSTALLMENT = CASE                   
   WHEN ROUND(dbo.FN_LI_CNT_DAYS_30_360(STARTAMORTDATE, PMT_DATE) / 30, 0, 1) = 0                  
    THEN N_INSTALLMENT / (POWER(1 + NULLIF(NPV_RATE, 0) / 360 / 100, dbo.FN_LI_CNT_DAYS_30_360(STARTAMORTDATE, PMT_DATE)))                  
   ELSE N_INSTALLMENT / NULLIF((POWER(1 + NULLIF(NPV_RATE, 0) / 12 / 100, ROUND(dbo.FN_LI_CNT_DAYS_30_360(STARTAMORTDATE, PMT_DATE) / 30, 0, 1))), 0)                  
   END                  
 WHERE NPV_RATE > 0                  
                  
 -- CALC STAFF LOAN BENEFIT                            
 TRUNCATE TABLE TMP_LI_B1                  
                  
 TRUNCATE TABLE TMP_LI_B2                  
                  
 TRUNCATE TABLE TMP_LI_B3                  
                  
 -- GET OS                            
 INSERT INTO TMP_LI_B1 (                  
  MASTERID                  
  ,N_OSPRN                  
  )                  
 SELECT MASTERID                  
  ,N_OSPRN                  
 FROM IFRS_LI_ACCT_EIR_PAYM                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND PREV_PMT_DATE = PMT_DATE                  
  AND NPV_RATE > 0                  
                  
 --GET NPV SUM                            
 INSERT INTO TMP_LI_B2 (                  
  MASTERID                  
  ,NPV_SUM                  
  )                  
 SELECT MASTERID                  
  ,SUM(COALESCE(NPV_INSTALLMENT, 0)) AS NPV_SUM                  
 FROM IFRS_LI_ACCT_EIR_PAYM                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND NPV_RATE > 0                  
 GROUP BY MASTERID                  
                  
 -- GET BENEFIT                            
 INSERT INTO TMP_LI_B3 (                  
  MASTERID                  
  ,N_OSPRN                  
  ,NPV_SUM                  
  ,BENEFIT                  
  )                  
 SELECT A.MASTERID                  
  ,A.N_OSPRN                  
  ,B.NPV_SUM                  
  ,B.NPV_SUM - A.N_OSPRN AS BENEFIT                  
 FROM TMP_LI_B1 A                  
 JOIN TMP_LI_B2 B ON B.MASTERID = A.MASTERID                  
                  
 -- UPDATE BACK                   
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET BENEFIT = A.BENEFIT                  
 FROM TMP_LI_B3 A                  
 WHERE A.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'3A'                  
  )                  
                  
 -- INSERT TODAY COST FEE                            
 INSERT INTO IFRS_LI_ACCT_EIR_COST_FEE_ECF (                  
  DOWNLOAD_DATE                  
  ,ECFDATE                  
  ,MASTERID                  
  ,BRCODE                  
  ,CIFNO                  
  ,FACNO                  
  ,ACCTNO                  
  ,DATASOURCE                  
  ,CCY                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,FLAG_CF                  
  ,FLAG_REVERSE                  
  ,METHOD                  
  ,STATUS                  
  ,SRCPROCESS                  
  ,AMOUNT                  
  ,CREATEDDATE                  
  ,CREATEDBY                  
  ,SEQ                  
  ,AMOUNT_ORG                  
  ,ORG_CCY                  
  ,ORG_CCY_EXRATE                  
  ,PRDTYPE                  
  ,CF_ID                  
  )                  
 SELECT C.DOWNLOAD_DATE                  
  ,@V_CURRDATE ECFDATE                  
  ,C.MASTERID                  
  ,C.BRCODE                  
  ,C.CIFNO                  
  ,C.FACNO                  
  ,C.ACCTNO                  
  ,C.DATASOURCE                  
  ,C.CCY                  
  ,C.PRD_CODE                  
  ,C.TRX_CODE                  
  ,C.FLAG_CF                  
  ,C.FLAG_REVERSE                  
  ,C.METHOD                  
  ,C.STATUS                  
  ,C.SRCPROCESS                  
  ,C.AMOUNT                  
  ,CURRENT_TIMESTAMP CREATEDDATE                  
  ,'EIR_ECF_MAIN' CREATEDBY                  
  ,'' SEQ                  
  ,C.AMOUNT           
  ,C.ORG_CCY                  
  ,C.ORG_CCY_EXRATE                  
  ,C.PRD_TYPE                  
  ,C.CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE C                  
 JOIN IFRS_LI_ACCT_EIR_CF_ECF B ON B.MASTERID = C.MASTERID                  
  AND B.TOTAL_AMT <> 0                  
  AND B.TOTAL_AMT_ACRU <> 0                  
 WHERE C.DOWNLOAD_DATE = @V_CURRDATE                  
  AND C.MASTERID = B.MASTERID                  
  AND C.STATUS = 'ACT'                  
  AND C.METHOD = 'EIR'                  
  --20180116 EXCLUDE CF REV AND ITS PAIR                            
  AND C.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
                  
 --INSERT UNAMORT                            
 INSERT INTO IFRS_LI_ACCT_EIR_COST_FEE_ECF (                  
  DOWNLOAD_DATE                  
  ,ECFDATE                  
  ,MASTERID                  
  ,BRCODE                  
  ,CIFNO                  
  ,FACNO                  
  ,ACCTNO                  
  ,DATASOURCE                  
  ,CCY                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,FLAG_CF                  
  ,FLAG_REVERSE                  
  ,METHOD                  
  ,STATUS                  
  ,SRCPROCESS                  
  ,AMOUNT                  
  ,CREATEDDATE              
  ,CREATEDBY                  
  ,SEQ                  
  ,AMOUNT_ORG                  
  ,ORG_CCY                  
  ,ORG_CCY_EXRATE                  
  ,PRDTYPE                  
  ,CF_ID                  
  )                  
 SELECT C.DOWNLOAD_DATE                  
  ,@V_CURRDATE ECFDATE                  
  ,C.MASTERID                  
  ,C.BRCODE                  
  ,C.CIFNO                  
  ,C.FACNO                  
  ,C.ACCTNO                  
  ,C.DATASOURCE                  
  ,C.CCY                  
  ,C.PRDCODE                  
  ,C.TRXCODE                  
  ,C.FLAG_CF                  
  ,C.FLAG_REVERSE                  
  ,C.METHOD                  
  ,C.STATUS                  
  ,C.SRCPROCESS                  
  ,C.AMOUNT                  
  ,CURRENT_TIMESTAMP CREATEDDATE                  
  ,'EIR_ECF_MAIN' CREATEDBY                  
  ,'' SEQ                  
  ,C.AMOUNT_ORG                  
  ,C.ORG_CCY                  
  ,C.ORG_CCY_EXRATE                  
  ,C.PRDTYPE                  
  ,C.CF_ID                  
 FROM IFRS_LI_ACCT_EIR_COST_FEE_PREV C                  
 JOIN VW_LI_LAST_EIR_CF_PREV X ON X.MASTERID = C.MASTERID                  
  AND X.DOWNLOAD_DATE = C.DOWNLOAD_DATE                  
  AND C.SEQ = X.SEQ                  
 JOIN IFRS_LI_ACCT_EIR_CF_ECF B ON B.MASTERID = C.MASTERID                  
  AND B.TOTAL_AMT <> 0                  
  AND B.TOTAL_AMT_ACRU <> 0                  
 --20160407 EIR STOP REV                            
 LEFT JOIN (                  
  SELECT DISTINCT MASTERID                  
  FROM IFRS_LI_ACCT_EIR_STOP_REV                  
  WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  ) A ON A.MASTERID = C.MASTERID                  
 WHERE C.DOWNLOAD_DATE IN (                  
   @V_CURRDATE                  
   ,@V_PREVDATE                  
   )                  
  AND C.STATUS = 'ACT'                  
  --20160407 EIR STOP REV                            
  AND A.MASTERID IS NULL                  
  --20180116 EXCLUDE CF REV AND ITS PAIR                            
  AND C.CF_ID NOT IN (                  
   SELECT CF_ID                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
                     
   UNION ALL                  
                     
   SELECT CF_ID_REV                  
   FROM IFRS_LI_ACCT_COST_FEE                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    AND FLAG_REVERSE = 'Y'                  
    AND CF_ID_REV IS NOT NULL                  
   )                  
  --20180426 EXCLUDE PREVDATE IF NOT FROM SP ACF ACCRU                    
  AND CASE                   
   WHEN C.DOWNLOAD_DATE = @V_PREVDATE                  
    AND C.SEQ <> '2'                  
    THEN 0                  
   ELSE 1                  
   END = 1                  
                  
 IF @PARAM_DISABLE_ACCRU_PREV != 0                  
 BEGIN                  
  --MASUKKAN KEMBALI ACCRU PREVDATE KE COST_FEE_ECF                            
  -- NO ACCRU IF TODAY IS DOING AMORT                            
  TRUNCATE TABLE TMP_LI_T1                  
                  
  INSERT INTO TMP_LI_T1 (MASTERID)                  
  SELECT DISTINCT MASTERID                  
  FROM IFRS_LI_ACCT_EIR_ACF                  
  WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   AND DO_AMORT = 'Y'                  
                  
  TRUNCATE TABLE TMP_LI_T3                  
                  
  INSERT INTO TMP_LI_T3 (MASTERID)                  
  SELECT MASTERID                  
  FROM IFRS_LI_ACCT_EIR_CF_ECF                  
  WHERE MASTERID NOT IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T1                  
    )                  
                  
  -- GET LAST ACF WITH DO_AMORT=N                            
  TRUNCATE TABLE TMP_LI_P1                  
                  
  INSERT INTO TMP_LI_P1 (ID)                  
  SELECT MAX(ID) AS ID                  
  FROM IFRS_LI_ACCT_EIR_ACF                  
  WHERE MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   AND DO_AMORT = 'N'                  
   AND DOWNLOAD_DATE < @V_CURRDATE                  
   AND DOWNLOAD_DATE >= @V_PREVDATE                  
  GROUP BY MASTERID                  
                  
  -- GET FEE SUMMARY                            
  TRUNCATE TABLE TMP_LI_TF                  
                  
  INSERT INTO TMP_LI_TF (                  
   SUM_AMT                  
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT                  
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
 AND A.FLAG_CF = 'F'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
                  
  -- GET COST SUMMARY                            
  TRUNCATE TABLE TMP_LI_TC                          
  INSERT INTO TMP_LI_TC (                  
   SUM_AMT                  
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT                  
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
    AND A.FLAG_CF = 'C'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
                  
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
   ,'3B'                  
   )                  
                  
  --INSERT FEE 1                            
  INSERT INTO IFRS_LI_ACCT_EIR_COST_FEE_ECF (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,BRCODE                  
   ,METHOD                  
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO                  
   ,@V_CURRDATE                  
  ,@V_CURRDATE ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                  
        THEN - 1 * B.AMOUNT                  
       ELSE B.AMOUNT                  
       END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_FEE * - 1, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,'ECFACCRU'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.BRCODE                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'F'                  
   AND B.STATUS = 'ACT'            
   AND A.MASTERID NOT IN (SELECT DISTINCT MASTERID FROM IFRS_LI_ACCT_SWITCH        
   WHERE DOWNLOAD_DATE = @V_CURRDATE )           
  JOIN TMP_LI_TF C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  --20160407 EIR STOP REV                            
  LEFT JOIN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   ) D ON A.MASTERID = D.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20160407 EIR STOP REV                            
   AND D.MASTERID IS NULL                  
   --20180116 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                 
    )                  
                  
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
   ,'3C'                  
   )                 
                  
  --COST 1                            
  INSERT INTO IFRS_LI_ACCT_EIR_COST_FEE_ECF (                  
   FACNO                  
   ,CIFNO                  
,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,BRCODE                  
   ,METHOD              
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO                  
   ,@V_CURRDATE                  
   ,@V_CURRDATE ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                  
        THEN - 1 * B.AMOUNT                  
       ELSE B.AMOUNT                  
       END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_COST * - 1, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,'ECFACCRU'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.BRCODE                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'C'                  
   AND B.STATUS = 'ACT'             
  AND A.MASTERID NOT IN (SELECT DISTINCT MASTERID         
 FROM IFRS_ACCT_SWITCH        
 WHERE DOWNLOAD_DATE = @V_CURRDATE)           
 AND B.STATUS = 'ACT'           
  JOIN TMP_LI_TC C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  --20160407 EIR STOP REV                            
  LEFT JOIN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   ) D ON A.MASTERID = D.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20160407 EIR STOP REV                            
   AND D.MASTERID IS NULL                  
   --20180108 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
    )                  
 END --MASUKKAN KEMBALI ACCRU PREVDATE KE COST_FEE_ECF                            
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'3D'                  
  )                  
                  
 -- 20160412 GROUP MULTIPLE ROWS BY CF_ID                            
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_CF_ECF_GRP'                  
     
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'4 GS START'                  
  )                  
                  
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_FAILED_GS                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_CF_ECF1                  
                  
 INSERT INTO IFRS_LI_ACCT_EIR_CF_ECF1 (                  
  MASTERID                  
  ,FEE_AMT                  
,COST_AMT                  
  ,BENEFIT                  
  ,STAFFLOAN                  
  ,PREV_EIR                  
  --20180226 COPY DATA                   
  ,TOTAL_AMT --20180517  ADD YACOP                   
  ,NEW_FEE_AMT                  
  ,NEW_COST_AMT                  
  ,NEW_TOTAL_AMT                  
  ,GAIN_LOSS_CALC                  
  )                  
 SELECT B.MASTERID                  
  ,B.FEE_AMT                  
  ,B.COST_AMT                  
  ,B.BENEFIT                  
  ,B.STAFFLOAN                  
  ,B.PREV_EIR                  
  ,B.TOTAL_AMT --20180517  ADD YACOP                      
  ,NEW_FEE_AMT                  
 ,NEW_COST_AMT                  
  ,NEW_TOTAL_AMT                  
  ,GAIN_LOSS_CALC                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF B                  
 WHERE (              
   B.TOTAL_AMT <> 0                  
   AND B.TOTAL_AMT_ACRU <> 0                  
   )                  
  OR (                  
   B.STAFFLOAN = 1                  
   AND B.PREV_EIR IS NULL                  
   )                  
  --20170927, IVAN NOCF           
  OR (                  
   B.MASTERID IN (                  
    SELECT DISTINCT MASTERID                  
    FROM IFRS_LI_EVENT_CHANGES                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND EVENT_ID = 4                  
    )                  
   )                  
                  
 --START: GOAL SEEK PREPARE STAFFLOAN BENEFIT                            
 -- PUT BEFORE REMARK -- GOAL SEEK PREPARE SP_IFRS_LI_ACCT_EIR_ECF_MAIN                            
 -- RESULT BENEFIT=UNAMORT-GLOSS GET FROM TABLE IFRS_LI_ACCT_EIR_GS_RESULT3                            
 TRUNCATE TABLE IFRS_LI_GS_MASTERID                  
                  
 --CLEAN UP                            
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT3                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_FAILED_GS3                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 --ONLY PROCESS STAFFLOAN WITH NO RUNNING AMORTIZATION                            
 INSERT INTO IFRS_LI_GS_MASTERID (MASTERID)                  
 SELECT A.MASTERID                  
 FROM (                  
  SELECT MASTERID                  
   ,PERIOD                  
  FROM IFRS_LI_ACCT_EIR_PAYM                  
  WHERE PREV_PMT_DATE = PMT_DATE                  
   AND MASTERID IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_EIR_CF_ECF1                  
    WHERE (                  
      STAFFLOAN = 1                  
      AND PREV_EIR IS NULL                  
      )                  
     OR GAIN_LOSS_CALC = 'Y' --20180226 PREPAYMENT                            
    )                  
  ) A                  
 ORDER BY PERIOD                  
                  
 SELECT @VMIN_ID = MIN(ID)                  
 FROM IFRS_LI_GS_MASTERID                  
                  
 SELECT @VMAX_ID = MAX(ID)                  
 FROM IFRS_LI_GS_MASTERID                  
                  
 SET @VX = @VMIN_ID                  
 SET @VX_INC = 500000                  
                  
 WHILE @VX <= @VMAX_ID                  
 BEGIN --LOOP                            
  INSERT INTO IFRS_LI_AMORT_LOG (             
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_GS_RANGE'                  
   ,CAST(@VX AS VARCHAR(30))                  
   )                  
                  
  SET @ID2 = @VX + @VX_INC - 1                  
                  
  EXEC SP_IFRS_LI_ACCT_EIR_GS_RANGE @VX                  
   ,@ID2                  
                  
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_GS_RANGE'                  
   ,'DONE'                  
   )                  
                  
  EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_GS_PROC3'                  
                  
  SET @VX = @VX + @VX_INC                  
 END --LOOP;                            
                  
 -- UPDATE BACK RESULT TO IFRS_LI_ACCT_EIR_CF_ECF1                            
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF1                  
 SET BENEFIT = B.UNAMORT - B.GLOSS                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT3 B                  
 WHERE (                  
   B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF1.MASTERID                  
   AND B.DOWNLOAD_DATE = @V_CURRDATE                  
   --20180226 ONLY FOR STAFF LOAN                            
   AND IFRS_LI_ACCT_EIR_CF_ECF1.STAFFLOAN = 1                  
   )                  
                  
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET BENEFIT = B.UNAMORT - B.GLOSS                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT3 B                  
 WHERE (                  
   B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID                  
   AND B.DOWNLOAD_DATE = @V_CURRDATE                  
   --20180226 ONLY FOR STAFF LOAN                            
   AND IFRS_LI_ACCT_EIR_CF_ECF.STAFFLOAN = 1                  
   )                  
                  
 --20180226 UPDATE FOR PARTIAL PAYMENT                          
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF1                  
 SET GAIN_LOSS_AMT = ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
  ,GAIN_LOSS_FEE_AMT = CASE                   
   WHEN FEE_AMT <> 0                  
    AND COST_AMT = 0                  
    THEN ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
   WHEN FEE_AMT = 0            AND COST_AMT <> 0                  
    THEN 0                  
   ELSE ROUND(B.GLOSS * FEE_AMT / TOTAL_AMT, @V_ROUND, @V_FUNCROUND)                  
   END                  
  ,GAIN_LOSS_COST_AMT = CASE                   
   WHEN FEE_AMT = 0                  
    AND COST_AMT <> 0                  
   THEN ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
   WHEN FEE_AMT <> 0                  
    AND COST_AMT = 0                  
    THEN 0                  
   ELSE ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND) - ROUND(B.GLOSS * FEE_AMT / TOTAL_AMT, @V_ROUND, @V_FUNCROUND)                  
   END                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT3 B                  
 WHERE (                  
   B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF1.MASTERID                  
   AND B.DOWNLOAD_DATE = @V_CURRDATE                  
   AND IFRS_LI_ACCT_EIR_CF_ECF1.STAFFLOAN = 0                  
   AND IFRS_LI_ACCT_EIR_CF_ECF1.GAIN_LOSS_CALC = 'Y'                  
   )                  
                  
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET GAIN_LOSS_AMT = ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
  ,GAIN_LOSS_FEE_AMT = CASE                   
   WHEN FEE_AMT <> 0                  
    AND COST_AMT = 0                  
    THEN ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
   WHEN FEE_AMT = 0                  
    AND COST_AMT <> 0                  
    THEN 0                  
   ELSE ROUND(B.GLOSS * FEE_AMT / TOTAL_AMT, @V_ROUND, @V_FUNCROUND)                  
   END                  ,GAIN_LOSS_COST_AMT = CASE                   
   WHEN FEE_AMT = 0                  
    AND COST_AMT <> 0                  
    THEN ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND)                  
   WHEN FEE_AMT <> 0                  
    AND COST_AMT = 0                  
    THEN 0                  
   ELSE ROUND(B.GLOSS, @V_ROUND, @V_FUNCROUND) - ROUND(B.GLOSS * FEE_AMT / TOTAL_AMT, @V_ROUND, @V_FUNCROUND)                  
   END                  
 FROM IFRS_LI_ACCT_EIR_GS_RESULT3 B                  
 WHERE (                  
   B.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID                  
   AND B.DOWNLOAD_DATE = @V_CURRDATE                  
   AND IFRS_LI_ACCT_EIR_CF_ECF.STAFFLOAN = 0                  
   AND IFRS_LI_ACCT_EIR_CF_ECF.GAIN_LOSS_CALC = 'Y'                  
   )                  
                  
 --RIDWAN  20 AUG 2015  INSERT BENEFIT AFTER GET BENEFIT                            
 --INSERT BENEFIT                            
 -- GET OS                            
 -- CALC STAFF LOAN BENEFIT                            
 TRUNCATE TABLE TMP_LI_B1                  
                  
 TRUNCATE TABLE TMP_LI_B2                  
                  
 TRUNCATE TABLE TMP_LI_B3                  
                  
 INSERT INTO TMP_LI_B1 (                  
  MASTERID                  
  ,N_OSPRN                  
  )                  
 SELECT MASTERID                  
  ,N_OSPRN                  
 FROM IFRS_LI_ACCT_EIR_PAYM                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND PREV_PMT_DATE = PMT_DATE                  
  AND NPV_RATE > 0                  
                  
 --GET NPV SUM                            
 INSERT INTO TMP_LI_B2 (                  
  MASTERID                  
  ,NPV_SUM                  
  )                  
 SELECT A.MASTERID                  
  ,(COALESCE(A.N_OSPRN, 0) + COALESCE(BENEFIT, 0)) AS NPV                  
 FROM TMP_LI_B1 A                  
 JOIN IFRS_LI_ACCT_EIR_CF_ECF B ON A.MASTERID = B.MASTERID                  
 JOIN IFRS_LI_ACCT_EIR_GS_RESULT3 C ON A.MASTERID = C.MASTERID                  
 WHERE C.DOWNLOAD_DATE = @V_CURRDATE                  
                  
 -- GET BENEFIT                            
 INSERT INTO TMP_LI_B3 (                  
  MASTERID                  
  ,N_OSPRN                  
  ,NPV_SUM                  
  ,BENEFIT                  
  )                  
 SELECT A.MASTERID                  
  ,A.N_OSPRN                  
  ,B.NPV_SUM                  
  ,B.NPV_SUM - A.N_OSPRN AS BENEFIT                  
 FROM TMP_LI_B1 A                  
 JOIN TMP_LI_B2 B ON B.MASTERID = A.MASTERID                  
                  
 -- UPDATE BACK                            
 UPDATE IFRS_LI_ACCT_EIR_CF_ECF                  
 SET BENEFIT = A.BENEFIT                  
 FROM TMP_LI_B3 A                  
 WHERE (A.MASTERID = IFRS_LI_ACCT_EIR_CF_ECF.MASTERID)                  
                  
 INSERT INTO IFRS_LI_ACCT_EIR_COST_FEE_ECF (          
  DOWNLOAD_DATE                  
  ,ECFDATE                  
  ,MASTERID                  
  ,BRCODE                  
  ,CIFNO                  
  ,FACNO                  
  ,ACCTNO                  
  ,DATASOURCE                  
  ,CCY                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,FLAG_CF                  
  ,FLAG_REVERSE                  
  ,METHOD                  
  ,STATUS                  
  ,SRCPROCESS                  
  ,AMOUNT                  
  ,CREATEDDATE                  
  ,CREATEDBY                  
  ,SEQ                  
  ,AMOUNT_ORG                  
  ,ORG_CCY                  
  ,ORG_CCY_EXRATE                  
  ,PRDTYPE                  
  ,CF_ID                  
  )                  
 SELECT @V_CURRDATE                  
  ,@V_CURRDATE                  
  ,A.MASTERID                  
  ,M.BRANCH_CODE                  
  ,M.CUSTOMER_NUMBER                  
  ,M.FACILITY_NUMBER                  
  ,M.ACCOUNT_NUMBER                  
  ,M.DATA_SOURCE                  
  ,M.CURRENCY                  
  ,M.PRODUCT_CODE        
  ,'BENEFIT'                  
  ,CASE                   
   WHEN A.BENEFIT < 0                  
    THEN 'F'                  
   ELSE 'C'                  
   END                  
  ,'N'                  
  ,'EIR'                  
 ,'ACT'                  
  ,'STAFFLOAN'                  
  ,A.BENEFIT                  
  ,CURRENT_TIMESTAMP CREATEDDATE                  
  ,'EIR_ECF_MAIN' CREATEDBY                  
  ,'' SEQ                  
  ,A.BENEFIT                  
  ,M.CURRENCY                  
  ,1                  
  ,M.PRODUCT_TYPE                  
  ,0 AS CF_ID                  
 FROM TMP_LI_B3 A                  
 JOIN IFRS_LI_IMA_AMORT_CURR M ON M.MASTERID = A.MASTERID                  
 JOIN IFRS_LI_ACCT_EIR_CF_ECF C ON C.MASTERID = A.MASTERID                  
  AND C.PREV_EIR IS NULL -- NO PREV ECF THEN INSERT                            
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_ECF                 
 SET CF_ID = ID                  
 WHERE CF_ID = 0                  
  AND SRCPROCESS = 'STAFFLOAN'                  
  AND DOWNLOAD_DATE = @V_CURRDATE                  
                  
 --END: GOAL SEEK PREPARE STAFFLOAN BENEFIT                            
 --START GOALSEEK CF & NO CF                            
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'4 GS START'                  
  )                  
                  
 DELETE IFRS_LI_ACCT_EIR_ECF_NOCF                  
 WHERE DOWNLOAD_DATE >= @V_CURRDATE -- CLEAN UP                            
                  
 DELETE IFRS_LI_ACCT_EIR_GS_RESULT4                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE IFRS_LI_ACCT_EIR_FAILED_GS4                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE IFRS_LI_ACCT_EIR_GS_RESULT                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE IFRS_LI_ACCT_EIR_FAILED_GS                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 TRUNCATE TABLE IFRS_LI_GS_MASTERID                  
                  
 INSERT INTO IFRS_LI_GS_MASTERID (MASTERID)                  
 SELECT A.MASTERID                  
 FROM (                  
  SELECT MASTERID                  
   ,PERIOD                  
  FROM IFRS_LI_ACCT_EIR_PAYM                  
  WHERE PREV_PMT_DATE = PMT_DATE                  
  ) A                  
 ORDER BY PERIOD                  
                  
 SELECT @VMIN_ID = MIN(ID)                  
 FROM IFRS_LI_GS_MASTERID                  
                  
 SELECT @VMAX_ID = MAX(ID)                  
 FROM IFRS_LI_GS_MASTERID                  
                  
 SET @VX = @VMIN_ID                  
 SET @VX_INC = 500000                  
                  
 WHILE @VX <= @VMAX_ID                  
 BEGIN --LOOP                            
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_GS_RANGE'                  
   ,CAST(@VX AS VARCHAR(30))                  
   )                  
                  
  SET @ID2 = @VX + @VX_INC - 1                  
                  
  EXEC SP_IFRS_LI_ACCT_EIR_GS_RANGE @VX                  
   ,@ID2                  
                  
  INSERT INTO IFRS_LI_AMORT_LOG (                  
   DOWNLOAD_DATE                  
   ,DTM                  
   ,OPS                  
   ,PROCNAME                  
   ,REMARK                  
   )                  
  VALUES (                  
   @V_CURRDATE                  
   ,CURRENT_TIMESTAMP                  
   ,'DEBUG'                  
   ,'SP_IFRS_LI_ACCT_EIR_GS_RANGE'                  
   ,'DONE'                  
   )                  
                  
  EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_GS_ALL';                  
                  
  SET @VX = @VX + @VX_INC                  
 END --LOOP;                            
                 
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'5 GS END'                  
  )                  
                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_GS_INSERT4'                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'6 ECFNOCF INSERT'                  
  )                  
                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_ECF_ALIGN4'                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'7 ECFNOCF ALIGNED'                  
  )                  
                  
 /* REMARKS                            
--UPDATE PNL IF FAILED GOAL SEEK 20160524                             
    UPDATE  IFRS_LI_ACCT_COST_FEE                            
    SET     STATUS = 'PNL' ,                            
            CREATEDBY = 'EIRECF3'                            
    WHERE   DOWNLOAD_DATE = @V_CURRDATE                            
            AND MASTERID IN ( SELECT    MASTERID                            
                              FROM      IFRS_LI_ACCT_EIR_FAILED_GS                      
                              WHERE     DOWNLOAD_DATE = @V_CURRDATE )                            
            AND STATUS = 'ACT'                            
*/                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_GS_INSERT'                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'8 ECF INSERTED'                  
  )                  
                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_ECF_ALIGN'                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'9 ECF ALIGNED'                  
  )                  
                  
 -- MERGE ECF FOR MASTERID WITH DIFFERENT INTEREST STRUCTURE                            
 EXEC SP_IFRS_LI_EXEC_AND_LOG 'SP_IFRS_LI_ACCT_EIR_ECF_MERGE'                  
                  
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'DEBUG'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,'10 ECF MERGED'                  
  )                  
                  
 -- GET ALL MASTER ID OF NEWLY GENERATED EIR ECF                            
 TRUNCATE TABLE TMP_LI_T1                  
                  
 INSERT INTO TMP_LI_T1 (MASTERID)                  
 SELECT DISTINCT MASTERID                  
 FROM IFRS_LI_ACCT_EIR_ECF                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 --FILTER OUT NOT TODAY STOPPED ECF                            
 TRUNCATE TABLE TMP_LI_T2                  
                  
 INSERT INTO TMP_LI_T2 (MASTERID)                  
 SELECT DISTINCT A.MASTERID                  
 FROM TMP_LI_T1 A                  
 JOIN IFRS_LI_ACCT_EIR_ECF B ON B.PREV_PMT_DATE = B.PMT_DATE                  
  AND B.AMORTSTOPDATE = @V_CURRDATE                  
  AND B.MASTERID = A.MASTERID                  
                   
 UNION -- 20171016 ALSO INCLUDE ACCOUNT WITH ZERO AMOUNT (FIX CHKAMORT ON DUE_DATE CHANGE WHEN END_AMORT_DT - 1)                            
                   
 SELECT MASTERID                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF                  
 WHERE TOTAL_AMT = 0                  
  OR TOTAL_AMT_ACRU = 0                  
                  
 -- INSERT ACCRU VALUES FOR NEWLY GENERATED ECF                            
 -- NO ACCRU IF TODAY IS DOING AMORT                            
 TRUNCATE TABLE TMP_LI_T1                  
                  
 INSERT INTO TMP_LI_T1 (MASTERID)                  
 SELECT DISTINCT MASTERID                  
 FROM IFRS_LI_ACCT_EIR_ACF                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND DO_AMORT = 'Y'                  
                  
 TRUNCATE TABLE TMP_LI_T3                  
                  
 INSERT INTO TMP_LI_T3 (MASTERID)                  
 SELECT MASTERID                  
 FROM TMP_LI_T2                  
 WHERE MASTERID NOT IN (                  
   SELECT MASTERID                  
   FROM TMP_LI_T1                  
   )                  
                  
 IF @PARAM_DISABLE_ACCRU_PREV = 0                  
 BEGIN                  
  -- GET LAST ACF WITH DO_AMORT=N                            
  TRUNCATE TABLE TMP_LI_P1                  
                  
  INSERT INTO TMP_LI_P1 (ID)                  
  SELECT MAX(ID) AS ID                  
  FROM IFRS_LI_ACCT_EIR_ACF                  
  WHERE MASTERID IN (                  
    SELECT MASTERID                  
    FROM TMP_LI_T3                  
    )                  
   AND DO_AMORT = 'N'                  
   AND DOWNLOAD_DATE < @V_CURRDATE                  
   AND DOWNLOAD_DATE >= @V_PREVDATE                  
  GROUP BY MASTERID                  
                  
  -- GET FEE SUMMARY                            
  TRUNCATE TABLE TMP_LI_TF                  
                  
  INSERT INTO TMP_LI_TF (                  
   SUM_AMT                  
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT                  
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
    AND A.FLAG_CF = 'F'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
                  
  -- GET COST SUMMARY                            
  TRUNCATE TABLE TMP_LI_TC                  
                  
  INSERT INTO TMP_LI_TC (                  
   SUM_AMT        
   ,DOWNLOAD_DATE                  
   ,MASTERID                  
   )                  
  SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
   ,A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM (                  
   SELECT CASE                   
     WHEN A.FLAG_REVERSE = 'Y'                  
      THEN - 1 * A.AMOUNT                  
     ELSE A.AMOUNT                  
     END AS N_AMOUNT                  
    ,A.ECFDATE DOWNLOAD_DATE                  
    ,A.MASTERID                  
   FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A            
   WHERE A.MASTERID IN (                  
     SELECT MASTERID                  
     FROM TMP_LI_T3                  
     )                  
    AND A.STATUS = 'ACT'                  
    AND A.FLAG_CF = 'C'                  
    AND A.METHOD = 'EIR'                  
   ) A                  
  GROUP BY A.DOWNLOAD_DATE                  
   ,A.MASTERID                  
               
  --INSERT FEE 1                            
  INSERT INTO IFRS_LI_ACCT_EIR_ACCRU_PREV (                  
   FACNO                  
   ,CIFNO         
   ,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,AMORTDATE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,METHOD                  
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO                  
   ,@V_CURRDATE                  
   ,A.ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                  
        THEN - 1 * B.AMOUNT                  
       ELSE B.AMOUNT                  
       END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_FEE, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,NULL AS AMORTDATE                  
   ,'ECF'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'F'                  
  JOIN TMP_LI_TF C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  --20160407 EIR STOP REV                            
  LEFT JOIN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   ) D ON A.MASTERID = D.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20160407 EIR STOP REV                            
   AND D.MASTERID IS NULL                  
   --20180108 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV                      FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
    )                  
                  
  --COST 1                            
  INSERT INTO IFRS_LI_ACCT_EIR_ACCRU_PREV (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,AMOUNT                  
   ,STATUS                  
   ,CREATEDDATE                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,FLAG_REVERSE                  
   ,AMORTDATE                  
   ,SRCPROCESS                  
   ,ORG_CCY                  
   ,ORG_CCY_EXRATE                  
   ,PRDTYPE                  
   ,CF_ID                  
   ,METHOD                  
   )                  
  SELECT A.FACNO                  
   ,A.CIFNO                  
   ,@V_CURRDATE                  
   ,A.ECFDATE                  
   ,A.DATASOURCE                  
   ,B.PRDCODE                  
   ,B.TRXCODE                  
   ,B.CCY                  
   ,ROUND(CAST(CAST(CASE                   
       WHEN B.FLAG_REVERSE = 'Y'                  
        THEN - 1 * B.AMOUNT                  
       ELSE B.AMOUNT                  
       END AS FLOAT) / NULLIF(CAST(C.SUM_AMT AS FLOAT), 0) AS DECIMAL(32, 20)) * A.N_ACCRU_COST, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
   ,B.STATUS                  
   ,CURRENT_TIMESTAMP                  
   ,A.ACCTNO                  
   ,A.MASTERID                  
   ,B.FLAG_CF                  
   ,'N'                  
   ,NULL AS AMORTDATE                  
   ,'ECF'                  
   ,B.ORG_CCY                  
   ,B.ORG_CCY_EXRATE                  
   ,B.PRDTYPE                  
   ,B.CF_ID                  
   ,B.METHOD                  
  FROM IFRS_LI_ACCT_EIR_ACF A                  
  JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE                  
   AND A.MASTERID = B.MASTERID                  
   AND B.FLAG_CF = 'C'                  
  JOIN TMP_LI_TC C ON C.DOWNLOAD_DATE = A.ECFDATE                  
   AND C.MASTERID = A.MASTERID                  
  --20160407 EIR STOP REV                            
  LEFT JOIN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   ) D ON A.MASTERID = D.MASTERID                  
  WHERE A.ID IN (                  
    SELECT ID                  
    FROM TMP_LI_P1                  
    )                  
   --20160407 EIR STOP REV                            
   AND D.MASTERID IS NULL                  
   --20180108 EXCLUDE CF REV AND ITS PAIR                            
   AND B.CF_ID NOT IN (                  
    SELECT CF_ID                  
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
                      
    UNION ALL                  
                      
    SELECT CF_ID_REV               
    FROM IFRS_LI_ACCT_COST_FEE                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
     AND FLAG_REVERSE = 'Y'                  
     AND CF_ID_REV IS NOT NULL                  
    )                  
 END --IF;                            
                  
 -- 20171016 MARK FOR DO AMORT ACRU (FIX CHKAMORT ON DUE_DATE CHANGE WHEN END_AMORT_DT - 1)                          
 UPDATE IFRS_LI_ACCT_EIR_ACCRU_PREV                  
 SET STATUS = CONVERT(VARCHAR, @V_CURRDATE, 112)                  
 WHERE STATUS = 'ACT'                  
  AND MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_EIR_CF_ECF                  
   WHERE TOTAL_AMT = 0                      OR TOTAL_AMT_ACRU = 0                  
   )                  
                  
 --20180226 INSERT GAIN LOSS                          
 -- GET FEE SUMMARY WITH ECFDATE=@CURRDATE                          
 TRUNCATE TABLE TMP_LI_TF                  
                  
 INSERT INTO TMP_LI_TF (                  
  SUM_AMT                  
  ,DOWNLOAD_DATE                  
  ,MASTERID                  
  )                  
 SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
  ,A.DOWNLOAD_DATE                  
  ,A.MASTERID                  
 FROM (                  
  SELECT CASE                   
    WHEN A.FLAG_REVERSE = 'Y'                  
     THEN - 1 * A.AMOUNT                  
    ELSE A.AMOUNT                  
    END AS N_AMOUNT                  
   ,A.ECFDATE DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
  WHERE A.ECFDATE = @V_CURRDATE                  
   AND A.STATUS = 'ACT'                  
   AND A.FLAG_CF = 'F'                  
   AND A.METHOD = 'EIR'                  
  ) A                  
 GROUP BY A.DOWNLOAD_DATE                  
  ,A.MASTERID                  
                  
 -- GET COST SUMMARY WITH ECFDATE=@CURRDATE                      
 TRUNCATE TABLE TMP_LI_TC                  
                  
 INSERT INTO TMP_LI_TC (                  
  SUM_AMT                  
  ,DOWNLOAD_DATE                  
  ,MASTERID                  
  )                  
 SELECT SUM(A.N_AMOUNT) AS SUM_AMT                  
  ,A.DOWNLOAD_DATE                  
  ,A.MASTERID                  
 FROM (                  
  SELECT CASE                   
    WHEN A.FLAG_REVERSE = 'Y'                  
     THEN - 1 * A.AMOUNT                  
    ELSE A.AMOUNT                  
    END AS N_AMOUNT                  
   ,A.ECFDATE DOWNLOAD_DATE                  
   ,A.MASTERID                  
  FROM IFRS_LI_ACCT_EIR_COST_FEE_ECF A                  
  WHERE A.ECFDATE = @V_CURRDATE                  
   AND A.STATUS = 'ACT'                  
   AND A.FLAG_CF = 'C'                  
   AND A.METHOD = 'EIR'                  
  ) A                  
 GROUP BY A.DOWNLOAD_DATE                  
  ,A.MASTERID                  
                  
 --201801417 CLEAN UP GAIN LOSS                      
 DELETE                  
 FROM IFRS_LI_ACCT_EIR_GAIN_LOSS                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 --INSERT FEE GAIN LOSS                          
 INSERT INTO IFRS_LI_ACCT_EIR_GAIN_LOSS (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,ECFDATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,AMOUNT                  
  ,[STATUS]                  
  ,CREATEDDATE                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,FLAG_REVERSE                  
  ,AMORTDATE                  
  ,SRCPROCESS                  
  ,ORG_CCY                  
  ,ORG_CCY_EXRATE                  
  ,PRDTYPE                  
  ,CF_ID                  
  ,METHOD                  
  )                  
 SELECT IMA.FACILITY_NUMBER                  
  ,IMA.CUSTOMER_NUMBER                  
  ,@V_CURRDATE                  
  ,@V_CURRDATE                  
  ,IMA.DATA_SOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,- 1 * --20180417 GAIN LOSS DIBALIK                      
  ROUND(CAST(CAST(CASE                   
      WHEN B.FLAG_REVERSE = 'Y'                  
       THEN - 1 * B.AMOUNT                  
      ELSE B.AMOUNT                  
      END AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20)) * A.GAIN_LOSS_FEE_AMT, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
  ,B.STATUS                  
  ,CURRENT_TIMESTAMP                  
  ,IMA.ACCOUNT_NUMBER                  
  ,A.MASTERID                  
  ,B.FLAG_CF                  
  ,'N'        
  ,NULL AS AMORTDATE                  
  ,'ECF'                  
  ,B.ORG_CCY                  
  ,B.ORG_CCY_EXRATE                  
  ,B.PRDTYPE                  
  ,B.CF_ID                  
  ,B.METHOD                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF A                  
 JOIN IFRS_LI_IMA_AMORT_CURR IMA ON IMA.MASTERID = A.MASTERID                  
 JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = @V_CURRDATE                  
  AND A.MASTERID = B.MASTERID                  
  AND B.FLAG_CF = 'F'                  
 JOIN TMP_LI_TF C ON C.MASTERID = A.MASTERID                  
 WHERE COALESCE(A.GAIN_LOSS_AMT, 0) <> 0                  
                  
 --INSERT COST GAIN LOSS                          
 INSERT INTO IFRS_LI_ACCT_EIR_GAIN_LOSS (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,ECFDATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,AMOUNT                  
  ,[STATUS]                  
  ,CREATEDDATE                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,FLAG_REVERSE                  
  ,AMORTDATE                  
  ,SRCPROCESS                  
  ,ORG_CCY                  
  ,ORG_CCY_EXRATE                  
  ,PRDTYPE                  
  ,CF_ID                  
  ,METHOD                  
  )                  
 SELECT IMA.FACILITY_NUMBER                  
  ,IMA.CUSTOMER_NUMBER                  
  ,@V_CURRDATE                  
  ,@V_CURRDATE                  
  ,IMA.DATA_SOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,- 1 * --20180417 GAIN LOSS DIBALIK                      
  ROUND(CAST(CAST(CASE                   
      WHEN B.FLAG_REVERSE = 'Y'                  
       THEN - 1 * B.AMOUNT                  
      ELSE B.AMOUNT                  
      END AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20)) * A.GAIN_LOSS_COST_AMT, @V_ROUND, @V_FUNCROUND) AS N_AMOUNT                  
  ,B.STATUS                  
  ,CURRENT_TIMESTAMP                  
  ,IMA.ACCOUNT_NUMBER                  
  ,A.MASTERID                  
  ,B.FLAG_CF                  
  ,'N'                  
  ,NULL AS AMORTDATE                  
  ,'ECF'                  
  ,B.ORG_CCY                  
  ,B.ORG_CCY_EXRATE                  
  ,B.PRDTYPE                  
  ,B.CF_ID                  
  ,B.METHOD                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF A               
 JOIN IFRS_LI_IMA_AMORT_CURR IMA ON IMA.MASTERID = A.MASTERID                  
 JOIN IFRS_LI_ACCT_EIR_COST_FEE_ECF B ON B.ECFDATE = @V_CURRDATE                  
  AND A.MASTERID = B.MASTERID                  
  AND B.FLAG_CF = 'C'                  
 JOIN TMP_LI_TC C ON C.MASTERID = A.MASTERID                  
 WHERE COALESCE(A.GAIN_LOSS_AMT, 0) <> 0                  
                  
 --20180226 ADJUST GAIN LOSS BACK TO IFRS_LI_ACCT_EIR_COST_FEE_ECF                          
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_ECF                  
 SET AMOUNT = ((A.FEE_AMT + A.GAIN_LOSS_FEE_AMT) / A.FEE_AMT) * AMOUNT                  
FROM IFRS_LI_ACCT_EIR_CF_ECF A                  
 WHERE A.MASTERID = IFRS_LI_ACCT_EIR_COST_FEE_ECF.MASTERID                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_ECF.ECFDATE = @V_CURRDATE                  
  AND COALESCE(A.GAIN_LOSS_FEE_AMT, 0) <> 0                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_ECF.FLAG_CF = 'F'                  
                  
 UPDATE IFRS_LI_ACCT_EIR_COST_FEE_ECF                  
 SET AMOUNT = ((A.COST_AMT + A.GAIN_LOSS_COST_AMT) / A.COST_AMT) * AMOUNT                  
 FROM IFRS_LI_ACCT_EIR_CF_ECF A                  
 WHERE A.MASTERID = IFRS_LI_ACCT_EIR_COST_FEE_ECF.MASTERID                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_ECF.ECFDATE = @V_CURRDATE                  
  AND COALESCE(A.GAIN_LOSS_FEE_AMT, 0) <> 0                  
  AND IFRS_LI_ACCT_EIR_COST_FEE_ECF.FLAG_CF = 'C'                  
              
 INSERT INTO IFRS_LI_AMORT_LOG (                  
  DOWNLOAD_DATE                  
  ,DTM                  
  ,OPS                  
  ,PROCNAME                  
  ,REMARK                  
  )                  
 VALUES (                  
  @V_CURRDATE                  
  ,CURRENT_TIMESTAMP                  
  ,'END'                  
  ,'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
  ,''                  
  )                  
END 
GO
