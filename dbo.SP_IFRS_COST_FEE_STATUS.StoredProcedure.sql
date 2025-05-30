USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_COST_FEE_STATUS]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_COST_FEE_STATUS]            
AS            
DECLARE @V_CURRDATE DATE            
 ,@V_PREVDATE DATE            
 ,@V_PARAM_MAT_LEVEL INT = 0      
 ,@V_PARAM_UNMAT_PL INT = 0        
BEGIN           
          
/***** @V_PARAM_MAT_LEVEL DESCRIPTION *****            
 0 => MATERIALITY BY PRODUCT PARAMETER             
 1 => MATERIALITY BY TRANSACTION PARAMETER            
******************************************/            
      
   SELECT @V_PARAM_UNMAT_PL = COMMONUSAGE                 
  FROM TBLM_COMMONCODEHEADER                  
  WHERE COMMONCODE = 'SCM011'              
            
  /***** @@@V_PARAM_UNMAT_PL DESCRIPTION *****           
 0 => Under Materiality Not Processed             
 1 => Under Materiality to PNL            
******************************************/            
          
 SELECT @V_CURRDATE = MAX(CURRDATE)            
  ,@V_PREVDATE = MAX(PREVDATE)            
 FROM IFRS_PRC_DATE_AMORT            
            
  SELECT @V_PARAM_MAT_LEVEL = COMMONUSAGE                 
  FROM TBLM_COMMONCODEHEADER                  
  WHERE COMMONCODE = 'SCM001'              
            
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
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,''            
  );            
            
 --RESET                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'FRZNF'            
  ,METHOD = 'X'            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND STATUS <> 'PARAM';-- TRAN PARAM NOT MATCH                  
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'1'            
  );            
            
 -- UPDATE FROM CURRDATE                   
 -- CHECK CURRENCY AND DUE DATE                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET IFRS_ACCT_COST_FEE.STATUS = CASE             
   WHEN IFRS_ACCT_COST_FEE.STATUS = 'PARAM'            
    THEN 'PARAM'            
   WHEN IFRS_ACCT_COST_FEE.CCY != B.CURRENCY            
    THEN 'FRZCCY'            
   WHEN (            
     B.LOAN_DUE_DATE <= IFRS_ACCT_COST_FEE.DOWNLOAD_DATE            
     OR B.ACCOUNT_STATUS IN (            
      'W'            
      ,'C'            
      ,'E'            
      ,'CE'            
      ,'CT'            
      ,'CN'            
      )            
     --AND IFRS_ACCT_COST_FEE.METHOD <> 'SL'                  
     )            
    THEN 'PNL'            
   ELSE 'ACT'            
   END            
  ,IFRS_ACCT_COST_FEE.POS_AMOUNT = CASE             
   WHEN B.OUTSTANDING = 0            
    THEN 100            
   ELSE IFRS_ACCT_COST_FEE.AMOUNT / B.OUTSTANDING            
   END            
  ,IFRS_ACCT_COST_FEE.MASTERID = B.MASTERID            
  ,IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
  ,IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRODUCT_TYPE            
  ,IFRS_ACCT_COST_FEE.PRD_CODE = B.PRODUCT_CODE            
 FROM IFRS_IMA_AMORT_CURR B            
 WHERE B.MASTERID = IFRS_ACCT_COST_FEE.MASTERID            
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = B.DOWNLOAD_DATE            
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'2'            
  );            
      
      
  -- CLOSED WILL GO PNL        
