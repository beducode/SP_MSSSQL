USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ACCT_JOURNAL_DATA]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[SP_IFRS_ACCT_JOURNAL_DATA]              
AS
----BEGIN TRAN
------ROLLBACK              
DECLARE @V_CURRDATE DATE              
 ,@V_PREVDATE DATE              
 ,@V_PREVMONTH DATE              
 ,@VMIN_NOREF BIGINT  
 ,@MIGRATIONDATE DATE              
              
BEGIN              
 SELECT @V_CURRDATE = MAX(CURRDATE)              
  ,@V_PREVDATE = MAX(PREVDATE)              
 FROM IFRS_PRC_DATE_AMORT              
              
 SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, - 1, @V_CURRDATE))       
   
 SELECT @MIGRATIONDATE = VALUE2 FROM TBLM_COMMONCODEDETAIL WHERE VALUE1 = 'ITRCGM'         
               
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,''              
  )              
              
 UPDATE IFRS_ACCT_JOURNAL_INTM              
 SET METHOD = 'EIR'              
 WHERE DOWNLOAD_DATE = @V_CURRDATE              
  AND SUBSTRING(SOURCEPROCESS, 1, 3) = 'EIR'              
              
 /* REMARK BY SAID BTPN 20190225 TUNING      
 -- JOURNAL INTM FLAG_AL FILL FROM IFRS_IMA_AMORT_CURR             
 UPDATE DBO.IFRS_ACCT_JOURNAL_INTM              
 SET FLAG_AL = B.IAS_CLASS              
 FROM IFRS_IMA_AMORT_CURR B              
 WHERE B.MASTERID = DBO.IFRS_ACCT_JOURNAL_INTM.MASTERID              
  AND DBO.IFRS_ACCT_JOURNAL_INTM.DOWNLOAD_DATE = @V_CURRDATE              
 */      
      
  -- JOURNAL INTM FLAG_AL FILL FROM IFRS_IMA_AMORT_CURR  AND UPDATE LOCAL CURRENCY AMOUNT      
  UPDATE A       
  SET A.FLAG_AL = CASE WHEN ISNULL(B.IAS_CLASS,'') = '' THEN D.INST_CLS_VALUE ELSE B.IAS_CLASS END ,      
   N_AMOUNT_IDR = A.N_AMOUNT * COALESCE(C.RATE_AMOUNT, 1)       
 FROM IFRS_ACCT_JOURNAL_INTM A       
 LEFT JOIN IFRS_IMA_AMORT_CURR B       
 ON A.MASTERID = B.MASTERID       
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C      
 ON A.CCY = C.CURRENCY  AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE       
 LEFT JOIN IFRS_MASTER_PRODUCT_PARAM D ON     
 A.DATASOURCE = D.DATA_SOURCE  AND A.PRDCODE = D.PRD_CODE                                            
 AND (                                            
     A.CCY = D.CCY  OR D.CCY = 'ALL'                                            
   )                                        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
              
 --POPULATE EXCHANGE RATE PINDAH KE INITIAL UPDATE                  
 --EXEC SP_IFRS_POPULATE_EXCHANGE_RATE                  
 --UPDATE  A                  
 --SET     N_AMOUNT_IDR = A.N_AMOUNT * COALESCE(B.RATE_AMOUNT, 1)                  
 --FROM    DBO.IFRS_ACCT_JOURNAL_INTM A                  
 --        LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B ON A.CCY = B.CURRENCY  AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE                 
 --WHERE   A.DOWNLOAD_DATE = @V_CURRDATE               
 /*        
 -- REMARK BY SAID BTPN 20190225 TUNING UPDATE MOVE TO TOP      
 UPDATE A              
 SET N_AMOUNT_IDR = N_AMOUNT * ISNULL(CURR.RATE_AMOUNT, 1)              
  --SHU 20180910 SELALU AMBIL CURR_RATE            
  --CASE               
  -- WHEN REVERSE = 'Y'              
  --  THEN N_AMOUNT * ISNULL(PREV.RATE_AMOUNT, 1)              
  -- ELSE N_AMOUNT * ISNULL(CURR.RATE_AMOUNT, 1)              
  -- END              
 FROM DBO.IFRS_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE CURR ON CURR.DOWNLOAD_DATE = @V_CURRDATE              
  AND A.CCY = CURR.CURRENCY              
 --LEFT JOIN IFRS_MASTER_EXCHANGE_RATE PREV ON PREV.DOWNLOAD_DATE = @V_PREVDATE              
 -- AND A.CCY = PREV.CURRENCY              
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
  */      
              
 --DELETE FIRST                  
 DELETE              
 FROM IFRS_ACCT_JOURNAL_DATA              
 WHERE DOWNLOAD_DATE >= @V_CURRDATE              
              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'CLEAN UP'              
  )   
    
 IF @V_CURRDATE = @MIGRATIONDATE  
 BEGIN       
  -- INSERT ITRCGM JOURNAL MIGRATION                 
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (          
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,B.JOURNALCODE AS JOURNALCODE2              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD             
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE    
  FROM IFRS_ACCT_JOURNAL_INTM A  
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND FEE.TRX_LEVEL <> 'FAC' AND FEE.SOURCE_TABLE = 'TBLU_TRANS_ASSET'           
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE = 'ITRCGM'            
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
   AND A.METHOD = 'EIR'  
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')             
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')             
              
  --STAFF LOAN DEFA0                  
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN ( 
   'ACCRU'          
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,B.JOURNALCODE AS JOURNALCODE2              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD         
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE       
  FROM IFRS_ACCT_JOURNAL_INTM A    
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND FEE.TRX_LEVEL <> 'FAC' AND FEE.SOURCE_TABLE = 'TBLU_TRANS_ASSET'          
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE = 'ITRCGM'           
   AND (              
    B.CCY = A.CCY              
    OR B.CCY = 'ALL'              
    )              
   AND B.FLAG_CF = 'B'              
   AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')              
   AND (              
    A.TRXCODE = B.TRX_CODE              
    OR B.TRX_CODE = 'ALL'              
    )        
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
   AND A.JOURNALCODE = 'DEFA0'              
 AND A.TRXCODE = 'BENEFIT'              
   AND A.METHOD = 'EIR'    
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')           
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')      
 END  
  
  /**  JIKA DATA COORPORATE TURUN DI TANGGAL MIGRASI DAN LEVELNYA FACILITAS, MAKA DI BENTUK JOURNAL ITRCG   **/  
                
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (          
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,A.JOURNALCODE2              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD      
   ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE           
  FROM IFRS_ACCT_JOURNAL_INTM A  
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND FEE.TRX_LEVEL = 'FAC'              
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
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
   AND A.METHOD = 'EIR'  
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')   
   AND A.DOWNLOAD_DATE = @MIGRATIONDATE           
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')             
              
  --STAFF LOAN DEFA0                  
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,B.JOURNALCODE              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD       
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE          
  FROM IFRS_ACCT_JOURNAL_INTM A  
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND FEE.TRX_LEVEL = 'FAC'             
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID           
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
    ,'ITEMB'              
    )              
   AND (              
    B.CCY = A.CCY              
    OR B.CCY = 'ALL'              
    )              
   AND B.FLAG_CF = 'B'              
   AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')              
   AND (              
    A.TRXCODE = B.TRX_CODE              
    OR B.TRX_CODE = 'ALL'              
    )        
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
   AND A.JOURNALCODE = 'DEFA0'              
 AND A.TRXCODE = 'BENEFIT'              
   AND A.METHOD = 'EIR'    
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')   
   AND A.DOWNLOAD_DATE = @MIGRATIONDATE             
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')    
 /** ----------------------------------------------------------------------------------------- **/  
 
 /**  JIKA DATA COORPORATE TURUN DI TANGGAL MIGRASI DAN BUKAN LEVEL FACILITAS, MAKA DI BENTUK JOURNAL ITRCG   **/  
                
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (          
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,A.JOURNALCODE2              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD      
   ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE           
  FROM IFRS_ACCT_JOURNAL_INTM A  
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND ISNULL(FEE.TRX_LEVEL,'') <> 'FAC' AND FEE.SOURCE_TABLE <> 'TBLU_TRANS_ASSET'              
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
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
   AND A.METHOD = 'EIR'  
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')   
   AND A.DOWNLOAD_DATE = @MIGRATIONDATE           
AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')             
              
  --STAFF LOAN DEFA0                  
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,B.JOURNALCODE              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,A.METHOD       
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE          
  FROM IFRS_ACCT_JOURNAL_INTM A  
  INNER JOIN IFRS_ACCT_COST_FEE FEE ON A.DOWNLOAD_DATE = FEE.DOWNLOAD_DATE AND A.CF_ID = FEE.CF_ID AND ISNULL(FEE.TRX_LEVEL,'') <> 'FAC' AND FEE.SOURCE_TABLE <> 'TBLU_TRANS_ASSET'            
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID           
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
    ,'ITEMB'              
    )              
   AND (              
    B.CCY = A.CCY              
    OR B.CCY = 'ALL'              
    )              
   AND B.FLAG_CF = 'B'              
   AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')              
   AND (              
    A.TRXCODE = B.TRX_CODE              
    OR B.TRX_CODE = 'ALL'              
    )        
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
   AND A.JOURNALCODE = 'DEFA0'              
 AND A.TRXCODE = 'BENEFIT'              
   AND A.METHOD = 'EIR'    
   AND A.DATASOURCE IN ('LOAN_T24','LIMIT_T24')   
   AND A.DOWNLOAD_DATE = @MIGRATIONDATE             
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')    
 /** ----------------------------------------------------------------------------------------- **/  
  

  -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION                  
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (          
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,A.JOURNALCODE2              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,METHOD      
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE           
  FROM IFRS_ACCT_JOURNAL_INTM A              
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
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
   AND A.METHOD = 'EIR'  
   AND (A.DATASOURCE NOT IN ('LOAN_T24','LIMIT_T24') OR (A.DATASOURCE IN ('LOAN_T24','LIMIT_T24') AND A.DOWNLOAD_DATE <> @MIGRATIONDATE))           
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')             
              
  --STAFF LOAN DEFA0          
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
   ,NOREF              
   ,VALCTR_CODE              
   ,GL_INTERNAL_CODE              
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
    WHEN A.N_AMOUNT >= 0              
     AND A.FLAG_CF = 'F'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
   ,'AMORT'              
   )              
     THEN B.DRCR              
    WHEN A.N_AMOUNT <= 0              
     AND A.FLAG_CF = 'C'              
     AND A.JOURNALCODE IN (              
   'ACCRU'              
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
     'ACCRU'              
     ,'AMORT'              
     )              
    THEN B.DRCR              
   WHEN A.N_AMOUNT >= 0              
    AND A.FLAG_CF = 'C'              
    AND A.JOURNALCODE IN (              
     'ACCRU'              
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
   ,'SP_JOURNAL_DATA2'              
   ,A.BRANCH              
   ,B.JOURNALCODE              
   ,B.JOURNAL_DESC              
   ,B.JOURNALCODE              
   ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
   ,B.GL_INTERNAL_CODE              
   ,METHOD       
     ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE          
  FROM IFRS_ACCT_JOURNAL_INTM A              
  LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
  LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
  JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
    'ITRCG'              
    ,'ITRCG1'              
    ,'ITRCG2'              
    ,'ITEMB'              
    )              
   AND (              
    B.CCY = A.CCY              
    OR B.CCY = 'ALL'              
    )              
   AND B.FLAG_CF = 'B'              
   AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')      
   AND (              
A.TRXCODE = B.TRX_CODE              
    OR B.TRX_CODE = 'ALL'              
    )        
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
   AND A.JOURNALCODE = 'DEFA0'              
 AND A.TRXCODE = 'BENEFIT'              
   AND A.METHOD = 'EIR'      
   AND (A.DATASOURCE NOT IN ('LOAN_T24','LIMIT_T24') OR (A.DATASOURCE IN ('LOAN_T24','LIMIT_T24') AND A.DOWNLOAD_DATE <> @MIGRATIONDATE))          
   AND A.SOURCEPROCESS NOT IN ('EIR_REV_SWITCH','EIR_SWITCH')            
              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'ITRCG 2'              
  )              
              
 -- INSERT ACCRU AMORT DATA SOURCE CCY PRDCODE COMBINATION                  
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
  ,BRANCH    ,JOURNALCODE2              
  ,JOURNAL_DESC              
  ,NOREF              
  ,VALCTR_CODE              
  ,GL_INTERNAL_CODE              
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
      WHEN A.N_AMOUNT >= 0              
       AND A.FLAG_CF = 'F'              
       AND A.JOURNALCODE IN (              
        'ACCRU'              
        ,'AMORT'              
        )              
       THEN B.DRCR              
      WHEN A.N_AMOUNT <= 0              
       AND A.FLAG_CF = 'C'              
       AND A.JOURNALCODE IN (              
        'ACCRU'              
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
       'ACCRU'              
       ,'AMORT'              
       )              
      THEN B.DRCR              
     WHEN A.N_AMOUNT >= 0              
      AND A.FLAG_CF = 'C'             
      AND A.JOURNALCODE IN (              
       'ACCRU'              
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
  ,'SP_ACCT_JOURNAL_DATA2'              
  ,A.BRANCH              
  ,A.JOURNALCODE2              
  ,B.JOURNAL_DESC              
  ,B.JOURNALCODE              
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
  ,B.GL_INTERNAL_CODE              
  ,METHOD        
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE         
 FROM IFRS_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
 JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
   'ACCRU'    
   ,'EMPBE'              
   ,'EMACR'              
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
  AND A.JOURNALCODE IN (              
   'ACCRU'              
   ,'AMORT'              
   )              
  AND A.TRXCODE <> 'BENEFIT'              
  AND A.METHOD = 'EIR'         
              
 --STAFF LOAN ACCRU                  
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
  ,NOREF              
  ,VALCTR_CODE              
  ,GL_INTERNAL_CODE      
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
      WHEN A.N_AMOUNT >= 0              
       AND A.FLAG_CF = 'F'              
       AND A.JOURNALCODE IN (              
        'ACCRU'              
  ,'AMORT'              
        )              
       THEN B.DRCR              
      WHEN A.N_AMOUNT <= 0              
       AND A.FLAG_CF = 'C'              
       AND A.JOURNALCODE IN (              
        'ACCRU'              
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
       'ACCRU'              
       ,'AMORT'              
       )              
      THEN B.DRCR              
     WHEN A.N_AMOUNT >= 0              
      AND A.FLAG_CF = 'C'              
      AND A.JOURNALCODE IN (              
       'ACCRU'              
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
  ,'SP_ACCT_JOURNAL_DATA2'              
  ,A.BRANCH              
  ,B.JOURNALCODE              
  ,B.JOURNAL_DESC              
  ,B.JOURNALCODE              
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
  ,B.GL_INTERNAL_CODE              
  ,METHOD      
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE           
 FROM IFRS_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
 JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN (              
   'ACCRU'              
   ,'EMPBE'              
   ,'EMACR'              
   ,'EBCTE'              
   )              
  AND (              
   B.CCY = A.CCY              
   OR B.CCY = 'ALL'              
   )              
  AND B.FLAG_CF = 'B'             
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
  AND A.METHOD = 'EIR'            
              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'AMORT 2'              
  )         
              
 /*ACRU NOCF*/              
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
  ,NOREF              
  ,VALCTR_CODE              
  ,GL_INTERNAL_CODE              
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
   WHEN A.REVERSE = 'N'              
    AND N_AMOUNT > 0              
    THEN B.DRCR              
   WHEN A.REVERSE = 'Y'              
    AND N_AMOUNT <= 0              
    THEN B.DRCR              
   ELSE CASE               
     WHEN B.DRCR = 'C'              
      THEN 'D'              
     ELSE 'C'              
     END              
   END AS DRCR              
  ,B.GLNO              
  ,ABS(A.N_AMOUNT) N_AMOUNT              
  ,ABS(A.N_AMOUNT_IDR) N_AMOUNT_IDR              
  ,A.SOURCEPROCESS              
  ,A.ID              
  ,CURRENT_TIMESTAMP AS CREATEDDATE              
  ,'SP_ACCT_JOURNAL_DATA2' CREATEDBY              
  ,A.BRANCH              
  ,A.JOURNALCODE2              
  ,B.JOURNAL_DESC              
  ,B.JOURNALCODE AS NOREF              
  ,B.COSTCENTER + '-' + COALESCE(IMC.APPLICATION_NO, IMP.APPLICATION_NO, '')              
  ,B.GL_INTERNAL_CODE              
  ,A.METHOD            
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE     
 FROM IFRS_ACCT_JOURNAL_INTM A              
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID              
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID              
 JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE = 'ACRU4'              
  AND (              
   B.CCY = A.CCY              
   OR B.CCY = 'ALL'              
   )              
  AND B.FLAG_CF = A.FLAG_CF              
  AND B.GL_CONSTNAME = COALESCE(IMC.GL_CONSTNAME, IMP.GL_CONSTNAME, '')              
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
  AND A.JOURNALCODE IN (              
   'ACRU4'              
   ,'AMRT4'              
   )              
  AND A.TRXCODE <> 'BENEFIT'              
  AND A.METHOD = 'EIR'         
              
-- JOURNAL SWITCH ACCOUNT                  
--RLCV OLD BRANCH               
-- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION                    
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
  ,NOREF                
  ,VALCTR_CODE                
  ,GL_INTERNAL_CODE                
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
    ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE      
 FROM IFRS_ACCT_JOURNAL_INTM A                
 --LEFT JOIN IFRS_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE        --REMARK BY SAID TUNING BTPN 20190225      
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID                
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID                
 JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN ('RCLV')        
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
  AND A.METHOD = 'EIR'         
  AND A.SOURCEPROCESS = 'EIR_REV_SWITCH'   
  
--RLCS NEW BRANCH         
 -- INSERT ITRCG DATA_SOURCE CCY JENIS_PINJAMAN COMBINATION                    
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
  ,NOREF                
  ,VALCTR_CODE                
  ,GL_INTERNAL_CODE                
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
  ,IMC.ACCOUNT_TYPE AS ACCOUNT_TYPE    
  ,IMC.CUSTOMER_TYPE AS CUSTOMER_TYPE   
 FROM IFRS_ACCT_JOURNAL_INTM A                
 --LEFT JOIN IFRS_MASTER_ACCOUNT IMA ON A.MASTERID = IMA.MASTERID AND A.DOWNLOAD_DATE = IMA.DOWNLOAD_DATE           --REMARK BY SAID TUNING BTPN 20190225      
 LEFT JOIN IFRS_IMA_AMORT_CURR IMC ON A.MASTERID = IMC.MASTERID                
 LEFT JOIN IFRS_IMA_AMORT_PREV IMP ON A.MASTERID = IMP.MASTERID                
 JOIN IFRS_JOURNAL_PARAM B ON B.JOURNALCODE IN ('RCLS')        
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
  AND A.METHOD = 'EIR'               
  AND A.SOURCEPROCESS = 'EIR_SWITCH'             
                
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'JOURNAL SL'              
  )              
              
 -- CALL JOURNAL SL GENERATED                  
 EXEC SP_IFRS_ACCT_JRNL_DATA_SL              
              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'JOURNAL SL DONE'              
  )              
              
 /* JOURNAL FACILITY LEVEL FOR PNL EXPIRED 20180501*/              
 ---CORPORATE              
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
  ,NOREF              
  ,VALCTR_CODE              
  ,GL_INTERNAL_CODE              
  ,METHOD    
    ,ACCOUNT_TYPE    
