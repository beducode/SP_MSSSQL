USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_SL_ACF_ACCRU]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_SL_ACF_ACCRU]      
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
  ,'SP_IFRS_ACCT_SL_ACF_ACCRU'      
  ,''      
  )      
      
 DELETE      
 FROM IFRS_ACCT_SL_ACF      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
  AND DO_AMORT = 'N'      
      
 DELETE      
 FROM IFRS_ACCT_SL_COST_FEE_PREV      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
  AND CREATEDBY = 'SLACF02'      
      
 -- INSERT ACF      
 INSERT INTO IFRS_ACCT_SL_ACF (      
  DOWNLOAD_DATE      
  ,FACNO      
  ,CIFNO      
  ,DATASOURCE      
  ,N_UNAMORT_COST      
  ,N_UNAMORT_FEE      
  ,N_AMORT_COST      
  ,N_AMORT_FEE      
  ,N_ACCRU_COST      
  ,N_ACCRU_FEE      
  ,N_ACCRUFULL_COST      
  ,N_ACCRUFULL_FEE      
  ,ECFDATE      
  ,CREATEDDATE      
  ,CREATEDBY      
  ,MASTERID      
  ,ACCTNO      
  ,DO_AMORT      
  ,BRANCH      
  ,ACF_CODE      
  ,FLAG_AL    
  )      
 SELECT @V_CURRDATE AS DOWNLOAD_DATE      
  ,M.FACILITY_NUMBER      
  ,M.CUSTOMER_NUMBER      
  ,M.DATA_SOURCE      
  ,CASE       
   WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
    THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
   ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
    * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
   END + A.UNAMORT_COST_PREV      
  ,CASE       
   WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
    THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
   ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
    * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
   END + A.UNAMORT_FEE_PREV      
  ,(C.N_UNAMORT_COST) /*( A.N_UNAMORT_COST + A.N_AMORT_COST )*/      
  - (      
   CASE       
    WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) -- AS NUMERIC(32, 6))      
     / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
     THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
    ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
     / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
     * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
    END + A.UNAMORT_COST_PREV      
   )      
  ,(C.N_UNAMORT_FEE) /*( A.N_UNAMORT_FEE + A.N_AMORT_FEE )*/      
  - (      
   CASE       
    WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
     / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
     THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
    ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32, 6))      
     / CAST(A.I_DAYSCNT AS NUMERIC(32, 6)) * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
    END + A.UNAMORT_FEE_PREV      
   )      
  ,CASE       
   WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
    THEN (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
   ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
    * (A.N_UNAMORT_COST - A.UNAMORT_COST_PREV)      
   END - ISNULL(A.SW_ADJ_COST, 0)      
  ,CASE       
   WHEN CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) > 1 --AS NUMERIC(32, 6)) > 1      
    THEN (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
   ELSE CAST((DATEDIFF(DD, A.PREVDATE, @V_CURRDATE) + 1) AS FLOAT) --AS NUMERIC(32,6))      
    / CAST(A.I_DAYSCNT AS FLOAT) --AS NUMERIC(32, 6))      
    * (A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV)      
   END - ISNULL(A.SW_ADJ_FEE, 0)      
  ,A.N_UNAMORT_COST - A.UNAMORT_COST_PREV - ISNULL(A.SW_ADJ_COST, 0) AS [N_ACCRUFULL_COST]      
  ,A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV - ISNULL(A.SW_ADJ_FEE, 0) AS [N_ACCRUFULL_FEE]      
  ,A.DOWNLOAD_DATE      
  ,CURRENT_TIMESTAMP      
  ,'SP_ACCT_SL_ACF_ACCRU 1'      
  ,M.MASTERID      
  ,M.ACCOUNT_NUMBER      
  ,'N' DO_AMORT      
  ,M.BRANCH_CODE      
  ,'2' ACFCODE    
  ,M.FLAG_AL      
 FROM IFRS_ACCT_SL_ECF A      
 JOIN (      
  SELECT M.MASTERID      
   ,M.ACCOUNT_NUMBER      
   ,M.BRANCH_CODE      
   ,M.FACILITY_NUMBER      
   ,M.CUSTOMER_NUMBER      
   ,M.DATA_SOURCE      
   ,M.IAS_CLASS AS FLAG_AL    
  FROM IFRS_IMA_AMORT_CURR M      
  LEFT JOIN (      
   SELECT DISTINCT MASTERID      
    ,DOWNLOAD_DATE      
   FROM IFRS_ACCT_CLOSED      
   WHERE DOWNLOAD_DATE = @V_CURRDATE      
   ) D ON M.DOWNLOAD_DATE = D.DOWNLOAD_DATE      
   AND M.MASTERID = D.MASTERID      
  WHERE M.DOWNLOAD_DATE = @V_CURRDATE      
   AND D.MASTERID IS NULL      
  ) M ON A.MASTERID = M.MASTERID      
 /*ADDING TO FIXING N_AMORT_AMOUNT 20160504*/      
 JOIN IFRS_ACCT_SL_ECF C ON C.AMORTSTOPDATE IS NULL      
  AND C.MASTERID = A.MASTERID      
  AND C.PMTDATE = C.PREVDATE      
 WHERE A.PMTDATE <> A.PREVDATE      
  AND A.PMTDATE > @V_CURRDATE      
  AND A.PREVDATE <= @V_CURRDATE      
  AND A.AMORTSTOPDATE IS NULL      
      
 /* REMARKS.. TUNNING SCRIPT 20160602      
            FROM    IFRS_IMA_AMORT_CURR M      
                    JOIN IFRS_ACCT_SL_ECF A ON A.AMORTSTOPDATE IS NULL      
                                               AND A.MASTERID = M.MASTERID      
                                               AND @V_CURRDATE < A.PMTDATE      
                                               AND @V_CURRDATE >= A.PREVDATE      
                                               AND A.PMTDATE <> A.PREVDATE      
                    /*ADDING TO FIXING N_AMORT_AMOUNT 20160504*/      
     JOIN IFRS_ACCT_SL_ECF C ON C.AMORTSTOPDATE IS NULL      
                                AND C.MASTERID = A.MASTERID      
                                               AND C.PMTDATE = C.PREVDATE      
            WHERE   --DONT DO IF CLOSED      
                    M.MASTERID NOT IN ( SELECT  MASTERID      
                                        FROM    IFRS_ACCT_CLOSED      
                                        WHERE   DOWNLOAD_DATE = @V_CURRDATE )      
      END REMARKS.. TUNNING SCRIPT 20160602*/     
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'ACF INSERTED'      
  )    
     
 -- GET SL_ACF MAX(ID) TO PROCESS      
 TRUNCATE TABLE TMP_P1      
      
 INSERT INTO TMP_P1 (ID)      
 SELECT MAX(ID) AS ID      
 FROM IFRS_ACCT_SL_ACF      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
  AND DO_AMORT = 'N'      
 GROUP BY MASTERID      
  
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'P1'      
  )      
    
 -- GET SUMM FEE      
 TRUNCATE TABLE TMP_T1      
      
 INSERT INTO TMP_T1 (      
  SUM_AMT      
  ,DOWNLOAD_DATE      
  ,FACNO      
  ,CIFNO      
  ,DATASOURCE      
  ,ACCTNO      
  ,MASTERID      
  )      
 SELECT SUM(A.N_AMOUNT) AS SUM_AMT      
  ,A.DOWNLOAD_DATE      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.DATASOURCE      
  ,A.ACCTNO      
  ,A.MASTERID      
 FROM (      
  SELECT CASE       
    WHEN A.FLAG_REVERSE = 'Y'      
     THEN - 1 * A.AMOUNT      
    ELSE A.AMOUNT      
    END AS N_AMOUNT      
   ,A.ECFDATE DOWNLOAD_DATE      
   ,A.FACNO      
   ,A.CIFNO      
   ,A.DATASOURCE      
   ,A.ACCTNO      
   ,A.MASTERID      
  FROM IFRS_ACCT_SL_COST_FEE_ECF A      
  WHERE A.FLAG_CF = 'F' AND A.STATUS = 'ACT'     
  ) A      
 GROUP BY A.DOWNLOAD_DATE      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.DATASOURCE      
  ,A.ACCTNO      
  ,A.MASTERID      
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'T1 FEE'      
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'INSERT FEE'      
  )      
  
 -- FEE 1      
 INSERT INTO IFRS_ACCT_SL_COST_FEE_PREV (      
  FACNO      
  ,CIFNO      
  ,DOWNLOAD_DATE      
  ,ECFDATE      
  ,DATASOURCE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,AMOUNT      
  ,STATUS      
  ,CREATEDDATE      
  ,ACCTNO      
  ,MASTERID      
  ,FLAG_CF      
  ,FLAG_REVERSE      
  ,BRCODE      
  ,SRCPROCESS      
  ,METHOD      
  ,CREATEDBY      
  ,SEQ      
  ,AMOUNT_ORG      
  ,ORG_CCY      
  ,ORG_CCY_EXRATE      
  ,PRDTYPE      
  ,CF_ID      
  )      
 SELECT A.FACNO      
  ,A.CIFNO      
  ,A.DOWNLOAD_DATE      
  ,A.ECFDATE      
  ,A.DATASOURCE      
  ,B.PRDCODE      
  ,B.TRXCODE      
  ,B.CCY      
  ,CAST(CAST(B.AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS NUMERIC(32, 20)) * A.N_UNAMORT_FEE AS N_AMOUNT      
  ,B.STATUS      
  ,CURRENT_TIMESTAMP      
  ,A.ACCTNO      
  ,A.MASTERID      
  ,B.FLAG_CF      
  ,B.FLAG_REVERSE      
  ,B.BRCODE      
  ,B.SRCPROCESS      
  ,'SL'      
  ,'SLACF02'      
  ,'2'      
  ,B.AMOUNT_ORG      
  ,B.ORG_CCY      
  ,B.ORG_CCY_EXRATE      
  ,B.PRDTYPE      
  ,B.CF_ID      
 FROM IFRS_ACCT_SL_ACF A      
 --TUNNING SCRIPT 20180914      
 JOIN TMP_P1 D ON A.ID = D.ID      
 --TUNNING SCRIPT 20180914    
 JOIN IFRS_ACCT_SL_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE      
  AND A.MASTERID = B.MASTERID      
  AND B.FLAG_CF = 'F'  AND B.STATUS = 'ACT'    
 JOIN TMP_T1 C ON C.DOWNLOAD_DATE = A.ECFDATE      
  AND C.MASTERID = A.MASTERID      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND (      
   (      
    A.N_UNAMORT_FEE < 0      
    AND A.FLAG_AL IN ('A', 'O')      
    )      
   OR (      
    A.N_UNAMORT_FEE > 0      
    AND A.FLAG_AL = 'L'      
    )      
   )       
/*20180914  
  AND A.ID IN (      
   SELECT ID      
   FROM TMP_P1      
   )      
 20180914*/  
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'FEE PREV'      
  )      
       
 --GET COST SUMM      
 TRUNCATE TABLE TMP_T2      
      
 INSERT INTO TMP_T2 (      
  SUM_AMT      
  ,DOWNLOAD_DATE      
  ,FACNO      
  ,CIFNO      
  ,DATASOURCE      
  ,ACCTNO      
  ,MASTERID      
  )      
 SELECT SUM(A.N_AMOUNT) AS SUM_AMT      
  ,A.DOWNLOAD_DATE      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.DATASOURCE      
  ,A.ACCTNO      
  ,A.MASTERID      
 FROM (      
  SELECT CASE       
    WHEN A.FLAG_REVERSE = 'Y'      
     THEN - 1 * A.AMOUNT      
    ELSE A.AMOUNT      
    END AS N_AMOUNT      
   ,A.ECFDATE DOWNLOAD_DATE      
   ,A.FACNO      
   ,A.CIFNO      
   ,A.DATASOURCE      
   ,A.ACCTNO      
   ,A.MASTERID      
  FROM IFRS_ACCT_SL_COST_FEE_ECF A      
  WHERE A.FLAG_CF = 'C' AND A.STATUS = 'ACT'  
  ) A      
 GROUP BY A.DOWNLOAD_DATE      
  ,A.FACNO      
  ,A.CIFNO      
  ,A.DATASOURCE      
  ,A.ACCTNO      
  ,A.MASTERID      
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'T2 COST'      
  )      
  
 -- COST 1      
 INSERT INTO IFRS_ACCT_SL_COST_FEE_PREV (      
  FACNO      
  ,CIFNO      
  ,DOWNLOAD_DATE      
  ,ECFDATE      
  ,DATASOURCE      
  ,PRDCODE      
  ,TRXCODE      
  ,CCY      
  ,AMOUNT      
  ,STATUS      
  ,CREATEDDATE      
  ,ACCTNO      
  ,MASTERID      
  ,FLAG_CF      
  ,FLAG_REVERSE      
  ,BRCODE      
  ,SRCPROCESS      
  ,METHOD      
  ,CREATEDBY      
  ,SEQ      
  ,AMOUNT_ORG      
  ,ORG_CCY      
  ,ORG_CCY_EXRATE      
  ,PRDTYPE      
  ,CF_ID      
  )      
 SELECT A.FACNO      
  ,A.CIFNO      
  ,A.DOWNLOAD_DATE      
  ,A.ECFDATE      
  ,A.DATASOURCE      
  ,B.PRDCODE      
  ,B.TRXCODE      
  ,B.CCY      
  ,CAST(CAST(B.AMOUNT AS FLOAT) / CAST(C.SUM_AMT AS FLOAT) AS NUMERIC(32, 20)) * A.N_UNAMORT_COST AS N_AMOUNT      
  ,B.STATUS      
  ,CURRENT_TIMESTAMP      
  ,A.ACCTNO      
  ,A.MASTERID      
  ,B.FLAG_CF      
  ,B.FLAG_REVERSE      
  ,B.BRCODE      
  ,B.SRCPROCESS      
  ,'SL'      
  ,'SLACF02'      
  ,'2'      
  ,B.AMOUNT_ORG      
  ,B.ORG_CCY      
  ,B.ORG_CCY_EXRATE      
  ,B.PRDTYPE      
  ,B.CF_ID      
 FROM IFRS_ACCT_SL_ACF A      
 --TUNNING SCRIPT 20180914      
 JOIN TMP_P1 D ON A.ID = D.ID      
 --TUNNING SCRIPT 20180914    
 JOIN IFRS_ACCT_SL_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE      
  AND A.MASTERID = B.MASTERID      
  AND B.FLAG_CF = 'C' AND B.STATUS = 'ACT'      
 JOIN TMP_T2 C ON C.DOWNLOAD_DATE = A.ECFDATE      
  AND C.MASTERID = A.MASTERID      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND (      
   (      
    A.N_UNAMORT_COST > 0      
    AND A.FLAG_AL IN ('A', 'O')
    )      
   OR (      
    A.N_UNAMORT_COST < 0      
    AND A.FLAG_AL = 'L'      
    )      
   )      
 /*20180914         
  AND A.ID IN (      
   SELECT ID      
   FROM TMP_P1      
   )      
  20180914*/  
  
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
  ,'DEBUG'      
  ,'SP_IFRS_ACCT_SL_ACF_ACRU'      
  ,'COST PREV'      
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
  ,'SP_IFRS_ACCT_SL_ACF_ACCRU'      
  ,''      
  )      
END   
GO
