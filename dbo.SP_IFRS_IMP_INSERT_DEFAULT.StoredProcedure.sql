USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_INSERT_DEFAULT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_INSERT_DEFAULT] @DOWNLOAD_DATE DATE = ''                              
AS                       
 DECLARE @V_PREVMONTH DATE                              
 DECLARE @V_CURRDATE DATE                               
 DECLARE @V_PREVDATE DATE                       
 DECLARE @FLAG_SURVIVE_DATE DATE                      
BEGIN                          
                              
IF @DOWNLOAD_DATE = ''                              
BEGIN                              
 SELECT                       
 @V_CURRDATE = EOMONTH(CURRDATE),                      
 @V_PREVDATE = PREVDATE,                       
 @V_PREVMONTH = EOMONTH(DATEADD(M,-1,CURRDATE))                       
 FROM IFRS_PRC_DATE                              
 END                              
 ELSE                               
 BEGIN                          
  set @V_CURRDATE = EOMONTH(@DOWNLOAD_DATE )                          
  set @V_PREVMONTH = EOMONTH(DATEADD(M,-1,@DOWNLOAD_DATE))                            
 END                      
                       
 SELECT @FLAG_SURVIVE_DATE = VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'FLAG_SURVIVE'                      
 --IF OBJECT_ID ('TEMPDB.DBO.#IMA_CURR') IS NOT NULL DROP TABLE #IMA_CURR                              
 --SELECT * INTO #IMA_CURR FROM IFRS_MASTER_ACCOUNT_MONTHLY WHERE DOWNLOAD_DATE =  @V_CURRDATE                      
                      
 -- IF OBJECT_ID ('TEMPDB.DBO.#IMA_PREV') IS NOT NULL DROP TABLE #IMA_PREV                              
 --SELECT * INTO #IMA_PREV FROM IFRS_MASTER_ACCOUNT_MONTHLY WHERE DOWNLOAD_DATE =  @V_PREVMONTH                      
                
 --MENCARI FLAG_COVID19 UNTUK ACCOUNT LAMA YANG DIRESTRU                              
 IF OBJECT_ID ('TEMPDB.DBO.#CURR_RESTRU_SIFAT_PREVIOUS_ACCT') IS NOT NULL DROP TABLE #CURR_RESTRU_SIFAT_PREVIOUS_ACCT                             
SELECT DISTINCT A.PREVIOUS_ACCOUNT_NUMBER, A.CUSTOMER_NUMBER,ISNULL(B.FLAG_RESTRU_COVID19,'N') AS FLAG_RESTRU_COVID19 INTO #CURR_RESTRU_SIFAT_PREVIOUS_ACCT                     
FROM IFRS_MASTER_RESTRU_SIFAT A              
LEFT JOIN IFRS_MASTER_FLAG_COVID B ON               
A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER               
AND A.PREVIOUS_ACCOUNT_NUMBER = B.PREVIOUS_ACCOUNT_NUMBER              
AND B.DOWNLOAD_DATE = @V_CURRDATE                       
 --MENCARI FLAG_RESTRU UNTUK EXISTING ACCOUNT              
IF OBJECT_ID ('TEMPDB.DBO.#CURR_RESTRU_SIFAT_EXISTING_ACCT') IS NOT NULL DROP TABLE #CURR_RESTRU_SIFAT_EXISTING_ACCT                            
SELECT  DISTINCT A.DOWNLOAD_DATE, A.CUSTOMER_NUMBER,A.PREVIOUS_ACCOUNT_NUMBER,A.ACCOUNT_NUMBER,ISNULL(C.FLAG_RESTRU_COVID19,              
'N') AS FLAG_RESTRU_COVID19              
INTO #CURR_RESTRU_SIFAT_EXISTING_ACCT              
FROM IFRS_MASTER_RESTRU_SIFAT A JOIN (              
SELECT              
  MAX(DOWNLOAD_DATE)as DOWNLOAD_DATE              
 ,CUSTOMER_NUMBER              
 ,ACCOUNT_NUMBER              
FROM IFRS_MASTER_RESTRU_SIFAT              
GROUP BY CUSTOMER_NUMBER,ACCOUNT_NUMBER) B ON A.DOWNLOAD_DATE=B.DOWNLOAD_DATE and A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER              
LEFT JOIN IFRS_MASTER_FLAG_COVID C ON A.ACCOUNT_NUMBER = C.ACCOUNT_NUMBER AND A.CUSTOMER_NUMBER = C.CUSTOMER_NUMBER              
AND C.DOWNLOAD_DATE = @V_CURRDATE                       
order by DOWNLOAD_DATE,ACCOUNT_NUMBER              
                