,CUSTOMER_TYPE               
  )              
 SELECT B.DOWNLOAD_DATE              
  ,A.TRX_FACILITY_NO              
  ,A.TRX_FACILITY_NO              
  ,NULL              
  ,A.TRX_FACILITY_NO              
  ,NULL              
  ,NULL              
  ,NULL              
  ,A.TRX_CODE              
  ,A.TRX_CCY              
  ,'PNL'              
  ,'ACT' STATUS              
  ,'N' REVERSE              
  ,D.VALUE1 FLAG_CF              
  ,LEFT(D.VALUE2, 1)              
  ,D.VALUE3 GLNO              
  ,A.REMAINING         
  ,A.REMAINING * RATE.RATE_AMOUNT              
  ,'CORP FACILITY EXP' AS SOURCEPROCESS              
  ,NULL              
  ,CURRENT_TIMESTAMP              
  ,'SP_ACCT_JOURNAL_DATA'              
  ,E.BRANCH_CODE              
  ,'PNL' JOURNALCODE2              
  ,D.DESCRIPTION              
  ,NULL              
  ,NULL              
  ,NULL GL_INTERNAL_CODE              
  ,NULL METHOD     
  ,MPB.ACCOUNT_TYPE  
  ,E.CUSTOMER_TYPE            
 FROM IFRS_TRX_FACILITY A              
 LEFT JOIN IFRS_MASTER_PARENT_LIMIT B ON A.TRX_FACILITY_NO = B.LIMIT_PARENT_NO              
  AND B.DOWNLOAD_DATE = @V_CURRDATE             
 LEFT JOIN IFRS_TRANSACTION_PARAM C ON A.TRX_CODE = C.TRX_CODE              
  AND (              
   A.TRX_CCY = C.CCY              
   OR C.CCY = 'ALL'              
   )              
    LEFT JOIN IFRS9_STG.. TBL_MASTER_PRODUCT_BANKWIDE MPB ON C.PRD_CODE =  MPB.PRODUCT_CODE      
 LEFT JOIN TBLM_COMMONCODEDETAIL D ON LEFT(C.IFRS_TXN_CLASS, 1) = D.VALUE1              
  AND D.COMMONCODE = 'B103'              
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE RATE ON A.TRX_CCY = RATE.CURRENCY              
  AND RATE.DOWNLOAD_DATE = @V_CURRDATE              
 LEFT JOIN IFRS_IMA_LIMIT E ON A.TRX_FACILITY_NO = E.MASTERID              
  AND E.DOWNLOAD_DATE = @V_CURRDATE              
 WHERE A.REMAINING > 0              
  AND DATEADD(DAY, 1, A.FACILITY_EXPIRED_DATE) = @V_CURRDATE              
  AND A.STATUS = 'P'              
  AND A.REVID IS NULL              
  AND A.PKID NOT IN (              
   SELECT DISTINCT REVID              
   FROM IFRS_TRX_FACILITY              
   WHERE REVID IS NOT NULL              
   )              
  AND B.SME_FLAG = 0              
              
 ---SME              
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
  ,NOREF              
  ,VALCTR_CODE              
  ,GL_INTERNAL_CODE              
  ,METHOD       
      ,ACCOUNT_TYPE    
