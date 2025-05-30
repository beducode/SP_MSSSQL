USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_INITIAL_UPDATE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_INITIAL_UPDATE]                                            
AS                                            
DECLARE @V_CURRDATE DATE                                            
 ,@V_PREVDATE DATE                                            
                                            
BEGIN                                            
 SELECT @V_CURRDATE = MAX(CURRDATE)                                            
  ,@V_PREVDATE = MAX(PREVDATE)                                            
 FROM IFRS_PRC_DATE_AMORT;                                            
                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,''                                            
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
  ,'DEBUG'                                            
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'UPDATE FACILITY_NUMBER & PLAFOND FROM LIMIT'                                            
  )                     
                  
 UPDATE IMA                    
 SET                    
 IMA.FACILITY_NUMBER = LIMIT.COMMITMENT_ID,                    
 IMA.PLAFOND = LIMIT.LIMIT_AMT                    
 FROM IFRS_MASTER_ACCOUNT IMA (NOLOCK)                    
 JOIN                     
 (                    
  SELECT DOWNLOAD_DATE, ACCOUNT_NUMBER, COMMITMENT_ID, LIMIT_AMT                     
  FROM IFRS_MASTER_LIMIT LIMIT (NOLOCK)                     
 ) LIMIT                    
 ON IMA.DOWNLOAD_DATE = LIMIT.DOWNLOAD_DATE                    
 AND IMA.ACCOUNT_NUMBER = LIMIT.ACCOUNT_NUMBER                    
 WHERE IMA.DOWNLOAD_DATE = @V_CURRDATE                                       
                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'UPDATE IMP FIELD FROM PREVDATE'                                            
  )                                            
                                            
 UPDATE A                                            
 SET                          
   A.ECL_AMOUNT = B.ECL_AMOUNT                                            
  ,A.CA_UNWINDING_AMOUNT = B.CA_UNWINDING_AMOUNT                                            
  ,A.IA_UNWINDING_AMOUNT = B.IA_UNWINDING_AMOUNT                                            
  ,A.BEGINNING_BALANCE = B.BEGINNING_BALANCE                                            
  ,A.CHARGE_AMOUNT = B.CHARGE_AMOUNT            
  ,A.WRITEBACK_AMOUNT = B.WRITEBACK_AMOUNT                                            
  ,A.ENDING_BALANCE = B.ENDING_BALANCE                  
  ,A.IS_IMPAIRED = B.IS_IMPAIRED                                            
  ,A.IMPAIRED_FLAG = B.IMPAIRED_FLAG                                            
  ,A.INITIAL_UNAMORT_ORG_FEE = B.INITIAL_UNAMORT_ORG_FEE                                            
  ,A.INITIAL_UNAMORT_TXN_COST = B.INITIAL_UNAMORT_TXN_COST                             
  ,A.UNAMORT_FEE_AMT = B.UNAMORT_FEE_AMT                                            
  ,A.UNAMORT_COST_AMT = B.UNAMORT_COST_AMT                                            
  ,A.FIRST_INSTALLMENT_DATE = ISNULL(B.FIRST_INSTALLMENT_DATE, A.NEXT_PAYMENT_DATE)                                            
 FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                       
 LEFT JOIN (                                            
  SELECT MASTERID AS MASTERID                                            
   ,PRODUCT_GROUP                                            
   ,ECL_AMOUNT                   
   ,CA_UNWINDING_AMOUNT                                            
   ,IA_UNWINDING_AMOUNT                                            
   ,BEGINNING_BALANCE                                            
   ,CHARGE_AMOUNT                                            
   ,WRITEBACK_AMOUNT                                            
   ,ENDING_BALANCE                                            
   ,IS_IMPAIRED                                            
   ,STAFF_LOAN_FLAG                                            
   ,IMPAIRED_FLAG                                            
   ,INITIAL_UNAMORT_ORG_FEE                                            
   ,INITIAL_UNAMORT_TXN_COST                                            
   ,UNAMORT_FEE_AMT                                            
   ,UNAMORT_COST_AMT                                            
   ,FIRST_INSTALLMENT_DATE                                            
  FROM IFRS_MASTER_ACCOUNT (NOLOCK)                                            
  WHERE DOWNLOAD_DATE = @V_PREVDATE                                            
  ) B ON A.MASTERID = B.MASTERID                                            
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                        
                        
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'UPDATE LAST & NEXT PAYMENT DATE'                                            
  )                                      
                                      
 TRUNCATE TABLE TMP_T1                                            
                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'UPDATE AMORT TYPE & PRODUCT NAME'                                            
  )            
                                      
 UPDATE DBO.IFRS_MASTER_ACCOUNT                                            
 SET                                
  PRODUCT_GROUP = B.PRD_GROUP,                                
  PRODUCT_TYPE = B.PRD_TYPE,                  
  PRODUCT_TYPE_1 = B.PRD_TYPE_1,                                
  AMORT_TYPE = B.AMORT_TYPE,                                        
  MARKET_RATE = B.MARKET_RATE,                                        
  IAS_CLASS = B.FLAG_AL,                                        
  STAFF_LOAN_FLAG = CASE WHEN B.IS_STAF_LOAN = 'Y'                                        
      THEN 1                                        
       ELSE 0                                  
      END                                        
 --PRODUCT_NAME = B.PRODUCT_DESCRIPTION                                                
 FROM (                               
  SELECT X.*                                            
   ,Y.*                                            
  FROM IFRS_PRODUCT_PARAM X                                            
  CROSS JOIN IFRS_PRC_DATE_AMORT Y                                        
  ) B                                            
 WHERE DBO.IFRS_MASTER_ACCOUNT.DATA_SOURCE = B.DATA_SOURCE                                        
  AND DBO.IFRS_MASTER_ACCOUNT.PRODUCT_CODE = B.PRD_CODE                                            
  AND (                                            
   DBO.IFRS_MASTER_ACCOUNT.CURRENCY = B.CCY                                            
   OR B.CCY = 'ALL'                                            
   )                                        
  AND DBO.IFRS_MASTER_ACCOUNT.DOWNLOAD_DATE = @V_CURRDATE                                            
  AND DBO.IFRS_MASTER_ACCOUNT.ACCOUNT_STATUS = 'A'                                     
                                      
  -- 20181112 RIS, BTPN UPDATE REVOLVING BASED ON PRODUCT_PARAM                                    
  UPDATE IMA
  SET REVOLVING_FLAG = CASE WHEN IMA.DATA_SOURCE IN ('LOAN_T24','TRADE_T24','TRS') THEN IMA.REVOLVING_FLAG WHEN PRD.REPAY_TYPE_VALUE = 'REV' THEN 1 ELSE 0 END                                
  ----SET REVOLVING_FLAG = CASE PRD.REPAY_TYPE_VALUE WHEN 'REV' THEN 1 ELSE 0 END                                    
  FROM IFRS_MASTER_ACCOUNT IMA (NOLOCK) JOIN IFRS_PRODUCT_PARAM PRD (NOLOCK)                                    
  ON IMA.DATA_SOURCE = PRD.DATA_SOURCE                                    
   AND IMA.PRODUCT_CODE = PRD.PRD_CODE                       
   AND IMA.PRODUCT_TYPE = PRD.PRD_TYPE                                    
   AND (IMA.CURRENCY = PRD.CCY OR PRD.CCY = 'ALL')                                    
  WHERE IMA.DOWNLOAD_DATE = @V_CURRDATE   AND SOURCE_SYSTEM <> 'T24'                                  
                                      
  UPDATE TXN                                  
  SET DEBET_CREDIT_FLAG = CASE IFRS_TXN_CLASS WHEN 'FEE' THEN 'C' WHEN 'COST' THEN 'D' END                                  
  FROM IFRS_TRANSACTION_DAILY TXN (NOLOCK)                                  
  JOIN IFRS_TRANSACTION_PARAM PARM                                  
  ON TXN.TRX_CODE = PARM.TRX_CODE                                  
   AND TXN.DATA_SOURCE = PARM.DATA_SOURCE                                  
   AND (TXN.CCY = PARM.CCY OR PARM.CCY = 'ALL')                                   
   AND (TXN.PRD_CODE = PARM.PRD_CODE OR PARM.PRD_CODE = 'ALL')                                   
   AND (TXN.PRD_TYPE = PARM.PRD_TYPE OR PARM.PRD_TYPE = 'ALL')                           
  WHERE TXN.DOWNLOAD_DATE = @V_CURRDATE AND DEBET_CREDIT_FLAG IS NULL                                                             
                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'EXCHANGE RATE CURR & PREV'                                            
  )                                            
                                            
 /* FRANS 04052018                                            
  ADD STEP TO UPDATE SPPI RESULT INTO IFRS9 CLASS                                            
 */                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'UPDATE IFRS9 CLASS BASED ON SPPI & BUSINESS MODEL TEST'                                            
  )                           
                                 
  /*AMBIL IFRS9_CLASS DARI IMA PREV DATE. SELAIN END OF MONTH */                                          
 UPDATE A                                           
 SET A.IFRS9_CLASS = C.IFRS9_CLASS                                          
 FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                                             
 INNER JOIN IFRS_MASTER_ACCOUNT C (NOLOCK) ON A.MASTERID = C.MASTERID                                           
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE AND C.DOWNLOAD_DATE = @V_PREVDATE                                             
 AND @V_CURRDATE <> EOMONTH(@V_CURRDATE)                            
                                            
 /*UPDATE LEVEL PRODUCT GROUP */                                            
 /*AMBIL IFRS9_CLASS SESUAI SPPI TEST. END OF MONTH & NEW ACCOUNT*/                                          
 UPDATE A                          
 SET IFRS9_CLASS = CASE                                             
   WHEN B.ASSET_CLASS = 'AMORT'                                            
    THEN 'AMORTIZED COST'                                            
   WHEN B.ASSET_CLASS = 'FVTPL'                                            
    THEN 'FVTPL'                             
   WHEN B.ASSET_CLASS = 'FVOCI'                                            
    THEN 'FVOCI'       
   WHEN ISNULL(B.ASSET_CLASS,'') = '' THEN NULL                                           
   END                                            
 FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                                            
 LEFT JOIN VW_AC_PRODUCT_CLASS B (NOLOCK) ON A.PRODUCT_CODE = B.PRD_CODE                                            
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                                            
 /*AND ( --@V_CURRDATE = EOMONTH(@V_CURRDATE)   OR         
 NOT EXISTS (         
   SELECT TOP 1 1                                           
   FROM IFRS_MASTER_ACCOUNT X (NOLOCK)                       ---REMARK BY SAID 20190624 REQ BY BTPN TO UPDATED DAILY                   
   WHERE X.MASTERID = A.MASTERID AND X.DOWNLOAD_DATE = @V_PREVDATE)) */                                         
                                           
 /*AMBIL IFRS9_CLASS SESUAI OVERRIDE. END OF MONTH & NEW ACCOUNT*/                                          
 UPDATE A SET A.IFRS9_CLASS = CASE                                             
   WHEN B.ASSET_CLS = 'AMORT'                                            
    THEN 'AMORTIZED COST'                                            
   WHEN B.ASSET_CLS = 'FVTPL'                                            
    THEN 'FVTPL'                                            
   WHEN B.ASSET_CLS = 'FVOCI'                                            
    THEN 'FVOCI'                                            
   END          
 FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                                           
 INNER JOIN IFRS_AC_OVERRIDE B ON A.MASTERID = B.MASTERID                                           
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                                     
 AND EOMONTH(B.DOWNLOAD_DATE) >= EOMONTH(@V_CURRDATE)                                          
