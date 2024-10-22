FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y sendmail

COPY . ./src

#include(`/etc/mail/tls/starttls.m4')dnl <- add to /etc/mail/tls/starttls.m4
# run sendmailconfig
# restart sendmail