,CUSTOMER_TYPE               
  )              
 SELECT B.DOWNLOAD_DATE              
  ,A.TRX_FACILITY_NO              
  ,A.TRX_FACILITY_NO              
  ,NULL              
 ,A.TRX_FACILITY_NO              
  ,'LIMIT'              
  ,NULL              
  ,NULL              
  ,A.TRX_CODE              
  ,A.TRX_CCY              
  ,'PNL'              
  ,'ACT' STATUS              
  ,'N' REVERSE              
  ,D.VALUE1 FLAG_CF          
  ,LEFT(D.VALUE2, 1)              
  ,D.VALUE3 GLNO              
  ,A.REMAINING              
  ,A.REMAINING * RATE.RATE_AMOUNT              
,'SME FACILITY EXP' AS SOURCEPROCESS              
  ,NULL              
  ,CURRENT_TIMESTAMP              
  ,'SP_ACCT_JOURNAL_DATA'              
  ,E.BRANCH_CODE              
  ,'PNL' JOURNALCODE2              
  ,D.DESCRIPTION              
  ,NULL              
  ,NULL              
  ,NULL GL_INTERNAL_CODE              
  ,NULL METHOD   
    ,MPB.ACCOUNT_TYPE  
  ,E.CUSTOMER_TYPE               
 FROM IFRS_TRX_FACILITY A              
 LEFT JOIN IFRS_MASTER_PARENT_LIMIT B ON A.TRX_FACILITY_NO = B.LIMIT_PARENT_NO              
  AND B.DOWNLOAD_DATE = @V_CURRDATE              
 LEFT JOIN IFRS_TRANSACTION_PARAM C ON A.TRX_CODE = C.TRX_CODE              
  AND (              
   A.TRX_CCY = C.CCY     
   OR C.CCY = 'ALL'              
   )        
      LEFT JOIN IFRS9_STG.. TBL_MASTER_PRODUCT_BANKWIDE MPB ON C.PRD_CODE =  MPB.PRODUCT_CODE      
 LEFT JOIN TBLM_COMMONCODEDETAIL D ON LEFT(C.IFRS_TXN_CLASS, 1) = D.VALUE1              
  AND D.COMMONCODE = 'B104'              
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE RATE ON A.TRX_CCY = RATE.CURRENCY              
  AND RATE.DOWNLOAD_DATE = @V_CURRDATE              
 LEFT JOIN IFRS_IMA_LIMIT E ON A.TRX_FACILITY_NO = E.MASTERID              
  AND E.DOWNLOAD_DATE = @V_CURRDATE              
 WHERE A.REMAINING > 0              
  AND DATEADD(DAY, 1, A.FACILITY_EXPIRED_DATE) = @V_CURRDATE              
  AND A.STATUS = 'P'              
  AND A.REVID IS NULL              
  AND A.PKID NOT IN (              
   SELECT DISTINCT REVID              
   FROM IFRS_TRX_FACILITY              
   WHERE REVID IS NOT NULL              
   )              
  AND B.SME_FLAG = 1              
              
 --SET REMAINING 0 AFTER JOURNAL 20180824              
 UPDATE IFRS_TRX_FACILITY              
 SET REMAINING = 0              
 WHERE REMAINING > 0              
  AND FACILITY_EXPIRED_DATE < @V_CURRDATE              
  AND STATUS = 'P'              
  AND REVID IS NULL              
  AND PKID NOT IN (              
   SELECT DISTINCT REVID              
   FROM IFRS_TRX_FACILITY              
   WHERE REVID IS NOT NULL              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'JOURNAL FACILITY DONE'              
  )              
              
 /*PINDAHAN DARI ATAS 20160510*/              
 UPDATE IFRS_ACCT_JOURNAL_DATA              
 SET NOREF = CASE               
   WHEN NOREF IN (              
     'ITRCG'              
     ,'ITRCG_SL'              
   ,'ITRCG_NE'              
     )              
    THEN '1'              
   WHEN NOREF IN (              
     'ITRCG1'              
     ,'ITRCG_SL1'              
     )              
    THEN '2'              
   WHEN NOREF IN (              
     'ITRCG2'              
     ,'ITRCG_SL2'              
     )              
    THEN '3'              
   WHEN NOREF IN (              
     'EMPBE'              
     ,'EMPBE_SL'              
     )              
    THEN '4'              
   WHEN NOREF IN (              
     'EMACR'              
     ,'EMACR_SL'              
     )              
    THEN '5'              
   WHEN NOREF = 'RLS'              
    THEN '6'              
   ELSE '9'              
   END + CASE               
   WHEN REVERSE = 'Y'              
    THEN '1'              
   ELSE '2'              
   END + CASE               
   WHEN DRCR = 'D'              
    THEN '1'         
   ELSE '2'              
   END              
 WHERE DOWNLOAD_DATE = @V_CURRDATE              
              
 /* REMARKS 20170221                  
        UPDATE  IFRS_ACCT_JOURNAL_DATA                  
        SET     NOREF = VALCTR_CODE                  
        WHERE   DOWNLOAD_DATE = @V_CURRDATE                  
  */              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,'FILL NOREF DONE'              
  )              
              
 /* FD: UPDATE MASTER ACCOUNT FAIR VALUE AMOUNT*/--SELECT UNAMORT_AMT_TOTAL FROM IFRS_MASTER_ACCOUNT                  
