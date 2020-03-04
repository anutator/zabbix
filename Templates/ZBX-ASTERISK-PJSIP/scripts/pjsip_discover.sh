#!/bin/bash
# Asterisk PJSIP Monitoring for Zabbix

# v1.0 -- Sebastien Bourgeois <sb@altho.st>
# This script is used for the discovery part of the template.

### Путь к исполняемому бинарнику Asterisk
ASTERISK=/usr/sbin/asterisk

# Сохраним в файл /tmp/list список транковых групп.
# Внимание: здесь предполагается, что транковые группы содержат буквы, а телефоны только номера
# Для этого я добавила grep [A-Za-z]. Иначе сохранялся список телефонов + транковых групп
$ASTERISK -rx "pjsip show endpoints"|grep Contact|egrep -v "MaxContact|RTT\(ms\)"|awk '{print $2}'|cut -d "/" -f1 | grep [A-Za-z] > /tmp/list
/usr/bin/jq -nR 'reduce inputs as $i ([]; .+[$i]) | map ({"{#TRUNKNAME}":.}) | {data: .}' /tmp/list
