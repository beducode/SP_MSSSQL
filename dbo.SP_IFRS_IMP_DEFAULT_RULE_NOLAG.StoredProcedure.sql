USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_DEFAULT_RULE_NOLAG]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE  PROCEDURE [dbo].[SP_IFRS_IMP_DEFAULT_RULE_NOLAG]      
@DOWNLOAD_DATE date = NULL,        
@MODEL_TYPE varchar(4) = '',        
@MODEL_ID bigint = 0        
AS        
BEGIN        
 DECLARE @V_CURRDATE date        
 DECLARE @V_PREVDATE date        
 DECLARE @V_STR_SQL varchar(max)        
 DECLARE @V_STR_SQL_RULE varchar(max)        
 DECLARE @v_Script1 varchar(max)        
 DECLARE @v_Script2 varchar(max)        
 DECLARE @V_SC_SCRIPT varchar(max)        
 DECLARE @RULE_ID varchar(100)        
 DECLARE @RULE_CODE1 varchar(250)        
 DECLARE @RULE_TYPE varchar(25)        
 DECLARE @default_flag1 varchar(5)        
 DECLARE @pd_segment2 varchar(250)        
 DECLARE @default_flag2 varchar(5)        
 DECLARE @PKID int        
 DECLARE @AOC varchar(3)        
 DECLARE @MAX_PKID int        
 DECLARE @MIN_PKID int        
 DECLARE @QG int        
 DECLARE @PREV_QG int        
 DECLARE @NEXT_QG int        
 DECLARE @jml int        
 DECLARE @rn int        
 DECLARE @pd_segment_pkid int        
 DECLARE @column_name varchar(250)        
 DECLARE @data_type varchar(250)        
 DECLARE @operator varchar(50)        
 DECLARE @value1 varchar(250)        
 DECLARE @value2 varchar(250)        
 DECLARE @Default_Flag varchar(5)        
 DECLARE @INCREMENTS int        
 DECLARE @statement nvarchar(200)        
 DECLARE @HISTORICAL_DATA varchar(30)        
 DECLARE @TABLE_NAME varchar(30)        
 DECLARE @UPDATED_TABLE varchar(30)        
 DECLARE @UPDATED_COLUMN varchar(30)        
        
 IF (@DOWNLOAD_DATE IS NULL)        
 BEGIN        
  SELECT        
   @V_CURRDATE = EOMONTH(CURRDATE)      
  FROM IFRS_PRC_DATE -- FOR NO LAG                                                                   
 END        
 ELSE        
 BEGIN        
  SELECT        
   @V_CURRDATE = EOMONTH(@DOWNLOAD_DATE)-- FOR NO LAG                                      
 END        
        
 SET @V_SC_SCRIPT = ' ';        
 SET @V_STR_SQL = ' ';        
 -- SET @statement = 'Truncate table IFRS_RULE_GENERATE_QUERY'                    
 -- EXECUTE sp_executesql @statement                    
        
 CREATE TABLE #TMPRULE (        
  DEFAULT_RULE_ID bigint        
 )        
        
 INSERT INTO #TMPRULE (DEFAULT_RULE_ID)        
  SELECT DISTINCT        
   B.PKID        
  FROM IFRS_SCENARIO_RULES_HEADER B        
  WHERE B.RULE_TYPE = 'DEFAULT_RULE_NOLAG' AND IS_DELETE = 0       
        
 DELETE [IFRS_SCENARIO_GENERATE_QUERY]        
 WHERE RULE_TYPE = 'DEFAULT_RULE_NOLAG'        
