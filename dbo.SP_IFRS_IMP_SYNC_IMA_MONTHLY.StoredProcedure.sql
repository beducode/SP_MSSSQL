USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SYNC_IMA_MONTHLY]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SYNC_IMA_MONTHLY]      
@DOWNLOAD_DATE DATE = NULL           
AS           
    DECLARE @V_CURRDATE DATE      
    DECLARE @V_PREVMONTH DATE          
BEGIN           
    IF @DOWNLOAD_DATE IS NULL           
    BEGIN           
        SELECT @V_CURRDATE = CURRDATE           
        FROM IFRS_PRC_DATE           
    END      
    ELSE           
    BEGIN           
        SET @V_CURRDATE = @DOWNLOAD_DATE           
    END         
    SET @V_PREVMONTH = EOMONTH(DATEADD(MM, -1, @V_CURRDATE))           
          
    -- EXCLUSION, IMPAIRED FLAG ALWAYS 'C'       
    UPDATE A      
    SET A.IMPAIRED_FLAG = 'C'      
    FROM IFRS_IMA_IMP_CURR A (NOLOCK)      
    JOIN IFRS_ECL_EXCLUSION B (NOLOCK)      
    ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
    AND A.MASTERID = B.MASTERID      
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE              
      
    UPDATE A           
    SET            
        A.LIFETIME = B.LIFETIME           
        ,A.ECL_MODEL_ID = B.ECL_MODEL_ID           
        ,A.EAD_RULE_ID = B.EAD_MODEL_ID           
        ,A.CCF_RULE_ID = B.CCF_RULES_ID          
        ,A.CCF_EFF_DATE = B.CCF_EFF_DATE          
        ,A.CCF = B.CCF          
        ,A.LGD_RULE_ID = B.LGD_MODEL_ID           
        ,A.PD_RULE_ID = B.PD_MODEL_ID           
        ,A.SEGMENTATION_ID = B.SEGMENTATION_ID           
        ,A.PD_ME_MODEL_ID = B.PD_ME_MODEL_ID           
        ,A.BUCKET_GROUP = B.BUCKET_GROUP           
        ,A.BUCKET_ID = B.BUCKET_ID           
        ,A.EAD_AMOUNT = B.EAD_BALANCE           
        ,A.PD_SEGMENT = B.PD_SEGMENT           
        ,A.LGD_SEGMENT = B.LGD_SEGMENT           
        ,A.EAD_SEGMENT = B.EAD_SEGMENT           
        ,A.DEFAULT_FLAG = B.DEFAULT_FLAG           
        ,A.DEFAULT_RULE_ID = B.DEFAULT_RULE_ID           
        ,A.STAGE = B.STAGE  
  ,A.COLL_AMOUNT = B.COLL_AMOUNT           
        ,A.ECL_AMOUNT =        
        CASE        
        WHEN D.MASTERID IS NOT NULL        
        THEN B.EAD_BALANCE * (CAST(D.EXCLUSION_PERCENTAGE AS FLOAT) / 100)            
        ELSE        
   CASE WHEN ISNULL(A.IMPAIRED_FLAG, 'C') = 'C'        
   THEN ISNULL(C.ECL_AMOUNT    ,0)            
   ELSE A.ECL_AMOUNT        
   END        
        END        
        ,A.ECL_AMOUNT_BFL =        
        CASE        
        WHEN D.MASTERID IS NOT NULL        
        THEN B.EAD_BALANCE * (CAST(D.EXCLUSION_PERCENTAGE AS FLOAT) / 100)            
        ELSE        
   CASE        
   WHEN ISNULL(A.IMPAIRED_FLAG, 'C') = 'C'        
   THEN ISNULL(C.ECL_AMOUNT_BFL,0)        
   ELSE A.ECL_AMOUNT_BFL       
   END        
        END      
        ,A.IA_UNWINDING_AMOUNT = CASE WHEN D.MASTERID IS NOT NULL THEN 0 ELSE A.IA_UNWINDING_AMOUNT END           
    FROM IFRS_IMA_IMP_CURR A (NOLOCK)           
    JOIN TMP_IFRS_ECL_IMA B (NOLOCK)           
    ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE           
    AND A.MASTERID = B.MASTERID           
    LEFT JOIN IFRS_ECL_RESULT_HEADER C (NOLOCK)             
    ON B.DOWNLOAD_DATE = C.DOWNLOAD_DATE AND A.MASTERID = C.MASTERID      
    LEFT JOIN IFRS_ECL_EXCLUSION D      
    ON A.MASTERID = D.MASTERID AND A.DOWNLOAD_DATE = D.DOWNLOAD_DATE             
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE           
        
        
 --- UPDATE LIMIT JENIUS ECL = 0 ENHANCEMENT JENIUS MODEL         
 UPDATE A        
 SET A.ECL_AMOUNT = 0 ,A.ECL_AMOUNT_BFL = 0        
 FROM IFRS_IMA_IMP_CURR A          
 INNER JOIN IFRS_CREDITLINE_JENIUS B ON A.FACILITY_NUMBER = B.CREDIT_LINE_REF AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
 WHERE A.DOWNLOAD_DATE  = @V_CURRDATE AND         
 A.DATA_SOURCE = 'LIMIT' AND B.ELIGIBILITY_STATUS = 'NOT_ELIGIBLE'        
         
        
    -------------------- UPDATING BEGINING_BALANCE ------------------        
    UPDATE A        
    SET          
        BEGINNING_BALANCE = CASE WHEN B.ECL_AMOUNT < 0 THEN 0 ELSE B.ECL_AMOUNT END      
    FROM IFRS_IMA_IMP_CURR A      
    JOIN IFRS_IMA_IMP_PREV B      
    ON A.DOWNLOAD_DATE = @V_CURRDATE      
    AND B.DOWNLOAD_DATE = @V_PREVMONTH      
    AND A.MASTERID = B.MASTERID      
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE          
            
    -------------------- UPDATING WRITEBACK, CHARGE, AND ENDING_BALANCE ------------------        
    UPDATE IFRS_IMA_IMP_CURR        
    SET          
        WRITEBACK_AMOUNT =       
        CASE         
   WHEN ISNULL(BEGINNING_BALANCE, 0) > CASE WHEN ISNULL(ECL_AMOUNT, 0) < 0 THEN 0 ELSE ISNULL(ECL_AMOUNT, 0) END            
   THEN ABS(CASE WHEN ISNULL(ECL_AMOUNT, 0) < 0 THEN 0 ELSE ISNULL(ECL_AMOUNT, 0) END  - ISNULL(BEGINNING_BALANCE, 0))         
   ELSE 0         
        END,        
        CHARGE_AMOUNT =         
        CASE         
   WHEN ISNULL(BEGINNING_BALANCE, 0) < CASE WHEN ISNULL(ECL_AMOUNT, 0)<0 THEN 0 ELSE ISNULL(ECL_AMOUNT, 0) END         
   THEN ABS(CASE WHEN ISNULL(ECL_AMOUNT, 0)<0 THEN 0 ELSE ISNULL(ECL_AMOUNT, 0) END  - ISNULL(BEGINNING_BALANCE, 0))         
   ELSE  0         
        END,        
        ENDING_BALANCE =         
        CASE         
     WHEN ISNULL(ECL_AMOUNT, 0)<0         
     THEN 0         
     ELSE ISNULL(ECL_AMOUNT, 0)         
        END        
    WHERE DOWNLOAD_DATE = @V_CURRDATE     
   
 ------ CROSS SEGMENT PROFILING  
  
 UPDATE A        
 SET A.ECL_AMOUNT = 0        
 FROM IFRS_IMA_IMP_CURR A        
 WHERE A.DOWNLOAD_DATE  = @V_CURRDATE   
 AND A.DATA_SOURCE = 'LIMIT' AND A.SEGMENT_FLAG = 'CROSS_SEGMENT_LIMIT'  
   
 ------ CROSS SEGMENT PROFILING        
            
    -------------------- RE-INSERTIN TO IFRS_MASTER_ACCOUNT AND IFRS_MASTER_ACCOUNT_MONTHLY ------------------          
        
    DELETE IFRS_MASTER_ACCOUNT WHERE DOWNLOAD_DATE = @V_CURRDATE          
    DELETE IFRS_MASTER_ACCOUNT_MONTHLY WHERE DOWNLOAD_DATE = @V_CURRDATE           
          
    INSERT INTO IFRS_MASTER_ACCOUNT          
    (          
        DOWNLOAD_DATE            
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
        ,WATCHLIST_FLAG            
        ,COLL_AMOUNT            
        ,FACILITY_NUMBER_PARENT          
        ,EXT_RATING_AGENCY          
        ,EXT_RATING_CODE          
        ,EXT_INIT_RATING_CODE          
        ,INTEREST_TYPE          
        ,SOVEREIGN_FLAG          
        ,ISIN_CODE          
        ,INV_TYPE          
        ,UNAMORT_DISCOUNT_PREMIUM          
        ,DISCOUNT_PREMIUM_AMOUNT            
        ,PRODUCT_CODE_T24          
        ,EXT_RATING_DOWNGRADE          
        ,SANDI_BANK      
		,LOB_CODE      
		,COUNTER_GUARANTEE_FLAG -- INDRA 20220722      
	    ,EARLY_PAYMENT      
	    ,EARLY_PAYMENT_FLAG      
	    ,EARLY_PAYMENT_DATE  
	    ,SEGMENT_FLAG     
    )          
    SELECT             
        DOWNLOAD_DATE            
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
        ,WATCHLIST_FLAG            
        ,COLL_AMOUNT            
        ,FACILITY_NUMBER_PARENT          
        ,EXT_RATING_AGENCY          
        ,EXT_RATING_CODE          
        ,EXT_INIT_RATING_CODE          
        ,INTEREST_TYPE          
        ,SOVEREIGN_FLAG          
        ,ISIN_CODE          
        ,INV_TYPE          
        ,UNAMORT_DISCOUNT_PREMIUM          
        ,DISCOUNT_PREMIUM_AMOUNT            
        ,PRODUCT_CODE_T24          
        ,EXT_RATING_DOWNGRADE          
        ,SANDI_BANK      
		,LOB_CODE      
		,COUNTER_GUARANTEE_FLAG -- INDRA 20220722      
		,EARLY_PAYMENT      
		,EARLY_PAYMENT_FLAG      
		,EARLY_PAYMENT_DATE  
		,SEGMENT_FLAG      
    FROM IFRS_IMA_IMP_CURR (NOLOCK)          
    WHERE DOWNLOAD_DATE = @V_CURRDATE          
          
    INSERT INTO IFRS_MASTER_ACCOUNT_MONTHLY          
    (          
        DOWNLOAD_DATE            
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
        ,WATCHLIST_FLAG            
        ,COLL_AMOUNT            
        ,FACILITY_NUMBER_PARENT          
        ,EXT_RATING_AGENCY          
        ,EXT_RATING_CODE          
        ,EXT_INIT_RATING_CODE          
        ,INTEREST_TYPE          
        ,SOVEREIGN_FLAG          
        ,ISIN_CODE          
        ,INV_TYPE          
        ,UNAMORT_DISCOUNT_PREMIUM          
        ,DISCOUNT_PREMIUM_AMOUNT            
        ,PRODUCT_CODE_T24          
        ,EXT_RATING_DOWNGRADE          
		,SANDI_BANK      
	    ,LOB_CODE       
	    ,COUNTER_GUARANTEE_FLAG -- INDRA 20220722      
	    ,EARLY_PAYMENT      
	    ,EARLY_PAYMENT_FLAG      
	    ,EARLY_PAYMENT_DATE  
	    ,SEGMENT_FLAG  
    )          
    SELECT          
        DOWNLOAD_DATE            
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
        ,WATCHLIST_FLAG            
        ,COLL_AMOUNT            
        ,FACILITY_NUMBER_PARENT          
        ,EXT_RATING_AGENCY          
        ,EXT_RATING_CODE          
        ,EXT_INIT_RATING_CODE          
        ,INTEREST_TYPE          
        ,SOVEREIGN_FLAG          
        ,ISIN_CODE          
        ,INV_TYPE          
        ,UNAMORT_DISCOUNT_PREMIUM          
        ,DISCOUNT_PREMIUM_AMOUNT              
        ,PRODUCT_CODE_T24          
        ,EXT_RATING_DOWNGRADE          
        ,SANDI_BANK      
	    ,LOB_CODE      
	    ,COUNTER_GUARANTEE_FLAG -- INDRA 20220722      
	    ,EARLY_PAYMENT      
	    ,EARLY_PAYMENT_FLAG      
	    ,EARLY_PAYMENT_DATE  
	    ,SEGMENT_FLAG      
    FROM IFRS_IMA_IMP_CURR (NOLOCK)          
    WHERE DOWNLOAD_DATE = @V_CURRDATE          
           
END
GO
