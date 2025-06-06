USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_EXEC_RULE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_EXEC_RULE]     
@CONSTNAME VARCHAR(50) = 'GL',                
@DOWNLOAD_DATE DATE = NULL                       
AS                                
 DECLARE @V_CURRDATE   DATE                                
 DECLARE @V_PREVDATE   DATE                                
 DECLARE @V_STR_SQL    VARCHAR(MAX)                                
 DECLARE @V_STR_SQL_RULE  VARCHAR(MAX)                                
 DECLARE @V_SCRIPT1    VARCHAR(MAX)                                
 DECLARE @V_SCRIPT2    VARCHAR(MAX)                                
 DECLARE @V_SC_SCRIPT VARCHAR(MAX)                                
 DECLARE @RULE_ID  VARCHAR(250)                                
 DECLARE @RULE_CODE1  VARCHAR(250)                                
 DECLARE @RULE_TYPE  VARCHAR(25)                                
 DECLARE @DEFAULT_FLAG1  VARCHAR(5)                                
 DECLARE @PD_SEGMENT2  VARCHAR(250)                                
 DECLARE @DEFAULT_FLAG2  VARCHAR(5)                                
 DECLARE @PKID  INT                                
 DECLARE @AOC  VARCHAR(3)                                
 DECLARE @MAX_PKID  INT                                
 DECLARE @MIN_PKID  INT                                
 DECLARE @QG   INT                                
 DECLARE @PREV_QG  INT                                
 DECLARE @NEXT_QG INT                                
 DECLARE @JML INT                                
 DECLARE @RN INT                                
 DECLARE @PD_SEGMENT_PKID INT                                
 DECLARE @COLUMN_NAME  VARCHAR(250)                                
 DECLARE @DATA_TYPE  VARCHAR(250)                                
 DECLARE @OPERATOR  VARCHAR(50)                                
 DECLARE @VALUE1 VARCHAR(250)                                
 DECLARE @VALUE2 VARCHAR(250)                                
 DECLARE @DEFAULT_FLAG  VARCHAR(5)                                
 DECLARE @INCREMENTS INT                                
 DECLARE @STATEMENT NVARCHAR(200)                                
 DECLARE @HISTORICAL_DATA VARCHAR(30)                                
 DECLARE @TABLE_NAME VARCHAR(30)                                
 DECLARE @UPDATED_TABLE VARCHAR(30)                                
 DECLARE @UPDATED_COLUMN VARCHAR(30)                          
BEGIN                         
                                
 IF @DOWNLOAD_DATE IS NULL                
 BEGIN                             
  SELECT @V_CURRDATE = CURRDATE,@V_PREVDATE = PREVDATE FROM IFRS_PRC_DATE_AMORT;                
 END                
 ELSE                
 BEGIN                
  SET @V_CURRDATE = @DOWNLOAD_DATE            
 END                                 
                                
SET @V_SC_SCRIPT = ' ';                                
SET @V_STR_SQL = ' ';                                
--SET @STATEMENT = 'TRUNCATE TABLE IFRS_RULE_GENERATE_QUERY'                                
--   EXECUTE SP_EXECUTESQL @STATEMENT                                
                                
