USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_RETAIL_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

  
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_RETAIL_DATA]            
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
 ---- START IFRS_MARKET_INT_RATE ----        
 ------------------------------------------             
 DELETE FROM IFRS_MARKET_INT_RATE WHERE DOWNLOAD_DATE = @V_CURRDATE        
        
 INSERT INTO IFRS_MARKET_INT_RATE         
 (        
   DEAL_TYPE          
  ,DOWNLOAD_DATE        
  ,MARKET_INT_RATE        
  ,CREATEDBY        
  ,CREATEDDATE        
 )        
 SELECT        
   DEAL_TYPE   
  ,MAX(EOMONTH(DOWNLOAD_DATE))            
  ,MAX(MARKET_INT_RATE)        
  ,'SP_IFRS_SYNC_RETAIL_DATA' AS CREATEDBY        
  ,GETDATE () AS CREATEDDATE        
 FROM TBLU_MARKET_INT_RATE         
 WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE  
 GROUP BY DEAL_TYPE  
 ----------------------------------------        
 ---- END IFRS_MARKET_INT_RATE ----        
 ----------------------------------------           
        
END


GO
