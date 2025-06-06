USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_EIR_ECF_EVENT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_EIR_ECF_EVENT]      
AS      
DECLARE @V_CURRDATE DATE      
 ,@V_PREVDATE DATE      
 ,@V_EFFDATEFLAG VARCHAR(1)      
      
BEGIN      
 SELECT @V_CURRDATE = MAX(CURRDATE)      
  ,@V_PREVDATE = MAX(PREVDATE)      
 FROM IFRS_PRC_DATE_AMORT      
      
 SELECT @V_EFFDATEFLAG = COMMONUSAGE      
 FROM TBLM_COMMONCODEHEADER      
 WHERE COMMONCODE = 'SCM004'      
      
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
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
  ,''      
  )      
      
 -- RESET        
 --UPDATE PMA SET EIR_STATUS='' WHERE DOWNLOAD_DATE=V_CURRDATE AND EIR_STATUS='Y';        
 UPDATE IFRS_IMA_AMORT_CURR      
 SET EIR_STATUS = ''      
  ,ECF_STATUS = ''      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
 UPDATE IFRS_MASTER_ACCOUNT      
 SET EIR_STATUS = ''      
  ,ECF_STATUS = ''      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
 DELETE IFRS_EVENT_CHANGES      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
 DELETE IFRS_EVENT_CHANGES_DETAILS      
 WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
 -- GET ACTIVE EIR ECF MASTERID        
 TRUNCATE TABLE IFRS_ACT_ECF_TMP      
      
 INSERT INTO IFRS_ACT_ECF_TMP (MASTERID)      
 SELECT DISTINCT MASTERID      
 FROM IFRS_ACCT_EIR_ECF      
 WHERE AMORTSTOPDATE IS NULL    
 AND DOWNLOAD_DATE <= @V_CURRDATE    
      
 --AND DOWNLOAD_DATE < @V_CURRDATE        
 --INTEREST RATE CHANGES        
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,CASE       
   WHEN @V_EFFDATEFLAG = '1'      
    THEN @V_CURRDATE      
   WHEN @V_EFFDATEFLAG = '2'      
    THEN A.NEXT_PAYMENT_DATE      
   ELSE @V_CURRDATE      
   END      
  ,C.INTEREST_RATE      
  ,A.INTEREST_RATE      
  ,0      
  ,'INTEREST RATE CHANGES'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_ACT_ECF_TMP B ON A.MASTERID = B.MASTERID      
 INNER JOIN IFRS_IMA_AMORT_PREV C ON A.MASTERID = C.MASTERID      
 WHERE (      
   A.INTEREST_RATE <> C.INTEREST_RATE      
   OR A.INTEREST_RATE_IDC <> C.INTEREST_RATE_IDC      
   )      
  AND (      
   ABS(A.UNAMORT_COST_AMT) <> 0      
   OR ABS(A.UNAMORT_FEE_AMT) <> 0      
   )      
  AND ISNULL(A.INTEREST_RATE, 0) > 0      
  AND A.LOAN_DUE_DATE > @V_CURRDATE      
  AND A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.STAFF_LOAN_FLAG = 'N' 
      

 --INTEREST RATE CHANGES  FOR BELOW MARKET 20180820      
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,CASE       
   WHEN @V_EFFDATEFLAG = '1'      
    THEN @V_CURRDATE      
   WHEN @V_EFFDATEFLAG = '2'      
    THEN A.NEXT_PAYMENT_DATE      
   ELSE @V_CURRDATE      
   END      
  ,C.INTEREST_RATE      
  ,A.INTEREST_RATE      
  ,0      
  ,'INTEREST RATE CHANGES'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN (SELECT DISTINCT MASTERID FROM IFRS_LBM_ACCT_EIR_ECF WHERE AMORTSTOPDATE IS NULL )B ON A.MASTERID = B.MASTERID      
 INNER JOIN IFRS_IMA_AMORT_PREV C ON A.MASTERID = C.MASTERID      
 WHERE (      
   A.INTEREST_RATE <> C.INTEREST_RATE      
   OR A.INTEREST_RATE_IDC <> C.INTEREST_RATE_IDC      
   )      
   --AND (      
   -- ABS(ISNULL(A.UNAMORT_COST_AMT,0)) = 0      
   -- AND ABS(ISNULL(A.UNAMORT_FEE_AMT,0)) = 0      
   --)      
   AND ISNULL(A.INTEREST_RATE, 0) > 0      
   AND A.LOAN_DUE_DATE > @V_CURRDATE      
   AND A.DOWNLOAD_DATE = @V_CURRDATE      
   AND A.STAFF_LOAN_FLAG = 'Y'      




 --LOAN DUE DATE CHANGES        
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
 ,CASE       
   WHEN @V_EFFDATEFLAG = '1'      
    THEN @V_CURRDATE      
   WHEN @V_EFFDATEFLAG = '2'      
    THEN A.NEXT_PAYMENT_DATE      
   ELSE @V_CURRDATE      
   END      
  ,C.LOAN_DUE_DATE      
  ,A.LOAN_DUE_DATE      
  ,6 -- SEBELUMNYA 1 TEST SAID SUPAYA EIR GA DI HITUNG ULANG       
  ,'LOAN DUE DATE CHANGES'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_ACT_ECF_TMP B ON A.MASTERID = B.MASTERID      
 INNER JOIN IFRS_IMA_AMORT_PREV C ON A.MASTERID = C.MASTERID      
 WHERE A.LOAN_DUE_DATE <> C.LOAN_DUE_DATE      
  AND (      
   ABS(A.UNAMORT_COST_AMT) <> 0      
   OR ABS(A.UNAMORT_FEE_AMT) <> 0      
   )      
  AND A.LOAN_DUE_DATE > @V_CURRDATE      
  AND A.DOWNLOAD_DATE = @V_CURRDATE      
  
  
 --NEW COST/FEE        
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT DISTINCT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,CASE       
   WHEN @V_EFFDATEFLAG = '1'      
    THEN @V_CURRDATE      
   WHEN @V_EFFDATEFLAG = '2'      
    THEN A.NEXT_PAYMENT_DATE      
   ELSE @V_CURRDATE      
   END      
  ,0      
  ,B.AMOUNT      
  ,2      
  ,B.FLAG_CF + ' - ' + B.FLAG_REVERSE + ' - ' + B.TRX_CODE      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_ACCT_COST_FEE B ON A.MASTERID = B.MASTERID      
  AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
 WHERE B.STATUS = 'ACT'      
  AND B.METHOD = 'EIR'      
  AND A.LOAN_DUE_DATE > @V_CURRDATE      
  AND A.DOWNLOAD_DATE = @V_CURRDATE      
      
        -- NEW STAFFLOAN EVENT        
        INSERT  INTO IFRS_EVENT_CHANGES        
                ( DOWNLOAD_DATE ,        
                  MASTERID ,        
                  ACCOUNT_NUMBER ,        
                  EFFECTIVE_DATE ,        
                  BEFORE_VALUE ,        
                  AFTER_VALUE ,        
                  EVENT_ID ,        
                  REMARKS ,        
                  CREATEDBY        
                )        
                SELECT  @V_CURRDATE ,        
                        A.MASTERID ,        
                        A.ACCOUNT_NUMBER ,        
                        @V_CURRDATE ,        
                        0 ,        
                        0 ,        
                        3 ,        
                        'NEW STAFFLOAN ACCOUNT' ,        
                        'SP_IFRS_ACCT_EIR_ECF_EVENT'        
                FROM    IFRS_IMA_AMORT_CURR A        
            INNER JOIN IFRS_PRODUCT_PARAM B ON A.DATA_SOURCE = B.DATA_SOURCE        
                                     AND A.PRODUCT_TYPE = B.PRD_TYPE        
                AND A.PRODUCT_CODE = B.PRD_CODE        
                AND (A.CURRENCY = B.CCY OR B.CCY = 'ALL')        
                WHERE   A.LOAN_START_DATE = @V_CURRDATE        
     AND   (B.IS_STAF_LOAN IN ('1','Y') OR A.STAFF_LOAN_FLAG = 'Y')        
     AND   A.DOWNLOAD_DATE = @V_CURRDATE        
     
	 
	 
	 
	 
	 
	  
        
 /*        
  -- REPAYMENT EVENT        
        INSERT  INTO IFRS_EVENT_CHANGES        
                ( DOWNLOAD_DATE ,        
                  MASTERID ,        
                  ACCOUNT_NUMBER ,        
                  EFFECTIVE_DATE ,        
                  BEFORE_VALUE ,        
                  AFTER_VALUE ,        
                  EVENT_ID ,        
                  REMARKS ,        
                  CREATEDBY        
                )        
                SELECT  @V_CURRDATE ,        
                        A.MASTERID ,    
                        A.ACCOUNT_NUMBER ,        
                        @V_CURRDATE ,        
                        0 ,        
                        1 ,        
                        4 ,        
                        'REPAYMENT ACCOUNT' ,        
                        'SP_IFRS_ACCT_EIR_ECF_EVENT'        
                FROM    IFRS_IMA_AMORT_CURR A        
            INNER JOIN IFRS_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID        
                                     AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
                AND A.CURRENCY = B.CURRENCY        
                WHERE   B.FLAG_REPAYMENT = '1'        
      AND   A.DOWNLOAD_DATE = @V_CURRDATE        
      AND A.MASTERID IN (        
       SELECT MASTERID FROM IFRS_MASTER_ACCOUNT        
       WHERE DOWNLOAD_DATE = @V_PREVDATE        
       AND FLAG_REPAYMENT = '0'        
       )        
     AND A.AMORT_TYPE = 'EIR'        
             
 -- DISBURSE REVERSAL EVENT        
        INSERT  INTO IFRS_EVENT_CHANGES        
                ( DOWNLOAD_DATE ,        
                  MASTERID ,        
                  ACCOUNT_NUMBER ,        
                  EFFECTIVE_DATE ,        
                  BEFORE_VALUE ,        
                  AFTER_VALUE ,        
                  EVENT_ID ,        
                  REMARKS ,        
     CREATEDBY        
                )        
                SELECT  @V_CURRDATE ,        
                        A.MASTERID ,        
                        A.ACCOUNT_NUMBER ,        
                        @V_CURRDATE ,        
                        0 ,        
                        0 ,        
                        5 ,        
                        'REVERSAL DISBURSE ACCOUNT' ,        
                        'SP_IFRS_ACCT_EIR_ECF_EVENT'        
                FROM    IFRS_IMA_AMORT_CURR A        
            INNER JOIN IFRS_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID        
                                     AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
                AND A.CURRENCY = B.CURRENCY        
                WHERE   B.FLAG_REVERSAL = 'Y'        
      AND   A.DOWNLOAD_DATE = @V_CURRDATE        
      AND A.MASTERID IN (        
       SELECT MASTERID FROM IFRS_MASTER_ACCOUNT        
       WHERE DOWNLOAD_DATE = @V_PREVDATE        
       AND FLAG_REVERSAL = 'N'        
       )        
    AND A.AMORT_TYPE = 'EIR'        
        
        INSERT  INTO IFRS_EVENT_CHANGES_DETAILS        
                ( DOWNLOAD_DATE ,        
                  MASTERID ,        
                  ACCOUNT_NUMBER ,        
                  BEFORE_VALUE ,        
                  AFTER_VALUE ,        
                  EVENT_ID ,        
                  REMARKS ,        
                  CREATEDBY        
                )        
                SELECT  A.DOWNLOAD_DATE ,        
                        A.MASTERID ,        
                        A.ACCOUNT_NUMBER ,        
                        B.BEFORE_VALUE ,        
                        B.AFTER_VALUE ,        
                        B.EVENT_ID ,        
                        B.REMARKS ,        
                        'SP_IFRS_ACCT_EIR_ECF_EVENT'        
                FROM    IFRS_IMA_AMORT_CURR A        
                        INNER JOIN IFRS_EVENT_CHANGES B ON A.MASTERID = B.MASTERID        
                                                           AND A.DOWNLOAD_DATE = B.EFFECTIVE_DATE        
                WHERE   A.DOWNLOAD_DATE = @V_CURRDATE        
      AND   A.AMORT_TYPE = 'EIR'        
      AND   A.MASTERID NOT IN (SELECT DISTINCT MASTERID        
                                      FROM      IFRS_ACCT_CLOSED        
                                      WHERE     DOWNLOAD_DATE = @V_CURRDATE)        
           */      
 /*REMARK CTBC      
        -- NEW NOCF EVENT        
        INSERT  INTO IFRS_EVENT_CHANGES        
                ( DOWNLOAD_DATE ,        
                  MASTERID ,        
                  ACCOUNT_NUMBER ,        
                  EFFECTIVE_DATE ,        
           BEFORE_VALUE ,        
                  AFTER_VALUE ,        
                  EVENT_ID ,        
                  REMARKS ,        
                  CREATEDBY        
                )        
                SELECT  @V_CURRDATE ,        
                        A.MASTERID ,        
                        A.ACCOUNT_NUMBER ,        
                        @V_CURRDATE ,        
                        0 ,        
                        0 ,        
                        4 ,        
                        'NEW NOCF ACCOUNT' ,        
                        'SP_IFRS_ACCT_EIR_ECF_EVENT'        
                FROM    IFRS_IMA_AMORT_CURR A        
            INNER JOIN IFRS_PRODUCT_PARAM B ON A.DATA_SOURCE = B.DATA_SOURCE        
                AND A.PRODUCT_TYPE = B.PRD_TYPE        
                AND A.PRODUCT_CODE = B.PRD_CODE        
             AND (A.CURRENCY = B.CCY OR B.CCY = 'ALL')       
                WHERE   A.LOAN_START_DATE = @V_CURRDATE        
    AND   (B.IS_STAF_LOAN IN ('N') OR A.STAFF_LOAN_FLAG = 'N')        
    AND   A.DOWNLOAD_DATE = @V_CURRDATE        
    AND A.MASTERID NOT IN (        
           SELECT DISTINCT MASTERID         
           FROM IFRS_EVENT_CHANGES        
           WHERE DOWNLOAD_DATE = @V_CURRDATE        
           )        
      
    AND A.LOAN_DUE_DATE > @V_CURRDATE        
    AND A.ACCOUNT_STATUS = 'A'       
         
   */      
 -- NEW RESTRUCT EVENT   
  INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT DISTINCT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,@V_CURRDATE      
  ,B.PREV_MASTERID      
  ,B.MASTERID      
  ,6      
  ,'RESTRUCTURE - '+B.PREV_MASTERID      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_ACCT_AMORT_RESTRU B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
  AND A.MASTERID = B.MASTERID
  --AND B.ACCTNO <> B.PREV_ACCTNO      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
 
 
 
 -- CHANGE BRANCH      
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,@V_CURRDATE      
  ,B.PREV_ACCTNO      
  ,B.ACCTNO      
  ,5      
  ,'CHANGE_BRANCH'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_ACCT_SWITCH B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
  AND A.MASTERID = B.MASTERID
  --AND B.ACCTNO <> B.PREV_ACCTNO      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
 
 
 /* --REMARK TEMPORARY SOLUTION 20191030 FAILED GOALSEEK BTPN  
 ---- NEW PAYMENT SCHEDULE FROM DWH
     INSERT INTO IFRS_EVENT_CHANGES (      
			   DOWNLOAD_DATE      
			  ,MASTERID      
			  ,ACCOUNT_NUMBER      
			  ,EFFECTIVE_DATE      
			  ,BEFORE_VALUE      
			  ,AFTER_VALUE      
			  ,EVENT_ID      
			  ,REMARKS      
			  ,CREATEDBY      
			  )   

        SELECT		@V_CURRDATE
                    ,A.MASTERID
                    ,A.ACCOUNT_NUMBER
                    ,@V_CURRDATE
                    ,0
                    ,0
                    ,6
                    ,'PAYMENT SCHEDULE CHANGES'
                    ,'SP_IFRS_ACCT_EIR_ECF_EVENT'
        FROM IFRS_IMA_AMORT_CURR AS A
		INNER JOIN 
		( SELECT DISTINCT MASTERID FROM IFRS_ACCT_EIR_ECF 
		WHERE DOWNLOAD_DATE <= @V_CURRDATE ) ECF
		ON A.MASTERID = ECF.MASTERID 
        INNER JOIN
        ( SELECT DISTINCT DOWNLOAD_DATE, MASTERID FROM IFRS_STG_PAYM_SCHD 
		WHERE DOWNLOAD_DATE = @V_CURRDATE)AS B
        ON A.MASTERID = B.MASTERID
        AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE
		WHERE A.DOWNLOAD_DATE = @V_CURRDATE
 */    
      
 -- PARTIAL PAYMENT EVENT        
 INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,@V_CURRDATE      
  ,0      
  ,B.ORG_CCY_AMT      
  ,6      
  ,'PARTIAL PAYMENT ACCOUNT'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A      
 INNER JOIN IFRS_TRANSACTION_DAILY B ON A.MASTERID = B.MASTERID      
  AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
  AND B.TRX_CODE = 'PREPAYMENT'      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
  AND A.ACCOUNT_STATUS = 'A'      
  AND A.OUTSTANDING > 0    
  
