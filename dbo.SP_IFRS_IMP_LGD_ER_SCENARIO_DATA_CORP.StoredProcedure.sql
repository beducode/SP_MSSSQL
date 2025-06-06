USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_LGD_ER_SCENARIO_DATA_CORP]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMP_LGD_ER_SCENARIO_DATA_CORP]                                 
@DOWNLOAD_DATE DATE = NULL                                  
AS          
 DECLARE @V_CURRDATE  DATE          
 DECLARE @V_PREVDATE  DATE          
 DECLARE @V_PREVMONTH DATE          
 DECLARE @V_STR_SQL VARCHAR(max)            
 DECLARE @LGD_RULE_ID VARCHAR(50)          
 DECLARE @DEFAULT_RULE_ID VARCHAR(50)          
 DECLARE @SEGMENT VARCHAR(100)          
 DECLARE @SUB_SEGMENT VARCHAR(100)          
 DECLARE @GROUP_SEGMENT VARCHAR(100)          
 DECLARE @CONDITION VARCHAR(4000)                          
 DECLARE @V_LAG CHAR(1)                           
 DECLARE @V_CALC_METHOD VARCHAR(50)                                  
BEGIN          
           
 IF (@DOWNLOAD_DATE IS NULL)          
 BEGIN          
  SELECT           
   @V_CURRDATE = EOMONTH(CURRDATE)                                    
   ,@V_PREVDATE = DATEADD(DAY,-1,CURRDATE)          
   ,@V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,CURRDATE))          
  FROM IFRS_PRC_DATE          
 END          
 ELSE          
 BEGIN          
  SET @V_CURRDATE = EOMONTH(@DOWNLOAD_DATE)                                     
  SET @V_PREVDATE = DATEADD(DAY,-1, @DOWNLOAD_DATE)          
  SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, -1, @DOWNLOAD_DATE))           
 END          
          
 SELECT * INTO #LGD FROM IFRS_LGD_ER_SCENARIO_DATA WHERE 1=2          
                          
 SET @V_STR_SQL = ''          
          
 DECLARE SEG1          
 CURSOR FOR          
  SELECT A.PKID, B.SEGMENT, B.SUB_SEGMENT, B.GROUP_SEGMENT, B.CONDITION, A.LAG_1MONTH_FLAG, UPPER(A.CALC_METHOD) AS CALC_METHOD              
  FROM IFRS_LGD_RULES_CONFIG A          
  INNER JOIN  IFRS_SCENARIO_SEGMENT_GENERATE_QUERY B          
  ON A.SEGMENTATION_ID = B.RULE_ID          
  WHERE B.SEGMENT_TYPE = 'LGD_SEGMENT'                               
  AND IS_DELETE = 0                               
  AND ACTIVE_FLAG = 1                               
  AND A.CUT_OFF_DATE <= CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END      
  AND A.LGD_METHOD = 'EXPECTED RECOVERY'      
  ORDER BY PKID           
 OPEN seg1;             
 FETCH seg1 INTO @LGD_RULE_ID, @SEGMENT, @SUB_SEGMENT, @GROUP_SEGMENT, @CONDITION, @V_LAG, @V_CALC_METHOD          
 WHILE @@FETCH_STATUS = 0          
 BEGIN            
  SET @V_STR_SQL = ''          
          
  SET @V_STR_SQL = '          
  INSERT INTO #LGD          
  (               
    DOWNLOAD_DATE          
    ,DEFAULT_DATE          
    ,RECOVERY_DATE          
    ,CALC_METHOD          
    ,LGD_UNIQUE_ID          
	,CUSTOMER_NAME          
    ,LGD_METHOD          
    ,LGD_RULE_ID          
    ,LGD_RULE_NAME          
    ,PRODUCT_GROUP          
    ,SEGMENT          
    ,SUB_SEGMENT          
    ,GROUP_SEGMENT          
    ,CURRENCY          
    ,EXCHANGE_RATE          
    ,OS_AT_DEFAULT          
    ,RECOVERY_AMOUNT          
    ,EIR_AT_DEFAULT          
    ,JAP_FLAG                   
  )          
  SELECT          
   A.DOWNLOAD_DATE          
   ,A.DEFAULT_DATE          
   ,A.RECOVERY_DATE          
   ,UPPER(B.CALC_METHOD) AS CALC_METHOD          
   ,A.CUSTOMER_NUMBER AS LGD_UNIQUE_ID          
   ,A.CUSTOMER_NAME          
   ,B.LGD_METHOD          
   ,B.PKID AS LGD_RULE_ID          
   ,B.LGD_RULE_NAME          
   ,A.PRODUCT_GROUP          
   ,'''+@SEGMENT+''' AS SEGMENT          
   ,'''+@SUB_SEGMENT+''' AS SUB_SEGMENT          
   ,'''+@GROUP_SEGMENT+''' AS GROUP_SEGMENT          
   ,A.CURRENCY          
   ,C.RATE_AMOUNT AS EXCHANGE_RATE          
   ,A.OS_AT_DEFAULT AS OS_AT_DEFAULT          
   ,A.NETT_RECOVERY AS RECOVERY_AMOUNT          
   ,A.EIR_AT_DEFAULT AS EIR_AT_DEFAULT          
   ,ISNULL(A.JAP_NON_JAP_IDENTIFIER, 0) AS JAP_FLAG          
  FROM IFRS_RECOVERY_CORP A (NOLOCK)          
  JOIN IFRS_LGD_RULES_CONFIG B ON B.PKID = ' + @LGD_RULE_ID + '          
  LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C ON EOMONTH(A.RECOVERY_DATE) = C.DOWNLOAD_DATE AND A.CURRENCY = C.CURRENCY          
  WHERE                                     
  A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, ''' + CONVERT(VARCHAR(10),@V_CURRDATE,112) + '''))          
  ELSE ''' + CONVERT(VARCHAR(10), @V_CURRDATE,112) + ''' END   
  ' + CASE WHEN @GROUP_SEGMENT LIKE '%JENIUS%' THEN + 'AND A.CUSTOMER_NUMBER NOT IN (SELECT DISTINCT CUSTOMER_NUMBER FROM IFRS_EXCLUDE_JENIUS) ' ELSE '' END + ' AND ' + @CONDITION + '' 
                              
  --PRINT  (@V_STR_SQL)          
  EXEC (@V_STR_SQL)          
          
  FETCH NEXT FROM seg1 INTO @LGD_RULE_ID, @SEGMENT, @SUB_SEGMENT, @GROUP_SEGMENT, @CONDITION, @V_LAG, @V_CALC_METHOD              
 END             
 CLOSE seg1;          
 DEALLOCATE seg1;          
          
 --INSERT INTO TABLE LGD DETAIL          
 DELETE A                                    
 FROM IFRS_LGD_ER_SCENARIO_DATA A                                  
 JOIN IFRS_LGD_RULES_CONFIG B                                    
 ON A.LGD_RULE_ID = B.PKID                                    
 WHERE DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END          
                                     
 INSERT INTO IFRS_LGD_ER_SCENARIO_DATA                                
 (                                
    DOWNLOAD_DATE          
    ,DEFAULT_DATE          
    ,RECOVERY_DATE          
    ,CALC_METHOD          
    ,LGD_UNIQUE_ID          
	,CUSTOMER_NAME          
    ,LGD_METHOD          
    ,LGD_RULE_ID          
    ,LGD_RULE_NAME          
    ,PRODUCT_GROUP          
    ,SEGMENT          
    ,SUB_SEGMENT          
    ,GROUP_SEGMENT          
    ,CURRENCY          
    ,EXCHANGE_RATE          
    ,OS_AT_DEFAULT          
    ,RECOVERY_AMOUNT          
    ,EIR_AT_DEFAULT          
    ,JAP_FLAG          
	,NPV_RECOVERY          
 )                       
 SELECT                                 
    DOWNLOAD_DATE          
    ,DEFAULT_DATE          
    ,RECOVERY_DATE          
    ,CALC_METHOD          
    ,LGD_UNIQUE_ID          
	,CUSTOMER_NAME          
    ,LGD_METHOD          
    ,LGD_RULE_ID          
    ,LGD_RULE_NAME          
    ,PRODUCT_GROUP          
    ,SEGMENT          
    ,SUB_SEGMENT          
    ,GROUP_SEGMENT          
    ,CURRENCY          
    ,EXCHANGE_RATE          
    ,OS_AT_DEFAULT          
    ,RECOVERY_AMOUNT          
    ,EIR_AT_DEFAULT          
    ,JAP_FLAG          
	,[dbo].[FUTIL_PV](ISNULL(EIR_AT_DEFAULT, 0)/100/12, DATEDIFF(MM, DEFAULT_DATE, RECOVERY_DATE), RECOVERY_AMOUNT) AS NPV_RECOVERY                           
 FROM #LGD          
          
END 
GO
