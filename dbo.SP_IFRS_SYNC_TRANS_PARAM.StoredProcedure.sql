USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_TRANS_PARAM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_TRANS_PARAM]    
AS    
BEGIN    
 DECLARE @v_currdate DATE    
 DECLARE @v_prevdate DATE    
    
 SELECT @v_currdate = currdate    
  ,@v_prevdate = prevdate    
 FROM IFRS_PRC_DATE_AMORT    
    
 INSERT INTO IFRS_AMORT_LOG (    
  DOWNLOAD_DATE    
  ,DTM    
  ,OPS    
  ,PROCNAME    
  ,REMARK    
  )    
 VALUES (    
  @v_currdate    
  ,CURRENT_TIMESTAMP    
  ,'START'    
  ,'SP_IFRS_SYNC_TRANSACTION_PARAM'    
  ,''    
  )    
    
 TRUNCATE TABLE IFRS_TRANSACTION_PARAM    
    
 INSERT INTO IFRS_AMORT_LOG (    
  DOWNLOAD_DATE    
  ,DTM    
  ,OPS    
  ,PROCNAME    
  ,REMARK    
  )    
 VALUES (    
  @v_currdate    
  ,CURRENT_TIMESTAMP    
  ,'DEBUG'    
  ,'SP_IFRS_SYNC_TRANSACTION_PARAM'    
  ,'INSERT TRANS PARAM'    
  )    
     
 INSERT INTO IFRS_TRANSACTION_PARAM (    
  DATA_SOURCE    
  ,PRD_TYPE    
  ,PRD_CODE    
  ,TRX_CODE    
  ,CCY    
  ,IFRS_TXN_CLASS    
  ,AMORTIZATION_FLAG    
  ,AMORT_TYPE    
  ,GL_CODE    
  ,TENOR_TYPE    
  ,TENOR_AMORTIZATION    
  ,SL_EXP_LIFE    
  ,FEE_MAT_TYPE    
  ,FEE_MAT_AMT    
  ,COST_MAT_TYPE    
  ,COST_MAT_AMT    
 )    
 SELECT DATA_SOURCE    
   ,PRD_TYPE    
   ,PRD_CODE    
   ,TRX_CODE    
   ,CCY    
   ,IFRS_TXN_CLASS    
   , CASE     
    WHEN AMORTIZATION_FLAG = 1 THEN 'Y'    
    ELSE 'N' END AMORTIZATION_FLAG    
   ,AMORT_TYPE    
   ,GL_CODE    
   ,TENOR_TYPE    
   ,TENOR_AMORTIZATION    
   ,SL_EXP_LIFE    
   ,org_fee_mat_type    
   ,org_fee_mat_amt    
   ,txn_cost_mat_type    
   ,txn_cost_mat_amt    
 FROM IFRS_MASTER_TRANS_PARAM    
 WHERE INST_CLS_VALUE IN ('A', 'O') AND IS_DELETE = 0    
    
 INSERT INTO IFRS_AMORT_LOG (    
  DOWNLOAD_DATE    
  ,DTM    
  ,OPS    
  ,PROCNAME    
  ,REMARK    
  )    
 VALUES (    
  @v_currdate    
  ,CURRENT_TIMESTAMP    
  ,'END'    
  ,'SP_IFRS_SYNC_TRANSACTION_PARAM'    
  ,''    
  )    
END 
GO
