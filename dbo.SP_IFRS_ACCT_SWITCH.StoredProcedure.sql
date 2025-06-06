USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_SWITCH]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_SWITCH]            
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
  ,'SP_IFRS_ACCT_SWITCH'            
  ,''            
  )            
            
 --DELETE FIRST            
 DELETE            
 FROM IFRS_ACCT_SWITCH            
 WHERE DOWNLOAD_DATE >= @V_CURRDATE            
            
 --CHANGE BRANCH            
 INSERT INTO IFRS_ACCT_SWITCH (            
  DOWNLOAD_DATE            
  ,DATASOURCE            
  ,MASTERID            
  ,FACNO            
  ,CIFNO            
  ,ACCTNO            
  ,PREV_ACCTNO            
  ,PREV_MASTERID            
  ,CREATEDBY            
  ,CREATEDDATE            
  ,PREV_SL_ECF            
  ,PREV_EIR_ECF            
  ,PRDCODE            
  ,BRCODE            
  ,PRDTYPE            
  ,PREV_DATASOURCE            
  ,PREV_FACNO            
  ,PREV_CIFNO            
  ,PREV_BRCODE            
  ,PREV_PRDTYPE            
  ,PREV_PRDCODE            
  ,CCY            
  ,LOAN_AMT            
  ,PLAFOND        
  ,REMARKS        
  )            
 SELECT @V_CURRDATE            
  ,A.DATA_SOURCE            
  ,A.MASTERID            
  ,A.FACILITY_NUMBER            
  ,A.CUSTOMER_NUMBER            
  ,A.ACCOUNT_NUMBER            
  ,B.ACCOUNT_NUMBER            
  ,B.MASTERID            
  ,'SP_IFRS_ACCT_SWITCH'            
  ,CURRENT_TIMESTAMP            
  ,'N'            
  ,'N'            
  ,A.PRODUCT_CODE            
  ,A.BRANCH_CODE            
  ,A.PRODUCT_TYPE            
  ,B.DATA_SOURCE            
  ,B.FACILITY_NUMBER            
  ,B.CUSTOMER_NUMBER            
  ,B.BRANCH_CODE            
  ,B.PRODUCT_TYPE            
  ,B.PRODUCT_CODE            
  ,A.CURRENCY            
  ,A.LOAN_AMT            
  ,A.PLAFOND        
  , 'CHANGE_BRANCH' AS REMARKS         -- ADDED BTPN    
 FROM IFRS_IMA_AMORT_CURR A            
 JOIN IFRS_IMA_AMORT_PREV B ON A.MASTERID = B.MASTERID            
  AND A.CURRENCY = B.CURRENCY -- MAKE SURE SAME CURRENCY            
 WHERE A.BRANCH_CODE <> B.BRANCH_CODE            
  AND B.MASTERID NOT IN (            
   SELECT DISTINCT MASTERID            
   FROM IFRS_ACCT_SWITCH            
   WHERE DOWNLOAD_DATE = @V_CURRDATE            
   )        
   AND A.MASTERID NOT IN (SELECT MASTERID FROM IFRS_ACCT_CLOSED WHERE DOWNLOAD_DATE = @V_CURRDATE)            
        
 -- NEW ACCOUNT METHOD OF AMORTZ            
 UPDATE IFRS_ACCT_SWITCH            
 SET METHOD = B.AMORT_TYPE            
 FROM (            
  SELECT X.*            
   ,Y.*            
  FROM IFRS_PRODUCT_PARAM X            
  CROSS JOIN IFRS_PRC_DATE_AMORT Y            
  ) B            
 WHERE B.PRD_CODE = IFRS_ACCT_SWITCH.PRDCODE            
  AND B.DATA_SOURCE = IFRS_ACCT_SWITCH.DATASOURCE            
  AND B.PRD_TYPE = IFRS_ACCT_SWITCH.PRDTYPE            
  AND (IFRS_ACCT_SWITCH.CCY = B.CCY OR B.CCY = 'ALL')          
  AND IFRS_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE            
        
        
--ADD LBM SWITCH 20180823          
DELETE IFRS_LBM_ACCT_SWITCH WHERE DOWNLOAD_DATE >= @V_CURRDATE            
          
