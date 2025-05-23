USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_UPLOAD_VALIDATION_PD_EXTERNAL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_UPLOAD_VALIDATION_PD_EXTERNAL]     
@UPLOADID INT,@UPLOADSTATUS VARCHAR(50)OUTPUT    
/* ============================================================================    
-- Author:  WILLY    
-- Create date: 03-APRIL-2018    
-- Description: SP UPLOAD VALIDATION     
    
-- TBLU_PD_EXTERNAL_FI    
-- TBLU_PD_EXTERNAL_SOV    
-- TBLU_PD_EXTERNAL_BUCKET_MAP    
-- TBLU_URR_EXTERNAL_FI    
-- TBLU_URR_EXTERNAL_SOV    
-- IFRS_MASTER_SAPGL_RECONCILE    
-- IFRS_EARLY_LOSS_ACCOUNT    
-- ============================================================================    
*/    
AS        
BEGIN    
 --EXEC SP_IFRS_UPLOAD_VALIDATION_PD_EXTERNAL @uploadid = 74 ,@UPLOADSTATUS = ''    
    
  DECLARE @CURRDATE DATE    
  SELECT @CURRDATE = CURRDATE FROM IFRS_PRC_DATE    
     
     DECLARE @SOURCE_HEADER TABLE (    
        NO_URUT int,    
        COLUMN_SOURCE varchar(100)    
    )    
    
    DECLARE @DESTINATION TABLE (    
        NO_URUT int,    
        COLUMN_DESTINATION varchar(100),    
        DATA_TYPE varchar(100)    
    )    
    
    
    IF OBJECT_ID('tempdb..#TEMP_DETAIL') IS NOT NULL    
    BEGIN    
        DROP TABLE #TEMP_DETAIL    
    END    
    SELECT    
        RANK() OVER (ORDER BY PKID ASC) AS NO_URUT,    
        * INTO #TEMP_DETAIL    
    FROM TBLU_DOC_TEMP_DETAIL(NOLOCK)    
    WHERE UPLOADID = @UPLOADID    
    
INSERT INTO @DESTINATION    
        SELECT    
            ORDINAL_POSITION NO_URUT,    
            COLUMN_NAME COLUMN_DESTINATION,    
            DATA_TYPE    
        FROM INFORMATION_SCHEMA.COLUMNS    
        WHERE TABLE_NAME = (SELECT    
            TABLEDESTINATION    
        FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)    
        WHERE PKID = (SELECT    
            MAPPINGID    
        FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
        WHERE UPLOADID = @UPLOADID))    
        AND COLUMN_NAME NOT IN ('UPLOADID', 'UPLOADBY', 'UPLOADDATE', 'UPLOADHOST', 'APPROVEDBY', 'APPROVEDDATE', 'APPROVEDHOST')    
    
    DELETE FROM @SOURCE_HEADER    
    INSERT INTO @SOURCE_HEADER    
        SELECT    
            ROW_NUMBER() OVER (ORDER BY PKID) NO_URUT,    
            COLUMN_NAME COLUMN_SOURCE    
        FROM TBLU_DOC_TEMP_HEADER(NOLOCK)    
  WHERE UPLOADID = @UPLOADID    
    
       DECLARE @Max int,    
                @Col int = 1,    
                @ColType varchar(50),    
                @ColName varchar(50),    
                @ColDesc varchar(50),    
                @ColMaxLen int,    
                @ColNullStatus varchar(3),    
                @Count int,    
                @query varchar(max),    
                @querycount varchar(max),    
                @queryCountNull varchar(max),    
                @queryCheckNull varchar(max),    
                @countNull int    
        SET @Max = (SELECT    
            COUNT(1)    
        FROM TBLU_DOC_TEMP_DETAIL(NOLOCK)    
        WHERE UPLOADID = @UPLOADID)    
    
 DECLARE @Result int    
    DECLARE @Message varchar(100)      
 DECLARE @TBLU_DOC_TEMP_EXCEPTION TABLE (    
        UPLOAD_ID int,    
        ROWNUMBER int,    
        COLUMN_NAME varchar(100),    
        COLUMN_VALUE varchar(100),    
        ERRORMESSAGE varchar(100)    
    )    
