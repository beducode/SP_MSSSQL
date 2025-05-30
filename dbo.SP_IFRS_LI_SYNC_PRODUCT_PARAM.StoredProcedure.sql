USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_SYNC_PRODUCT_PARAM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_SYNC_PRODUCT_PARAM]     
AS     
DECLARE @V_CURRDATE DATE     
 ,@V_PREVDATE DATE     
     
BEGIN     
 SELECT @V_CURRDATE = MAX(CURRDATE)     
    ,@V_PREVDATE = MAX(PREVDATE)     
 FROM IFRS_LI_PRC_DATE_AMORT     
     
 INSERT INTO IFRS_LI_AMORT_LOG (     
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
  ,'SP_IFRS_LI_SYNC_PRODUCT_PARAM'     
  ,'START'     
  )     
     
 --  PRE-PROCESS EXTRACT CURRENCY ALL AND SYNC SEGMENT         
 -- EXEC SP_EXTRACT_ALL_CCY_PARAM         
 --  EXEC SP_SYNC_MASTER_SEGMENT BCAF NO NEED         
 --  END PRE-PROCESS EXTRACT CURRENCY ALL AND SYNC SEGMENT    
 TRUNCATE TABLE IFRS_LI_PRODUCT_PARAM     
         
 INSERT INTO IFRS_LI_PRODUCT_PARAM (     
  DATA_SOURCE     
  ,PRD_TYPE     
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
  ,LIABILITES_CLASSIFICATION     
  )     
 SELECT DISTINCT DATA_SOURCE     
   ,PRD_TYPE     
   ,PRD_CODE     
   ,PRD_GROUP     
   ,MKT_INT_RATE     
   ,CCY     
   ,AMORT_TYPE     
   ,CASE WHEN STAFF_LOAN_IND = 1     
    THEN 'Y'     
   ELSE 'N'     
   END     
   ,IS_IMPAIRED     
   ,PRD_DESC     
   ,ORG_FEE_MAT_AMT     
   ,TXN_COST_MAT_AMT     
   ,EXP_LIFE     
   ,ORG_FEE_MAT_TYPE     
   ,TXN_COST_MAT_TYPE    
   --,BISEGMENT     
   ,INST_CLS_VALUE     
   ,LIABILITES_CLASSIFICATION    
 FROM IFRS_MASTER_PRODUCT_PARAM     
 WHERE INST_CLS_VALUE = 'L' AND IS_DELETE = 0     
     
 INSERT INTO IFRS_LI_AMORT_LOG (     
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
  ,'SP_IFRS_LI_SYNC_PRODUCT_PARAM'     
  ,'END'     
  )     
END 
GO
