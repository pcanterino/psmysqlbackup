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

$databases = Get-Databases | Where-Object { $_ -ne "information_schema" -and $_ -ne "performance_schema"}

foreach($d in $databases) {
    $backupFile = $configBackupDir + "\" + $d + ".sql"
    Write-Output "Backing up $d to $backupFile..."
    Create-Backup $d $backupFile
}