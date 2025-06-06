USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_FILL_HOLIDAY]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_FILL_HOLIDAY]
AS
BEGIN

DECLARE @ISHOLIDAY INT ,  
        @V_CURRDATE DATETIME ,  
        @V_PREVDATE DATETIME                                  
                                                    
             
    SELECT  @V_CURRDATE = CURRDATE ,  
            @V_PREVDATE = PREVDATE  
    FROM    IFRS_PRC_DATE_AMORT (NOLOCK) 

	SELECT @ISHOLIDAY = DBO.FN_HOLIDAY(CURRDATE) FROM IFRS_PRC_DATE_AMORT (NOLOCK) 

	 IF @IsHoliday = 1   
        BEGIN

		INSERT INTO IFRS_AMORT_LOG 
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
					,'START COPY IFRS HOLIDAY'
					,'SP_IFRS_FILL_HOLIDAY'
					,''
		)
		DELETE FROM DBO.IFRS_HOLIDAY WHERE DOWNLOAD_DATE = @V_CURRDATE

        INSERT INTO IFRS_HOLIDAY  
                ( 
				   HOLIDAY_DATE,  
                   DESCRIPTION,  
                   DOWNLOAD_DATE,  
                   INSERTDATE
                )  
        SELECT  HOLIDAY_DATE,  
                DESCRIPTION,  
                DATEADD(DAY, 1, DOWNLOAD_DATE),
                GETDATE()
        FROM IFRS_HOLIDAY
        WHERE DOWNLOAD_DATE = @V_PREVDATE
		
		INSERT INTO IFRS_AMORT_LOG 
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
					,'END COPY IFRS HOLIDAY'
					,'SP_IFRS_FILL_HOLIDAY'
					,''
		)  

		END

END

GO
