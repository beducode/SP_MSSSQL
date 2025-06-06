USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_DEFAULT_RULE_ECL]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_DEFAULT_RULE_ECL]         
 @DOWNLOAD_DATE DATE = NULL,                      
 @MODEL_TYPE VARCHAR(4) = '',                          
 @MODEL_ID BIGINT = 0                   
AS                  
BEGIN                 
   DECLARE @V_CURRDATE   DATE                      
   DECLARE @V_PREVDATE   DATE                      
   DECLARE @V_STR_SQL    VARCHAR(max)                      
   DECLARE @V_STR_SQL_RULE  VARCHAR(max)                      
   DECLARE @v_Script1    VARCHAR(max)                      
   DECLARE @v_Script2    VARCHAR(max)                      
   DECLARE @V_SC_SCRIPT VARCHAR(max)                      
   DECLARE @RULE_ID  VARCHAR(100)                      
   DECLARE @RULE_CODE1  VARCHAR(250)                      
   DECLARE @RULE_TYPE  VARCHAR(25)                      
   DECLARE @default_flag1  VARCHAR(5)                      
   DECLARE @pd_segment2  VARCHAR(250)                      
   DECLARE @default_flag2  VARCHAR(5)                      
   DECLARE @PKID  INT                      
   DECLARE @AOC  VARCHAR(3)                      
   DECLARE @MAX_PKID  INT                      
   DECLARE @MIN_PKID  INT                      
   DECLARE @QG   INT                      
   DECLARE @PREV_QG  INT                      
   DECLARE @NEXT_QG INT                      
   DECLARE @jml int                      
   DECLARE @rn int                      
   DECLARE @pd_segment_pkid INT                      
   DECLARE @column_name  VARCHAR(250)                      
   DECLARE @data_type  VARCHAR(250)                      
   DECLARE @operator  VARCHAR(50)                      
   DECLARE @value1 VARCHAR(250)                      
   DECLARE @value2 VARCHAR(250)                      
   DECLARE @Default_Flag  VARCHAR(5)                      
   DECLARE @INCREMENTS INT                      
   DECLARE @statement NVARCHAR(200)                      
   DECLARE @HISTORICAL_DATA VARCHAR(30)                      
   DECLARE @TABLE_NAME VARCHAR(30)                      
   DECLARE @UPDATED_TABLE VARCHAR(30)                      
   DECLARE @UPDATED_COLUMN VARCHAR(30)                   
                      
  IF (@DOWNLOAD_DATE IS NULL)          
  BEGIN          
 SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE          
  END          
  ELSE          
  BEGIN          
 SET @V_CURRDATE = @DOWNLOAD_DATE          
  END                       
                      
   SET @V_SC_SCRIPT = ' ';                      
   SET @V_STR_SQL = ' ';                                  
              
 SELECT * INTO #DEFAULT FROM IFRS_DEFAULT WHERE 1 = 2              
 CREATE TABLE #TMPRULE ( DEFAULT_RULE_ID BIGINT)                            
                                       
 INSERT INTO #TMPRULE (DEFAULT_RULE_ID)              
 SELECT DISTINCT B.PKID FROM  IFRS_SCENARIO_RULES_HEADER B                                
 WHERE B.RULE_TYPE = 'DEFAULT_RULE_ECL'                   
                   
 DELETE [IFRS_SCENARIO_GENERATE_QUERY]                   
 WHERE RULE_TYPE = 'DEFAULT_RULE_ECL'                  
              
 DECLARE seg1                       
 CURSOR FOR                     
 SELECT             
 DISTINCT CASE UPDATED_TABLE WHEN 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_IMP_CURR' ELSE UPDATED_TABLE END AS UPDATED_TABLE,             
 UPDATED_COLUMN,            
 rule_type,             
 CASE TABLE_NAME WHEN 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_IMP_CURR' ELSE TABLE_NAME END AS TABLE_NAME,             
 a.RULE_NAME,A.PKID                  
 FROM IFRS_SCENARIO_RULES_HEADER a                      
 INNER JOIN IFRS_SCENARIO_RULES_DETAIL b ON a.PKID = b.RULE_ID                   
 INNER JOIN #TMPRULE C ON A.PKID = C.DEFAULT_RULE_ID              
 WHERE A.IS_DELETE = 0 AND B.IS_DELETE = 0                      
                      
   OPEN seg1;                               
   FETCH seg1 INTO @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,@TABLE_NAME, @RULE_CODE1, @RULE_ID                  
   WHILE @@FETCH_STATUS=0                      
   BEGIN                      
  SET @v_Script1 = ' ';                      
  SET @V_STR_SQL = ' ';                             
                      
  DECLARE seg_rule CURSOR FOR                       
