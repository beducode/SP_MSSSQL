USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPI_PROCESS]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
     
CREATE PROCEDURE [dbo].[SP_IFRS_IMPI_PROCESS]                                                         
@DOWNLOAD_DATE DATE = NULL        
AS                                   
   DECLARE @V_CURRDATE DATE                                    
   DECLARE @V_PREVDATE DATE                                                              
   DECLARE @V_PREVMONTH DATE                                  
   DECLARE @V_STR_SQL VARCHAR(MAX)                                    
   DECLARE @V_SCRIPT1 VARCHAR(MAX)                                    
   DECLARE @RULE_ID VARCHAR(100)                                    
   DECLARE @RULE_CODE1 VARCHAR(250)                                    
   DECLARE @RULE_TYPE VARCHAR(25)                                    
   DECLARE @PKID INT                                    
   DECLARE @AOC VARCHAR(3)                                   
   DECLARE @QG INT                                    
   DECLARE @PREV_QG INT                                    
   DECLARE @NEXT_QG INT                                    
   DECLARE @JML INT                                    
   DECLARE @RN INT                                     
   DECLARE @COLUMN_NAME VARCHAR(250)                                    
   DECLARE @DATA_TYPE VARCHAR(250)                                    
   DECLARE @OPERATOR VARCHAR(50)                                    
   DECLARE @VALUE1 VARCHAR(250)                                    
   DECLARE @VALUE2 VARCHAR(250)                                     
   DECLARE @TABLE_NAME VARCHAR(30)                                    
   DECLARE @UPDATED_TABLE VARCHAR(30)                                    
   DECLARE @UPDATED_COLUMN VARCHAR(30)                                   
