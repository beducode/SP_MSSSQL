USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPMM_CROSS_SEQUENCE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_IMPMM_CROSS_SEQUENCE]              
@DOWNLOAD_DATE DATE = NULL,                      
@MODEL_TYPE VARCHAR(4) = '',                      
@MODEL_ID BIGINT = 0              
AS              
DECLARE                                                   
@V_CURRDATE DATE,              
@SQLRATING_CODE NVARCHAR(MAX),
@SQLRATING_CODE2 NVARCHAR(MAX),              
@PRD_TYPE_VAL_CS VARCHAR(MAX),              
@RULE_ID INT,              
@LGD_ID INT,              
@CCF_ID INT,              
@DEFAULT_ID INT,              
@CEKIMA INT              
            
IF(@DOWNLOAD_DATE IS NULL)                                        
BEGIN                                       
    SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE                                
END                                        
ELSE                                        
BEGIN                                        
    SELECT @V_CURRDATE = @DOWNLOAD_DATE                                        
END        
             
---- CLEAN & REPLACE FROM IFRS MASTER ACCOUNT MONTHLY              
DELETE FROM IFRS_MASTER_ACCOUNT WHERE DOWNLOAD_DATE = @V_CURRDATE              
              
SELECT @PRD_TYPE_VAL_CS = VALUE1 FROM IFRS9..TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'PRD_TYPE_CS'              
              
