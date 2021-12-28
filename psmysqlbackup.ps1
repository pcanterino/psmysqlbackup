[String]$configMysqlHost = "localhost"
[Int32]$configMysqlPort = 3306
[String]$configMysqlUser = "backup"
[String]$configMysqlPassword = "backup"

[String]$configMysqlCli = "C:\Program Files\MariaDB 10.5\bin\mysql.exe"
[String]$configMysqldumpCli = "C:\Program Files\MariaDB 10.5\bin\mysqldump.exe"

[String]$configBackupDir = "backup"
[Int32]$configRotate = 7

function Get-Databases() {
    $databaseString = (& $configMysqlCli --host=$configMysqlHost --port=$configMysqlPort --user=$configMysqlUser --password=$configMysqlPassword --batch --skip-column-names -e "SHOW DATABASES;")
    $databases = $databaseString.split([Environment]::NewLine)

    return $databases
}

function Create-Backup([String]$database, [String]$target) {
    & $configMysqldumpCli --host=$configMysqlHost --port=$configMysqlPort --user=$configMysqlUser --password=$configMysqlPassword --single-transaction --result-file=$target $database
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
    Rotate-Backups $databaseBackupDir
}