--DELETE DUPLICATE OLD ACCOUNT NUMBER IN SAME DOWNLOAD_DATE--                  
DELETE A   
FROM  #CURR_RESTRU_SIFAT_PREVIOUS_ACCT A   
INNER JOIN  #CURR_RESTRU_SIFAT_EXISTING_ACCT b   
ON a.PREVIOUS_ACCOUNT_NUMBER = b.ACCOUNT_NUMBER and a.FLAG_RESTRU_COVID19 <> b.FLAG_RESTRU_COVID19   
INNER JOIN  (SELECT  CUSTOMER_NUMBER,PREVIOUS_ACCOUNT_NUMBER,COUNT(*) AS CT FROM #CURR_RESTRU_SIFAT_PREVIOUS_ACCT   
GROUP BY CUSTOMER_NUMBER,PREVIOUS_ACCOUNT_NUMBER HAVING COUNT(*)>1) C    
ON  A.CUSTOMER_NUMBER = C.CUSTOMER_NUMBER AND A.PREVIOUS_ACCOUNT_NUMBER = C.PREVIOUS_ACCOUNT_NUMBER    
                              
 IF OBJECT_ID ('TEMPDB.DBO.#CURR_WO') IS NOT NULL DROP TABLE #CURR_WO                              
SELECT DISTINCT MASTERID, CUSTOMER_NUMBER INTO #CURR_WO FROM IFRS_MASTER_WO WHERE DOWNLOAD_DATE  = @V_CURRDATE                              
                      
-- IF OBJECT_ID('TEMPDB.DBO.#PREV_RESTRU_SIFAT') IS NOT NULL DROP TABLE #PREV_RESTRU_SIFAT                    
--SELECT DISTINCT DOWNLOAD_DATE, MASTERID, FLAG_RESTRU_COVID19 INTO #PREV_RESTRU_SIFAT FROM IFRS_MASTER_RESTRU_SIFAT WHERE DOWNLOAD_DATE = @V_PREVMONTH                    
                
IF OBJECT_ID('TEMPDB.DBO.#PREV_SURVIVE') IS NOT NULL DROP TABLE #PREV_SURVIVE                    
SELECT DISTINCT DOWNLOAD_DATE, CUSTOMER_NUMBER, PREVIOUS_ACCOUNT_NUMBER , ACCOUNT_NUMBER, SURVIVE_FLAG INTO #PREV_SURVIVE                    
FROM IFRS_MASTER_SURVIVE WHERE DOWNLOAD_DATE = @V_PREVMONTH                    
                       
-- DOWNLOAD_DATE LAG 1 BULAN                     
IF OBJECT_ID('TEMPDB.DBO.#PREV_SURVIVE_RESTRU') IS NOT NULL                    
 DROP TABLE #PREV_SURVIVE_RESTRU                    
SELECT DISTINCT                 
  A.CUSTOMER_NUMBER                
 ,A.PREVIOUS_ACCOUNT_NUMBER                
 ,A.FLAG_RESTRU_COVID19                  
 ,B.SURVIVE_FLAG                  
INTO #PREV_SURVIVE_RESTRU                    
FROM #CURR_RESTRU_SIFAT_PREVIOUS_ACCT A                    
LEFT JOIN #PREV_SURVIVE B ON  A.PREVIOUS_ACCOUNT_NUMBER = B.PREVIOUS_ACCOUNT_NUMBER AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER                    
                
IF OBJECT_ID('TEMPDB.DBO.#CURR_SURVIVE_RESTRU') IS NOT NULL                    
 DROP TABLE #CURR_SURVIVE_RESTRU                
