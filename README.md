# simple_file_monitor
Simple file monitoring daemon compatible with Imperial college london's IT network.

## Features
- **Directory Monitoring**: Monitors specified directories for file deletions.
- **Email Alerts**: Sends email alerts if any deletions are detected.
- **Connection Tests**: Performs periodic connection tests and sends alerts if the connection is inactive.
- **Report Generation**: Generates detailed reports of deleted files.
- **Logging**: Logs all activities for auditing and debugging purposes.
- **State Management**: Saves and loads the state of monitored directories to handle restarts gracefully.
- **Startup Alerts**: Sends an alert when the monitoring process starts.
- **Configurable**: Configurable emails and run parameters through a parameters file; conf/monitor.conf. 

## Usage
1. Clone the repository
2. Modify the `conf/monitor.conf` file to suit your needs.
3. Add the directories you want to monitor to a conf/directories.txt file (directories should be relative to the hostmachines root directory. If using docker they should also be prefixed with "/mount")
4. If using docker, mount the remote directory to the host machine.

reports and summaries of missing files will be generated in the reports directory. A log file will also be availiblein the log directory. If copy_dir is specified they will also be copied to the specified directory for easy access.

If new directores are added to the directories.txt file the program/container will have to be restarted to monitor the new directories.

| Parameter | Description | Required? |
|-----------|-------------|--|
| handshake_dir | Directory used to check connection | ✅ |
| check_interval | Time between checks | ✅ |
| periodic_check | Number of checks before periodic connection check is triggered | ✅ |  
| email_recipients | Email recipients | ✅ |  
| email_source | Email source address (use college email) | ✅ |  
| copy_dir | Directory to copy report/summary/log files to | ❌ |
| monitor_file | File containing directories to monitor | ✅ |  
| connection_test_subject | Subject line for connection test email | ❌ |
| connection_test_body | Body of connection test email | ❌ |
| data_loss_subject | Subject line for data loss email | ❌ |
| data_loss_body | Body of data loss email | ❌ |
| startup_subject | Subject line for start email | ❌ |
| startup_body | Body of start email | ❌ |
| mailhub | SMTP server ip/FQDN | ✅ |
| rewriteDomain | Should be set to the domain requried of the network (e.g. imperial.ac.uk) | ✅ |
| hostname | Hostname of the machine | ✅ |

## Dockerisation
The repository contains an implemention in docker and is orchestrated through docker compose. This brings the advantage of me isolated from the host system and can be easily deployed on any system with docker installed. Further more compose brings advantages of container managment through e.g. restart policies.

This can be run using the following command:
```bash
docker-compose up -d
```

The included docker compose configuraion is designed to work with the Imperial College London RDS from within the ICL network. RDS onto the host machine so it is able to see the directory. This can be done by running the following command:
```bash
 sudo mount -t cifs -o uid=$USER -o gid=emailonly -o username=$USER //rds.imperial.ac.uk/RDS/ simple_file_monitor/rdsmount
```
This will mount the RDS into the simple_file_monitor/rdsmount directory.

## Dependencies
- `ssmtp` for sending emails.

## Known issues:
- Not yet able to mount network drives directly into the container.
- Container has to be restarted to monitor new directories.
- Unable to resolve UIDs of users on the RDS (limitation)
- Log is copied to copy_dir before the check cycle has completed, causeing a truncated log to be copied.
- Could be more efficient in memory (e.g. remove redundant environmental variables)
- State file is large, could be optimised