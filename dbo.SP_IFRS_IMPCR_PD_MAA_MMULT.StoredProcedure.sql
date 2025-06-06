USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_PD_MAA_MMULT]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROC [dbo].[SP_IFRS_IMPCR_PD_MAA_MMULT] 
@DOWNLOAD_DATE DATE ='',
@RULE_ID BIGINT = 0  
AS   
BEGIN  
    DECLARE @V_CURRDATE DATE                                                                        
    DECLARE @V_PREVDATE DATE          
    DECLARE @V_PREVMONTH DATE       
  
    IF @DOWNLOAD_DATE <> ''        
    BEGIN         
        SET @V_CURRDATE = EOMONTH(DATEADD(MONTH,-1,@DOWNLOAD_DATE)) -- LAG -1 MONTH BTPN        
        SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)        
        SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))        
    END        
    ELSE         
    BEGIN         
        SELECT @V_CURRDATE = EOMONTH(DATEADD(M,-1,CURRDATE)) FROM IFRS_PRC_DATE        
        SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)        
        SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))   
    END        
        
    DELETE [IFRS_PD_MAA_MMULT] WHERE TO_DATE = @V_CURRDATE AND PD_RULE_ID = @RULE_ID  
  
    DECLARE @PD_RULE_ID INT   
  
    DECLARE LOOP1             
    CURSOR FOR 
        SELECT DISTINCT PKID 
        FROM IFRS_PD_RULES_CONFIG 
        WHERE 
            PKID = @RULE_ID
            AND PD_METHOD = 'MAA' 
            AND ACTIVE_FLAG = 1 
            AND IS_DELETE  = 0  
    OPEN LOOP1      
    FETCH LOOP1 INTO @PD_RULE_ID   
  
    WHILE @@FETCH_STATUS = 0       
    BEGIN      
  
        IF OBJECT_ID ('TEMPDB.DBO.#BASE_MAA_MMULT') IS NOT NULL DROP TABLE #BASE_MAA_MMULT  
        SELECT *
        INTO #BASE_MAA_MMULT 
        FROM [IFRS_PD_MAA_AVERAGE] 
        WHERE 
            TO_DATE = @V_CURRDATE 
            AND BUCKET_TO <> 0 
            AND PD_RULE_ID = @PD_RULE_ID -- EXCLUDE FOR FP  
  
        DECLARE @MAX_SEQ INT  
        DECLARE @MIN_SEQ INT = 1  
        SELECT @MAX_SEQ = EXPECTED_LIFE/INCREMENT_PERIOD 
        FROM IFRS_PD_RULES_CONFIG  
        WHERE 
            PD_METHOD = 'MAA' 
            AND ACTIVE_FLAG = 1 
            AND IS_DELETE  = 0 
            AND PKID = @PD_RULE_ID  
  
        -- FIRST YEAR SAME WITH AVERAGE BASE DATE  
        IF @MIN_SEQ = 1   
        BEGIN   
            INSERT INTO  [IFRS_PD_MAA_MMULT] 
            (
                DOWNLOAD_DATE  
                ,TO_DATE  
                ,PD_RULE_ID  
                ,PD_RULE_NAME  
                ,FL_SEQ  
                ,BUCKET_FROM  
                ,BUCKET_TO  
                ,MMULT  
                ,CREATEDBY  
                ,CREATEDDATE
            )  
            SELECT 
                DOWNLOAD_DATE  
                ,@V_CURRDATE AS TO_DATE  
                ,PD_RULE_ID  
                ,PD_RULE_NAME  
                ,1 AS FL_SEQ  
                ,BUCKET_FROM  
                ,BUCKET_TO  
                , AVERAGE_RATE AS  MMULT  
                ,'SP_IFRS_IMP_PD_MAA_AVERAGE' AS CREATEDBY  
                ,GETDATE() AS CREATEDDATE  
            FROM #BASE_MAA_MMULT
            WHERE PD_RULE_ID = @PD_RULE_ID  
        END  
  
        SET @MIN_SEQ = 2  
        WHILE @MIN_SEQ <= @MAX_SEQ  
        BEGIN  
  
            IF OBJECT_ID ('TEMPDB.DBO.#CURR_MAA_MMULT') IS NOT NULL DROP TABLE #CURR_MAA_MMULT  
            SELECT * INTO #CURR_MAA_MMULT 
            FROM [IFRS_PD_MAA_MMULT] 
            WHERE 
                TO_DATE = @V_CURRDATE 
                AND FL_SEQ = @MIN_SEQ-1 
                AND PD_RULE_ID = @PD_RULE_ID  
  
            INSERT INTO [IFRS_PD_MAA_MMULT] 
            (
                DOWNLOAD_DATE  
                ,TO_DATE  
                ,PD_RULE_ID  
                ,PD_RULE_NAME  
                ,FL_SEQ  
                ,BUCKET_FROM  
                ,BUCKET_TO  
                ,MMULT  
                ,CREATEDBY  
                ,CREATEDDATE
            )  
            SELECT 
                A.DOWNLOAD_DATE  
                ,A.TO_DATE  
                ,A.PD_RULE_ID  
                ,A.PD_RULE_NAME  
                ,@MIN_SEQ AS FL_SEQ  
                ,B.BUCKET_FROM AS BUCKET_FROM  
                ,A.BUCKET_TO  
                ,SUM(A.AVERAGE_RATE*B.MMULT) AS MMULT  
                ,'SP_IFRS_IMP_PD_MAA_AVERAGE'  AS CREATEDBY  
                ,GETDATE() AS CREATEDDATE  
            FROM #BASE_MAA_MMULT A 
            INNER JOIN #CURR_MAA_MMULT B 
            ON A.PD_RULE_ID = B.PD_RULE_ID AND A.BUCKET_FROM = B.BUCKET_TO  
            WHERE A.PD_RULE_ID = @PD_RULE_ID  
            GROUP BY   
                A.DOWNLOAD_DATE  
                ,A.TO_DATE  
                ,A.PD_RULE_ID  
                ,A.PD_RULE_NAME  
                ,B.BUCKET_FROM   
                ,A.BUCKET_TO  
  
            SET @MIN_SEQ = @MIN_SEQ +1   
        END   
  
        FETCH NEXT FROM LOOP1 INTO  @PD_RULE_ID  
    END       
    CLOSE LOOP1      
    DEALLOCATE LOOP1        
END

GO