----------------------------------------------------------------------------------------------------------------------------    
  --START LOOP    
----------------------------------------------------------------------------------------------------------------------------    
  WHILE(@COL<=@MAX)    
  BEGIN     
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for Number of Issuer - TBLU_PD_SNP_CORPORATE , TBLU_PD_SNP_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
    IF EXISTS(    
  SELECT CHECK_NUMBER FROM (    
  SELECT DISTINCT     
  CASE WHEN NUMBER = 1 THEN 'MATCH'     
        ELSE 'NOT MATCH'     
        END CHECK_NUMBER    
  FROM    
  (    
  SELECT COLUMN_1, COLUMN_2, COLUMN_3, COUNT(COLUMN_6) NUMBER    
  FROM    
  (    
  SELECT DISTINCT A.COLUMN_1, A.COLUMN_2, A.COLUMN_3,     
  A.COLUMN_6    
  FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
  WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
  ) D    
  GROUP BY COLUMN_1, COLUMN_2, COLUMN_3    
  HAVING COUNT(COLUMN_6) > 1    
  ) H )E    
    
        WHERE CHECK_NUMBER = 'NOT MATCH')    
    
    
    SET @Message = 'Number_Of_Issuer Must Be Same for 1 Bucket_From from Same Effective_Date.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_6 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Number_Of_Issuer'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (SELECT COLUMN_1, COLUMN_2, COLUMN_3, COUNT(COLUMN_6) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_1, A.COLUMN_2, COLUMN_3,     
    A.COLUMN_6    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
    WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
    ) D    
    GROUP BY COLUMN_1, COLUMN_2, COLUMN_3    
    HAVING COUNT(COLUMN_6) > 1    
    )G ON F.COLUMN_2 = G.COLUMN_2 AND F.COLUMN_1 = G.COLUMN_1 AND F.COLUMN_3 = G.COLUMN_3    
    WHERE UPLOADID = @UPLOADID AND NO_URUT = @COL    
