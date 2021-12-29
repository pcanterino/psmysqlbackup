# PSMySQLBackup
# PowerShell script for backing up MySQL / MariaDB databases on Windows 
#
# Author: Patrick Canterino <patrick@patrick-canterino.de>
# WWW: https://www.patrick-canterino.de/
#      https://github.com/pcanterino/dsmonrot
# License: 2-Clause BSD License

# Config

$configMysqlHost = "localhost"
$configMysqlPort = 3306
$configMysqlUser = "backup"
$configMysqlPassword = "backup"

$configMysqlCli = "C:\Program Files\MariaDB 10.5\bin\mysql.exe"
$configMysqldumpCli = "C:\Program Files\MariaDB 10.5\bin\mysqldump.exe"

$configBackupDir = "backup"
$configRotate = 7

$configDbBackup = @()
$configDbExclusions = @("test")

# End of config

function Get-Databases() {
    $databaseString = (& $configMysqlCli --host=$configMysqlHost --port=$configMysqlPort --user=$configMysqlUser --password=$configMysqlPassword --batch --skip-column-names -e "SHOW DATABASES;")
    
    if($LastExitCode -ne 0) {
        throw "MySQL CLI exited with Exit code $LastExitCode"
    }
    
    $databases = $databaseString.split([Environment]::NewLine)

    return $databases
}

function Create-Backup([String]$database, [String]$target) {
    & $configMysqldumpCli --host=$configMysqlHost --port=$configMysqlPort --user=$configMysqlUser --password=$configMysqlPassword --single-transaction --result-file=$target $database

    if($LastExitCode -ne 0) {
        throw "mysqldump exited with Exit code $LastExitCode"
    }
}

function Rotate-Backups($backupDir) {
    if($configRotate -le 0) {
        return
    }
    
    $keepBackupsCount = $configRotate

    Get-ChildItem $backupDir -File | Where-Object {($_.Name -match "^backup-.+-\d{8,}-\d{6}\.sql$")} | Sort-Object -Descending |
    Foreach-Object {
        if($keepBackupsCount -ge 0) {
            $keepBackupsCount--
        }

        if($keepBackupsCount -eq -1) {
            Write-Output "Deleting backup $($_.FullName)"
            Remove-Item -Force $_.FullName
        }
    }
}

$defaultExclusions = @("information_schema", "performance_schema")

$currDaytime = Get-Date -format "yyyyMMdd-HHmmss"

try {
    $databases = Get-Databases | Where-Object {!($_ -in $defaultExclusions -or $_ -in $configDbExclusions)}
}
catch {
    Write-Output "Failed to get list of databases"
    Write-Output $_
    exit 1
}

$databasesToBackup = @()

if($configDbBackup -and $configDbBackup.count -gt 0) {
    foreach($cDb in $configDbBackup) {
        if($cDb -in $databases) {
            $databasesToBackup += $cDb
        }
        else {
            Write-Warning "Not backing up database $cDb, because it does not exist"
        }
    }
}
else {
    $databasesToBackup = $databases
}

foreach($d in $databasesToBackup) {
    $databaseBackupDir = Join-Path -Path $configBackupDir -ChildPath $d

    if(!(Test-Path $databaseBackupDir)) {
        New-Item -ItemType directory -Path $databaseBackupDir -ErrorAction Stop | Out-Null
    }

    $databaseBackupFile = Join-Path -Path $databaseBackupDir -ChildPath "backup-$d-$currDaytime.sql"
    Write-Output "Backing up $d to $databaseBackupFile..."
    
    try {
        Create-Backup $d $databaseBackupFile
        Rotate-Backups $databaseBackupDir
    }
    catch {
        Write-Output "Could not backup database $d to $databaseBackupFile"
        Write-Output $_
    }
}