USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_INITIAL_UPDATE_CS]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_INITIAL_UPDATE_CS]                                       
@DOWNLOAD_DATE DATE = NULL,                                       
@MODEL_ID BIGINT = 0                               
AS                              
    DECLARE @V_CURRDATE DATE                                         
BEGIN                                  
    IF(@DOWNLOAD_DATE IS NULL)                                        
    BEGIN                                       
        SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE                                
    END                                        
    ELSE                                        
    BEGIN                                        
        SELECT @V_CURRDATE = @DOWNLOAD_DATE                                        
    END          
          
          
     --------- UPDATE PRODUCT PARAM                                 
    UPDATE A                                
    SET                                     
     PRODUCT_GROUP = B.PRD_GROUP,                                     
     PRODUCT_TYPE = B.PRD_TYPE,                                      
     PRODUCT_TYPE_1 = B.PRD_TYPE_1,           
  ----ADD BY BEDU -- TERKAIT REVOLVING_FLAG CORPORATE KITA AMBIL APA ADANYA DARI DATA STAGING          
  REVOLVING_FLAG = CASE WHEN A.DATA_SOURCE IN ('LOAN_T24','TRADE_T24','TRS') THEN A.REVOLVING_FLAG WHEN B.REPAY_TYPE_VALUE = 'REV' THEN 1 ELSE 0 END,               
  ----REMARK BY BEDU          
  ----REVOLVING_FLAG = CASE B.REPAY_TYPE_VALUE WHEN 'REV' THEN 1 ELSE 0 END,             
  DATA_SOURCE = B.DATA_SOURCE                               
    FROM IFRS_MASTER_ACCOUNT A                         
    INNER JOIN IFRS_MASTER_PRODUCT_PARAM B                                    
    --ON A.DATA_SOURCE = B.DATA_SOURCE                                
    ON A.PRODUCT_CODE = B.PRD_CODE                                    
    AND (A.CURRENCY = B.CCY OR B.CCY = 'ALL')                                
    --AND A.DOWNLOAD_DATE = @V_CURRDATE  AND B.IS_DELETE = 0   AND SOURCE_SYSTEM <> 'T24'          
 AND A.DOWNLOAD_DATE = @V_CURRDATE  AND B.IS_DELETE = 0 AND ISNULL(A.SEGMENT_FLAG,'') <> ''          
          
 -- Sync Corporate Data (T24 Addons)                
 IF(@V_CURRDATE = EOMONTH(@V_CURRDATE))                
 BEGIN                
  EXEC SP_IFRS_SYNC_CORPORATE_DATA_CS @V_CURRDATE                
  -- Sync Retail Data 20220922              
  EXEC SP_IFRS_SYNC_RETAIL_DATA @V_CURRDATE           
           
 END          
                                      
    -- INSERT IMA TO TMP_IMA                                
    DROP TABLE IF EXISTS #IMA_CURR_IMP                                  
    SELECT *,          
 CASE WHEN DATA_SOURCE IN('LOAN_T24','TRADE_T24','TRS','LIMIT_T24') THEN 'CORPORATE'           
 WHEN DATA_SOURCE = 'LOAN' THEN 'RETAIL' ELSE NULL  END AS BUSSINESS_UNIT                       
    INTO #IMA_CURR_IMP                         
    FROM IFRS_MASTER_ACCOUNT (NOLOCK)                        
    WHERE DOWNLOAD_DATE = @V_CURRDATE                                
                                
    -- UPDATE DPD_CIF                                      
    DROP TABLE IF EXISTS #TMP_IMA_CUST_DPD                            
    SELECT CUSTOMER_NUMBER, MAX(DAY_PAST_DUE) AS DAY_PAST_DUE_CIF            
 ,MAX(BI_COLLECTABILITY) AS BI_COLLECT_CIF            
 ,MAX (DPD_FINAL) AS DPD_FINAL_CIF                 
 ,MAX(CASE WHEN RESTRUCTURE_COLLECT_FLAG = 1 THEN 1 ELSE 0 END) AS RESTRUCTURE_COLLECT_FLAG_CIF          
 ,BUSSINESS_UNIT                      
    INTO #TMP_IMA_CUST_DPD                                         
    FROM #IMA_CURR_IMP                                        
    WHERE DOWNLOAD_DATE = @V_CURRDATE                                
    GROUP BY CUSTOMER_NUMBER, BUSSINESS_UNIT                                          
                                   
    CREATE INDEX IDX_CUST ON #TMP_IMA_CUST_DPD (CUSTOMER_NUMBER)                               
                                          
    UPDATE A                         
    SET                         
  A.DPD_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 0 ELSE B.DAY_PAST_DUE_CIF END                                   
  ,A.BI_COLLECT_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 1 ELSE B.BI_COLLECT_CIF END                    
