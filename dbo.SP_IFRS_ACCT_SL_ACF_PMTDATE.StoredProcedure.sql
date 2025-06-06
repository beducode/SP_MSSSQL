USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_SL_ACF_PMTDATE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_SL_ACF_PMTDATE]  
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
  ,'SP_IFRS_ACCT_SL_ACF_PMTDATE'  
  ,''  
  )  
  
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
 SELECT M.DOWNLOAD_DATE  
  ,M.FACILITY_NUMBER  
  ,M.CUSTOMER_NUMBER  
  ,M.DATA_SOURCE  
  ,A.N_UNAMORT_COST  
  ,A.N_UNAMORT_FEE  
  ,A.N_AMORT_COST  
  ,A.N_AMORT_FEE  
  ,A.N_UNAMORT_COST - A.UNAMORT_COST_PREV - COALESCE(A.SW_ADJ_COST, 0)  
  ,A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV - COALESCE(A.SW_ADJ_FEE, 0)  
  ,A.N_UNAMORT_COST - A.UNAMORT_COST_PREV - COALESCE(A.SW_ADJ_COST, 0) AS N_ACCRUFULL_COST  
  ,A.N_UNAMORT_FEE - A.UNAMORT_FEE_PREV - COALESCE(A.SW_ADJ_FEE, 0) AS N_ACCRUFULL_FEE  
  ,A.DOWNLOAD_DATE  
  ,CURRENT_TIMESTAMP  
  ,'SP_ACCT_SL_ACF_PMTDATE 1'  
  ,M.MASTERID  
  ,M.ACCOUNT_NUMBER  
  ,'Y' DO_AMORT  
  ,M.BRANCH_CODE  
  ,'1' ACFCODE
  ,M.FLAG_AL  
 FROM IFRS_ACCT_SL_ECF A  
 JOIN (  
  SELECT M.DOWNLOAD_DATE  
   ,M.MASTERID  
   ,M.ACCOUNT_NUMBER  
   ,M.DATA_SOURCE  
   ,M.BRANCH_CODE  
   ,M.FACILITY_NUMBER  
   ,M.CUSTOMER_NUMBER  
   ,M.IAS_CLASS AS FLAG_AL
  FROM IFRS_IMA_AMORT_CURR M  
  LEFT JOIN (  
   SELECT DISTINCT DOWNLOAD_DATE  
    ,MASTERID  
   FROM IFRS_ACCT_CLOSED  
   WHERE DOWNLOAD_DATE = @V_CURRDATE  
   ) D ON M.DOWNLOAD_DATE = D.DOWNLOAD_DATE  
   AND M.MASTERID = D.MASTERID  
  WHERE M.DOWNLOAD_DATE = @V_CURRDATE  
   AND D.MASTERID IS NULL  
  ) M ON M.MASTERID = A.MASTERID  
 WHERE A.PMTDATE = @V_CURRDATE  
  AND A.PMTDATE <> A.PREVDATE  
  AND A.AMORTSTOPDATE IS NULL  
  
 /* REMARKS.. TUNNING SCRIPT 20160602  
FROM IFRS_IMA_AMORT_CURR  M  
JOIN IFRS_ACCT_SL_ECF A ON A.AMORTSTOPDATE IS NULL  
 AND A.MASTERID=M.MASTERID  
 AND A.PMTDATE=@V_CURRDATE  
    AND A.PMTDATE<>A.PREVDATE  
WHERE  
--DONT DO IF CLOSED  
M.MASTERID NOT IN (SELECT MASTERID FROM IFRS_ACCT_CLOSED WHERE DOWNLOAD_DATE=@V_CURRDATE);  
END REMARKS.. TUNNING SCRIPT 20160602*/  
 TRUNCATE TABLE TMP_P1  
  
 INSERT INTO TMP_P1 (ID)  
 SELECT MAX(ID) AS ID  
 FROM IFRS_ACCT_SL_ACF  
 WHERE DOWNLOAD_DATE = @V_CURRDATE  
  -- EXCLUDE ACCT REGISTERED @ STOP REV 20160619  
  AND MASTERID NOT IN (  
   SELECT MASTERID  
   FROM IFRS_ACCT_SL_STOP_REV  
   WHERE DOWNLOAD_DATE = @V_CURRDATE  
   )  
 GROUP BY MASTERID  
  
 TRUNCATE TABLE TMP_T1  
  
 TRUNCATE TABLE TMP_T2  
  
 -- FEE SUMM  
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
  WHERE A.FLAG_CF = 'F'  
  ) A  
 GROUP BY A.DOWNLOAD_DATE  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.DATASOURCE  
  ,A.ACCTNO  
  ,A.MASTERID  
  
 -- FEE DETAIL UNAMORT  
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
  ,CREATEDBY  
  ,METHOD  
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
  ,'SLACF01'  
  ,'SL'  
  ,'1'  
  ,B.AMOUNT_ORG  
  ,B.ORG_CCY  
  ,B.ORG_CCY_EXRATE  
  ,B.PRDTYPE  
  ,B.CF_ID  
 FROM IFRS_ACCT_SL_ACF A  
 JOIN IFRS_ACCT_SL_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE  
  AND A.MASTERID = B.MASTERID  
  AND B.FLAG_CF = 'F'  
  AND B.STATUS = 'ACT'  
  AND B.METHOD = 'SL'  
 JOIN TMP_T1 C ON C.DOWNLOAD_DATE = A.ECFDATE  
  AND C.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.N_UNAMORT_FEE < 0  
  AND A.ID IN (  
   SELECT ID  
   FROM TMP_P1  
   )  
  
 -- COST SUMM  
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
  WHERE A.FLAG_CF = 'C'  
  ) A  
 GROUP BY A.DOWNLOAD_DATE  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.DATASOURCE  
  ,A.ACCTNO  
  ,A.MASTERID  
  
 -- COST DETAIL  
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
  ,CREATEDBY  
  ,METHOD  
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
  ,'SLACF01'  
  ,'SL'  
  ,'1'  
  ,B.AMOUNT_ORG  
  ,B.ORG_CCY  
  ,B.ORG_CCY_EXRATE  
  ,B.PRDTYPE  
  ,B.CF_ID  
 FROM IFRS_ACCT_SL_ACF A  
 JOIN IFRS_ACCT_SL_COST_FEE_ECF B ON B.ECFDATE = A.ECFDATE  
  AND A.MASTERID = B.MASTERID  
  AND B.FLAG_CF = 'C'  
  AND B.STATUS = 'ACT'  
 JOIN TMP_T2 C ON C.DOWNLOAD_DATE = A.ECFDATE  
  AND C.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.N_UNAMORT_COST > 0  
  AND A.ID IN (  
   SELECT ID  
   FROM TMP_P1  
   )  
  
 -- AMORT ACRU --JOURNAL SHOULD DO THE REST  
 UPDATE IFRS_ACCT_SL_ACCRU_PREV  
 SET STATUS = CONVERT(VARCHAR(8), @V_CURRDATE, 112)  
 WHERE STATUS = 'ACT'  
  AND MASTERID IN (  
   SELECT DISTINCT MASTERID  
   FROM IFRS_ACCT_SL_ACF  
   WHERE DOWNLOAD_DATE = @V_CURRDATE  
    AND DO_AMORT = 'Y'  
   )  
  
 -- STOP SL ECF END TODAY  
 UPDATE IFRS_ACCT_SL_ECF  
 SET AMORTSTOPDATE = @V_CURRDATE  
  ,AMORTSTOPREASON = 'END_ACF'  
 WHERE AMORTENDDATE = @V_CURRDATE  
  AND AMORTSTOPDATE IS NULL  
  AND MASTERID NOT IN (  
   SELECT DISTINCT MASTERID  
   FROM IFRS_ACCT_CLOSED  
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
  ,'SP_IFRS_ACCT_SL_ACF_PMTDATE'  
  ,''  
  )  
END  

GO