----------------------------------------------------------------------------------------------------------------------------    
  -- Exception for Default_Rate - TBLU_PD_SNP_CORPORATE , TBLU_PD_SNP_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS(    
  SELECT CHECK_HEADER FROM (    
  SELECT DISTINCT     
  CASE WHEN NUMBER = 1 THEN 'MATCH'     
        ELSE 'NOT MATCH'     
        END CHECK_HEADER    
  FROM    
  (    
  SELECT COLUMN_1, COLUMN_2, COLUMN_3, COUNT(COLUMN_7) NUMBER    
  FROM    
  (    
  SELECT DISTINCT A.COLUMN_1, A.COLUMN_2, A.COLUMN_3,    
  A.COLUMN_7    
  FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
  WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
  ) D    
  GROUP BY COLUMN_1, COLUMN_2, COLUMN_3    
  HAVING COUNT(COLUMN_7) > 1    
  ) H )E    
    
        WHERE CHECK_HEADER = 'NOT MATCH')    
    
    
    SET @Message = 'Default_Rate Must Be Same for 1 Bucket_From from Same Effective_Date.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_7 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Default_Rate'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (SELECT COLUMN_1, COLUMN_2, COLUMN_3, COUNT(COLUMN_7) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_1, A.COLUMN_2, A.COLUMN_3,    
    A.COLUMN_7    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
    WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
    ) D    
    GROUP BY COLUMN_1, COLUMN_2, COLUMN_3    
    HAVING COUNT(COLUMN_7) > 1    
    )G ON F.COLUMN_2 = G.COLUMN_2 AND F.COLUMN_1 = G.COLUMN_1 AND F.COLUMN_3 = G.COLUMN_3    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for Annual_PD_Rate TBLU_PD_SNP_CORPORATE , TBLU_PD_SNP_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS(    
  SELECT CHECK_HEADER FROM (    
  SELECT DISTINCT     
  CASE WHEN NUMBER = 1 THEN 'MATCH'     
        ELSE 'NOT MATCH'     
        END CHECK_HEADER    
  FROM    
  (    
  SELECT COLUMN_1, COLUMN_2, COUNT(COLUMN_8) NUMBER    
  FROM    
  (    
  SELECT DISTINCT A.COLUMN_1,A.COLUMN_2,    
  A.COLUMN_8    
  FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
  WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
  ) D    
  GROUP BY COLUMN_1, COLUMN_2    
  HAVING COUNT(COLUMN_8) > 1    
  ) H )E    
      
        WHERE CHECK_HEADER = 'NOT MATCH')    
    
    SET @Message = 'Annual_PD_Rate Must Be Same from One Effective_Date.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_8 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Annual_PD_Rate'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (SELECT COLUMN_1, COLUMN_2, COUNT(COLUMN_8) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_1, A.COLUMN_2, A.COLUMN_8    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    --WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID IN ('1','2','3')    
    WHERE A.UPLOADID = @UPLOADID AND C.MAPPINGNAME IN ('PD_SNP_CORPORATE','PD_SNP_SOVEREIGN')    
    ) D    
    GROUP BY COLUMN_1, COLUMN_2    
    HAVING COUNT(COLUMN_8) > 1    
    )G ON F.COLUMN_1 = G.COLUMN_1 AND F.COLUMN_2 = G.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUB_SEGMENT - TBLU_PD_SNP_CORPORATE    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   --AND B.MAPPINGID = '2'    
   AND C.MAPPINGNAME = 'PD_SNP_CORPORATE'    
   AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER WHERE SEGMENT_TYPE = 'PD_SEGMENT' AND SEGMENT = 'FI')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Sub_Segment Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Sub_Segment'    
    
INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_2    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'PD_SNP_CORPORATE'        AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
             WHERE SEGMENT_TYPE = 'PD_SEGMENT' AND SEGMENT = 'FI')    
     GROUP BY A.COLUMN_2    
     ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUB_SEGMENT - TBLU_PD_SNP_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   --AND B.MAPPINGID = '2'    
   AND C.MAPPINGNAME = 'PD_SNP_SOVEREIGN'    
   AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER WHERE SEGMENT_TYPE = 'PD_SEGMENT' AND SEGMENT = 'SOVEREIGN')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Sub_Segment Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Sub_Segment'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_2    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'PD_SNP_SOVEREIGN'    
      AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
             WHERE SEGMENT_TYPE = 'PD_SEGMENT' AND SEGMENT = 'SOVEREIGN')    
     GROUP BY A.COLUMN_2    
     ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUB_SEGMENT - TBLU_PD_EXTERNAL_BUCKET_MAP    
----------------------------------------------------------------------------------------------------------------------------    
/* IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID    
  AND B.MAPPINGID = '4'    
  AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER WHERE SEGMENT_TYPE = 'PD_SEGMENT'    
  AND SEGMENT IN('SOVEREIGN', 'FI'))    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Sub_Segment Not in Master Segment, Segment Type = PD SEGMENT and SEGMENT = FI, SOVEREIGN.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Sub_Segment'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_2    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID = '4'    
    AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
    WHERE SEGMENT_TYPE = 'PD_SEGMENT' AND SEGMENT IN ('SOVEREIGN', 'FI')     
    ) GROUP BY A.COLUMN_2    
    ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
*/    
    
    
-- ASK MBA RILLA TO CONFIRMED    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for CCY - IFRS_EARLY_LOSS_ACCOUNT    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT          
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'EARLY_LOSS'    
  AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'PMT_CCY')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'CCY Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'CCY'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_2    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME= 'EARLY_LOSS'    
    AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL    
    WHERE COMMONCODE = 'PMT_CCY'     
    ) GROUP BY A.COLUMN_2    
    ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL     
    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for BI_FORM - IFRS_ACOD_BIFORM_PARAM    
