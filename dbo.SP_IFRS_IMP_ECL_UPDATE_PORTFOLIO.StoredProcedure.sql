USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_ECL_UPDATE_PORTFOLIO]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_ECL_UPDATE_PORTFOLIO] @DOWNLOAD_DATE DATE = NULL          
AS             
DECLARE                            
  @V_RULE_ID VARCHAR(250),                            
  @v_TABLE_NAME VARCHAR(30),                          
  @TABLE_NAME VARCHAR(30),                            
  @V_STR_SQL VARCHAR(4000),                            
  @V_GROUP_SEGMENT VARCHAR(250),                            
  @V_SEGMENT VARCHAR(250),                            
  @V_SUB_SEGMENT VARCHAR(250),                            
  @V_CONDITION VARCHAR(4000),                            
  @V_CURRDATE DATE,                          
  @V_EXCEPT_ID VARCHAR(10)                              
BEGIN                              
 SET NOCOUNT ON;             
           
 IF (@DOWNLOAD_DATE IS NULL)          
 BEGIN          
 SELECT @V_CURRDATE = CONVERT(VARCHAR(8), CURRDATE, 112) FROM IFRS_PRC_DATE          
 END          
 ELSE                   
 BEGIN          
 SELECT @V_CURRDATE = @DOWNLOAD_DATE          
 END          
                   
 SET @V_EXCEPT_ID = 888;                          
                        
 SELECT DISTINCT            
 @TABLE_NAME = TABLE_NAME                     
 FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY                            
 WHERE SEGMENT_TYPE = 'PORTFOLIO_SEGMENT'                
            
 SET @V_STR_SQL =             
 'UPDATE A                            
 SET A.SUB_SEGMENT = NULL, A.SEGMENT = NULL, A.GROUP_SEGMENT = NULL                            
 FROM ' + @TABLE_NAME + ' A                            
 WHERE A.DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';              
             
 EXEC (@V_STR_SQL);                       
                        
 DELETE IFRS_EXCEPTION_ACCOUNT                        
 WHERE EXCEPTION_ID = @V_EXCEPT_ID AND DOWNLOAD_DATE = @V_CURRDATE                        
                      
 DECLARE i SCROLL CURSOR FOR                            
 SELECT DISTINCT                            
 RULE_ID,                            
 TABLE_NAME,                            
 GROUP_SEGMENT,                            
 SEGMENT,                            
 SUB_SEGMENT,                            
 CONDITION                            
 FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY                            
 WHERE SEGMENT_TYPE = 'PORTFOLIO_SEGMENT'                            
      
 OPEN i                            
 WHILE 1=1                           
    BEGIN                            
                                  
  FETCH NEXT from i INTO @v_RULE_ID, @v_TABLE_NAME, @V_GROUP_SEGMENT, @V_SEGMENT, @V_SUB_SEGMENT, @V_CONDITION;                               
                                  
  IF @@FETCH_STATUS = -1                                  
  BREAK                                  
                        
  SET @V_STR_SQL =                   
   'UPDATE A SET A.SUB_SEGMENT = ''' + @V_SUB_SEGMENT + ''', A.SEGMENT = ''' + @V_SEGMENT + ''', A.GROUP_SEGMENT = ''' + @V_GROUP_SEGMENT                   
   + ''' FROM ' + @V_TABLE_NAME + ' A '                            
   + 'WHERE (' + @V_CONDITION + ') AND DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) + '''';                          
  --PRINT @v_STR_SQL                                 
  EXEC (@V_STR_SQL)   
                                                                   
    END                                  
    CLOSE i                                  
 DEALLOCATE i                           
                  
END
GO
