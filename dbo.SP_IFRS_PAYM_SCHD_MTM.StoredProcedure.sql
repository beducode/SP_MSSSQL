USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_PAYM_SCHD_MTM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_PAYM_SCHD_MTM]    
AS    
/*    
 - RUNNING ONLY ENDOFMONTH    
 - MARKET RATE > 0    
 - DATA SOURCE LOAN    
 - PAYMENT SCHEDULE TYPE CUTOFF    
    
COMPONENT TYPE :    
0 : FIX PRINCIPAL AMOUNT    
1 : FIX INTEREST AMOUNT    
2 : FIX INSTALMENT AMOUNT    
3 : FIX INTEREST PERCENTAGE    
4 : FIX INSTALMENT AMOUNT FOR COMPONENT TYPE 3 & 5    
5 : STEP UP DISBURSMENT    
*/    
--VARIABLE    
DECLARE @V_CURRDATE DATE    
 ,@V_PREVDATE DATE    
 ,@V_COUNTER_PAY INTEGER    
 ,@V_MAX_COUNTERPAY INTEGER    
 ,@V_NEXT_COUNTER_PAY INTEGER    
 ,@V_PMT_DATE DATE    
 ,---ADD YAHYA    
 @V_NEXT_START_DATE DATE    
 ,---ADD YAHYA    
 @V_ENDOFMONTH DATE    
 ,    
 --CONSTANT    
 @CUT_OFF_DATE DATE    
 ,@V_ROUND INTEGER    
 ,@V_FUNCROUND INTEGER    
 ,@V_LOG_ID INTEGER    
 ,@PARAM_CALC_TO_LASTPAYMENT INT ---ADD YAHYA IF 0 CURRDATE 1 LAST CYCLEDATE    
    
SET @CUT_OFF_DATE = '1 JAN 2016'    
SET @V_MAX_COUNTERPAY = 0    
SET @V_COUNTER_PAY = 0    
SET @V_NEXT_COUNTER_PAY = 1    
  
SELECt @V_ROUND = VALUE1,   
 @V_FUNCROUND = VALUE2  
FROM TBLM_COMMONCODEDETAIL  
WHERE COMMONCODE = 'SCM003'  
  
SET @V_LOG_ID = 912    
SET @PARAM_CALC_TO_LASTPAYMENT = 0 ---ADD YAHYA    
    
