USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_CLOSED]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

/****** OBJECT:  STOREDPROCEDURE [DBO].[SP_IFRS_LI_ACCT_CLOSED]    SCRIPT DATE: 5/7/2018 12:32:36 PM ******/
CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_CLOSED]
AS
DECLARE @V_CURRDATE DATE
	,@V_PREVDATE DATE

BEGIN
	SELECT @V_CURRDATE = MAX(CURRDATE)
		,@V_PREVDATE = MAX(PREVDATE)
	FROM IFRS_LI_PRC_DATE_AMORT;

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
		,'SP_IFRS_LI_ACCT_CLOSED'
		,''
		);

	TRUNCATE TABLE TMP_LI_ACCT

	INSERT INTO TMP_LI_ACCT (MASTERID)
	SELECT A.MASTERID
	FROM IFRS_LI_IMA_AMORT_CURR A
	LEFT JOIN IFRS_LI_IMA_AMORT_PREV B ON A.MASTERID = B.MASTERID
	WHERE B.MASTERID IS NULL

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
		,'SP_IFRS_LI_ACCT_CLOSED ACCTSTATUS'
		,''
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
		,'SP_IFRS_LI_ACCT_CLOSED CLS'
		,''
		)

	-- INSERT ACCOUNT CLOSED
	DELETE
	FROM IFRS_LI_ACCT_CLOSED
	WHERE DOWNLOAD_DATE >= @V_CURRDATE;

	--ADDING 20170227 TO GET EIR ACCOUNT
	TRUNCATE TABLE TMP_LI_T1

	--GET EIR ACCOUNT
	INSERT INTO TMP_LI_T1 (MASTERID) (
		SELECT DISTINCT MASTERID FROM IFRS_LI_IMA_AMORT_CURR WHERE AMORT_TYPE = 'EIR'
	
	UNION
		
		SELECT DISTINCT MASTERID FROM IFRS_LI_IMA_AMORT_PREV WHERE AMORT_TYPE = 'EIR'
		)

	/*END ADDING 20170227*/
	--AMORT TYPE EIR
	INSERT INTO IFRS_LI_ACCT_CLOSED (
		FACNO
		,CIFNO
		,DATASOURCE
		,DOWNLOAD_DATE
		,MASTERID
		,ACCTNO
		)
	SELECT A.FACILITY_NUMBER
		,A.CUSTOMER_NUMBER
		,A.DATA_SOURCE
		,@V_CURRDATE
		,A.MASTERID
		,A.ACCOUNT_NUMBER
	FROM IFRS_LI_IMA_AMORT_CURR A
	INNER JOIN TMP_LI_T1 C ON A.MASTERID = C.MASTERID
	WHERE (
			A.WRITEOFF_FLAG = 'Y'
			OR A.ACCOUNT_STATUS = 'W'
			)
		OR (
			A.ACCOUNT_STATUS IN (
				'C'
				,'E'
				,'CE'
				,'CT'
				,'CN'
				)
			)
		OR (A.OUTSTANDING <= 0)
		OR (A.LOAN_DUE_DATE <= @V_CURRDATE)

	--ADDING 20170227 TO GET SL ACCOUNT
	TRUNCATE TABLE TMP_LI_T1

	--GET SL ACCOUNT
	INSERT INTO TMP_LI_T1 (MASTERID) (
		SELECT DISTINCT MASTERID FROM IFRS_LI_IMA_AMORT_CURR WHERE AMORT_TYPE = 'SL'
	
	UNION
		
		SELECT DISTINCT MASTERID FROM IFRS_LI_IMA_AMORT_PREV WHERE AMORT_TYPE = 'SL'
		)

	/*END ADDING 20170227*/
	--AMORT TYPE SL
	INSERT INTO IFRS_LI_ACCT_CLOSED (
		FACNO
		,CIFNO
		,DATASOURCE
		,DOWNLOAD_DATE
		,MASTERID
		,ACCTNO
		)
	SELECT A.FACILITY_NUMBER
		,A.CUSTOMER_NUMBER
		,A.DATA_SOURCE
		,@V_CURRDATE
		,A.MASTERID
		,A.ACCOUNT_NUMBER
	FROM IFRS_LI_IMA_AMORT_CURR A
	INNER JOIN TMP_LI_T1 C ON A.MASTERID = C.MASTERID
	WHERE (
			A.WRITEOFF_FLAG = 'Y'
			OR A.ACCOUNT_STATUS = 'W'
			)
		OR (
			A.ACCOUNT_STATUS IN (
				'C'
				,'E'
				,'CE'
				,'CT'
				,'CN'
				)
			)
		OR (A.LOAN_DUE_DATE <= @V_CURRDATE)

	--ACCOUNT HILANG
	INSERT INTO IFRS_LI_ACCT_CLOSED (
		FACNO
		,CIFNO
		,DATASOURCE
		,DOWNLOAD_DATE
		,MASTERID
		,ACCTNO
		)
	SELECT A.FACILITY_NUMBER
		,A.CUSTOMER_NUMBER
		,A.DATA_SOURCE
		,@V_CURRDATE
		,A.MASTERID
		,A.ACCOUNT_NUMBER
	FROM IFRS_LI_IMA_AMORT_PREV A
	LEFT JOIN IFRS_LI_IMA_AMORT_CURR B ON A.MASTERID = B.MASTERID
	WHERE B.MASTERID IS NULL

	
	--CLOSE PROGRAM FUNDING ADAM
	INSERT INTO IFRS_LI_ACCT_CLOSED
	(
		FACNO
		,CIFNO
		,DATASOURCE
		,DOWNLOAD_DATE
		,MASTERID
		,ACCTNO
	)
	SELECT 
		 A.FACNO
		,A.CIFNO
		,A.DATASOURCE
		,@V_CURRDATE
		,A.MASTERID
		,A.ACCTNO
	FROM DBO.IFRS_LI_ACCT_COST_FEE AS A
	JOIN DBO.IFRS_LI_STG_TRANSACTION_DAILY AS B
	ON
	A.TRX_REFF_NUMBER = B.TRANSACTION_REFERENCE_NUMBER
	AND
	B.DOWNLOAD_DATE = @V_CURRDATE
	AND
	B.TERMINATE_FLAG = 'Y'
	WHERE 
	A.STATUS = 'ACT'
	

	-- PNL SISA UNAMORT IF IFRS9 CLASS FVTPL
	INSERT INTO IFRS_LI_ACCT_CLOSED (
		FACNO
		,CIFNO
		,DATASOURCE
		,DOWNLOAD_DATE
		,MASTERID
		,ACCTNO
		)
	SELECT A.FACILITY_NUMBER
		,A.CUSTOMER_NUMBER
		,A.DATA_SOURCE
		,@V_CURRDATE
		,A.MASTERID
		,A.ACCOUNT_NUMBER
	FROM IFRS_LI_IMA_AMORT_CURR A
	WHERE A.IFRS9_CLASS = 'FVTPL'
	AND A.DOWNLOAD_DATE = @V_CURRDATE
	
	
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
		,'SP_IFRS_LI_ACCT_CLOSED'
		,''
		)
END

GO
