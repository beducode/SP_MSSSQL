USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMPCR_PD_CHR_RESULT]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMPCR_PD_CHR_RESULT]     
@DOWNLOAD_DATE DATE = '',                                             
@RULE_ID BIGINT = 0                  
AS               
BEGIN               
    DECLARE @V_CURRDATE DATE                                                                              
    DECLARE @V_PREVDATE DATE                
    DECLARE @V_PREVMONTH DATE             
    DECLARE @LAST_YEAR DATE            
    
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
      
    ---- CREATE TEMP TABEL MAKS TOTAL COUNT             
    IF OBJECT_ID ('TEMPDB.DBO.#TOTAL_COUNT_BUCKET') IS NOT NULL DROP TABLE #TOTAL_COUNT_BUCKET            
    SELECT PD_RULE_ID, BUCKET_ID, SUM(TOTAL_COUNT) AS TOTAL_COUNT_ALL    
    INTO #TOTAL_COUNT_BUCKET             
    FROM [IFRS_PD_CHR_SUMM]     
    WHERE     
        PROJECTION_DATE <= @V_CURRDATE     
        AND SEQ_YEAR = 1    
        AND PD_RULE_ID = @RULE_ID            
    GROUP BY  PD_RULE_ID, BUCKET_ID ORDER BY PD_RULE_ID, BUCKET_ID            
            
    ---- INSERT SUMMARY MARGINAL PD            
            
    DELETE [IFRS_PD_CHR_RESULT_YEARLY] WHERE PROJECTION_DATE = @V_CURRDATE AND PD_RULE_ID = @RULE_ID           
    
    INSERT INTO  [dbo].[IFRS_PD_CHR_RESULT_YEARLY]            
    (            
        DOWNLOAD_DATE            
        ,PROJECTION_DATE            
        ,PD_RULE_ID            
        ,PD_RULE_NAME            
        ,SEGMENT            
        ,CALC_METHOD            
        ,BUCKET_GROUP            
        ,BUCKET_ID            
        ,BUCKET_NAME            
        ,SEQ_YEAR            
        ,CUMULATIVE_PD_RATE            
        ,MARGINAL_PD_RATE            
    )            
    SELECT             
        EOMONTH(DATEADD(MONTH,MAX(B.INCREMENT_PERIOD)*-1,@V_CURRDATE)) AS DOWNLOAD_DATE            
        ,@V_CURRDATE AS PROJECTION_DATE            
        ,A.PD_RULE_ID            
        ,MAX(PD_RULE_NAME) AS PD_RULE_NAME            
        ,MAX(SEGMENT) AS SEGMENT            
        ,MAX(A.CALC_METHOD)            
        ,MAX(A.BUCKET_GROUP)            
        ,A.BUCKET_ID            
        ,MAX(BUCKET_NAME)            
        ,SEQ_YEAR            
        ,NULL AS CUMULATIVE_PD_RATE            
        ,CAST(SUM(MARGINAL_DEFAULT_COUNT) AS FLOAT)/CAST(MAX(C.TOTAL_COUNT_ALL) AS FLOAT) AS MARGINAL_PD_RATE             
    FROM [IFRS_PD_CHR_SUMM] A             
    INNER JOIN IFRS_PD_RULES_CONFIG B  ON A.PD_RULE_ID = B.PKID            
    LEFT JOIN #TOTAL_COUNT_BUCKET C ON A.PD_RULE_ID = C.PD_RULE_ID  AND A.BUCKET_ID = C.BUCKET_ID            
    WHERE A.DOWNLOAD_DATE <= EOMONTH(DATEADD(MONTH,B.INCREMENT_PERIOD*-1,@V_CURRDATE))  AND A.DOWNLOAD_DATE >= B.CUT_OFF_DATE       
    AND A.DOWNLOAD_DATE >= EOMONTH(DATEADD(MONTH,B.HISTORICAL_DATA*-1,@V_CURRDATE))    
    AND A.PD_RULE_ID = @RULE_ID    
    GROUP BY A.PD_RULE_ID,SEQ_YEAR,A.BUCKET_ID            
    ORDER BY A.PD_RULE_ID,SEQ_YEAR,A.BUCKET_ID            
           
    -- START UPDATE CUMULATIVE            
    IF OBJECT_ID ('TEMPDB.DBO.#CUMULATIVE') IS NOT NULL DROP TABLE #CUMULATIVE            
    SELECT *     
    INTO #CUMULATIVE     
    FROM [IFRS_PD_CHR_RESULT_YEARLY]     
    WHERE PROJECTION_DATE= @V_CURRDATE AND PD_RULE_ID = @RULE_ID    
            
    IF OBJECT_ID ('TEMPDB.DBO.#CUMULATIVE_PD_RESULT') IS NOT NULL DROP TABLE #CUMULATIVE_PD_RESULT            
    SELECT A.PD_RULE_ID, A.DOWNLOAD_DATE, A.BUCKET_ID, MAX(A.MARGINAL_PD_RATE) AS MARGINAL_PD_RATE,A.SEQ_YEAR,SUM(B.MARGINAL_PD_RATE) AS CUMULATIVE_PD_RATE INTO #CUMULATIVE_PD_RESULT            
    FROM [IFRS_PD_CHR_RESULT_YEARLY]  A     
    LEFT JOIN #CUMULATIVE B     
    ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.PD_RULE_ID = B.PD_RULE_ID              
    AND A.BUCKET_ID = B.BUCKET_ID AND B.SEQ_YEAR <= A.SEQ_YEAR            
    WHERE A.PROJECTION_DATE = @V_CURRDATE AND A.PD_RULE_ID = @RULE_ID            
    GROUP BY A.PD_RULE_ID, A.DOWNLOAD_DATE, A.BUCKET_ID,A.SEQ_YEAR            
    ORDER BY A.PD_RULE_ID,A.DOWNLOAD_DATE,A.BUCKET_ID,A.SEQ_YEAR            
            
    UPDATE A            
    SET A.CUMULATIVE_PD_RATE = B.CUMULATIVE_PD_RATE            
    FROM [IFRS_PD_CHR_RESULT_YEARLY] A             
    INNER JOIN #CUMULATIVE_PD_RESULT B     
    ON A.PD_RULE_ID = B.PD_RULE_ID AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.SEQ_YEAR  = B.SEQ_YEAR AND A.BUCKET_ID= B.BUCKET_ID            
    WHERE A.PROJECTION_DATE = @V_CURRDATE    
    AND A.PD_RULE_ID = @RULE_ID            
         
        
    /*      
    -- INSERT INTO TERM SCTRUCTURE YEARLY       
    DELETE [IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY]     
    WHERE     
        CURR_DATE  = @V_CURRDATE     
        AND CREATEDBY = 'SP_IFRS_IMP_PD_CHR_RESULT'     
        AND PD_RULE_ID = @RULE_ID    
      
    INSERT INTO [IFRS_PD_TERM_STRUCTURE_NOFL_YEARLY]      
    (    
        DOWNLOAD_DATE      
        ,CURR_DATE      
        ,PD_RULE_ID      
        ,PD_RULE_NAME      
        ,BUCKET_GROUP      
        ,BUCKET_ID      
        ,BUCKET_NAME      
        ,FL_SEQ      
        ,FL_YEAR      
        ,PD_RATE      
        ,CREATEDBY      
        ,CREATEDDATE      
    )      
    SELECT     
        DOWNLOAD_DATE      
        ,@V_CURRDATE AS CURR_DATE      
        ,PD_RULE_ID      
        ,PD_RULE_NAME      
        ,A.BUCKET_GROUP      
        ,A.BUCKET_ID      
        ,B.BUCKET_NAME      
        ,A.SEQ_YEAR AS FL_SEQ      
        ,A.SEQ_YEAR AS FL_YEAR      
        ,MARGINAL_PD_RATE AS PD_RATE      
        ,'SP_IFRS_IMP_PD_CHR_RESULT' AS CREATEDBY      
        ,GETDATE() AS CREATEDDATE     
    FROM [IFRS_PD_CHR_RESULT_YEARLY] A      
    JOIN IFRS_BUCKET_DETAIL B     
    ON A.BUCKET_GROUP = B.BUCKET_GROUP     
    WHERE A.PD_RULE_ID = @RULE_ID                
    */      
      
END 
GO
