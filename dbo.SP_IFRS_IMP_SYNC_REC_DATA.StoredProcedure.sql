USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SYNC_REC_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SYNC_REC_DATA]   
@DOWNLOAD_DATE DATE = NULL         
AS         
SET NOCOUNT ON;

 DECLARE @V_CURRDATE DATE    
BEGIN   
 IF(@DOWNLOAD_DATE IS NULL)  
 BEGIN   
 SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE    
 END  
 ELSE  
 BEGIN  
 SELECT @V_CURRDATE = @DOWNLOAD_DATE  
 END

DROP TABLE IF EXISTS #TBL_REC_TBLU
DROP TABLE IF EXISTS #TBL_REC_EFS
DROP TABLE IF EXISTS #FINAL_REC_MASTER

SELECT DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME
,CUSTOMER_NUMBER,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY
,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE,PRODUCT_GROUP,PRODUCT_TYPE
,RECOVERY_DATE,SUM(RECOVERY_AMOUNT) AS RECOVERY_AMOUNT,SUM(TOTAL_RECOVERY) AS TOTAL_RECOVERY
,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT,SEGMENT_FLAG
INTO #TBL_REC_TBLU 
FROM IFRS9..IFRS_MASTER_WO_RECOVERY
WHERE DOWNLOAD_DATE = @V_CURRDATE
AND SOURCE_TABLE = 'TBLU_RECOVERY_JENIUS'
GROUP BY DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME,CUSTOMER_NUMBER
,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE
,PRODUCT_GROUP,PRODUCT_TYPE,RECOVERY_DATE,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT,SEGMENT_FLAG

SELECT DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME
,CUSTOMER_NUMBER,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY
,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE,PRODUCT_GROUP,PRODUCT_TYPE
,RECOVERY_DATE,SUM(RECOVERY_AMOUNT) AS RECOVERY_AMOUNT,SUM(TOTAL_RECOVERY) AS TOTAL_RECOVERY
,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT,SEGMENT_FLAG
INTO #TBL_REC_EFS 
FROM IFRS9..IFRS_MASTER_WO_RECOVERY
WHERE DOWNLOAD_DATE = @V_CURRDATE
AND SOURCE_TABLE = 'STG_M_RECOVERY_EFS'
GROUP BY DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME,CUSTOMER_NUMBER
,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE
,PRODUCT_GROUP,PRODUCT_TYPE,RECOVERY_DATE,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT,SEGMENT_FLAG

MERGE #TBL_REC_EFS A
 USING (
  SELECT DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME
,CUSTOMER_NUMBER,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY
,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE,PRODUCT_GROUP,PRODUCT_TYPE
,RECOVERY_DATE,RECOVERY_AMOUNT,TOTAL_RECOVERY
,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT, SEGMENT_FLAG
  FROM #TBL_REC_TBLU
 ) B ON A.MASTERID = B.MASTERID
   AND A.RECOVERY_DATE = B.RECOVERY_DATE
 WHEN MATCHED THEN
  UPDATE SET A.RECOVERY_AMOUNT = B.RECOVERY_AMOUNT
  , A.SOURCE_TABLE = B.SOURCE_TABLE
  , A.TOTAL_RECOVERY = B.TOTAL_RECOVERY
  , A.CREATEDBY = B.CREATEDBY
  , A.CREATEDDATE = B.CREATEDDATE
  WHEN NOT MATCHED BY TARGET THEN
  INSERT VALUES (DOWNLOAD_DATE,ACCOUNT_NUMBER,ACCOUNT_STATUS,BRANCH_CODE,CURRENCY,CUSTOMER_NAME
,CUSTOMER_NUMBER,DATA_SOURCE,DAY_PAST_DUE,EXCHANGE_RATE,MASTERID,BI_COLLECTABILITY
,OUTSTANDING_WO,PLAFOND,PRODUCT_CODE,PRODUCT_GROUP,PRODUCT_TYPE
,RECOVERY_DATE,RECOVERY_AMOUNT,TOTAL_RECOVERY
,SOURCE_TABLE,CREATEDBY,CREATEDDATE,CREATEDHOST,SEGMENT,SUB_SEGMENT,GROUP_SEGMENT,SEGMENT_FLAG);

SELECT * INTO #FINAL_REC_MASTER FROM #TBL_REC_EFS

DELETE FROM IFRS_MASTER_WO_RECOVERY WHERE DOWNLOAD_DATE = @V_CURRDATE AND SOURCE_TABLE IN ('TBLU_RECOVERY_JENIUS','STG_M_RECOVERY_EFS')

INSERT INTO IFRS_MASTER_WO_RECOVERY
SELECT DOWNLOAD_DATE
,ACCOUNT_NUMBER
,ACCOUNT_STATUS
,BRANCH_CODE
,CURRENCY
,CUSTOMER_NAME
,CUSTOMER_NUMBER
,DATA_SOURCE
,DAY_PAST_DUE
,EXCHANGE_RATE
,MASTERID
,BI_COLLECTABILITY
,OUTSTANDING_WO
,PLAFOND
,PRODUCT_CODE
,PRODUCT_GROUP
,PRODUCT_TYPE
,RECOVERY_DATE
,RECOVERY_AMOUNT
,TOTAL_RECOVERY
,SOURCE_TABLE
,CREATEDBY
,CREATEDDATE
,CREATEDHOST
,SEGMENT
,SUB_SEGMENT
,GROUP_SEGMENT
,SEGMENT_FLAG 
FROM #FINAL_REC_MASTER

END
GO
