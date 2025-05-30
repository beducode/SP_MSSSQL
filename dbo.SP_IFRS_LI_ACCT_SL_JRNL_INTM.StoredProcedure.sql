USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_SL_JRNL_INTM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_SL_JRNL_INTM]                  
AS                  
DECLARE @V_CURRDATE DATE                  
 ,@V_PREVDATE DATE                  
 ,@PARAM_DISABLE_ACCRU_PREV BIGINT                  
 ,@SL_METHOD VARCHAR(40) = 'ECF'       
 ,@V_ROUND INT = 6            
 ,@V_FUNCROUND INT = 1                
                
BEGIN                  
 SELECT @V_CURRDATE = MAX(CURRDATE)                  
  ,@V_PREVDATE = MAX(PREVDATE)                  
 FROM IFRS_LI_PRC_DATE_AMORT                  
                  
 --DISABLE ACCRU PREV CREATE ON NEW ECF AND RETURN ACCRUAL TO UNAMORT                  
 SET @PARAM_DISABLE_ACCRU_PREV = 0                  
                  
 --PARAM SL METHOD ECF OR NO_ECF                  
 SELECT @SL_METHOD = VALUE1                  
 FROM TBLM_COMMONCODEDETAIL                  
 WHERE COMMONCODE = 'SL_METHOD'         
   
  SELECT @V_ROUND = CAST(VALUE1 AS INT)            
  ,@V_FUNCROUND = CAST(VALUE2 AS INT)            
 FROM TBLM_COMMONCODEDETAIL            
 WHERE COMMONCODE = 'SCM003'               
                  
 --20171013 ADD DEFAULT VALUE                  
 IF (                  
   @SL_METHOD IS NULL                  
   OR @SL_METHOD NOT IN (                  
    'ECF'                  
    ,'NO_ECF'                  
    )                  
   )                  
  SET @SL_METHOD = 'ECF'                  
                  
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
  ,'SP_IFRS_LI_ACCT_SL_JOURNAL_INTM'                  
  ,''                  
  )                  
                  
 --DELETE FIRST                  
 DELETE                  
 FROM IFRS_LI_ACCT_JOURNAL_INTM                  
 WHERE DOWNLOAD_DATE >= @V_CURRDATE                  
  AND SOURCEPROCESS LIKE 'SL%'                  
                  
 -- PNL = DEFA0 + AMORT OF NEW COST FEE TODAY                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,IS_PNL                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                       
  ,'DEFA0'             
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN FLAG_REVERSE = 'Y'                  
    THEN -1                 
   ELSE 1                 
   END * AMOUNT    
  ,CURRENT_TIMESTAMP                  
  ,'SL PNL 1'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,'Y' IS_PNL                  
  ,PRD_TYPE --,'ITRCG'                  
  ,'ITRCG_SL'             
  ,CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE                 
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'PNL'                  
  AND METHOD = 'SL'                   
            
  UNION ALL            
            
  SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                   
 ,'DEFA0'               
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN FLAG_REVERSE = 'Y'                  
    THEN -1                 
   ELSE 1                 
   END *   TAX_AMOUNT                 
  ,CURRENT_TIMESTAMP                  
  ,'SL PNL 1'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,'Y' IS_PNL                  
  ,PRD_TYPE --,'ITRCG'                  
  ,'ITRCG1_SL'             
  ,CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'PNL'                  
  AND METHOD = 'SL'                  
  AND TAX_AMOUNT <> 0                
                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,IS_PNL                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,- 1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL PNL 2'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,'Y' IS_PNL                  
  ,PRD_TYPE                  
  ,'ACCRU_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'PNL'                  
  AND METHOD = 'SL'                  
                  
 -- PNL = AMORT OF UNAMORT BY CURRDATE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO               
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,- 1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL PNL 3'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,PRDTYPE                  
  ,'ACRRU_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE             
  AND STATUS = 'PNL'                  
                  
 -- PNL2 = AMORT OF UNAMORT BY PREVDATE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )          
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,- 1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL PNL 3'                  
  ,ACCTNO                  
  ,MASTERID            
  ,FLAG_CF                  
  ,BRCODE                  
  ,PRDTYPE                  
  ,'ACCRU_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV                  
 WHERE DOWNLOAD_DATE = @V_PREVDATE                  
  AND STATUS = 'PNL2'                  
                  
 --DEFA0 NORMAL AMORTIZED COST/FEE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                    
  ,'DEFA0'               
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN FLAG_REVERSE = 'Y'                  
    THEN -1                 
   ELSE 1                 
   END * AMOUNT                
  ,CURRENT_TIMESTAMP                  
  ,'SL ACT 1'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,PRD_TYPE                  
  , 'ITRCG_SL'                    
  ,CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE                   
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'ACT'                  
  AND METHOD = 'SL'                   
            
  UNION ALL            
            
  --INSERT COMPONEN TAX             
            
   SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                      
  ,'DEFA0'             
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN FLAG_REVERSE = 'Y'                  
    THEN -1                 
   ELSE 1                 
   END *   TAX_AMOUNT                 
  ,CURRENT_TIMESTAMP                  
  ,'SL ACT 1'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF               
  ,BRCODE      
  ,PRD_TYPE                  
  ,  'ITRCG1_SL'                
  ,CF_ID                  
 FROM IFRS_LI_ACCT_COST_FEE                
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'ACT'                  
  AND METHOD = 'SL'                  
  AND TAX_AMOUNT <> 0               
                  
 --REVERSE ACCRUAL                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,@V_CURRDATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,'Y'                  
  ,N_AMOUNT                  
  ,CURRENT_TIMESTAMP                  
  ,'SL REV ACCRU'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_JOURNAL_INTM                  
 WHERE DOWNLOAD_DATE = @V_PREVDATE                  
  AND STATUS = 'ACT'                  
  AND JOURNALCODE = 'ACCRU_SL'                  
  AND REVERSE = 'N'                  
  AND SUBSTRING(SOURCEPROCESS, 1, 2) = 'SL'                  
                  
 --ACCRU FEE                  
 TRUNCATE TABLE TMP_LI_T5                  
            
  INSERT INTO TMP_LI_T5 (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
   )                  
  SELECT FACNO                  
   ,CIFNO                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END AS N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
  FROM IFRS_LI_ACCT_SL_COST_FEE_ECF                  
  WHERE FLAG_CF = 'F'                  
                   
 --JOURNAL SL BARU                  
 IF @SL_METHOD = 'NO_ECF'                  
 BEGIN                  
  TRUNCATE TABLE TMP_LI_T5                  
                  
  INSERT INTO TMP_LI_T5 (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
   )                  
  SELECT FACNO                  
   ,CIFNO                  
   ,EFFDATE                  
   ,A.DATA_SOURCE                  
   ,PRD_CODE                  
   ,TRX_CODE                  
   ,CCY                  
   ,A.SL_AMORT_DAILY                  
   ,A.MASTERID                  
   ,A.MASTERID                  
   ,BRCODE                  
 ,B.PRODUCT_TYPE                  
   ,ID_SL                  
  FROM IFRS_LI_ACF_SL_MSTR A                  
  JOIN IFRS_LI_MASTER_ACCOUNT B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER                  
   AND A.EFFDATE = B.DOWNLOAD_DATE                  
  WHERE FLAG_CF = 'F'                  
   AND IFRS_STATUS = 'ACT'                  
 END                  
                  
 --JOURNAL SL BARU                  
 TRUNCATE TABLE TMP_LI_T6                  
                  
 INSERT INTO TMP_LI_T6 (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,SUM_AMT                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,SUM(N_AMOUNT) AS SUM_AMT                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
 FROM TMP_LI_T5 D                  
 GROUP BY FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (             
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE               
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'ACCRU_SL'                  
  ,'ACT'                  
  ,'N'                  
  ,A.N_ACCRU_FEE * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20))                  
  ,CURRENT_TIMESTAMP                  
  ,'SL ACCRU FEE 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'F'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
 ,'ACCRU_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'N'                  
                  
 /*                  
 --JOURNAL SL BARU                  
                  
   INSERT  INTO IFRS_LI_ACCT_JOURNAL_INTM                  
                ( FACNO ,                  
                  CIFNO ,                  
                  DOWNLOAD_DATE ,                  
                  DATASOURCE ,                  
                  PRDCODE ,                  
                  TRXCODE ,                  
                  CCY ,                  
                  JOURNALCODE ,                  
                  STATUS ,                  
                  REVERSE ,                  
                  N_AMOUNT ,                  
                  CREATEDDATE ,                  
                  SOURCEPROCESS ,                  
                  ACCTNO ,                  
                  MASTERID ,                  
                  FLAG_CF ,                  
                  BRANCH ,         
                  PRDTYPE ,                  
                  JOURNALCODE2 ,                  
 CF_ID                  
                )                  
                SELECT  A.FACNO ,                  
                        A.CIFNO ,                  
                        A.EFFDATE ,                  
                        A.DATA_SOURCE ,                  
                        B.PRDCODE ,                  
                        B.TRXCODE ,                  
                        B.CCY ,                  
                        'ACCRU_SL' ,                  
                        'ACT' ,                  
                        'N' ,                  
                        A.SL_AMORT_DAILY ,                  
                        CURRENT_TIMESTAMP ,                  
                        'SL ACCRU FEE 1' ,                  
                        A.MASTERID ,                  
                        A.MASTERID ,                  
                        'F' ,                  
                        B.BRCODE ,                  
                        B.PRDTYPE ,                  
                        'ACCRU_SL' ,                  
                        B.CF_ID                  
                FROM    IFRS_LI_ACF_SL_MSTR A                  
                        JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.EFFDATE                  
                                              AND B.MASTERID = A.MASTERID                  
                        JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
                                              AND A.EFFDATE = C.DOWNLOAD_DATE                  
                WHERE   A.EFFDATE = @V_CURRDATE                  
                        AND A.IFRS_STATUS = 'ACT'                  
                  
 */                  
 --AMORT FEE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,A.N_ACCRU_FEE * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20))                  
  ,CURRENT_TIMESTAMP                  
  ,'SL AMORT FEE 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'F'                
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'Y'                  
                  
 --JOURNAL SL BARU                  
 IF @SL_METHOD = 'NO_ECF'                  
 BEGIN                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS     
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.EFFDATE                  
  ,A.DATA_SOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,A.SL_AMORT_DAILY                  
  ,CURRENT_TIMESTAMP                  
  ,'SL AMORT FEE 1'               
  ,A.MASTERID                  
  ,A.MASTERID                  
  ,'F'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACF_SL_MSTR A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.EFFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.EFFDATE = C.DOWNLOAD_DATE                  
 WHERE A.EFFDATE = @V_CURRDATE                  
  AND A.IFRS_STATUS = 'ACT'                  
 END                  
                  
 --DEFA0 FEE STOP REV AT PMTDATE 20160619                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'N'                  
  ,- 1 * A.N_ACCRU_FEE * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20))                  
  ,CURRENT_TIMESTAMP                  
  ,'SL DEFA0 FEE 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'F'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ITRCG_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'Y'                  
  -- ONLY FOR STOP REV                  
  AND A.MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_SL_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   )                  
                  
 --ACCRU COST                  
                  
  TRUNCATE TABLE TMP_LI_T5                  
                  
  INSERT INTO TMP_LI_T5 (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
   )                  
  SELECT FACNO                  
   ,CIFNO                  
   ,ECFDATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY             
   ,CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END AS N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
