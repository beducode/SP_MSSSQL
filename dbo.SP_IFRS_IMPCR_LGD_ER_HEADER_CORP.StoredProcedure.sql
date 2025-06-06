USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_LGD_ER_HEADER_CORP]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_LGD_ER_HEADER_CORP]    
@DOWNLOAD_DATE DATE = NULL,  
@RULE_ID BIGINT = 0  
AS    
 DECLARE @V_CURRDATE DATE    
 DECLARE @V_PREVDATE DATE    
 DECLARE @V_PREVMONTH DATE    
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
    
 --INSERT INTO TABLE LGD HEADER    
 DELETE IFRS_LGD_ER_HEADER WHERE DOWNLOAD_DATE = @V_CURRDATE AND LGD_RULE_ID = @RULE_ID  
    
 INSERT INTO IFRS_LGD_ER_HEADER    
 (    
  DOWNLOAD_DATE    
  ,CALC_METHOD    
  ,LGD_METHOD    
  ,LGD_RULE_ID    
  ,LGD_RULE_NAME    
  ,PRODUCT_GROUP    
  ,SEGMENT    
  ,SUB_SEGMENT    
  ,GROUP_SEGMENT    
  ,RECOVERY_RATE    
  ,LGD    
 )    
 SELECT     
  DOWNLOAD_DATE    
  ,CALC_METHOD    
  ,LGD_METHOD    
  ,LGD_RULE_ID    
  ,LGD_RULE_NAME    
  ,PRODUCT_GROUP    
  ,SEGMENT    
  ,SUB_SEGMENT    
  ,GROUP_SEGMENT    
  ,1 - (SUM(LGD_X_OS) / SUM(EQV_AT_DEFAULT)) AS RECOVERY_RATE    
  ,SUM(LGD_X_OS) / SUM(EQV_AT_DEFAULT) AS LGD    
 FROM IFRS_LGD_ER_DETAIL    
 WHERE DOWNLOAD_DATE = @V_CURRDATE    
 AND LGD_RULE_ID = @RULE_ID  
 GROUP BY    
 DOWNLOAD_DATE    
 ,CALC_METHOD    
 ,LGD_METHOD    
 ,LGD_RULE_ID    
 ,LGD_RULE_NAME    
 ,PRODUCT_GROUP    
 ,SEGMENT    
 ,SUB_SEGMENT    
 ,GROUP_SEGMENT    
    
 -- LGD Term Structure    
 DELETE A             
 FROM IFRS_LGD_TERM_STRUCTURE A            
 JOIN IFRS_LGD_RULES_CONFIG B            
 ON A.LGD_RULE_ID = B.PKID            
 AND A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID            
 WHERE A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END        
 AND B.LGD_METHOD IN ('EXPECTED RECOVERY','EXTERNAL')    
    AND A.LGD_RULE_ID = @RULE_ID   
                                
 INSERT INTO IFRS_LGD_TERM_STRUCTURE                                
 (                                
  DOWNLOAD_DATE                                
  ,LGD_RULE_ID                                
  ,LGD_RULE_NAME                                
  ,DEFAULT_RULE_ID                                
  ,LGD                                
 )                                
 SELECT                                
  DOWNLOAD_DATE                                
  ,A.LGD_RULE_ID                                
  ,A.LGD_RULE_NAME                                
  ,B.DEFAULT_RULE_ID                                
  ,LGD                                
 FROM IFRS_LGD_ER_HEADER A (NOLOCK)                              
 JOIN IFRS_LGD_RULES_CONFIG B (NOLOCK)                              
 ON A.LGD_RULE_ID = B.PKID            
 AND B.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID            
 WHERE A.DOWNLOAD_DATE = CASE WHEN B.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END    
 AND A.LGD_RULE_ID = @RULE_ID  
 -- COMBINE WITH UPLOADED TREASURY LGD    
 UNION ALL    
 SELECT     
  A.DOWNLOAD_DATE,     
  C.PKID AS LGD_RULE_ID,     
  C.LGD_RULE_NAME,     
  C.DEFAULT_RULE_ID,     
  (1 - RECOVERY_RATE) AS LGD    
 FROM IFRS_RECOVERY_RATE_TREASURY A    
 JOIN IFRS_MSTR_SEGMENT_RULES_HEADER B ON A.SEGMENT = B.SEGMENT AND B.SEGMENT_TYPE = 'LGD_SEGMENT'    
 JOIN IFRS_LGD_RULES_CONFIG C ON B.PKID = C.SEGMENTATION_ID    
 WHERE C.LGD_METHOD = 'EXTERNAL' AND A.DOWNLOAD_DATE = CASE WHEN C.LAG_1MONTH_FLAG = 1 THEN EOMONTH(DATEADD(MM, -1, @V_CURRDATE)) ELSE @V_CURRDATE END    
 AND C.PKID = @RULE_ID  
     
END 
GO
