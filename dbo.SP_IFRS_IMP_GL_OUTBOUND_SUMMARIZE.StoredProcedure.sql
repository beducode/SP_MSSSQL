USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_GL_OUTBOUND_SUMMARIZE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_GL_OUTBOUND_SUMMARIZE]          
@DOWNLOAD_DATE DATE = NULL                    
AS                  
    DECLARE                   
        @V_CURRDATE DATE                  
        ,@V_PREVDATE DATE                 
        ,@IS_POSTED BIT                 
BEGIN                 
    IF @DOWNLOAD_DATE IS NULL              
    BEGIN              
        SELECT @V_CURRDATE = MAX(CURRDATE), @V_PREVDATE = MAX(PREVDATE)               
        FROM IFRS_PRC_DATE              
    END              
    ELSE              
    BEGIN              
        SET @V_CURRDATE = @DOWNLOAD_DATE              
    END              

	---------------------- GL OUTBUND AMORTIZATION ------------------------------
	EXEC [SP_IFRS_GL_OUTBOUND_SUMMARIZE] @V_CURRDATE
	---------------------- GL OUTBUND AMORTIZATION ------------------------------

	   --- CLEAN IFRS_GL_OUTBOUND WITH AMOUNT = 0 
	 DELETE IFRS_GL_OUTBOUND                  
    WHERE YEAR(BUSS_DATE) = YEAR(@V_CURRDATE) AND MONTH(BUSS_DATE) = MONTH(@V_CURRDATE) AND CLASS = 'I' AND AMOUNT = 0     
                
    DELETE STG_TRX_PSAK71_REV WHERE BUSS_DATE = @V_CURRDATE AND TRANSACTION_TYPE = 'IMPAIRMENT'         
    DELETE STG_TRX_PSAK71 WHERE  TRANSACTION_TYPE = 'IMPAIRMENT'         
              
    --INSERT TO REVERSAL TABLE IF EXISTS                  
    IF EXISTS                  
    (                
        SELECT *                  
        FROM STG_TRX_PSAK71_LOG                 
        WHERE PROCESS_ID = 'GL_TRX' AND LAST_BUSS_DATE = @V_CURRDATE                  
    )                
    BEGIN  
        INSERT INTO STG_TRX_PSAK71_REV                
        (                
            BUSS_DATE                
            ,BRANCH                
            ,ACCOUNT_NO                
            ,DESCRIPTION                
            ,CCY                
            ,ACCOUNT_TYPE                
            ,VALUE_DATE                
            ,SIGN                
            ,AMOUNT                
            ,NARRATIVE1                
            ,GROUP_OR_USER_ID                
            ,TIME_STAMP                
            ,PRODUCT_CODE                
            ,CUSTOMER_TYPE                
            ,TRANSACTION_RATE                
            ,AMOUNT_LEV                
            ,JURNAL_NUMBER                
            ,SOURCE_DATA                
            ,EVENT_TYPE            
            ,TRANSACTION_TYPE                   
        )                
        SELECT                  
            EOMONTH(BUSS_DATE) AS BUSS_DATE                  
            ,BRANCH                
            ,ACCOUNT_NO                
            ,LEFT(DESCRIPTION,50)                
            ,CCY                
            ,ACCOUNT_TYPE                
            ,EOMONTH(VALUE_DATE) AS VALUE_DATE                  
            ,CASE WHEN SIGN = 'D' THEN 'C' ELSE 'D' END AS SIGN                
            ,SUM(AMOUNT) AS AMOUNT                
            ,NARRATIVE1                
            ,GROUP_OR_USER_ID                
            ,TIME_STAMP                
            ,PRODUCT_CODE                
            ,CUSTOMER_TYPE                
            ,CASE WHEN SUM(AMOUNT) = 0 THEN 0 ELSE SUM(AMOUNT_LEV) / SUM(AMOUNT) END AS TRANSACTION_RATE                
            ,SUM(AMOUNT_LEV) AS AMOUNT_LEV                
            ,JURNAL_NUMBER+'_REV'                
            ,SOURCE_DATA                
            ,EVENT_TYPE            
            ,TRANSACTION_TYPE                  
        FROM STG_TRX_PSAK71_HISTORY                  
        WHERE YEAR(BUSS_DATE) = YEAR(@V_CURRDATE) AND MONTH(BUSS_DATE) = MONTH(@V_CURRDATE) AND TRANSACTION_TYPE = 'IMPAIRMENT'                 
        GROUP BY                 
            BUSS_DATE                
            ,BRANCH                
            ,ACCOUNT_NO                
            ,LEFT(DESCRIPTION,50)                
            ,CCY                
            ,ACCOUNT_TYPE                
            ,VALUE_DATE                
            ,SIGN                
            ,NARRATIVE1                
            ,GROUP_OR_USER_ID                
            ,TIME_STAMP                
            ,PRODUCT_CODE                
            ,CUSTOMER_TYPE                
            ,JURNAL_NUMBER                
            ,SOURCE_DATA                
            ,EVENT_TYPE          
            ,TRANSACTION_TYPE                  
        ORDER BY                
            BUSS_DATE ASC                
            ,BRANCH ASC                
            ,CCY ASC                
            ,AMOUNT ASC                
            ,SIGN DESC                
       ,ACCOUNT_NO ASC              
    END                
               
    DELETE STG_TRX_PSAK71_HISTORY WHERE BUSS_DATE = @V_CURRDATE AND TRANSACTION_TYPE = 'IMPAIRMENT'            
                
    INSERT INTO STG_TRX_PSAK71                
    (                  
        BUSS_DATE                
        ,BRANCH                
        ,ACCOUNT_NO                
        ,DESCRIPTION                
        ,CCY                
        ,ACCOUNT_TYPE                
      ,VALUE_DATE                
        ,SIGN                
        ,AMOUNT                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,TRANSACTION_RATE                
        ,AMOUNT_LEV                
   ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE            
        ,TRANSACTION_TYPE                
    )                
    SELECT                  
        EOMONTH(BUSS_DATE) AS BUSS_DATE                  
        ,BRANCH                
        ,ACCOUNT_NO                
        ,LEFT(DESCRIPTION,50)                
        ,CCY                
        ,ACCOUNT_TYPE                
        ,EOMONTH(VALUE_DATE) AS VALUE_DATE                  
        ,SIGN                
        ,SUM(AMOUNT) AS AMOUNT                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,REPLACE(REPLACE(REPLACE(PRODUCT_CODE,'CL_',''),'_LC',''),'_DR','') AS PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,CASE WHEN SUM(AMOUNT)= 0 THEN 0 ELSE  SUM(AMOUNT_LEV) / SUM(AMOUNT) END AS TRANSACTION_RATE                
        ,SUM(AMOUNT_LEV) AS AMOUNT_LEV                
        ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE            
        ,'IMPAIRMENT' AS TRANSACTION_TYPE                  
    FROM IFRS_GL_OUTBOUND                  
    WHERE YEAR(BUSS_DATE) = YEAR(@V_CURRDATE) AND MONTH(BUSS_DATE) = MONTH(@V_CURRDATE) AND CLASS = 'I'                  
    GROUP BY                 
        BUSS_DATE                
        ,BRANCH                
        ,ACCOUNT_NO                
        ,LEFT(DESCRIPTION,50)                
        ,CCY                
        ,ACCOUNT_TYPE                
        ,VALUE_DATE                
        ,SIGN                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE                  
    UNION ALL                  
    SELECT                  
        BUSS_DATE                  
        ,BRANCH                
        ,ACCOUNT_NO                
        ,LEFT(DESCRIPTION,50)                
        ,CCY                
        ,ACCOUNT_TYPE                
        ,VALUE_DATE                  
        ,SIGN                
        ,AMOUNT                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,REPLACE(REPLACE(REPLACE(PRODUCT_CODE,'CL_',''),'_LC',''),'_DR','') AS PRODUCT_CODE
        ,CUSTOMER_TYPE                
        ,TRANSACTION_RATE                
        ,AMOUNT_LEV                
        ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE            
        ,TRANSACTION_TYPE                  
    FROM STG_TRX_PSAK71_REV                  
    WHERE BUSS_DATE = @V_CURRDATE                  
    ORDER BY                
        BUSS_DATE ASC                
        ,BRANCH ASC                
        ,CCY ASC                
        ,AMOUNT ASC                
        ,SIGN DESC                
        ,ACCOUNT_NO ASC               
                
    INSERT INTO STG_TRX_PSAK71_HISTORY                
    (                  
        BUSS_DATE           
        ,BRANCH                
        ,ACCOUNT_NO                
        ,DESCRIPTION                
        ,CCY                
        ,ACCOUNT_TYPE                
        ,VALUE_DATE                
        ,SIGN                
        ,AMOUNT                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,TRANSACTION_RATE                
        ,AMOUNT_LEV                
        ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE            
        ,TRANSACTION_TYPE                
    )                
    SELECT                  
        EOMONTH(BUSS_DATE) AS BUSS_DATE                  
        ,BRANCH                
        ,ACCOUNT_NO                
        ,LEFT(DESCRIPTION,50)             
        ,CCY                
        ,ACCOUNT_TYPE                
        ,EOMONTH(VALUE_DATE) AS VALUE_DATE                  
        ,SIGN                
        ,SUM(AMOUNT) AS AMOUNT                
        ,NARRATIVE1                
        ,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,CASE WHEN SUM(AMOUNT) = 0 THEN 0 ELSE SUM(AMOUNT_LEV) / SUM(AMOUNT) END AS TRANSACTION_RATE                
        ,SUM(AMOUNT_LEV) AS AMOUNT_LEV                
   ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE            
        ,'IMPAIRMENT' AS TRANSACTION_TYPE                  
    FROM IFRS_GL_OUTBOUND                  
    WHERE YEAR(BUSS_DATE) = YEAR(@V_CURRDATE) AND MONTH(BUSS_DATE) = MONTH(@V_CURRDATE) AND CLASS = 'I'                
    GROUP BY                 
        BUSS_DATE                
        ,BRANCH                
        ,ACCOUNT_NO                
        ,LEFT(DESCRIPTION,50)                
        ,CCY                
        ,ACCOUNT_TYPE                
        ,VALUE_DATE                
        ,SIGN                
        ,NARRATIVE1                
		,GROUP_OR_USER_ID                
        ,TIME_STAMP                
        ,PRODUCT_CODE                
        ,CUSTOMER_TYPE                
        ,JURNAL_NUMBER                
        ,SOURCE_DATA                
        ,EVENT_TYPE                  
    ORDER BY                
        BUSS_DATE ASC                
        ,BRANCH ASC                
        ,CCY ASC                
        ,AMOUNT ASC                
        ,SIGN DESC                
        ,ACCOUNT_NO ASC                     



END


GO
