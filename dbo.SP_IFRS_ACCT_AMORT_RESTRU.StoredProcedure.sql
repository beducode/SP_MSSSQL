USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_AMORT_RESTRU]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SP_IFRS_ACCT_AMORT_RESTRU]  
AS   
BEGIN  
DECLARE @V_CURRDATE DATE          
 ,@V_PREVDATE DATE          
          
        
 SELECT @V_CURRDATE = MAX(CURRDATE)          
  ,@V_PREVDATE = MAX(PREVDATE)          
 FROM IFRS_PRC_DATE_AMORT         
  
  
  INSERT  INTO IFRS_AMORT_LOG                      
                    ( DOWNLOAD_DATE,                      
                      DTM,                      
                      OPS,                      
                      PROCNAME,                      
                      REMARK                      
                    )                      
            VALUES  ( @v_currdate,                      
                      CURRENT_TIMESTAMP,                      
                      'START',                      
                      'SP_IFRS_ACCT_AMORT_RESTRU',                      
                      ''                      
                    )      
      
  
  DELETE FROM IFRS_ACCT_AMORT_RESTRU WHERE DOWNLOAD_DATE = @V_CURRDATE  
 ------ ---- INSERT RESTRU IN BTPN ------------  
 INSERT INTO IFRS_ACCT_AMORT_RESTRU (DOWNLOAD_DATE  
,DATA_SOURCE  
,MASTERID  
,PREV_MASTERID  
,ACCOUNT_NUMBER  
,PREV_ACCOUNT_NUMBER 
,RESTRUCTURE_DATE  
,PRODUCT_CODE  
,PRODUCT_TYPE  
,PRODUCT_GROUP  
,BRANCH_CODE  
,PREV_BRANCH_CODE  
,CIFNO  
,CCY  
,EIR  
,PREV_EIR  
,METHOD  
,OUTSTANDING
,PREV_UNAMORT_FEE_AMT  
,PREV_UNAMORT_COST_AMT  
,UNAMORT_FEE_AMT  
,UNAMORT_COST_AMT  
,ADJ_VALUE)  
 SELECT A.DOWNLOAD_DATE  
,A.DATA_SOURCE  
,A.MASTERID  
,A.PREVIOUS_ACCOUNT_NUMBER AS PREV_MASTERID  
,A.ACCOUNT_NUMBER AS ACCOUNT_NUMBER  
,B.ACCOUNT_NUMBER AS PREV_ACCOUNT_NUMBER
,A.RESTRUCTURE_DATE  
,A.PRODUCT_CODE  
,A.PRODUCT_TYPE  
,A.PRODUCT_GROUP  
,A.BRANCH_CODE  
,B.BRANCH_CODE AS PREV_BRANCH_CODE  
,A.CUSTOMER_NUMBER AS CIFNO  
,A.CURRENCY AS CCY  
,A.EIR  
,B.EIR AS PREV_EIR  
,A.AMORT_TYPE  AS METHOD 
,A.OUTSTANDING 
,B.UNAMORT_FEE_AMT AS PREV_UNAMORT_FEE_AMT  
,B.UNAMORT_COST_AMT AS PREV_UNAMORT_COST_AMT  
,A.UNAMORT_FEE_AMT  
,A.UNAMORT_COST_AMT  
,0 AS ADJ_VALUE    
  FROM IFRS_IMA_AMORT_CURR A          
 JOIN IFRS_IMA_AMORT_PREV B ON A.PREVIOUS_ACCOUNT_NUMBER = B.MASTERID AND A.RESTRUCTURE_DATE = @V_CURRDATE  
 AND A.CURRENCY = B.CURRENCY -- MAKE SURE SAME CURRENC8Y    
  
  IF OBJECT_ID ('TEMPDB.DBO.#RESTRU_PREV') IS NOT NULL DROP TABLE #RESTRU_PREV
  SELECT  PREV_MASTERID, SUM(OUTSTANDING) AS TOTAL_OS,
  COUNT(1) AS CNT
   INTO   #RESTRU_PREV
  FROM IFRS_ACCT_AMORT_RESTRU WHERE DOWNLOAD_DATE = @V_CURRDATE GROUP BY PREV_MASTERID

  UPDATE A
  SET A.CNT = B.CNT
  ,A.PRORATE_UNAMORT_FEE = CASE WHEN ISNULL(B.TOTAL_OS,0) = 0 THEN A.PREV_UNAMORT_FEE_AMT/B.CNT ELSE A.PREV_UNAMORT_FEE_AMT*(CAST(A.OUTSTANDING AS FLOAT)/CAST(B.TOTAL_OS AS FLOAT)) END 
  ,A.PRORATE_UNAMORT_COST =  CASE WHEN ISNULL(B.TOTAL_OS,0) = 0 THEN A.PREV_UNAMORT_COST_AMT/B.CNT ELSE A.PREV_UNAMORT_COST_AMT*(CAST(A.OUTSTANDING AS FLOAT)/CAST(B.TOTAL_OS AS FLOAT)) END 
  FROM IFRS_ACCT_AMORT_RESTRU A
  INNER JOIN #RESTRU_PREV B ON A.PREV_MASTERID = B.PREV_MASTERID 
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE
  

 INSERT  INTO IFRS_AMORT_LOG                      
                    ( DOWNLOAD_DATE,                      
                      DTM,                      
                      OPS,                      
                      PROCNAME,                      
                      REMARK                      
                    )                      
            VALUES  ( @v_currdate,                      
                      CURRENT_TIMESTAMP,                      
                      'END',                      
                      'SP_IFRS_ACCT_AMORT_RESTRU',                      
                      ''                      
                    )                          
  
END 
GO
