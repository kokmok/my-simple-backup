# My simple backup

It's just a script to use to download files from remote server with rsync and store them by date. To add a remote server just add a file in config.d folder (take a look at the sample file).

A reporting can be sent using system mail command.

To launch a specific configuration, just add the name of the file as an argument, by exemple: `./backup.sh myWebServer`

To launch every configuration file do not precise any argument.

## Parameters
- `backup_name mybackupName` the name of your backup config. It is used for logging.
- `mail_report NO` YES if you want the script to send you an email with the logs.
- `mail_report_address email@example.com` the target mail report address.
- `user myRemoteHostUser` the ssh user of your remote host
- `host myRemoteHost` the host of from where you want to backup
- `source_folder pathToTheRemoteHostFolderToSync` the directory of your remote host you want to backup
- `dest_folder pathToTheLocalFolder` the local directory where you want to store the files
- `limit_backup_number 2` every run will create a dated backup directory. This is the parameter of the number of dated folders you want to store.
- `compress_backup NO` if YES, it will make an archive with your downloaded directory








