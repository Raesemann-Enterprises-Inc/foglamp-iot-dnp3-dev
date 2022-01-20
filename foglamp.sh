#!/bin/bash

# Unprivileged Docker containers do not have access to the kernel log. This prevents an error when starting rsyslogd.
sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

# temporarily needed for kafka producing
echo '10.119.111.85 kafkaserver' >> /etc/hosts

service rsyslog start
/usr/local/foglamp/bin/foglamp start

# Codeserver for development and debugging
# password is stored in environment variable defined in dockerfile
# self-signed SSL cert
code-server --bind-addr 0.0.0.0:8080 --cert --auth password 
tail -f /var/log/syslog