,A.DPD_FINAL_CIF = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN 0 ELSE B.DPD_FINAL_CIF END                   
  ,A.RESTRUCTURE_COLLECT_FLAG_CIF = ISNULL(B.RESTRUCTURE_COLLECT_FLAG_CIF,0)                 
    FROM #IMA_CURR_IMP A                                          
    LEFT JOIN #TMP_IMA_CUST_DPD B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER AND A.BUSSINESS_UNIT = B.BUSSINESS_UNIT                                         
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE                                         
    -- END UPDATE DPD CIF --                   
                                        
    UPDATE #IMA_CURR_IMP                                     
    SET REMAINING_TENOR = (DATEDIFF(DD, DOWNLOAD_DATE, LOAN_DUE_DATE)/30)+1                 
  ,UNUSED_AMOUNT = CASE WHEN DATA_SOURCE = 'LOAN' THEN 0 ELSE  UNUSED_AMOUNT END   -- UPDATE INITIAL UNUSED                 
    WHERE DOWNLOAD_DATE = @V_CURRDATE                                         
                              
              
    -- UPDATING UNUSED_AMOUNT JUST FOR LOAN DATA_SOURCE                                  
    UPDATE #IMA_CURR_IMP              
    SET UNUSED_AMOUNT = CASE WHEN PLAFOND - OUTSTANDING < 0 THEN 0 ELSE PLAFOND - OUTSTANDING END                                
    WHERE DATA_SOURCE = 'LOAN' AND DOWNLOAD_DATE = @V_CURRDATE AND PRODUCT_TYPE_1 = 'PRK'                
    -- END UPDATING UNUSED_AMOUNT JUST FOR LOAN DATA_SOURCE                  
                             
    -- UPDATE PLAFOND_CIF                                              
    DROP TABLE IF EXISTS #IMA                                                
 SELECT                                                
        A.DOWNLOAD_DATE,                                                
        A.MASTERID,                                                 
        A.CUSTOMER_NUMBER,                                                 
        CASE WHEN A.FACILITY_NUMBER IS NULL THEN A.MASTERID ELSE A.FACILITY_NUMBER END FACILITY_NUMBER,                      
        A.PLAFOND * B.RATE_AMOUNT AS PLAFOND_IDR,          
  A.BUSSINESS_UNIT                                                
    INTO #IMA                                                
    FROM #IMA_CURR_IMP A (NOLOCK)           
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B           
 ON ISNULL(A.LIMIT_CURRENCY, 'IDR') = B.CURRENCY          
 AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE                             
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE                                       
                                                
    DROP TABLE IF EXISTS #IMA_CUSTOMER                              
    SELECT                                                
  DOWNLOAD_DATE,                                                
        CUSTOMER_NUMBER,                                                
        SUM(PLAFOND) AS PLAFOND_CIF_IDR,          
  BUSSINESS_UNIT                                                
    INTO #IMA_CUSTOMER                                                
    FROM                                                
    (                         
        SELECT                                                 
            DOWNLOAD_DATE,                                                
            CUSTOMER_NUMBER,                                                
            FACILITY_NUMBER,                                                
            MAX(PLAFOND_IDR) AS PLAFOND,          
   BUSSINESS_UNIT                                                
        FROM #IMA                                                
        GROUP BY DOWNLOAD_DATE, CUSTOMER_NUMBER, FACILITY_NUMBER, BUSSINESS_UNIT                                                
    ) A                                                
    GROUP BY DOWNLOAD_DATE, CUSTOMER_NUMBER,BUSSINESS_UNIT                                                
    ORDER BY CUSTOMER_NUMBER                      
    -- END UPDATE PLAFOND_CIF           
                      
     UPDATE A                                 
 SET                         
        A.PLAFOND_CIF = (C.PLAFOND_CIF_IDR / B.RATE_AMOUNT)                                       
    FROM #IMA_CURR_IMP A                                                      
    JOIN #IMA_CUSTOMER C                    
    ON A.CUSTOMER_NUMBER = C.CUSTOMER_NUMBER                                                
    AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE          
 AND A.BUSSINESS_UNIT = C.BUSSINESS_UNIT            
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B           
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE          
 AND ISNULL(A.LIMIT_CURRENCY, 'IDR') = B.CURRENCY                    
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE            
                       
    -- UPDATE BACK TO MASTER_ACCOUNT                                
    UPDATE A                                 
    SET                         
        A.DPD_CIF = B.DPD_CIF                                   
        ,A.BI_COLLECT_CIF = B.BI_COLLECT_CIF                                 
        ,A.DPD_FINAL_CIF = B.DPD_FINAL_CIF                                    
        ,A.UNUSED_AMOUNT = B.UNUSED_AMOUNT                                
        ,A.REMAINING_TENOR = B.REMAINING_TENOR                                
        ,A.PRODUCT_GROUP = B.PRODUCT_GROUP                                     
        ,A.PRODUCT_TYPE = B.PRODUCT_TYPE            
        ,A.PRODUCT_TYPE_1 = B.PRODUCT_TYPE_1                                
        ,A.REVOLVING_FLAG = B.REVOLVING_FLAG                      
        ,A.PLAFOND_CIF = B.PLAFOND_CIF                      
        --,A.IMPAIRED_FLAG = 'C'    -- no need update impaired_flag for catchup cross segment              
  ,A.RESTRUCTURE_COLLECT_FLAG_CIF = B.RESTRUCTURE_COLLECT_FLAG_CIF                                
    FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                                
    JOIN #IMA_CURR_IMP B                         
    ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID                      
    --JOIN #IMA_CUSTOMER C                      
    --ON A.CUSTOMER_NUMBER = C.CUSTOMER_NUMBER                                                
    --AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE                      
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE                         
              
 -- UPDATE JENIUS PAYLATER MARKET INTEREST RATE              
 DROP TABLE IF EXISTS #MIR                
 SELECT TOP 1 DEAL_TYPE,MARKET_INT_RATE,MAX(DOWNLOAD_DATE) AS DOWNLOAD_DATE                 
 INTO #MIR                 
 FROM IFRS_MARKET_INT_RATE                 
 GROUP BY DEAL_TYPE,MARKET_INT_RATE            
 HAVING MAX(DOWNLOAD_DATE)<=@V_CURRDATE            
 ORDER BY DOWNLOAD_DATE DESC              
           
 UPDATE IMA              
 SET IMA.INTEREST_RATE = B.MARKET_INT_RATE              
 FROM IFRS_MASTER_ACCOUNT IMA               
 INNER JOIN #MIR B ON IMA.PRODUCT_CODE = B.DEAL_TYPE              
 WHERE IMA.DOWNLOAD_DATE = @V_CURRDATE              
              
 -- INITIAL UPDATE T24 (T24 ADDONS)          
 IF(@V_CURRDATE = EOMONTH(@V_CURRDATE))          
 BEGIN          
  EXEC SP_IFRS_IMP_INITIAL_UPDATE_T24 @V_CURRDATE          
 END             
      
   /*START UPDATE RATING CODE FROM IMA TO IMA MONTHLY CROSS SEGMENT ONLY*/      
    --UPDATE A
	--SET 
	--A.WATCHLIST_FLAG = B.WATCHLIST_FLAG,
	--A.INITIAL_RATING_CODE = B.INITIAL_RATING_CODE,
	--A.RATING_DOWNGRADE = B.RATING_DOWNGRADE,
	--A.PD_CURRENT_RATE = B.PD_CURRENT_RATE,
	--A.PD_INITIAL_RATE = B.PD_INITIAL_RATE,
	--A.PD_CHANGE = B.PD_CHANGE
	--FROM IFRS9..IFRS_MASTER_ACCOUNT_MONTHLY A
	--INNER JOIN IFRS9..IFRS_MASTER_ACCOUNT B ON A.DOWNLOAD_DATE = A.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID
	--WHERE ISNULL(B.SEGMENT_FLAG,'N/A') <> 'N/A'
	--AND A.DOWNLOAD_DATE = @V_CURRDATE
	/*END UPDATE RATING CODE FROM IMA TO IMA MONTHLY CROSS SEGMENT ONLY*/           
         
 -- UPDATE GL_CONSTNAME                      
--EXEC SP_IFRS_EXEC_RULE 'GL', @V_CURRDATE;                                  
                              
END 

GO
