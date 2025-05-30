USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_ECL_EAD_RESULT_PRK]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_ECL_EAD_RESULT_PRK]         
------DECLARE               
@DOWNLOAD_DATE DATE = NULL              
AS              
 DECLARE @V_CURRDATE DATE;              
BEGIN              
 IF (@DOWNLOAD_DATE IS NULL)              
 BEGIN              
  SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE              
 END              
 ELSE              
 BEGIN              
  SELECT @V_CURRDATE = @DOWNLOAD_DATE;              
 END           
          
              
/* ENCHANGMENT CREDIT CARD 2021-03-31 - UPDATE LIFETIME - STAGE 1,2,3 */          
 UPDATE A            
 SET A.LIFETIME = B.VALUE2            
 FROM TMP_IFRS_ECL_IMA A            
 INNER JOIN TBLM_COMMONCODEDETAIL B            
 ON A.STAGE = B.VALUE1            
 JOIN (SELECT PRD_CODE FROM IFRS_MASTER_PRODUCT_PARAM WHERE PRD_TYPE = 'CREDITCARD') C            
 ON A.PRODUCT_CODE = C.PRD_CODE             
 WHERE B.COMMONCODE = 'CC_PERIOD'          
 AND A.DATA_SOURCE <> 'LIMIT'            
              
 TRUNCATE TABLE IFRS_EAD_RESULT_PRK;                 
                
 INSERT INTO IFRS_EAD_RESULT_PRK              
 (              
  DOWNLOAD_DATE,              
  MASTERID,              
  GROUP_SEGMENT,              
  SEGMENT,              
  SUB_SEGMENT,              
  SEGMENTATION_ID,              
  ACCOUNT_NUMBER,              
  CUSTOMER_NUMBER,               
  SICR_RULE_ID,              
  BUCKET_GROUP,              
  BUCKET_ID,              
  LIFETIME,              
  STAGE,              
  REVOLVING_FLAG,              
  PD_SEGMENT,              
  LGD_SEGMENT,              
  EAD_SEGMENT,              
  PREV_ECL_AMOUNT,              
  ECL_MODEL_ID,              
  EAD_MODEL_ID,              
  CCF_RULES_ID,               
  LGD_MODEL_ID,               
  PD_MODEL_ID,              
  SEQ,              
  FL_YEAR,              
  FL_MONTH,              
  EIR,              
  OUTSTANDING,              
  UNAMORT_COST_AMT,              
  UNAMORT_FEE_AMT,              
  INTEREST_ACCRUED,              
  UNUSED_AMOUNT,              
  FAIR_VALUE_AMOUNT,              
  EAD_BALANCE,              
  PLAFOND,              
  EAD,              
  CCF,              
  BI_COLLECTABILITY,                
  COLL_AMOUNT,    
  SEGMENT_FLAG              
 )              
 SELECT               
  A.DOWNLOAD_DATE,              
  A.MASTERID,              
  A.GROUP_SEGMENT,              
  A.SEGMENT,              
  A.SUB_SEGMENT,              
  A.SEGMENTATION_ID,              
  A.ACCOUNT_NUMBER,              
  A.CUSTOMER_NUMBER,               
  A.SICR_RULE_ID,              
  A.BUCKET_GROUP,              
  A.BUCKET_ID,              
  A.LIFETIME,              
  A.STAGE,              
  A.REVOLVING_FLAG,              
  A.PD_SEGMENT,              
  A.LGD_SEGMENT,              
  A.EAD_SEGMENT,              
  A.PREV_ECL_AMOUNT,              
  A.ECL_MODEL_ID,              
  A.EAD_MODEL_ID,              
  A.CCF_RULES_ID,               
  A.LGD_MODEL_ID,              
  A.PD_MODEL_ID,              
  1 AS SEQ,              
  1 AS FL_YEAR,              
  0 AS FL_MONTH,              
  A.EIR,              
  A.OUTSTANDING,              
  A.UNAMORT_COST_AMT,              
  A.UNAMORT_FEE_AMT,              
  A.INTEREST_ACCRUED,              
  A.UNUSED_AMOUNT,              
  A.FAIR_VALUE_AMOUNT,              
  A.EAD_BALANCE,              
  A.PLAFOND,              
  CASE WHEN EAD_BALANCE < 0 THEN 0 ELSE EAD_BALANCE END AS EAD,              
  CASE D.AVERAGE_METHOD WHEN 'WEIGHTED' THEN C.WEIGHTED_AVG_CCF WHEN 'SIMPLE' THEN C.SIMPLE_AVG_CCF END AS CCF,                
  BI_COLLECTABILITY,                
  A.COLL_AMOUNT,    
  A.SEGMENT_FLAG               
 FROM TMP_IFRS_ECL_IMA  A              
 JOIN IFRS_ECL_MODEL_DETAIL_EAD B              
 ON A.CCF_RULES_ID = B.CCF_MODEL_ID AND A.ECL_MODEL_ID = B.ECL_MODEL_ID AND A.SEGMENTATION_ID = B.SEGMENTATION_ID              
 LEFT JOIN IFRS_EAD_CCF_HEADER C ON (CASE B.CCF_EFF_DATE_OPTION WHEN 'SELECT_DATE' THEN B.CCF_EFF_DATE WHEN 'LAST_MONTH' THEN DATEADD(DD, -1, A.DOWNLOAD_DATE) END = C.DOWNLOAD_DATE) AND A.CCF_RULES_ID = C.CCF_RULE_ID                
 LEFT JOIN IFRS_CCF_RULES_CONFIG D ON C.CCF_RULE_ID = D.PKID               
 WHERE               
 -- FD CHANGE 28/11/2019 TO ADD LOAN T24 REVOLVING, LIMIT T24 AND TRADE T24 INTO THIS EAD PRK POPULATION              
 -- LOAN AND LOAN_T24 SPLIT TO MONTHLY PRK 20201001 - RIS              
 (              
  A.DATA_SOURCE IN ('TRADE_T24','TRS')               
 ) AND A.IMPAIRED_FLAG = 'C';               
               
 -- PRK MONTHLY NEW 20201001 - RIS              
 TRUNCATE TABLE IFRS_EAD_RESULT_PRK_MONTHLY              
          
