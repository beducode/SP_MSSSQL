USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_RULE_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_RULE_DATA] (@RULE_TYPE VARCHAR(30), @RULE_NAME VARCHAR(50)='')      
AS          
BEGIN          
        
DECLARE          
  @V_CURRDATE  VARCHAR(10),--date,          
  @v_HISTORICAL_DATA VARCHAR(30),          
  @v_TABLE_NAME VARCHAR(30),          
  @V_STR_SQL VARCHAR(4000),          
  @V_STR_SQL_RULE VARCHAR(4000),          
  @V_RULE_ID VARCHAR(250),        
  @V_RULE_TYPE VARCHAR(50)          
           
 SELECT          
    @V_CURRDATE=CURRDATE           
  FROM IFRS_PRC_DATE;          
          
  TRUNCATE TABLE IFRS_SCENARIO_DATA;           
           
 declare            
  i SCROLL CURSOR FOR           
    SELECT          
    RULE_ID,      
 RULE_TYPE,          
    TABLE_NAME,          
    PD_RULES_QRY_RESULT          
  FROM DBO.IFRS_SCENARIO_GENERATE_QUERY          
  WHERE RULE_ID IN       
  (SELECT PKID FROM IFRS_SCENARIO_RULES_HEADER WHERE IS_DELETE = 0 and RULE_TYPE=@RULE_TYPE AND (RULE_NAME = @RULE_NAME OR @RULE_NAME =''))
            
  OPEN i          
  WHILE 1=1--ISNULL(@V_RULE_ID,'') <> ''          
  BEGIN          
          
  FETCH NEXT from i INTO @V_RULE_ID, @V_RULE_TYPE, @v_TABLE_NAME, @V_STR_SQL_RULE            
          
          
  IF @@FETCH_STATUS = -1        
    BREAK        
          
    set @V_STR_SQL = '  INSERT INTO  IFRS_SCENARIO_DATA (          
                                       DOWNLOAD_DATE,          
                                       RULE_ID,      
            RULE_TYPE,          
                                       MASTERID,      
            PKID          
                                       )          
      SELECT  A.DOWNLOAD_DATE,          
                   ''' +@V_RULE_ID+''',       
       ''' +@V_RULE_TYPE+''',          
              A.MASTERID,      
     A.PKID          
        FROM  ' + @v_TABLE_NAME+' A          
       WHERE  A.DOWNLOAD_DATE =  '''          
    +@V_CURRDATE          
    + ''' AND ('          
    + RTRIM(ISNULL(@V_STR_SQL_RULE, '')) + ')';          
        
    EXECUTE (@V_STR_SQL);        
         
END          
 CLOSE i          
  DEALLOCATE i          
END   
GO