/* AND (--@V_CURRDATE = EOMONTH(@V_CURRDATE)  OR         
 NOT EXISTS (                                          
   SELECT TOP 1 1                                   ---REMARK BY SAID 20190624 REQ BY BTPN TO UPDATED DAILY          
   FROM IFRS_MASTER_ACCOUNT X (NOLOCK)                                     
   WHERE X.MASTERID = A.MASTERID AND X.DOWNLOAD_DATE = @V_PREVDATE))                            
 */                        
                               
                                           
 /* FRANS 07052018                                            
ADD STEP TO RELOAD CURRENCY TABLE                                            
*/                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,'RELOAD MASTER CURRENCY TABLE'                     
  )                                            
                                            
 DELETE FROM TBLM_CURRENCY;                                            
                                            
 INSERT INTO TBLM_CURRENCY (                                            
  CCY                                            
  ,CCY_TYPE                                            
  ,CCY_DESC                                 
  ,CREATEDBY                                            
  ,CREATEDDATE                                            
  )                                            
 SELECT CURRENCY                                            
  ,CURRENCY                                            
  ,COALESCE(CURRENCY_DESC, 'N/A') --CURRENCY_DESC                                            
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,GETDATE()                                            
FROM IFRS_MASTER_EXCHANGE_RATE                                            
 WHERE DOWNLOAD_DATE = @V_CURRDATE;        
         
 ---- UPDATE DPD_CIF, BI_COLLECTABILITY_CIF        
 DROP TABLE IF EXISTS #TMP_IMA_CUST_DPD              
 SELECT CUSTOMER_NUMBER, MAX(DAY_PAST_DUE) AS DAY_PAST_DUE_CIF, MAX(BI_COLLECTABILITY) AS BI_COLLECT_CIF                       
 INTO #TMP_IMA_CUST_DPD                           
 FROM IFRS_MASTER_ACCOUNT (NOLOCK)                          
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
 GROUP BY CUSTOMER_NUMBER                            
                     
 CREATE INDEX IDX_CUST ON #TMP_IMA_CUST_DPD (CUSTOMER_NUMBER)        
        
 UPDATE A           
 SET           
  A.DPD_cif = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 0 ELSE B.DAY_PAST_DUE_CIF END      
  ,A.BI_COLLECT_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 1 ELSE B.BI_COLLECT_CIF END               
 FROM IFRS_MASTER_ACCOUNT A                            
 LEFT JOIN #TMP_IMA_CUST_DPD B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER                           
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE         
 ---- UPDATE DPD_CIF, BI_COLLECTABILITY_CIF        
                                             
                                          
 -- SHU 20180830                        
 -- ADD STEP TO UPDATE GL_CONSTNAME                                           
                                            
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
 ,'SP_IFRS_INITIAL_UPDATE'                                              
 ,'UPDATE GL_CONSTNAME'                                              
 )                 
                                            
 EXEC SP_IFRS_EXEC_RULE 'GL', @V_CURRDATE;                                          
                                               
                                            
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
  ,'SP_IFRS_INITIAL_UPDATE'                                            
  ,''                                            
  )                                            
END 

GO