SELECT DISTINCT                 
  A.CUSTOMER_NUMBER                
 ,A.ACCOUNT_NUMBER                
 ,A.FLAG_RESTRU_COVID19                  
 ,B.SURVIVE_FLAG                  
INTO #CURR_SURVIVE_RESTRU                    
FROM #CURR_RESTRU_SIFAT_EXISTING_ACCT A                    
LEFT JOIN #PREV_SURVIVE B ON  A.ACCOUNT_NUMBER = B.ACCOUNT_NUMBER AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER                    
                  
                               
IF OBJECT_ID ('TEMPDB.DBO.#IFRS_IMP_DEFAULT_STATUS')  IS NOT NULL DROP TABLE #IFRS_IMP_DEFAULT_STATUS                              
SELECT @V_PREVMONTH AS DOWNLOAD_DATE                              
,A.MASTERID                              
,A.ACCOUNT_NUMBER                              
,A.PRODUCT_CODE                              
,A.CUSTOMER_NUMBER                              
,A.BI_COLLECTABILITY                              
,NULL as BI_COLLECT_CIF        --,A.BI_COLLECT_CIF AS BI_COLLECT_CIF                              
,A.DAY_PAST_DUE                ,NULL AS DPD_CIF    --A.DPD_CIF                              
,A.DPD_FINAL                              
,NULL AS  DPD_FINAL_CIF  --A.DPD_FINAL_CIF                              
,CASE WHEN C.MASTERID IS NOT NULL THEN 1 ELSE 0 END WO_FLAG                              
,NULL AS WO_FLAG_CIF                              
,CASE WHEN (B.PREVIOUS_ACCOUNT_NUMBER IS NOT NULL OR F.ACCOUNT_NUMBER IS NOT NULL) THEN 1 ELSE 0 END AS  RESTRU_SIFAT_FLAG                              
,NULL AS RESTRU_SIFAT_FLAG_CIF                              
,CASE WHEN D.MASTERID IS NULL AND C.MASTERID IS NULL AND B.PREVIOUS_ACCOUNT_NUMBER IS NULL AND A.DAY_PAST_DUE <= 180 THEN 1 ELSE 0 END AS  FP_FLAG                              
,A.EXCHANGE_RATE                              
,A.PLAFOND                              
,A.OUTSTANDING                              
,A.INTEREST_RATE                              
,A.EIR                              
,A.SUB_SEGMENT                      
,A.FACILITY_NUMBER                      
,CASE WHEN D.MASTERID IS NULL AND C.MASTERID IS NULL AND B.PREVIOUS_ACCOUNT_NUMBER IS NULL  THEN 1 ELSE 0 END AS FP_FLAG_ORIG                      
--CR RESTRU COVID START INDRA                
,CASE WHEN (RTRIM(LTRIM(E.FLAG_RESTRU_COVID19)) = 'Y' OR RTRIM(LTRIM(F.FLAG_RESTRU_COVID19)) = 'Y') THEN 1 ELSE 0 END  as FLAG_RESTRU_COVID19 --CR RESTRU COVID 20230316                   
,CASE                       
  WHEN                      
  @V_PREVMONTH < @FLAG_SURVIVE_DATE--FEB 2021                      
  AND (                
  UPPER(LTRIM(RTRIM(E.SURVIVE_FLAG))) NOT IN ('Y','N' )                
  OR UPPER(LTRIM(RTRIM(F.SURVIVE_FLAG))) NOT IN ('Y','N' )                  
  OR E.SURVIVE_FLAG IS NULL OR F.SURVIVE_FLAG IS NULL)                
  AND (E.FLAG_RESTRU_COVID19 = 'Y' OR F.FLAG_RESTRU_COVID19 = 'Y')                    
   THEN 1                       
    WHEN                       
 (                
    (ISNULL(E.FLAG_RESTRU_COVID19,'N') = 'N' AND ISNULL(F.FLAG_RESTRU_COVID19,'N') = 'N')         
  )              
   THEN NULL  --SURVIVE_FLAG NULL                     
  WHEN                       
   (UPPER(LTRIM(RTRIM(E.SURVIVE_FLAG))) = 'Y' OR UPPER(LTRIM(RTRIM(F.SURVIVE_FLAG))) = 'Y')               
   THEN 1     
 -- WHEN                       
 ----@V_PREVMONTH >= @FLAG_SURVIVE_DATE--FEB 2021 AND     
 --(                
 -- --UPPER(LTRIM(RTRIM(ISNULL(E.SURVIVE_FLAG,'N')))) NOT IN ('Y' )                 
 -- --OR UPPER(LTRIM(RTRIM(ISNULL(F.SURVIVE_FLAG,'N')))) NOT IN ('Y' )                
 -- --AND    
 --  (E.SURVIVE_FLAG IS NULL OR F.SURVIVE_FLAG IS NULL)                 
 -- AND (E.FLAG_RESTRU_COVID19 = 'Y' OR F.FLAG_RESTRU_COVID19 = 'Y')         
 -- )              
 --  THEN 0                      
  ELSE 0                       
  END AS SURVIVE_FLAG                  
  ,NULL AS FLAG_RESTRU_COVID19_CIF          
  ,NULL AS SURVIVE_FLAG_CIF            
