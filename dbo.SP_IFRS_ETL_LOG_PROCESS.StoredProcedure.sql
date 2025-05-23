USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ETL_LOG_PROCESS]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_ETL_LOG_PROCESS]      
    (      
      @P_SP_NAME  VARCHAR(100) ,      
      @P_PRC_NAME VARCHAR(10) = 'ETL' ,      
   @STATUS     VARCHAR(1) = 'R'      
    )      
AS       
    DECLARE @V_Counter INT ,      
        @V_ERRN INT ,      
        @V_ERRM VARCHAR(255) ,      
        @V_CURRDATE DATE ,      
        @V_max_Counter INT= 0 ,      
        @v_prevdate DATE ,      
        @v_sessionid VARCHAR(50) ,      
        @V_COUNT INT ,      
        @v_str_sql VARCHAR(100) ,      
        @v_MinStartDateSession DATETIME      
      
      
    BEGIN TRY      
      
        SELECT  @v_currdate = currdate ,      
                @v_prevdate = prevdate ,      
    @v_sessionid = sessionid      
        FROM    IFRS_PRC_DATE_AMORT      
      
        SELECT  @V_Counter = ISNULL(MAX(counter), 0) ,      
                @v_MinStartDateSession = ISNULL(MIN(start_date),CURRENT_TIMESTAMP)      
        FROM    IFRS_STATISTIC      
        WHERE   PRC_NAME = @P_PRC_NAME AND      
                DOWNLOAD_DATE = @v_currdate      
      
        SET @V_Counter = @V_Counter + 1      
      
  IF @STATUS = 'R'      
  BEGIN      
      
  UPDATE  IFRS_PRC_DATE      
        SET     BATCH_STATUS = 'Running..' ,      
                REMARK = @P_SP_NAME      
      
        UPDATE  IFRS_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Running..' ,      
                REMARK = @P_SP_NAME      
    
  UPDATE  IFRS_LI_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Running..' ,      
                REMARK = @P_SP_NAME      
      
      
  IF @P_PRC_NAME = 'IFRS EOD' -- Reset Statistic      
  Begin      
              
   DELETE IFRS_STATISTIC where DOWNLOAD_DATE = @v_currdate      
   Set @V_Counter = 1      
        end      
      
  DELETE IFRS_STATISTIC where DOWNLOAD_DATE = @v_currdate and SP_NAME = @P_SP_NAME and PRC_NAME = @P_PRC_NAME      
      
        INSERT  INTO IFRS_STATISTIC      
                ( DOWNLOAD_DATE ,      
                  SP_NAME ,      
                  START_DATE ,      
                  ISCOMPLETE ,      
                  COUNTER ,      
                  PRC_NAME ,      
                  SESSIONID ,      
                  REMARK      
                )      
                SELECT  CURRDATE ,      
                        @P_SP_NAME ,      
                        CURRENT_TIMESTAMP ,      
                        'N' ,      
                        @V_Counter ,      
                        @P_PRC_NAME ,      
                        @v_sessionid ,      
                        'Running..'      
                FROM    IFRS_PRC_DATE                
               
  END          
  ELSE IF @STATUS = 'S'      
  BEGIN      
        UPDATE  IFRS_STATISTIC      
        SET     END_DATE = CURRENT_TIMESTAMP ,      
                ISCOMPLETE = 'Y' ,      
                PRC_PROCESS_TIME = dbo.F_GetProcessTime(START_DATE,CURRENT_TIMESTAMP) ,      
                REMARK = 'Succeed'      
        WHERE   DOWNLOAD_DATE = @V_CURRDATE      
                AND SP_NAME = @P_SP_NAME      
                AND PRC_NAME = @P_PRC_NAME      
      
        UPDATE  IFRS_STATISTIC      
        SET     SESSION_PROCESS_TIME = dbo.F_GetProcessTime(@v_MinStartDateSession,GETDATE())      
        WHERE   DOWNLOAD_DATE = @V_CURRDATE --and counter = @V_Counter + 1      
               -- AND sessionid = @v_sessionid      
      
        UPDATE  IFRS_PRC_DATE      
        SET     BATCH_STATUS = 'Finished' ,      
                REMARK = 'Execute ' + @P_SP_NAME + ' is Succeed' ,      
    LAST_PROCESS_DATE = CURRDATE      
      
     UPDATE  IFRS_PRC_DATE_AMORT      
   SET     BATCH_STATUS = 'Finished' ,      
     REMARK = 'Execute ' + @P_SP_NAME + ' is Succeed',      
     LAST_PROCESS_DATE = CURRDATE      
  
  UPDATE  IFRS_LI_PRC_DATE_AMORT      
   SET     BATCH_STATUS = 'Finished' ,      
     REMARK = 'Execute ' + @P_SP_NAME + ' is Succeed',      
     LAST_PROCESS_DATE = CURRDATE      
        
  END      
  ELSE      
  BEGIN      
        UPDATE  IFRS_STATISTIC      
   SET     END_DATE = CURRENT_TIMESTAMP ,      
                ISCOMPLETE = 'N' ,      
                PRC_PROCESS_TIME = dbo.F_GetProcessTime(START_DATE,CURRENT_TIMESTAMP) ,      
                REMARK = 'Failed..'      
        WHERE   DOWNLOAD_DATE = @V_CURRDATE      
                AND SP_NAME = @P_SP_NAME      
                AND PRC_NAME = @P_PRC_NAME      
      
        UPDATE  IFRS_STATISTIC      
        SET     SESSION_PROCESS_TIME = dbo.F_GetProcessTime(@v_MinStartDateSession,GETDATE())      
        WHERE   DOWNLOAD_DATE = @V_CURRDATE --and counter = @V_Counter + 1      
               -- AND sessionid = @v_sessionid      
      
        UPDATE  IFRS_PRC_DATE      
        SET     BATCH_STATUS = 'Failed..' ,      
                REMARK = 'Execute ' + @P_SP_NAME + ' is Failed..'      
      
  UPDATE  IFRS_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Failed..' ,      
                REMARK = 'Execute ' + @P_SP_NAME + ' is Failed..'      
  
  UPDATE  IFRS_LI_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Failed..' ,      
                REMARK = 'Execute ' + @P_SP_NAME + ' is Failed..'   
        
  END      
      
    END TRY      
      
    BEGIN CATCH      
        SELECT  @V_ERRN = ERROR_NUMBER()      
        SELECT  @V_ERRM = ERROR_MESSAGE()      
        
        UPDATE  IFRS_STATISTIC      
        SET     END_DATE = CURRENT_TIMESTAMP ,      
                ISCOMPLETE = 'N' ,      
                REMARK = 'Error - ' + CAST(@V_ERRN AS VARCHAR(50)) + ' '      
                + @V_ERRM      
        WHERE   DOWNLOAD_DATE = @V_CURRDATE      
                AND SP_NAME = @P_SP_NAME      
                AND PRC_NAME = @P_PRC_NAME               
      
        UPDATE  IFRS_PRC_DATE      
        SET     BATCH_STATUS = 'Error!! ' ,      
                REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @P_PRC_NAME + ')'      
      
  UPDATE  IFRS_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Error!! ' ,      
                REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @P_PRC_NAME + ')'      
  
  UPDATE  IFRS_LI_PRC_DATE_AMORT      
        SET     BATCH_STATUS = 'Error!! ' ,      
                REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @P_PRC_NAME + ')'     
      
  --sp_psak_drop_psak_batch_job;      
        --SP_PSAK_SENT_EMAIL ('TS-ERROR', V_ERRM);      
        RAISERROR (@V_ERRM, -- Message text.      
           11, -- Severity,      
           -1 -- State      
        )  
        RETURN    
      
    END CATCH   
  
  
  
  

GO
