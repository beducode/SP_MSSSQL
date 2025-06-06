USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_PROCESS_TRAN_DAILY]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_PROCESS_TRAN_DAILY]              
AS              
DECLARE @V_CURRDATE DATE              
 ,@V_PREVDATE DATE              
              
BEGIN              
 SELECT @V_CURRDATE = MAX(CURRDATE)              
  ,@V_PREVDATE = MAX(PREVDATE)              
 FROM IFRS_PRC_DATE_AMORT              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'              
  ,''              
  );          


   --DELETE FIRST                
 DELETE              
 FROM IFRS_ACCT_COST_FEE              
 WHERE DOWNLOAD_DATE >= @V_CURRDATE       
          
/*
----- AUTO INSERT DUMMY TRANSACTION PREPAYMENT FOR EXPECTED LIFE ------          
---- DISABLE EXPECTED LIFE RECALCULATION FOR BTPN 20190527 
DELETE  IFRS_TRANSACTION_DAILY WHERE DOWNLOAD_DATE = @V_CURRDATE AND TRX_CODE = 'PREPAYMENT'         
        
INSERT INTO IFRS_TRANSACTION_DAILY (DOWNLOAD_DATE        
,EFFECTIVE_DATE        
,MATURITY_DATE        
,MASTERID        
,ACCOUNT_NUMBER        
,FACILITY_NUMBER        
,CUSTOMER_NUMBER        
,BRANCH_CODE        
,DATA_SOURCE        
,PRD_TYPE        
,PRD_CODE        
,TRX_CODE        
,CCY        
,EVENT_CODE        
,TRX_REFERENCE_NUMBER        
,ORG_CCY_AMT        
,EQV_LCY_AMT        
,DEBET_CREDIT_FLAG        
,TRX_SOURCE        
,INTERNAL_NO        
,REVOLVING_FLAG        
,CREATED_DATE        
,SOURCE_TABLE        
,TRX_LEVEL)        
SELECT DOWNLOAD_DATE        
,DOWNLOAD_DATE AS EFFECTIVE_DATE        
,DOWNLOAD_DATE AS MATURITY_DATE        
,MASTERID        
,ACCOUNT_NUMBER        
,FACILITY_NUMBER        
,CUSTOMER_NUMBER        
,BRANCH_CODE        
,A.DATA_SOURCE        
,PRD_TYPE        
,PRD_CODE        
,'PREPAYMENT' AS TRX_CODE        
,CCY        
,NULL AS EVENT_CODE        
,NULL AS TRX_REFERENCE_NUMBER        
,0 AS ORG_CCY_AMT        
,0 AS EQV_LCY_AMT        
,'C' AS DEBET_CREDIT_FLAG        
,NULL AS TRX_SOURCE        
,NULL AS INTERNAL_NO        
,A.REVOLVING_FLAG        
,GETDATE() AS CREATED_DATE        
,'SP_IFRS_PROCESS_TRAN_DAILY' SOURCE_TABLE        
,NULL AS TRX_LEVEL FROM IFRS_IMA_AMORT_CURR A INNER JOIN         
(SELECT * FROM IFRS_MASTER_PRODUCT_PARAM WHERE TENOR_TYPE = 'E' AND EXP_LIFE <> 0 AND IS_DELETE =0) B        
  ON   A.PRODUCT_CODE = B.PRD_CODE AND DATEADD(MONTH,EXP_LIFE,A.LOAN_START_DATE) = @V_CURRDATE        
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE AND OUTSTANDING > 0        
       
----- AUTO INSERT DUMMY TRANSACTION PREPAYMENT FOR EXPECTED LIFE ------         
---- DISABLE EXPECTED LIFE RECALCULATION FOR BTPN 20190527
 */      
       
