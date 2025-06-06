USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_RESTRU_SURVIVE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


      
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_RESTRU_SURVIVE]                
@DOWNLOAD_DATE DATE = NULL              
AS              
BEGIN              
 DECLARE @V_CURRDATE DATE              
 DECLARE @V_PREVDATE DATE              
 DECLARE @V_CURRDATE_CHAR VARCHAR(8)            
              
 IF @DOWNLOAD_DATE IS NULL              
 BEGIN              
  SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE              
 END              
 ELSE              
 BEGIN              
  SET @V_CURRDATE = @DOWNLOAD_DATE              
 END              
      
       
      
 ------------------------------------------            
 ---- START IFRS_MASTER_SURVIVE ----            
 ------------------------------------------                 
 DELETE FROM IFRS_MASTER_SURVIVE WHERE DOWNLOAD_DATE = EOMONTH(DATEADD(month,-1,(@V_CURRDATE)))          
  
 INSERT INTO IFRS_MASTER_SURVIVE             
 (            
  DOWNLOAD_DATE  
 ,CUSTOMER_NUMBER 
 ,PREVIOUS_MASTERID
 ,MASTERID  
 ,PREVIOUS_ACCOUNT_NUMBER
 ,ACCOUNT_NUMBER  
 ,PRODUCT_CODE  
 ,SURVIVE_FLAG  
 ,CREATEDBY  
 ,CREATEDDATE  
 ,CREATEDHOST            
 )            
 SELECT            
   DOWNLOAD_DATE  
 ,CUSTOMER_NUMBER  
 ,CONCAT(CUSTOMER_NUMBER,'_',PREVIOUS_ACCOUNT_NUMBER,'_',PRODUCT_CODE) as PREVIOUS_MASTERID  
 ,CONCAT(CUSTOMER_NUMBER,'_',ACCOUNT_NUMBER,'_',PRODUCT_CODE) as MASTERID  
 ,PREVIOUS_ACCOUNT_NUMBER
 ,ACCOUNT_NUMBER  
 ,PRODUCT_CODE  
 ,RTRIM(LTRIM(UPPER(SURVIVE_FLAG)))
 ,'SP_IFRS_SYNC_RESTRU_SURVIVE' AS CREATEDBY            
 ,GETDATE () AS CREATEDDATE  
 ,CREATEDHOST  
 FROM TBLU_SURVIVE_FLAG             
 WHERE EOMONTH(DOWNLOAD_DATE) = EOMONTH(DATEADD(month,-1,(@V_CURRDATE)))         
      
 ----------------------------------------            
 ---- END IFRS_MASTER_SURVIVE ----            
 ----------------------------------------               
            
END    

GO