FROM IFRS_LI_ACCT_SL_COST_FEE_ECF                  
  WHERE FLAG_CF = 'C'                  
 --JOURNAL SL BARU                  
 IF @SL_METHOD = 'NO_ECF'                  
 BEGIN                  
  TRUNCATE TABLE TMP_LI_T5                  
                  
  INSERT INTO TMP_LI_T5 (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,N_AMOUNT                  
   ,ACCTNO                  
   ,MASTERID                  
   ,BRCODE                  
   ,PRDTYPE                  
   ,CF_ID                  
   )                  
  SELECT FACNO                  
   ,CIFNO                  
   ,EFFDATE                  
   ,A.DATA_SOURCE                  
   ,PRD_CODE                  
   ,TRX_CODE                  
   ,CCY                  
   ,SL_AMORT_DAILY                  
   ,A.MASTERID                  
   ,A.MASTERID                  
   ,BRCODE                  
   ,B.PRODUCT_TYPE                  
   ,ID_SL                  
  FROM IFRS_LI_ACF_SL_MSTR A                  
  JOIN IFRS_LI_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID                  
   AND A.EFFDATE = B.DOWNLOAD_DATE                  
  WHERE FLAG_CF = 'C'                  
 END                  
                  
 TRUNCATE TABLE TMP_LI_T6                  
                  
 INSERT INTO TMP_LI_T6 (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,SUM_AMT                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,SUM(N_AMOUNT) AS SUM_AMT                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
 FROM TMP_LI_T5 D                  
 GROUP BY FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,ACCTNO                  
  ,MASTERID                  
  ,BRCODE                  
                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'ACCRU_SL'                  
  ,'ACT'                  
  ,'N'         
  ,ROUND(A.N_ACCRU_COST * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20)), @V_ROUND, @V_FUNCROUND)             
  ,CURRENT_TIMESTAMP                  
  ,'SL ACCRU COST 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'C'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'N'                  
                  
 --AMORT COST                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,A.N_ACCRU_COST * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20))                  
  ,CURRENT_TIMESTAMP                  
  ,'SL AMORT COST 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'C'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'Y'                  
                  
 --STOP REV DEFA0 COST 20160619                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE              
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                 
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,B.PRDCODE                  
  ,B.TRXCODE                  
  ,B.CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'N'                  
  ,- 1 * A.N_ACCRU_COST * CAST(CAST(B.N_AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS DECIMAL(32, 20))                  
  ,CURRENT_TIMESTAMP                  
  ,'SL AMORT COST 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,'C'                  
  ,B.BRCODE                  
  ,B.PRDTYPE                  
  ,'ITRCG_SL'                  
  ,B.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN TMP_LI_T5 B ON B.DOWNLOAD_DATE = A.ECFDATE                  
  AND B.MASTERID = A.MASTERID                  
 JOIN TMP_LI_T6 C ON C.MASTERID = A.MASTERID                  
  AND A.ECFDATE = C.DOWNLOAD_DATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'Y'                  
  -- STOP REV                  
  AND A.MASTERID IN (                  
   SELECT MASTERID                  
   FROM IFRS_LI_ACCT_SL_STOP_REV                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE             
   )                  
                  
 -- 20160407 DANIEL S : SET BLK BEFORE ACCRU PREV CODE                  
 -- UPDATE STATUS ACCRU PREV FOR SL STOP REV                  
 UPDATE IFRS_LI_ACCT_SL_ACCRU_PREV                  
 SET IFRS_LI_ACCT_SL_ACCRU_PREV.STATUS = CONVERT(VARCHAR, @V_CURRDATE, 112) + 'BLK'                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN IFRS_LI_ACCT_SL_STOP_REV E ON E.DOWNLOAD_DATE = @V_CURRDATE                  
  AND E.MASTERID = A.MASTERID                  
 JOIN IFRS_LI_ACCT_SL_ACCRU_PREV C ON C.MASTERID = A.MASTERID                  
  AND C.STATUS = 'ACT'                  
  AND C.DOWNLOAD_DATE <= @V_CURRDATE                  
 WHERE A.DOWNLOAD_DATE = @V_PREVDATE                  
                  
 --SL ACCRU PREV                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE              
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,C.PRDCODE                  
  ,C.TRXCODE                  
  ,C.CCY                  
  ,'ACCRU_SL'                  
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN C.FLAG_REVERSE = 'Y'                  
    THEN - 1 * C.AMOUNT                  
   ELSE C.AMOUNT                  
   END                  
  ,CURRENT_TIMESTAMP                  
  ,'SL ACCRU PREV'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,C.FLAG_CF                  
  ,A.BRANCH                  
  ,C.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,C.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN IFRS_LI_ACCT_SL_ACCRU_PREV C ON C.MASTERID = A.MASTERID                  
  AND C.STATUS = 'ACT'                  
  AND C.DOWNLOAD_DATE <= @V_CURRDATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'N'                  
             
 --SL AMORT PREV                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,C.PRDCODE                  
  ,C.TRXCODE                  
  ,C.CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN C.FLAG_REVERSE = 'Y'                  
    THEN - 1 * C.AMOUNT                  
   ELSE C.AMOUNT                  
   END                  
  ,CURRENT_TIMESTAMP                  
  ,'SL AMORT PREV'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,C.FLAG_CF                  
  ,A.BRANCH                  
  ,C.PRDTYPE                  
  ,'ACCRU_SL'                  
  ,C.CF_ID                  
 FROM IFRS_LI_ACCT_SL_ACF A                  
 JOIN IFRS_LI_ACCT_SL_ACCRU_PREV C ON C.MASTERID = A.MASTERID          AND C.STATUS = CONVERT(VARCHAR(8), @V_CURRDATE, 112)                  
  AND C.DOWNLOAD_DATE <= @V_CURRDATE                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.DO_AMORT = 'Y'                  
  --20180808 MUST NOT INCLUDE SWITCH ACCT                  
  AND A.MASTERID NOT IN (                  
   SELECT PREV_MASTERID                  
   FROM IFRS_LI_ACCT_SWITCH                  
   WHERE DOWNLOAD_DATE = @V_CURRDATE                  
   )                  
                  
 --SL SWITCH AMORT OF ACCRU PREV                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.PREV_FACNO                  
  ,A.PREV_CIFNO                  
  ,A.DOWNLOAD_DATE                  
  ,A.PREV_DATASOURCE                  
  ,A.PREV_PRDCODE                  
  ,--20180808 USE PREV PRD CODE                  
  C.TRXCODE                  
  ,C.CCY                  
  ,'AMORT'                  
  ,'ACT'                  
  ,'N'                  
  ,CASE                   
   WHEN C.FLAG_REVERSE = 'Y'                  
    THEN - 1 * C.AMOUNT                  
   ELSE C.AMOUNT                  
   END                  
  ,CURRENT_TIMESTAMP                 
  ,'SL ACRU SW'                  
  ,A.PREV_ACCTNO                  
  ,A.PREV_MASTERID                  
  ,C.FLAG_CF                  
  ,A.PREV_BRCODE                  
  ,A.PREV_PRDTYPE                  
  ,--20180808 USE PREV PRD TYPE                  
  'ACCRU_SL'                  
  ,C.CF_ID                  
 FROM IFRS_LI_ACCT_SWITCH A                  
 JOIN IFRS_LI_ACCT_SL_ACCRU_PREV C ON C.MASTERID = A.PREV_MASTERID                  
  AND C.STATUS = CONVERT(VARCHAR(8), @V_CURRDATE, 112)                  
  --AND C.DOWNLOAD_DATE = @V_CURRDATE                  
  AND C.DOWNLOAD_DATE <= @V_CURRDATE --20180411 MUST EMIT INTM FOR ACCRU PREV <= @CURRDATE WITH OLD BRANCH                  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
  AND A.PREV_SL_ECF = 'Y'                  
                  
 -- REV = DEFA0 REV OF UNAMORT BY CURRDATE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'Y'                  
  ,1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL_REV_SWITCH'           
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF          
  ,BRCODE                  
  ,PRDTYPE                  
  ,'ITRCG_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
  AND STATUS = 'REV'  AND CREATEDBY = 'SL_SWITCH'                   
                  
 -- REV2 = REV DEFA0 OF UNAMORT BY PREVDATE                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,@V_CURRDATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'Y'                  
  ,1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL_REV_SWITCH'               
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,PRDTYPE                  
  ,'ITRCG_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV                  
 WHERE DOWNLOAD_DATE = @V_PREVDATE                  
  AND STATUS = 'REV2' AND CREATEDBY = 'SL_SWITCH'                    
                  
 -- DEFA0 FOR NEW ACCT OF SL SWITCH                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,@V_CURRDATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'N'                  
  ,1 * (                  
   CASE                   
    WHEN FLAG_REVERSE = 'Y'                  
     THEN - 1 * AMOUNT                  
    ELSE AMOUNT                  
    END                  
   )                  
  ,CURRENT_TIMESTAMP                  
  ,'SL_SWITCH'                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,PRDTYPE                  
  ,'ITRCG_SL'                  
  ,CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND STATUS = 'ACT'                  
  AND SEQ = '0'                  
                  
 ----JOURNAL SL SWITCH NO ECF                  
 IF @SL_METHOD = 'NO_ECF'                  
 BEGIN                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY      
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO                  
  ,CIFNO                  
  ,@V_CURRDATE                  
  ,A.DATA_SOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'Y'                  
  ,UNAMORT_VALUE                  
  ,CURRENT_TIMESTAMP                  
  ,'SL_SWITCH'                  
  ,A.MASTERID                  
  ,A.MASTERID                  
  ,FLAG_CF                  
  ,BRCODE                  
  ,B.PRODUCT_TYPE                  
  ,'ITRCG_SL'                  
  ,ID_SL                 
 FROM IFRS_LI_ACF_SL_MSTR A                  
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID                  
  AND A.EFFDATE = B.DOWNLOAD_DATE                  
 WHERE EFFDATE = @V_PREVDATE                  
  AND IFRS_STATUS = 'ACT'                  
  AND A.MASTERID IN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACF_SL_MSTR                  
   WHERE EFFDATE = @V_CURRDATE                  
    AND IFRS_STATUS = 'SWC'                  
   )                  
                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT FACNO               
  ,CIFNO                  
  ,@V_CURRDATE                  
  ,A.DATA_SOURCE                  
  ,PRD_CODE                  
  ,TRX_CODE                  
  ,CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'N'                  
  ,UNAMORT_VALUE                  
  ,CURRENT_TIMESTAMP                  
  ,'SL_SWITCH'                  
  ,A.MASTERID                  
  ,A.MASTERID                  
  ,FLAG_CF                  
  ,B.BRANCH_CODE                  
  ,B.PRODUCT_TYPE                  
  ,'ITRCG_SL'                  
  ,ID_SL                  
 FROM IFRS_LI_ACF_SL_MSTR A                  
 JOIN IFRS_LI_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID                  
 WHERE EFFDATE = @V_PREVDATE                  
  AND B.DOWNLOAD_DATE = @V_CURRDATE                  
  AND IFRS_STATUS = 'ACT'                  
  AND A.MASTERID IN (                  
   SELECT DISTINCT MASTERID                  
   FROM IFRS_LI_ACF_SL_MSTR                  
   WHERE EFFDATE = @V_CURRDATE                  
    AND IFRS_STATUS = 'SWC'                  
   )           
 END                  
                  
 -- 20160407 SL STOP REVERSE                  
 -- BEFORE SL ACF RUN                  
 -- REVERSE UNAMORTIZED AND AMORT ACCRU IF EXIST                  
 -- UNAMORTIZED MAY BE USED BY OTHER PROCESS                  
 INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
  FACNO                  
  ,CIFNO                  
  ,DOWNLOAD_DATE                  
  ,DATASOURCE                  
  ,PRDCODE                  
  ,TRXCODE                  
  ,CCY                  
  ,JOURNALCODE                  
  ,STATUS                  
  ,REVERSE                  
  ,N_AMOUNT                  
  ,CREATEDDATE                  
  ,SOURCEPROCESS                  
  ,ACCTNO                  
  ,MASTERID                  
  ,FLAG_CF                  
  ,BRANCH                  
  ,PRDTYPE                  
  ,JOURNALCODE2                  
  ,CF_ID                  
  )                  
 SELECT A.FACNO                  
  ,A.CIFNO                  
  ,@V_CURRDATE AS DOWNLOAD_DATE                  
  ,A.DATASOURCE                  
  ,A.PRDCODE                  
  ,A.TRXCODE                  
  ,A.CCY                  
  ,'DEFA0'                  
  ,'ACT'                  
  ,'Y'                  
  ,CASE                   
   WHEN FLAG_REVERSE = 'Y'                  
    THEN - 1 * AMOUNT                  
   ELSE AMOUNT                  
   END                  
  ,CURRENT_TIMESTAMP                  
  ,'SL STOP REV 1'                  
  ,A.ACCTNO                  
  ,A.MASTERID                  
  ,A.FLAG_CF                  
