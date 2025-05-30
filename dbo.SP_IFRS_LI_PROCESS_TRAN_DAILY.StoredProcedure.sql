USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_PROCESS_TRAN_DAILY]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_PROCESS_TRAN_DAILY]    
AS    
DECLARE @V_CURRDATE DATE    
 ,@V_PREVDATE DATE    
    
BEGIN    
 SELECT @V_CURRDATE = MAX(CURRDATE)    
  ,@V_PREVDATE = MAX(PREVDATE)    
 FROM IFRS_LI_PRC_DATE_AMORT    
    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,''    
  );    
    
 --DELETE FIRST      
 DELETE    
 FROM IFRS_LI_ACCT_COST_FEE    
 WHERE DOWNLOAD_DATE >= @V_CURRDATE    
    
 -- FEE & COST      
 INSERT INTO IFRS_LI_ACCT_COST_FEE (    
  DOWNLOAD_DATE    
  ,MASTERID    
  ,BRCODE    
  ,CIFNO    
  ,FACNO    
  ,ACCTNO    
  ,DATASOURCE    
  ,PRD_TYPE    
  ,PRD_CODE    
  ,TRX_CODE    
  ,CCY    
  ,FLAG_CF    
  ,FLAG_REVERSE    
  ,METHOD    
  ,STATUS    
  ,SRCPROCESS    
  ,AMOUNT               
  ,INITIAL_AMOUNT -- TAMBAH INFORMASI INITIAL AMOUNT & TAX UNTUK LIAB 20180824          
  ,TAX_AMOUNT              
  ,ISTAX_INCLUDE          
  ,CREATEDDATE    
  ,CREATEDBY    
  ,TRX_REFF_NUMBER    
  ,SOURCE_TABLE    
  ,TRX_LEVEL    
  )    
 SELECT A.DOWNLOAD_DATE EFFDATE    
  ,A.MASTERID MASTERID    
  ,A.BRANCH_CODE BRCODE    
  ,NULL CIFNO    
  ,A.FACILITY_NUMBER FACNO    
  ,A.ACCOUNT_NUMBER ACCTNO    
  ,B.DATA_SOURCE DATASOURCE    
  ,A.PRD_TYPE    
  ,A.PRD_CODE    
  ,A.TRX_CODE    
  ,A.CCY CCY    
  ,SUBSTRING(COALESCE(B.IFRS_TXN_CLASS, 'F'), 1, 1) FLAG_CF    
  ,SUBSTRING(COALESCE(A.DEBET_CREDIT_FLAG, 'X'), 1, 1) FLAG_REVERSE    
  ,'X' METHOD    
  ,'ACT' STATUS    
  ,'TRAN_DAILY' SRCPROCESS          
  ,A.ORG_CCY_AMT +          
 CASE WHEN A.ISTAX_INCLUDE  = 0               
    THEN A.ORG_CCY_AMT *  (CAST(A.TAX_PERCENTAGE  AS FLOAT) / 100)          
    ELSE 0              
    END             
  , CASE WHEN A.ISTAX_INCLUDE  = 0       -- TAMBAH INFORMASI INITIAL AMOUNT & TAX UNTUK LIAB 20180824           
  THEN A.ORG_CCY_AMT          
  ELSE A.ORG_CCY_AMT * (CAST (100 AS FLOAT) - A.TAX_PERCENTAGE)/100              
    END    -- INITIAL AMOUNT        
  ,A.ORG_CCY_AMT *  (CAST(A.TAX_PERCENTAGE  AS FLOAT) / 100)  -- TAX AMOUNT         
  ,ISTAX_INCLUDE          
  ,CURRENT_TIMESTAMP CREATEDDATE    
  ,'SP_IFRS_TRAN_DAILY' CREATEDBY    
  ,TRX_REFERENCE_NUMBER    
  ,SOURCE_TABLE    
  ,TRX_LEVEL    
 FROM IFRS_LI_TRANSACTION_DAILY A    
 JOIN (    
  SELECT DISTINCT DATA_SOURCE    
   ,PRD_TYPE
   ,PRD_CODE    
   ,TRX_CODE    
   ,CCY    
   ,IFRS_TXN_CLASS    
  FROM IFRS_LI_TRANSACTION_PARAM    
  WHERE IFRS_TXN_CLASS IN ('FEE', 'COST')    
   AND AMORTIZATION_FLAG = 'Y'    
  ) B ON --(B.DATA_SOURCE = A.DATA_SOURCE OR ISNULL(B.DATA_SOURCE, 'ALL') = 'ALL')    
  --AND (B.PRD_TYPE = A.PRD_TYPE OR ISNULL(B.PRD_TYPE, 'ALL') = 'ALL' OR ISNULL(A.PRD_TYPE, 'ALL') = 'ALL')    
  (B.PRD_CODE = A.PRD_CODE OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL' OR ISNULL(A.PRD_CODE, 'ALL') = 'ALL')    
  AND B.TRX_CODE = A.TRX_CODE    
  AND (B.CCY = A.CCY OR B.CCY = 'ALL' OR A.CCY = 'ALL')    
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE    
                
 /*20171129 INSERT FROM COST FEE UNPROCESSED FROM PREVDATE*/    
 INSERT INTO IFRS_LI_ACCT_COST_FEE (    
  DOWNLOAD_DATE    
  ,MASTERID    
  ,BRCODE    
  ,CIFNO    
  ,FACNO    
  ,ACCTNO    
  ,DATASOURCE    
  ,PRD_TYPE    
  ,PRD_CODE    
  ,TRX_CODE    
  ,CCY    
  ,FLAG_CF    
  ,FLAG_REVERSE    
  ,METHOD    
  ,STATUS    
  ,SRCPROCESS    
  ,AMOUNT               
  ,INITIAL_AMOUNT -- TAMBAH INFORMASI INITIAL AMOUNT & TAX UNTUK LIAB 20180824          
  ,TAX_AMOUNT              
  ,ISTAX_INCLUDE               
  ,CREATEDDATE    
  ,CREATEDBY    
  ,TRX_REFF_NUMBER    
  ,SOURCE_TABLE    
  ,TRX_LEVEL    
  )    
 SELECT @V_CURRDATE    
  ,MASTERID    
  ,BRCODE    
  ,CIFNO    
  ,FACNO    
  ,ACCTNO    
  ,DATASOURCE    
  ,PRD_TYPE    
  ,PRD_CODE    
  ,TRX_CODE    
  ,CCY    
  ,FLAG_CF    
  ,CASE     
   WHEN FLAG_AL = 'A'    
    THEN --ASSETS      
     CASE     
      WHEN FLAG_CF = 'F'    
       THEN CASE     
         WHEN FLAG_REVERSE = 'N'    
          THEN 'C'    
         ELSE 'D'    
         END    
      ELSE CASE     
        WHEN FLAG_REVERSE = 'N'    
         THEN 'D'    
        ELSE 'C'    
        END    
      END                 
   ELSE --LIAB      
    CASE     
     WHEN FLAG_CF = 'F'    
      THEN CASE     
        WHEN FLAG_REVERSE = 'N'    
         THEN 'C'    
        ELSE 'Y'    
        END    
     ELSE CASE     
       WHEN FLAG_REVERSE = 'N'    
        THEN 'D'    
       ELSE 'C'    
       END    
     END    
   END AS FLAG_REVERSE    
  ,METHOD    
  ,'ACT'    
  ,SRCPROCESS    
  ,AMOUNT               
  ,INITIAL_AMOUNT  -- TAMBAH INFORMASI INITIAL AMOUNT & TAX UNTUK LIAB 20180824          
  ,TAX_AMOUNT          
  ,ISTAX_INCLUDE                
  ,CREATEDDATE    
  ,CREATEDBY    
  ,TRX_REFF_NUMBER    
  ,SOURCE_TABLE    
  ,TRX_LEVEL    
 FROM IFRS_LI_ACCT_COST_FEE    
 WHERE DOWNLOAD_DATE = @V_PREVDATE    
  AND STATUS = 'NPRCD'    
      
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,'INSERTED'    
  );    
    
 -- UPDATE INFO FROM IMA_CURR      
 /* FD 30042018: UPDATE SET DATA SOURCE DISINI JUGA, WHERE NYA HANYA BY MASTERID SAJA */    
 UPDATE IFRS_LI_ACCT_COST_FEE    
 SET CIFNO = B.CUSTOMER_NUMBER    
  ,PRD_CODE = B.PRODUCT_CODE    
  ,PRD_TYPE = B.PRODUCT_TYPE    
  ,DATASOURCE = B.DATA_SOURCE    
  ,BRCODE = B.BRANCH_CODE    
  ,FACNO = B.FACILITY_NUMBER    
 FROM IFRS_LI_IMA_AMORT_CURR B    
 WHERE B.MASTERID = IFRS_LI_ACCT_COST_FEE.MASTERID    
  --AND B.DATA_SOURCE = IFRS_LI_ACCT_COST_FEE.DATASOURCE      
  AND IFRS_LI_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE    
    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,'UPD FROM IMA'    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,'UPD FROM TRAN PARAM'    
  )    
    
 -- UPDATE FLAG_AL       
 UPDATE IFRS_LI_ACCT_COST_FEE    
 SET FLAG_AL = COALESCE(B.FLAG_AL, 'L')    
 FROM IFRS_LI_PRODUCT_PARAM B        
 WHERE (B.DATA_SOURCE = IFRS_LI_ACCT_COST_FEE.DATASOURCE OR ISNULL(B.DATA_SOURCE, 'ALL') = 'ALL')    
  --AND (B.PRD_TYPE = IFRS_LI_ACCT_COST_FEE.PRD_TYPE OR ISNULL(B.PRD_TYPE, 'ALL') = 'ALL')    
  AND (B.PRD_CODE = IFRS_LI_ACCT_COST_FEE.PRD_CODE OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL')    
  AND (B.CCY = IFRS_LI_ACCT_COST_FEE.CCY OR ISNULL(B.CCY, 'ALL') = 'ALL')    
  AND IFRS_LI_ACCT_COST_FEE.SRCPROCESS = 'TRAN_DAILY'    
  AND IFRS_LI_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE    
    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,'UPD FROM PROD PARAM'    
  );    
    
 --UPDATE AMOUNT AND REV FLAG      
 UPDATE IFRS_LI_ACCT_COST_FEE    
 SET AMOUNT = CASE     
   WHEN FLAG_AL = 'A'    
    THEN CASE     
      WHEN FLAG_CF = 'F'    
       THEN - 1 * AMOUNT    
      ELSE AMOUNT    
      END    
   ELSE CASE     
     WHEN FLAG_CF = 'C'    
      THEN - 1 * AMOUNT    
     ELSE AMOUNT    
     END    
   END           
  ,INITIAL_AMOUNT = CASE     
   WHEN FLAG_AL = 'A'    
    THEN CASE     
      WHEN FLAG_CF = 'F'    
       THEN - 1 * INITIAL_AMOUNT    
      ELSE INITIAL_AMOUNT    
      END    
   ELSE CASE     
     WHEN FLAG_CF = 'C'    
      THEN - 1 * INITIAL_AMOUNT    
     ELSE INITIAL_AMOUNT    
     END    
   END            
  ,TAX_AMOUNT = CASE                
   WHEN FLAG_AL = 'A'    
    THEN CASE     
      WHEN FLAG_CF = 'F'    
       THEN - 1 * TAX_AMOUNT    
      ELSE TAX_AMOUNT    
      END    
   ELSE CASE     
     WHEN FLAG_CF = 'C'    
      THEN - 1 * TAX_AMOUNT    
     ELSE TAX_AMOUNT    
     END    
   END     
  ,FLAG_REVERSE = CASE     
   WHEN FLAG_AL = 'A'    
    THEN --ASSETS      
     CASE     
      WHEN FLAG_CF = 'F'    
       THEN CASE     
         WHEN FLAG_REVERSE = 'C'    
          THEN 'N'    
         ELSE 'Y'    
         END    
      ELSE CASE     
        WHEN FLAG_REVERSE = 'D'    
         THEN 'N'    
        ELSE 'Y'    
        END    
      END    
   ELSE --LIAB      
    CASE     
  WHEN FLAG_CF = 'F'    
      THEN CASE     
        WHEN FLAG_REVERSE = 'C'    
         THEN 'N'    
        ELSE 'Y'    
        END    
     ELSE CASE     
       WHEN FLAG_REVERSE = 'D'    
        THEN 'N'    
       ELSE 'Y'    
       END    
     END    
   END    
 WHERE DOWNLOAD_DATE = @V_CURRDATE    
  AND STATUS = 'ACT'    
  AND SRCPROCESS = 'TRAN_DAILY'    
    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,'UPD AMT REV'    
  );    
    
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
  ,'SP_IFRS_LI_PROCESS_TRAN_DAILY'    
  ,''    
  )    
END 
GO
