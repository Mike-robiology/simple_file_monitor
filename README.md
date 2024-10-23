# file_monitor
Simple file monitoring daemon

## Features
- **Directory Monitoring**: Monitors specified directories for file deletions.
- **Email Alerts**: Sends email alerts if any deletions are detected.
- **Connection Tests**: Performs periodic connection tests and sends alerts if the connection is inactive.
- **Report Generation**: Generates detailed reports of deleted files.
- **Logging**: Logs all activities for auditing and debugging purposes.
- **State Management**: Saves and loads the state of monitored directories to handle restarts gracefully.
- **Startup Alerts**: Sends an alert when the monitoring process starts.
- **Configurable**: Configurable emails and run parameters through a parameters file; conf/monitor.conf. 

## Parameters
| Parameter | Description |
|-----------|-------------|
| handshake_dir | Directory used to check connection |                           
| check_interval | Time between checks |                                          
| periodic_check | Number of checks before periodic connection check is triggered |
| email_recipients | Email recipients |
| email_source | Email source address (use college email) |
| connection_test_subject | Subject line for connection test email |
| connection_test_body | Body of connection test email |
| data_loss_subject | Subject line for data loss email |
| data_loss_body | Body of data loss email |
| startup_subject | Subject line for start email |
| startup_body | Body of start email |

## Dockerisation

## Known issues:
