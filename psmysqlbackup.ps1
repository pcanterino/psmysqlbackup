# PSMySQLBackup
# PowerShell script for backing up MySQL / MariaDB databases on Windows 
#
# Author: Patrick Canterino <patrick@patrick-canterino.de>
# WWW: https://www.patrick-canterino.de/
#      https://github.com/pcanterino/psmysqlbackup
# License: 2-Clause BSD License

# Config

# MySQL host
$configMysqlHost = "localhost"
# Port of MySQL host
$configMysqlPort = 3306
# MySQL user using to connect to MySQL
$configMysqlUser = "backup"
# Password for MySQL user
$configMysqlPassword = "backup"

# Path to MySQL CLI program
$configMysqlCli = "C:\Program Files\MariaDB 10.5\bin\mysql.exe"
# Path to mysqldump CLI program
$configMysqldumpCli = "C:\Program Files\MariaDB 10.5\bin\mysqldump.exe"

# Directory where to store the backups
$configBackupDir = "backup"
# Number of backups to keep, set to 0 to keep all backups
$configRotate = 7

# Databases to backup, leave empty to backup all databases
$configDbBackup = @()
# If $configDbBackup is empty, don't backup the databases defined here
$configDbExclude = @("test")
# If $configDbBackup is empty, don't backup the databases matching these patterns
$configDbExcludePattern = @()

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

$defaultDbExclude = @("information_schema", "performance_schema")

$currDaytime = Get-Date -format "yyyyMMdd-HHmmss"

# Get a list of all databases
try {
    $databases = Get-Databases | Where-Object {!($_ -in $defaultDbExclude)}
}
catch {
    Write-Output "Failed to get list of databases"
    Write-Output $_
    exit 1
}

# Create a list of databases to backup

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
    :excludeOuter
    foreach($rDb in $databases) {
        if($rDb -in $configDbExclude) {
            continue;
        }

        foreach($cPattern in $configDbExcludePattern) {
            if($rDb -match $cPattern) {
                continue excludeOuter;
            }
        }

        $databasesToBackup += $rDb
    }
}

# Iterate over the list of databases and back them up and rotate the backups
foreach($d in $databasesToBackup) {
    $databaseBackupDir = Join-Path -Path $configBackupDir -ChildPath $d

    if(!(Test-Path $databaseBackupDir)) {
        try {
            New-Item -ItemType directory -Path "$databaseBackupDir" -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Output "Failed to create directory $databaseBackupDir"
            Write-Output $_
            exit 1
        }
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