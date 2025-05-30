USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_SL_MAIN_PROC]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
      
CREATE PROCEDURE [dbo].[SP_IFRS_LI_SL_MAIN_PROC]      
AS      
BEGIN      
 DECLARE @CURRDATE DATE      
  ,@PREVDATE DATE      
      
 SELECT @CURRDATE = CURRDATE      
  ,@PREVDATE = PREVDATE      
 FROM IFRS_LI_PRC_DATE_AMORT      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'START'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,''      
  )      
      
 DELETE IFRS_LI_ACF_SL_MSTR      
 WHERE EFFDATE >= @CURRDATE      
      
 DELETE IFRS_LI_ACF_SL_MSTR_REV      
 WHERE EFFDATE >= @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'CLEAN UP DONE'      
  )      
      
 INSERT IFRS_LI_ACF_SL_MSTR (      
  EFFDATE      
  ,ACCOUNT_NUMBER      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,ORIGINAL_VALUE_ORG      
  ,ORIGINAL_VALUE      
  ,DRCR      
  ,IFRS_STATUS      
  ,EXCHANGE_RATE --,          
  --BRCODE          
  )      
 SELECT @CURRDATE      
  ,ACCOUNT_NUMBER      
  ,A.TRX_CODE      
  ,A.CCY      
  ,A.PRD_TYPE      
  ,@CURRDATE      
  ,      
  --  LEFT(B.IFRS_TXN_CLASS,1),          
  --  CASE WHEN B.SL_EXP_LIFE IS NOT NULL THEN DATEADD(MM,B.SL_EXP_LIFE, @CURRDATE) ELSE NULL END,          
  /*          
  CASE WHEN LEFT(B.IFRS_TXN_CLASS,1) = 'F' AND A.DEBET_CREDIT_FLAG = 'C' THEN -A.ORG_CCY_AMT           
       WHEN LEFT(B.IFRS_TXN_CLASS,1) = 'C' AND A.DEBET_CREDIT_FLAG = 'D' THEN A.ORG_CCY_AMT           
  ELSE -A.ORG_CCY_AMT END,          
  CASE WHEN LEFT(B.IFRS_TXN_CLASS,1) = 'F' AND A.DEBET_CREDIT_FLAG = 'C' THEN -A.EQV_LCY_AMT           
       WHEN LEFT(B.IFRS_TXN_CLASS,1) = 'C' AND A.DEBET_CREDIT_FLAG = 'D' THEN A.EQV_LCY_AMT           
  ELSE -A.EQV_LCY_AMT END,          
*/      
  A.ORG_CCY_AMT      
  ,A.EQV_LCY_AMT      
  ,A.DEBET_CREDIT_FLAG      
  ,'ACT'      
  ,ORG_CCY_AMT / EQV_LCY_AMT      
 /*,          
  A.BRANCH_CODE*/      
 FROM IFRS_LI_TRANSACTION_DAILY A      
 WHERE TRX_CODE IN (      
   SELECT DISTINCT TRX_CODE      
   FROM (      
    SELECT DISTINCT TRX_CODE      
    FROM IFRS_LI_TRANSACTION_PARAM      
    WHERE AMORT_TYPE = 'SL'      
    ) A      
   LEFT JOIN (      
    SELECT DISTINCT TRX_CODE AS TRX_CODE_EIR      
    FROM IFRS_LI_TRANSACTION_PARAM      
    WHERE AMORT_TYPE = 'EIR'      
    ) B ON A.TRX_CODE = B.TRX_CODE_EIR      
   WHERE B.TRX_CODE_EIR IS NULL      
   )      
  AND DOWNLOAD_DATE = @CURRDATE      
      
 UPDATE A      
 SET A.PRD_CODE = B.PRODUCT_CODE      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.EFFDATE = B.DOWNLOAD_DATE      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
 WHERE A.EFFDATE = @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'INS 1 DONE'      
  )      
      
 INSERT IFRS_LI_ACF_SL_MSTR (      
  EFFDATE      
  ,ACCOUNT_NUMBER      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,ORIGINAL_VALUE_ORG      
  ,ORIGINAL_VALUE      
  ,DRCR      
  ,IFRS_STATUS      
  ,EXCHANGE_RATE --,          
  --BRCODE          
  )      
 SELECT @CURRDATE      
  ,ACCOUNT_NUMBER      
  ,A.TRX_CODE      
  ,A.CCY      
  ,A.PRD_TYPE      
  ,@CURRDATE      
  ,A.ORG_CCY_AMT      
  ,A.EQV_LCY_AMT      
  ,A.DEBET_CREDIT_FLAG      
  ,'ACT'      
  ,ORG_CCY_AMT / EQV_LCY_AMT      
 FROM IFRS_LI_TRANSACTION_DAILY A      
 JOIN IFRS_LI_TRANSACTION_PARAM B ON A.TRX_CODE = B.TRX_CODE      
  AND (      
   A.PRD_CODE = B.PRD_CODE      
   OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL'      
   )      
  AND AMORT_TYPE = 'SL'      
 WHERE A.TRX_CODE IN (      
   SELECT DISTINCT TRX_CODE      
   FROM (      
    SELECT DISTINCT TRX_CODE      
    FROM IFRS_LI_TRANSACTION_PARAM      
    WHERE AMORT_TYPE = 'SL'      
    ) A      
   JOIN (      
    SELECT DISTINCT TRX_CODE AS TRX_CODE_EIR      
    FROM IFRS_LI_TRANSACTION_PARAM      
    WHERE AMORT_TYPE = 'EIR'      
    ) B ON A.TRX_CODE = B.TRX_CODE_EIR      
   )      
  AND DOWNLOAD_DATE = @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'INS 2 DONE'      
  )      
      
 UPDATE A      
 SET A.FLAG_CF = LEFT(B.IFRS_TXN_CLASS, 1)      
  ,A.END_AMORT_DATE = CASE       
   WHEN B.SL_EXP_LIFE IS NOT NULL      
    THEN DATEADD(DD, - 1, DATEADD(MM, B.SL_EXP_LIFE, START_AMORT_DATE))      
   ELSE NULL      
   END      
  ,A.ORIGINAL_VALUE = CASE       
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'F'      
    AND A.DRCR = 'C'      
    THEN - A.ORIGINAL_VALUE      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'C'      
    AND A.DRCR = 'D'      
    THEN A.ORIGINAL_VALUE      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'F'      
    AND A.DRCR = 'D'      
    THEN A.ORIGINAL_VALUE      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'C'      
    AND A.DRCR = 'C'      
    THEN - A.ORIGINAL_VALUE      
   END      
  ,A.ORIGINAL_VALUE_ORG = CASE       
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'F'      
    AND A.DRCR = 'C'      
    THEN - A.ORIGINAL_VALUE_ORG      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'C'      
    AND A.DRCR = 'D'      
    THEN A.ORIGINAL_VALUE_ORG      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'F'      
    AND A.DRCR = 'D'      
    THEN A.ORIGINAL_VALUE_ORG      
   WHEN LEFT(B.IFRS_TXN_CLASS, 1) = 'C'      
    AND A.DRCR = 'C'      
    THEN - A.ORIGINAL_VALUE_ORG      
   END      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_TRANSACTION_PARAM B ON (      
   A.PRD_CODE = B.PRD_CODE      
   OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL'      
   )      
  AND A.TRX_CODE = B.TRX_CODE      
 WHERE A.EFFDATE = @CURRDATE      
      
 ----          
 UPDATE A      
 SET A.MASTERID = B.MASTERID      
  ,A.END_AMORT_DATE = ISNULL(A.END_AMORT_DATE, B.LOAN_DUE_DATE)      
  ,A.CIFNO = B.CUSTOMER_NUMBER      
  ,A.FACNO = B.FACILITY_NUMBER      
  ,A.DATA_SOURCE = B.DATA_SOURCE      
  ,A.PRD_CODE = B.PRODUCT_CODE      
  ,A.BRCODE = B.BRANCH_CODE      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.EFFDATE = B.DOWNLOAD_DATE      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
 WHERE A.EFFDATE = @CURRDATE      
      
 UPDATE A      
 SET A.EXCHANGE_RATE = B.EXCHANGE_RATE      
  ,A.ORIGINAL_VALUE = A.ORIGINAL_VALUE_ORG * B.EXCHANGE_RATE      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.EFFDATE = B.DOWNLOAD_DATE      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
 WHERE A.EFFDATE = @CURRDATE      
  AND A.EXCHANGE_RATE IS NULL      
      
 UPDATE A      
 SET A.SL_AMORT_DAILY = (A.ORIGINAL_VALUE_ORG / (DATEDIFF(DAY, A.START_AMORT_DATE, A.END_AMORT_DATE) + 1)) * - 1      
 FROM IFRS_LI_ACF_SL_MSTR A      
 WHERE A.EFFDATE = @CURRDATE      
  AND IFRS_STATUS = 'ACT'      
  AND SL_AMORT_DAILY IS NULL      
      
 UPDATE A      
 SET A.MASTERID = B.MASTERID      
  ,A.END_AMORT_DATE = ISNULL(A.END_AMORT_DATE, B.LOAN_DUE_DATE)      
  ,A.CIFNO = B.CUSTOMER_NUMBER      
  ,A.FACNO = B.FACILITY_NUMBER      
  ,A.DATA_SOURCE = B.DATA_SOURCE      
  ,A.PRD_CODE = B.PRODUCT_CODE      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.EFFDATE = B.DOWNLOAD_DATE      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
  AND A.START_AMORT_DATE = B.LOAN_START_DATE      
 WHERE A.EFFDATE = @CURRDATE      
      
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET IFRS_STATUS = 'FRZ'      
 WHERE MASTERID IS NULL      
  AND EFFDATE = @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'UPDATE DONE'      
  )      
      
 ---------CAPTURE REVERSAL          
 INSERT IFRS_LI_ACF_SL_MSTR_REV (      
  MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,EFFDATE      
  ,ACCOUNT_NUMBER      
  ,BRCODE      
  ,CIFNO      
  ,FACNO      
  ,DATA_SOURCE      
  ,DRCR      
  )      
 SELECT MASTERID      
  ,TRX_CODE     
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,EFFDATE      
  ,ACCOUNT_NUMBER      
  ,BRCODE      
  ,CIFNO      
  ,FACNO      
  ,DATA_SOURCE      
  ,DRCR      
 FROM IFRS_LI_ACF_SL_MSTR      
 WHERE EFFDATE = @CURRDATE      
  AND (      
   (      
    ORIGINAL_VALUE < 0      
    AND FLAG_CF = 'C'      
    )      
   OR (      
    ORIGINAL_VALUE > 0      
    AND FLAG_CF = 'F'      
    )      
   )      
      
 --FOR REVERSE IF MASTERID IS MISSING TAKE FROM PREVIOUS MASTERID          
 UPDATE A      
 SET A.MASTERID = B.MASTERID      
  ,A.END_AMORT_DATE = ISNULL(A.END_AMORT_DATE, B.LOAN_DUE_DATE)      
  ,A.CIFNO = B.CUSTOMER_NUMBER      
  ,A.FACNO = B.FACILITY_NUMBER      
  ,A.DATA_SOURCE = B.DATA_SOURCE      
  ,A.PRD_CODE = B.PRODUCT_CODE      
  ,A.BRCODE = B.BRANCH_CODE      
 FROM IFRS_LI_ACF_SL_MSTR_REV A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.EFFDATE = @CURRDATE      
  AND B.DOWNLOAD_DATE = @PREVDATE      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
 WHERE A.EFFDATE = @CURRDATE      
  AND A.MASTERID IS NULL      
      
 UPDATE A      
 SET A.MASTERID = B.MASTERID      
 FROM IFRS_LI_ACF_SL_MSTR_REV A      
 JOIN IFRS_LI_ACF_SL_MSTR B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
  AND B.EFFDATE = @PREVDATE      
  AND A.ORIGINAL_VALUE = B.ORIGINAL_VALUE * - 1      
 WHERE A.EFFDATE = @CURRDATE      
  AND A.MASTERID IS NULL      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'REVERSE DONE'      
  )      
      
 DELETE IFRS_LI_ACF_SL_MSTR      
 WHERE EFFDATE = @CURRDATE      
  AND (      
   (      
    ORIGINAL_VALUE < 0      
    AND FLAG_CF = 'C'      
    )      
   OR (      
    ORIGINAL_VALUE > 0      
    AND FLAG_CF = 'F'      
    )      
   )      
      
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET IFRS_STATUS = 'PNL'      
 WHERE END_AMORT_DATE <= @CURRDATE      
  AND IFRS_STATUS = 'ACT'      
  AND EFFDATE = @CURRDATE      
      
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET IFRS_STATUS = 'PNL'      
 WHERE END_AMORT_DATE > @CURRDATE      
  AND IFRS_STATUS = 'ACT'      
  AND MASTERID IN (      
   SELECT DISTINCT MASTERID      
   FROM IFRS_LI_MASTER_ACCOUNT      
   WHERE DOWNLOAD_DATE = @CURRDATE      
    AND ACCOUNT_STATUS <> 'A'      
   )      
  AND EFFDATE = @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'UPDATE 2 DONE'      
  )      
      
 /*          
DELETE IFRS_LI_ACCT_COST_FEE          
WHERE CREATEDBY = 'SL PROCESS'          
  AND DOWNLOAD_DATE = @CURRDATE          
          
          
DELETE IFRS_LI_ACCT_COST_FEE          
WHERE CREATEDBY = 'SP_IFRS_LI_TRAN_DAILY'          
  AND DOWNLOAD_DATE = @CURRDATE          
  AND METHOD = 'SL'          
          
          
INSERT IFRS_LI_ACCT_COST_FEE          
(          
  DOWNLOAD_DATE,          
  CREATEDBY,          
  MASTERID,          
  BRCODE,          
  CCY,          
  TRX_CODE,          
  CIFNO,          
  FACNO,          
  ACCTNO,          
  DATASOURCE,          
  PRD_CODE,          
  FLAG_CF,          
  FLAG_REVERSE,          
  METHOD,          
  STATUS,          
  SRCPROCESS,          
  AMOUNT,          
  ORG_CCY,          
  ORG_CCY_EXRATE          
)          
SELECT           
  @CURRDATE,          
  'SL PROCESS',          
  MASTERID,          
  BRCODE,           
  CCY,          
  TRX_CODE,          
  CIFNO,          
  FACNO,          
  ACCOUNT_NUMBER,          
  DATA_SOURCE,          
  PRD_CODE,          
  FLAG_CF,          
  'N',          
  'SL',          
  IFRS_STATUS,          
  'SL PROCESS',          
  ORIGINAL_VALUE,          
  CCY,          
  EXCHANGE_RATE          
FROM IFRS_LI_ACF_SL_MSTR          
WHERE EFFDATE = @CURRDATE          
--AND START_AMORT_DATE = @CURRDATE          
*/      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
 ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'INS ACCT COST FEE DONE'      
  )      
      
 INSERT IFRS_LI_ACF_SL_MSTR (      
  MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,IFRS_STATUS      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,EFFDATE      
  ,ACCOUNT_NUMBER      
  ,DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,BRCODE      
  ,DRCR      
  )      
 SELECT MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,IFRS_STATUS      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,@CURRDATE      
  ,ACCOUNT_NUMBER      
  ,DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,BRCODE      
  ,DRCR      
 FROM IFRS_LI_ACF_SL_MSTR      
 WHERE EFFDATE = @PREVDATE      
  AND IFRS_STATUS = 'ACT'      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'INS SL MSTR PREVDATE DONE'      
  )      
      
 --REVERSE          
 --MARK THE ACF_SL_MSTR FIRST          
 CREATE TABLE #REV_LS (      
  ACCOUNT_NUMBER VARCHAR(60)      
  ,TRX_CODE VARCHAR(15)      
  ,FLAG_CF CHAR(1)      
  ,AMOUNT DECIMAL(32, 6)      
  ,ID BIGINT      
  ,CNT BIGINT      
  ,STAT VARCHAR(3)      
  )      
      
 INSERT #REV_LS      
 SELECT ACCOUNT_NUMBER      
  ,TRX_CODE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE_ORG      
  ,ID_SL      
  ,SUM(CNT) OVER (      
   PARTITION BY ACCOUNT_NUMBER      
   ,TRX_CODE      
   ,FLAG_CF      
   ,ORIGINAL_VALUE_ORG ORDER BY ID_SL      
   )      
  ,'NEW' AS STAT      
 FROM (      
  SELECT ACCOUNT_NUMBER      
   ,TRX_CODE      
   ,FLAG_CF      
   ,ORIGINAL_VALUE_ORG      
   ,ID_SL      
   ,1 AS CNT      
  FROM IFRS_LI_ACF_SL_MSTR_REV      
  WHERE EFFDATE = @CURRDATE      
  ) REV_CHECK      
      
 CREATE TABLE #CF_LS (      
  ACCOUNT_NUMBER VARCHAR(60)      
  ,TRX_CODE VARCHAR(15)      
  ,FLAG_CF CHAR(1)      
  ,AMOUNT DECIMAL(32, 6)      
  ,ID BIGINT      
  ,CNT BIGINT      
  ,STAT VARCHAR(3)      
  )      
      
 INSERT #CF_LS      
 SELECT ACCOUNT_NUMBER      
  ,TRX_CODE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE_ORG      
  ,ID_SL      
  ,SUM(CNT) OVER (      
   PARTITION BY ACCOUNT_NUMBER      
   ,TRX_CODE      
   ,FLAG_CF      
   ,ORIGINAL_VALUE_ORG ORDER BY ID_SL      
   )      
  ,'NEW' AS STAT      
 FROM (      
  SELECT A.ACCOUNT_NUMBER      
   ,A.TRX_CODE      
   ,A.FLAG_CF      
 ,ORIGINAL_VALUE_ORG      
   ,A.ID_SL      
   ,1 AS CNT      
  FROM IFRS_LI_ACF_SL_MSTR A      
  JOIN (      
   SELECT DISTINCT ACCOUNT_NUMBER      
    ,TRX_CODE      
    ,AMOUNT * - 1 AS AMT      
   FROM #REV_LS      
   ) B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
   AND A.TRX_CODE = B.TRX_CODE      
   AND A.ORIGINAL_VALUE_ORG = B.AMT      
  WHERE EFFDATE = @CURRDATE      
  ) REV_CF      
      
 UPDATE A      
 SET STAT = CASE       
   WHEN B.ACCOUNT_NUMBER IS NULL      
    THEN 'FRZ'      
   ELSE 'ACT'      
   END      
 FROM #REV_LS A      
 LEFT JOIN #CF_LS B ON A.CNT = B.CNT      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
  AND A.TRX_CODE = B.TRX_CODE      
  AND A.AMOUNT = B.AMOUNT * - 1      
  AND A.FLAG_CF = B.FLAG_CF      
      
 UPDATE A      
 SET STAT = CASE       
   WHEN B.ACCOUNT_NUMBER IS NULL      
    THEN 'FRZ'      
   ELSE 'ACT'      
   END      
 FROM #CF_LS A      
 LEFT JOIN #REV_LS B ON A.CNT = B.CNT      
  AND A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
  AND A.TRX_CODE = B.TRX_CODE      
  AND A.AMOUNT = B.AMOUNT * - 1      
  AND A.FLAG_CF = B.FLAG_CF      
      
 UPDATE A      
 SET A.IFRS_STATUS = CASE       
   WHEN B.STAT = 'ACT'      
    THEN 'REV'      
   ELSE 'ACT'      
   END      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN #CF_LS B ON A.ID_SL = B.ID      
 WHERE A.EFFDATE = @CURRDATE      
      
 UPDATE A      
 SET A.IFRS_STATUS = B.STAT      
 FROM IFRS_LI_ACF_SL_MSTR_REV A      
 JOIN #REV_LS B ON A.ID_SL = B.ID      
 WHERE A.EFFDATE = @CURRDATE      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'REVERSE 2 DONE'      
  )      
      
 DELETE IFRS_LI_ACCT_COST_FEE      
 WHERE CREATEDBY = 'SL PROC REV'      
  AND DOWNLOAD_DATE = @CURRDATE      
      
 ---COST FEE FOR REVERSE          
 INSERT IFRS_LI_ACCT_COST_FEE (      
  DOWNLOAD_DATE      
  ,CREATEDBY      
  ,MASTERID      
  ,BRCODE      
  ,CCY      
  ,TRX_CODE      
  ,CIFNO      
  ,FACNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRD_CODE      
  ,FLAG_CF      
  ,FLAG_REVERSE      
  ,METHOD      
  ,STATUS      
  ,SRCPROCESS      
  ,AMOUNT      
  ,ORG_CCY      
  ,ORG_CCY_EXRATE      
  )      
 SELECT @CURRDATE      
  ,'SL PROC REV'      
  ,MASTERID      
  ,BRCODE      
  ,CCY      
  ,TRX_CODE      
  ,CIFNO      
  ,FACNO      
  ,ACCOUNT_NUMBER      
  ,DATA_SOURCE      
  ,PRD_CODE      
  ,FLAG_CF      
  ,'Y'      
  ,'SL'      
  ,IFRS_STATUS      
  ,'SL PROCESS'      
  ,ORIGINAL_VALUE      
  ,CCY      
  ,EXCHANGE_RATE      
 FROM IFRS_LI_ACF_SL_MSTR_REV      
 WHERE EFFDATE = @CURRDATE      
      
 --AND START_AMORT_DATE = @CURRDATE          
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'REVERSE INS ACCT COST FEE DONE'      
  )      
      
 --CLOSE ACCOUNT          
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET CLOSING_AMOUNT = - ORIGINAL_VALUE      
  ,CLOSING_AMOUNT_ORG = - ORIGINAL_VALUE_ORG      
  ,UNAMORT_VALUE = 0      
  ,UNAMORT_VALUE_ORG = 0      
  ,AMORT_VALUE = - ORIGINAL_VALUE      
  ,AMORT_VALUE_ORG = - ORIGINAL_VALUE_ORG      
  ,IFRS_STATUS = 'CLS'      
 WHERE END_AMORT_DATE <= @CURRDATE      
  AND IFRS_STATUS = 'ACT'      
  AND EFFDATE = @CURRDATE      
      
 --CLOSE ACCOUNT NOT IN IMA          
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET CLOSING_AMOUNT = - ORIGINAL_VALUE      
  ,CLOSING_AMOUNT_ORG = - ORIGINAL_VALUE_ORG      
  ,UNAMORT_VALUE = 0      
  ,UNAMORT_VALUE_ORG = 0      
  ,AMORT_VALUE = - ORIGINAL_VALUE      
  ,AMORT_VALUE_ORG = - ORIGINAL_VALUE_ORG      
  ,IFRS_STATUS = 'CLS'      
 WHERE MASTERID NOT IN (      
   SELECT MASTERID      
   FROM IFRS_LI_MASTER_ACCOUNT      
   WHERE DOWNLOAD_DATE = @CURRDATE      
   )      
  AND IFRS_STATUS = 'ACT'      
  AND EFFDATE = @CURRDATE      
      
 --CLOSE WHEN NOT ACTIVE          
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET CLOSING_AMOUNT = - ORIGINAL_VALUE      
  ,CLOSING_AMOUNT_ORG = - ORIGINAL_VALUE_ORG      
  ,UNAMORT_VALUE = 0      
  ,UNAMORT_VALUE_ORG = 0      
  ,AMORT_VALUE = - ORIGINAL_VALUE      
  ,AMORT_VALUE_ORG = - ORIGINAL_VALUE_ORG      
  ,IFRS_STATUS = 'CLS'      
 WHERE MASTERID IN (      
   SELECT MASTERID      
   FROM IFRS_LI_MASTER_ACCOUNT      
   WHERE DOWNLOAD_DATE = @CURRDATE      
    AND ACCOUNT_STATUS <> 'A'      
   )      
  AND IFRS_STATUS = 'ACT'      
  AND EFFDATE = @CURRDATE      
      
 UPDATE IFRS_LI_ACF_SL_MSTR      
 SET AMORT_VALUE = ROUND((ORIGINAL_VALUE / (DATEDIFF(DD, START_AMORT_DATE, END_AMORT_DATE) + 1)) * (DATEDIFF(DD, START_AMORT_DATE, @CURRDATE) + 1) * - 1, 2)      
  ,AMORT_VALUE_ORG = ROUND((ORIGINAL_VALUE_ORG / (DATEDIFF(DD, START_AMORT_DATE, END_AMORT_DATE) + 1)) * (DATEDIFF(DD, START_AMORT_DATE, @CURRDATE) + 1) * - 1, 2)      
  ,UNAMORT_VALUE = ORIGINAL_VALUE - ROUND(((ORIGINAL_VALUE / (DATEDIFF(DD, START_AMORT_DATE, END_AMORT_DATE) + 1)) * (DATEDIFF(DD, START_AMORT_DATE, @CURRDATE) + 1)), 2)      
  ,UNAMORT_VALUE_ORG = ORIGINAL_VALUE_ORG - ROUND(((ORIGINAL_VALUE_ORG / (DATEDIFF(DD, START_AMORT_DATE, END_AMORT_DATE) + 1)) * (DATEDIFF(DD, START_AMORT_DATE, @CURRDATE) + 1)), 2)      
 WHERE IFRS_STATUS = 'ACT'      
  AND EFFDATE = @CURRDATE      
      
 --DETECT MSSING ACC FOR SL IN IMA          
 SELECT DISTINCT MASTERID      
 INTO #IMA_LS      
 FROM IFRS_LI_ACF_SL_MSTR      
 WHERE EFFDATE = @CURRDATE      
  AND MASTERID NOT IN (      
   SELECT DISTINCT MASTERID      
   FROM IFRS_LI_MASTER_ACCOUNT      
   WHERE DOWNLOAD_DATE = @CURRDATE      
   )      
      
 /*          
SELECT * INTO #IMA FROM IFRS_LI_MASTER_ACCOUNT          
WHERE MASTERID IN (SELECT DISTINCT MASTERID FROM #IMA_LS)          
AND DOWNLOAD_DATE = @PREVDATE          
          
UPDATE #IMA          
SET ACCOUNT_STATUS = 'S',          
    DOWNLOAD_DATE = @CURRDATE,          
 OUTSTANDING = 0,          
-- OUTSTANDING_PROFIT = 0,          
 OUTSTANDING_PASTDUE = 0,          
 PLAFOND = 0          
          
DELETE IFRS_LI_MASTER_ACCOUNT          
WHERE DOWNLOAD_DATE = @CURRDATE          
AND ACCOUNT_STATUS = 'S'          
          
INSERT IFRS_LI_MASTER_ACCOUNT          
SELECT * FROM #IMA          
*/      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'CLOSE ACCT DONE'      
  )      
      
 /*          
UPDATE IFRS_LI_MASTER_ACCOUNT          
SET UNAMOR_ORIGINATION_FEE_AMT_SL = 0,          
    UNAMOR_TRANS_COST_AMT_SL = 0,          
 UNAMOR_AMT_TOTAL_SL = 0,          
 UNAMOR_ORG_FEE_AMT_SL_LCY = 0,          
 UNAMOR_TRANS_COST_AMT_SL_LCY = 0,          
 UNAMOR_AMT_TOTAL_SL_LCY = 0,          
 INITIAL_UNAMOR_FEE_SL_LCY = 0,          
 INITIAL_UNAMOR_COST_SL_LCY = 0,          
 INITIAL_UNAMOR_TOTAL_SL_LCY = 0,          
 INITIAL_UNAMOR_FEE_SL_ORG = 0,          
 INITIAL_UNAMOR_COST_SL_ORG = 0,          
 INITIAL_UNAMOR_TOTAL_SL_ORG = 0          
WHERE DOWNLOAD_DATE = @CURRDATE          
          
UPDATE A          
SET A.UNAMOR_ORIGINATION_FEE_AMT_SL = B.FEE,          
    A.UNAMOR_TRANS_COST_AMT_SL = B.COST,          
 A.UNAMOR_AMT_TOTAL_SL = B.FEE+B.COST,          
 A.UNAMOR_ORG_FEE_AMT_SL_LCY = B.FEE_LCY,          
 A.UNAMOR_TRANS_COST_AMT_SL_LCY = B.COST_LCY,          
 A.UNAMOR_AMT_TOTAL_SL_LCY = B.FEE_LCY+B.COST_LCY,          
 A.INITIAL_UNAMOR_FEE_SL_LCY = B.FEE_INI,          
 A.INITIAL_UNAMOR_COST_SL_LCY = B.COST_INI,          
 A.INITIAL_UNAMOR_TOTAL_SL_LCY = B.FEE_INI+B.COST_INI,          
 A.INITIAL_UNAMOR_FEE_SL_ORG = B.FEE_INI_ORG,          
 A.INITIAL_UNAMOR_COST_SL_ORG = B.COST_INI_ORG,          
 A.INITIAL_UNAMOR_TOTAL_SL_ORG = B.FEE_INI_ORG+B.COST_INI_ORG          
FROM IFRS_LI_MASTER_ACCOUNT A JOIN          
  (SELECT MASTERID, SUM(CASE WHEN FLAG_CF = 'F' THEN UNAMORT_VALUE_ORG ELSE 0 END) AS FEE,          
      SUM(CASE WHEN FLAG_CF = 'C' THEN UNAMORT_VALUE_ORG ELSE 0 END) AS COST,          
   SUM(CASE WHEN FLAG_CF = 'F' THEN UNAMORT_VALUE ELSE 0 END) AS FEE_LCY,          
      SUM(CASE WHEN FLAG_CF = 'C' THEN UNAMORT_VALUE ELSE 0 END) AS COST_LCY,          
   SUM(CASE WHEN FLAG_CF = 'F' THEN ORIGINAL_VALUE ELSE 0 END) AS FEE_INI,          
      SUM(CASE WHEN FLAG_CF = 'C' THEN ORIGINAL_VALUE ELSE 0 END) AS COST_INI,          
   SUM(CASE WHEN FLAG_CF = 'F' THEN ORIGINAL_VALUE_ORG ELSE 0 END) AS FEE_INI_ORG,          
      SUM(CASE WHEN FLAG_CF = 'C' THEN ORIGINAL_VALUE_ORG ELSE 0 END) AS COST_INI_ORG          
   FROM IFRS_LI_ACF_SL_MSTR WHERE EFFDATE = @CURRDATE AND IFRS_STATUS = 'ACT'          
   GROUP BY MASTERID) B           
 ON A.MASTERID = B.MASTERID          
WHERE A.DOWNLOAD_DATE = @CURRDATE          
          
  --INITIAL          
  UPDATE A          
  SET A.INITIAL_UNAMOR_FEE_SL_ORG = FEE_AMT_ORG,          
   A.INITIAL_UNAMOR_COST_SL_ORG = COST_AMT_ORG,          
   A.INITIAL_UNAMOR_FEE_SL_LCY = FEE_AMT_LCY,          
   A.INITIAL_UNAMOR_COST_SL_LCY = COST_AMT_LCY,          
   A.INITIAL_UNAMORT_TOTAL = FEE_AMT_ORG+COST_AMT_ORG,          
   A.INITIAL_UNAMOR_TOTAL_SL_ORG = FEE_AMT_LCY+COST_AMT_LCY          
  FROM IFRS_LI_MASTER_ACCOUNT A          
  JOIN (SELECT MASTERID,           
    SUM(CASE WHEN FLAG_CF = 'F' THEN AMOUNT ELSE 0 END) AS FEE_AMT_LCY,          
    SUM(CASE WHEN FLAG_CF = 'C' THEN AMOUNT ELSE 0 END) AS COST_AMT_LCY,          
    SUM(CASE WHEN FLAG_CF = 'F' THEN AMOUNT_ORG ELSE 0 END) AS FEE_AMT_ORG,          
    SUM(CASE WHEN FLAG_CF = 'C' THEN AMOUNT_ORG ELSE 0 END) AS COST_AMT_ORG          
 FROM IFRS_LI_ACCT_COST_FEE          
    WHERE EFFDATE <= @CURRDATE AND STATUS IN ('PNL','ACT') AND METHOD = 'SL'          
 GROUP BY MASTERID ) B ON A.MASTERID = B.MASTERID          
  WHERE A.DOWNLOAD_DATE = @CURRDATE          
  */      
 UPDATE A      
 SET A.SL_AMORT_DAILY = (A.ORIGINAL_VALUE_ORG / (DATEDIFF(DAY, A.START_AMORT_DATE, A.END_AMORT_DATE) + 1)) * - 1      
 FROM IFRS_LI_ACF_SL_MSTR A      
 WHERE A.EFFDATE = @CURRDATE      
  AND IFRS_STATUS = 'ACT'      
  AND SL_AMORT_DAILY IS NULL      
      
 --SL SWITCH          
 UPDATE A      
 SET IFRS_STATUS = 'SWC'      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_ACCT_SWITCH B ON A.ACCOUNT_NUMBER = B.PREV_ACCTNO      
  AND A.EFFDATE = B.DOWNLOAD_DATE      
 WHERE A.IFRS_STATUS = 'ACT'      
  AND A.EFFDATE = @CURRDATE      
      
 UPDATE A      
 SET IFRS_STATUS = 'SWC'      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_ACCT_SWITCH B ON A.ACCOUNT_NUMBER = B.ACCTNO      
  AND A.BRCODE = B.PREV_BRCODE      
  AND A.EFFDATE = B.DOWNLOAD_DATE      
 WHERE A.IFRS_STATUS = 'ACT'      
  AND A.EFFDATE = @CURRDATE      
      
 UPDATE A      
 SET IFRS_STATUS = 'SWC'      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_ACCT_SWITCH B ON A.ACCOUNT_NUMBER = B.ACCTNO      
  AND A.PRD_CODE = B.PREV_PRDCODE      
  AND A.EFFDATE = B.DOWNLOAD_DATE      
 WHERE A.IFRS_STATUS = 'ACT'      
  AND A.EFFDATE = @CURRDATE      
      
 INSERT IFRS_LI_ACF_SL_MSTR (      
  MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,IFRS_STATUS      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,EFFDATE      
  ,ACCOUNT_NUMBER      
  ,DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,BRCODE      
  ,DRCR      
  ,SL_AMORT_DAILY      
  )      
 SELECT A.MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,B.PRODUCT_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,'ACT'      
  ,ITRCG_FLAG      
  ,A.EXCHANGE_RATE      
  ,@CURRDATE      
  ,B.ACCOUNT_NUMBER      
  ,A.DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,B.BRANCH_CODE      
  ,DRCR      
  ,SL_AMORT_DAILY      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER      
  AND A.EFFDATE = B.DOWNLOAD_DATE      
 WHERE EFFDATE = @CURRDATE      
  AND IFRS_STATUS = 'SWC'      
      
 INSERT IFRS_LI_ACF_SL_MSTR (      
  MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,PRD_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,IFRS_STATUS      
  ,ITRCG_FLAG      
  ,EXCHANGE_RATE      
  ,EFFDATE      
  ,ACCOUNT_NUMBER      
  ,DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,BRCODE      
  ,DRCR      
  ,SL_AMORT_DAILY      
  )      
 SELECT A.MASTERID      
  ,TRX_CODE      
  ,CCY      
  ,B.PRODUCT_CODE      
  ,START_AMORT_DATE      
  ,END_AMORT_DATE      
  ,FLAG_CF      
  ,ORIGINAL_VALUE      
  ,ORIGINAL_VALUE_ORG      
  ,AMORT_VALUE      
  ,AMORT_VALUE_ORG      
  ,UNAMORT_VALUE      
  ,UNAMORT_VALUE_ORG      
  ,CLOSING_AMOUNT      
  ,CLOSING_AMOUNT_ORG      
  ,'ACT'      
  ,ITRCG_FLAG      
  ,A.EXCHANGE_RATE      
  ,@CURRDATE      
  ,B.ACCOUNT_NUMBER      
  ,A.DATA_SOURCE      
  ,FACNO      
  ,CIFNO      
  ,B.BRANCH_CODE      
  ,DRCR      
  ,SL_AMORT_DAILY      
 FROM IFRS_LI_ACF_SL_MSTR A      
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.ACCOUNT_NUMBER = B.PREVIOUS_ACCOUNT_NUMBER      
  AND A.EFFDATE = B.DOWNLOAD_DATE      
 WHERE EFFDATE = @CURRDATE      
  AND IFRS_STATUS = 'SWC'      
      
 --SL SWITCH          
 UPDATE A      
 SET A.UNAMORT_FEE_AMT = CASE       
   WHEN FLAG_CF = 'F'      
    THEN UNAMORT_VALUE_ORG      
   ELSE 0      
   END      
  ,A.UNAMORT_COST_AMT = CASE       
   WHEN FLAG_CF = 'C'      
    THEN UNAMORT_VALUE_ORG      
   ELSE 0      
   END      
 FROM IFRS_LI_MASTER_ACCOUNT A      
 JOIN IFRS_LI_ACF_SL_MSTR B ON A.MASTERID = B.MASTERID      
  AND A.DOWNLOAD_DATE = B.EFFDATE      
 WHERE A.DOWNLOAD_DATE = @CURRDATE      
  AND B.IFRS_STATUS = 'ACT'      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'DEBUG'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,'UPD IMA DONE'      
  )      
      
 DROP TABLE #REV_LS      
      
 DROP TABLE #CF_LS      
      
 INSERT INTO IFRS_LI_AMORT_LOG (      
  DOWNLOAD_DATE      
  ,DTM      
  ,OPS      
  ,PROCNAME      
  ,REMARK      
  )      
 VALUES (      
  @CURRDATE      
  ,CURRENT_TIMESTAMP      
  ,'END'      
  ,'SP_IFRS_LI_SL_MAIN_PROC'      
  ,''      
  )      
END 

GO
