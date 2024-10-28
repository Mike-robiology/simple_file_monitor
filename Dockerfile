FROM ubuntu:latest

SHELL ["/bin/bash", "-c"]

RUN apt-get update \
&& apt upgrade -y \
&& apt-get install -y ssmtp \
&& apt-get install -y cifs-utils

WORKDIR /monitord
COPY src src

RUN chmod +x src/monitor.sh
CMD [ "src/monitor.sh" ]
