USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SEQUENCE_DAILY]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SEQUENCE_DAILY]                     
@DOWNLOAD_DATE DATE = NULL                     
AS                       
    DECLARE @V_CURRDATE DATE;                       
    DECLARE @V_CURRMONTH DATE;                       
    DECLARE @V_PREVMONTH DATE;                                 
    DECLARE @PARAM_WITHPRC VARCHAR(MAX);                       
    DECLARE @PARAM_WITHPRCFLAG VARCHAR(MAX);                    
BEGIN                     
                
    SET NOCOUNT ON;
                    
    IF @DOWNLOAD_DATE IS NULL                      
    BEGIN                      
        SELECT                       
         @V_CURRDATE = CURRDATE,                       
         @V_CURRMONTH = EOMONTH(CURRDATE),                       
         @V_PREVMONTH = EOMONTH(DATEADD(MM, -1, CURRDATE))                       
        FROM IFRS_PRC_DATE                        
    END                     
    ELSE                   
    BEGIN                      
        SET @V_CURRDATE = @DOWNLOAD_DATE                       
        SET @V_CURRMONTH = EOMONTH(@DOWNLOAD_DATE)                       
        SET @V_PREVMONTH = EOMONTH(DATEADD(MM, -1, @DOWNLOAD_DATE))                       
    END                   
                    
    SET @PARAM_WITHPRC = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRDATE), 'NULL') + '''';      
    SET @PARAM_WITHPRCFLAG = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRDATE), 'NULL') + ''', @FLAG = ''I''';       
          
    BEGIN TRY      
      
        DELETE IFRS_STATISTIC WHERE DOWNLOAD_DATE = @V_CURRDATE AND PRC_NAME = 'IMP_DAILY'        
        
        -- PREP DATA                   
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMP_INITIAL_UPDATE',          
        @DOWNLOAD_DATE = @V_CURRDATE,          
        @P_PRC_NAME = 'IMP_DAILY',        
        @EXECUTE_FLAG = 'Y',          
        @PARAMETER = @PARAM_WITHPRC;                   
                     
        -- RULE SEGMENTATION                   
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMP_GENERATE_RULE_SEGMENT',          
        @DOWNLOAD_DATE = @V_CURRDATE,          
        @P_PRC_NAME = 'IMP_DAILY',        
        @EXECUTE_FLAG = 'Y';                   
                    
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMP_ECL_UPDATE_PORTFOLIO',          
        @DOWNLOAD_DATE = @V_CURRDATE,                
        @P_PRC_NAME = 'IMP_DAILY',        
        @EXECUTE_FLAG = 'Y',          
        @PARAMETER = @PARAM_WITHPRC;                   
                     
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMP_ECL_UPDATE_EIR',          
        @DOWNLOAD_DATE = @V_CURRDATE,          
        @P_PRC_NAME = 'IMP_DAILY',                  
        @EXECUTE_FLAG = 'Y',          
        @PARAMETER = @PARAM_WITHPRC;                      
             
        -- INDIVIDUAL                   
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMPI_PROCESS',         
        @DOWNLOAD_DATE = @V_CURRDATE,          
        @P_PRC_NAME = 'IMP_DAILY',        
        @EXECUTE_FLAG = 'Y',          
        @PARAMETER = @PARAM_WITHPRC;           
          
    END TRY                          
                          
    BEGIN CATCH                                
                          
        DECLARE @ErrorSeverity INT,                          
        @ErrorState INT,                          
        @ErrorMessageDescription NVARCHAR(4000),                          
        @DateProcess VARCHAR(100),      
        @V_ERRM VARCHAR(255),      
        @V_SPNAME VARCHAR(100);                               
                          
        SELECT  @DateProcess = CONVERT(VARCHAR(20), GETDATE(), 107)                            
                          
        SELECT  @V_ERRM = ERROR_MESSAGE(),                          
        @ErrorSeverity = ERROR_SEVERITY(),                          
        @ErrorState = ERROR_STATE();                                    
                          
        UPDATE  A                          
        SET     A.END_DATE = GETDATE(),                          
        ISCOMPLETE = 'N',                          
        REMARK = @V_ERRM                          
        FROM    IFRS_STATISTIC A                          
        WHERE   A.DOWNLOAD_DATE = @v_currdate                          
        AND A.SP_NAME = @V_SPNAME;                         
                          
        UPDATE  IFRS_PRC_DATE                          
        SET     BATCH_STATUS = 'ERROR!!..',                          
        Remark = @V_ERRM,                          
        Last_Process_Date = GETDATE();                             
                          
        SET @ErrorMessageDescription = @V_SPNAME + ' ( ' + @DateProcess + ' ) --> ' + @V_ERRM                                          
        RAISERROR (@ErrorMessageDescription, 11, 1)                           
        RETURN                  
    END CATCH;
       
  END   

GO