BEGIN    
 SELECT @V_CURRDATE = CURRDATE    
  ,@V_PREVDATE = PREVDATE    
  ,@V_ENDOFMONTH = EOMONTH(CURRDATE)    
 FROM IFRS_PRC_DATE_AMORT;    
   
   
 IF @V_ENDOFMONTH = @V_CURRDATE  
 BEGIN  
    
  --TRUNCATE TABLE IFRS_PAYM_SCHD_MTM    
 DELETE [IFRS_PAYM_SCHD_MTM] WHERE DOWNLOAD_DATE = @V_CURRDATE  
    
  INSERT INTO [IFRS_PAYM_SCHD_MTM]    
  (    
    [MASTERID]    
    ,ACCOUNT_NUMBER  
    ,[PMTDATE]    
    ,[INTEREST_RATE]    
    ,[OSPRN]    
    ,[PRINCIPAL]    
    ,[INTEREST]    
    ,[DISB_PERCENTAGE]    
    ,[DISB_AMOUNT]    
    ,[PLAFOND]    
    ,[I_DAYS]    
    ,[COUNTER]    
    ,[ICC]    
    ,[OUTSTANDING]    
    ,[DOWNLOAD_DATE]    
    ,[SCH_FLAG]    
    ,[GRACE_DATE]    
   )    
    
  SELECT A.[MASTERID]    
   ,B.ACCOUNT_NUMBER  
    ,[PMTDATE]    
    ,A.[INTEREST_RATE]    
    ,A.[OSPRN]    
    ,A.[PRINCIPAL]    
    ,A.[INTEREST]    
    ,A.[DISB_PERCENTAGE]    
    ,A.[DISB_AMOUNT]    
    ,A.[PLAFOND]    
    ,A.[I_DAYS]    
    ,ROW_NUMBER() OVER( PARTITION BY A.MASTERID ORDER BY A.PMTDATE ASC) [COUNTER]    
    ,A.[ICC]    
    ,A.[OUTSTANDING]    
    ,@V_CURRDATE AS DOWNLOAD_DATE   
    ,A.[SCH_FLAG]    
    ,A.[GRACE_DATE]    
  FROM [IFRS_PAYM_SCHD_ALL] A    
   INNER JOIN IFRS_IMA_AMORT_CURR B ON A.MASTERID = B.MASTERID    
  WHERE  B.IFRS9_CLASS IN ('FVOCI','FVTPL')    
  AND B.MARKET_RATE <> 0   
  AND PMTDATE > @V_CURRDATE AND B.DOWNLOAD_DATE = @V_CURRDATE    
  AND END_DATE IS NULL     
  ORDER BY PMTDATE    
    
   UPDATE X    
   SET X.PV_CF = (X.PRINCIPAL + X.INTEREST) / POWER((1 + Z.MARKET_RATE / 12 / 100), X.COUNTER) ,  
   X.MARKET_RATE = Z.MARKET_RATE   
   FROM IFRS_PAYM_SCHD_MTM X    
   INNER JOIN IFRS_IMA_AMORT_CURR Z ON X.MASTERID = Z.MASTERID    
   WHERE Z.DOWNLOAD_DATE = @V_CURRDATE    AND X.DOWNLOAD_DATE = @V_CURRDATE
    
   DELETE IFRS_EIR_ADJUSTMENT    
   WHERE DOWNLOAD_DATE = @V_CURRDATE;    
    
   INSERT INTO IFRS_EIR_ADJUSTMENT (    
    DOWNLOAD_DATE    
    ,MASTERID    
    ,ACCOUNT_NUMBER    
    ,IFRS9_CLASS    
    ,LOAN_START_DATE    
    ,LOAN_DUE_DATE    
    ,OUTSTANDING    
    ,INTEREST_RATE    
    ,EIR    
    ,MARKET_RATE    
    ,FAIR_VALUE_AMT    
    ,TOTAL_PV_CF    
    ,--GANTI NAMA    
    TOT_ADJUST --- TOTAL_PV_CF - ISNULL(FAIRVALUEAMT, OUTSTANDING)    
    )    
   SELECT A.DOWNLOAD_DATE    
    ,A.MASTERID    
    ,A.ACCOUNT_NUMBER    
    ,A.IFRS9_CLASS    
    ,A.LOAN_START_DATE    
    ,A.LOAN_DUE_DATE    
    ,A.OUTSTANDING    
    ,A.INTEREST_RATE    
    ,A.EIR    
    ,A.MARKET_RATE    
    ,A.FAIR_VALUE_AMOUNT    
    ,B.TOTAL_PV_CF AS TOTAL_PV_CF    
    ,(B.TOTAL_PV_CF - COALESCE(A.FAIR_VALUE_AMOUNT, A.OUTSTANDING)) AS TOT_ADJUST    
   FROM IFRS_IMA_AMORT_CURR A    
   INNER JOIN (    
    SELECT X.MASTERID    
  ,MIN(X.PMTDATE) AS MIN_PMTDATE    
  ,MAX(X.PMTDATE) AS MAX_PMTDATE    
  ,SUM(X.PRINCIPAL + X.INTEREST) AS TOT_INSTALMENT    
  ,SUM((X.PRINCIPAL + X.INTEREST) / POWER((1 + Z.MARKET_RATE / 12 / 100), X.COUNTER)) AS TOTAL_PV_CF    
    FROM IFRS_PAYM_SCHD_MTM X    
    INNER JOIN IFRS_IMA_AMORT_CURR Z ON X.MASTERID = Z.MASTERID    
    WHERE Z.DOWNLOAD_DATE = @V_CURRDATE  AND X.DOWNLOAD_DATE = @V_CURRDATE  
    GROUP BY X.MASTERID    
    ) B ON A.MASTERID = B.MASTERID    
   WHERE A.DOWNLOAD_DATE = @V_CURRDATE    
    AND A.IFRS9_CLASS IN (    
  'FVTPL'    
  ,'FVOCI'    
  ) --IFRS_CLASS    
    AND A.ACCOUNT_STATUS = 'A'    
    
  END  
    
    
    
    
 /*    
 IF (@V_CURRDATE = @V_ENDOFMONTH)    
 BEGIN    
  SELECT @V_ROUND = CAST(VALUE1 AS INT)    
   ,@V_FUNCROUND = CAST(VALUE2 AS INT)    
  FROM TBLM_COMMONCODEDETAIL    
  WHERE COMMONCODE = 'SCM003'    
    
  DELETE IFRS_BATCH_LOG_DETAILS    
  WHERE DOWNLOAD_DATE = @V_CURRDATE    
   AND BATCH_ID_HEADER = @V_LOG_ID    
   AND BATCH_NAME = 'PMTSCHD'    
    
  --TRACKING--    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,0    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,0    
   ,'JUST STARTED'    
   );    
    
  ----COMMIT;    
  --IF @V_CURRDATE < @CUT_OFF_DATE RETURN    
  TRUNCATE TABLE TMP_SCHEDULE_MAIN_MTM;    
    
  TRUNCATE TABLE IFRS_PAYM_SCHD_MTM;    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,1    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,1    
   ,'INSERT TMP_SCHEDULE_MAIN_MTM'    
   );    
    
  ----COMMIT;    
  INSERT INTO TMP_SCHEDULE_MAIN_MTM (    
   DOWNLOAD_DATE    
   ,MASTERID    
   ,ACCOUNT_NUMBER    
   ,BRANCH_CODE    
   ,PRODUCT_CODE    
   ,START_DATE    
   ,DUE_DATE    
   ,START_AMORTIZATION_DATE    
   ,END_AMORTIZATION_DATE    
   ,FIRST_PMT_DATE    
   ,CURRENCY    
   ,OUTSTANDING    
   ,PLAFOND    
   ,    
   --HOLD_AMOUNT,    
   INTEREST_RATE    
   ,TENOR    
   ,PAYMENT_TERM    
   ,PAYMENT_CODE    
   ,INTEREST_CALCULATION_CODE    
   ,NEXT_PMTDATE    
   ,NEXT_COUNTER_PAY    
   ,SCH_FLAG    
   ,GRACE_DATE    
   ) --BIBD GRACE PERIOD    
  /*  BCA DISABLE BPI ,SPECIAL_FLAG */    
  SELECT PMA.DOWNLOAD_DATE    
   ,PMA.MASTERID    
   ,PMA.ACCOUNT_NUMBER    
   ,PMA.BRANCH_CODE    
   ,PMA.PRODUCT_CODE    
   ,PMA.LOAN_START_DATE    
   ,PMA.LOAN_DUE_DATE    
   ,CASE     
    WHEN @PARAM_CALC_TO_LASTPAYMENT = 0    
     THEN @V_CURRDATE    
    ELSE CASE     
      WHEN ISNULL(PMA.LAST_PAYMENT_DATE, PMA.LOAN_START_DATE) <= PMA.LOAN_START_DATE    
       THEN PMA.LOAN_START_DATE    
      ELSE CASE     
        WHEN PMA.LAST_PAYMENT_DATE >= ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE)    
         THEN DATEADD(MONTH, - 1, ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE))    
        ELSE PMA.LAST_PAYMENT_DATE    
        END    
      END    
    END START_AMORTIZATION_DATE    
   ,PMA.LOAN_DUE_DATE    
   ,CASE     
    WHEN PMA.NEXT_PAYMENT_DATE >= ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE)    
     OR CONVERT(VARCHAR(6), PMA.NEXT_PAYMENT_DATE, 112) = CONVERT(VARCHAR(6), ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE), 112)    
     THEN ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE)    
    ELSE PMA.NEXT_PAYMENT_DATE    
    END AS FIRST_PMT_DATE    
   ,PMA.CURRENCY    
   ,PMA.OUTSTANDING    
   ,PMA.PLAFOND    
   ,PMA.INTEREST_RATE    
   ,CASE     
    WHEN ISNULL(PMA.TENOR, 0) > DATEDIFF(MONTH, PMA.LOAN_START_DATE, PMA.LOAN_DUE_DATE)    
     THEN ISNULL(PMA.TENOR, 0)    
    ELSE DATEDIFF(MONTH, PMA.LOAN_START_DATE, PMA.LOAN_DUE_DATE)    
    END AS TENOR    
   ,PMA.PAYMENT_TERM    
   ,PMA.PAYMENT_CODE    
   ,PMA.INTEREST_CALCULATION_CODE    
   ,CASE     
    WHEN PMA.NEXT_PAYMENT_DATE >= ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE)    
     OR CONVERT(VARCHAR(6), PMA.NEXT_PAYMENT_DATE, 112) = CONVERT(VARCHAR(6), ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE), 112)    
     THEN ISNULL(PMA.LOAN_END_AMORTIZATION, PMA.LOAN_DUE_DATE)    
    ELSE PMA.NEXT_PAYMENT_DATE    
    END    
   ,0    
   ,'N'    
   ,PMA.INSTALLMENT_GRACE_PERIOD AS GRACE_DATE -- BIBD GRACE PERIOD    
   /*  BCA DISABLE BPI  ,CASE WHEN PMA.NEXT_PAYMENT_DATE = PMA.FIRST_INSTALLMENT_DATE AND PMA.SPECIAL_FLAG = 1 THEN 1 ELSE 0 END --- BPI FLAG ONLY CTBC */    
  FROM IFRS_MASTER_ACCOUNT AS PMA    
  INNER JOIN IFRS_IMA_AMORT_CURR PMC ON PMA.MASTERID = PMC.MASTERID    
   AND PMA.DOWNLOAD_DATE = PMC.DOWNLOAD_DATE    
  WHERE PMA.DOWNLOAD_DATE = @V_CURRDATE    
   AND PMA.IFRS9_CLASS IN (    
    'FVTPL'    
    ,'FVOCI'    
    )    
   ---AND PMA.DATA_SOURCE = 'LOAN'    
   AND PMA.MARKET_RATE > 0    
   AND PMA.ACCOUNT_STATUS = 'A'    
   AND PMA.IAS_CLASS = 'A' -----ADD YAHYA    
   AND PMA.LOAN_DUE_DATE > @V_CURRDATE    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,1    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,3    
   ,'INITIAL PROCESS'    
   );    
    
  ----COMMIT;    
  TRUNCATE TABLE TMP_PY0;    
    
  TRUNCATE TABLE TMP_PY1;    
    
  TRUNCATE TABLE TMP_PY2;    
    
  TRUNCATE TABLE TMP_PY3;    
    
  TRUNCATE TABLE TMP_PY4;    
    
  TRUNCATE TABLE TMP_PY5;    
    
  INSERT INTO TMP_PY0    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY0    
  WHERE PY0.COMPONENT_TYPE = '0'    
   AND PY0.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY0.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  INSERT INTO TMP_PY1    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY1    
  WHERE PY1.COMPONENT_TYPE = '1'    
   AND PY1.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY1.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  INSERT INTO TMP_PY2    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY2    
  WHERE PY2.COMPONENT_TYPE = '2'    
   AND PY2.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY2.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  INSERT INTO TMP_PY3    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY3    
  WHERE PY3.COMPONENT_TYPE = '3'    
   AND PY3.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY3.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  INSERT INTO TMP_PY4    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY4    
  WHERE PY4.COMPONENT_TYPE = '4'    
   AND PY4.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY4.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  INSERT INTO TMP_PY5    
  SELECT *    
  FROM IFRS_MASTER_PAYMENT_SETTING PY5    
  WHERE PY5.COMPONENT_TYPE = '5'    
   AND PY5.DOWNLOAD_DATE = @V_CURRDATE    
   AND PY5.FREQUENCY IN (    
    'M'    
    ,'N'    
    ,'D'    
    );    
    
  TRUNCATE TABLE TMP_SCHEDULE_CURR_MTM_HIST;    
    
  TRUNCATE TABLE TMP_SCHEDULE_PREV_MTM_HIST;    
    
  TRUNCATE TABLE TMP_SCHEDULE_CURR;    
    
  TRUNCATE TABLE TMP_SCHEDULE_PREV;    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,1    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,4    
   ,'INSERT TMP_SCHEDULE_CURR'    
   );    
    
  ----COMMIT;    
  INSERT INTO TMP_SCHEDULE_CURR (    
   MASTERID    
   ,ACCOUNT_NUMBER    
   ,INTEREST_RATE    
   ,PMTDATE    
   ,OSPRN    
   ,PRINCIPAL    
   ,INTEREST    
   ,DISB_PERCENTAGE    
   ,DISB_AMOUNT    
   ,PLAFOND    
   ,I_DAYS    
   ,COUNTER    
   ,DATE_START    
   ,DATE_END    
   ,TENOR    
   ,PAYMENT_CODE    
   ,ICC    
,NEXT_PMTDATE    
   ,NEXT_COUNTER_PAY    
   ,SCH_FLAG    
   ,GRACE_DATE    
   ) --BIBD FOR GRACE PERIOD    
  /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
  SELECT A.MASTERID    
   ,A.ACCOUNT_NUMBER    
   ,A.INTEREST_RATE    
   ,A.START_AMORTIZATION_DATE    
   ,A.OUTSTANDING    
   ,0 AS PRINCIPAL    
   ,0 AS INTEREST    
   ,ISNULL(PY5.AMOUNT, 0) AS DISB_PERCENTAGE    
   ,A.OUTSTANDING AS DISB_AMOUNT    
   ,A.PLAFOND AS PLAFOND    
   ,0 AS I_DAYS    
   ,0 COUNTER    
   ,A.FIRST_PMT_DATE AS DATE_START    
   ,A.END_AMORTIZATION_DATE    
   ,A.TENOR    
   ,A.PAYMENT_CODE    
   ,A.INTEREST_CALCULATION_CODE    
   ,A.NEXT_PMTDATE AS NEXT_PMTDATE    
   ,A.NEXT_COUNTER_PAY + 1    
   ,A.SCH_FLAG    
   ,A.GRACE_DATE --BIBD FOR GRACE PERIOD    
   /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
  FROM TMP_SCHEDULE_MAIN_MTM A    
  LEFT JOIN TMP_PY5 PY5 ON A.MASTERID = PY5.MASTERID    
   AND A.DOWNLOAD_DATE BETWEEN PY5.DATE_START    
    AND PY5.DATE_END    
   AND DATEDIFF(MONTH, A.DOWNLOAD_DATE, PY5.DATE_START) % PY5.INCREMENTS = 0;    
    
  ----COMMIT;    
  INSERT INTO TMP_SCHEDULE_CURR_MTM_HIST    
  SELECT *    
  FROM TMP_SCHEDULE_CURR;    
    
  ----COMMIT;    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,1    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,5    
   ,'INSERT IFRS_PAYM_SCHD'    
   );    
    
  ----COMMIT;    
  INSERT INTO IFRS_PAYM_SCHD_MTM (    
   MASTERID    
   --,ACCOUNT_NUMBER    
   ,PMTDATE    
   ,INTEREST_RATE    
   ,OSPRN    
   ,PRINCIPAL    
   ,INTEREST    
   ,DISB_PERCENTAGE    
   ,DISB_AMOUNT    
   ,PLAFOND    
   ,I_DAYS    
   ,ICC    
   ,COUNTER    
   ,DOWNLOAD_DATE    
   ,SCH_FLAG    
   ,GRACE_DATE    
   ) --BIBD FOR GRACE    
  /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
  SELECT MASTERID    
   --,ACCOUNT_NUMBER    
   ,PMTDATE    
   ,INTEREST_RATE    
   ,OSPRN    
   ,PRINCIPAL    
   ,INTEREST    
   ,DISB_PERCENTAGE    
   ,DISB_AMOUNT    
   ,PLAFOND    
   ,I_DAYS    
   ,ICC    
   ,COUNTER    
   ,@V_CURRDATE    
   ,SCH_FLAG    
   ,GRACE_DATE --BIBD FOR GRACE    
   /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
  FROM TMP_SCHEDULE_CURR;    
    
  SELECT @V_MAX_COUNTERPAY = MAX(TENOR)    
  FROM TMP_SCHEDULE_MAIN_MTM;    
    
  WHILE (@V_COUNTER_PAY <= @V_MAX_COUNTERPAY)    
  BEGIN    
   --- START ADD YAHYA--    
   DECLARE @TMP_MIN_MAX_DATE TABLE (    
    ACCOUNT_NUMBER VARCHAR(50)    
    ,MIN_DATE DATE    
    )    
    
   DELETE    
   FROM @TMP_MIN_MAX_DATE    
    
   INSERT INTO @TMP_MIN_MAX_DATE    
   SELECT A.ACCOUNT_NUMBER    
    ,MIN(A.DATE_START) AS MIN_DATE -- INTO #TMP_MIN_MAX_DATE     
   FROM IFRS_MASTER_PAYMENT_SETTING A    
   INNER JOIN TMP_SCHEDULE_CURR B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER    
    AND A.DATE_START > B.NEXT_PMTDATE    
   GROUP BY A.ACCOUNT_NUMBER;    
    
   --- END ADD YAHYA--    
   SET @V_COUNTER_PAY = @V_COUNTER_PAY + 1;    
   SET @V_NEXT_COUNTER_PAY = @V_NEXT_COUNTER_PAY + 1;    
    
   INSERT INTO IFRS_BATCH_LOG_DETAILS (    
    DOWNLOAD_DATE    
    ,BATCH_ID    
    ,BATCH_ID_HEADER    
    ,BATCH_NAME    
    ,PROCESS_NAME    
    ,START_DATE    
    ,CREATEDBY    
    ,COUNTER    
    ,REMARKS    
    )    
   VALUES (    
    @V_CURRDATE    
    ,2    
    ,@V_LOG_ID    
    ,'PMTSCHD'    
    ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
    ,GETDATE()    
    ,'IFRS ENGINE'    
    ,@V_COUNTER_PAY    
    ,'PAYMENT SCHEDULE LOOPING'    
    );    
    
   --COMMIT;    
   TRUNCATE TABLE TMP_SCHEDULE_PREV;    
    
   INSERT INTO TMP_SCHEDULE_PREV (    
    MASTERID    
    ,ACCOUNT_NUMBER    
    ,INTEREST_RATE    
    ,PMTDATE    
    ,OSPRN    
    ,PRINCIPAL    
    ,INTEREST    
    ,DISB_PERCENTAGE    
    ,DISB_AMOUNT    
    ,PLAFOND    
    ,I_DAYS    
    ,COUNTER    
    ,DATE_START    
    ,DATE_END    
    ,TENOR    
    ,PAYMENT_CODE    
    ,ICC    
    ,NEXT_PMTDATE    
    ,NEXT_COUNTER_PAY    
    ,SCH_FLAG    
    ,GRACE_DATE    
    ) --BIBD FOR GRACE PERIOD    
   /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
   SELECT A.MASTERID    
    ,A.ACCOUNT_NUMBER    
    ,ISNULL(PY3.AMOUNT, A.INTEREST_RATE) AS INTEREST_RATE    
    ,A.NEXT_PMTDATE AS NEW_PMTDATE    
    ,ROUND((    
      CASE     
       WHEN PY5.COMPONENT_TYPE = '5'    
        THEN A.OSPRN + (PY5.AMOUNT / 100 * A.PLAFOND)    
       ELSE A.OSPRN    
       END - (    
       ROUND((    
         CASE     
          WHEN A.GRACE_DATE >= A.NEXT_PMTDATE    
           AND A.GRACE_DATE IS NOT NULL    
           THEN --BIBD FOR GRACE PERIOD    
            0    
          ELSE CASE     
            WHEN A.NEXT_PMTDATE >= A.DATE_END    
             THEN A.OSPRN    
            ELSE CASE     
              WHEN PY0.COMPONENT_TYPE = 0    
               THEN --FIX PRINCIPAL    
                CASE     
                 WHEN A.OSPRN <= PY0.AMOUNT    
                  THEN A.OSPRN    
                 ELSE PY0.AMOUNT    
                 END    
              WHEN PY2.COMPONENT_TYPE = 2    
               THEN --INSTALMENT    
                CASE     
                 WHEN A.OSPRN <= PY2.AMOUNT    
                  THEN A.OSPRN    
                 ELSE PY2.AMOUNT - (    
                   ROUND((    
                     CASE     
                      WHEN PY1.COMPONENT_TYPE = '1'    
                       THEN --FIX INTEREST    
                        PY1.AMOUNT    
                      ELSE CASE     
                        WHEN A.ICC = '1'    
                         THEN --ACTUAL/360    
                          A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
                        WHEN A.ICC = '2'    
                         THEN --ACTUAL/365    
                          A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
                        WHEN A.ICC = '6'    
                         THEN --30 / 360    
                          A.INTEREST_RATE / 100 * A.OSPRN * ISNULL(PY1.INCREMENTS, PY2.INCREMENTS) * 30 / 360    
                        ELSE 0    
                        END    
                      END    
                     ), @V_ROUND, @V_FUNCROUND)    
                   )    
                 END    
              WHEN PY4.COMPONENT_TYPE = 4    
               THEN --INSTALMENT    
                CASE     
                 WHEN A.OSPRN <= PY4.AMOUNT    
                  THEN A.OSPRN    
                 ELSE PY4.AMOUNT - (    
                   ROUND((    
                     CASE     
                      WHEN A.ICC = '1'    
                       THEN --ACTUAL/360    
                        ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
                      WHEN A.ICC = '2'    
                       THEN --ACTUAL/365    
                        ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
                      WHEN A.ICC = '6'    
                       THEN --ACTUAL/365    
                        ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * ISNULL(PY3.INCREMENTS, PY4.INCREMENTS) * 30 / 360    
                      ELSE 0    
                      END    
                     ), @V_ROUND, @V_FUNCROUND)    
                   )    
                 END    
              ELSE 0    
              END    
            END    
          END    
         ), @V_ROUND, @V_FUNCROUND)    
       )    
      ), @V_ROUND, @V_FUNCROUND) AS NEW_OSPRN    
    ,ROUND((    
      CASE     
       WHEN A.GRACE_DATE >= A.NEXT_PMTDATE    
        AND A.GRACE_DATE IS NOT NULL    
        THEN --BIBD FOR GRACE PERIOD    
         0    
       ELSE CASE     
         WHEN A.NEXT_PMTDATE >= A.DATE_END    
          THEN A.OSPRN    
         ELSE CASE     
           WHEN PY0.COMPONENT_TYPE = 0    
            THEN --FIX PRINCIPAL    
             CASE     
              WHEN A.OSPRN <= PY0.AMOUNT    
               THEN A.OSPRN    
              ELSE PY0.AMOUNT    
              END    
           WHEN PY2.COMPONENT_TYPE = 2    
            THEN --INSTALMENT    
             CASE     
              WHEN A.OSPRN <= PY2.AMOUNT    
               THEN A.OSPRN    
              ELSE PY2.AMOUNT - (    
                ROUND((    
                  CASE     
                   WHEN PY1.COMPONENT_TYPE = '1'    
                    THEN --FIX INTEREST    
                     PY1.AMOUNT    
                   ELSE CASE     
                     WHEN A.ICC = '1'    
                      THEN --ACTUAL/360    
                       A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
                     WHEN A.ICC = '2'    
                      THEN --ACTUAL/365    
                       A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
                     WHEN A.ICC = '6'    
                      THEN --30/360    
                       A.INTEREST_RATE / 100 * A.OSPRN * ISNULL(PY1.INCREMENTS, PY2.INCREMENTS) * 30 / 360    
                     ELSE 0    
                     END    
                   END    
                  ), @V_ROUND, @V_FUNCROUND)    
                )    
              END    
           WHEN PY4.COMPONENT_TYPE = 4    
            THEN --INSTALMENT    
             CASE     
              WHEN A.OSPRN <= PY4.AMOUNT    
               THEN A.OSPRN    
              ELSE PY4.AMOUNT - (    
                ROUND((    
                  CASE     
                   WHEN A.ICC = '1'    
                    THEN --ACTUAL/360    
                     ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
                   WHEN A.ICC = '2'    
                    THEN --ACTUAL/365    
                     ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
                   WHEN A.ICC = '6'    
                    THEN --30/360    
                     ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * ISNULL(PY3.INCREMENTS, PY4.INCREMENTS) * 30 / 360    
                   ELSE 0    
                   END    
                  ), @V_ROUND, @V_FUNCROUND)    
                )    
              END    
           ELSE 0    
           END    
         END    
       END    
      ), @V_ROUND, @V_FUNCROUND) AS NEW_PRINCIPAL    
    ,ROUND((    
      CASE     
       WHEN A.GRACE_DATE >= A.NEXT_PMTDATE    
        AND A.GRACE_DATE IS NOT NULL    
        THEN --BIBD FOR GRACE PERIOD     
         0    
       ELSE    
        /*  BCA DISABLE BPI     
            -- ADD YAHYA TO CALCULATE BPI FLAG ONLY CTBC    
                                                CASE WHEN     
            A.SPECIAL_FLAG = 1 AND @V_COUNTER_PAY = 1    
            THEN     
             A.INTEREST_RATE/100*(DATEDIFF(DAY,A.PMTDATE,A.DATE_START))*    
             A.OSPRN/12/(DATEDIFF(DAY,CASE WHEN A.DATE_START = EOMONTH(A.DATE_START)     
             THEN EOMONTH(DATEADD(MONTH,-1,A.DATE_START)) ELSE DATEADD(MONTH,-1,A.DATE_START) END,A.DATE_START))    
            ----END ADD YAHYA    
            ELSE     
            */    
        CASE     
         WHEN PY1.COMPONENT_TYPE = '1'    
          THEN --FIX INTEREST    
           CASE     
            WHEN PY1.AMOUNT = 0    
             THEN CASE     
               WHEN A.ICC = '1'    
                THEN --ACTUAL/360    
                 A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
               WHEN A.ICC = '2'    
                THEN --ACTUAL/365    
                 A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
               WHEN A.ICC = '6'    
                THEN --30/360    
                 -- ADD YAHYA TO CALCULATE INTEREST IF MIGRATION IN CUTOFF    
                 CASE     
                  WHEN (    
                    @PARAM_CALC_TO_LASTPAYMENT = 0    
                    AND A.ICC = '6'    
                    AND @V_COUNTER_PAY = 1    
                    )    
                   THEN A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
                  ELSE A.INTEREST_RATE / 100 * A.OSPRN * PY1.INCREMENTS * 30 / 360    
                  END    
                 ----END ADD YAHYA    
               ELSE 0    
               END    
            ELSE PY1.AMOUNT    
            END    
         WHEN PY3.COMPONENT_TYPE = '3'    
          THEN CASE     
            WHEN A.ICC = '1'    
             THEN --ACTUAL/360    
              ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
            WHEN A.ICC = '2'    
             THEN --ACTUAL/365    
              ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
            WHEN A.ICC = '6'    
             THEN --30/360    
              -- ADD YAHYA TO CALCULATE INTEREST IF MIGRATION IN CUTOFF    
              CASE     
               WHEN (    
                 @PARAM_CALC_TO_LASTPAYMENT = 0    
                 AND A.ICC = '6'    
                 AND @V_COUNTER_PAY = 1    
                 )    
                THEN ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
               ELSE ISNULL(PY3.AMOUNT, A.INTEREST_RATE) / 100 * A.OSPRN * PY3.INCREMENTS * 30 / 360    
               END    
              ----END ADD YAHYA    
            ELSE 0    
            END    
         ELSE CASE     
           WHEN A.ICC = '1'    
            THEN --ACTUAL/360    
             A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
           WHEN A.ICC = '2'    
            THEN --ACTUAL/365    
             A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 365    
           WHEN A.ICC = '6'    
            THEN --30/360    
             -- ADD YAHYA TO CALCULATE INTEREST IF MIGRATION IN CUTOFF    
             CASE     
              WHEN @PARAM_CALC_TO_LASTPAYMENT = 0    
               AND A.ICC = '6'    
               AND @V_COUNTER_PAY = 1    
               THEN A.INTEREST_RATE / 100 * A.OSPRN * DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE) / 360    
              ELSE A.INTEREST_RATE / 100 * A.OSPRN * ISNULL(PY2.INCREMENTS, 1) * 30 / 360    
              END    
             ----END ADD YAHYA    
           ELSE 0    
           END    
         END    
        /*  BCA DISABLE BPI  END */    
       END    
      ), @V_ROUND, @V_FUNCROUND) AS NEW_INTEREST    
    ,ISNULL(PY5.AMOUNT, 0) AS DISB_PERCENTAGE    
    ,ISNULL(PY5.AMOUNT, 0) / 100 * A.PLAFOND AS DISB_AMOUNT    
    ,A.PLAFOND    
    ,CASE     
     WHEN A.GRACE_DATE >= A.NEXT_PMTDATE    
      AND A.GRACE_DATE IS NOT NULL    
      THEN 0    
     ELSE CASE     
       WHEN A.ICC IN (    
         '1'    
         ,'2'    
         )    
        THEN CASE     
          WHEN PY1.COMPONENT_TYPE = '1'    
           THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
          WHEN PY2.COMPONENT_TYPE = '2'    
           THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
          WHEN PY3.COMPONENT_TYPE = '3'    
           THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
          ELSE 0    
          END    
       WHEN A.ICC = '6'    
        THEN    
         ---- ADD YAHYA TO CALCULATE I_DAYS IF MIGRATION IN CUTOFF    
         CASE     
          WHEN (    
            @PARAM_CALC_TO_LASTPAYMENT = 0    
            AND A.ICC = '6'    
            AND @V_COUNTER_PAY = 1    
            )    
           THEN CASE     
             WHEN PY1.COMPONENT_TYPE = '1'    
              THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
             WHEN PY2.COMPONENT_TYPE = '2'    
              THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
             WHEN PY3.COMPONENT_TYPE = '3'    
              THEN DATEDIFF(DAY, A.PMTDATE, A.NEXT_PMTDATE)    
             ELSE 0    
      END    
          ELSE CASE     
            WHEN PY1.COMPONENT_TYPE = '1'    
             THEN ISNULL(PY1.INCREMENTS, 1) * 30    
            WHEN PY2.COMPONENT_TYPE = '2'    
             THEN ISNULL(PY2.INCREMENTS, 1) * 30    
            WHEN PY3.COMPONENT_TYPE = '3'    
             THEN ISNULL(PY3.INCREMENTS, 1) * 30    
            ELSE 0    
            END    
          END    
         --------- END ADD YAHYA    
       ELSE 0 -- NOT IN 1,2,6    
       END    
     END AS I_DAYS    
    ,@V_COUNTER_PAY AS COUNTER    
    ,CASE     
     WHEN PY1.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY1.DATE_END    
      THEN B.MIN_DATE    
     WHEN PY2.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY2.DATE_END    
      THEN B.MIN_DATE    
     WHEN PY3.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY3.DATE_END    
      THEN B.MIN_DATE    
     WHEN PY4.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY4.DATE_END    
      THEN B.MIN_DATE    
     WHEN PY5.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY5.DATE_END    
      THEN B.MIN_DATE    
     ELSE A.DATE_START    
     END DATE_START    
    ,A.DATE_END    
    ,A.TENOR    
    ,A.PAYMENT_CODE    
    ,A.ICC    
    ,CASE     
     WHEN PY1.COMPONENT_TYPE = '1'    
      THEN CASE     
        WHEN PY1.FREQUENCY = 'N'    
         THEN EOMONTH(DATEADD(MONTH, (PY1.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START))    
        ELSE CASE     
          ---START ADD YAHYA ---     
          WHEN PY1.DATE_END IS NOT NULL    
           AND A.NEXT_PMTDATE = PY1.DATE_END    
           THEN B.MIN_DATE --- ADD YAHYA    
          WHEN ISDATE(CONCAT (    
             CONVERT(VARCHAR(6), DATEADD(MONTH, (PY1.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
             ,PY1.PMT_DATE    
             )) = 1    
           THEN CONVERT(DATE, CONCAT (    
              CONVERT(VARCHAR(6), DATEADD(MONTH, (PY1.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
              ,PY1.PMT_DATE    
              ))    
          ELSE DATEADD(MONTH, (PY1.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START)    
           ---END ADD YAHYA----    
          END    
        END    
     WHEN PY2.COMPONENT_TYPE = '2'    
      THEN CASE     
        WHEN PY2.FREQUENCY = 'N'    
         THEN EOMONTH(DATEADD(MONTH, (PY2.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START))    
        ELSE CASE     
          ---START ADD YAHYA ---     
          WHEN PY2.DATE_END IS NOT NULL    
           AND A.NEXT_PMTDATE = PY2.DATE_END    
           THEN B.MIN_DATE    
          WHEN ISDATE(CONCAT (    
             CONVERT(VARCHAR(6), DATEADD(MONTH, (PY2.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
             ,PY2.PMT_DATE    
             )) = 1    
           THEN CONVERT(DATE, CONCAT (    
              CONVERT(VARCHAR(6), DATEADD(MONTH, (PY2.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
              ,PY2.PMT_DATE    
              ))    
          ELSE DATEADD(MONTH, (PY2.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START)    
           ---END ADD YAHYA----    
          END    
        END    
     WHEN PY3.COMPONENT_TYPE = '3'    
      THEN CASE     
        WHEN PY3.FREQUENCY = 'N'    
         THEN EOMONTH(DATEADD(MONTH, (PY3.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START))    
        ELSE CASE     
          ---START ADD YAHYA ---    
          WHEN PY3.DATE_END IS NOT NULL    
           AND A.NEXT_PMTDATE = PY3.DATE_END    
           THEN B.MIN_DATE    
          WHEN ISDATE(CONCAT (    
             CONVERT(VARCHAR(6), DATEADD(MONTH, (PY3.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
             ,PY3.PMT_DATE    
             )) = 1    
           THEN CONVERT(DATE, CONCAT (    
              CONVERT(VARCHAR(6), DATEADD(MONTH, (PY3.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
              ,PY3.PMT_DATE    
              ))    
          ELSE DATEADD(MONTH, (PY3.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START)    
           ---END ADD YAHYA----    
          END    
        END    
     WHEN PY4.COMPONENT_TYPE = '4'    
      THEN CASE     
        WHEN PY4.FREQUENCY = 'N'    
         THEN EOMONTH(DATEADD(MONTH, (PY4.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START))    
        ELSE CASE     
          ---START ADD YAHYA ---    
          WHEN PY4.DATE_END IS NOT NULL    
           AND A.NEXT_PMTDATE = PY4.DATE_END    
           THEN B.MIN_DATE    
          WHEN ISDATE(CONCAT (    
             CONVERT(VARCHAR(6), DATEADD(MONTH, (PY4.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
             ,PY4.PMT_DATE    
             )) = 1    
           THEN CONVERT(DATE, CONCAT (    
              CONVERT(VARCHAR(6), DATEADD(MONTH, (PY4.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
              ,PY4.PMT_DATE    
              ))    
          ELSE DATEADD(MONTH, (PY4.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START)    
           ---END ADD YAHYA----    
          END    
        END    
     WHEN PY0.COMPONENT_TYPE = '0'    
      THEN CASE     
        WHEN PY0.FREQUENCY = 'N'    
         THEN EOMONTH(DATEADD(MONTH, (PY0.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START))    
        ELSE CASE     
          ---START ADD YAHYA ---    
          WHEN PY0.DATE_END IS NOT NULL    
           AND A.NEXT_PMTDATE = PY0.DATE_END    
           THEN B.MIN_DATE    
          WHEN ISDATE(CONCAT (    
             CONVERT(VARCHAR(6), DATEADD(MONTH, (PY0.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
             ,PY0.PMT_DATE    
             )) = 1    
           THEN CONVERT(DATE, CONCAT (    
              CONVERT(VARCHAR(6), DATEADD(MONTH, (PY0.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START), 112)    
              ,PY0.PMT_DATE    
              ))    
          ELSE DATEADD(MONTH, (PY0.INCREMENTS * A.NEXT_COUNTER_PAY), A.DATE_START)    
           ---END ADD YAHYA----    
          END    
        END    
     ELSE A.DATE_END ----ADD YAHYA    
     END    
    ,CASE     
     WHEN PY1.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY1.DATE_END    
      THEN 0    
     WHEN PY2.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY2.DATE_END    
      THEN 0    
     WHEN PY3.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY3.DATE_END    
      THEN 0    
     WHEN PY4.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY4.DATE_END    
      THEN 0    
     WHEN PY5.DATE_END IS NOT NULL    
      AND A.NEXT_PMTDATE = PY5.DATE_END    
      THEN 0    
     ELSE A.NEXT_COUNTER_PAY    
     END NEXT_COUNTER_PAY    
    ,A.SCH_FLAG    
    ,A.GRACE_DATE --BIBD FOR GRACE PERIOD    
    /*  BCA DISABLE BPI ,A.SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
   FROM TMP_SCHEDULE_CURR A    
   LEFT JOIN @TMP_MIN_MAX_DATE B ON A.MASTERID = B.ACCOUNT_NUMBER ---ADD YAHYA    
   LEFT JOIN TMP_PY0 PY0 ON A.MASTERID = PY0.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY0.DATE_START    
     AND PY0.DATE_END    
    AND DATEDIFF(MONTH, PY0.DATE_START, A.NEXT_PMTDATE) % PY0.INCREMENTS = 0    
   LEFT JOIN TMP_PY1 PY1 ON A.MASTERID = PY1.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY1.DATE_START    
     AND PY1.DATE_END    
    AND DATEDIFF(MONTH, PY1.DATE_START, A.NEXT_PMTDATE) % PY1.INCREMENTS = 0    
   LEFT JOIN TMP_PY2 PY2 ON A.MASTERID = PY2.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY2.DATE_START    
     AND PY2.DATE_END    
    AND DATEDIFF(MONTH, PY2.DATE_START, A.NEXT_PMTDATE) % PY2.INCREMENTS = 0    
   LEFT JOIN TMP_PY3 PY3 ON A.MASTERID = PY3.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY3.DATE_START    
     AND PY3.DATE_END    
    AND DATEDIFF(MONTH, PY3.DATE_START, A.NEXT_PMTDATE) % PY3.INCREMENTS = 0    
   LEFT JOIN TMP_PY4 PY4 ON A.MASTERID = PY4.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY4.DATE_START    
     AND PY4.DATE_END    
    AND DATEDIFF(MONTH, PY4.DATE_START, A.NEXT_PMTDATE) % PY4.INCREMENTS = 0    
   LEFT JOIN TMP_PY5 PY5 ON A.MASTERID = PY5.MASTERID    
    AND A.NEXT_PMTDATE BETWEEN PY5.DATE_START    
     AND PY5.DATE_END    
    AND DATEDIFF(MONTH, PY5.DATE_START, A.NEXT_PMTDATE) % PY5.INCREMENTS = 0    
   WHERE A.TENOR >= @V_COUNTER_PAY    
    AND A.PMTDATE <= A.DATE_END    
    AND A.OSPRN > 0;    
    
   INSERT INTO TMP_SCHEDULE_PREV_MTM_HIST    
   SELECT *    
   FROM TMP_SCHEDULE_PREV;    
    
   --COMMIT;    
   TRUNCATE TABLE TMP_SCHEDULE_CURR;    
    
   INSERT INTO TMP_SCHEDULE_CURR (    
    MASTERID    
    ,ACCOUNT_NUMBER    
    ,INTEREST_RATE    
    ,PMTDATE    
    ,OSPRN    
    ,PRINCIPAL    
    ,INTEREST    
    ,DISB_PERCENTAGE    
    ,DISB_AMOUNT    
    ,PLAFOND    
    ,I_DAYS    
    ,COUNTER    
    ,DATE_START    
    ,DATE_END    
    ,TENOR    
    ,PAYMENT_CODE    
    ,ICC    
    ,NEXT_PMTDATE    
    ,NEXT_COUNTER_PAY    
    ,SCH_FLAG    
    ,GRACE_DATE    
    ) --BIBD FOR GRACE PERIOD    
   /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
   SELECT A.MASTERID    
    ,A.ACCOUNT_NUMBER    
    ,A.INTEREST_RATE    
    ,A.PMTDATE    
    ,A.OSPRN    
    ,A.PRINCIPAL    
    ,A.INTEREST    
    ,A.DISB_PERCENTAGE    
    ,A.DISB_AMOUNT    
    ,A.PLAFOND    
    ,A.I_DAYS    
    ,A.COUNTER    
    ,A.DATE_START    
    ,A.DATE_END    
    ,A.TENOR    
    ,A.PAYMENT_CODE    
    ,A.ICC    
    ,CASE     
     WHEN A.NEXT_PMTDATE > A.DATE_END    
      THEN A.DATE_END ------ADD YAHYA 20180312    
     WHEN EOMONTH(A.NEXT_PMTDATE) = EOMONTH(A.DATE_END)    
      THEN A.DATE_END    
     ELSE A.NEXT_PMTDATE    
     END    
    ,A.NEXT_COUNTER_PAY + 1    
    ,A.SCH_FLAG    
    ,A.GRACE_DATE --BIBD FOR GRACE PERIOD    
    /*  BCA DISABLE BPI ,A.SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
   FROM TMP_SCHEDULE_PREV A;    
    
   INSERT INTO TMP_SCHEDULE_CURR_MTM_HIST    
   SELECT *    
   FROM TMP_SCHEDULE_CURR;    
    
   --COMMIT;    
   INSERT INTO IFRS_PAYM_SCHD_MTM (    
    MASTERID    
    --,ACCOUNT_NUMBER    
    ,PMTDATE    
    ,INTEREST_RATE    
    ,OSPRN    
    ,PRINCIPAL    
    ,INTEREST    
    ,DISB_PERCENTAGE    
    ,DISB_AMOUNT    
    ,PLAFOND    
    ,I_DAYS    
    ,ICC    
    ,COUNTER    
    ,DOWNLOAD_DATE    
    ,SCH_FLAG    
    ,GRACE_DATE --BIBD FOR GRACE PERIOD    
    /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
    )    
   SELECT MASTERID    
    --,ACCOUNT_NUMBER    
    ,PMTDATE    
    ,INTEREST_RATE    
    ,OSPRN    
    ,PRINCIPAL    
    ,INTEREST    
    ,DISB_PERCENTAGE    
    ,DISB_AMOUNT    
    ,PLAFOND    
    ,I_DAYS    
    ,ICC    
    ,COUNTER    
    ,@V_CURRDATE    
    ,SCH_FLAG    
    ,GRACE_DATE --BIBD FOR GRACE PERIOD    
    /*  BCA DISABLE BPI ,SPECIAL_FLAG --- BPI FLAG ONLY CTBC */    
   FROM TMP_SCHEDULE_CURR;    
  END    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,3    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,1    
   ,'PAYMENT SCHEDULE EXCEPTIONS'    
   );    
    
  --COMMIT;    
  TRUNCATE TABLE TMP_SCH_MAX;    
    
  TRUNCATE TABLE TMP_SCHD;    
    
  INSERT INTO TMP_SCH_MAX    
  SELECT MASTERID    
   ,MAX(PMTDATE) AS MAX_PMTDATE    
  FROM IFRS_PAYM_SCHD_MTM    
  GROUP BY MASTERID;    
    
  INSERT INTO TMP_SCHD    
  SELECT A.MASTERID    
   ,A.OSPRN    
  FROM IFRS_PAYM_SCHD_MTM A    
  INNER JOIN TMP_SCH_MAX B ON A.MASTERID = B.MASTERID    
   AND A.PMTDATE = B.MAX_PMTDATE;    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,3    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,2    
   ,'INSERT IFRS_EXCEPTION_DETAILS'    
   );    
    
  --COMMIT;    
  DELETE IFRS_EXCEPTION_DETAILS    
  WHERE DOWNLOAD_DATE = @V_CURRDATE    
   AND EXCEPTION_CODE = 'V-2';    
    
  --COMMIT;    
  INSERT INTO IFRS_EXCEPTION_DETAILS (    
   DOWNLOAD_DATE    
   ,DATA_SOURCE    
   ,PRD_CODE    
   ,ACCOUNT_NUMBER    
   ,MASTERID    
  ,PROCESS_ID    
   ,EXCEPTION_CODE    
   ,REMARKS    
   )    
  SELECT PMA.DOWNLOAD_DATE    
   ,PMA.DATA_SOURCE    
   ,PMA.PRODUCT_CODE    
   ,PMA.ACCOUNT_NUMBER    
   ,PMA.MASTERID    
   ,'IFRS EXCEPTIONS' AS PROCESS_ID    
   ,'V-2' AS EXCEPTION_CODE    
   ,'SCHEDULE : LAST OSPRN SCHEDULE <> 0 ' AS REMARKS    
  FROM IFRS_MASTER_ACCOUNT PMA    
  INNER JOIN TMP_SCHD SCH ON PMA.MASTERID = SCH.MASTERID    
   AND PMA.DOWNLOAD_DATE = @V_CURRDATE    
   --AND PMA.PMT_SCH_STATUS = 'Y'    
   AND ISNULL(SCH.OSPRN, 0) <> 0;    
    
  --COMMIT;    
  -- EXCEPTIONS IF THERE IS PMTDATE IS NULL    
  TRUNCATE TABLE TMP_SCHD;    
    
  INSERT INTO TMP_SCHD (MASTERID)    
  SELECT MASTERID    
  FROM IFRS_PAYM_SCHD_MTM    
  WHERE PMTDATE IS NULL    
    
  INSERT INTO IFRS_EXCEPTION_DETAILS (    
   DOWNLOAD_DATE    
   ,DATA_SOURCE    
   ,PRD_CODE    
   ,ACCOUNT_NUMBER    
   ,MASTERID    
   ,PROCESS_ID    
   ,EXCEPTION_CODE    
   ,REMARKS    
   )    
  SELECT PMA.DOWNLOAD_DATE    
   ,PMA.DATA_SOURCE    
   ,PMA.PRODUCT_CODE    
   ,PMA.ACCOUNT_NUMBER    
   ,PMA.MASTERID    
   ,'IFRS EXCEPTIONS' AS PROCESS_ID    
   ,'V-2' AS EXCEPTION_CODE    
   ,'PMTDATE : IS NULL' AS REMARKS    
  FROM IFRS_MASTER_ACCOUNT PMA    
  INNER JOIN TMP_SCHD SCH ON PMA.MASTERID = SCH.MASTERID    
   AND PMA.DOWNLOAD_DATE = @V_CURRDATE;    
    
  TRUNCATE TABLE TMP_SCHD;    
    
  INSERT INTO TMP_SCHD (MASTERID)    
  SELECT DISTINCT MASTERID    
  FROM (    
   SELECT MASTERID    
    ,PMTDATE    
   FROM IFRS_PAYM_SCHD_MTM    
   GROUP BY MASTERID    
    ,PMTDATE    
   HAVING COUNT(1) > 1    
   ) A    
    
  INSERT INTO IFRS_EXCEPTION_DETAILS (    
   DOWNLOAD_DATE    
   ,DATA_SOURCE    
   ,PRD_CODE    
   ,ACCOUNT_NUMBER    
   ,MASTERID    
   ,PROCESS_ID    
   ,EXCEPTION_CODE    
   ,REMARKS    
   )    
  SELECT PMA.DOWNLOAD_DATE    
   ,PMA.DATA_SOURCE    
   ,PMA.PRODUCT_CODE    
   ,PMA.ACCOUNT_NUMBER    
   ,PMA.MASTERID    
   ,'IFRS EXCEPTIONS' AS PROCESS_ID    
   ,'V-2' AS EXCEPTION_CODE    
   ,'PMTDATE : DOUBLE ' AS REMARKS    
  FROM IFRS_MASTER_ACCOUNT PMA    
  INNER JOIN TMP_SCHD SCH ON PMA.MASTERID = SCH.MASTERID    
    
  --START 20160331 PRE-PAYMENT, LATE-PAYMENT, RESTRUCTURE WITH NO CHANGE EIR    
  UPDATE X    
  SET X.PV_CF = (X.PRINCIPAL + X.INTEREST) / POWER((1 + Z.MARKET_RATE / 12 / 100), X.COUNTER)    
  FROM IFRS_PAYM_SCHD_MTM X    
  INNER JOIN IFRS_IMA_AMORT_CURR Z ON X.MASTERID = Z.MASTERID    
  WHERE Z.DOWNLOAD_DATE = @V_CURRDATE    
    
  DELETE IFRS_EIR_ADJUSTMENT    
  WHERE DOWNLOAD_DATE = @V_CURRDATE;    
    
  INSERT INTO IFRS_EIR_ADJUSTMENT (    
   DOWNLOAD_DATE    
   ,MASTERID    
   ,ACCOUNT_NUMBER    
   ,IFRS9_CLASS    
   ,LOAN_START_DATE    
   ,LOAN_DUE_DATE    
   ,OUTSTANDING    
   ,INTEREST_RATE    
   ,EIR    
   ,MARKET_RATE    
   ,FAIR_VALUE_AMT    
   ,TOTAL_PV_CF    
   ,--GANTI NAMA    
   TOT_ADJUST --- TOTAL_PV_CF - ISNULL(FAIRVALUEAMT, OUTSTANDING)    
   )    
  SELECT A.DOWNLOAD_DATE    
   ,A.MASTERID    
   ,A.ACCOUNT_NUMBER    
   ,A.IFRS9_CLASS    
   ,A.LOAN_START_DATE    
   ,A.LOAN_DUE_DATE    
   ,A.OUTSTANDING    
   ,A.INTEREST_RATE    
   ,A.EIR    
   ,A.MARKET_RATE    
   ,A.FAIR_VALUE_AMOUNT    
   ,B.TOTAL_PV_CF AS TOTAL_PV_CF    
   ,(B.TOTAL_PV_CF - COALESCE(A.FAIR_VALUE_AMOUNT, A.OUTSTANDING)) AS TOT_ADJUST    
  FROM IFRS_IMA_AMORT_CURR A    
  INNER JOIN (    
   SELECT X.MASTERID    
    ,MIN(X.PMTDATE) AS MIN_PMTDATE    
    ,MAX(X.PMTDATE) AS MAX_PMTDATE    
    ,SUM(X.PRINCIPAL + X.INTEREST) AS TOT_INSTALMENT    
    ,SUM((X.PRINCIPAL + X.INTEREST) / POWER((1 + Z.MARKET_RATE / 12 / 100), X.COUNTER)) AS TOTAL_PV_CF    
   FROM IFRS_PAYM_SCHD_MTM X    
   INNER JOIN IFRS_IMA_AMORT_CURR Z ON X.MASTERID = Z.MASTERID    
   WHERE Z.DOWNLOAD_DATE = @V_CURRDATE    
   GROUP BY X.MASTERID    
   ) B ON A.MASTERID = B.MASTERID    
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE    
   AND A.IFRS9_CLASS IN (    
    'FVTPL'    
    ,'FVOCI'    
    ) --IFRS_CLASS    
   AND A.ACCOUNT_STATUS = 'A'    
    
  --END 20160331 PRE-PAYMENT, LATE-PAYMENT, RESTRUCTURE    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,4    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE_MTM'    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,1    
   ,'MARKET TO MARKET'    
   );    
    
  INSERT INTO IFRS_BATCH_LOG_DETAILS (    
   DOWNLOAD_DATE    
   ,BATCH_ID    
   ,BATCH_ID_HEADER    
   ,BATCH_NAME    
   ,PROCESS_NAME    
   ,START_DATE    
   ,END_DATE    
   ,CREATEDBY    
   ,COUNTER    
   ,REMARKS    
   )    
  VALUES (    
   @V_CURRDATE    
   ,99    
   ,@V_LOG_ID    
   ,'PMTSCHD'    
   ,'SP_IFRS_PAYMENT_SCHEDULE'    
   ,GETDATE()    
   ,GETDATE()    
   ,'IFRS ENGINE'    
   ,99    
   ,'JUST ENDED'    
   );    
   --COMMIT; --=========    
 END    
 */    
END;    
GO