----------------------------------------------------------------------------------------------------------------------------*    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'ACOD_BIFORM'    
  AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'PMT_BIFORM')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Bi_Form Value not Registered in CB or WB.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'BI_FORM'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_2    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'ACOD_BIFORM'    
    AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'PMT_BIFORM')     
    GROUP BY A.COLUMN_2    
    ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for PRODUCT_ENTITY - IFRS_ACOD_BIFORM_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_3,COUNT(A.COLUMN_3) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'ACOD_BIFORM'    
  AND COLUMN_3 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'S0052')    
  GROUP BY A.COLUMN_3    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Product_Entity not in C or I Value List.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_3 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Product_Entity'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_3, COUNT(COLUMN_3) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_3    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'ACOD_BIFORM'    
    AND COLUMN_3 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'S0052')     
    GROUP BY A.COLUMN_3    
    ) B GROUP BY COLUMN_3    
    ) E ON F.COLUMN_3 = E.COLUMN_3    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for OFF_BS_FLAG - IFRS_ACOD_BIFORM_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_4,COUNT(A.COLUMN_4) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'ACOD_BIFORM'    
  AND COLUMN_4 NOT IN ('0','1')    
  GROUP BY A.COLUMN_4    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'OFF_BS_FLAG not in 0 or 1 Value List.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_4 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'OFF_BS_FLAG'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_4, COUNT(COLUMN_4) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_4    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'ACOD_BIFORM'    
    AND COLUMN_4 NOT IN ('0','1')     
    GROUP BY A.COLUMN_4    
    ) B GROUP BY COLUMN_4    
    ) E ON F.COLUMN_4 = E.COLUMN_4    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for ACOD - IFRS_ACOD_BIFORM_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_1,COUNT(A.COLUMN_1) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = 74     
  AND C.MAPPINGNAME = 'ACOD_BIFORM'    
  AND (LEN(COLUMN_1) < 5 OR LEN(COLUMN_1) > 7)    
  GROUP BY A.COLUMN_1     
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'ACOD length < 5 or > 7.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_1 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'ACOD'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_1, COUNT(COLUMN_1) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_1    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'ACOD_BIFORM'    
    AND (LEN(COLUMN_1) < 5 OR LEN(COLUMN_1) > 7)    
    GROUP BY A.COLUMN_1    
    ) B GROUP BY COLUMN_1    
    ) E ON F.COLUMN_1 = E.COLUMN_1    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for DOWNLOAD_DATE - IFRS_EARLY_LOSS_ACCOUNT    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_1,COUNT(A.COLUMN_1) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'EARLY_LOSS'    
  AND COLUMN_1 < @CURRDATE    
  GROUP BY A.COLUMN_1    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Download_Date Must be Greater or Equal with Current Date.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_1 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Download_Date'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_1, COUNT(COLUMN_1) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_1    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'EARLY_LOSS'    
    AND COLUMN_1 < @CURRDATE    
    GROUP BY A.COLUMN_1    
    ) B GROUP BY COLUMN_1    
    ) E ON F.COLUMN_1 = E.COLUMN_1    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for COLLATERAL_CATEGORY - IFRS_COLL_HAIRCUT_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
  AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'COLL_CAT_01')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Collateral_Category not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Collateral_Category'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_2    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
    AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'COLL_CAT_01')    
    GROUP BY A.COLUMN_2    
    ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for COLLATERAL_HAIRCUT - IFRS_COLL_HAIRCUT_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_3,COUNT(A.COLUMN_3) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
  AND COLUMN_3 > 100    
  GROUP BY A.COLUMN_3    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Collateral_Haircut Maximum Value is 100.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_3 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Collateral_Haircut'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_3, COUNT(COLUMN_3) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_3    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
    AND COLUMN_3 > 100    
    GROUP BY A.COLUMN_3    
    ) B GROUP BY COLUMN_3    
    ) E ON F.COLUMN_3 = E.COLUMN_3    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for COLLATERAL_FORCE_SALE - IFRS_COLL_HAIRCUT_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_4,COUNT(A.COLUMN_4) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
  AND COLUMN_4 > 100    
  GROUP BY A.COLUMN_4    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Collateral_Force_Sale Maximum Value is 100.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_4 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Collateral_Force_Sale'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_4, COUNT(COLUMN_4) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_4    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
    AND COLUMN_4 > 100    
    GROUP BY A.COLUMN_4    
    ) B GROUP BY COLUMN_4    
    ) E ON F.COLUMN_4 = E.COLUMN_4    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for FSV - IFRS_COLL_HAIRCUT_PARAM    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_5,COUNT(A.COLUMN_4) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
  AND COLUMN_5 > 100    
  GROUP BY A.COLUMN_5    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'FSV Maximum Value is 100.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_5 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'FSV'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_5, COUNT(COLUMN_5) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_5    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'COLL_HAIRCUT'    
    AND COLUMN_5 > 100    
    GROUP BY A.COLUMN_5    
    ) B GROUP BY COLUMN_5    
    ) E ON F.COLUMN_5 = E.COLUMN_5    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for GROUP_VALCTR - IFRS_MASTER_VALCTR_GROUP    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_3,COUNT(A.COLUMN_3) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'VALCTR_GROUP'    
  AND COLUMN_3 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'GRP_VALCTR')    
  GROUP BY A.COLUMN_3    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Group_Valctr not in CB or WB Value List.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_3 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Group_Valctr'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_3, COUNT(COLUMN_3) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_3    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'VALCTR_GROUP'    
    AND COLUMN_3 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'GRP_VALCTR')     
    GROUP BY A.COLUMN_3    
    ) B GROUP BY COLUMN_3    
    ) E ON F.COLUMN_3 = E.COLUMN_3    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUBGROUP_VALCTR_CODE - IFRS_MASTER_VALCTR_GROUP    
