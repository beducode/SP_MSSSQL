USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_UPDATE_WO_RECOVERY_PORTFOLIO]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_UPDATE_WO_RECOVERY_PORTFOLIO]     
@DOWNLOAD_DATE DATE = NULL                      
AS                   
----SET @DOWNLOAD_DATE = '20231130'          
DECLARE          
  @V_RULE_ID VARCHAR(250),                                      
  @V_STR_SQL VARCHAR(4000),          
  @V_GROUP_SEGMENT VARCHAR(250),          
  @V_SEGMENT VARCHAR(250),          
  @V_SUB_SEGMENT VARCHAR(250),          
  @V_CONDITION VARCHAR(4000),          
  @V_CURRDATE DATE,                                      
  @V_EXCEPT_ID VARCHAR(10),     
  @CIF VARCHAR(50)           
BEGIN            
 SET NOCOUNT ON;                         
                       
 IF (@DOWNLOAD_DATE IS NULL)                      
 BEGIN                      
 SELECT @V_CURRDATE = CONVERT(VARCHAR(8), CURRDATE, 112) FROM IFRS_PRC_DATE                      
 END                      
 ELSE                               
 BEGIN                      
 SELECT @V_CURRDATE = @DOWNLOAD_DATE                      
 END                      
                               
 SET @V_EXCEPT_ID = 888;    
     
 DECLARE @CSPRD_VALUE VARCHAR(100)    
 DECLARE @SQLRATING_CODE NVARCHAR(MAX)    
    
----- PRODUCT TYPE FILTER    
 SELECT @CSPRD_VALUE = VALUE1  FROM IFRS9..TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'PRD_TYPE_CS'    
    
------ CROSS SEGMENT PROFILING    
    
IF OBJECT_ID ('TEMPDB.DBO.#TBLU_CUST_GRADE') IS NOT NULL DROP TABLE #TBLU_CUST_GRADE    
SELECT DISTINCT CUSTOMER_NUMBER INTO #TBLU_CUST_GRADE FROM TBLU_CUSTOMER_GRADING     
WHERE DOWNLOAD_DATE <= @V_CURRDATE    
    
IF OBJECT_ID ('TEMPDB.DBO.#IMA_CS') IS NOT NULL DROP TABLE #IMA_CS    
SELECT CUSTOMER_NUMBER, SEGMENT_FLAG INTO #IMA_CS FROM IFRS_MASTER_ACCOUNT     
--WHERE DOWNLOAD_DATE = '20231130'    
WHERE DOWNLOAD_DATE = @V_CURRDATE    
AND SEGMENT_FLAG <> 'N/A'    
    
    
------ CROSS SEGMENT PROFILING    
    
SET @SQLRATING_CODE = ''    
        
SET @SQLRATING_CODE = 'UPDATE A        
SET A.SEGMENT_FLAG = ISNULL(B.SEGMENT_FLAG,''N/A'')           
FROM IFRS_MASTER_WO A     
LEFT JOIN #IMA_CS B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER       
WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + '''      
AND A.PRODUCT_TYPE IN (''' + REPLACE(@CSPRD_VALUE, ',', ''',''') + ''')'    
     
EXEC SP_EXECUTESQL @SQLRATING_CODE      
----PRINT @SQLRATING_CODE    
    
SET @SQLRATING_CODE = ''    
        
SET @SQLRATING_CODE = 'UPDATE A        
SET A.SEGMENT_FLAG = ISNULL(B.SEGMENT_FLAG,''N/A'')                  
FROM IFRS_MASTER_WO_RECOVERY A     
LEFT JOIN #IMA_CS B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER       
WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + '''      
AND A.PRODUCT_TYPE IN (''' + REPLACE(@CSPRD_VALUE, ',', ''',''') + ''')'    
     
EXEC SP_EXECUTESQL @SQLRATING_CODE    
----PRINT @SQLRATING_CODE     
           
 -- ADDITIONAL FOR IFRS_MASTER_WO_RECOVERY              
 SET @V_STR_SQL =                         
 'UPDATE A          
 SET A.SUB_SEGMENT = NULL, A.SEGMENT = NULL, A.GROUP_SEGMENT = NULL          
 FROM IFRS_MASTER_WO_RECOVERY A          
 WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';        
 EXEC (@V_STR_SQL);         
              
 -- ADDITIONAL FOR IFRS_MASTER_WO              
 SET @V_STR_SQL =                         
 'UPDATE A          
 SET A.SUB_SEGMENT = NULL, A.SEGMENT = NULL, A.GROUP_SEGMENT = NULL          
 FROM IFRS_MASTER_WO A          
 WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';        
 EXEC (@V_STR_SQL);                                   
                                    
 DELETE IFRS_EXCEPTION_ACCOUNT                                    
 WHERE EXCEPTION_ID = @V_EXCEPT_ID AND DOWNLOAD_DATE = @V_CURRDATE                                    
                                  
 DECLARE I SCROLL CURSOR FOR          
 SELECT DISTINCT          
 RULE_ID,          
 GROUP_SEGMENT,      
 SEGMENT,          
 SUB_SEGMENT,          
 CONDITION          
 FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY          
 WHERE SEGMENT_TYPE = 'PORTFOLIO_SEGMENT' AND GROUP_SEGMENT NOT IN ('CORPORATE', 'TREASURY') AND SEGMENT NOT IN ('MB - TRADE')          
                  
 OPEN I          
 WHILE 1=1                                       
 BEGIN          
                
    FETCH NEXT FROM I INTO @V_RULE_ID, @V_GROUP_SEGMENT, @V_SEGMENT, @V_SUB_SEGMENT, @V_CONDITION;                                 
    IF @@FETCH_STATUS = -1                
    BREAK          
          
        -- ADDITIONAL FOR IFRS_MASTER_WO_RECOVERY          
        SET @V_STR_SQL =                               
         'UPDATE A SET A.SUB_SEGMENT = ''' + @V_SUB_SEGMENT + ''', A.SEGMENT = ''' + @V_SEGMENT + ''', A.GROUP_SEGMENT = ''' + @V_GROUP_SEGMENT        
         + ''' FROM IFRS_MASTER_WO_RECOVERY A '          
         + 'WHERE (' + @V_CONDITION + ') AND DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';                                          
        --PRINT @V_STR_SQL               
        EXEC (@V_STR_SQL)        
                
        -- ADDITIONAL FOR IFRS_MASTER_WO        
        SET @V_STR_SQL =                               
         'UPDATE A SET A.SUB_SEGMENT = ''' + @V_SUB_SEGMENT + ''', A.SEGMENT = ''' + @V_SEGMENT + ''', A.GROUP_SEGMENT = ''' + @V_GROUP_SEGMENT        
         + ''' FROM IFRS_MASTER_WO A '          
         + 'WHERE (' + @V_CONDITION + ') AND DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';                                          
        --PRINT @V_STR_SQL               
        EXEC (@V_STR_SQL)               
                   
    END                
    CLOSE I                
    DEALLOCATE I                                       
                              
END 
GO
