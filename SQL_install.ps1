param(
[string]$version,
[string]$edition,
[string]$InstanceName,
[string]$collation,
[string]$TCPPort
) 
try{
  stop-transcript|out-null
}
catch [System.InvalidOperationException]{}
cls
New-Item -ItemType Directory -Force -Path D:\DBA\logs
Write-Output "$date Starting logging to file D:\DBA\logs\$InstanceName_00_SQL_install.txt "
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
$date = Get-Date -format "yyyyMMdd_HHmmss" 
$MainLog = "D:\DBA\logs\"+$InstanceName+$date+"_00_SQL_install.txt"
Start-Transcript -path $MainLog
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "################################################################################
                    SQL Server installation script
################################################################################

Installation started at $date 
On computer $env:computername
Script parameters: $version $edition $InstanceName $collation $TCPPort"

################################################################################
# Step 1: Validating input parameters
################################################################################
Write-Output "$date Validating input parameters"

if (($version -eq "2008R2") -or ($version -eq "2012") -or ($version -eq "2014") -or ($version -eq "2016") -or ($version -eq "2017"))
{
}
else
{

Write-Output "$date Missing parameter with version of SQL Server. Possible options are: 2008R2, 2012, 2014, 2016, 2017

################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

if (($edition -eq "DEV") -or ($edition -eq "STD") -or ($edition -eq "ENT") -or ($edition -eq "ENT_core"))
{
}
else
{
Write-Output "$date Missing parameter with edition of SQL Server. Possible options are: DEV, STD, ENT, (ENT_Core only for 2016/2017)

################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

if ($InstanceName)
{
}
else
{
Write-Output "$date Please provide Instance Name for SQL Server

################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}
if ($collation)
{
}
else
{
Write-Output "$date Missing parameter with collation of server. Please provide correct collation like SQL_Latin1_General_CP1_CI_AS, etc.

################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

if ($TCPPort)
{
Write-Output "$date Step 2: completed - Script is going to install SQL Server $version $edition edition with Instance Name: $InstanceName using $TCPPort on $env:computername"

}
else
{
Write-Output "$date Step 2: failed

Please provide TCP Port for SQL Server

################################################################################
"
Get-Date -format "yyyy-MM-dd HH:mm:ss"
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"
exit
}

################################################################################
# Step 2: .Net framework 3.5 sp1 
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Checking if .NET 3.5 is installed"

$net_core_2012r2 = (Get-WindowsFeature -Name Net-Framework-Core).InstallState
$net_core_2008r2 = (Get-WindowsFeature -Name Net-Framework-Core).Installed

if (($net_core_2012r2 -eq "Installed") -or ($net_core_2008r2 -eq $True))
{
$message = ".NET Framework 3.5 is installed on the server"
Write-Output $message
}
else
{
$message = ".NET Framework 3.5 is missing on the server, please reach out to the Provisioning team and ask them to install .NET Framework 3.5"
Write-Output $message
exit
}
################################################################################
# Step 3: Disk alignment
################################################################################
 
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Checking disk aligment"

$wql = "SELECT Label, Blocksize, Name FROM Win32_Volume WHERE FileSystem='NTFS'"

$disk_block_sizes = (Get-WmiObject -Query $wql -ComputerName '.' | Where-Object {$_.Name -notmatch "C:?"})  | Where-Object {$_.Name -notmatch "System"}
($disk_block_sizes |  Where-Object {$_.BlockSize -eq "65536"}).Name

$disks_wrong = ($disk_block_sizes |  Where-Object {$_.BlockSize -ne "65536"}).Name
$disks_64k = ($disk_block_sizes |  Where-Object {$_.BlockSize -eq "65536"}).Name

if ($disks_64k -ne $null)
{
$message = "Following disks are correctly formated, please check if following disk are with letters D:, F:, L:, T:, U: "
Write-Output $message $disks_64k
}
else
{
$message = "Following disks are formatted incorrectly, please consider reformating following disk"
Write-Output $message, $disks_wrong 
exit
}

################################################################################
# Step 4: Granting required privileges to Admins group 
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Granting required privileges to Admins group"

robocopy D:\DBA\scripts C:\Windows\System32 ntrights.exe
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Granting required privileges to Administrators group"
C:\Windows\System32\ntrights -u Administrators +r SeInteractiveLogonRight
C:\Windows\System32\ntrights -u Administrators +r SeBatchLogonRight
C:\Windows\System32\ntrights -u Administrators +r SeServiceLogonRight
C:\Windows\System32\ntrights -u Administrators +r SeNetworkLogonRight
C:\Windows\System32\ntrights -u Administrators +r SeTcbPrivilege
C:\Windows\System32\ntrights -u Administrators +r SeDebugPrivilege
C:\Windows\System32\ntrights -u Administrators +r SeSecurityPrivilege
C:\Windows\System32\ntrights -u Administrators +r SeBackupPrivilege

################################################################################
# Step 5: Preparing SQL Server binaries before installation (DEV, STD, ENT)
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Preparing SQL Server binaries before installation"

if ($version -eq "2017")
{
$sql_version_part = "MSSQL14"
$sql_version_number = "140"
    if ($edition -eq "DEV")
    {
      copy D:\DBA\scripts\2017_DEV.ini D:\DBA\SQLServer2017\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "STD")
    {
      copy D:\DBA\scripts\2017_STD.ini D:\DBA\SQLServer2017\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT")
    {
      copy D:\DBA\scripts\2017_ENT.ini D:\DBA\SQLServer2017\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT_Core")
    {
      copy D:\DBA\scripts\2017_ENT_core.ini D:\DBA\SQLServer2017\x64\DefaultSetup.ini
    }
}
elseif ($version -eq "2016")
{
$sql_version_part = "MSSQL13"
$sql_version_number = "130"
    if ($edition -eq "DEV")
    {
      copy D:\DBA\scripts\2016_DEV.ini D:\DBA\SQLServer2016\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "STD")
    {
      copy D:\DBA\scripts\2016_STD.ini D:\DBA\SQLServer2016\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT")
    {
      copy D:\DBA\scripts\2016_ENT.ini D:\DBA\SQLServer2016\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT_Core")
    {
      copy D:\DBA\scripts\2016_ENT_core.ini D:\DBA\SQLServer2016\x64\DefaultSetup.ini
    }
}
elseif ($version -eq "2014")
{
$sql_version_part = "MSSQL12"
$sql_version_number = "120"
    if ($edition -eq "DEV")
    {
      copy D:\DBA\scripts\2014_DEV.ini D:\DBA\SQLServer2014\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "STD")
    {
      copy D:\DBA\scripts\2014_STD.ini D:\DBA\SQLServer2014\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT")
    {
      copy D:\DBA\scripts\2014_ENT.ini D:\DBA\SQLServer2014\x64\DefaultSetup.ini
    }
}
elseif($version -eq "2012")
{
$sql_version_part = "MSSQL11"
$sql_version_number = "110"
    if ($edition -eq "DEV")
    {
      copy D:\DBA\scripts\2012_DEV.ini D:\DBA\SQLServer2012\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "STD")
    {
      copy D:\DBA\scripts\2012_STD.ini D:\DBA\SQLServer2012\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT")
    {
      copy D:\DBA\scripts\2012_ENT.ini D:\DBA\SQLServer2012\x64\DefaultSetup.ini
    }
}
elseif($version -eq "2008R2")
{
$sql_version_part = "MSSQL10_50"
$sql_version_number = "100"
    if ($edition -eq "DEV")
    {
      copy D:\DBA\scripts\2008R2_DEV.ini D:\DBA\SQLServer2008R2\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "STD")
    {
      copy D:\DBA\scripts\2008R2_STD.ini D:\DBA\SQLServer2008R2\x64\DefaultSetup.ini
    }
    elseif ($edition -eq "ENT")
    {
      copy D:\DBA\scripts\2008R2_ENT.ini D:\DBA\SQLServer2008R2\x64\DefaultSetup.ini
    }
}

################################################################################
# Step 6: Install SQL Server with SP and CU
################################################################################

$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Starting SQL Server installation"

$InstallationDIR="D:\MSSQLServer\"
$SQLBackupDIR="D:\SQLBackup\" +$env:computername+"$"+$InstanceName
$SQLTempDBDIR="D:\SQLTempDB01\" + $sql_version_part +"."+ $InstanceName
$SQLTempDBDIR2016="D:\SQLTempDB01\" + $sql_version_part +"."+ $InstanceName + " D:\SQLTempDB02\" + $sql_version_part +"."+ $InstanceName + " D:\SQLTempDB03\" + $sql_version_part +"."+ $InstanceName + " D:\SQLTempDB04\" + $sql_version_part +"."+ $InstanceName
$SQLTempDBLogDIR="D:\SQLTLog\" + $sql_version_part +"."+ $InstanceName
$SQLUserDBDIR="D:\SQLData00\" + $sql_version_part +"."+ $InstanceName
$SQLUserDBLogDIR="D:\SQLTLog\" + $sql_version_part +"."+ $InstanceName

if ($version -eq "2017")
{
    if ($InstanceName -eq "MSSQLSERVER")
    {
    D:\DBA\SQLServer2017\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCENAME=MSSQLSERVER /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR2016 /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /SQLTEMPDBFILECOUNT=4 /IACCEPTSQLSERVERLICENSETERMS  
    }
    else
    {
    D:\DBA\SQLServer2017\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCEID=$InstanceName /INSTANCENAME=$InstanceName /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR2016 /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /SQLTEMPDBFILECOUNT=4 /IACCEPTSQLSERVERLICENSETERMS  
    }
	
	$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
	Write-Output "$date SQL Server installation completed, starting installation of Microsoft SQL Server Management Studio - it can take few minutes, please wait..."
	Start-Process D:\DBA\Updates\SSMS-Setup-ENU.exe -argumentlist " /install /passive /norestart /log D:\DBA\logs\SSMS.txt" -wait
	$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
	Write-Output "$date Installation of Microsoft SQL Server Management Studio completed"
}
if ($version -eq "2016")
{
    if ($InstanceName -eq "MSSQLSERVER")
    {
    D:\DBA\SQLServer2016\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCENAME=MSSQLSERVER /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR2016 /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /SQLTEMPDBFILECOUNT=4 /IACCEPTSQLSERVERLICENSETERMS  
    }
    else
    {
    D:\DBA\SQLServer2016\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCEID=$InstanceName /INSTANCENAME=$InstanceName /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR2016 /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /SQLTEMPDBFILECOUNT=4 /IACCEPTSQLSERVERLICENSETERMS  
    }
	
	$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
	Write-Output "$date SQL Server installation completed, starting installation of Microsoft SQL Server Management Studio - it can take few minutes, please wait..."
	Start-Process D:\DBA\Updates\SSMS-Setup-ENU.exe -argumentlist " /install /passive /norestart /log D:\DBA\logs\SSMS.txt" -wait
	$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
	Write-Output "$date Installation of Microsoft SQL Server Management Studio completed"
}
elseif ($version -eq "2014")
{
    if ($InstanceName -eq "MSSQLSERVER")
    {
    D:\DBA\SQLServer2014\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCENAME=MSSQLSERVER /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS  
    }
    else
    {
    D:\DBA\SQLServer2014\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCEID=$InstanceName /INSTANCENAME=$InstanceName /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS  
    }
}
elseif ($version -eq "2012")
{
    if ($InstanceName -eq "MSSQLSERVER")
    {
    D:\DBA\SQLServer2012\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCENAME=MSSQLSERVER /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS 
    }
    else
    {
    D:\DBA\SQLServer2012\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /UpdateEnabled=1 /UpdateSource="D:\DBA\Updates" /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCEID=$InstanceName /INSTANCENAME=$InstanceName /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS 
    }
}
elseif ($version -eq "2008R2")
{
    if ($InstanceName -eq "MSSQLSERVER")
    {
    D:\DBA\SQLServer2008R2\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCENAME=MSSQLSERVER /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS 
    }
    else
    {
    D:\DBA\SQLServer2008R2\Setup.exe /QS /ACTION=Install /FEATURES=SQLENGINE,ADV_SSMS /ENU /ERRORREPORTING=0 /INSTANCEDIR=$InstallationDIR /INSTANCEID=$InstanceName /INSTANCENAME=$InstanceName /SQMREPORTING=0 /SQLSVCACCOUNT="DATACOMMUNITY\SQLServerEngine$" /AGTSVCACCOUNT="DATACOMMUNITY\SQLServerAgent$" /AGTSVCSTARTUPTYPE="Automatic" /BROWSERSVCSTARTUPTYPE="Disabled" /INSTALLSQLDATADIR=$InstallationDIR /SQLBACKUPDIR=$SQLBackupDIR /SQLCOLLATION=$collation /SQLSVCSTARTUPTYPE="Automatic" /SQLTEMPDBDIR=$SQLTempDBDIR /SQLTEMPDBLOGDIR=$SQLTempDBLogDIR /SQLUSERDBDIR=$SQLUserDBDIR /SQLUSERDBLOGDIR=$SQLUserDBLogDIR /IACCEPTSQLSERVERLICENSETERMS 
    }
}

New-Item -ItemType directory -Path D:\DBA\logs -Force
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date SQL Server installation completed, starting installation of Microsoft System CLR Types for Microsoft SQL Server 2016"
$ArgumentList = "/i D:\DBA\scripts\SQLSysClrTypes.msi /passive /norestart /log D:\DBA\logs\"+$InstanceName+"_SQLSysClrTypes.log"
Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $ArgumentList -wait

$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Starting installation of Microsoft® SQL Server® 2016 Shared Management Objects"
$ArgumentList =  "/i D:\DBA\scripts\SharedManagementObjects.msi /passive /norestart /log D:\DBA\logs\"+$InstanceName+"_SharedManagementObjects.log" 
Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $ArgumentList -wait

$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Starting installation Microsoft Windows PowerShell Extensions for Microsoft SQL Server 2016"
$ArgumentList = "/i D:\DBA\scripts\PowerShellTools.msi /passive /norestart /log D:\DBA\logs\"+$InstanceName+"_PowerShellTools.txt"
Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $ArgumentList -wait
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Installation of all additonal packages completed"

################################################################################
# Step 7: Admin access script
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running admin access script"

cd "C:\Program Files\Microsoft SQL Server\130\Tools\PowerShell\Modules"
Import-Module (Resolve-Path('SQLPS')) -DisableNamechecking

start-service -displayname "SQL Server ($InstanceName)"
start-service -displayname "SQL Server Agent ($InstanceName)"

$Log = "D:\DBA\logs\"+$InstanceName+"_01_Admin_Access.txt"

################################################################################
# Step 8: Server configuration script
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running server configuration  script"

$Log = "D:\DBA\logs\"+$InstanceName+"_02_Server_Config.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\02_Server_Config.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\02_Server_Config.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 9: sp_Blitz stored procedure
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running sp_Blitz stored procedure script"

$Log = "D:\DBA\logs\"+$InstanceName+"_03_sp_Blitz.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\03_sp_Blitz.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\03_sp_Blitz.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 10: sp_WhoIsActive stored procedure
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running sp_WhoIsActive stored procedure script"

$Log = "D:\DBA\logs\"+$InstanceName+"_04_sp_WhoIsActive.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\04_sp_WhoIsActive.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\04_sp_WhoIsActive.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 11: Perfmon_Dashboard_Setup stored procedure
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running Performance Dashboard Setup stored procedure script"

$Log = "D:\DBA\logs\"+$InstanceName+"_05_Perfmon_Dashboard_Setup.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\05_Perfmon_Dashboard_Setup.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\05_Perfmon_Dashboard_Setup.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 12: Database Server Options
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running 0_database_server_options script"

$Log = "D:\DBA\logs\"+$InstanceName+"_06_database_server_options.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\06_database_server_options.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\06_database_server_options.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 13: job_AdaptiveCycleErrorlog
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running 4_job_AdaptiveCycleErrorlog script"

$Log = "D:\DBA\logs\"+$InstanceName+"_07_job_AdaptiveCycleErrorlog.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\07_job_AdaptiveCycleErrorlog.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\07_job_AdaptiveCycleErrorlog.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 14: MaintenanceSolution
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running MaintenanceSolution script"

$Log = "D:\DBA\logs\"+$InstanceName+"_MaintenanceSolution.txt"
	if ($InstanceName -eq "MSSQLSERVER")
		{
		Invoke-Sqlcmd -InputFile D:\DBA\scripts\08_MaintenanceSolution.sql -ServerInstance . -verbose > $Log 4>&1
		}
	else
		{
		Invoke-Sqlcmd -InputFile D:\DBA\scripts\08_MaintenanceSolution.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
		}


################################################################################
# Step 15: Lockdown script
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running lockdown script"

$Log = "D:\DBA\logs\"+$InstanceName+"_09_Secure_Build.txt"
if ($InstanceName -eq "MSSQLSERVER")
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\09_Secure_Build.sql -ServerInstance . -verbose > $Log 4>&1
    }
else
    {
    Invoke-Sqlcmd -InputFile D:\DBA\scripts\09_Secure_Build.sql -ServerInstance .\$InstanceName -verbose > $Log 4>&1
    }

################################################################################
# Step 16: TCP Port configuration
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running TCP IP configuration for SQL Server"

$TCPPath = 'HKLM:\SOFTWARE\Microsoft\\Microsoft SQL Server\' + $sql_version_part +'.'+ $InstanceName + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
set-itemproperty -path $TCPPath -name TcpPort -value $TCPPort
set-itemproperty -path $TCPPath -name TcpDynamicPorts -value ""

$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 

################################################################################
# Step 17: Adding trace flags
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Running Trace flag configuration for SQL Server"

$TraceFlagPath = 'HKLM:\SOFTWARE\Microsoft\\Microsoft SQL Server\' + $sql_version_part +'.'+ $InstanceName + '\MSSQLServer\Parameters'

if ($version -eq "2016") or ($version -eq "2017")
{
New-ItemProperty -path $TraceFlagPath -name SQLArg5 -Value "-T3226" -Force | Out-Null
}
else
{
New-ItemProperty -path $TraceFlagPath -name SQLArg3 -Value "-T1117" -Force | Out-Null
New-ItemProperty -path $TraceFlagPath -name SQLArg4 -Value "-T1118" -Force | Out-Null
New-ItemProperty -path $TraceFlagPath -name SQLArg5 -Value "-T3226" -Force | Out-Null
New-ItemProperty -path $TraceFlagPath -name SQLArg6 -Value "-T4199" -Force | Out-Null
}

$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Stopping SQL Server"
stop-service -displayname "SQL Server ($InstanceName)" -force
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Starting SQL Server"
start-service -displayname "SQL Server ($InstanceName)"
start-service -displayname "SQL Server Agent ($InstanceName)"

################################################################################
# Step 18: Review summary
################################################################################
$date = Get-Date -format "yyyy-MM-dd HH:mm:ss" 
Write-Output "$date Installation completed"
Stop-Transcript|out-null
Set-Location D:\DBA
notepad $MainLog
notepad "C:\Program Files\Microsoft SQL Server\$sql_version_number\Setup Bootstrap\LOG\Summary.txt"