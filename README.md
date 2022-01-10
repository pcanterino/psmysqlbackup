# PSMySQLBackup

PSMySQLBackup is a script for backing up MySQL / MariaDB databases on Windows using [`mysqldump`](https://mariadb.com/kb/en/mysqldump/). The "PS" in PSMySQLBackup either stands for _**P**ower**S**hell …_ or _**P**atrick's **s**imple …_.

PSMySQLBackup allows you to backup all databases or only a list of databases and to keep an arbitrary or infinite number of backups.

PSMySQLBackup was inspired by [AutoMySQLBackup](https://sourceforge.net/projects/automysqlbackup/) and its [continuations](https://github.com/sixhop/AutoMySQLBackup), but has only a minimum amount of features.

## Requirements

* PowerShell x.0 (or higher)

## Basic installation

1. Copy *psmysqlbackup.ps1* to arbitrary directory (for example *C:\PSMySQLBackup*).
2. Create a directory for your backups (for example *C:\Backup*).
3. Edit *psmysqlbackup.ps1* and modify the following variables:
   1. Set ``$configBackupDir`` to the path you created in step 2.
   2. …
4. Configure Windows task planner to run the script.

## Credits

Author: Patrick Canterino, https://www.patrick-canterino.de/

License: [2-Clause BSD License](LICENSE)