BEGIN              
SET NOCOUNT ON;              
              
  IF OBJECT_ID ('TEMPDB.DBO.#IMA') IS NOT NULL DROP TABLE #IMA                      
               
 ---- GET DATA CROSS SEGMENT FROM STG_M_LOAN              
 SELECT A.BUSS_DATE AS DOWNLOAD_DATE,                                        
  A.CIF + '_' + A.DEAL_REF + '_' + A.DEAL_TYPE AS MASTERID,                           
  CASE WHEN PD.PRD_TYPE IN ('MB','AR FINANCING') THEN               
  CASE               
  WHEN LEFT(A.RA_CODE,LEN('68')) = '68' THEN 'CROSS_SEGMENT3'               
  WHEN LEFT(A.RA_CODE,LEN('A')) = 'A' THEN 'CROSS_SEGMENT2'               
  WHEN LEFT(A.RA_CODE,LEN('B')) = 'B' THEN 'CROSS_SEGMENT1'               
  WHEN LEFT(A.REL_OB_MGR_1,LEN('68')) = '68' THEN 'CROSS_SEGMENT3'               
  WHEN LEFT(A.REL_OB_MGR_1,LEN('A')) = 'A' THEN 'CROSS_SEGMENT2'               
  WHEN LEFT(A.REL_OB_MGR_1,LEN('B')) = 'B' THEN 'CROSS_SEGMENT1'               
  ELSE               
  'N/A' END               
  ELSE 'N/A' END               
  AS SEGMENT_FLAG,
  CG.OBLIGOR_GRADE AS RATING_CODE              
 INTO #IMA              
 FROM IFRS9_STG..STG_M_LOAN A (NOLOCK)                                          
 LEFT JOIN IFRS9_STG..DM_EXCHANGE_RATE_T24 D(NOLOCK)  ON A.CCY = D.CURR_CD AND A.BUSS_DATE = D.YMD                          
 LEFT JOIN IFRS9_STG..STG_COMMITMENT_LOAN E(NOLOCK)  ON E.SOURCE_SYSTEM <> 'T24' AND A.BUSS_DATE = E.BUSS_DATE AND A.CIF + '_' + A.DEAL_REF + '_' + A.DEAL_TYPE = E.CIF + '_' + E.DEAL_REF + '_' + E.DEAL_TYPE                                   
 LEFT JOIN IFRS9_STG..STG_M_LOAN_RESTRUKTUR_COLLECT F(NOLOCK)  ON A.BUSS_DATE = F.BUSS_DATE AND A.CIF + '_' + A.DEAL_REF + '_' + A.DEAL_TYPE =  F.CIF + '_' + F.DEAL_REF + '_' + F.DEAL_TYPE                                          
 LEFT JOIN IFRS9_STG..TBL_MASTER_PRODUCT_BANKWIDE G(NOLOCK)  ON A.DEAL_TYPE = G.PRODUCT_CODE                                                          
 LEFT JOIN IFRS9_STG..STG_CIF H(NOLOCK)  ON H.SOURCE_SYSTEM <> 'T24' AND A.CIF = H.CIF AND CASE WHEN A.SOURCE_SYSTEM = 'CMS' THEN 'EQ' ELSE A.SOURCE_SYSTEM END = H.SOURCE_SYSTEM                        
 ---- ADD BY BEDU STG_IFRS_ADDINFO_CIF                        
 LEFT JOIN IFRS9_STG..STG_IFRS_ADDINFO_CIF J(NOLOCK)  ON A.CIF = J.CIF AND J.T24_FLAG = 'Y' AND A.DEAL_TYPE = 'H1'                       
 LEFT JOIN IFRS9_STG..STG_M_LOAN_PENYAMAAN_COLLECT I(NOLOCK)  ON I.SOURCE_SYSTEM <> 'T24' AND A.CIF + '_' + A.DEAL_REF + '_' + A.DEAL_TYPE = I.CIF + '_' + I.DEAL_REF + '_' + I.DEAL_TYPE  AND I.BUSS_DATE =  '20220531'                  
 LEFT JOIN (SELECT PRD_CODE, PRD_TYPE FROM IFRS9..IFRS_MASTER_PRODUCT_PARAM(NOLOCK) WHERE IS_DELETE = 0 AND PRD_TYPE IN ('MB','AR FINANCING')) PD ON A.DEAL_TYPE = PD.PRD_CODE                  
 JOIN TBLU_CUSTOMER_GRADING CG ON A.BUSS_DATE = CG.DOWNLOAD_DATE AND A.CIF = CG.CUSTOMER_NUMBER
 WHERE A.SOURCE_SYSTEM <> 'T24' AND A.BUSS_DATE = @V_CURRDATE              
              
 CREATE NONCLUSTERED INDEX #NCI_IMA ON DBO.#IMA (DOWNLOAD_DATE ASC, MASTERID ASC)                 
 WITH (PAD_INDEX = OFF, ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, SORT_IN_TEMPDB = OFF, FILLFACTOR =100) ON [PRIMARY];                
                      
 INSERT INTO IFRS_MASTER_ACCOUNT              
  (DOWNLOAD_DATE              
 ,MASTERID              
 ,MASTER_ACCOUNT_CODE              
 ,DATA_SOURCE              
 ,GLOBAL_CUSTOMER_NUMBER              
 ,CUSTOMER_NUMBER              
 ,CUSTOMER_NAME              
 ,FACILITY_NUMBER              
 ,ACCOUNT_NUMBER              
 ,PREVIOUS_ACCOUNT_NUMBER              
 ,ACCOUNT_STATUS              
 ,INTEREST_RATE              
 ,MARKET_RATE              
 ,PRODUCT_GROUP              
 ,PRODUCT_TYPE              
 ,PRODUCT_CODE              
 ,PRODUCT_ENTITY              
 ,GL_CONSTNAME              
 ,BRANCH_CODE              
 ,BRANCH_CODE_OPEN              
 ,CURRENCY              
 ,EXCHANGE_RATE              
 ,INITIAL_OUTSTANDING              
 ,OUTSTANDING              
 ,OUTSTANDING_IDC              
 ,OUTSTANDING_JF              
 ,OUTSTANDING_BANK              
 ,OUTSTANDING_PASTDUE              
 ,OUTSTANDING_WO              
 ,PLAFOND              
 ,PLAFOND_CASH              
 ,INTEREST_ACCRUED              
 ,INSTALLMENT_AMOUNT              
 ,UNUSED_AMOUNT              
 ,DOWN_PAYMENT_AMOUNT              
 ,JF_FLAG              
 ,LOAN_START_DATE              
 ,LOAN_DUE_DATE              
 ,LOAN_START_AMORTIZATION              
 ,LOAN_END_AMORTIZATION              
 ,INSTALLMENT_GRACE_PERIOD              
 ,NEXT_PAYMENT_DATE              
 ,NEXT_INT_PAYMENT_DATE              
 ,LAST_PAYMENT_DATE              
 ,FIRST_INSTALLMENT_DATE              
 ,TENOR              
 ,REMAINING_TENOR              
 ,PAYMENT_CODE              
 ,PAYMENT_TERM              
 ,INTEREST_CALCULATION_CODE              
 ,INTEREST_PAYMENT_TERM              
 ,RESTRUCTURE_DATE              
 ,RESTRUCTURE_FLAG              
 ,POCI_FLAG              
 ,STAFF_LOAN_FLAG              
 ,BELOW_MARKET_FLAG              
 ,BTB_FLAG              
 ,COMMITTED_FLAG              
 ,REVOLVING_FLAG              
 ,IAS_CLASS              
 ,IFRS9_CLASS              
 ,AMORT_TYPE              
 ,EIR_STATUS              
 ,ECF_STATUS              
 ,EIR              
 ,EIR_AMOUNT              
 ,FAIR_VALUE_AMOUNT              
 ,INITIAL_UNAMORT_TXN_COST              
 ,INITIAL_UNAMORT_ORG_FEE              
 ,UNAMORT_COST_AMT              
 ,UNAMORT_FEE_AMT              
 ,DAILY_AMORT_AMT              
 ,UNAMORT_AMT_TOTAL_JF              
 ,UNAMORT_FEE_AMT_JF              
 ,UNAMORT_COST_AMT_JF              
 ,ORIGINAL_COLLECTABILITY              
 ,BI_COLLECTABILITY              
 ,DAY_PAST_DUE              
 ,DPD_START_DATE              
 ,DPD_ZERO_COUNTER              
 ,NPL_DATE              
 ,NPL_FLAG              
 ,DEFAULT_DATE              
 ,DEFAULT_FLAG              
 ,WRITEOFF_FLAG              
 ,WRITEOFF_DATE              
 ,IMPAIRED_FLAG              
 ,IS_IMPAIRED              
 ,GROUP_SEGMENT              
 ,SEGMENT              
 ,SUB_SEGMENT              
 ,STAGE              
 ,LIFETIME              
 ,EAD_RULE_ID              
 ,EAD_SEGMENT              
 ,EAD_AMOUNT              
 ,LGD_RULE_ID              
 ,LGD_SEGMENT              
 ,PD_RULE_ID              
 ,PD_SEGMENT              
 ,BUCKET_GROUP              
 ,BUCKET_ID              
 ,ECL_12_AMOUNT              
 ,ECL_LIFETIME_AMOUNT 
 ,ECL_AMOUNT              
 ,CA_UNWINDING_AMOUNT              
 ,IA_UNWINDING_AMOUNT              
 ,IA_UNWINDING_SUM_AMOUNT              
 ,BEGINNING_BALANCE              
 ,ENDING_BALANCE              
 ,WRITEBACK_AMOUNT              
 ,CHARGE_AMOUNT              
 ,CREATEDBY              
 ,CREATEDDATE              
 ,CREATEDHOST              
 ,UPDATEDBY              
 ,UPDATEDDATE              
 ,UPDATEDHOST              
 ,INITIAL_BENEFIT              
 ,UNAMORT_BENEFIT         
 ,SPPI_RESULT              
 ,BM_RESULT              
 ,ECONOMIC_SECTOR              
 ,AO_CODE              
 ,SUFFIX              
 ,ACCOUNT_TYPE              
 ,CUSTOMER_TYPE              
 ,OUTSTANDING_PROFIT_DUE              
 ,RESTRUCTURE_COLLECT_FLAG              
 ,DPD_FINAL              
 ,EIR_SEGMENT              
 ,DPD_CIF              
 ,DPD_FINAL_CIF              
 ,BI_COLLECT_CIF        
 ,PRODUCT_TYPE_1              
 ,RATING_CODE              
 ,CCF              
 ,CCF_RULE_ID              
 ,CCF_EFF_DATE              
 ,ECL_AMOUNT_BFL              
 ,AVG_EIR              
 ,ECL_MODEL_ID              
 ,SEGMENTATION_ID              
 ,PD_ME_MODEL_ID              
 ,DEFAULT_RULE_ID              
 ,PLAFOND_CIF              
 ,RESTRUCTURE_COLLECT_FLAG_CIF              
 ,SOURCE_SYSTEM              
 ,INITIAL_RATING_CODE              
 ,PD_INITIAL_RATE              
 ,PD_CURRENT_RATE              
 ,PD_CHANGE              
 ,LIMIT_CURRENCY              
 ,SUN_ID              
 ,RATING_DOWNGRADE              
 ,EXT_RATING_AGENCY              
 ,EXT_RATING_CODE              
 ,EXT_INIT_RATING_CODE              
 ,INTEREST_TYPE              
 ,SOVEREIGN_FLAG              
 ,ISIN_CODE              
 ,INV_TYPE              
 ,UNAMORT_DISCOUNT_PREMIUM              
 ,DISCOUNT_PREMIUM_AMOUNT              
 ,WATCHLIST_FLAG              
 ,COLL_AMOUNT              
 ,FACILITY_NUMBER_PARENT              
 ,PRODUCT_CODE_T24              
 ,EXT_RATING_DOWNGRADE              
 ,SANDI_BANK              
 ,EARLY_PAYMENT              
 ,EARLY_PAYMENT_FLAG              
 ,EARLY_PAYMENT_DATE              
 ,LOB_CODE              
 ,COUNTER_GUARANTEE_FLAG              
 ,SEGMENT_FLAG)              
 SELECT DOWNLOAD_DATE              
 ,MASTERID              
 ,MASTER_ACCOUNT_CODE              
 ,DATA_SOURCE              
 ,GLOBAL_CUSTOMER_NUMBER              
 ,CUSTOMER_NUMBER              
 ,CUSTOMER_NAME              
 ,FACILITY_NUMBER              
 ,ACCOUNT_NUMBER              
 ,PREVIOUS_ACCOUNT_NUMBER              
 ,ACCOUNT_STATUS              
 ,INTEREST_RATE              
 ,MARKET_RATE              
 ,PRODUCT_GROUP              
 ,PRODUCT_TYPE              
 ,PRODUCT_CODE              
 ,PRODUCT_ENTITY              
 ,GL_CONSTNAME              
 ,BRANCH_CODE              
 ,BRANCH_CODE_OPEN              
 ,CURRENCY              
 ,EXCHANGE_RATE              
 ,INITIAL_OUTSTANDING              
 ,OUTSTANDING              
 ,OUTSTANDING_IDC              
 ,OUTSTANDING_JF              
 ,OUTSTANDING_BANK              
 ,OUTSTANDING_PASTDUE              
 ,OUTSTANDING_WO              
 ,PLAFOND              
 ,PLAFOND_CASH              
 ,INTEREST_ACCRUED              
 ,INSTALLMENT_AMOUNT              
 ,UNUSED_AMOUNT              
 ,DOWN_PAYMENT_AMOUNT              
 ,JF_FLAG              
 ,LOAN_START_DATE              
 ,LOAN_DUE_DATE              
 ,LOAN_START_AMORTIZATION              
 ,LOAN_END_AMORTIZATION              
 ,INSTALLMENT_GRACE_PERIOD              
 ,NEXT_PAYMENT_DATE              
 ,NEXT_INT_PAYMENT_DATE              
 ,LAST_PAYMENT_DATE              
 ,FIRST_INSTALLMENT_DATE              
 ,TENOR              
 ,REMAINING_TENOR              
 ,PAYMENT_CODE              
 ,PAYMENT_TERM              
 ,INTEREST_CALCULATION_CODE              
 ,INTEREST_PAYMENT_TERM              
 ,RESTRUCTURE_DATE       
 ,RESTRUCTURE_FLAG              
 ,POCI_FLAG              
 ,STAFF_LOAN_FLAG              
 ,BELOW_MARKET_FLAG              
 ,BTB_FLAG              
 ,COMMITTED_FLAG              
 ,REVOLVING_FLAG              
 ,IAS_CLASS              
 ,IFRS9_CLASS              
 ,AMORT_TYPE              
 ,EIR_STATUS              
 ,ECF_STATUS              
 ,EIR              
 ,EIR_AMOUNT              
 ,FAIR_VALUE_AMOUNT              
 ,INITIAL_UNAMORT_TXN_COST              
 ,INITIAL_UNAMORT_ORG_FEE              
 ,UNAMORT_COST_AMT              
 ,UNAMORT_FEE_AMT              
 ,DAILY_AMORT_AMT              
 ,UNAMORT_AMT_TOTAL_JF              
 ,UNAMORT_FEE_AMT_JF              
 ,UNAMORT_COST_AMT_JF              
 ,ORIGINAL_COLLECTABILITY              
 ,BI_COLLECTABILITY              
 ,DAY_PAST_DUE              
 ,DPD_START_DATE              
 ,DPD_ZERO_COUNTER              
 ,NPL_DATE              
 ,NPL_FLAG              
 ,DEFAULT_DATE              
 ,DEFAULT_FLAG              
 ,WRITEOFF_FLAG              
 ,WRITEOFF_DATE              
 ,IMPAIRED_FLAG              
 ,IS_IMPAIRED              
 ,GROUP_SEGMENT              
 ,SEGMENT              
 ,SUB_SEGMENT              
 ,STAGE              
 ,LIFETIME              
 ,EAD_RULE_ID              
 ,EAD_SEGMENT              
 ,EAD_AMOUNT              
 ,LGD_RULE_ID              
 ,LGD_SEGMENT              
 ,PD_RULE_ID              
 ,PD_SEGMENT              
 ,BUCKET_GROUP              
 ,BUCKET_ID              
 ,ECL_12_AMOUNT              
 ,ECL_LIFETIME_AMOUNT              
 ,ECL_AMOUNT              
 ,CA_UNWINDING_AMOUNT              
 ,IA_UNWINDING_AMOUNT              
 ,IA_UNWINDING_SUM_AMOUNT              
 ,BEGINNING_BALANCE              
 ,ENDING_BALANCE              
 ,WRITEBACK_AMOUNT              
 ,CHARGE_AMOUNT              
 ,CREATEDBY              
 ,CREATEDDATE              
 ,CREATEDHOST              
 ,UPDATEDBY              
 ,UPDATEDDATE              
 ,UPDATEDHOST              
 ,INITIAL_BENEFIT              
 ,UNAMORT_BENEFIT              
 ,SPPI_RESULT              
 ,BM_RESULT              
 ,ECONOMIC_SECTOR              
 ,AO_CODE              
 ,SUFFIX              
 ,ACCOUNT_TYPE              
 ,CUSTOMER_TYPE              
 ,OUTSTANDING_PROFIT_DUE              
 ,RESTRUCTURE_COLLECT_FLAG              
 ,DPD_FINAL              
 ,EIR_SEGMENT              
 ,DPD_CIF              
 ,DPD_FINAL_CIF              
 ,BI_COLLECT_CIF              
 ,PRODUCT_TYPE_1              
 ,RATING_CODE              
 ,CCF              
 ,CCF_RULE_ID              
 ,CCF_EFF_DATE              
 ,ECL_AMOUNT_BFL              
 ,AVG_EIR              
 ,ECL_MODEL_ID              
 ,SEGMENTATION_ID              
 ,PD_ME_MODEL_ID              
 ,DEFAULT_RULE_ID              
 ,PLAFOND_CIF              
 ,RESTRUCTURE_COLLECT_FLAG_CIF              
 ,SOURCE_SYSTEM              
 ,INITIAL_RATING_CODE              
 ,PD_INITIAL_RATE              
 ,PD_CURRENT_RATE              
 ,PD_CHANGE              
 ,LIMIT_CURRENCY              
 ,SUN_ID              
 ,RATING_DOWNGRADE              
 ,EXT_RATING_AGENCY              
 ,EXT_RATING_CODE              
 ,EXT_INIT_RATING_CODE              
 ,INTEREST_TYPE              
 ,SOVEREIGN_FLAG              
 ,ISIN_CODE              
 ,INV_TYPE              
 ,UNAMORT_DISCOUNT_PREMIUM              
 ,DISCOUNT_PREMIUM_AMOUNT              
 ,WATCHLIST_FLAG              
 ,COLL_AMOUNT              
 ,FACILITY_NUMBER_PARENT              
 ,PRODUCT_CODE_T24              
 ,EXT_RATING_DOWNGRADE              
 ,SANDI_BANK              
 ,EARLY_PAYMENT              
 ,EARLY_PAYMENT_FLAG              
 ,EARLY_PAYMENT_DATE              
 ,LOB_CODE              
 ,COUNTER_GUARANTEE_FLAG              
 ,SEGMENT_FLAG FROM IFRS_MASTER_ACCOUNT_MONTHLY WHERE DOWNLOAD_DATE = @V_CURRDATE                     
              
 ---- START UPDATE SEGMENT FLAG & RATING CODE IFRS_MASTER_ACCOUNT              
 UPDATE A              
 SET A.SEGMENT_FLAG = B.SEGMENT_FLAG,    
 A.RATING_CODE = B.RATING_CODE                  
 FROM IFRS9..IFRS_MASTER_ACCOUNT A               
 LEFT JOIN #IMA B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID              
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE 
 --AND B.SEGMENT_FLAG IN ('CROSS_SEGMENT1','CROSS_SEGMENT2','CROSS_SEGMENT3','CROSS_SEGMENT_LIMIT')
 --AND ISNULL(B.RATING_CODE,'N/A') <> 'N/A'              
   
 UPDATE A              
 SET A.SEGMENT_FLAG = B.SEGMENT_FLAG,    
 A.RATING_CODE = B.RATING_CODE
 --A.BUCKET_ID = NULL,
 --A.BUCKET_GROUP = NULL                  
 FROM IFRS9..IFRS_MASTER_ACCOUNT_MONTHLY A               
 LEFT JOIN IFRS_MASTER_ACCOUNT B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID              
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE 
 --AND B.SEGMENT_FLAG IN ('CROSS_SEGMENT1','CROSS_SEGMENT2','CROSS_SEGMENT3','CROSS_SEGMENT_LIMIT')              
    
 ---- END UPDATE SEGMENT FLAG & RATING CODE IFRS_MASTER_ACCOUNT              
              
 IF OBJECT_ID ('TEMPDB.DBO.#TBLU_CUST_GRADE') IS NOT NULL DROP TABLE #TBLU_CUST_GRADE                
 SELECT DISTINCT CUSTOMER_NUMBER INTO #TBLU_CUST_GRADE FROM IFRS9..TBLU_CUSTOMER_GRADING WHERE DOWNLOAD_DATE= @V_CURRDATE             
              
  ------ CROSS SEGMENT PROFILING LIMIT              
              
  SET @SQLRATING_CODE = ''              
                  
  SET @SQLRATING_CODE = 'UPDATE A                  
  SET A.SEGMENT_FLAG = ''CROSS_SEGMENT_LIMIT''                   
  FROM IFRS9..IFRS_MASTER_ACCOUNT A               
  INNER JOIN #TBLU_CUST_GRADE B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER              
  INNER JOIN (SELECT PRD_CODE FROM IFRS9..IFRS_MASTER_PRODUCT_PARAM WHERE PRD_TYPE IN (''' + REPLACE(@PRD_TYPE_VAL_CS, ',', ''',''') + ''') AND IS_DELETE = 0) PD ON A.PRODUCT_CODE = PD.PRD_CODE                 
  WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + '''              
  AND A.DATA_SOURCE = ''LIMIT'''   

  EXEC SP_EXECUTESQL @SQLRATING_CODE              
  
  SET @SQLRATING_CODE2 = '' 
  
  SET @SQLRATING_CODE2 = 'UPDATE A    
 SET A.SEGMENT_FLAG = CASE WHEN B.CUSTOMER_NUMBER IS NULL THEN ''N/A'' ELSE A.SEGMENT_FLAG END     
 FROM IFRS9..IFRS_MASTER_ACCOUNT A 
 LEFT JOIN #TBLU_CUST_GRADE B ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER   
 WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + ''' '
	
  EXEC SP_EXECUTESQL @SQLRATING_CODE2   
  
  ------ CROSS SEGMENT PROFILING LIMIT            
             
/* START TEMPORARY UPDATE LOB CODE FOR CORPORATE DATA BEFORE CBS GO LIVE */            
 UPDATE A              
 SET A.LOB_CODE = ''             
 FROM IFRS9..IFRS_MASTER_ACCOUNT A               
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE AND LOB_CODE IS NULL              
 AND A.DOWNLOAD_DATE <= '20221231'
            
 ----JAPAN LOB CODE =12            
 --UPDATE A            
 --SET A.LOB_CODE ='12'            
 --FROM IFRS_MASTER_ACCOUNT A            
 --INNER JOIN TBLU_CUSTOMER_GRADING B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER             
 --WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
 --AND DATA_SOURCE IN ('LOAN_T24','TRADE_T24')             
 --AND B.JAP_NON_JAP_IDENTIFIER ='1' --JAPAN LOB CODE =12            
             
 ----JAPAN LOB CODE =22            
 --UPDATE A            
 --SET A.LOB_CODE ='22'            
 --FROM IFRS_MASTER_ACCOUNT A            
 --INNER JOIN TBLU_CUSTOMER_GRADING B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER             
 --WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
 --AND DATA_SOURCE IN ('LOAN_T24','TRADE_T24')             
 -- AND B.JAP_NON_JAP_IDENTIFIER ='2'             
      
 -- IF CUSTOMER CORPORATE NOT UPLOAD GRADING UPDATE LOB_CODE = 42      
 UPDATE A            
 SET A.LOB_CODE = '42'   
 FROM IFRS_MASTER_ACCOUNT A
 LEFT JOIN (SELECT DISTINCT CUSTOMER_NUMBER FROM TBLU_CUSTOMER_GRADING WHERE DOWNLOAD_DATE = @V_CURRDATE) B ON A.DOWNLOAD_DATE= @V_CURRDATE AND A.CUSTOMER_NUMBER=B.CUSTOMER_NUMBER
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
 AND DATA_SOURCE IN ('LOAN_T24','TRADE_T24')            
 AND B.CUSTOMER_NUMBER IS NULL
 AND A.DOWNLOAD_DATE <= '20221231'           
     
 /* END TEMPORARY UPDATE LOB CODE FOR CORPORATE DATA BEFORE CBS GO LIVE */             
            
END 

GO
