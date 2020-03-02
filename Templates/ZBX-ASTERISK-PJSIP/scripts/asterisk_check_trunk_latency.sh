#!/bin/bash
# Asterisk PJSIP Monitoring for Zabbix

# v1.0 -- Sebastien Bourgeois <sb@altho.st>

### Путь к исполняемому файлу бинарника Asterisk
ASTERISK=/usr/sbin/asterisk

if [ ! -n "$1" ]; then
    echo "Необходим аргумент."
    exit 1
fi

$ASTERISK -rx "pjsip show endpoints"|grep Contact|egrep -v "MaxContact|RTT\(ms\)"|grep "$1"|awk '{print $5}'
