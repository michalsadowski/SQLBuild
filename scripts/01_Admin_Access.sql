SET NOCOUNT ON
USE master

EXEC sp_configure 'show advanced options' , 1
RECONFIGURE
EXEC sp_configure 'Ole Automation Procedures', 1
RECONFIGURE

DECLARE @DomainName VARCHAR(128) 
DECLARE @hr INT 
DECLARE @SysInfo INT 

EXEC @hr = sp_OACreate 'ADSystemInfo', @SysInfo OUTPUT  
EXEC @hr = sp_OAGetProperty @SysInfo, 'DomainShortName', @DomainName OUTPUT 
EXEC @hr = sp_OADestroy @SysInfo



DECLARE @COMPNAME VARCHAR(100)
SELECT @COMPNAME = RTRIM((SELECT CONVERT(char(20), SERVERPROPERTY('MachineName'))))
PRINT 'Begin process for SQL Server: '  + @COMPNAME 
PRINT ''
PRINT ''
PRINT @@version

IF  NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE name = N'NT AUTHORITY\SYSTEM')
BEGIN
	PRINT 'Since BUILTIN\Administrators is removed, [NT AUTHORITY\SYSTEM] account is needed to support maintenance jobs'
	PRINT 'Adding [NT AUTHORITY\SYSTEM] login'
	EXEC sp_grantlogin 'NT AUTHORITY\SYSTEM'
	PRINT 'Grant sysadmin access to [NT AUTHORITY\SYSTEM] login'
	EXEC sp_addsrvrolemember 'NT AUTHORITY\SYSTEM','sysadmin'
END

-- remove buildin\Administrators local server group from sysadmin on the SQL Server
IF EXISTS (SELECT * FROM master.dbo.syslogins WHERE name = N'BUILTIN\Administrators')
BEGIN
	--remove login BUILTIN\Administrators 
	PRINT 'Remove login BUILTIN\Administrators'
	EXEC sp_dropsrvrolemember @loginame = [BUILTIN\Administrators], @rolename = [sysadmin]
	EXEC sp_droplogin @loginame = [BUILTIN\Administrators]
	EXEC sp_revokelogin @loginame = [BUILTIN\Administrators]
END 

--DECLARE @COMPNAME VARCHAR(100)
SELECT @COMPNAME = RTRIM((SELECT CONVERT(char(20), SERVERPROPERTY('MachineName'))))
PRINT 'Begin process for SQL Server : '  + @COMPNAME 
PRINT ''
PRINT ''
PRINT @@version

-- reset SA password to our standard for SQL Server 
-- commented out the password
--PRINT 'Reset SA password to our standard for SQL Server '
--EXEC sp_password @new = 'Put_password_here', @loginame = 'sa'
DECLARE @srvver varchar(200)
select @srvver=convert(varchar(255),serverproperty(N'ProductVersion') )
print ''
print ''
print 'SQL Server version is ' + @srvver 
print ''
print ''
print 'Done!!!'