,A.BRCODE                  
  ,A.PRDTYPE                  
  ,'ITRCG_SL'                  
  ,A.CF_ID                  
 FROM IFRS_LI_ACCT_SL_COST_FEE_PREV A -- 20130722 ADD JOIN COND TO PICK LATEST CF PREV                  
 JOIN VW_LI_LAST_SL_CF_PREV_YEST C ON C.MASTERID = A.MASTERID                  
  AND C.DOWNLOAD_DATE = A.DOWNLOAD_DATE                  
  AND ISNULL(C.SEQ, '') = ISNULL(A.SEQ, '')                  
 JOIN IFRS_LI_ACCT_SL_STOP_REV B ON B.DOWNLOAD_DATE = @V_CURRDATE                  
  AND B.MASTERID = A.MASTERID                  
 WHERE A.DOWNLOAD_DATE = @V_PREVDATE                  
  AND A.STATUS = 'ACT'                  
                  
 -- 20160407 AMORT YESTERDAY ACCRU                  
 -- BLOCK ACCRU PREV GENERATION ON SL_ECF                  
 PRINT CONVERT(VARCHAR, GETDATE(), 113) + ' START SP_FAC_JOURNAL_INTM SL STOP REV 19'                  
                  
 IF @PARAM_DISABLE_ACCRU_PREV = 0                  
 BEGIN                  
  INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,JOURNALCODE                  
   ,STATUS                  
   ,REVERSE                  
   ,N_AMOUNT                  
   ,CREATEDDATE                  
   ,SOURCEPROCESS                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,BRANCH                  
   ,PRDTYPE                  
   ,JOURNALCODE2                  
   ,CF_ID                  
   )                  
  SELECT [FACNO]                  
   ,[CIFNO]                  
   ,@V_CURRDATE                  
   ,[DATASOURCE]                  
   ,[PRDCODE]                  
   ,[TRXCODE]                  
   ,[CCY]                  
   ,'AMORT'                  
   ,[STATUS]                  
   ,'N'                  
   ,[N_AMOUNT]                  
   ,CURRENT_TIMESTAMP                  
   ,'SL STOP REV 2'                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,BRANCH                  
   ,PRDTYPE                  
   ,'ACCRU_SL'                  
   ,CF_ID                  
  FROM IFRS_LI_ACCT_JOURNAL_INTM                  
  WHERE DOWNLOAD_DATE = @V_PREVDATE                  
   AND STATUS = 'ACT'                  
   AND JOURNALCODE = 'ACCRU_SL'                  
   AND REVERSE = 'N'                  
   AND SUBSTRING(SOURCEPROCESS, 1, 2) = 'SL'                  
   AND MASTERID IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_SL_STOP_REV                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    )                  
 END                  
 ELSE                  
 BEGIN                  
  INSERT INTO IFRS_LI_ACCT_JOURNAL_INTM (                  
   FACNO                  
   ,CIFNO                  
   ,DOWNLOAD_DATE                  
   ,DATASOURCE                  
   ,PRDCODE                  
   ,TRXCODE                  
   ,CCY                  
   ,JOURNALCODE                  
   ,STATUS                  
   ,REVERSE                  
   ,N_AMOUNT                  
   ,CREATEDDATE                  
   ,SOURCEPROCESS                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,BRANCH                  
   ,PRDTYPE                  
   ,JOURNALCODE2                  
   ,CF_ID                  
   )                  
  SELECT [FACNO]                  
   ,[CIFNO]                  
   ,@V_CURRDATE                  
   ,[DATASOURCE]                  
   ,[PRDCODE]                  
   ,[TRXCODE]                  
   ,[CCY]                  
   ,'DEFA0'                  
   ,[STATUS]                  
   ,'Y'                  
   ,- 1 * [N_AMOUNT]                  
   ,CURRENT_TIMESTAMP                  
   ,'SL STOP REV 2'                  
   ,ACCTNO                  
   ,MASTERID                  
   ,FLAG_CF                  
   ,BRANCH                  
   ,PRDTYPE                  
   ,'ITRCG_SL'                  
   ,CF_ID                  
  FROM IFRS_LI_ACCT_JOURNAL_INTM                  
  WHERE DOWNLOAD_DATE = @V_PREVDATE                  
   AND STATUS = 'ACT'                  
   AND JOURNALCODE = 'ACCRU_SL'                  
   AND REVERSE = 'N'                  
   AND SUBSTRING(SOURCEPROCESS, 1, 2) = 'SL'                  
   AND MASTERID IN (                  
    SELECT MASTERID                  
    FROM IFRS_LI_ACCT_SL_STOP_REV                  
    WHERE DOWNLOAD_DATE = @V_CURRDATE                  
    )                  
 END                  
                  
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
  ,'SP_IFRS_LI_ACCT_SL_JOURNAL_INTM'                  
  ,''                  
  )                  
END   
GO
