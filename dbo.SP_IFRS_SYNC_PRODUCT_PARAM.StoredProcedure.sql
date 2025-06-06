USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_PRODUCT_PARAM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_PRODUCT_PARAM]          
AS          
DECLARE @V_CURRDATE DATE          
 ,@V_PREVDATE DATE          
          
BEGIN          
 SELECT @V_CURRDATE = MAX(CURRDATE)          
    ,@V_PREVDATE = MAX(PREVDATE)          
 FROM IFRS_PRC_DATE_AMORT          
          
 INSERT INTO IFRS_AMORT_LOG (          
  DOWNLOAD_DATE          
  ,DTM          
  ,OPS          
  ,PROCNAME          
  ,REMARK          
  )          
 VALUES (          
  @V_CURRDATE          
  ,CURRENT_TIMESTAMP          
  ,'START'          
  ,'SP_IFRS_SYNC_PRODUCT_PARAM'          
  ,''          
  )          
           
 SELECT EFF_DATE, PRD_CODE, MKT_RATE          
 INTO #TMP_MARKETRATE          
 FROM ( SELECT PKID,PRD_CODE, EFF_DATE, MKT_RATE          
   ,ROW_NUMBER() OVER (PARTITION BY PRD_CODE ORDER BY EFF_DATE DESC) RN          
   FROM IFRS_MASTER_MARKETRATE_PARAM          
   WHERE EFF_DATE <= @V_CURRDATE    AND IS_DELETE = 0       
 ) A          
 WHERE RN = 1         
         
 --  PRE-PROCESS EXTRACT CURRENCY ALL AND SYNC SEGMENT              
 -- EXEC SP_EXTRACT_ALL_CCY_PARAM              
 --  EXEC SP_SYNC_MASTER_SEGMENT BCAF NO NEED              
 --  END PRE-PROCESS EXTRACT CURRENCY ALL AND SYNC SEGMENT                
 TRUNCATE TABLE IFRS_PRODUCT_PARAM          
          
 INSERT INTO IFRS_PRODUCT_PARAM (          
  DATA_SOURCE          
  ,PRD_TYPE          
  ,PRD_TYPE_1          
  ,PRD_CODE          
  ,PRD_GROUP          
  ,MARKET_RATE          
  ,CCY          
  ,AMORT_TYPE          
  ,IS_STAF_LOAN          
  ,IS_IMPAIRED          
  ,PRODUCT_DESCRIPTION          
  ,FEE_MAT_AMT          
  ,COST_MAT_AMT          
  ,EXPECTED_LIFE          
  ,FEE_MAT_TYPE          
  ,COST_MAT_TYPE          
  --,BISEGMENT          
  ,FLAG_AL          
  ,REPAY_TYPE_VALUE          
  ,WORKING_PERIOD          
  ,TENOR_TYPE          
  )          
 SELECT DISTINCT A.DATA_SOURCE          
   ,A.PRD_TYPE          
   ,A.PRD_TYPE_1          
   ,A.PRD_CODE          
   ,A.PRD_GROUP          
   ,COALESCE(B.MKT_RATE,A.MKT_INT_RATE,0)          
   ,A.CCY          
   ,A.AMORT_TYPE      
   ,CASE WHEN A.STAFF_LOAN_IND = 1          
    THEN 'Y'          
   ELSE 'N'          
   END          
   ,A.IS_IMPAIRED          
   ,A.PRD_DESC          
   ,A.ORG_FEE_MAT_AMT          
   ,A.TXN_COST_MAT_AMT          
   ,A.EXP_LIFE          
   ,A.ORG_FEE_MAT_TYPE          
   ,A.TXN_COST_MAT_TYPE          
   --,BI_SEGMENT          
   ,A.INST_CLS_VALUE          
   ,A.REPAY_TYPE_VALUE          
   ,A.WORKING_PERIOD          
   ,A.TENOR_TYPE        
 FROM IFRS_MASTER_PRODUCT_PARAM A    
  LEFT JOIN #TMP_MARKETRATE B ON (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')          
 WHERE A.INST_CLS_VALUE IN ('A', 'O') AND A.IS_DELETE = 0           
          
 INSERT INTO IFRS_AMORT_LOG (          
  DOWNLOAD_DATE          
  ,DTM          
  ,OPS          
  ,PROCNAME          
  ,REMARK          
  )          
 VALUES (          
  @V_CURRDATE          
  ,CURRENT_TIMESTAMP          
  ,'END'          
  ,'SP_IFRS_SYNC_PRODUCT_PARAM'          
  ,''          
  )          
END 
GO