/* ADD & CHANGE SOURCE FOR CC LIFETIME - 2022-01-11*/        
  IF OBJECT_ID ('TEMPDB.DBO.#TEMP') IS NOT NULL DROP TABLE #TEMP                  
        
  SELECT          
  ROW_NUMBER() OVER(ORDER BY MASTERID) AS R_NUMBER,A.*          
  INTO #TEMP         
  FROM TMP_IFRS_ECL_IMA  A                 
  WHERE                 
  ((A.DATA_SOURCE='LOAN' AND A.PRODUCT_TYPE_1 = 'PRK')              
   OR              
   (A.DATA_SOURCE = 'LOAN_T24' AND ISNULL(A.REVOLVING_FLAG,1)=1)                    
   OR           
 (A.DATA_SOURCE IN ('LIMIT','LIMIT_T24'))) AND A.IMPAIRED_FLAG = 'C'           
        
CREATE NONCLUSTERED INDEX #NCI_TEMP ON DBO.#TEMP(CCF_RULES_ID ASC, EAD_MODEL_ID ASC, R_NUMBER ASC)             
WITH (PAD_INDEX = OFF, ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, SORT_IN_TEMPDB = OFF, FILLFACTOR =100) ON [PRIMARY];          
/* ENCHANGEMNT JENIUS 2021-03-31 - LIMIT */        
           
 /*        
        
 DECLARE @ROW_NUMBERMAX INT = 0          
 SET @ROW_NUMBERMAX = (SELECT MAX(R_NUMBER) FROM #TEMP)                
              
 DECLARE @START INT = 1              
 DECLARE @END INT = 12              
 DECLARE @ROW_NUMBER INT = 1          
 DECLARE @YEAR INT = 12          
 DECLARE @FL_YEAR INT = 1          
 DECLARE @FL_MONTH INT = 1          
           
 WHILE  @ROW_NUMBER <= @ROW_NUMBERMAX            
 BEGIN             
 IF ((SELECT COUNT(*) FROM #TEMP WHERE R_NUMBER = @ROW_NUMBER AND PRODUCT_CODE IN (SELECT PRD_CODE FROM IFRS_MASTER_PRODUCT_PARAM WHERE PRD_TYPE = 'CREDITCARD')) <> 0)           
 BEGIN          
 SET @END = (SELECT [LIFETIME] FROM #TEMP WHERE R_NUMBER = @ROW_NUMBER)          
 END          
 ELSE           
 BEGIN          
 SET @END = 12          
 END          
               
 WHILE @START <= @END              
 BEGIN             
            
 IF(@START > @YEAR)          
 BEGIN          
 SET @FL_YEAR = @FL_YEAR + 1          
 SET @YEAR = @YEAR + 12          
 SET @FL_MONTH = 1          
 END          
        
        
 */        
           
   /* SET UP LIMIT RUNNING NUMBER */        
   ;WITH N(N) AS         
 (        
   SELECT TOP (256) (NUMBER)+1         
   FROM [MASTER].DBO.SPT_VALUES        
   WHERE [TYPE] = N'P' ORDER BY NUMBER        
 )        
         
 INSERT INTO IFRS_EAD_RESULT_PRK_MONTHLY              
   (              
    DOWNLOAD_DATE,              
    MASTERID,              
    GROUP_SEGMENT,              
    SEGMENT,              
    SUB_SEGMENT,              
    SEGMENTATION_ID,              
    ACCOUNT_NUMBER,              
    CUSTOMER_NUMBER,               
    SICR_RULE_ID,              
    BUCKET_GROUP,              
    BUCKET_ID,              
    LIFETIME,              
    STAGE,              
    REVOLVING_FLAG,              
    PD_SEGMENT,              
    LGD_SEGMENT,              
    EAD_SEGMENT,              
    PREV_ECL_AMOUNT,              
    ECL_MODEL_ID,              
    EAD_MODEL_ID,              
    CCF_RULES_ID,               
    LGD_MODEL_ID,               
    PD_MODEL_ID,              
    SEQ,              
    FL_YEAR,              
    FL_MONTH,              
    EIR,              
    OUTSTANDING,              
    UNAMORT_COST_AMT,              
    UNAMORT_FEE_AMT,              
    INTEREST_ACCRUED,              
    UNUSED_AMOUNT,              
    FAIR_VALUE_AMOUNT,              
    EAD_BALANCE,              
    PLAFOND,              
    EAD,              
    CCF,       
    BI_COLLECTABILITY,                
    COLL_AMOUNT,    
 SEGMENT_FLAG              
    )        
 SELECT               
 A.DOWNLOAD_DATE,              
 A.MASTERID,           
 A.GROUP_SEGMENT,              
 A.SEGMENT,              
 A.SUB_SEGMENT,              
 A.SEGMENTATION_ID,              
 A.ACCOUNT_NUMBER,              
 A.CUSTOMER_NUMBER,               
 A.SICR_RULE_ID,              
 A.BUCKET_GROUP,              
 A.BUCKET_ID,              
 A.LIFETIME,              
 A.STAGE,         
 A.REVOLVING_FLAG,              
 A.PD_SEGMENT,              
 A.LGD_SEGMENT,              
 A.EAD_SEGMENT,              
 A.PREV_ECL_AMOUNT,              
 A.ECL_MODEL_ID,              
 A.EAD_MODEL_ID,              
 A.CCF_RULES_ID,               
 A.LGD_MODEL_ID,              
 A.PD_MODEL_ID,           
 N.N AS SEQ,              
 CASE WHEN CAST(N.N AS DECIMAL(10,2))/12 <= 1 THEN 1 ELSE CEILING(CAST(N.N AS DECIMAL(10,2))/12) END FL_YEAR,            
 ----CASE WHEN (N.N % 12) = 0 THEN N.N ELSE (N.N % 12) END AS FL_MONTH,            
 CASE WHEN (N.N % 12) = 0 THEN         
 (CASE WHEN CAST(N.N AS DECIMAL(10,2))/12 = 1 THEN N.N ELSE CAST(N.N/CEILING(CAST(N.N AS DECIMAL(10,2))/12) AS INT) END)        
 ELSE         
 (N.N % 12) END AS FL_MONTH,          
 A.EIR,              
 A.OUTSTANDING,              
 A.UNAMORT_COST_AMT,              
 A.UNAMORT_FEE_AMT,              
 CASE WHEN N.N = 1 THEN A.INTEREST_ACCRUED ELSE 0 END AS INTEREST_ACCRUED,              
 A.UNUSED_AMOUNT,              
 A.FAIR_VALUE_AMOUNT,              
 A.EAD_BALANCE AS EAD_BALANCE,          
 A.PLAFOND,              
 CASE WHEN N.N <> 1 AND E.EAD_BALANCE LIKE  '%INTEREST_ACCRUED%' THEN               
 CASE WHEN ISNULL(A.EAD_BALANCE,0) - ISNULL(A.INTEREST_ACCRUED,0) < 0 THEN 0 ELSE ISNULL(A.EAD_BALANCE,0) - ISNULL(A.INTEREST_ACCRUED,0) END               
 ELSE               
 CASE WHEN A.EAD_BALANCE < 0 THEN 0 ELSE A.EAD_BALANCE END               
 END   AS EAD, 
 CASE D.AVERAGE_METHOD WHEN 'WEIGHTED' THEN C.WEIGHTED_AVG_CCF WHEN 'SIMPLE' THEN C.SIMPLE_AVG_CCF END AS CCF,                
 BI_COLLECTABILITY,                
 A.COLL_AMOUNT,    
 A.SEGMENT_FLAG               
 FROM #TEMP A         
 LEFT JOIN IFRS_MASTER_PRODUCT_PARAM PP ON         
 A.PRODUCT_CODE = PP.PRD_CODE         
 AND PP.PRD_TYPE = 'CREDITCARD'             
 INNER JOIN N ON CASE WHEN ISNULL(PP.PRD_CODE,'') = '' THEN 12 ELSE A.LIFETIME END >= N.N        
 JOIN IFRS_ECL_MODEL_DETAIL_EAD B              
 ON A.CCF_RULES_ID = B.CCF_MODEL_ID AND A.ECL_MODEL_ID = B.ECL_MODEL_ID AND A.SEGMENTATION_ID = B.SEGMENTATION_ID              
 LEFT JOIN IFRS_EAD_CCF_HEADER C ON (CASE B.CCF_EFF_DATE_OPTION WHEN 'SELECT_DATE' THEN B.CCF_EFF_DATE WHEN 'LAST_MONTH' THEN DATEADD(DD, -1, A.DOWNLOAD_DATE) END = C.DOWNLOAD_DATE) AND A.CCF_RULES_ID = C.CCF_RULE_ID                
 LEFT JOIN IFRS_CCF_RULES_CONFIG D ON C.CCF_RULE_ID = D.PKID              
 LEFT JOIN IFRS_EAD_RULES_CONFIG E ON A.EAD_MODEL_ID = E.PKID           
 WHERE N.N <= A.LIFETIME        
              
 /*         
        
 SET @START = @START + 1          
 SET @FL_MONTH = @FL_MONTH + 1              
 END           
 SET @ROW_NUMBER = @ROW_NUMBER + 1          
 SET @START = 1          
 SET @FL_MONTH = 1          
 SET @FL_YEAR = 1          
 SET @YEAR = 12            
 END              
        
 */        
END;
GO