UPDATE A          
 SET A.FAIR_VALUE_AMOUNT =           
 CASE WHEN B.VALUE1 IS NOT NULL           
  THEN COALESCE(A.OUTSTANDING, 0) + COALESCE(A.OUTSTANDING_IDC, 0)           
  ELSE COALESCE(A.OUTSTANDING, 0) + COALESCE(A.OUTSTANDING_IDC, 0) + COALESCE(A.UNAMORT_FEE_AMT,0) + COALESCE(A.UNAMORT_COST_AMT, 0)                  
 END          
 --FAIR_VALUE_AMOUNT = COALESCE(OUTSTANDING_JF, 0) + COALESCE(UNAMOR_AMT_TOTAL, 0)                      
 FROM IFRS_MASTER_ACCOUNT A                 
 LEFT JOIN TBLM_COMMONCODEDETAIL B           
  ON A.DATA_SOURCE = B.VALUE1 AND A.PRODUCT_CODE = B.VALUE1           
   AND B.COMMONCODE = 'S1022' -- PRODUCT OVERDRAFT, FAIRVALUE = OUTSTANDING           
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                  
 AND NOT EXISTS (          
  SELECT TOP 1 1           
  FROM TBLM_COMMONCODEDETAIL X           
  WHERE A.DATA_SOURCE = X.VALUE1 AND X.COMMONCODE = 'S1003' ) -- TREASURY, FAIRVALUE = LEMPARAN DARI DWH. GA PERLU UPDATE          
             
/*************************          
FACILITY JURNAL          
**************************/          
          
EXEC  [dbo].[SP_IFRS_ACCT_JRNL_DATA_FAC]          
              
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
  ,'SP_IFRS_ACCT_JOURNAL_DATA'              
  ,''              
  )              
    
  IF @V_CURRDATE = EOMONTH(@V_CURRDATE)    
  BEGIN    
  EXEC SP_IFRS_JOURNAL_GAIN_LOSS --- ADDED FOR JOURNAL FVTPL AND FVOCI    
  END    
    
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
  ,'GAIN_LOSS_JOURNAL_DATA'              
  ,''              
  )         
    
END


GO
