USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_REPORT_RECON]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
        
CREATE PROCEDURE [dbo].[SP_IFRS_REPORT_RECON]        
AS        
BEGIN        
 DECLARE @V_CURRDATE DATE        
  ,@V_PREVDATE DATE        
  ,        
  --@V_RETENTION_DATE DATE ,            
  --@V_DAY_RETENTION INTEGER ,            
  @V_ROUND INTEGER        
  ,@V_FUNCROUND INTEGER        
  ,@ISBOM INTEGER        
  ,@ISBOY INTEGER        
        
 SELECT @V_CURRDATE = MAX(CURRDATE)        
  ,@V_PREVDATE = MAX(PREVDATE)        
 FROM IFRS_PRC_DATE_AMORT;        
        
 SET @V_ROUND = 2;        
 SET @V_FUNCROUND = 1;        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,''        
  )        
        
 SELECT @ISBOM = CASE         
   WHEN CONVERT(VARCHAR(6), @V_CURRDATE, 112) <> CONVERT(VARCHAR(6), @V_PREVDATE, 112)        
    THEN 1        
   ELSE 0        
   END        
  ,@ISBOY = CASE         
   WHEN CONVERT(VARCHAR(4), @V_CURRDATE, 112) <> CONVERT(VARCHAR(4), @V_PREVDATE, 112)        
    THEN 1        
   ELSE 0        
   END        
        
 /* MOVING TO SP ARCHIVING..            
  SET @V_DAY_RETENTION = 10 ;               
            
        SET @V_RETENTION_DATE = DATEADD(DAY, -1 * @V_DAY_RETENTION,@V_CURRDATE) ;              
  */        
 SELECT @V_ROUND = B.VALUE1        
  ,@V_FUNCROUND = B.VALUE2        
 FROM TBLM_COMMONCODEHEADER A        
  ,TBLM_COMMONCODEDETAIL B        
 WHERE A.COMMONCODE = B.COMMONCODE        
  AND A.COMMONCODE = 'SCM003'        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'CLEANUP'        
  )        
        
 DELETE IFRS_LOAN_REPORT_RECON        
 WHERE DOWNLOAD_DATE >= @V_CURRDATE;        
        
 EXECUTE ('TRUNCATE TABLE TMP_JOURNAL_PARAM');        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'INSERT TMP_JOURNAL_PARAM'        
  )        
        
 INSERT INTO TMP_JOURNAL_PARAM (        
  GL_CONSTNAME        
  ,TRX_CODE        
  ,FLAG_CF        
  ,JOURNALCODE        
  ,DRCR        
  ,GLNO        
  ,GL_INTERNAL_CODE        
  ,COSTCENTER        
  ,JOURNAL_DESC        
  ,CCY        
  )        
 SELECT GL_CONSTNAME        
  ,TRX_CODE        
  ,FLAG_CF        
  ,JOURNALCODE        
  ,DRCR        
  ,GLNO        
  ,GL_INTERNAL_CODE        
  ,COSTCENTER        
  ,JOURNAL_DESC        
  ,CCY        
 FROM IFRS_JOURNAL_PARAM        
 WHERE JOURNALCODE IN (        
   'ACCRU'        
   ,'ACCRU_NE'        
   ,'ITRCG'        
   ,'ITRCG_SL'        
   ,'ACCRU_SL'        
   ,'ADJMR'        
   ,'ITRCG_NE'        
   ,'ITRCG2'        
   ,'ITRCG2_SL'        
   ,'ITRCG1'       
   );        
        
 EXECUTE ('TRUNCATE TABLE TMP_JOURNAL');        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'INSERT TMP_JOURNAL'        
  )        
        
 INSERT INTO TMP_JOURNAL (        
  DOWNLOAD_DATE        
  ,MASTERID        
  ,ACCTNO        
  ,DATASOURCE        
  ,PRDTYPE        
  ,PRDCODE        
  ,TRXCODE        
  ,BRANCH        
  ,CCY        
  ,JOURNALCODE        
  ,DRCR        
  ,FLAG_CF        
  ,REVERSE        
  ,VALCTR_CODE        
  ,GLNO        
  ,ORG_AMOUNT        
  ,IDR_AMOUNT        
  ,CLS_AMOUNT        
  ,ACT_AMOUNT        
  ,        
  --ORG_AMOUNT_SL ,            
  --IDR_AMOUNT_SL ,            
  METHOD        
  )        
 SELECT @V_CURRDATE        
  ,GL.MASTERID        
  ,GL.ACCTNO        
  ,GL.DATASOURCE        
  ,GL.PRDTYPE        
  ,GL.PRDCODE        
  ,GL.TRXCODE        
  ,GL.BRANCH        
  ,GL.CCY        
  ,GL.JOURNALCODE        
  ,GL.DRCR        
  ,GL.FLAG_CF        
  ,GL.REVERSE        
  ,GL.VALCTR_CODE        
  ,GL.GLNO        
  ,SUM(CASE         
    WHEN GL.DRCR = 'C'        
     THEN GL.N_AMOUNT        
    ELSE GL.N_AMOUNT * - 1        
END) AS ORG_AMOUNT        
  ,SUM(CASE         
    WHEN GL.DRCR = 'C'        
     THEN GL.N_AMOUNT_IDR * ISNULL(1, 1)        
    ELSE GL.N_AMOUNT_IDR * ISNULL(1, 1) * - 1        
    END) AS IDR_AMOUNT        
  ,0 CLS_AMOUNT        
  ,0 ACT_AMOUNT        
  ,        
  /*        
      SUM(CASE WHEN METHOD = 'SL'            
                                 THEN CASE WHEN GL.DRCR = 'C' THEN GL.N_AMOUNT            
                       ELSE GL.N_AMOUNT * -1            
                                      END            
                                 ELSE 0            
                            END) AS ORG_AMOUNT_SL ,            
                        SUM(CASE WHEN METHOD = 'SL'            
                                 THEN CASE WHEN GL.DRCR = 'C'            
                                           THEN GL.N_AMOUNT_IDR * ISNULL(1, 1)                                                 ELSE GL.N_AMOUNT_IDR * ISNULL(1, 1)            
                                                * -1            
                                      END            
                                 ELSE 0            
                            END) AS IDR_AMOUNT_SL ,            
                        */        
  METHOD        
 FROM IFRS_ACCT_JOURNAL_DATA GL        
 WHERE GL.DOWNLOAD_DATE = @V_CURRDATE  
	AND GL.TRXCODE <> 'BENEFIT'  
	and gl.JOURNALCODE NOT IN ('OCIMTM','PLMTM')     -- ADDED BTPN FOR EXCLUDE GAIN LOSS JOURNAL, BECAUSE OF TRX CODE 
 --AND  GL.JOURNALCODE2 <> 'ITRCG1'            
 GROUP BY GL.MASTERID        
  ,GL.ACCTNO        
  ,GL.DATASOURCE        
  ,GL.PRDTYPE        
  ,GL.PRDCODE        
  ,GL.TRXCODE        
  ,GL.BRANCH        
  ,GL.CCY        
  ,GL.JOURNALCODE        
  ,GL.DRCR        
  ,GL.FLAG_CF        
  ,GL.REVERSE        
  ,GL.VALCTR_CODE        
  ,GL.GLNO        
  ,METHOD;        
        
 EXECUTE ('TRUNCATE TABLE TMP_LOAN_REPORT_RECON');        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'INSERT TMP_PSAK_RECON CURR'        
  )        
        
 --INSERT CURRENT DATE DATA              
 INSERT INTO TMP_LOAN_REPORT_RECON (        
  DOWNLOAD_DATE        
  ,MASTERID        
  ,ACCOUNT_NUMBER        
  ,BRANCH_CODE        
  ,TRANSACTION_CODE        
  ,CCY        
  ,INITIAL_GL_FEE_AMT        
  ,INITIAL_GL_COST_AMT        
  ,UNAMORT_GL_FEE_AMT        
  ,UNAMORT_GL_COST_AMT        
  ,AMORT_GL_FEE_AMT        
  ,DAILY_AMORT_GL_FEE_AMT        
  ,MTD_AMORT_GL_FEE_AMT        
  ,YTD_AMORT_GL_FEE_AMT        
  ,AMORT_GL_COST_AMT        
  ,DAILY_AMORT_GL_COST_AMT        
  ,MTD_AMORT_GL_COST_AMT        
  ,YTD_AMORT_GL_COST_AMT        
  ,METHOD        
  )        
 SELECT A.DOWNLOAD_DATE        
  ,A.MASTERID        
  ,A.ACCTNO        
  ,A.BRANCH        
  ,null        
  ,A.CCY        
  ,SUM(CASE         
    WHEN A.JOURNALCODE = 'DEFA0'   AND FLAG_CF = 'F'      
     AND A.GLNO = X1.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS INITIAL_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.JOURNALCODE = 'DEFA0'   AND FLAG_CF = 'C'     
     AND A.GLNO = X4.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS INITIAL_GL_COST_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'F'        
     AND A.GLNO = X2.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS UNAMORT_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'C'        
     AND A.GLNO = X5.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS UNAMORT_GL_COST_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'F'        
     AND A.GLNO = X3.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS AMORT_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'F'        
     AND A.GLNO = X3.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS DAILY_AMORT_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'F'        
     AND A.GLNO = X3.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS MTD_AMORT_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'F'        
     AND A.GLNO = X3.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS YTD_AMORT_GL_FEE_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'C'        
     AND A.GLNO = X6.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS AMORT_GL_COST_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'C'        
     AND A.GLNO = X6.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS DAILY_AMORT_GL_COST_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'C'        
     AND A.GLNO = X6.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS MTD_AMORT_GL_COST_AMT        
  ,SUM(CASE         
    WHEN A.FLAG_CF = 'C'        
     AND A.GLNO = X6.GLNO        
     THEN A.ORG_AMOUNT        
    ELSE 0        
    END) AS YTD_AMORT_GL_COST_AMT        
  ,METHOD        
 FROM TMP_JOURNAL A        
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ITRCG'        
    ,'ITRCG_SL'        
    ,'ITRCG2'        
    ,'ITRCG2_SL'        
    ,'ITRCG_NE'        
    ,'ITRCG1'        
    )        
   AND DRCR = 'C'        
   AND FLAG_CF = 'F'        
  ) X1 ON A.GLNO = X1.GLNO        
 --UNAMORT FEE GL                    
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ACCRU'        
    ,'ACCRU_SL'        
    ,'ACCRU_NE'        
 ,'OTHER'      
    )        
   AND DRCR = 'D'        
   AND FLAG_CF = 'F'        
  ) X2 ON A.GLNO = X2.GLNO        
 --AMORT FEE GL                    
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ACCRU'        
    ,'ACCRU_SL'        
    ,'ACCRU_NE'        
 ,'OTHER'      
    )        
   AND DRCR = 'C'        
   AND FLAG_CF = 'F'        
  ) X3 ON A.GLNO = X3.GLNO        
 --INITIAL COST GL                   
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ITRCG'        
    ,'ITRCG_SL'        
    ,'ITRCG2'        
    ,'ITRCG2_SL'        
    ,'ITRCG_NE'        
    ,'ITRCG1'        
    )        
   AND DRCR = 'D'        
   AND FLAG_CF = 'C'        
  ) X4 ON A.GLNO = X4.GLNO        
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ACCRU'        
    ,'ACCRU_SL'        
    ,'ACCRU_NE'        
 ,'OTHER'      
    )        
   AND DRCR = 'C'        
   AND FLAG_CF = 'C'        
  ) X5 ON A.GLNO = X5.GLNO        
 LEFT JOIN (        
  SELECT DISTINCT GLNO        
  FROM TMP_JOURNAL_PARAM        
  WHERE JOURNALCODE IN (        
    'ACCRU'        
    ,'ACCRU_SL'        
    ,'ACCRU_NE'        
 ,'OTHER'      
    )        
   AND DRCR = 'D'        
   AND FLAG_CF = 'C'        
  ) X6 ON A.GLNO = X6.GLNO        
 GROUP BY A.DOWNLOAD_DATE        
  ,A.MASTERID        
  ,A.ACCTNO        
  ,A.BRANCH         
  ,A.CCY        
  ,A.METHOD;        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'INSERT TMP_IFRS_RECON PREV'        
  )        
        
 --INSERT PREVIOUS DATE DATA                    
 INSERT INTO TMP_LOAN_REPORT_RECON (        
  DOWNLOAD_DATE        
  ,MASTERID        
  ,ACCOUNT_NUMBER        
  ,BRANCH_CODE        
  ,TRANSACTION_CODE        
  ,CCY        
  ,INITIAL_GL_FEE_AMT      
  ,INITIAL_GL_COST_AMT        
  ,UNAMORT_GL_FEE_AMT        
  ,UNAMORT_GL_COST_AMT        
  ,AMORT_GL_FEE_AMT        
  ,DAILY_AMORT_GL_FEE_AMT        
  ,MTD_AMORT_GL_FEE_AMT        
  ,YTD_AMORT_GL_FEE_AMT        
  ,AMORT_GL_COST_AMT        
  ,DAILY_AMORT_GL_COST_AMT        
  ,MTD_AMORT_GL_COST_AMT        
  ,YTD_AMORT_GL_COST_AMT        
  ,METHOD        
  )        
 SELECT @V_CURRDATE        
  ,A.MASTERID        
  ,A.ACCOUNT_NUMBER        
  ,A.BRANCH_CODE        
  ,A.TRANSACTION_CODE        
  ,A.CCY        
  ,A.INITIAL_GL_FEE_AMT        
  ,A.INITIAL_GL_COST_AMT        
  ,A.UNAMORT_GL_FEE_AMT        
  ,A.UNAMORT_GL_COST_AMT        
  ,A.AMORT_GL_FEE_AMT        
  ,0 AS DAILY_AMORT_GL_FEE_AMT        
  ,CASE         
   WHEN @ISBOM = 0        
    THEN MTD_AMORT_GL_FEE_AMT        
   ELSE 0        
   END AS MTD_AMORT_GL_FEE_AMT        
  ,CASE         
   WHEN @ISBOY = 0        
    THEN YTD_AMORT_GL_FEE_AMT        
   ELSE 0        
   END AS YTD_AMORT_GL_FEE_AMT        
  ,A.AMORT_GL_COST_AMT        
  ,0 AS DAILY_AMORT_GL_COST_AMT        
  ,CASE         
   WHEN @ISBOM = 0        
    THEN MTD_AMORT_GL_COST_AMT        
   ELSE 0        
   END AS MTD_AMORT_GL_COST_AMT        
  ,CASE         
   WHEN @ISBOY = 0        
    THEN YTD_AMORT_GL_COST_AMT        
   ELSE 0        
   END AS YTD_AMORT_GL_COST_AMT        
  ,METHOD        
 FROM IFRS_LOAN_REPORT_RECON A        
 WHERE A.DOWNLOAD_DATE = @V_PREVDATE;        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'INSERT PSAK_RECON'        
  )        
        
 --INSERT INTO IFRS_LOAN_REPORT_RECON                    
 INSERT INTO IFRS_LOAN_REPORT_RECON (        
  DOWNLOAD_DATE        
  ,MASTERID        
  ,ACCOUNT_NUMBER        
  ,TRANSACTION_CODE        
  ,CCY    
  ,INITIAL_GL_FEE_AMT  
  ,INITIAL_GL_COST_AMT        
  ,UNAMORT_GL_FEE_AMT        
  ,UNAMORT_GL_COST_AMT        
  ,AMORT_GL_FEE_AMT        
  ,DAILY_AMORT_GL_FEE_AMT        
  ,MTD_AMORT_GL_FEE_AMT        
  ,YTD_AMORT_GL_FEE_AMT        
  ,AMORT_GL_COST_AMT        
  ,DAILY_AMORT_GL_COST_AMT        
  ,MTD_AMORT_GL_COST_AMT        
  ,YTD_AMORT_GL_COST_AMT        
  ,METHOD        
  )        
 SELECT X.DOWNLOAD_DATE              
  ,X.MASTERID              
  ,X.ACCOUNT_NUMBER              
  ,X.TRANSACTION_CODE        
  ,X.CCY    
  ,SUM(INITIAL_GL_FEE_AMT)  
  ,SUM(INITIAL_GL_COST_AMT)              
  ,SUM(X.UNAMORT_GL_FEE_AMT)           
  ,SUM(X.UNAMORT_GL_COST_AMT)        
  ,SUM(X.AMORT_GL_FEE_AMT)         
  ,SUM(X.DAILY_AMORT_GL_FEE_AMT)        
  ,SUM(X.MTD_AMORT_GL_FEE_AMT)        
  ,SUM(X.YTD_AMORT_GL_FEE_AMT)        
  ,SUM(X.AMORT_GL_COST_AMT)        
  ,SUM(X.DAILY_AMORT_GL_COST_AMT)        
  ,SUM(X.MTD_AMORT_GL_COST_AMT)        
  ,SUM(X.YTD_AMORT_GL_COST_AMT)                 
  ,X.METHOD         
  FROM TMP_LOAN_REPORT_RECON X              
 WHERE X.DOWNLOAD_DATE = @V_CURRDATE          
 GROUP BY X.DOWNLOAD_DATE              
  ,X.MASTERID              
  ,X.ACCOUNT_NUMBER              
  ,X.TRANSACTION_CODE        
  ,X.CCY            
  ,X.METHOD          
            
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'UPD PSAK_RECON'        
  )        
        
 /*UPDATE DATA FROM PREV DATE*/        
 UPDATE A        
 SET A.FACILITY_NUMBER = B.FACILITY_NUMBER        
  ,A.CUSTOMER_NAME = B.CUSTOMER_NAME        
  ,A.BRANCH_CODE = B.BRANCH_CODE        
  ,A.DATA_SOURCE = B.DATA_SOURCE        
  ,A.PRODUCT_CODE = B.PRODUCT_CODE        
  ,A.PRODUCT_TYPE = B.PRODUCT_TYPE        
  ,A.JF_FLAG = B.JF_FLAG        
  ,        
  --A.CURRENCY               = B.CURRENCY,              
  A.EXCHANGE_RATE = B.EXCHANGE_RATE        
  ,        
  --A.DEPARTMENT          = B.DEPARTEMEN,              
  --A.SEGMENTATION           = B.FACILITY_DESC,              
  A.BI_COLLECTABILITY = B.BI_COLLECTABILITY        
  ,A.DAY_PAST_DUE = B.DAY_PAST_DUE        
  ,A.INTEREST_RATE = B.INTEREST_RATE        
  ,A.EIR = B.EIR        
  ,A.LOAN_START_DATE = B.LOAN_START_DATE        
  ,A.LOAN_DUE_DATE = B.LOAN_DUE_DATE        
  ,A.OUTSTANDING = B.OUTSTANDING        
  ,A.OUTSTANDING_JF = B.OUTSTANDING_JF        
  ,A.OUTSTANDING_BANK = B.OUTSTANDING_BANK        
  ,A.PLAFOND = B.PLAFOND        
  ,A.METHOD = B.METHOD        
 FROM IFRS_LOAN_REPORT_RECON A        
 JOIN IFRS_LOAN_REPORT_RECON B ON A.MASTERID = B.MASTERID        
  AND A.DOWNLOAD_DATE = @V_CURRDATE        
  AND B.DOWNLOAD_DATE = @V_PREVDATE        
        
 --UPDATE FIELDS FROM MASTER ACCOUNT FROM CURRDATE            
 MERGE INTO IFRS_LOAN_REPORT_RECON A        
 USING IFRS_MASTER_ACCOUNT B        
  --USING IFRS_MASTER_ACCOUNT_ACV B              
  ON (        
    A.MASTERID = B.MASTERID        
    AND A.DOWNLOAD_DATE = @V_CURRDATE        
    AND B.DOWNLOAD_DATE = @V_CURRDATE        
    )        
 WHEN MATCHED        
  THEN        
   UPDATE        
   SET A.FACILITY_NUMBER = B.FACILITY_NUMBER        
    ,A.CUSTOMER_NAME = B.CUSTOMER_NAME        
    ,A.BRANCH_CODE = B.BRANCH_CODE        
    ,A.DATA_SOURCE = B.DATA_SOURCE        
    ,A.PRODUCT_CODE = B.PRODUCT_CODE        
    ,A.PRODUCT_TYPE = B.PRODUCT_TYPE        
 ,A.JF_FLAG = B.JF_FLAG        
    ,        
    --A.CURRENCY               = B.CURRENCY,              
    A.EXCHANGE_RATE = B.EXCHANGE_RATE        
    ,        
    --A.DEPARTMENT             = B.DEPARTEMEN,              
    --A.SEGMENTATION           = B.FACILITY_DESC,              
    A.BI_COLLECTABILITY = B.BI_COLLECTABILITY        
    ,A.DAY_PAST_DUE = B.DAY_PAST_DUE        
    ,A.INTEREST_RATE = B.INTEREST_RATE        
    ,A.EIR = B.EIR        
    ,A.LOAN_START_DATE = B.LOAN_START_DATE        
    ,A.LOAN_DUE_DATE = B.LOAN_DUE_DATE        
    ,A.OUTSTANDING = B.OUTSTANDING        
    ,A.OUTSTANDING_JF = B.OUTSTANDING_JF        
    ,A.OUTSTANDING_BANK = B.OUTSTANDING_BANK        
    ,A.PLAFOND = B.PLAFOND        
    ,A.UNAMORT_MASTER_FEE_AMT = ISNULL(B.UNAMORT_FEE_AMT, 0)  
    ,A.UNAMORT_MASTER_FEE_NONEIR_AMT = ISNULL(B.UNAMORT_FEE_AMT_JF, 0)        
    ,A.UNAMORT_MASTER_COST_AMT = ISNULL(B.UNAMORT_COST_AMT, 0)        
    ,A.UNAMORT_MASTER_COST_NONEIR_AMT = ISNULL(B.UNAMORT_COST_AMT_JF, 0)        
    ,A.METHOD = B.AMORT_TYPE;        
    
   
    
     
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
   ,'SP_IFRS_LI_REPORT_RECON'              
   , 'UPD INITIAL RECON'          
   )              
  
  
	--INITIAL TRX AMOUNT          
	  UPDATE  A          
	  SET     A.INITIAL_TRX_FEE_AMT = ISNULL(C.FEE_AMOUNT,          
	     B.INITIAL_TRX_FEE_AMT) ,          
	 A.INITIAL_TRX_COST_AMT = ISNULL(C.COST_AMOUNT,          
	   B.INITIAL_TRX_COST_AMT)          
	  FROM    IFRS_LOAN_REPORT_RECON A          
	 LEFT JOIN IFRS_LOAN_REPORT_RECON B ON A.MASTERID = B.MASTERID          
	   AND B.DOWNLOAD_DATE = @v_prevdate          
	 LEFT JOIN ( SELECT  TRX.MASTERID ,          
	   SUM(TRX.AMOUNT_FEE) AS FEE_AMOUNT ,          
	   SUM(TRX.AMOUNT_COST) AS COST_AMOUNT              
	  --FROM PSAK_ACCT_COST_FEE TRX            
	  FROM    IFRS_ACCT_COST_FEE_SUMM TRX ( NOLOCK )          
	 WHERE   TRX.DOWNLOAD_DATE = @v_currdate          
	 GROUP BY TRX.MASTERID          
	  ) C ON A.MASTERID = C.MASTERID          
	  WHERE   A.DOWNLOAD_DATE = @v_currdate        
    
         
 --A.UNAMORT_MASTER_FEE_AMT = ROUND(ISNULL(B.UNAMOR_ORIGINATION_FEE_AMT,0), @V_ROUND, @V_FUNCROUND) + ROUND(ISNULL(B.UNAMOR_ORIGINATION_FEE_AMT_SL,0), @V_ROUND, @V_FUNCROUND),             
 --A.UNAMORT_MASTER_COST_AMT = ROUND(ISNULL(B.UNAMOR_TRANS_COST_AMT,0), @V_ROUND,@V_FUNCROUND) + ROUND(ISNULL(B.UNAMOR_TRANS_COST_AMT_SL,0), @V_ROUND, @V_FUNCROUND) ;                
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
  ,'SP_IFRS_REPORT_RECON'        
  ,'UPD COUNTER RECON'        
  )        
        
 --UPDATE COUNTER CHECK MASTER ACCOUNT                 
 UPDATE A        
 SET A.COUNTER_CHECK_FEE = CASE         
   WHEN Z.FLAG_AL = 'L'        
    THEN ROUND((SUMMARY.INITIAL_GL_FEE_AMT - SUMMARY.UNAMORT_GL_FEE_AMT - SUMMARY.AMORT_GL_FEE_AMT) + (A.UNAMORT_MASTER_FEE_AMT - SUMMARY.UNAMORT_GL_FEE_AMT), @V_ROUND, @V_FUNCROUND)        
   ELSE ROUND((SUMMARY.INITIAL_GL_FEE_AMT - SUMMARY.UNAMORT_GL_FEE_AMT - SUMMARY.AMORT_GL_FEE_AMT) + (A.UNAMORT_MASTER_FEE_AMT + SUMMARY.UNAMORT_GL_FEE_AMT), @V_ROUND, @V_FUNCROUND)        
   END        
  ,A.COUNTER_CHECK_COST = CASE         
   WHEN Z.FLAG_AL = 'L'        
    THEN ROUND((SUMMARY.INITIAL_GL_COST_AMT - SUMMARY.UNAMORT_GL_COST_AMT - SUMMARY.AMORT_GL_COST_AMT) + (A.UNAMORT_MASTER_COST_AMT - SUMMARY.UNAMORT_GL_COST_AMT), @V_ROUND, @V_FUNCROUND)        
   ELSE ROUND((SUMMARY.INITIAL_GL_COST_AMT- SUMMARY.UNAMORT_GL_COST_AMT - SUMMARY.AMORT_GL_COST_AMT) + (A.UNAMORT_MASTER_COST_AMT + SUMMARY.UNAMORT_GL_COST_AMT), @V_ROUND, @V_FUNCROUND)        
   END        
 FROM IFRS_LOAN_REPORT_RECON A        
 INNER JOIN (        
  SELECT MASTERID        
   ,SUM(X.INITIAL_GL_FEE_AMT) INITIAL_GL_FEE_AMT        
   ,SUM(X.UNAMORT_GL_FEE_AMT) UNAMORT_GL_FEE_AMT        
   ,SUM(X.AMORT_GL_FEE_AMT) AMORT_GL_FEE_AMT        
   ,SUM(X.INITIAL_GL_COST_AMT) INITIAL_GL_COST_AMT        
   ,SUM(X.UNAMORT_GL_COST_AMT) UNAMORT_GL_COST_AMT        
   ,SUM(X.AMORT_GL_COST_AMT) AMORT_GL_COST_AMT        
  FROM IFRS_LOAN_REPORT_RECON X        
  WHERE X.DOWNLOAD_DATE = @V_CURRDATE        
  GROUP BY MASTERID        
  ) SUMMARY ON SUMMARY.MASTERID = A.MASTERID        
 LEFT JOIN IFRS_PRODUCT_PARAM Z ON A.DATA_SOURCE = Z.DATA_SOURCE        
  AND A.PRODUCT_CODE = Z.PRD_CODE        
  AND A.PRODUCT_TYPE = Z.PRD_TYPE        
  AND (        
   A.CCY = Z.CCY        
   OR Z.CCY = 'ALL'        
   )        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
        
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
  ,'SP_IFRS_REPORT_RECON'        
  ,''        
  )        
END; 

GO
