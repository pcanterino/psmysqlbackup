# PSMySQLBackup
# PowerShell script for backing up MySQL / MariaDB databases on Windows 
#
# Author: Patrick Canterino <patrick@patrick-canterino.de>
# WWW: https://www.patrick-canterino.de/
#      https://github.com/pcanterino/psmysqlbackup
# License: 2-Clause BSD License

# Config

# MySQL host
$configMysqlHost = 'localhost'
# Port of MySQL host
$configMysqlPort = 3306
# MySQL user using to connect to MySQL
$configMysqlUser = 'backup'
# Password for MySQL user
$configMysqlPassword = 'backup'

# Path to MySQL CLI program
$configMysqlCli = 'mysql.exe'
# Path to mysqldump CLI program
$configMysqldumpCli = 'mysqldump.exe'

# Directory where to store the backups
$configBackupDir = 'backup'
# Number of backups to keep, set to 0 to keep all backups
$configBackupRotate = 7

# Compress backups (limited to 2 GB due to usage of Compress-Archive)
$configBackupCompress = $False

# Directory where to store the logfiles
$configLogDir = 'log'
# Number of logfiles to keep, set to 0 to keep all logfiles
# You should set this to at least the same as $configBackupRotate
$configLogRotate = 7

# Databases to backup, leave empty to backup all databases
$configDbBackup = @()
# If $configDbBackup is empty, don't backup the databases defined here
$configDbExclude = @('test')
# If $configDbBackup is empty, don't backup the databases matching these patterns
$configDbExcludePattern = @()

# End of config

<# 
.Synopsis 
   Write-Log writes a message to a specified log file with the current time stamp. 
.DESCRIPTION 
   The Write-Log function is designed to add logging capability to other scripts. 
   In addition to writing output and/or verbose you can write to a log file for 
   later debugging. 
.NOTES 
   Created by: Jason Wasser @wasserja 
   Modified: 11/24/2015 09:30:19 AM   
 
   Changelog: 
    * Code simplification and clarification - thanks to @juneb_get_help 
    * Added documentation. 
    * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks 
    * Revised the Force switch to work as it should - thanks to @JeffHicks 
 
   To Do: 
    * Add error handling if trying to create a log file in a inaccessible location. 
    * Add ability to write $Message to $Verbose or $Error pipelines to eliminate 
      duplicates. 
.PARAMETER Message 
   Message is the content that you wish to add to the log file.  
.PARAMETER Path 
   The path to the log file to which you would like to write. By default the function will  
   create the path and file if it does not exist.  
.PARAMETER Level 
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational) 
.PARAMETER NoClobber 
   Use NoClobber if you do not wish to overwrite an existing file. 
.EXAMPLE 
   Write-Log -Message 'Log message'  
   Writes the message to c:\Logs\PowerShellLog.log. 
.EXAMPLE 
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log 
   Writes the content to the specified log file and creates the path and file specified.  
.EXAMPLE 
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error 
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline. 
.LINK 
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
#>
function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='C:\Logs\PowerShellLog.log', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

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

    if($configBackupCompress) {
        Compress-Archive -Path $target -DestinationPath "$target.zip"
        Remove-Item -Path $target
    }
}
function Invoke-FileRotation {
    Param (
        $Dir,
        $MaxFiles,
        [Parameter(Mandatory=$false)]
        $Pattern,
        [Parameter(Mandatory=$false)]
        $LogFile
    )

    if($MaxFiles -le 0) {
        return
    }

    $keepFilesCount = $MaxFiles

    Get-ChildItem $Dir -File | Where-Object {($null -eq $Pattern -or $_.Name -match $Pattern)} | Sort-Object -Descending |
    Foreach-Object {
        if($keepFilesCount -ge 0) {
            $keepFilesCount--
        }

        if($keepFilesCount -eq -1) {
            if($null -ne $LogFile) {
                Write-Log "Deleting file $($_.FullName)" -Path $LogFile
            }

            Remove-Item -Force $_.FullName
        }
    }
}

$defaultDbExclude = @('information_schema', 'performance_schema')

$patternBackupFile = '^backup-.+-\d{8,}-\d{6}\.sql(\.zip)?$'
$patternLogFile = '^log-\d{8,}-\d{6}\.log$'

$currDaytime = Get-Date -format 'yyyyMMdd-HHmmss'

$logFile = "$configLogDir\log-$currDaytime.log"

$startTime = Get-Date -format 'yyyy-MM-dd HH:mm:ss'
Write-Log "Started at $startTime" -Path $logFile

# Get a list of all databases
try {
    $databases = Get-Databases | Where-Object {!($_ -in $defaultDbExclude)}
}
catch {
    Write-Log 'Failed to get list of databases' -Path $logFile -Level Error
    Write-Log $_ -Path $logFile -Level Error
    Write-Log 'Exiting' -Path $logFile -Level Error

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
            Write-Log "Not backing up database $cDb, because it does not exist" -Path $logFile -Level Warn
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
            Write-Log "Failed to create directory $databaseBackupDir" -Path $logFile -Level Error
            Write-Log $_ -Path $logFile -Level Error
            Write-Log 'Exiting' -Path $logFile -Level Error

            exit 1
        }
    }

    $databaseBackupFile = Join-Path -Path $databaseBackupDir -ChildPath "backup-$d-$currDaytime.sql"

    if($configBackupCompress) {
        Write-Log "Backing up $d to compressed file $databaseBackupFile.zip..." -Path $logFile
    }
    else {
        Write-Log "Backing up $d to $databaseBackupFile..." -Path $logFile
    }
    
    try {
        Create-Backup $d $databaseBackupFile
        Invoke-FileRotation -Dir $databaseBackupDir -MaxFiles $configBackupRotate -Pattern $patternBackupFile -LogFile $logFile
    }
    catch {
        Write-Log "Could not backup database $d to $databaseBackupFile" -Path $logFile -Level Error
        Write-Log $_ -Path $logFile -Level Error
    }
}

Invoke-FileRotation -Dir $configLogDir -MaxFiles $configLogRotate -Pattern $patternLogFile -LogFile $logFile

$endTime = Get-Date -format 'yyyy-MM-dd HH:mm:ss'
Write-Log "Ended at $endTime" -Path $logFile