USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_UPLOAD_APPROVAL]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_IFRS_UPLOAD_APPROVAL]       
(      
 @uploadId int      
 , @CreatedBy varchar(36)     
 , @CreatedHost varchar(30)  
)      
AS      
BEGIN      
      
    DECLARE @approvedBy varchar(36) = @CreatedBy;      
    DECLARE @approvedHost varchar(30) = @CreatedHost;      
    DECLARE @approvedDate datetime = GETDATE()      
      
    DECLARE @tableName varchar(50),      
            @colNumber varchar(max),      
            @colDesc varchar(max),      
            @colMaxLen varchar(max),      
            @colSource varchar(max),      
            @query varchar(max),      
            @queryCheckUploadId varchar(max),      
            @queryDelete varchar(max),      
            @queryMaxLen varchar(max),      
            @queryTruncate varchar(max)      
      
      
    DECLARE @SOURCE_HEADER TABLE (      
        NO_URUT int,      
        COLUMN_NAME varchar(100),      
        COLUMN_ALIAS varchar(100),      
        DATA_TYPE_DESTINATION varchar(100),      
        MAXLEN int      
    )      
      
    DECLARE @MAXLEN TABLE (      
        COLUMN_NAME varchar(100),      
        MAXLEN int      
    )      
      
    IF OBJECT_ID('tempdb..#TEMP_DETAIL') IS NOT NULL      
    BEGIN      
        DROP TABLE #TEMP_DETAIL      
    END      
    SELECT      
        RANK() OVER (ORDER BY PKID ASC) AS NO_URUT,      
        * INTO #TEMP_DETAIL      
    FROM TBLU_DOC_TEMP_DETAIL(NOLOCK)      
    WHERE UPLOADID = @uploadId      
      
    SET @tableName = (SELECT      
        TABLEDESTINATION      
    FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)      
    WHERE PKID = (SELECT      
        MAPPINGID      
    FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)      
    WHERE UPLOADID = @uploadId))      
 
    DELETE FROM @SOURCE_HEADER      
    INSERT INTO @SOURCE_HEADER (NO_URUT, COLUMN_NAME, COLUMN_ALIAS, DATA_TYPE_DESTINATION)      
        SELECT      
            ROW_NUMBER() OVER (ORDER BY PKID) NO_URUT,      
            A.COLUMN_NAME,      
            'COLUMN_' + CONVERT(varchar(10), ROW_NUMBER() OVER (ORDER BY PKID)) AS COlUMN_ALIAS,      
            B.DATA_TYPE      
        FROM TBLU_DOC_TEMP_HEADER(NOLOCK) A      
        LEFT JOIN (SELECT      
            COLUMN_NAME,      
            DATA_TYPE      
        FROM INFORMATION_SCHEMA.COLUMNS      
        WHERE TABLE_NAME = @tableName) B      
            ON A.COLUMN_NAME = B.COLUMN_NAME      
        WHERE UPLOADID = @uploadId 
		
		SELECT * FROM @SOURCE_HEADER     
      
    SET @colMaxLen = STUFF((SELECT      
        ',' + ('MAX(LEN(' + QUOTENAME(COLUMN_ALIAS) + ')) AS ' + QUOTENAME(COLUMN_ALIAS))      
    FROM @SOURCE_HEADER      
    ORDER BY NO_URUT ASC      
    FOR xml PATH (''))      
    , 1, 1, '')      
    SET @colNumber = STUFF((SELECT      
        ',' + COLUMN_ALIAS      
    FROM @SOURCE_HEADER      
    ORDER BY NO_URUT ASC      
    FOR xml PATH (''))      
    , 1, 1, '')      
    SET @queryMaxLen =      
    'SELECT  COLUMN_NAME,MAXLEN from (      
    SELECT ' + @colMaxLen + '      
    FROM  #TEMP_DETAIL ) a      
   UNPIVOT      
   (MAXLEN FOR COLUMN_NAME IN (' + @colNumber + ')      
   ) AS b'      
      
    DELETE FROM @MAXLEN      
    INSERT INTO @MAXLEN      
    EXEC (@queryMaxLen)      
      
    UPDATE C      
    SET MAXLEN = D.MAXLEN      
    FROM @SOURCE_HEADER C      
    INNER JOIN @MAXLEN D      
        ON C.COLUMN_ALIAS = D.COLUMN_NAME      
      
    SET @colSource = STUFF((SELECT      
        ',' + CASE      
            WHEN (DATA_TYPE_DESTINATION = 'date' AND      
                MAXLEN = 6) THEN 'EOMONTH(' + COLUMN_ALIAS + ' + ''01'') AS ' + COLUMN_ALIAS      
            ELSE COLUMN_ALIAS      
        END      
    FROM @SOURCE_HEADER      
    ORDER BY NO_URUT ASC      
    FOR xml PATH (''))      
    , 1, 1, '')      
    SET @colDesc = STUFF((SELECT      
        ',' + COLUMN_NAME      
    FROM @SOURCE_HEADER      
    ORDER BY NO_URUT ASC      
    FOR xml PATH (''))      
    , 1, 1, '')      
      
    SET @query = 'INSERT INTO ' + @tableName + ' (' + @colDesc + ',CREATEDBY,CREATEDDATE,CREATEDHOST)' +      
    'SELECT ' + @colSource + ',B.[CREATEDBY],B.[CREATEDDATE],B.[CREATEDHOST]'      
    --+ ISNULL(@approvedBy, 'NULL') + ''',''' + ISNULL(CONVERT(varchar(50), @approvedDate, 121), 'NULL') + ''',''' + ISNULL(@approvedHost, 'NULL') 
	+ '      
   FROM #TEMP_DETAIL A      
   INNER JOIN [dbo].[TBLT_UPLOAD_POOL] (NOLOCK) B ON A.UPLOADID = B.UPLOADID      
   ORDER BY NO_URUT ASC'      
 
    DECLARE @keyHistory varchar(100),      
            @queryKeyHistory varchar(max),      
            @keyHistoryValue varchar(max),      
            @keyHistoryAlias varchar(max)      
    SET @keyHistory = (SELECT      
        KEYHISTORY      
    FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)      
    WHERE PKID = (SELECT      
        MAPPINGID      
    FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)      
    WHERE UPLOADID = @UploadId))      
  
 --SELECT * INTO ##TEST3   
 --FROM @SOURCE_HEADER WHERE COLUMN_NAME = @keyHistory  
  
    SET @KeyHistoryAlias = (SELECT      
        CASE      
            WHEN (DATA_TYPE_DESTINATION = 'date' AND      
                MAXLEN = 6) THEN 'EOMONTH(' + COLUMN_ALIAS + ' + ''01'') AS ' + COLUMN_ALIAS      
            ELSE COLUMN_ALIAS      
        END      
    FROM @SOURCE_HEADER      
    WHERE COLUMN_NAME = @keyHistory)      
      
    SET @queryKeyHistory = 'select distinct ' + @keyHistoryAlias + ' from #TEMP_DETAIL'      
      
    DECLARE @tableKey TABLE (      
        ColumnReturned varchar(100)      
    )      
    DELETE FROM @tableKey      
    INSERT @tableKey      
    EXEC (@queryKeyHistory)      
    SET @keyHistoryValue = (SELECT      
        ColumnReturned      
    FROM @tableKey)      
      
    SET @queryCheckUploadId = 'SELECT TOP 1 1 FROM ' + @tableName + ' WHERE ' + @keyHistory + ' = ''' + @KeyHistoryValue + ''''      
    SET @queryDelete = 'DELETE FROM ' + @tableName + +' WHERE ' + @keyHistory + ' = ''' + @KeyHistoryValue + ''''      
    SET @queryTruncate = 'TRUNCATE TABLE ' + @tableName      
      
    DECLARE @tableResults TABLE (      
        ColumnReturned int      
    )      
    DELETE FROM @tableResults      
    INSERT @tableResults      
    EXEC (@queryCheckUploadId)      
      
    DECLARE @mappingType varchar(100)      
      
    SET @mappingType = (SELECT      
        MAPPINGTYPE      
    FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)      
    WHERE PKID = (SELECT      
        MAPPINGID      
    FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)      
    WHERE UPLOADID = @UploadId))      
      
    IF @mappingType = 'DEL_INS'      
    BEGIN      
        IF EXISTS (SELECT      
                ColumnReturned      
            FROM @tableResults)      
        BEGIN      
            EXEC (@queryDelete)      
            EXEC (@query)      
        END      
        ELSE      
        BEGIN      
            EXEC (@query)      
        END      
    END      
    ELSE      
    IF @mappingType = 'TRUNCATE_INSERT'      
    BEGIN      
        EXEC (@queryTruncate)      
        EXEC (@query)      
    END      
    ELSE      
    BEGIN      
        EXEC (@queryTruncate)      
        EXEC (@query)      
    END      
      
    UPDATE TBLT_UPLOAD_POOL      
    SET STATUS = 'APPROVED',  
  APPROVEDBY = @CreatedBy,  
  APPROVEDDATE = getdate()      
    WHERE UPLOADID = @UploadId      
      
END  


GO
