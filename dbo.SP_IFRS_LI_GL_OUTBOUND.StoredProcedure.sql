USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_GL_OUTBOUND]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_LI_GL_OUTBOUND]               
@DOWNLOAD_DATE DATE = NULL                          
AS                      
 DECLARE                       
 @V_CURRDATE DATE                      
 ,@V_PREVDATE DATE                      
 ,@V_ROUND INT = 2                      
 ,@V_FUNCROUND INT = 0                      
 ,@IS_POSTED BIT                      
BEGIN                  
 IF @DOWNLOAD_DATE IS NULL              
 BEGIN              
    SELECT @V_CURRDATE = MAX(CURRDATE), @V_PREVDATE = MAX(PREVDATE)               
    FROM IFRS_PRC_DATE_AMORT              
 END              
 ELSE              
 BEGIN              
    SET @V_CURRDATE = @DOWNLOAD_DATE              
 END              
              
 INSERT INTO IFRS_LI_AMORT_LOG                       
 (                      
  DOWNLOAD_DATE                      
  ,DTM                      
  ,OPS                      
  ,PROCNAME                      
  ,REMARK                      
 )                      
 VALUES                       
 (                      
  @V_CURRDATE                      
  ,CURRENT_TIMESTAMP                      
  ,'START'                      
  ,'SP_IFRS_LI_GL_OUTBOUND'                      
  ,''                      
 )  
 
 DECLARE @SANDI_DATE DATE
 SELECT @SANDI_DATE = MAX(BUSS_DATE) FROM IFRS_BTPN_MAPPING_SANDI            
              
 SELECT  ACCOUNT, SANDI_LBU, DESCRIPTION                
 INTO #MAPPING_SANDI              
 FROM               
 (               
 SELECT  ACCOUNT, SANDI_LBU, LEFT(DESCRIPTION,50) AS DESCRIPTION                
 FROM IFRS_BTPN_MAPPING_SANDI               
 WHERE SANDI_LBU = 175 and LEFT(ACCOUNT, 2) = 10            
 AND BUSS_DATE = @SANDI_DATE              
    UNION ALL              
 SELECT  ACCOUNT, SANDI_LBU,  LEFT(DESCRIPTION,50) AS DESCRIPTION                  
 FROM IFRS_BTPN_MAPPING_SANDI               
 WHERE SANDI_LBU <> 175            
 AND BUSS_DATE = @SANDI_DATE              
 ) a              
                    
 SELECT                     
  A.DOWNLOAD_DATE AS BUSS_DATE                    
  ,A.BRANCH AS BRANCH                    
  ,A.GLNO AS ACCOUNT_NO                    
  ,LEFT(B.DESCRIPTION,50) AS DESCRIPTION                    
  ,A.CCY AS CCY                    
  ,C.ACCOUNT_TYPE                    
  ,A.DOWNLOAD_DATE AS VALUE_DATE                    
  ,A.DRCR AS SIGN                    
  ,ROUND(CONVERT(NUMERIC(38, 2), ISNULL(A.N_AMOUNT, 0)), @V_ROUND, @V_FUNCROUND) AS AMOUNT                    
  ,A.REVERSE AS NARRATIVE1                    
  ,'REGLA' AS GROUP_OR_USER_ID                    
  ,CONVERT(VARCHAR(26), GETDATE(), 121) AS TIME_STAMP                    
  ,LEFT(PRDCODE, 6) AS PRODUCT_CODE                    
  ,C.CUSTOMER_TYPE                    
  ,CONVERT(NUMERIC(38, 2), ISNULL(D.RATE_AMOUNT, 1)) AS TRANSACTION_RATE                    
  ,(ROUND(CONVERT(NUMERIC(38, 2), ISNULL(A.N_AMOUNT, 0)), @V_ROUND, @V_FUNCROUND) * CONVERT(NUMERIC(38, 2), ISNULL(D.RATE_AMOUNT, 1))) AS AMOUNT_LEV         
  ,CONCAT(CONVERT(VARCHAR(8), A.DOWNLOAD_DATE, 112), CASE WHEN A.JOURNALCODE = 'AMORT' THEN A.JOURNALCODE ELSE A.JOURNALCODE2 END, A.BRANCH, A.CCY, LEFT(PRDCODE, 6)) AS JURNAL_NUMBER                 
  ,'PSAK71' AS SOURCE_DATA                    
  ,CASE WHEN A.JOURNALCODE = 'AMORT' THEN A.JOURNALCODE ELSE A.JOURNALCODE2 END AS EVENT_TYPE                   
 INTO #TT_GL_OUTBOUND                  
 FROM IFRS_LI_ACCT_JOURNAL_DATA A(NOLOCK)                     
 LEFT JOIN #MAPPING_SANDI B (NOLOCK) ON A.GLNO = B.ACCOUNT                  
 LEFT JOIN IFRS_LI_IMA_AMORT_CURR C (NOLOCK) ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE                   
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE D(NOLOCK) ON A.DOWNLOAD_DATE = D.DOWNLOAD_DATE AND A.CCY = D.CURRENCY                    
 LEFT JOIN IFRS_MASTER_EXCHANGE_RATE E(NOLOCK) ON E.DOWNLOAD_DATE = (DATEADD(DAY, - 1, @V_CURRDATE)) AND A.CCY = E.CURRENCY                    
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE                     
                 
 DELETE IFRS_GL_OUTBOUND where BUSS_DATE = @V_CURRDATE AND CLASS = 'L'                
                
 INSERT INTO IFRS_GL_OUTBOUND                    
 (                      
  BUSS_DATE                    
  ,BRANCH                    
  ,ACCOUNT_NO                    
  ,DESCRIPTION                    
  ,CCY                    
  ,ACCOUNT_TYPE           
  ,VALUE_DATE                    
  ,SIGN                    
  ,AMOUNT                    
  ,NARRATIVE1                    
  ,GROUP_OR_USER_ID                    
  ,TIME_STAMP                    
  ,PRODUCT_CODE                    
  ,CUSTOMER_TYPE                    
  ,TRANSACTION_RATE                    
  ,AMOUNT_LEV                    
  ,JURNAL_NUMBER                    
  ,SOURCE_DATA                    
  ,EVENT_TYPE            
  ,CLASS                  
 )                    
 SELECT                      
  BUSS_DATE                    
  ,BRANCH                    
  ,ACCOUNT_NO                    
  ,LEFT(DESCRIPTION,50)                    
  ,CCY                    
  ,ACCOUNT_TYPE                    
  ,VALUE_DATE           
  ,SIGN                    
  ,SUM(AMOUNT) AS AMOUNT                    
  ,NARRATIVE1                    
  ,GROUP_OR_USER_ID                    
  ,MAX(TIME_STAMP) AS TIME_STAMP                    
  ,PRODUCT_CODE                    
  ,CUSTOMER_TYPE                    
  ,TRANSACTION_RATE                    
  ,SUM(AMOUNT_LEV) AS AMOUNT_LEV                    
  ,JURNAL_NUMBER                    
  ,SOURCE_DATA                    
  ,EVENT_TYPE                
  ,'L' as CLASS                      
 FROM #TT_GL_OUTBOUND                    
 GROUP BY                     
  BUSS_DATE                    
  ,BRANCH                    
  ,ACCOUNT_NO                    
  ,LEFT(DESCRIPTION,50)                    
  ,CCY                    
  ,ACCOUNT_TYPE                    
  ,VALUE_DATE                    
  ,SIGN                    
  ,NARRATIVE1                    
  ,GROUP_OR_USER_ID                
  ,PRODUCT_CODE                    
  ,CUSTOMER_TYPE                    
  ,TRANSACTION_RATE                
  ,JURNAL_NUMBER                    
  ,SOURCE_DATA                    
  ,EVENT_TYPE                       
 ORDER BY                    
  BUSS_DATE ASC                    
  ,BRANCH ASC                    
  ,CCY ASC                    
  ,AMOUNT ASC                    
  ,SIGN DESC                    
  ,ACCOUNT_NO ASC                    
                    
 INSERT INTO IFRS_LI_AMORT_LOG                      
 (                      
  DOWNLOAD_DATE                      
  ,DTM                      
  ,OPS                      
  ,PROCNAME                      
  ,REMARK                      
 )                      
 VALUES                       
 (                      
  @V_CURRDATE                      
  ,CURRENT_TIMESTAMP                      
  ,'END'                      
  ,'SP_IFRS_LI_GL_OUTBOUND'                      
  ,''                      
 )                      
END


GO
