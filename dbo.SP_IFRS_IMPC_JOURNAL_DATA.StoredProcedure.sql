USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPC_JOURNAL_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMPC_JOURNAL_DATA]            
@DOWNLOAD_DATE DATE = NULL            
/* created on 7-may-2019              
author: Frans Darmawan            
*/              
AS              
BEGIN              
  DECLARE @V_CURRDATE DATETIME;              
  DECLARE @V_CURRMONTH DATETIME;              
  DECLARE @V_PREVMONTH DATETIME;              
  DECLARE @V_ERRN FLOAT;              
  DECLARE @V_ERRM VARCHAR(250);              
  DECLARE @V_MINSTARTDATESESSION DATETIME2(6);              
  DECLARE @V_SP_NAME VARCHAR(30) = 'SP_IFRS_IMPC_JOURNAL_DATA';              
  DECLARE @V_COUNTER INT;              
  DECLARE @V_PREVDATE DATETIME;              
  DECLARE @V_SESSIONID VARCHAR(50);              
  DECLARE @V_COUNT INT;              
  DECLARE @V_PRC_NAME VARCHAR(50);              
              
  SET NOCOUNT ON;              
  IF @DOWNLOAD_DATE IS NULL            
  BEGIN            
    SELECT              
      @V_CURRDATE = CURRDATE,             
      @V_SESSIONID = SESSIONID              
    FROM IFRS_PRC_DATE;            
  END            
  ELSE            
  BEGIN            
    SET @V_CURRDATE = @DOWNLOAD_DATE            
  END             
            
  SET @V_CURRMONTH = EOMONTH(@V_CURRDATE)              
  SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE))            
  SET @V_SESSIONID = @V_SESSIONID              
              
  DELETE IFRS_IMP_JOURNAL_DATA              
  WHERE JOURNAL_TYPE IN ('BKPI', 'BKUW', 'BKPI_OCI')              
    AND DOWNLOAD_DATE = @V_CURRMONTH;              
              
    --**START** JOURNAL BKPI AND BKUW              
    INSERT INTO IFRS_IMP_JOURNAL_DATA            
    (              
        DOWNLOAD_DATE,              
        MASTERID,              
        ACCOUNT_NUMBER,              
        FACILITY_NUMBER,              
        JOURNAL_REF_NUM,              
        JOURNAL_TYPE,              
        DATA_SOURCE,              
        PRD_TYPE,              
        PRD_CODE,              
        PRD_GROUP,              
        BRANCH_CODE,              
        CURRENCY,              
        TXN_TYPE,              
        AMOUNT,              
        AMOUNT_IDR,              
        GL_ACCOUNT,              
        GL_CORE,              
        JOURNAL_DESC,              
        REVERSAL_FLAG,              
        SEGMENT,              
        CUSTOMER_NUMBER,              
        RESTRUCTURE_FLAG,
        CREATEDBY,
        CREATEDDATE               
    )              
    SELECT *              
    FROM             
    (            
        SELECT              
            @V_CURRMONTH AS DOWNLOAD_DATE,            
            PMA.MASTERID,              
            PMA.ACCOUNT_NUMBER,              
            PMA.FACILITY_NUMBER,              
            CASE             
                WHEN GL.IFRS_ACCT_TYPE = 'BKPI' THEN 'IMPAIRMENT - CA'              
                WHEN GL.IFRS_ACCT_TYPE = 'BKUW' THEN 'UNWINDING - CA'              
            ELSE NULL              
            END AS JOURNAL_REF_NUM,              
            GL.IFRS_ACCT_TYPE AS JOURNAL_TYPE,              
            PMA.DATA_SOURCE,              
            PMA.PRODUCT_TYPE,              
            PMA.PRODUCT_CODE,              
            PMA.PRODUCT_GROUP,              
            PMA.BRANCH_CODE,              
            PMA.CURRENCY,              
            GL.TXN_TYPE,              
            SUM(              
                CASE              
                    WHEN GL.IFRS_ACCT_TYPE = 'BKPI' THEN ISNULL(PMA.ECL_AMOUNT, 0)              
                    WHEN GL.IFRS_ACCT_TYPE = 'BKUW' THEN ISNULL(PMA.CA_UNWINDING_AMOUNT, 0)              
                ELSE NULL              
                END   ) AS AMOUNT,              
            SUM(              
                CASE              
                    WHEN GL.IFRS_ACCT_TYPE = 'BKPI' THEN ISNULL(PMA.ECL_AMOUNT, 0)  * ISNULL(PMA.EXCHANGE_RATE, 1)             
                    WHEN GL.IFRS_ACCT_TYPE = 'BKUW' THEN ISNULL(PMA.CA_UNWINDING_AMOUNT, 0) * ISNULL(PMA.EXCHANGE_RATE, 1)         
                ELSE NULL              
                END            
            ) AS AMOUNT_IDR,              
            GL.GL_CODE,              
            GL.GL_INTERNAL_CODE,              
            GL.REMARKS,              
            'N' AS REVERSAL_FLAG,              
            PMA.SEGMENT,              
            PMA.CUSTOMER_NUMBER,              
            ISNULL(PMA.RESTRUCTURE_FLAG,0) RESTRUCTURE_FLAG, ---NEW   
            @V_SP_NAME AS CREATEDBY,  
            GETDATE() AS CREATEDDATE              
        FROM IFRS_IMA_IMP_CURR PMA (NOLOCK)              
        INNER JOIN IFRS_MASTER_JOURNAL_PARAM GL (NOLOCK)           
        ON              
        UPPER(RTRIM(LTRIM(PMA.GL_CONSTNAME)))= UPPER(RTRIM(LTRIM(GL.GL_CONSTNAME)))              
        AND (UPPER(RTRIM(LTRIM(PMA.CURRENCY))) = UPPER(RTRIM(LTRIM(GL.CCY))) or UPPER(RTRIM(LTRIM(GL.CCY)))='ALL')              
        WHERE PMA.DOWNLOAD_DATE = EOMONTH(@V_CURRDATE)              
        AND ISNULL(PMA.IMPAIRED_FLAG,'C') = 'C'       
        AND ISNULL(IFRS9_CLASS,'') <> 'FVOCI'  
        AND GL.IFRS_ACCT_TYPE IN ('BKPI', 'BKUW')            
		AND GL.IS_DELETE = 0
        GROUP BY PMA.DOWNLOAD_DATE,              
        PMA.MASTERID,              
        PMA.ACCOUNT_NUMBER,              
        PMA.FACILITY_NUMBER,              
        GL.IFRS_ACCT_TYPE,              
        PMA.DATA_SOURCE,              
        PMA.PRODUCT_TYPE,              
        PMA.PRODUCT_CODE,              
        PMA.PRODUCT_GROUP,              
        PMA.BRANCH_CODE,              
        PMA.CURRENCY,              
        GL.TXN_TYPE,              
        GL.GL_CODE,              
        GL.GL_INTERNAL_CODE,              
        GL.REMARKS,              
        PMA.SEGMENT,              
        PMA.CUSTOMER_NUMBER,              
        ISNULL(PMA.RESTRUCTURE_FLAG,0)            
    ) S               
    WHERE AMOUNT > 0               
          
 UNION ALL          
          
 --------------------------------------------------------- FOR JOURNAL IMPAIRMENT FVOCI -----------------------------------          
  SELECT *              
    FROM             
    (            
        SELECT              
            @V_CURRMONTH AS DOWNLOAD_DATE,            
            PMA.MASTERID,              
            PMA.ACCOUNT_NUMBER,              
            PMA.FACILITY_NUMBER,              
            'IMPAIRMENT FVOCI - CA'AS JOURNAL_REF_NUM,              
            GL.IFRS_ACCT_TYPE AS JOURNAL_TYPE,              
            PMA.DATA_SOURCE,              
            PMA.PRODUCT_TYPE,              
            PMA.PRODUCT_CODE,              
            PMA.PRODUCT_GROUP,              
            PMA.BRANCH_CODE,              
            PMA.CURRENCY,              
            GL.TXN_TYPE,              
            SUM(ISNULL(PMA.ECL_AMOUNT, 0) ) AS AMOUNT,              
            SUM(ISNULL(PMA.ECL_AMOUNT, 0)  * ISNULL(PMA.EXCHANGE_RATE, 1))AS AMOUNT_IDR,              
            GL.GL_CODE,              
            GL.GL_INTERNAL_CODE,              
            GL.REMARKS,              
            'N' AS REVERSAL_FLAG,              
            PMA.SEGMENT,              
            PMA.CUSTOMER_NUMBER,              
            ISNULL(PMA.RESTRUCTURE_FLAG,0) RESTRUCTURE_FLAG, ---NEW   
            @V_SP_NAME AS CREATEDBY,  
            GETDATE() AS CREATEDDATE
        FROM IFRS_IMA_IMP_CURR PMA (NOLOCK)             
        INNER JOIN IFRS_EIR_ADJUSTMENT ADJ ON PMA.MASTERID = ADJ.MASTERID AND ADJ.DOWNLOAD_DATE = EOMONTH(@V_CURRDATE)          
        INNER JOIN IFRS_MASTER_JOURNAL_PARAM GL (NOLOCK)           
        ON                
        UPPER(RTRIM(LTRIM(PMA.GL_CONSTNAME)))= UPPER(RTRIM(LTRIM(GL.GL_CONSTNAME)))              
        AND (UPPER(RTRIM(LTRIM(PMA.CURRENCY))) = UPPER(RTRIM(LTRIM(GL.CCY))) or UPPER(RTRIM(LTRIM(GL.CCY))) = 'ALL')              
        WHERE PMA.DOWNLOAD_DATE = EOMONTH(@V_CURRDATE)              
        AND ISNULL(PMA.IMPAIRED_FLAG,'C') = 'C'               
        AND GL.IFRS_ACCT_TYPE IN ('BKPI_OCI' )           
        AND ADJ.IFRS9_CLASS = 'FVOCI'     
		AND GL.IS_DELETE = 0   
        GROUP BY PMA.DOWNLOAD_DATE,              
        PMA.MASTERID,              
        PMA.ACCOUNT_NUMBER,       
        PMA.FACILITY_NUMBER,              
        GL.IFRS_ACCT_TYPE,              
        PMA.DATA_SOURCE,    
        PMA.PRODUCT_TYPE,              
        PMA.PRODUCT_CODE,              
        PMA.PRODUCT_GROUP,              
        PMA.BRANCH_CODE,              
        PMA.CURRENCY,              
        GL.TXN_TYPE,              
        GL.GL_CODE,              
        GL.GL_INTERNAL_CODE,     
        GL.REMARKS,              
        PMA.SEGMENT,              
        PMA.CUSTOMER_NUMBER,              
        ISNULL(PMA.RESTRUCTURE_FLAG,0)            
    ) A               
    WHERE AMOUNT > 0              
          
          
              
    --**START** JOURNAL REVERSE BKPI AND BKUW              
    INSERT INTO IFRS_IMP_JOURNAL_DATA             
    (              
        DOWNLOAD_DATE,              
        MASTERID,              
        ACCOUNT_NUMBER,              
        FACILITY_NUMBER,              
        JOURNAL_REF_NUM,              
        JOURNAL_TYPE,              
        DATA_SOURCE,              
        PRD_TYPE,              
        PRD_CODE,              
        PRD_GROUP,              
        BRANCH_CODE,              
        CURRENCY,              
        TXN_TYPE,              
        AMOUNT,              
        AMOUNT_IDR,              
        GL_ACCOUNT,              
        GL_CORE,              
        JOURNAL_DESC,              
        REVERSAL_FLAG,              
        SEGMENT,              
        CUSTOMER_NUMBER,              
        RESTRUCTURE_FLAG,  
        CREATEDBY,  
        CREATEDDATE               
    )              
    SELECT              
        @V_CURRMONTH AS DOWNLOAD_DATE,              
        GL.MASTERID,              
        GL.ACCOUNT_NUMBER,              
        GL.FACILITY_NUMBER,              
        GL.JOURNAL_REF_NUM,              
        GL.JOURNAL_TYPE,              
        GL.DATA_SOURCE,              
        GL.PRD_TYPE,              
        GL.PRD_CODE,              
        GL.PRD_GROUP,              
        GL.BRANCH_CODE,              
        GL.CURRENCY,              
        CASE              
          WHEN GL.TXN_TYPE = 'DB' THEN 'CR'              
          ELSE 'DB'              
        END AS TXN_TYPE,              
        GL.AMOUNT,              
        GL.AMOUNT_IDR,              
        GL.GL_ACCOUNT,              
        GL.GL_CORE,              
        GL.JOURNAL_DESC,               
        'Y' AS REVERSAL_FLAG,              
        GL.SEGMENT,              
        GL.CUSTOMER_NUMBER,              
        GL.RESTRUCTURE_FLAG,  
        @V_SP_NAME,  
        GETDATE()               
    FROM IFRS_IMP_JOURNAL_DATA GL (NOLOCK)            
    WHERE GL.DOWNLOAD_DATE = @V_PREVMONTH              
    AND GL.JOURNAL_TYPE IN ('BKPI', 'BKUW')              
    AND GL.REVERSAL_FLAG = 'N';              
              
END



GO