---------------------------------INSERT FOR RESTRUCTURE ACCOUNT AS TRANSACTION-----------------------------------------      
INSERT INTO IFRS_ACCT_COST_FEE (            
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
  ,CREATEDDATE              
  ,CREATEDBY              
  ,TRX_REFF_NUMBER              
  ,SOURCE_TABLE              
  ,TRX_LEVEL             
  )            
   ---- UNAMORT FEE RESTRU ------       
 SELECT A.DOWNLOAD_DATE EFFDATE              
  ,A.MASTERID MASTERID              
  ,A.BRANCH_CODE BRCODE              
  ,A.CUSTOMER_NUMBER CIFNO              
  ,A.FACILITY_NUMBER FACNO              
  ,A.ACCOUNT_NUMBER ACCTNO              
  ,A.DATA_SOURCE DATASOURCE              
  ,A.PRODUCT_TYPE              
  ,A.PRODUCT_CODE              
  ,'RESTRU' AS TRX_CODE              
  ,A.CURRENCY CCY              
  ,'F' AS  FLAG_CF              
  ,'N' AS FLAG_REVERSE              
  ,A.AMORT_TYPE METHOD              
  ,'ACT' STATUS              
  ,'RESTRU' SRCPROCESS              
  ,B.PRORATE_UNAMORT_FEE AS AMOUNT              
  ,CURRENT_TIMESTAMP CREATEDDATE              
  ,'SP_IFRS_TRAN_DAILY' CREATEDBY              
  ,'RESTRU - '+B.PREV_MASTERID AS TRX_REFERENCE_NUMBER              
  ,'IFRS_ACCT_AMORT_RESTRU' SOURCE_TABLE              
  ,NULL AS TRX_LEVEL          
   FROM IFRS_IMA_AMORT_CURR A       
INNER JOIN [dbo].[IFRS_ACCT_AMORT_RESTRU] B ON A.MASTERID = B.MASTERID AND B.DOWNLOAD_DATE = @V_CURRDATE      
      
UNION ALL      
      
   ---- UNAMORT COST RESTRU ------       
 SELECT A.DOWNLOAD_DATE EFFDATE              
  ,A.MASTERID MASTERID              
  ,A.BRANCH_CODE BRCODE              
  ,A.CUSTOMER_NUMBER CIFNO              
  ,A.FACILITY_NUMBER FACNO              
  ,A.ACCOUNT_NUMBER ACCTNO              
  ,A.DATA_SOURCE DATASOURCE              
  ,A.PRODUCT_TYPE              
  ,A.PRODUCT_CODE              
  ,'RESTRU' AS TRX_CODE              
  ,A.CURRENCY CCY              
  ,'C' AS  FLAG_CF              
  ,'N' AS FLAG_REVERSE              
  ,A.AMORT_TYPE METHOD              
  ,'ACT' STATUS              
  ,'RESTRU' SRCPROCESS              
  ,B.PRORATE_UNAMORT_FEE AS AMOUNT              
  ,CURRENT_TIMESTAMP CREATEDDATE              
  ,'SP_IFRS_TRAN_DAILY' CREATEDBY              
  ,'RESTRU - '+B.PREV_MASTERID AS TRX_REFERENCE_NUMBER              
  ,'IFRS_ACCT_AMORT_RESTRU' SOURCE_TABLE              
  ,NULL AS TRX_LEVEL        
  FROM IFRS_IMA_AMORT_CURR A       
