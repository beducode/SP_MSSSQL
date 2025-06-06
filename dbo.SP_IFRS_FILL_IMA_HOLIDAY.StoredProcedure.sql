USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_FILL_IMA_HOLIDAY]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_FILL_IMA_HOLIDAY]    
AS    
BEGIN    
    
DECLARE @ISHOLIDAY INT ,      
        @V_CURRDATE DATETIME ,      
        @V_PREVDATE DATETIME                                      
                                                        
                 
    SELECT  @V_CURRDATE = CURRDATE ,      
            @V_PREVDATE = PREVDATE      
    FROM    IFRS_PRC_DATE_AMORT (NOLOCK)     
    
 SELECT @ISHOLIDAY = DBO.FN_HOLIDAY(CURRDATE) FROM IFRS_PRC_DATE_AMORT (NOLOCK)     
    
  IF @IsHoliday = 1       
        BEGIN    
      
  INSERT INTO IFRS_AMORT_LOG     
  (    
     DOWNLOAD_DATE    
     ,DTM    
     ,OPS    
     ,PROCNAME    
     ,REMARK    
  )    
  VALUES     
  (    
     @V_CURRDATE    
     ,CURRENT_TIMESTAMP    
     ,'START COPY IFRS MASTER ACCOUNT'    
     ,'SP_IFRS_FILL_IMA_HOLIDAY'    
     ,''    
  )    
    
  DELETE FROM DBO.IFRS_MASTER_ACCOUNT WHERE DOWNLOAD_DATE = @V_CURRDATE    
    
  INSERT INTO DBO.IFRS_MASTER_ACCOUNT    
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
     ,OUTSTANDING_WO    
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
  )    
  SELECT    
      DATEADD(DAY,1,DOWNLOAD_DATE)    
     ,MASTERID    
     ,MASTER_ACCOUNT_CODE    
     ,DATA_SOURCE    
     ,GLOBAL_CUSTOMER_NUMBER         ,CUSTOMER_NUMBER    
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
     ,OUTSTANDING_WO    
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
  FROM DBO.IFRS_MASTER_ACCOUNT    
  WHERE DOWNLOAD_DATE = @V_PREVDATE AND ISNULL(ACCOUNT_STATUS, ' ') NOT IN ('WO','ET','FF')     
    
  INSERT INTO IFRS_AMORT_LOG     
  (    
     DOWNLOAD_DATE    
     ,DTM    
     ,OPS    
     ,PROCNAME    
     ,REMARK    
  )    
  VALUES     
  (    
     @V_CURRDATE    
     ,CURRENT_TIMESTAMP    
     ,'END COPY IFRS MASTER ACCOUNT'    
     ,'SP_IFRS_FILL_IMA_HOLIDAY'    
     ,''    
  )    
    
    
  INSERT INTO IFRS_AMORT_LOG     
  (    
     DOWNLOAD_DATE    
     ,DTM    
     ,OPS    
     ,PROCNAME    
     ,REMARK    
  )    
  VALUES     
  (    
     @V_CURRDATE    
     ,CURRENT_TIMESTAMP    
     ,'START COPY IFRS HOLIDAY'    
     ,'SP_IFRS_FILL_IMA_HOLIDAY'    
     ,''    
  )    
  DELETE FROM DBO.IFRS_HOLIDAY WHERE DOWNLOAD_DATE = @V_CURRDATE    
    
        INSERT INTO IFRS_HOLIDAY      
                (     
       HOLIDAY_DATE ,      
                   [DESCRIPTION] ,      
                   DOWNLOAD_DATE ,      
                   INSERTDATE      
                )      
        SELECT  HOLIDAY_DATE ,      
                [DESCRIPTION] ,      
                DATEADD(DAY, 1, DOWNLOAD_DATE) ,      
                GETDATE()      
        FROM IFRS_HOLIDAY      
        WHERE DOWNLOAD_DATE = @V_PREVDATE    
      
  INSERT INTO IFRS_AMORT_LOG     
  (    
     DOWNLOAD_DATE    
     ,DTM    
     ,OPS    
     ,PROCNAME    
     ,REMARK    
  )    
  VALUES     
  (    
     @V_CURRDATE    
     ,CURRENT_TIMESTAMP    
     ,'END COPY IFRS HOLIDAY'    
     ,'SP_IFRS_FILL_IMA_HOLIDAY'    
     ,''    
  )      
    
  END    
    
END 
GO
