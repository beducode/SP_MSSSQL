USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_IMP_ECL_EAD_RESULT_NONPRK]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_IMP_ECL_EAD_RESULT_NONPRK]                           
@DOWNLOAD_DATE DATE = NULL                          
AS                             
    DECLARE @V_CURRDATE DATE                           
BEGIN                
                           
    IF (@DOWNLOAD_DATE IS NULL)                              
    BEGIN                              
        SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE;                           
    END                              
    ELSE                              
    BEGIN                              
        SET @V_CURRDATE = @DOWNLOAD_DATE                              
    END;                                
                    
    DECLARE @MAX_LIFETIME INT                  
    SELECT @MAX_LIFETIME = MAX(LIFETIME - 1) FROM TMP_IFRS_ECL_IMA;                
                
    DROP TABLE IF EXISTS #TMP_LISTDATE;                
    WITH CTE_DATE AS (                
        SELECT EOMONTH(DATEADD(MONTH, 1, @V_CURRDATE)) AS START_DATE,                
        EOMONTH(DATEADD(MONTH, @MAX_LIFETIME, @V_CURRDATE)) AS MAX_DATE                
        UNION ALL                
        SELECT EOMONTH(DATEADD(MONTH,1, START_DATE)), MAX_DATE                
        FROM CTE_DATE                
        WHERE EOMONTH(DATEADD(MONTH,1, START_DATE)) <=  MAX_DATE                
    )                  
    SELECT START_DATE                   
    INTO #TMP_LISTDATE                
    FROM CTE_DATE                
    OPTION (MAXRECURSION 0);                 
                
    DROP TABLE IF EXISTS #TMP_MAXDATE;                
    SELECT MASTERID, MAX(EOMONTH(PMTDATE)) AS MAXDATE                
    INTO #TMP_MAXDATE                
    FROM IFRS_PAYM_SCHD_ALL(NOLOCK) A                 
    WHERE EOMONTH(PMTDATE) > EOMONTH(@V_CURRDATE)                
     AND (END_DATE IS NULL OR END_DATE > @V_CURRDATE)                
     AND DOWNLOAD_DATE <= @V_CURRDATE                
    GROUP BY MASTERID;                
                
    DROP TABLE IF EXISTS #TMP_IFRS_ECL_MODEL;                
                
    SELECT DISTINCT B.EAD_BALANCE, EAD_MODEL_ID                            
    INTO #TMP_IFRS_ECL_MODEL                              
    FROM TMP_IFRS_ECL_IMA A                            
    JOIN IFRS_EAD_RULES_CONFIG B                            
    ON A.EAD_MODEL_ID = B.PKID                             
    WHERE B.EAD_BALANCE LIKE '%INTEREST_ACCRUED%'                 
                     
    UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'UNUSED_AMOUNT', 'A.UNUSED_AMOUNT')            
    UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'OUTSTANDING', 'A.OUTSTANDING')               
    UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'INTEREST_ACCRUED', 'A.INTEREST_ACCRUED')          
	UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'COLL_AMOUNT', 'A.COLL_AMOUNT')            
    UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, 'CCF', 'A.CCF')                             
    UPDATE #TMP_IFRS_ECL_MODEL SET EAD_BALANCE = REPLACE(EAD_BALANCE, '+', ' + ')              
                     
    DROP TABLE IF EXISTS #SCHD              
    SELECT MAX(DOWNLOAD_DATE) AS DOWNLOAD_DATE, MASTERID              
    INTO #SCHD              
    FROM IFRS_PAYM_SCHD_ALL               
    WHERE DOWNLOAD_DATE <= @V_CURRDATE              
    GROUP BY MASTERID              
            
    DROP TABLE IF EXISTS #IFRS_EAD_PAYM_NONPRK;               
    WITH CTE_PAYM_SCHD                              
    (                              
        DOWNLOAD_DATE,                           
        MASTERID,                           
        PMTDATE,                           
        OSPRN,                           
        PRINCIPAL,                           
        END_DATE,                           
        RN                              
    )                             
    AS                          
    (                              
SELECT                           
            EOMONTH(A.DOWNLOAD_DATE) AS DOWNLOAD_DATE,                   
            A.MASTERID,                   
EOMONTH(A.PMTDATE) AS PMTDATE,                   
            MIN(A.OSPRN) AS OSPRN,                   
            SUM(A.PRINCIPAL) AS PRINCIPAL,                   
   EOMONTH(A.END_DATE) AS END_DATE,                   
            ROW_NUMBER() OVER (PARTITION BY A.MASTERID, EOMONTH(A.PMTDATE) ORDER BY A.DOWNLOAD_DATE) RN               
        FROM IFRS_PAYM_SCHD_ALL (NOLOCK) A              
        JOIN #SCHD B ON A.DOWNLOAD_DATE = B.DOWNLOAD_DATE AND A.MASTERID = B.MASTERID            
        WHERE                 
         (EOMONTH(A.DOWNLOAD_DATE) <= @V_CURRDATE OR @V_CURRDATE <= PMTDATE)            
            AND (A.END_DATE IS NULL OR EOMONTH(A.END_DATE) <= @V_CURRDATE)            
            AND EOMONTH(A.PMTDATE) >= @V_CURRDATE            
        GROUP BY                     
            A.DOWNLOAD_DATE,                   
            A.MASTERID,                   
            EOMONTH(A.PMTDATE),                   
            EOMONTH(A.END_DATE)                               
    )                  
    SELECT                 
        DOWNLOAD_DATE                
        ,MASTERID                
        ,PMTDATE                
        ,OSPRN                
        ,PRINCIPAL                
        ,SEQ               
    INTO #IFRS_EAD_PAYM_NONPRK                
    FROM                 
    (                
        SELECT                 
            EOMONTH(DOWNLOAD_DATE) AS DOWNLOAD_DATE                
            ,B.MASTERID                
            ,C.START_DATE AS PMTDATE                
            ,ISNULL(D.TOTAL_PRIN,0) - SUM(ISNULL(PRINCIPAL,0)) OVER (PARTITION BY B.MASTERID ORDER BY C.START_DATE)   AS OSPRN                
            ,SUM(PRINCIPAL) OVER (PARTITION BY B.MASTERID ORDER BY C.START_DATE) AS PRINCIPAL                
            ,ROW_NUMBER() OVER (PARTITION BY B.MASTERID ORDER BY C.START_DATE) AS SEQ                
        FROM #TMP_MAXDATE B                
        JOIN #TMP_LISTDATE C ON B.MAXDATE >= C.START_DATE                 
        LEFT JOIN CTE_PAYM_SCHD A ON A.MASTERID = B.MASTERID AND A.PMTDATE = C.START_DATE AND RN = 1        
  LEFT JOIN (SELECT MASTERID, SUM(ISNULL(PRINCIPAL,0)) AS TOTAL_PRIN FROM CTE_PAYM_SCHD GROUP BY MASTERID) D ON B.MASTERID = D.MASTERID                  
    ) PAYM_SCHD;                           
                           
    WITH CTE_EAD AS                           
    (                              
        SELECT                           
            DOWNLOAD_DATE,                           
            MASTERID,                           
            GROUP_SEGMENT,                           
            SEGMENT,                           
            SUB_SEGMENT,                           
            SEGMENTATION_ID,                           
            ACCOUNT_NUMBER,                           
            CUSTOMER_NUMBER,                           
            SICR_RULE_ID,                           
            BUCKET_GROUP,                           
            BUCKET_ID,                           
            LIFETIME,                           
            STAGE,                           
            REVOLVING_FLAG,                             
            PD_SEGMENT,                             
            LGD_SEGMENT,                             
            EAD_SEGMENT,                             
            PREV_ECL_AMOUNT,                           
            ECL_MODEL_ID,                           
            EAD_MODEL_ID,                           
            CCF_RULES_ID,                           
            LGD_MODEL_ID,                              
            PD_MODEL_ID,                              
            0 AS SEQ,                           
            1 AS FL_YEAR,                           
            1 AS FL_MONTH,                           
            EIR,                           
            OUTSTANDING,                           
            UNAMORT_COST_AMT,                           
            UNAMORT_FEE_AMT,                           
            INTEREST_ACCRUED,                            
            UNUSED_AMOUNT,                             
            FAIR_VALUE_AMOUNT,           
            EAD_BALANCE,                           
            PLAFOND,                                       
            EAD_BALANCE AS EAD,                                              
            BI_COLLECTABILITY,        
			COLL_AMOUNT,
			SEGMENT_FLAG                           
        FROM TMP_IFRS_ECL_IMA (NOLOCK)                  
        WHERE             
  --FD change 28/11/2019 to add loan t24 non revolving into this ead non prk population          
  (          
  (DATA_SOURCE='LOAN' AND PRODUCT_TYPE_1 <> 'PRK' AND DATA_SOURCE <> 'LIMIT')          
  or          
  (           
  DATA_SOURCE='LOAN_T24' and REVOLVING_FLAG=0          
  )          
  )          
   AND IMPAIRED_FLAG = 'C'               
                        
        UNION ALL                           
                  
        SELECT                           
            A.DOWNLOAD_DATE,                           
            A.MASTERID,                           
            A.GROUP_SEGMENT,                     
            A.SEGMENT,                           
            A.SUB_SEGMENT,                           
            A.SEGMENTATION_ID,                           
            A.ACCOUNT_NUMBER,                           
            A.CUSTOMER_NUMBER,                           
            A.SICR_RULE_ID,                           
            A.BUCKET_GROUP,                           
            A.BUCKET_ID,                       
            A.LIFETIME,                           
            A.STAGE,                           
            A.REVOLVING_FLAG,                             
            A.PD_SEGMENT,                             
            A.LGD_SEGMENT,                             
            A.EAD_SEGMENT,                             
            A.PREV_ECL_AMOUNT,                           
            A.ECL_MODEL_ID,                           
            A.EAD_MODEL_ID,                           
            A.CCF_RULES_ID,                             
            A.LGD_MODEL_ID,                            
            A.PD_MODEL_ID,                            
            B.SEQ,                           
            (CAST(B.SEQ AS INT) / 12) + 1 AS FL_YEAR,                           
            ((B.SEQ) % 12) + 1 AS FL_MONTH,                           
            A.EIR,                           
            CASE WHEN ISNULL(A.OUTSTANDING,0) - ISNULL(B.PRINCIPAL,0) < 0 THEN 0 ELSE ISNULL(A.OUTSTANDING,0) - ISNULL(B.PRINCIPAL,0) END AS OUTSTANDING,                           
            A.UNAMORT_COST_AMT,                           
            A.UNAMORT_FEE_AMT,                           
            A.INTEREST_ACCRUED,                            
            A.UNUSED_AMOUNT,                             
            A.FAIR_VALUE_AMOUNT,                                            
            A.EAD_BALANCE,                           
            A.PLAFOND,                                             
            CAST((A.EAD_BALANCE -                     
            CASE WHEN A.BI_COLLECTABILITY IN (1, 2) AND A.EAD_MODEL_ID IN (SELECT EAD_MODEL_ID FROM #TMP_IFRS_ECL_MODEL) THEN ISNULL(A.INTEREST_ACCRUED,0) --- CASE WHEN B.SEQ - 1 >= 1 THEN A.INTEREST_ACCRUED ELSE 0 END          
            ELSE 0 END -                                            
            ISNULL(B.PRINCIPAL,0)) AS DECIMAL(32, 6)) AS EAD,                                              
            A.BI_COLLECTABILITY,           
			A.COLL_AMOUNT,
			A.SEGMENT_FLAG                
        FROM TMP_IFRS_ECL_IMA A                             
        JOIN #IFRS_EAD_PAYM_NONPRK B ON A.MASTERID = B.MASTERID                
        WHERE A.LIFETIME > B.SEQ                 
        AND ((A.STAGE = 1 AND B.SEQ < 12) OR (A.STAGE IN (2,3)))          
        AND IMPAIRED_FLAG = 'C'         
  AND    ((A.DATA_SOURCE='LOAN' AND A.PRODUCT_TYPE_1 <> 'PRK' AND A.DATA_SOURCE <> 'LIMIT')   OR  (A.DATA_SOURCE='LOAN_T24' and A.REVOLVING_FLAG=0 ))                 
    )                
    SELECT                        
        DOWNLOAD_DATE,                           
        MASTERID,                           
        GROUP_SEGMENT,                           
        SEGMENT,                           
        SUB_SEGMENT,                           
        SEGMENTATION_ID,                           
        ACCOUNT_NUMBER,                           
        CUSTOMER_NUMBER,                              
        SICR_RULE_ID,                           
        BUCKET_GROUP,                           
        BUCKET_ID,                           
        LIFETIME,                           
        STAGE,                           
        REVOLVING_FLAG,                             
        PD_SEGMENT,                             
        LGD_SEGMENT,                             
		EAD_SEGMENT,                             
        PREV_ECL_AMOUNT,                           
        ECL_MODEL_ID,                           
        EAD_MODEL_ID,                           
        CCF_RULES_ID,                             
        LGD_MODEL_ID,                             
        PD_MODEL_ID,                              
        SEQ,                           
        FL_YEAR,                           
        FL_MONTH,                           
        EIR,                           
        OUTSTANDING,                           
        UNAMORT_COST_AMT,                           
        UNAMORT_FEE_AMT,                           
        INTEREST_ACCRUED,                            
        UNUSED_AMOUNT,                           
        FAIR_VALUE_AMOUNT,                           
        EAD_BALANCE,                           
        PLAFOND,                           
        EAD,                            
        BI_COLLECTABILITY,        
		COLL_AMOUNT,
		SEGMENT_FLAG             
    INTO #CTE_EAD                        
    FROM CTE_EAD                
    ORDER BY MASTERID, SEQ               
    OPTION (MAXRECURSION 0)               
                              
    UPDATE #CTE_EAD SET SEQ = SEQ + 1               
    WHERE DOWNLOAD_DATE = @V_CURRDATE               
                  
    -- UPDATING & DELETING LESS THAN ZERO                                    
    SELECT MASTERID, MIN(SEQ) SEQ, COUNT(1) [COUNT]                                    
    INTO #ZEROING                                    
    FROM #CTE_EAD                                     
    WHERE EAD <= 0 AND DOWNLOAD_DATE = @V_CURRDATE                    
    GROUP BY MASTERID                                    
    HAVING COUNT(1) > 1                                    
    ORDER BY MASTERID                                    
                          
    UPDATE A                                    
    SET A.EAD = 0                                    
    FROM #CTE_EAD A                                    
    JOIN #ZEROING B                                     
    ON A.MASTERID = B.MASTERID AND A.SEQ = B.SEQ                                    
    WHERE A.EAD <= 0                                    
                                    
    DELETE A                                    
    FROM #CTE_EAD A                                    
    JOIN #ZEROING B                                     
    ON A.MASTERID = B.MASTERID AND A.SEQ > B.SEQ                                    
    WHERE A.EAD <= 0                                    
    -- END UPDATING & DELETING LESS THAN ZERO                    
                                        
    TRUNCATE TABLE IFRS_EAD_RESULT_NONPRK;                       
                     
    INSERT INTO IFRS_EAD_RESULT_NONPRK                      
    (                        
        DOWNLOAD_DATE,                     
        MASTERID,                     
        GROUP_SEGMENT,                     
        SEGMENT,                     
        SUB_SEGMENT,                     
        SEGMENTATION_ID,                     
        ACCOUNT_NUMBER,                     
        CUSTOMER_NUMBER,                        
        SICR_RULE_ID,                     
        BUCKET_GROUP,                     
        BUCKET_ID,                     
        LIFETIME,                     
        STAGE,                     
        REVOLVING_FLAG,                       
        PD_SEGMENT,                       
        LGD_SEGMENT,                       
        EAD_SEGMENT,                       
        PREV_ECL_AMOUNT,                     
        ECL_MODEL_ID,                 
        EAD_MODEL_ID,                   
        CCF_RULES_ID,                       
        LGD_MODEL_ID,                       
        PD_MODEL_ID,                        
        SEQ,                     
        FL_YEAR,                     
        FL_MONTH,                     
        EIR,                     
        OUTSTANDING,                     
        UNAMORT_COST_AMT,                     
        UNAMORT_FEE_AMT,                     
        INTEREST_ACCRUED,                      
        UNUSED_AMOUNT,                     
        FAIR_VALUE_AMOUNT,                     
        EAD_BALANCE,                     
        PLAFOND,                     
        EAD,                     
        BI_COLLECTABILITY,        
		COLL_AMOUNT,
		SEGMENT_FLAG                       
)                       
    SELECT                      
        DOWNLOAD_DATE,                     
        MASTERID,                     
        GROUP_SEGMENT,                     
        SEGMENT,                     
        SUB_SEGMENT,                     
        SEGMENTATION_ID,                     
        ACCOUNT_NUMBER,                     
        CUSTOMER_NUMBER,                      
        SICR_RULE_ID,                     
        BUCKET_GROUP,                     
        BUCKET_ID,                     
        LIFETIME,                     
        STAGE,                     
        REVOLVING_FLAG,                       
        PD_SEGMENT,                       
        LGD_SEGMENT,                       
        EAD_SEGMENT,                       
        PREV_ECL_AMOUNT,                        
        ECL_MODEL_ID,                     
        EAD_MODEL_ID,                     
        CCF_RULES_ID,                       
        LGD_MODEL_ID,                        
        PD_MODEL_ID,                        
        SEQ,                     
        FL_YEAR,                     
        FL_MONTH,                     
        EIR,                     
        OUTSTANDING,                     
        UNAMORT_COST_AMT,                     
        UNAMORT_FEE_AMT,                     
        INTEREST_ACCRUED,                      
        UNUSED_AMOUNT,                     
        FAIR_VALUE_AMOUNT,                     
        EAD_BALANCE,                     
        PLAFOND,                     
        CASE WHEN EAD < 0 THEN 0 ELSE EAD END AS EAD,                     
        BI_COLLECTABILITY,        
		COLL_AMOUNT,
		SEGMENT_FLAG                       
    FROM #CTE_EAD                     
    ORDER BY DOWNLOAD_DATE, MASTERID;                   
                    
    DROP TABLE IF EXISTS #MINUS_LIFETIME                  
    SELECT MASTERID                  
    INTO #MINUS_LIFETIME                   
    FROM IFRS_EAD_RESULT_NONPRK                   
    WHERE DOWNLOAD_DATE = @V_CURRDATE                   
    AND LIFETIME < 0                  
                  
    SELECT * INTO #IFRS_EAD_RESULT_NONPRK FROM IFRS_EAD_RESULT_NONPRK WHERE 1 = 2                  
               
    IF((SELECT COUNT(1) FROM #MINUS_LIFETIME) > 0)                  
    BEGIN                  
        DECLARE @START INT = 2                  
        DECLARE @END INT = 12                  
                      
        WHILE @START <= @END                  
        BEGIN                  
            INSERT INTO #IFRS_EAD_RESULT_NONPRK                      
            (                        
                DOWNLOAD_DATE,              
                MASTERID,                     
                GROUP_SEGMENT,                     
                SEGMENT,                     
                SUB_SEGMENT,                     
                SEGMENTATION_ID,                     
                ACCOUNT_NUMBER,                     
                CUSTOMER_NUMBER,                        
                SICR_RULE_ID,                     
                BUCKET_GROUP,                     
                BUCKET_ID,                     
                LIFETIME,                     
                STAGE,                     
                REVOLVING_FLAG,                       
                PD_SEGMENT,                       
                LGD_SEGMENT,                       
                EAD_SEGMENT,              
                PREV_ECL_AMOUNT,                     
                ECL_MODEL_ID,                     
                EAD_MODEL_ID,                     
                CCF_RULES_ID,                       
                LGD_MODEL_ID,                       
                PD_MODEL_ID,                        
                SEQ,                     
                FL_YEAR,                     
                FL_MONTH,                     
                EIR,                     
                OUTSTANDING,                     
                UNAMORT_COST_AMT,                     
                UNAMORT_FEE_AMT,                     
                INTEREST_ACCRUED,                      
                UNUSED_AMOUNT,                     
                FAIR_VALUE_AMOUNT,                     
                EAD_BALANCE,                     
                PLAFOND,                     
                EAD,                     
                CCF,                
                BI_COLLECTABILITY,        
				COLL_AMOUNT,
				SEGMENT_FLAG                       
            )                  
            SELECT                  
                DOWNLOAD_DATE,                     
                MASTERID,                     
                GROUP_SEGMENT,                     
                SEGMENT,                     
                SUB_SEGMENT,                     
                SEGMENTATION_ID,                     
                ACCOUNT_NUMBER,                     
                CUSTOMER_NUMBER,                        
                SICR_RULE_ID,                     
                BUCKET_GROUP,                     
                BUCKET_ID,                     
                LIFETIME,                     
                STAGE,                     
                REVOLVING_FLAG,                       
                PD_SEGMENT,                       
                LGD_SEGMENT,                       
                EAD_SEGMENT,                       
                PREV_ECL_AMOUNT,                     
                ECL_MODEL_ID,                     
                EAD_MODEL_ID,                     
                CCF_RULES_ID,                       
                LGD_MODEL_ID,                       
                PD_MODEL_ID,                        
                @START AS SEQ,                     
                FL_YEAR,                     
				@START AS FL_MONTH,                     
                EIR,                     
                OUTSTANDING,                     
                UNAMORT_COST_AMT,                     
                UNAMORT_FEE_AMT,                     
                INTEREST_ACCRUED,                      
                UNUSED_AMOUNT,                     
                FAIR_VALUE_AMOUNT,                     
                EAD_BALANCE,                     
                PLAFOND,                     
                EAD,                     
                CCF,                     
                BI_COLLECTABILITY,        
				COLL_AMOUNT,
				SEGMENT_FLAG                  
            FROM IFRS_EAD_RESULT_NONPRK                  
            WHERE MASTERID IN (SELECT MASTERID FROM #MINUS_LIFETIME)                  
                  
            SET @START = @START + 1                  
        END                  
                  
        INSERT INTO IFRS_EAD_RESULT_NONPRK                      
        (                        
            DOWNLOAD_DATE,                     
            MASTERID,                     
            GROUP_SEGMENT,                     
            SEGMENT,                     
            SUB_SEGMENT,                     
            SEGMENTATION_ID,                     
            ACCOUNT_NUMBER,                     
            CUSTOMER_NUMBER,                        
            SICR_RULE_ID,                     
            BUCKET_GROUP,                     
            BUCKET_ID,                     
            LIFETIME,                     
            STAGE,                     
            REVOLVING_FLAG,                       
            PD_SEGMENT,                       
            LGD_SEGMENT,                       
            EAD_SEGMENT,                       
			PREV_ECL_AMOUNT,                     
            ECL_MODEL_ID,                     
            EAD_MODEL_ID,                     
            CCF_RULES_ID,                       
            LGD_MODEL_ID,                       
            PD_MODEL_ID,                        
            SEQ,                     
            FL_YEAR,                     
            FL_MONTH,                     
            EIR,                     
            OUTSTANDING,                     
            UNAMORT_COST_AMT,                     
            UNAMORT_FEE_AMT,                     
            INTEREST_ACCRUED,                      
            UNUSED_AMOUNT,                     
            FAIR_VALUE_AMOUNT,                     
            EAD_BALANCE,                     
            PLAFOND,                     
            EAD,                     
            CCF,                     
            BI_COLLECTABILITY,        
			COLL_AMOUNT,
			SEGMENT_FLAG                       
        )                  
		SELECT                  
            DOWNLOAD_DATE,                     
            MASTERID,                     
            GROUP_SEGMENT,                     
            SEGMENT,                   
            SUB_SEGMENT,                     
            SEGMENTATION_ID,                     
            ACCOUNT_NUMBER,                     
            CUSTOMER_NUMBER,                        
            SICR_RULE_ID,                     
            BUCKET_GROUP,                     
            BUCKET_ID,                     
            LIFETIME,                     
            STAGE,                     
            REVOLVING_FLAG,                       
            PD_SEGMENT,                       
            LGD_SEGMENT,                       
            EAD_SEGMENT,                       
            PREV_ECL_AMOUNT,                     
            ECL_MODEL_ID,                     
            EAD_MODEL_ID,                     
            CCF_RULES_ID,                       
            LGD_MODEL_ID,                       
            PD_MODEL_ID,                        
            SEQ,                     
            FL_YEAR,                     
            FL_MONTH,                     
            EIR,                     
            OUTSTANDING,                     
            UNAMORT_COST_AMT,                     
            UNAMORT_FEE_AMT,                     
            INTEREST_ACCRUED,                      
            UNUSED_AMOUNT,                     
            FAIR_VALUE_AMOUNT,                     
            EAD_BALANCE,                     
            PLAFOND,                     
            EAD,                     
            CCF,                     
            BI_COLLECTABILITY,        
			COLL_AMOUNT,
			SEGMENT_FLAG        
        FROM #IFRS_EAD_RESULT_NONPRK                  
    END;                                     
                            
END;
GO