INNER JOIN [dbo].[IFRS_ACCT_AMORT_RESTRU] B ON A.MASTERID = B.MASTERID AND B.DOWNLOAD_DATE = @V_CURRDATE      
      
      
-------------------------------END RESTRUCTURE ACCOUNT ---------------------------------------------------------------------      
              
              
       
              
 -- FEE & COST                
 INSERT INTO IFRS_ACCT_COST_FEE (            
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
  ,A.DATA_SOURCE DATASOURCE              
  ,A.PRD_TYPE              
  ,A.PRD_CODE              
  ,A.TRX_CODE              
  ,A.CCY CCY              
  ,SUBSTRING(COALESCE(B.IFRS_TXN_CLASS, 'F'), 1, 1) FLAG_CF              
  ,SUBSTRING(COALESCE(A.DEBET_CREDIT_FLAG, 'X'), 1, 1) FLAG_REVERSE              
  ,'X' METHOD              
  ,'ACT' STATUS              
  ,'TRAN_DAILY' SRCPROCESS              
  ,A.ORG_CCY_AMT AS AMOUNT              
  ,CURRENT_TIMESTAMP CREATEDDATE              
  ,'SP_IFRS_TRAN_DAILY' CREATEDBY              
  ,TRX_REFERENCE_NUMBER              
  ,SOURCE_TABLE              
  ,TRX_LEVEL          
 FROM IFRS_TRANSACTION_DAILY A              
 JOIN (              
  SELECT DISTINCT DATA_SOURCE              
   ,PRD_TYPE              
   ,PRD_CODE          
   ,TRX_CODE              
   ,CCY              
   ,IFRS_TXN_CLASS              
  FROM IFRS_TRANSACTION_PARAM              
  WHERE IFRS_TXN_CLASS IN (              
    'FEE'              
    ,'COST'              
    )              
   AND AMORTIZATION_FLAG = 'Y'              
  ) B ON (              
   B.DATA_SOURCE = A.DATA_SOURCE              
   OR ISNULL(B.DATA_SOURCE, 'ALL') = 'ALL'              
   )              
  AND (              
   B.PRD_TYPE = A.PRD_TYPE              
   OR ISNULL(B.PRD_TYPE, 'ALL') = 'ALL'              
   )              
  AND (              
   B.PRD_CODE = A.PRD_CODE              
   OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL'     
   )              
  AND B.TRX_CODE = A.TRX_CODE              
  AND (              
   B.CCY = A.CCY              
   OR B.CCY = 'ALL'              
   )              
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
              
 --AND A.ACCOUNT_NUMBER <> A.FACILITY_NUMBER                
 /*20171129 INSERT FROM COST FEE UNPROCESSED FROM PREVDATE*/              
 INSERT INTO IFRS_ACCT_COST_FEE (              
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
   WHEN FLAG_AL IN ('A', 'O')              
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
  ,METHOD        ,'ACT'              
  ,SRCPROCESS              
  ,AMOUNT              
  ,CREATEDDATE              
  ,CREATEDBY              
  ,TRX_REFF_NUMBER              
  ,SOURCE_TABLE              
  ,TRX_LEVEL           
 FROM IFRS_ACCT_COST_FEE              
 WHERE DOWNLOAD_DATE = @V_PREVDATE              
  AND STATUS = 'NPRCD'              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'              
  ,'INSERTED'              
  );              
              
 -- UPDATE INFO FROM IMA_CURR                
 /* FD 30042018: UPDATE SET DATA SOURCE DISINI JUGA, WHERE NYA HANYA BY MASTERID SAJA */              
 UPDATE IFRS_ACCT_COST_FEE              
 SET CIFNO = B.CUSTOMER_NUMBER              
  ,PRD_CODE = B.PRODUCT_CODE              
  ,PRD_TYPE = B.PRODUCT_TYPE              
  ,DATASOURCE = B.DATA_SOURCE              
  ,BRCODE = B.BRANCH_CODE              
  ,FACNO = B.FACILITY_NUMBER              
 FROM IFRS_IMA_AMORT_CURR B              
 WHERE B.MASTERID = IFRS_ACCT_COST_FEE.MASTERID              
  --AND B.DATA_SOURCE = IFRS_ACCT_COST_FEE.DATASOURCE                
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'             
  ,'UPD FROM IMA'              
  )              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'              
  ,'UPD FROM TRAN PARAM'              
  )              
              
 -- UPDATE FLAG_AL                 
 UPDATE IFRS_ACCT_COST_FEE              
 SET FLAG_AL = B.FLAG_AL              
 FROM IFRS_PRODUCT_PARAM B              
 WHERE (              
   B.DATA_SOURCE = IFRS_ACCT_COST_FEE.DATASOURCE              
   OR ISNULL(B.DATA_SOURCE, 'ALL') = 'ALL'              
   )              
  AND (              
   B.PRD_TYPE = IFRS_ACCT_COST_FEE.PRD_TYPE              
   OR ISNULL(B.PRD_TYPE, 'ALL') = 'ALL'              
 )              
  AND (              
   B.PRD_CODE = IFRS_ACCT_COST_FEE.PRD_CODE              
   OR ISNULL(B.PRD_CODE, 'ALL') = 'ALL'              
   )              
  AND (              
   B.CCY = IFRS_ACCT_COST_FEE.CCY              
   OR ISNULL(B.CCY, 'ALL') = 'ALL'              
   )              
  AND IFRS_ACCT_COST_FEE.SRCPROCESS = 'TRAN_DAILY'              
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'         
  ,'UPD FROM PROD PARAM'              
  );              
              
 --UPDATE AMOUNT AND REV FLAG                
 UPDATE IFRS_ACCT_COST_FEE              
 SET AMOUNT = CASE               
   WHEN FLAG_AL IN ('A', 'O')              
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
  ,FLAG_REVERSE = CASE               
   WHEN FLAG_AL IN ('A', 'O')              
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
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'              
  ,'UPD AMT REV'              
  );              
              
 INSERT INTO IFRS_AMORT_LOG (              
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
  ,'SP_IFRS_PROCESS_TRAN_DAILY'              
  ,''              
  )              
END 
GO
