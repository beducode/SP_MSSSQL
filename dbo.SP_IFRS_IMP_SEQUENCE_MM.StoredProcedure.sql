USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_SEQUENCE_MM]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_SEQUENCE_MM]   
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
        DELETE IFRS_STATISTIC WHERE DOWNLOAD_DATE = @V_CURRDATE AND PRC_NAME = 'IMP'          
      
        DECLARE @TABLE_NAME VARCHAR(50)            
        DECLARE @V_STR_SQL VARCHAR(MAX)            
        DECLARE SEG1           
        CURSOR FOR  
   SELECT TABLE_NAME          
   FROM INFORMATION_SCHEMA.COLUMNS           
   WHERE COLUMN_NAME = 'IS_DELETE' AND TABLE_CATALOG = 'IFRS9'           
    
  OPEN SEG1;     
  FETCH SEG1 INTO @TABLE_NAME  
    
  WHILE @@FETCH_STATUS = 0  
  BEGIN    
      SET @V_STR_SQL = ''    
      SET @V_STR_SQL = 'DELETE ' + @TABLE_NAME + ' WHERE IS_DELETE = 1'            
        
      EXEC (@V_STR_SQL);          
          
      FETCH NEXT FROM SEG1 INTO @TABLE_NAME  
  END     
        CLOSE SEG1;  
        DEALLOCATE SEG1;            
        
        -- RULE SEGMENTATION                   
        EXEC SP_IFRS_EXEC_AND_LOG          
        @P_SP_NAME = 'SP_IFRS_IMP_GENERATE_RULE_SEGMENT',          
        @DOWNLOAD_DATE = @V_CURRDATE,          
        @P_PRC_NAME = 'IMP_DAILY',        
        @EXECUTE_FLAG = 'Y';                   


        -- UPDATE EIR RATE, RUN EVERYTIME SEQ IMP RUN, UNTIL BEFORE GOLIVE    
        --EXEC SP_IFRS_UPDATE_EIR @V_CURRDATE    
        
        -- SYNC EXCLUSION  
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_SYNC_EXCLUSION',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;  
      
        -- SYNC MASTER WO, NOT RUN COZ NO MANUAL UPLOAD WO    
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_SYNC_WO_UPLOAD',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
       
        --EXEC SP_IFRS_EXEC_AND_LOG      
        --@P_SP_NAME = 'SP_IFRS_IMPI_JOURNAL_DATA',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',    
        --@EXECUTE_FLAG = 'Y',  
        --@PARAMETER = @PARAM_WITHPRC;    
          
        -- INSERT IMA IMP CURR    
        EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_FILL_IMA_PREV_CURR',    
        @P_SP_NAME = 'SP_IFRS_IMP_FILL_IMA_PREV_CURR_MM',
		@DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
      
        -- AVERAGE eir    
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_AVG_EIR',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',    
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;     
   
        -- DEFAULT DEFINITION UPDATE    
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_INSERT_DEFAULT',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;      
        
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;   
  		--
		---- DEFAULT RULE (T24 Addons)  
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE_NOLAG',    
        --@DOWNLOAD_DATE = @V_CURRDATE,    
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;    
        
  --      -- PD SCENARIO DATA           
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_SCENARIO_DATA',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,         
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      -- PD SCENARIO DATA (T24 Addons)         
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_SCENARIO_DATA_NOLAG',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,         
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;    
        
  --      -- DEFAULT RATE (ODR)     
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RATE',     
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      -- DEFAULT RATE (ODR) (T24 Addons)     
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RATE_NOLAG',     
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      -- PD COHORT    
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_CHR_SUMM',      
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',     
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_CHR_RESULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;           
    
  --      -- for COHORT RUN R FOR GAMMA         
  --      EXEC SP_IFRS_EXEC_AND_LOG     
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_CHR_GAMMA_DIST',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;  
        
  --      -- PD MIGRATION ANALYSIS      
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_DETAIL',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,      
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_ENR',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG       
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_AVERAGE',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',          
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_MMULT',          
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_RESULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;  
    
  ---- PD MIGRATION ANALYSIS (T24 Addons)  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_DETAIL',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;  
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_ENR',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_AVERAGE',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_FITTED',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_MMULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_RESULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;   
  
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_CORP_EXTRAPOLATE',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',      
  --      @PARAMETER = @PARAM_WITHPRC;  
        
  --      -- PD NET FLOWRATE    
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_NFR_ENR',   
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG   
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_NFR_FLOWRATE',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_NFR_FLOWLOSS',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_NFR_RESULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',   
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      -- PD Yearly to Monthly    
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_TERM_YEARLY',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;     
        
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_YEAR_TO_MONTH',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,      
  --      @P_PRC_NAME = 'IMP',           
  --      @EXECUTE_FLAG = 'Y',  
  --      @PARAMETER = @PARAM_WITHPRC;      
      
  --      -- PD FL Yearly to Monthly    
  --      EXEC SP_IFRS_EXEC_AND_LOG    
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_FL_TERM_YEARLY',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',      
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;            
        
  --      EXEC SP_IFRS_EXEC_AND_LOG     
  --      @P_SP_NAME = 'SP_IFRS_IMP_PD_FL_YEAR_TO_MONTH',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',           
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;         
        
  --      -- BACKTEST MODEL SCALAR PD        
  --      EXEC SP_IFRS_EXEC_AND_LOG     
  --      @P_SP_NAME = 'SP_IFRS_IMP_BACKTEST_RESULT',    
  --      @DOWNLOAD_DATE = @V_CURRDATE,    
  --      @P_PRC_NAME = 'IMP',           
  --      @EXECUTE_FLAG = 'Y',    
  --      @PARAMETER = @PARAM_WITHPRC;         
        
        -- RECOVERY  
        EXEC SP_IFRS_EXEC_AND_LOG      
        @P_SP_NAME = 'SP_IFRS_IMP_UPDATE_WO_RECOVERY_PORTFOLIO',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
  
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_RECOVERY_SCENARIO_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
    @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;  
      
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_WO_SCENARIO_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
       @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;            
        
        -- LGD     
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_LGD_SCENARIO_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
     
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_LGD_CURE_LGL_DETAIL',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_LGD_CURE_LGL_HEADER',    
        @DOWNLOAD_DATE = @V_CURRDATE,   
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;   
    
  -- LGD (T24 Addons)    
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_LGD_ER_SCENARIO_DATA_CORP',    
        --@DOWNLOAD_DATE = @V_CURRDATE,   
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;  
  
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_LGD_ER_DETAIL_CORP',    
        --@DOWNLOAD_DATE = @V_CURRDATE,   
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;   
  
        --EXEC SP_IFRS_EXEC_AND_LOG    
        --@P_SP_NAME = 'SP_IFRS_IMP_LGD_ER_HEADER_CORP',    
        --@DOWNLOAD_DATE = @V_CURRDATE,   
        --@P_PRC_NAME = 'IMP',      
        --@EXECUTE_FLAG = 'Y',    
        --@PARAMETER = @PARAM_WITHPRC;   
    /* 
        
        -- CCF SEQUENCE        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_CCF_SCENARIO_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',            
        @EXECUTE_FLAG = 'Y',  
        @PARAMETER = @PARAM_WITHPRC;    
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_EAD_CCF_DETAIL',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_EAD_CCF_HEADER',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',           
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
    
	
		  -- SBLC (T24 Addons)  
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_SBLC_PRORATE',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',           
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;   
         
        -- ECL COLLECTIVE    
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_ECL_GENERATE_IMA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE_ECL',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
          
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_EXEC_RULE_STAGE',    
        @DOWNLOAD_DATE = @V_CURRDATE,     
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_ECL_EAD_RESULT_NONPRK',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_ECL_EAD_RESULT_PRK',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
        
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_ECL_RESULT_DETAIL',    
        @DOWNLOAD_DATE = @V_CURRDATE,  
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;     
        
        -- SYNC IMA      
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_SYNC_IMA_MONTHLY',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',      
        @PARAMETER = @PARAM_WITHPRC;    
         
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMPC_JOURNAL_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',     
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;    
         
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_GL_OUTBOUND',    
  @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;       
         
        EXEC SP_IFRS_EXEC_AND_LOG    
        @P_SP_NAME = 'SP_IFRS_IMP_GL_OUTBOUND_SUMMARIZE',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;       
         
        EXEC SP_IFRS_EXEC_AND_LOG   
        @P_SP_NAME = 'SP_IFRS_IMP_NOMINATIVE_OUTPUT',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;      
      
        --LOAD DASHBOARD DATA     
        EXEC SP_IFRS_EXEC_AND_LOG       
        @P_SP_NAME = 'SP_IFRS_IMP_DASHBOARD_DATA',    
        @DOWNLOAD_DATE = @V_CURRDATE,    
        @P_PRC_NAME = 'IMP',      
        @EXECUTE_FLAG = 'Y',    
        @PARAMETER = @PARAM_WITHPRC;      
   
        -- EXCEPTION REPORT     
        EXEC SP_IFRS_EXEC_AND_LOG       
        @P_SP_NAME = 'SP_IFRS_EXCEPTION_REPORT',      
        @DOWNLOAD_DATE = @V_CURRDATE,  
        @P_PRC_NAME = 'IMP',   
        @EXECUTE_FLAG = 'Y',  
        @PARAMETER = @PARAM_WITHPRCFLAG   
     */

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