INSERT INTO IFRS_EVENT_CHANGES (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,ACCOUNT_NUMBER      
  ,EFFECTIVE_DATE      
  ,BEFORE_VALUE      
  ,AFTER_VALUE      
  ,EVENT_ID      
  ,REMARKS      
  ,CREATEDBY      
  )      
 SELECT @V_CURRDATE      
  ,A.MASTERID      
  ,A.ACCOUNT_NUMBER      
  ,@V_CURRDATE      
  ,0      
  ,ISNULL(EARLY_PAYMENT,0)  
  ,6      
  ,'EARLY PAYMENT'      
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
 FROM IFRS_IMA_AMORT_CURR A        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE AND EARLY_PAYMENT_FLAG = 'Y'      
  AND A.ACCOUNT_STATUS = 'A'      
  AND A.OUTSTANDING > 0  
      
 UPDATE IFRS_IMA_AMORT_CURR      
 SET EIR_STATUS = 'Y'      
  ,ECF_STATUS = 'Y'      
 FROM IFRS_IMA_AMORT_CURR IMA      
  ,IFRS_EVENT_CHANGES RES      
 WHERE IMA.DOWNLOAD_DATE = @V_CURRDATE      
  AND RES.EFFECTIVE_DATE = @V_CURRDATE      
  AND RES.MASTERID = IMA.MASTERID      
  AND IMA.MASTERID NOT IN (      
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
  ,'SP_IFRS_ACCT_EIR_ECF_EVENT'      
  ,''      
  )      
END
GO
