USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_UPLOAD_VALIDATION]    Script Date: 14/06/2024 06:32:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[SP_IFRS_UPLOAD_VALIDATION]     
 @UploadId int    
AS    
-- EXEC SP_IFRS_UPLOAD_VALIDATION @UPLOADID = 87    
BEGIN    
    DECLARE @Result int    
    DECLARE @Message varchar(100)    
 DECLARE @UPLOADSTATUS VARCHAR(50)    
 DECLARE @UID INT    
    
    DECLARE @TBLU_DOC_TEMP_EXCEPTION TABLE (    
        UPLOAD_ID int,    
        ROWNUMBER int,    
        COLUMN_NAME varchar(255),    
        COLUMN_VALUE varchar(255),    
        ERRORMESSAGE varchar(255)    
    )    
    
    DECLARE @DESTINATION TABLE (    
        NO_URUT int,    
        COLUMN_DESTINATION varchar(100),    
        DATA_TYPE varchar(100),    
        MAX_LENGTH int,    
        IS_NULLABLE varchar(3)    
    )    
    
    DECLARE @SOURCE_HEADER TABLE (    
        NO_URUT int,    
        COLUMN_SOURCE varchar(100)    
    )    
    
    DECLARE @PK TABLE (    
        ORDINAL_POSITION int,    
        COLUMN_PK varchar(100),    
        COLUMN_DETAIL varchar(100)    
    )    
    
    DELETE FROM @TBLU_DOC_TEMP_EXCEPTION    
    DELETE FROM @DESTINATION    
    INSERT INTO @DESTINATION    
        SELECT    
            ORDINAL_POSITION NO_URUT,    
            COLUMN_NAME COLUMN_DESTINATION,    
            DATA_TYPE,    
            ISNULL(CHARACTER_MAXIMUM_LENGTH, 0) AS MAX_LENGTH,    
            IS_NULLABLE    
        FROM INFORMATION_SCHEMA.COLUMNS    
        WHERE TABLE_NAME = (SELECT    
            TABLEDESTINATION    
        FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)    
        WHERE PKID = (SELECT    
            MAPPINGID    
        FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
        WHERE UPLOADID = @UploadId))    
        AND COLUMN_NAME NOT IN ('UPLOADID', 'UPLOADBY', 'UPLOADDATE', 'UPLOADHOST', 'APPROVEDBY', 'APPROVEDDATE', 'APPROVEDHOST','CREATEDBY','CREATEDDATE','CREATEDHOST')  
		 
    
    DELETE FROM @SOURCE_HEADER    
    INSERT INTO @SOURCE_HEADER    
        SELECT    
            ROW_NUMBER() OVER (ORDER BY PKID) NO_URUT,    
            COLUMN_NAME COLUMN_SOURCE    
        FROM TBLU_DOC_TEMP_HEADER(NOLOCK)    
  WHERE UPLOADID = @UploadId   
  
    
    DELETE FROM @PK    
    INSERT INTO @PK    
        SELECT    
            ORDINAL_POSITION,    
            COLUMN_NAME,    
            'COLUMN_' + CONVERT(varchar(3), B.NO_URUT)    
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE A    
        LEFT JOIN @SOURCE_HEADER B    
            ON A.COLUMN_NAME = B.COLUMN_SOURCE    
        WHERE TABLE_NAME = (SELECT    
            TABLEDESTINATION    
        FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)    
        WHERE PKID = (SELECT    
            MAPPINGID    
        FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
        WHERE UPLOADID = @UploadId))    
        AND LEFT(CONSTRAINT_NAME, 2) = 'PK'    
        ORDER BY ORDINAL_POSITION ASC    
    
    IF OBJECT_ID('tempdb..#TEMP_DETAIL') IS NOT NULL    
    BEGIN    
        DROP TABLE #TEMP_DETAIL    
    END    
    SELECT    
        RANK() OVER (ORDER BY PKID ASC) AS NO_URUT,    
        * INTO #TEMP_DETAIL    
    FROM TBLU_DOC_TEMP_DETAIL(NOLOCK)    
    WHERE UPLOADID = @UploadId    
    
    --CHECK HEADER NAME BETWEEN SOURCE AND DESTINATION     
    IF EXISTS (SELECT    
            CHECK_HEADER    
        FROM (SELECT DISTINCT    
            CASE    
                WHEN COLUMN_SOURCE IS NULL OR    
                    COLUMN_DESTINATION IS NULL THEN 'NOT MATCH'    
                ELSE 'MATCH'    
            END CHECK_HEADER    
        FROM @DESTINATION A    
        FULL OUTER JOIN @SOURCE_HEADER B    
            ON A.COLUMN_DESTINATION = B.COLUMN_SOURCE    
            AND A.NO_URUT = B.NO_URUT) H    
        WHERE CHECK_HEADER = 'NOT MATCH')    
    BEGIN    
        SET @Result = 0    
        SET @Message = 'Column name or number of uploaded columns does not match.'    
        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ERRORMESSAGE)    
            SELECT    
                @UploadId,    
                @Message    
    END    
    ELSE    
    BEGIN    
    
        SET @Result = 1    
    
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
    
        DECLARE @CountResults TABLE (    
            CountReturned int    
        )    
    
        SET @Max = (SELECT    
            COUNT(1)    
        FROM TBLU_DOC_TEMP_HEADER(NOLOCK)    
        WHERE UPLOADID = @UploadId)    
    
        ---CHECK KEY HISTORY MUST BE ONE    
        DECLARE @keyHistory varchar(100),    
                @queryCountKey varchar(max),    
                @queryKey varchar(max),    
                @ColNumber varchar(3)    
            
  IF (SELECT MAPPINGTYPE    
   FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)    
   WHERE PKID = (SELECT    
    MAPPINGID    
   FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
   WHERE UPLOADID = @UploadId)    
   ) = 'DEL_INS' -- 'TRUNCATE_INSERT'    
        BEGIN    
   SET @keyHistory = (SELECT    
    KEYHISTORY    
   FROM TBLM_MAPPINGRULEHEADER_NEW(NOLOCK)    
   WHERE PKID = (SELECT    
    MAPPINGID    
   FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
   WHERE UPLOADID = @UploadId))    
   SET @ColNumber = (SELECT    
    NO_URUT    
   FROM @SOURCE_HEADER    
   WHERE COLUMN_SOURCE = @keyHistory)    
    
   SET @queryCountKey = 'SELECT COUNT(1) FROM (SELECT DISTINCT  COLUMN_' + @ColNumber + ' FROM #TEMP_DETAIL)A'    
   SET @Message = 'Column must be 1 same date for 1 file.'    
    
   DELETE FROM @CountResults    
   INSERT @CountResults EXEC (@querycountKey)    
   SET @Count = (SELECT    
    CountReturned    
   FROM @CountResults)    
  END    
    
        IF (@Count > 1)    
        BEGIN    
            SET @Result = 0    
            INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, COLUMN_NAME, ERRORMESSAGE)    
                SELECT    
                    @UploadId,    
                    @keyHistory,    
                    @Message    
        END    
        ELSE    
        BEGIN    
            SET @Result = 1    
            SET @Message = 'Successfully'    
    
            -- CHECK DATA TYPE AND NULL    
            -- START LOOP    
            WHILE (@Col <= @Max)    
            BEGIN    
                SET @ColType = (SELECT    
                    DATA_TYPE    
                FROM @DESTINATION    
                WHERE NO_URUT = @Col)    
                SET @ColMaxLen = (SELECT    
                    MAX_LENGTH    
                FROM @DESTINATION    
                WHERE NO_URUT = @Col)    
                SET @ColDesc = (SELECT    
                    COLUMN_SOURCE    
                FROM @SOURCE_HEADER    
                WHERE NO_URUT = @Col)    
                SET @ColNullStatus = (SELECT    
                    IS_NULLABLE    
                FROM @DESTINATION    
                WHERE NO_URUT = @Col)    
    
                SET @ColName = 'COLUMN_' + CONVERT(varchar(10), @Col)    
    
                IF (@ColNullStatus = 'NO')    
                BEGIN    
                    ---check data null or not    
                    SET @queryCountNull = 'SELECT TOP 1 1 from #TEMP_DETAIL WHERE (' + @ColName + ' IS NULL OR ' + @ColName + ' = '''')  ;'    
                    SET @Message = 'Column cannot be blank.'    
                    SET @queryCheckNull = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL WHERE (' + @ColName + ' IS NULL OR ' + @ColName + ' = '''');'    
    
                    DELETE FROM @CountResults    
                    INSERT @CountResults EXEC (@queryCountNull)    
                    IF EXISTS (SELECT    
                            CountReturned    
                        FROM @CountResults)    
                    BEGIN    
                        SET @Result = 0    
                        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                        EXEC (@queryCheckNull)    
                    END    
                    ELSE    
                    BEGIN    
                        SET @Result = 1    
                        SET @Message = 'Successfully'    
                        ---CHECK DATA TYPE    
                        IF (@ColType IN ('date', 'datetime', 'smalldatetime'))    
                        BEGIN    
                            SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL     
             WHERE (LEN(COLUMN_1) = 6  AND  isdate(' + @ColName + ' + ''01'') = 0) OR (LEN(COLUMN_1) <> 6 AND ISDATE(' + @ColName + ') = 0)'    
                            SET @Message = 'Error inserting text to data type date.'    
                            SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL     
             WHERE (LEN(COLUMN_1) = 6  AND  isdate(' + @ColName + ' + ''01'') = 0) OR (LEN(COLUMN_1) <> 6 AND ISDATE(' + @ColName + ') = 0)'    
                            DELETE FROM @CountResults    
                            INSERT @CountResults EXEC (@querycount)    
                            IF EXISTS (SELECT    
                                    CountReturned    
                                FROM @CountResults)    
                            BEGIN    
                                SET @Result = 0    
                                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                                EXEC (@query)    
                            END    
                            ELSE    
                            BEGIN    
                                SET @Result = 1    
                                SET @Message = 'Successfully'    
                            END    
                        --SELECT @ColType,@query,@Result, @Message    
                        END 
						ELSE    
                        IF (@ColDesc LIKE '%DOWNLOAD_DATE')  
                        BEGIN    
						print 'ok'
                            SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') <> 8' +  + ' ;'    
                            SET @Message = 'Download Date must be 8 digit.'    
                            SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') <> 8 ' +  + ' ;'    
                            DELETE FROM @CountResults    
                            INSERT @CountResults EXEC (@querycount)    
                            IF EXISTS (SELECT    
                                    CountReturned    
                                FROM @CountResults)    
                            BEGIN    
                                SET @Result = 0    
                                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                                EXEC (@query)    
                            END    
                            ELSE    
                            BEGIN    
                                SET @Result = 1    
                                SET @Message = 'Successfully'    
                            END    
                        --SELECT @ColType,@query,@Result, @Message    
                        END    
                        ELSE    
                        IF (@ColType LIKE '%char')    
                        BEGIN    
                            SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') > ' + CONVERT(varchar(5), @ColMaxLen) + ' ;'    
                            SET @Message = 'Text length is too long.'    
                            SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') > ' + CONVERT(varchar(5), @ColMaxLen) + ' ;'    
                            DELETE FROM @CountResults    
                            INSERT @CountResults EXEC (@querycount)    
                            IF EXISTS (SELECT    
                                    CountReturned    
                                FROM @CountResults)    
                            BEGIN    
                                SET @Result = 0    
                                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                                EXEC (@query)    
                            END    
                            ELSE    
                            BEGIN    
                                SET @Result = 1    
                                SET @Message = 'Successfully'    
                            END    
                        --SELECT @ColType,@query,@Result, @Message    
                        END    
                        ELSE    
                        IF (@ColType IN ('decimal', 'numeric', 'float', 'real', 'int', 'bigint', 'smallint', 'tinyint', 'money', 'smallmoney'))    
 BEGIN    
                            SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL WHERE ISNUMERIC(' + @ColName + ') = 0;'    
                            SET @Message = 'Error inserting text to data type numeric.'    
                            SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL WHERE ISNUMERIC(' + @ColName + ') = 0;'    
                            DELETE FROM @CountResults    
                            INSERT @CountResults EXEC (@querycount)    
                            IF EXISTS (SELECT    
                         CountReturned    
                                FROM @CountResults)    
                            BEGIN    
                                SET @Result = 0    
                                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                                EXEC (@query)    
                            END    
                            ELSE    
                            BEGIN    
                                SET @Result = 1    
                                SET @Message = 'Successfully'    
                            END    
                        --SELECT @ColType,@query,@Result, @Message    
                        END    
                    END    
                END    
                ELSE    
                ---CHECK DATA TYPE    
                IF (@ColType IN ('date', 'datetime', 'smalldatetime'))    
                BEGIN    
                    SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL     
          WHERE (LEN(COLUMN_1) = 6  AND  isdate(' + @ColName + ' + ''01'') = 0) OR (LEN(COLUMN_1) <> 6 AND ISDATE(' + @ColName + ') = 0)'    
                    SET @Message = 'Error inserting text to data type date.'    
                    SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL     
          WHERE (LEN(COLUMN_1) = 6  AND  isdate(' + @ColName + ' + ''01'') = 0) OR (LEN(COLUMN_1) <> 6 AND ISDATE(' + @ColName + ') = 0)'    
                    DELETE FROM @CountResults    
                    INSERT @CountResults EXEC (@querycount)    
                    IF EXISTS (SELECT    
                            CountReturned    
                        FROM @CountResults)    
                    BEGIN    
                        SET @Result = 0    
                        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                        EXEC (@query)    
                    END    
                    ELSE    
                    BEGIN    
                        SET @Result = 1    
                        SET @Message = 'Successfully'    
                    END    
                --SELECT @ColType,@query,@Result, @Message    
                END    
				ELSE    
                        IF (@ColDesc LIKE '%DOWNLOAD_DATE')  
                        BEGIN    
						print 'ok2'
                            SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') <> 8 ' +  + ' ;'    
                            SET @Message = 'Download Date must be 8 digit.'    
                            SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') <> 8 ' + + ' ;'    
                            DELETE FROM @CountResults    
                            INSERT @CountResults EXEC (@querycount)    
                            IF EXISTS (SELECT    
                                    CountReturned    
                                FROM @CountResults)    
                            BEGIN    
                                SET @Result = 0    
                                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                                EXEC (@query)    
                            END   
							end
                ELSE    
                IF (@ColType LIKE '%char')    
                BEGIN    
                    SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') > ' + CONVERT(varchar(5), @ColMaxLen) + ' ;'    
                    SET @Message = 'Text length is too long.'    
                    SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL (NOLOCK) WHERE LEN(' + @ColName + ') > ' + CONVERT(varchar(5), @ColMaxLen) + ' ;'    
                    DELETE FROM @CountResults    
                    INSERT @CountResults EXEC (@querycount)    
                    IF EXISTS (SELECT    
                            CountReturned    
                        FROM @CountResults)    
                    BEGIN    
                        SET @Result = 0    
                        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                        EXEC (@query)    
                    END    
                    ELSE    
                    BEGIN    
                  SET @Result = 1    
                        SET @Message = 'Successfully'    
                    END    
                --SELECT @ColType,@query,@Result, @Message    
                END    
                ELSE    
                IF (@ColType IN ('decimal', 'numeric', 'float', 'real', 'int', 'bigint', 'smallint', 'tinyint', 'money', 'smallmoney'))    
                BEGIN    
                    SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL WHERE ISNUMERIC(' + @ColName + ') = 0;'    
                    SET @Message = 'Error inserting text to data type numeric.'    
                    SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL WHERE ISNUMERIC(' + @ColName + ') = 0;'    
                    DELETE FROM @CountResults    
                    INSERT @CountResults EXEC (@querycount)    
                    IF EXISTS (SELECT    
                            CountReturned    
                        FROM @CountResults)    
                    BEGIN    
                        SET @Result = 0    
                        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                        EXEC (@query)    
                    END    
                    ELSE    
                    BEGIN    
                        SET @Result = 1    
                        SET @Message = 'Successfully'    
                    END    
                --SELECT @ColType,@query,@Result, @Message    
                END    
    ELSE    
    IF (@ColType = 'BIT')    
                BEGIN    
                    SET @querycount = 'SELECT TOP 1 1 from #TEMP_DETAIL WHERE ' + @ColName + ' NOT IN (0,1);'    
                    SET @Message = 'Error inserting Data Bit, Must 1 or 0.'    
                    SET @query = 'SELECT UPLOADID,NO_URUT,''' + @ColDesc + ''',' + @ColName + ',''' + @Message + ''' from #TEMP_DETAIL WHERE ' + @ColName + ' NOT IN(0,1);'    
                    DELETE FROM @CountResults    
                    INSERT @CountResults EXEC (@querycount)    
                    IF EXISTS (SELECT    
                            CountReturned    
                        FROM @CountResults)    
                    BEGIN    
                        SET @Result = 0    
                        INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                        EXEC (@query)    
                    END    
                    ELSE    
                    BEGIN    
                        SET @Result = 1    
                        SET @Message = 'Successfully'    
                    END    
    
    END    
                SET @Col = @Col + 1    
            END    
            -- END LOOP    
    
            -- CHECK DUPLICATE     
            DECLARE @colPK varchar(max),    
                    @queryPK varchar(max),    
                    @queryCountPK varchar(max),    
                    @ColPKDesc varchar(max)    
            SET @colPK = STUFF((SELECT    
                ',' + QUOTENAME(COLUMN_DETAIL)    
            FROM @PK    
            ORDER BY ORDINAL_POSITION ASC    
            FOR xml PATH (''))    
            , 1, 1, '')    
    
            SET @ColPKDesc = STUFF((SELECT    
                ',' + COLUMN_PK    
            FROM @PK    
            ORDER BY ORDINAL_POSITION ASC    
            FOR xml PATH (''))    
            , 1, 1, '')    
    
            SET @queryPK =    
            'SELECT A.UPLOADID, A.NO_URUT, ''' + @ColPKDesc + ''',B.DUP_COL_VALUE, ''Duplicate Data'' FROM #TEMP_DETAIL A    
    INNER JOIN     
    (SELECT CONCAT(' + REPLACE(@colPK, ',', ','','',') + ') AS DUP_COL_VALUE     
     FROM  #TEMP_DETAIL GROUP BY ' + @colPK + ' HAVING COUNT(*) > 1'    
            + ' )B  ON  CONCAT(' + REPLACE(REPLACE(@colPK, ',', ','','','), '[', 'A.[') + ') = B.DUP_COL_VALUE'    
            + ' ORDER BY' + @colPK + ',A.NO_URUT '    
            SET @queryCountPK =    
            'SELECT COUNT(1) FROM ( SELECT ' + @colPK + '     
     FROM  #TEMP_DETAIL GROUP BY ' + @colPK + ' HAVING COUNT(*) > 1 ) A'    
    
            DELETE FROM @CountResults    
            INSERT @CountResults EXEC (@queryCountPK)    
            SET @Count = (SELECT    
                CountReturned    
            FROM @CountResults)    
            IF (@Count > 0)    
            BEGIN    
                SET @Result = 0    
                INSERT INTO @TBLU_DOC_TEMP_EXCEPTION (UPLOAD_ID, ROWNUMBER, COLUMN_NAME, COLUMN_VALUE, ERRORMESSAGE)    
                EXEC (@queryPK)    
            END    
            ELSE    
            BEGIN    
                SET @Result = 1    
                SET @Message = 'Successfully'    
            END    
        END    
    END    
     
    --UPDATE VALIDATION STATUS    
    
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
    
	--bikin lama btpn
  --EXEC SP_IFRS_UPLOAD_VALIDATION_PD_EXTERNAL @UPLOADID,@UPLOADSTATUS OUTPUT    
    
        --check Flag approval    
    
        DECLARE @flagApproval int    
        SET @flagApproval = (SELECT    
            NEEDAPPROVAL    
        FROM [dbo].[TBLM_MAPPINGRULEHEADER_NEW](NOLOCK)    
        WHERE PKID = (SELECT    
            MAPPINGID    
        FROM [dbo].[TBLT_UPLOAD_POOL](NOLOCK)    
        WHERE UPLOADID = @UPLOADID))    
    
        IF @flagApproval = 0    
        BEGIN    
            EXEC [dbo].[SP_IFRS_UPLOAD_APPROVAL] @uploadId,    
                                                 'SYSTEM',    
                                                 'SYSTEM'    
        END    
        ELSE    
        IF @flagApproval = 1    
        BEGIN    
    IF (@UPLOADSTATUS = 'VALIDATION FAILED')    
  BEGIN    
   UPDATE TBLT_UPLOAD_POOL    
   SET STATUS = 'VALIDATION FAILED'    
   WHERE UPLOADID = @UPLOADID    
  END    
  ELSE    
            UPDATE TBLT_UPLOAD_POOL    
            SET STATUS = 'PENDING'    
            WHERE UPLOADID = @UploadId    
    
        END    
    END    
END




GO
