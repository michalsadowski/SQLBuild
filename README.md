# SQLBuild
PowerShell scripts to automate installation of SQL Server

Requirements:
  1. Binaries of the SQL Server are sotred in D:\DBA directory - e.g. SQL Server 2016 in D:\DBA\SQLServer2016, etc.
  2. Windows Server is configured as in https://sqlplayer.net/2018/12/preparation-for-sql-server-installation/ and https://sqlplayer.net/2019/01/unattended-installation-of-sql-server/ blog posts
  3. All files from this site are located in D:\DBA directory
  4. Latest Cumulative Updates are located in D:\DBA\Updates directory
  5. Latest version of SSMS is located in D:\DBA\Updates directory
 
To run installation start PowerShell as an Administrator and browse to D:\DBA
Run ./SQL_install.ps1 with following parameters:

$version - possible values: 2008R2, 2012, 2014, 2016, 2017

$edition - possible values: DEV, STD, ENT

$InstanceName - provide name of instance, for default use MSSQLSERVER

$collation - proivde collation for installation e.g. SQL_Latin1_General_CP1_CI_AS

$TCPPort - provide TCP port on which SQL Server will be listening

Example of installation command:

./SQL_install.ps1 2017 DEV MSSQLSERVER SQL_Latin1_General_CP1_CI_AS 1433
