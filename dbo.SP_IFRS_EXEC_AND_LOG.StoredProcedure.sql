USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_EXEC_AND_LOG]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_EXEC_AND_LOG]              
(    
 @P_SP_NAME     VARCHAR(100),               
 @P_PRC_NAME    VARCHAR(50)  = 'AMT',               
 @EXECUTE_FLAG  CHAR(1)      = 'Y',               
 @DOWNLOAD_DATE DATE         = NULL,               
 @PARAMETER     VARCHAR(MAX) = ''              
)              
AS              
              
DECLARE           
 @V_COUNTER INT,           
 @V_ERRN INT,           
 @V_ERRM VARCHAR(255),           
 @V_CURRDATE DATE,           
 @V_MAX_COUNTER INT= 0,           
 @V_PREVDATE DATE,           
 @V_SESSIONID VARCHAR(32),           
 @V_COUNT INT,           
 @V_STR_SQL VARCHAR(100),           
 @V_MINSTARTDATESESSION DATETIME,           
 @V_SP_NAME VARCHAR(50),           
 @V_PRC_NAME VARCHAR(20);              
              
 BEGIN TRY              
        SET @V_SP_NAME = @P_SP_NAME;              
        SET @V_PRC_NAME = @P_PRC_NAME;              
        IF @DOWNLOAD_DATE IS NOT NULL             
        BEGIN  
            IF @V_PRC_NAME = 'AMT'  
            BEGIN  
                SELECT @V_SESSIONID = SESSIONID              
                FROM IFRS_PRC_DATE_AMORT;  
            END   
            ELSE  
            BEGIN        
                SELECT @V_SESSIONID = SESSIONID              
                FROM IFRS_PRC_DATE;  
            END  
            SELECT   
                @V_CURRDATE = @DOWNLOAD_DATE,               
                @V_PREVDATE = EOMONTH(DATEADD(MONTH, -1, @DOWNLOAD_DATE));              
        END;              
        ELSE              
        BEGIN              
            IF @V_PRC_NAME = 'AMT'              
                SELECT   
                    @V_CURRDATE = CURRDATE,               
                    @V_PREVDATE = PREVDATE,               
                    @V_SESSIONID = SESSIONID              
                FROM IFRS_PRC_DATE_AMORT;              
            ELSE              
                SELECT   
                    @V_CURRDATE = CURRDATE,               
                    @V_PREVDATE = PREVDATE,               
                    @V_SESSIONID = SESSIONID              
                FROM IFRS_PRC_DATE;              
        END;              
        SELECT @V_COUNTER = ISNULL(MAX(COUNTER), 0) + 1,               
               @V_MINSTARTDATESESSION = ISNULL(MIN(START_DATE), CURRENT_TIMESTAMP)              
        FROM IFRS_STATISTIC              
        WHERE PRC_NAME = @V_PRC_NAME              
              AND DOWNLOAD_DATE = @V_CURRDATE;              
        UPDATE IFRS_PRC_DATE_AMORT              
          SET               
              BATCH_STATUS = 'RUNNING..',               
              REMARK = @V_SP_NAME;              
        UPDATE IFRS_PRC_DATE              
          SET               
              BATCH_STATUS = 'RUNNING..',               
              REMARK = @V_SP_NAME;              
        DELETE IFRS_STATISTIC              
        WHERE DOWNLOAD_DATE = @V_CURRDATE              
              AND SP_NAME = @V_SP_NAME              
              AND PRC_NAME = @V_PRC_NAME;              
        IF @V_PRC_NAME = 'AMT'              
            INSERT INTO IFRS_STATISTIC              
            (DOWNLOAD_DATE,               
             SP_NAME,               
             START_DATE,               
             ISCOMPLETE,               
             COUNTER,               
             PRC_NAME,               
             SESSIONID,               
             REMARK,               
             PARAMETER              
            )              
                   SELECT @V_CURRDATE,               
                          @V_SP_NAME,               
                          CURRENT_TIMESTAMP,               
                          'N',               
                          @V_COUNTER,               
                          @V_PRC_NAME,               
                          @V_SESSIONID,               
                          'RUNNING..',               
                          @PARAMETER              
                   FROM IFRS_PRC_DATE_AMORT;              
            ELSE              
            INSERT INTO IFRS_STATISTIC            
            (DOWNLOAD_DATE,               
             SP_NAME,               
             START_DATE,               
             ISCOMPLETE,               
             COUNTER,               
             PRC_NAME,               
             SESSIONID,               
             REMARK,               
             PARAMETER              
            )              
                   SELECT @V_CURRDATE,               
                          @V_SP_NAME,               
    CURRENT_TIMESTAMP,               
                          'N',               
                          @V_COUNTER,               
                          @V_PRC_NAME,               
                          @V_SESSIONID,               
                          'RUNNING..',               
                          @PARAMETER              
                   FROM IFRS_PRC_DATE;              
        IF @EXECUTE_FLAG = 'Y'              
            BEGIN                
              ------SET @V_STR_SQL = @V_SP_NAME; -- OLD                
                SET @V_STR_SQL = @V_SP_NAME + ' ' + @PARAMETER + ''; -- ADD PARAMETER            
    PRINT '=====================';            
    PRINT @V_STR_SQL;            
    PRINT '=====================';                
                EXEC (@V_STR_SQL);              
        END;              
        UPDATE IFRS_STATISTIC              
          SET               
              END_DATE = CURRENT_TIMESTAMP,               
              ISCOMPLETE = 'Y',               
           PRC_PROCESS_TIME = DBO.FN_GETPROCESSTIME(START_DATE, CURRENT_TIMESTAMP),               
              REMARK = 'SUCCEED'              
        WHERE DOWNLOAD_DATE = @V_CURRDATE              
              AND SP_NAME = @V_SP_NAME              
              AND PRC_NAME = @V_PRC_NAME;              
        UPDATE IFRS_STATISTIC              
          SET               
              SESSION_PROCESS_TIME = DBO.FN_GETPROCESSTIME(@V_MINSTARTDATESESSION, GETDATE())              
        WHERE DOWNLOAD_DATE = @V_CURRDATE              
              AND PRC_NAME = @V_PRC_NAME;              
        UPDATE IFRS_PRC_DATE_AMORT              
          SET               
              BATCH_STATUS = 'FINISHED',               
              REMARK = 'EXECUTE ' + @V_SP_NAME + ' IS SUCCEED',               
              LAST_PROCESS_DATE = CURRDATE;              
        UPDATE IFRS_PRC_DATE              
          SET               
              BATCH_STATUS = 'FINISHED',               
              REMARK = 'EXECUTE ' + @V_SP_NAME + ' IS SUCCEED',               
              LAST_PROCESS_DATE = CURRDATE;              
    END TRY              
    BEGIN CATCH              
        SELECT @V_ERRN = ERROR_NUMBER();              
        SELECT @V_ERRM = ERROR_MESSAGE();              
        UPDATE IFRS_STATISTIC              
          SET               
              END_DATE = CURRENT_TIMESTAMP,               
              ISCOMPLETE = 'N',               
              REMARK = 'ERROR - ' + CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM              
        WHERE DOWNLOAD_DATE = @V_CURRDATE              
              AND SP_NAME = @V_SP_NAME              
              AND PRC_NAME = @V_PRC_NAME;              
        UPDATE IFRS_PRC_DATE_AMORT              
          SET               
              RUNNING_FLAG_FROM_DW = 'N',               
              BATCH_STATUS = 'ERROR!!',               
              REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @V_PRC_NAME + ')';              
        UPDATE IFRS_PRC_DATE              
          SET               
              BATCH_STATUS = 'ERROR!!',               
              REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @V_PRC_NAME + ')';              
        RAISERROR(@V_ERRM, -- MESSAGE TEXT.                  
        16, -- SEVERITY,                  
        1 -- STATE                  
        ); 
        RETURN;             
  END CATCH;  
  

GO
