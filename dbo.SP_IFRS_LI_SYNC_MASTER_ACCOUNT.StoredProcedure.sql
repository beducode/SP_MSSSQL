USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_SYNC_MASTER_ACCOUNT]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_SYNC_MASTER_ACCOUNT] AS            
BEGIN            
 DECLARE @CURRDATE DATE     
 DECLARE @PREVDATE DATE           
            
 SELECT @CURRDATE = CURRDATE, @PREVDATE = PREVDATE FROM DBO.IFRS_LI_PRC_DATE_AMORT            
             
 BEGIN TRANSACTION            
  DELETE FROM DBO.IFRS_LI_MASTER_ACCOUNT            
  WHERE DOWNLOAD_DATE >= @CURRDATE    
            
  --CREATE TEMP TABLE UNTUK PROCESS    
  SELECT A.DOWNLOAD_DATE,          
   A.IAS_CLASS,          
   A.DATA_SOURCE,            
   A.DATA_SOURCE + '_' + A.ACCOUNT_NUMBER + '_' + CONVERT(VARCHAR, B.TRANSACTION_DATE,112) + '_' + CONVERT(VARCHAR, B.TRANSACTION_REFERENCE_NUMBER) AS MASTER_ACCOUNT_CODE,            
   A.ACCOUNT_NUMBER,             
   B.PRD_CODE,            
   B.TRX_CODE,            
   A.BRANCH_CODE,            
   A.FACILITY_NUMBER,            
   A.CUSTOMER_NUMBER ,                                    
   A.CUSTOMER_NAME ,                                    
   A.GLOBAL_CUSTOMER_NUMBER ,              
   A.ACCOUNT_STATUS,            
   ISNULL(B.START_DATE,B.TRANSACTION_DATE) AS START_DATE,            
   CASE WHEN CONVERT(DATE, B.DUE_DATE) IS NULL    
  THEN DATEADD(MONTH, C.SL_EXP_LIFE, ISNULL(B.START_DATE,B.TRANSACTION_DATE))    
   ELSE B.DUE_DATE    
  END AS DUE_DATE,            
   CASE WHEN DATEADD(MONTH, 1, B.START_DATE) >= B.DUE_DATE                              
            THEN B.DUE_DATE                              
            ELSE DATEADD(MONTH, 1, B.START_DATE)                              
   END AS NEXT_PAYMENT_DATE, --ADD BY ADAM            
   A.LAST_PAYMENT_DATE,            
   B.POSTING_DATE,            
   DATEDIFF(MONTH, B.START_DATE, B.DUE_DATE) AS TENOR,            
   A.CURRENCY,            
   A.EXCHANGE_RATE,            
   A.OUTSTANDING,            
   A.INITIAL_OUTSTANDING,            
   A.PLAFOND,            
   B.HOLD_AMOUNT,            
   B.TERMINATE_FLAG,            
   B.INITIAL_COST_AMOUNT,            
   C.TXN_COST_MAT_AMT,            
   C.ORG_FEE_MAT_AMT,            
   B.DEBIT_CREDIT_FLAG,               
   A.PRODUCT_ENTITY,            
   A.PRODUCT_CODE,             
   D.PRD_TYPE,        
   A.INTEREST_RATE,              
   A.INTEREST_CALCULATION_CODE,
   C.AMORT_TYPE          
  INTO #TMP_ACC_TRANSACTION_DAILY            
  FROM IFRS_LI_MASTER A             
   INNER JOIN IFRS_LI_STG_TRANSACTION_DAILY B ON A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE  AND B.TERMINATE_FLAG = 'N'          
   INNER JOIN IFRS_MASTER_TRANS_PARAM C ON B.PRD_CODE = C.PRD_CODE AND B.TRX_CODE = C.TRX_CODE AND B.DATA_SOURCE = C.DATA_SOURCE AND C.INST_CLS_VALUE = 'L'      
   INNER JOIN IFRS_MASTER_PRODUCT_PARAM D ON B.DATA_SOURCE = D.DATA_SOURCE AND B.PRD_CODE  = D.PRD_CODE AND D.INST_CLS_VALUE = 'L'      
  WHERE A.DOWNLOAD_DATE = @CURRDATE            
  AND NOT EXISTS (SELECT TOP 1 1 FROM IFRS_LI_MASTER_ACCOUNT X     
  WHERE X.DOWNLOAD_DATE = @PREVDATE    
 AND X.MASTER_ACCOUNT_CODE =      
  A.DATA_SOURCE + '_' + A.ACCOUNT_NUMBER + '_' + CONVERT(VARCHAR, B.TRANSACTION_DATE,112) + '_' + CONVERT(VARCHAR, B.TRANSACTION_REFERENCE_NUMBER))    
              
  -- INSERT MASTER ID UNTUK ACCOUNT DUMMIES            
  INSERT INTO IFRS_MASTER_ID (MASTER_ACCOUNT_CODE, ACCOUNT_NUMBER, IAS_CLASS, EFFDATE, CREATED_DATE)            
  SELECT A.MASTER_ACCOUNT_CODE,            
   A.ACCOUNT_NUMBER,             
   'L',             
   A.DOWNLOAD_DATE ,            
   GETDATE()            
  FROM #TMP_ACC_TRANSACTION_DAILY A             
  WHERE A.DOWNLOAD_DATE = @CURRDATE            
   AND NOT EXISTS (SELECT TOP 1 1 FROM IFRS_MASTER_ID X WHERE X.MASTER_ACCOUNT_CODE =  A.MASTER_ACCOUNT_CODE)            
              