UPDATE  A           
 SET STATUS = 'PNL'            
  ,CREATEDBY = B.CREATEDBY    
  FROM IFRS_ACCT_COST_FEE    A    
  INNER JOIN (SELECT MASTERID, CREATEDBY FROM IFRS_ACCT_CLOSED WHERE DOWNLOAD_DATE = @V_CURRDATE) B ON A.MASTERID = B.MASTERID    
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE     
    
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'3'            
  );            
            
 -- MARK AMORT METHOD BASED ON PRODUCT PARAM                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET METHOD = B.AMORT_TYPE            
 FROM (            
  SELECT X.*            
   ,Y.*            
  FROM IFRS_PRODUCT_PARAM X            
  CROSS JOIN IFRS_PRC_DATE_AMORT Y            
  ) B            
 WHERE IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
  AND IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRD_TYPE            
  AND IFRS_ACCT_COST_FEE.PRD_CODE = B.PRD_CODE            
  AND (            
   IFRS_ACCT_COST_FEE.CCY = B.CCY            
   OR B.CCY = 'ALL'            
   )            
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE                       
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'5'            
  );            
            
 -- EIR WITH ZERO OS WILL GO PNL                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'PNL'            
  ,CREATEDBY = 'EIR_ZERO_OS'       
 WHERE STATUS = 'ACT'            
  AND METHOD = 'EIR'            
  AND DOWNLOAD_DATE = @V_CURRDATE            
  AND MASTERID IN (            
   SELECT MASTERID            
   FROM IFRS_IMA_AMORT_CURR            
   WHERE COALESCE(OUTSTANDING, 0) <= 0            
   )            
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'5'            
  );            
            
----------------------------------START UNDER MATERILIATY TO PNL -----------------------------------------------        
        
