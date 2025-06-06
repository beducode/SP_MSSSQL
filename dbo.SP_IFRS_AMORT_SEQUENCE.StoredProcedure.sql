USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_AMORT_SEQUENCE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_AMORT_SEQUENCE]    
@DOWNLOAD_DATE DATE = NULL    
AS                                       
BEGIN                                      
                                      
 DECLARE @v_currdate DATE                                      
 DECLARE @v_prevdate DATE                                      
 DECLARE @V_SPNAME VARCHAR(100)                                      
 DECLARE @vcnt BIGINT                                      
 DECLARE @V_SESSIONID VARCHAR(100)                                      
 DECLARE @V_ERRN INTEGER                                      
 DECLARE @V_ERRM VARCHAR(255)                                      
 DECLARE @StepDescription VARCHAR(200)                           
 DECLARE @PARAM_WITHPRC VARCHAR(MAX)                           
 DECLARE @PARAM_WITHPRCFLAG VARCHAR(MAX)                           
                                 
 BEGIN TRY                                      
    SET @V_SESSIONID = @@SPID;                                      
    
    IF @DOWNLOAD_DATE IS NULL    
    BEGIN    
        SELECT  @v_currdate = currdate FROM IFRS_PRC_DATE_AMORT    
    END    
    ELSE    
    BEGIN    
        SET @v_currdate = @DOWNLOAD_DATE    
    END          
    SET @v_prevdate = DATEADD(DD, -1, @v_currdate)              
        
    SET @PARAM_WITHPRC = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRDATE), 'NULL') + '''';                       
    SET @PARAM_WITHPRCFLAG = '@DOWNLOAD_DATE = ''' + ISNULL(CONVERT(VARCHAR(50), @V_CURRDATE), 'NULL') + ''', @FLAG = ''A''';                                       
                                      
  DELETE  FROM IFRS_AMORT_LOG                                      
  WHERE   DOWNLOAD_DATE = @v_currdate                                      
                                      
  DELETE  FROM IFRS_STATISTIC                                      
  WHERE   DOWNLOAD_DATE = @v_currdate AND PRC_NAME = 'AMT'                
                
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
                                      
  INSERT  INTO IFRS_AMORT_LOG                                      
  (                                   
   DOWNLOAD_DATE,                                      
   DTM,                                      
   OPS,                                      
   PROCNAME,                                      
   REMARK                                      
  )                                      
  VALUES                                  
  (                                  
   @v_currdate,                                      
   CURRENT_TIMESTAMP,                                      
   'START',                                      
   'SP_IFRS_AMORT_SEQUENCE',                                      
   ''      
  )                                      
                                     
  SET @V_SPNAME = 'SP_IFRS_RESET_AMT_PRC';                 
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                   
  /* -- OPEN COMMENT BY SAID */                                            
  SET @V_SPNAME = 'SP_IFRS_SYNC_PRODUCT_PARAM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'       
                                                  
  SET @V_SPNAME = 'SP_IFRS_SYNC_TRANS_PARAM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_SYNC_JOURNAL_PARAM';                                      
EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                               
  /* -- END OPEN COMMENT BY SAID */                                      
                  
  SET @V_SPNAME = 'SP_IFRS_SYNC_UPLOAD_TRAN_DAILY';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                    
                        