BEGIN                                              
    IF @DOWNLOAD_DATE IS NULL                                  
    BEGIN                                   
        SELECT                                   
            @V_CURRDATE = CURRDATE,                                   
            @V_PREVDATE = PREVDATE                                    
        FROM IFRS_PRC_DATE_AMORT                                  
    END                                  
    ELSE                                  
    BEGIN                                   
        SET @V_CURRDATE = @DOWNLOAD_DATE                                   
    END                                  
    SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH, -1, @V_CURRDATE))                                              
                                    
    --DELETE IFRS_IMP_IA_SCENARIO_DATA WHERE EFFECTIVE_DATE = @V_CURRDATE AND SOURCE_SYSTEM <> 'T24'    
 --DELETE IFRS_IMP_IA_MASTER_HIST WHERE EFFECTIVE_DATE = DATEADD(DD, -1, @V_CURRDATE) AND IMPAIRED_FLAG = 'C' AND OVERRIDE_FLAG = 'A' AND SOURCE_SYSTEM <> 'T24'       
 /* NEW CBS */    
 DELETE IFRS_IMP_IA_SCENARIO_DATA WHERE EFFECTIVE_DATE = @V_CURRDATE AND DATA_SOURCE NOT IN ('LOAN_T24',  'TRADE_T24') --   ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24') 20221208 CBS    
 DELETE IFRS_IMP_IA_MASTER_HIST WHERE EFFECTIVE_DATE = DATEADD(DD, -1, @V_CURRDATE) AND IMPAIRED_FLAG = 'C' AND OVERRIDE_FLAG = 'A' AND DATA_SOURCE NOT IN ('LOAN_T24', 'TRADE_T24') -- ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24') 20221208 CBS    
 /* END NEW CBS */                                                       
        
                              
    -- UPDATE PLAFOND_CIF                              
    DROP TABLE IF EXISTS #IMA                                
    SELECT                                
        DOWNLOAD_DATE,                                
        MASTERID,                                   
        CUSTOMER_NUMBER,                                 
        CASE WHEN FACILITY_NUMBER IS NULL THEN MASTERID ELSE FACILITY_NUMBER END FACILITY_NUMBER,                         
        PLAFOND,          
        DATA_SOURCE,      
        SOURCE_SYSTEM                                    
    INTO #IMA                                
    FROM IFRS_IMA_AMORT_CURR (NOLOCK)                            
    WHERE DOWNLOAD_DATE = @V_CURRDATE       
    -- NEW LOGIC FOR CORPORATE T24      
    -- AND SOURCE_SYSTEM <> 'T24'    
 /* NEW CBS */    
 --AND DATA_SOURCE NOT IN ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24')         
 AND DATA_SOURCE NOT IN ('LOAN_T24', 'TRADE_T24')        
                                
    DROP TABLE IF EXISTS #IMA_CUSTOMER                    
    SELECT                                
        DOWNLOAD_DATE,                                
        CUSTOMER_NUMBER,                                          
        SUM(PLAFOND) AS PLAFOND_CIF,          
        DATA_SOURCE,      
        SOURCE_SYSTEM                                
    INTO #IMA_CUSTOMER        
    FROM                                
    (                                
        SELECT                               
            DOWNLOAD_DATE,                                
            CUSTOMER_NUMBER,                           
            FACILITY_NUMBER,                                
            MAX(PLAFOND) AS PLAFOND,          
            DATA_SOURCE,      
            SOURCE_SYSTEM                        
        FROM #IMA                           
        GROUP BY DOWNLOAD_DATE, CUSTOMER_NUMBER, FACILITY_NUMBER, DATA_SOURCE, SOURCE_SYSTEM                               
    ) A                      
    GROUP BY DOWNLOAD_DATE, CUSTOMER_NUMBER, DATA_SOURCE, SOURCE_SYSTEM                                
    ORDER BY CUSTOMER_NUMBER                                
                        
    UPDATE A                                
    SET                                             
        A.PLAFOND_CIF = B.PLAFOND_CIF,                                                            
        A.IMPAIRED_FLAG = 'C'                                                      
    FROM IFRS_IMA_AMORT_CURR A (NOLOCK)                               
    JOIN #IMA_CUSTOMER B                                
    ON A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER                                
    AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE          
    AND A.DATA_SOURCE = B.DATA_SOURCE      
    AND A.SOURCE_SYSTEM = B.SOURCE_SYSTEM                                
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE       
    -- NEW LOGIC FOR CORPORATE T24      
    -- AND A.SOURCE_SYSTEM <> 'T24'    
 /* NEW CBS */    
 AND A.DATA_SOURCE NOT IN ('LOAN_T24', 'TRADE_T24')      
 --AND A.DATA_SOURCE NOT IN ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24')      
                   
    UPDATE A                                
    SET                                                             
        A.PLAFOND_CIF = B.PLAFOND_CIF,                                                            
        A.IMPAIRED_FLAG = B.IMPAIRED_FLAG                            
    FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                            
    JOIN IFRS_IMA_AMORT_CURR B (NOLOCK)                            
    ON A.MASTERID = B.MASTERID                                                              
    AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
    AND A.SOURCE_SYSTEM = B.SOURCE_SYSTEM                                
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE       
    -- NEW LOGIC FOR CORPORATE T24      
    -- AND A.SOURCE_SYSTEM <> 'T24'       
 /* NEW CBS */     
 --AND A.DATA_SOURCE NOT IN ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24')      
 AND A.DATA_SOURCE NOT IN ('LOAN_T24', 'TRADE_T24')     
      
    DELETE [IFRS_SCENARIO_GENERATE_QUERY]                                                 
    WHERE RULE_TYPE = 'INDIVIDUAL_RULE'                           
                                      
    DECLARE SEG1                                     
    CURSOR FOR                           
        SELECT DISTINCT                                           
            CASE WHEN UPDATED_TABLE = 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_AMORT_CURR' ELSE UPDATED_TABLE END AS UPDATED_TABLE,      
            UPDATED_COLUMN,                                          
            RULE_TYPE,                                           
            CASE WHEN TABLE_NAME = 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_AMORT_CURR' ELSE TABLE_NAME END AS TABLE_NAME,      
            A.RULE_NAME,      
            A.PKID                                                
        FROM IFRS_SCENARIO_RULES_HEADER A                                    
        INNER JOIN IFRS_SCENARIO_RULES_DETAIL B ON A.PKID = B.RULE_ID                           
        WHERE A.IS_DELETE = 0 AND B.IS_DELETE = 0 AND RULE_TYPE = 'INDIVIDUAL_RULE'                                     
                                
    OPEN SEG1;                                             
    FETCH SEG1 INTO @UPDATED_TABLE, @UPDATED_COLUMN, @RULE_TYPE, @TABLE_NAME, @RULE_CODE1, @RULE_ID      
          
    WHILE @@FETCH_STATUS=0                                    
        BEGIN                                 
            SET @V_SCRIPT1 = ' ';                                    
            SET @V_STR_SQL = ' ';                                               
                                    
            DECLARE SEG_RULE CURSOR FOR                                     
                SELECT                                   
                    'A.' + COLUMN_NAME,                                  
                    DATA_TYPE,                                    
                    OPERATOR,                                    
                    VALUE1,                                        VALUE2,                                    
                    QUERY_GROUPING,                                    
                    AND_OR_CONDITION,                                    
                    LAG (QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) PREV_QG,      
                    LEAD (QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) NEXT_QG,      
                    JML,                                    
                    RN,                                    
                    PKID                                                
                FROM                                 
                (                                  
                    SELECT                      
                        MIN (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG,                                              
                        MAX (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG,                                              
                        ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY  QUERY_GROUPING, SEQUENCE ) RN,      
                        COUNT (0) OVER (PARTITION BY RULE_ID) JML,                                                      
                        COLUMN_NAME,                           
                        DATA_TYPE,                         
                        OPERATOR,                                    
                        VALUE1,                                    
                        VALUE2,                                    
                        QUERY_GROUPING,                                  
                        RULE_ID,                                                            
                        AND_OR_CONDITION,                                                
                        PKID,                  
                        SEQUENCE                                    
                    FROM IFRS_SCENARIO_RULES_DETAIL                                  
                    WHERE RULE_ID = @RULE_ID                            
                    AND IS_DELETE=0                             
                ) A;                                    
                                         
            OPEN SEG_RULE;                                    
            FETCH SEG_RULE INTO  @COLUMN_NAME, @DATA_TYPE, @OPERATOR, @VALUE1, @VALUE2, @QG, @AOC, @PREV_QG, @NEXT_QG, @JML, @RN, @PKID                                        
                WHILE @@FETCH_STATUS = 0                                    
                BEGIN      
                    SET @V_SCRIPT1 =                                    
                        ISNULL(@V_SCRIPT1, ' ') + ' ' + @AOC + ' ' + CASE WHEN  @QG <> @PREV_QG   THEN '(' ELSE ' ' END + ISNULL(CASE WHEN RTRIM(LTRIM (@DATA_TYPE)) IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'FLOAT', 'INT')       
                        THEN                                    
            CASE                                    
                                WHEN @OPERATOR IN ('=','<>','>','<','>=','<=')                                                    
                                THEN                         
                                ISNULL(@COLUMN_NAME, '')                                              
                                + ' '                                    
                                + ISNULL(@OPERATOR, '')                                              
                               + ' '                                    
                                + ISNULL(@VALUE1, '')                                              
                                WHEN LOWER (@OPERATOR) = 'BETWEEN'                                              
                                THEN                                    
                                ISNULL(@COLUMN_NAME, '')                                              
                                + ' '                                                
                                + ISNULL(@OPERATOR, '')                            
                                + ' '                                    
                                + ISNULL(@VALUE1, '')                                    
                                + ' AND '                                    
                                + ISNULL(@VALUE2, '')                                    
                                WHEN LOWER (@OPERATOR) = 'IN'                                              
                                THEN                          
                                ISNULL(@COLUMN_NAME, '')                                              
                                + ' '                                          
                                + ISNULL(@OPERATOR, '')                                              
                                + ' '                                    
                                + '('                                                              
                                + ISNULL(@VALUE1, '')                     
                                + ')'                                    
                                ELSE                                    
                                'XXX'                                    
                            END             
                            WHEN RTRIM(LTRIM (@DATA_TYPE)) IN ('DATE','DATETIME')                                              
                            THEN                                    
                                CASE                                    
                                    WHEN @OPERATOR IN ('=','<>','>','<','>=','<=')                                              
                                    THEN                                              
                                    ISNULL(@COLUMN_NAME, '')                                              
                                    + ' '                                    
                                    + ISNULL(@OPERATOR, '')                                              
                                    + '  TO_DATE('''+ ISNULL(@VALUE1, '')                                     
                                    + ''',''MM/DD/YYYY'')'                                              
                                    WHEN LOWER (@OPERATOR) = 'BETWEEN'                                              
                                    THEN                                    
      ISNULL(@COLUMN_NAME, '')                                              
                                    + ' '                                            
                                    + ISNULL(@OPERATOR, '')                                              
                                    + ' '                                    
                                    + '   CONVERT(DATE,'''                                              
                           + ISNULL(@VALUE1, '')                                              
                                    + ''',110)'          
                                    + ' AND '                           
                                    + '  CONVERT(DATE,'''                                              
                                    + ISNULL(@VALUE2, '')                                              
                                    + ''',110)'                                    
                                    WHEN LOWER (@OPERATOR) IN('=','<>','>','<','>=','<=')                                  
                                    THEN                                   
                                    ISNULL(@COLUMN_NAME, '')                                              
                                    + ' '                                    
                                    + ISNULL(@OPERATOR, '')                                              
                                    + ' '                                                
                                    + '('                                    
                                    + '  TO_DATE('''                                    
                                    + ISNULL(@VALUE1, '')                                              
                                    + ''',''MM/DD/YYYY'')'                                              
                                    + ')'                                    
                                    ELSE                                       
                                    'XXX'                                    
                                END                                    
                            WHEN UPPER(RTRIM(LTRIM (@DATA_TYPE))) IN ('CHAR','CHARACTER', 'VARCHAR', 'VARCHAR2','BIT')                                      
                            THEN                                  
                                CASE                                    
                                    WHEN RTRIM(LTRIM (@OPERATOR)) = '='                                              
                                    THEN                                    
                                     ISNULL(@COLUMN_NAME, ' ')                                              
                                     + ' '                                    
                                     + ISNULL(@OPERATOR, ' ')                                              
                                     + ''''                               
                                     + ISNULL(@VALUE1, ' ')                                              
                                     + ''''                                    
                                    WHEN RTRIM(LTRIM (LOWER (@OPERATOR))) = 'BETWEEN'                                              
                                    THEN    ISNULL(@COLUMN_NAME, '')                                              
                                     + ' '                                    
                                     + ISNULL(@OPERATOR, '')                                              
                                     + '  '                           
                                     + ISNULL(@VALUE1, '')                                              
                                     + ' AND '                                    
                                     + ISNULL(@VALUE2, '')                                      
                                    WHEN RTRIM(LTRIM (LOWER (@OPERATOR))) = 'IN'                                              
                                    THEN                                    
                                     ISNULL(@COLUMN_NAME, '')                          
                                     + ' '                                              
                                     + ISNULL(@OPERATOR, '')                                              
                      + '  '                                    
                                     + '('''                                    
                                     + ISNULL(REPLACE (@VALUE1, ',', ''','''), '')                                              
                                     + ''')'                               
                                    ELSE                                    
                                     'XXX'                                  
                                END                                    
                            ELSE                                   
                            'XXX'                                    
                        END , ' ')  + CASE WHEN @QG <> @NEXT_QG   OR @RN = @JML THEN ')' ELSE ' ' END;                    
                                    
         FETCH NEXT FROM SEG_RULE INTO @COLUMN_NAME, @DATA_TYPE, @OPERATOR, @VALUE1, @VALUE2, @QG, @AOC, @PREV_QG, @NEXT_QG, @JML, @RN, @PKID                                             
      END;                                    
                                            
        SET  @V_SCRIPT1 = '(' + LTRIM(SUBSTRING (@V_SCRIPT1, 6, LEN (@V_SCRIPT1)))                                
                                
        SET @V_STR_SQL =                                  
            @V_STR_SQL + 'SELECT                                 
            A.MASTERID,                                 
            A.DOWNLOAD_DATE AS EFFECTIVE_DATE,                                 
            A.CUSTOMER_NUMBER,                      
            CUSTOMER_NAME,                                
            PRODUCT_GROUP,                                                  
            PRODUCT_CODE,                                
            CASE WHEN A.FACILITY_NUMBER IS NULL THEN A.MASTERID ELSE A.FACILITY_NUMBER END AS FACILITY_NUMBER,                
            A.LOAN_DUE_DATE AS MATURITY_DATE,                                
            CURRENCY,                                
            INTEREST_RATE,                                
            EIR,                                
            AVG_EIR,           
            CASE WHEN A.DATA_SOURCE = ''LIMIT_T24'' THEN UNUSED_AMOUNT ELSE OUTSTANDING END OUTSTANDING,                         
            PLAFOND,                                
            DAY_PAST_DUE,                                
            BI_COLLECTABILITY,                                         
            DPD_CIF,                                                       
            RESTRUCTURE_COLLECT_FLAG,                                
            BI_COLLECT_CIF,                                
            B.PLAFOND_CIF,                                
            ' + @RULE_ID + ' AS IA_RULE_ID,          
            A.DATA_SOURCE,      
            A.SOURCE_SYSTEM'          
        SET @V_STR_SQL = @V_STR_SQL + '                     
        FROM ' + @UPDATED_TABLE + ' A (NOLOCK)                       
        JOIN #IMA_CUSTOMER B                                
        ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE                                
        AND A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER          
        AND A.DATA_SOURCE = B.DATA_SOURCE           
        AND A.SOURCE_SYSTEM = B.SOURCE_SYSTEM      
        WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE,112) + '''      
  AND A.DATA_SOURCE <> ''LIMIT'' AND A.DATA_SOURCE NOT IN (''LOAN_T24'', ''TRADE_T24'') ' -- NEW CBS    
  --AND A.DATA_SOURCE <> ''LIMIT'' AND A.DATA_SOURCE NOT IN (''LOAN_T24'', ''LIMIT_T24'', ''TRADE_T24'')    
  --AND A.DATA_SOURCE <> ''LIMIT'' AND A.SOURCE_SYSTEM <> ''T24''                                             
                                                                 
                                    
        SET @V_STR_SQL = @V_STR_SQL + ' AND (' + @V_SCRIPT1 + ')'                                              
                          
        -- INSERT TO SCENARIO DATA                                
        INSERT INTO IFRS_IMP_IA_SCENARIO_DATA                                 
        (                 
            MASTERID,                                 
            EFFECTIVE_DATE,                                 
            CUSTOMER_NUMBER,                          
            CUSTOMER_NAME,                                
            PRODUCT_GROUP,                            
            PRODUCT_CODE,                                
            FACILITY_NUMBER,                                
            MATURITY_DATE,                                
            CURRENCY,                                
            INTEREST_RATE,                                
            EIR,                                
            AVG_EIR,                                      
            OUTSTANDING,                                
            PLAFOND,                                
            DAY_PAST_DUE,                                
            BI_COLLECTABILITY,                                                            
            DPD_CIF,                                
            RESTRUCTURE_COLLECT_FLAG,                                
          BI_COLLECT_CIF,                                
            PLAFOND_CIF,                                
            IA_RULE_ID,          
            DATA_SOURCE,      
            SOURCE_SYSTEM                                 
        )                                
        EXEC (@V_STR_SQL)                                 
        --PRINT @V_STR_SQL                           
                                
        CLOSE SEG_RULE;                                               
        DEALLOCATE SEG_RULE;                                  
                                        
        -- INSERT TO RULES                                                
        INSERT INTO [IFRS_SCENARIO_GENERATE_QUERY]                                              
        (                                                
            RULE_ID                                 
            ,RULE_NAME                                  
            ,RULE_TYPE                                  
            ,TABLE_NAME                                  
            ,PD_RULES_QRY_RESULT                                  
            ,CREATEDBY                                  
            ,CREATEDDATE                                  
        )                                  
        SELECT                                                 
            @RULE_ID                                  
            ,@RULE_CODE1                                  
            ,@RULE_TYPE                        
            ,@TABLE_NAME                                  
            ,@V_SCRIPT1 AS PD_RULES_QRY_RESULT                                  
            ,'SP_IFRS_IMP_IA_PROCESS' AS CREATEDBY                                  
            ,GETDATE () AS CREATEDDATE                                  
                                   
        FETCH NEXT FROM SEG1 INTO @UPDATED_TABLE, @UPDATED_COLUMN, @RULE_TYPE, @TABLE_NAME, @RULE_CODE1, @RULE_ID                                    
    END;                                    
    CLOSE SEG1;                                    
    DEALLOCATE SEG1;                                   
                        
    IF (DAY(@V_CURRDATE) BETWEEN 1 AND 26)               
    --OR (@V_CURRDATE = '20190731')              
    BEGIN                           
        -- INSERT TO IFRS_IMP_IA_MASTER FROM SCENARIO DATA, WHICH IS NOT IN IFRS_IMP_IA_MASTER ITSELF                    
        INSERT INTO IFRS_IMP_IA_MASTER                                
        (                                
            MASTERID                                
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME                                            
            ,PRODUCT_GROUP                                
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                     
            ,CURRENCY                                                              
            ,INTEREST_RATE     
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                             
            ,DPD_CIF                              
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,OVERRIDE_FLAG                                
            ,BEING_EDITED                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM      
        )                                
        SELECT                                
            MASTERID                            
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME        
            ,PRODUCT_GROUP                                
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                                
            ,INTEREST_RATE                                   
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                         
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                
            ,DPD_CIF                                
            ,RESTRUCTURE_COLLECT_FLAG                     
            ,BI_COLLECT_CIF                                
  ,OVERRIDE_FLAG                           
            ,BEING_EDITED                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM          
        FROM IFRS_IMP_IA_SCENARIO_DATA                                
        WHERE EFFECTIVE_DATE = @V_CURRDATE                               
        AND MASTERID NOT IN (SELECT MASTERID FROM IFRS_IMP_IA_MASTER)      
                                    
        -- INSERT TO IFRS_IMP_IA_MASTER_HIST FOR INITIALIZE                                              
        INSERT INTO IFRS_IMP_IA_MASTER_HIST                                
        (                                
            MASTERID                                
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME                                
            ,PRODUCT_GROUP                                                 
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                                
            ,INTEREST_RATE                                
            ,EIR                                
            ,AVG_EIR                         
            ,OUTSTANDING                                
            ,PLAFOND                 
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                
            ,DPD_CIF                                
            ,RESTRUCTURE_COLLECT_FLAG                                                      
            ,BI_COLLECT_CIF                                
            ,OVERRIDE_FLAG                                
            ,BEING_EDITED                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM                                
        )                                
        SELECT                              
            MASTERID                                
            ,EFFECTIVE_DATE                                                 
            ,CUSTOMER_NUMBER                                                     
            ,CUSTOMER_NAME                                
            ,PRODUCT_GROUP                                                       
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                                
            ,INTEREST_RATE                                
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                
            ,DAY_PAST_DUE                                       
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                
            ,DPD_CIF                                
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,OVERRIDE_FLAG             
            ,BEING_EDITED                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM                                  
        FROM IFRS_IMP_IA_SCENARIO_DATA                        
        WHERE EFFECTIVE_DATE = @V_CURRDATE                                
        AND MASTERID NOT IN (SELECT MASTERID FROM IFRS_IMP_IA_MASTER)                                              
                                    
        -- INSERT TO IFRS_IMP_IA_MASTER_HIST WHICH IS CHANGE TO COLLECTIVE                                              
        INSERT INTO IFRS_IMP_IA_MASTER_HIST                                
        (                                
            MASTERID                         
            ,DCFID                                
            ,DOWNLOAD_DATE                                
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME                            
            ,PRODUCT_GROUP                                
            ,PRODUCT_CODE                                    
            ,MATURITY_DATE                                
            ,CURRENCY                        
            ,INTEREST_RATE                                
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                
            ,DPD_CIF                                
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,METHOD                                
            ,REMARKS                                
            ,MANAGER_NAME                               
            ,MANAGER_TELEPHONE                                
            ,MANAGER_HANDPHONE                                
            ,REMARKS_A                                
            ,REMARKS_B                                
            ,REMARKS_C                                
            ,REMARKS_D                                                     
            ,REMARKS_E                                
            ,REMARKS_E1                                
            ,REMARKS_E2                                
            ,REMARKS_F                                
            ,REMARKS_F1                                
            ,STATUS                                
            ,BEING_EDITED                                
            ,OVERRIDE_FLAG                                
            ,NPV_AMOUNT                                
            ,ECL_AMOUNT                                
            ,UNWINDING_AMOUNT                                
            ,CREATEDBY                                
            ,CREATEDDATE                                
,CREATEDHOST                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM                                                       
        )                                
        SELECT                           
            MASTERID                                
            ,DCFID                                
            ,DOWNLOAD_DATE                    
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME                                
            ,PRODUCT_GROUP                                
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                                
            ,INTEREST_RATE                                
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                    
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,'C' AS IMPAIRED_FLAG                                                   
            ,DPD_CIF                            
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,METHOD                                
            ,REMARKS                                
            ,MANAGER_NAME                                
            ,MANAGER_TELEPHONE                                
            ,MANAGER_HANDPHONE                                
            ,REMARKS_A                                
            ,REMARKS_B                                
            ,REMARKS_C                                
            ,REMARKS_D                                
            ,REMARKS_E                   
            ,REMARKS_E1                                
            ,REMARKS_E2                                
            ,REMARKS_F                                
            ,REMARKS_F1                                
            ,'APPROVE_OVERRIDE' AS STATUS                                
            ,BEING_EDITED                                
            ,'A' AS OVERRIDE_FLAG                                             
            ,NPV_AMOUNT                                
            ,ECL_AMOUNT                                
            ,UNWINDING_AMOUNT                                
            ,CREATEDBY                                
            ,CREATEDDATE                                
            ,CREATEDHOST                    
            ,PLAFOND_CIF          
            ,DATA_SOURCE      
            ,SOURCE_SYSTEM                                   
        FROM IFRS_IMP_IA_MASTER                                
        WHERE MASTERID NOT IN          
        (                                              
            SELECT MASTERID                                              
            FROM IFRS_IMP_IA_SCENARIO_DATA                                              
            WHERE EFFECTIVE_DATE = @V_CURRDATE                                              
        )                            
                           
        DELETE IFRS_IMP_IA_MASTER                                                               
        WHERE MASTERID NOT IN                                               
        (                                              
            SELECT MASTERID                                               
            FROM IFRS_IMP_IA_SCENARIO_DATA                                               
            WHERE EFFECTIVE_DATE = @V_CURRDATE                                              
        )                                                     
    END                                        
                      
    -- UP TO DATING INFORMATION DATA                              
    UPDATE A          
    SET                                
        A.CUSTOMER_NUMBER = B.CUSTOMER_NUMBER,                                
        A.CUSTOMER_NAME = B.CUSTOMER_NAME,                                
        A.PRODUCT_CODE = B.PRODUCT_CODE,                                
        A.PRODUCT_GROUP = B.PRODUCT_GROUP,                                   
        A.MATURITY_DATE = B.LOAN_DUE_DATE,                            
        A.CURRENCY = B.CURRENCY,                                
        A.INTEREST_RATE = B.INTEREST_RATE,                                
        A.EIR = B.EIR,                                
        A.AVG_EIR = B.AVG_EIR,                         
        A.OUTSTANDING = CASE WHEN A.DATA_SOURCE = 'LIMIT_T24' THEN B.UNUSED_AMOUNT ELSE B.OUTSTANDING END,   --~oO 20221208 CBS                            
        A.PLAFOND = B.PLAFOND,                                
        A.DAY_PAST_DUE = B.DAY_PAST_DUE,                                
        A.DPD_CIF = B.DPD_CIF,                                
        A.BI_COLLECTABILITY = B.BI_COLLECTABILITY,                                
        A.BI_COLLECT_CIF = B.BI_COLLECT_CIF,              
        A.RESTRUCTURE_COLLECT_FLAG = B.RESTRUCTURE_COLLECT_FLAG,                                      
        A.UPDATEDBY = 'SP_IFRS_IMPI_PROCESS',                                                    
        A.UPDATEDDATE = GETDATE()                                
    FROM IFRS_IMP_IA_MASTER A (NOLOCK)                                 
    JOIN IFRS_IMA_AMORT_CURR B (NOLOCK)                                         
    ON A.MASTERID = B.MASTERID                                
                                                              
    -- IF CURRENT DATE IS EOMONTH                             
    IF EOMONTH(@V_CURRDATE) = @V_CURRDATE                    
    BEGIN                    
        DROP TABLE IF EXISTS #ECL                                                 
        -- INDIVIDUAL WHICH IS LATEST DCF UPLOAD DATE = CURRENT_DATE                    
        SELECT                                               
            EOMONTH(B.DOWNLOADDATE) AS DOWNLOAD_DATE,                                               
            A.MASTERID,                 
   --Update 14 Dec 2022 Indra Outstanding-sum(NPV) < 0 as 0  
            CASE WHEN (A.OUTSTANDING - SUM(B.NPV)) < 0 Then 0 ElSE (A.OUTSTANDING-SUM(B.NPV)) END AS ECL_AMOUNT,                                               
            CASE WHEN (A.OUTSTANDING - SUM(B.NPV)) < 0 Then 0 ElSE (A.OUTSTANDING-SUM(B.NPV)) END AS ECL_AMOUNT_BFL                      
        INTO #ECL                    
        FROM (SELECT * FROM IFRS_IMP_IA_MASTER WHERE EFFECTIVE_DATE <= @V_CURRDATE) A      
        JOIN TBLT_PAYMENTEXPECTED B                                  
        ON A.DCFID = B.DCFID                                
        WHERE EOMONTH(B.DOWNLOADDATE) = @V_CURRDATE                                  
        GROUP BY EOMONTH(B.DOWNLOADDATE), A.MASTERID, A.OUTSTANDING                       
                            
        DELETE IFRS_ECL_INDIVIDUAL WHERE DOWNLOAD_DATE >= @V_CURRDATE                    
                            
        INSERT INTO IFRS_ECL_INDIVIDUAL (DOWNLOAD_DATE, MASTERID, ECL_AMOUNT, ECL_AMOUNT_BFL)                    
        SELECT DOWNLOAD_DATE, MASTERID, ECL_AMOUNT, ECL_AMOUNT_BFL FROM #ECL WHERE DOWNLOAD_DATE = @V_CURRDATE      
              
        SELECT * INTO #ECL_INDIVIDUAL FROM #ECL WHERE 1 = 2                    
                    
        INSERT INTO #ECL_INDIVIDUAL (DOWNLOAD_DATE, MASTERID)                    
        SELECT MAX(DOWNLOAD_DATE) AS DOWNLOAD_DATE, MASTERID FROM IFRS_ECL_INDIVIDUAL GROUP BY MASTERID      
      
        UPDATE X                    
        SET X.ECL_AMOUNT = Y.ECL_AMOUNT,                    
            X.ECL_AMOUNT_BFL = Y.ECL_AMOUNT_BFL                    
        FROM #ECL_INDIVIDUAL X                    
        JOIN IFRS_ECL_INDIVIDUAL Y                    
        ON X.DOWNLOAD_DATE = Y.DOWNLOAD_DATE AND X.MASTERID = Y.MASTERID                    
                    
        -- INDIVIDUAL WHICH IS LATEST DCF UPLOAD DATE < CURRENT_DATE                     
        INSERT INTO #ECL                                              
        (                                              
            DOWNLOAD_DATE,              
            MASTERID,                                               
            ECL_AMOUNT,               
            ECL_AMOUNT_BFL                                              
        )                                              
        SELECT                                               
            EOMONTH(B.DOWNLOADDATE) AS DOWNLOAD_DATE,                                               
            A.MASTERID,                     
            CASE WHEN C.ECL_AMOUNT > A.OUTSTANDING THEN A.OUTSTANDING ELSE C.ECL_AMOUNT END AS ECL_AMOUNT,      
            CASE WHEN C.ECL_AMOUNT_BFL > A.OUTSTANDING THEN A.OUTSTANDING ELSE C.ECL_AMOUNT_BFL END AS ECL_AMOUNT_BFL                    
        FROM (SELECT * FROM IFRS_IMP_IA_MASTER WHERE EFFECTIVE_DATE <= @V_CURRDATE) A                      
        JOIN (SELECT DISTINCT DOWNLOADDATE, DCFID FROM TBLT_PAYMENTEXPECTED) B                      
        ON A.DCFID = B.DCFID                    
        JOIN                     
        (                    
            SELECT                            
                X.MASTERID,                    
                X.ECL_AMOUNT,                                               
                X.ECL_AMOUNT_BFL                                              
            FROM #ECL_INDIVIDUAL (NOLOCK) X                           
            JOIN (SELECT * FROM IFRS_IMP_IA_MASTER WHERE EFFECTIVE_DATE <= @V_CURRDATE) Y                      
            ON X.MASTERID = Y.MASTERID                    
        ) C                    
        ON A.MASTERID = C.MASTERID                                             
        WHERE B.DOWNLOADDATE < @V_CURRDATE                                      
                                  
        -- INDIVIDUAL BUT NOT HAVE DCF                    
        INSERT INTO #ECL                                              
        (                                              
            DOWNLOAD_DATE,                                               
            MASTERID,                                               
            ECL_AMOUNT,                                               
            ECL_AMOUNT_BFL                                              
        )                                              
        SELECT                                               
            EOMONTH(EFFECTIVE_DATE) AS DOWNLOAD_DATE,                                               
            MASTERID,           
            OUTSTANDING AS ECL_AMOUNT,                                               
            OUTSTANDING AS ECL_AMOUNT_BFL                    
        FROM IFRS_IMP_IA_MASTER                     
        WHERE DCFID IS NULL                                          
        AND EFFECTIVE_DATE <= @V_CURRDATE                    
                                          
        ALTER TABLE #ECL ADD UNWINDING_AMOUNT NUMERIC(32,6) DEFAULT 0;      
                    
        UPDATE A                    
        SET A.UNWINDING_AMOUNT = B.UNWINDING_AMOUNT                    
        FROM #ECL A                    
        JOIN                     
        (                                                        
            SELECT                                               
               EOMONTH(A.EFFECTIVE_DATE) AS DOWNLOAD_DATE,                                               
                A.MASTERID,                                               
                SUM(B.UNWINDING_AMOUNT) AS UNWINDING_AMOUNT                     
            FROM (SELECT * FROM IFRS_IMP_IA_MASTER WHERE EFFECTIVE_DATE <= @V_CURRDATE) A                      
            JOIN TBLT_PAYMENTEXPECTED B                    
            ON A.DCFID = B.DCFID                    
            WHERE EOMONTH(B.EFFECTIVE_DATE_FD) <= @V_CURRDATE                                                  
            GROUP BY EOMONTH(A.EFFECTIVE_DATE), A.MASTERID                    
        ) B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID                                        
                                                             
        UPDATE A                    
        SET        
            A.ECL_AMOUNT = B.ECL_AMOUNT,                                                   
            A.UNWINDING_AMOUNT = CASE WHEN ISNULL(B.UNWINDING_AMOUNT, 0) > B.ECL_AMOUNT THEN B.ECL_AMOUNT ELSE ISNULL(B.UNWINDING_AMOUNT, 0) END                                             
        FROM IFRS_IMP_IA_MASTER (NOLOCK) A                                                     
        JOIN #ECL B                    
        ON A.MASTERID = B.MASTERID                                          
                    
        UPDATE A                    
        SET                     
            A.ECL_AMOUNT = CASE WHEN ISNULL(A.IFRS9_CLASS, '') = 'FVTPL' THEN 0 ELSE B.ECL_AMOUNT END,                    
            A.ECL_AMOUNT_BFL = CASE WHEN ISNULL(A.IFRS9_CLASS, '') = 'FVTPL' THEN 0 ELSE B.ECL_AMOUNT_BFL END,      
            A.IA_UNWINDING_AMOUNT = CASE WHEN ISNULL(A.IFRS9_CLASS, '') = 'FVTPL' THEN 0 ELSE CASE WHEN B.UNWINDING_AMOUNT > B.ECL_AMOUNT THEN B.ECL_AMOUNT ELSE B.UNWINDING_AMOUNT END END                
        FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                 
        JOIN #ECL B                    
        ON A.MASTERID = B.MASTERID                                              
        WHERE A.DOWNLOAD_DATE = @V_CURRDATE                                              
                                          
        DELETE IFRS_IMP_IA_MASTER_HIST WHERE CREATEDBY = 'IFRS_IMP_IA_MASTER_HIST' AND EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE                                    
                                      
        INSERT INTO IFRS_IMP_IA_MASTER_HIST                                
        (                                
            MASTERID                         
            ,DCFID                                
            ,DOWNLOAD_DATE                                                        
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                
            ,CUSTOMER_NAME                                
            ,PRODUCT_GROUP                                
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                                
            ,INTEREST_RATE                                
            ,EIR                                
            ,AVG_EIR                                 
            ,OUTSTANDING                                
            ,PLAFOND                    
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                
            ,DPD_CIF                                
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,METHOD                                
            ,REMARKS                                
            ,MANAGER_NAME                               
            ,MANAGER_TELEPHONE                                
            ,MANAGER_HANDPHONE                                
            ,REMARKS_A                                
            ,REMARKS_B                                
            ,REMARKS_C                                
            ,REMARKS_D                                
            ,REMARKS_E                          
            ,REMARKS_E1                                
            ,REMARKS_E2                                
            ,REMARKS_F                     
            ,REMARKS_F1                      
            ,STATUS                                
            ,BEING_EDITED                                
            ,OVERRIDE_FLAG                                
            ,NPV_AMOUNT                             
            ,ECL_AMOUNT                                
            ,UNWINDING_AMOUNT                                
            ,CREATEDBY                                                            
            ,CREATEDDATE                           
            ,CREATEDHOST                    
            ,PLAFOND_CIF      
       ,SOURCE_SYSTEM                                                       
        )                                
        SELECT                                
            MASTERID                                
            ,NULL AS DCFID                                
            ,DOWNLOAD_DATE                                
            ,EFFECTIVE_DATE                                
            ,CUSTOMER_NUMBER                                                             
            ,CUSTOMER_NAME                                
            ,PRODUCT_GROUP                    
            ,PRODUCT_CODE                                
            ,MATURITY_DATE                                
            ,CURRENCY                      
            ,INTEREST_RATE                      
            ,EIR                                
            ,AVG_EIR                                
            ,OUTSTANDING                                
            ,PLAFOND                                
            ,DAY_PAST_DUE                                
            ,BI_COLLECTABILITY                                
            ,IMPAIRED_FLAG                                                            
            ,DPD_CIF                  
            ,RESTRUCTURE_COLLECT_FLAG                                
            ,BI_COLLECT_CIF                                
            ,METHOD                                
            ,REMARKS                                
            ,MANAGER_NAME                                
            ,MANAGER_TELEPHONE                                
            ,MANAGER_HANDPHONE                                         
            ,REMARKS_A                                
            ,REMARKS_B                                
            ,REMARKS_C                                
            ,REMARKS_D                                
            ,REMARKS_E                                
            ,REMARKS_E1                                
            ,REMARKS_E2                                
            ,REMARKS_F                                
            ,REMARKS_F1                                
            ,STATUS                      
            ,BEING_EDITED                                
            ,OVERRIDE_FLAG                                            
            ,NPV_AMOUNT                                
       ,ECL_AMOUNT                                
            ,UNWINDING_AMOUNT                                
            ,'SP_IFRS_IMPI_PROCESS' AS CREATEDBY                                
            ,GETDATE() AS CREATEDDATE                                
            ,CREATEDHOST                    
            ,PLAFOND_CIF      
            ,SOURCE_SYSTEM                                                   
        FROM IFRS_IMP_IA_MASTER                                
        WHERE DCFID IS NOT NULL                                          
        AND EOMONTH(DOWNLOAD_DATE) <= @V_CURRDATE                                                              
    END                    
                                                             
    UPDATE A                                                   
    SET A.IMPAIRED_FLAG = CASE WHEN B.MASTERID IS NOT NULL THEN 'I' ELSE 'C' END      
    FROM IFRS_IMA_AMORT_CURR A (NOLOCK)                                                               
    LEFT JOIN                 
    (                
        SELECT EFFECTIVE_DATE, MASTERID                
        FROM IFRS_IMP_IA_MASTER (NOLOCK)                
        WHERE EFFECTIVE_DATE <= @V_CURRDATE                 
        AND MASTERID NOT IN                 
        (                
            SELECT MASTERID                 
            FROM IFRS_ECL_EXCLUSION                 
            WHERE DOWNLOAD_DATE = @V_CURRDATE                
        )                
    ) B                    
    ON                                       
    /* FD 31 05 2019, CHANGE LOGIC NOT =, BUT ALL IA MASTER THAT HAS EFFECTIVE DATE <= CURRDATE*/                
    --A.DOWNLOAD_DATE = EOMONTH(B.EFFECTIVE_DATE)                                       
    A.DOWNLOAD_DATE >= EOMONTH(B.EFFECTIVE_DATE)                                       
    AND A.MASTERID = B.MASTERID                
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
    --AND A.SOURCE_SYSTEM <> 'T24'     
 /* NEW CBS */    
 AND A.DATA_SOURCE NOT IN ('LOAN_T24', 'LIMIT_T24', 'TRADE_T24')                                                 
                                                        
    UPDATE A                    
    SET A.IMPAIRED_FLAG = CASE WHEN B.MASTERID IS NOT NULL THEN 'I' ELSE 'C' END      
    FROM IFRS_MASTER_ACCOUNT A (NOLOCK)                     
    LEFT JOIN                 
    (                
        SELECT EFFECTIVE_DATE, MASTERID                
        FROM IFRS_IMP_IA_MASTER (NOLOCK)                
        WHERE EFFECTIVE_DATE <= @V_CURRDATE                 
        AND MASTERID NOT IN                 
        (                
            SELECT MASTERID                 
            FROM IFRS_ECL_EXCLUSION                 
            WHERE DOWNLOAD_DATE = @V_CURRDATE                
        )                
    ) B                     
    ON                                
    /* FD 31 05 2019, CHANGE LOGIC NOT =, BUT ALL IA MASTER THAT HAS EFFECTIVE DATE <= CURRDATE*/       
    --A.DOWNLOAD_DATE = EOMONTH(B.EFFECTIVE_DATE)                                       
     A.DOWNLOAD_DATE >= EOMONTH(B.EFFECTIVE_DATE)                                       
    AND A.MASTERID = B.MASTERID                                              
    WHERE A.DOWNLOAD_DATE = @V_CURRDATE             
            
END
GO