----------------------------------------------------------------------------------------------------------------------------    
/* IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND C.MAPPINGNAME = 'VALCTR_GROUP'    
  AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'SUBGRP_VALCTR')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'SubGroup_Valctr_Code not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'SubGroup_Valctr'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_2    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID     
    AND C.MAPPINGNAME = 'VALCTR_GROUP'    
    AND COLUMN_2 NOT IN (SELECT VALUE1 FROM TBLM_COMMONCODEDETAIL WHERE COMMONCODE = 'SUBGRP_VALCTR')    
    GROUP BY A.COLUMN_2    
    ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
*/    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUB_SEGMENT - TBLU_MOODYS_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   --AND B.MAPPINGID = '2'    
   AND C.MAPPINGNAME = 'MOODYS_SOVEREIGN'    
   AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
         WHERE SEGMENT_TYPE = 'URR_SEGMENT' AND SEGMENT = 'SOVEREIGN')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Sub_Segment Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Sub_Segment'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_2    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'MOODYS_SOVEREIGN'    
      AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
             WHERE SEGMENT_TYPE = 'URR_SEGMENT' AND SEGMENT = 'SOVEREIGN')    
     GROUP BY A.COLUMN_2    
     ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for CURRENCY - TBLU_MOODYS_SOVEREIGN    
