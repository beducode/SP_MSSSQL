USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_AC_GENERATE_RESULT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_AC_GENERATE_RESULT] @BM_ID BIGINT          
AS         
BEGIN    
    
CREATE TABLE #BM    
(    
 PKID INT,    
    BM_NAME VARCHAR(100),    
    SPPI_CLASS VARCHAR(MAX),    
 EFFECTIVE_DATE DATE,    
 BM_RSLT VARCHAR(20)    
)    
    
INSERT INTO #BM SELECT PKID, BM_NAME, SPPI_CLASS, EFFECTIVE_DATE, BM_RSLT FROM IFRS_AC_BM_HEADER WHERE IS_DELETE = 0 AND PKID = @BM_ID  
    
;WITH tmp(PKID, BM_RSLT, EFFECTIVE_DATE, BM_NAME, SPPI_CLASS, String) AS    
(    
    SELECT    
  PKID,    
  BM_RSLT,    
  EFFECTIVE_DATE,    
        BM_NAME,    
        LEFT(SPPI_CLASS, CHARINDEX(',', SPPI_CLASS + ',') - 1) SPPI_CLASS,    
        STUFF(SPPI_CLASS, 1, CHARINDEX(',', SPPI_CLASS + ','), '') String    
    FROM #BM    
    UNION ALL    
    SELECT    
  PKID,    
        BM_RSLT,    
  EFFECTIVE_DATE,    
        BM_NAME,    
        LEFT(String, CHARINDEX(',', String + ',') - 1) SPPI_CLASS,    
        STUFF(String, 1, CHARINDEX(',', String + ','), '') String    
    FROM tmp    
    WHERE    
        String > ''    
)    
    
SELECT    
 PKID,    
    BM_RSLT,    
 EFFECTIVE_DATE,    
    BM_NAME,    
    SPPI_CLASS,    
 String    
INTO #BM_HEAD    
FROM tmp    
ORDER BY BM_NAME    

DELETE FROM IFRS_AC_MAPPING WHERE BMID = @BM_ID
          
IF EXISTS (SELECT TOP 1 BMID FROM IFRS_AC_MAPPING WHERE BMID = @BM_ID)          
BEGIN        
 IF EXISTS(SELECT TOP 1 BMID FROM IFRS_AC_MAPPING A        
    LEFT JOIN #BM_HEAD B        
    ON A.SPPIID = B.SPPI_CLASS AND A.EFF_DATE = B.EFFECTIVE_DATE        
   WHERE A.BMID = @BM_ID        
    AND A.EFF_DATE = B.EFFECTIVE_DATE)        
 BEGIN        
  UPDATE MAP          
   SET SPPI_RSLT = CASE WHEN ISNULL(SPPI.OVERRIDE_RSLT,'') != '' THEN SPPI.OVERRIDE_RSLT ELSE SPPI.SPPI_RSLT END,        
    BM_RSLT = BM.BM_RSLT          
  FROM IFRS_AC_MAPPING MAP INNER JOIN IFRS_AC_BM_HEADER BM ON MAP.BMID = BM.PKID          
  INNER JOIN IFRS_AC_SPPI_HEADER SPPI ON MAP.SPPIID = SPPI.PKID          
  WHERE          
   BMID = @BM_ID           
 END        
 ELSE        
 BEGIN          
  INSERT INTO IFRS_AC_MAPPING          
  (          
   EFF_DATE,          
   BMID,          
   SPPIID,          
   SPPI_RSLT,          
   BM_RSLT,          
   FV_OPTION,          
   ASSET_CLASS          
  )          
  SELECT          
   BM.EFFECTIVE_DATE,          
   @BM_ID,          
   SPPI_CLASS,          
   CASE        
  WHEN ISNULL(SPPI.OVERRIDE_RSLT,'') != '' THEN SPPI.OVERRIDE_RSLT        
  ELSE SPPI.SPPI_RSLT        
  END AS SPPI_RSLT,        
   BM.BM_RSLT,          
   0,          
   '' AS ASSET_CLASS          
  FROM #BM_HEAD BM INNER JOIN IFRS_AC_SPPI_HEADER SPPI ON BM.SPPI_CLASS = SPPI.CLASSNAME          
  WHERE          
   BM.PKID = @BM_ID          
 END        
END          
ELSE          
BEGIN          
 INSERT INTO IFRS_AC_MAPPING          
 (          
  EFF_DATE,          
  BMID,          
  SPPIID,          
  SPPI_RSLT,          
  BM_RSLT,          
  FV_OPTION,          
  ASSET_CLASS          
 )          
 SELECT          
  BM.EFFECTIVE_DATE,          
  @BM_ID,          
  SPPI_CLASS,        
  CASE        
 WHEN ISNULL(SPPI.OVERRIDE_RSLT,'') != '' THEN SPPI.OVERRIDE_RSLT        
 ELSE SPPI.SPPI_RSLT        
  END AS SPPI_RSLT,        
  BM.BM_RSLT,          
  0,          
  '' AS ASSET_CLASS          
 FROM #BM_HEAD BM INNER JOIN IFRS_AC_SPPI_HEADER SPPI ON BM.SPPI_CLASS = SPPI.PKID          
 WHERE          
  BM.PKID = @BM_ID          
END       
      
      
UPDATE A      
SET ASSET_CLASS = B.ASSET_CLASS      
FROM  IFRS_AC_MAPPING A      
INNER JOIN IFRS_AC_MAIN_MAPPING B ON A.BM_RSLT = B.BM_RSLT      
AND A.SPPI_RSLT  = B.SPPI_RSLT  
AND 0 = B.FV_OPTION      
WHERE          
 A.BMID = @BM_ID
 
 DECLARE @CREATEDBY AS VARCHAR(100);
 SELECT TOP 1 @CREATEDBY = CREATEDBY  FROM IFRS_AC_BM_HEADER WHERE PKID = @BM_ID 

 UPDATE IFRS_AC_MAPPING
 SET CREATEDBY = @CREATEDBY
 WHERE BMID = @BM_ID        
END 



GO
