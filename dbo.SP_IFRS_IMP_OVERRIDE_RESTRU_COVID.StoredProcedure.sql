USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_OVERRIDE_RESTRU_COVID]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[SP_IFRS_IMP_OVERRIDE_RESTRU_COVID]  
@DOWNLOAD_DATE DATE = NULL  
AS  
DECLARE @V_CURRDATE DATE  
BEGIN  
  
    IF @DOWNLOAD_DATE IS NULL  
    BEGIN  
        SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE  
    END  
    ELSE  
    BEGIN  
        SET @V_CURRDATE = @DOWNLOAD_DATE  
    END  
  
    DELETE TMP_IFRS_ECL_IMA_COVID WHERE DOWNLOAD_DATE = @V_CURRDATE  
  
    INSERT INTO TMP_IFRS_ECL_IMA_COVID  
    (  
        DOWNLOAD_DATE  
        ,MASTERID  
        ,LIFETIME  
        ,REVOLVING_FLAG  
        ,EIR  
        ,OUTSTANDING  
        ,PLAFOND  
        ,ECL_MODEL_ID  
        ,EAD_MODEL_ID  
        ,CCF_FLAG  
        ,LGD_MODEL_ID  
        ,PD_MODEL_ID  
        ,GROUP_SEGMENT  
        ,SEGMENT  
        ,SUB_SEGMENT  
        ,SEGMENTATION_ID  
        ,CUSTOMER_NUMBER  
        ,PD_ME_MODEL_ID  
        ,BUCKET_GROUP  
        ,BUCKET_ID  
        ,ACCOUNT_NUMBER  
        ,UNAMORT_COST_AMT  
        ,UNAMORT_FEE_AMT  
        ,INTEREST_ACCRUED  
        ,UNUSED_AMOUNT  
        ,FAIR_VALUE_AMOUNT  
        ,EAD_BALANCE  
        ,SICR_RULE_ID  
        ,DPD_CIF  
        ,PRODUCT_ENTITY  
        ,DATA_SOURCE  
        ,PRODUCT_CODE  
        ,PRODUCT_TYPE  
        ,PRODUCT_GROUP  
        ,STAFF_LOAN_FLAG  
        ,IS_IMPAIRED  
        ,PD_SEGMENT  
        ,LGD_SEGMENT  
        ,EAD_SEGMENT  
        ,PREV_ECL_AMOUNT  
        ,SICR_FLAG  
        ,DEFAULT_FLAG  
        ,DEFAULT_RULE_ID  
        ,CCF_RULES_ID  
        ,DPD_FINAL  
        ,BI_COLLECTABILITY  
        ,DPD_FINAL_CIF  
        ,BI_COLLECT_CIF  
        ,STAGE  
        ,RESTRUCTURE_COLLECT_FLAG  
        ,PRODUCT_TYPE_1  
        ,CCF  
        ,CCF_EFF_DATE  
        ,RESTRUCTURE_COLLECT_FLAG_CIF  
        ,IMPAIRED_FLAG  
    )  
    SELECT   
        DOWNLOAD_DATE  
        ,MASTERID  
        ,LIFETIME  
        ,REVOLVING_FLAG  
        ,EIR  
        ,OUTSTANDING  
        ,PLAFOND  
        ,ECL_MODEL_ID  
        ,EAD_MODEL_ID  
        ,CCF_FLAG  
        ,LGD_MODEL_ID  
        ,PD_MODEL_ID  
        ,GROUP_SEGMENT  
        ,SEGMENT  
        ,SUB_SEGMENT  
        ,SEGMENTATION_ID  
        ,CUSTOMER_NUMBER  
        ,PD_ME_MODEL_ID  
        ,BUCKET_GROUP  
        ,BUCKET_ID  
        ,ACCOUNT_NUMBER  
        ,UNAMORT_COST_AMT  
        ,UNAMORT_FEE_AMT  
        ,INTEREST_ACCRUED  
        ,UNUSED_AMOUNT  
        ,FAIR_VALUE_AMOUNT  
        ,EAD_BALANCE  
        ,SICR_RULE_ID  
        ,DPD_CIF  
        ,PRODUCT_ENTITY  
        ,DATA_SOURCE  
        ,PRODUCT_CODE  
        ,PRODUCT_TYPE  
        ,PRODUCT_GROUP  
        ,STAFF_LOAN_FLAG  
        ,IS_IMPAIRED  
        ,PD_SEGMENT  
        ,LGD_SEGMENT  
        ,EAD_SEGMENT  
        ,PREV_ECL_AMOUNT  
        ,SICR_FLAG  
        ,DEFAULT_FLAG  
        ,DEFAULT_RULE_ID  
        ,CCF_RULES_ID  
        ,DPD_FINAL  
        ,BI_COLLECTABILITY  
        ,DPD_FINAL_CIF  
        ,BI_COLLECT_CIF  
        ,STAGE  
        ,RESTRUCTURE_COLLECT_FLAG  
        ,PRODUCT_TYPE_1  
        ,CCF  
        ,CCF_EFF_DATE  
        ,RESTRUCTURE_COLLECT_FLAG_CIF  
        ,IMPAIRED_FLAG  
    FROM TMP_IFRS_ECL_IMA  
    WHERE DOWNLOAD_DATE = @V_CURRDATE  
    AND MASTERID IN (SELECT MASTERID FROM IFRS_MASTER_RESTRU_COVID WHERE DOWNLOAD_DATE = @V_CURRDATE)  
  
    UPDATE A  
    SET A.STAGE = B.STAGE, A.BUCKET_ID = C.BUCKET_ID  
    FROM TMP_IFRS_ECL_IMA A  
    INNER JOIN IFRS_MASTER_RESTRU_COVID B  
    ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE  
    AND A.MASTERID = B.MASTERID 
	INNER JOIN IFRS_BUCKET_DETAIL C ON A.BUCKET_GROUP = c.BUCKET_GROUP and B.BUCKET_NAME = C.BUCKET_NAME AND C.IS_DELETE = 0
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
  
END  
GO
