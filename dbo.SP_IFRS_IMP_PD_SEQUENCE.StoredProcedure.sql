USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_PD_SEQUENCE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_PD_SEQUENCE] 
----DECLARE
@PRC      CHAR(1)  = 'M', 
@RULE_ID  BIGINT   = 0, 
  @INTERVAL SMALLINT = 0
AS


----BEGIN TRANSACTION
-- COMMIT ROLLBACK
    BEGIN


EXEC [SP_IFRS_IMP_INSERT_DEFAULT] 
EXEC  SP_IFRS_IMP_DEFAULT_RULE 
EXEC [dbo].[SP_IFRS_IMP_PD_SCENARIO_DATA] 
EXEC [dbo].[SP_IFRS_IMP_DEFAULT_RATE] 
EXEC [dbo].[SP_IFRS_IMP_PD_CHR_SUMM] 

	DECLARE @V_PRCDATE DATE = '31 JAN 2012'

    EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_INSERT_DEFAULT', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y' 

    EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RULE', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y' 

	EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_SCENARIO_DATA', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y' 

	EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_DEFAULT_RATE', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y' 

--- COHOORT -----
	EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_CHR_SUMM', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  


 --- MAA -----
		EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_DETAIL', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  
 		EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_ENR', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  
 		EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_AVERAGE', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  
		EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_MMULT', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  
 		EXEC SP_IFRS_EXEC_AND_LOG 
           @P_SP_NAME = 'SP_IFRS_IMP_PD_MAA_RESULT', 
           @DOWNLOAD_DATE = @V_PRCDATE, 
           @P_PRC_NAME = 'IMP-PD', 
           @EXECUTE_FLAG = 'Y'  


			/*
        SET NOCOUNT ON;
        DECLARE @V_CURRDATE DATE, @V_PRCDATE DATE, @PARAM_WITHTYPE VARCHAR(MAX), @PARAM_NONTYPE VARCHAR(MAX);
        SELECT @V_CURRDATE = EOMONTH(DATEADD(MONTH, @INTERVAL * -1, CURRDATE))
        FROM IFRS_PRC_DATE;
        SELECT @V_PRCDATE = CASE
                                WHEN @PRC <> 'S'
                                THEN @V_CURRDATE
                                ELSE CUT_OFF_DATE
                            END
        FROM IFRS_PD_RULES_CONFIG A
        WHERE A.IS_DELETE = 0
              AND A.ACTIVE_FLAG = 1
              AND (A.PKID = @RULE_ID
                   OR @RULE_ID = 0);
				   
        SET @PARAM_WITHTYPE = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_PRCDATE), 'NULL') + ''', ' + '@MODEL_TYPE = ''PD'', ' + '@MODEL_ID = ' + ISNULL(CONVERT(VARCHAR(50), @RULE_ID), 'NULL');
        SET @PARAM_NONTYPE = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_PRCDATE), 'NULL') + ''', ' + '@MODEL_ID = ' + ISNULL(CONVERT(VARCHAR(50), @RULE_ID), 'NULL');
        
		WHILE @V_PRCDATE <= @V_CURRDATE
            BEGIN
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_DEFAULT_RULE', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_WITHTYPE;
                ------EXEC SP_IFRS_DEFAULT_RULE   
                ------     @DOWNLOAD_DATE = @V_PRCDATE,   
                ------     @MODEL_TYPE = 'PD',   
                ------     @MODEL_ID = @RULE_ID;  
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_GENERATE_RULE_SEGMENT', 
                     @P_PRC_NAME = 'IMP', 
                     @EXECUTE_FLAG = 'Y', 
                     @DOWNLOAD_DATE = @V_PRCDATE;  
                ------EXEC [SP_IFRS_EXEC_AND_LOG_SIM] 'SP_IFRS_GENERATE_RULE_SEGMENT', 'IMP','Y',@V_PRCDATE, @RULE_ID              
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_RULE_DATA', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                --EXEC SP_IFRS_PD_RULE_DATA 
                --     @DOWNLOAD_DATE = @V_PRCDATE, 
                --     @MODEL_ID = @RULE_ID;
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_TM_SCENARIO_DATA', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                --EXEC SP_IFRS_PD_TM_SCENARIO_DATA 
                --     @DOWNLOAD_DATE = @V_PRCDATE, 
                --     @MODEL_ID = @RULE_ID;
                 --======================                            
                 --PD_MIGRATION_DETAIL ALL METHODS                            
                 --======================  
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MIGRATION_DETAIL', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;                
                ----EXEC SP_IFRS_PD_MIGRATION_DETAIL 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                -- ======================                            
                -- ENR FOR ALL METHODS                            
                -- ====================== 
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_ENR', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;                            
                ----EXEC SP_IFRS_PD_MAA_ENR 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_ENR_PIT_SUM', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                ----EXEC SP_IFRS_PD_MAA_ENR_PIT_SUM 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_ENR_SUM', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                ----EXEC SP_IFRS_PD_MAA_ENR_SUM 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                -- ======================                            
                -- MAA METHOD                            
                -- ======================   
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_FLOWRATE', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;                   
                ----EXEC SP_IFRS_PD_MAA_FLOWRATE 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_FLOWRATE_PIT_SUM', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                ----EXEC SP_IFRS_PD_MAA_FLOWRATE_PIT_SUM 
                ----     @DOWNLOAD_DATE = @V_PRCDATE, 
                ----     @MODEL_ID = @RULE_ID;
                EXEC SP_IFRS_EXEC_AND_LOG 
                     @P_SP_NAME = 'SP_IFRS_PD_MAA_FLOWRATE_SUM', 
                     @DOWNLOAD_DATE = @V_PRCDATE, 
                     @P_PRC_NAME = 'IMP-PD', 
                     @EXECUTE_FLAG = 'Y', 
                     @PARAMETER = @PARAM_NONTYPE;
                --EXEC SP_IFRS_PD_MAA_FLOWRATE_SUM 
                --     @DOWNLOAD_DATE = @V_PRCDATE, 
                --     @MODEL_ID = @RULE_ID;
                -- ======================                            
                -- GENERATE Z USING R SCRIPT VIA BAT                             
                -- ======================                     
                -- EXEC SP_IFRS_PD_GENERATE_Z_FROM_R @MODEL_ID = @RULE_ID                      

                SET @V_PRCDATE = EOMONTH(DATEADD(MONTH, 1, @V_PRCDATE));
            END;
			*/
    END;
GO
