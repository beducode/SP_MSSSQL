USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SYNC_WO_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SYNC_WO_DATA]   
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

DROP TABLE IF EXISTS #TBL_WO_TBLU
DROP TABLE IF EXISTS #TBL_WO_EFS
DROP TABLE IF EXISTS #DIFF_WO_TBLU
DROP TABLE IF EXISTS #DIFF_WO_EFS
DROP TABLE IF EXISTS #UPDATE_WO_TBLU_EFS
DROP TABLE IF EXISTS #FINAL_WO_MASTER

SELECT * 
INTO #TBL_WO_TBLU 
FROM IFRS9..IFRS_MASTER_WO
WHERE DOWNLOAD_DATE = @V_CURRDATE
AND SOURCE_TABLE = 'TBLU_WO_JENIUS'

SELECT * 
INTO #TBL_WO_EFS 
FROM IFRS9..IFRS_MASTER_WO
WHERE DOWNLOAD_DATE = @V_CURRDATE
AND SOURCE_TABLE = 'STG_M_WO_EFS'

--- APPEND DATA FROM TBLU TO EFS
SELECT A.* 
INTO #DIFF_WO_TBLU
FROM #TBL_WO_EFS A
    LEFT JOIN #TBL_WO_TBLU B ON (A.MASTERID = B.MASTERID)
WHERE B.MASTERID IS NULL

SELECT A.* 
INTO #DIFF_WO_EFS
FROM #TBL_WO_TBLU A
    LEFT JOIN #TBL_WO_EFS B ON (A.MASTERID = B.MASTERID)
WHERE B.MASTERID IS NULL

SELECT B.* 
INTO #UPDATE_WO_TBLU_EFS
FROM #TBL_WO_EFS A
INNER JOIN #TBL_WO_TBLU B ON (A.MASTERID = B.MASTERID)

SELECT * INTO #FINAL_WO_MASTER
FROM (
SELECT * FROM #DIFF_WO_TBLU
UNION ALL
SELECT * FROM #DIFF_WO_EFS
UNION ALL
SELECT * FROM #UPDATE_WO_TBLU_EFS) FINAL

DELETE FROM IFRS_MASTER_WO WHERE DOWNLOAD_DATE = @V_CURRDATE AND SOURCE_TABLE IN ('TBLU_WO_JENIUS','STG_M_WO_EFS')

INSERT INTO IFRS_MASTER_WO    
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
,LOAN_DUE_DATE
,LOAN_START_DATE
,MASTERID
,BI_COLLECTABILITY
,OUTSTANDING_WO
,PLAFOND
,PRODUCT_CODE
,PRODUCT_GROUP
,PRODUCT_TYPE
,TENOR
,WRITEOFF_DATE
,WRITEOFF_FLAG
,SOURCE_TABLE
,PRODUCT_ENTITY
,SUFFIX
,NPL_FLAG
,CO_FLAG
,CREATEDBY
,GETDATE()  AS CREATEDDATE
,SEGMENT
,SUB_SEGMENT
,GROUP_SEGMENT 
,SEGMENT_FLAG FROM #FINAL_WO_MASTER

END
GO
