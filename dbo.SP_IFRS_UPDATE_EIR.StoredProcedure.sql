USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_UPDATE_EIR]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_UPDATE_EIR]        
@DOWNLOAD_DATE DATE = NULL        
AS        
    DECLARE @V_CURRDATE DATE        
BEGIN        
    IF @DOWNLOAD_DATE IS NULL        
    BEGIN        
        SELECT @V_CURRDATE = CURRDATE FROM IFRS_PRC_DATE        
    END        
    ELSE        
    BEGIN        
        SET @V_CURRDATE = @DOWNLOAD_DATE        
    END        
       
    IF @V_CURRDATE <= '20190731'  
    BEGIN    
        drop table if exists #eir         
                
        select max(valuation_date) as valuation_date, deal_id        
        into #eir        
        from IFRS9_STG..[t_trn_loan_valuation]        
        where valuation_type= 'EFF YIELD 99'  AND CAST(valuation_date AS DATE) <= @v_currdate        
        group by deal_id        
        order by max(valuation_date)        
                
        alter table #eir add eir float;        
                
        update a        
        set a.eir = b.amount / 100000000000000        
        from #eir a        
        join IFRS9_STG..[t_trn_loan_valuation] b        
        on a.valuation_date = b.valuation_date        
        and a.deal_id = b.deal_id        
                
        TRUNCate table  eir       
                
        insert into eir (valuation_date, deal_id, eir)        
        select valuation_date, deal_id, eir        
        from #eir        
        --where valuation_date <= @v_currdate        
                
        update a        
        set a.eir = b.eir        
        from ifrs_master_account a        
        join eir b        
        on concat(a.BRANCH_CODE, a.PRODUCT_CODE, a.ACCOUNT_NUMBER) = b.deal_id        
        where a.DOWNLOAD_DATE = @v_currdate       
		
		/*update a        
        set a.eir = b.eir        
        from IFRS_MASTER_ACCOUNT_MONTHLY a        
        join eir b        
        on concat(a.BRANCH_CODE, a.PRODUCT_CODE, a.ACCOUNT_NUMBER) = b.deal_id        
        where a.DOWNLOAD_DATE = @v_currdate        
             */   

        -- select concat(BRANCH_CODE, PRODUCT_CODE, ACCOUNT_NUMBER) as masterid, eir         
        -- from ifrs_master_account_monthly where download_date = @v_currdate   
    END       
END
GO