--CR RESTRU COVID END INDRA                
INTO #IFRS_IMP_DEFAULT_STATUS         
FROM IFRS_IMA_IMP_PREV A                 
--CR RESTRU COVID START INDRA                
LEFT JOIN #CURR_RESTRU_SIFAT_PREVIOUS_ACCT B  ON A.ACCOUNT_NUMBER = B.PREVIOUS_ACCOUNT_NUMBER  AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER                          
LEFT JOIN #CURR_WO C ON A.MASTERID = C.MASTERID                       
LEFT JOIN IFRS_IMA_IMP_CURR D ON A.MASTERID = D.MASTERID                       
LEFT JOIN #PREV_SURVIVE_RESTRU E ON A.ACCOUNT_NUMBER = E.PREVIOUS_ACCOUNT_NUMBER  AND A.CUSTOMER_NUMBER = E.CUSTOMER_NUMBER  --CR RESTRU COVID19 20230316                      
LEFT JOIN #CURR_SURVIVE_RESTRU F ON A.ACCOUNT_NUMBER = F.ACCOUNT_NUMBER  AND A.CUSTOMER_NUMBER = F.CUSTOMER_NUMBER           --CR RESTRU COVID19 20230316                      
--CR RESTRU COVID END INDRA                
WHERE A.DATA_SOURCE <> 'LIMIT'                               
                          
                      
IF OBJECT_ID ('TEMPDB.DBO.#CIF_LEVEL') IS NOT NULL DROP TABLE #CIF_LEVEL                              
SELECT CUSTOMER_NUMBER,SUB_SEGMENT, MAX(WO_FLAG) AS WO_FLAG_CIF, MAX(RESTRU_SIFAT_FLAG) AS RESTRU_SIFAT_FLAG_CIF, MIN(FP_FLAG) AS FP_FLAG_CIF                      
,MAX(BI_COLLECTABILITY) AS BI_COLLECT_CIF, MAX(DAY_PAST_DUE) AS DPD_CIF, MAX(DPD_FINAL) AS DPD_FINAL_CIF, MIN(FP_FLAG_ORIG) AS FP_FLAG_ORIG_CIF           
--RESTRU COVID          
,FLAG_RESTRU_COVID19_CIF = MAX(FLAG_RESTRU_COVID19)          
,SURVIVE_FLAG_CIF = MIN(SURVIVE_FLAG)          
--RESTRU COVID                     
INTO #CIF_LEVEL                       
FROM #IFRS_IMP_DEFAULT_STATUS --WHERE DOWNLOAD_DATE = @V_PREVMONTH                               
GROUP BY CUSTOMER_NUMBER, SUB_SEGMENT                              
                              
