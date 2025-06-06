USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SYNC_CORPORATE_DATA]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SYNC_CORPORATE_DATA]          
@DOWNLOAD_DATE DATE = NULL        
AS        
BEGIN        
 DECLARE @V_CURRDATE DATE        
 DECLARE @V_PREVDATE DATE        
 DECLARE @V_CURRDATE_CHAR VARCHAR(8)      
        
 IF @DOWNLOAD_DATE IS NULL        
 BEGIN        
  SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE        
 END        
 ELSE        
 BEGIN        
  SET @V_CURRDATE = @DOWNLOAD_DATE        
 END        
 SET @V_PREVDATE = EOMONTH(DATEADD(MM, -1, @V_CURRDATE))        
 SET @V_CURRDATE_CHAR = convert(varchar(8), @V_CURRDATE, 112)      
       
 ----------------------------------------      
 ---- START IFRS_PD_MASTERSCALE_CORP ----      
 ----------------------------------------      
 DELETE IFRS_PD_MASTERSCALE_CORP WHERE DOWNLOAD_DATE = @V_CURRDATE        
 IF EXISTS (SELECT TOP 1 * FROM TBLU_PD_MASTERSCALE  WHERE DOWNLOAD_DATE = @V_CURRDATE)        
 BEGIN        
  INSERT IFRS_PD_MASTERSCALE_CORP        
  (        
   DOWNLOAD_DATE        
   ,OBLIGOR_GRADE        
   ,PD        
   ,CREATEDBY        
   ,CREATEDDATE        
   ,CREATEDHOST         
  )        
  SELECT         
   DOWNLOAD_DATE        
   ,OBLIGOR_GRADE        
   ,PD        
   ,CREATEDBY        
   ,CREATEDDATE        
   ,CREATEDHOST         
  FROM TBLU_PD_MASTERSCALE        
  WHERE DOWNLOAD_DATE = @V_CURRDATE        
 END        
 ELSE        
 BEGIN        
  INSERT IFRS_PD_MASTERSCALE_CORP        
  (        
   DOWNLOAD_DATE        
   ,OBLIGOR_GRADE        
   ,PD        
   ,CREATEDBY        
   ,CREATEDDATE        
   ,CREATEDHOST         
  )        
  SELECT         
   @V_CURRDATE AS DOWNLOAD_DATE        
   ,OBLIGOR_GRADE        
   ,PD        
   ,CREATEDBY        
   ,CREATEDDATE        
   ,CREATEDHOST         
  FROM TBLU_PD_MASTERSCALE        
  WHERE DOWNLOAD_DATE = @V_PREVDATE        
 END         
 ---------------------------------------      
 ---- END IFRS_PD_MASTERSCALE_CORP -----      
 ---------------------------------------      
        
 ----------------------------------      
 ---- START IFRS_RECOVERY_CORP ----      
 ----------------------------------      
 DELETE IFRS_RECOVERY_CORP WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE        
        
 INSERT IFRS_RECOVERY_CORP        
 (        
  DOWNLOAD_DATE        
  ,DEFAULT_DATE        
  ,OS_AT_DEFAULT        
  ,CUSTOMER_NUMBER        
  ,CUSTOMER_NAME        
  ,PRODUCT_GROUP      
  ,CURRENCY      
  ,RECOVERY_DATE        
  ,NETT_RECOVERY        
  ,EIR_AT_DEFAULT        
  ,JAP_NON_JAP_IDENTIFIER        
  ,CREATEDBY        
  ,CREATEDDATE        
  ,CREATEDHOST        
 )        
 SELECT         
  CASE WHEN EOMONTH(DOWNLOAD_DATE) <= '20110131' THEN '20110131' ELSE EOMONTH(DOWNLOAD_DATE) END AS DOWNLOAD_DATE      
  ,DEFAULT_DATE        
  ,REPLACE(OS_AT_DEFAULT, ',', '.') AS OS_AT_DEFAULT        
  ,CUSTOMER_NUMBER        
  ,CUSTOMER_NAME        
  ,PRODUCT_GROUP      
  ,CURRENCY        
  ,RECOVERY_DATE        
  ,REPLACE(NETT_RECOVERY, ',', '.') AS NETT_RECOVERY        
  ,REPLACE(OEIR_AT_DEFAULT, ',', '.') AS EIR_AT_DEFAULT        
  ,JAP_NON_JAP_IDENTIFIER        
  ,CREATEDBY        
  ,CREATEDDATE        
  ,CREATEDHOST        
 FROM TBLU_RECOVERY        
 WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE      
 --------------------------------      
 ---- END IFRS_RECOVERY_CORP ----      
 --------------------------------      
       
 ---------------------------------------------      
 ---- START IFRS_MASTER_LIMIT_CORP_UPLOAD ----      
 ---------------------------------------------      
 DELETE IFRS_MASTER_LIMIT_CORP_UPLOAD WHERE DOWNLOAD_DATE = @V_CURRDATE      
       
 INSERT INTO IFRS_MASTER_LIMIT_CORP_UPLOAD      
 (      
  DOWNLOAD_DATE      
  ,DATA_SOURCE      
  ,LIMIT_FLAG      
  ,BRANCH_CODE      
  ,ACCOUNT_NUMBER      
  ,PRODUCT_CODE      
  ,CUSTOMER_NUMBER      
  ,CURRENCY      
  ,BI_COLLECTABILITY      
  ,MATURITY_DATE      
  ,PLAFOND      
  ,UNUSED_LIMIT      
  ,OUTSTANDING      
 )      
 SELECT      
  DOWNLOAD_DATE      
  ,'LIMIT_T24' AS DATA_SOURCE      
  ,CASE FAC_COMMIT WHEN 'Y' THEN 1 ELSE 0 END AS LIMIT_FLAG      
