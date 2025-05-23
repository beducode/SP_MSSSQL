USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_GL_OUTBOUND_ORI]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_GL_OUTBOUND_ORI]        
AS        
DECLARE @V_CURRDATE DATE        
 ,@V_PREVDATE DATE        
 ,@V_ROUND INT = 2        
 ,@V_FUNCROUND INT = 0      
 ,@OUTPUT_DATE DATE    
        
BEGIN        
 SELECT @V_CURRDATE = MAX(CURRDATE)        
  ,@V_PREVDATE = MAX(PREVDATE)        
 FROM IFRS_PRC_DATE_AMORT      
      
 SET @OUTPUT_DATE = [DBO].[FN_JOURNALDATE](@V_CURRDATE)    
        
 INSERT INTO IFRS_AMORT_LOG (        
  DOWNLOAD_DATE        
  ,DTM        
  ,OPS        
  ,PROCNAME        
  ,REMARK        
  )        
 VALUES (        
  @V_CURRDATE        
  ,CURRENT_TIMESTAMP        
  ,'START'        
  ,'SP_IFRS_GL_OUTBOUND'        
  ,''        
  )        
        
 DECLARE @IFRS_AMORT_TT_GL_OUTBOUND TABLE (        
  [DOWNLOAD_DATE] DATE NULL        
  ,[CUSTOMER_NUMBER] [VARCHAR](50) NULL        
  ,[NMLEDG] [VARCHAR](50) NULL        
  ,[GLNO] [VARCHAR](50) NULL        
  ,[GLDESC] [VARCHAR](200) NULL        
  ,[CCY] [VARCHAR](5) NULL        
  ,[CCY_RATE] [DECIMAL](32, 2) NULL        
  ,[ORIG_AMOUNT] [DECIMAL](32, 2) NULL        
  ,[IDR_AMOUNT] [DECIMAL](32, 2) NULL        
  ,[JOURNALCODE] [VARCHAR](10) NULL        
  ,[SRCPROCESS] [VARCHAR](20) NULL        
  ,[FLAG_CF] [CHAR](1) NULL        
  ,[FLAG_REV] [VARCHAR](5) NULL        
  ,[DRCR] [VARCHAR](5) NULL        
  ,[SEQ] [INT] NULL        
  ,[BRANCH_CODE] [VARCHAR](7) NULL        
  ,[CREATEDDATE] [DATETIME] NULL        
  ,[CREATEDBY] [VARCHAR](40) NULL        
  ,[NARRATIVE_LINE] [VARCHAR](100) NULL      
  ,[JRNL_TYPE] [VARCHAR](100) NULL      
  ,[JRNL_SRCE] [VARCHAR](100) NULL      
  ,[ANAL_T0] [VARCHAR](50) NULL           
  ,[PERIOD] [VARCHAR](20) NULL      
  )        
        
 DELETE        
 FROM @IFRS_AMORT_TT_GL_OUTBOUND        
        
 INSERT INTO @IFRS_AMORT_TT_GL_OUTBOUND        
 SELECT A.DOWNLOAD_DATE        
  ,A.CIFNO AS CUSTOMER_NUMBER        
  ,'JOURNAL AMORT' AS NMLEDG        
  ,A.GLNO AS GLNO        
  ,A.JOURNAL_DESC AS GLDESC        
  ,A.CCY AS CCY        
  ,CASE         
   WHEN [REVERSE] = 'N'        
    THEN CONVERT(NUMERIC(38, 2), ISNULL(B.RATE_AMOUNT, 1))        
   WHEN (        
     [REVERSE] = 'Y'        
     AND JOURNALCODE IN (        
      'FVTPLG'        
      ,'FVTPLL'        
      ,'FVOCIG'        
      ,'FVOCIL'        
      )        
     )        
    THEN CONVERT(NUMERIC(38, 2), ISNULL(E.RATE_AMOUNT, 1))        
   ELSE CONVERT(NUMERIC(38, 2), ISNULL(C.RATE_AMOUNT, 1))        
   END AS CCY_RATE        
  ,ROUND(CONVERT(NUMERIC(38, 2), ISNULL(A.N_AMOUNT, 0)), @V_ROUND, @V_FUNCROUND) AS ORIG_AMOUNT        
  ,ROUND(CONVERT(NUMERIC(38, 2), ISNULL(A.N_AMOUNT_IDR, 0)), @V_ROUND, @V_FUNCROUND) AS IDR_AMOUNT        
  ,CASE         
   WHEN A.JOURNALCODE = 'AMORT'        
    THEN A.JOURNALCODE        
   ELSE A.JOURNALCODE2        
   END JOURNALCODE        
  ,'AMORT' AS SRCPROCESS        
  ,A.FLAG_CF AS FLAG_CF        
  ,A.[REVERSE] AS FLAG_REV        
  ,SUBSTRING(A.DRCR, 1, 1) AS DRCR        
  ,DENSE_RANK() OVER (        
   ORDER BY A.CCY        
    ,SUBSTRING(A.NOREF, 1, 1)        
    ,A.PRDCODE        
    ,A.REVERSE        
    ,CASE         
     WHEN A.JOURNALCODE = 'AMORT'        
      THEN A.JOURNALCODE        
     ELSE A.JOURNALCODE2        
     END        
   ) AS SEQ        
  ,BRANCH AS BRANCH_CODE        
  ,CURRENT_TIMESTAMP AS CREATEDDATE        
  ,'REGLA' AS CREATEDBY        
  ,(        
   CASE         
    WHEN (        
      FLAG_CF = 'O'        
      AND JOURNALCODE LIKE 'FVTPL%'        
      )        
     THEN 'PSAK ADJUSTMENT - FVTPL - ' + CONVERT(VARCHAR, A.DOWNLOAD_DATE, 112) + CASE         
       WHEN [REVERSE] = 'Y'        
        THEN ' REVERSAL '        
       ELSE ' '        
       END + ISNULL(D.PRD_GROUP, 'DEFAULT')        
    WHEN (        
      FLAG_CF = 'O'        
      AND JOURNALCODE LIKE 'FVOCI%'        
      )        
     THEN 'PSAK ADJUSTMENT - FVOCI - ' + CONVERT(VARCHAR, A.DOWNLOAD_DATE, 112) + CASE         
       WHEN [REVERSE] = 'Y'        
        THEN ' REVERSAL '        
       ELSE ' '        
       END + ISNULL(D.PRD_GROUP, 'DEFAULT')        
    WHEN FLAG_CF = 'F'        
     THEN 'PSAK AMORTIZATION FEE - ' + CONVERT(VARCHAR, A.DOWNLOAD_DATE, 112) + CASE         
       WHEN [REVERSE] = 'Y'        
        THEN ' REVERSAL '        
       ELSE ' '        
       END + ISNULL(D.PRD_GROUP, 'DEFAULT')        
    WHEN FLAG_CF = 'C'        
     THEN 'PSAK AMORTIZATION COST - ' + CONVERT(VARCHAR, A.DOWNLOAD_DATE, 112) + CASE         
       WHEN [REVERSE] = 'Y'        
        THEN ' REVERSAL '        
       ELSE ' '        
       END + ISNULL(D.PRD_GROUP, 'DEFAULT')        
    END        
   ) AS NARRATIVE_LINE,      
   'PS' AS JRNAL_TYPE,      
   'PSAK' AS JRNAL_SRCE,      
   RIGHT('00' + LTRIM(CONVERT(VARCHAR(2),MONTH(A.DOWNLOAD_DATE))),3) + CONVERT(CHAR(4),YEAR(A.DOWNLOAD_DATE)) AS PERIOD,      
   '12' AS ANAL_T0     
 FROM IFRS_ACCT_JOURNAL_DATA A(NOLOCK)        
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE B(NOLOCK) ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE        
  AND A.CCY = B.CURRENCY        
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE C(NOLOCK) ON C.DOWNLOAD_DATE = (DATEADD(DAY, - 1, @V_CURRDATE))        
  AND A.CCY = C.CURRENCY        
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E(NOLOCK) ON E.DOWNLOAD_DATE = EOMONTH(DATEADD(MONTH, - 1, @V_CURRDATE))        
  AND A.CCY = E.CURRENCY        
 LEFT JOIN IFRS_PRODUCT_PARAM D ON A.DATASOURCE = D.DATA_SOURCE        
  AND A.PRDCODE = D.PRD_CODE        
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE        
        
 --DELETE FIRST         
 DELETE        
 FROM IFRS_AMORT_GL_OUTBOUND        
 WHERE DOWNLOAD_DATE >= @V_CURRDATE        
        
 --AND NMLEDG = 'JOURNAL AMORT'        
     
 INSERT INTO [IFRS_AMORT_GL_OUTBOUND] (    
  DOWNLOAD_DATE,    
  BRANCH_CODE,    
  NARRATIVE_LINE,    
  COA_CODE,    
  ACCOUNT_PRODUCT,    
  CUSTOMER_CODE,    
  CURRENCY,    
  DEBIT_CREDIT_FLAG,    
  AMOUNT,    
  VALUE_DATE,    
  EXCHANGE_RATE,    
  MULTIPLY_DIVIDE_FLAG,    
  CREATEDDATE,    
  CREATEDBY    
  )        
 SELECT    
  CONVERT(VARCHAR, DOWNLOAD_DATE, 112) AS DOWNLOAD_DATE    
  ,BRANCH_CODE        
  ,NARRATIVE_LINE        
  ,GLNO AS COA_CODE        
  ,'' AS ACCOUNT_PRODUCT        
  ,'' AS CUSTOMER_CODE        
  ,CCY AS CURRENCY        
  ,DRCR AS DEBIT_CREDIT_FLAG        
  ,SUM(ORIG_AMOUNT) AS AMOUNT        
  ,CONVERT(VARCHAR, @OUTPUT_DATE, 112) AS VALUE_DATE        
  ,CCY_RATE AS EXCHANGE_RATE        
  ,'M' AS MULTIPLY_DIVIDE_FLAG     
  ,CURRENT_TIMESTAMP AS CREATEDDATE        
  ,'REGLA' AS CREATEDBY      
 FROM @IFRS_AMORT_TT_GL_OUTBOUND        
 GROUP BY DOWNLOAD_DATE        
  ,BRANCH_CODE        
  ,NARRATIVE_LINE        
  ,GLNO        
  ,CCY        
  ,CCY_RATE        
  ,DRCR          
 ORDER BY DOWNLOAD_DATE ASC        
  ,BRANCH_CODE ASC        
  ,NARRATIVE_LINE ASC        
  ,CURRENCY ASC        
  ,AMOUNT ASC        
  ,DEBIT_CREDIT_FLAG DESC        
  ,COA_CODE ASC        
        
 INSERT INTO IFRS_AMORT_LOG (        
  DOWNLOAD_DATE        
  ,DTM        
  ,OPS        
  ,PROCNAME        
  ,REMARK        
  )        
 VALUES (        
  @V_CURRDATE        
  ,CURRENT_TIMESTAMP        
  ,'END'        
  ,'SP_IFRS_GL_OUTBOUND'        
  ,''        
  )        
      
      
END
GO
