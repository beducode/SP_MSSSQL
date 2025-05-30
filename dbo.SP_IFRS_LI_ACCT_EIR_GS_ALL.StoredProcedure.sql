USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_EIR_GS_ALL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_EIR_GS_ALL]
AS
DECLARE @V_CURRDATE DATE
DECLARE @V_PREVDATE DATE
DECLARE @VLOOP2 BIGINT
DECLARE @VCNT BIGINT
DECLARE @VCNT2 BIGINT
DECLARE @V_COUNTER BIGINT
DECLARE @V_MAXCOUNTER BIGINT

BEGIN
	SELECT @V_CURRDATE = MAX(CURRDATE)
		,@V_PREVDATE = MAX(PREVDATE)
	FROM IFRS_LI_PRC_DATE_AMORT

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,''
		)

	UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET EIR = NULL
		,NEXT_EIR = NULL
		,FINAL_EIR = NULL
		,EIR_NOCF = NULL
		,NEXT_EIR_NOCF = NULL
		,FINAL_EIR_NOCF = NULL

	TRUNCATE TABLE TMP_LI_GS2

	INSERT INTO TMP_LI_GS2 (
		MASTERID
		,DTMIN
		,CNTMIN
		,--ADDING FOR MIN COUNTER  
		BENEFIT
		,STAFFLOAN
		,COST_AMT
		,FEE_AMT
		,GAIN_LOSS_FEE_AMT
		,GAIN_LOSS_COST_AMT
		)
	SELECT B.MASTERID
		,C.DTMIN
		,C.CNTMIN
		,--ADDING FOR MIN COUNTER  
		B.BENEFIT
		,B.STAFFLOAN
		,B.COST_AMT
		,B.FEE_AMT
		,COALESCE(B.GAIN_LOSS_FEE_AMT, 0) --20180226 GAIN LOSS ADJ  
		,COALESCE(B.GAIN_LOSS_COST_AMT, 0)
	FROM IFRS_LI_ACCT_EIR_CF_ECF1 B
	JOIN IFRS_LI_ACCT_EIR_PAYM_GS_DATE C ON C.MASTERID = B.MASTERID

	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS
	SET PREV_UNAMORT1 = CASE 
			WHEN B.STAFFLOAN = 1
				AND B.BENEFIT < 0
				THEN B.BENEFIT
			WHEN B.STAFFLOAN = 1
				AND B.BENEFIT >= 0
				THEN 0
			ELSE B.FEE_AMT - B.GAIN_LOSS_FEE_AMT --20180417  
			END + CASE 
			WHEN B.STAFFLOAN = 1
				AND B.BENEFIT <= 0
				THEN 0
			WHEN B.STAFFLOAN = 1
				AND B.BENEFIT > 0
				THEN B.BENEFIT
			ELSE B.COST_AMT - B.GAIN_LOSS_COST_AMT --20180417  
			END
		,PREV_UNAMORT_NOCF1 = 0
		,--FOR NO CF CALCULATION  
		EIR1 = CASE 
			WHEN B.STAFFLOAN = 1
				THEN 10.5
			WHEN N_INT_RATE > 1
				THEN N_INT_RATE
			ELSE 1
			END
		,EIR2 = CASE 
			WHEN B.STAFFLOAN = 1
				THEN 11
			WHEN N_INT_RATE > 1
				THEN N_INT_RATE
			ELSE 1
			END + (
			0.01 * CASE 
				WHEN N_INT_RATE > 1
					THEN N_INT_RATE
				ELSE 1
				END
			)
		,EIR_NOCF1 = CASE 
			WHEN B.STAFFLOAN = 1
				THEN 10.5
			WHEN N_INT_RATE > 1
				THEN N_INT_RATE
			ELSE 1
			END
		,EIR_NOCF2 = CASE 
			WHEN B.STAFFLOAN = 1
				THEN 11
			WHEN N_INT_RATE > 1
				THEN N_INT_RATE
			ELSE 1
			END + (
			0.01 * CASE 
				WHEN N_INT_RATE > 1
					THEN N_INT_RATE
				ELSE 1
				END
			)
	FROM TMP_LI_GS2 B
	WHERE B.MASTERID = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID
		--AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = B.DTMIN  
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = B.CNTMIN

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'1'
		)

	-- 20131106 DANIEL S : NOTE UNAMORT AMOUNT FOR EACH MASTERID  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET UNAMORT = B.PREV_UNAMORT1
		,UNAMORT_NOCF = B.PREV_UNAMORT_NOCF1
	FROM IFRS_LI_ACCT_EIR_PAYM_GS B
	WHERE B.MASTERID = DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID
		AND B.PMT_DATE = DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.DTMIN

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'2'
		)

	--SELECT * FROM IFRS_LI_ACCT_EIR_PAYM_GS ORDER BY PMT_DATE  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS
	SET
		--WITHOUT CF PART  
		PREV_UNAMORT_NOCF2 = PREV_UNAMORT_NOCF1
		,PREV_CRYAMT_NOCF1 = N_OSPRN_PREV + PREV_UNAMORT_NOCF1
		,PREV_CRYAMT_NOCF2 = N_OSPRN_PREV + PREV_UNAMORT_NOCF1
		,EIRAMT_NOCF1 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END
		,EIRAMT_NOCF2 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END
		,AMORT_NOCF1 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END - N_INT_PAYMENT
		,AMORT_NOCF2 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END - N_INT_PAYMENT
		,UNAMORT_NOCF1 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END - N_INT_PAYMENT + PREV_UNAMORT_NOCF1
		,UNAMORT_NOCF2 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
			END - N_INT_PAYMENT + PREV_UNAMORT_NOCF1
		,CRYAMT_NOCF1 = (N_OSPRN_PREV + PREV_UNAMORT_NOCF1) - N_PRN_PAYMENT + (
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT
			) + DISB_AMOUNT
		,CRYAMT_NOCF2 = (N_OSPRN_PREV + PREV_UNAMORT_NOCF1) - N_PRN_PAYMENT + (
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT
			) + DISB_AMOUNT
		,
		--WITH CF PART  
		PREV_UNAMORT2 = PREV_UNAMORT1
		,PREV_CRYAMT1 = N_OSPRN_PREV + PREV_UNAMORT1
		,PREV_CRYAMT2 = N_OSPRN_PREV + PREV_UNAMORT1
		,EIRAMT1 =
		/*  BCA DISABLE BPI   
      CASE WHEN (IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = 1 AND IFRS_LI_ACCT_EIR_PAYM_GS.SPECIAL_FLAG = 1)  
   THEN  
      EIR1 /100*(DATEDIFF(DAY,IFRS_LI_ACCT_EIR_PAYM_GS.PREV_PMT_DATE,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))*  
      (N_OSPRN_PREV + PREV_UNAMORT1)/12/(DATEDIFF(DAY,  
        CASE WHEN IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = EOMONTH(IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)   
        THEN EOMONTH(DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)) ELSE DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE) END,  
     IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))  
   ELSE 
   */
		CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
				/*  BCA DISABLE BPI END */
			END
		,EIRAMT2 =
		/*  BCA DISABLE BPI
		   CASE WHEN (IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = 1 AND IFRS_LI_ACCT_EIR_PAYM_GS.SPECIAL_FLAG = 1)  
		   THEN  
			  EIR2 /100*(DATEDIFF(DAY,IFRS_LI_ACCT_EIR_PAYM_GS.PREV_PMT_DATE,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))*  
			  (N_OSPRN_PREV + PREV_UNAMORT1)/12/(DATEDIFF(DAY,  
				CASE WHEN IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = EOMONTH(IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)   
				THEN EOMONTH(DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)) ELSE DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE) END,  
			 IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))  
		   ELSE  
		  */
		CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
				/*  BCA DISABLE BPI END  */
			END
		,AMORT1 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
			END - N_INT_PAYMENT
		,AMORT2 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
			END - N_INT_PAYMENT
		,UNAMORT1 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
			END - N_INT_PAYMENT + PREV_UNAMORT1
		,UNAMORT2 = CASE 
			--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'1'
					,'6'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
			WHEN INTCALCCODE IN (
					'2'
					,'3'
					)
				THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
			ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
			END - N_INT_PAYMENT + PREV_UNAMORT1
		,CRYAMT1 = (N_OSPRN_PREV + PREV_UNAMORT1) - N_PRN_PAYMENT + (
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT
			) + DISB_AMOUNT
		,CRYAMT2 = (N_OSPRN_PREV + PREV_UNAMORT1) - N_PRN_PAYMENT + (
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT
			) + DISB_AMOUNT
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE C
	WHERE C.MASTERID = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID
		--AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = C.DTMIN  
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = C.CNTMIN

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'3'
		)

	TRUNCATE TABLE IFRS_LI_GS_DATE1

	INSERT INTO IFRS_LI_GS_DATE1 (
		MASTERID
		,PMT_DATE
		,PERIOD
		)
	SELECT MASTERID
		,DTMIN
		,PERIOD
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE

	/* REMARKS REMARKS 20160525  
        SELECT A.MASTERID, MIN (A.PMT_DATE) DT  
          FROM    IFRS_LI_ACCT_EIR_PAYM_GS A  
               JOIN  
                  IFRS_LI_ACCT_EIR_PAYM_GS_DATE B  
               ON A.PMT_DATE > B.DTMIN AND A.MASTERID = B.MASTERID  
      GROUP BY A.MASTERID  
   END REMARKS 20160525*/
	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'4'
		)

	SET @VLOOP2 = 0

	-- OUTER LOOP  
	WHILE 1 = 1
	BEGIN --LOOP  
		SET @VLOOP2 = @VLOOP2 + 1

		IF @VLOOP2 > 50
			BREAK -- MAX COUNT FOR OUTER LOOP  

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'LOOP ' + CAST(@VLOOP2 AS VARCHAR(5))
			)

		SET @V_COUNTER = 1

		SELECT @V_MAXCOUNTER = ISNULL(MAX(PERIOD), 0)
		FROM IFRS_LI_GS_DATE1

		IF @V_MAXCOUNTER <= 0
			BREAK

		--INNER LOOP  
		--WHILE 1 = 1  
		WHILE @V_COUNTER <= @V_MAXCOUNTER
		BEGIN --LOOP  
			/* REMARKS 20160525  
   SELECT @VCNT=COUNT (*) FROM IFRS_LI_GS_DATE1  
         IF @VCNT <= 0 BREAK  
     
  
         --UPDATE  
         TRUNCATE TABLE PSAK_TMP_GS3  
  
         INSERT INTO PSAK_TMP_GS3 (MASTERID,  
                                   PMT_DATE,  
                                   EIR1,  
                                   CRYAMT1,  
                                   EIR2,  
                                   CRYAMT2,  
                                   UNAMORT1,  
                                   UNAMORT2)  
            SELECT B.MASTERID,  
                   B.PMT_DATE,  
                   C.EIR1,  
                   C.CRYAMT1,  
                   C.EIR2,  
                   C.CRYAMT2,  
                   C.UNAMORT1,  
                   C.UNAMORT2  
              FROM IFRS_LI_GS_DATE1 B  
                   JOIN IFRS_LI_ACCT_EIR_PAYM_GS D  
              ON D.MASTERID = B.MASTERID AND D.PMT_DATE = B.PMT_DATE  
                   JOIN IFRS_LI_ACCT_EIR_PAYM_GS C  
                      ON C.MASTERID = B.MASTERID  
                         AND C.PMT_DATE = D.PREV_PMT_DATE  
           
   END REMARKS 20160525*/
			UPDATE A --DBO.IFRS_LI_ACCT_EIR_PAYM_GS  
			SET --WITHOUT CF PART  
				A.PREV_UNAMORT_NOCF1 = C.UNAMORT_NOCF1
				,A.PREV_UNAMORT_NOCF2 = C.UNAMORT_NOCF2
				,A.PREV_CRYAMT_NOCF1 = C.CRYAMT_NOCF1
				,A.PREV_CRYAMT_NOCF2 = C.CRYAMT_NOCF2
				,A.EIR_NOCF1 = C.EIR_NOCF1
				,A.EIR_NOCF2 = C.EIR_NOCF2
				,A.EIRAMT_NOCF1 = CASE 
					WHEN A.INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.EIR_NOCF1 / CAST(100 AS FLOAT) * C.CRYAMT_NOCF1
					WHEN A.INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.EIR_NOCF1 / CAST(100 AS FLOAT) * C.CRYAMT_NOCF1
					ELSE (CAST(A.M AS NUMERIC(18, 10)) / CAST(1200 AS FLOAT) * C.EIR_NOCF1 * C.CRYAMT_NOCF1)
					END
				,A.EIRAMT_NOCF2 = CASE 
					WHEN A.INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.EIR_NOCF2 / CAST(100 AS FLOAT) * C.CRYAMT_NOCF2
					WHEN A.INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.EIR_NOCF2 / CAST(100 AS FLOAT) * C.CRYAMT_NOCF2
					ELSE (CAST(A.M AS FLOAT) / CAST(1200 AS FLOAT) * C.EIR_NOCF2 * C.CRYAMT_NOCF2)
					END
				,
				/*20170912, REMARK KATA YACOP  
                A.AMORT_NOCF1 = ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                       THEN CAST(A.I_DAYS AS FLOAT)  
                                            / CAST (360 AS FLOAT)  
                                            * C.EIR_NOCF1 / CAST(100 AS FLOAT)  
                                            * C.CRYAMT_NOCF1  
                                       WHEN A.INTCALCCODE IN ( '2', '3' )  
                                       THEN CAST(A.I_DAYS AS FLOAT)  
                                            / CAST (365 AS FLOAT)  
                                            * C.EIR_NOCF1 / CAST(100 AS FLOAT)  
                                            * C.CRYAMT_NOCF1  
                                       ELSE ( CAST (A.M AS NUMERIC(18, 10))  
                                              / CAST (1200 AS FLOAT)  
                                              * C.EIR_NOCF1 * C.CRYAMT_NOCF1 )  
                                  END ) - A.N_INT_PAYMENT ,  
                A.AMORT_NOCF2 = ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                       THEN CAST(A.I_DAYS AS FLOAT)  
                                            / CAST (360 AS FLOAT)  
                                            * C.EIR_NOCF2 / CAST(100 AS FLOAT)  
                                            * C.CRYAMT_NOCF2  
                                       WHEN A.INTCALCCODE IN ( '2', '3' )  
                                       THEN CAST(A.I_DAYS AS FLOAT)  
                                            / CAST (365 AS FLOAT)  
                                            * C.EIR_NOCF2 / CAST(100 AS FLOAT)  
                                            * C.CRYAMT_NOCF2  
                                       ELSE ( CAST (A.M AS FLOAT)  
                                              / CAST (1200 AS FLOAT)  
                                              * C.EIR_NOCF2 * C.CRYAMT_NOCF2 )  
                                  END ) - A.N_INT_PAYMENT ,  
                A.UNAMORT_NOCF1 = ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                           THEN CAST(A.I_DAYS AS FLOAT)  
                                                / CAST (360 AS FLOAT)  
                                                * C.EIR_NOCF1  
                                                / CAST(100 AS FLOAT)  
                                                * C.CRYAMT_NOCF1  
                                           WHEN A.INTCALCCODE IN ( '2', '3' )  
                                           THEN CAST(A.I_DAYS AS FLOAT)  
                                                / CAST (365 AS FLOAT)  
                                                * C.EIR_NOCF1  
                                                / CAST(100 AS FLOAT)  
                                                * C.CRYAMT_NOCF1  
                                           ELSE ( CAST (A.M AS NUMERIC(18, 10))  
                                                  / CAST (1200 AS FLOAT)  
                                                  * C.EIR_NOCF1  
                                                  * C.CRYAMT_NOCF1 )  
                                      END ) - A.N_INT_PAYMENT )  
                + C.UNAMORT_NOCF1 ,  
                A.UNAMORT_NOCF2 = ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                           THEN CAST(A.I_DAYS AS FLOAT)  
                                                / CAST (360 AS FLOAT)  
                                                * C.EIR_NOCF2  
                                                / CAST(100 AS FLOAT)  
                                                * C.CRYAMT_NOCF2  
                                           WHEN A.INTCALCCODE IN ( '2', '3' )  
                                           THEN CAST(A.I_DAYS AS FLOAT)  
                                                / CAST (365 AS FLOAT)  
                                                * C.EIR_NOCF2  
                                                / CAST(100 AS FLOAT)  
* C.CRYAMT_NOCF2  
                                           ELSE ( CAST (A.M AS FLOAT)  
                                                  / CAST (1200 AS FLOAT)  
                                                  * C.EIR_NOCF2  
                                                  * C.CRYAMT_NOCF2 )  
                                      END ) - A.N_INT_PAYMENT )  
                + C.UNAMORT_NOCF2 ,  
                A.CRYAMT_NOCF1 = C.CRYAMT_NOCF1  
                + ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                           THEN CAST(A.I_DAYS AS FLOAT) / CAST (360 AS FLOAT)  
                                * C.EIR_NOCF1 / CAST(100 AS FLOAT)  
                                * C.CRYAMT_NOCF1  
                           WHEN A.INTCALCCODE IN ( '2', '3' )  
                           THEN CAST(A.I_DAYS AS FLOAT) / CAST (365 AS FLOAT)  
                                * C.EIR_NOCF1 / CAST(100 AS FLOAT)  
                                * C.CRYAMT_NOCF1  
                           ELSE ( CAST (A.M AS NUMERIC(18, 10))  
                                  / CAST (1200 AS FLOAT) * C.EIR_NOCF1  
                                  * C.CRYAMT_NOCF1 )  
                      END ) - A.N_INT_PAYMENT ) - A.N_PRN_PAYMENT + A.DISB_AMOUNT,  
                A.CRYAMT_NOCF2 = C.CRYAMT_NOCF2  
                + ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                           THEN CAST(A.I_DAYS AS FLOAT) / CAST (360 AS FLOAT)  
                                * C.EIR_NOCF2 / CAST(100 AS FLOAT)  
                                * C.CRYAMT_NOCF2  
                           WHEN A.INTCALCCODE IN ( '2', '3' )  
                           THEN CAST(A.I_DAYS AS FLOAT) / CAST (365 AS FLOAT)  
                                * C.EIR_NOCF2 / CAST(100 AS FLOAT)  
                                * C.CRYAMT_NOCF2  
                           ELSE ( CAST (A.M AS FLOAT) / CAST (1200 AS FLOAT)  
                                  * C.EIR_NOCF2 * C.CRYAMT_NOCF2 )  
                      END ) - A.N_INT_PAYMENT ) - A.N_PRN_PAYMENT + A.DISB_AMOUNT,   
*/
				--WITH CF PART  
				A.PREV_UNAMORT1 = C.UNAMORT1
				,A.PREV_UNAMORT2 = C.UNAMORT2
				,A.PREV_CRYAMT1 = C.CRYAMT1
				,A.PREV_CRYAMT2 = C.CRYAMT2
				,A.EIR1 = C.EIR1
				,A.EIR2 = C.EIR2
				,A.EIRAMT1 =
				/*  BCA DISABLE BPI 
					CASE WHEN (A.COUNTER = 1 AND A.SPECIAL_FLAG = 1)  
					THEN  
					  C.EIR1 /100*(DATEDIFF(DAY,A.PREV_PMT_DATE,A.PMT_DATE))*  
					  C.CRYAMT1/12/(DATEDIFF(DAY,  
						CASE WHEN A.PMT_DATE = EOMONTH(A.PMT_DATE )   
						THEN EOMONTH(DATEADD(MONTH,-1,A.PMT_DATE )) ELSE DATEADD(MONTH,-1,A.PMT_DATE) END,  
					 A.PMT_DATE ))  
					ELSE  
					*/
				CASE 
					WHEN A.INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.EIR1 / 100 * C.CRYAMT1
					WHEN A.INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.EIR1 / 100 * C.CRYAMT1
					ELSE (CAST(A.M AS FLOAT) / CAST(1200 AS FLOAT) * C.EIR1 * C.CRYAMT1)
						/*  BCA DISABLE BPI END */
					END
				,EIRAMT2 =
				/*  BCA DISABLE BPI  
    CASE WHEN (A.COUNTER = 1 AND A.SPECIAL_FLAG = 1)  
    THEN  
      C.EIR2 /100*(DATEDIFF(DAY,A.PREV_PMT_DATE,A.PMT_DATE))*  
      C.CRYAMT2/12/(DATEDIFF(DAY,  
        CASE WHEN A.PMT_DATE = EOMONTH(A.PMT_DATE )   
        THEN EOMONTH(DATEADD(MONTH,-1,A.PMT_DATE )) ELSE DATEADD(MONTH,-1,A.PMT_DATE) END,  
     A.PMT_DATE ))  
    ELSE  
      */
				CASE 
					WHEN A.INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * C.EIR2 / 100 * C.CRYAMT2
					WHEN A.INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(A.I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * C.EIR2 / 100 * C.CRYAMT2
					ELSE (CAST(A.M AS FLOAT) / CAST(1200 AS FLOAT) * C.EIR2 * C.CRYAMT2)
					END
			/*  BCA DISABLE BPI END */
			--,  
			/*20170912, REMARK KATA YACOP  
                A.AMORT1 = ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                  THEN CAST (A.I_DAYS AS FLOAT)  
                                       / CAST (360 AS FLOAT) * C.EIR1 / 100  
                                       * C.CRYAMT1  
                                  WHEN A.INTCALCCODE IN ( '2', '3' )  
                                  THEN CAST (A.I_DAYS AS FLOAT)  
                                       / CAST (365 AS FLOAT) * C.EIR1 / 100  
                                       * C.CRYAMT1  
                                  ELSE ( CAST (A.M AS FLOAT)  
                                         / CAST (1200 AS FLOAT) * C.EIR1  
                                         * C.CRYAMT1 )  
                             END ) - A.N_INT_PAYMENT ,  
                A.AMORT2 = ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                  THEN CAST (A.I_DAYS AS FLOAT)  
                                       / CAST (360 AS FLOAT) * C.EIR2 / 100  
                                       * C.CRYAMT2  
                                  WHEN A.INTCALCCODE IN ( '2', '3' )  
                                  THEN CAST (A.I_DAYS AS FLOAT)  
                                       / CAST (365 AS FLOAT) * C.EIR2 / 100  
                                       * C.CRYAMT2  
                                  ELSE ( CAST (A.M AS FLOAT)  
                                         / CAST (1200 AS FLOAT) * C.EIR2  
                                         * C.CRYAMT2 )  
                             END ) - A.N_INT_PAYMENT ,  
                A.UNAMORT1 = ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                      THEN CAST (A.I_DAYS AS FLOAT)  
                                           / CAST (360 AS FLOAT) * C.EIR1  
                                           / 100 * C.CRYAMT1  
                                      WHEN A.INTCALCCODE IN ( '2', '3' )  
                                      THEN CAST (A.I_DAYS AS FLOAT)  
                                           / CAST (365 AS FLOAT) * C.EIR1  
                                           / 100 * C.CRYAMT1  
                                      ELSE ( CAST (A.M AS FLOAT)  
                                             / CAST (1200 AS FLOAT) * C.EIR1  
                                             * C.CRYAMT1 )  
                                 END ) - A.N_INT_PAYMENT ) + C.UNAMORT1 ,  
                A.UNAMORT2 = ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                                      THEN CAST (A.I_DAYS AS FLOAT)  
                                           / CAST (360 AS FLOAT) * C.EIR2  
                                           / 100 * C.CRYAMT2  
                                      WHEN A.INTCALCCODE IN ( '2', '3' )  
                                      THEN CAST (A.I_DAYS AS FLOAT)  
                                           / CAST (365 AS FLOAT) * C.EIR2  
                                           / 100 * C.CRYAMT2  
                                      ELSE ( CAST (A.M AS FLOAT)  
                                             / CAST (1200 AS FLOAT) * C.EIR2  
                                             * C.CRYAMT2 )  
                                 END ) - A.N_INT_PAYMENT ) + C.UNAMORT2 ,  
                A.CRYAMT1 = C.CRYAMT1  
                + ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                           THEN CAST (A.I_DAYS AS FLOAT) / CAST (360 AS FLOAT)  
                                * C.EIR1 / 100 * C.CRYAMT1                             WHEN A.INTCALCCODE IN ( '2', '3' )  
                           THEN CAST (A.I_DAYS AS FLOAT) / CAST (365 AS FLOAT)  
                                * C.EIR1 / 100 * C.CRYAMT1  
                           ELSE ( CAST (A.M AS FLOAT) / CAST (1200 AS FLOAT)  
                                  * C.EIR1 * C.CRYAMT1 )  
                      END ) - A.N_INT_PAYMENT ) - A.N_PRN_PAYMENT + A.DISB_AMOUNT,  
                A.CRYAMT2 = C.CRYAMT2  
                + ( ( CASE WHEN A.INTCALCCODE IN ( '1', '6' )  
                           THEN CAST (A.I_DAYS AS FLOAT) / CAST (360 AS FLOAT)  
                                * C.EIR2 / 100 * C.CRYAMT2  
                           WHEN A.INTCALCCODE IN ( '2', '3' )  
                           THEN CAST (A.I_DAYS AS FLOAT) / CAST (365 AS FLOAT)  
                                * C.EIR2 / 100 * C.CRYAMT2  
                           ELSE ( CAST (A.M AS FLOAT) / CAST (1200 AS FLOAT)  
                                  * C.EIR2 * C.CRYAMT2 )  
                      END ) - A.N_INT_PAYMENT ) - A.N_PRN_PAYMENT + A.DISB_AMOUNT  
*/
			/*REPLACE CODE 20160525*/
			FROM DBO.IFRS_LI_ACCT_EIR_PAYM_GS A
			JOIN IFRS_LI_GS_DATE1 B ON A.MASTERID = B.MASTERID
			JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON B.MASTERID = C.MASTERID
				AND C.COUNTER = @V_COUNTER - 1
			WHERE A.COUNTER = @V_COUNTER

			/*REPLACE CODE 20160525*/
			/* REMARKS 20160525  
         FROM PSAK_TMP_GS3 C  
         WHERE C.PMT_DATE = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE   
    AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID = C.MASTERID  
  */
			INSERT INTO IFRS_LI_AMORT_LOG (
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
				,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
				,'5'
				)

			UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS
			SET
				--WITHOUT CF PART  
				AMORT_NOCF1 = EIRAMT_NOCF1 - N_INT_PAYMENT
				,AMORT_NOCF2 = EIRAMT_NOCF2 - N_INT_PAYMENT
				,UNAMORT_NOCF1 = (EIRAMT_NOCF1 - N_INT_PAYMENT) + PREV_UNAMORT_NOCF1
				,UNAMORT_NOCF2 = (EIRAMT_NOCF2 - N_INT_PAYMENT) + PREV_UNAMORT_NOCF2
				,CRYAMT_NOCF1 = PREV_CRYAMT_NOCF1 + (EIRAMT_NOCF1 - N_INT_PAYMENT) - N_PRN_PAYMENT
				,CRYAMT_NOCF2 = PREV_CRYAMT_NOCF2 + (EIRAMT_NOCF2 - N_INT_PAYMENT) - N_PRN_PAYMENT
				,
				--WITH CF PART  
				AMORT1 = EIRAMT1 - N_INT_PAYMENT
				,AMORT2 = EIRAMT2 - N_INT_PAYMENT
				,UNAMORT1 = (EIRAMT1 - N_INT_PAYMENT) + PREV_UNAMORT1
				,UNAMORT2 = (EIRAMT2 - N_INT_PAYMENT) + PREV_UNAMORT2
				,CRYAMT1 = PREV_CRYAMT1 + (EIRAMT1 - N_INT_PAYMENT) - N_PRN_PAYMENT
				,CRYAMT2 = PREV_CRYAMT2 + (EIRAMT2 - N_INT_PAYMENT) - N_PRN_PAYMENT
			FROM IFRS_LI_GS_DATE1 B
			WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID = B.MASTERID
				--AND B.PMT_DATE = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE --REMARKS 20160525  
				AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = @V_COUNTER --ADDING 20160525  
				/*REMARKS.. UPDATE SEKALIAN DIATAS 20160525  
         END REMARKS 20160525*/

			INSERT INTO IFRS_LI_AMORT_LOG (
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
				,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
				,'6'
				)

			--PREPARE NEXT  
			SET @V_COUNTER = @V_COUNTER + 1
				/*REMARKS 200160525   
         TRUNCATE TABLE PSAK_GS_DATE2  
         INSERT INTO PSAK_GS_DATE2 (MASTERID, PMT_DATE)  
              SELECT A.MASTERID, MIN (A.PMT_DATE) DT  
                FROM    IFRS_LI_ACCT_EIR_PAYM_GS A  
                     JOIN  
                        IFRS_LI_GS_DATE1 B  
                     ON A.PMT_DATE > B.PMT_DATE AND B.MASTERID = A.MASTERID  
            GROUP BY A.MASTERID  
              
  TRUNCATE TABLE IFRS_LI_GS_DATE1  
         INSERT INTO IFRS_LI_GS_DATE1 (MASTERID, PMT_DATE)  
            SELECT MASTERID, PMT_DATE FROM PSAK_GS_DATE2  
              
         INSERT INTO IFRS_LI_AMORT_LOG (  
                                     DOWNLOAD_DATE,  
                                     DTM,  
                                     OPS,  
                                     PROCNAME,  
                                     REMARK)  
              VALUES (  
                      @V_CURRDATE,  
                      CURRENT_TIMESTAMP,  
                      'DEBUG',  
                      'SP_IFRS_LI_ACCT_EIR_GS_PROCESS',  
                      '7')  
  
    REMARKS 200160525*/
		END --LOOP;  

		--INNER LOOP  
		-- GET SUCCESS EIR1   
		--WITH CF PART  
		TRUNCATE TABLE TMP_LI_T14

		INSERT INTO TMP_LI_T14 (
			MASTERID
			,E1
			)
		SELECT B.MASTERID
			,C.EIR1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_GS_DATE1 D ON B.MASTERID = D.MASTERID --ADDING JOIN 20160525  
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT1) < 0.01

		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET FINAL_EIR = C.E1
		FROM TMP_LI_T14 C
		WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = C.MASTERID
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR IS NULL

		UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET EIR = FINAL_EIR
		WHERE FINAL_EIR IS NOT NULL
			AND EIR IS NULL

		--WITHOUT CF PART  
		TRUNCATE TABLE TMP_LI_T14

		INSERT INTO TMP_LI_T14 (
			MASTERID
			,E1
			)
		SELECT B.MASTERID
			,C.EIR_NOCF1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_GS_DATE1 D ON B.MASTERID = D.MASTERID --ADDING JOIN 20160525  
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT_NOCF1) < 0.01

		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET FINAL_EIR_NOCF = C.E1
		FROM TMP_LI_T14 C
		WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = C.MASTERID
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR_NOCF IS NULL

		UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET EIR_NOCF = FINAL_EIR_NOCF
		WHERE FINAL_EIR_NOCF IS NOT NULL
			AND EIR_NOCF IS NULL

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'7B'
			)

		-- SET NEXT EIR  
		TRUNCATE TABLE TMP_LI_GS1

		INSERT INTO TMP_LI_GS1 (
			MASTERID
			,UNAMORT_NOCF1
			,UNAMORT_NOCF2
			,EIR_NOCF1
			,EIR_NOCF2
			,UNAMORT1
			,UNAMORT2
			,EIR1
			,EIR2
			)
		SELECT B.MASTERID
			,C.UNAMORT_NOCF1
			,C.UNAMORT_NOCF2
			,C.EIR_NOCF1
			,C.EIR_NOCF2
			,C.UNAMORT1
			,C.UNAMORT2
			,C.EIR1
			,C.EIR2
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_GS_DATE1 D ON B.MASTERID = D.MASTERID --ADDING JOIN 20160525  
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX   
			AND B.MASTERID = C.MASTERID
			AND (
				B.EIR IS NULL
				OR B.EIR_NOCF IS NULL
				)

		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET
			--WITHOUT CF PART  
			NEXT_EIR_NOCF = ISNULL(EIR_NOCF, CASE 
					WHEN ABS((((C.UNAMORT_NOCF2 - C.UNAMORT_NOCF1) / (C.EIR_NOCF2 - C.EIR_NOCF1)) * C.EIR_NOCF1 - C.UNAMORT_NOCF1) / ((C.UNAMORT_NOCF2 - C.UNAMORT_NOCF1) / (C.EIR_NOCF2 - C.EIR_NOCF1))) > 2000
						THEN 15
					ELSE (((CAST(C.UNAMORT_NOCF2 AS FLOAT) - CAST(C.UNAMORT_NOCF1 AS FLOAT)) / (CAST(C.EIR_NOCF2 AS FLOAT) - CAST(C.EIR_NOCF1 AS FLOAT))) * CAST(C.EIR_NOCF1 AS FLOAT) - CAST(C.UNAMORT_NOCF1 AS FLOAT)) / ((CAST(C.UNAMORT_NOCF2 AS FLOAT) - CAST(C.UNAMORT_NOCF1 AS FLOAT)) / (CAST(C.EIR_NOCF2 AS FLOAT) - CAST(C.EIR_NOCF1 AS FLOAT)))
					END)
			,
			--WITH CF PART  
			NEXT_EIR = ISNULL(EIR, CASE 
					WHEN ABS((((C.UNAMORT2 - C.UNAMORT1) / (C.EIR2 - C.EIR1)) * C.EIR1 - C.UNAMORT1) / ((C.UNAMORT2 - C.UNAMORT1) / (C.EIR2 - C.EIR1))) > 2000
						THEN 15
					ELSE (((CAST(C.UNAMORT2 AS FLOAT) - CAST(C.UNAMORT1 AS FLOAT)) / (CAST(C.EIR2 AS FLOAT) - CAST(C.EIR1 AS FLOAT))) * CAST(C.EIR1 AS FLOAT) - CAST(C.UNAMORT1 AS FLOAT)) / ((CAST(C.UNAMORT2 AS FLOAT) - CAST(C.UNAMORT1 AS FLOAT)) / (CAST(C.EIR2 AS FLOAT) - CAST(C.EIR1 AS FLOAT)))
					END)
		FROM TMP_LI_GS1 C
		WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = C.MASTERID
			AND (
				DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR IS NULL
				OR DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR_NOCF IS NULL
				)

		-- IF NEXT_EIR=EIR1 THEN PROBABLY GS HAS REACH ITS LIMIT SO TERMINATE AS SOON AS POSSIBLE  
		--WITH CF PART  
		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET FINAL_EIR = NEXT_EIR
		FROM TMP_LI_GS1 C
		WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = C.MASTERID
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR IS NULL
			AND C.EIR1 = DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.NEXT_EIR
			AND ABS(C.UNAMORT1) < 1

		UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET EIR = FINAL_EIR
		WHERE FINAL_EIR IS NOT NULL
			AND EIR IS NULL

		--WITHOUT CF PART  
		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET FINAL_EIR_NOCF = NEXT_EIR_NOCF
		FROM TMP_LI_GS1 C
		WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = C.MASTERID
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR_NOCF IS NULL
			AND C.EIR_NOCF1 = DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.NEXT_EIR_NOCF
			AND ABS(C.UNAMORT_NOCF1) < 1

		UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		SET EIR_NOCF = FINAL_EIR_NOCF
		WHERE FINAL_EIR_NOCF IS NOT NULL
			AND EIR_NOCF IS NULL

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'8'
			)

		--INIT LOOP 1 --SELECT * FROM TMP_LI_GS2  
		TRUNCATE TABLE TMP_LI_GS2

		INSERT INTO TMP_LI_GS2 (
			MASTERID
			,DTMIN
			,CNTMIN
			,NEXT_EIR
			,NEXT_EIR_NOCF
			,STAFFLOAN
			,BENEFIT
			,FEE_AMT
			,COST_AMT
			,GAIN_LOSS_FEE_AMT --20180417  
			,GAIN_LOSS_COST_AMT --20180417  
			)
		SELECT B.MASTERID
			,C.DTMIN
			,C.CNTMIN
			,C.NEXT_EIR
			,C.NEXT_EIR_NOCF
			,B.STAFFLOAN
			,B.BENEFIT
			,B.FEE_AMT
			,B.COST_AMT
			,COALESCE(B.GAIN_LOSS_FEE_AMT, 0) --20180417 GAIN LOSS ADJ  
			,COALESCE(B.GAIN_LOSS_COST_AMT, 0)
		FROM IFRS_LI_ACCT_EIR_CF_ECF1 B
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS_DATE C ON C.MASTERID = B.MASTERID
			AND (
				C.EIR IS NULL
				OR C.EIR_NOCF IS NULL
				)

		SELECT @VCNT2 = COUNT(*)
		FROM TMP_LI_GS2

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'NOA GS : ' + CAST(@VCNT2 AS VARCHAR(10))
			)

		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS
		SET
			--WITHOUT CF PART  
			PREV_UNAMORT_NOCF1 = 0
			,--ZERO UNAMORT  
			EIR_NOCF1 = B.NEXT_EIR_NOCF
			,EIR_NOCF2 = B.NEXT_EIR_NOCF + (CAST(0.001 AS FLOAT) * B.NEXT_EIR_NOCF)
			,
			--WITH CF PART  
			PREV_UNAMORT1 = CASE 
				WHEN B.STAFFLOAN = 1
					AND B.BENEFIT < 0
					THEN B.BENEFIT
				WHEN B.STAFFLOAN = 1
					AND B.BENEFIT >= 0
					THEN 0
				ELSE B.FEE_AMT - B.GAIN_LOSS_FEE_AMT --201801417  
				END + CASE 
				WHEN B.STAFFLOAN = 1
					AND B.BENEFIT <= 0
					THEN 0
				WHEN B.STAFFLOAN = 1
					AND B.BENEFIT > 0
					THEN B.BENEFIT
				ELSE B.COST_AMT - B.GAIN_LOSS_COST_AMT --201801417  
				END
			,EIR1 = B.NEXT_EIR
			,EIR2 = B.NEXT_EIR + (0.001 * B.NEXT_EIR)
		FROM TMP_LI_GS2 B
		WHERE B.MASTERID = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID
			--AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = B.DTMIN -- REMARKS 20160525  
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = B.CNTMIN -- ADDING 20160525  

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'9'
			)

		UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS
		SET
			-- WITHOUT CF PART  
			PREV_UNAMORT_NOCF2 = PREV_UNAMORT_NOCF1
			,PREV_CRYAMT_NOCF1 = N_OSPRN_PREV + PREV_UNAMORT_NOCF1
			,PREV_CRYAMT_NOCF2 = N_OSPRN_PREV + PREV_UNAMORT_NOCF1
			,EIRAMT_NOCF1 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END
			,EIRAMT_NOCF2 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END
			,AMORT_NOCF1 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT
			,AMORT_NOCF2 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT
			,UNAMORT_NOCF1 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT + PREV_UNAMORT_NOCF1
			,UNAMORT_NOCF2 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
				END - N_INT_PAYMENT + PREV_UNAMORT_NOCF1
			,CRYAMT_NOCF1 = (N_OSPRN_PREV + PREV_UNAMORT_NOCF1) - N_PRN_PAYMENT + (
				CASE 
					--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
							--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
					WHEN INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF1 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF1 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
					END - N_INT_PAYMENT
				) + DISB_AMOUNT
			,CRYAMT_NOCF2 = (N_OSPRN_PREV + PREV_UNAMORT_NOCF1) - N_PRN_PAYMENT + (
				CASE 
					--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
							--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE  
					WHEN INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR_NOCF2 / CAST(100 AS FLOAT) * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1)
					ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR_NOCF2 * (N_OSPRN_PREV + PREV_UNAMORT_NOCF1))
					END - N_INT_PAYMENT
				) + DISB_AMOUNT
			,
			-- WITH CF PART  
			PREV_UNAMORT2 = PREV_UNAMORT1
			,PREV_CRYAMT1 = N_OSPRN_PREV + PREV_UNAMORT1
			,PREV_CRYAMT2 = N_OSPRN_PREV + PREV_UNAMORT1
			,EIRAMT1 =
			/*  BCA DISABLE BPI  
		   CASE WHEN (IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = 1 AND IFRS_LI_ACCT_EIR_PAYM_GS.SPECIAL_FLAG = 1)  
		   THEN  
			  EIR1/100*(DATEDIFF(DAY,IFRS_LI_ACCT_EIR_PAYM_GS.PREV_PMT_DATE,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))*  
			  (N_OSPRN_PREV + PREV_UNAMORT1)/12/(DATEDIFF(DAY,  
				CASE WHEN IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = EOMONTH(IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)   
				THEN EOMONTH(DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)) ELSE DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE) END,  
			 IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))  
		   ELSE  
		   */
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
					/*  BCA DISABLE BPI END */
				END
			,EIRAMT2 =
			/*  BCA DISABLE BPI  
   CASE WHEN (IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = 1 AND IFRS_LI_ACCT_EIR_PAYM_GS.SPECIAL_FLAG = 1)  
   THEN  
      EIR2/100*(DATEDIFF(DAY,IFRS_LI_ACCT_EIR_PAYM_GS.PREV_PMT_DATE,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))*  
      (N_OSPRN_PREV + PREV_UNAMORT2)/12/(DATEDIFF(DAY,  
        CASE WHEN IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = EOMONTH(IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)   
        THEN EOMONTH(DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE)) ELSE DATEADD(MONTH,-1,IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE) END,  
     IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE))  
   ELSE  
        */
			CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
					/*  BCA DISABLE BPI END */
				END
			,AMORT1 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT
			,AMORT2 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT
			,UNAMORT1 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT + PREV_UNAMORT1
			,UNAMORT2 = CASE 
				--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'1'
						,'6'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
						--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
				WHEN INTCALCCODE IN (
						'2'
						,'3'
						)
					THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
				ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
				END - N_INT_PAYMENT + PREV_UNAMORT1
			,CRYAMT1 = (N_OSPRN_PREV + PREV_UNAMORT1) - N_PRN_PAYMENT + (
				CASE 
					--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
							--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR1 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR1 * (N_OSPRN_PREV + PREV_UNAMORT1))
					END - N_INT_PAYMENT
				) + DISB_AMOUNT
			,CRYAMT2 = (N_OSPRN_PREV + PREV_UNAMORT1) - N_PRN_PAYMENT + (
				CASE 
					--WHEN INTCALCCODE IN ('2','6') REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'1'
							,'6'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(360 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
							--WHEN INTCALCCODE = '3' REMARKS FOR ALIGN WITH ICC PAYMENT SCHEDULE 20160428  
					WHEN INTCALCCODE IN (
							'2'
							,'3'
							)
						THEN CAST(I_DAYS AS FLOAT) / CAST(365 AS FLOAT) * EIR2 / 100 * (N_OSPRN_PREV + PREV_UNAMORT1)
					ELSE (CAST(M AS FLOAT) / CAST(1200 AS FLOAT) * EIR2 * (N_OSPRN_PREV + PREV_UNAMORT1))
					END - N_INT_PAYMENT
				) + DISB_AMOUNT
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE C
		WHERE C.MASTERID = DBO.IFRS_LI_ACCT_EIR_PAYM_GS.MASTERID
			--AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.PMT_DATE = C.DTMIN --REMARKS 20160525  
			AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS.COUNTER = C.CNTMIN --ADDING 20160525  
			AND (
				C.EIR IS NULL
				OR C.EIR_NOCF IS NULL
				)

		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'9B'
			)

		TRUNCATE TABLE IFRS_LI_GS_DATE1

		INSERT INTO IFRS_LI_GS_DATE1 (
			MASTERID
			,PMT_DATE
			,PERIOD
			)
		SELECT MASTERID
			,DTMIN
			,PERIOD
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE
		WHERE (
				EIR IS NULL
				OR EIR_NOCF IS NULL
				)

		/*REMARKS 20160525  
           SELECT A.MASTERID, MIN (A.PMT_DATE) DT  
             FROM    IFRS_LI_ACCT_EIR_PAYM_GS A  
                  JOIN  
                     IFRS_LI_ACCT_EIR_PAYM_GS_DATE B  
                  ON     A.PMT_DATE > B.DTMIN  
                     AND A.MASTERID = B.MASTERID  
                     AND B.EIR IS NULL  
         GROUP BY A.MASTERID  
   END REMARKS 20160525*/
		INSERT INTO IFRS_LI_AMORT_LOG (
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
			,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
			,'10'
			)
	END --LOOP;  

	--OUTER LOOP  
	-- GET SUCCESS EIR1 LAST LOOP  
	--WITH CF PART  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET FINAL_EIR = B.EIR1
	FROM (
		SELECT B.MASTERID
			,C.EIR1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT1) < 1
		) B
	WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = B.MASTERID
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR IS NULL

	UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET EIR = FINAL_EIR
	WHERE FINAL_EIR IS NOT NULL
		AND EIR IS NULL

	--WITHOUT CF PART  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET FINAL_EIR_NOCF = B.EIR_NOCF1
	FROM (
		SELECT B.MASTERID
			,C.EIR_NOCF1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT_NOCF1) < 1
		) B
	WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = B.MASTERID
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR_NOCF IS NULL

	UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET EIR_NOCF = FINAL_EIR_NOCF
	WHERE FINAL_EIR_NOCF IS NOT NULL
		AND EIR_NOCF IS NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'11'
		)

	-- 20131106 DANIEL S : GET SUCCESS EIR1 LAST LOOP WITH BIG INITIAL UNAMORT  
	-- WITH CF PART  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET FINAL_EIR = B.EIR1
	FROM (
		SELECT B.MASTERID
			,C.EIR1
			,C.EIR_NOCF1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT1) < 10
		) B
	WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = B.MASTERID
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR IS NULL
		AND ABS(DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.UNAMORT) > 1000000000

	UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET EIR = FINAL_EIR
	WHERE FINAL_EIR IS NOT NULL
		AND EIR IS NULL

	-- WITHOUT CF PART  
	UPDATE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET FINAL_EIR_NOCF = B.EIR_NOCF1
	FROM (
		SELECT B.MASTERID
			,C.EIR_NOCF1
		FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE B
		JOIN IFRS_LI_ACCT_EIR_PAYM_GS C ON C.COUNTER = B.CNTMAX --C.PMT_DATE = B.DTMAX  
			AND B.MASTERID = C.MASTERID
			AND ABS(C.UNAMORT_NOCF1) < 10
		) B
	WHERE DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.MASTERID = B.MASTERID
		AND DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.EIR_NOCF IS NULL
		AND ABS(DBO.IFRS_LI_ACCT_EIR_PAYM_GS_DATE.UNAMORT_NOCF) > 1000000000

	UPDATE IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	SET EIR_NOCF = FINAL_EIR_NOCF
	WHERE FINAL_EIR_NOCF IS NOT NULL
		AND EIR_NOCF IS NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'12'
		)

	-- FAILED GOAL SEEK WITH CF PART  
	INSERT INTO IFRS_LI_ACCT_EIR_FAILED_GS (
		DOWNLOAD_DATE
		,MASTERID
		,CREATEDBY
		,CREATEDDATE
		)
	SELECT @V_CURRDATE
		,MASTERID
		,'EIR_GS'
		,CURRENT_TIMESTAMP
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	WHERE EIR IS NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'13'
		)

	-- SUCCESS GOAL SEEK WITH CF PART  
	INSERT INTO IFRS_LI_ACCT_EIR_GS_RESULT (
		DOWNLOAD_DATE
		,MASTERID
		,CREATEDBY
		,CREATEDDATE
		,EIR
		)
	SELECT @V_CURRDATE
		,MASTERID
		,'EIR_GS'
		,CURRENT_TIMESTAMP
		,EIR
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	WHERE EIR IS NOT NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'14'
		)

	-- FAILED GOAL SEEK WITHOUT CF PART   
	INSERT INTO IFRS_LI_ACCT_EIR_FAILED_GS4 (
		DOWNLOAD_DATE
		,MASTERID
		,CREATEDBY
		,CREATEDDATE
		)
	SELECT @V_CURRDATE
		,MASTERID
		,'EIR_GS'
		,CURRENT_TIMESTAMP
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	WHERE EIR_NOCF IS NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,'15'
		)

	-- SUCCESS GOAL SEEK WITHOUT CF PART  
	INSERT INTO IFRS_LI_ACCT_EIR_GS_RESULT4 (
		DOWNLOAD_DATE
		,MASTERID
		,CREATEDBY
		,CREATEDDATE
		,EIR
		)
	SELECT @V_CURRDATE
		,MASTERID
		,'EIR_GS'
		,CURRENT_TIMESTAMP
		,EIR_NOCF
	FROM IFRS_LI_ACCT_EIR_PAYM_GS_DATE
	WHERE EIR_NOCF IS NOT NULL

	INSERT INTO IFRS_LI_AMORT_LOG (
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
		,'SP_IFRS_LI_ACCT_EIR_GS_PROCESS'
		,''
		)
END

GO
