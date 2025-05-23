USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_JOURNAL_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_JOURNAL_DATA]      
AS      
DECLARE @V_CURRDATE DATE      
 ,@V_PREVDATE DATE      
 ,@V_PREVMONTH DATE      
 ,@VMIN_NOREF BIGINT      
      
BEGIN      
 SELECT @V_CURRDATE = MAX(CURRDATE)      
  ,@V_PREVDATE = MAX(PREVDATE)      
 FROM IFRS_LI_PRC_DATE_AMORT      
      
 SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, - 1, @V_CURRDATE))      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,''      
  )      
 UPDATE IFRS_LI_ACCT_JOURNAL_INTM      
 SET METHOD = 'EIR'      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
  AND SUBSTRING(SOURCEPROCESS, 1, 3) = 'EIR'      
      
      
 -- JOURNAL INTM FLAG_AL FILL FROM IFRS_LI_IMA_AMORT_CURR          
 UPDATE DBO.IFRS_LI_ACCT_JOURNAL_INTM      
 SET FLAG_AL = 'L'               
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
-- JOURNAL INTM FLAG_AL FILL FROM IFRS_LI_IMA_AMORT_CURR       
           
 UPDATE A      
 SET N_AMOUNT_IDR = N_AMOUNT * ISNULL(CURR.RATE_AMOUNT, 1)          
 FROM DBO.IFRS_LI_ACCT_JOURNAL_INTM A      
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE CURR ON CURR.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.CCY = CURR.CURRENCY               
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
      
 --DELETE FIRST          
 DELETE      
 FROM IFRS_LI_ACCT_JOURNAL_DATA      
 WHERE DOWNLOAD_DATE >= @V_CURRDATE      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'CLEAN UP'      
  )      
      
 -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE             
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,CASE       
   WHEN (         
     A.REVERSE = 'N'      
     AND COALESCE(A.FLAG_AL, 'A') = 'A'      
     )      
    OR (      
     A.REVERSE = 'Y'      
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'      
     )      
    THEN CASE       
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'C'      
  AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      ELSE CASE       
        WHEN B.DRCR = 'D'      
         THEN 'C'      
        ELSE 'D'      
        END      
      END      
   ELSE CASE       
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
 WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     ELSE CASE       
       WHEN B.DRCR = 'D'      
        THEN 'C'      
       ELSE 'D'      
       END      
     END      
   END AS DRCR      
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,A.JOURNALCODE2      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE         
 FROM IFRS_LI_ACCT_JOURNAL_INTM A      
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'ITRCG'      
   ,'ITRCG1'      
   ,'ITRCG2'      
   )      
  AND A.JOURNALCODE2 = B.JOURNALCODE --IFRS9 FUNDING      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.JOURNALCODE = 'DEFA0'      
  AND A.TRXCODE <> 'BENEFIT'      
  AND A.METHOD = 'EIR'               
  AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')             
              
 --STAFF LOAN DEFA0          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE               
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,CASE       
   WHEN (      
     A.REVERSE = 'N'      
     AND COALESCE(A.FLAG_AL, 'A') = 'A'      
     )      
    OR (      
     A.REVERSE = 'Y'      
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'      
     )      
    THEN CASE       
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0               
  AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      ELSE CASE       
        WHEN B.DRCR = 'D'      
         THEN 'C'      
        ELSE 'D'      
        END      
      END      
   ELSE CASE       
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     ELSE CASE       
       WHEN B.DRCR = 'D'      
        THEN 'C'      
       ELSE 'D'      
       END      
     END      
   END AS DRCR      
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,B.JOURNALCODE      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE            
 FROM IFRS_LI_ACCT_JOURNAL_INTM A               
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'ITRCG'      
   ,'ITRCG1'      
   ,'ITRCG2'      
   ,'ITEMB'      
   )      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND COALESCE(B.FLAG_CF, '-') NOT IN (      
   'F'      
   ,'C'      
   )      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.JOURNALCODE = 'DEFA0'      
  AND A.TRXCODE = 'BENEFIT'      
  AND A.METHOD = 'EIR'           
  AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')          
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'ITRCG 2'      
  )      
      
 -- INSERT ACCRU AMORT DATA SOURCE CCY PRDCODE COMBINATION          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE            
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE              
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,CASE       
   WHEN (      
     A.REVERSE = 'N'      
     AND COALESCE(A.FLAG_AL, 'A') = 'A'      
     )      
    OR (      
     A.REVERSE = 'Y'      
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'      
     )      
    THEN CASE       
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      ELSE CASE       
        WHEN B.DRCR = 'D'      
         THEN 'C'      
        ELSE 'D'      
        END      
      END      
   ELSE CASE       
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
    ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     ELSE CASE       
       WHEN B.DRCR = 'D'      
        THEN 'C'      
       ELSE 'D'      
       END      
     END      
   END AS DRCR      
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_ACCT_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,A.JOURNALCODE2      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE            
 FROM IFRS_LI_ACCT_JOURNAL_INTM A      
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'ACCRU'      
   ,'EMPBE'      
   ,'EMACR'      
   )      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.JOURNALCODE IN (      
   'ACCRU'      
   ,'AMORT'      
   )      
  AND A.TRXCODE <> 'BENEFIT'      
  AND A.METHOD = 'EIR'      
      
      
  ---EARLY TERMINATE IFRS9      
  INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE        
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,B.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,B.DRCR      
  ,B.GLNO      
  ,ABS(COST_FEE_PREV.AMOUNT)      
  ,ABS(COST_FEE_PREV.AMOUNT) * IMC.EXCHANGE_RATE      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_ACCT_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,A.JOURNALCODE2      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,A.METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE                   
 FROM IFRS_LI_ACCT_EIR_COST_FEE_PREV AS COST_FEE_PREV             
 INNER JOIN VW_LI_LAST_EIR_CF_PREV C ON COST_FEE_PREV.MASTERID = C.MASTERID AND COST_FEE_PREV.SEQ = C.SEQ AND COST_FEE_PREV.DOWNLOAD_DATE = C.DOWNLOAD_DATE              
 LEFT JOIN IFRS_LI_ACCT_JOURNAL_INTM AS A ON A.MASTERID = COST_FEE_PREV.MASTERID AND A.DOWNLOAD_DATE = @V_CURRDATE AND A.TRXCODE <> 'BENEFIT' AND A.METHOD = 'EIR' AND REVERSE = 'N'      
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR  AS IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV  AS IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'OTHER'      
   )      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE COST_FEE_PREV.DOWNLOAD_DATE = @V_PREVDATE      
 AND COST_FEE_PREV.MASTERID IN       
 (      
   SELECT A.MASTERID FROM DBO.IFRS_LI_ACCT_COST_FEE AS A      
   JOIN DBO.IFRS_LI_STG_TRANSACTION_DAILY AS B   
   ON      
   A.TRX_REFF_NUMBER = B.TRANSACTION_REFERENCE_NUMBER      
   AND      
   B.DOWNLOAD_DATE = @V_CURRDATE      
   AND      
   B.TERMINATE_FLAG = 'Y'      
   WHERE       
   A.STATUS = 'ACT'      
 )      
 ---EARLY TERMINATE IFRS9       
      
 --STAFF LOAN ACCRU          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE             
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,CASE       
   WHEN (      
     A.REVERSE = 'N'      
     AND COALESCE(A.FLAG_AL, 'A') = 'A'      
     )      
    OR (      
     A.REVERSE = 'Y'      
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'      
     )      
    THEN CASE       
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN (      
        'ACCRU'      
        ,'AMORT'      
        )      
       THEN B.DRCR      
      WHEN A.N_AMOUNT <= 0      
       AND A.FLAG_CF = 'F'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      WHEN A.N_AMOUNT >= 0      
       AND A.FLAG_CF = 'C'      
       AND A.JOURNALCODE IN ('DEFA0')      
       THEN B.DRCR      
      ELSE CASE       
        WHEN B.DRCR = 'D'      
         THEN 'C'      
        ELSE 'D'      
 END      
      END      
   ELSE CASE       
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN (      
       'ACCRU'      
       ,'AMORT'      
       )      
      THEN B.DRCR      
     WHEN A.N_AMOUNT >= 0      
      AND A.FLAG_CF = 'F'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR         
     WHEN A.N_AMOUNT <= 0      
      AND A.FLAG_CF = 'C'      
      AND A.JOURNALCODE IN ('DEFA0')      
      THEN B.DRCR      
     ELSE CASE       
       WHEN B.DRCR = 'D'      
        THEN 'C'      
       ELSE 'D'      
       END      
     END      
   END AS DRCR      
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID              
  ,CURRENT_TIMESTAMP      
  ,'SP_ACCT_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,B.JOURNALCODE      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE
 FROM IFRS_LI_ACCT_JOURNAL_INTM A               
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'ACCRU'      
   ,'EMPBE'      
   ,'EMACR'      
   ,'EBCTE'      
   )      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND COALESCE(B.FLAG_CF, '-') NOT IN (      
   'F'      
   ,'C'      
   )      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.JOURNALCODE IN (      
   'ACCRU'      
   ,'AMORT'      
   )      
  AND A.TRXCODE = 'BENEFIT'      
  AND A.METHOD = 'EIR'      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'AMORT 2'      
  )      
      
 IF @V_CURRDATE = EOMONTH(@V_CURRDATE)      
 BEGIN          
  WITH IFRS_LI_EIR_ADJUSTMENT_TEMP      
  AS (      
   SELECT *      
    ,CASE       
     WHEN A.TOT_ADJUST >= 0      
      AND A.IFRS9_CLASS = 'FVTPL'      
      THEN 'FVTPLG'      
     WHEN A.TOT_ADJUST < 0      
      AND A.IFRS9_CLASS = 'FVTPL'      
      THEN 'FVTPLL'     
     WHEN A.TOT_ADJUST >= 0      
      AND A.IFRS9_CLASS = 'FVOCI'      
      THEN 'FVOCIG'      
     WHEN A.TOT_ADJUST < 0      
      AND A.IFRS9_CLASS = 'FVOCI'      
      THEN 'FVOCIL'      
     END JOURNALCODE      
   FROM [DBO].[IFRS_LI_EIR_ADJUSTMENT] A      
   )      
  INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
   DOWNLOAD_DATE      
   ,MASTERID      
   ,FACNO      
   ,CIFNO      
   ,ACCTNO      
   ,DATASOURCE      
   ,PRDTYPE      
   ,PRDCODE      
   ,TRXCODE      
   ,CCY      
 ,JOURNALCODE      
   ,STATUS      
   ,REVERSE      
   ,FLAG_CF      
   ,DRCR      
   ,GLNO      
   ,N_AMOUNT      
   ,N_AMOUNT_IDR      
   ,SOURCEPROCESS      
   ,INTMID      
   ,CREATEDDATE      
   ,CREATEDBY      
   ,BRANCH      
   ,JOURNALCODE2      
   ,JOURNAL_DESC      
   ,NOREF      
   ,VALCTR_CODE      
   ,GL_INTERNAL_CODE      
   ,METHOD
   ,ACCOUNT_TYPE
   ,CUSTOMER_TYPE             
   )      
  SELECT A.DOWNLOAD_DATE      
   ,A.MASTERID      
   ,IMC.FACILITY_NUMBER      
   ,IMC.CUSTOMER_NUMBER      
   ,A.ACCOUNT_NUMBER      
   ,IMC.DATA_SOURCE      
   ,IMC.PRODUCT_TYPE      
   ,IMC.PRODUCT_CODE      
   ,B.TRX_CODE      
   ,IMC.CURRENCY      
   ,B.JOURNALCODE      
   ,'ACT' STATUS      
   ,'N' REVERSE      
   ,B.FLAG_CF      
   ,B.DRCR      
   ,B.GLNO      
   ,ABS(A.TOT_ADJUST)      
   ,ABS(A.TOT_ADJUST * COALESCE(IMC.EXCHANGE_RATE, 1))      
   ,'MARK TO MARKET' AS SOURCEPROCESS      
   ,NULL      
   ,CURRENT_TIMESTAMP      
   ,'SP_JOURNAL_DATA2'      
   ,IMC.BRANCH_CODE      
   ,NULL JOURNALCODE2      
   ,B.JOURNAL_DESC      
   ,B.JOURNALCODE      
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, '')      
   ,B.GL_INTERNAL_CODE      
   ,NULL METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE                 
  FROM IFRS_LI_EIR_ADJUSTMENT_TEMP A              
  INNER JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
  JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE = A.JOURNALCODE      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, '')      
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
      
  ---REVERSE MARK TO MARKET        
  INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
   DOWNLOAD_DATE      
   ,MASTERID      
   ,FACNO      
   ,CIFNO      
   ,ACCTNO      
   ,DATASOURCE      
   ,PRDTYPE      
   ,PRDCODE      
   ,TRXCODE      
   ,CCY      
   ,JOURNALCODE      
   ,STATUS      
   ,REVERSE      
   ,FLAG_CF      
   ,DRCR      
   ,GLNO      
   ,N_AMOUNT      
   ,N_AMOUNT_IDR      
   ,SOURCEPROCESS      
   ,INTMID      
   ,CREATEDDATE      
   ,CREATEDBY      
   ,BRANCH      
   ,JOURNALCODE2      
   ,JOURNAL_DESC      
   ,NOREF      
   ,VALCTR_CODE      
   ,GL_INTERNAL_CODE      
   ,METHOD
   ,ACCOUNT_TYPE
   ,CUSTOMER_TYPE            
   )      
  SELECT               
    @V_CURRDATE DOWNLOAD_DATE      
   ,A.MASTERID      
   ,A.FACNO      
   ,A.CIFNO      
   ,A.ACCTNO             
   ,A.DATASOURCE      
   ,A.PRDTYPE      
   ,A.PRDCODE      
   ,A.TRXCODE      
   ,A.CCY      
   ,A.JOURNALCODE      
   ,A.STATUS      
   ,'Y' REVERSE      
   ,A.FLAG_CF      
   ,CASE       
    WHEN A.DRCR = 'D'      
     THEN 'C'      
    ELSE 'D'      
    END DRCR      
   ,A.GLNO      
   ,A.N_AMOUNT      
   ,A.N_AMOUNT_IDR      
   ,A.SOURCEPROCESS      
   ,A.INTMID      
   ,A.CREATEDDATE      
   ,A.CREATEDBY      
   ,A.BRANCH      
   ,A.JOURNALCODE2      
   ,A.JOURNAL_DESC      
   ,A.NOREF      
   ,A.VALCTR_CODE      
   ,A.GL_INTERNAL_CODE      
   ,A.METHOD
   ,A.ACCOUNT_TYPE
   ,A.CUSTOMER_TYPE         
  FROM IFRS_LI_ACCT_JOURNAL_DATA AS A      
  WHERE A.DOWNLOAD_DATE = @V_PREVMONTH      
   AND JOURNALCODE IN (      
    'FVTPLG'      
    ,'FVTPLL'      
    ,'FVOCIG'      
    ,'FVOCIL'      
    )      
   AND REVERSE = 'N'      
 END      
      
 /*ACRU NOCF*/      
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE             
  )      
 SELECT               
   A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,CASE       
   WHEN A.REVERSE = 'N'      
    AND N_AMOUNT > 0      
    THEN B.DRCR      
   WHEN A.REVERSE = 'Y'      
    AND N_AMOUNT <= 0      
    THEN B.DRCR      
   ELSE CASE       
     WHEN B.DRCR = 'C'      
      THEN 'D'      
     ELSE 'C'      
     END      
   END AS DRCR      
  ,B.GLNO      
  ,ABS(A.N_AMOUNT) N_AMOUNT      
  ,ABS(A.N_AMOUNT_IDR) N_AMOUNT_IDR      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP AS CREATEDDATE      
  ,'SP_ACCT_JOURNAL_DATA2' CREATEDBY      
  ,A.BRANCH      
  ,A.JOURNALCODE2      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE AS NOREF      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,A.METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE      
 FROM IFRS_LI_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE = 'ACRU4'      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.JOURNALCODE IN (      
   'ACRU4'      
   ,'AMRT4'      
   )      
  AND A.TRXCODE <> 'BENEFIT'      
  AND A.METHOD = 'EIR';      
           
 --RLCV OLD BRANCH               
 -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR    ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE           
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,B.DRCR          
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,B.JOURNALCODE      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE      
 FROM IFRS_LI_ACCT_JOURNAL_INTM A        
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'RCLV'          
   ) AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE             
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
  AND A.JOURNALCODE = 'DEFA0'      
  AND A.TRXCODE <> 'BENEFIT'      
  AND A.METHOD = 'EIR'               
  AND A.SOURCEPROCESS = 'EIR_REV_SWITCH'          
              
              
