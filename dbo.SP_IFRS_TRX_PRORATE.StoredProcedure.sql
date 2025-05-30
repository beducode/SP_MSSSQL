USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_TRX_PRORATE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_TRX_PRORATE]           
@V_CURRDATE DATE = NULL          
AS          
DECLARE @V_PREVDATE         DATE,          
        @DIFF_DIGIT_DECIMAL NUMERIC(32, 6),          
        @V_FUNCROUND        INTEGER,          
        @V_ROUND            INTEGER,          
        @ROWSELLDOWN        INTEGER          
          
BEGIN          
    IF @V_CURRDATE IS NULL          
    BEGIN          
        SELECT @V_CURRDATE = CURRDATE          
        FROM   IFRS_PRC_DATE_AMORT          
    END          
          
    SET @V_PREVDATE = DATEADD(DD, -1, @V_CURRDATE)          
          
    SELECT @V_ROUND = CAST(VALUE1 AS INT), @V_FUNCROUND = CAST(VALUE2 AS INT)          
    FROM   TBLM_COMMONCODEDETAIL          
    WHERE  COMMONCODE = 'SCM003'          
          
    SELECT @DIFF_DIGIT_DECIMAL = CAST(VALUE1 AS FLOAT)          
    FROM   TBLM_COMMONCODEDETAIL          
    WHERE  COMMONCODE = 'SCM007'          
       
 UPDATE A          
    SET    A.STATUS = B.STATUS,          
           A.ALOC = B.ALOC,          
           A.UNALOC = B.UNALOC,          
           A.REVID = B.REVID          
 FROM IFRS_TRX_FACILITY_HEADER A          
 JOIN IFRS_TRX_FACILITY_HEADER_HIST B          
 ON A.PKID = B.PKID          
 WHERE  B.DOWNLOAD_DATE = @V_PREVDATE          
 AND A.DOWNLOAD_DATE < @V_CURRDATE        
      
 UPDATE A          
    SET    A.EXCHANGE_RATE = B.RATE_AMOUNT       
 FROM IFRS_TRX_FACILITY_HEADER A          
 JOIN IFRS_MASTER_EXCHANGE_RATE B on b.CURRENCY = a.CCY and b.DOWNLOAD_DATE = @V_CURRDATE       
      
    DELETE IFRS_TRX_FACILITY_DETAIL          
    WHERE  DOWNLOAD_DATE >= @V_CURRDATE          
          
    UPDATE IFRS_TRX_FACILITY_HEADER          
    SET    STATUS = 'PNL'          
    WHERE  MATURITY_DATE = @V_CURRDATE          
            AND STATUS = 'ACT'          
            AND UNALOC > 0.00          
          
  UPDATE A          
  SET A.STATUS = CASE WHEN B.LIMIT_ID IS NULL THEN 'PNL' ELSE A.STATUS END          
  FROM   IFRS_TRX_FACILITY_HEADER A          
  LEFT JOIN (SELECT *          
  FROM   IFRS9_STG..STG_N3L_UNDRAWN          
  WHERE  YMD = @V_CURRDATE) B          
  ON A.FACILITY_NUMBER = CASE WHEN ISNULL(B.REPORT_LIMIT_ID, '') = '' THEN B.LIMIT_ID ELSE B.REPORT_LIMIT_ID END          
  WHERE  STATUS = 'ACT' AND UNALOC > 0.00          
          
    -- =========================================================              
    -- REVERSAL              
    -- =========================================================              
    IF OBJECT_ID('TEMPDB.DBO.#TMP_FACILITY_REVERSAL') IS NOT NULL          
    DROP TABLE #TMP_FACILITY_REVERSAL          
          
    SELECT A.PKID,          
            A.TRX_CODE,          
            A.TRX_DATE,          
            A.FACILITY_NUMBER,          
            A.PKID AS TRX_REFERENCE_NUMBER,          
            A.TRX_AMOUNT,          
            A.CCY,          
            TRX_DR_CR,          
            STATUS          
    INTO   #TMP_FACILITY_REVERSAL          
    FROM   IFRS_TRX_FACILITY_HEADER A          
            /* JOIN KE TRANSACTION PARAM UNTUK TAU DIA FEE/COST  DAN NORMAL BALANCE NYA */          
            INNER JOIN (SELECT DISTINCT TRX_CODE,          
                        IFRS_TXN_CLASS,          
                        CCY          
                        FROM   IFRS_MASTER_TRANS_PARAM          
                        WHERE  IS_DELETE = 0) C          
                    ON A.TRX_CODE = C.TRX_CODE          
                    AND ( C.CCY = 'ALL' OR A.CCY = C.CCY ) AND A.STATUS = 'ACT'          
    WHERE  A.TRX_DATE = @V_CURRDATE AND ((C.IFRS_TXN_CLASS = 'FEE' AND A.TRX_DR_CR = 'D') OR (C.IFRS_TXN_CLASS = 'COST' AND A.TRX_DR_CR = 'C'))          
    GROUP  BY A.PKID,          
            A.TRX_CODE,          
            A.TRX_DATE,          
            A.FACILITY_NUMBER,          
            A.TRX_AMOUNT,          
            A.CCY,          
            TRX_DR_CR,          
            STATUS;          
          
    -- =========================================================              
    -- GET REFERENCE NUMBER              
    -- =========================================================               
    IF OBJECT_ID('TEMPDB.DBO.#TMP_FACILITY_REFERENCE') IS NOT NULL          
    DROP TABLE #TMP_FACILITY_REFERENC          
          
    SELECT MIN(A.PKID) AS PKID_REVTO,          
            B.PKID      AS PKID_REVFROM,          
            A.TRX_CODE,        
            A.TRX_AMOUNT,          
            A.CCY,          
            A.FACILITY_NUMBER          
    INTO   #TMP_FACILITY_REFERENCE          
    FROM   IFRS_TRX_FACILITY_HEADER A          
            JOIN #TMP_FACILITY_REVERSAL B          
            ON A.TRX_CODE = B.TRX_CODE          
                AND A.TRX_AMOUNT = B.TRX_AMOUNT          
             AND A.CCY = B.CCY          
                AND A.FACILITY_NUMBER = B.FACILITY_NUMBER          
            JOIN (SELECT DISTINCT TRX_CODE, IFRS_TXN_CLASS, CCY FROM IFRS_TRANSACTION_PARAM) C          
            ON A.TRX_CODE = C.TRX_CODE AND ( A.CCY = C.CCY OR C.CCY = 'ALL' )          
    WHERE  ( ( C.IFRS_TXN_CLASS = 'FEE' AND A.TRX_DR_CR = 'C' )          
            OR ( C.IFRS_TXN_CLASS = 'COST'AND A.TRX_DR_CR = 'D' ) )          
            AND A.PKID NOT IN (SELECT DISTINCT REVID FROM   IFRS_TRX_FACILITY_HEADER WHERE  REVID IS NOT NULL)          
    GROUP  BY B.PKID,          
            A.TRX_CODE,          
            A.TRX_AMOUNT,          
            A.CCY,          
            A.FACILITY_NUMBER          
          
    -- =========================================================              
    -- UPDATE REVID              
    -- =========================================================              
    UPDATE IFRS_TRX_FACILITY_HEADER          
    SET    REVID = B.PKID_REVTO,          
           STATUS = 'REV'          
    FROM   IFRS_TRX_FACILITY_HEADER A          
           JOIN #TMP_FACILITY_REFERENCE B ON A.PKID = B.PKID_REVFROM          
    WHERE  A.TRX_DATE = @V_CURRDATE          
          
    -- =========================================================              
    -- INSERT REVERSAL TO IFRS_TRX_FACILITY_DETAIL              
    -- =========================================================              
    IF OBJECT_ID('TEMPDB.DBO.#INSERT_TRANSACTION_DAILY') IS NOT NULL          
    DROP TABLE #INSERT_TRANSACTION_DAILY          
          
    SELECT @V_CURRDATE AS DOWNLOAD_DATE,          
            @V_CURRDATE AS EFFECTIVE_DATE,          
            MASTERID,          
            ACCOUNT_NUMBER,          
            A.FACILITY_NUMBER,          
            CUSTOMER_NUMBER,          
            BRANCH_CODE,          
            DATA_SOURCE,          
            PRD_TYPE,          
            PRD_CODE,          
            A.CCY,          
            ORG_CCY_AMT,          
            EQV_LCY_AMT,          
            B.PKID_REVFROM AS TRX_REFERENCE_NUMBER,          
            A.TRX_CODE,          
            TRX_LEVEL,          
            CASE A.TRX_DR_CR WHEN 'D' THEN 'C' WHEN 'C' THEN 'D' END AS TRX_DR_CR,          
            EXC_RATE_ACC_TO_IDR,          
            EXC_RATE_TRX_TO_IDR,          
            ORG_INITIAL_OS_AMT,          
            LOAN_START_DATE,          
            LOAN_DUE_DATE,          
            SOURCE_TABLE,          
            MATURITY_DATE          
    INTO   #INSERT_TRANSACTION_DAILY          
    FROM   IFRS_TRX_FACILITY_DETAIL A          
            JOIN #TMP_FACILITY_REFERENCE B          
            ON B.PKID_REVTO = A.TRX_REFERENCE_NUMBER          
    WHERE  TRX_LEVEL = 'FAC'          
          
    INSERT INTO IFRS_TRX_FACILITY_DETAIL          
                (DOWNLOAD_DATE,          
                EFFECTIVE_DATE,          
                MASTERID,          
                ACCOUNT_NUMBER,          
                FACILITY_NUMBER,          
                CUSTOMER_NUMBER,          
                BRANCH_CODE,          
                DATA_SOURCE,          
                PRD_TYPE,          
                PRD_CODE,          
                CCY,          
                ORG_CCY_AMT,          
                EQV_LCY_AMT,          
                TRX_REFERENCE_NUMBER,          
                TRX_CODE,          
                TRX_LEVEL,          
                TRX_DR_CR,          
                EXC_RATE_ACC_TO_IDR,          
                EXC_RATE_TRX_TO_IDR,          
                ORG_INITIAL_OS_AMT,          
                LOAN_START_DATE,          
                LOAN_DUE_DATE,          
                SOURCE_TABLE,          
                MATURITY_DATE)          
    SELECT DOWNLOAD_DATE,          
            EFFECTIVE_DATE,          
            MASTERID,          
            ACCOUNT_NUMBER,          
            FACILITY_NUMBER,          
            CUSTOMER_NUMBER,          
            BRANCH_CODE,          
            DATA_SOURCE,          
            PRD_TYPE,          
            PRD_CODE,          
            CCY,          
            ORG_CCY_AMT,          
            EQV_LCY_AMT,          
            TRX_REFERENCE_NUMBER,          
            TRX_CODE,          
            TRX_LEVEL,          
            TRX_DR_CR,          
            EXC_RATE_ACC_TO_IDR,          
            EXC_RATE_TRX_TO_IDR,          
            ORG_INITIAL_OS_AMT,          
            LOAN_START_DATE,          
            LOAN_DUE_DATE,          
            SOURCE_TABLE,          
            MATURITY_DATE          
    FROM   #INSERT_TRANSACTION_DAILY          
          
    /*****************************              
        UPDATE STATUS                
    *****************************/          
    UPDATE IFRS_TRX_FACILITY_HEADER          
    SET    ALOC = 0,          
            UNALOC = TRX_AMOUNT          
    WHERE  DOWNLOAD_DATE = @V_CURRDATE          
            AND REVID IS NULL       
         
        
    /*****************************              
        INITIAL              
    *****************************/          
    IF OBJECT_ID('TEMPDB.DBO.#TMP1') IS NOT NULL          
    DROP TABLE #TMP1          
          
    SELECT A.*,          
    LAG(A.SUM_TOTAL_ALOC)          
    OVER (PARTITION BY A.PKID ORDER BY A.PKID, ( A.INITIAL_OUTSTANDING * A.EXC_RATE_ACC_TO_IDR) DESC, A.ACCOUNT_NUMBER ) PREV_TOTAL_ALOC,         
 CASE WHEN ISNULL(A.UNALOC - SUM_TOTAL_ALOC,0) < 0 THEN          
  CASE          
    WHEN LAG(A.SUM_TOTAL_ALOC)          
      OVER (          
      PARTITION BY A.PKID          
      ORDER BY A.PKID, ( A.INITIAL_OUTSTANDING *          
      A.EXC_RATE_ACC_TO_IDR          
      )          
      DESC,          
      A.ACCOUNT_NUMBER ) IS NULL THEN A.UNALOC          
    WHEN A.UNALOC - LAG(A.SUM_TOTAL_ALOC)          
      OVER (          
      PARTITION BY A.PKID          
      ORDER BY A.PKID, ( A.INITIAL_OUTSTANDING          
      *          
      A.EXC_RATE_ACC_TO_IDR          
      ) DESC,          
      A.ACCOUNT_NUMBER ) < 0 THEN 0          
    ELSE A.UNALOC - LAG(A.SUM_TOTAL_ALOC)          
      OVER (          
      PARTITION BY A.PKID          
      ORDER BY A.PKID, ( A.INITIAL_OUTSTANDING          
      *          
      A.EXC_RATE_ACC_TO_IDR          
      ) DESC,          
      A.ACCOUNT_NUMBER )          
    END          
    ELSE --A.ALOC              
        CASE          
        WHEN ROUND(( A.UNALOC - SUM_TOTAL_ALOC ), @V_ROUND, @V_FUNCROUND) <  @DIFF_DIGIT_DECIMAL THEN A.ALOC + ROUND( (A.UNALOC - SUM_TOTAL_ALOC),@V_ROUND,@V_FUNCROUND )          
        ELSE A.ALOC          
        END          
    END ALOC_AFTER          
 INTO   #TMP1          
 FROM   (      
 SELECT B.EXCHANGE_RATE,          
    B.[DOWNLOAD_DATE],          
    A.TRX_DATE AS [EFFECTIVE_DATE],          
    A.[MATURITY_DATE],          
    B.[MASTERID],          
    B.[ACCOUNT_NUMBER],          
    A.[FACILITY_NUMBER],          
    B.[CUSTOMER_NUMBER],          
    B.[BRANCH_CODE],          
    B.[DATA_SOURCE],          
    A.PRD_TYPE,          
    A.PRD_CODE,          
    A.[TRX_CODE],          
    B.CURRENCY AS [CCY],          
    NULL [EVENT_CODE],          
    A.PKID AS [TRX_REFERENCE_NUMBER],          
    NULL AS [ORG_CCY_AMT],          
    NULL AS [EQV_LCY_AMT],          
    NULL AS [TRX_SOURCE],          
    NULL AS [INTERNAL_NO],          
    B.[REVOLVING_FLAG],          
    GETDATE() AS [CREATED_DATE],          
    'FAC' AS [TRX_LEVEL],          
    A.[TRX_DR_CR],          
    B.EXCHANGE_RATE AS [EXC_RATE_ACC_TO_IDR],          
    A.LIMIT_EXCHANGE_RATE AS [EXC_RATE_TRX_TO_IDR],          
    NULL AS [ORG_INITIAL_OS_AMT],          
    ROUND(( ROUND(( CAST(B.INITIAL_OUTSTANDING AS FLOAT) * B.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) / ROUND(( A.PLAFOND * A.LIMIT_EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) *           
 ROUND(( A.TRX_AMOUNT * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) ), @V_ROUND, @V_FUNCROUND) AS [ALOC],  -- Change from A.TRX_AMOUNT * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RATE 20221213      
   ROUND(( A.[UNALOC] * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) AS [UNALOC]  -- Change from A.[UNALOC] * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RATE        
 ,[LOAN_START_DATE]          
 ,[LOAN_DUE_DATE],          
    'IFRS_TRX_FACILITY_HEADER' AS [SOURCE_TABLE],          
    A.PKID,          
    B.INITIAL_OUTSTANDING,          
    A.PLAFOND AS PLAFOND,        
 A.TRX_AMOUNT,    
   NULL AS SELLDOWN_OR_CANCELATION_FLAG,    
  NULL AS SELLDOWN_PERCENTAGE,      
  NULL AS SELLDOWN_CURRENCY,      
 ROUND(( SUM(ROUND(( ROUND(( CAST(B.INITIAL_OUTSTANDING AS FLOAT) * B.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) /          
    ROUND((A.PLAFOND * A.LIMIT_EXCHANGE_RATE), @V_ROUND, @V_FUNCROUND) * ROUND((A.TRX_AMOUNT * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) ), @V_ROUND, @V_FUNCROUND))    /** Change from A.TRX_AMOUNT * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RAT 
  
   
E20221213 **/      
    OVER (PARTITION BY A.PKID ORDER BY A.PKID, ( B.INITIAL_OUTSTANDING * B.EXCHANGE_RATE ) DESC, B.ACCOUNT_NUMBER ) ), @V_ROUND, @V_FUNCROUND) AS [SUM_TOTAL_ALOC]          
 FROM   IFRS_TRX_FACILITY_HEADER A          
    INNER JOIN IFRS_MASTER_ACCOUNT B ON A.FACILITY_NUMBER = B.FACILITY_NUMBER          
    AND B.LOAN_START_DATE >= A.TRX_DATE          
 AND B.DATA_SOURCE <> 'LIMIT_T24'          
    AND B.DOWNLOAD_DATE = @V_CURRDATE          
    AND B.ACCOUNT_STATUS = 'A'          
    AND A.REVID IS NULL          
    AND A.STATUS = 'ACT'          
 AND A.PLAFOND > 0          
    INNER JOIN IFRS_MASTER_EXCHANGE_RATE C          
 ON B.DOWNLOAD_DATE = C.DOWNLOAD_DATE          
            AND C.DOWNLOAD_DATE >= @V_CURRDATE          
            AND A.CCY = C.CURRENCY          
 WHERE  NOT EXISTS (SELECT TOP 1 1          
                FROM   IFRS_TRX_FACILITY_DETAIL D          
                WHERE  D.TRX_REFERENCE_NUMBER = A.PKID          
                    AND B.MASTERID = D.MASTERID          
                    AND A.FACILITY_NUMBER =          
                        D.FACILITY_NUMBER                    
                    AND A.DOWNLOAD_DATE = D.EFFECTIVE_DATE)          
    AND NOT EXISTS (SELECT TOP 1 1          
                    FROM   IFRS_TRX_FACILITY_HEADER E          
                    WHERE  E.REVID = A.PKID          
                        AND E.DOWNLOAD_DATE <= @V_CURRDATE)          
    AND A.DOWNLOAD_DATE <= @V_CURRDATE      
      
 UNION ALL      
      
  ----~oO> SELLDOWN BEGIN<Oo~--       
 SELECT C.RATE_AMOUNT  EXCHANGE_RATE,          
  B.[DOWNLOAD_DATE],          
  A.TRX_DATE AS [EFFECTIVE_DATE],          
  A.[MATURITY_DATE],          
  a.FACILITY_NUMBER [MASTERID],          
  a.FACILITY_NUMBER [ACCOUNT_NUMBER],          
  A.[FACILITY_NUMBER],          
  a.[CUSTOMER_NUMBER],          
  a.[BRANCH_CODE],          
  a.[DATA_SOURCE],          
  A.PRD_TYPE,          
  A.PRD_CODE,          
  A.[TRX_CODE],          
  CURRENCY_SELLDOWN AS [CCY],          
  NULL [EVENT_CODE],          
  A.PKID AS [TRX_REFERENCE_NUMBER],          
  NULL AS [ORG_CCY_AMT],          
  NULL AS [EQV_LCY_AMT],          
  NULL AS [TRX_SOURCE],          
  NULL AS [INTERNAL_NO],          
  NULL [REVOLVING_FLAG],          
  GETDATE() AS [CREATED_DATE],          
  'FAC' AS [TRX_LEVEL],          
  A.[TRX_DR_CR],          
  C.RATE_AMOUNT AS [EXC_RATE_ACC_TO_IDR],          
  A.LIMIT_EXCHANGE_RATE AS [EXC_RATE_TRX_TO_IDR],          
  NULL AS [ORG_INITIAL_OS_AMT],          
  ROUND(( ROUND(( CAST(B.AMOUNT_SELLDOWN AS FLOAT) * C.RATE_AMOUNT ), @V_ROUND, @V_FUNCROUND) / ROUND(( A.PLAFOND * A.LIMIT_EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) *           
  ROUND(( A.TRX_AMOUNT * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) ), @V_ROUND, @V_FUNCROUND) AS [ALOC],  -- Change from A.TRX_AMOUNT * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RATE 20221213      
  ROUND(( A.[UNALOC] * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) AS [UNALOC]  -- Change from A.[UNALOC] * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RATE        
  ,NULL [LOAN_START_DATE]          
  ,NULL [LOAN_DUE_DATE],          
  'IFRS_FACILITY_SELLDOWN_FLAG' AS [SOURCE_TABLE],          
  A.PKID,          
  b.AMOUNT_SELLDOWN INITIAL_OUTSTANDING,          
  A.PLAFOND AS PLAFOND,        
  A.TRX_AMOUNT,    
  B.SELLDOWN_OR_CANCELATION_FLAG,    
  B.SELLDOWN_PERCENTAGE,      
  B.CURRENCY_SELLDOWN AS SELLDOWN_CURRENCY,    
  ROUND(( SUM(ROUND(( ROUND(( CAST(B.AMOUNT_SELLDOWN AS FLOAT) * C.RATE_AMOUNT ), @V_ROUND, @V_FUNCROUND) /          
  ROUND((A.PLAFOND * A.LIMIT_EXCHANGE_RATE), @V_ROUND, @V_FUNCROUND) * ROUND((A.TRX_AMOUNT * A.EXCHANGE_RATE ), @V_ROUND, @V_FUNCROUND) ), @V_ROUND, @V_FUNCROUND))    /** Change from A.TRX_AMOUNT * A.LIMIT_EXCHANGE_RATE to A.TRX_AMOUNT * A.EXCHANGE_RATE 2
  
    
0221213 **/      
  OVER (PARTITION BY A.PKID ORDER BY A.PKID, ( B.AMOUNT_SELLDOWN * C.RATE_AMOUNT ) DESC,  B.FACILITY_NUMBER    ) ), @V_ROUND, @V_FUNCROUND) AS [SUM_TOTAL_ALOC]          
 FROM   IFRS_TRX_FACILITY_HEADER A          
  INNER JOIN IFRS_FACILITY_SELLDOWN_FLAG B ON A.FACILITY_NUMBER = CASE WHEN ISNULL(B.OLD_FACILITY_NUMBER,'') = '' THEN B.FACILITY_NUMBER ELSE B.OLD_FACILITY_NUMBER END AND SELLDOWN_OR_CANCELATION_FLAG = 'Y'          
  AND   B.DOWNLOAD_DATE = @V_CURRDATE          
  AND A.REVID IS NULL          
  AND A.STATUS = 'ACT'          
 AND A.PLAFOND > 0          
  INNER JOIN IFRS_MASTER_EXCHANGE_RATE C          
 ON B.DOWNLOAD_DATE = C.DOWNLOAD_DATE          
    AND C.DOWNLOAD_DATE = @V_CURRDATE          
    AND B.CURRENCY_SELLDOWN = C.CURRENCY          
 --WHERE  NOT EXISTS (SELECT TOP 1 1          
 --    FROM   IFRS_TRX_FACILITY_DETAIL D          
 --    WHERE  D.TRX_REFERENCE_NUMBER = A.PKID         
 --     AND A.FACILITY_NUMBER =          
 --      D.FACILITY_NUMBER                    
 --     AND A.DOWNLOAD_DATE = D.EFFECTIVE_DATE  AND B.FACILITY_NUMBER = D.MASTERID )          
 -- AND NOT EXISTS (SELECT TOP 1 1          
 --     FROM   IFRS_TRX_FACILITY_HEADER E          
 --     WHERE  E.REVID = A.PKID          
 --      AND E.DOWNLOAD_DATE <= @V_CURRDATE)          
 -- AND A.DOWNLOAD_DATE <= @V_CURRDATE      
   --~oO>SELLDOWN END<Oo~--      
 ) A          
       
   /*****************************              
        UPDATE ALOC_AMOUNT ON PARENT                
    *****************************/          
    UPDATE A          
    SET    A.ALOC = ISNULL(A.ALOC,0) + B.ALOC,          
            A.UNALOC = CASE WHEN ISNULL(A.UNALOC,0) = 0 THEN 0 ELSE A.UNALOC - B.ALOC END         
    FROM   IFRS_TRX_FACILITY_HEADER A          
            INNER JOIN (SELECT DOWNLOAD_DATE,          
                            FACILITY_NUMBER,          
                            TRX_REFERENCE_NUMBER,          
                            SUM(ALOC_AFTER / EXC_RATE_TRX_TO_IDR) AS ALOC          
                        FROM   #TMP1          
                        GROUP  BY DOWNLOAD_DATE,          
                                FACILITY_NUMBER,          
                                TRX_REFERENCE_NUMBER) B          
                    ON A.FACILITY_NUMBER = B.FACILITY_NUMBER          
                    AND A.DOWNLOAD_DATE <= @V_CURRDATE          
                    AND A.PKID = B.TRX_REFERENCE_NUMBER            
    /*****************************              
        UPDATE STATUS IF CLOSE               
    *****************************/          
    UPDATE IFRS_TRX_FACILITY_HEADER          
    SET    STATUS = 'CLS'          
    WHERE          
            
    STATUS = 'ACT'          
    AND UNALOC = 0          
    AND TRX_AMOUNT = ALOC          
          
    UPDATE A          
    SET    A.STATUS = CASE          
                        WHEN B.LIMIT_ID IS NULL THEN 'CLS'          
                        ELSE A.STATUS          
                    END          
    FROM   IFRS_TRX_FACILITY_HEADER A          
            LEFT JOIN (SELECT *          
                    FROM   IFRS9_STG..STG_N3L_UNDRAWN          
                    WHERE  YMD = @V_CURRDATE) B          
                ON A.FACILITY_NUMBER = ISNULL(B.REPORT_LIMIT_ID, B.LIMIT_ID)          
    WHERE  STATUS = 'ACT'          
            AND UNALOC = 0          
            AND TRX_AMOUNT = ALOC      
      
/*****************************              
        INSERT INTO IFRS_TRX_FACILITY_DETAIL             
    *****************************/          
 DELETE FROM IFRS_TRX_FACILITY_DETAIL      
 WHERE  DOWNLOAD_DATE >= @V_CURRDATE          
 AND TRX_LEVEL = 'FAC'          
           
    INSERT INTO IFRS_TRX_FACILITY_DETAIL          
                ([DOWNLOAD_DATE],          
                [EFFECTIVE_DATE],          
                [MATURITY_DATE],          
                [MASTERID],          
                [ACCOUNT_NUMBER],          
                [FACILITY_NUMBER],          
                [CUSTOMER_NUMBER],          
                [BRANCH_CODE],          
    [DATA_SOURCE],          
                [PLAFOND],          
                [INITIAL_OUTSTANDING],          
                [PRD_TYPE],          
                [PRD_CODE],          
                [TRX_CODE],          
                [CCY],          
                [EVENT_CODE],          
                [TRX_REFERENCE_NUMBER],          
                [ORG_CCY_AMT],          
                [EQV_LCY_AMT],          
                [TRX_SOURCE],          
                [INTERNAL_NO],          
                [REVOLVING_FLAG],          
                [CREATED_DATE],          
                [TRX_LEVEL],          
                [TRX_DR_CR],          
                [EXC_RATE_ACC_TO_IDR],          
                [EXC_RATE_TRX_TO_IDR],       
                [ORG_INITIAL_OS_AMT],          
                [LOAN_START_DATE],          
                [LOAN_DUE_DATE],          
                [SOURCE_TABLE],    
    [AMOUNT_SELLDOWN],    
    [SELLDOWN_OR_CANCELATION_FLAG],    
    [SELLDOWN_PERCENTAGE],    
    [CURRENCY_SELLDOWN])          
    SELECT [DOWNLOAD_DATE],          
   [EFFECTIVE_DATE],          
            [MATURITY_DATE],          
            [MASTERID],          
            [ACCOUNT_NUMBER],          
            [FACILITY_NUMBER],          
            [CUSTOMER_NUMBER],          
            [BRANCH_CODE],          
            [DATA_SOURCE],          
            [PLAFOND],          
            [INITIAL_OUTSTANDING],          
            [PRD_TYPE],          
            [PRD_CODE],          
            [TRX_CODE],          
            [CCY],          
            [EVENT_CODE],          
            [TRX_REFERENCE_NUMBER],          
   ROUND((ALOC_AFTER / EXC_RATE_ACC_TO_IDR),  @V_ROUND, @V_FUNCROUND) [ORG_CCY_AMT],      
   ALOC_AFTER [EQV_LCY_AMT],         
            [TRX_SOURCE],          
            [INTERNAL_NO],          
            [REVOLVING_FLAG],          
            [CREATED_DATE],          
            [TRX_LEVEL],          
            [TRX_DR_CR],          
            [EXC_RATE_ACC_TO_IDR],          
            [EXC_RATE_TRX_TO_IDR],          
            [ORG_INITIAL_OS_AMT],          
            [LOAN_START_DATE],          
            [LOAN_DUE_DATE],          
            [SOURCE_TABLE],    
   CASE WHEN [SOURCE_TABLE] = 'IFRS_FACILITY_SELLDOWN_FLAG' THEN [INITIAL_OUTSTANDING] ELSE NULL END AS SELLDOWN_AMOUNT,          
   [SELLDOWN_OR_CANCELATION_FLAG],          
   [SELLDOWN_PERCENTAGE],          
   [SELLDOWN_CURRENCY]         
    FROM   #TMP1          
    WHERE  ALOC_AFTER > 0      
          
    /*****************************              
        INSERT INTO TRANSACTION DAILY              
    *****************************/          
    DELETE IFRS_TRANSACTION_DAILY          
    WHERE  DOWNLOAD_DATE >= @V_CURRDATE          
            AND TRX_LEVEL = 'FAC'          
          
    INSERT INTO [DBO].[IFRS_TRANSACTION_DAILY]          
                ([DOWNLOAD_DATE],          
                [EFFECTIVE_DATE],          
                [MATURITY_DATE],          
                [MASTERID],          
                [ACCOUNT_NUMBER],          
                [FACILITY_NUMBER],          
                [CUSTOMER_NUMBER],          
                [BRANCH_CODE],          
                [DATA_SOURCE],          
                [PRD_TYPE],          
                [PRD_CODE],          
                [TRX_CODE],          
                [CCY],          
                [EVENT_CODE],          
                [TRX_REFERENCE_NUMBER],          
                [ORG_CCY_AMT],          
                [EQV_LCY_AMT],          
                [DEBET_CREDIT_FLAG],          
                [TRX_SOURCE],          
                [INTERNAL_NO],          
                [REVOLVING_FLAG],          
                [CREATED_DATE],          
                [SOURCE_TABLE],          
                [TRX_LEVEL])          
    SELECT [DOWNLOAD_DATE],          
            [EFFECTIVE_DATE],          
            [MATURITY_DATE],          
            [MASTERID],          
            [ACCOUNT_NUMBER],          
            [FACILITY_NUMBER],          
            [CUSTOMER_NUMBER],          
            [BRANCH_CODE],          
            [DATA_SOURCE],          
            [PRD_TYPE],          
            [PRD_CODE],          
            [TRX_CODE],          
            [CCY],          
            [EVENT_CODE],          
            [TRX_REFERENCE_NUMBER],          
            [ORG_CCY_AMT],          
            [EQV_LCY_AMT],          
            [TRX_DR_CR] [DEBET_CREDIT_FLAG],          
            [TRX_SOURCE],          
            [INTERNAL_NO],          
            [REVOLVING_FLAG],          
            [CREATED_DATE],          
            [SOURCE_TABLE],          
            [TRX_LEVEL]          
    FROM   [DBO].[IFRS_TRX_FACILITY_DETAIL]          
    WHERE  DOWNLOAD_DATE = @V_CURRDATE          
          
    DELETE IFRS_TRX_FACILITY_HEADER_HIST          
    WHERE  DOWNLOAD_DATE >= @V_CURRDATE          
          
    INSERT INTO IFRS_TRX_FACILITY_HEADER_HIST          
                (PKID,          
				REVID,          
                DOWNLOAD_DATE,          
                TRX_DATE,          
                FACILITY_NUMBER,          
                GL_CONSTNAME,          
                BRANCH_CODE,          
                TRX_CODE,          
                DATA_SOURCE,          
				PRD_TYPE,          
                PRD_CODE,          
                TRX_DR_CR,          
                CCY,          
                MATURITY_DATE,          
                EXCHANGE_RATE,          
				METHOD,          
                STATUS,          
                FLAG_CF,          
                PLAFOND,          
                TRX_AMOUNT,          
                ALOC,          
                UNALOC,          
                CREATEDBY,          
                CREATEDDATE,          
                CREATEDHOST,          
                CUSTOMER_NUMBER,      
				LIMIT_CURRENCY,      
				LIMIT_EXCHANGE_RATE,
				-- ADD COLUMN SEGMENT_FLAG 25-APR-2024
				SEGMENT_FLAG)          
    SELECT PKID,          
            REVID,          
            @V_CURRDATE AS DOWNLOAD_DATE,          
            TRX_DATE,          
            FACILITY_NUMBER,          
            GL_CONSTNAME,          
            BRANCH_CODE,          
            TRX_CODE,          
            DATA_SOURCE,          
			PRD_TYPE,          
            PRD_CODE,          
            TRX_DR_CR,          
            CCY,          
            MATURITY_DATE,          
            EXCHANGE_RATE,          
            METHOD,          
            STATUS,          
            FLAG_CF,          
            PLAFOND,          
            TRX_AMOUNT,          
            CASE          
            WHEN MATURITY_DATE <= @V_CURRDATE THEN TRX_AMOUNT          
            ELSE ALOC          
            END         AS ALOC,          
            CASE          
            WHEN MATURITY_DATE <= @V_CURRDATE THEN 0          
            ELSE UNALOC          
            END         AS UNALOC,          
            CASE CREATEDBY          
            WHEN 'TBLU_FACILITY_FEECOST' THEN 'TBLU_FACILITY_FEECOST'          
            ELSE 'SP_IFRS_TRX_PRORATE_HIST'          
            END         CREATEDBY,          
            GETDATE()   CREATEDDATE,          
            'LOCALHOST' CREATEDHOST,          
            CUSTOMER_NUMBER,      
			LIMIT_CURRENCY,      
			LIMIT_EXCHANGE_RATE,
			-- ADD COLUMN SEGMENT_FLAG 25-APR-2024
			SEGMENT_FLAG           
    FROM   IFRS_TRX_FACILITY_HEADER          
 WHERE (STATUS = 'ACT' AND DOWNLOAD_DATE <= @V_CURRDATE AND UNALOC > 0) OR      
 (STATUS IN ('CLS', 'PNL', 'REV') AND DOWNLOAD_DATE = @V_CURRDATE)         
          
    INSERT INTO IFRS_TRX_FACILITY_HEADER_HIST          
                (PKID,          
                REVID,          
                DOWNLOAD_DATE,          
                TRX_DATE,          
				FACILITY_NUMBER,          
                GL_CONSTNAME,          
                BRANCH_CODE,          
                TRX_CODE,          
                DATA_SOURCE,          
                PRD_TYPE,          
                PRD_CODE,          
                TRX_DR_CR,          
                CCY,          
                MATURITY_DATE,          
                EXCHANGE_RATE,          
                METHOD,          
                STATUS,          
                FLAG_CF,          
                PLAFOND,          
                TRX_AMOUNT,          
                ALOC,          
                UNALOC,          
                CREATEDBY,          
                CREATEDDATE,          
                CREATEDHOST,          
                CUSTOMER_NUMBER,      
				LIMIT_CURRENCY,      
				LIMIT_EXCHANGE_RATE,
				-- ADD COLUMN SEGMENT_FLAG 25-APR-2024
				SEGMENT_FLAG)       
   SELECT A.PKID,          
            REVID,          
            @V_CURRDATE DOWNLOAD_DATE,          
            TRX_DATE,          
            FACILITY_NUMBER,          
            GL_CONSTNAME,          
            BRANCH_CODE,          
            TRX_CODE,          
            DATA_SOURCE,          
            PRD_TYPE,          
            PRD_CODE,          
            TRX_DR_CR,          
            CCY,          
            MATURITY_DATE,          
            EXCHANGE_RATE,          
            METHOD,          
            A.STATUS,          
            FLAG_CF,          
            PLAFOND,          
            TRX_AMOUNT,          
            CASE          
            WHEN MATURITY_DATE <= @V_CURRDATE THEN TRX_AMOUNT          
            ELSE ALOC          
            END         AS ALOC,          
            CASE          
            WHEN MATURITY_DATE <= @V_CURRDATE THEN 0  ELSE UNALOC END AS UNALOC,          
            CASE CREATEDBY          
            WHEN 'TBLU_FACILITY_FEECOST' THEN 'TBLU_FACILITY_FEECOST'          
            ELSE 'SP_IFRS_TRX_PRORATE_HIST'          
            END         CREATEDBY,          
            GETDATE()   CREATEDDATE,          
            'LOCALHOST' CREATEDHOST,          
            CUSTOMER_NUMBER,      
			LIMIT_CURRENCY,      
			LIMIT_EXCHANGE_RATE,
			-- ADD COLUMN SEGMENT_FLAG 25-APR-2024
			SEGMENT_FLAG             
    FROM   IFRS_TRX_FACILITY_HEADER A          
        JOIN (SELECT PKID,          
                        STATUS          
                FROM   IFRS_TRX_FACILITY_HEADER_HIST          
                WHERE  STATUS = 'ACT'          
                        AND DOWNLOAD_DATE = @V_PREVDATE) B          
            ON A.PKID = B.PKID          
    WHERE  A.STATUS <> 'ACT'          
          
    SELECT @ROWSELLDOWN = COUNT(*)          
    FROM   IFRS_FACILITY_SELLDOWN_FLAG          
    WHERE  SELLDOWN_OR_CANCELATION_FLAG = 'Y'          
            AND DOWNLOAD_DATE = @V_CURRDATE              
END 
GO
