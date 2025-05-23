USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_STG_SEQUENCE]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_STG_SEQUENCE]    
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
    
    
 BEGIN TRY    
  SET @V_SESSIONID = @@SPID ;    
    
  SELECT  @v_currdate = currdate ,    
  @v_prevdate = prevdate    
  FROM    IFRS_PRC_DATE_AMORT    
    
  DELETE  FROM IFRS_AMORT_LOG    
  WHERE   DOWNLOAD_DATE = @v_currdate    
    
  DELETE  FROM IFRS_STATISTIC    
  WHERE   DOWNLOAD_DATE = @v_currdate    
  AND PRC_NAME = 'AMT'    
    
  INSERT  INTO IFRS_AMORT_LOG    
  ( DOWNLOAD_DATE ,    
  DTM ,    
  OPS ,    
  PROCNAME ,    
  REMARK    
  )    
  VALUES  ( @v_currdate ,    
  CURRENT_TIMESTAMP ,    
  'START' ,    
  'SP_IFRS_SYNC_STG_SEQUENCE' ,    
  ''    
  )  
  
  --SYNC IFRS_STG_MASTER_ACCOUNT TO IFRS_MASTER_ACCOUNT    
  SET @V_SPNAME = 'SP_IFRS_SYNC_MASTER_ACCOUNT';     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'    
    
  --SYNC IFRS_STG_TRANSACTION_DAILY TO IFRS_TRANSACTION_DAILY    
  SET @V_SPNAME = 'SP_IFRS_SYNC_TRANS_DAILY';     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'  
  
  --SYNC IFRS_STG_TRANSACTION_DAILY TO IFRS_TRX_FACILITY_HEADER    
  SET @V_SPNAME = 'SP_IFRS_SYNC_FACILITY';     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'  
  
  --SYNC IFRS_STG_LND TO IFRS_STG_PAYM_SCHD    
  SET @V_SPNAME = 'SP_IFRS_SYNC_PAYM_SCHD';     
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'    
    
  --SYNC IFRS_STG_MASTER_ACCOUNT TO IFRS_MASTER_CUSTOMER_RATING  
  SET @V_SPNAME = 'SP_IFRS_SYNC_CUSTOMER_RATING';  
  EXEC SP_IFRS_EXEC_AND_LOG @V_SPNAME, 'AMT'  
  
  INSERT  INTO IFRS_AMORT_LOG    
  ( DOWNLOAD_DATE ,    
  DTM ,    
  OPS ,    
  PROCNAME ,    
  REMARK    
  )    
  VALUES  ( @v_currdate ,    
  CURRENT_TIMESTAMP ,    
  'END' ,    
  'SP_IFRS_SYNC_STG_SEQUENCE' ,    
  ''    
  )      
    
 END TRY    
    
 BEGIN CATCH    
    
  DECLARE @ErrorSeverity INT ,    
    @ErrorState INT ,    
    @ErrorMessageDescription NVARCHAR(4000) ,    
    @DateProcess VARCHAR(100) ;         
    
  SELECT  @DateProcess = CONVERT(VARCHAR(20), GETDATE(), 107)      
    
  SELECT  @V_ERRM = ERROR_MESSAGE() ,    
    @ErrorSeverity = ERROR_SEVERITY() ,    
    @ErrorState = ERROR_STATE() ;        
    
  UPDATE  A    
  SET     A.END_DATE = GETDATE() ,    
  ISCOMPLETE = 'N' ,    
  REMARK = @V_ERRM    
  FROM    IFRS_STATISTIC A    
  WHERE   A.DOWNLOAD_DATE = @v_currdate    
  AND A.SP_NAME = @V_SPNAME ;    
    
  UPDATE  IFRS_PRC_DATE_AMORT    
  SET     BATCH_STATUS = 'ERROR!!..' ,    
  Remark = @V_ERRM ,    
  Last_Process_Date = GETDATE() ;        
    
  SET @ErrorMessageDescription = @V_SPNAME + ' ( ' + @DateProcess + ' ) --> ' + @V_ERRM        
    
  RAISERROR (@ErrorMessageDescription, 11, 1)    
  RETURN;  
 END CATCH;    
    
END; 


GO
