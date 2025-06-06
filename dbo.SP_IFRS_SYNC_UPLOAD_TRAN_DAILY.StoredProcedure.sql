USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_UPLOAD_TRAN_DAILY]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_UPLOAD_TRAN_DAILY]            
AS                      
    DECLARE @V_CURRDATE DATE          
BEGIN                      
                  
  SELECT @V_CURRDATE = CURRDATE FROM DBO.IFRS_PRC_DATE_AMORT                                  
                      
  DELETE IFRS_TRANSACTION_DAILY WHERE DOWNLOAD_DATE = @V_CURRDATE AND SOURCE_TABLE = 'TBLU_TRANS_ASSET'          
      
  IF OBJECT_ID ('TEMPDB.DBO.#DM_LIMIT') IS NOT NULL DROP TABLE #DM_LIMIT                   
     
 SELECT YMD, BR_CD, LIMIT_ID    
 INTO #DM_LIMIT    
 FROM IFRS9_STG..DM_LIMIT WHERE YMD = @V_CURRDATE    
 GROUP BY YMD, BR_CD, LIMIT_ID    
      
  ---- ### CREATE TEMP STG_CIF BY @CURRDATE        
  IF OBJECT_ID ('TEMPDB.DBO.#STG_CIF_ITFH') IS NOT NULL DROP TABLE #STG_CIF_ITFH           
        
   SELECT CIF, CUSTOMER_TYPE, SOURCE_SYSTEM         
   INTO #STG_CIF_ITFH        
   FROM IFRS9_STG..STG_CIF WHERE SOURCE_SYSTEM = 'EQ'        
        
  CREATE NONCLUSTERED INDEX #NCI_STG_CIF_ITFH ON DBO.#STG_CIF_ITFH(CIF ASC, SOURCE_SYSTEM ASC)         
  WITH (PAD_INDEX = OFF, ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, SORT_IN_TEMPDB = OFF, FILLFACTOR =100) ON [PRIMARY];        
      
      
 ---- ## COLLECT DATA N3L_UNDRAWN FROM STG TO TEMP ##CBSPROJECT    
 IF OBJECT_ID ('TEMPDB.DBO.#TEMP_STG_N3L_UNDRAWN') IS NOT NULL DROP TABLE #TEMP_STG_N3L_UNDRAWN        
    
  SELECT *     
  INTO #TEMP_STG_N3L_UNDRAWN    
  FROM IFRS9_STG..STG_N3L_UNDRAWN    
  WHERE YMD = @V_CURRDATE     
    
  CREATE NONCLUSTERED INDEX #NCI_STG_N3L_UNDRAWN ON DBO.#TEMP_STG_N3L_UNDRAWN(LIMIT_ID ASC, REPORT_LIMIT_ID ASC, YMD ASC)         
  WITH (PAD_INDEX = OFF, ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, SORT_IN_TEMPDB = OFF, FILLFACTOR =100) ON [PRIMARY];        
     
                
        INSERT INTO IFRS_TRANSACTION_DAILY             
        (                    
            DOWNLOAD_DATE,                    
            EFFECTIVE_DATE,                    
            MATURITY_DATE,                    
            MASTERID,                    
            ACCOUNT_NUMBER,                    
            FACILITY_NUMBER,                    
            CUSTOMER_NUMBER,                    
            BRANCH_CODE,                    
            DATA_SOURCE,                    
            PRD_TYPE,                    
            PRD_CODE,                    
            TRX_CODE,                    
            CCY,                    
            EVENT_CODE,                    
            TRX_REFERENCE_NUMBER,                    
            ORG_CCY_AMT,                    
            EQV_LCY_AMT,                    
            DEBET_CREDIT_FLAG,                    
            TRX_SOURCE,                    
            INTERNAL_NO,                    
            REVOLVING_FLAG,                    
            CREATED_DATE,                    
            SOURCE_TABLE,                    
            TRX_LEVEL                    
        )                      
        SELECT             
            A.TRANSACTION_DATE AS DOWNLOAD_DATE,                      
            A.TRANSACTION_DATE AS EFFECTIVE_DATE,                      
            C.LOAN_DUE_DATE AS MATURITY_DATE,                      
            C.MASTERID,                      
            C.ACCOUNT_NUMBER,                      
            A.FACILITY_NUMBER,                      
            C.CUSTOMER_NUMBER,                      
            C.BRANCH_CODE,                      
            C.DATA_SOURCE,                      
            C.PRODUCT_TYPE,                      
            A.PRD_CODE,                      
            A.TRX_CODE,                      
            A.CURRENCY,                      
            '' AS EVENT_CODE,                      
            '' AS TRX_REFERENCE_NUMBER,                      
            A.TRANSACTION_AMOUNT AS ORG_CCY_AMT,                      
            A.TRANSACTION_AMOUNT * C.EXCHANGE_RATE AS EQV_LCY_AMT,                      
            A.DEBIT_CREDIT_FLAG,                      
            '' AS TRX_SOURCE,                      
            '' AS INTERNAL_NO,                      
            '' AS REVOLVING_FLAG,                      
            GETDATE(),                      
            'TBLU_TRANS_ASSET' AS SOURCE_TABLE,                      
            '' AS TRX_LEVEL      
        FROM TBLU_TRANS_ASSET A                    
        JOIN IFRS_MASTER_ACCOUNT C            
        ON A.ACCOUNT_NUMBER = C.MASTERID AND CAST(A.TRANSACTION_DATE AS DATE) =  C.DOWNLOAD_DATE            
        JOIN IFRS_MASTER_TRANS_PARAM D             
        ON (A.PRD_CODE = D.PRD_CODE OR D.PRD_CODE = 'ALL') AND A.TRX_CODE = D.TRX_CODE            
        WHERE D.INST_CLS_VALUE IN ('A', 'O') AND CAST(A.TRANSACTION_DATE AS DATE) = @V_CURRDATE            
            
  DELETE IFRS_TRX_FACILITY_HEADER WHERE DOWNLOAD_DATE = @V_CURRDATE AND CREATEDBY = 'TBLU_FACILITY_FEECOST'        
          
  ---- ### UPDATE ADD CUSTOMER TYPE FIELD FROM #STG_CIF_ITFH        
  INSERT INTO IFRS_TRX_FACILITY_HEADER          
  (          
   DOWNLOAD_DATE          
   ,TRX_DATE          
   ,FACILITY_NUMBER          
   ,CUSTOMER_NUMBER        
   ,CUSTOMER_TYPE          
   ,BRANCH_CODE          
   ,TRX_CODE          
   ,FLAG_CF    
   ,PLAFOND        
   ,DATA_SOURCE          
   ,PRD_TYPE          
   ,PRD_CODE          
   ,TRX_DR_CR          
   ,CCY          
   ,MATURITY_DATE    
   ,EXCHANGE_RATE          
   ,STATUS          
   ,TRX_AMOUNT          
   ,CREATEDBY          
   ,CREATEDDATE          
   ,CREATEDHOST          
   ,START_DATE    
   ,LIMIT_CURRENCY    
   ,LIMIT_EXCHANGE_RATE           
  )          
 SELECT           
  A.DOWNLOAD_DATE          
 ,TRANSACTION_DATE AS TRX_DATE          
 ,FACILITY_NUMBER          
 ,CASE WHEN ISNULL(C.OLD_CIF_NUMBER,'') = '' THEN C.CIF_NO ELSE C.OLD_CIF_NUMBER END AS CUSTOMER_NUMBER          
 ,SCF.CUSTOMER_TYPE        
 --,A.BRANCH_CODE    
 ,DM.BR_CD AS BRANCH_CODE           
 ,A.TRX_CODE          
 ,CASE WHEN D.IFRS_TXN_CLASS = 'FEE' THEN 'F' ELSE 'C' END     
 ,C.STG_LIMIT_AMT/ISNULL(C.LIMIT_CURRENCY_RATE, 1) AS PLAFOND       
 ,'LIMIT_T24' AS DATA_SOURCE       
 ,E.PRD_TYPE         
 ,E.PRD_CODE    
 ,DEBIT_CREDIT_FLAG AS TRX_DR_CR          
 ,A.CCY          
 ,C.EXPIRY_DATE AS MATURITY_DATE    
 ,RATE.RATE_AMOUNT AS EXCHANGE_RATE            
 ,'ACT' AS STATUS          
 ,TRANSACTION_AMOUNT AS TRX_AMOUNT          
 ,'TBLU_FACILITY_FEECOST' AS CREATEDBY          
 ,A.CREATEDDATE          
 ,A.CREATEDHOST          
 ,C.SECOND_AGREE_DT AS START_DATE    
 , C.LIMIT_CURRENCY    
 , C.LIMIT_CURRENCY_RATE AS LIMIT_EXCHANGE_RATE         
 FROM TBLU_FACILITY_FEECOST A          
 JOIN IFRS_MASTER_TRANS_PARAM D             
  ON (A.PRD_CODE = D.PRD_CODE OR D.PRD_CODE = 'ALL') AND A.TRX_CODE = D.TRX_CODE          
 INNER JOIN #TEMP_STG_N3L_UNDRAWN C ON A.FACILITY_NUMBER = ISNULL(C.REPORT_LIMIT_ID,C.LIMIT_ID) AND C.YMD = A.DOWNLOAD_DATE    
 INNER JOIN IFRS9..IFRS_MASTER_EXCHANGE_RATE RATE ON A.DOWNLOAD_DATE = RATE.DOWNLOAD_DATE     
 AND RATE.DOWNLOAD_DATE = @V_CURRDATE     
 AND A.CCY = RATE.CURRENCY    
 LEFT JOIN IFRS_MASTER_PRODUCT_PARAM E ON E.PRD_CODE = C.LIMIT_PRODUCT    
 LEFT JOIN #STG_CIF_ITFH SCF ON C.CIF_NO = SCF.CIF    
 LEFT JOIN #DM_LIMIT DM ON ISNULL(C.REPORT_LIMIT_ID, C.LIMIT_ID) = DM.LIMIT_ID AND C.YMD = DM.YMD        
 WHERE D.INST_CLS_VALUE IN ('A', 'O') AND CAST(A.TRANSACTION_DATE AS DATE) = @V_CURRDATE  
   
  
 ---- UPDATE SEGMENT_FLAG FROM IMA LIMIT_T24 25 APR 2024
 UPDATE A  
 SET A.SEGMENT_FLAG = B.SEGMENT_FLAG  
 FROM IFRS_TRX_FACILITY_HEADER A  
 INNER JOIN IFRS_MASTER_ACCOUNT B ON A.FACILITY_NUMBER = B.MASTERID AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE  
 WHERE B.DATA_SOURCE = 'LIMIT_T24' AND A.DOWNLOAD_DATE =  @V_CURRDATE           
          
  ---- ##UPDATE GL_CONSTNAME IFRS_TRX_FACILITY_HEADER        
 EXEC SP_IFRS_EXEC_RULE_ITFH 'GL', @V_CURRDATE;     
      
 ---- ##SELLDOWN FACILITY LEVEL PROCESS ##CBSPROJECTR    
