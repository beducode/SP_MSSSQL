USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_AVG_EIR]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_AVG_EIR]                   
@DOWNLOAD_DATE DATE = NULL             
AS              
 DECLARE                         
 @v_TABLE_NAME VARCHAR(30),            
 @V_STR_SQL VARCHAR(4000),                 
 @V_SUB_SEGMENT VARCHAR(250),            
 @V_CONDITION VARCHAR(4000),            
 @V_CURRDATE DATE,                        
 @V_STARTDATE_OF_YEAR DATE                
BEGIN              
 SET NOCOUNT ON;             
               
 IF (@DOWNLOAD_DATE IS NULL)              
 BEGIN              
    SELECT @V_CURRDATE = CONVERT(VARCHAR(8), @V_CURRDATE, 112)              
    FROM IFRS_PRC_DATE          
 END              
 ELSE              
 BEGIN              
    SELECT @V_CURRDATE = @DOWNLOAD_DATE              
 END              
                
 SET @V_STARTDATE_OF_YEAR = CONCAT(YEAR(@V_CURRDATE), '0101')                     
                
 DECLARE @V_START DATE, @V_END DATE                
 SET @V_START = EOMONTH(@V_STARTDATE_OF_YEAR)                
 SET @V_END =  EOMONTH(DATEADD(MM,-1,@V_CURRDATE))    
                
 SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, INTEREST_RATE, LOAN_START_DATE                
 INTO #IMA                
 FROM IFRS_MASTER_ACCOUNT_MONTHLY                
 WHERE 1 = 2                
                
 WHILE @V_START <= @V_END                
 BEGIN                
    INSERT INTO #IMA (DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, INTEREST_RATE, LOAN_START_DATE)            
    SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, INTEREST_RATE, LOAN_START_DATE            
    FROM IFRS_MASTER_ACCOUNT_MONTHLY (NOLOCK)                
    WHERE DOWNLOAD_DATE = @V_START                
    ORDER BY DOWNLOAD_DATE, MASTERID                
                 
    SET @V_START = EOMONTH(DATEADD(MM, 1, @V_START))                
 END                 
     
 INSERT INTO #IMA (DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, INTEREST_RATE, LOAN_START_DATE)            
 SELECT DOWNLOAD_DATE, MASTERID, EIR_SEGMENT, EIR, INTEREST_RATE, LOAN_START_DATE                
 FROM [dbo].IFRS_IMA_IMP_CURR (NOLOCK)                
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
 ORDER BY DOWNLOAD_DATE, MASTERID                 
  
                 
 DELETE IFRS_IMP_AVG_EIR WHERE DOWNLOAD_DATE = @V_CURRDATE AND CREATEDBY <> 'AVG_FS'            
                
 INSERT INTO IFRS_IMP_AVG_EIR (DOWNLOAD_DATE, AVG_EIR, EIR_SEGMENT, CREATEDBY)                      
 SELECT @V_CURRDATE AS DOWNLOAD_DATE, AVG(EIR)/100 AS AVG_EIR, EIR_SEGMENT, 'AVG_EIR'                
 FROM #IMA                
 WHERE EIR_SEGMENT IS NOT NULL AND DOWNLOAD_DATE >= '20190101'               
 GROUP BY EIR_SEGMENT                
                
 UPDATE AVG                
 SET AVG_EIR = IMA.AVG_EIR, CREATEDBY = IMA.CREATEDBY                
 FROM IFRS_IMP_AVG_EIR AVG                
 JOIN                 
 (                
    SELECT @V_CURRDATE AS DOWNLOAD_DATE, AVG(INTEREST_RATE)/100 AS AVG_EIR, EIR_SEGMENT, 'AVG_INT' AS CREATEDBY                
    FROM #IMA                
    WHERE YEAR(LOAN_START_DATE) = YEAR(@V_CURRDATE)                
    AND EIR_SEGMENT IN (SELECT EIR_SEGMENT FROM IFRS_IMP_AVG_EIR WHERE AVG_EIR IS NULL)            
    GROUP BY EIR_SEGMENT                
 ) IMA ON AVG.EIR_SEGMENT = IMA.EIR_SEGMENT AND AVG.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE            
 WHERE AVG.AVG_EIR IS NULL AND AVG.CREATEDBY <> 'AVG_FS'                 
             
UPDATE A            
 SET A.AVG_EIR = B.AVG_EIR            
 FROM IFRS_IMA_IMP_CURR A (NOLOCK)           
 JOIN IFRS_IMP_AVG_EIR B (NOLOCK)            
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE            
 AND A.EIR_SEGMENT = B.EIR_SEGMENT            
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE            
  
  /*
 UPDATE A   
  SET A.AVG_EIR = B.AVG_EIR            
 FROM IFRS_MASTER_ACCOUNT_MONTHLY A (NOLOCK)           
 JOIN IFRS_IMP_AVG_EIR B (NOLOCK)            
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE            
 AND A.EIR_SEGMENT = B.EIR_SEGMENT            
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE    
  */ 
            
END
GO
