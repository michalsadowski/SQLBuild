-- Enable Database Mail for this instance
EXECUTE sp_configure 'show advanced', 1;
RECONFIGURE;
EXECUTE sp_configure 'remote admin connections',1;
RECONFIGURE;
EXECUTE sp_configure 'Database Mail XPs',1;
RECONFIGURE;
GO
 
DECLARE @strEmailAddress varchar (50)
SET @strEmailAddress = (REPLACE((SELECT @@servername),'\','_')) +'@aon.net'

DECLARE @servername varchar(max)
SET @servername = (REPLACE((SELECT @@servername),'\','_'))

-- Create a Database Mail account

EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = @servername,
    @description = 'Account used by all mail profiles.',
    @email_address = @strEmailAddress ,
    @replyto_address = @strEmailAddress,
    @display_name = @servername,
    @mailserver_name = 'smtp.yourdomain.local';
	
	
-- Create a Database Mail profile
EXECUTE msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'Default Public Profile',
    @description = 'Default public profile for all users';
 
-- Add the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'Default Public Profile',
    @account_name = @@SERVERNAME,
    @sequence_number = 1;
 
-- Grant access to the profile to all msdb database users
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
    @profile_name = 'Default Public Profile',
    @principal_name = 'public',
    @is_default = 1;
GO
 
--send a test email
--EXECUTE msdb.dbo.sp_send_dbmail @subject = 'Test Database Mail Message',   @recipients = 'a82254@aonhewitt.com',   @query = 'SELECT @@SERVERNAME';
--GO


-- Monitoring setup: STEP #2
-- configure alert operator.sql
USE [msdb]
GO

BEGIN
EXEC msdb.dbo.sp_add_operator @name=N'SQL DBAs', 
		@enabled=1, 
		@email_address=N'DBA@smtp.yourdomain.local'
END

GO

USE tempdb
SET NOCOUNT ON
GO
---------------------------------------------------------------------------------------------------
--Code below creates a wrapper procedure, which in turns creates the alerts
--------------------------------------------------------------------------------------------------- 
IF OBJECT_ID('tempdb..create_alert_notification') IS NOT NULL DROP PROC create_alert_notification
GO

CREATE PROC create_alert_notification
@msgid int, @sev int
AS
-------------------------------------------------------------------------------------------
--This procedure create alert and operator notification
--It is a wrapper around sp_add_alert and sp_add_notification
--Paramaters:
-- @msgid error number to define alert for. Specify 0 if for severity level.
-- @sev severity level to define alert for. Specify 0 if for error number.
--One of above must be 0 and the other must be > 0

--IMPORTANT: Walk the code and replace ward-wired values.
--Operator name is obvious, but also check other relevant parameter. Adjust to suit you!
--------------------------------------------------------------------------------------------
DECLARE @alert_name sysname, @ret int
--Not both @msgid and @sev can be <> 0
IF @msgid <> 0 AND @sev <> 0
BEGIN
RAISERROR('Cannot have both error number and severity <> 0.', 16, 0)
RETURN -101
END

SET @alert_name =
CASE
WHEN @sev = 0 THEN 'Error ' + (RIGHT('00000' + CAST(@msgid AS varchar(20)),5))
ELSE 'Severity level ' + CAST(@sev AS varchar(20))
END

BEGIN TRY
EXEC @ret = msdb.dbo.sp_add_alert
@name = @alert_name
,@message_id = @msgid
,@severity = @sev
,@delay_between_responses = 600 --10 minutes
,@include_event_description_in = 1 --Email

EXEC msdb.dbo.sp_add_notification
@alert_name = @alert_name
,@operator_name=N'SQL DBAs' -- NOTE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
,@notification_method = 1
END TRY

BEGIN CATCH
DECLARE @err_str VARCHAR(2000), @err_sev tinyint, @err_state tinyint, @err_proc VARCHAR(200)
SET @err_str = ERROR_MESSAGE() + ' Error rooted in procdure "' + ERROR_PROCEDURE() + '".'
SET @err_sev = ERROR_SEVERITY()
SET @err_state = ERROR_STATE()
RAISERROR(@err_str, @err_sev, @err_state)
END CATCH
/*
--Test execution
EXEC create_alert_notification @msgid = 1105, @sev = 0
EXEC create_alert_notification @msgid = 0, @sev = 18
EXEC create_alert_notification @msgid = 55000, @sev = 0
EXEC create_alert_notification @msgid = 55000, @sev = 18
*/
GO

---------------------------------------------------------------------------------------------------
--Code below defines SQL Server Agent alerts, don't use it if you don't understand the code.
---------------------------------------------------------------------------------------------------
--Severity level 16 and higher, all errors in each level
EXEC create_alert_notification @msgid = 0, @sev = 16
EXEC create_alert_notification @msgid = 0, @sev = 17
EXEC create_alert_notification @msgid = 0, @sev = 18
EXEC create_alert_notification @msgid = 0, @sev = 19
EXEC create_alert_notification @msgid = 0, @sev = 20
EXEC create_alert_notification @msgid = 0, @sev = 21
EXEC create_alert_notification @msgid = 0, @sev = 22
EXEC create_alert_notification @msgid = 0, @sev = 23
EXEC create_alert_notification @msgid = 0, @sev = 24
EXEC create_alert_notification @msgid = 0, @sev = 25

--Level 14, selected errors
EXEC create_alert_notification @msgid = 18401, @sev = 0

--Level 13, selected errors
EXEC sp_altermessage @message_id = 1205, @parameter = 'WITH_LOG', @parameter_value = 'true'
EXEC create_alert_notification @msgid = 1205, @sev = 0

--Level 12, selected errors
EXEC sp_altermessage @message_id = 601, @parameter = 'WITH_LOG', @parameter_value = 'true'
EXEC create_alert_notification @msgid = 601, @sev = 0

--Level 10, selected errors
IF OBJECT_ID('tempdb..#alerts_to_include') IS NOT NULL DROP TABLE #alerts_to_include
GO
CREATE TABLE #alerts_to_include
(message_id int PRIMARY KEY, short_msg varchar(90), already_defined bit DEFAULT 0)

INSERT INTO #alerts_to_include(message_id, short_msg)
          SELECT 674, 'Exception occurred in destructor of RowsetNewSS 0x%p...'
UNION ALL SELECT 708, 'Server is running low on virtual address space or machine is running low on virtual...'
UNION ALL SELECT 806, 'audit failure (a page read from disk failed to pass basic integrity checks)...'
UNION ALL SELECT 825, 'A read of the file %ls at offset %#016I64x succeeded after failing %d time(s) wi..'
UNION ALL SELECT 973, 'Database %ls was started . However, FILESTREAM is not compatible with the READ_COM...'
UNION ALL SELECT 3401, 'Errors occurred during recovery while rolling back a transaction...'
UNION ALL SELECT 3410, 'Data in filegroup %s is offline, and deferred transactions exist...'
UNION ALL SELECT 3414, 'An error occurred during recovery, preventing the database %.*ls (database ID %d)...'
UNION ALL SELECT 3422, 'Database %ls was shutdown due to error %d in routine %hs.'
UNION ALL SELECT 3452, 'Recovery of database %.*ls (%d) detected possible identity value inconsistency...'
UNION ALL SELECT 3619, 'Could not write a checkpoint record in database ID %d because the log is out..'
UNION ALL SELECT 3620, 'Automatic checkpointing is disabled in database %.*ls because the log is out..'
UNION ALL SELECT 3959, 'Version store is full. New version(s) could not be added.'
UNION ALL SELECT 5029, 'Warning: The log for database %.*ls has been rebuilt.'
UNION ALL SELECT 5144, 'Autogrow of file %.*ls in database %.*ls was cancelled by user or timed out...'
UNION ALL SELECT 5145, 'Autogrow of file %.*ls in database %.*ls took %d milliseconds.'
UNION ALL SELECT 5182, 'New log file %.*ls was created.'
UNION ALL SELECT 8539, 'The distributed transaction with UOW %ls was forced to commit...'
UNION ALL SELECT 8540, 'The distributed transaction with UOW %ls was forced to rollback. '
UNION ALL SELECT 9001, 'The log for database %.*ls is not available.'
UNION ALL SELECT 14157, 'The subscription created by Subscriber %s to publication %s has expired...'
UNION ALL SELECT 14161, 'The threshold [%s:%s] for the publication [%s] has been set.'
UNION ALL SELECT 17173, 'Ignoring trace flag %d specified during startup'
UNION ALL SELECT 17179, 'Could not use Address Windowing Extensions because the lock pages in mem...'
UNION ALL SELECT 17883, 'Process %ld:%ld:%ld (0x%lx) Worker 0x%p appears to be non-yielding on Scheduler...'
UNION ALL SELECT 17884, 'New queries assigned to process on Node %d have not been picked up by a worker...'
UNION ALL SELECT 17887, 'IO Completion Listener (0x%lx) Worker 0x%p appears to be non-yielding...'
UNION ALL SELECT 17888, 'All schedulers on Node %d appear deadlocked due to a large number of...'
UNION ALL SELECT 17890, 'A significant part of sql server process memory has been paged out...'
UNION ALL SELECT 17891, 'Resource Monitor (0x%lx) Worker 0x%p appears to be non-yielding on Node %ld...'
UNION ALL SELECT 20572, 'Subscriber %s subscription to article %s in publication %s has been reinitiali...'
UNION ALL SELECT 20574, 'Subscriber %s subscription to article %s in publication %s failed...'

DECLARE c CURSOR FOR
   SELECT CAST(message_id AS varchar(10))
   FROM sys.messages
   WHERE message_id IN (SELECT message_id FROM #alerts_to_include)
     AND language_id = 1033
DECLARE @msg varchar(10), @sql varchar(2000)
OPEN c
WHILE 1 = 1
BEGIN
FETCH NEXT FROM c INTO @msg
IF @@FETCH_STATUS <> 0
   BREAK
SET @sql = 'EXEC create_alert_notification @msgid = ' + @msg + ', @sev = 0' 
EXEC(@sql)
END
CLOSE c
DEALLOCATE c
GO

---------------------------------------------------------------------------------------------------
-- Disable some Alerts
---------------------------------------------------------------------------------------------------
DECLARE @name sysname, @sql varchar(2000)
DECLARE @alerts_to_disable AS TABLE (name sysname PRIMARY KEY)
-------------------------------------
--- Insert all alerts do disable here
INSERT INTO @alerts_to_disable (name) values ('Severity level 16'),('Severity level 17'),('Severity level 18'),('Severity level 19')
-------------------------------------
-- Do not change code below
DECLARE atdc CURSOR FOR
	SELECT sa.name as name
	FROM @alerts_to_disable atd INNER JOIN msdb.dbo.sysalerts sa on sa.name = atd.name
OPEN atdc
	WHILE 1 = 1
	BEGIN
		FETCH NEXT FROM atdc INTO @name
		IF @@FETCH_STATUS <> 0 BREAK
		SET @sql = 'EXEC msdb.dbo.sp_update_alert @name=N'''+@name+''', @enabled=0'
		EXEC(@sql)
	END
CLOSE atdc
DEALLOCATE atdc
GO


-- STEP #4 Configure the tables/stored procedures used for Disk Space monitoring:
--Server disk info _create table and stored procedures_2005 and 2008.sql
USE [master]
GO

sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
sp_configure 'Ole Automation Procedures', 1
GO
RECONFIGURE
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Server_DiskInfo]') AND type in (N'U'))
DROP TABLE [dbo].[Server_DiskInfo]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[Server_DiskInfo](
	[Server_Name] [varchar](100) NULL,
	[Instance_Name] [varchar](100) NULL,
	[Serv_Date] [varchar](25) NULL,
	[Drive_Ltr] [char](1) NULL,
	[Free_MB] [int] NULL,
	[Total_MB] [int] NULL,
	[Free_Percent] [decimal](18, 2) NULL,
	[SpacebySQL_MB] [int] NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetSrvDiskInfo]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[sp_GetSrvDiskInfo]
GO

CREATE PROCEDURE [dbo].[sp_GetSrvDiskInfo]
AS
SET NOCOUNT ON
DELETE FROM master.dbo.Server_DiskInfo where Serv_Date <= GETDATE()

CREATE TABLE #tmpSqlSpace (DBName Varchar(25),Location Varchar(60),Size Varchar(8),Device Varchar(30))
Exec sp_MSforeachdb 'Use [?] Insert into #tmpSqlSpace Select Convert(Varchar(25),DB_Name())''Database'',
Convert(Varchar(60),filename),Convert(Varchar(8),size/128)''Size in MB'',Convert(Varchar(30),Name) from sysfiles'

DECLARE @ServName VARCHAR(100), @InstName VARCHAR(100), @ServDate datetime

SELECT @ServName = RTRIM(CONVERT(char(30), SERVERPROPERTY('MachineName')))
SELECT @InstName = RTRIM(CONVERT(char(40), SERVERPROPERTY('ServerName'))) 

SELECT @ServDate = GetDate()

DECLARE @hr int, @fso int, @drive char(1), @odrive int, @TotalSize varchar(20) 
DECLARE @MB bigint ; SET @MB = 1048576

CREATE TABLE #drives (
drive char(1) PRIMARY KEY,
FreeSpace int NULL,
TotalSize int NULL,
SQLDriveSize int NULL)

INSERT #drives(drive,FreeSpace) EXEC master.dbo.xp_fixeddrives

EXEC @hr=sp_OACreate 'Scripting.FileSystemObject',@fso OUT,1

IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso

DECLARE @SQLDrvSize int  

DECLARE dcur CURSOR LOCAL FAST_FORWARD
FOR SELECT drive from #drives
ORDER by drive

OPEN dcur
FETCH NEXT FROM dcur INTO @drive
WHILE @@FETCH_STATUS=0
BEGIN

Select @SQLDrvSize=sum(Convert(Int,Size)) from #tmpSqlSpace where Substring(Location,1,1)=@drive
Select @TotalSize=0

EXEC @hr = sp_OAMethod @fso,'GetDrive', @odrive OUT, @drive
IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso
EXEC @hr = sp_OAGetProperty @odrive,'TotalSize', @TotalSize OUT

IF @hr <> 0 EXEC sp_OAGetErrorInfo @odrive
UPDATE #drives  SET SQLDriveSize=@SQLDrvSize, TotalSize=@TotalSize/@MB  WHERE drive=@drive  

FETCH NEXT FROM dcur INTO @drive
END

CLOSE dcur
DEALLOCATE dcur

EXEC @hr=sp_OADestroy @fso
IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso

insert into master.dbo.Server_DiskInfo (Server_Name, Instance_Name, Serv_Date, Drive_Ltr, Free_MB,Total_MB, Free_Percent, SpacebySQL_MB) 

SELECT rtrim(CONVERT(char(30), SERVERPROPERTY('MachineName'))), RTRIM(CONVERT(char(40), SERVERPROPERTY('ServerName'))) , CAST(@ServDate AS nvarchar(30)), drive,
FreeSpace as 'Free(MB)', TotalSize as 'Total(MB)', CAST((FreeSpace/(TotalSize*1.0))*100.0 as int) as 'Free(%)', SQLDriveSize FROM #drives ORDER BY drive

DROP TABLE #drives
DROP table #tmpSqlSpace
GO

-- STEP #5 Configure backup view
--IderaFuncView2005.sql

USE [master]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

If exists (select name from sysobjects where name = 'fn_getDBFileSize') DROP FUNCTION fn_getDBFileSize
GO

CREATE FUNCTION [dbo].[fn_getDBFileSize] (@db sysname,  @filetype varchar(4) = 'ALL' )
RETURNS dec(15)
	AS
	BEGIN 
		declare @low	nvarchar(11)
		declare @size   integer
		declare @dbsize dec(15)
		 
		SELECT @low =  convert(varchar(11),low)  
		  from master.dbo.spt_values
		where type = N'E' and number = 1 

		If upper(@filetype) = 'ALL'  
			-- return the size of all data and log files combined (default)
			select @size = sum(size)  
				FROM master.dbo.sysdatabases a
					, master.dbo.sysaltfiles  b
				where a.name = @db       
				and a.dbid= b.dbid
				group by a.name 
		if upper(@filetype) = 'DATA'  
			-- return the size of all data files combined
			select @size = sum(size)  
				FROM master.dbo.sysdatabases a
					, master.dbo.sysaltfiles  b
				where a.name = @db       
				and a.dbid= b.dbid
				and groupid != 0
				group by a.name 
		If upper(@filetype) = 'LOG'  
			-- return the size of all log files combined
			select @size = sum(size)  
				FROM master.dbo.sysdatabases a
					, master.dbo.sysaltfiles  b
				where a.name = @db       
				and a.dbid= b.dbid
				and groupid = 0
				group by a.name 
--	the commented code below was used to convert the value to STR data type and calculate size in MB
--		set @dbsize = str(convert(dec(15),sum(@size))*  @low / 1048576,10,2)
		set @dbsize = convert(dec(15),sum(@size))*  @low 
 
	-- Return the result of the function
	RETURN @dbsize
END
GO

USE [master]
GO

IF EXISTS (SELECT name FROM master.dbo.sysobjects WHERE name = 'vw_backup_report')
	DROP VIEW dbo.vw_backup_report 
GO

CREATE VIEW [dbo].[vw_backup_report] 
AS 
-- This is a query for SQL Server 2005 and 2008

SELECT		CONVERT(NVARCHAR(128),ISNULL(SERVERPROPERTY('InstanceName'),'DEFAULT'))			AS Instance
			,CONVERT(NVARCHAR(128),SERVERPROPERTY('EDITION'))								AS Edition
			,db.name																		AS DBName 
			,db.crdate																		AS DBCreateDate
			,master.dbo.fn_getDBFileSize(name,'ALL')										AS DBSize
			,master.dbo.fn_getDBFileSize(name,'DATA')										AS DataSize
			,master.dbo.fn_getDBFileSize(name,'LOG')										AS LogSize 
			,f.last_backup																	AS LastFullBackupDate 
			,f.backup_size																	AS FullBackupSize
			,ISNULL(DATEDIFF(d,f.last_backup ,GETDATE()),999)								AS DaysSinceLastFull
			,d.last_backup																	AS LastDiffBackupDate
			,d.backup_size																	AS DiffBackupSize
			,ISNULL(DATEDIFF(d,d.last_backup ,GETDATE()),999)								AS DaysSinceLastDiff
			,l.last_backup																	AS LastTranBackupDate 
			,l.backup_size																	AS LogBackupSize
			,ISNULL(DATEDIFF(d,l.last_backup ,GETDATE()),999)								AS DaysSinceLastTran
			,CONVERT(NVARCHAR(128),	DATABASEPROPERTYEX(db.name ,'Recovery')	)				AS RecoveryModel
			,CONVERT(NVARCHAR(128),	DATABASEPROPERTYEX(db.name ,'Updateability'))			AS Updateability 
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX(db.name ,'IsPublished'))				AS IsPublished 
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX(db.name ,'IsSubscribed'))			AS IsSubscribed 
			,CONVERT(NVARCHAR(1),	SERVERPROPERTY('IsClustered'))							AS IsClustered
			,ISNULL(m.mirroring_role,0)														AS IsMirrored
			,CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion'))						AS SQLVersion
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX	(db.name ,'IsAutoClose'))			AS IsAutoClose			
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX	(db.name ,'IsAutoShrink'))			AS IsAutoShrink			
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX	(db.name ,'IsAutoCreateStatistics'))AS IsAutoCreateStatistics
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTYEX	(db.name ,'IsAutoUpdateStatistics'))AS IsAutoUpdateStatistics
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTY	(db.name ,'IsBulkCopy'))			AS IsBulkCopy			
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTY	(db.name ,'IsDboOnly'))				AS IsDboOnly				
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTY	(db.name ,'IsReadOnly'))			AS IsReadOnly			
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTY	(db.name ,'IsSingleUser'))			AS IsSingleUser			
			,CONVERT(NVARCHAR(1),	DATABASEPROPERTY	(db.name ,'IsTruncLog'))			AS IsTruncLog
FROM		[master].[dbo].[sysdatabases] db   
INNER JOIN sys.database_mirroring m on db.dbid=m.database_id 
LEFT OUTER JOIN (SELECT backup_finish_date AS last_backup,
							database_name,
							[type],
							backup_size   AS backup_size
					 FROM	[msdb].[dbo].[backupset]  x
					 WHERE	type = N'D' 
					 and	x.backup_finish_date = 
						( 
							SELECT		max(backup_finish_date) 
							FROM		[msdb].[dbo].[backupset] 
							WHERE		type = N'D' 
							AND			x.database_name = database_name
							GROUP BY	database_name
										,type 
						)
				 ) f ON f.database_name = db.name  
LEFT OUTER JOIN (SELECT backup_finish_date AS last_backup,
							database_name,
							[type],
							backup_size   AS backup_size
					 FROM	[msdb].[dbo].[backupset]  y
					 WHERE	type = N'L' 
					 and	y.backup_finish_date = 
						( 
							SELECT		max(backup_finish_date) 
							FROM		[msdb].[dbo].[backupset] 
							WHERE		type = N'L' 
							AND			y.database_name = database_name
							GROUP BY	database_name
										,type 
						)  
				) l ON l.database_name = db.name 
LEFT OUTER JOIN (SELECT backup_finish_date AS last_backup,
							database_name,
							[type],
							backup_size   AS backup_size
					 FROM	[msdb].[dbo].[backupset]  z
					 WHERE	type = N'I' 
					 and	z.backup_finish_date = 
						( 
							SELECT		max(backup_finish_date) 
							FROM		[msdb].[dbo].[backupset] 
							WHERE		type = N'I' 
							AND			z.database_name = database_name
							GROUP BY	database_name
										,type 
						) 
				 ) d ON d.database_name = db.name  
WHERE 		db.name not in ('model','tempdb')	



go
 select * from vw_backup_report 



-- STEP #6 Configure 'SQL Server Restart' Startup notification
---- the stored procedure must reside in the [master] database
---- it's owner must be dbo
---- it must not have any input or output parameters
---- The following is what we have on all of our production servers. 
---- Any reboot of a database servers will email to our distribution list when sql starts up
---- All of our server have a standard mail profile that is used: 'Default Public Profile'

-- START: GG, to modify below procedure to use the new format
USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'DBA_SQLRestartNotification')
	EXEC ('CREATE PROC [dbo].[DBA_SQLRestartNotification] AS RETURN 0;')
GO
ALTER PROCEDURE [dbo].[DBA_SQLRestartNotification]
AS

set nocount on
set transaction isolation level read uncommitted

WAITFOR DELAY '00:02:00'

declare @sql nvarchar(2000), @Edn char(3), @Ver varchar(20), @Upd datetime, @Nod varchar(30), @Vir varchar(3)
select   @Edn = cast(SERVERPROPERTY ('Edition') as varchar(50)),
		 @Ver = cast(SERVERPROPERTY ('ProductVersion' ) as varchar(15)),
		 @Nod = cast(ServerProperty('ComputerNamePhysicalNetBIOS') as varchar(30)),
		 @Upd = convert(char(19), create_date,20), 
		 @Vir = case when @@version like '%hyper%' then 'Yes' else 'No' end 		   
from master.sys.databases where name = 'tempdb' 

if object_id('tempdb..#dbreport') is not null drop table #dbreport
create table #dbreport (rownumber int identity(1,1), name varchar(100), [dbid] int, crdate datetime, cmpt varchar(4), [recovery] varchar(20), [ReadOnly] varchar(3),[State] varchar(20))

insert into #dbreport(name, [dbid], crdate, cmpt, [recovery], [ReadOnly],[state])
select name, database_id [dbid], convert(char(16),create_date,20) crdate,
	[Compatibility_level], recovery_model_desc, [ReadOnly] = case when is_read_only = 1 then 'YES' else ' ' end, state_desc
From master.sys.databases order by 1

declare @tableBody varchar(max), @tableHead varchar(max), @tableTail varchar(max), @email_Subject varchar(255)
set @tableTail = '</table></body></html>';
set @email_Subject = 'SQL Server Startup Report for ' + @@servername + ' - ' + datename(dw, getdate()) + ', ' + convert(varchar(24),getdate(),101)

-------------------------------
--create report table for email
-------------------------------
	set @tableHead = '<html><div><p><b>' + 'Current Node = ' + @Nod + ', Edition = ' + @Edn + ', Version = ' + @Ver + ', isVirtual = ' + @Vir+ '</b></p></div></html>'
	set @tableHead = @tableHead + '<html><head>' +
			  '<style>' +
			  'td {border: solid black 1px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font-size:11pt;} ' +
			  '</style>' +
			  '</head>' +
			  '<body><table cellpadding="0" cellspacing="0" border="0">' +
			  '<tr bgcolor="#FFEFD8"><td align="left"><b>Database</b></td>' + 
			  '<td align="center"><b>DB_ID</b></td>' + 
			  '<td align="center"><b>Create Date</b></td>' + 
			  '<td align="center"><b>Cmpt</b></td>' + 
			  '<td align="center"><b>Recovery</b></td>' +
			  '<td align="center"><b>ReadOnly</b></td>' +			   
			  '<td align="center"><b>Status</b></td></tr>';
	select @tableBody = (select rownumber % 2				[TRRow],  
						   name								[TD align="left"],
						   [dbid]							[TD align="center"],
						   convert(char(16),[crdate],20)	[TD align="left"],
						   cmpt								[TD align="center"],
						   [Recovery]						[TD align="center"],
						   [ReadOnly]						[TD align="center"],
						   case when [state] = 'ONLINE' then [state] else 'xx' + [state] end [TD align="center"]
					From #dbreport
					order by name
					for XML raw('tr'), Elements)	

	Set @tableBody = Replace(@tableBody, '_x0020_', space(1))
	Set @tableBody = Replace(@tableBody, '_x003D_', '=')
	Set @tableBody = Replace(@tableBody, '<tr><TRRow>1</TRRow>', '<tr bgcolor="#96F896">')  --green
	Set @tableBody = Replace(@tableBody, '<tr><TRRow>3</TRRow>', '<tr bgcolor="#E67070">')  --red
	Set @tableBody = Replace(@tableBody, '<TRRow>0</TRRow>', '')
	Select @tableBody = @TableHead + @tableBody + @TableTail

--put in standard form	
	select @tableBody = replace(replace(replace(replace(replace(replace(@tableBody,
		'<TD align=_x0022_center_x0022_>','<TD align="center">'),
		'<TD align=_x0022_right_x0022_>' ,'<TD align="right">'), 
		'<TD align=_x0022_left_x0022_>' ,'<TD align="left">'), 
		'</TD align=_x0022_center_x0022_>','</TD>'),
		'</TD align=_x0022_left_x0022_>','</TD>'),
		'</TD align=_x0022_right_x0022_>' ,'</TD>')
		--select cast(@tablebody as XML) tablebody	

--mark anything with status <> ONLINE in read
	select @tableBody = Replace(@tableBody, '<TD align="center">xx','<TD align="center" bgcolor="#E67070">') 		

--send email
	declare @emailprofile varchar(50)
	select @emailprofile = sp.name 
		From msdb.dbo.sysmail_profile sp with(nolock)
		join msdb.dbo.sysmail_principalprofile spp  with(nolock) on spp.profile_id = sp.profile_id
		where spp.is_default = 1


	BEGIN
		EXEC msdb.dbo.sp_send_dbmail 
			@recipients=N'DBA@smtp.yourdomain.local',
			@body = @tableBody,
			@body_format = 'HTML', 
			@subject = @email_Subject, 
			@profile_name = @emailprofile
	END
GO
-- END

----Make the procedure a 'startup'

EXEC sp_procoption N'DBA_SQLRestartNotification', 'startup', 'on'


EXEC msdb.dbo.sp_update_alert @name=N'Severity level 20', @enabled=0
GO


-- tempdb modifications
IF NOT EXISTS (SELECT name FROM sys.master_files WHERE database_id = 2 AND file_id = 1 AND name = 'tempdb01')
BEGIN
DECLARE @cpu_count int
DECLARE @path NVARCHAR(255)
DECLARE @tempdb_sql NVARCHAR(500);
SELECT @cpu_count = cpu_count FROM sys.dm_os_sys_info
SELECT @path = physical_name FROM sys.master_files WHERE name = 'tempdev' AND database_id = 2 AND file_id = 1

ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', NEWNAME = N'tempdb01', SIZE = 1048576KB , FILEGROWTH = 102400KB )
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', SIZE = 524288KB , FILEGROWTH = 524288KB )

IF (@cpu_count >= 2 AND @cpu_count < 4)
BEGIN
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb02'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb02.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
END
ELSE IF (@cpu_count >= 4 AND @cpu_count < 6)
BEGIN
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb02'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb02.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb03'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9)) +'tempdb03.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb04'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb04.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
END
ELSE IF (@cpu_count >= 6 AND @cpu_count < 8)
BEGIN
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb02'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb02.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb03'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9)) +'tempdb03.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb04'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb04.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb05'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb05.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb06'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb06.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
END
ELSE IF @cpu_count >= 8
BEGIN
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb02'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb02.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb03'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9)) +'tempdb03.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb04'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb04.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb05'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb05.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb06'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb06.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb07'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb07.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
	SET @tempdb_sql = N'ALTER DATABASE [tempdb] ADD FILE ( NAME = N''tempdb08'', FILENAME = N'''+(SELECT SUBSTRING(@path,0,LEN(@path)-9) )+'tempdb08.ndf'' , SIZE = 1048576KB , FILEGROWTH = 102400KB )'
	EXECUTE sys.sp_executesql @tempdb_sql
END

END

--Enable failsafe operator, enable mail profile for SQL Agent
USE msdb
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'SQL DBAs', @notificationmethod=1
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'UseDatabaseMail', N'REG_DWORD', 1
EXEC master.dbo.xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent', N'DatabaseMailProfile', N'REG_SZ', N'Default Public Profile'
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1

EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE WITH OVERRIDE
GO
EXEC sp_configure 'Agent XPs', 1
GO
RECONFIGURE WITH OVERRIDE
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=10000
GO