IF @V_PARAM_UNMAT_PL = 1        
BEGIN        
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN            
       ----ABS MATERIALITY FEE BY PRODUCT            
      UPDATE A            
      SET CREATEDBY = 'ABS_MAT_FEE'            
       ,STATUS = 'PNL'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_PRODUCT_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE A.FLAG_CF = 'F'            
  AND A.STATUS = 'ACT'            
  AND B.FEE_MAT_TYPE IN ('','ABS')            
  AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.FEE_MAT_AMT    
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX         
     END            
   IF @V_PARAM_MAT_LEVEL = 1            
       BEGIN            
      -- ABS MATERIALITY FEE BY TRANSACTION            
      UPDATE A            
      SET CREATEDBY = 'ABS_MAT_FEE'            
       ,STATUS = 'PNL'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE   A.FLAG_CF = 'F'            
     AND A.STATUS = 'ACT'            
     AND B.FEE_MAT_TYPE IN ('','ABS')            
     AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.FEE_MAT_AMT    
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
     END            
            
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'6'            
    );            
            
   /*                  
   UPDATE  IFRS_ACCT_COST_FEE                  
   SET     STATUS = 'PNL'                  
   WHERE   DOWNLOAD_DATE = @V_CURRDATE                  
     AND CREATEDBY = 'ABS_MAT_FEE'                  
     */            
                  
   INSERT  INTO IFRS_AMORT_LOG                  
     ( DOWNLOAD_DATE ,                  
       DTM ,                  
       OPS ,                  
       PROCNAME ,                  
       REMARK                 
     )                  
   VALUES  ( @V_CURRDATE ,                  
       CURRENT_TIMESTAMP ,                  
       'DEBUG' ,                  
       'SP_IFRS_COST_FEE_STATUS' ,                  
       '7'                  
     ) ;                  
            
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN            
       -- ABS MATERIALITY COST BY PRODUCT                
      UPDATE A            
      SET CREATEDBY = 'ABS_MAT_COST'            
       ,STATUS = 'PNL'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_PRODUCT_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE   A.FLAG_CF = 'C'            
  AND A.STATUS = 'ACT'            
  AND B.FEE_MAT_TYPE IN ('','ABS')            
  AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.COST_MAT_AMT            
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX    
     END            
    IF @V_PARAM_MAT_LEVEL = 1             
     BEGIN    
      -- ABS MATERIALITY COST BY TRANSACTION                 
      UPDATE IFRS_ACCT_COST_FEE            
      SET CREATEDBY = 'ABS_MAT_COST'            
       ,STATUS = 'PNL'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE   A.FLAG_CF = 'C'            
  AND A.STATUS = 'ACT'            
  AND B.FEE_MAT_TYPE IN ('','ABS')            
  AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.COST_MAT_AMT    
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
     END     
    
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'7'            
    );            
            
   INSERT  INTO IFRS_AMORT_LOG                  
     ( DOWNLOAD_DATE ,                  
       DTM ,                  
       OPS ,                  
       PROCNAME ,                  
       REMARK                  
     )                  
   VALUES  ( @V_CURRDATE ,                  
       CURRENT_TIMESTAMP ,                  
       'DEBUG' ,                  
       'SP_IFRS_COST_FEE_STATUS' ,                  
       '9'                  
     ) ;                  
            
          
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN            
     -- PERCENT OF OS FEE PRODUCT PARAM                
     UPDATE IFRS_ACCT_COST_FEE            
     SET CREATEDBY = 'POS_MAT_FEE'            
      ,STATUS = 'PNL'            
     FROM (SELECT X.*, Y.* FROM IFRS_PRODUCT_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B            
     WHERE IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
      AND IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRD_TYPE            
      AND IFRS_ACCT_COST_FEE.PRD_CODE = B.PRD_CODE            
      AND (IFRS_ACCT_COST_FEE.CCY = B.CCY OR B.CCY = 'ALL')            
      AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = B.CURRDATE            
      AND IFRS_ACCT_COST_FEE.FLAG_CF = 'F'            
      AND IFRS_ACCT_COST_FEE.STATUS = 'ACT'            
      AND B.FEE_MAT_TYPE = 'POS'            
      AND ABS(IFRS_ACCT_COST_FEE.POS_AMOUNT) < B.FEE_MAT_AMT     
   AND SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX        
     END           
        
    IF @V_PARAM_MAT_LEVEL = 1           
    BEGIN            
      -- ABS MATERIALITY FEE BY TRANSACTION            
      UPDATE A            
      SET CREATEDBY = 'POS_MAT_FEE'            
       ,STATUS = 'PNL'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      WHERE   A.FLAG_CF = 'F'            
  AND A.STATUS = 'ACT'            
  AND B.FEE_MAT_TYPE = 'POS'           
  AND ABS(A.POS_AMOUNT) < B.FEE_MAT_AMT    
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX          
     END            
        
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'8'            
    );          
            
          
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN               
   -- PERCENT OF OS COST                  
   UPDATE IFRS_ACCT_COST_FEE            
   SET CREATEDBY = 'POS_MAT_COST'            
    ,STATUS = 'PNL'            
   FROM (            
    SELECT X.*            
     ,Y.*            
    FROM IFRS_PRODUCT_PARAM X            
    CROSS JOIN IFRS_PRC_DATE_AMORT Y            
    ) B            
   WHERE IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
    AND IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRD_TYPE            
    AND IFRS_ACCT_COST_FEE.PRD_CODE = B.PRD_CODE            
    AND (IFRS_ACCT_COST_FEE.CCY = B.CCY OR B.CCY = 'ALL')            
    AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = B.CURRDATE            
    AND IFRS_ACCT_COST_FEE.FLAG_CF = 'C'            
    AND IFRS_ACCT_COST_FEE.STATUS = 'ACT'            
    AND B.COST_MAT_TYPE = 'POS'            
    AND ABS(IFRS_ACCT_COST_FEE.POS_AMOUNT) < B.COST_MAT_AMT     
    AND SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
      END        
    IF @V_PARAM_MAT_LEVEL = 1        
     BEGIN        
    -- POS MATERIALITY COST BY TRANSACTION                 
    UPDATE IFRS_ACCT_COST_FEE            
    SET CREATEDBY = 'POS_MAT_COST'            
     ,STATUS = 'PNL'            
    FROM IFRS_ACCT_COST_FEE A            
    LEFT JOIN            
    (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
    ON            
     (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
     AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
     AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
     AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
     AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
     AND A.DOWNLOAD_DATE = B.CURRDATE            
   WHERE   A.FLAG_CF = 'C'            
    AND A.STATUS = 'ACT'            
    AND B.FEE_MAT_TYPE = 'POS'           
    AND ABS(A.POS_AMOUNT) < B.COST_MAT_AMT    
    AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
 END         
            
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'9'            
    );            
 END           
 ----------------------------------END UNDER MATERILIATY TO PNL -----------------------------------------------        
        
        
         
----------------------------------START UNDER MATERILIATY NOT PROCESSED -----------------------------------------------        
        
IF @V_PARAM_UNMAT_PL = 0        
BEGIN        
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN            
    ----ABS MATERIALITY FEE BY PRODUCT            
    UPDATE A            
    SET CREATEDBY = 'ABS_MAT_FEE'            
     ,STATUS = 'UNMAT'            
    FROM IFRS_ACCT_COST_FEE A            
    LEFT JOIN            
    (SELECT X.*,Y.* FROM IFRS_PRODUCT_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
    ON            
     (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
     AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
     AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
     AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
     AND A.DOWNLOAD_DATE = B.CURRDATE            
    LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
    WHERE   A.FLAG_CF = 'F'            
    AND A.STATUS = 'ACT'            
    AND B.FEE_MAT_TYPE IN ('','ABS')            
    AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.FEE_MAT_AMT    
    AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX            
     END            
   IF @V_PARAM_MAT_LEVEL = 1            
   BEGIN            
      -- ABS MATERIALITY FEE BY TRANSACTION            
      UPDATE A            
      SET CREATEDBY = 'ABS_MAT_FEE'            
       ,STATUS = 'UNMAT'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE   A.FLAG_CF = 'F'            
   AND A.STATUS = 'ACT'            
   AND B.FEE_MAT_TYPE IN ('','ABS')            
   AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.FEE_MAT_AMT    
   AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX          
 END            
            
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'6'            
    );            
            
   /*                  
   UPDATE  IFRS_ACCT_COST_FEE                  
   SET     STATUS = 'PNL'                  
   WHERE   DOWNLOAD_DATE = @V_CURRDATE                  
     AND CREATEDBY = 'ABS_MAT_FEE'                  
     */            
                  
   INSERT  INTO IFRS_AMORT_LOG                  
     ( DOWNLOAD_DATE ,                  
       DTM ,                  
       OPS ,                  
       PROCNAME ,                  
       REMARK                  
     )                  
   VALUES  ( @V_CURRDATE ,                  
       CURRENT_TIMESTAMP ,         
       'DEBUG' ,                  
       'SP_IFRS_COST_FEE_STATUS' ,                  
       '7'                  
     ) ;                  
            
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN            
    -- ABS MATERIALITY COST BY PRODUCT                
    UPDATE A            
    SET CREATEDBY = 'ABS_MAT_COST'            
     ,STATUS = 'UNMAT'            
    FROM IFRS_ACCT_COST_FEE A            
    LEFT JOIN            
    (SELECT X.*,Y.* FROM IFRS_PRODUCT_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
    ON            
     (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
     AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
     AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
     AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
     AND A.DOWNLOAD_DATE = B.CURRDATE            
    LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
    WHERE   A.FLAG_CF = 'C'            
    AND A.STATUS = 'ACT'            
    AND B.FEE_MAT_TYPE IN ('','ABS')            
    AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.COST_MAT_AMT            
    AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX    
     END            
  IF @V_PARAM_MAT_LEVEL = 1             
   BEGIN       
      -- ABS MATERIALITY COST BY TRANSACTION                 
      UPDATE IFRS_ACCT_COST_FEE            
      SET CREATEDBY = 'ABS_MAT_COST'            
       ,STATUS = 'UNMAT'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      LEFT JOIN IFRS_IMA_AMORT_CURR  C ON A.MASTERID = C.MASTERID AND A.DOWNLOAD_DATE = C.DOWNLOAD_DATE            
      WHERE   A.FLAG_CF = 'C'            
   AND A.STATUS = 'ACT'            
   AND B.FEE_MAT_TYPE IN ('','ABS')            
   AND ABS(A.AMOUNT * ISNULL(C.EXCHANGE_RATE,1)) < B.COST_MAT_AMT    
   AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX            
     END         
            
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'7'            
    );            
            
   INSERT  INTO IFRS_AMORT_LOG                  
     ( DOWNLOAD_DATE ,                  
       DTM ,                  
       OPS ,                  
       PROCNAME ,                  
       REMARK                  
     )                  
   VALUES  ( @V_CURRDATE ,                  
       CURRENT_TIMESTAMP ,                  
       'DEBUG' ,                  
       'SP_IFRS_COST_FEE_STATUS' ,                  
       '9'                  
     ) ;                  
            
          
   IF @V_PARAM_MAT_LEVEL = 0            
   BEGIN            
  -- PERCENT OF OS FEE  PRODUCT PARAM                
  UPDATE IFRS_ACCT_COST_FEE            
   SET CREATEDBY = 'POS_MAT_FEE'            
    ,STATUS = 'UNMAT'            
   FROM (            
    SELECT X.*            
     ,Y.*            
    FROM IFRS_PRODUCT_PARAM X            
    CROSS JOIN IFRS_PRC_DATE_AMORT Y            
    ) B            
   WHERE IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
    AND IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRD_TYPE            
    AND IFRS_ACCT_COST_FEE.PRD_CODE = B.PRD_CODE            
    AND (IFRS_ACCT_COST_FEE.CCY = B.CCY OR B.CCY = 'ALL')            
    AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = B.CURRDATE            
    AND IFRS_ACCT_COST_FEE.FLAG_CF = 'F'            
    AND IFRS_ACCT_COST_FEE.STATUS = 'ACT'            
    AND B.FEE_MAT_TYPE = 'POS'            
    AND ABS(IFRS_ACCT_COST_FEE.POS_AMOUNT) < B.FEE_MAT_AMT     
    AND SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX      
     END           
        
    IF @V_PARAM_MAT_LEVEL = 1           
    BEGIN            
      -- ABS MATERIALITY FEE BY TRANSACTION            
      UPDATE A            
      SET CREATEDBY = 'POS_MAT_FEE'            
       ,STATUS = 'UNMAT'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
      WHERE   A.FLAG_CF = 'F'            
   AND A.STATUS = 'ACT'            
   AND B.FEE_MAT_TYPE = 'POS'           
   AND ABS(A.POS_AMOUNT) < B.FEE_MAT_AMT     
   AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX          
     END            
        
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'8'            
    );          
            
          
   IF @V_PARAM_MAT_LEVEL = 0            
     BEGIN               
     -- PERCENT OF OS COST                  
     UPDATE IFRS_ACCT_COST_FEE            
     SET CREATEDBY = 'POS_MAT_COST'            
      ,STATUS = 'UNMAT'            
     FROM (            
      SELECT X.*            
       ,Y.*            
      FROM IFRS_PRODUCT_PARAM X            
      CROSS JOIN IFRS_PRC_DATE_AMORT Y            
      ) B            
     WHERE IFRS_ACCT_COST_FEE.DATASOURCE = B.DATA_SOURCE            
      AND IFRS_ACCT_COST_FEE.PRD_TYPE = B.PRD_TYPE            
      AND IFRS_ACCT_COST_FEE.PRD_CODE = B.PRD_CODE            
      AND (IFRS_ACCT_COST_FEE.CCY = B.CCY OR B.CCY = 'ALL')            
      AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = B.CURRDATE            
      AND IFRS_ACCT_COST_FEE.FLAG_CF = 'C'            
      AND IFRS_ACCT_COST_FEE.STATUS = 'ACT'            
      AND B.COST_MAT_TYPE = 'POS'            
      AND ABS(IFRS_ACCT_COST_FEE.POS_AMOUNT) < B.COST_MAT_AMT    
   AND SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
      END        
    IF @V_PARAM_MAT_LEVEL = 1        
     BEGIN        
      -- POS MATERIALITY COST BY TRANSACTION                 
      UPDATE IFRS_ACCT_COST_FEE            
      SET CREATEDBY = 'POS_MAT_COST'            
       ,STATUS = 'UNMAT'            
      FROM IFRS_ACCT_COST_FEE A            
      LEFT JOIN            
      (SELECT X.*,Y.* FROM IFRS_TRANSACTION_PARAM X CROSS JOIN IFRS_PRC_DATE_AMORT Y) B             
      ON            
       (A.DATASOURCE = B.DATA_SOURCE OR B.DATA_SOURCE = 'ALL')            
       AND (A.PRD_TYPE = B.PRD_TYPE OR B.PRD_TYPE = 'ALL')            
       AND (A.PRD_CODE = B.PRD_CODE OR B.PRD_CODE = 'ALL')            
       AND (A.TRX_CODE = B.TRX_CODE OR B.TRX_CODE = 'ALL')            
       AND (A.CCY = B.CCY OR B.CCY = 'ALL')            
       AND A.DOWNLOAD_DATE = B.CURRDATE            
     WHERE   A.FLAG_CF = 'C'            
     AND A.STATUS = 'ACT'            
     AND B.FEE_MAT_TYPE = 'POS'           
     AND ABS(A.POS_AMOUNT) < B.COST_MAT_AMT     
  AND A.SOURCE_TABLE <> 'MAIN_M_LOAN_PSAK'  -- EXCLUDE UNAMORT TRX           
  END            
            
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
    ,'DEBUG'            
    ,'SP_IFRS_COST_FEE_STATUS'            
    ,'9'            
    );            
 END           
 ----------------------------------END UNDER MATERILIATY NOT PROCESSED -----------------------------------------------        
        
        
 ----CTBC_20180525: ACT WITH METHOD SL BUT LOAN_START_DATE OR LOAN_DUE DATE IS NULL WILL GO TO PNL            
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'PNL'            
  ,CREATEDBY = 'SL_START_ENDDT_NULL'            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND STATUS = 'ACT'            
  AND METHOD = 'SL'            
  AND FLAG_AL = 'A'            
  AND MASTERID IN (            
   SELECT ACCOUNT_NUMBER            
   FROM IFRS_IMA_AMORT_CURR            
   WHERE AMORT_TYPE = 'SL'            
    AND DOWNLOAD_DATE = @V_CURRDATE            
    AND (            
     LOAN_START_DATE IS NULL            
     OR LOAN_DUE_DATE IS NULL            
     OR (LOAN_START_DATE > LOAN_DUE_DATE)            
     )            
   )            
    
    
---- NEW CONDITION BY SMY 20181226    
---- IF DIFF DATE BETWEEN COST FEE DATE AND LOAN DUE DATE ONLY HAVE DIFFERENT 1 DAY, WILL TREAT AS PNL (CAUSING AN ERROR WHEN GOALSEEK)    
UPDATE A     
SET STATUS = 'PNL'            
  ,CREATEDBY = 'EIR_DUE_DATE_1_DAY'        
FROM IFRS_ACCT_COST_FEE A    
INNER JOIN     
IFRS_IMA_AMORT_CURR B ON A.MASTERID = B.MASTERID AND A.DOWNLOAD_DATE = B.DOWNLOAD_DATE    
WHERE A.DOWNLOAD_DATE = @V_CURRDATE           
  AND A.STATUS = 'ACT'            
  AND A.METHOD = 'EIR'            
  AND A.FLAG_AL = 'A'  AND DATEDIFF(DAY,A.DOWNLOAD_DATE,B.LOAN_DUE_DATE) <= 1     
     
    
    
            
 TRUNCATE TABLE TMP_T1            
            
 -- ACT BUT NO METHOD WILL GO TO FRZMTD                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'FRZMTD'            
 WHERE DOWNLOAD_DATE = @V_CURRDATE            
  AND STATUS = 'ACT'            
  AND METHOD NOT IN (            
   'SL'            
   ,'EIR'            
   )            
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'10'            
  );            
            
 -- CAN NOT PROCESS ACT REVERSE FEE/COST IF NO PREV COST FEE FOR THAT ACCOUNT                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'FRZREV'            
 WHERE ID IN (            
   SELECT A.ID            
   FROM IFRS_ACCT_COST_FEE A            
   LEFT JOIN IFRS_ACCT_COST_FEE B ON B.DOWNLOAD_DATE <= @V_CURRDATE            
    AND B.FLAG_REVERSE = 'N'            
    AND B.AMOUNT = A.AMOUNT            
    AND A.MASTERID = B.MASTERID            
    -- 20160411 ONLY GET DATA BEFORE PRORATE                  
    AND B.ID = B.CF_ID            
   -- 20160411 STATUS FILTER NOT NEEDED                  
   -- AND B.STATUS='ACT'                  
   WHERE A.DOWNLOAD_DATE = @V_CURRDATE            
    AND A.FLAG_REVERSE = 'Y'            
    AND A.STATUS = 'ACT'            
    AND B.MASTERID IS NULL            
   )            
            
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'11'            
  );            
            
 -- FILL CF ID                  
 UPDATE IFRS_ACCT_COST_FEE            
 SET CF_ID = ID            
 WHERE STATUS IN (            
   'ACT'            
   ,'PNL'            
   )          
  -- 20160411 UPDATE CURRDATE DATA                  
  AND DOWNLOAD_DATE = @V_CURRDATE            
            
 --DROP TABLE #PAYM_COMBINE            
            
 -- DANIEL SISWANTO 2018 FOR CTBC, UPDATE CF_ID_REV              
 -- START : PAIRING TODAY NEW REVERSAL, IF NOT FOUND THEN REJECT FROM PRORATE PROCESSING              
 -- INSERT LOG DEBUG              
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
  ,'DEBUG'            
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,'REVERSAL-PAIRING'            
  )            
            
 IF OBJECT_ID('TEMPDB..#REV_PAIR') IS NOT NULL            
  DROP TABLE #REV_PAIR            
            
 SELECT A.ID            
  ,A.CF_ID            
  ,MIN(B.ID) AS PAIR_ID            
 INTO #REV_PAIR            
 FROM IFRS_ACCT_COST_FEE A            
 LEFT JOIN IFRS_ACCT_COST_FEE B ON --B.ACCRU_DATE=@V_CURRDATE AND               
  B.FLAG_REVERSE = 'N'            
  AND B.CF_ID_REV IS NULL            
  AND B.MASTERID = A.MASTERID            
  AND B.AMOUNT = A.AMOUNT            
  AND B.CCY = A.CCY            
  AND B.FLAG_CF = A.FLAG_CF            
  AND B.TRX_CODE = A.TRX_CODE            
 WHERE A.DOWNLOAD_DATE = @V_CURRDATE            
  AND A.FLAG_REVERSE = 'Y'            
 GROUP BY A.ID            
  ,A.CF_ID            
            
 --IF MORE THAN ONE PAIR_ID ON TABLE #REV_PAIR THEN ONLY ALLOW ONE AND REJECT THE OTHERS              
 UPDATE #REV_PAIR            
 SET PAIR_ID = NULL            
 FROM (            
  SELECT PAIR_ID            
   ,MIN(ID) AS ALLOWED_ID            
  FROM #REV_PAIR            
  GROUP BY PAIR_ID            
  HAVING COUNT(PAIR_ID) > 1            
  ) A            
 WHERE #REV_PAIR.PAIR_ID = A.PAIR_ID            
  AND #REV_PAIR.ID <> A.ALLOWED_ID            
            
 DECLARE @REV_PAIR2 TABLE (            
  ID2 BIGINT            
  ,CF_ID2 BIGINT            
  ,PAIR_ID2 BIGINT            
  )            
 DECLARE @CX INT            
            
 SET @CX = 1            
            
 --LOOP 5X MAX              
 WHILE (            
   @CX <= 5            
   AND EXISTS (            
    SELECT *            
    FROM #REV_PAIR            
    WHERE PAIR_ID IS NULL            
    )            
   )            
 BEGIN            
  -- 2ND PASS PAIRING              
  DELETE            
  FROM @REV_PAIR2            
            
  INSERT INTO @REV_PAIR2 (            
   ID2            
   ,CF_ID2            
   ,PAIR_ID2            
   )            
  SELECT A.ID            
   ,A.CF_ID            
   ,MIN(B.ID) AS PAIR_ID            
  FROM IFRS_ACCT_COST_FEE A            
  LEFT JOIN IFRS_ACCT_COST_FEE B ON B.FLAG_REVERSE = 'N'            
   AND B.CF_ID_REV IS NULL            
   AND B.MASTERID = A.MASTERID            
   AND B.AMOUNT = A.AMOUNT            
   AND B.CCY = A.CCY            
   AND B.FLAG_CF = A.FLAG_CF            
   AND B.TRX_CODE = A.TRX_CODE            
   AND B.ID NOT IN (            
    SELECT PAIR_ID            
    FROM #REV_PAIR            
    WHERE PAIR_ID IS NOT NULL            
    )            
  WHERE A.DOWNLOAD_DATE = @V_CURRDATE            
   AND A.FLAG_REVERSE = 'Y'            
   AND A.ID IN (            
    SELECT ID            
    FROM #REV_PAIR            
    WHERE PAIR_ID IS NULL            
    )            
  GROUP BY A.ID            
   ,A.CF_ID            
            
  --20180305 2ND PASS : IF MORE THAN ONE PAIR_ID ON TABLE #REV_PAIR THEN ONLY ALLOW ONE AND REJECT THE OTHERS              
  UPDATE @REV_PAIR2            
  SET PAIR_ID2 = NULL            
  FROM (            
   SELECT PAIR_ID2 AS PAIR_ID            
    ,MIN(ID2) AS ALLOWED_ID            
   FROM @REV_PAIR2            
   GROUP BY PAIR_ID2            
   HAVING COUNT(PAIR_ID2) > 1            
   ) A            
  WHERE PAIR_ID2 = A.PAIR_ID            
   AND ID2 <> A.ALLOWED_ID            
            
  --20180305 2ND PASS UPDATE BACK TO #REV_PAIR              
  UPDATE #REV_PAIR            
  SET PAIR_ID = A.PAIR_ID2            
  FROM @REV_PAIR2 A            
  WHERE A.ID2 = #REV_PAIR.ID            
   AND A.PAIR_ID2 IS NOT NULL            
            
  --INC CX              
  SET @CX = @CX + 1            
 END            
            
 -- IF PAIR_ID IS NULL THEN PAIR NOT FOUND THEN REJECT : MARK ON COST_FEE TABLE AS FRZ AND DELETE FROM FAC_CF              
 UPDATE IFRS_ACCT_COST_FEE            
 SET STATUS = 'FRZREVPRO'            
 FROM #REV_PAIR A            
 WHERE A.CF_ID = IFRS_ACCT_COST_FEE.CF_ID            
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE            
  AND A.PAIR_ID IS NULL            
            
 DELETE            
 FROM #REV_PAIR            
 WHERE PAIR_ID IS NULL            
            
 --UPDATE CF_ID_REV OF PAIR_ID              
 UPDATE IFRS_ACCT_COST_FEE            
 SET CF_ID_REV = A.PAIR_ID            
 FROM #REV_PAIR A            
 WHERE A.CF_ID = IFRS_ACCT_COST_FEE.CF_ID            
  AND IFRS_ACCT_COST_FEE.DOWNLOAD_DATE = @V_CURRDATE            
            
 --END   : PAIRING TODAY NEW REVERSAL   
   
 -- FRZNF if have CF but not have Master Account  
 UPDATE IFRS_ACCT_COST_FEE  
 SET STATUS = 'FRZNF',  
 CREATEDBY = 'SP_IFRS_TRAN_DAILY'  
 WHERE DOWNLOAD_DATE = @V_CURRDATE  
 AND MASTERID NOT IN (SELECT MASTERID FROM IFRS_IMA_AMORT_CURR WHERE DOWNLOAD_DATE = @V_CURRDATE)  
 -- END FRZNF if have CF but not have Master Account              
            
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
  ,'SP_IFRS_COST_FEE_STATUS'            
  ,''            
  )            
END 
GO
