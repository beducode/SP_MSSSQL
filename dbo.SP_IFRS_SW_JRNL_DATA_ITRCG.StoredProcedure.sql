USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SW_JRNL_DATA_ITRCG]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SW_JRNL_DATA_ITRCG]  
AS  
DECLARE @V_CURRDATE DATE  
 ,@V_PREVDATE DATE  
 ,@VMAX_INTMID BIGINT  
 ,@VMIN_SWID BIGINT  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,''  
  )  
  
 DELETE  
 FROM IFRS_ACCT_JOURNAL_DATA  
 WHERE DOWNLOAD_DATE >= @V_CURRDATE  
  AND CREATEDBY LIKE 'SW_%'  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'CLEAN UP'  
  )  
  
 -- USE MAX INTMID + 1 FROM INTM JOURNAL AS STARTING INTMID ON JOURNAL DATA FOR SWITCH JOURNAL  
 SELECT @VMAX_INTMID = MAX(ID)  
 FROM IFRS_ACCT_JOURNAL_INTM  
  
 SELECT @VMIN_SWID = MIN(ID)  
 FROM IFRS_ACCT_SWITCH  
 WHERE DOWNLOAD_DATE = @V_CURRDATE  
  
 -- INTMID = @MAX_INTMID - @MIN_SWID + 1 + SWID  
 -- GET GL NO CREDIT FOR ITRCG --SELECT * FROM TMP_SW0  
 TRUNCATE TABLE TMP_SW0  
  
 INSERT INTO TMP_SW0 (  
  FACNO  
  ,CIFNO  
  ,ACCTNO  
  ,BRCODE  
  ,PRDTYPE  
  ,PRDCODE  
  ,DATASOURCE  
  ,MASTERID  
  ,PREV_ACCTNO  
  ,PREV_FACNO  
  ,PREV_CIFNO  
  ,PREV_BRCODE  
  ,PREV_PRDTYPE  
  ,PREV_PRDCODE  
  ,PREV_DATASOURCE  
  ,PREV_MASTERID  
  ,PREV_SL_ECF  
  ,PREV_EIR_ECF  
  ,METHOD  
  ,CCY  
  ,COSTCENTER  
  ,GLNOPREVCR  
  ,GLNOPREVDR  
  ,GLNOCURRCR  
  ,GLNOCURRDR  
  ,GLNOPREVCR2  
  ,GLNOPREVDR2  
  ,GLNOCURRCR2  
  ,GLNOCURRDR2  
  ,GL_INTERNAL_CODE_REVCR  
  ,GL_INTERNAL_CODE_PREVDR  
  ,GL_INTERNAL_CODE_CURRCR  
  ,GL_INTERNAL_CODE_CURRDR  
  ,GL_INTERNAL_CODE_PREVCR2  
  ,GL_INTERNAL_CODE_PREVDR2  
  ,GL_INTERNAL_CODE_CURRCR2  
  ,GL_INTERNAL_CODE_CURRDR2  
  )  
 SELECT SW.FACNO  
  ,SW.CIFNO  
  ,SW.ACCTNO  
  ,SW.BRCODE  
  ,SW.PRDTYPE  
  ,SW.PRDCODE  
  ,SW.DATASOURCE  
  ,SW.MASTERID  
  ,SW.PREV_ACCTNO  
  ,SW.PREV_FACNO  
  ,SW.PREV_CIFNO  
  ,SW.PREV_BRCODE  
  ,SW.PREV_PRDTYPE  
  ,SW.PREV_PRDCODE  
  ,SW.PREV_DATASOURCE  
  ,SW.PREV_MASTERID  
  ,SW.PREV_SL_ECF  
  ,SW.PREV_EIR_ECF  
  ,SW.METHOD  
  ,SW.CCY  
  ,JPREV2.COSTCENTER  
  ,JPREV.GLNO AS GLNOPREVCR  
  ,JPREV2.GLNO AS GLNOPREVDR  
  ,--  
  JCURR.GLNO AS GLNOCURRCR  
  ,JCURR2.GLNO AS GLNOCURRDR  
  ,JPREVB.GLNO AS GLNOPREVCR2  
  ,--  
  JPREV2B.GLNO AS GLNOPREVDR2  
  ,JCURRB.GLNO AS GLNOCURRCR2  
  ,JCURR2B.GLNO AS GLNOCURRDR2  
  ,JPREV.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_REVCR  
  ,JPREV2.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_PREVDR  
  ,JCURR.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_CURRCR  
  ,JCURR2.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_CURRDR  
  ,JPREVB.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_PREVCR2  
  ,JPREV2B.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_PREVDR2  
  ,JCURRB.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_CURRCR2  
  ,JCURR2B.GL_INTERNAL_CODE AS GL_INTERNAL_CODE_CURRDR2  
 FROM IFRS_ACCT_SWITCH SW  
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON SW.MASTERID = IMC.MASTERID  
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON SW.PREV_MASTERID = IMP.MASTERID  
 LEFT JOIN IFRS_ACCT_JOURNAL_INTM A ON A.MASTERID = IMC.MASTERID  
  AND A.MASTERID = IMP.MASTERID  
 JOIN IFRS_JOURNAL_PARAM JPREV ON JPREV.CCY = SW.CCY  
  AND JPREV.JOURNALCODE = 'ITRCG1'  
  AND JPREV.FLAG_CF = 'F'  
  AND JPREV.DRCR = 'C'  
  AND JPREV.GL_CONSTNAME = IMP.GL_CONSTNAME  
  AND JPREV.TRX_CODE = A.TRXCODE  
 /*SELECT * FROM IFRS_JOURNAL_PARAM  
                        JOIN IFRS_JOURNAL_PARAM JPREV ON JPREV.DATASOURCE = SW.PREV_DATASOURCE  
                                                         AND JPREV.CCY = SW.CCY  
                                                         AND JPREV.DRCR = 'C'  
                                    AND JPREV.JOURNALCODE = 'ITRCG1'  
                                                         AND JPREV.PRDTYPE = SW.PREV_PRDTYPE  
                                                         AND SW.PREV_PRDCODE = JPREV.PRDCODE  
             AND JPREV.FLAG_CF = 'F'  
                                                         AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JPREV.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JPREV2 ON JPREV2.CCY = SW.CCY  
  AND JPREV2.JOURNALCODE = 'ITRCG1'  
  AND JPREV2.FLAG_CF = 'F'  
  AND JPREV2.DRCR = 'D'  
  AND JPREV2.GL_CONSTNAME = IMP.GL_CONSTNAME  
  AND JPREV2.TRX_CODE = A.TRXCODE  
 /*  
     --AND JPREV.SEQ='1'  
                        JOIN IFRS_JOURNAL_PARAM JPREV2 ON JPREV2.DATASOURCE = SW.PREV_DATASOURCE  
                                                          AND JPREV2.CCY = SW.CCY  
                                                          AND JPREV2.DRCR = 'D'  
                                                          AND JPREV2.JOURNALCODE = 'ITRCG1'  
                                                          AND JPREV2.PRDTYPE = SW.PREV_PRDTYPE  
                                                          AND SW.PREV_PRDCODE = JPREV2.PRDCODE  
                                                          AND JPREV2.FLAG_CF = 'F'                 
  
                   --AND JPREV2.SEQ='1'  
                                                          AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JPREV2.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JCURR ON JCURR.CCY = SW.CCY  
  AND JCURR.JOURNALCODE = 'ITRCG1'  
  AND JCURR.FLAG_CF = 'F'  
  AND JCURR.DRCR = 'C'  
  AND JCURR.GL_CONSTNAME = IMC.GL_CONSTNAME  
  AND JCURR.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JCURR ON JCURR.DATASOURCE = SW.DATASOURCE  
                                                         AND JCURR.CCY = SW.CCY  
                                                         AND JCURR.DRCR = 'C'  
                                                         AND JCURR.JOURNALCODE = 'ITRCG1'  
                                                         AND SW.PRDTYPE = JCURR.PRDTYPE  
                                                         AND SW.PRDCODE = JCURR.PRDCODE  
                                                         AND JCURR.FLAG_CF = 'F'                   
  
                   --AND JCURR.SEQ='1'  
                                                         AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JCURR.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JCURR2 ON JCURR2.CCY = SW.CCY  
  AND JCURR2.JOURNALCODE = 'ITRCG1'  
  AND JCURR2.FLAG_CF = 'F'  
  AND JCURR2.DRCR = 'D'  
  AND JCURR2.GL_CONSTNAME = IMC.GL_CONSTNAME  
  AND JCURR2.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JCURR2 ON JCURR2.DATASOURCE = SW.DATASOURCE  
                                                          AND JCURR2.CCY = SW.CCY  
                                                          AND JCURR2.DRCR = 'D'  
                                                          AND JCURR2.JOURNALCODE = 'ITRCG1'  
                                                          AND SW.PRDTYPE = JCURR2.PRDTYPE  
                                                          AND SW.PRDCODE = JCURR2.PRDCODE  
                                                          AND JCURR2.FLAG_CF = 'F'                 
  
                   --AND JCURR2.SEQ='1'  
                                         AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JCURR2.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JPREVB ON JPREVB.CCY = SW.CCY  
  AND JPREVB.JOURNALCODE = 'ITRCG1'  
  AND JPREVB.FLAG_CF = 'C'  
  AND JPREVB.DRCR = 'C'  
  AND JPREVB.GL_CONSTNAME = IMP.GL_CONSTNAME  
  AND JPREVB.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JPREVB ON JPREVB.DATASOURCE = SW.PREV_DATASOURCE  
                                                          AND JPREVB.CCY = SW.CCY  
                                                          AND JPREVB.DRCR = 'C'  
                                                          AND JPREVB.JOURNALCODE = 'ITRCG1'  
                                                          AND SW.PREV_PRDTYPE = JPREVB.PRDTYPE  
                                                          AND SW.PREV_PRDCODE = JPREVB.PRDCODE  
                                                          AND JPREVB.FLAG_CF = 'C'                 
  
                   --AND JPREVB.SEQ='1'  
                                                          AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JPREVB.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JPREV2B ON JPREV2B.CCY = SW.CCY  
  AND JPREV2B.JOURNALCODE = 'ITRCG1'  
  AND JPREV2B.FLAG_CF = 'C'  
  AND JPREV2B.DRCR = 'D'  
  AND JPREV2B.GL_CONSTNAME = IMP.GL_CONSTNAME  
  AND JPREV2B.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JPREV2B ON JPREV2B.DATASOURCE = SW.PREV_DATASOURCE  
                                                           AND JPREV2B.CCY = SW.CCY  
                                                           AND JPREV2B.DRCR = 'D'  
                                                           AND JPREV2B.JOURNALCODE = 'ITRCG1'  
                                                           AND SW.PREV_PRDTYPE = JPREV2B.PRDTYPE  
                                                           AND SW.PREV_PRDCODE = JPREV2B.PRDCODE  
                                                           AND JPREV2B.FLAG_CF = 'F'               
  
                   --AND JPREV2B.SEQ='1'  
                                                           AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JPREV2B.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JCURRB ON JCURRB.CCY = SW.CCY  
  AND JCURRB.JOURNALCODE = 'ITRCG1'  
  AND JCURRB.FLAG_CF = 'C'  
  AND JCURRB.DRCR = 'C'  
  AND JCURRB.GL_CONSTNAME = IMC.GL_CONSTNAME  
  AND JCURRB.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JCURRB ON JCURRB.DATASOURCE = SW.DATASOURCE  
                                                          AND JCURRB.CCY = SW.CCY  
                                                          AND JCURRB.DRCR = 'C'  
                                                          AND JCURRB.JOURNALCODE = 'ITRCG1'  
                                                          AND SW.PRDTYPE = JCURRB.PRDTYPE  
                                                          AND SW.PRDCODE = JCURRB.PRDCODE  
                                                          AND JCURRB.FLAG_CF = 'F'                 
  
                   --AND JCURRB.SEQ='1'  
                                                          AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JCURRB.BRANCH_CODE  
      */  
 JOIN IFRS_JOURNAL_PARAM JCURR2B ON JCURR2B.CCY = SW.CCY  
  AND JCURR2B.JOURNALCODE = 'ITRCG1'  
  AND JCURR2B.FLAG_CF = 'C'  
  AND JCURR2B.DRCR = 'D'  
  AND JCURR2B.GL_CONSTNAME = IMC.GL_CONSTNAME  
  AND JCURR2B.TRX_CODE = A.TRXCODE  
 /*  
                        JOIN IFRS_JOURNAL_PARAM JCURR2B ON JCURR2B.DATASOURCE = SW.DATASOURCE  
                                                           AND JCURR2B.CCY = SW.CCY  
                                                           AND JCURR2B.DRCR = 'D'  
                      AND JCURR2B.JOURNALCODE = 'ITRCG1'  
                                                           AND SW.PRDTYPE = JCURR2B.PRDTYPE  
                                                           AND SW.PRDCODE = JCURR2B.PRDCODE  
                                                           AND JCURR2B.FLAG_CF = 'F'     
                        --AND JCURR2B.SEQ='1'  
                                                           AND SUBSTRING(SW.PREV_BRCODE,  
                                                              LEN(SW.PREV_BRCODE)  
                                                              - 2, 3) = JCURR2B.BRANCH_CODE  
             */  
 WHERE SW.DOWNLOAD_DATE = @V_CURRDATE  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'TMP SW0'  
  )  
  
 -- CREATE INTM PREV ACCOUNT SL  
 TRUNCATE TABLE TMP_SWSL1  
  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,A.DOWNLOAD_DATE  
  ,A.DATASOURCE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'N' REVERSE  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * A.AMOUNT  
    ELSE A.AMOUNT  
    END  
   ) N_AMOUNT  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * (A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1))  
    ELSE A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1)  
    END  
   ) N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_SL_JOURNAL' SOURCEPROCESS  
  ,SW.PREV_ACCTNO AS ACCTNO  
  ,SW.PREV_MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,SW.PREV_BRCODE AS BRANCH  
  ,A.PRDTYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACCT_SL_COST_FEE_PREV A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.STATUS = 'ACT'  
  AND A.SEQ = '0'  
  
 --JOURNAL SL BARU  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,SW.DOWNLOAD_DATE  
  ,A.DATA_SOURCE  
  ,A.PRD_CODE  
  ,A.TRX_CODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'Y' REVERSE  
  ,UNAMORT_VALUE AS N_AMOUNT  
  ,UNAMORT_VALUE AS N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_SL_JOURNAL' SOURCEPROCESS  
  ,SW.PREV_ACCTNO AS ACCTNO  
  ,SW.PREV_MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,SW.PREV_BRCODE AS BRANCH  
  ,B.PRODUCT_TYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACF_SL_MSTR A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 JOIN IFRS_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID  
  AND A.EFFDATE = B.DOWNLOAD_DATE  
 WHERE A.EFFDATE = @V_PREVDATE  
  AND A.IFRS_STATUS = 'ACT'  
  
 UPDATE DBO.TMP_SWSL1  
 SET FLAG_AL = B.IAS_CLASS  
 FROM IFRS_IMA_AMORT_CURR B  
 WHERE DBO.TMP_SWSL1.MASTERID = B.MASTERID  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM SL 1'  
  )  
  
 --INSERT TO JOURNAL DATA  
 INSERT INTO IFRS_ACCT_JOURNAL_DATA (  
  DOWNLOAD_DATE  
  ,MASTERID  
  ,FACNO  
  ,CIFNO  
  ,ACCTNO  
  ,DATASOURCE  
  ,PRDTYPE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,FLAG_CF  
  ,DRCR  
  ,GLNO  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,SOURCEPROCESS  
  ,INTMID  
  ,CREATEDDATE  
  ,CREATEDBY  
  ,BRANCH  
  ,JOURNALCODE2  
  ,JOURNAL_DESC  
  ,VALCTR_CODE  
  ,METHOD 
  ,ACCOUNT_TYPE  
,CUSTOMER_TYPE   
  )  
 SELECT A.DOWNLOAD_DATE  
  ,A.MASTERID  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.ACCTNO  
  ,A.DATASOURCE  
  ,A.PRDTYPE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,A.JOURNALCODE  
  ,A.STATUS  
  ,A.REVERSE  
  ,A.FLAG_CF  
  ,CASE   
   WHEN (  
     A.REVERSE = 'N'  
     AND A.FLAG_AL IN ('A', 'O')  
     )  
    OR (  
     A.REVERSE = 'Y'  
     AND A.FLAG_AL NOT IN ('A', 'O')
     )  
    THEN CASE   
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      END  
   ELSE CASE   
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     END  
   END AS DRCR  
  ,CASE   
   WHEN A.FLAG_CF = 'F'  
    THEN B.GLNOPREVDR  
   ELSE B.GLNOPREVCR2  
   END  
  ,ABS(A.N_AMOUNT)  
  ,ABS(A.N_AMOUNT_IDR)  
  ,A.SOURCEPROCESS  
  ,A.INTMID  
  ,CURRENT_TIMESTAMP  
  ,'SW_SL_JOURNAL_1'  
  ,A.BRANCH  
  ,A.JOURNALCODE2  
  ,'' JOURNAL_DESC  
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')  
  ,'SL'  
  ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE  
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE  
 FROM TMP_SWSL1 A  
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID  
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID  
 JOIN TMP_SW0 B ON B.PREV_MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.JOURNALCODE = 'DEFA0'  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM SL 1 DATA'  
  )  
  
 -- CREATE INTM CURR ACCOUNT SL  
 TRUNCATE TABLE TMP_SWSL1  
  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,A.DOWNLOAD_DATE  
  ,A.DATASOURCE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'N' REVERSE  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * A.AMOUNT  
    ELSE A.AMOUNT  
    END  
   ) N_AMOUNT  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * (A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1))  
    ELSE A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1)  
    END  
   ) AS N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_SL_JOURNAL' SOURCEPROCESS  
  ,A.ACCTNO  
  ,A.MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,A.BRCODE AS BRANCH  
  ,A.PRDTYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACCT_SL_COST_FEE_PREV A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.STATUS = 'ACT'  
  AND A.SEQ = '0'  
  
 --JOURNAL SL BARU  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,SW.DOWNLOAD_DATE  
  ,A.DATA_SOURCE  
  ,A.PRD_CODE  
  ,A.TRX_CODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'N' REVERSE  
  ,UNAMORT_VALUE AS N_AMOUNT  
  ,UNAMORT_VALUE AS N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_SL_JOURNAL' SOURCEPROCESS  
  ,A.MASTERID  
  ,A.MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,SW.BRCODE AS BRANCH  
  ,B.PRODUCT_TYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACF_SL_MSTR A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 JOIN IFRS_MASTER_ACCOUNT B ON A.MASTERID = B.MASTERID  
  AND A.EFFDATE = B.DOWNLOAD_DATE  
 WHERE A.EFFDATE = @V_PREVDATE  
  AND A.IFRS_STATUS = 'ACT'  
  
 UPDATE DBO.TMP_SWSL1  
 SET FLAG_AL = B.IAS_CLASS  
 FROM IFRS_IMA_AMORT_CURR B  
 WHERE DBO.TMP_SWSL1.MASTERID = B.MASTERID  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM SL 2'  
  )  
  
 --INSERT TO JOURNAL DATA  
 INSERT INTO IFRS_ACCT_JOURNAL_DATA (  
  DOWNLOAD_DATE  
  ,MASTERID  
  ,FACNO  
  ,CIFNO  
  ,ACCTNO  
  ,DATASOURCE  
  ,PRDTYPE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,FLAG_CF  
  ,DRCR  
  ,GLNO  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,SOURCEPROCESS  
  ,INTMID  
  ,CREATEDDATE  
  ,CREATEDBY  
  ,BRANCH  
  ,JOURNALCODE2  
  ,JOURNAL_DESC  
  ,VALCTR_CODE  
  ,METHOD  
    ,ACCOUNT_TYPE  
,CUSTOMER_TYPE   
  )  
 SELECT A.DOWNLOAD_DATE  
  ,A.MASTERID  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.ACCTNO  
  ,A.DATASOURCE  
  ,A.PRDTYPE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,A.JOURNALCODE  
  ,A.STATUS  
  ,A.REVERSE  
  ,A.FLAG_CF  
  ,CASE   
   WHEN (  
     A.REVERSE = 'N'  
     AND A.FLAG_AL IN ('A', 'O')
     )  
    OR (  
     A.REVERSE = 'Y'  
     AND A.FLAG_AL NOT IN ('A', 'O')
     )  
    THEN CASE   
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      END  
   ELSE CASE   
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT >= 0  
   AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     END  
   END AS DRCR  
  ,CASE   
   WHEN A.FLAG_CF = 'F'  
    THEN B.GLNOCURRDR  
   ELSE B.GLNOCURRCR2  
   END  
  ,ABS(A.N_AMOUNT)  
  ,ABS(A.N_AMOUNT_IDR)  
  ,A.SOURCEPROCESS  
  ,A.INTMID  
  ,CURRENT_TIMESTAMP  
  ,'SW_SL_JOURNAL_2'  
  ,A.BRANCH  
  ,A.JOURNALCODE2  
  ,'' JOURNAL_DESC  
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')  
  ,'SL'  
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE  
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE 
 FROM TMP_SWSL1 A  
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID  
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID  
 JOIN TMP_SW0 B ON B.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.JOURNALCODE = 'DEFA0'  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM SL 2 DATA'  
  )  
  
 -- CREATE INTM PREV ACCOUNT EIR  
 TRUNCATE TABLE TMP_SWSL1  
  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,A.DOWNLOAD_DATE  
  ,A.DATASOURCE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'N' REVERSE  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * A.AMOUNT  
    ELSE A.AMOUNT  
    END  
   ) N_AMOUNT  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * (A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1))  
    ELSE A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1)  
    END  
   ) N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_EIR_JOURNAL' SOURCEPROCESS  
  ,SW.PREV_ACCTNO AS ACCTNO  
  ,SW.PREV_MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,SW.PREV_BRCODE AS BRANCH  
  ,A.PRDTYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACCT_EIR_COST_FEE_PREV A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.STATUS = 'ACT'  
  AND A.SEQ = '0'  
  
 UPDATE DBO.TMP_SWSL1  
 SET FLAG_AL = B.IAS_CLASS  
 FROM IFRS_IMA_AMORT_CURR B  
 WHERE DBO.TMP_SWSL1.MASTERID = B.MASTERID  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM EIR 1'  
  )  
  
 --INSERT TO JOURNAL DATA  
 INSERT INTO IFRS_ACCT_JOURNAL_DATA (  
  DOWNLOAD_DATE  
  ,MASTERID  
  ,FACNO  
  ,CIFNO  
  ,ACCTNO  
  ,DATASOURCE  
  ,PRDTYPE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,FLAG_CF  
  ,DRCR  
  ,GLNO  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,SOURCEPROCESS  
  ,INTMID  
  ,CREATEDDATE  
  ,CREATEDBY  
  ,BRANCH  
  ,JOURNALCODE2  
  ,JOURNAL_DESC  
  ,VALCTR_CODE  
  ,METHOD  
    ,ACCOUNT_TYPE  
,CUSTOMER_TYPE   
  )  
 SELECT A.DOWNLOAD_DATE  
  ,A.MASTERID  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.ACCTNO  
  ,A.DATASOURCE  
  ,A.PRDTYPE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,A.JOURNALCODE  
  ,A.STATUS  
  ,A.REVERSE  
  ,A.FLAG_CF  
  ,CASE   
   WHEN (  
     A.REVERSE = 'N'  
     AND A.FLAG_AL IN ('A', 'O') 
     )  
    OR (  
     A.REVERSE = 'Y'  
     AND A.FLAG_AL NOT IN ('A', 'O')
     )  
    THEN CASE   
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      END  
   ELSE CASE   
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     END  
   END AS DRCR  
  ,CASE   
   WHEN A.FLAG_CF = 'F'  
    THEN B.GLNOPREVDR  
   ELSE B.GLNOPREVCR2  
   END  
  ,ABS(A.N_AMOUNT)  
  ,ABS(A.N_AMOUNT_IDR)  
  ,A.SOURCEPROCESS  
  ,A.INTMID  
  ,CURRENT_TIMESTAMP  
  ,'SW_EIR_JOURNAL_1'  
  ,A.BRANCH  
  ,A.JOURNALCODE2  
  ,'' JOURNAL_DESC  
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')  
  ,'EIR'  
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE  
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE 
 FROM TMP_SWSL1 A  
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID  
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID  
 JOIN TMP_SW0 B ON B.PREV_MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.JOURNALCODE = 'DEFA0'  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM EIR 1 DATA'  
  )  
  
 -- CREATE INTM CURR ACCOUNT EIR  
 TRUNCATE TABLE TMP_SWSL1  
  
 INSERT INTO TMP_SWSL1 (  
  FACNO  
  ,CIFNO  
  ,DOWNLOAD_DATE  
  ,DATASOURCE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,CREATEDDATE  
  ,SOURCEPROCESS  
  ,ACCTNO  
  ,MASTERID  
  ,FLAG_CF  
  ,BRANCH  
  ,PRDTYPE  
  ,JOURNALCODE2  
  ,INTMID  
  )  
 SELECT A.FACNO  
  ,A.CIFNO  
  ,A.DOWNLOAD_DATE  
  ,A.DATASOURCE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,'DEFA0' JOURNALCODE  
  ,'ACT' STATUS  
  ,'N' REVERSE  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * A.AMOUNT  
    ELSE A.AMOUNT  
    END  
   ) N_AMOUNT  
  ,1 * (  
   CASE   
    WHEN A.FLAG_REVERSE = 'Y'  
     THEN - 1 * (A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1))  
    ELSE A.AMOUNT * COALESCE(A.ORG_CCY_EXRATE, 1)  
    END  
   ) N_AMOUNT_IDR  
  ,CURRENT_TIMESTAMP CREATEDDATE  
  ,'SW_EIR_JOURNAL' SOURCEPROCESS  
  ,A.ACCTNO  
  ,A.MASTERID AS MASTERID  
  ,A.FLAG_CF  
  ,A.BRCODE AS BRANCH  
  ,A.PRDTYPE  
  ,'ITRCG1' AS JOURNALCODE2  
  ,(@VMAX_INTMID - @VMIN_SWID + 1 + SW.ID) AS INTMID  
 FROM IFRS_ACCT_EIR_COST_FEE_PREV A  
 JOIN IFRS_ACCT_SWITCH SW ON SW.DOWNLOAD_DATE = @V_CURRDATE  
  AND SW.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.STATUS = 'ACT'  
  AND A.SEQ = '0'  
  
 UPDATE DBO.TMP_SWSL1  
 SET FLAG_AL = B.IAS_CLASS  
 FROM IFRS_IMA_AMORT_CURR B  
 WHERE DBO.TMP_SWSL1.MASTERID = B.MASTERID  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM EIR 2'  
  )  
  
 --INSERT TO JOURNAL DATA  
 INSERT INTO IFRS_ACCT_JOURNAL_DATA (  
  DOWNLOAD_DATE  
  ,MASTERID  
  ,FACNO  
  ,CIFNO  
  ,ACCTNO  
  ,DATASOURCE  
  ,PRDTYPE  
  ,PRDCODE  
  ,TRXCODE  
  ,CCY  
  ,JOURNALCODE  
  ,STATUS  
  ,REVERSE  
  ,FLAG_CF  
  ,DRCR  
  ,GLNO  
  ,N_AMOUNT  
  ,N_AMOUNT_IDR  
  ,SOURCEPROCESS  
  ,INTMID  
  ,CREATEDDATE  
  ,CREATEDBY  
  ,BRANCH  
  ,JOURNALCODE2  
  ,JOURNAL_DESC  
  ,VALCTR_CODE  
  ,METHOD  
    ,ACCOUNT_TYPE  
,CUSTOMER_TYPE   

  )  
 SELECT A.DOWNLOAD_DATE  
  ,A.MASTERID  
  ,A.FACNO  
  ,A.CIFNO  
  ,A.ACCTNO  
  ,A.DATASOURCE  
  ,A.PRDTYPE  
  ,A.PRDCODE  
  ,A.TRXCODE  
  ,A.CCY  
  ,A.JOURNALCODE  
  ,A.STATUS  
  ,A.REVERSE  
  ,A.FLAG_CF  
  ,CASE   
   WHEN (  
     A.REVERSE = 'N'  
     AND A.FLAG_AL IN ('A', 'O')
     )  
    OR (  
     A.REVERSE = 'Y'  
     AND A.FLAG_AL NOT IN ('A', 'O')
     )  
    THEN CASE   
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT >= 0  
       AND A.FLAG_CF = 'F'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'D'  
      WHEN A.N_AMOUNT <= 0  
       AND A.FLAG_CF = 'C'  
       AND A.JOURNALCODE IN ('DEFA0')  
       THEN 'C'  
      END  
   ELSE CASE   
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT >= 0  
      AND A.FLAG_CF = 'F'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'C'  
     WHEN A.N_AMOUNT <= 0  
      AND A.FLAG_CF = 'C'  
      AND A.JOURNALCODE IN ('DEFA0')  
      THEN 'D'  
     END  
   END AS DRCR  
  ,CASE   
   WHEN A.FLAG_CF = 'F'  
    THEN B.GLNOCURRDR  
   ELSE B.GLNOCURRCR2  
   END  
  ,ABS(A.N_AMOUNT)  
  ,ABS(A.N_AMOUNT_IDR)  
  ,A.SOURCEPROCESS  
  ,A.INTMID  
  ,CURRENT_TIMESTAMP  
  ,'SW_EIR_JOURNAL_2'  
  ,A.BRANCH  
  ,A.JOURNALCODE2  
  ,'' JOURNAL_DESC  
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')  
  ,'EIR'  
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE  
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE 
 FROM TMP_SWSL1 A  
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID  
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID  
 JOIN TMP_SW0 B ON B.MASTERID = A.MASTERID  
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  AND A.JOURNALCODE = 'DEFA0'  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,'INTM EIR 2 DATA'    )  
  
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
  ,'SP_IFRS_SW_JOURNAL_DATA_ITRCG'  
  ,''  
  )  
END 
GO
