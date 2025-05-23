USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_AMORT_SEQUENCE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE  PROCEDURE [dbo].[SP_IFRS_LI_AMORT_SEQUENCE] @DOWNLOAD_DATE DATE = NULL                 
AS                  
BEGIN                  
                  
    DECLARE @V_CURRDATE DATE                  
    DECLARE @V_PREVDATE DATE                  
    DECLARE @V_SPNAME VARCHAR(100)                  
    DECLARE @VCNT BIGINT                  
    DECLARE @V_SESSIONID VARCHAR(100)                  
    DECLARE @V_ERRN INTEGER                  
    DECLARE @V_ERRM VARCHAR(255)                  
    DECLARE @STEPDESCRIPTION VARCHAR(200)                  
                          
 BEGIN TRY                  
 SET @V_SESSIONID = @@SPID  
   
 IF @DOWNLOAD_DATE IS NULL    
 BEGIN    
     SELECT  @V_CURRDATE = CURRDATE FROM IFRS_LI_PRC_DATE_AMORT    
 END    
 ELSE    
 BEGIN    
     SET @V_CURRDATE = @DOWNLOAD_DATE
	 UPDATE IFRS_LI_PRC_DATE_AMORT SET CURRDATE = @V_CURRDATE, PREVDATE = DATEADD(DD, -1, @V_CURRDATE)
 END          
 SET @V_PREVDATE = DATEADD(DD, -1, @V_CURRDATE)                             
                  
 DELETE IFRS_LI_AMORT_LOG                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
                  
 DELETE IFRS_STATISTIC                  
 WHERE DOWNLOAD_DATE = @V_CURRDATE                  
 AND PRC_NAME = 'LI_AMT'                  
                  
 INSERT  INTO IFRS_LI_AMORT_LOG                  
 (                   
  DOWNLOAD_DATE,                  
  DTM,                  
  OPS,                  
  PROCNAME,                  
  REMARK                  
 )                  
 VALUES                    
 (                   
  @V_CURRDATE,                  
  CURRENT_TIMESTAMP,                  
  'START',                  
  'SP_IFRS_LI_AMORT_SEQUENCE',                  
  ''                  
 )                      
                    
SET @V_SPNAME = 'SP_IFRS_LI_RESET_AMT_PRC'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                     
                  
SET @V_SPNAME = 'SP_IFRS_LI_SYNC_PRODUCT_PARAM'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
SET @V_SPNAME = 'SP_IFRS_LI_SYNC_TRANS_PARAM'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
SET @V_SPNAME = 'SP_IFRS_LI_SYNC_JOURNAL_PARAM'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                
               
SET @V_SPNAME = 'SP_IFRS_LI_SYNC_UPLOAD_TRAN_DAILY'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                          
                                            
