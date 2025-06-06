USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_EIR_GS_INSERT4]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_EIR_GS_INSERT4]  
AS  
DECLARE @V_CURRDATE DATE  
DECLARE @V_PREVDATE DATE  
DECLARE @VI BIGINT  
DECLARE @V_ROUND INT  
DECLARE @V_FUNCROUND INT  
  
BEGIN  
 -- DANIEL S : ZERO UNAMORT WITH NO COST FEE  
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
  ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
  ,''  
  )  
  
 SELECT @V_ROUND = CAST(VALUE1 AS INT)  
  ,@V_FUNCROUND = CAST(VALUE2 AS INT)  
 FROM TBLM_COMMONCODEDETAIL  
 WHERE COMMONCODE = 'SCM003'  
  
 -- INSERT INITIAL ROW PREVDATE=PMTDATE  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF1  
  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF2  
  
 -- PREPARE INDEX  
 --EXECUTE IMMEDIATE 'DROP INDEX PSAK_EIR_PAYM_IDX1';  
 --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_EIR_PAYM_IDX1 ON IFRS_LI_ACCT_EIR_PAYM(MASTERID,PMT_DATE,PREV_PMT_DATE)';  
 --EXECUTE IMMEDIATE 'DROP INDEX PSAK_EIR_CF_ECF_IDX1';  
 --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_EIR_CF_ECF_IDX1 ON IFRS_LI_ACCT_EIR_CF_ECF(MASTERID)';  
 --EXECUTE IMMEDIATE 'DROP INDEX PSAK_GS_RESULT_IDX14';  
 --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_GS_RESULT_IDX14 ON IFRS_LI_ACCT_EIR_GS_RESULT4(MASTERID,DOWNLOAD_DATE)';  
 INSERT INTO IFRS_LI_ACCT_EIR_ECF2 (  
  MASTERID  
  ,DOWNLOAD_DATE  
  ,N_LOAN_AMT  
  ,N_INT_RATE  
  ,N_EFF_INT_RATE  
  ,STARTAMORTDATE  
  ,ENDAMORTDATE  
  ,GRACEDATE  
  ,DISB_PERCENTAGE  
  ,DISB_AMOUNT  
  ,PLAFOND  
  ,PAYMENTCODE  
  ,INTCALCCODE  
  ,PAYMENTTERM  
  ,ISGRACE  
  ,PREV_PMT_DATE  
  ,PMT_DATE  
  ,I_DAYS  
  ,I_DAYS2  
  ,N_OSPRN_PREV  
  ,N_INSTALLMENT  
  ,N_PRN_PAYMENT  
  ,N_INT_PAYMENT  
  ,N_OSPRN  
  ,N_FAIRVALUE_PREV  
  ,N_EFF_INT_AMT  
  ,N_FAIRVALUE  
  ,N_UNAMORT_AMT_PREV  
  ,N_AMORT_AMT  
  ,N_UNAMORT_AMT  
  ,N_COST_UNAMORT_AMT_PREV  
  ,N_COST_AMORT_AMT  
  ,N_COST_UNAMORT_AMT  
  ,N_FEE_UNAMORT_AMT_PREV  
  ,N_FEE_AMORT_AMT  
  ,N_FEE_UNAMORT_AMT  
  ,N_FEE_AMT  
  ,N_COST_AMT  
  )  
 SELECT A.MASTERID  
  ,@V_CURRDATE  
  ,A.N_LOAN_AMT  
  ,A.N_INT_RATE  
  ,C.EIR  
  ,A.STARTAMORTDATE  
  ,A.ENDAMORTDATE  
  ,A.GRACEDATE  
  ,A.DISB_PERCENTAGE  
  ,A.DISB_AMOUNT  
  ,A.PLAFOND  
  ,A.PAYMENTCODE  
  ,A.INTCALCCODE  
  ,A.PAYMENTTERM  
  ,A.ISGRACE  
  ,A.PREV_PMT_DATE  
  ,A.PMT_DATE  
  ,A.I_DAYS  
  ,A.I_DAYS  
  ,A.N_OSPRN_PREV  
  ,A.N_INSTALLMENT  
  ,A.N_PRN_PAYMENT  
  ,A.N_INT_PAYMENT  
  ,A.N_OSPRN  
  ,0 + A.N_OSPRN N_FAIRVALUE_PREV --ZERO UNAMORT  
  ,0 N_EFF_INT_AMT  
  ,0 + A.N_OSPRN N_FAIRVALUE --ZERO UNAMORT  
  ,0 N_UNAMORT_AMT_PREV --ZERO UNAMORT  
  ,0 N_AMORT_AMT  
  ,0 N_UNAMORT_AMT  
  ,0 N_COST_UNAMORT_AMT_PREV  
  ,0 N_COST_AMORT_AMT  
  ,0 N_COST_UNAMORT_AMT  
  ,0 N_FEE_UNAMORT_AMT_PREV  
  ,0 N_FEE_AMORT_AMT  
  ,0 N_FEE_UNAMORT_AMT  
  ,0 N_FEE_AMT  
  ,0 N_COST_AMT_PREV  
 FROM IFRS_LI_ACCT_EIR_PAYM A  
 JOIN IFRS_LI_ACCT_EIR_CF_ECF B ON B.MASTERID = A.MASTERID  
 JOIN IFRS_LI_ACCT_EIR_GS_RESULT4 C ON C.MASTERID = A.MASTERID  
  AND C.DOWNLOAD_DATE = @V_CURRDATE  
 WHERE A.PMT_DATE = A.PREV_PMT_DATE  
  
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
  ,'DEBUG'  
  ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
  ,'1'  
  )  
  
 INSERT INTO IFRS_LI_ACCT_EIR_ECF_NOCF (  
  MASTERID  
  ,DOWNLOAD_DATE  
  ,N_LOAN_AMT  
  ,N_INT_RATE  
  ,N_EFF_INT_RATE  
  ,STARTAMORTDATE  
  ,ENDAMORTDATE  
  ,GRACEDATE  
  ,DISB_PERCENTAGE  
  ,DISB_AMOUNT  
  ,PLAFOND  
  ,PAYMENTCODE  
  ,INTCALCCODE  
  ,PAYMENTTERM  
  ,ISGRACE  
  ,PREV_PMT_DATE  
  ,PMT_DATE  
  ,I_DAYS  
  ,I_DAYS2  
  ,N_OSPRN_PREV  
  ,N_INSTALLMENT  
  ,N_PRN_PAYMENT  
  ,N_INT_PAYMENT  
  ,N_OSPRN  
  ,N_FAIRVALUE_PREV  
  ,N_EFF_INT_AMT  
  ,N_FAIRVALUE  
  ,N_UNAMORT_AMT_PREV  
  ,N_AMORT_AMT  
  ,N_UNAMORT_AMT  
  ,N_COST_UNAMORT_AMT_PREV  
  ,N_COST_AMORT_AMT  
  ,N_COST_UNAMORT_AMT  
  ,N_FEE_UNAMORT_AMT_PREV  
  ,N_FEE_AMORT_AMT  
  ,N_FEE_UNAMORT_AMT  
  )  
 SELECT MASTERID  
  ,DOWNLOAD_DATE  
  ,N_LOAN_AMT  
  ,N_INT_RATE    ,N_EFF_INT_RATE  
  ,STARTAMORTDATE  
  ,ENDAMORTDATE  
  ,GRACEDATE  
  ,DISB_PERCENTAGE  
  ,DISB_AMOUNT  
  ,PLAFOND  
  ,PAYMENTCODE  
  ,INTCALCCODE  
  ,PAYMENTTERM  
  ,ISGRACE  
  ,PREV_PMT_DATE  
  ,PMT_DATE  
  ,I_DAYS  
  ,DATEDIFF(DD, PREV_PMT_DATE, PMT_DATE) AS I_DAYS2  
  ,N_OSPRN_PREV  
  ,N_INSTALLMENT  
  ,N_PRN_PAYMENT  
  ,N_INT_PAYMENT  
  ,N_OSPRN  
  ,N_FAIRVALUE_PREV  
  ,N_EFF_INT_AMT  
  ,N_FAIRVALUE  
  ,N_UNAMORT_AMT_PREV  
  ,N_AMORT_AMT  
  ,N_UNAMORT_AMT  
  ,N_COST_UNAMORT_AMT_PREV  
  ,N_COST_AMORT_AMT  
  ,N_COST_UNAMORT_AMT  
  ,N_FEE_UNAMORT_AMT_PREV  
  ,N_FEE_AMORT_AMT  
  ,N_FEE_UNAMORT_AMT  
 FROM IFRS_LI_ACCT_EIR_ECF2  
  
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
  ,'DEBUG'  
  ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
  ,'2'  
  )  
  
 -- PREPARE TEMP TABLE FOR LOOPING  
 TRUNCATE TABLE TMP_LI_T9  
  
 INSERT INTO TMP_LI_T9 (  
  MASTERID  
  ,PMTDATE  
  )  
 SELECT MASTERID  
  ,PMT_DATE  
 FROM IFRS_LI_ACCT_EIR_PAYM  
 WHERE PMT_DATE = PREV_PMT_DATE  
  
 TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF_T2  
  
 INSERT INTO IFRS_LI_ACCT_EIR_ECF_T2 (  
  MASTERID  
  ,PMTDATE  
  )  
 SELECT A.MASTERID  
  ,MIN(A.PMT_DATE) AS PMTDATE  
 FROM IFRS_LI_ACCT_EIR_PAYM A  
 JOIN TMP_LI_T9 B ON B.MASTERID = A.MASTERID  
  AND A.PMT_DATE > B.PMTDATE  
 GROUP BY A.MASTERID  
  
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
  ,'DEBUG'  
  ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
  ,'3'  
  )  
  
 --DROP INDEX PSAK_EIR_PAYM_IDX2  
 --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_EIR_PAYM_IDX2 ON IFRS_LI_ACCT_EIR_PAYM(MASTERID,PMT_DATE)';  
 SELECT @VI = COUNT(*)  
 FROM IFRS_LI_ACCT_EIR_ECF_T2  
  
 WHILE @VI > 0  
 BEGIN --LOOP  
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
   ,'DEBUG'  
   ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
   ,'4'  
   )  
  
  TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF1  
  
  -- PREPARE INDEX  
  --EXECUTE IMMEDIATE 'DROP INDEX PSAK_EIR_ECF_T2_IDX1';  
  --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_EIR_ECF_T2_IDX1 ON IFRS_LI_ACCT_EIR_ECF_T2(MASTERID,PMTDATE)';  
  --EXECUTE IMMEDIATE 'DROP INDEX PSAK_EIR_ECF2_IDX1';  
  --EXECUTE IMMEDIATE 'CREATE INDEX PSAK_EIR_ECF2_IDX1 ON IFRS_LI_ACCT_EIR_ECF2(MASTERID)';  
  INSERT INTO IFRS_LI_ACCT_EIR_ECF1 (  
   MASTERID  
   ,DOWNLOAD_DATE  
   ,N_LOAN_AMT  
   ,N_INT_RATE  
   ,N_EFF_INT_RATE  
   ,STARTAMORTDATE  
   ,ENDAMORTDATE  
   ,GRACEDATE  
   ,DISB_PERCENTAGE  
   ,DISB_AMOUNT  
   ,PLAFOND  
   ,PAYMENTCODE  
   ,INTCALCCODE  
   ,PAYMENTTERM  
   ,ISGRACE  
   ,PREV_PMT_DATE  
   ,PMT_DATE  
   ,I_DAYS  
   ,I_DAYS2  
   ,N_OSPRN_PREV  
   ,N_INSTALLMENT  
   ,N_PRN_PAYMENT  
   ,N_INT_PAYMENT  
   ,N_OSPRN  
   ,N_FAIRVALUE_PREV  
   ,N_EFF_INT_AMT  
   ,N_FAIRVALUE  
   ,N_UNAMORT_AMT_PREV  
   ,N_AMORT_AMT  
   ,N_UNAMORT_AMT  
   ,N_COST_UNAMORT_AMT_PREV  
   ,N_COST_AMORT_AMT  
   ,N_COST_UNAMORT_AMT  
   ,N_FEE_UNAMORT_AMT_PREV  
   ,N_FEE_AMORT_AMT  
   ,N_FEE_UNAMORT_AMT  
   ,N_FEE_AMT  
   ,N_COST_AMT  
   )  
  SELECT A.MASTERID  
   ,@V_CURRDATE  
   ,A.N_LOAN_AMT  
   ,A.N_INT_RATE  
   ,C.N_EFF_INT_RATE  
   ,A.STARTAMORTDATE  
   ,A.ENDAMORTDATE  
   ,A.GRACEDATE  
   ,A.DISB_PERCENTAGE  
   ,A.DISB_AMOUNT  
   ,A.PLAFOND  
   ,A.PAYMENTCODE  
   ,A.INTCALCCODE  
   ,A.PAYMENTTERM  
   ,A.ISGRACE  
   ,A.PREV_PMT_DATE  
   ,A.PMT_DATE  
   ,A.I_DAYS  
   ,A.I_DAYS  
   ,A.N_OSPRN_PREV  
   ,A.N_INSTALLMENT  
   ,A.N_PRN_PAYMENT  
   ,A.N_INT_PAYMENT  
   ,A.N_OSPRN  
   ,C.N_FAIRVALUE N_FAIRVALUE_PREV  
   ,ROUND(CASE   
     --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428   
     WHEN A.INTCALCCODE IN (  
       '1'  
       ,'6'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
       --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '2'  
       ,'3'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
     WHEN A.INTCALCCODE = '4'  
      THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
     ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
     END, @V_ROUND, @V_FUNCROUND) AS N_EFF_INT_AMT  
   ,C.N_FAIRVALUE - A.N_PRN_PAYMENT + ROUND(CASE   
     --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '1'  
       ,'6'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
       --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '2'  
       ,'3'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
     WHEN A.INTCALCCODE = '4'  
      THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
     ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
     END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT + A.DISB_AMOUNT AS N_FAIRVALUE  
   ,C.N_UNAMORT_AMT N_UNAMORT_AMT_PREV  
   ,ROUND(CASE   
     --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '1'  
       ,'6'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
       --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '2'  
       ,'3'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
     WHEN A.INTCALCCODE = '4'  
      THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
     ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
     END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT AS N_AMORT_AMT  
   ,C.N_UNAMORT_AMT + ROUND(CASE   
     --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '1'  
       ,'6'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
       --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
     WHEN A.INTCALCCODE IN (  
       '2'  
       ,'3'  
       )  
      THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
     WHEN A.INTCALCCODE = '4'  
      THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
     ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
     END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT AS N_UNAMORT_AMT  
   ,C.N_COST_UNAMORT_AMT N_COST_UNAMORT_AMT_PREV  
   ,CASE   
    WHEN C.N_FEE_AMT + C.N_COST_AMT = 0  
     THEN 0  
    ELSE (  
      ROUND(CASE   
        --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '1'  
          ,'6'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
          --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '2'  
          ,'3'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
        WHEN A.INTCALCCODE = '4'  
         THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
        ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
        END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT  
      ) * C.N_COST_AMT / (C.N_FEE_AMT + C.N_COST_AMT)  
    END AS N_COST_AMORT_AMT  
   ,C.N_COST_UNAMORT_AMT + CASE   
    WHEN C.N_FEE_AMT + C.N_COST_AMT = 0  
     THEN 0  
    ELSE (  
      ROUND(CASE   
        --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '1'  
          ,'6'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
          --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '2'  
          ,'3'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
        WHEN A.INTCALCCODE = '4'  
         THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
        ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
        END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT  
      ) * C.N_COST_AMT / (C.N_FEE_AMT + C.N_COST_AMT)  
    END AS N_COST_UNAMORT_AMT  
   ,C.N_FEE_UNAMORT_AMT N_FEE_UNAMORT_AMT_PREV  
   ,CASE   
    WHEN C.N_FEE_AMT + C.N_COST_AMT = 0  
     THEN 0  
    ELSE (  
      ROUND(CASE   
        --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '1'  
          ,'6'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
          --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '2'  
          ,'3'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
        WHEN A.INTCALCCODE = '4'  
         THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
        ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
        END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT  
      ) * C.N_FEE_AMT / (C.N_FEE_AMT + C.N_COST_AMT)  
    END AS N_FEE_AMORT_AMT  
   ,C.N_FEE_UNAMORT_AMT + CASE   
    WHEN C.N_FEE_AMT + C.N_COST_AMT = 0  
     THEN 0  
    ELSE (  
      ROUND(CASE   
        --WHEN A.INTCALCCODE IN('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '1'  
          ,'6'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
          --WHEN A.INTCALCCODE='3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
        WHEN A.INTCALCCODE IN (  
          '2'  
          ,'3'  
          )  
         THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE  
        WHEN A.INTCALCCODE = '4'  
         THEN C.N_EFF_INT_RATE / C.N_INT_RATE * A.N_INT_PAYMENT  
        ELSE (CAST(30 AS FLOAT) * A.M / CAST(360 AS FLOAT) * C.N_EFF_INT_RATE / 100 * C.N_FAIRVALUE)  
        END, @V_ROUND, @V_FUNCROUND) - A.N_INT_PAYMENT  
      ) * C.N_FEE_AMT / (C.N_FEE_AMT + C.N_COST_AMT)  
    END AS N_FEE_UNAMORT_AMT  
   ,C.N_FEE_AMT  
   ,C.N_COST_AMT  
  FROM IFRS_LI_ACCT_EIR_PAYM A  
  JOIN IFRS_LI_ACCT_EIR_ECF_T2 B ON B.MASTERID = A.MASTERID  
   AND B.PMTDATE = A.PMT_DATE  
  JOIN IFRS_LI_ACCT_EIR_ECF2 C ON C.MASTERID = B.MASTERID  
  
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
   ,'DEBUG'  
   ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
   ,'5'  
   )  
  
  -- INSERT TO ECF  
  INSERT INTO IFRS_LI_ACCT_EIR_ECF_NOCF (  
   MASTERID  
   ,DOWNLOAD_DATE  
   ,N_LOAN_AMT  
   ,N_INT_RATE  
   ,N_EFF_INT_RATE  
   ,STARTAMORTDATE  
   ,ENDAMORTDATE  
   ,GRACEDATE  
   ,DISB_PERCENTAGE  
   ,DISB_AMOUNT  
   ,PLAFOND  
   ,PAYMENTCODE  
   ,INTCALCCODE  
   ,PAYMENTTERM  
   ,ISGRACE  
   ,PREV_PMT_DATE  
   ,PMT_DATE  
   ,I_DAYS  
   ,I_DAYS2  
   ,N_OSPRN_PREV  
   ,N_INSTALLMENT  
   ,N_PRN_PAYMENT  
   ,N_INT_PAYMENT  
   ,N_OSPRN  
   ,N_FAIRVALUE_PREV  
   ,N_EFF_INT_AMT  
   ,N_FAIRVALUE  
   ,N_UNAMORT_AMT_PREV  
   ,N_AMORT_AMT  
   ,N_UNAMORT_AMT  
   ,N_COST_UNAMORT_AMT_PREV  
   ,N_COST_AMORT_AMT  
   ,N_COST_UNAMORT_AMT  
   ,N_FEE_UNAMORT_AMT_PREV  
   ,N_FEE_AMORT_AMT  
   ,N_FEE_UNAMORT_AMT  
   )  
  SELECT MASTERID  
   ,DOWNLOAD_DATE  
   ,N_LOAN_AMT  
   ,N_INT_RATE  
   ,N_EFF_INT_RATE  
   ,STARTAMORTDATE  
   ,ENDAMORTDATE  
   ,GRACEDATE  
   ,DISB_PERCENTAGE  
   ,DISB_AMOUNT  
   ,PLAFOND  
   ,PAYMENTCODE  
   ,INTCALCCODE  
   ,PAYMENTTERM  
   ,ISGRACE  
   ,PREV_PMT_DATE  
   ,PMT_DATE  
   ,I_DAYS  
   ,DATEDIFF(DD, PREV_PMT_DATE, PMT_DATE) AS I_DAYS2  
   ,N_OSPRN_PREV  
   ,N_INSTALLMENT  
   ,N_PRN_PAYMENT  
   ,N_INT_PAYMENT  
   ,N_OSPRN  
   ,N_FAIRVALUE_PREV  
   ,N_EFF_INT_AMT  
   ,N_FAIRVALUE  
   ,N_UNAMORT_AMT_PREV  
   ,N_AMORT_AMT  
   ,N_UNAMORT_AMT  
   ,N_COST_UNAMORT_AMT_PREV  
   ,N_COST_AMORT_AMT  
   ,N_COST_UNAMORT_AMT  
   ,N_FEE_UNAMORT_AMT_PREV  
   ,N_FEE_AMORT_AMT  
   ,N_FEE_UNAMORT_AMT  
  FROM IFRS_LI_ACCT_EIR_ECF1  
  
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
   ,'DEBUG'  
   ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
   ,'6'  
   )  
  
  -- INSERT TO ECF2  
  TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF2  
  
  INSERT INTO IFRS_LI_ACCT_EIR_ECF2 (  
   MASTERID  
   ,DOWNLOAD_DATE  
   ,N_LOAN_AMT  
   ,N_INT_RATE  
   ,N_EFF_INT_RATE  
   ,STARTAMORTDATE  
   ,ENDAMORTDATE  
   ,GRACEDATE  
   ,DISB_PERCENTAGE  
   ,DISB_AMOUNT  
   ,PLAFOND  
   ,PAYMENTCODE  
   ,INTCALCCODE  
   ,PAYMENTTERM  
   ,ISGRACE  
   ,PREV_PMT_DATE  
   ,PMT_DATE  
   ,I_DAYS  
   ,I_DAYS2  
   ,N_OSPRN_PREV  
   ,N_INSTALLMENT  
   ,N_PRN_PAYMENT  
   ,N_INT_PAYMENT  
   ,N_OSPRN  
   ,N_FAIRVALUE_PREV  
   ,N_EFF_INT_AMT  
   ,N_FAIRVALUE  
   ,N_UNAMORT_AMT_PREV  
   ,N_AMORT_AMT  
   ,N_UNAMORT_AMT  
   ,N_COST_UNAMORT_AMT_PREV  
   ,N_COST_AMORT_AMT  
   ,N_COST_UNAMORT_AMT  
   ,N_FEE_UNAMORT_AMT_PREV  
   ,N_FEE_AMORT_AMT  
   ,N_FEE_UNAMORT_AMT  
   ,N_FEE_AMT  
   ,N_COST_AMT  
   )  
  SELECT MASTERID  
   ,DOWNLOAD_DATE  
   ,N_LOAN_AMT  
   ,N_INT_RATE  
   ,N_EFF_INT_RATE  
   ,STARTAMORTDATE  
   ,ENDAMORTDATE  
   ,GRACEDATE  
   ,DISB_PERCENTAGE  
   ,DISB_AMOUNT  
   ,PLAFOND  
   ,PAYMENTCODE  
   ,INTCALCCODE  
   ,PAYMENTTERM  
   ,ISGRACE  
   ,PREV_PMT_DATE  
   ,PMT_DATE  
   ,I_DAYS  
   ,I_DAYS2  
   ,N_OSPRN_PREV  
   ,N_INSTALLMENT  
   ,N_PRN_PAYMENT  
   ,N_INT_PAYMENT  
   ,N_OSPRN  
   ,N_FAIRVALUE_PREV  
   ,N_EFF_INT_AMT  
   ,N_FAIRVALUE  
   ,N_UNAMORT_AMT_PREV  
   ,N_AMORT_AMT  
   ,N_UNAMORT_AMT  
   ,N_COST_UNAMORT_AMT_PREV  
   ,N_COST_AMORT_AMT  
   ,N_COST_UNAMORT_AMT  
   ,N_FEE_UNAMORT_AMT_PREV  
   ,N_FEE_AMORT_AMT  
   ,N_FEE_UNAMORT_AMT  
   ,N_FEE_AMT  
   ,N_COST_AMT  
  FROM IFRS_LI_ACCT_EIR_ECF1  
  
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
   ,'DEBUG'  
   ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
   ,'7'  
   )  
  
  -- NEXT CYCLE PREPARE #T2  
  TRUNCATE TABLE IFRS_LI_ACCT_EIR_ECF_T2  
  
  INSERT INTO IFRS_LI_ACCT_EIR_ECF_T2 (  
   MASTERID  
   ,PMTDATE  
   )  
  SELECT A.MASTERID  
   ,MIN(A.PMT_DATE) AS PMTDATE  
  FROM IFRS_LI_ACCT_EIR_PAYM A  
  JOIN IFRS_LI_ACCT_EIR_ECF1 B ON B.MASTERID = A.MASTERID  
   AND A.PMT_DATE > B.PMT_DATE  
  GROUP BY A.MASTERID  
  
  -- ASSIGN VAR @I  
  SELECT @VI = COUNT(*)  
  FROM IFRS_LI_ACCT_EIR_ECF_T2  
  
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
   ,'DEBUG'  
   ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
   ,'8'  
   )  
 END --LOOP;  
  
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
  ,'SP_IFRS_LI_ACCT_EIR_GS_ECF_INSER4'  
  ,''  
  )  
END  

GO