-- INSERT MASTER ACCOUNT DUMMIES            
  INSERT INTO DBO.IFRS_LI_MASTER_ACCOUNT            
  (            
  DOWNLOAD_DATE,        
  IAS_CLASS,            
  DATA_SOURCE,            
  BRANCH_CODE,        
  MASTERID,            
  MASTER_ACCOUNT_CODE,            
  ACCOUNT_NUMBER,            
  CUSTOMER_NUMBER,            
  CUSTOMER_NAME,            
  --COUNTRY_ID,            
  TENOR,            
  PRODUCT_ENTITY,            
  PRODUCT_CODE,           
  PRODUCT_TYPE,         
  CURRENCY,            
  EXCHANGE_RATE,            
  INITIAL_OUTSTANDING,            
  INTEREST_RATE,            
  OUTSTANDING,            
  ACCOUNT_STATUS,            
  LOAN_START_DATE,            
  LOAN_DUE_DATE,            
  NEXT_PAYMENT_DATE,            
  INTEREST_CALCULATION_CODE,  
  CREATEDBY,    
  CREATEDDATE    
  )            
  SELECT            
  CONVERT(DATE, A.DOWNLOAD_DATE, 112 ) AS DOWNLOAD_DATE_CONVERT,            
  A.IAS_CLASS,        
  A.DATA_SOURCE,            
  A.BRANCH_CODE,            
  B.MASTERID,            
  A.MASTER_ACCOUNT_CODE,            
  A.ACCOUNT_NUMBER,            
  A.CUSTOMER_NUMBER,            
  A.CUSTOMER_NAME,            
  --COUNTRY_ID,            
  A.TENOR,            
  A.PRODUCT_ENTITY,            
  A.PRODUCT_CODE,         
  A.PRD_TYPE,           
  A.CURRENCY,            
  A.EXCHANGE_RATE,            
  CASE WHEN A.AMORT_TYPE = 'EIR'   
 THEN A.HOLD_AMOUNT  
 ELSE A.INITIAL_OUTSTANDING  
  END,            
  A.INTEREST_RATE,            
  CASE WHEN A.AMORT_TYPE = 'EIR'   
 THEN A.HOLD_AMOUNT  
 ELSE A.OUTSTANDING  
  END,  
  A.ACCOUNT_STATUS,            
  A.START_DATE ,            
  A.DUE_DATE,            
  A.NEXT_PAYMENT_DATE,            
  A.INTEREST_CALCULATION_CODE,  
  'SYSTEM' AS CREATEDBY,    
  GETDATE() AS CREATEDDATE    
  FROM #TMP_ACC_TRANSACTION_DAILY A             
   INNER JOIN IFRS_MASTER_ID B ON A.MASTER_ACCOUNT_CODE = B.MASTER_ACCOUNT_CODE            
  WHERE A.Download_Date = @CURRDATE            
               
 COMMIT TRANSACTION             
END   
GO
