USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_SENT_MAIL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_SENT_MAIL] --'IMPCR', 'C'  
@V_PRCNAME VARCHAR(10) = 'IMP',  
@FLAG CHAR(1) = 'S' -- 'E' Error, 'C' Completed, 'S' Start  
AS  
BEGIN  
    DECLARE @MAIL_BODY VARCHAR(MAX)   
    DECLARE @FOOTER VARCHAR(MAX)  
    DECLARE @V_CURRDATE DATE   
    DECLARE @V_STARTDATE VARCHAR(50)   
    DECLARE @V_ENDDATE VARCHAR(50)   
    DECLARE @V_ISCOMPLETE VARCHAR(10)   
    DECLARE @V_SESSION_PROCESS_TIME VARCHAR(10)   
    DECLARE @V_REMARK VARCHAR(MAX)   
    DECLARE @TRCE VARCHAR(MAX)   
    DECLARE @V_SUBJECT VARCHAR(MAX)   
  
    IF @V_PRCNAME = 'AMT'   
    BEGIN   
        SELECT @V_CURRDATE = CASE WHEN @FLAG = 'S' THEN DATEADD(DD, 1, CURRDATE) ELSE CURRDATE END  
        FROM IFRS_PRC_DATE_AMORT   
    END 
    ELSE IF @V_PRCNAME = 'IMP_DAILY'   
    BEGIN   
        SELECT @V_CURRDATE = CURRDATE  
        FROM IFRS_PRC_DATE_AMORT   
    END   
    ELSE IF @V_PRCNAME IN ('IMP', 'IMPCR', 'IMP-PRV')   
    BEGIN   
        SELECT @V_CURRDATE = EOMONTH(CURRDATE) FROM IFRS_PRC_DATE   
    END   
    ELSE IF @V_PRCNAME = 'STG'   
    BEGIN   
        SELECT @V_CURRDATE = CASE WHEN @FLAG = 'S' THEN DATEADD(DD, 1, CURRDATE) ELSE CURRDATE END  
        FROM IFRS9_STG..STG_PRC_DATE   
    END   
    
    IF @V_PRCNAME = 'IMPCR'   
    BEGIN   
        SELECT    
            @V_CURRDATE = DOWNLOAD_DATE,    
            @V_STARTDATE = MIN(START_DATE),    
            @V_ENDDATE = MAX(END_DATE),    
            @V_ISCOMPLETE = MIN(ISCOMPLETE),    
            @V_SESSION_PROCESS_TIME = MAX(SESSION_PROCESS_TIME),    
            @V_REMARK = MIN(REMARK)   
        FROM IFRS_STATISTIC WHERE DOWNLOAD_DATE = @V_CURRDATE AND PRC_NAME LIKE '%' + @V_PRCNAME + '%'   
        GROUP BY DOWNLOAD_DATE   
    END   
    ELSE   
    BEGIN   
        SELECT    
            @V_CURRDATE = DOWNLOAD_DATE,    
            @V_STARTDATE = MIN(START_DATE),    
            @V_ENDDATE = MAX(END_DATE),    
            @V_ISCOMPLETE = MIN(ISCOMPLETE),    
            @V_SESSION_PROCESS_TIME = MAX(SESSION_PROCESS_TIME),   
            @V_REMARK = MIN(REMARK)   
        FROM IFRS_STATISTIC WHERE DOWNLOAD_DATE = @V_CURRDATE AND PRC_NAME = @V_PRCNAME   
        GROUP BY DOWNLOAD_DATE   
    END   
    -- SELECT @V_CURRDATE, @V_STARTDATE, @V_ENDDATE, @V_ISCOMPLETE, @V_SESSION_PROCESS_TIME, @V_REMARK   
    
    SET @TRCE = '<tr>   
        <td><strong>END DATE</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + CAST(@V_ENDDATE AS VARCHAR(50))+ '</td>   
        </tr>   
        <tr>   
        <td><strong>PROCESS TIME</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + CAST(@V_SESSION_PROCESS_TIME AS VARCHAR(50))+ '</td>   
        </tr>   
        <tr>   
        <td><strong>COMPLETED</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + @V_ISCOMPLETE + '</td>   
        </tr>   
        <tr>   
        <td><strong>BATCH STATUS</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + @V_REMARK + '</td>   
        </tr>   
        '   
    SET @MAIL_BODY = '  
    <table cellpadding="2" cellspacing="0">  
        <tr align="left">  
   <td style="color:black; font-family:consolas; text-align: left; font-size: 11pt;">Dear All,  
   </td>   
        </tr>   
        <tr>   
   <td></br></td>   
        </tr>   
        <tr>   
   <td style="color:black; font-family:consolas; text-align: left; font-size: 11pt;">   
   The Job for <strong>REGLA PSAK71 ' +   
   CASE @V_PRCNAME   
       WHEN 'IMP' THEN 'Impairment Monthly'   
       WHEN 'AMT' THEN 'Amortization Daily'   
       WHEN 'IMP_DAILY' THEN 'Impairment Daily'   
       WHEN 'STG' THEN 'Staging Daily'  
       WHEN 'IMPCR' THEN 'Catch Up Run'  
    WHEN 'IMP-PRV' THEN 'Impairment Preview'   
   END   
   + '</strong> Process is <strong>' +   
   CASE    
       WHEN @FLAG = 'S' THEN 'STARTED'   
       WHEN @FLAG = 'C' THEN 'COMPLETED'   
       WHEN @FLAG = 'E' THEN 'ERROR'   
   END   
   + '</strong></td>   
        </tr>   
        </table>   
        <table align="center" cellpadding="2" cellspacing="0" style="color:black; font-family:consolas; text-align:left;">   
        <tr>   
   <td style="color:black; font-family:consolas; text-align:center; font-size: 16pt;"><strong>REGLA PSAK71 STATISTIC</strong></td>   
        </tr>   
        </table>   
        <table border="1" align="center" cellpadding="2" cellspacing="0" style="color:black; font-family:consolas; text-align:left;">   
        <td><strong>DOWNLOAD DATE</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + CONVERT(VARCHAR(50), @V_CURRDATE, 106) + '</td>   
        </tr>   
        <tr>   
        <td><strong>PROCESS NAME</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + @V_PRCNAME + '</td>   
        </tr>  
        <tr>   
        <td><strong>START DATE</strong></td>   
        <td><strong> : </strong></td>   
        <td>' + CAST(CASE WHEN @FLAG = 'S' THEN GETDATE() ELSE @V_STARTDATE END AS VARCHAR(50)) + '</td>   
        </tr>  
        ' + CASE    
       WHEN @FLAG = 'S' THEN ''   
       WHEN @FLAG = 'C' OR @FLAG = 'E' THEN @TRCE   
   END   
    
    SELECT @MAIL_BODY = @MAIL_BODY + '</table>'   
    
    SELECT @FOOTER =    
    '<table align="left" cellpadding="2" cellspacing="0">   
        <tr>   
   <td style="color:black; font-family:consolas; text-align:left; font-size:10pt">REGARDS,</td>   
        </tr>   
        <tr>   
   <td></br></td>   
        </tr>   
        <tr>   
   <td></br></td>   
        </tr>   
        <tr>   
   <td style="color:black; font-family:consolas; text-align:left; font-size:10pt">REGLA IFRS9</td>   
        </tr>   
   <td style="color:black; font-family:consolas; text-align:left; font-size:8pt;"><hr>"E-Mail ini dan dokumen lampirannya ditujukan untuk digunakan oleh penerima e-mail. Bila anda bukan orang yang tepat untuk menerima e-mail ini segera hapus e-mail ini. I
