USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_GENERATE_RULE_SEGMENT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_GENERATE_RULE_SEGMENT]          
AS          
 DECLARE @Script1 nvarchar(max)          
 DECLARE @PKID int          
 DECLARE @AOC varchar(3)          
 DECLARE @QG int          
 DECLARE @PREV_QG int          
 DECLARE @NEXT_QG int          
 DECLARE @jml int          
 DECLARE @rn int          
 DECLARE @RULE_ID int          
 DECLARE @column_name varchar(250)          
 DECLARE @data_type varchar(250)          
 DECLARE @operator varchar(50)          
 DECLARE @value1 varchar(250)          
 DECLARE @value2 varchar(250)         
 DECLARE @TABLE_NAME varchar(30)         
 DECLARE @GRP_SEGMENT varchar(50)          
 DECLARE @SEGMENT varchar(50)          
 DECLARE @SUB_SEGMENT varchar(50)          
 DECLARE @SEGMENT_TYPE varchar(50)          
 DECLARE @SEQ int        
        
 BEGIN          
  SET NOCOUNT ON;          
          
  DECLARE seg1 CURSOR LOCAL FOR          
          
  SELECT DISTINCT          
   SEGMENT_TYPE,          
   GROUP_SEGMENT,          
   SEGMENT,          
   SUB_SEGMENT,          
   RULE_ID,          
   TABLE_NAME,          
   SEQUENCE          
  FROM (SELECT DISTINCT          
   A.SEGMENT_TYPE,          
   A.GROUP_SEGMENT,          
   A.SEGMENT,    
   A.SUB_SEGMENT,          
   B.RULE_ID,          
   B.TABLE_NAME,          
   A.SEQUENCE          
  FROM IFRS_MSTR_SEGMENT_RULES_HEADER a    
  INNER JOIN IFRS_MSTR_SEGMENT_RULES_DETAIL b          
   ON a.pkid = b.rule_id    
  WHERE ISNULL(A.IS_DELETE, 0) = 0) SGT          
  ORDER BY RULE_ID;
          
  SET @Script1 = 'TRUNCATE TABLE IFRS_SCENARIO_SEGMENT_GENERATE_QUERY'          
  EXEC (@Script1)          
          
  OPEN seg1;          
  FETCH NEXT FROM seg1 INTO @SEGMENT_TYPE, @GRP_SEGMENT, @SEGMENT, @SUB_SEGMENT, @RULE_ID, @TABLE_NAME, @SEQ;          
  WHILE @@FETCH_STATUS = 0          
  BEGIN          
          
   SET @Script1 = ' ';          
          
   DECLARE seg_rule CURSOR FOR          
   SELECT          
    'A."' + ISNULL(column_name, '') + '"' v_column_name,          
    data_type v_data_type,          
    operator v_operator,          
    value1 v_value1,          
    value2 v_value2,          
    QUERY_GROUPING v_QG,          
    AND_OR_CONDITION v_AOC,          
    LAG(QUERY_GROUPING, 1, MIN_QG) OVER (PARTITION BY rule_id ORDER BY QUERY_GROUPING, SEQUENCE) v_PREV_QG,          
    LEAD(QUERY_GROUPING, 1, MAX_QG) OVER (PARTITION BY rule_id ORDER BY QUERY_GROUPING, SEQUENCE) v_NEXT_QG,          
    jml v_jml,          
    rn v_rn,          
    PKID v_PKID          
   FROM (SELECT          
    MIN(QUERY_GROUPING) OVER (PARTITION BY rule_id) MIN_QG,          
    MAX(QUERY_GROUPING) OVER (PARTITION BY rule_id) MAX_QG,          
    ROW_NUMBER() OVER (PARTITION BY rule_id ORDER BY QUERY_GROUPING, sequence) rn,          
    COUNT(0) OVER (PARTITION BY rule_id) jml,          
    column_name,          
    data_type,          
    operator,          
    value1,          
    value2,          
    QUERY_GROUPING,          
    rule_id,          
    AND_OR_CONDITION,          
    PKID,      
    SEQUENCE          
   FROM IFRS_MSTR_SEGMENT_RULES_DETAIL          
   WHERE RULE_ID = @RULE_ID) A          
          
   OPEN seg_rule          
   FETCH NEXT FROM seg_rule INTO @column_name, @data_type, @operator, @value1, @value2, @QG, @AOC, @PREV_QG, @NEXT_QG, @jml, @rn, @PKID          
   WHILE @@FETCH_STATUS = 0          
          
   BEGIN          
          
    SET @Script1 =          
    ISNULL(ISNULL(@Script1, ' '), '') + ' ' + ISNULL(CASE          
     WHEN @QG > @PREV_QG THEN 'OR'          
     WHEN @QG = @PREV_QG THEN @AOC          
    END, '') + ' ' + ISNULL(CASE          
     WHEN @QG <> @PREV_QG THEN '('          
     ELSE ' '          
    END, '')          
    + ISNULL(ISNULL(CASE          
     WHEN RTRIM(LTRIM(@data_type)) IN ('NUMBER', 'DECIMAL', 'NUMERIC', 'FLOAT', 'INT') THEN CASE          
       WHEN @operator IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@value1, ''), '')          
       WHEN LOWER(@operator) = 'between' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
 + ISNULL(ISNULL(@operator, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@value1, ''), '')          
        + ' and '          
        + ISNULL(ISNULL(@value2, ''), '')          
       WHEN LOWER(@operator) = 'in' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + ' '          
        + '('          
        + ISNULL(ISNULL(@value1, ''), '')          
        + ')'          
       ELSE 'xxx'          
      END          
     WHEN RTRIM(LTRIM(@data_type)) IN ('DATE', 'DATETIME') THEN CASE          
       WHEN @operator IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + '  Convert(DATE,'''          
        + ISNULL(ISNULL(REPLACE(@value1, ' ', '/'), ''), '')          
        + ''',101)'          
       WHEN LOWER(@operator) = 'between' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + ' '          
        + '   CONVERT(DATE,'''          
        + ISNULL(ISNULL(REPLACE(@value1, ' ', '/'), ''), '')          
        + ''',101)'          
        + ' and '          
        + '  CONVERT(DATE,'''          
        + ISNULL(ISNULL(REPLACE(@value2, ' ', '/'), ''), '')          
        + ''',101)'          
       WHEN LOWER(@operator) IN ('=', '<>', '>', '<', '>=', '<=') THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + ' '          
        + '('          
        + '  CONVERT(DATE,'''          
        + ISNULL(ISNULL(@value1, ''), '')          
        + ''',101)'          
        + ')'          
       ELSE 'xXx'          
      END          
     WHEN UPPER(RTRIM(LTRIM(@data_type))) IN ('CHAR', 'CHARACTER', 'VARCHAR', 'VARCHAR2', 'BIT') THEN CASE          
       WHEN RTRIM(LTRIM(@operator)) = '=' THEN ISNULL(ISNULL(@column_name, ' '), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ' '), '')          
        + ''''          
        + ISNULL(ISNULL(@value1, ' '), '')          
        + ''''          
       WHEN RTRIM(LTRIM(LOWER(@operator))) = 'between' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + '  '          
        + ISNULL(ISNULL(@value1, ''), '')          
        + ' and '          
        + ISNULL(ISNULL(@value2, ''), '')          
       WHEN RTRIM(LTRIM(LOWER(@operator))) = 'in' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + '  '          
        + '('''          
        + ISNULL(ISNULL(REPLACE(@value1, ',', ''','''), ''), '')          
        + ''')'          
       WHEN RTRIM(LTRIM(LOWER(@operator))) = 'not in' THEN ISNULL(ISNULL(@column_name, ''), '')          
        + ' '          
        + ISNULL(ISNULL(@operator, ''), '')          
        + '  '          
        + '('''          
        + ISNULL(ISNULL(REPLACE(@value1, ',', ''','''), ''), '')          
        + ''')'          
       ELSE 'XXX'          
      END          
     ELSE 'XxX'          
    END, ' '), '') + ISNULL(CASE          
     WHEN @QG <> @NEXT_QG OR          
      @rn = @jml THEN ')'          
     ELSE ' '          
    END, '');          
          
    FETCH NEXT FROM seg_rule INTO @column_name, @data_type, @operator, @value1, @value2, @QG, @AOC, @PREV_QG, @NEXT_QG, @jml, @rn, @PKID          
          
   END;          
          
   SET @Script1 = '(' + ISNULL(LTRIM(SUBSTRING(@Script1, 6, LEN(RTRIM(@Script1)))), '');          
          
   SET @TABLE_NAME = 'IFRS_MASTER_ACCOUNT'        
          
   INSERT INTO IFRS_SCENARIO_SEGMENT_GENERATE_QUERY (RULE_ID, SEGMENT_TYPE, GROUP_SEGMENT, SUB_SEGMENT, SEGMENT, TABLE_NAME, CONDITION, SEQUENCE)          
    VALUES (@RULE_ID, @SEGMENT_TYPE, @GRP_SEGMENT, @SUB_SEGMENT, @SEGMENT, @TABLE_NAME, @Script1, @SEQ);          
          
   CLOSE seg_rule;          
   DEALLOCATE seg_rule;          
          
   FETCH NEXT FROM seg1 INTO @SEGMENT_TYPE, @GRP_SEGMENT, @SEGMENT, @SUB_SEGMENT, @RULE_ID, @TABLE_NAME, @SEQ;          
          
  END;          
          
  CLOSE seg1;          
  DEALLOCATE seg1;          
 END

GO