,'0800' AS BRANCH_CODE      
  ,LIMIT_ID AS ACCOUNT_NUMBER      
  ,LIMIT_PRODUCT AS PRODUCT_CODE      
  ,CIF_NO AS CUSTOMER_NUMBER      
  ,LIMIT_CURRENCY AS CURRENCY      
  ,COLLECTIBILITY AS BI_COLLECTABILITY      
  ,EXPIRY_DATE AS MATURITY_DATE      
  ,STG_LIMIT_AMT AS PLAFOND      
  ,UNDRAWN_FINAL AS UNUSED_LIMIT      
  ,STG_TOTAL_OS AS OUTSTANDING      
 FROM TBLU_LIMIT_CORPORATE      
 WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE      
 -------------------------------------------      
 ---- END IFRS_MASTER_LIMIT_CORP_UPLOAD ----      
 -------------------------------------------      
      
 ----------------------------------------------      
 ---- START IFRS_JUDGEMENT_RATING_TREASURY ----      
 ----------------------------------------------      
 DELETE IFRS_JUDGEMENT_RATING_TREASURY WHERE DOWNLOAD_DATE = @V_CURRDATE      
          
 INSERT INTO IFRS_JUDGEMENT_RATING_TREASURY      
 (      
  DOWNLOAD_DATE      
  ,MASTERID      
  ,EXTERNAL_RATING_AGENCY      
  ,EXTERNAL_RATING_CODE      
 )      
 SELECT      
  DOWNLOAD_DATE      
  ,DEAL_NO      
  ,EXTERNAL_RATING_AGENCY      
  ,EXTERNAL_RATING_CODE      
 FROM TBLU_JUDGEMENT_RATING_TREASURY      
 WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE      
 --------------------------------------------      
 ---- END IFRS_JUDGEMENT_RATING_TREASURY ----      
 --------------------------------------------      
      
 -----------------------------------------      
 ---- START IFRS_PD_EXTERNAL_TREASURY ----      
 -----------------------------------------      
 DELETE IFRS_PD_EXTERNAL_TREASURY WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE      
      
 IF EXISTS (SELECT TOP 1 DOWNLOAD_DATE FROM TBLU_PD_EXTERNAL_PEFINDO WHERE DOWNLOAD_DATE = @V_CURRDATE UNION ALL SELECT TOP 1 DOWNLOAD_DATE FROM TBLU_PD_EXTERNAL_SNP WHERE DOWNLOAD_DATE = @V_CURRDATE)          
 BEGIN      
      
 DELETE IFRS_PD_EXTERNAL_MAPPING WHERE DOWNLOAD_DATE = @V_CURRDATE      
       
 INSERT INTO IFRS_PD_EXTERNAL_MAPPING      
 (      
  DOWNLOAD_DATE      
  ,SEGMENT      
  ,PEFINDO_RATING_CODE      
  ,PEFINDO_PD_RATE      
  ,SNP_PD_RATE      
 )      
 SELECT       
  A.DOWNLOAD_DATE,      
  A.SEGMENT,      
  A.RATING_CODE AS PEFINDO_RATING_CODE,       
  CAST(A.CUMMULATIVE_PD AS FLOAT) AS PEFINDO_PD_RATE,       
  MAX(CAST(B.CUMMULATIVE_PD AS FLOAT)) AS SNP_PD_RATE      
 FROM TBLU_PD_EXTERNAL_PEFINDO A      
 JOIN TBLU_PD_EXTERNAL_SNP B       
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE       
 AND A.SEGMENT = B.SEGMENT       
 AND A.REMAINING_TENOR_YEAR = B.REMAINING_TENOR_YEAR      
 WHERE A.REMAINING_TENOR_YEAR = '1'       
 AND CAST(B.CUMMULATIVE_PD AS FLOAT) <= CAST(A.CUMMULATIVE_PD AS FLOAT)      
 AND A.DOWNLOAD_DATE = @V_CURRDATE      
 GROUP BY A.DOWNLOAD_DATE, A.SEGMENT, A.RATING_AGENCY_CODE, A.RATING_CODE, A.CUMMULATIVE_PD      
 ORDER BY A.RATING_CODE      
      
 UPDATE A      
 SET A.SNP_RATING_CODE = B.RATING_CODE      
 FROM IFRS_PD_EXTERNAL_MAPPING A      
 JOIN       
 (      
  SELECT DOWNLOAD_DATE, CUMMULATIVE_PD, SEGMENT, MAX(RATING_CODE) AS RATING_CODE, REMAINING_TENOR_YEAR       
  FROM TBLU_PD_EXTERNAL_SNP       
  WHERE REMAINING_TENOR_YEAR = '1' AND DOWNLOAD_DATE = @V_CURRDATE      
  GROUP BY DOWNLOAD_DATE, CUMMULATIVE_PD, SEGMENT, REMAINING_TENOR_YEAR      
 ) B      
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE       
 AND A.SNP_PD_RATE = B.CUMMULATIVE_PD      
 AND A.SEGMENT = B.SEGMENT      
 WHERE B.REMAINING_TENOR_YEAR = '1' AND A.DOWNLOAD_DATE = @V_CURRDATE      
       
 INSERT INTO IFRS_PD_EXTERNAL_TREASURY      
 (      
  DOWNLOAD_DATE      
  ,SEGMENT      
  ,RATING_CODE      
  ,REMAINING_TENOR_YEAR      
  ,CUMMULATIVE_PD      
  ,PEFINDO_RATING_CODE      
  ,SnP_RATING_CODE      
  ,PEFINDO_PD_RATE      
  ,SnP_PD_RATE       
 )      
 SELECT       
  A.DOWNLOAD_DATE      
  ,A.SEGMENT      
  ,RATING_CODE      
  ,REMAINING_TENOR_YEAR      
  ,(CAST(B.SNP_PD_RATE AS FLOAT) / 100) AS CUMMULATIVE_PD      
  ,B.PEFINDO_RATING_CODE      
  ,B.SnP_RATING_CODE      
  ,(CAST(B.PEFINDO_PD_RATE AS FLOAT) / 100) AS PEFINDO_PD_RATE      
  ,(CAST(B.SnP_PD_RATE AS FLOAT) / 100) AS SnP_PD_RATE      
 FROM TBLU_PD_EXTERNAL_PEFINDO A       
 LEFT JOIN IFRS_PD_EXTERNAL_MAPPING B      
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
 AND A.SEGMENT = B.SEGMENT      
 AND A.REMAINING_TENOR_YEAR = 1      
 AND A.RATING_CODE = B.PEFINDO_RATING_CODE      
 WHERE EOMONTH(A.DOWNLOAD_DATE) = @V_CURRDATE      
 ORDER BY CAST(A.REMAINING_TENOR_YEAR AS INT), B.PEFINDO_RATING_CODE      
    
 UPDATE A      
 SET A.PEFINDO_RATING_CODE = B.PEFINDO_RATING_CODE, A.SnP_RATING_CODE = B.SnP_RATING_CODE, A.PEFINDO_PD_RATE = B.PEFINDO_PD_RATE, A.SnP_PD_RATE = B.SnP_PD_RATE      
 FROM IFRS_PD_EXTERNAL_TREASURY A      
 JOIN       
 (      
  SELECT DOWNLOAD_DATE, SEGMENT, REMAINING_TENOR_YEAR, PEFINDO_RATING_CODE, PEFINDO_PD_RATE, SNP_RATING_CODE, SNP_PD_RATE      
  FROM IFRS_PD_EXTERNAL_TREASURY      
  WHERE DOWNLOAD_DATE = @V_CURRDATE      
  AND REMAINING_TENOR_YEAR = '1'      
 ) B      
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
 AND A.SEGMENT = B.SEGMENT      
 AND A.RATING_CODE = B.PEFINDO_RATING_CODE      
 WHERE A.REMAINING_TENOR_YEAR > 1      
 AND A.DOWNLOAD_DATE = @V_CURRDATE      
      
 UPDATE A      
 SET A.CUMMULATIVE_PD = (CAST(B.CUMMULATIVE_PD AS FLOAT) / 100)      
 FROM IFRS_PD_EXTERNAL_TREASURY A      
 JOIN TBLU_PD_EXTERNAL_SNP B      
 ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
 AND A.SEGMENT = B.SEGMENT      
 AND A.SnP_RATING_CODE = B.RATING_CODE      
 AND A.REMAINING_TENOR_YEAR = B.REMAINING_TENOR_YEAR      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
      
 UPDATE A      
 SET A.MARGINAL_PD = B.MARGINAL      
 FROM IFRS_PD_EXTERNAL_TREASURY A      
 JOIN       
 (      
  SELECT CAST(CAST(CUMMULATIVE_PD AS FLOAT) AS NUMERIC(32,6)) - CAST(ISNULL(LAG(CAST(CUMMULATIVE_PD AS FLOAT)) OVER (PARTITION BY DOWNLOAD_DATE, SEGMENT, RATING_CODE ORDER BY CAST(REMAINING_TENOR_YEAR AS INT)), 0) AS NUMERIC(32,6)) AS MARGINAL      
  , *      
  FROM IFRS_PD_EXTERNAL_TREASURY      
  WHERE DOWNLOAD_DATE = @V_CURRDATE      
 )B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE      
 AND A.SEGMENT = B.SEGMENT      
 AND A.RATING_CODE = B.RATING_CODE      
 AND A.REMAINING_TENOR_YEAR = B.REMAINING_TENOR_YEAR      
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE      
 END           