SELECT                       
   'A.' + column_name,                                    
   data_type,                      
   operator,                      
   value1,                      
 value2,                      
   QUERY_GROUPING,                      
   AND_OR_CONDITION,                      
   LAG (QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) PREV_QG,                      
   LEAD (QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) NEXT_QG,                       
   jml,                      
   rn,                      
   PKID                  
  FROM                     
  (                    
   SELECT                     
    MIN (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG,                         
    MAX (QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG,                               
    ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) rn,                      
    cOUNT (0) OVER (PARTITION BY RULE_ID) jml,                    
    column_name,                            
    data_type,                      
    operator,                      
    value1,                      
    value2,                      
    QUERY_GROUPING,                                    
    RULE_ID,                      
    AND_OR_CONDITION,                                  
    PKID,  
    SEQUENCE                      
   FROM IFRS_SCENARIO_RULES_DETAIL                    
   WHERE RULE_ID = @RULE_ID    
   AND IS_DELETE = 0                 
  ) A;                      
                           
    OPEN seg_rule;                      
    FETCH seg_rule INTO  @column_name, @data_type, @operator, @value1, @value2, @QG, @AOC, @PREV_QG, @NEXT_QG, @jml, @rn, @PKID                    
    WHILE @@FETCH_STATUS = 0                      
    BEGIN                      
  SET @v_Script1 =                      
   ISNULL(@v_Script1, ' ') + ' ' + @AOC + ' ' + CASE WHEN  @QG <> @PREV_QG   THEN '(' ELSE ' ' END     + ISNULL(CASE                      
   WHEN RTRIM(LTRIM (@data_type)) IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'FLOAT', 'INT')                    
   THEN                      
    CASE                      
    WHEN @operator in ('=','<>','>','<','>=','<=')                      
    THEN                      
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@operator, '')                      
     + ' '                      
     + isnull(@value1, '')                      
    WHEN LOWER (@OPERATOR) = 'between'                      
    THEN                      
     isnull(@column_name, '')                      
     + ' '                  
     + ISNULL(@OPERATOR, '')                      
     + ' '                      
     + isnull(@value1, '')                      
     + ' and '                      
                    + isnull(@value2, '')                                      
    WHEN LOWER (@OPERATOR) = 'in'                      
                THEN                 
     isnull(@column_name, '')                      
     + ' '               
     + ISNULL(@OPERATOR, '')                      
     + ' '                      
     + '('                      
     + isnull(@value1, '')                      
     + ')'                      
    ELSE                      
     'xxx'                      
    END                      
   WHEN RTRIM(LTRIM (@data_type)) in ('DATE','DATETIME')                    
   THEN                      
    CASE                      
    WHEN @OPERATOR in ('=','<>','>','<','>=','<=')                      
    THEN                      
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@OPERATOR, '')                      
     + '  to_date('''                          
     + isnull(@value1, '')                      
     + ''',''MM/DD/YYYY'')'                      
    WHEN LOWER (@OPERATOR) = 'between'              
    THEN                      
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@OPERATOR, '')                
     + ' '                      
     + '   CONVERT(DATE,'''                      
     + isnull(@value1, '')                      
     + ''',110)'                      
     + ' and '                      
     + '  CONVERT(DATE,'''                      
     + isnull(@value2, '')                      
     + ''',110)'                      
    WHEN LOWER (@OPERATOR) in ('=','<>','>','<','>=','<=')                
    THEN                                     
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@OPERATOR, '')                      
     + ' '                                  
     + '('                      
     + '  to_date('''                                      
     + isnull(@value1, '')                      
     + ''',''MM/DD/YYYY'')'                      
     + ')'                      
    ELSE                         
     'xXx'                      
    END                      
   WHEN UPPER(RTRIM(LTRIM (@data_type))) IN ('CHAR','CHARACTER', 'VARCHAR', 'VARCHAR2','BIT')                     
   THEN                    
    CASE                      
    WHEN RTRIM(LTRIM (@OPERATOR)) = '='                      
    THEN                      
     isnull(@column_name, ' ')                      
     + ' '                      
     + ISNULL(@OPERATOR, ' ')                      
     + ''''                      
     + isnull(@value1, ' ')                
     + ''''                      
    WHEN RTRIM(LTRIM (LOWER (@OPERATOR))) = 'between'                      
                   THEN                       
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@OPERATOR, '')                      
     + '  '                      
                       + isnull(@value1, '')                      
     + ' and '                      
     + isnull(@value2, '')                      
    WHEN RTRIM(LTRIM (LOWER (@OPERATOR))) = 'in'                
    THEN                      
     isnull(@column_name, '')                      
     + ' '                      
     + ISNULL(@OPERATOR, '')                      
     + '  '                      
     + '('''                      
     + ISNULL(REPLACE (@value1, ',', ''','''), '')                                  
     + ''')'                                    
    ELSE                      
     'XXX'                      
    END                      
   ELSE                     
    'XxX'                      
   END , ' ')  + CASE WHEN  @QG <> @NEXT_QG   OR @rn = @jml THEN ')' ELSE ' ' END;                      
                      
   FETCH NEXT FROM seg_rule INTO    @column_name,@data_type,@operator,@value1, @value2, @QG,@AOC, @PREV_QG,@NEXT_QG,@jml,@rn,@PKID                               
  END;                      
              
  Set  @v_Script1 = '(' + ltrim(SUBSTRING (@v_Script1, 6, LEN (@v_Script1) ))                                            
                                     
  SET @V_STR_SQL = @V_STR_SQL + 'SELECT DOWNLOAD_DATE, ' + @RULE_ID + ', MASTERID, ACCOUNT_NUMBER ,CUSTOMER_NUMBER, OUTSTANDING, OUTSTANDING * EXCHANGE_RATE,                    
  PLAFOND, PLAFOND * EXCHANGE_RATE, ISNULL( EIR, INTEREST_RATE) , GETDATE()  '              
  SET @V_STR_SQL = @V_STR_SQL + 'FROM ' + @UPDATED_TABLE + ' A WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10),@V_CURRDATE,112) + ''' '                      
  SET @V_STR_SQL = @V_STR_SQL + 'AND (' + @v_Script1 + ' )'                                      
                                      
  INSERT INTO #DEFAULT               
  (                    
   DOWNLOAD_DATE, RULE_ID, MASTERID, ACCOUNT_NUMBER, CUSTOMER_NUMBER, OS_AT_DEFAULT, EQV_AT_DEFAULT, PLAFOND_AT_DEFAULT, EQV_PLAFOND_AT_DEFAULT ,EIR_AT_DEFAULT, CREATED_DATE                    
  )                 
  EXEC (@V_STR_SQL)               
              
  CLOSE seg_rule;                 
  DEALLOCATE seg_rule;                           
                   
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
   ,@v_Script1 AS PD_RULES_QRY_RESULT                    
   ,'SP_DEFAULT_RULE_ECL' AS CREATEDBY                    
   ,GETDATE () AS CREATEDDATE                    
                     
  FETCH NEXT FROM seg1 INTO @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,@TABLE_NAME, @RULE_CODE1, @RULE_ID --,@HISTORICAL_DATA,@Default_Flag                      
                      
 END;                      
 CLOSE seg1;                      
 DEALLOCATE seg1;                 
                
 UPDATE A SET DEFAULT_FLAG = CASE WHEN ISNULL(B.MASTERID,'') = ''  THEN 0 ELSE 1 END                
 FROM TMP_IFRS_ECL_IMA A               
 LEFT JOIN #DEFAULT B                
 ON A.DEFAULT_RULE_ID = B.RULE_ID AND A.MASTERID = B.MASTERID AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE                
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE          
           
 UPDATE X          
 SET BUCKET_ID = CASE WHEN DEFAULT_FLAG = 1 THEN Y.BUCKET_ID ELSE X.BUCKET_ID END          
 FROM TMP_IFRS_ECL_IMA X          
 JOIN          
 (          
  SELECT A.BUCKET_GROUP, MAX(BUCKET_ID) AS BUCKET_ID           
  FROM IFRS_BUCKET_HEADER A JOIN IFRS_BUCKET_DETAIL B ON A.BUCKET_GROUP = B.BUCKET_GROUP           
  GROUP BY A.BUCKET_GROUP          
 ) Y ON X.BUCKET_GROUP = Y.BUCKET_GROUP           
 WHERE X.DOWNLOAD_DATE = @V_CURRDATE               
              
END
GO
