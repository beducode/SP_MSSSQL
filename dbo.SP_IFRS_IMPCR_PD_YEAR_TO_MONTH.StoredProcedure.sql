USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_PD_YEAR_TO_MONTH]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_PD_YEAR_TO_MONTH]  -- '20190930' 
@DOWNLOAD_DATE DATE = '',
@RULE_ID BIGINT = 0     
 AS      
BEGIN      
   DECLARE @V_CURRDATE   DATE                                                                          
  DECLARE @V_PREVDATE   DATE            
  DECLARE @V_PREVMONTH DATE         
  DECLARE @V_CURRDATE_NOLAG   DATE                                                                          
  DECLARE @V_PREVDATE_NOLAG   DATE            
  DECLARE @V_PREVMONTH_NOLAG DATE       
    
   IF @DOWNLOAD_DATE <> ''          
 BEGIN           
 SET @V_CURRDATE = EOMONTH(DATEADD(MONTH,-1,@DOWNLOAD_DATE)) -- LAG -1 MONTH BTPN          
 SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)          
 SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))          
    
 SET @V_CURRDATE_NOLAG = EOMONTH(@DOWNLOAD_DATE) -- NO LAG          
 SET @V_PREVDATE_NOLAG = DATEADD(DAY,-1,@V_CURRDATE_NOLAG)          
 SET @V_PREVMONTH_NOLAG = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE_NOLAG))          
 END          
 ELSE           
 BEGIN           
 SELECT @V_CURRDATE = EOMONTH(DATEADD(M,-1,CURRDATE) )            
 FROM IFRS_PRC_DATE          
 SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)          
 SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))     
    
 SELECT @V_CURRDATE_NOLAG =  EOMONTH(CURRDATE)  FROM IFRS_PRC_DATE             
 SET @V_PREVDATE_NOLAG = DATEADD(DAY,-1,@V_CURRDATE_NOLAG)          
 SET @V_PREVMONTH_NOLAG = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE_NOLAG))          
 END          
              
  
    DECLARE @MAX_YEAR INT      
    DECLARE @MIN_YEAR INT      
    DECLARE @COUNT_MIN INT = 1       
    DECLARE @COUNT_MAX INT = 12      
          
    DELETE A  
 FROM IFRS_PD_TERM_STRUCTURE_NOFL A  
 INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID AND IS_DELETE   = 0 AND ACTIVE_FLAG = 1   
 WHERE CURR_DATE =  (CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN @V_CURRDATE ELSE @V_CURRDATE_NOLAG END    )
 AND A.PD_RULE_ID = @RULE_ID  
          
    WHILE @COUNT_MIN <= @COUNT_MAX      
    BEGIN       
          print @count_min
        INSERT INTO IFRS_PD_TERM_STRUCTURE_NOFL     
        (    
            DOWNLOAD_DATE      
            ,CURR_DATE      
            ,PD_RULE_ID      
            ,PD_RULE_NAME      
            ,BUCKET_GROUP      
            ,BUCKET_ID      
            ,BUCKET_NAME      
            ,FL_SEQ      
            ,FL_YEAR      
            ,FL_MONTH      
            ,FL_DATE      
            ,PD_RATE      
        )      
        SELECT        
            DOWNLOAD_DATE      
            ,CURR_DATE AS CURR_DATE      
            ,PD_RULE_ID      
            ,PD_RULE_NAME      
            ,A.BUCKET_GROUP      
            ,BUCKET_ID      
            ,BUCKET_NAME      
            ,(12 * (FL_YEAR-1)) + @COUNT_MIN AS FL_SEQ      
            ,FL_YEAR AS FL_YEAR      
            ,@COUNT_MIN AS FL_MONTH      
            ,NULL AS FL_DATE      
            ,CASE     
                WHEN @COUNT_MIN  = 1 THEN 1-POWER((1-PD_RATE),(CAST( @COUNT_MIN AS FLOAT)/CAST( 12 AS FLOAT)))      
                ELSE (1-POWER((1-PD_RATE),(CAST( @COUNT_MIN AS FLOAT)/CAST( 12 AS FLOAT)))) - (1-POWER((1-PD_RATE),(CAST((@COUNT_MIN-1) AS FLOAT)/CAST( 12 AS FLOAT))))      
             END AS PD_RATE      
        FROM [IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY] A      
   INNER JOIN IFRS_PD_RULES_CONFIG B ON A.PD_RULE_ID = B.PKID AND IS_DELETE   = 0 AND ACTIVE_FLAG = 1    
        WHERE CURR_DATE = (CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN @V_CURRDATE ELSE @V_CURRDATE_NOLAG END    )      
  AND A.CREATEDBY<>'NFR'
  AND A.PD_RULE_ID = @RULE_ID     
          
        SET @COUNT_MIN = @COUNT_MIN + 1      
    END    
    
    
 --- INSERT FOR NETFLOWRATE     
     
DELETE IFRS_PD_TERM_STRUCTURE_NOFL WHERE CREATEDBY = 'NFR' AND PD_RULE_ID = @RULE_ID   
    
INSERT INTO  IFRS_PD_TERM_STRUCTURE_NOFL (DOWNLOAD_DATE    
,CURR_DATE    
,PD_RULE_ID    
,PD_RULE_NAME    
,BUCKET_GROUP    
,BUCKET_ID    
,BUCKET_NAME    
,FL_SEQ    
,FL_YEAR    
,FL_MONTH    
,FL_DATE    
,PD_RATE    
,CREATEDBY    
,CREATEDDATE    
)    
SELECT DOWNLOAD_DATE    
,DOWNLOAD_DATE AS CURR_DATE    
,PD_RULE_ID    
,PD_RULE_NAME    
,BUCKET_GROUP    
,BUCKET_ID    
,NULL AS BUCKET_NAME    
,1 AS FL_SEQ    
,1 AS FL_YEAR    
,1 AS FL_MONTH    
,NULL AS FL_DATE    
,PD_RATE    
,'NFR'  AS CREATEDBY    
,CREATEDDATE FROM IFRS_PD_NFR_RESULT A  
WHERE PD_RULE_ID = @RULE_ID  
    
END    
GO