si e-mail ini mungkin tidak mewakili pandangan dan/atau pendapat PT Bank BTPN Tbk, kecuali bila dinyatakan dengan jelas demikian. Informasi yang terdapat dalam e-mail ini dapat bersifat rahasia. Dilarang memperbanyak, menyebarkan dan menyalin informasi ra
hasia kepada pihak lain tanpa persetujuan Bank. Bank tidak bertanggungjawab atas kerusakan yang diakibatkan oleh e-mail ini jika terkena virus atau gangguan komunikasi."   
   </td>   
        </tr>   
        <tr><td></br></td></tr>   
        <tr>   
   <td style="color:black; font-family:consolas; text-align:left; font-size:8pt;">   
   “This e-mail and it’s attachment is intended for the use of the email receiver only. If you are not the intended recipient you should delete this e-mail immediately. The e-mail’s contain might be not represent vision and/or opinion of PT Bank BTPN Tbk,
 except if it is clearly declared as it is. The information of this e-mail may contain confidential information. Strictly prohibited to duplicate, propagate and make a copy or to other party without Bank’s approval. Bank will not responsible on any harmle
ss or disaster caused of this e-mail’s virus or communication error”<hr>   
   </td>  
   </tr>   
    </table>'   
    
    SELECT @MAIL_BODY = @MAIL_BODY + @FOOTER   
    
    SET @V_SUBJECT = 'REGLA PSAK71 ' + CASE @V_PRCNAME  
    WHEN 'IMP' THEN 'Impairment Monthly'   
    WHEN 'AMT' THEN 'Amortization Daily'   
    WHEN 'IMP_DAILY' THEN 'Impairment Daily'   
    WHEN 'STG' THEN 'Staging'          
    WHEN 'IMPCR' THEN 'Catch Up Run'   
    WHEN 'IMP-PRV' THEN 'Impairment Preview'   
END      
+ ' Process is ' +   
CASE    
    WHEN @FLAG = 'S' THEN 'Started'   
    WHEN @FLAG = 'C' THEN 'Completed'   
    WHEN @FLAG = 'E' THEN 'Error'   
END + ' [' + CONVERT(VARCHAR(50), @V_CURRDATE, 106) + ']'   
    
    DECLARE @Profile_Name Varchar(20)    
    DECLARE @Body_Format Varchar(20)    
    DECLARE @From Varchar(MAX)     
    DECLARE @To Varchar(50)    
    
    SELECT @Profile_Name = Value3     
    FROM TBLM_COMMONCODEDETAIL    
    WHERE COMMONCODE = 'MC001' AND VALUE1 = 'Profile_Name'   
  
    SELECT @Body_Format = Value3     
    FROM TBLM_COMMONCODEDETAIL    
    WHERE COMMONCODE = 'MC001' AND VALUE1 = 'Body_Format'   
  
    SELECT @From = Value3     
    FROM TBLM_COMMONCODEDETAIL    
    WHERE COMMONCODE = 'MC001' AND VALUE1 = 'From'   
    
    DECLARE SEG1    
    CURSOR FOR   
        SELECT Value3 AS [To]   
  FROM TBLM_COMMONCODEDETAIL  
        WHERE COMMONCODE = 'MC001' AND VALUE1 = 'To'       
    OPEN seg1;    
    FETCH seg1 INTO @To      
    WHILE @@FETCH_STATUS = 0   
    BEGIN    
        EXEC msdb.dbo.sp_send_dbmail   
   @profile_name = @Profile_Name,   
   @recipients = @To,   
   @subject = @V_SUBJECT,   
   @body = @MAIL_BODY,   
   @body_format = @Body_Format   
    
        FETCH NEXT FROM seg1 INTO @To     
    END       
    CLOSE seg1;    
    DEALLOCATE seg1;      
     
    
END  
  
GO
