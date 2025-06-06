USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_PD_NFR_RESULT]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 CREATE PROC [dbo].[SP_IFRS_IMP_PD_NFR_RESULT] @DOWNLOAD_DATE DATE =''
AS 
BEGIN
 DECLARE @V_CURRDATE   DATE                                                                      
 DECLARE @V_PREVDATE   DATE        
 DECLARE @V_PREVMONTH DATE 
 DECLARE @LAST_YEAR DATE    

  IF @DOWNLOAD_DATE <> ''      
BEGIN       
SET @V_CURRDATE = EOMONTH(DATEADD(MONTH,-1,@DOWNLOAD_DATE)) -- LAG -1 MONTH BTPN      
SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)      
SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE))     
SET @LAST_YEAR =  EOMONTH(DATEADD(MONTH,-12, @V_CURRDATE)) 
END      
ELSE       
BEGIN       
SELECT @V_CURRDATE = EOMONTH(DATEADD(M,-1,CURRDATE) )        
FROM IFRS_PRC_DATE      
SET @V_PREVDATE = DATEADD(DAY,-1,@V_CURRDATE)      
SET @V_PREVMONTH = EOMONTH(DATEADD(MONTH,-1,@V_CURRDATE)) 
SET @LAST_YEAR =  EOMONTH(DATEADD(MONTH,-12, @V_CURRDATE)) 
END      
 
 DELETE [IFRS_PD_NFR_RESULT] WHERE DOWNLOAD_DATE = @V_CURRDATE
INSERT INTO [IFRS_PD_NFR_RESULT] (DOWNLOAD_DATE
,PD_RULE_ID
,PD_RULE_NAME
,BUCKET_GROUP
,BUCKET_ID
,CALC_METHOD
,PD_RATE
,CREATEDBY
,CREATEDDATE)
  select @V_CURRDATE as DOWNLOAD_DATE
 ,a.PD_RULE_ID
,max(a.PD_RULE_NAME)
,max(a.BUCKET_GROUP)
,a.BUCKET_ID
,max(a.CALC_METHOD)
 ,CASE COUNT(CASE SIGN(C.FLOW_TO_LOSS)
                            WHEN 0 THEN
                             1
                            ELSE
                             NULL
                          END) -- COUNT ZEROS IN GROUP
                     WHEN 0 THEN -- NO ZEROES: PROCEED NORMALLY
                     -- LN ONLY ACCEPTS POSITIVE VALUES. HERE, WE COUNT HOW MANY NEGATIVE NUMBERS THERE WERE IN A GROUP:
                      CASE (SUM(CASE SIGN(C.FLOW_TO_LOSS)
                                 WHEN -1 THEN
                                  1
                                 ELSE
                                  0
                               END) %
                           2)
                        WHEN 1 THEN
                         -1 -- ODD NUMBER OF NEGATIVE NUMBERS: RESULT WILL BE NEGATIVE
                        ELSE
                         1 -- EVEN NUMBER OF NEGATIVE NUMBERS: RESULT WILL BE POSITIVE
                      END * -- MULTIPLY -1 OR 1 WITH THE FOLLOWING EXPRESSION
                      EXP(SUM(LOG(
                                 -- ONLY POSITIVE (NON-ZERO) VALUES!
                                 ABS(CASE C.FLOW_TO_LOSS
                                       WHEN 0 THEN
                                        NULL
                                       ELSE
                                        C.FLOW_TO_LOSS
                                     END))))
                     ELSE
                      0 -- THERE WERE ZEROES, SO THE ENTIRE PRODUCT IS 0, TOO.
                   END  as PD_RATE
		,'SP_IFRS_IMP_PD_NFR_RESULT' AS CREATEDBY
		,GETDATE() AS CREATEDDATE
		from IFRS_PD_NFR_FLOWRATE A
		INNER JOIN IFRS_PD_NFR_FLOWTOLOSS c  ON A.PD_RULE_ID = C.PD_RULE_ID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE AND A.BUCKET_ID <= C.BUCKET_ID
		WHERE A.DOWNLOAD_DATE = @V_CURRDATE
		GROUP BY A.DOWNLOAD_DATE,A.PD_RULE_ID,A.BUCKET_ID


END

GO