INSERT INTO IFRS_LBM_ACCT_SWITCH (          
ID,          
DOWNLOAD_DATE,          
FACNO,          
CIFNO,          
ACCTNO,          
BRCODE,          
PRDTYPE,          
PRDCODE,          
DATASOURCE,          
MASTERID,          
PREV_ACCTNO,          
PREV_FACNO,          
PREV_CIFNO,          
PREV_BRCODE,          
PREV_PRDTYPE,          
PREV_PRDCODE,          
PREV_DATASOURCE,          
PREV_MASTERID,          
PREV_SL_ECF,          
PREV_EIR_ECF,          
METHOD,          
CCY,          
LOAN_AMT,          
PLAFOND,          
SW_ADJ_FEE,          
SW_ADJ_COST,          
CREATEDDATE,    
CREATEDBY          
)          
SELECT ID,          
DOWNLOAD_DATE,          
FACNO,          
CIFNO,          
ACCTNO,          
BRCODE,          
PRDTYPE,          
PRDCODE,          
DATASOURCE,          
MASTERID,          
PREV_ACCTNO,          
PREV_FACNO,          
PREV_CIFNO,          
PREV_BRCODE,          
PREV_PRDTYPE,          
PREV_PRDCODE,          
PREV_DATASOURCE,          
PREV_MASTERID,          
PREV_SL_ECF,          
PREV_EIR_ECF,          
METHOD,          
CCY,          
LOAN_AMT,          
PLAFOND,          
SW_ADJ_FEE,          
SW_ADJ_COST,          
CREATEDDATE,          
CREATEDBY          
FROM IFRS_ACCT_SWITCH (NOLOCK)          
WHERE DOWNLOAD_DATE = @V_CURRDATE          
--END ADD LBM SWITCH 20180823        
            
 --DETECT SL ECF NON LBM        
 UPDATE IFRS_ACCT_SWITCH            
 SET PREV_SL_ECF = 'Y'            
 FROM (            
  SELECT B.MASTERID            
   ,C.CURRDATE            
  FROM IFRS_ACCT_SL_ECF B            
  CROSS JOIN IFRS_PRC_DATE_AMORT C            
  WHERE ISNULL(B.AMORTSTOPDATE, '') = ''            
   AND B.PREVDATE = B.PMTDATE            
  ) B            
 WHERE B.MASTERID = IFRS_ACCT_SWITCH.PREV_MASTERID            
  AND IFRS_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE      
    
            
 --DETECT EIR ECF NON LBM            
 UPDATE IFRS_ACCT_SWITCH            
 SET PREV_EIR_ECF = 'Y'            
 FROM (            
  SELECT B.MASTERID            
   ,C.CURRDATE            
  FROM IFRS_ACCT_EIR_ECF B            
  CROSS JOIN IFRS_PRC_DATE_AMORT C            
  WHERE ISNULL(B.AMORTSTOPDATE, '') = ''            
   AND B.PREV_PMT_DATE = B.PMT_DATE            
  ) B            
 WHERE B.MASTERID = IFRS_ACCT_SWITCH.PREV_MASTERID            
  AND IFRS_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE    
  AND REMARKS = 'CHANGE_BRANCH'       -- BTPN     
            
/*20180828*/        
         
 --DETECT EIR ECF LBM            
 UPDATE IFRS_LBM_ACCT_SWITCH            
 SET PREV_EIR_ECF = 'Y'            
 FROM (            
  SELECT B.MASTERID            
   ,C.CURRDATE            
  FROM IFRS_LBM_ACCT_EIR_ECF B            
  CROSS JOIN IFRS_PRC_DATE_AMORT C            
  WHERE ISNULL(B.AMORTSTOPDATE, '') = ''            
   AND B.PREV_PMT_DATE = B.PMT_DATE            
  ) B            
 WHERE B.MASTERID = IFRS_LBM_ACCT_SWITCH.PREV_MASTERID            
  AND IFRS_LBM_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE            
        
