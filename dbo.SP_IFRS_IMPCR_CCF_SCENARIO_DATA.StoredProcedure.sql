USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_CCF_SCENARIO_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_CCF_SCENARIO_DATA]  
@DOWNLOAD_DATE DATE = null,                                 
@RULE_ID BIGINT = 0,                                 
@PRC CHAR(1) = 'S' -- M = MANUAL, S = SYSTEM / CATCH UP           
AS        
 DECLARE        
 @V_TABLE_NAME VARCHAR(100),        
 @V_SQL VARCHAR(MAX),        
 @V_CURRDATE VARCHAR(10),        
 @V_DATADATE VARCHAR(10),         
 @V_STR_SQL VARCHAR(4000),        
 @V_STR_SQL_RULE VARCHAR(4000),        
 @V_CCF_RULE_ID VARCHAR(250),        
 @V_ID BIGINT= 0,        
 @V_MAX_ID BIGINT= 0,        
 @V_SEGMENTATION_ID VARCHAR(250),        
 @V_SEGMENT_TYPE VARCHAR(250),        
 @V_SEGMENT VARCHAR(50),        
 @V_SBSEGMENT VARCHAR(50),        
 @V_GRPSEGMENT VARCHAR(50),          
 @V_CUT_OFF_DATE VARCHAR(10),        
 @V_LAG CHAR(1),        
 @V_CALC_METHOD VARCHAR(20),        
 @V_DEFAULT_RULE_ID VARCHAR(10);        
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
         
 IF @PRC = 'M'                                 
 BEGIN                                 
  SET @v_TABLE_NAME = 'IFRS_MASTER_ACCOUNT';                                 
 END                                 
 ELSE                                 
 BEGIN                                 
  SET @v_TABLE_NAME = 'IFRS_MASTER_ACCOUNT_MONTHLY';                                 
 END;         
        
 DELETE IFRS_CCF_SCENARIO_DATA         
 WHERE RULE_TYPE = 'CCF_SEGMENT'         
 AND DOWNLOAD_DATE = CASE WHEN ISNULL(LAG_1MONTH_FLAG, 1) = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END  
 AND CCF_RULE_ID = @RULE_ID;        
         
 DELETE IFRS_CCF_SCENARIO_DATA_SUMM              
 WHERE RULE_TYPE = 'CCF_SEGMENT'         
 AND DOWNLOAD_DATE = CASE WHEN ISNULL(LAG_1MONTH_FLAG, 1) = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END  
 AND CCF_RULE_ID = @RULE_ID;  
         
 DROP TABLE IF EXISTS #TMP_CCF_RULES_CONFIG        
        
 SELECT        
  PKID,          
  CCF_RULE_NAME,          
  SEGMENTATION_ID,          
  LAG_1MONTH_FLAG,             
  CUT_OFF_DATE,        
  UPPER(CALC_METHOD) AS CALC_METHOD,        
  DEFAULT_RULE_ID,        
  OBSERV_PERIOD_MOVING,        
  OS_DEF_ZERO_EXCLUDE,        
  HEADROOM_ZERO_EXCLUDE        
 INTO #TMP_CCF_RULES_CONFIG        
 FROM IFRS_CCF_RULES_CONFIG         
 WHERE ACTIVE_FLAG = 1         
  AND IS_DELETE = 0        
  AND CALC_METHOD <> 'EXT'  
  AND PKID = @RULE_ID;        
           
 DROP TABLE IF EXISTS #TMP_IFRS_SCN_GENERATE_QUERY          
         
 SELECT ROW_NUMBER() OVER(ORDER BY SEGMENTATION_ID, DATA_DATE) AS ID, *         
 INTO #TMP_IFRS_SCN_GENERATE_QUERY         
 FROM         
 (         
  SELECT DISTINCT        
   RULE_ID AS SEGMENTATION_ID,        
   B.PKID AS CCF_RULE_ID,        
   SEGMENT_TYPE,        
   @V_TABLE_NAME AS TABLE_NAME,        
   CONDITION,              
   CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END AS DATA_DATE,          
   CCF_RULE_NAME AS SEGMENT,        
   SUB_SEGMENT,              
   GROUP_SEGMENT,        
   CUT_OFF_DATE,        
   LAG_1MONTH_FLAG,        
   B.CALC_METHOD,        
   DEFAULT_RULE_ID        
  FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY A         
  JOIN #TMP_CCF_RULES_CONFIG B ON A.RULE_ID = B.SEGMENTATION_ID           
  WHERE A.SEGMENT_TYPE = 'CCF_SEGMENT'  
  AND B.PKID = @RULE_ID   
 ) TMP;         
          
 SELECT @V_MAX_ID = MAX(ID)         
 FROM #TMP_IFRS_SCN_GENERATE_QUERY;         
         
 WHILE @V_ID < @V_MAX_ID         
 BEGIN         
  SELECT @V_ID = MIN(ID)         
  FROM #TMP_IFRS_SCN_GENERATE_QUERY         
  WHERE ID > @V_ID;         
        
  SELECT        
    @V_SEGMENTATION_ID = SEGMENTATION_ID,        
    @V_CCF_RULE_ID = CCF_RULE_ID,        
    @V_SEGMENT_TYPE = SEGMENT_TYPE,        
    @V_TABLE_NAME = TABLE_NAME,     
    @V_STR_SQL_RULE = CONDITION,           
    @V_DATADATE = DATA_DATE,        
    @V_SEGMENT = SEGMENT,        
    @V_SBSEGMENT = SUB_SEGMENT,        
    @V_GRPSEGMENT = GROUP_SEGMENT,          
    @V_CUT_OFF_DATE = CUT_OFF_DATE,        
    @V_CALC_METHOD = CALC_METHOD,        
    @V_LAG = LAG_1MONTH_FLAG,        
    @V_DEFAULT_RULE_ID = DEFAULT_RULE_ID        
  FROM #TMP_IFRS_SCN_GENERATE_QUERY         
  WHERE ID = @V_ID         
  AND SEGMENT_TYPE = 'CCF_SEGMENT'  
  AND CCF_RULE_ID = @RULE_ID;        
        
  SET @V_STR_SQL =            
  'INSERT INTO IFRS_CCF_SCENARIO_DATA        
  (        
    DOWNLOAD_DATE        
    ,CCF_RULE_ID     
    ,DEFAULT_RULE_ID        
    ,SEQUENCE        
    ,SEGMENT        
    ,SUB_SEGMENT        
    ,GROUP_SEGMENT        
    ,RULE_TYPE        
    ,MASTERID        
    ,CUSTOMER_NUMBER        
    ,CUSTOMER_NAME        
    ,FACILITY_NUMBER        
    ,PLAFOND        
    ,OUTSTANDING        
    ,EXCHANGE_RATE        
    ,BI_COLLECTABILITY        
    ,SOURCE_PROCESS        
    ,REVOLVING_FLAG        
    ,CCF_UNIQUE_ID        
    ,CALC_METHOD        
    ,LAG_1MONTH_FLAG        
 ,CURRENCY        
 ,LIMIT_CURRENCY        
  )        
  SELECT         
    A.DOWNLOAD_DATE,        
    ' + @V_CCF_RULE_ID + ' AS CCF_RULE_ID,         
    ' + @V_DEFAULT_RULE_ID + ' AS DEFAULT_RULE_ID,        
    ' + @V_SEGMENTATION_ID + ' AS SEQUENCE,         
    ''' + @V_SEGMENT + ''' AS SEGMENT,        
    ''' + @V_SBSEGMENT + ''' AS SUB_SEGMENT,        
    ''' + @V_GRPSEGMENT + ''' AS GROUP_SEGMENT,         
    ''' + @V_SEGMENT_TYPE + ''' AS RULE_TYPE,        
    A.MASTERID,        
    A.CUSTOMER_NUMBER,        
    A.CUSTOMER_NAME,        
    CASE WHEN A.FACILITY_NUMBER is NULL AND A.PRODUCT_TYPE_1 =''PRK'' THEN A.MASTERID ELSE A.FACILITY_NUMBER END as FACILITY_NUMBER,        
    A.PLAFOND,        
    A.OUTSTANDING,        
    ISNULL(A.EXCHANGE_RATE, B.RATE_AMOUNT) AS EXCHANGE_RATE,        
    A.BI_COLLECTABILITY,        
    ''SP_IFRS_IMP_CCF_RULE_DATA_CIF'' AS SOURCE_PROCESS,        
    A.REVOLVING_FLAG,        
    ' + CASE @V_CALC_METHOD WHEN 'CUSTOMER' THEN 'A.CUSTOMER_NUMBER' WHEN 'ACCOUNT' THEN 'A.MASTERID' WHEN 'FACILITY' THEN 'A.FACILITY_NUMBER' END + ' AS CCF_UNIQUE_ID,        
    ''' + @V_CALC_METHOD + ''' AS CALC_METHOD,        
    ''' + @V_LAG + ''' AS LAG_1MONTH_FLAG,        
 A.CURRENCY,        
 A.LIMIT_CURRENCY        
  FROM  ' + @v_TABLE_NAME + ' A (NOLOCK)        
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B        
  ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.CURRENCY = B.CURRENCY        
  WHERE  
  A.DOWNLOAD_DATE =  ''' + @V_DATADATE + '''  
  AND A.ACCOUNT_STATUS = ''A''  
  AND CASE WHEN A.FACILITY_NUMBER is NULL AND A.PRODUCT_TYPE_1 =''PRK'' THEN A.MASTERID ELSE A.FACILITY_NUMBER END is not null  
  ' + CASE WHEN @V_GRPSEGMENT LIKE '%JENIUS%' THEN + 'AND A.CUSTOMER_NUMBER NOT IN (SELECT DISTINCT CUSTOMER_NUMBER FROM IFRS_EXCLUDE_JENIUS) ' ELSE '' END + ' AND (' + RTRIM(ISNULL(@V_STR_SQL_RULE, '')) + ')' + '';  
              
  --print   @V_STR_SQL  
  EXECUTE (@V_STR_SQL);  
 END;  
        
 INSERT INTO IFRS_CCF_SCENARIO_DATA_SUMM        
 (        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    CUSTOMER_NAME,        
    FACILITY_NUMBER,        
    PLAFOND,        
    OUTSTANDING,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
 CURRENCY,        
 LIMIT_CURRENCY        
 )        
 SELECT        
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    MAX(CUSTOMER_NAME) AS CUSTOMER_NAME,        
    MAX(FACILITY_NUMBER) AS FACILITY_NUMBER,        
    SUM(PLAFOND) AS PLAFOND,   
    SUM(OUTSTANDING) AS OUTSTANDING,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
 CURRENCY,        
 LIMIT_CURRENCY        
 FROM        
 (         
    SELECT        
       DOWNLOAD_DATE,        
       CCF_UNIQUE_ID,        
       CCF_RULE_ID,        
       A.DEFAULT_RULE_ID,        
     DEFAULT_FLAG,        
       SEQUENCE,        
       SEGMENT,        
       SUB_SEGMENT,        
       GROUP_SEGMENT,        
       RULE_TYPE,        
       MAX(CUSTOMER_NAME) AS CUSTOMER_NAME,        
       FACILITY_NUMBER,        
       MAX(PLAFOND) AS PLAFOND,        
       SUM(OUTSTANDING) AS OUTSTANDING,        
       EXCHANGE_RATE,        
       SOURCE_PROCESS,        
       A.LAG_1MONTH_FLAG,        
       A.CALC_METHOD,        
     A.CURRENCY,        
     A.LIMIT_CURRENCY        
    FROM IFRS_CCF_SCENARIO_DATA A        
    JOIN IFRS_CCF_RULES_CONFIG B ON A.CCF_RULE_ID = B.PKID AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID  
    WHERE DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END  
    AND A.CCF_RULE_ID = @RULE_ID  
 GROUP BY        
       DOWNLOAD_DATE,        
       CCF_UNIQUE_ID,        
       CCF_RULE_ID,        
       A.DEFAULT_RULE_ID,        
       DEFAULT_FLAG,        
       SEQUENCE,        
       SEGMENT,        
       SUB_SEGMENT,        
       GROUP_SEGMENT,        
       RULE_TYPE,            
       FACILITY_NUMBER,         
       EXCHANGE_RATE,        
       SOURCE_PROCESS,        
       A.LAG_1MONTH_FLAG,        
       A.CALC_METHOD,        
    A.CURRENCY,        
    A.LIMIT_CURRENCY        
 ) X        
 GROUP BY         
    DOWNLOAD_DATE,        
    CCF_UNIQUE_ID,        
    CCF_RULE_ID,        
    DEFAULT_RULE_ID,        
    DEFAULT_FLAG,        
    SEQUENCE,        
    SEGMENT,        
    SUB_SEGMENT,        
    GROUP_SEGMENT,        
    RULE_TYPE,        
    EXCHANGE_RATE,        
    SOURCE_PROCESS,        
    LAG_1MONTH_FLAG,        
    CALC_METHOD,        
 CURRENCY,        
 LIMIT_CURRENCY        
        
 UPDATE A SET DEFAULT_FLAG = CASE WHEN CASE A.CALC_METHOD WHEN 'ACCOUNT' THEN B.MASTERID WHEN 'CUSTOMER' THEN B.CUSTOMER_NUMBER WHEN 'FACILITY' THEN B.FACILITY_NUMBER END IS NOT NULL THEN 1 ELSE 0 END        
 FROM IFRS_CCF_SCENARIO_DATA_SUMM A        
 LEFT JOIN IFRS_DEFAULT_NOLAG B          
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
 AND A.CCF_UNIQUE_ID = CASE A.CALC_METHOD WHEN 'ACCOUNT' THEN B.MASTERID WHEN 'CUSTOMER' THEN B.CUSTOMER_NUMBER WHEN 'FACILITY' THEN B.FACILITY_NUMBER END        
 AND A.DEFAULT_RULE_ID = B.RULE_ID         
 WHERE A.DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END        
 AND ISNULL(A.LAG_1MONTH_FLAG, 0) = 0  
 AND A.CCF_RULE_ID = @RULE_ID  
         
 UPDATE A SET DEFAULT_FLAG = CASE WHEN CASE A.CALC_METHOD WHEN 'ACCOUNT' THEN B.MASTERID WHEN 'CUSTOMER' THEN B.CUSTOMER_NUMBER WHEN 'FACILITY' THEN B.FACILITY_NUMBER END IS NOT NULL THEN 1 ELSE 0 END        
 FROM IFRS_CCF_SCENARIO_DATA_SUMM A        
 LEFT JOIN IFRS_DEFAULT B          
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
 AND A.CCF_UNIQUE_ID = CASE A.CALC_METHOD WHEN 'ACCOUNT' THEN B.MASTERID WHEN 'CUSTOMER' THEN B.CUSTOMER_NUMBER WHEN 'FACILITY' THEN B.FACILITY_NUMBER END        
 AND A.DEFAULT_RULE_ID = B.RULE_ID         
 WHERE A.DOWNLOAD_DATE = CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE)) ELSE @V_CURRDATE END        
 AND ISNULL(A.LAG_1MONTH_FLAG, 0) = 1  
 AND A.CCF_RULE_ID = @RULE_ID        
        
END;
GO
