USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_JRNL_DATA_FAC]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_JRNL_DATA_FAC]      
AS      
      
BEGIN      
      
DECLARE @V_CURRDATE DATE          
 ,@V_PREVDATE DATE          
 ,@V_PREVMONTH DATE          
 ,@VMIN_NOREF BIGINT    
 ,@MIGRATION_DATE DATE          
              
 SELECT @V_CURRDATE = MAX(CURRDATE)          
  ,@V_PREVDATE = MAX(PREVDATE)          
 FROM IFRS_PRC_DATE_AMORT          
          
 SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, - 1, @V_CURRDATE))         
 SELECT @MIGRATION_DATE = VALUE2 FROM TBLM_COMMONCODEDETAIL WHERE VALUE1 = 'ITRCGFM'      
      
/**********************      
  1. PNL      
***********************/      
INSERT INTO IFRS_ACCT_JOURNAL_DATA (          
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
  A.MATURITY_DATE AS DOWNLOAD_DATE          
 ,A.FACILITY_NUMBER  AS MASTERID          
 ,A.FACILITY_NUMBER AS FACNO          
 ,A.CUSTOMER_NUMBER  AS CIFNO          
 ,A.FACILITY_NUMBER  AS ACCTNO          
 ,A.DATA_SOURCE    AS DATASOURCE       
 ,A.PRD_TYPE AS PRDTYPE          
 ,A.PRD_CODE  AS PRDCODE         
 ,A.TRX_CODE   AS TRXCODE        
 ,A.LIMIT_CURRENCY     AS CCY       
 ,C.JOURNALCODE          
 ,'ACT' AS STATUS          
 ,'N' AS REVERSE          
 ,A.FLAG_CF          
 ,CASE WHEN C.DRCR = 'C' THEN 'D' ELSE 'C' END AS DRCR          
 ,C.GLNO          
 ,A.UNALOC AS N_AMOUNT          
 ,(A.UNALOC * B.RATE_AMOUNT )AS N_AMOUNT_IDR          
 ,'PNL FACILITY' AS SOURCEPROCESS          
 ,NULL INTMID          
 ,CURRENT_TIMESTAMP AS CREATEDDATE          
 ,'JOURNAL FACILITY' AS CREATEDBY          
 ,A.BRANCH_CODE         
 ,C.JOURNALCODE    AS JOURNALCODE2          
 ,C.JOURNAL_DESC          
 ,NULL AS NOREF       
 ,C.COSTCENTER         
 ,C.GL_INTERNAL_CODE          
 ,NULL METHOD      
 ,MPB.ACCOUNT_TYPE    
 ,A.CUSTOMER_TYPE     
FROM IFRS_TRX_FACILITY_HEADER A        
JOIN IFRS_MASTER_EXCHANGE_RATE B      
    ON A.LIMIT_CURRENCY = B.CURRENCY      
      AND A.MATURITY_DATE = B.DOWNLOAD_DATE     
LEFT JOIN IFRS9_STG..TBL_MASTER_PRODUCT_BANKWIDE MPB ON A.PRD_CODE =  MPB.PRODUCT_CODE        
JOIN IFRS_JOURNAL_PARAM C      
 ON A.GL_CONSTNAME = C.GL_CONSTNAME      
   AND (  A.TRX_CODE = C.TRX_CODE OR C.TRX_CODE = 'ALL')      
   AND (A.LIMIT_CURRENCY = C.CCY OR C.CCY = 'ALL')        
   AND C.JOURNALCODE = 'ITRCGF'         
   AND A.FLAG_CF = C.FLAG_CF      
WHERE A.UNALOC > 0         
  AND A.MATURITY_DATE = @V_CURRDATE          
  AND A.STATUS = 'PNL'          
  AND A.REVID IS NULL          
  AND A.PKID NOT IN ( SELECT DISTINCT REVID FROM IFRS_TRX_FACILITY_HEADER WHERE REVID IS NOT NULL)       
  
  
  
/**********************      
  2. PNL SELLDOWN      
***********************/  
INSERT INTO IFRS_ACCT_JOURNAL_DATA (          
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
  D.DOWNLOAD_DATE AS DOWNLOAD_DATE          
 ,A.FACILITY_NUMBER  AS MASTERID          
 ,A.FACILITY_NUMBER AS FACNO          
 ,A.CUSTOMER_NUMBER  AS CIFNO          
 ,A.FACILITY_NUMBER  AS ACCTNO          
 ,A.DATA_SOURCE    AS DATASOURCE       
 ,A.PRD_TYPE AS PRDTYPE          
 ,A.PRD_CODE  AS PRDCODE         
 ,A.TRX_CODE   AS TRXCODE        
 ,A.LIMIT_CURRENCY     AS CCY       
 ,C.JOURNALCODE          
 ,'ACT' AS STATUS          
 ,'N' AS REVERSE          
 ,A.FLAG_CF          
 ,CASE WHEN C.DRCR = 'C' THEN 'D' ELSE 'C' END AS DRCR         
 ,C.GLNO          
 ,d.ORG_CCY_AMT AS N_AMOUNT          
 ,(d.ORG_CCY_AMT * B.RATE_AMOUNT )AS N_AMOUNT_IDR          
 ,'PNL SELLDOWN' AS SOURCEPROCESS          
 ,NULL INTMID          
 ,CURRENT_TIMESTAMP AS CREATEDDATE          
 ,'JOURNAL FACILITY' AS CREATEDBY          
 ,A.BRANCH_CODE         
 ,C.JOURNALCODE    AS JOURNALCODE2          
 ,C.JOURNAL_DESC          
 ,NULL AS NOREF       
 ,C.COSTCENTER         
 ,C.GL_INTERNAL_CODE          
 ,NULL METHOD      
 ,MPB.ACCOUNT_TYPE    
 ,A.CUSTOMER_TYPE    
------SELECT *   
FROM IFRS_TRX_FACILITY_HEADER A   
INNER JOIN IFRS_TRX_FACILITY_DETAIL D ON A.FACILITY_NUMBER = D.FACILITY_NUMBER  
AND D.SOURCE_TABLE = 'IFRS_FACILITY_SELLDOWN_FLAG'      
INNER JOIN IFRS_MASTER_EXCHANGE_RATE B ON A.CCY = B.CURRENCY AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE     
LEFT JOIN IFRS9_STG.. TBL_MASTER_PRODUCT_BANKWIDE MPB ON A.PRD_CODE =  MPB.PRODUCT_CODE        
JOIN IFRS_JOURNAL_PARAM C      
 ON A.GL_CONSTNAME = C.GL_CONSTNAME      
   AND (  A.TRX_CODE = C.TRX_CODE OR C.TRX_CODE = 'ALL')      
   AND (A.LIMIT_CURRENCY = C.CCY OR C.CCY = 'ALL')        
   AND C.JOURNALCODE = 'ITRCGF'         
   AND A.FLAG_CF = C.FLAG_CF      
WHERE A.UNALOC > 0         
  AND D.DOWNLOAD_DATE = @V_CURRDATE               
  AND A.REVID IS NULL          
  AND A.PKID NOT IN ( SELECT DISTINCT REVID FROM IFRS_TRX_FACILITY_HEADER WHERE REVID IS NOT NULL)   
   
       
/*************************      
 2. JOURNAL ITRCG      
**************************/      
INSERT INTO IFRS_ACCT_JOURNAL_DATA (          
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
 ,A.FACILITY_NUMBER  AS MASTERID          
 ,A.FACILITY_NUMBER AS FACNO          
 ,A.CUSTOMER_NUMBER  AS CIFNO          
 ,A.FACILITY_NUMBER  AS ACCTNO          
 ,A.DATA_SOURCE    AS DATASOURCE       
 ,A.PRD_TYPE AS PRDTYPE          
 ,A.PRD_CODE  AS PRDCODE         
 ,A.TRX_CODE   AS TRXCODE        
 ,A.LIMIT_CURRENCY     AS CCY       
 ,C.JOURNALCODE          
 ,'ACT' AS STATUS          
 ,'N' AS REVERSE          
 ,A.FLAG_CF          
 ,C.DRCR          
 ,C.GLNO          
 ,A.TRX_AMOUNT AS N_AMOUNT          
 ,(A.TRX_AMOUNT * B.RATE_AMOUNT ) AS N_AMOUNT_IDR          
 ,'ACT FACILITY' AS SOURCEPROCESS          
 ,NULL INTMID          
 ,CURRENT_TIMESTAMP AS CREATEDDATE          
 ,'JOURNAL FACILITY' AS CREATEDBY          
 ,A.BRANCH_CODE         
 ,C.JOURNALCODE    AS JOURNALCODE2          
 ,C.JOURNAL_DESC          
 ,NULL AS NOREF       
 ,C.COSTCENTER      
 ,C.GL_INTERNAL_CODE          
 ,NULL METHOD      
 ,MPB.ACCOUNT_TYPE    
 ,A.CUSTOMER_TYPE     
FROM IFRS_TRX_FACILITY_HEADER A        
JOIN IFRS_MASTER_EXCHANGE_RATE B      
    ON A.LIMIT_CURRENCY = B.CURRENCY      
      AND A.DOWNLOAD_DATE= B.DOWNLOAD_DATE    
LEFT JOIN IFRS9_STG..TBL_MASTER_PRODUCT_BANKWIDE MPB ON A.PRD_CODE =  MPB.PRODUCT_CODE          
JOIN IFRS_JOURNAL_PARAM C      
 ON A.GL_CONSTNAME = C.GL_CONSTNAME      
   AND (A.TRX_CODE = C.TRX_CODE OR C.TRX_CODE = 'ALL')      
   AND (A.LIMIT_CURRENCY = C.CCY OR C.CCY = 'ALL')        
   AND C.JOURNALCODE = 'ITRCGF'         
   AND A.FLAG_CF = C.FLAG_CF      
WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
  AND A.REVID IS NULL  AND (a.DOWNLOAD_DATE <> @MIGRATION_DATE OR CREATEDBY = 'STG_IFRS_TRANSACTION_DAILY_FACILITY')        
  --AND A.PKID NOT IN ( SELECT DISTINCT REVID FROM IFRS_TRX_FACILITY_HEADER       
  --WHERE REVID IS NOT NULL AND DOWNLOAD_DATE < @V_CURRDATE)       
      
  --~oO> 2.2 ITRCGFM (migration) <Oo~--    
  INSERT INTO IFRS_ACCT_JOURNAL_DATA (          
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
 ,A.FACILITY_NUMBER  AS MASTERID          
 ,A.FACILITY_NUMBER AS FACNO          
 ,A.CUSTOMER_NUMBER  AS CIFNO          
 ,A.FACILITY_NUMBER  AS ACCTNO          
 ,A.DATA_SOURCE    AS DATASOURCE       
 ,A.PRD_TYPE AS PRDTYPE          
 ,A.PRD_CODE  AS PRDCODE         
 ,A.TRX_CODE   AS TRXCODE        
 ,A.LIMIT_CURRENCY   AS CCY       
 ,C.JOURNALCODE          
 ,'ACT' AS STATUS          
 ,'N' AS REVERSE          
 ,A.FLAG_CF          
 ,C.DRCR          
 ,C.GLNO          
 ,A.TRX_AMOUNT AS N_AMOUNT          
 ,(A.TRX_AMOUNT * B.RATE_AMOUNT )AS N_AMOUNT_IDR          
 ,'ACT FACILITY' AS SOURCEPROCESS          
 ,NULL INTMID          
 ,CURRENT_TIMESTAMP AS CREATEDDATE          
 ,'JOURNAL FACILITY' AS CREATEDBY          
 ,A.BRANCH_CODE         
 ,C.JOURNALCODE    AS JOURNALCODE2          
 ,C.JOURNAL_DESC          
 ,NULL AS NOREF       
 ,C.COSTCENTER      
 ,C.GL_INTERNAL_CODE          
 ,NULL METHOD      
 ,MPB.ACCOUNT_TYPE    
 ,A.CUSTOMER_TYPE      
FROM IFRS_TRX_FACILITY_HEADER A        
JOIN IFRS_MASTER_EXCHANGE_RATE B      
    ON A.LIMIT_CURRENCY = B.CURRENCY      
      AND A.DOWNLOAD_DATE= B.DOWNLOAD_DATE       
LEFT JOIN IFRS9_STG..TBL_MASTER_PRODUCT_BANKWIDE MPB ON A.PRD_CODE =  MPB.PRODUCT_CODE       
JOIN IFRS_JOURNAL_PARAM C      
 ON A.GL_CONSTNAME = C.GL_CONSTNAME      
   AND (A.TRX_CODE = C.TRX_CODE OR C.TRX_CODE = 'ALL')      
   AND (A.LIMIT_CURRENCY = C.CCY OR C.CCY = 'ALL')        
   AND C.JOURNALCODE = 'ITRCGFM'   
   AND A.CREATEDBY = 'TBLU_FACILITY_FEECOST'        
   AND A.FLAG_CF = C.FLAG_CF      
WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
  AND A.REVID IS NULL AND a.DOWNLOAD_DATE = @MIGRATION_DATE         
  --AND A.PKID NOT IN ( SELECT DISTINCT REVID FROM IFRS_TRX_FACILITY_HEADER       
  --WHERE REVID IS NOT NULL AND DOWNLOAD_DATE < @V_CURRDATE)       
      
      
  /*************************      
 3. JOURNAL IF STATUS 'REV'      
**************************/      
INSERT INTO IFRS_ACCT_JOURNAL_DATA (          
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
 ,A.FACILITY_NUMBER  AS MASTERID          
 ,A.FACILITY_NUMBER AS FACNO          
 ,A.CUSTOMER_NUMBER  AS CIFNO          
 ,A.FACILITY_NUMBER  AS ACCTNO          
 ,A.DATA_SOURCE    AS DATASOURCE       
 ,A.PRD_TYPE AS PRDTYPE          
 ,A.PRD_CODE AS PRDCODE         
 ,A.TRX_CODE   AS TRXCODE        
 ,A.LIMIT_CURRENCY  AS CCY       
 ,C.JOURNALCODE          
 ,'ACT' AS STATUS          
 ,'Y' AS REVERSE          
 ,A.FLAG_CF          
 , CASE WHEN C.DRCR = 'C'      
  THEN 'D'      
  ELSE 'C'      
  END DRCR          
 ,C.GLNO          
 ,A.TRX_AMOUNT AS N_AMOUNT          
 ,(A.TRX_AMOUNT * ISNULL(B.RATE_AMOUNT,1) )AS N_AMOUNT_IDR          
 ,'REV FACILITY' AS SOURCEPROCESS          
 ,NULL INTMID          
 ,CURRENT_TIMESTAMP AS CREATEDDATE          
 ,'JOURNAL FACILITY' AS CREATEDBY          
 ,A.BRANCH_CODE         
 ,C.JOURNALCODE    AS JOURNALCODE2          
 ,C.JOURNAL_DESC          
 ,NULL AS NOREF       
 ,C.COSTCENTER      
 ,C.GL_INTERNAL_CODE          
 ,NULL METHOD      
 ,MPB.ACCOUNT_TYPE    
 ,A.CUSTOMER_TYPE      
FROM IFRS_TRX_FACILITY_HEADER A        
LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B      
    ON A.LIMIT_CURRENCY = B.CURRENCY      
      AND A.DOWNLOAD_DATE= B.DOWNLOAD_DATE      
LEFT JOIN IFRS9_STG..TBL_MASTER_PRODUCT_BANKWIDE MPB ON A.PRD_CODE =  MPB.PRODUCT_CODE         
JOIN IFRS_JOURNAL_PARAM C      
 ON A.GL_CONSTNAME = C.GL_CONSTNAME      
   AND (A.TRX_CODE = C.TRX_CODE OR C.TRX_CODE = 'ALL')      
   AND (A.LIMIT_CURRENCY = C.CCY OR C.CCY = 'ALL')        
   AND C.JOURNALCODE = 'ITRCGF'         
   AND A.FLAG_CF = C.FLAG_CF      
WHERE A.DOWNLOAD_DATE = @V_CURRDATE          
  AND A.STATUS = 'REV'          
  AND A.REVID IS NOT NULL          
       
      
  END
GO