--RLCS NEW BRANCH               
 -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION          
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD
  ,ACCOUNT_TYPE
  ,CUSTOMER_TYPE             
  )      
 SELECT A.DOWNLOAD_DATE      
  ,A.MASTERID      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.ACCTNO      
  ,A.DATASOURCE      
  ,A.PRDTYPE      
  ,A.PRDCODE      
  ,A.TRXCODE      
  ,A.CCY      
  ,A.JOURNALCODE      
  ,A.STATUS      
  ,A.REVERSE      
  ,A.FLAG_CF      
  ,B.DRCR         
  ,B.GLNO      
  ,ABS(A.N_AMOUNT)      
  ,ABS(A.N_AMOUNT_IDR)      
  ,A.SOURCEPROCESS      
  ,A.ID      
  ,CURRENT_TIMESTAMP      
  ,'SP_JOURNAL_DATA2'      
  ,A.BRANCH      
  ,B.JOURNALCODE      
  ,B.JOURNAL_DESC      
  ,B.JOURNALCODE      
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')      
  ,B.GL_INTERNAL_CODE      
  ,METHOD
  ,IMC.ACCOUNT_TYPE
  ,IMC.CUSTOMER_TYPE      
 FROM IFRS_LI_ACCT_JOURNAL_INTM A      
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID      
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID      
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (      
   'RCLS'               
   )      
  AND (      
   B.CCY = A.CCY      
   OR B.CCY = 'ALL'      
   )      
  AND B.FLAG_CF = A.FLAG_CF      
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
  AND (      
   A.TRXCODE = B.TRX_CODE      
   OR B.TRX_CODE = 'ALL'      
   )      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
  AND A.JOURNALCODE = 'DEFA0'      
  AND A.TRXCODE <> 'BENEFIT'      
  AND A.METHOD = 'EIR'               
  AND A.SOURCEPROCESS = 'EIR_SWITCH'              
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'JOURNAL SL'      
  )              
 -- CALL JOURNAL SL GENERATED          
 EXEC SP_IFRS_LI_ACCT_JRNL_DATA_SL      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'JOURNAL SL DONE'      
  )      
      
 /* JOURNAL FACILITY LEVEL FOR PNL EXPIRED 20180501*/      
 ---CORPORATE      
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD  
  )      
 SELECT B.DOWNLOAD_DATE      
  ,A.TRX_FACILITY_NO      
  ,A.TRX_FACILITY_NO      
  ,NULL      
  ,A.TRX_FACILITY_NO      
  ,NULL      
  ,NULL      
  ,NULL      
  ,A.TRX_CODE      
  ,A.TRX_CCY      
  ,'PNL'      
  ,'ACT' STATUS      
  ,'N' REVERSE      
  ,D.VALUE1 FLAG_CF      
  ,LEFT(D.VALUE2, 1)      
  ,D.VALUE3 GLNO      
  ,A.REMAINING      
  ,A.REMAINING * RATE.RATE_AMOUNT      
  ,'CORP FACILITY EXP' AS SOURCEPROCESS      
  ,NULL      
  ,CURRENT_TIMESTAMP      
  ,'SP_ACCT_JOURNAL_DATA'      
  ,E.BRANCH_CODE      
  ,'PNL' JOURNALCODE2      
  ,D.DESCRIPTION      
  ,NULL      
  ,NULL      
  ,NULL GL_INTERNAL_CODE      
  ,NULL METHOD                
 FROM IFRS_TRX_FACILITY A              
 LEFT JOIN IFRS_MASTER_PARENT_LIMIT B ON A.TRX_FACILITY_NO = B.LIMIT_PARENT_NO AND B.DOWNLOAD_DATE = @V_CURRDATE      
 LEFT JOIN IFRS_LI_TRANSACTION_PARAM C ON A.TRX_CODE = C.TRX_CODE      
  AND (      
   A.TRX_CCY = C.CCY      
   OR C.CCY = 'ALL'      
   )      
 LEFT JOIN TBLM_COMMONCODEDETAIL D ON LEFT(C.IFRS_TXN_CLASS, 1) = D.VALUE1      
  AND D.COMMONCODE = 'B103'      
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE RATE ON A.TRX_CCY = RATE.CURRENCY      
  AND RATE.DOWNLOAD_DATE = @V_CURRDATE      
 LEFT JOIN IFRS_IMA_LIMIT E ON A.TRX_FACILITY_NO = E.MASTERID      
  AND E.DOWNLOAD_DATE = @V_CURRDATE      
 WHERE A.REMAINING > 0      
  AND DATEADD(DAY, 1, A.FACILITY_EXPIRED_DATE) = @V_CURRDATE      
  AND A.STATUS = 'P'      
  AND A.REVID IS NULL      
  AND A.PKID NOT IN (      
   SELECT DISTINCT REVID      
   FROM IFRS_TRX_FACILITY      
   WHERE REVID IS NOT NULL      
   )      
  AND B.SME_FLAG = 0      
      
 ---SME      
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,FACNO      
  ,CIFNO      
  ,ACCTNO      
  ,DATASOURCE      
  ,PRDTYPE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,JOURNALCODE      
  ,STATUS      
  ,REVERSE      
  ,FLAG_CF      
  ,DRCR      
  ,GLNO      
  ,N_AMOUNT      
  ,N_AMOUNT_IDR      
  ,SOURCEPROCESS      
  ,INTMID      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,BRANCH      
  ,JOURNALCODE2      
  ,JOURNAL_DESC      
  ,NOREF      
  ,VALCTR_CODE      
  ,GL_INTERNAL_CODE      
  ,METHOD           
  )      
 SELECT B.DOWNLOAD_DATE      
  ,A.TRX_FACILITY_NO      
  ,A.TRX_FACILITY_NO      
  ,NULL      
  ,A.TRX_FACILITY_NO      
  ,NULL      
  ,NULL      
  ,NULL      
  ,A.TRX_CODE      
  ,A.TRX_CCY      
  ,'PNL'      
  ,'ACT' STATUS      
  ,'N' REVERSE      
  ,D.VALUE1 FLAG_CF      
  ,LEFT(D.VALUE2, 1)      
  ,D.VALUE3 GLNO      
  ,A.REMAINING      
  ,A.REMAINING * RATE.RATE_AMOUNT      
  ,'SME FACILITY EXP' AS SOURCEPROCESS      
  ,NULL      
  ,CURRENT_TIMESTAMP      
 ,'SP_ACCT_JOURNAL_DATA'      
  ,E.BRANCH_CODE      
  ,'PNL' JOURNALCODE2      
  ,D.DESCRIPTION      
  ,NULL      
  ,NULL      
  ,NULL GL_INTERNAL_CODE      
  ,NULL METHOD        
 FROM IFRS_TRX_FACILITY A      
 LEFT JOIN IFRS_MASTER_PARENT_LIMIT B ON A.TRX_FACILITY_NO = B.LIMIT_PARENT_NO      
  AND B.DOWNLOAD_DATE = @V_CURRDATE      
 LEFT JOIN IFRS_LI_TRANSACTION_PARAM C ON A.TRX_CODE = C.TRX_CODE      
  AND (      
   A.TRX_CCY = C.CCY      
   OR C.CCY = 'ALL'      
   )      
 LEFT JOIN TBLM_COMMONCODEDETAIL D ON LEFT(C.IFRS_TXN_CLASS, 1) = D.VALUE1      
  AND D.COMMONCODE = 'B104'      
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE RATE ON A.TRX_CCY = RATE.CURRENCY      
  AND RATE.DOWNLOAD_DATE = @V_CURRDATE      
 LEFT JOIN IFRS_IMA_LIMIT E ON A.TRX_FACILITY_NO = E.MASTERID      
  AND E.DOWNLOAD_DATE = @V_CURRDATE      