UPDATE A                              
SET A.WO_FLAG_CIF = B.WO_FLAG_CIF, A.RESTRU_SIFAT_FLAG_CIF = B.RESTRU_SIFAT_FLAG_CIF,                       
A.BI_COLLECT_CIF = B.BI_COLLECT_CIF,A.DPD_CIF = B.DPD_CIF,A.DPD_FINAL_CIF = B.DPD_FINAL_CIF            
--RESTRU COVID            
,A.FLAG_RESTRU_COVID19_CIF = B.FLAG_RESTRU_COVID19_CIF,A.SURVIVE_FLAG_CIF = B.SURVIVE_FLAG_CIF                    
--RESTRU COVID          
FROM #IFRS_IMP_DEFAULT_STATUS A INNER JOIN  #CIF_LEVEL B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER AND A.SUB_SEGMENT = B.SUB_SEGMENT                              
--WHERE A.DOWNLOAD_DATE = @V_PREVMONTH                               
                      
--- UPDATE FOR CIF LEVEL FOR FP_FLAG                       
UPDATE A                              
SET A.FP_FLAG = B.FP_FLAG_CIF,                      
A.FP_FLAG_ORIG = B.FP_FLAG_ORIG_CIF                                  
FROM #IFRS_IMP_DEFAULT_STATUS A                       
INNER JOIN  #CIF_LEVEL B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER AND A.SUB_SEGMENT= B.SUB_SEGMENT                      
WHERE A.SUB_SEGMENT IN (SELECT DISTINCT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'B154')                      
--- UPDATE FOR CIF LEVEL FOR FP_FLAG                       
                              
DELETE  IFRS_IMP_DEFAULT_STATUS WHERE DOWNLOAD_DATE = @V_PREVMONTH                          
                          
INSERT INTO IFRS_IMP_DEFAULT_STATUS                              
(                      
 DOWNLOAD_DATE                              
 ,MASTERID                              
 ,ACCOUNT_NUMBER                              
 ,PRODUCT_CODE                              
 ,CUSTOMER_NUMBER                              
 ,BI_COLLECTABILITY                              
 ,BI_COLLECT_CIF                              
 ,DAY_PAST_DUE                              
 ,DPD_CIF                              
 ,DPD_FINAL                              
 ,DPD_FINAL_CIF                              
 ,WO_FLAG                              
 ,WO_FLAG_CIF                              
 ,RESTRU_SIFAT_FLAG                              
 ,RESTRU_SIFAT_FLAG_CIF                              
 ,FP_FLAG                              
 ,EXCHANGE_RATE                              
 ,PLAFOND                              
 ,OUTSTANDING                         
 ,INTEREST_RATE                              
 ,EIR                      
 ,SUB_SEGMENT                      
 ,FP_FLAG_ORIG                      
 ,FACILITY_NUMBER                      
 ,FLAG_RESTRU_COVID19                      
 ,SURVIVE_FLAG            
 ,FLAG_RESTRU_COVID19_CIF                    
 ,SURVIVE_FLAG_CIF          
)                              
SELECT                               
 DOWNLOAD_DATE                     
 ,MASTERID                              
 ,ACCOUNT_NUMBER                              
 ,PRODUCT_CODE                              
 ,CUSTOMER_NUMBER                              
 ,BI_COLLECTABILITY                              
 ,BI_COLLECT_CIF                              
 ,DAY_PAST_DUE                              
 ,DPD_CIF                              
 ,DPD_FINAL                              
 ,DPD_FINAL_CIF                              
 ,WO_FLAG                              
 ,WO_FLAG_CIF                          
 ,RESTRU_SIFAT_FLAG                              
 ,RESTRU_SIFAT_FLAG_CIF                              
 ,FP_FLAG                              
 ,EXCHANGE_RATE                              
 ,PLAFOND                              
 ,OUTSTANDING                              
 ,INTEREST_RATE                              
 ,EIR                      
 ,SUB_SEGMENT                      
 ,FP_FLAG_ORIG                      
 ,FACILITY_NUMBER                      
 ,FLAG_RESTRU_COVID19                      
 ,SURVIVE_FLAG                      
 ,FLAG_RESTRU_COVID19_CIF                    
 ,SURVIVE_FLAG_CIF          
FROM #IFRS_IMP_DEFAULT_STATUS                              
                              
END 
GO
