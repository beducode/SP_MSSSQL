USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_EXEC_AND_LOG_PROCESS]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_EXEC_AND_LOG_PROCESS]  
(  
 @p_SP_NAME VARCHAR(100),  
 @p_PRC_NAME VARCHAR(10) = 'AMT',  
 @EXECUTE_FLAG CHAR(1) = 'Y'  
)  
AS  
BEGIN  
 DECLARE @V_Counter INT,  
 @V_ERRN INT,  
 @V_ERRM VARCHAR(255),  
 @V_CURRDATE DATE,  
 @V_max_Counter INT= 0,  
 @v_prevdate DATE,  
 @v_sessionid VARCHAR(32),  
 @V_COUNT INT,  
 @v_str_sql VARCHAR(100),  
 @v_MinStartDateSession DATETIME,  
 @v_SP_NAME VARCHAR(50),  
 @v_PRC_NAME VARCHAR(3)  
  
BEGIN TRY  
 SET @v_SP_NAME = @p_SP_NAME  
 SET @v_PRC_NAME = @p_PRC_NAME  
  
 IF @v_PRC_NAME = 'AMT'  
 BEGIN  
  SELECT @v_currdate = currdate,  
   @v_prevdate = prevdate,  
   @v_sessionid = sessionid  
  FROM IFRS_PRC_DATE_AMORT  
 END  
 ELSE IF @v_PRC_NAME IN ('STG', 'FET')  
 BEGIN  
  SELECT @v_currdate = currdate,  
  @v_prevdate = prevdate,  
  @v_sessionid = sessionid  
  FROM IFRS9_STG..STG_PRC_DATE  
 END  
 ELSE   
 BEGIN  
  SELECT @v_currdate = currdate,  
  @v_prevdate = prevdate,  
  @v_sessionid = sessionid  
  FROM IFRS_PRC_DATE   
 END  
  
 SELECT @V_Counter = ISNULL(MAX(counter), 0) + 1,  
 @v_MinStartDateSession = ISNULL(MIN(start_date),CURRENT_TIMESTAMP)  
 FROM IFRS_STATISTIC  
 WHERE PRC_NAME = @v_PRC_NAME AND  
 DOWNLOAD_DATE = @V_CURRDATE  
  
 UPDATE IFRS_PRC_DATE_AMORT  
 SET BATCH_STATUS = 'Running..',  
 REMARK = @v_SP_NAME   
  
 UPDATE IFRS_PRC_DATE  
 SET BATCH_STATUS = 'Running..',  
 REMARK = @v_SP_NAME  
  
 UPDATE IFRS9_STG..STG_PRC_DATE  
 SET BATCH_STATUS = 'Running..',  
 REMARK = @v_SP_NAME  
  
 DELETE IFRS_STATISTIC   
 WHERE DOWNLOAD_DATE = @v_currdate   
 and SP_NAME = @v_SP_NAME   
 and PRC_NAME = @v_PRC_NAME  
  
 IF @V_PRC_NAME = 'AMT'  
 BEGIN  
  INSERT INTO IFRS_STATISTIC  
  (   
   DOWNLOAD_DATE,  
   SP_NAME,  
   START_DATE,  
   ISCOMPLETE,  
   COUNTER,  
   PRC_NAME,  
   SESSIONID,  
   REMARK  
  )  
  SELECT CURRDATE,  
  @v_SP_NAME,  
  CURRENT_TIMESTAMP,  
  'N',  
  @V_Counter,  
  @v_PRC_NAME,  
  @v_sessionid,  
  'Running..'  
  FROM IFRS_PRC_DATE_AMORT  
 END  
 ELSE IF @V_PRC_NAME IN ('STG', 'FET')   
 BEGIN  
  INSERT INTO IFRS_STATISTIC  
  (   
   DOWNLOAD_DATE,  
   SP_NAME,  
   START_DATE,  
   ISCOMPLETE,  
   COUNTER,  
   PRC_NAME,  
   SESSIONID,  
   REMARK  
  )  
  SELECT CURRDATE,  
  @v_SP_NAME,  
  CURRENT_TIMESTAMP,  
  'N',  
  @V_Counter,  
  @v_PRC_NAME,  
  @v_sessionid,  
  'Running..'  
  FROM IFRS9_STG..STG_PRC_DATE  
 END  
 ELSE  
 BEGIN  
  INSERT INTO IFRS_STATISTIC  
  (   
   DOWNLOAD_DATE,  
   SP_NAME,  
   START_DATE,  
   ISCOMPLETE,  
   COUNTER,  
   PRC_NAME,  
   SESSIONID,  
   REMARK  
  )  
  SELECT CURRDATE,  
  @v_SP_NAME,  
  CURRENT_TIMESTAMP,  
  'N',  
  @V_Counter,  
  @v_PRC_NAME,  
  @v_sessionid,  
  'Running..'  
  FROM IFRS_PRC_DATE  
 END  
  
 IF @EXECUTE_FLAG = 'Y'   
 BEGIN  
  SET @v_str_sql = @v_SP_NAME  
  EXECUTE @v_str_sql  
 END  
  
 UPDATE IFRS_STATISTIC  
 SET END_DATE = CURRENT_TIMESTAMP,  
  ISCOMPLETE = 'Y',  
  PRC_PROCESS_TIME = dbo.Fn_GetProcessTime(START_DATE,CURRENT_TIMESTAMP),  
  REMARK = 'SUCCEED'  
 WHERE DOWNLOAD_DATE = @V_CURRDATE  
 AND SP_NAME = @v_SP_NAME  
 AND PRC_NAME = @v_PRC_NAME  
  
 UPDATE IFRS_STATISTIC  
 SET SESSION_PROCESS_TIME = dbo.Fn_GetProcessTime(@v_MinStartDateSession,GETDATE())  
 WHERE DOWNLOAD_DATE = @V_CURRDATE   
 -- AND sessionid = @v_sessionid  
 AND PRC_NAME = @v_PRC_NAME  
  
 UPDATE IFRS_PRC_DATE_AMORT  
 SET BATCH_STATUS = 'Finished',  
 REMARK = 'Execute ' + @v_SP_NAME + ' is Succeed',  
 LAST_PROCESS_DATE = CURRDATE  
  
 UPDATE  IFRS_PRC_DATE  
 SET BATCH_STATUS = 'Finished',  
 REMARK = 'Execute ' + @v_SP_NAME + ' is Succeed',  
 LAST_PROCESS_DATE = CURRDATE  
  
END TRY  
  
BEGIN CATCH  
 SELECT  @V_ERRN = ERROR_NUMBER()  
 SELECT  @V_ERRM = ERROR_MESSAGE()  
    
 UPDATE  IFRS_STATISTIC  
 SET END_DATE = CURRENT_TIMESTAMP,  
 ISCOMPLETE = 'N',  
 REMARK = 'Error - ' + CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM  
 WHERE   DOWNLOAD_DATE = @V_CURRDATE  
 AND SP_NAME = @v_SP_NAME AND PRC_NAME = @v_PRC_NAME   
  
 UPDATE  IFRS_PRC_DATE_AMORT  
 SET RUNNING_FLAG_FROM_DW = 'N',  
 BATCH_STATUS = 'Error!!',  
 REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @v_PRC_NAME + ')'  
  
 UPDATE  IFRS_PRC_DATE  
 SET BATCH_STATUS = 'Error!!',  
 REMARK = CAST(@V_ERRN AS VARCHAR(50)) + ' ' + @V_ERRM + ' (' + @v_PRC_NAME + ')'  
  
    
 RAISERROR (@V_ERRM,   -- Message text.  
  16, -- Severity,  
  1 -- State  
 );
 RETURN;
  
END CATCH   
END


GO