SET @V_SPNAME = 'SP_IFRS_AC_SYNC_LIST_VALUE';                                  
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                
                                                 
  SET @V_SPNAME = 'SP_IFRS_INITIAL_UPDATE';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                     
                                                     
  SET @V_SPNAME = 'SP_IFRS_TRX_PRORATE';                                                    
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                    
                          
  SET @V_SPNAME = 'SP_IFRS_FILL_IMA_AMORT_PREV_CURR';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                          
                                                          
  SET @V_SPNAME = 'SP_IFRS_ACCT_AMORT_RESTRU';     -- BTPN RESTRUCTURE                                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                               
                                                  
  SET @V_SPNAME = 'SP_IFRS_ACCT_CLOSED';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                                  
  SET @V_SPNAME = 'SP_IFRS_PROCESS_TRAN_DAILY';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                    
                                      
  SET @V_SPNAME = 'SP_IFRS_COST_FEE_STATUS';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_COST_FEE_SUMM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SWITCH';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_SWITCH';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_SWITCH';                                                       
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                    
                                                      
  -- EIR ENGINE                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_ACF_PMTDT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_ECF_EVENT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'          
                      
  -- Generate Payment Schedule                                      
  SET  @V_SPNAME = 'SP_IFRS_PAYM_SCHD';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                
                            
  --ADD CTBC                                    
  --MARK TO MARKET                                        
  SET @V_SPNAME = 'SP_IFRS_PAYM_SCHD_MTM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                  
                                    
                                
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_ECF_MAIN';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_STAFF_BENEFIT_SUMM';                                     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                     
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_ACF_ACRU';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_UPD_ACRU';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                           
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_LAST_ACF';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_JRNL_INTM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                             
  --START ENGINE BELOW MARKET                                    
  SET @V_SPNAME = 'SP_IFRS_LBM_RESET_AMT_PRC';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                                      
  --ADD LBM EIR SWITCH 20180823                                                      
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_SWITCH';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                       
  --END ADD 20180823                                                      
                                       
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_ACF_PMTDT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                        
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_ECF_EVENT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT', 'N'                                     
                                    
  SET @V_SPNAME = 'SP_LBM_SYNC_PAYM_CORE';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                              
                                    
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_ECF_MAIN';                                    
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_LBM_STAFF_BENEFIT_SUMM';                           
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_ACF_ACRU';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_UPD_ACRU';                                  
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
               
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_LAST_ACF';                 
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_JRNL_INTM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                     
                                    
  SET @V_SPNAME = 'SP_IFRS_LBM_ACCT_EIR_UPD_UNAMRT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                  
  --END ENGINE BELOW MARKET                                               
                                    
  --SL ENGINE                                                
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_ACF_PMTDATE';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_ECF_EVENT';                              
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_ECF_MAIN';                                     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_ACF_ACCRU';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                    
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_UPD_ACRU';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_LAST_ACF';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                                
  -- update unamortized pma SL then EIR                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_UPD_UNAMRT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                     
  SET @V_SPNAME = 'SP_IFRS_ACCT_SL_JRNL_INTM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                          
  SET @V_SPNAME = 'SP_IFRS_ACCT_EIR_UPD_UNAMRT';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                               
                              
  -- JOURNAL SUMMARY                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_JRNL_INTM_SUMM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                         
  SET @V_SPNAME = 'SP_IFRS_CFID_JRNL_INTM_SUMM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  SET @V_SPNAME = 'SP_IFRS_JRNL_ACF_ABN_ADJ';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                       
                                                  
  --JOURNAL DATA                                      
  SET @V_SPNAME = 'SP_IFRS_ACCT_JOURNAL_DATA';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                     
             
  SET @V_SPNAME = 'SP_IFRS_ACCT_JRNL_DATA_MTM';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                       
                                      
  --GL OUTBOUND                                      
  SET @V_SPNAME = 'SP_IFRS_GL_OUTBOUND';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                
      
  --IFRS RECON REPORT  20180501                                    
  SET @V_SPNAME = 'SP_IFRS_REPORT_RECON';                                   
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                     
                                                    
  --IFRS LBM RECON REPORT 20180915                                  
  SET @V_SPNAME = 'SP_IFRS_LBM_REPORT_RECON';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                       
                                        
  --[SP_IFRS_NOMINATIF]  20180501                                    
  SET @V_SPNAME = 'SP_IFRS_NOMINATIF';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                  
                                                     
  --[SP_IFRS_TREASURY_NOMINATIF]                              
  SET @V_SPNAME = 'SP_IFRS_TREASURY_NOMINATIF';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                                  
                                      
  --CHECK AMORT                                      
  SET @V_SPNAME = 'SP_IFRS_CHECK_AMORT';                     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                      
  --CHECK AMORT NO CF                                      
  SET @V_SPNAME = 'SP_IFRS_CHECK_AMORT_NOCF';                                      
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'                                      
                                
-- EXCEPTION REPORT                                  
  SET @V_SPNAME = 'SP_IFRS_EXCEPTION_REPORT';                                         
  EXEC SP_IFRS_EXEC_AND_LOG                               
  @P_SP_NAME = @V_SPNAME,                                                                    
  @DOWNLOAD_DATE = @V_CURRDATE,                                              
  @P_PRC_NAME = 'AMT',                                            
  @EXECUTE_FLAG = 'Y',                           
  @PARAMETER = @PARAM_WITHPRCFLAG                
                                                 
                                      
  INSERT  INTO IFRS_AMORT_LOG                                                
  (                                                
   DOWNLOAD_DATE,                                                
   DTM,                                                
   OPS,                                                
   PROCNAME,                                                
   REMARK                                      
  )                          
  VALUES                                                
  (                                                
   @v_currdate,                                                
   CURRENT_TIMESTAMP,                                                
   'END',                                                
   'SP_IFRS_AMORT_SEQUENCE',                                                
   ''                                      
  )  
    
  UPDATE IFRS_LI_PRC_DATE_AMORT SET CURRDATE = @v_currdate, PREVDATE = @v_prevdate  
  EXEC SP_IFRS_LI_AMORT_SEQUENCE                                                  
                           
 END TRY                                      
                                      
 BEGIN CATCH                          
                  
  DECLARE @ErrorSeverity INT,                                      
  @ErrorState INT,                                      
  @ErrorMessageDescription NVARCHAR(4000),                                      
  @DateProcess VARCHAR(100);                                           
                                      
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
                                      
  UPDATE  IFRS_PRC_DATE_AMORT                                      
  SET     BATCH_STATUS = 'ERROR!!..',                                      
  Remark = @V_ERRM,                                      
  Last_Process_Date = GETDATE();                                         
                                      
  SET @ErrorMessageDescription = @V_SPNAME + ' ( ' + @DateProcess                                      
  + ' ) --> ' + @V_ERRM                                                      
                                      
    RAISERROR (@ErrorMessageDescription, 11, 1)                              
    RETURN          
 END CATCH;          
                                  
END; 
GO
