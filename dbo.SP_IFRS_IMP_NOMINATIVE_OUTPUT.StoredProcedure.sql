USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_NOMINATIVE_OUTPUT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[SP_IFRS_IMP_NOMINATIVE_OUTPUT]          
@DOWNLOAD_DATE DATE = NULL          
AS          
    DECLARE @V_CURRDATE DATE          
    DECLARE @V_PREVDATE DATE          
BEGIN          
    IF @DOWNLOAD_DATE IS NULL          
    BEGIN          
        SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE          
    END          
    ELSE          
    BEGIN          
        SET @V_CURRDATE = @DOWNLOAD_DATE          
    END          
    SET @V_PREVDATE = DATEADD(DD, -1, @V_CURRDATE)          
    
    
    TRUNCATE TABLE STG_PSAK71      
          
    INSERT INTO STG_PSAK71       
    (          
        BUSS_DATE          
        ,CIF          
        ,COMMITMENT_REFERENCE          
        ,DEAL_REF          
        ,CUSTOMER_FULL_NAME          
        ,BRANCH          
        ,DEAL_TYPE          
        ,CCY          
        ,OUTSTANDING_ORI          
        ,OUTSTANDING_LEV          
        ,INITIAL_FEE          
        ,INITIAL_COST          
        ,UNAMORT_FEE_ORI          
        ,UNAMORT_FEE_LEV          
        ,UNAMORT_COST_ORI          
        ,UNAMORT_COST_LEV          
        ,FAIR_VALUE_ORI          
        ,FAIR_VALUE_LEV          
        ,INT_RATE          
        ,EIR_RATE          
        ,EXCHANGE_RATE          
        ,COLLECT          
        ,CKPN_TYPE          
        ,CKPN_ORI          
        ,CKPN_LEV          
        ,UNWINDING_ORI          
        ,UNWINDING_LEV          
        ,STAFF_LOAN_FLAG          
        ,IFRS9_CLASS          
        ,SEGMENTATION          
        ,IFRS_STAGE          
        ,DEFAULT_FLAG          
        ,SOURCE_SYSTEM       
        ,PRODUCT_TYPE       
        ,PLAFOND        
        ,UNUSED_AMOUNT    
        ,BUCKET_NAME    
        ,DPD_FINAL  
  ,CKPN_ORI_NET  
  ,CKPN_LEV_NET        
    )          
    SELECT          
        DOWNLOAD_DATE AS BUSS_DATE          
        ,CUSTOMER_NUMBER AS CIF          
        ,FACILITY_NUMBER AS COMMITMENT_REFERENCE          
        ,ACCOUNT_NUMBER AS DEAL_REF          
        ,CUSTOMER_NAME AS CUSTOMER_FULL_NAME          
        ,BRANCH_CODE AS BRANCH          
        ,PRODUCT_CODE AS DEAL_TYPE          
        ,CURRENCY AS CCY          
        ,ISNULL(OUTSTANDING,0) AS OUTSTANDING_ORI          
        ,ISNULL(OUTSTANDING,0) * ISNULL(EXCHANGE_RATE, 1) AS OUTSTANDING_LEV          
        ,ISNULL(INITIAL_UNAMORT_ORG_FEE,0) AS  INITIAL_FEE          
        ,ISNULL(INITIAL_UNAMORT_TXN_COST,0) AS INITIAL_COST          
        ,ISNULL(UNAMORT_FEE_AMT,0) AS UNAMORT_FEE_ORI          
        ,ISNULL(UNAMORT_FEE_AMT,0) * ISNULL(EXCHANGE_RATE, 1) AS UNAMORT_FEE_LEV          
        ,ISNULL(UNAMORT_COST_AMT,0) AS UNAMORT_COST_ORI          
        ,ISNULL(UNAMORT_COST_AMT,0) * ISNULL(EXCHANGE_RATE, 1) AS UNAMORT_COST_LEV          
        ,ISNULL(FAIR_VALUE_AMOUNT,0) AS FAIR_VALUE_ORI          
        ,ISNULL(FAIR_VALUE_AMOUNT,0) * ISNULL(EXCHANGE_RATE, 1) AS FAIR_VALUE_LEV          
        ,INTEREST_RATE AS INT_RATE          
        ,EIR AS EIR_RATE          
        ,ISNULL(EXCHANGE_RATE, 1) AS EXCHANGE_RATE          
        ,BI_COLLECTABILITY AS COLLECT          
        ,IMPAIRED_FLAG AS CKPN_TYPE          
        ,ISNULL(ECL_AMOUNT,0) AS CKPN_ORI          
        ,ISNULL(ECL_AMOUNT,0) * ISNULL(EXCHANGE_RATE, 1) AS CKPN_LEV          
        ,ISNULL(IA_UNWINDING_AMOUNT,0)  AS UNWINDING_ORI          
        ,ISNULL(IA_UNWINDING_AMOUNT,0)  * ISNULL(EXCHANGE_RATE, 1) AS UNWINDING_LEV          
        ,ISNULL(STAFF_LOAN_FLAG,0)          
        ,IFRS9_CLASS          
        ,SUB_SEGMENT AS SEGMENTATION          
        ,STAGE AS IFRS_STAGE          
        ,DEFAULT_FLAG          
        ,SOURCE_SYSTEM        
        ,PRODUCT_TYPE_1 AS PRODUCT_TYPE       
        ,ISNULL(PLAFOND,0)        
        ,ISNULL(UNUSED_AMOUNT,0)    
        ,BUCKET_NAME    
        ,DPD_FINAL   
  ,ISNULL(ECL_AMOUNT,0)  - ISNULL(IA_UNWINDING_AMOUNT,0)  AS CKPN_ORI_NET  
  ,(ISNULL(ECL_AMOUNT,0)*ISNULL(EXCHANGE_RATE, 1) ) - (ISNULL(IA_UNWINDING_AMOUNT,0)*ISNULL(EXCHANGE_RATE, 1)) AS  CKPN_LEV_NET               
    FROM IFRS_MASTER_ACCOUNT_MONTHLY A (NOLOCK)    
    LEFT JOIN (SELECT  BUCKET_GROUP,BUCKET_ID, MAX(BUCKET_NAME) AS  BUCKET_NAME FROM IFRS_BUCKET_DETAIL WHERE IS_DELETE = 0 GROUP BY BUCKET_GROUP,BUCKET_ID ) B     
    ON A.BUCKET_GROUP = B.BUCKET_GROUP AND A.BUCKET_ID = B.BUCKET_ID    
    WHERE DOWNLOAD_DATE = @V_CURRDATE          
  /*
 22-06-2022
 NEW STORED PROCEDURE TO RUN LIAB 
 */
 EXEC [SP_IFRS_IMP_NOMINATIVE_OUTPUT_SYNC_LIAB] @DOWNLOAD_DATE

 -- INSERT FLAG OUTBOUND FOR TRIGEER AUTO ETL TO EDW    
 DELETE IFRS_OUTBOUND_FLAG WHERE TABLE_NAME = 'STG_PSAK71'    
    
 INSERT INTO IFRS_OUTBOUND_FLAG     
 (DOWNLOAD_DATE    
 ,TABLE_NAME    
 ,FINISHED_FLAG    
 ,CREATED_DATE)    
 VALUES (@V_CURRDATE,'STG_PSAK71',1,GETDATE())    
 --END INSERT FLAG OUTBOUND FOR TRIGEER AUTO ETL TO EDW    
          
END
GO
