USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_JRNL_DATA_SL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_JRNL_DATA_SL]        
AS        
DECLARE @V_CURRDATE DATE        
 ,@V_PREVDATE DATE        
        
BEGIN        
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
  ,'DEBUG'        
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA_SL'        
  ,'CLEAN UP'        
  )        
        
 UPDATE IFRS_LI_ACCT_JOURNAL_INTM        
 SET METHOD = 'SL'        
 WHERE DOWNLOAD_DATE = @V_CURRDATE        
  AND SUBSTRING(SOURCEPROCESS, 1, 2) = 'SL'        
        
 -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION        
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (        
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
  ,NOREF        
  ,VALCTR_CODE        
  ,GL_INTERNAL_CODE        
  ,METHOD       
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
     AND COALESCE(A.FLAG_AL, 'A') = 'A'        
     )        
    OR (        
     A.REVERSE = 'Y'        
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'        
     )        
    THEN CASE         
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      ELSE CASE         
        WHEN B.DRCR = 'D'        
         THEN 'C'        
        ELSE 'D'        
        END        
      END        
   ELSE CASE         
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     ELSE CASE         
       WHEN B.DRCR = 'D'        
        THEN 'C'        
       ELSE 'D'        
       END        
     END        
   END AS DRCR        
  ,B.GLNO        
  ,ABS(A.N_AMOUNT)        
  ,ABS(A.N_AMOUNT_IDR)        
  ,A.SOURCEPROCESS        
  ,A.ID        
  ,CURRENT_TIMESTAMP        
  ,'SP_JOURNAL_DATA_SL'        
  ,A.BRANCH        
  ,        
  --SUBSTRING (A.BRANCH, LEN (A.BRANCH) - 2, 3) AS BRANCH_CODE,        
  B.JOURNALCODE        
  ,--A.JOURNALCODE2 ,        
  B.JOURNAL_DESC        
  ,B.JOURNALCODE        
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')        
  ,B.GL_INTERNAL_CODE        
  ,METHOD       
 FROM IFRS_LI_ACCT_JOURNAL_INTM A        
 LEFT JOIN IFRS_LI_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE        
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID        
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID        
 JOIN IFRS_LI_JOURNAL_PARAM B ON (        
   B.CCY = A.CCY        
   OR B.CCY = 'ALL'        
   )        
  AND B.JOURNALCODE IN ('ITRCG_SL', 'ITRCG1_SL','ITRCG_SL2', 'ITRCG_NE')        
  AND B.JOURNALCODE = A.JOURNALCODE2      
 -- AND B.JOURNALCODE = 'ITRCG' --- ONLY CTBC        
  AND B.FLAG_CF = A.FLAG_CF        
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')        
  AND (        
   A.TRXCODE = B.TRX_CODE        
   OR B.TRX_CODE = 'ALL'        
   )        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
  AND A.JOURNALCODE = 'DEFA0'        
  AND A.TRXCODE <> 'BENEFIT'        
  AND A.METHOD = 'SL'        
  AND A.SOURCEPROCESS NOT IN ('SL_REV_SWITCH','SL_SWITCH')         
        
 --STAFF LOAN DEFA0        
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (        
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
  ,NOREF        
  ,VALCTR_CODE        
  ,GL_INTERNAL_CODE        
  ,METHOD       
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
     AND COALESCE(A.FLAG_AL, 'A') = 'A'        
     )        
    OR (        
     A.REVERSE = 'Y'        
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'        
     )        
    THEN CASE         
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      ELSE CASE         
        WHEN B.DRCR = 'D'        
         THEN 'C'        
        ELSE 'D'        
        END        
      END        
   ELSE CASE         
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     ELSE CASE         
       WHEN B.DRCR = 'D'        
        THEN 'C'        
       ELSE 'D'        
       END        
     END        
   END AS DRCR        
  ,B.GLNO        
  ,ABS(A.N_AMOUNT)        
  ,ABS(A.N_AMOUNT_IDR)        
  ,A.SOURCEPROCESS        
  ,A.ID        
  ,CURRENT_TIMESTAMP        
  ,'SP_JOURNAL_DATA2_SL'        
  ,A.BRANCH        
  ,        
  --SUBSTRING (A.BRANCH, LEN (A.BRANCH) - 2, 3) AS BRANCH_CODE,        
  B.JOURNALCODE        
  ,B.JOURNAL_DESC        
  ,B.JOURNALCODE        
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')        
  ,B.GL_INTERNAL_CODE        
  ,A.METHOD           
 FROM IFRS_LI_ACCT_JOURNAL_INTM A        
 LEFT JOIN IFRS_LI_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE        
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID        
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID        
 JOIN IFRS_LI_JOURNAL_PARAM B ON (        
   B.CCY = A.CCY        
   OR B.CCY = 'ALL'        
   )        
  AND B.JOURNALCODE IN ('ITRCG_SL', 'ITRCG1_SL','ITRCG_SL2', 'ITEMB_SL','ITRCG_NE')        
  --AND B.JOURNALCODE = 'ITRCG' --- ONLY CTBC        
  AND B.JOURNALCODE = A.JOURNALCODE2      
  AND COALESCE(B.FLAG_CF, '-') NOT IN (        
   'F'        
   ,'C'        
   )        
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')        
  AND (        
   A.TRXCODE = B.TRX_CODE        
   OR B.TRX_CODE = 'ALL'        
   )        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
  AND A.JOURNALCODE = 'DEFA0'        
  AND A.TRXCODE = 'BENEFIT'        
  AND A.METHOD = 'SL'        
  AND A.SOURCEPROCESS NOT IN ('SL_REV_SWITCH','SL_SWITCH')       
        
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA_SL'        
  ,'ITRCG 2'        
  )        
        
 --JOURNAL INTERBRANCH      
 --RLCV OLD BRANCH       
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (            
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
  ,NOREF            
  ,VALCTR_CODE            
  ,GL_INTERNAL_CODE            
  ,METHOD                 
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
  ,B.DRCR          
  ,B.GLNO            
  ,ABS(A.N_AMOUNT)            
  ,ABS(A.N_AMOUNT_IDR)            
  ,A.SOURCEPROCESS            
  ,A.ID            
  ,CURRENT_TIMESTAMP            
  ,'SP_JOURNAL_DATA2'            
  ,A.BRANCH            
  ,B.JOURNALCODE            
  ,B.JOURNAL_DESC            
  ,B.JOURNALCODE            
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')            
  ,B.GL_INTERNAL_CODE            
  ,METHOD                   
 FROM IFRS_LI_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID            
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID            
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (            
   'RCLV_SL'           
   )
  AND (            
   B.CCY = A.CCY            
   OR B.CCY = 'ALL'            
   )            
  AND B.FLAG_CF = A.FLAG_CF            
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')            
  AND (            
   A.TRXCODE = B.TRX_CODE         
   OR B.TRX_CODE = 'ALL'            
   )       
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE          
  AND A.JOURNALCODE = 'DEFA0'            
  AND A.TRXCODE <> 'BENEFIT'            
  AND A.METHOD = 'SL'           
  AND A.SOURCEPROCESS = 'SL_REV_SWITCH'      
        
  --RLCS NEW BRANCH      
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (            
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
  ,NOREF            
  ,VALCTR_CODE            
  ,GL_INTERNAL_CODE            
  ,METHOD                   
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
  ,B.DRCR      
  ,B.GLNO            
  ,ABS(A.N_AMOUNT)            
  ,ABS(A.N_AMOUNT_IDR)            
  ,A.SOURCEPROCESS            
  ,A.ID            
  ,CURRENT_TIMESTAMP            
  ,'SP_JOURNAL_DATA2'            
  ,A.BRANCH            
  ,B.JOURNALCODE            
  ,B.JOURNAL_DESC            
  ,B.JOURNALCODE            
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')            
  ,B.GL_INTERNAL_CODE            
  ,METHOD                       
 FROM IFRS_LI_ACCT_JOURNAL_INTM A            
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID            
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID            
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (            
   'RCLS_SL'           
   )
  AND (            
   B.CCY = A.CCY            
   OR B.CCY = 'ALL'            
   )            
  AND B.FLAG_CF = A.FLAG_CF            
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')            
  AND (            
   A.TRXCODE = B.TRX_CODE            
   OR B.TRX_CODE = 'ALL'            
   )                
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE          
  AND A.JOURNALCODE = 'DEFA0'            
  AND A.TRXCODE <> 'BENEFIT'            
  AND A.METHOD = 'SL'           
  AND A.SOURCEPROCESS = 'SL_SWITCH'      
 --JOURNAL INTERBRANCH         
        
        
 -- INSERT ACCRU AMORT DATA SOURCE CCY PRDCODE COMBINATION        
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (        
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
  ,NOREF        
  ,VALCTR_CODE        
  ,GL_INTERNAL_CODE        
  ,METHOD               
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
     AND COALESCE(A.FLAG_AL, 'A') = 'A'        
     )        
    OR (        
     A.REVERSE = 'Y'        
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'        
     )        
    THEN CASE         
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      ELSE CASE         
        WHEN B.DRCR = 'D'        
         THEN 'C'        
        ELSE 'D'        
        END        
      END        
   ELSE CASE         
     WHEN A.N_AMOUNT <= 0       
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     ELSE CASE         
       WHEN B.DRCR = 'D'        
        THEN 'C'        
       ELSE 'D'        
       END        
     END        
   END AS DRCR        
  ,B.GLNO        
  ,ABS(A.N_AMOUNT)        
  ,ABS(A.N_AMOUNT_IDR)        
  ,A.SOURCEPROCESS        
  ,A.ID        
  ,CURRENT_TIMESTAMP        
  ,'SP_ACCT_JOURNAL_DATA2_SL'        
  ,A.BRANCH        
  ,B.JOURNALCODE        
  ,B.JOURNAL_DESC        
  ,B.JOURNALCODE        
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')        
  ,B.GL_INTERNAL_CODE        
  ,METHOD               
 FROM IFRS_LI_ACCT_JOURNAL_INTM A        
 LEFT JOIN IFRS_LI_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE        
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID        
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID        
 JOIN IFRS_LI_JOURNAL_PARAM B ON (        
   B.CCY = A.CCY        
   OR B.CCY = 'ALL'        
   )        
  AND B.JOURNALCODE IN ('ACCRU_SL', 'EMPBE_SL','EMACR_SL', 'ACCRU_NE')    
  AND B.JOURNALCODE = A.JOURNALCODE2      
  AND B.FLAG_CF = A.FLAG_CF        
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')        
  AND (        
   A.TRXCODE = B.TRX_CODE        
   OR B.TRX_CODE = 'ALL'        
   )        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
  AND A.JOURNALCODE IN (        
   'ACCRU_SL'        
   ,'AMORT'        
   )        
  AND A.TRXCODE <> 'BENEFIT'    
  AND A.METHOD = 'SL'        
      
   ---EARLY TERMINATE IFRS9            
  INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (            
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
  ,NOREF            
  ,VALCTR_CODE            
  ,GL_INTERNAL_CODE            
  ,METHOD                   
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
  ,B.JOURNALCODE            
  ,A.STATUS            
  ,A.REVERSE            
  ,A.FLAG_CF            
  ,B.DRCR            
  ,B.GLNO            
  ,ABS(COST_FEE_PREV.AMOUNT)            
  ,ABS(COST_FEE_PREV.AMOUNT) * IMC.EXCHANGE_RATE            
  ,A.SOURCEPROCESS            
  ,A.ID            
  ,CURRENT_TIMESTAMP            
  ,'SP_ACCT_JOURNAL_DATA2'            
  ,A.BRANCH            
  ,A.JOURNALCODE2            
  ,B.JOURNAL_DESC            
  ,B.JOURNALCODE            
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')            
  ,B.GL_INTERNAL_CODE            
  ,A.METHOD                 
FROM IFRS_LI_ACCT_SL_COST_FEE_PREV AS COST_FEE_PREV      
 INNER JOIN VW_LI_LAST_SL_CF_PREV C ON COST_FEE_PREV.MASTERID = C.MASTERID AND COST_FEE_PREV.SEQ = C.SEQ AND COST_FEE_PREV.DOWNLOAD_DATE = C.DOWNLOAD_DATE                
 LEFT JOIN IFRS_LI_ACCT_JOURNAL_INTM AS A ON A.MASTERID = COST_FEE_PREV.MASTERID AND A.DOWNLOAD_DATE = @V_CURRDATE AND A.TRXCODE <> 'BENEFIT' AND A.METHOD = 'SL' AND REVERSE = 'N'            
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR  AS IMC ON A.MASTERID = IMC.MASTERID            
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV  AS IMP ON A.MASTERID = IMP.MASTERID            
 JOIN IFRS_LI_JOURNAL_PARAM B ON B.JOURNALCODE IN (            
   'OTHER_SL'            
   )            
  AND (            
   B.CCY = A.CCY            
   OR B.CCY = 'ALL'            
   )            
  AND B.FLAG_CF = A.FLAG_CF            
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')            
  AND (            
   A.TRXCODE = B.TRX_CODE            
   OR B.TRX_CODE = 'ALL'            
   )            
 WHERE COST_FEE_PREV.DOWNLOAD_DATE = @V_PREVDATE            
 AND COST_FEE_PREV.MASTERID IN             
 (            
   SELECT A.MASTERID FROM DBO.IFRS_LI_ACCT_COST_FEE AS A            
   JOIN DBO.IFRS_LI_STG_TRANSACTION_DAILY AS B            
   ON            
   A.TRX_REFF_NUMBER = B.TRANSACTION_REFERENCE_NUMBER            
   AND            
   B.DOWNLOAD_DATE = @V_CURRDATE            
   AND            
   B.TERMINATE_FLAG = 'Y'            
   WHERE             
   A.STATUS = 'ACT'            
 )            
 ---EARLY TERMINATE IFRS9      
       
 --STAFF LOAN ACCRU        
 INSERT INTO IFRS_LI_ACCT_JOURNAL_DATA (        
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
  ,NOREF        
  ,VALCTR_CODE        
  ,GL_INTERNAL_CODE        
  ,METHOD               
  )        
 SELECT A.DOWNLOAD_DATE        
  ,A.MASTERID        
  ,A.FACNO        
  ,A.CIFNO        
  ,A.ACCTNO        
  ,A.DATASOURCE        
  ,A.PRDTYPE    ,A.PRDCODE        
  ,A.TRXCODE        
  ,A.CCY        
  ,A.JOURNALCODE        
  ,A.STATUS        
  ,A.REVERSE        
  ,A.FLAG_CF        
  ,CASE         
   WHEN (        
     A.REVERSE = 'N'        
     AND COALESCE(A.FLAG_AL, 'A') = 'A'        
     )        
    OR (        
     A.REVERSE = 'Y'        
     AND COALESCE(A.FLAG_AL, 'A') <> 'A'        
     )        
    THEN CASE         
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN (        
        'ACCRU_SL'        
        ,'AMORT'        
        )        
       THEN B.DRCR        
      WHEN A.N_AMOUNT <= 0        
       AND A.FLAG_CF = 'F'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      WHEN A.N_AMOUNT >= 0        
       AND A.FLAG_CF = 'C'        
       AND A.JOURNALCODE IN ('DEFA0')        
       THEN B.DRCR        
      ELSE CASE         
        WHEN B.DRCR = 'D'        
         THEN 'C'        
        ELSE 'D'        
        END        
      END        
   ELSE CASE         
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN (        
       'ACCRU_SL'        
       ,'AMORT'        
       )        
      THEN B.DRCR        
     WHEN A.N_AMOUNT >= 0        
      AND A.FLAG_CF = 'F'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     WHEN A.N_AMOUNT <= 0        
      AND A.FLAG_CF = 'C'        
      AND A.JOURNALCODE IN ('DEFA0')        
      THEN B.DRCR        
     ELSE CASE              
	 WHEN B.DRCR = 'D'        
        THEN 'C'        
       ELSE 'D'        
       END        
     END        
   END AS DRCR        
  ,B.GLNO        
  ,ABS(A.N_AMOUNT)        
  ,ABS(A.N_AMOUNT_IDR)        
  ,A.SOURCEPROCESS        
  ,A.ID        
  ,CURRENT_TIMESTAMP        
  ,'SP_ACCT_JOURNAL_DATA2_SL'        
  ,A.BRANCH        
  ,        
  --SUBSTRING (A.BRANCH, LEN (A.BRANCH) - 2, 3) AS BRANCH_CODE,        
  B.JOURNALCODE        
  ,B.JOURNAL_DESC        
  ,B.JOURNALCODE        
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')        
  ,B.GL_INTERNAL_CODE        
  ,METHOD            
 FROM IFRS_LI_ACCT_JOURNAL_INTM A        
 LEFT JOIN IFRS_LI_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE        
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID        
 LEFT JOIN IFRS_LI_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID        
 JOIN IFRS_LI_JOURNAL_PARAM B ON (        
   B.CCY = A.CCY        
   OR B.CCY = 'ALL'        
   )        
  AND B.JOURNALCODE IN ('ACCRU_SL', 'EMPBE_SL','EMACR_SL', 'EBCTE_SL','ACCRU_NE')    
  AND B.JOURNALCODE = A.JOURNALCODE2      
  AND COALESCE(B.FLAG_CF, '-') NOT IN (        
   'F'        
   ,'C'        
   )        
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')        
  AND (        
   A.TRXCODE = B.TRX_CODE        
   OR B.TRX_CODE = 'ALL'        
   )        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
  AND A.JOURNALCODE IN (        
   'ACCRU'        
   ,'AMORT'        
   )        
  AND A.TRXCODE = 'BENEFIT'        
  AND A.METHOD = 'SL'        
        
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA'        
  ,'AMORT 2'        
  )        
        
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
  ,'SP_IFRS_LI_ACCT_JOURNAL_DATA_SL'        
  ,''        
  )        
END   
GO