----------------------------------------------------------------------------------------------------------------------------    
 /*IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_5,COUNT(A.COLUMN_5) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   AND C.MAPPINGNAME = 'MOODYS_SOVEREIGN'    
   AND COLUMN_5 NOT IN ('IDR','VLS','BOT')    
  GROUP BY A.COLUMN_5    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Currency Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_5 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Currency'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_5, COUNT(COLUMN_5) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_5    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'MOODYS_SOVEREIGN'    
      AND COLUMN_5 NOT IN ('IDR','VLS','BOT')    
     GROUP BY A.COLUMN_5    
     ) B GROUP BY COLUMN_5    
    ) E ON F.COLUMN_5 = E.COLUMN_5    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL*/    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for SUB_SEGMENT - TBLU_MOODYS_CORPORATE    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_2,COUNT(A.COLUMN_2) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   --AND B.MAPPINGID = '2'    
   AND C.MAPPINGNAME = 'MOODYS_CORPORATE'    
   AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
         WHERE SEGMENT_TYPE = 'URR_SEGMENT' AND SEGMENT = 'FI')    
  GROUP BY A.COLUMN_2    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Sub_Segment Not Registered.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Sub_Segment'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_2, COUNT(COLUMN_2) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_2    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'MOODYS_CORPORATE'    
      AND COLUMN_2 NOT IN (SELECT SUB_SEGMENT FROM IFRS_MSTR_SEGMENT_RULES_HEADER     
             WHERE SEGMENT_TYPE = 'URR_SEGMENT' AND SEGMENT = 'FI')    
     GROUP BY A.COLUMN_2    
     ) B GROUP BY COLUMN_2    
    ) E ON F.COLUMN_2 = E.COLUMN_2    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for RECOVERY_RATE - TBLU_MOODYS_CORPORATE    
----------------------------------------------------------------------------------------------------------------------------    
 IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_3,COUNT(A.COLUMN_3) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
   ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
   ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
   --AND B.MAPPINGID = '2'    
   AND C.MAPPINGNAME = 'MOODYS_CORPORATE'    
   AND (COLUMN_3 < '0' OR COLUMN_3 > '1')    
  GROUP BY A.COLUMN_3    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Recovery_Rate Value < 0 or > 1.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_3 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Recovery_Rate'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_3, COUNT(COLUMN_3) NUMBER    
    FROM    
     (    
     SELECT DISTINCT A.COLUMN_3    
     FROM TBLU_DOC_TEMP_DETAIL A    
     LEFT JOIN TBLT_UPLOAD_POOL B    
     ON A.UPLOADID = B.UPLOADID    
     LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
     ON C.PKID = B.MAPPINGID    
     WHERE A.UPLOADID = @UPLOADID     
      --AND B.MAPPINGID = '2'    
      AND C.MAPPINGNAME = 'MOODYS_CORPORATE'    
      AND (COLUMN_3 < '0' OR COLUMN_3 > '1')    
     GROUP BY A.COLUMN_3    
     ) B GROUP BY COLUMN_3    
    ) E ON F.COLUMN_3 = E.COLUMN_3    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
----------------------------------------------------------------------------------------------------------------------------    
 -- Exception for GROUP_ACOD - IFRS_MASTER_SAPGL_RECONCILE    
----------------------------------------------------------------------------------------------------------------------------    
/* IF EXISTS (    
  SELECT CHECK_HEADER FROM     
   (    
    SELECT DISTINCT     
    CASE WHEN NUMBER >= 1 THEN 'NOT MATCH'     
          ELSE 'MATCH'     
          END CHECK_HEADER    
    FROM    
    (    
  SELECT DISTINCT A.COLUMN_5,COUNT(A.COLUMN_5) NUMBER FROM TBLU_DOC_TEMP_DETAIL A    
  LEFT JOIN TBLT_UPLOAD_POOL B    
  ON A.UPLOADID = B.UPLOADID    
  LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
  ON C.PKID = B.MAPPINGID    
  WHERE A.UPLOADID = @UPLOADID     
  AND B.MAPPINGID = '8'    
  AND COLUMN_5 NOT IN ('OFF_BS', 'OS_PRIN', 'OS_DUE')    
  GROUP BY A.COLUMN_5    
  )B     
  )E    
  WHERE CHECK_HEADER = 'NOT MATCH')    
    
  SET @Message = 'Group_Acod Not in OFF_BS, OS_PRIN, OS_DUE.'    
                SET @ColType = (SELECT DATA_TYPE FROM @DESTINATION WHERE NO_URUT = @Col)    
    SELECT @ColName = COLUMN_2 FROM #TEMP_DETAIL where NO_URUT = @col    
    SET @ColDesc = 'Group_Acod'    
    
    INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
    SELECT UPLOADID , NO_URUT,  @ColDesc,  @ColName ,  @Message     
    FROM #TEMP_DETAIL F    
    INNER JOIN (    
    SELECT COLUMN_5, COUNT(COLUMN_5) NUMBER    
    FROM    
    (    
    SELECT DISTINCT A.COLUMN_5    
    FROM TBLU_DOC_TEMP_DETAIL A    
    LEFT JOIN TBLT_UPLOAD_POOL B    
    ON A.UPLOADID = B.UPLOADID    
    LEFT JOIN TBLM_MAPPINGRULEHEADER_NEW C    
    ON C.PKID = B.MAPPINGID    
    WHERE A.UPLOADID = @UPLOADID AND B.MAPPINGID = '6'    
    AND COLUMN_5 NOT IN ('OFF_BS', 'OS_PRIN', 'OS_DUE')     
    GROUP BY A.COLUMN_5    
    ) B GROUP BY COLUMN_5    
    ) E ON F.COLUMN_5 = E.COLUMN_5    
    WHERE UPLOADID = @UPLOADID  AND NO_URUT = @COL    
*/    
    
