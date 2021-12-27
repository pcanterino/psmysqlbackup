[String]$configMysqlHost = "localhost"
[String]$configMysqlUser = "backup"
[String]$configMysqlPassword = "backup"

[String]$configMysqlCli = "C:\Program Files\MariaDB 10.5\bin\mysql.exe"
[String]$configMysqldumpCli = "C:\Program Files\MariaDB 10.5\bin\mysqldump.exe"

[String]$configBackupDir = "backup"
[String]$configRotate = 7

function Get-Databases() {
    $databaseString = (& $configMysqlCli --host=$configMysqlHost --user=$configMysqlUser --password=$configMysqlPassword --batch --skip-column-names -e "SHOW DATABASES;")
    $databases = $databaseString.split([Environment]::NewLine)

    return $databases
}

function Create-Backup([String]$database, [String]$target) {
    & $configMysqldumpCli --host=$configMysqlHost --user=$configMysqlUser --password=$configMysqlPassword --single-transaction --result-file=$target $database
}

$currDaytime = Get-Date -format "yyyyMMdd-HHmmss"

$databases = Get-Databases | Where-Object { $_ -ne "information_schema" -and $_ -ne "performance_schema"}

foreach($d in $databases) {
    $databaseBackupDir = Join-Path -Path $configBackupDir -ChildPath $d

    if(!(Test-Path $databaseBackupDir)) {
        New-Item -ItemType directory -Path $databaseBackupDir -ErrorAction Stop | Out-Null
    }

    $databaseBackupFile = Join-Path -Path $databaseBackupDir -ChildPath "backup-$d-$currDaytime.sql"
    Write-Output "Backing up $d to $databaseBackupFile..."
    Create-Backup $d $databaseBackupFile
}