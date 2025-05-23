USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_PAYM_SCHD_FUNDING]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_PAYM_SCHD_FUNDING]      
AS      
BEGIN      
 DECLARE @V_CURRDATE DATE = '2017-12-06'      
 DECLARE @V_PREVDATE DATE      
 DECLARE @V_I INT;      
 DECLARE @V_J INT;      
      
 SELECT @V_CURRDATE = CURRDATE      
  ,@V_PREVDATE = PREVDATE      
 FROM IFRS_LI_PRC_DATE_AMORT;      
      
 TRUNCATE TABLE IFRS_LI_FUNDING_SCHD2      
      
 TRUNCATE TABLE IFRS_LI_FUNDING_SCHD1       
  
 INSERT INTO IFRS_LI_FUNDING_SCHD1 (      
  MASTERID      
  ,NOMINAL_AMT      
  ,TOPUP      
  ,INT_RATE      
  ,START_DATE      
  ,END_DATE     
  ,NEXT_DATE  
  ,CURR_DATE      
  ,FLG      
  )      
 SELECT  A.MASTERID    
  ,ISNULL(A.OUTSTANDING, 0)      
  ,ISNULL(A.TOPUP ,0)   
  ,A.INTEREST_RATE AS INTEREST_RATE      
  ,A.LOAN_START_DATE      
  ,A.LOAN_DUE_DATE  
  ,A.NEXT_PAYMENT_DATE      
  ,@V_CURRDATE 
  ,COMPOUND_FLAG  
  FROM IFRS_LI_IMA_AMORT_CURR A   
 LEFT JOIN IFRS_LI_TRANSACTION_DAILY B ON A.MASTERID = B.MASTERID AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE  
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE  
 AND ((A.EIR_STATUS = 'Y' AND A.ECF_STATUS = 'Y') OR B.MASTERID IS NOT NULL)
 -- ADD SUPAYA YANG DI GENERATE HANYA FUNDING
 AND A.DATA_SOURCE = 'FUNDING'
 -- ADD SUPAYA YANG DI GENERATE HANYA FUNDING
      
 SELECT @V_I = COUNT(*)      
 FROM IFRS_LI_FUNDING_SCHD1      
 WHERE NEXT_DATE <= CURR_DATE;      
      
 SET @V_J = 1;      
      
 WHILE @V_I > 0      
 BEGIN      
  UPDATE IFRS_LI_FUNDING_SCHD1      
  SET NEXT_DATE = DATEADD(MONTH, @V_J, START_DATE)      
  WHERE NEXT_DATE <= CURR_DATE;      
      
  SELECT @V_I = COUNT(*)      
  FROM IFRS_LI_FUNDING_SCHD1      
  WHERE NEXT_DATE <= CURR_DATE;      
      
  SET @V_J = @V_J + 1;      
 END      
      
 --SET DATA FOR 1ST ROW  
 UPDATE IFRS_LI_FUNDING_SCHD1      
 SET PREV_PAYM_DATE = CASE       
   WHEN FLG IN (      
     1      
     )      
    THEN CURR_DATE      
   ELSE DATEADD(MONTH, - 1, NEXT_DATE)      
   END      
  ,PAYM_DATE = CASE       
   WHEN FLG IN (      
     1      
     )      
    THEN CURR_DATE      
   ELSE DATEADD(MONTH, - 1, NEXT_DATE)      
   END      
  ,INT_DAYS = 0      
  ,PREV_OS_AMT = NOMINAL_AMT      
  ,OS_AMT = NOMINAL_AMT      
  ,PRIN_AMT = 0      
  ,INT_AMT = 0      
      
 INSERT INTO IFRS_LI_FUNDING_SCHD2 (      
  MASTERID      
  ,NOMINAL_AMT      
  ,TOPUP      
  ,INT_RATE      
  ,START_DATE   
  ,END_DATE      
  ,NEXT_DATE      
  ,CURR_DATE      
  ,PREV_PAYM_DATE      
  ,PAYM_DATE      
  ,INT_DAYS      
  ,PREV_OS_AMT   
  ,PRIN_AMT      
  ,INT_AMT      
  ,OS_AMT      
  ,FLG      
  ,COUNTER      
  )      
 SELECT MASTERID      
  ,NOMINAL_AMT      
  ,TOPUP      
  ,INT_RATE      
  ,START_DATE      
  ,END_DATE      
  ,NEXT_DATE      
  ,CURR_DATE      
  ,PREV_PAYM_DATE      
  ,PAYM_DATE      
  ,INT_DAYS      
  ,PREV_OS_AMT      
  ,PRIN_AMT      
  ,INT_AMT      
  ,OS_AMT      
  ,FLG      
  ,0      
 FROM IFRS_LI_FUNDING_SCHD1;      
      
 SELECT @V_I = COUNT(*)      
 FROM IFRS_LI_FUNDING_SCHD1      
 WHERE PAYM_DATE < END_DATE;      
      
 SET @V_J = 0;      
      
 WHILE @V_I > 0      
 BEGIN      
  UPDATE IFRS_LI_FUNDING_SCHD1      
  SET PREV_PAYM_DATE = PAYM_DATE      
   ,PAYM_DATE = DATEADD(MONTH, @V_J, NEXT_DATE)      
   ,INT_DAYS = - 1      
   ,--UPDATE LATER,  
   PREV_OS_AMT = OS_AMT       
  WHERE PAYM_DATE < END_DATE;      
      
  /*SET LAST PAYMENT DATE AS END DATA*/      
 UPDATE IFRS_LI_FUNDING_SCHD1      
  SET PAYM_DATE = END_DATE      
  WHERE PAYM_DATE > END_DATE;      
      
  UPDATE IFRS_LI_FUNDING_SCHD1      
  SET OS_AMT = OS_AMT + TOPUP      
   ,PRIN_AMT = - 1 * TOPUP      
   ,INT_DAYS = DATEDIFF(DAY, PREV_PAYM_DATE, PAYM_DATE)      
   ,INT_AMT = - 1 --UPDATE LATER  
  WHERE INT_DAYS = - 1;      
      
  TRUNCATE TABLE IFRS_LI_FUNDING_SUMM;      
      
  INSERT INTO IFRS_LI_FUNDING_SUMM (      
   MASTERID      
   ,SUMM_INT_AMT      
   )      
  SELECT MASTERID      
   ,SUM(INT_AMT) AS SUMM_INT_AMT      
  FROM IFRS_LI_FUNDING_SCHD2      
  GROUP BY MASTERID;      
      
  UPDATE A      
  SET OS_AMT = CASE       
    WHEN FLG = '1'      
     THEN OS_AMT + (INT_DAYS * PREV_OS_AMT * (CAST(INT_RATE AS FLOAT)/ 100) / 365.00) -- COMPOUND INTEREST  AND IMPACT TO  
    ELSE OS_AMT      
    END      
   ,INT_AMT = CASE   
    WHEN FLG IN ('1') THEN INT_DAYS * (PREV_OS_AMT ) * (CAST (INT_RATE AS FLOAT) / 100) / 365.00      
    ELSE INT_DAYS * PREV_OS_AMT * (CAST (INT_RATE AS FLOAT)  / 100) / 365.00    
   END      
  FROM IFRS_LI_FUNDING_SCHD1 A      
  INNER JOIN IFRS_LI_FUNDING_SUMM B ON (A.MASTERID = B.MASTERID)      
  WHERE A.INT_AMT = - 1;      
        
  INSERT INTO IFRS_LI_FUNDING_SCHD2 (      
   MASTERID      
   ,NOMINAL_AMT      
   ,TOPUP      
   ,INT_RATE      
   ,START_DATE      
   ,END_DATE      
   ,NEXT_DATE      
   ,CURR_DATE      
   ,PREV_PAYM_DATE      
   ,PAYM_DATE      
   ,INT_DAYS      
   ,PREV_OS_AMT      
   ,PRIN_AMT      
   ,INT_AMT      
   ,OS_AMT      
   ,FLG      
   ,COUNTER      
   )      
  SELECT MASTERID      
   ,NOMINAL_AMT      
   ,TOPUP      
   ,INT_RATE      
   ,START_DATE      
   ,END_DATE      
   ,NEXT_DATE      
   ,CURR_DATE      
   ,PREV_PAYM_DATE      
   ,PAYM_DATE      
   ,INT_DAYS  
   ,PREV_OS_AMT      
   ,PRIN_AMT      
   ,INT_AMT      
   ,OS_AMT      
   ,FLG      
   ,(@V_J + 1)      
  FROM IFRS_LI_FUNDING_SCHD1;      
      
  DELETE      
  FROM IFRS_LI_FUNDING_SCHD1      
  WHERE PAYM_DATE >= END_DATE;      
      
  SELECT @V_I = COUNT(*)      
  FROM IFRS_LI_FUNDING_SCHD1      
  WHERE PAYM_DATE < END_DATE;      
      
  SET @V_J = @V_J + 1;      
 END      
      
 TRUNCATE TABLE TMP_LI_PAYM_FUNDING      
      
 INSERT INTO TMP_LI_PAYM_FUNDING (      
 MASTERID      
  ,DOWNLOAD_DATE      
  )      
 SELECT DISTINCT MASTERID      
  ,@V_CURRDATE      
 FROM IFRS_LI_FUNDING_SCHD2;      
      
 DELETE IFRS_LI_PAYM_SCHD      
 WHERE MASTERID IN (      
   SELECT MASTERID      
   FROM TMP_LI_PAYM_FUNDING      
   );      
      
 INSERT INTO IFRS_LI_PAYM_SCHD (      
  MASTERID      
  ,ACCOUNT_NUMBER      
  ,PMTDATE      
  ,INTEREST_RATE      
  ,OSPRN      
  ,PRINCIPAL      
  ,INTEREST      
  ,DISB_PERCENTAGE      
  ,DISB_AMOUNT      
  ,PLAFOND      
  ,I_DAYS      
  ,ICC      
  ,COUNTER      
  ,DOWNLOAD_DATE      
  ,SCH_FLAG      
  ,GRACE_DATE      
  ,DATA_SOURCE      
  ) --BIBD FOR GRACE PERIOD  
 SELECT A.MASTERID       
  ,A.MASTERID      
  ,A.PAYM_DATE      
  ,A.INT_RATE      
  ,CASE       
   WHEN B.MAX_PAYM_DATE IS NOT NULL      
    THEN 0      
   ELSE A.OS_AMT      
   END OS_AMT      
  ,A.PRIN_AMT   
  ,A.INT_AMT      
  ,0 DISB_PERCENTAGE      
  ,CASE       
   WHEN COUNTER = 0      
    THEN OS_AMT      
   ELSE 0      
   END DISB_AMOUNT      
  ,A.OS_AMT PLAFOND      
  ,A.INT_DAYS      
  ,'2'      
  ,A.COUNTER      
  ,A.CURR_DATE      
  ,'N'      
  ,NULL      
  ,'FUNDING'   
 FROM IFRS_LI_FUNDING_SCHD2 A      
 LEFT JOIN (      
  SELECT MASTERID      
   ,MAX(PAYM_DATE) AS MAX_PAYM_DATE      
  FROM IFRS_LI_FUNDING_SCHD2      
  GROUP BY MASTERID      
  ) B ON A.MASTERID = B.MASTERID      
  AND A.PAYM_DATE = B.MAX_PAYM_DATE      
      
 DELETE IFRS_LI_PAYM_CORE_SRC      
 WHERE MASTERID IN (      
   SELECT MASTERID      
   FROM TMP_LI_PAYM_FUNDING      
   );      
      
 INSERT INTO IFRS_LI_PAYM_CORE_SRC (      
  MASTERID      
  ,ACCTNO      
  ,PREV_PMT_DATE      
  ,PMT_DATE      
  ,INTEREST_RATE      
  ,I_DAYS      
,PRN_AMT      
  ,INT_AMT      
  ,DISB_PERCENTAGE      
  ,DISB_AMOUNT      
  ,PLAFOND      
  ,OS_PRN_PREV      
  ,OS_PRN      
  ,COUNTER      
  ,ICC      
  ,GRACE_DATE      
  )      
 SELECT SCH.MASTERID      
  ,SCH.ACCOUNT_NUMBER      
  ,ISNULL(LAG(SCH.PMTDATE) OVER (      
    PARTITION BY SCH.MASTERID ORDER BY SCH.PMTDATE      
    ), SCH.PMTDATE)      
  ,SCH.PMTDATE      
  ,SCH.INTEREST_RATE      
  ,SCH.I_DAYS     
  ,SCH.PRINCIPAL      
  ,SCH.INTEREST      
  ,SCH.DISB_PERCENTAGE      
  ,SCH.DISB_AMOUNT      
  ,SCH.PLAFOND      
  ,ISNULL(LAG(SCH.OSPRN) OVER (      
    PARTITION BY SCH.MASTERID ORDER BY SCH.PMTDATE      
    ), SCH.OSPRN)      
  ,SCH.OSPRN      
  ,SCH.COUNTER      
  ,SCH.ICC      
  ,SCH.GRACE_DATE      
 FROM IFRS_LI_PAYM_SCHD SCH      
 WHERE MASTERID IN (      
   SELECT MASTERID      
   FROM TMP_LI_PAYM_FUNDING      
   );   
END       
GO