/*End add 20180828*/               
            
 -- NON LBM CANCEL IF METHOD NOT THE SAME            
 UPDATE IFRS_ACCT_SWITCH            
 SET PREV_SL_ECF = 'X'            
  ,PREV_EIR_ECF = 'X'            
  ,CREATEDBY = 'DIFF_METHOD'            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND (            
   (            
    PREV_SL_ECF = 'Y'            
    AND METHOD = 'EIR'            
    )            
   OR (            
    PREV_EIR_ECF = 'Y'            
    AND METHOD = 'SL'            
    )            
   )            
         
  -- LBM CANCEL IF METHOD NOT THE SAME            
 UPDATE IFRS_LBM_ACCT_SWITCH            
 SET PREV_SL_ECF = 'X'            
  ,PREV_EIR_ECF = 'X'            
  ,CREATEDBY = 'DIFF_METHOD'            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND (            
   (            
    PREV_SL_ECF = 'Y'            
    AND METHOD = 'EIR'            
    )            
   OR (            
    PREV_EIR_ECF = 'Y'            
    AND METHOD = 'SL'            
    )            
   )          
        
            
 -- CANCEL IF NEW ACCT ALREADY HAVE SL ECF             
 UPDATE IFRS_ACCT_SWITCH            
 SET PREV_SL_ECF = 'X'            
  ,PREV_EIR_ECF = 'X'            
  ,CREATEDBY = 'SL_ECF_EXIST'         
 FROM (            
  SELECT B.MASTERID            
   ,C.CURRDATE            
  FROM IFRS_ACCT_SL_ECF B            
  CROSS JOIN IFRS_PRC_DATE_AMORT C            
  WHERE ISNULL(B.AMORTSTOPDATE, '') = ''            
   AND B.PREVDATE = B.PMTDATE            
  ) B            
 WHERE B.MASTERID = IFRS_ACCT_SWITCH.MASTERID            
  AND IFRS_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE            
  AND IFRS_ACCT_SWITCH.MASTERID <> IFRS_ACCT_SWITCH.PREV_MASTERID            
            
 -- CANCEL IF NEW ACCT ALREADY HAVE EIR ECF            
 UPDATE IFRS_ACCT_SWITCH            
 SET PREV_SL_ECF = 'X'            
  ,PREV_EIR_ECF = 'X'            
  ,CREATEDBY = 'EIR_ECF_EXIST'            
 FROM (            
  SELECT B.MASTERID            
   ,C.CURRDATE            
  FROM IFRS_ACCT_EIR_ECF B            
  CROSS JOIN IFRS_PRC_DATE_AMORT C            
  WHERE ISNULL(B.AMORTSTOPDATE, '') = ''            
   AND B.PREV_PMT_DATE = B.PMT_DATE            
  ) B            
 WHERE B.MASTERID = IFRS_ACCT_SWITCH.MASTERID            
  AND IFRS_ACCT_SWITCH.DOWNLOAD_DATE = B.CURRDATE            
  AND IFRS_ACCT_SWITCH.MASTERID <> IFRS_ACCT_SWITCH.PREV_MASTERID            
            
 -- UPDATE COST FEE SUMM TO NEW SWITCH ACCT NO            
 UPDATE IFRS_ACCT_COST_FEE_SUMM            
 SET SW_MASTERID = B.MASTERID            
  ,BRCODE = B.BRCODE            
  ,CIFNO = B.CIFNO            
  ,FACNO = B.FACNO            
  ,ACCTNO = B.ACCTNO            
  ,DATASOURCE = B.DATASOURCE            
 FROM (            
  SELECT B.*            
  FROM IFRS_ACCT_SWITCH B            
  JOIN IFRS_PRC_DATE_AMORT C ON C.CURRDATE = B.DOWNLOAD_DATE            
  WHERE B.PREV_SL_ECF = 'Y'            
   OR B.PREV_EIR_ECF = 'Y'            
  ) B            
 WHERE IFRS_ACCT_COST_FEE_SUMM.MASTERID = B.PREV_MASTERID            
  AND IFRS_ACCT_COST_FEE_SUMM.DOWNLOAD_DATE = B.DOWNLOAD_DATE            
            
 UPDATE IFRS_ACCT_COST_FEE_SUMM            
 SET MASTERID = SW_MASTERID            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND SW_MASTERID IN (            
   SELECT MASTERID            
   FROM IFRS_ACCT_SWITCH            
   WHERE DOWNLOAD_DATE = @V_CURRDATE            
   )            
        
          
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
  ,'SP_IFRS_ACCT_SWITCH'            
  ,''            
  )            
END 
GO