--INSERT INTO IFRS_TRX_FACILITY_HEADER          
--  (          
--   DOWNLOAD_DATE          
--   ,TRX_DATE          
--   ,FACILITY_NUMBER          
--   ,CUSTOMER_NUMBER        
--   ,CUSTOMER_TYPE          
--   ,BRANCH_CODE          
--   ,TRX_CODE          
--   ,FLAG_CF        
--   ,DATA_SOURCE          
--   ,PRD_TYPE          
--   ,PRD_CODE          
--   ,TRX_DR_CR          
--   ,CCY          
--   ,MATURITY_DATE          
--   ,STATUS          
--   ,TRX_AMOUNT          
--   ,CREATEDBY          
--   ,CREATEDDATE          
--   ,CREATEDHOST          
--   ,START_DATE          
--  )    
-- SELECT     
-- B.DOWNLOAD_DATE    
-- , B.SELLDOWN_DATE AS TRX_DATE    
-- , CASE WHEN ISNULL(B.OLD_FACILITY_NUMBER,'') = '' THEN B.FACILITY_NUMBER ELSE B.OLD_FACILITY_NUMBER END FACILITY_NUMBER    
-- , CASE WHEN ISNULL(A.OLD_CIF_NUMBER,'') = '' THEN A.CIF_NO ELSE A.OLD_CIF_NUMBER END AS CUSTOMER_NUMBER      
-- --, SCF.CUSTOMER_TYPE AS CUSTOMER_TYPE    
-- , SCF.CUSTOMER_TYPE AS CUSTOMER_TYPE ---- FOR DEVELOPMENT UPDATE GL_CONSTNAME    
-- , '0800' AS BRANCH_CODE     
-- , 'SELLDOWN' AS TRX_CODE    
-- , 'F' AS FLAG_CF    
-- , 'LIMIT_T24' AS DATA_SOURCE    
-- , 'ALL' AS PRD_TYPE    
-- , 'ALL' AS PRD_CODE    
-- , 'C' AS TRX_DR_CR     
-- , A.LIMIT_CURRENCY AS CCY    
-- , B.DOWNLOAD_DATE AS MATURITY_DATE     
-- , 'ACT' AS STATUS     
-- --------, (A.STG_AVAIL_AMT - B.AMOUNT_SELLDOWN) AS TRX_AMOUNT --- WHEN SELLDOWN IN AMOUNT     
-- , B.AMOUNT_SELLDOWN AS TRX_AMOUNT --- WHEN SELLDOWN IN PERCENTAGE     
--  ,'STG_IFRS_FACILITY_SELLDOWN_FLAG' AS CREATEDBY          
--  ,GETDATE() AS CREATEDDATE          
--  ,'IFRS9' AS CREATEDHOST      
--  ,B.DOWNLOAD_DATE AS START_DATE     
--  FROM #TEMP_STG_N3L_UNDRAWN A    
-- INNER JOIN IFRS_FACILITY_SELLDOWN_FLAG B     
-- ON ISNULL(A.REPORT_LIMIT_ID,A.LIMIT_ID) = ISNULL(B.OLD_FACILITY_NUMBER,B.FACILITY_NUMBER)    
-- AND A.YMD = B.DOWNLOAD_DATE AND B.SELLDOWN_FLAG = 'Y'    
-- LEFT JOIN #STG_CIF_ITFH SCF ON A.CIF_NO = SCF.CIF     
-- WHERE B.DOWNLOAD_DATE = @V_CURRDATE      
                      
END
GO
