#!/bin/bash
# Asterisk PJSIP Monitoring for Zabbix

# v1.0 -- Sebastien Bourgeois <sb@altho.st>
# Комментарии и изменения — Торопова Анна
### Абсолютный путь к исполняемому файлу бинарника Asterisk
ASTERISK=/usr/sbin/asterisk

# Предупреждение
# -------
# Этот скрипт разработам для текущей схемы на работе, один транк для входящих вызовов и один для исходящих.
#
# Если у вас только один транк, вы можете деактивировать элементы Входящие/Исходящие вызовы, т.к. они будут нерелевантны в вашем случае
#QUEUEINC="ctt-inc"
#QUEUEOUT="ctt-out"
# Я изменила, чтобы определять число вызовов по городским линиям MTS, Beeline

if [ ! -n "$1" ]; then
    echo "Необходим аргумент !"
    exit 1
fi

# Число активных вызовов
function calls.active(){
    CALL=`$ASTERISK -rx "core show channels" |grep "active call"|awk '{print$1}'`
    echo "$CALL"
}

# Число обработанных (выполненных) вызовов
function calls.processed(){
    CALL=`$ASTERISK -rx "core show channels" |grep "calls processed"|awk '{print$1}'`
    echo "$CALL"
}

function calls.longest(){
    CHANNEL="$($ASTERISK -rx 'core show channels concise' | cut -f12,1 -d'!' | sed 's/!/ /g' | sort -n -k 2 | tail -1)"
    CHANNEL_NAME=$(echo $CHANNEL |awk '{print$1}')
    CHANNEL_TIME=$(echo $CHANNEL |awk '{print$2}')
    CHANNEL_TIME=${CHANNEL_TIME:-"0"}

    if [ "$CHANNEL_TIME" -gt 7200 ]; then
        asterisk -rx "channel request hangup $CHANNEL_NAME" >> /var/log/asterisk/full
        sleep 1

        if [ "`$ASTERISK -rx 'core show channels concise' | grep $CHANNEL_NAME`" ]; then
            echo "$CHANNEL_NAME is $CHANNEL_TIME long"
        else
            echo 1
        fi
    else
        echo 1
    fi
}

#function calls.incoming(){
#    CALL=`$ASTERISK -rx "core show channels" |grep "$QUEUEINC"|wc -l`
#    echo "$CALL"
#}

#function calls.outgoing(){
#    CALL=`$ASTERISK -rx "core show channels" |grep "$QUEUEOUT"|wc -l`
#    echo "$CALL"
#}

# Число вызовов через МТС
# Имя после grep должно совпадать с именем транковой группы в Asterisk
function calls.mts(){
    CALL=`$ASTERISK -rx "core show channels" |grep MTS|wc -l`
    echo "$CALL"
}

# Число вызовов через Билайн
function calls.beeline(){
    CALL=`$ASTERISK -rx "core show channels" |grep Beeline|wc -l`
    echo "$CALL"
}

# Число активных каналов
function channels.active(){
    CHANNEL=`$ASTERISK -rx "core show channels" | grep "active channels" | awk '{print$1}'`
    echo "$CHANNEL"
}

# Проверку числа запущенных процессов Asterisk через pidof asterisk удалила,
# т.к. для Zabbix есть готовая функция proc.num[<имя>,<пользователь>,<состояние>,<cmdline>,<зона>] 

# Проверка наличия core дампов в каталоге /tmp. Косвенно свидетельствует о проблемах с Asterisk
function status.crashes(){
    if [ -n "`find /tmp/ -type f -mtime -1 -name 'core*'`" ]; then
        echo 1
    else
        echo 0
    fi
}

# Сколько времени прошло с момента последней перезагрузки (reload) всех или одного из файлов конфигурации 
function status.reload(){
    reload_time=`$ASTERISK -rx "core show uptime seconds" | awk -F": " '/Last reload/{print$2}'`
    if [ -z "$reload_time" ];then
        echo "Конфигурационные файлы Asterisk еще не применялись (reload)"
    else
        printf '%dd:%dh:%dm:%ds\n' $(($reload_time/86400)) $(($reload_time%86400/3600)) $(($reload_time%3600/60)) $(($reload_time%60))
    fi
}

# Сколько времени работает Asterisk c момента последней перезагрузки
function status.uptime(){
    uptime=`$ASTERISK -rx "core show uptime seconds" | awk -F": " '/System uptime/{print$2}'`
    if [ -z "$uptime" ];then
        echo "Asterisk не работает"
    else
        printf '%dd:%dh:%dm:%ds\n' $(($uptime/86400)) $(($uptime%86400/3600)) $(($uptime%3600/60)) $(($uptime%60))
    fi
}

# Версия Asterisk
function status.version(){
    version=`$ASTERISK -rx "core show version" | grep Asterisk|awk '{print$2}'`
    echo "$version"
}

# Общее число SIP пиров: зарегистрированные SIP телефоны + SIP транки (как доступные, так и недоступные)
function sip.peers(){
    TRUNK=`$ASTERISK -rx "pjsip show endpoints" | grep Contact| egrep -v "<MaxContact|<Hash" | wc -l`
    echo $TRUNK
}

# Число SIP транковых групп в статусе Avail (доступен)
function sip.trunk.up(){
    TRUNK=`$ASTERISK -rx "pjsip list contacts" | grep Avail|wc -l`
    echo $TRUNK
}

# SIP транковые группы в статусе Unavail (недоступен) - показываем имя (в Zabbix имя будет в логе отвалившихся групп)
function sip.trunk.down(){
    TRUNK=`$ASTERISK -rx "pjsip list contacts" | grep Unavail| awk '{print$2}'`
    if [ -n "$TRUNK" ]; then
        echo $TRUNK
    else
        echo "1"
    fi
}

# Число зарегистрированных SIP телефонов
function sip.phone.up(){
    PHONE=`$ASTERISK -rx "pjsip list contacts" | grep Contact | egrep -v 'Avail|Unavail|RTT\(ms\)'| wc -l`
    echo $PHONE
}

# Число прописанных, но не зарегистрированных телефонов.
# Подразумевается, что внутренние телефоны это числа, т.е. не содержат букв. Имейте ввиду при настройках.
function sip.phone.down(){
    PHONE=`$ASTERISK -rx "pjsip show endpoints" | grep -w Unavailable | awk '{print$2}' | grep -v [A-Za-z] | wc -l`
    echo $PHONE
}

### Выполнить аргумент
$1
