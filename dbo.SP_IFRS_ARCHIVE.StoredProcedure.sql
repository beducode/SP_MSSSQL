USE [IFRS9]
GO
/****** Object:  StoredProcedure [dbo].[SP_IFRS_ARCHIVE]    Script Date: 14/06/2024 06:32:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SP_IFRS_ARCHIVE]    
@download_date date = null     
AS      
-- 20170120 daniel s : archive selected from param tables      
-- 20170125 daniel s : can archive to different db on same server and will populate all rows from src on new dest table      
-- set param on ifrs_archive_master table      
-- see log on ifrs_archive_log table      
      
IF OBJECT_ID('tempdb..#m') IS NOT NULL DROP TABLE #m      
      
create table #m      
(      
id int identity(1,1)      
, src varchar(60)      
, dest varchar(60)      
, cdate varchar(60)      
, ret int      
, destdb varchar(50)      
, EOM char(1)      
, srcdb varchar(50)      
)      
      
insert into #m(src,dest,cdate,ret,destdb,eom,srcdb)      
select TABLE_SRC,TABLE_DEST,COL_NAME_DATE,RETENTION_DAYS,SCHEMA_DEST,case EOM when 0 then 'N' else 'Y' end as EOM, SCHEMA_SRC      
from IFRS_ARCHIVE_MASTER    
where is_delete = 0    
      
declare @id int      
declare @max_id int      
declare @src varchar(60)      
declare @dest varchar(60)      
declare @destdb varchar(60)      
declare @srcdb varchar(60)      
declare @cdate varchar(60)      
declare @ret int      
declare @is_table_exist int      
declare @eom char(1)      
      
declare @x varchar(max)      
declare @qry nvarchar(max)      
declare @xid int      
declare @max_xid int      
      
declare @currdate date      
    
if @download_date is null    
begin    
    select @currdate=max(CURRDATE) from IFRS_PRC_DATE_AMORT     
end    
else    
begin    
    set @currdate = @download_date    
end     
      
declare @datelimit date    
declare @datelimitvarchar varchar(10)     
declare @is_identity int      
      
select @max_id=max(id) from #m      
set @id=1      
while @id<=@max_id      
begin      
 select @src=src,@dest=dest,@cdate=cdate,@ret=ret,@destdb=destdb, @eom=eom, @srcdb=srcdb from #m       
 where id=@id      
      
 if ISNULL(@destdb,'')='' set @destdb=@srcdb       
      
 --insert log start      
 delete from IFRS_ARCHIVE_LOG       
 where TABLE_SRC=@src       
  and TABLE_DEST=@dest       
  and COL_NAME_DATE=@cdate       
  and RETENTION_DAYS=@ret      
  and currdate=@currdate      
  and destdb=@destdb      
      
 insert into IFRS_ARCHIVE_LOG(TABLE_SRC,TABLE_DEST,COL_NAME_DATE,RETENTION_DAYS,START_DT,CURRDATE,destdb)      
 select @src,@dest,@cdate,@ret,CURRENT_TIMESTAMP,@currdate,@destdb      
      
 set @is_table_exist=1      
 truncate table ifrs_archive_cols      
      
 --create dest from src defn if not exist      
 --also create columnstore index      
 set @qry='use ' + @destdb + ' if object_id(''' + @dest + ''') is null '      
 set @qry= @qry+'begin select * into ' + @dest + ' from ' + @srcdb + '.dbo.' + @src + ' where 1<>1 '      
 set @qry= @qry+'insert into IFRS9..ifrs_archive_cols(cname) select ''not_exist'' '      
 set @qry= @qry+'create clustered columnstore index cci_' + replace(@dest,'.','') +' on ' + @dest + ' end'      
 select @qry      
 execute sp_executesql @qry      
      
 if exists(select * from IFRS_ARCHIVE_COLS) set @is_table_exist=0      
 select @is_table_exist      
      
 set @qry='truncate table IFRS9..ifrs_archive_cols '      
 set @qry+='use ' + @destdb + ' '      
 set @qry+='insert into IFRS9..ifrs_archive_cols(cname,is_identity) '      
 set @qry+='select name,is_identity from sys.all_columns where OBJECT_NAME(object_id)=''' + @dest + ''' '      
      
 --select @qry      
 execute sp_executesql @qry      
      
 select @is_identity=count(*) from ifrs_archive_cols where is_identity=1      
      
 set @x=''      
 set @xid=1      
 select @max_xid=max(id) from ifrs_archive_cols      
 while @xid<=@max_xid      
 begin      
  if len(@x)>0 set @x=@x+' ,'      
  select @x=@x+ '[' +cname+']' from ifrs_archive_cols where id=@xid      
  set @xid=@xid+1      
 end      
    
 set @datelimit=DATEADD(DD,-1 * abs(@ret),@currdate)     
 set @datelimitvarchar = @datelimit    
      
 --delete insert to dest from src by date      
 if @is_table_exist=1      
 begin      
  set @qry='use ' + @destdb + ' set identity_insert ' + @dest + ' on ;    
WHILE 1=1    
  BEGIN    
    WITH EventsTop AS     
 (SELECT TOP 10000 * FROM ' + @srcdb + '.dbo.' + @src + ' WHERE ' + @cdate + ' <= '''+@datelimitvarchar+''')    
 DELETE EventsTop OUTPUT DELETED.* INTO ' + @dest + '(' + @x + ')    
    
  --USE IFRS9; BACKUP LOG IFRS9 TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_LOG'');      
  --USE IFRS9_STG; BACKUP LOG IFRS9_STG TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_STG_LOG'');      
  --USE IFRS9_ACV; BACKUP LOG IFRS9_ACV TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_ACV_LOG'');       
     
    IF (@@ROWCOUNT = 0) BREAK;    
  END    
  set identity_insert ' + @dest + ' off ;'       
  if @is_identity=0     
  set @qry='use ' + @destdb + '    
  WHILE 1=1    
  BEGIN    
    WITH EventsTop AS     
 (SELECT TOP 10000 * FROM ' + @srcdb + '.dbo.' + @src + ' WHERE ' + @cdate + ' <= '''+@datelimitvarchar+''')    
 DELETE EventsTop OUTPUT DELETED.* INTO ' + @dest + '(' + @x + ')    
       
  --USE IFRS9; BACKUP LOG IFRS9 TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_LOG'');      
  --USE IFRS9_STG; BACKUP LOG IFRS9_STG TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_STG_LOG'');      
  --USE IFRS9_ACV; BACKUP LOG IFRS9_ACV TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_ACV_LOG'');      
     
    IF (@@ROWCOUNT = 0) BREAK;    
  END'       
  --print @qry    
  select @qry      
  execute sp_executesql @qry    
 end      
 else       
 begin      
  set @qry='use ' + @destdb + ' set identity_insert ' + @dest + ' on ;    
  WHILE 1=1    
  BEGIN    
    WITH EventsTop AS     
 (SELECT TOP 10000 * FROM ' + @srcdb + '.dbo.' + @src + ' WHERE ' + @cdate + ' <= '''+@datelimitvarchar+''')    
 DELETE EventsTop OUTPUT DELETED.* INTO ' + @dest + '(' + @x + ')    
    
  --USE IFRS9; BACKUP LOG IFRS9 TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_LOG'');      
  --USE IFRS9_STG; BACKUP LOG IFRS9_STG TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_STG_LOG'');      
  --USE IFRS9_ACV; BACKUP LOG IFRS9_ACV TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_ACV_LOG'');     
     
    IF (@@ROWCOUNT = 0) BREAK;    
  END    
  set identity_insert ' + @dest + ' off ;'       
  if @is_identity=0 set @qry='use ' + @destdb + '     
  WHILE 1=1    
  BEGIN    
    WITH EventsTop AS     
 (SELECT TOP 10000 * FROM ' + @srcdb + '.dbo.' + @src + ' WHERE ' + @cdate + ' <= '''+@datelimitvarchar+''')    
 DELETE EventsTop OUTPUT DELETED.* INTO ' + @dest + '(' + @x + ')    
    
  --USE IFRS9; BACKUP LOG IFRS9 TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_LOG'');      
  --USE IFRS9_STG; BACKUP LOG IFRS9_STG TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_STG_LOG'');      
  --USE IFRS9_ACV; BACKUP LOG IFRS9_ACV TO DISK = ''NUL''; DBCC SHRINKFILE (''IFRS9_ACV_LOG'');     
     
    IF (@@ROWCOUNT = 0) BREAK;    
  END'        
  select @qry      
  execute sp_executesql @qry     
 end      
      
 --insert log end      
 update IFRS_ARCHIVE_LOG       
 set end_dt=CURRENT_TIMESTAMP       
 where TABLE_SRC=@src       
  and TABLE_DEST=@dest       
  and COL_NAME_DATE=@cdate       
  and RETENTION_DAYS=@ret      
  and currdate=@currdate      
  and destdb=@destdb      
      
 set @id=@id+1         
        
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9'     
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_STG'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_STG'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_STG'      
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_ACV'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_ACV'    
 --exec [dbo].[SP_SHRINKLOG] 'IFRS9_ACV'    
 --EXEC ('USE TEMPDB; dbcc shrinkfile (''TEMPlog'', 0)')    
end      
      
IF OBJECT_ID('tempdb..#m') IS NOT NULL DROP TABLE #m     
GO