----------------------------------------------------------------------------------------------------------------------------     
 -- END LOOP    
----------------------------------------------------------------------------------------------------------------------------       
  SET @COL = @COL+1    
  END    
----------------------------------------------------------------------------------------------------------------------------    
 --UPDATE VALIDATION STATUS    
----------------------------------------------------------------------------------------------------------------------------    
    IF ((SELECT    
            COUNT(*)    
        FROM @TBLU_DOC_TEMP_EXCEPTION    
        WHERE [UPLOAD_ID] = @UploadId)    
        > 0)    
    BEGIN    
     
        DELETE FROM TBLU_DOC_TEMP_EXCEPTION    
        WHERE UPLOADID = @UploadId    
        INSERT INTO TBLU_DOC_TEMP_EXCEPTION    
            SELECT    
                A.*,    
                B.[CREATEDBY],    
                B.[CREATEDDATE],    
                B.[CREATEDHOST],    
                B.[UPDATEDBY],    
                B.[UPDATEDDATE],    
                B.[UPDATEDHOST]    
            FROM @TBLU_DOC_TEMP_EXCEPTION A    
            INNER JOIN [dbo].[TBLT_UPLOAD_POOL](NOLOCK) B    
                ON A.UPLOAD_ID = B.UPLOADID    
    
        UPDATE TBLT_UPLOAD_POOL    
        SET STATUS = 'VALIDATION FAILED'    
        WHERE UPLOADID = @UploadId    
    
    END    
    ELSE    
    BEGIN    
----------------------------------------------------------------------------------------------------------------------------    
        --check Flag approval    
----------------------------------------------------------------------------------------------------------------------------    
        DECLARE @flagApproval int    
        SET @flagApproval = (SELECT    
            NEEDAPPROVAL    
        FROM [dbo].[TBLM_MAPPINGRULEHEADER_NEW](NOLOCK)    
        WHERE PKID = (SELECT    
            MAPPINGID    
        FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
        WHERE UPLOADID = @UploadId))    
        IF @flagApproval = 0    
        BEGIN    
            EXEC [dbo].[SP_IFRS_UPLOAD_APPROVAL] @uploadId,    
                                                 'SYSTEM',    
                                                 'SYSTEM'    
        END    
        ELSE    
        IF @flagApproval = 1    
        BEGIN    
            UPDATE TBLT_UPLOAD_POOL    
            SET STATUS = 'PENDING'    
            WHERE UPLOADID = @UploadId    
        END    
    END    
  SELECT @UPLOADSTATUS =  STATUS FROM TBLT_UPLOAD_POOL WHERE UPLOADID = @UPLOADID    
    
END    
GO
