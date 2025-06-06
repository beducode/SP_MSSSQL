USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SEQUENCE_PREVIEW]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SEQUENCE_PREVIEW]                                          
AS        
 DECLARE @V_CURRDATE DATE;        
 DECLARE @V_CURRMONTH DATE;        
 DECLARE @V_PREVMONTH DATE;         
 DECLARE @V_LAST_STATISTIC_DATE DATE;          
 DECLARE @PARAM_WITHPRC VARCHAR(MAX);        
 DECLARE @PARAM_WITHPRCFLAG VARCHAR(MAX);                                         
BEGIN                                          
                                     
    SET NOCOUNT ON;                                      
                                      
    SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE        
        
    SET @V_CURRMONTH = EOMONTH(@V_CURRDATE)                                       
    SET @V_PREVMONTH = EOMONTH(DATEADD(MM, -1, @V_CURRDATE))         
        
    SELECT @V_LAST_STATISTIC_DATE = MAX(DOWNLOAD_DATE) FROM IFRS_STATISTIC WHERE PRC_NAME = 'IMP'    
        
    -- IF CURRDATE > LAST_STATISTIC_DATE THEN CAN RUN PRIVIEW ENGINE        
    IF @V_CURRDATE > @V_LAST_STATISTIC_DATE        
    BEGIN        
        -- IF @V_CURRDATE NOT EOMONTH THEN RUN        
        IF (@V_CURRDATE <> EOMONTH(@V_CURRDATE))        
        BEGIN        
        
            SET @PARAM_WITHPRC = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRMONTH), 'NULL') + '''';                   
            SET @PARAM_WITHPRCFLAG = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRMONTH), 'NULL') + ''', @FLAG = ''I''';                   
        
            DELETE IFRS_STATISTIC WHERE DOWNLOAD_DATE = @V_CURRMONTH AND PRC_NAME = 'IMP-PRV'                                           
                                              
            -- SET LATEST MASTER ACCOUNT TO EOMONTH POSITION                                      
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_FILL_IMA_PREVIEW',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y';         
      
            -- SYNC MASTER WO                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_SYNC_WO_UPLOAD',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                        
        
            -- PREP DATA                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_INITIAL_UPDATE',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;     
    
             -- PREVIEW Purposes    
             UPDATE A    
             SET A.DPD_FINAL = DPD_CIF    
             FROM IFRS_MASTER_ACCOUNT A (NOLOCK)    
             WHERE DOWNLOAD_DATE = @V_CURRMONTH       
                                 
            -- RULE SEGMENTATION                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_GENERATE_RULE_SEGMENT',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y';                                        
                
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_ECL_UPDATE_PORTFOLIO',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',                               
             @PARAMETER = @PARAM_WITHPRC;                                        
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_ECL_UPDATE_EIR',                               
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',                                     
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                    
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_AVG_EIR',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                        
                                             
             -- INDIVIDUAL                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
            @P_SP_NAME = 'SP_IFRS_IMPI_PROCESS',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;       
                     
              -- INSERT IMA IMP CURR                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_FILL_IMA_PREV_CURR',        
             @DOWNLOAD_DATE = @V_CURRMONTH,                                    
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
        
            -- DEFAULT DEFINITION UPDATE                                        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_INSERT_DEFAULT',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            -- PD FL Yearly to Monthly            
            EXEC SP_IFRS_EXEC_AND_LOG              
            @P_SP_NAME = 'SP_IFRS_IMP_PD_FL_TERM_YEARLY',              
            @DOWNLOAD_DATE = @V_CURRMONTH,              
            @P_PRC_NAME = 'IMP-PRV',                            
            @EXECUTE_FLAG = 'Y',              
            @PARAMETER = @PARAM_WITHPRC;             
                      
            EXEC SP_IFRS_EXEC_AND_LOG                                   
            @P_SP_NAME = 'SP_IFRS_IMP_PD_FL_YEAR_TO_MONTH',              
            @DOWNLOAD_DATE = @V_CURRMONTH,              
            @P_PRC_NAME = 'IMP-PRV',                                         
            @EXECUTE_FLAG = 'Y',              
            @PARAMETER = @PARAM_WITHPRC;        
                  
            -- ECL COLLECTIVE                                          
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_ECL_GENERATE_IMA',        
             @DOWNLOAD_DATE = @V_CURRMONTH,                        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            EXEC SP_IFRS_EXEC_AND_LOG                                          
             @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE_ECL',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                                     
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_EXEC_RULE_STAGE',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_ECL_EAD_RESULT_NONPRK',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_ECL_EAD_RESULT_PRK',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
                 
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_ECL_RESULT_DETAIL',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',        
             @PARAMETER = @PARAM_WITHPRC;                                         
           
            -- SYNC IMA        
            EXEC SP_IFRS_EXEC_AND_LOG        
             @P_SP_NAME = 'SP_IFRS_IMP_SYNC_IMA_MONTHLY',        
             @DOWNLOAD_DATE = @V_CURRMONTH,        
             @P_PRC_NAME = 'IMP-PRV',            
             @EXECUTE_FLAG = 'Y',                          
             @PARAMETER = @PARAM_WITHPRC;        
        END        
    END                                         
END 
GO
