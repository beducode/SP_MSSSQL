USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_CCF_SEQUENCE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[SP_IFRS_IMPCR_CCF_SEQUENCE]   
@PRC CHAR(1)  = 'S'  -- M = MANUAL, S = SYSTEM / CATCH UP                
AS  
    DECLARE  
        @V_CURRDATE DATE,  
        @V_PRCDATE DATE,  
        @PARAM_WITHTYPE VARCHAR(MAX),  
        @PARAM_NONTYPE VARCHAR(MAX),  
        @PARAM_WITHPRC VARCHAR(MAX),                  
        @V_ERRN INTEGER,  
        @V_ERRM VARCHAR(255),                  
        @V_SPNAME VARCHAR(100),                
        @RULE_ID INT,            
        @V_PRC_NAME VARCHAR(20);   
BEGIN     
    SET NOCOUNT ON;     
   
    SELECT @V_CURRDATE = EOMONTH(CURRDATE) FROM IFRS_PRC_DATE;              
                    
    DROP TABLE IF EXISTS #LOOP                
    CREATE TABLE #LOOP (PKID INT IDENTITY(1,1), RULE_ID INT)                
                
    INSERT INTO #LOOP (RULE_ID)                
    SELECT PKID AS RULE_ID                
    FROM IFRS_CCF_RULES_CONFIG                 
    WHERE RUNNING_STATUS = 'PENDING' AND IS_DELETE = 0 AND ACTIVE_FLAG = 1              
                
    IF EXISTS (SELECT * FROM #LOOP)                
    BEGIN TRY                
        DECLARE @START INT, @END INT                
        SELECT @START = MIN(PKID), @END = MAX(PKID) FROM #LOOP                
                
        WHILE @START <= @END                
        BEGIN                 
            SELECT @RULE_ID = RULE_ID FROM #LOOP WHERE PKID = @START                
                
            SELECT @V_PRCDATE =  
            CASE     
                WHEN @PRC = 'M' THEN @V_CURRDATE ELSE A.CUT_OFF_DATE  
            END     
            FROM IFRS_CCF_RULES_CONFIG A                         
            WHERE A.IS_DELETE = 0     
            AND A.ACTIVE_FLAG = 1     
            AND A.PKID = @RULE_ID   
            AND A.RUNNING_STATUS = 'PENDING';                  
     
            SET @V_PRC_NAME = CONCAT('IMPCR-CCF', '-', @RULE_ID)                  
            PRINT @V_PRCDATE    
                      
            SET @V_CURRDATE = CASE WHEN @V_CURRDATE = EOMONTH(@V_CURRDATE) THEN @V_CURRDATE ELSE    EOMONTH    (DATEADD(MM, -1, @V_CURRDATE)) END                      
   
            IF @V_CURRDATE IS NOT NULL OR @V_PRCDATE IS NOT NULL                    
            BEGIN                    
                UPDATE IFRS_CCF_RULES_CONFIG                    
                SET RUNNING_STATUS = 'RUNNING'                    
                WHERE RUNNING_STATUS = 'PENDING'                    
                AND PKID = @RULE_ID                    
                            
                WHILE @V_PRCDATE <= @V_CURRDATE     
                BEGIN         
     SET @PARAM_WITHTYPE = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_PRCDATE),  'NULL')  + ''', ' + '@MODEL_TYPE = ''CCF'', ' + '@RULE_ID = ' + ISNULL(CONVERT(VARCHAR (50), @RULE_ID), 'NULL');   
     SET @PARAM_NONTYPE = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_PRCDATE),   'NULL') +  ''', ' + '@RULE_ID = ' + ISNULL(CONVERT(VARCHAR(50), @RULE_ID), 'NULL');        
     SET @PARAM_WITHPRC = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_PRCDATE),   'NULL') +  ''', ' + '@RULE_ID = ' + ISNULL(CONVERT(VARCHAR(50), @RULE_ID), 'NULL')+ ', '  + '@PRC = ''' + ISNULL(CONVERT(VARCHAR(1), @PRC), 'NULL') + '''';       
  
    
     DELETE IFRS_STATISTIC                   
                    WHERE PRC_NAME = @V_PRC_NAME        
                    AND DOWNLOAD_DATE = @V_PRCDATE                  
                 
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_DEFAULT_RULE'                   
                    EXEC SP_IFRS_EXEC_AND_LOG  
                        @P_SP_NAME = @V_SPNAME,  
                        @DOWNLOAD_DATE = @V_PRCDATE,                    
                        @P_PRC_NAME = @V_PRC_NAME,                    
                        @EXECUTE_FLAG = 'Y',  
                        @PARAMETER = @PARAM_WITHTYPE;                  
                 
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_DEFAULT_RULE_NOLAG'                   
           EXEC SP_IFRS_EXEC_AND_LOG  
                        @P_SP_NAME = @V_SPNAME,  
                        @DOWNLOAD_DATE = @V_PRCDATE,                    
                        @P_PRC_NAME = @V_PRC_NAME,                    
                        @EXECUTE_FLAG = 'Y',  
                        @PARAMETER = @PARAM_WITHTYPE;                   
     
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_GENERATE_RULE_SEGMENT'  
                    EXEC SP_IFRS_EXEC_AND_LOG     
                        @P_SP_NAME = @V_SPNAME,  
                        @P_PRC_NAME = @V_PRC_NAME,  
                        @EXECUTE_FLAG = 'Y',  
                        @DOWNLOAD_DATE = @V_PRCDATE;                   
     
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_CCF_SCENARIO_DATA'  
                    EXEC SP_IFRS_EXEC_AND_LOG  
                        @P_SP_NAME = @V_SPNAME,  
                        @DOWNLOAD_DATE = @V_PRCDATE,  
                        @P_PRC_NAME = @V_PRC_NAME,  
                        @EXECUTE_FLAG = 'Y',  
                        @PARAMETER = @PARAM_WITHPRC;  
                
                    -------------------------------     
                    -- GENERATE    CCF   
                    -------------------------------                         
                      
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_EAD_CCF_DETAIL'                   
                    EXEC SP_IFRS_EXEC_AND_LOG                           
                        @P_SP_NAME = @V_SPNAME,  
                        @DOWNLOAD_DATE = @V_PRCDATE,  
                        @P_PRC_NAME = @V_PRC_NAME,  
                        @EXECUTE_FLAG = 'Y',  
                        @PARAMETER = @PARAM_NONTYPE;                     
     
                    SET @V_SPNAME = 'SP_IFRS_IMPCR_EAD_CCF_HEADER'  
                    EXEC SP_IFRS_EXEC_AND_LOG  
                        @P_SP_NAME = @V_SPNAME,                         
                        @DOWNLOAD_DATE = @V_PRCDATE,  
                        @P_PRC_NAME = @V_PRC_NAME,  
                        @EXECUTE_FLAG = 'Y',  
                        @PARAMETER = @PARAM_NONTYPE;  
                   
                    SET @V_PRCDATE = EOMONTH(DATEADD(MONTH, 1, @V_PRCDATE));     
                END                  
  
                UPDATE IFRS_CCF_RULES_CONFIG                    
                SET RUNNING_STATUS = 'COMPLETED'                    
                WHERE RUNNING_STATUS = 'RUNNING'                    
                AND PKID = @RULE_ID                     
            END                
            SET @START = @START + 1               
        END                
    END TRY                
                    
    BEGIN CATCH   
  
        DECLARE                   
            @ErrorSeverity INT,  
            @ErrorState INT,  
            @ErrorMessageDescription NVARCHAR(4000),  
            @DateProcess VARCHAR(100);  
   
        SELECT                  
            @DateProcess = CONVERT(VARCHAR(20), GETDATE(), 107),                  
			@V_ERRM = ERROR_MESSAGE(),  
            @ErrorSeverity = ERROR_SEVERITY(),  
            @ErrorState = ERROR_STATE();       
   
        UPDATE  A  
        SET     A.END_DATE = GETDATE(),  
        ISCOMPLETE = 'N',  
        REMARK = @V_ERRM  
        FROM    IFRS_STATISTIC A  
        WHERE   A.DOWNLOAD_DATE = @v_currdate  
        AND A.SP_NAME = @V_SPNAME                
        AND PRC_NAME = @V_PRC_NAME;                    
   
        UPDATE  IFRS_PRC_DATE  
        SET     BATCH_STATUS = 'ERROR!!..',  
        Remark = @V_ERRM,  
        Last_Process_Date = GETDATE();                  
                          
        UPDATE IFRS_CCF_RULES_CONFIG                  
        SET RUNNING_STATUS = 'FAILED'                  
        WHERE PKID = @RULE_ID                  
   
        SET @ErrorMessageDescription = @V_SPNAME + ' ( ' + @DateProcess + ' ) --> ' + @V_ERRM                  
   
        RAISERROR (@ErrorMessageDescription, 11, 1)   
        RETURN                          
    END CATCH   
END
GO