END        
        
 DELETE A        
  FROM IFRS_DEFAULT_NOLAG A        
  INNER JOIN #TMPRULE B        
   ON A.RULE_ID = B.DEFAULT_RULE_ID        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE;        
        
 DECLARE seg1 CURSOR FOR        
 SELECT DISTINCT        
  UPDATED_TABLE,        
  UPDATED_COLUMN,        
  rule_type,        
  TABLE_NAME,        
  a.RULE_NAME,        
  A.PKID        
 FROM IFRS_SCENARIO_RULES_HEADER a        
 INNER JOIN IFRS_SCENARIO_RULES_DETAIL b        
  ON a.PKID = b.RULE_ID        
 INNER JOIN #TMPRULE C        
  ON A.PKID = C.DEFAULT_RULE_ID        
 WHERE A.IS_DELETE = 0        
 AND B.IS_DELETE = 0        
        
 OPEN seg1;        
 FETCH seg1 INTO @UPDATED_TABLE, @UPDATED_COLUMN, @RULE_TYPE, @TABLE_NAME, @RULE_CODE1, @RULE_ID        
 WHILE @@FETCH_STATUS = 0        
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
   LAG(QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) PREV_QG,        
   LEAD(QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) NEXT_QG,        
   jml,        
   rn,        
   PKID        
  FROM (SELECT        
   MIN(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG,        
   MAX(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG,        
   ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, sequence) rn,        
   COUNT(0) OVER (PARTITION BY RULE_ID) jml,        
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
  WHERE RULE_ID = @RULE_ID and IS_DELETE = 0) A;        
        
  OPEN seg_rule;        
  FETCH seg_rule INTO @column_name, @data_type, @operator, @value1, @value2, @QG, @AOC, @PREV_QG, @NEXT_QG, @jml, @rn, @PKID        
  WHILE @@FETCH_STATUS = 0        
  BEGIN        
   SET @v_Script1 =        
   ISNULL(@v_Script1, ' ') + ' ' + @AOC + ' ' + CASE        
    WHEN @QG <> @PREV_QG THEN '('        
    ELSE ' '        
   END + ISNULL(CASE        
    WHEN RTRIM(LTRIM(@data_type)) IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'FLOAT', 'INT') THEN CASE        
      WHEN @operator IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@operator, '')        
       + ' '        
       + ISNULL(@value1, '')        
      WHEN LOWER(@OPERATOR) = 'between' THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + ' '        
       + ISNULL(@value1, '')        
       + ' and '        
       + ISNULL(@value2, '')        
      WHEN LOWER(@OPERATOR) = 'in' THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + ' '        
       + '('        
       + ISNULL(@value1, '')        
       + ')'        
      ELSE 'xxx'        
     END        
    WHEN RTRIM(LTRIM(@data_type)) IN ('DATE', 'DATETIME') THEN CASE        
      WHEN @OPERATOR IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + '  to_date('''        
       + ISNULL(@value1, '')        
       + ''',''MM/DD/YYYY'')'        
      WHEN LOWER(@OPERATOR) = 'between' THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + ' '        
       + '   CONVERT(DATE,'''        
       + ISNULL(@value1, '')        
       + ''',110)'        
       + ' and '        
       + '  CONVERT(DATE,'''        
       + ISNULL(@value2, '')        
       + ''',110)'        
      WHEN LOWER(@OPERATOR) IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + ' '        
       + '('        
       + '  to_date('''        
       + ISNULL(@value1, '')        
       + ''',''MM/DD/YYYY'')'        
       + ')'        
      ELSE 'xXx'        
     END        
    WHEN UPPER(RTRIM(LTRIM(@data_type))) IN ('CHAR', 'CHARACTER', 'VARCHAR', 'VARCHAR2', 'BIT') THEN CASE        
      WHEN RTRIM(LTRIM(@OPERATOR)) = '=' THEN ISNULL(@column_name, ' ')        
       + ' '        
       + ISNULL(@OPERATOR, ' ')        
       + ''''        
       + ISNULL(@value1, ' ')        
       + ''''        
      WHEN RTRIM(LTRIM(LOWER(@OPERATOR))) = 'between' THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + '  '        
       + ISNULL(@value1, '')        
       + ' and '        
       + ISNULL(@value2, '')        
      WHEN RTRIM(LTRIM(LOWER(@OPERATOR))) = 'in' THEN ISNULL(@column_name, '')        
       + ' '        
       + ISNULL(@OPERATOR, '')        
       + '  '        
       + '('''        
       + ISNULL(REPLACE(@value1, ',', ''','''), '')        
       + ''')'        
      ELSE 'XXX'        
     END        
    ELSE 'XxX'        
   END, ' ') + CASE        
    WHEN @QG <> @NEXT_QG OR        
     @rn = @jml THEN ')'        
    ELSE ' '        
   END;        
        
        
   FETCH NEXT FROM seg_rule INTO @column_name, @data_type, @operator, @value1, @value2, @QG, @AOC, @PREV_QG, @NEXT_QG, @jml, @rn, @PKID        
        
        
  END;        
        
  SET @v_Script1 = '(' + LTRIM(SUBSTRING(@v_Script1, 6, LEN(@v_Script1)))        
        
        
  --PRINT @v_Script1                                                                          
        
  SET @V_STR_SQL = @V_STR_SQL + 'SELECT DOWNLOAD_DATE, ' + @RULE_ID + ', MASTERID, ACCOUNT_NUMBER ,CUSTOMER_NUMBER, OUTSTANDING, OUTSTANDING * EXCHANGE_RATE,                                                            
 PLAFOND, PLAFOND * EXCHANGE_RATE,                                                            
 ISNULL( EIR, INTEREST_RATE) , GETDATE(), FACILITY_NUMBER  '        
  SET @V_STR_SQL = @V_STR_SQL + 'FROM ' + @UPDATED_TABLE + ' A WHERE A.DOWNLOAD_DATE = ''' + CONVERT(varchar(10), @V_CURRDATE, 112) + ''' '        
  SET @V_STR_SQL = @V_STR_SQL + 'AND (' + @v_Script1 + ' )'        
        
  -- PRINT @V_STR_SQL                                    
        
  INSERT INTO IFRS_DEFAULT_NOLAG (DOWNLOAD_DATE, RULE_ID, MASTERID, ACCOUNT_NUMBER, CUSTOMER_NUMBER, OS_AT_DEFAULT, EQV_AT_DEFAULT,        
  PLAFOND_AT_DEFAULT, EQV_PLAFOND_AT_DEFAULT, EIR_AT_DEFAULT, CREATED_DATE,FACILITY_NUMBER)        
  EXEC (@V_STR_SQL)        
  --INSERT INTO IFRS_RULE_GENERATE_QUERY (UPDATED_TABLE, UPDATED_COLUMN,RULE_TYPE,RULE_CODE,HISTORICAL_DATA,TABLE_NAME, PD_RULES_QRY_RESULT,DEFAULT_FLAG )                                                                
  --VALUES ( @UPDATED_TABLE, @UPDATED_COLUMN,@RULE_TYPE,(@RULE_CODE1), @HISTORICAL_DATA,@TABLE_NAME ,  @v_Script1,@Default_Flag);                    
        
  CLOSE seg_rule;        
  DEALLOCATE seg_rule;        
        
  INSERT INTO [IFRS_SCENARIO_GENERATE_QUERY] (RULE_ID        
  , RULE_NAME        
  , RULE_TYPE        
  , TABLE_NAME        
  , PD_RULES_QRY_RESULT        
  , CREATEDBY        
  , CREATEDDATE)        
   SELECT        
    @RULE_ID,        
    @RULE_CODE1,        
    @RULE_TYPE,        
    @TABLE_NAME,        
    @v_Script1 AS PD_RULES_QRY_RESULT,        
    'SP_IFRS_DEFAULT_RULE' AS CREATEDBY,        
    GETDATE() AS CREATEDDATE        
        
  FETCH NEXT FROM seg1 INTO @UPDATED_TABLE, @UPDATED_COLUMN, @RULE_TYPE, @TABLE_NAME, @RULE_CODE1, @RULE_ID        
        
 END;        
 CLOSE seg1;        
 DEALLOCATE seg1;  

GO
