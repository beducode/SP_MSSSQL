USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_ECL_UPDATE_EIR]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_ECL_UPDATE_EIR]               
@DOWNLOAD_DATE DATE = NULL         
AS          
 DECLARE                     
 @v_TABLE_NAME VARCHAR(30),        
 @V_STR_SQL VARCHAR(4000),             
 @V_SUB_SEGMENT VARCHAR(250),        
 @V_CONDITION VARCHAR(4000),        
 @V_CURRDATE DATE,                    
 @V_STARTDATE_OF_YEAR DATE            
BEGIN          
 SET NOCOUNT ON;         
           
 IF (@DOWNLOAD_DATE IS NULL)          
 BEGIN          
 SELECT @V_CURRDATE = CONVERT(VARCHAR(8), @V_CURRDATE, 112)          
 FROM IFRS_PRC_DATE_AMORT        
 END          
 ELSE          
 BEGIN          
 SELECT @V_CURRDATE = @DOWNLOAD_DATE          
 END          
            
 SET @V_STARTDATE_OF_YEAR = CONCAT(YEAR(@V_CURRDATE), '0101')                 
          
 UPDATE A        
 SET A.EIR_SEGMENT = NULL            
 FROM IFRS_MASTER_ACCOUNT A        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE           
        
 DECLARE i SCROLL CURSOR FOR        
 SELECT DISTINCT       
 TABLE_NAME,        
 SUB_SEGMENT,        
 CONDITION        
 FROM IFRS_SCENARIO_SEGMENT_GENERATE_QUERY        
 WHERE SEGMENT_TYPE = 'EIR_SEGMENT'        
        
 OPEN i        
 WHILE 1 = 1             
    BEGIN        
        
        FETCH NEXT from i INTO @v_TABLE_NAME, @V_SUB_SEGMENT, @V_CONDITION        
          
        IF @@FETCH_STATUS = -1        
        BREAK        
                  
        SET @V_STR_SQL =           
            'UPDATE A SET A.EIR_SEGMENT = ''' + @V_SUB_SEGMENT           
            + ''' FROM ' + @V_TABLE_NAME + ' A (NOLOCK) '        
            + 'WHERE (' + @V_CONDITION + ') AND DOWNLOAD_DATE = ''' + CONVERT(VARCHAR(8), @V_CURRDATE, 112) +     '''';        
            
        EXEC (@V_STR_SQL)          
        --PRINT  @V_STR_SQL             
    END        
    CLOSE i        
 DEALLOCATE i        

 UPDATE A
 SET
    A.EIR_SEGMENT = B.EIR_SEGMENT
 FROM IFRS_MASTER_ACCOUNT A (NOLOCK)
 JOIN
 (
    SELECT PRODUCT_TYPE, EIR_SEGMENT 
    FROM IFRS_MASTER_ACCOUNT (NOLOCK)
    WHERE DOWNLOAD_DATE = @V_CURRDATE AND DATA_SOURCE = 'LOAN'
    GROUP BY PRODUCT_TYPE, EIR_SEGMENT
 ) B ON A.PRODUCT_TYPE = B.PRODUCT_TYPE
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE
 AND DATA_SOURCE = 'LIMIT'

END
GO