SET @V_SPNAME = 'SP_IFRS_LI_INITIAL_UPDATE'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
SET @V_SPNAME = 'SP_IFRS_LI_FILL_IMA_PREV_CURR'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
SET @V_SPNAME = 'SP_IFRS_LI_ACCT_CLOSED'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
SET @V_SPNAME = 'SP_IFRS_LI_PROCESS_TRAN_DAILY'                  
EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                       
 SET @V_SPNAME = 'SP_IFRS_LI_COST_FEE_STATUS'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_COST_FEE_SUMM'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SWITCH'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_SWITCH'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_SWITCH'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 -- EIR ENGINE                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_ACF_PMTDT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'            
                   
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_ECF_EVENT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 -- GENERATE PAYMENT SCHEDULE                        
 SET  @V_SPNAME = 'SP_IFRS_LI_PAYM_SCHD_FUNDING'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'          
                        
 SET  @V_SPNAME = 'SP_IFRS_LI_PAYM_SCHD_SRC'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'         
                        
 SET  @V_SPNAME = 'SP_IFRS_LI_EXCEPTION_REPORT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                                   
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_ECF_MAIN'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                     
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_ACF_ACRU'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_UPD_ACRU'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_LAST_ACF'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_JRNL_INTM'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 --SL ENGINE                     
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_ACF_PMTDATE'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_ECF_EVENT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_ECF_MAIN'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_ACF_ACCRU'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_UPD_ACRU'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_LAST_ACF'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 -- UPDATE UNAMORTIZED PMA SL THEN EIR                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_UPD_UNAMRT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                        
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_SL_JRNL_INTM'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_EIR_UPD_UNAMRT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 -- JOURNAL SUMMARY                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_JRNL_INTM_SUMM'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_CFID_JRNL_INTM_SUMM'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 SET @V_SPNAME = 'SP_IFRS_LI_JRNL_ACF_ABN_ADJ'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 --JOURNAL DATA                  
 SET @V_SPNAME = 'SP_IFRS_LI_ACCT_JOURNAL_DATA'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                   
 --GL OUTBOUND                  
 SET @V_SPNAME = 'SP_IFRS_LI_GL_OUTBOUND'                 
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 --IFRS RECON REPORT  20180501                  
 SET @V_SPNAME = 'SP_IFRS_LI_REPORT_RECON'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 --[SP_IFRS_LI_NOMINATIF]  20180501                  
 SET @V_SPNAME = 'SP_IFRS_LI_NOMINATIF'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                         
 --[SP_IFRS_LI_TREASURY_NOMINATIF]                      
 SET @V_SPNAME = 'SP_IFRS_LI_TREASURY_NOMINATIF'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                      
                  
 --CHECK AMORT                  
 SET @V_SPNAME = 'SP_IFRS_LI_CHECK_AMORT'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 --CHECK AMORT NO CF                  
 SET @V_SPNAME = 'SP_IFRS_LI_CHECK_AMORT_NOCF'                  
 EXEC SP_IFRS_LI_EXEC_AND_LOG @V_SPNAME, 'LI_AMT'                  
                  
 INSERT  INTO IFRS_LI_AMORT_LOG                  
 (                   
  DOWNLOAD_DATE,                  
  DTM,                  
  OPS,                  
  PROCNAME,                  
 REMARK                  
 )                  
 VALUES                  
 (                   
  @V_CURRDATE,                  
  CURRENT_TIMESTAMP,                  
  'END',                  
  'SP_IFRS_LI_AMORT_SEQUENCE',                  
  ''                  
 )                   
                  
 END TRY                  
                  
    BEGIN CATCH                       
                  
  DECLARE                   
   @ERRORSEVERITY INT,                  
   @ERRORSTATE INT,                  
   @ERRORMESSAGEDESCRIPTION NVARCHAR(4000),                  
   @DATEPROCESS VARCHAR(100)                      
                  
  SELECT  @DATEPROCESS = CONVERT(VARCHAR(20), GETDATE(), 107)                   
                  
  SELECT                    
   @V_ERRM = ERROR_MESSAGE(),                  
   @ERRORSEVERITY = ERROR_SEVERITY(),                  
   @ERRORSTATE = ERROR_STATE()                           
                  
  UPDATE  A                  
  SET                       
   A.END_DATE = GETDATE(),                  
   ISCOMPLETE = 'N',                  
   REMARK = @V_ERRM                  
  FROM    IFRS_STATISTIC A              
  WHERE   A.DOWNLOAD_DATE = @V_CURRDATE                  
   AND A.SP_NAME = @V_SPNAME                  
                  
  UPDATE  IFRS_LI_PRC_DATE_AMORT                  
  SET                       
   BATCH_STATUS = 'ERROR!!..',                  
   REMARK = @V_ERRM,                  
   LAST_PROCESS_DATE = GETDATE()                     
                  
  SET @ERRORMESSAGEDESCRIPTION = @V_SPNAME + ' ( ' + @DATEPROCESS + ' ) --> ' + @V_ERRM                    
                  
  RAISERROR (@ERRORMESSAGEDESCRIPTION, 11, 1)    
  RETURN                  
 END CATCH                  
END

GO
