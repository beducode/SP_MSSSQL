USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_EAD_CCF_DETAIL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_EAD_CCF_DETAIL]  
@DOWNLOAD_DATE DATE = NULL,  
@RULE_ID BIGINT = 0  
AS   
 DECLARE @V_CURRDATE DATE;  
BEGIN   
 SET NOCOUNT ON;   
       
 IF (@DOWNLOAD_DATE IS NULL)  
 BEGIN  
  SELECT @V_CURRDATE = EOMONTH(CURRDATE) FROM IFRS_PRC_DATE;  
 END  
 ELSE  
 BEGIN  
  SELECT @V_CURRDATE = EOMONTH(@DOWNLOAD_DATE);  
 END         
  
 SELECT DISTINCT    
  A.PKID,    
  A.CCF_RULE_NAME,    
  A.SEGMENTATION_ID,    
  A.CALC_METHOD,    
  A.AVERAGE_METHOD,    
  A.DEFAULT_RULE_ID,    
  A.CUT_OFF_DATE,    
  A.CCF_OVERRIDE,    
  A.LAG_1MONTH_FLAG,  
  OBSERV_PERIOD_MOVING,  
  OS_DEF_ZERO_EXCLUDE,  
  HEADROOM_ZERO_EXCLUDE   
 INTO #TMP_CCF_RULES_CONFIG   
 FROM IFRS_CCF_RULES_CONFIG A   
 WHERE A.IS_DELETE = 0     
 AND A.ACTIVE_FLAG = 1       
 AND CALC_METHOD <> 'EXT'  
 AND A.PKID = @RULE_ID;   
    
 ----------------------------------------------------------------  
 ------------------------ ACCOUNT Level -------------------------       
 ----------------------------------------------------------------  
  
 IF EXISTS (SELECT CALC_METHOD FROM #TMP_CCF_RULES_CONFIG WHERE CALC_METHOD = 'ACCOUNT')  
 BEGIN   
  DELETE A  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID   
  WHERE DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND CCF_RULE_ID = @RULE_ID;  
  
  INSERT INTO IFRS_EAD_CCF_DETAIL  
  (   
   CCF_RULE_ID,    
   DOWNLOAD_DATE,    
   CCF_UNIQUE_ID,    
   CUSTOMER_NUMBER,    
   CUSTOMER_NAME,    
   FACILITY_NUMBER,    
   EQV_AT_DEFAULT,    
   EQV_PLAFOND_AT_DEFAULT,    
   EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   EQV_OS_12M_BEFORE_DEFAULT,  
   CREATEDBY,     
   CREATEDDATE     
  )   
  SELECT    
   A.CCF_RULE_ID,    
   C.DEFAULT_DATE AS DOWNLOAD_DATE,    
   A.CCF_UNIQUE_ID,    
   A.CCF_UNIQUE_ID,    
   CUSTOMER_NAME,    
   A.FACILITY_NUMBER,    
   ISNULL(C.EQV_AT_DEFAULT, 0) * D.RATE_AMOUNT AS EQV_AT_DEFAULT,    
   ISNULL(C.EQV_PLAFOND_AT_DEFAULT, 0) * E.RATE_AMOUNT AS EQV_PLAFOND_AT_DEFAULT,    
   ISNULL(C.EQV_PLAFOND_12M_BEFORE_DEFAULT, 0) * E.RATE_AMOUNT AS EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   ISNULL(C.EQV_OS_12M_BEFORE_DEFAULT, 0) * D.RATE_AMOUNT AS EQV_OS_12M_BEFORE_DEFAULT,  
   'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY,     
   GETDATE()  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN #TMP_CCF_RULES_CONFIG B ON A.CCF_RULE_ID = B.PKID   
  JOIN VW_IFRS_FIRST_DEFAULT C ON A.CCF_UNIQUE_ID = CASE B.CALC_METHOD WHEN 'CUSTOMER' THEN C.CUSTOMER_NUMBER WHEN 'ACCOUNT' THEN C.MASTERID WHEN 'FACILITY' THEN C.FACILITY_NUMBER END     
  AND B.DEFAULT_RULE_ID = C.RULE_ID AND A.DOWNLOAD_DATE = C.DEFAULT_DATE  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = D.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON A.DOWNLOAD_DATE = E.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = E.CURRENCY  
  WHERE B.CALC_METHOD = 'ACCOUNT'  
  AND A.RULE_TYPE = 'CCF_SEGMENT'   
  AND C.DEFAULT_DATE >= B.CUT_OFF_DATE   
  AND C.DEFAULT_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 1  
  AND A.CCF_RULE_ID = @RULE_ID  
  UNION ALL  
  SELECT    
   A.CCF_RULE_ID,    
   C.DEFAULT_DATE AS DOWNLOAD_DATE,    
   A.CCF_UNIQUE_ID,    
   A.CCF_UNIQUE_ID,    
   CUSTOMER_NAME,    
   A.FACILITY_NUMBER,    
   ISNULL(C.EQV_AT_DEFAULT, 0) * D.RATE_AMOUNT AS EQV_AT_DEFAULT,    
   ISNULL(C.EQV_PLAFOND_AT_DEFAULT, 0) * E.RATE_AMOUNT AS EQV_PLAFOND_AT_DEFAULT,    
   ISNULL(C.EQV_PLAFOND_12M_BEFORE_DEFAULT, 0) * E.RATE_AMOUNT AS EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   ISNULL(C.EQV_OS_12M_BEFORE_DEFAULT, 0) * D.RATE_AMOUNT AS EQV_OS_12M_BEFORE_DEFAULT,  
   'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY,     
   GETDATE()  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN #TMP_CCF_RULES_CONFIG B ON A.CCF_RULE_ID = B.PKID   
  JOIN VW_IFRS_FIRST_DEFAULT_NOLAG C ON A.CCF_UNIQUE_ID = CASE B.CALC_METHOD WHEN 'CUSTOMER' THEN C.CUSTOMER_NUMBER WHEN 'ACCOUNT' THEN C.MASTERID WHEN 'FACILITY' THEN C.FACILITY_NUMBER END     
  AND B.DEFAULT_RULE_ID = C.RULE_ID AND A.DOWNLOAD_DATE = C.DEFAULT_DATE  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = D.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON A.DOWNLOAD_DATE = E.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = E.CURRENCY  
  WHERE B.CALC_METHOD = 'ACCOUNT'  
  AND A.RULE_TYPE = 'CCF_SEGMENT'   
  AND C.DEFAULT_DATE >= B.CUT_OFF_DATE   
  AND C.DEFAULT_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 0  
  AND A.CCF_RULE_ID = @RULE_ID  
       
  -- Getting 12M Data Account Lv      
  DROP TABLE IF EXISTS #MIN12DATEACC      
  SELECT       
   A.DOWNLOAD_DATE,      
   MIN(B.DOWNLOAD_DATE) AS MIN_12M_DATE,  
   B.CCF_RULE_ID,  
   B.DEFAULT_RULE_ID,    
   B.CCF_UNIQUE_ID      
  INTO #MIN12DATEACC   
  FROM IFRS_EAD_CCF_DETAIL A   
  JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON A.CCF_UNIQUE_ID = B.CCF_UNIQUE_ID AND A.CCF_RULE_ID = B.CCF_RULE_ID  
  JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID  
  WHERE B.DOWNLOAD_DATE BETWEEN EOMONTH(DATEADD(MONTH, -12, A.DOWNLOAD_DATE)) AND EOMONTH(DATEADD(MONTH, -1, A.DOWNLOAD_DATE))      
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND B.OUTSTANDING > 0  
  AND A.CCF_RULE_ID = @RULE_ID      
  GROUP BY       
  A.DOWNLOAD_DATE,      
  B.CCF_RULE_ID,  
  B.DEFAULT_RULE_ID,  
  B.CCF_UNIQUE_ID      
    
  ;WITH CTE   
  (  
   CCF_RULE_ID,  
   RULE_ID,  
   DEFAULT_DATE,   
   CCF_UNIQUE_ID,   
   PLAFOND_12M_BEFORE_DEFAULT,  
   EQV_PLAFOND_12M_BEFORE_DEFAULT,   
   OS_12M_BEFORE_DEFAULT,  
   EQV_OS_12M_BEFORE_DEFAULT,  
   LAG_1MONTH_FLAG,  
   RN  
  )  
  AS    
  (      
   SELECT      
    B.CCF_RULE_ID,      
    A.RULE_ID,  
    A.DOWNLOAD_DATE,   
    B.CCF_UNIQUE_ID,   
    ISNULL(B.PLAFOND, 0) AS PLAFOND_12M_BEFORE_DEFAULT,   
    ISNULL(B.PLAFOND, 0) * ISNULL(F.RATE_AMOUNT, 0) EQV_PLAFOND_12M_BEFORE_DEFAULT,   
    ISNULL(B.OUTSTANDING, 0) AS OS_12M_BEFORE_DEFAULT,   
    ISNULL(B.OUTSTANDING, 0) * ISNULL(E.RATE_AMOUNT, 0) EQV_OS_12M_BEFORE_DEFAULT,  
    C.LAG_1MONTH_FLAG,  
    ROW_NUMBER() OVER (PARTITION BY A.RULE_ID, B.CCF_UNIQUE_ID ORDER BY B.DOWNLOAD_DATE) RN       
   FROM IFRS_DEFAULT A (NOLOCK)    
   JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON CASE B.CALC_METHOD WHEN 'CUSTOMER' THEN A.CUSTOMER_NUMBER WHEN 'ACCOUNT' THEN A.MASTERID WHEN 'FACILITY' THEN A.FACILITY_NUMBER END = B.CCF_UNIQUE_ID       
   JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON A.RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID      
   JOIN #MIN12DATEACC D ON A.ACCOUNT_NUMBER = D.CCF_UNIQUE_ID AND B.DEFAULT_RULE_ID = D.DEFAULT_RULE_ID  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON EOMONTH(A.DOWNLOAD_DATE) = E.DOWNLOAD_DATE AND ISNULL(B.CURRENCY, 'IDR') = E.CURRENCY  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE F ON EOMONTH(A.DOWNLOAD_DATE) = F.DOWNLOAD_DATE AND ISNULL(B.LIMIT_CURRENCY, ISNULL(B.CURRENCY, 'IDR')) = F.CURRENCY  
   WHERE B.DOWNLOAD_DATE = D.MIN_12M_DATE  
   AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
   AND C.LAG_1MONTH_FLAG = 1  
   AND B.CCF_RULE_ID = @RULE_ID  
  )  
  UPDATE A   
  SET    
   A.EQV_PLAFOND_12M_BEFORE_DEFAULT = B.EQV_PLAFOND_12M_BEFORE_DEFAULT,         
   A.EQV_OS_12M_BEFORE_DEFAULT = B.EQV_OS_12M_BEFORE_DEFAULT  
  FROM IFRS_EAD_CCF_DETAIL A  
  INNER JOIN CTE B ON A.CCF_UNIQUE_ID = B.CCF_UNIQUE_ID  
  AND A.CCF_RULE_ID = B.CCF_RULE_ID   
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE   
  WHERE RN = 1   
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
      
  ;WITH CTE   
  (  
   CCF_RULE_ID,  
   RULE_ID,  
   DEFAULT_DATE,   
   CCF_UNIQUE_ID,   
   PLAFOND_12M_BEFORE_DEFAULT,  
   EQV_PLAFOND_12M_BEFORE_DEFAULT,   
   OS_12M_BEFORE_DEFAULT,  
   EQV_OS_12M_BEFORE_DEFAULT,  
   LAG_1MONTH_FLAG,  
   RN  
  )  
  AS    
  (      
   SELECT      
    B.CCF_RULE_ID,      
    A.RULE_ID,  
    A.DOWNLOAD_DATE,   
    B.CCF_UNIQUE_ID,   
    ISNULL(B.PLAFOND, 0) AS PLAFOND_12M_BEFORE_DEFAULT,   
    ISNULL(B.PLAFOND, 0) * ISNULL(F.RATE_AMOUNT, 0) EQV_PLAFOND_12M_BEFORE_DEFAULT,   
    ISNULL(B.OUTSTANDING, 0) AS OS_12M_BEFORE_DEFAULT,   
    ISNULL(B.OUTSTANDING, 0) * ISNULL(E.RATE_AMOUNT, 0) EQV_OS_12M_BEFORE_DEFAULT,  
    B.LAG_1MONTH_FLAG,  
    ROW_NUMBER() OVER (PARTITION BY A.RULE_ID, B.CCF_UNIQUE_ID ORDER BY B.DOWNLOAD_DATE) RN       
   FROM IFRS_DEFAULT_NOLAG A (NOLOCK)    
   JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON CASE B.CALC_METHOD WHEN 'CUSTOMER' THEN A.CUSTOMER_NUMBER WHEN 'ACCOUNT' THEN A.MASTERID WHEN 'FACILITY' THEN A.FACILITY_NUMBER END = B.CCF_UNIQUE_ID       
   JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON A.RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID      
   JOIN #MIN12DATEACC D ON A.ACCOUNT_NUMBER = D.CCF_UNIQUE_ID AND B.DEFAULT_RULE_ID = D.DEFAULT_RULE_ID  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON EOMONTH(A.DOWNLOAD_DATE) = E.DOWNLOAD_DATE AND ISNULL(B.CURRENCY, 'IDR') = E.CURRENCY  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE F ON EOMONTH(A.DOWNLOAD_DATE) = F.DOWNLOAD_DATE AND ISNULL(B.LIMIT_CURRENCY, ISNULL(B.CURRENCY, 'IDR')) = F.CURRENCY  
   WHERE B.DOWNLOAD_DATE = D.MIN_12M_DATE  
   AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
   AND C.LAG_1MONTH_FLAG = 0  
   AND B.CCF_RULE_ID = @RULE_ID  
  )  
  UPDATE A   
  SET    
   A.EQV_PLAFOND_12M_BEFORE_DEFAULT = B.EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   A.EQV_OS_12M_BEFORE_DEFAULT = B.EQV_OS_12M_BEFORE_DEFAULT  
  FROM IFRS_EAD_CCF_DETAIL A       
  INNER JOIN CTE B ON A.CCF_UNIQUE_ID = B.CCF_UNIQUE_ID  
  AND A.CCF_RULE_ID = B.CCF_RULE_ID   
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE   
  WHERE RN = 1   
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
     
  DELETE A  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B ON A.CCF_RULE_ID = B.PKID  
  WHERE DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END    
  AND (EQV_OS_12M_BEFORE_DEFAULT IS NULL AND EQV_PLAFOND_12M_BEFORE_DEFAULT IS NULL)  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET EXCLUDE = 1   
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B   
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_OS_12M_BEFORE_DEFAULT = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.OS_DEF_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_AT_DEFAULT <= 0  
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = 1  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_OS_12M_BEFORE_DEFAULT >= EQV_PLAFOND_12M_BEFORE_DEFAULT   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END    
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET   
  DRAWDOWN = CAST((EQV_AT_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) AS FLOAT) / EQV_PLAFOND_12M_BEFORE_DEFAULT,   
  HEADROOM = (EQV_PLAFOND_12M_BEFORE_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) / EQV_PLAFOND_12M_BEFORE_DEFAULT  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID   
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END       
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.HEADROOM_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END   
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE ISNULL(HEADROOM, 0) <= 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET CCF = CASE WHEN HEADROOM = 0 THEN NULL ELSE CASE WHEN DRAWDOWN / HEADROOM > 1 THEN 1 ELSE CASE WHEN DRAWDOWN / HEADROOM < 0 THEN 0 ELSE DRAWDOWN / HEADROOM END END END  
  FROM IFRS_EAD_CCF_DETAIL A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
 END  
    
 ----------------------------------------------------------------  
 ------------------------ CIF Level -----------------------------  
 ----------------------------------------------------------------  
 ELSE IF EXISTS (SELECT CALC_METHOD FROM #TMP_CCF_RULES_CONFIG WHERE CALC_METHOD = 'CUSTOMER')  
 BEGIN  
  DELETE A  
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  INSERT INTO IFRS_EAD_CCF_DETAIL_CIF    
  (   
   CCF_RULE_ID,    
   DOWNLOAD_DATE,   
   CUSTOMER_NUMBER,    
   CUSTOMER_NAME,    
   EQV_AT_DEFAULT,    
   EQV_PLAFOND_AT_DEFAULT,      
   CREATEDBY      
  )   
  SELECT   
   A.CCF_RULE_ID,  
   A.DOWNLOAD_DATE,  
   A.CCF_UNIQUE_ID,  
   CUSTOMER_NAME,  
   OUTSTANDING * C.RATE_AMOUNT AS OUTSTANDING,  
   PLAFOND * D.RATE_AMOUNT AS PLAFOND,  
   'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN  
  (       
   SELECT   
    PKID AS CCF_RULE_ID,   
    RULE_ID,   
    MIN(DEFAULT_DATE) DEFAULT_DATE,  
    CUSTOMER_NUMBER   
   FROM VW_IFRS_FIRST_DEFAULT X  
   JOIN #TMP_CCF_RULES_CONFIG Y ON X.RULE_ID = Y.DEFAULT_RULE_ID  
   WHERE X.DEFAULT_DATE >= Y.CUT_OFF_DATE  
   AND PKID = @RULE_ID  
   GROUP BY PKID, RULE_ID, CUSTOMER_NUMBER  
  ) B ON A.DEFAULT_RULE_ID = B.RULE_ID     
  AND A.CCF_RULE_ID = B.CCF_RULE_ID     
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE     
  AND A.CCF_UNIQUE_ID = B.CUSTOMER_NUMBER  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C ON A.DOWNLOAD_DATE = C.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = C.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = D.CURRENCY  
  WHERE A.DOWNLOAD_DATE = CASE A.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 1  
  AND A.CCF_RULE_ID = @RULE_ID  
  UNION ALL  
  SELECT   
   A.CCF_RULE_ID,  
   A.DOWNLOAD_DATE,  
   A.CCF_UNIQUE_ID,  
   CUSTOMER_NAME,  
   OUTSTANDING * C.RATE_AMOUNT AS OUTSTANDING,  
   PLAFOND * D.RATE_AMOUNT AS PLAFOND,  
   'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN  
  (       
   SELECT   
    PKID AS CCF_RULE_ID,   
    RULE_ID,   
    MIN(DEFAULT_DATE) DEFAULT_DATE,   
    CUSTOMER_NUMBER   
   FROM VW_IFRS_FIRST_DEFAULT_NOLAG X  
   JOIN #TMP_CCF_RULES_CONFIG Y ON X.RULE_ID = Y.DEFAULT_RULE_ID  
   WHERE X.DEFAULT_DATE >= Y.CUT_OFF_DATE  
   AND PKID = @RULE_ID  
   GROUP BY PKID, RULE_ID, CUSTOMER_NUMBER  
  ) B ON A.DEFAULT_RULE_ID = B.RULE_ID     
  AND A.CCF_RULE_ID = B.CCF_RULE_ID     
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE     
  AND A.CCF_UNIQUE_ID = B.CUSTOMER_NUMBER  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C ON A.DOWNLOAD_DATE = C.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = C.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = D.CURRENCY  
  WHERE A.DOWNLOAD_DATE = CASE A.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 0  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  -- GETTING DATA 12M BEFORE        
  DROP TABLE IF EXISTS #MIN12DATECIF      
  SELECT       
   A.DOWNLOAD_DATE,      
   MIN(B.DOWNLOAD_DATE) AS MIN_12M_DATE,  
   B.CCF_RULE_ID,  
   B.DEFAULT_RULE_ID,    
   B.CCF_UNIQUE_ID      
  INTO #MIN12DATECIF   
  FROM IFRS_EAD_CCF_DETAIL_CIF A   
  JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON A.CUSTOMER_NUMBER = B.CCF_UNIQUE_ID AND A.CCF_RULE_ID = B.CCF_RULE_ID  
  JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID  
  WHERE B.DOWNLOAD_DATE BETWEEN EOMONTH(DATEADD(MONTH, -12, A.DOWNLOAD_DATE)) AND EOMONTH(DATEADD(MONTH, -1, A.DOWNLOAD_DATE))     
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND B.OUTSTANDING > 0  
  AND A.CCF_RULE_ID = @RULE_ID      
  GROUP BY       
  A.DOWNLOAD_DATE,      
  B.CCF_RULE_ID,  
  B.DEFAULT_RULE_ID,  
  B.CCF_UNIQUE_ID      
  
  DROP TABLE IF EXISTS #12MCIF      
  SELECT  
   CCF_RULE_ID,  
   DEFAULT_RULE_ID,  
   DOWNLOAD_DATE,  
   CCF_UNIQUE_ID,  
   SUM(EQV_PLAFOND_12M_BEFORE_DEFAULT) AS EQV_PLAFOND_12M_BEFORE_DEFAULT,  
   SUM(EQV_OS_12M_BEFORE_DEFAULT) AS EQV_OS_12M_BEFORE_DEFAULT  
  INTO #12MCIF  
  FROM  
  (  
   SELECT  
    B.CCF_RULE_ID,  
    B.DEFAULT_RULE_ID,      
    A.DOWNLOAD_DATE,       
    B.CCF_UNIQUE_ID,      
    B.FACILITY_NUMBER,  
    MAX(ISNULL(B.PLAFOND, 0) * ISNULL(F.RATE_AMOUNT, 0)) EQV_PLAFOND_12M_BEFORE_DEFAULT,  
    SUM(ISNULL(B.OUTSTANDING, 0) * ISNULL(E.RATE_AMOUNT, 0)) EQV_OS_12M_BEFORE_DEFAULT      
   FROM IFRS_EAD_CCF_DETAIL_CIF A   
   JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON A.CUSTOMER_NUMBER = B.CCF_UNIQUE_ID AND A.CCF_RULE_ID = B.CCF_RULE_ID  
   JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID      
   JOIN #MIN12DATECIF D ON A.CUSTOMER_NUMBER = D.CCF_UNIQUE_ID AND A.CCF_RULE_ID = D.CCF_RULE_ID AND B.DEFAULT_RULE_ID = D.DEFAULT_RULE_ID  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON EOMONTH(A.DOWNLOAD_DATE) = E.DOWNLOAD_DATE AND ISNULL(B.CURRENCY, 'IDR') = E.CURRENCY  
   LEFT JOIN IFRS_MASTER_EXCHANGE_RATE F ON EOMONTH(A.DOWNLOAD_DATE) = F.DOWNLOAD_DATE AND ISNULL(B.LIMIT_CURRENCY, ISNULL(B.CURRENCY, 'IDR')) = F.CURRENCY  
   WHERE B.DOWNLOAD_DATE = D.MIN_12M_DATE   
   AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
   AND A.CCF_RULE_ID = @RULE_ID  
   GROUP BY   
   B.CCF_RULE_ID,  
   B.DEFAULT_RULE_ID,  
   A.DOWNLOAD_DATE,  
   B.CCF_UNIQUE_ID,  
   B.FACILITY_NUMBER  
  ) X  
  GROUP BY   
  CCF_RULE_ID,  
  DEFAULT_RULE_ID,  
  DOWNLOAD_DATE,  
  CCF_UNIQUE_ID  
  
  UPDATE A   
  SET    
   A.EQV_PLAFOND_12M_BEFORE_DEFAULT = B.EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   A.EQV_OS_12M_BEFORE_DEFAULT = B.EQV_OS_12M_BEFORE_DEFAULT  
  FROM IFRS_EAD_CCF_DETAIL_CIF A       
  INNER JOIN #12MCIF B ON A.CUSTOMER_NUMBER = B.CCF_UNIQUE_ID  
  AND A.CCF_RULE_ID = B.CCF_RULE_ID   
  AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE  
  JOIN #TMP_CCF_RULES_CONFIG C ON A.CCF_RULE_ID = C.PKID   
  WHERE A.DOWNLOAD_DATE = CASE C.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID      
  
  DELETE A  
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID   
  WHERE DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END   
  AND (EQV_OS_12M_BEFORE_DEFAULT IS NULL AND EQV_PLAFOND_12M_BEFORE_DEFAULT IS NULL)  
  AND A.CCF_RULE_ID = @RULE_ID        
     
  UPDATE A   
  SET EXCLUDE = 1  
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID    
  WHERE EQV_OS_12M_BEFORE_DEFAULT = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.OS_DEF_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END  
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_AT_DEFAULT <= 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET EXCLUDE = 1   
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_OS_12M_BEFORE_DEFAULT >= EQV_PLAFOND_12M_BEFORE_DEFAULT   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET   
  DRAWDOWN = CAST((EQV_AT_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) AS FLOAT) / EQV_PLAFOND_12M_BEFORE_DEFAULT,   
  HEADROOM = (EQV_PLAFOND_12M_BEFORE_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) / EQV_PLAFOND_12M_BEFORE_DEFAULT   
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID         
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END       
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.HEADROOM_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END   
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE ISNULL(HEADROOM, 0) <= 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
    
  UPDATE A  
  SET CCF = CASE WHEN HEADROOM = 0 THEN NULL ELSE CASE WHEN DRAWDOWN / HEADROOM > 1 THEN 1 ELSE CASE WHEN DRAWDOWN / HEADROOM < 0 THEN 0 ELSE DRAWDOWN / HEADROOM END END END  
  FROM IFRS_EAD_CCF_DETAIL_CIF A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END   
  AND A.CCF_RULE_ID = @RULE_ID  
 END  
  
 ----------------------------------------------------------------  
 ------------------------ FACILITY Level -----------------------------  
 ----------------------------------------------------------------  
 ELSE IF EXISTS (SELECT CALC_METHOD FROM #TMP_CCF_RULES_CONFIG WHERE CALC_METHOD = 'FACILITY')  
 BEGIN  
  DELETE A  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE DOWNLOAD_DATE = @V_CURRDATE  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  INSERT INTO IFRS_EAD_CCF_DETAIL_FACILITY    
  (   
  CCF_RULE_ID,    
  DOWNLOAD_DATE,   
  FACILITY_NUMBER,    
  CUSTOMER_NAME,    
  EQV_AT_DEFAULT,    
  EQV_PLAFOND_AT_DEFAULT,      
  CREATEDBY      
  )   
  SELECT   
  A.CCF_RULE_ID,  
  A.DOWNLOAD_DATE,  
  A.CCF_UNIQUE_ID,  
  CUSTOMER_NAME,  
  OUTSTANDING * C.RATE_AMOUNT AS OUTSTANDING,  
  PLAFOND * D.RATE_AMOUNT AS PLAFOND,  
  'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN  
  (       
  SELECT   
   PKID AS CCF_RULE_ID,   
   RULE_ID,  
   MIN(DEFAULT_DATE) DEFAULT_DATE,   
   FACILITY_NUMBER  
  FROM VW_IFRS_FIRST_DEFAULT X  
  JOIN #TMP_CCF_RULES_CONFIG Y ON X.RULE_ID = Y.DEFAULT_RULE_ID  
  WHERE X.DEFAULT_DATE >= Y.CUT_OFF_DATE  
  AND PKID = @RULE_ID  
  GROUP BY PKID, RULE_ID, FACILITY_NUMBER  
  ) B ON A.DEFAULT_RULE_ID = B.RULE_ID     
  AND A.CCF_RULE_ID = B.CCF_RULE_ID     
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE     
  AND A.CCF_UNIQUE_ID = B.FACILITY_NUMBER  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C ON EOMONTH(A.DOWNLOAD_DATE) = C.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = C.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON EOMONTH(A.DOWNLOAD_DATE) = D.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = D.CURRENCY  
  WHERE A.DOWNLOAD_DATE = CASE A.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 1  
  AND A.CCF_RULE_ID = @RULE_ID  
  UNION ALL  
  SELECT   
  A.CCF_RULE_ID,  
  A.DOWNLOAD_DATE,  
  A.CCF_UNIQUE_ID,  
  CUSTOMER_NAME,  
  OUTSTANDING * C.RATE_AMOUNT AS OUTSTANDING,  
  PLAFOND * D.RATE_AMOUNT AS PLAFOND,  
  'SP_IFRS_IMP_EAD_CCF_DETAIL' AS CREATEDBY  
  FROM IFRS_CCF_SCENARIO_DATA_SUMM A  
  JOIN  
  (       
  SELECT   
   PKID AS CCF_RULE_ID,   
   RULE_ID,   
   MIN(DOWNLOAD_DATE) DEFAULT_DATE,   
   FACILITY_NUMBER   
  FROM IFRS_DEFAULT_NOLAG X  
  JOIN #TMP_CCF_RULES_CONFIG Y ON X.RULE_ID = Y.DEFAULT_RULE_ID  
  WHERE X.DOWNLOAD_DATE >= Y.CUT_OFF_DATE  
  AND PKID = @RULE_ID  
  GROUP BY PKID, RULE_ID, FACILITY_NUMBER  
  ) B ON A.DEFAULT_RULE_ID = B.RULE_ID     
  AND A.CCF_RULE_ID = B.CCF_RULE_ID     
  AND A.DOWNLOAD_DATE = B.DEFAULT_DATE     
  AND A.CCF_UNIQUE_ID = B.FACILITY_NUMBER  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C ON EOMONTH(A.DOWNLOAD_DATE) = C.DOWNLOAD_DATE AND ISNULL(A.CURRENCY, 'IDR') = C.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D ON EOMONTH(A.DOWNLOAD_DATE) = D.DOWNLOAD_DATE AND ISNULL(A.LIMIT_CURRENCY, ISNULL(A.CURRENCY, 'IDR')) = D.CURRENCY  
  WHERE A.DOWNLOAD_DATE = CASE A.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.LAG_1MONTH_FLAG = 0  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  -- GETTING DATA 12M BEFORE        
  DROP TABLE IF EXISTS #MIN12DATEFAC      
  SELECT       
  A.DOWNLOAD_DATE,      
  MIN(B.DOWNLOAD_DATE) AS MIN_12M_DATE,  
  B.CCF_RULE_ID,  
  B.DEFAULT_RULE_ID,    
  B.CCF_UNIQUE_ID      
  INTO #MIN12DATEFAC   
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A   
  JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON A.FACILITY_NUMBER = B.CCF_UNIQUE_ID AND A.CCF_RULE_ID = B.CCF_RULE_ID  
  JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID  
  WHERE B.DOWNLOAD_DATE BETWEEN EOMONTH(DATEADD(MONTH, -12, A.DOWNLOAD_DATE)) AND EOMONTH(DATEADD(MONTH, -1, A.DOWNLOAD_DATE))     
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND B.OUTSTANDING > 0      
  AND A.CCF_RULE_ID = @RULE_ID  
  GROUP BY       
  A.DOWNLOAD_DATE,      
  B.CCF_RULE_ID,  
  B.DEFAULT_RULE_ID,  
  B.CCF_UNIQUE_ID      
  
  DROP TABLE IF EXISTS #12MFAC      
  SELECT  
  CCF_RULE_ID,  
  DEFAULT_RULE_ID,  
  DOWNLOAD_DATE,  
  CCF_UNIQUE_ID,  
  SUM(EQV_PLAFOND_12M_BEFORE_DEFAULT) AS EQV_PLAFOND_12M_BEFORE_DEFAULT,  
  SUM(EQV_OS_12M_BEFORE_DEFAULT) AS EQV_OS_12M_BEFORE_DEFAULT  
  INTO #12MFAC  
  FROM  
  (  
  SELECT  
   B.CCF_RULE_ID,  
   B.DEFAULT_RULE_ID,      
   A.DOWNLOAD_DATE,       
   B.CCF_UNIQUE_ID,      
   B.FACILITY_NUMBER,  
   MAX(ISNULL(B.PLAFOND, 0) * ISNULL(F.RATE_AMOUNT, 0)) EQV_PLAFOND_12M_BEFORE_DEFAULT,  
   SUM(ISNULL(B.OUTSTANDING, 0) * ISNULL(E.RATE_AMOUNT, 0)) EQV_OS_12M_BEFORE_DEFAULT      
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A   
  JOIN IFRS_CCF_SCENARIO_DATA_SUMM B (NOLOCK) ON A.FACILITY_NUMBER = B.CCF_UNIQUE_ID AND A.CCF_RULE_ID = B.CCF_RULE_ID  
  JOIN #TMP_CCF_RULES_CONFIG C (NOLOCK) ON B.DEFAULT_RULE_ID = C.DEFAULT_RULE_ID AND B.CCF_RULE_ID = C.PKID      
  JOIN #MIN12DATEFAC D ON A.FACILITY_NUMBER = D.CCF_UNIQUE_ID AND A.CCF_RULE_ID = D.CCF_RULE_ID AND B.DEFAULT_RULE_ID = D.DEFAULT_RULE_ID      
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E ON EOMONTH(A.DOWNLOAD_DATE) = E.DOWNLOAD_DATE AND ISNULL(B.CURRENCY, 'IDR') = E.CURRENCY  
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE F ON EOMONTH(A.DOWNLOAD_DATE) = F.DOWNLOAD_DATE AND ISNULL(B.LIMIT_CURRENCY, ISNULL(B.CURRENCY, 'IDR')) = F.CURRENCY  
  WHERE B.DOWNLOAD_DATE = D.MIN_12M_DATE   
  AND A.DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  GROUP BY   
  B.CCF_RULE_ID,  
  B.DEFAULT_RULE_ID,  
  A.DOWNLOAD_DATE,  
  B.CCF_UNIQUE_ID,  
  B.FACILITY_NUMBER  
  ) X  
  GROUP BY   
  CCF_RULE_ID,  
  DEFAULT_RULE_ID,  
  DOWNLOAD_DATE,  
  CCF_UNIQUE_ID  
  
  UPDATE A   
  SET    
   A.EQV_PLAFOND_12M_BEFORE_DEFAULT = B.EQV_PLAFOND_12M_BEFORE_DEFAULT,    
   A.EQV_OS_12M_BEFORE_DEFAULT = B.EQV_OS_12M_BEFORE_DEFAULT,  
   A.EXCLUDE = 0  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A       
  INNER JOIN #12MFAC B ON A.FACILITY_NUMBER = B.CCF_UNIQUE_ID  
   AND A.CCF_RULE_ID = B.CCF_RULE_ID   
   AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE   
  JOIN #TMP_CCF_RULES_CONFIG C  
  ON A.CCF_RULE_ID = C.PKID  
  WHERE A.DOWNLOAD_DATE = CASE C.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END      
  AND A.CCF_RULE_ID = @RULE_ID  
  
  DELETE A   
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END    
  AND (EQV_OS_12M_BEFORE_DEFAULT IS NULL AND EQV_PLAFOND_12M_BEFORE_DEFAULT IS NULL)        
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = 1  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_OS_12M_BEFORE_DEFAULT = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.OS_DEF_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EQV_AT_DEFAULT <= 0  
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
      
  UPDATE A  
  SET   
  DRAWDOWN = CAST((EQV_AT_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) AS FLOAT) / EQV_PLAFOND_12M_BEFORE_DEFAULT,   
  HEADROOM = (EQV_PLAFOND_12M_BEFORE_DEFAULT - EQV_OS_12M_BEFORE_DEFAULT) / EQV_PLAFOND_12M_BEFORE_DEFAULT  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID   
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A   
  SET EXCLUDE = CASE WHEN B.HEADROOM_ZERO_EXCLUDE = 0 THEN 0 ELSE 1 END   
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE ISNULL(HEADROOM, 0) <= 0  
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END  
  AND A.CCF_RULE_ID = @RULE_ID  
  
  UPDATE A  
  SET CCF = CASE WHEN HEADROOM = 0 THEN 1 ELSE CASE WHEN DRAWDOWN / HEADROOM > 1 THEN 1 ELSE CASE WHEN DRAWDOWN / HEADROOM < 0 THEN 0 ELSE DRAWDOWN / HEADROOM END END END  
  FROM IFRS_EAD_CCF_DETAIL_FACILITY A  
  JOIN #TMP_CCF_RULES_CONFIG B  
  ON A.CCF_RULE_ID = B.PKID  
  WHERE EXCLUDE = 0   
  AND DOWNLOAD_DATE = CASE B.LAG_1MONTH_FLAG WHEN 0 THEN @V_CURRDATE WHEN 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) END   
  AND A.CCF_RULE_ID = @RULE_ID  
  
 END  
END; 
GO