DECLARE SEG1 CURSOR FOR                 
 SELECT DISTINCT UPDATED_TABLE, UPDATED_COLUMN, RULE_TYPE, TABLE_NAME, A.RULE_NAME, A.PKID                      
 FROM IFRS_SCENARIO_RULES_HEADER A                                
    INNER JOIN IFRS_SCENARIO_RULES_DETAIL B                                
    ON A.PKID = B.RULE_ID     AND B.IS_DELETE = 0   AND A.IS_DELETE = 0                        
    --LEFT JOIN IFRS_SCENARIO_RULES_CONFIG C                                
    --ON A.RULE_CODE = C.RULE_CODE                                
    WHERE A.RULE_TYPE = @CONSTNAME;                                
                                
 OPEN SEG1;                                
 FETCH SEG1 INTO @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,@TABLE_NAME, @RULE_CODE1, @RULE_ID --,@HISTORICAL_DATA,@DEFAULT_FLAG                                
 WHILE @@FETCH_STATUS=0                                
 BEGIN                            
  SET @V_SCRIPT1 = ' ';               
  SET @V_STR_SQL = ' ';                                
                                
  DECLARE SEG_RULE CURSOR FOR                      
   SELECT                                 
    'A.' + COLUMN_NAME,                                
    DATA_TYPE,                                
    OPERATOR,                                
    VALUE1,                                
    VALUE2,                                
    QUERY_GROUPING,                        
    AND_OR_CONDITION,                                
    LAG (QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING,SEQUENCE) PREV_QG,        
    LEAD (QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) NEXT_QG,        
    JML,                                
    RN,                         
    SEQUENCE                                
   FROM           
   (          
    SELECT           
     MIN (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG,                                
     MAX (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG,                                
     ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE ) RN,                                
     COUNT (0) OVER (PARTITION BY RULE_ID) JML,                                
     COLUMN_NAME,                                
     DATA_TYPE,                                
     OPERATOR,                                
     VALUE1,                                
     VALUE2,                                
     QUERY_GROUPING,                                
     --RULE_CODE,                                
     RULE_ID,                             
     AND_OR_CONDITION,                                  
     SEQUENCE                                
    FROM IFRS_SCENARIO_RULES_DETAIL                                
    WHERE RULE_ID = @RULE_ID  AND IS_DELETE = 0                              
   ) A;                                
         OPEN SEG_RULE;                                
         FETCH SEG_RULE INTO  @COLUMN_NAME,@DATA_TYPE,@OPERATOR,@VALUE1, @VALUE2, @QG,@AOC, @PREV_QG,@NEXT_QG,@JML ,@RN,@PKID                                
         WHILE @@FETCH_STATUS=0                                
         BEGIN                                
            SET @V_SCRIPT1 =                                
               ISNULL(@V_SCRIPT1, ' ') + ' ' + @AOC + ' ' + CASE WHEN  @QG <> @PREV_QG   THEN '(' ELSE ' ' END                                
               + ISNULL(CASE                                
               WHEN RTRIM(LTRIM (@DATA_TYPE)) IN ('NUMBER','DECIMAL','NUMERIC','FLOAT')                                
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
                           WHEN LOWER (@OPERATOR) IN ('IN','NOT IN')                                
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
                     WHEN RTRIM(LTRIM (@DATA_TYPE)) = 'DATE'                                
                     THEN                                
                        CASE                                
                      WHEN @OPERATOR IN ('=','<>','>','<','>=','<=')                                
                       THEN                                
                                ISNULL(@COLUMN_NAME, '')                                
                              + ' '                                
                              + ISNULL(@OPERATOR, '')                                
                              + '  TO_DATE('''                                
                              + ISNULL(@VALUE1, '')                                
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
                           WHEN LOWER (@OPERATOR) IN ('=','<>','>','<','>=','<=')                                
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
                     WHEN UPPER(RTRIM(LTRIM (@DATA_TYPE))) IN ('CHARACTER','VARCHAR','VARCHAR2')                                
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
                     THEN                                
                                 ISNULL(@COLUMN_NAME, '')                                
                              + ' '                                
                              + ISNULL(@OPERATOR, '')                                
                              + '  '                                
                              + ISNULL(@VALUE1, '')                                
                              + ' AND '                                
                              + ISNULL(@VALUE2, '')                                
                    WHEN RTRIM(LTRIM (LOWER (@OPERATOR))) IN ('IN','NOT IN')                                
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
                  END , ' ')  + CASE WHEN   @QG <> @NEXT_QG   OR @RN = @JML THEN ')' ELSE ' ' END;                                
                                
                                
                 FETCH NEXT FROM SEG_RULE INTO    @COLUMN_NAME,@DATA_TYPE,@OPERATOR,@VALUE1, @VALUE2, @QG,@AOC, @PREV_QG,@NEXT_QG,@JML,@RN,@PKID          
         END;                                
                                
       SET  @V_SCRIPT1 = '(' + LTRIM(SUBSTRING (@V_SCRIPT1, 6, LEN (@V_SCRIPT1) ))                                
                                
    SET @V_STR_SQL = @V_STR_SQL + 'UPDATE A SET ' + @UPDATED_COLUMN + ' = ''' + @RULE_CODE1 + ''' '                                
    SET @V_STR_SQL = @V_STR_SQL + 'FROM ' + @UPDATED_TABLE + ' A WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10),@V_CURRDATE,112) + ''' '                                
    SET @V_STR_SQL = @V_STR_SQL + 'AND (' + @V_SCRIPT1 + ')'                              
                               
    EXECUTE (@V_STR_SQL)                                
    --PRINT(@V_STR_SQL)                   
                                
       --INSERT INTO IFRS_RULE_GENERATE_QUERY (UPDATED_TABLE, UPDATED_COLUMN,RULE_TYPE,RULE_CODE,HISTORICAL_DATA,TABLE_NAME, PD_RULES_QRY_RESULT,DEFAULT_FLAG )                                
       --VALUES ( @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,(@RULE_CODE1), @HISTORICAL_DATA,@TABLE_NAME ,  @V_SCRIPT1,@DEFAULT_FLAG);                                
                                
                                
         CLOSE SEG_RULE;                           
         DEALLOCATE SEG_RULE;                                
                     
   FETCH NEXT FROM SEG1 INTO @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,@TABLE_NAME, @RULE_CODE1, @RULE_ID                               
                                
   END;                                
   CLOSE SEG1;                                
   DEALLOCATE SEG1;                                    
                                
END   
GO
