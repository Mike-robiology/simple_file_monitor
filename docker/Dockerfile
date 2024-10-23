FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y ssmtp

COPY ../src/ ../conf/ monitord/
COPY ../conf/ssmtp.conf /etc/ssmtp/ssmtp.conf

RUN chmod +x monitord/src/monitor.sh
RUN bash monitord/src/monitor.sh