WHERE A.REMAINING > 0      
  AND DATEADD(DAY, 1, A.FACILITY_EXPIRED_DATE) = @V_CURRDATE      
  AND A.STATUS = 'P'      
  AND A.REVID IS NULL      
  AND A.PKID NOT IN (      
   SELECT DISTINCT REVID      
   FROM IFRS_TRX_FACILITY      
   WHERE REVID IS NOT NULL      
   )      
  AND B.SME_FLAG = 1      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'JOURNAL FACILITY DONE'      
  )      
      
 /*PINDAHAN DARI ATAS 20160510*/      
 UPDATE IFRS_LI_ACCT_JOURNAL_DATA      
 SET NOREF = CASE       
   WHEN NOREF IN (      
     'ITRCG'      
     ,'ITRCG_SL'      
     ,'ITRCG_NE'      
     )      
    THEN '1'      
   WHEN NOREF IN (      
     'ITRCG1'      
     ,'ITRCG_SL1'      
     )      
    THEN '2'      
   WHEN NOREF IN (      
     'ITRCG2'      
     ,'ITRCG_SL2'      
     )      
    THEN '3'      
   WHEN NOREF IN (      
     'EMPBE'      
     ,'EMPBE_SL'      
     )      
    THEN '4'      
   WHEN NOREF IN (      
     'EMACR'      
     ,'EMACR_SL'      
     )      
    THEN '5'      
   WHEN NOREF = 'RLS'      
    THEN '6'      
   ELSE '9'      
   END + CASE       
   WHEN REVERSE = 'Y'      
    THEN '1'      
   ELSE '2'      
   END + CASE       
   WHEN DRCR = 'D'      
    THEN '1'      
   ELSE '2'      
   END      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,'FILL NOREF DONE'      
  )      
      
 /* FD: UPDATE MASTER ACCOUNT FAIR VALUE AMOUNT*/--SELECT UNAMORT_AMT_TOTAL FROM IFRS_LI_MASTER_ACCOUNT          
 UPDATE A        
 SET A.FAIR_VALUE_AMOUNT =         
 CASE WHEN B.VALUE1 IS NOT NULL         
  THEN COALESCE(A.OUTSTANDING, 0) + COALESCE(A.OUTSTANDING_IDC, 0)         
  ELSE COALESCE(A.OUTSTANDING, 0) + COALESCE(A.OUTSTANDING_IDC, 0) + COALESCE(A.UNAMORT_FEE_AMT,0) + COALESCE(A.UNAMORT_COST_AMT, 0)      
 END       
 FROM IFRS_LI_MASTER_ACCOUNT A               
 LEFT JOIN TBLM_COMMONCODEDETAIL B         
  ON A.DATA_SOURCE = B.VALUE1 AND A.PRODUCT_CODE = B.VALUE1         
   AND B.COMMONCODE = 'S1022'        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
 AND NOT EXISTS (        
  SELECT TOP 1 1         
  FROM TBLM_COMMONCODEDETAIL X         
  WHERE A.DATA_SOURCE = X.VALUE1 AND X.COMMONCODE = 'S1003' ) -- TREASURY, FAIRVALUE = LEMPARAN DARI DWH. GA PERLU UPDATE        
      
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'      
  ,''      
  )      
END 
GO
