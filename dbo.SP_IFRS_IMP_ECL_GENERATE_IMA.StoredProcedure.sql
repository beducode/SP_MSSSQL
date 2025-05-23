USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_ECL_GENERATE_IMA]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_ECL_GENERATE_IMA]   
@DOWNLOAD_DATE DATE = NULL        
 ,@MODEL_ID BIGINT = 0        
AS        
BEGIN        
 DECLARE @V_CURRDATE DATE        
 DECLARE @V_CCFDATE DATE        
 DECLARE @V_PREPAYMENTDATE DATE        
 DECLARE @V_STRSQL VARCHAR(MAX) = ''        
 DECLARE @QRY_RN INT        
 DECLARE @V_TABLE_NAME VARCHAR(100)        
        
 IF (@DOWNLOAD_DATE IS NULL)        
 BEGIN        
  SELECT @V_CURRDATE = CURRDATE        
  FROM IFRS_PRC_DATE        
 END        
 ELSE        
 BEGIN        
  SET @V_CURRDATE = @DOWNLOAD_DATE        
 END        
        
 SELECT @V_CCFDATE = @V_CURRDATE        
        
 SELECT @V_PREPAYMENTDATE = @V_CURRDATE        
        
 TRUNCATE TABLE TMP_IFRS_ECL_IMA        
        
 DROP TABLE        
        
 IF EXISTS #TMP_IFRS_ECL_MODEL        
  SELECT DISTINCT @V_CURRDATE AS DOWNLOAD_DATE        
   ,A.PKID AS ECL_MODEL_ID        
   ,B.EAD_MODEL_ID        
   ,A.ECL_MODEL_NAME        
   ,I.SUB_SEGMENT AS SUB_SEGMENT_EAD        
   ,B.SEGMENTATION_ID        
   ,N.SUB_SEGMENT AS SEGMENTATION_NAME        
   ,C.CCF_FLAG        
   ,B.CCF_MODEL_ID AS CCF_RULES_ID        
   ,D.LGD_MODEL_ID        
   ,D.EFF_DATE AS LGD_EFF_DATE        
   ,D.ME_MODEL_ID AS LGD_ME_MODEL_ID        
   ,J.SUB_SEGMENT AS SUB_SEGMENT_LGD        
   ,E.PD_MODEL_ID        
   ,E.ME_MODEL_ID AS PD_ME_MODEL_ID        
   ,E.EFF_DATE AS PD_EFF_DATE        
   ,K.SUB_SEGMENT AS SUB_SEGMENT_PD        
   ,F.BUCKET_GROUP        
   ,C.EAD_BALANCE        
   ,F.LT_RULE_ID        
   ,F.SICR_RULE_ID        
   ,H.EXPECTED_LIFE        
   ,F.DEFAULT_RULE_ID        
   ,B.CCF_EFF_DATE_OPTION        
   ,L.AVERAGE_METHOD        
   ,CASE B.CCF_EFF_DATE_OPTION        
    WHEN 'SELECT_DATE'        
     THEN B.CCF_EFF_DATE        
    WHEN 'LAST_MONTH'        
     THEN DATEADD(DD, - 1, @V_CURRDATE)        
    END AS CCF_EFF_DATE        
   ,CASE L.AVERAGE_METHOD        
    WHEN 'WEIGHTED'        
     THEN M.WEIGHTED_AVG_CCF        
    WHEN 'SIMPLE'        
     THEN M.SIMPLE_AVG_CCF        
    END AS CCF        
   ,I.SEGMENT        
   ,I.SUB_SEGMENT        
   ,I.GROUP_SEGMENT        
  INTO #TMP_IFRS_ECL_MODEL        
  FROM IFRS_ECL_MODEL_HEADER A        
  JOIN IFRS_ECL_MODEL_DETAIL_EAD B ON A.PKID = B.ECL_MODEL_ID        
  JOIN IFRS_EAD_RULES_CONFIG C ON B.EAD_MODEL_ID = C.PKID        
  JOIN IFRS_ECL_MODEL_DETAIL_LGD D ON A.PKID = D.ECL_MODEL_ID        
   AND B.SEGMENTATION_ID = D.SEGMENTATION_ID        
  JOIN IFRS_ECL_MODEL_DETAIL_PD E ON A.PKID = E.ECL_MODEL_ID        
   AND B.SEGMENTATION_ID = E.SEGMENTATION_ID        
  JOIN IFRS_ECL_MODEL_DETAIL_PF F ON A.PKID = F.ECL_MODEL_ID        
   AND B.SEGMENTATION_ID = F.SEGMENTATION_ID        
  LEFT JOIN IFRS_LGD_RULES_CONFIG G ON D.LGD_MODEL_ID = G.PKID        
  LEFT JOIN IFRS_PD_RULES_CONFIG H ON E.PD_MODEL_ID = H.PKID        
  LEFT JOIN IFRS_MSTR_SEGMENT_RULES_HEADER I ON C.SEGMENTATION_ID = I.PKID        
  LEFT JOIN IFRS_MSTR_SEGMENT_RULES_HEADER J ON G.SEGMENTATION_ID = J.PKID        
  LEFT JOIN IFRS_MSTR_SEGMENT_RULES_HEADER K ON H.SEGMENTATION_ID = K.PKID        
  LEFT JOIN IFRS_CCF_RULES_CONFIG L ON B.CCF_MODEL_ID = L.PKID        
  LEFT JOIN IFRS_EAD_CCF_HEADER M ON (        
    CASE B.CCF_EFF_DATE_OPTION        
     WHEN 'SELECT_DATE'        
      THEN B.CCF_EFF_DATE        
     WHEN 'LAST_MONTH'        
      THEN DATEADD(DD, - 1, @V_CURRDATE)        
     END = M.DOWNLOAD_DATE        
    )        
   AND L.PKID = M.CCF_RULE_ID        
  LEFT JOIN IFRS_MSTR_SEGMENT_RULES_HEADER N ON B.SEGMENTATION_ID = N.PKID        
  WHERE A.IS_DELETE = 0        
   AND B.IS_DELETE = 0        
   AND C.IS_DELETE = 0        
   AND C.ACTIVE_FLAG = 1        
   AND D.IS_DELETE = 0        
   AND E.IS_DELETE = 0        
   AND F.IS_DELETE = 0        
   AND (        
    (        
     @MODEL_ID = 0        
     AND A.ACTIVE_STATUS = 1        
     )        
    OR (A.PKID = @MODEL_ID)        
    )        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'UNUSED_AMOUNT', 'A.UNUSED_AMOUNT')        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'OUTSTANDING', 'A.OUTSTANDING')        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'INTEREST_ACCRUED', 'A.INTEREST_ACCRUED')        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'COLL_AMOUNT', 'A.COLL_AMOUNT')        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'CCF', 'ISNULL(A.CCF, 0)')        
        
 UPDATE #TMP_IFRS_ECL_MODEL        
 SET EAD_BALANCE = REPLACE(EAD_BALANCE, '+', ' + ')        
        
 UPDATE X        
 SET X.CCF_EFF_DATE = Z.CCF_EFF_DATE        
  ,X.CCF_RULE_ID = Z.CCF_RULES_ID        
  ,X.CCF = Z.CCF        
 FROM IFRS_IMA_IMP_CURR X(NOLOCK)        
 LEFT JOIN IFRS_MSTR_SEGMENT_RULES_HEADER Y ON X.SEGMENT = Y.SEGMENT        
  AND X.SUB_SEGMENT = Y.SUB_SEGMENT        
  AND X.GROUP_SEGMENT = Y.GROUP_SEGMENT        
 LEFT JOIN #TMP_IFRS_ECL_MODEL Z ON Z.SEGMENTATION_ID = Y.PKID        
 WHERE Y.SEGMENT_TYPE = 'PORTFOLIO_SEGMENT'        
        
        
 --CR JENIUS PAYLATER UPDATE UNUSED AMOUNT = 0 FOR DEAL_TYPE = 'HP'        
 UPDATE X        
 SET X.UNUSED_AMOUNT = 0        
 FROM IFRS_IMA_IMP_CURR X(NOLOCK)        
 LEFT JOIN IFRS_CREDITLINE_JENIUS Y ON X.CUSTOMER_NUMBER = Y.CUSTOMER_NUMBER AND X.PRODUCT_CODE = Y.DEAL_TYPE        
 WHERE Y.DEAL_TYPE IS NOT NULL     
 AND Y.ELIGIBILITY_STATUS IN ('NOT_ELIGIBLE','NOT ELIGIBLE')        
        
 DROP TABLE        
        
 IF EXISTS #TMP_QRY        
  SELECT ROW_NUMBER() OVER (        
    ORDER BY A.ECL_MODEL_ID        
    ) RN        
   ,'SELECT                                        
    A.DOWNLOAD_DATE,                                                          
    A.MASTERID,                                                          
    A.GROUP_SEGMENT,                                                          
    A.SEGMENT,                                                          
    A.SUB_SEGMENT, ' + ISNULL(CAST(A.SEGMENTATION_ID AS VARCHAR(10)), '') + ' AS SEGMENTATION_ID,                                   
    A.ACCOUNT_NUMBER,                                                     
    A.CUSTOMER_NUMBER, ' + ISNULL(CAST(A.SICR_RULE_ID AS VARCHAR(10)), '') +         
   ' AS SICR_RULE_ID,                                                          
    0 AS SICR_FLAG,                                                                  
    A.DPD_CIF,                                                           
    A.PRODUCT_ENTITY,                                                    
    A.DATA_SOURCE,                                                   
    A.PRODUCT_CODE,                                                   
    A.PRODUCT_TYPE,                                                      
    A.PRODUCT_GROUP,                                                   
    A.STAFF_LOAN_FLAG,                                                   
    A.IS_IMPAIRED, ''' + ISNULL(A.SUB_SEGMENT_PD, '') + ''' AS SUB_SEGMENT_PD, ''' + ISNULL(A.SUB_SEGMENT_LGD, '') + ''' AS SUB_SEGMENT_LGD, ''' + ISNULL(A.SUB_SEGMENT_EAD, '') + ''' AS SUB_SEGMENT_EAD,                                                         
    ISNULL(E.ECL_AMOUNT,0) AS PREV_ECL_AMOUNT, ''' + ISNULL(A.BUCKET_GROUP, '') +         
   ''' AS BUCKET_GROUP,                                                  
    D.BUCKET_ID,                                                      
    A.REVOLVING_FLAG,                                                          
    CASE WHEN ISNULL(A.EIR, 0) <> 0 THEN A.EIR WHEN ISNULL(A.INTEREST_RATE, 0) <> 0 THEN A.INTEREST_RATE ELSE F.AVG_EIR * 100.00 END AS EIR ,                                                      
    A.OUTSTANDING,                                                          
    ISNULL(A.UNAMORT_COST_AMT,0) AS UNAMORT_COST_AMT,                                                          
    ISNULL(A.UNAMORT_FEE_AMT,0) AS UNAMORT_FEE_AMT,           
    ISNULL(CASE WHEN A.INTEREST_ACCRUED < 0 THEN 0 ELSE A.INTEREST_ACCRUED END, 0) AS INTEREST_ACCRUED,                                            
    ISNULL(A.UNUSED_AMOUNT,0) AS UNUSED_AMOUNT,                                                          
    ISNULL(A.FAIR_VALUE_AMOUNT,0) AS FAIR_VALUE_AMOUNT,                                                    
    CASE WHEN A.PRODUCT_TYPE_1 <> ''PRK'' AND A.DATA_SOURCE NOT IN  (''LIMIT'',''LIMIT_T24'')                                                    
    THEN                                                      
     ISNULL(CASE WHEN A.BI_COLLECTABILITY >= 3 THEN '         
   + CASE         
    WHEN A.EAD_BALANCE LIKE '%A.INTEREST_ACCRUED%'        
     THEN REPLACE(REPLACE(A.EAD_BALANCE, 'A.UNUSED_AMOUNT', 0), 'A.INTEREST_ACCRUED', '0')        
    ELSE REPLACE(A.EAD_BALANCE, 'A.UNUSED_AMOUNT', 0)        
    END + ' ELSE ' + REPLACE( CASE WHEN A.EAD_BALANCE LIKE '%UNUSED_AMOUNT%' THEN A.EAD_BALANCE ELSE REPLACE(A.EAD_BALANCE, 'A.UNUSED_AMOUNT', 0) END, 'A.INTEREST_ACCRUED', 'CASE WHEN A.INTEREST_ACCRUED < 0 THEN   0 ELSE A.INTEREST_ACCRUED END') + ' END, 0)                                       
    ELSE                                                      
     ISNULL(CASE WHEN A.BI_COLLECTABILITY >= 3 THEN ' + CASE         
    -- CHANGE HERE | UNUSED_AMOUNT TO 0                                                    
    WHEN A.EAD_BALANCE LIKE '%A.INTEREST_ACCRUED%'        
     THEN REPLACE(REPLACE(A.EAD_BALANCE, 'A.INTEREST_ACCRUED', '0'), 'A.UNUSED_AMOUNT', '0')        
    ELSE REPLACE(A.EAD_BALANCE, 'A.UNUSED_AMOUNT', '0')        
    END + ' WHEN A.DPD_FINAL > 30 THEN ' + REPLACE(REPLACE(A.EAD_BALANCE, 'A.UNUSED_AMOUNT', '0'), 'A.INTEREST_ACCRUED', 'CASE WHEN A.INTEREST_ACCRUED < 0 THEN 0 ELSE A.INTEREST_ACCRUED END') +        
   -- UNTIL HERE | UNUSED_AMOUNT TO 0                                   
   ' ELSE ' + REPLACE(A.EAD_BALANCE, 'A.INTEREST_ACCRUED', 'CASE WHEN A.INTEREST_ACCRUED < 0 THEN 0 ELSE A.INTEREST_ACCRUED END') + ' END, 0)                                                          
    END AS EAD_BALANCE,                                                                
    ISNULL(A.PLAFOND,0) PLAFOND, ' + ISNULL(CAST(A.ECL_MODEL_ID AS VARCHAR(10)), '') + ' AS ECL_MODEL_ID, ' + ISNULL(CAST(A.EAD_MODEL_ID AS VARCHAR(10)), '') + ' AS EAD_MODEL_ID, ' + ISNULL(CAST(A.CCF_FLAG AS VARCHAR(10)), '') + ' AS CCF_FLAG, ' + ISNULL
(  
    
      
CAST(A.CCF_RULES_ID AS VARCHAR(10)), 'NULL') + ' AS CCF_RULE_ID, ' + ISNULL(CAST(A.LGD_MODEL_ID AS VARCHAR(10)), '') + ' AS LGD_MODEL_ID, ' + ISNULL(CAST(A.PD_MODEL_ID AS VARCHAR(10)), '') + ' AS PD_MODEL_ID, ' + ISNULL(CAST(A.PD_ME_MODEL_ID AS VARCHAR(10
  
    
      
)), '') +         
   ' AS PD_ME_MODEL_ID,                                                           
    CASE             
  WHEN A.PRODUCT_TYPE_1 = ''PRK'' AND A.REMAINING_TENOR <= 0 THEN 12               
  WHEN A.DATA_SOURCE = ''LOAN_T24'' AND ISNULL(A.REVOLVING_FLAG,1) = 1 AND A.REMAINING_TENOR <= 0 THEN 12              
  ELSE A.REMAINING_TENOR             
 END AS LIFETIME,' +        
   --CHANGE 20201008 KPMG CHANGES FOR PRK           -- CASE WHEN A.PRODUCT_TYPE_1 <> ''PRK'' THEN A.REMAINING_TENOR ELSE ' + ISNULL(CAST(A.EXPECTED_LIFE AS VARCHAR(10)), 'NULL') + ' END AS LIFETIME,'                
   ISNULL(CAST(A.DEFAULT_RULE_ID AS VARCHAR(10)), 'NULL') + ' AS DEFAULT_RULE_ID,                                                           
    A.DPD_FINAL,                                                           
    A.BI_COLLECTABILITY,                                                           
    A.DPD_FINAL_CIF,                                              
    A.BI_COLLECT_CIF,                                        
    A.RESTRUCTURE_COLLECT_FLAG,                                                
    A.PRODUCT_TYPE_1,                                                
    NULL AS CCF,                                               
    ''' + CAST(ISNULL(A.CCF_EFF_DATE, '') AS VARCHAR(20)) +         
   ''' AS CCF_EFF_DATE,                                      
 A.RESTRUCTURE_COLLECT_FLAG_CIF,                                    
    A.IMPAIRED_FLAG                                     
 ,A.INITIAL_RATING_CODE                                
 ,A.RATING_CODE                                
    ,A.RATING_DOWNGRADE                                
    ,A.PD_INITIAL_RATE                                
    ,A.WATCHLIST_FLAG                                
    ,A.PD_CURRENT_RATE                                
    ,A.PD_CHANGE             
 ,A.COLL_AMOUNT                    
 ,A.EXT_RATING_AGENCY                    
 ,A.EXT_RATING_CODE                    
 ,A.EXT_INIT_RATING_CODE                    
 ,A.EXT_RATING_DOWNGRADE
 ,A.SEGMENT_FLAG                                      
 FROM IFRS_IMA_IMP_CURR A                                                           
 JOIN IFRS_MSTR_SEGMENT_RULES_HEADER B ON A.GROUP_SEGMENT = B.GROUP_SEGMENT                                                        
 AND A.SEGMENT = B.SEGMENT                              
 AND A.SUB_SEGMENT = B.SUB_SEGMENT                                                     
 JOIN IFRS_BUCKET_HEADER C ON '''         
   + ISNULL(A.BUCKET_GROUP, 1) +         
   ''' = C.BUCKET_GROUP                                                   
 JOIN IFRS_BUCKET_DETAIL D ON C.BUCKET_GROUP = D.BUCKET_GROUP                                                               
 AND ((CASE                                              
            WHEN C.OPTION_GROUPING = ''DPD''                       
     THEN A.DAY_PAST_DUE                                                                 
            WHEN C.OPTION_GROUPING = ''DPD_CIF''                                                     
            THEN A.DPD_CIF                                                       
            WHEN C.OPTION_GROUPING = ''DPD_FINAL''                                   
            THEN A.DPD_FINAL                                                                   
            WHEN C.OPTION_GROUPING = ''DPD_FINAL_CIF''                                        
            THEN A.DPD_FINAL_CIF                                                     
            WHEN C.OPTION_GROUPING = ''BIC''                                                     
            THEN A.BI_COLLECTABILITY                                            
 END) BETWEEN D.RANGE_START AND D.RANGE_END                                   
  OR C.OPTION_GROUPING  IN (''IR'',''ER'') AND  D.SUB_BUCKET_GROUP = CASE WHEN C.OPTION_GROUPING = ''ER'' THEN A.EXT_RATING_CODE WHEN C.OPTION_GROUPING = ''IR'' THEN A.RATING_CODE END)                                     
 LEFT JOIN IFRS_IMA_IMP_PREV E ON A.MASTERID = E.MASTERID                                                                    
 LEFT JOIN IFRS_IMP_AVG_EIR F ON A.DOWNLOAD_DATE = F.DOWNLOAD_DATE AND A.EIR_SEGMENT = F.EIR_SEGMENT                                            
 WHERE B.PKID = '         
   + ISNULL(CAST(A.SEGMENTATION_ID AS VARCHAR(10)), '') + '                                                      
    AND  A.DOWNLOAD_DATE = ''' + CAST(@V_CURRDATE AS VARCHAR(10)) + '''                                
    AND B.SEGMENT_TYPE = ''PORTFOLIO_SEGMENT''                                                           
    AND A.ACCOUNT_STATUS = ''A''                                           
    AND ISNULL(A.IFRS9_CLASS,'''') <> ''FVTPL'' ' QRY        
  --  AND ISNULL(A.IMPAIRED_FLAG, ''C'') = ''C''                                                            
  INTO #TMP_QRY        
  FROM #TMP_IFRS_ECL_MODEL A        
        
 DECLARE @XXX VARCHAR(MAX)        
        
 SELECT @XXX = QRY        
 FROM #TMP_QRY        
        
 WHILE EXISTS (        
   SELECT TOP 1 1        
   FROM #TMP_QRY        
   )        
 BEGIN        
  SELECT TOP 1 @QRY_RN = RN        
   ,@V_STRSQL = QRY        
  FROM #TMP_QRY        
        
  INSERT INTO TMP_IFRS_ECL_IMA (        
   DOWNLOAD_DATE        
   ,MASTERID        
   ,GROUP_SEGMENT        
   ,SEGMENT        
   ,SUB_SEGMENT        
   ,SEGMENTATION_ID        
   ,ACCOUNT_NUMBER        
   ,CUSTOMER_NUMBER        
   ,SICR_RULE_ID        
   ,SICR_FLAG        
   ,DPD_CIF        
   ,PRODUCT_ENTITY        
   ,DATA_SOURCE        
   ,PRODUCT_CODE        
   ,PRODUCT_TYPE        
   ,PRODUCT_GROUP        
   ,STAFF_LOAN_FLAG        
   ,IS_IMPAIRED        
   ,PD_SEGMENT        
   ,LGD_SEGMENT        
   ,EAD_SEGMENT        
   ,PREV_ECL_AMOUNT        
   ,BUCKET_GROUP        
   ,BUCKET_ID        
   ,REVOLVING_FLAG        
   ,EIR        
   ,OUTSTANDING        
   ,UNAMORT_COST_AMT        
   ,UNAMORT_FEE_AMT        
   ,INTEREST_ACCRUED        
   ,UNUSED_AMOUNT        
   ,FAIR_VALUE_AMOUNT        
   ,EAD_BALANCE        
   ,PLAFOND        
   ,ECL_MODEL_ID        
   ,EAD_MODEL_ID        
   ,CCF_FLAG        
   ,CCF_RULES_ID        
   ,LGD_MODEL_ID        
   ,PD_MODEL_ID        
   ,PD_ME_MODEL_ID        
   ,LIFETIME        
   ,DEFAULT_RULE_ID        
   ,DPD_FINAL        
   ,BI_COLLECTABILITY        
   ,DPD_FINAL_CIF        
   ,BI_COLLECT_CIF        
   ,RESTRUCTURE_COLLECT_FLAG        
   ,PRODUCT_TYPE_1        
   ,CCF        
   ,CCF_EFF_DATE        
   ,RESTRUCTURE_COLLECT_FLAG_CIF        
   ,IMPAIRED_FLAG        
   ,INITIAL_RATING_CODE        
   ,RATING_CODE        
   ,RATING_DOWNGRADE        
   ,PD_INITIAL_RATE        
   ,WATCHLIST_FLAG        
   ,PD_CURRENT_RATE        
   ,PD_CHANGE        
   ,COLL_AMOUNT        
   ,EXT_RATING_AGENCY        
   ,EXT_RATING_CODE        
   ,EXT_INIT_RATING_CODE        
   ,EXT_RATING_DOWNGRADE
   ,SEGMENT_FLAG        
   )        
  EXEC (@V_STRSQL)        
        
  --PRINT @V_STRSQL                                                       
  DELETE #TMP_QRY        
  WHERE RN = @QRY_RN        
 END        
        
 /* ENCHANGMENT JENIUS 2021-03-31 - UPDATE LIFETIME PERIOD */        
 UPDATE A        
 SET A.LIFETIME = CASE         
   WHEN B.VALUE2 <= A.LIFETIME        
    THEN B.VALUE2        
   ELSE A.LIFETIME        
   END        
 FROM TMP_IFRS_ECL_IMA A        
 INNER JOIN TBLM_COMMONCODEDETAIL B ON A.PRODUCT_CODE = B.VALUE1        
 WHERE B.COMMONCODE = 'RVW_PERIOD'        
        
 UPDATE A        
 SET A.CCF = B.CCF        
  ,A.EAD_BALANCE = CASE         
   WHEN A.EAD_BALANCE < 0        
    THEN 0        
   ELSE A.EAD_BALANCE        
   END        
 FROM TMP_IFRS_ECL_IMA A        
 LEFT JOIN #TMP_IFRS_ECL_MODEL B ON A.CCF_RULES_ID = B.CCF_RULES_ID        
  AND A.CCF_EFF_DATE = B.CCF_EFF_DATE        
        
 ---------------------------------- INSERT HISTORY ECL CONFIG -------------------------                                      
 DELETE IFRS_ECL_MODEL_CONFIG_HIST        
 WHERE DOWNLOAD_DATE = @V_CURRDATE        
        
 INSERT INTO IFRS_ECL_MODEL_CONFIG_HIST (        
  DOWNLOAD_DATE        
  ,ECL_MODEL_ID         
  ,ECL_MODEL_NAME        
  ,SEGMENTATION_ID        
  ,SEGMENTATION_NAME        
  ,EAD_MODEL_ID        
  ,SUB_SEGMENT_EAD        
  ,PD_MODEL_ID        
  ,PD_ME_MODEL_ID        
  ,PD_EFF_DATE        
  ,SUB_SEGMENT_PD        
  ,BUCKET_GROUP        
  ,LGD_MODEL_ID        
  ,LGD_ME_MODEL_ID        
  ,SUB_SEGMENT_LGD        
  ,LGD_EFF_DATE        
  ,CCF_RULES_ID        
  ,CCF_FLAG        
  ,CCF_EFF_DATE_OPTION        
  ,CCF_EFF_DATE        
  ,CCF        
  ,AVERAGE_METHOD        
  ,SICR_RULE_ID        
  ,DEFAULT_RULE_ID        
  ,EAD_BALANCE        
  ,LT_RULE_ID        
  ,EXPECTED_LIFE        
  ,SEGMENT        
  ,SUB_SEGMENT        
  ,GROUP_SEGMENT        
  )        
 SELECT @V_CURRDATE AS DOWNLOAD_DATE        
  ,ECL_MODEL_ID        
  ,ECL_MODEL_NAME        
  ,SEGMENTATION_ID        
  ,SEGMENTATION_NAME        
  ,EAD_MODEL_ID        
  ,SUB_SEGMENT_EAD        
  ,PD_MODEL_ID        
  ,PD_ME_MODEL_ID        
  ,PD_EFF_DATE        
  ,SUB_SEGMENT_PD        
  ,BUCKET_GROUP        
  ,LGD_MODEL_ID        
  ,LGD_ME_MODEL_ID        
  ,SUB_SEGMENT_LGD        
  ,LGD_EFF_DATE        
  ,CCF_RULES_ID        
  ,CCF_FLAG        
  ,CCF_EFF_DATE_OPTION        
  ,CCF_EFF_DATE        
  ,CCF        
  ,AVERAGE_METHOD        
  ,SICR_RULE_ID        
  ,DEFAULT_RULE_ID        
  ,EAD_BALANCE        
  ,LT_RULE_ID        
  ,EXPECTED_LIFE        
  ,SEGMENT        
  ,SUB_SEGMENT       
  ,GROUP_SEGMENT        
 FROM #TMP_IFRS_ECL_MODEL        
END
GO
