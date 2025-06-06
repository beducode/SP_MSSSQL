USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_LGD_SCENARIO_DATA]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMP_LGD_SCENARIO_DATA]                               
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
                                    
 SELECT * INTO #LGD FROM IFRS_LGD_SCENARIO_DATA WHERE 1=2                                    
                        
 SET @V_STR_SQL = ''                                    
                                    
 DECLARE SEG1                                    
 CURSOR FOR                                    
  SELECT A.PKID, B.SEGMENT, B.SUB_SEGMENT, B.GROUP_SEGMENT, REPLACE(B.CONDITION, '"', '') AS CONDITION, A.LAG_1MONTH_FLAG, UPPER(A.CALC_METHOD) AS CALC_METHOD            
  FROM IFRS_LGD_RULES_CONFIG A                                    
  INNER JOIN  IFRS_SCENARIO_SEGMENT_GENERATE_QUERY B                                    
  ON A.SEGMENTATION_ID = B.RULE_ID                                    
  WHERE B.SEGMENT_TYPE = 'LGD_SEGMENT'                             
  AND IS_DELETE = 0                             
  AND ACTIVE_FLAG = 1                             
  AND A.CUT_OFF_DATE <= CASE WHEN A.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END        
  AND A.LGD_METHOD = 'CR x LGL'        
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
   ,LGD_RULE_ID                                    
   ,LGD_RULE_NAME                                    
   ,DEFAULT_RULE_ID                                    
   ,MASTERID                                    
   ,ACCOUNT_NUMBER                                    
   ,CUSTOMER_NUMBER                                    
   ,SEGMENT                                    
   ,SUB_SEGMENT                                    
   ,GROUP_SEGMENT                                  
   ,EIR_SEGMENT     
   ,LGD_METHOD                                    
   ,LGD_UNIQUE_ID                                    
   ,CALC_METHOD                                    
   ,CALC_AMOUNT                             
   ,OUTSTANDING                                    
   ,IMPAIRED_FLAG                                    
   ,DEFAULT_FLAG                         
   ,FAIR_VALUE_AMOUNT                                    
   ,BI_COLLECTABILITY                                    
   ,DAY_PAST_DUE                 
   ,DPD_CIF                                    
   ,DPD_FINAL                                    
   ,DPD_FINAL_CIF                                    
   ,CREATEDBY                       
   ,CREATEDDATE                                   
   ,LOAN_START_DATE                            
   ,AVG_EIR                        
   ,RESTRU_SIFAT_FLAG              
   ,WO_FLAG               
   ,FP_FLAG_ORIG                       
  )                                    
  SELECT    
   A.DOWNLOAD_DATE                                    
   ,B.PKID AS LGD_RULE_ID                                    
   ,B.LGD_RULE_NAME                                    
   ,B.DEFAULT_RULE_ID                                    
   ,A.MASTERID                                    
   ,A.ACCOUNT_NUMBER                                    
   ,A.CUSTOMER_NUMBER                                    
   ,'''+@SEGMENT+''' AS SEGMENT                                    
   ,'''+@SUB_SEGMENT+''' AS SUB_SEGMENT                                    
   ,'''+@GROUP_SEGMENT+''' AS GROUP_SEGMENT                                    
   ,A.EIR_SEGMENT                              
   ,LGD_METHOD                                    
   ,CASE CALC_METHOD WHEN ''CUSTOMER'' THEN A.CUSTOMER_NUMBER WHEN ''ACCOUNT'' THEN A.MASTERID END AS LGD_UNIQUE_ID            
   ,UPPER(CALC_METHOD) AS CALC_METHOD                                  
   ,0 AS CALC_AMOUNT                                    
   ,A.OUTSTANDING * ISNULL(A.EXCHANGE_RATE, 1) AS OUTSTANDING                                    
   ,ISNULL(IMPAIRED_FLAG, ''C'') AS IMPAIRED_FLAG                          
   ,CASE WHEN C.MASTERID IS NOT NULL THEN 1 ELSE 0 END DEFAULT_FLAG                                    
   ,FAIR_VALUE_AMOUNT * ISNULL(A.EXCHANGE_RATE, 1) AS FAIR_VALUE_AMOUNT                                    
   ,A.BI_COLLECTABILITY                                    
   ,A.DAY_PAST_DUE                                    
   ,A.DPD_CIF                                    
   ,A.DPD_FINAL                                    
   ,A.DPD_FINAL_CIF                                         
   ,''ADMIN'' AS CREATEDBY                                  
   ,GETDATE() AS CREATEDDATE                                
   ,A.LOAN_START_DATE                            
   ,CASE WHEN ISNULL(A.EIR, 0) <> 0 THEN A.EIR/100 WHEN ISNULL(A.INTEREST_RATE, 0) <> 0 THEN A.INTEREST_RATE/100 ELSE D.AVG_EIR  END  AS AVG_EIR                
   ,CASE ''' + @V_CALC_METHOD + ''' WHEN ''CUSTOMER'' THEN ISNULL(E.RESTRU_SIFAT_FLAG_CIF, 0) WHEN ''ACCOUNT'' THEN ISNULL(E.RESTRU_SIFAT_FLAG, 0) END AS RESTRU_SIFAT_FLAG                 
   ,CASE ''' + @V_CALC_METHOD + ''' WHEN ''CUSTOMER'' THEN ISNULL(E.WO_FLAG_CIF, 0) WHEN ''ACCOUNT'' THEN ISNULL(E.WO_FLAG, 0) END AS WO_FLAG              
   ,FP_FLAG_ORIG                   
  FROM IFRS_MASTER_ACCOUNT_MONTHLY A (NOLOCK)                                    
  JOIN IFRS_LGD_RULES_CONFIG B ON B.PKID = ' + @LGD_RULE_ID + '                                  
  LEFT JOIN IFRS_DEFAULT C (NOLOCK) ON B.DEFAULT_RULE_ID = C.RULE_ID AND A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE              
  LEFT JOIN IFRS_IMP_AVG_EIR D (NOLOCK) ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND A.EIR_SEGMENT = D.EIR_SEGMENT          
  LEFT JOIN                        
  (                        
    SELECT                         
        DOWNLOAD_DATE,                        
        MASTERID,                   
        RESTRU_SIFAT_FLAG,                
        RESTRU_SIFAT_FLAG_CIF,                
        WO_FLAG,                
        WO_FLAG_CIF,            
  FP_FLAG_ORIG               
    FROM IFRS_IMP_DEFAULT_STATUS (NOLOCK)                        
    WHERE DOWNLOAD_DATE = CASE WHEN ' + @V_LAG + ' = 1 THEN EOMONTH(DATEADD(MM, -1, ''' + CONVERT(VARCHAR(10), @V_CURRDATE,112) + ''')) ELSE ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + ''' END                
  ) E ON A.DOWNLOAD_DATE = E.DOWNLOAD_DATE                         
  AND A.MASTERID = E.MASTERID                          
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
                                    
 --INSERT INTO TABLE SCENARIO DATA                                    
 DELETE A                                  
 FROM IFRS_LGD_SCENARIO_DATA A                                  
 JOIN IFRS_LGD_RULES_CONFIG B                                  
 ON A.LGD_RULE_ID = B.PKID                                  
 WHERE DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END
 AND B.ACTIVE_FLAG = 1 AND B.IS_DELETE = 0                                 
                                   
 INSERT INTO IFRS_LGD_SCENARIO_DATA                              
 (                              
 DOWNLOAD_DATE                              
 ,LGD_RULE_ID                           
 ,LGD_RULE_NAME                              
 ,DEFAULT_RULE_ID                              
 ,MASTERID                              
 ,SEGMENT                              
 ,SUB_SEGMENT                              
 ,GROUP_SEGMENT                              
 ,EIR_SEGMENT                              
 ,ACCOUNT_NUMBER                              
 ,CUSTOMER_NUMBER                              
 ,LOAN_START_DATE                              
 ,LGD_METHOD                              
 ,CALC_METHOD                              
 ,CALC_AMOUNT                              
 ,OUTSTANDING                              
 ,IMPAIRED_FLAG                              
 ,DEFAULT_FLAG                              
 ,FAIR_VALUE_AMOUNT                              
 ,BI_COLLECTABILITY                              
 ,RATING_CODE                              
 ,DAY_PAST_DUE                              
 ,DPD_CIF                              
 ,DPD_FINAL                              
 ,DPD_FINAL_CIF                              
 ,LGD_UNIQUE_ID                            
 ,AVG_EIR                         
 ,RESTRU_SIFAT_FLAG                
 ,WO_FLAG            
 ,FP_FLAG_ORIG                             
 )                     
 SELECT                               
 DOWNLOAD_DATE                              
 ,LGD_RULE_ID                              
 ,LGD_RULE_NAME                              
 ,DEFAULT_RULE_ID                              
 ,MASTERID                              
 ,SEGMENT                              
 ,SUB_SEGMENT                              
 ,GROUP_SEGMENT                              
 ,EIR_SEGMENT                              
 ,ACCOUNT_NUMBER                              
 ,CUSTOMER_NUMBER                              
 ,LOAN_START_DATE                              
 ,LGD_METHOD                              
 ,CALC_METHOD                              
 ,CALC_AMOUNT                              
 ,OUTSTANDING            
 ,IMPAIRED_FLAG                              
 ,DEFAULT_FLAG                              
 ,FAIR_VALUE_AMOUNT                              
 ,BI_COLLECTABILITY                              
 ,RATING_CODE                              
 ,DAY_PAST_DUE                              
 ,DPD_CIF                              
 ,DPD_FINAL                              
 ,DPD_FINAL_CIF                              
 ,LGD_UNIQUE_ID                            
 ,AVG_EIR                        
 ,RESTRU_SIFAT_FLAG                 
 ,WO_FLAG            
 ,FP_FLAG_ORIG                              
 FROM #LGD                                    
                                    
END 
GO
