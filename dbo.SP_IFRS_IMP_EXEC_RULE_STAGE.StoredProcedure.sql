USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_EXEC_RULE_STAGE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_EXEC_RULE_STAGE]             
@DOWNLOAD_DATE DATE = NULL,             
@MODEL_ID BIGINT = 0          
AS          
BEGIN          
 DECLARE @V_CURRDATE DATE          
 DECLARE @V_PREVDATE DATE          
 DECLARE @V_STR_SQL VARCHAR(MAX)          
 DECLARE @V_SCRIPT1 VARCHAR(MAX)          
 DECLARE @V_SCRIPT2 VARCHAR(MAX)          
 DECLARE @RULE_CODE1 BIGINT          
 DECLARE @VALUE VARCHAR(250)          
 DECLARE @RULE_TYPE VARCHAR(50)          
 DECLARE @PKID INT          
 DECLARE @AOC VARCHAR(3)          
 DECLARE @MAX_PKID INT          
 DECLARE @MIN_PKID INT          
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
 /* ADD SEGMENTATION_ID */          
 DECLARE @SEGMENTATION_ID VARCHAR(5)                             
          
 SET NOCOUNT ON;          
                 
 IF (@DOWNLOAD_DATE IS NULL)                
 BEGIN                
 SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE                
 END                
 ELSE                
 BEGIN                
 SET @V_CURRDATE = @DOWNLOAD_DATE          
 END                            
          
 DROP TABLE IF EXISTS #TMP_ECL_SICR_RUN          
                            
  SELECT DISTINCT B.SICR_RULE_ID, B.SEGMENTATION_ID          
  INTO #TMP_ECL_SICR_RUN          
  FROM IFRS_ECL_MODEL_HEADER A          
  JOIN IFRS_ECL_MODEL_DETAIL_PF B ON A.PKID = B.ECL_MODEL_ID          
  WHERE A.IS_DELETE = 0          
   AND B.IS_DELETE = 0          
   AND (A.PKID = @MODEL_ID OR (@MODEL_ID = 0 AND A.ACTIVE_STATUS = 1))          
          
 SET @V_STR_SQL = ' ';          
          
 DECLARE SEG1 CURSOR          
 FOR          
 SELECT DISTINCT                       
  CASE UPDATED_TABLE WHEN 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_IMP_CURR' ELSE UPDATED_TABLE END AS UPDATED_TABLE                             
  ,UPDATED_COLUMN          
  ,RULE_TYPE          
  ,CASE TABLE_NAME WHEN 'IFRS_MASTER_ACCOUNT' THEN 'IFRS_IMA_IMP_CURR' ELSE TABLE_NAME END AS TABLE_NAME                      
  ,A.PKID           
  ,B.DETAIL_TYPE                             
  ,C.SEGMENTATION_ID          
 FROM IFRS_SCENARIO_RULES_HEADER A          
 INNER JOIN IFRS_SCENARIO_RULES_DETAIL B ON A.PKID = B.RULE_ID          
 INNER JOIN #TMP_ECL_SICR_RUN C ON A.PKID = C.SICR_RULE_ID          
 WHERE A.RULE_TYPE = 'STAGE' AND B.DETAIL_TYPE <> 'SICR'          
 ORDER BY A.PKID, B.DETAIL_TYPE DESC          
          
 OPEN SEG1;          
          
 FETCH SEG1          
 INTO @UPDATED_TABLE          
  ,@UPDATED_COLUMN          
  ,@RULE_TYPE          
  ,@TABLE_NAME          
  ,@RULE_CODE1          
  ,@VALUE          
  ,@SEGMENTATION_ID          
          
 WHILE @@FETCH_STATUS = 0          
 BEGIN          
  SET @V_SCRIPT1 = ' ';          
  SET @V_STR_SQL = ' ';          
  SET @V_SCRIPT2 = ' ';          
          
  DECLARE SEG_RULE CURSOR          
  FOR          
  SELECT 'A.' + COLUMN_NAME          
   ,DATA_TYPE          
   ,OPERATOR          
   ,VALUE1          
   ,VALUE2          
   ,QUERY_GROUPING          
   ,AND_OR_CONDITION          
   ,LAG(QUERY_GROUPING, 1, MIN_QG) OVER (          
    PARTITION BY RULE_ID ORDER BY QUERY_GROUPING                      
     ,PKID          
    ) PREV_QG          
   ,LEAD(QUERY_GROUPING, 1, MAX_QG) OVER (          
    PARTITION BY RULE_ID ORDER BY QUERY_GROUPING          
     ,PKID          
    ) NEXT_QG          
   ,JML          
   ,RN          
   ,PKID          
  FROM (          
   SELECT MIN(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MIN_QG          
    ,MAX(QUERY_GROUPING) OVER (PARTITION BY RULE_ID) MAX_QG          
    ,ROW_NUMBER() OVER (PARTITION BY RULE_ID ORDER BY QUERY_GROUPING, SEQUENCE) RN          
    ,COUNT(0) OVER (PARTITION BY RULE_ID) JML          
    ,COLUMN_NAME          
    ,DATA_TYPE          
    ,OPERATOR          
    ,VALUE1                             
    ,VALUE2          
    ,QUERY_GROUPING          
    ,RULE_ID                            
    ,AND_OR_CONDITION          
    ,PKID            
   FROM IFRS_SCENARIO_RULES_DETAIL          
   WHERE RULE_ID = @RULE_CODE1          
    AND DETAIL_TYPE = @VALUE                           
   ) A;          
        
  OPEN SEG_RULE;          
          
  FETCH SEG_RULE          
  INTO @COLUMN_NAME          
   ,@DATA_TYPE          
   ,@OPERATOR          
   ,@VALUE1          
   ,@VALUE2          
   ,@QG          
   ,@AOC          
   ,@PREV_QG          
   ,@NEXT_QG                          
   ,@JML          
   ,@RN          
   ,@PKID          
          
  WHILE @@FETCH_STATUS = 0          
  BEGIN          
   SET @V_SCRIPT1 = ISNULL(@V_SCRIPT1, ' ') + ' ' + @AOC + ' ' + CASE           
     WHEN @QG <> @PREV_QG          
      THEN '('          
     ELSE ' '          
     END + ISNULL(CASE           
      WHEN RTRIM(LTRIM(@DATA_TYPE)) IN (          
        'NUMBER'          
        ,'DECIMAL'          
        ,'NUMERIC'          
  ,'FLOAT'          
        ,'INT'          
        )          
       THEN CASE           
         WHEN @OPERATOR IN (          
           '='          
           ,'<>'          
           ,'>'          
           ,'<'          
       ,'>='          
           ,'<='          
           )          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + ' ' + ISNULL(@VALUE1, '')          
         WHEN UPPER(@OPERATOR) = 'BETWEEN'          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + ' ' + ISNULL(@VALUE1, '') + ' AND ' + ISNULL(@VALUE2, '')          
         WHEN UPPER(@OPERATOR) IN (          
           'IN'          
           ,'NOT IN'          
           )          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + ' ' + '(' + ISNULL(@VALUE1, '') + ')'          
         ELSE 'XXX'          
         END          
      WHEN RTRIM(LTRIM(@DATA_TYPE)) = 'DATE'          
       THEN CASE           
         WHEN @OPERATOR IN (          
           '='          
           ,'<>'          
           ,'>'          
           ,'<'          
           ,'>='          
           ,'<='          
           )          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + '  TO_DATE(''' + ISNULL(@VALUE1, '') + ''',''MM/DD/YYYY'')'              
         WHEN UPPER(@OPERATOR) = 'BETWEEN'          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + ' ' + '   CONVERT(DATE,''' + ISNULL(@VALUE1, '') + ''',110)' + ' AND ' + '  CONVERT(DATE,''' + ISNULL(@VALUE2, '') + ''',110)'          
         WHEN UPPER(@OPERATOR) IN (          
           '='                            
           ,'<>'          
           ,'>'          
           ,'<'          
           ,'>='          
           ,'<='          
           )          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + ' ' + '(' + '  TO_DATE(''' + ISNULL(@VALUE1, '') + ''',''MM/DD/YYYY'')' + ')'          
         ELSE 'XXX'          
         END          
      WHEN UPPER(RTRIM(LTRIM(@DATA_TYPE))) IN (          
        'CHAR'          
        ,'CHARACTER'          
        ,'VARCHAR'          
        ,'VARCHAR2'          
        ,'BIT'          
        )          
       THEN CASE           
         WHEN RTRIM(LTRIM(@OPERATOR)) = '='          
  THEN ISNULL(@COLUMN_NAME, ' ') + ' ' + ISNULL(@OPERATOR, ' ') + '''' + ISNULL(@VALUE1, ' ') + ''''          
         WHEN RTRIM(LTRIM(UPPER(@OPERATOR))) = 'BETWEEN'          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + '  ' + ISNULL(@VALUE1, '') + ' AND ' + ISNULL(@VALUE2, '')          
         WHEN RTRIM(LTRIM(UPPER(@OPERATOR))) IN (          
           'IN'          
           ,'NOT IN'          
           )          
          THEN ISNULL(@COLUMN_NAME, '') + ' ' + ISNULL(@OPERATOR, '') + '  ' + '(''' + ISNULL(REPLACE(@VALUE1, ',', ''','''), '') + ''')'          
         ELSE 'XXX'          
         END          
      ELSE 'XXX'          
      END, ' ') + CASE           
     WHEN @QG <> @NEXT_QG          
      OR @RN = @JML          
      THEN ')'          
     ELSE ' '          
     END;          
          
   FETCH NEXT          
   FROM SEG_RULE          
   INTO @COLUMN_NAME          
    ,@DATA_TYPE                  
    ,@OPERATOR          
    ,@VALUE1          
    ,@VALUE2          
    ,@QG          
    ,@AOC          
    ,@PREV_QG          
    ,@NEXT_QG          
    ,@JML          
    ,@RN          
    ,@PKID          
  END;          
          
  SET @V_SCRIPT1 = '(' + LTRIM(SUBSTRING(@V_SCRIPT1, 6, LEN(@V_SCRIPT1)))          
          
  --SICR CONDITION ADD BY YY 20190209             
  SELECT @V_SCRIPT2 = DBO.[F_GET_RULES_SICR](@RULE_CODE1, @VALUE)          
          
  SET @V_SCRIPT2 = 'CASE ' + @V_SCRIPT2          
  SET @V_SCRIPT2 = @V_SCRIPT2 + ' WHEN ''' + LTRIM(RTRIM(CAST(@VALUE AS VARCHAR))) + ''' = ''' + LTRIM(RTRIM(CAST(@VALUE AS VARCHAR))) + ''''          
  SET @V_SCRIPT2 = @V_SCRIPT2 + ' THEN ''' + LTRIM(RTRIM(CAST(@VALUE AS VARCHAR))) + ''''          
  SET @V_SCRIPT2 = @V_SCRIPT2 + ' END'          
  --SICR CONDITION              
  SET @V_STR_SQL = @V_STR_SQL + 'UPDATE A SET ' + @UPDATED_COLUMN + ' = ' + @V_SCRIPT2          
  SET @V_STR_SQL = @V_STR_SQL + ',          
   A.SICR_RULE_ID = ''' + LTRIM(RTRIM(CAST(@RULE_CODE1 AS VARCHAR))) + ''',          
   A.SICR_FLAG = CASE WHEN ''' + LTRIM(RTRIM(CAST(@VALUE AS VARCHAR))) + ''' = ' + @V_SCRIPT2 + ' THEN 0 ELSE 1 END'          
  SET @V_STR_SQL = @V_STR_SQL + ' FROM TMP_IFRS_ECL_IMA A WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(10), @V_CURRDATE, 112) + ''' '          
  SET @V_STR_SQL = @V_STR_SQL + ' AND (' + @V_SCRIPT1 + ')' + ' AND A.SEGMENTATION_ID = ' + @SEGMENTATION_ID + ''          
  -- print ( @V_STR_SQL )            
  EXEC (@V_STR_SQL)                             
                            
  CLOSE SEG_RULE;          
                            
  DEALLOCATE SEG_RULE;          
          
  FETCH NEXT          
  FROM SEG1          
  INTO @UPDATED_TABLE          
 ,@UPDATED_COLUMN          
 ,@RULE_TYPE          
 ,@TABLE_NAME          
 ,@RULE_CODE1          
 ,@VALUE          
 ,@SEGMENTATION_ID          
 END;          
          
 CLOSE SEG1;          
          
 DEALLOCATE SEG1;          
  /*END SET RULES*/  
  
  EXEC SP_IFRS_IMP_OVERRIDE_RESTRU_COVID @V_CURRDATE  
        
END 
GO
