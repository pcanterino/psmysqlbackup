[String]$config_mysql_host = "localhost"
[String]$config_mysql_user = "backup"
[String]$config_mysql_password = "backup"

[String]$config_mysql_cli = "C:\Program Files\MariaDB 10.5\bin\mysql.exe"
[String]$config_mysqldump_cli = "C:\Program Files\MariaDB 10.5\bin\mysqldump.exe"

[String]$config_backup_dir = "backup"
[String]$config_rotate = 7

function Get-Databases() {
    $databaseString = (& $config_mysql_cli --host=$config_mysql_host --user=$config_mysql_user --password=$config_mysql_password --batch --skip-column-names -e "SHOW DATABASES;")
    $databases = $databaseString.split([Environment]::NewLine)

    return $databases
}

function Create-Backup([String]$database, [String]$target) {
    & $config_mysqldump_cli --host=$config_mysql_host --user=$config_mysql_user --password=$config_mysql_password --single-transaction --result-file=$target $database
}

$databases = Get-Databases | Where-Object { $_ -ne "information_schema" -and $_ -ne "performance_schema"}

foreach($d in $databases) {
    $backupFile = $config_backup_dir + "\" + $d + ".sql"
    Write-Output "Backing up $d to $backupFile..."
    Create-Backup $d $backupFile
}