ELSE           
 BEGIN           
 INSERT INTO IFRS_PD_EXTERNAL_TREASURY      
 (      
  DOWNLOAD_DATE      
  ,SEGMENT      
  ,RATING_CODE      
  ,REMAINING_TENOR_YEAR      
  ,CUMMULATIVE_PD      
  ,MARGINAL_PD      
  ,PEFINDO_RATING_CODE      
  ,SnP_RATING_CODE      
  ,PEFINDO_PD_RATE      
  ,SnP_PD_RATE        
 )      
 SELECT       
  @V_CURRDATE as DOWNLOAD_DATE      
  ,SEGMENT      
  ,RATING_CODE      
  ,REMAINING_TENOR_YEAR      
  ,CUMMULATIVE_PD      
  ,MARGINAL_PD       
  ,PEFINDO_RATING_CODE      
  ,SnP_RATING_CODE      
  ,PEFINDO_PD_RATE      
  ,SnP_PD_RATE           
 FROM IFRS_PD_EXTERNAL_TREASURY WHERE DOWNLOAD_DATE = EOMONTH(@V_PREVDATE)          
END           
          
 ---------------------------------------      
 ---- END IFRS_PD_EXTERNAL_TREASURY ----      
 ---------------------------------------          
      
 -------------------------------------------      
 ---- START TBLU_RECOVERY_RATE_TREASURY ----      
 -------------------------------------------      
 DELETE IFRS_RECOVERY_RATE_TREASURY WHERE DOWNLOAD_DATE = @V_CURRDATE      
          
 IF EXISTS (SELECT TOP 1 * FROM TBLU_RECOVERY_RATE_TREASURY  WHERE DOWNLOAD_DATE = @V_CURRDATE)      
 BEGIN      
  INSERT INTO IFRS_RECOVERY_RATE_TREASURY      
  (      
   DOWNLOAD_DATE      
   ,SEGMENT      
   ,RECOVERY_RATE       
  )      
  SELECT       
   DOWNLOAD_DATE      
   ,SEGMENT      
   ,CAST(RECOVERY_RATE AS FLOAT) / 100 AS RECOVERY_RATE      
  FROM TBLU_RECOVERY_RATE_TREASURY      
  WHERE EOMONTH(DOWNLOAD_DATE) = @V_CURRDATE      
 END      
 ELSE      
 BEGIN      
  INSERT INTO IFRS_RECOVERY_RATE_TREASURY      
  (      
   DOWNLOAD_DATE      
   ,SEGMENT      
   ,RECOVERY_RATE      
  )      
  SELECT       
   @V_CURRDATE AS DOWNLOAD_DATE      
   ,SEGMENT      
   ,RECOVERY_RATE      
  FROM IFRS_RECOVERY_RATE_TREASURY      
  WHERE EOMONTH(DOWNLOAD_DATE) = @V_PREVDATE      
 END       
 -----------------------------------------      
 ---- END TBLU_RECOVERY_RATE_TREASURY ----      
 -----------------------------------------      
         
 ------------------------------------------      
 ---- START IFRS_CUSTOMER_GRADING_CORP ----      
 ------------------------------------------           
 DELETE FROM IFRS_CUSTOMER_GRADING_CORP WHERE DOWNLOAD_DATE = @V_CURRDATE      
      
 INSERT INTO IFRS_CUSTOMER_GRADING_CORP       
 (      
  DOWNLOAD_DATE      
  ,CUSTOMER_NUMBER        
  ,SANDI_BANK      
  ,OBLIGOR_GRADE      
  ,JAP_NON_JAP_IDENTIFIER      
  ,WATCH_LIST_FLAG      
  ,CREATEDBY      
  ,CREATEDDATE      
 )      
 SELECT      
  DOWNLOAD_DATE      
  ,CUSTOMER_NUMBER        
  ,SANDI_BANK           
  ,UPPER(max(OBLIGOR_GRADE))      
  ,max(JAP_NON_JAP_IDENTIFIER)      
  ,max(case when WATCH_LIST_FLAG = 1 then 1 else 0 end)      
  ,'SP_IFRS_SYNC_CORPORATE_DATA' AS CREATEDBY      
  ,GETDATE () AS CREATEDDATE      
 FROM TBLU_CUSTOMER_GRADING       
 WHERE DOWNLOAD_DATE = @V_CURRDATE_CHAR  --and DOWNLOAD_DATE >= '20140531'      
 GROUP BY DOWNLOAD_DATE, CUSTOMER_NUMBER, SANDI_BANK         
 ----------------------------------------      
 ---- END IFRS_CUSTOMER_GRADING_CORP ----      
 ----------------------------------------         
      
 ----------------------------------      
 ---- START IFRS_SYNC_TREASURY ----      
 ----------------------------------      
 EXEC SP_IFRS_SYNC_TREASURY @V_CURRDATE       
 --------------------------------      
 ---- END IFRS_SYNC_TREASURY ----      
 --------------------------------      
           
        
 --------------------------------      
 ---- START SYNC ASSET CLASS CORP ----      
 --------------------------------      
 delete IFRS_ASSET_CLASSIFICATION_CORP where download_date = @V_CURRDATE        
        
 INSERT INTO  IFRS_ASSET_CLASSIFICATION_CORP (DOWNLOAD_DATE        
,FACILITY_NUMBER        
,SPPI_RESULT        
,BM_RESULT)        
SELECT DOWNLOAD_DATE        
,FACILITY_NUMBER        
,SPPI_RESULT        
,CASE WHEN BM_RESULT = 'OTHERS' THEN 'TRADE'        
 ELSE BM_RESULT END  AS BM_RESULT        
FROM tblu_asset_classification_corp WHERE download_date = @v_currdate_char        
        
 --------------------------------      
 ---- END SYNC ASSET CLASS CORP ----      
 --------------------------------    
END
GO
