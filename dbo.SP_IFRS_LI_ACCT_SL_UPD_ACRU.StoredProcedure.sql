USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_LI_ACCT_SL_UPD_ACRU]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_LI_ACCT_SL_UPD_ACRU]
AS
declare @v_currdate	date
	,@v_prevdate	date

begin

select @v_currdate=max(currdate),@v_prevdate=max(prevdate) from IFRS_LI_PRC_DATE_AMORT 


insert into IFRS_LI_AMORT_LOG(DOWNLOAD_DATE,DTM,OPS,PROCNAME,REMARK)
VALUES(@v_currdate,current_timestamp,'START','SP_IFRS_LI_ACCT_SL_UPD_ACRU_ACF','')

truncate table TMP_LI_AP
insert into TMP_LI_AP(masterid, flag_cf,amount)
select masterid, flag_cf,
sum(case when flag_reverse='Y' then -1 * amount else amount end) as amount
from IFRS_LI_ACCT_SL_ACCRU_PREV
where status='ACT'
group by masterid, flag_cf

update dbo.IFRS_LI_ACCT_SL_ACF 
set n_accru_prev_cost=a.amount
from (select x.*,y.* from TMP_LI_AP x cross join IFRS_LI_PRC_DATE_AMORT y) a
where a.masterid=dbo.IFRS_LI_ACCT_SL_ACF.masterid
	and dbo.IFRS_LI_ACCT_SL_ACF.DOWNLOAD_DATE=a.currdate
	and a.flag_cf='C'

update dbo.IFRS_LI_ACCT_SL_ACF 
set n_accru_prev_fee=a.amount
from (select x.*,y.* from TMP_LI_AP x cross join IFRS_LI_PRC_DATE_AMORT y) a
where a.masterid=dbo.IFRS_LI_ACCT_SL_ACF.masterid
	and dbo.IFRS_LI_ACCT_SL_ACF.DOWNLOAD_DATE=a.currdate
	and a.flag_cf='F'

insert into IFRS_LI_AMORT_LOG(DOWNLOAD_DATE,DTM,OPS,PROCNAME,REMARK)
VALUES(@v_currdate,current_timestamp,'END','SP_IFRS_LI_ACCT_SL_UPD_ACRU_ACF','')

end






GO
